#[allow(dead_code)]
#[path = "fixtures/infantry_breach_world.rs"]
mod fixture;
use fixture::{scene, step};
use frontline_core::infantry_action::Action;
use frontline_core::infantry_controller::Task;
use frontline_core::infantry_fight_world::Event;
use frontline_core::world_combat;

#[test]
fn expired_breach_releases_the_shared_claim_without_random_draws() {
    let mut s = scene(0, false, true);
    s.world.now = 145.0;
    let random = s.world.rng.state();
    assert!(step(&mut s).unwrap().is_empty());
    let man = s.world.actors.soldier(1).unwrap();
    assert_eq!(man.duty.kind, Task::Fight);
    assert_eq!(man.duty.entity, 0);
    assert_eq!(s.world.squads[0].breach_by, 0);
    assert_eq!(s.world.rng.state(), random);
}
#[test]
fn stacking_stops_the_path_before_waiting_at_the_door() {
    let mut s = scene(0, false, true);
    step(&mut s).unwrap();
    let man = s.world.actors.soldier(1).unwrap();
    assert_eq!(man.duty.phase, 1);
    assert!(!man.orders.pending_path && !man.is_moving());
    assert!(man.entry.wait_until >= 100.5 && man.entry.wait_until <= 100.9);
}
#[test]
fn a_closed_door_requires_a_kick_before_using_a_grenade() {
    let mut s = scene(2, true, false);
    let random = s.world.rng.state();
    let events = step(&mut s).unwrap();
    let man = s.world.actors.soldier(1).unwrap();
    assert_eq!(man.grenades.frags, 1);
    assert!(matches!(
        man.action.current,
        Action::DoorKick { door: 11, .. }
    ));
    assert_eq!(man.action.remaining, 0.45);
    assert_eq!(man.orders.path_revision, 2);
    assert!(events.contains(&Event::World(world_combat::Event::Stat("breach_door_kick"))));
    assert_eq!(s.world.rng.state(), random);
}
#[test]
fn an_open_door_starts_the_throw_and_preserves_its_fuse_and_room_target() {
    let mut s = scene(2, false, false);
    let events = step(&mut s).unwrap();
    let man = s.world.actors.soldier(1).unwrap();
    assert_eq!(man.grenades.frags, 0);
    assert_eq!(man.duty.phase, 3);
    assert_eq!(man.entry.wait_until, 104.5);
    let Action::ThrowIn { position, fuse } = man.action.current else {
        panic!("missing breach throw")
    };
    assert_eq!(fuse, 3.4);
    assert_eq!(position.y, 0.06);
    assert!(position.z < 4.0 && position.z > 0.0);
    assert!(events
        .iter()
        .any(|e| matches!(e, Event::Speech { id: 1, .. })));
}
#[test]
fn room_entry_issues_the_buddys_route_and_releases_the_breach_claim() {
    let mut s = scene(4, false, true);
    let events = step(&mut s).unwrap();
    assert_eq!(s.world.squads[0].breach_by, 0);
    assert_eq!(s.world.squads[0].clear_call, Some((1, 102.5)));
    assert_eq!(s.world.actors.soldier(1).unwrap().duty.kind, Task::Fight);
    assert_eq!(s.world.actors.soldier(3).unwrap().orders.leash, 2.5);
    assert_eq!(s.world.actors.soldier(3).unwrap().orders.move_mode, 2);
    assert_eq!(s.world.actors.soldier(4).unwrap().orders.leash, 9.0);
    assert!(events
        .iter()
        .any(|e| matches!(e, Event::Speech { id: 3, .. })));
}
#[test]
fn resumed_breach_phases_preserve_shared_routes_actions_and_randomness() {
    for phase in 0..5 {
        for closed in [false, true] {
            let mut s = scene(phase, closed, true);
            let mut restored = s.resume();
            assert_eq!(step(&mut s).unwrap(), step(&mut restored).unwrap());
            assert_eq!(
                s.world.actors.checkpoint().unwrap(),
                restored.world.actors.checkpoint().unwrap()
            );
            assert_eq!(
                s.world.geometry.checkpoint(),
                restored.world.geometry.checkpoint()
            );
            assert_eq!(s.world.squads, restored.world.squads);
            assert_eq!(s.world.rng.state(), restored.world.rng.state());
        }
    }
}

#[test]
fn invalid_step_rejects_before_changing_breach_or_randomness() {
    let mut s = scene(2, false, false);
    let before = s.world.actors.checkpoint().unwrap();
    let random = s.world.rng.state();
    let result = s.context().advance_breach(
        1,
        f64::NAN,
        None,
        &|_| None,
        &mut frontline_core::bullet_world::Gunfire::default(),
        &mut frontline_core::supply_network::SupplyNetwork::default(),
        &mut vec![],
        &|_| frontline_core::vehicle_damage::Armor {
            level: 0,
            helicopter: false,
            boat: false,
            supply: false,
            toss: 1.0,
        },
        &|_| 2.0,
    );
    assert!(result.is_err());
    assert_eq!(s.world.actors.checkpoint().unwrap(), before);
    assert_eq!(s.world.rng.state(), random);
}
