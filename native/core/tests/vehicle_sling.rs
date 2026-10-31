use frontline_core::actors::{Actor, Actors};
use frontline_core::path_planner::PathPlanner;
use frontline_core::vector::Vector3;
use frontline_core::vehicle::Vehicle;
use frontline_core::vehicle_sling::SlingSpec;

fn spec() -> SlingSpec {
    SlingSpec {
        lift: true,
        capacity: 2,
        cargo_weight: 2,
        cargo_helicopter: false,
        cargo_boat: false,
        cargo_automatic: false,
    }
}
fn pair() -> Actors {
    Actors::from_entries(
        3,
        vec![
            Actor::Vehicle(Box::new(Vehicle {
                id: 1,
                team: 0,
                position: Vector3::new(13.0, 16.0, 21.0),
                velocity: Vector3::new(2.1, 0.0, -3.7),
                yaw: 1.2,
                ..Default::default()
            })),
            Actor::Vehicle(Box::new(Vehicle {
                id: 2,
                team: 0,
                path: vec![Vector3::X * 20.0],
                speed: 3.0,
                velocity: Vector3::X * 3.0,
                assault: true,
                path_revision: 13,
                path_pending: true,
                max_hp: 1000.0,
                hp: 1000.0,
                ..Default::default()
            })),
        ],
    )
    .unwrap()
}

#[test]
fn sling_orders_and_hooking_update_both_owned_vehicles() {
    let mut actors = pair();
    assert!(actors.order_sling(1, 2, spec()).unwrap());
    let h = actors.vehicle(1).unwrap();
    assert_eq!((h.sling_target, h.lift_phase), (2, 5));
    assert!(actors.hook_sling(1, 2, spec()).unwrap());
    assert_eq!(actors.vehicle(1).unwrap().sling_cargo, 2);
    let v = actors.vehicle(2).unwrap();
    assert_eq!(v.slung_by, 1);
    assert!(v.path.is_empty() && !v.assault);
    assert_eq!(v.speed, 0.0);
    assert_eq!(v.velocity, Vector3::ZERO);
    assert_eq!(v.path_revision, 13);
    assert!(v.path_pending);
    assert!(!actors.hook_sling(1, 2, spec()).unwrap());
}

#[test]
fn capacity_and_cargo_type_gate_sling_orders_without_mutating_state() {
    let mut actors = pair();
    let saved = actors.checkpoint().unwrap();
    for s in [
        SlingSpec {
            capacity: 1,
            ..spec()
        },
        SlingSpec {
            cargo_helicopter: true,
            ..spec()
        },
        SlingSpec {
            cargo_boat: true,
            ..spec()
        },
        SlingSpec {
            cargo_automatic: true,
            ..spec()
        },
    ] {
        assert!(!actors.order_sling(1, 2, s).unwrap());
        assert_eq!(actors.checkpoint().unwrap(), saved);
    }
    assert!(!actors.order_sling(1, 1, spec()).unwrap());
    assert!(!actors.order_sling(1, 9, spec()).unwrap());
    assert_eq!(actors.checkpoint().unwrap(), saved);
}

#[test]
fn swing_position_and_heading_resume_from_the_shared_checkpoint() {
    let mut a = pair();
    a.hook_sling(1, 2, spec()).unwrap();
    for _ in 0..100 {
        a.step_sling(1, 1.0 / 30.0, 2.2).unwrap();
    }
    let mut b = Actors::restore(&a.checkpoint().unwrap()).unwrap();
    for _ in 0..200 {
        assert_eq!(
            a.step_sling(1, 1.0 / 30.0, 2.2),
            b.step_sling(1, 1.0 / 30.0, 2.2)
        );
        assert_eq!(a.checkpoint().unwrap(), b.checkpoint().unwrap());
    }
    let v = a.vehicle(2).unwrap();
    assert!((v.position.y - 6.8).abs() < 1e-5);
    assert!(v.position.x < 13.0 && v.position.z > 21.0);
    assert!((v.yaw - 1.2).abs() < 0.001);
}

#[test]
fn release_grounds_cargo_and_clears_both_links() {
    let nav = PathPlanner::new(64).unwrap();
    let mut actors = pair();
    actors.hook_sling(1, 2, spec()).unwrap();
    actors.step_sling(1, 0.1, 2.2).unwrap();
    assert_eq!(actors.release_sling(1, &nav).unwrap(), Some(2));
    assert_eq!(actors.vehicle(1).unwrap().sling_cargo, 0);
    let v = actors.vehicle(2).unwrap();
    assert_eq!(v.slung_by, 0);
    assert_eq!(v.position.y, 0.0);
    assert_eq!(v.velocity, Vector3::ZERO);
    assert_eq!(actors.release_sling(1, &nav).unwrap(), None);
}

#[test]
fn destroyed_heli_and_missing_cargo_release_the_surviving_link() {
    let nav = PathPlanner::new(64).unwrap();
    let mut actors = pair();
    actors.hook_sling(1, 2, spec()).unwrap();
    actors.step_sling(1, 0.1, 2.2).unwrap();
    let mut missing = Actors::restore(&actors.checkpoint().unwrap()).unwrap();
    missing.remove(2).unwrap();
    assert!(!missing.step_sling(1, 0.1, 2.2).unwrap());
    assert_eq!(missing.vehicle(1).unwrap().sling_cargo, 0);
    actors.remove(1).unwrap();
    let drop = actors.drop_sling(2, &nav).unwrap();
    assert!((drop.damage - 1000.0 * 6.8 / 30.0).abs() < 1e-4);
    assert!(drop.impact);
    assert_eq!(drop.position.y, 0.0);
    assert_eq!(actors.vehicle(2).unwrap().slung_by, 0);
    let landed = actors.drop_sling(2, &nav).unwrap();
    assert!(!landed.impact);
    assert_eq!(landed.damage, 0.0);
}

#[test]
fn rejected_sling_steps_leave_both_vehicles_unchanged() {
    let mut actors = pair();
    actors.hook_sling(1, 2, spec()).unwrap();
    let saved = actors.checkpoint().unwrap();
    assert!(actors.step_sling(1, f64::NAN, 2.2).is_err());
    assert!(actors.step_sling(1, 0.1, -1.0).is_err());
    assert_eq!(actors.checkpoint().unwrap(), saved);
}
