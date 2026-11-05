#[allow(dead_code)]
#[path = "fixtures/infantry_mount_world.rs"]
mod fixture;
use fixture::{scene, step};
use frontline_core::infantry_action_owned::Event as Ordnance;
use frontline_core::infantry_fight_world::Event;
use frontline_core::world_combat;

#[test]
fn a_tower_climb_retains_its_timer_then_sets_the_elevated_firing_position() {
    let mut s = scene("watchtower", 0, 0, false);
    step(&mut s, 0.1).unwrap();
    assert_eq!(s.world.actors.soldier(1).unwrap().duty.phase, 1);
    assert_eq!(s.world.actors.soldier(1).unwrap().motion.position.y, 0.0);
    step(&mut s, 1.6).unwrap();
    let man = s.world.actors.soldier(1).unwrap();
    assert_eq!(man.duty.phase, 2);
    assert_eq!(man.orders.base_y, 4.25);
    assert_eq!(man.motion.position.y, 4.25);
}
#[test]
fn a_gun_claim_changes_the_weapon_before_firing_and_calls_out_once() {
    let mut s = scene("mg_nest", 0, 1, false);
    assert!(step(&mut s, 0.1)
        .unwrap()
        .iter()
        .any(|e| matches!(e, Event::Speech { text, .. } if text == "Manning the gun!")));
    assert_eq!(
        s.world.actors.soldier(1).unwrap().identity.mounted_weapon,
        "mmg"
    );
    assert!(!step(&mut s, 0.1)
        .unwrap()
        .iter()
        .any(|e| matches!(e, Event::Speech { .. })));
}
#[test]
fn the_mortar_consumes_one_order_and_creates_an_attributed_round() {
    let mut s = scene("mortar_pit", 2, 0, false);
    let out = step(&mut s, 0.1).unwrap();
    assert!(out.contains(&Event::World(world_combat::Event::Stat("mortar_round"))));
    assert_eq!(s.world.actors.structure(10).unwrap().fire_queue.len(), 1);
    let man = s.world.actors.soldier(1).unwrap();
    assert_eq!(man.arsenal.mortar_ready, 102.2);
    assert!(man.emplacement.mortar_aim.is_none());
    let Some(Event::Ordnance(Ordnance::Spawn(id))) = out.first() else {
        panic!("missing mortar")
    };
    let frontline_core::actors::Actor::Projectile(p) = s.world.actors.get(*id).unwrap() else {
        panic!("wrong actor")
    };
    assert_eq!((p.thrower, p.team), (1, 0));
}
#[test]
fn both_at_weapons_launch_and_vehicle_defense_finishes_before_the_launch_effect() {
    for team in [0, 1] {
        let mut s = scene("at_post", 2, team, true);
        let out = step(&mut s, 0.1).unwrap();
        assert!(
            out.contains(&Event::World(world_combat::Event::Stat("at_launch"))),
            "{out:?}"
        );
        let smoke = out
            .iter()
            .position(|e| matches!(e, Event::Ordnance(Ordnance::Smoke { .. })))
            .unwrap();
        let launch = out
            .iter()
            .position(|e| matches!(e, Event::Ordnance(Ordnance::Launch { .. })))
            .unwrap();
        assert!(smoke < launch);
        assert_eq!(s.world.actors.vehicle(20).unwrap().smoke_left, 1);
        assert_eq!(s.world.actors.vehicle(20).unwrap().brain_state, "evade");
    }
}
#[test]
fn mounted_updates_resume_routes_rounds_and_randomness_exactly() {
    for kind in ["watchtower", "mg_nest", "hmg_nest", "mortar_pit", "at_post"] {
        let mut s = scene(kind, 2, 1, true);
        let mut resumed = s.resume();
        assert_eq!(step(&mut s, 0.1).unwrap(), step(&mut resumed, 0.1).unwrap());
        s.world.compare(&resumed.world);
    }
}
#[test]
fn invalid_steps_do_not_move_gunners_or_consume_orders_and_randomness() {
    let mut s = scene("mortar_pit", 2, 0, false);
    let original = s.resume();
    assert!(step(&mut s, f64::NAN).is_err());
    s.world.compare(&original.world);
}
