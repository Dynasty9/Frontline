#[allow(dead_code)]
#[path = "fixtures/ordnance_world.rs"]
mod fixture;
use fixture::Battle;
use frontline_core::actors::Actor;
use frontline_core::infantry_vitals::Life;
use frontline_core::ordnance_world::Event;
use frontline_core::projectile_actor::Motion;
use frontline_core::vector::Vector3;
use frontline_core::world_combat::Event as Combat;

#[test]
fn grenade_damage_and_smothering_apply_before_removal_and_resume_exactly() {
    for case in [0, 1, 6] {
        let mut battle = Battle::new(case);
        let mut resumed = battle.resume();
        let events = battle.step(0.1).unwrap();
        assert_eq!(events, resumed.step(0.1).unwrap());
        battle.compare(&resumed);
        assert!(battle.field.scene.world.actors.get(battle.id).is_none());
        assert_ne!(
            battle
                .field
                .scene
                .world
                .actors
                .soldier(1)
                .unwrap()
                .vitals
                .life,
            Life::Alive
        );
        if case == 1 {
            let death = events
                .iter()
                .position(|e| matches!(e, Event::Combat(Combat::InfantryHit { id: 1, .. })))
                .unwrap();
            let blast = events
                .iter()
                .position(|e| matches!(e, Event::Combat(Combat::Explosion { .. })))
                .unwrap();
            assert!(death < blast);
            assert!(events.contains(&Event::Combat(Combat::Stat("smother_saved"))));
        }
    }
}
#[test]
fn smoke_updates_visibility_and_disappears_when_its_actor_expires() {
    let mut battle = Battle::new(2);
    battle.step(1.0).unwrap();
    assert!(battle.field.scene.world.visibility.smoke_blocks(
        Vector3::new(-5.0, 1.0, -10.0),
        Vector3::new(5.0, 1.0, -10.0)
    ));
    for _ in 0..3 {
        battle.step(9.0).unwrap();
    }
    assert!(battle.field.scene.world.actors.get(battle.id).is_none());
    assert!(!battle.field.scene.world.visibility.smoke_blocks(
        Vector3::new(-5.0, 1.0, -10.0),
        Vector3::new(5.0, 1.0, -10.0)
    ));
}
#[test]
fn missiles_resolve_their_source_smoke_and_shared_target() {
    let mut battle = Battle::new(3);
    let events = battle.step(0.05).unwrap();
    assert!(events.contains(&Event::Combat(Combat::Stat("atgm_lost_in_smoke"))));
    let Some(Actor::Projectile(p)) = battle.field.scene.world.actors.get(battle.id) else {
        panic!()
    };
    assert_eq!(p.target_id, 0);
    assert!(matches!(&p.motion, Motion::Guided(f) if !f.locked));
}
#[test]
fn support_aircraft_spawn_attributed_bombs_and_retained_recon_marks() {
    let mut battle = Battle::new(4);
    let mut resumed = battle.resume();
    let events = battle.step(0.1).unwrap();
    assert_eq!(events, resumed.step(0.1).unwrap());
    battle.compare(&resumed);
    let spawned = events
        .iter()
        .find_map(|e| {
            if let Event::Spawn(id) = e {
                Some(*id)
            } else {
                None
            }
        })
        .unwrap();
    let Some(Actor::Projectile(p)) = battle.field.scene.world.actors.get(spawned) else {
        panic!()
    };
    assert_eq!((p.thrower, p.called_by, p.team), (20, 7, 0));
    assert_eq!(battle.marks[0].len(), 1);
    assert!(battle.marks[1].is_empty());
    assert!(events.contains(&Event::Combat(Combat::Stat("recon_photo"))));
}
#[test]
fn drones_finish_shared_damage_before_despawning() {
    let mut battle = Battle::new(5);
    let mut resumed = battle.resume();
    let events = battle.step(0.1).unwrap();
    assert_eq!(events, resumed.step(0.1).unwrap());
    battle.compare(&resumed);
    assert_eq!(
        events.first(),
        Some(&Event::Combat(Combat::Stat("drone_boom")))
    );
    assert_eq!(
        events.last(),
        Some(&Event::Combat(Combat::Despawn(battle.id)))
    );
    assert!(battle.field.scene.world.actors.get(battle.id).is_none());
    assert!(battle.field.scene.world.actors.vehicle(20).is_none());
}
#[test]
fn invalid_steps_do_not_change_shared_state() {
    for case in [0, 5] {
        let mut battle = Battle::new(case);
        let before = battle.resume();
        assert!(battle.step(f64::NAN).is_err());
        battle.compare(&before);
    }
}
