use frontline_core::infantry::{Identity, Infantry};
use frontline_core::infantry_action::{Action, Round, Throw};
use frontline_core::infantry_control::{Hidden, HiddenReason};
use frontline_core::infantry_controller::Task;
use frontline_core::infantry_pose::Posture;
use frontline_core::infantry_vitals::{DamageResult, Life};
use frontline_core::path_planner::PathPlanner;
use frontline_core::random::SimulationRandom;
use frontline_core::vector::Vector3;

fn soldier() -> Infantry {
    let mut s = Infantry {
        identity: Identity {
            id: 1,
            squad: 17,
            unit: "rifleman".into(),
            weapon: "rifle".into(),
            ..Default::default()
        },
        ..Default::default()
    };
    s.action.current = Action::Cook;
    s.action.remaining = 0.2;
    s.action.queued_throw = Some(Throw {
        position: Vector3::X * 12.0,
        round: Round::Frag,
        fuse: 1.0,
    });
    s.motion.path = vec![Vector3::X * 10.0];
    s.weapon.magazine = 17;
    s.weapon.reserve = 94;
    s.fight.controlled_drone = 8;
    s.emplacement.structure = 9;
    s.identity.mounted_weapon = "mg".into();
    s.orders.base_y = 4.0;
    s.orders.backwards = true;
    s.duty.entity = 2;
    s.duty.partner = 3;
    s
}

#[test]
fn downing_releases_rescue_and_drone_links_and_preserves_casualty_carriers() {
    let mut s = soldier();
    s.duty.kind = Task::Rescue;
    s.links.carried_by = vec![4, 5];
    s.links.rescue_claimed = 6;
    s.links.stretcher_claimed = true;
    s.hit_kind = "bullet".into();
    s.weapon.peek_up = true;
    let released = s.go_down(100.0).unwrap();
    assert_eq!((released.patient, released.drone), (2, 8));
    assert_eq!(s.vitals.life, Life::Downed);
    assert_eq!(s.vitals.bleed, 50.0);
    assert_eq!(s.vitals.downed_at, 100.0);
    assert_eq!(s.posture, Posture::Prone);
    assert_eq!(s.links.carried_by, vec![4, 5]);
    assert!(!s.links.stretcher_claimed && s.links.rescue_claimed == 0);
    assert!(!s.weapon.peek_up && !s.orders.backwards && !s.is_moving());
    assert!(s.identity.mounted_weapon.is_empty() && s.hit_kind.is_empty());
    assert_eq!(s.action.current, Action::None);
    assert!(s.action.queued_throw.is_none());
    assert_eq!(s.orders.path_revision, 1);
}

#[test]
fn death_keeps_loot_and_is_idempotent_and_breaching_releases_the_squad() {
    let mut s = soldier();
    s.duty.kind = Task::Breach;
    s.hit_kind = "explosion".into();
    s.hit_direction = Vector3::new(3.0, 2.0, 4.0);
    let out = s.die(30.0, Some(200)).unwrap().unwrap();
    assert_eq!(out.squad, 17);
    assert_eq!(s.fight.loot, 111);
    assert_eq!((s.weapon.magazine, s.weapon.reserve), (0, 0));
    assert_eq!(s.death_pose().kind, 1);
    assert_eq!(s.death_pose().impulse, Vector3::new(2.4, 2.5, 3.2));
    let dead = s.clone();
    assert_eq!(s.die(40.0, Some(200)).unwrap(), None);
    assert_eq!(s, dead);
    s = soldier();
    s.duty.kind = Task::Stretcher;
    let out = s.die(30.0, Some(9000)).unwrap().unwrap();
    assert_eq!(out.stretcher, 2);
    assert_eq!(s.fight.loot, 0);
}

