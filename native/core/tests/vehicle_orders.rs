#[path = "fixtures/vehicle_orders.rs"]
#[allow(dead_code)]
mod fixture;
use frontline_core::actors::Actor;
use frontline_core::vector::Vector3;
use frontline_core::vehicle_orders::Order;

use fixture::scene;
#[test]
fn landing_objective_does_not_replace_the_safe_beach_route() {
    let (mut s, mut boats) = scene("boat", false);
    s.context()
        .order_vehicle(20, Order::Move(Vector3::new(10., 0., 10.)), &mut boats)
        .unwrap();
    let before = s.world.actors.checkpoint().unwrap();
    assert!(s
        .world
        .actors
        .set_landing_objective(999, Vector3::ZERO)
        .is_err());
    assert!(s
        .world
        .actors
        .set_landing_objective(20, Vector3::new(f32::NAN, 0., 0.))
        .is_err());
    assert_eq!(before, s.world.actors.checkpoint().unwrap());
    let path = s.world.actors.vehicle(20).unwrap().path.clone();
    let objective = Vector3::new(-12., 0., 5.);
    s.world.actors.set_landing_objective(20, objective).unwrap();
    let boat = s.world.actors.vehicle(20).unwrap();
    assert_eq!(boat.assault_destination, Some(objective));
    assert_eq!(boat.path, path);
}

#[test]
fn movement_submits_routes_and_stop_rejects_old_completions() {
    let (mut s, mut boats) = scene("tank", false);
    s.context()
        .order_vehicle(20, Order::Move(Vector3::new(10., 0., 10.)), &mut boats)
        .unwrap();
    let revision = s.world.actors.vehicle(20).unwrap().path_revision;
    assert!(revision > 0);
    s.context()
        .order_vehicle(20, Order::Stop, &mut boats)
        .unwrap();
    let v = s.world.actors.vehicle(20).unwrap();
    assert_eq!(v.path_revision, revision + 1);
    assert!(v.path.is_empty());
    assert!(!v.path_pending);
    assert!(!v
        .clone()
        .complete_path(revision, vec![Vector3::ONE])
        .unwrap());
    s.world.geometry.navigation.planner.begin_batch();
    assert!(s.world.geometry.navigation.planner.next_job().is_none());
}
#[test]
fn boat_routes_are_applied_before_the_order_returns() {
    let (mut s, mut boats) = scene("boat", false);
    let dest = Vector3::new(10., 0., 10.);
    let expected = boats.path(s.world.actors.vehicle(20).unwrap().position, dest);
    assert!(!expected.is_empty());
    s.context()
        .order_vehicle(20, Order::Assault(dest), &mut boats)
        .unwrap();
    let v = s.world.actors.vehicle(20).unwrap();
    assert_eq!(v.path, expected);
    assert!(v.assault);
    assert_eq!(v.assault_destination, Some(dest));
}
#[test]
fn withdrawing_ai_crew_keeps_its_route_and_player_ownership_can_override_it() {
    let (mut s, mut boats) = scene("tank", true);
    let before = s.world.actors.checkpoint().unwrap();
    s.context()
        .order_vehicle(20, Order::Move(Vector3::ZERO), &mut boats)
        .unwrap();
    assert_eq!(before, s.world.actors.checkpoint().unwrap());
    s.world.actors = frontline_core::actors::Actors::from_entries(
        1000,
        s.world
            .actors
            .iter()
            .cloned()
            .map(|mut a| {
                if let Actor::Vehicle(v) = &mut a {
                    v.owner = 7;
                }
                a
            })
            .collect(),
    )
    .unwrap();
    s.context()
        .order_vehicle(20, Order::Move(Vector3::ZERO), &mut boats)
        .unwrap();
    let v = s.world.actors.vehicle(20).unwrap();
    assert!(v.brain_overruled);
    assert!(v.brain_state.is_empty());
}
#[test]
fn attack_uses_retained_target_position_and_missing_targets_do_nothing() {
    let (mut s, mut boats) = scene("tank", false);
    let before = s.world.actors.checkpoint().unwrap();
    s.context()
        .order_vehicle(20, Order::Attack(999), &mut boats)
        .unwrap();
    assert_eq!(before, s.world.actors.checkpoint().unwrap());
    s.context()
        .order_vehicle(20, Order::Attack(21), &mut boats)
        .unwrap();
    let v = s.world.actors.vehicle(20).unwrap();
    assert_eq!(v.forced_target, 21);
    assert!(v.path_revision > 0);
}
#[test]
fn lift_orders_find_landing_ground_and_stop_holds_the_aircraft() {
    let (mut s, mut boats) = scene("heli", false);
    s.context()
        .order_vehicle(20, Order::Move(Vector3::new(2., 8., 3.)), &mut boats)
        .unwrap();
    assert_eq!(
        s.world.actors.vehicle(20).unwrap().lift_destination,
        Some(Vector3::new(2., 0., 3.))
    );
    s.context()
        .order_vehicle(20, Order::Stop, &mut boats)
        .unwrap();
    let v = s.world.actors.vehicle(20).unwrap();
    assert_eq!(v.flight_hold, Some(v.position));
    assert_eq!(v.lift_phase, 7);
}
#[test]
fn malformed_positions_do_not_change_the_actor_or_route_queue() {
    let (mut s, mut boats) = scene("tank", false);
    let before = s.world.actors.checkpoint().unwrap();
    let nav = s.world.geometry.navigation.checkpoint();
    assert!(s
        .context()
        .order_vehicle(20, Order::Move(Vector3::splat(f32::NAN)), &mut boats)
        .is_err());
    assert_eq!(before, s.world.actors.checkpoint().unwrap());
    assert_eq!(nav, s.world.geometry.navigation.checkpoint());
}
