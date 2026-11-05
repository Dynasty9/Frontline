#[allow(dead_code)]
#[path = "fixtures/boat_world.rs"]
mod fixture;
use fixture::{field, navigation, profile, step};
use frontline_core::attack_plan;
use frontline_core::infantry_vitals::Life;
use frontline_core::vehicle_movement_world::Event as Movement;
use frontline_core::vehicle_world::Event;

#[test]
fn boat_motion_and_shared_combat_resume_together() {
    let mut a = field(0);
    let mut nav = navigation(false);
    let events = step(&mut a, &mut nav, profile(), &mut vec![], &mut 17).unwrap();
    assert!(a.scene.world.actors.vehicle(20).unwrap().position.z < 8.0);
    assert!(events.iter().any(|e| matches!(e, Event::Combat(_))));
    fixture::transcript();
}
#[test]
fn landed_passengers_leave_before_the_boat_fights() {
    let mut a = field(1);
    let mut nav = navigation(false);
    let events = step(&mut a, &mut nav, profile(), &mut vec![], &mut 17).unwrap();
    assert!(events.contains(&Event::Attack(attack_plan::Event::Stat("dismount"))));
    assert!(a
        .scene
        .world
        .actors
        .vehicle(20)
        .unwrap()
        .passengers
        .is_empty());
    let s = a.scene.world.actors.soldier(1).unwrap();
    assert_eq!(s.vitals.life, Life::Alive);
    assert_eq!(s.links.vehicle, 0);
}
#[test]
fn stuck_boats_keep_their_recovery_and_emit_the_original_stat() {
    let mut a = field(2);
    let mut nav = navigation(false);
    let events = step(&mut a, &mut nav, profile(), &mut vec![], &mut 17).unwrap();
    assert!(events.contains(&Event::Movement(Movement::Stat("boat_unstick"))));
    assert!(a.scene.world.actors.vehicle(20).unwrap().astern);
}
#[test]
fn invalid_boat_profile_does_not_change_actors_or_navigation() {
    let mut a = field(0);
    let before = a.resume();
    let mut nav = navigation(false);
    let saved = nav.checkpoint();
    let mut p = profile();
    p.movement.speed = f64::NAN;
    assert!(step(&mut a, &mut nav, p, &mut vec![], &mut 17).is_err());
    a.compare(&before);
    assert_eq!(nav.checkpoint(), saved);
}