#[test]
fn revival_restores_missing_rifles_and_preserves_remaining_ammunition_otherwise() {
    let mut rng = SimulationRandom::new(137);
    let mut expected = rng;
    let mut s = soldier();
    s.identity.weapon.clear();
    s.vitals.life = Life::Downed;
    s.motion.position.y = -1.0;
    s.links.carried_by = vec![4, 5];
    s.links.dragged_by = 4;
    s.links.rescue_claimed = 5;
    s.cover.at_cover = true;
    assert_eq!(
        s.revive(false, Some(("rifle", 30)), &mut rng).unwrap(),
        (expected.randi() % 4) as u8
    );
    assert_eq!(s.vitals.times_downed, 1);
    assert_eq!(s.vitals.hp, s.vitals.base_hp * 0.8 * 0.85);
    assert_eq!(s.posture, Posture::Crouch);
    assert_eq!((s.weapon.magazine, s.weapon.reserve), (30, 0));
    assert!(
        s.links.carried_by.is_empty() && s.links.dragged_by == 0 && s.links.rescue_claimed == 0
    );
    assert_eq!(s.motion.position.y, 0.0);
    assert!(!s.cover.at_cover);
    s.weapon.magazine = 9;
    s.weapon.reserve = 7;
    s.revive(true, Some(("other", 10)), &mut rng).unwrap();
    assert_eq!(s.identity.weapon, "rifle");
    assert_eq!((s.weapon.magazine, s.weapon.reserve), (9, 7));
    assert_eq!(s.vitals.hp, s.vitals.max_hp);
}

#[test]
fn blast_releases_a_living_actor_but_does_not_interrupt_carried_casualties() {
    let mut s = soldier();
    s.duty.kind = Task::Rescue;
    s.links.dragged_by = 7;
    let mut rng = SimulationRandom::new(137);
    let out = s.fling_from(Vector3::ZERO, 7.0, &mut rng).unwrap().unwrap();
    assert_eq!(out.patient, 2);
    assert!(s.shock.flinging);
    assert_eq!(s.activity, 17);
    assert_eq!(s.links.dragged_by, 0);
    assert_eq!(s.death_pose().impulse, s.shock.velocity);
    let flung = s.clone();
    let random = rng;
    assert_eq!(s.fling_from(Vector3::ZERO, 7.0, &mut rng).unwrap(), None);
    assert_eq!(s, flung);
    assert_eq!(rng, random);
    s = soldier();
    s.links.carried_by.push(7);
    let before = s.clone();
    assert_eq!(s.fling_from(Vector3::ZERO, 7.0, &mut rng).unwrap(), None);
    assert_eq!(s, before);
}

#[test]
fn hidden_transport_and_corpse_cleanup_keep_link_and_tick_boundaries() {
    let mut s = soldier();
    s.hide_in(HiddenReason::Vehicle, 9.0, None).unwrap();
    assert_eq!(
        s.hidden_tick(0.1, Some(Vector3::X)).unwrap(),
        Hidden::FollowVehicle(Vector3::X)
    );
    assert_eq!(s.motion.position, Vector3::X);
    assert_eq!(s.control.hidden_timer, 9.0);
    assert_eq!(s.hidden_tick(0.1, None).unwrap(), Hidden::BailOut);
    let nav = PathPlanner::new(32).unwrap();
    s.unhide(Vector3::new(2.1, -2.0, 3.2), &nav).unwrap();
    assert_eq!(s.vitals.life, Life::Alive);
    assert_eq!(s.motion.position.y, 0.0);
    assert_eq!(s.orders.hold_position, s.motion.position);
    s.die(10.0, None).unwrap();
    s.links.carried_by = vec![2, 3];
    assert!(!s.corpse_tick(0.0, 400.0, true).unwrap());
    assert_eq!(s.activity, 13);
    assert!(!s.corpse_tick(0.0, 400.0, false).unwrap());
    assert!(s.links.carried_by.is_empty());
    assert!(s.corpse_tick(0.0, 400.0, false).unwrap());
}

#[test]
fn damage_and_failed_transitions_resume_from_the_full_actor_checkpoint() {
    let mut s = soldier();
    let mut rng = SimulationRandom::new(137);
    let mut restored = Infantry::restore(&s.checkpoint().unwrap()).unwrap();
    let mut random = rng;
    let damage = s
        .receive_damage(150.0, Vector3::X, "bullet", false, &mut rng)
        .unwrap();
    assert_eq!(
        restored
            .receive_damage(150.0, Vector3::X, "bullet", false, &mut random)
            .unwrap(),
        damage
    );
    assert_eq!(s, restored);
    assert_eq!(rng, random);
    assert!(matches!(damage, DamageResult::Down | DamageResult::Die));
    s.orders.path_revision = i64::MAX as u64;
    let before = s.clone();
    assert!(s.go_down(1.0).is_err());
    assert!(s.die(1.0, None).is_err());
    assert!(s.fling_from(Vector3::ZERO, 8.0, &mut rng).is_err());
    assert!(s.revive(true, Some(("rifle", -1)), &mut rng).is_err());
    assert_eq!(s, before);
    assert_eq!(rng, random);
}
