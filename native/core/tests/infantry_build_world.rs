#[allow(dead_code)]
#[path = "fixtures/infantry_build_world.rs"]
mod fixture;
use fixture::{scene, step};
use frontline_core::infantry_build_world::Construction;
use frontline_core::infantry_controller::Task;
use frontline_core::infantry_fight_world::Event;

#[test]
fn finishing_a_building_adds_collision_cover_and_credit_before_the_work_sound() {
    let mut s = scene(0);
    assert!(!s.world.geometry.collision.contains(10));
    let out = step(&mut s, 0.1).unwrap();
    assert!(s.world.geometry.collision.contains(10));
    assert!(s.world.actors.structure(10).unwrap().built);
    assert_eq!(s.world.battle.sides[0][17], 1.0);
    assert!(matches!(
        out[0],
        Event::Construction(Construction::Completed { id: 10, .. })
    ));
    assert!(matches!(
        out[1],
        Event::Construction(Construction::Sound { .. })
    ));
    assert_eq!(s.world.actors.soldier(1).unwrap().activity, 7);
}
#[test]
fn repairs_restore_a_fob_and_fix_tracks_without_construction_credit() {
    let mut s = scene(1);
    let out = step(&mut s, 0.1).unwrap();
    assert!(!s.world.actors.structure(10).unwrap().wrecked);
    assert!(out.contains(&Event::Construction(Construction::FobRestored { id: 10 })));
    assert_eq!(s.world.battle.sides[0][17], 0.0);
    let mut s = scene(2);
    let out = step(&mut s, 0.1).unwrap();
    let v = s.world.actors.vehicle(10).unwrap();
    assert!(!v.track_broken);
    assert_eq!(v.track_fix, 0.0);
    assert_eq!(v.hp, 90.25);
    assert!(out.contains(&Event::Construction(Construction::TrackRepaired { id: 10 })));
}
#[test]
fn a_completed_tent_is_ready_for_bearers_and_the_order_finishes_on_the_next_update() {
    let mut s = scene(3);
    step(&mut s, 0.1).unwrap();
    assert_eq!(s.world.actors.structure(10).unwrap().bearer_timer, 0.0);
    assert_eq!(s.world.actors.soldier(1).unwrap().duty.kind, Task::Build);
    step(&mut s, 0.1).unwrap();
    assert_eq!(s.world.actors.soldier(1).unwrap().duty.kind, Task::Fight);
    assert_eq!(s.world.squads[0].build_target, 0);
    assert_eq!(s.world.squads[0].order, "hold");
}
#[test]
fn another_working_builder_prevents_the_completion_shout_and_random_draw() {
    let mut s = scene(5);
    let random = s.world.rng.state();
    assert!(step(&mut s, 0.1).unwrap().is_empty());
    assert_eq!(s.world.rng.state(), random);
    let mut s = scene(6);
    assert!(step(&mut s, 0.1)
        .unwrap()
        .iter()
        .any(|e| matches!(e, Event::Speech { .. })));
}
#[test]
fn construction_resumes_preserve_shared_state_and_randomness() {
    for case in 0..10 {
        let mut s = scene(case);
        let mut resumed = s.resume();
        assert_eq!(step(&mut s, 0.1).unwrap(), step(&mut resumed, 0.1).unwrap());
        s.world.compare(&resumed.world);
        assert_eq!(s.world.squads, resumed.world.squads);
    }
}
#[test]
fn an_invalid_step_does_not_start_work_or_consume_randomness() {
    let mut s = scene(0);
    let original = s.resume();
    assert!(step(&mut s, f64::NAN).is_err());
    s.world.compare(&original.world);
    assert_eq!(s.world.squads, original.world.squads);
}
