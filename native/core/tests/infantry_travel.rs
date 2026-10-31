use frontline_core::infantry_travel::{
    self as travel, AfterBoarding, Boarding, SupplyArrival, Throw, Tunnel,
};
use frontline_core::vector::Vector3;

#[test]
fn boarding_keeps_ground_water_and_helicopter_thresholds() {
    let at = Vector3::ZERO;
    assert_eq!(
        travel::boarding(false, at, at, 1, false, false, false),
        Ok(Boarding::Cancel)
    );
    assert_eq!(
        travel::boarding(true, at, at, 0, false, false, false),
        Ok(Boarding::Cancel)
    );
    assert_eq!(
        travel::boarding(true, at, Vector3::Y * 1.01, 1, true, false, false),
        Ok(Boarding::Cancel)
    );
    assert_eq!(
        travel::boarding(true, at, Vector3::Y, 1, true, false, false),
        Ok(Boarding::Enter)
    );
    for (d, boat, moving, expected) in [
        (3.5, false, true, Boarding::Enter),
        (3.7, false, false, Boarding::Move),
        (7.9, true, true, Boarding::Enter),
        (8.0, true, true, Boarding::Move),
        (17.9, true, false, Boarding::Enter),
        (17.9, true, true, Boarding::Move),
        (18.0, true, false, Boarding::Move),
    ] {
        assert_eq!(
            travel::boarding(true, at, Vector3::X * d, 1, false, boat, moving),
            Ok(expected)
        );
    }
}

#[test]
fn after_movement_boarding_uses_the_new_position_and_route_goal() {
    assert_eq!(
        travel::after_boarding_move(Vector3::ZERO, Vector3::X * 17.0, Vector3::ZERO, true, false),
        Ok(AfterBoarding::Enter)
    );
    assert_eq!(
        travel::after_boarding_move(Vector3::ZERO, Vector3::X * 18.0, Vector3::ZERO, true, false),
        Ok(AfterBoarding::Continue { repath: true })
    );
    for (moved, goal, expected) in [(false, 0.0, true), (true, 3.0, false), (true, 3.01, true)] {
        assert_eq!(
            travel::after_boarding_move(
                Vector3::X * 20.0,
                Vector3::ZERO,
                Vector3::X * goal,
                false,
                moved
            ),
            Ok(AfterBoarding::Continue { repath: expected })
        );
    }
    assert_eq!(
        travel::tunnel_arrival(Vector3::ZERO, Vector3::ZERO, true),
        Ok(Tunnel::Move)
    );
    assert_eq!(
        travel::tunnel_arrival(Vector3::ZERO, Vector3::X * 2.5, false),
        Ok(Tunnel::Enter)
    );
    assert_eq!(
        travel::tunnel_arrival(Vector3::ZERO, Vector3::X * 2.51, false),
        Ok(Tunnel::Approach)
    );
}

#[test]
fn ordered_throw_checks_range_before_spending_or_refusing_ammunition() {
    assert_eq!(
        travel::ordered_throw(Vector3::ZERO, Vector3::X * 25.01, 0),
        Ok(Throw::Move)
    );
    assert_eq!(
        travel::ordered_throw(Vector3::ZERO, Vector3::X * 25.0, 0),
        Ok(Throw::Cancel)
    );
    assert_eq!(
        travel::ordered_throw(Vector3::ZERO, Vector3::X * 25.0, 1),
        Ok(Throw::Release { remaining: 0 })
    );
}

#[test]
fn supply_arrivals_preserve_shared_loot_and_depot_waiting() {
    assert_eq!(
        travel::supply_arrival(120, 30, 10, Some(50)),
        Ok(SupplyArrival {
            rounds: 50,
            announce: true,
            return_to_hold: true
        })
    );
    assert_eq!(
        travel::supply_arrival(120, 30, 10, Some(100)),
        Ok(SupplyArrival {
            rounds: 80,
            announce: true,
            return_to_hold: true
        })
    );
    assert_eq!(
        travel::supply_arrival(120, 30, 10, Some(0)),
        Ok(SupplyArrival {
            rounds: 0,
            announce: false,
            return_to_hold: true
        })
    );
    // A body reached after another refill keeps the existing signed transfer behavior.
    assert_eq!(
        travel::supply_arrival(120, 30, 100, Some(10)),
        Ok(SupplyArrival {
            rounds: -10,
            announce: true,
            return_to_hold: true
        })
    );
    assert!(
        !travel::supply_arrival(120, 30, 84, None)
            .unwrap()
            .return_to_hold
    );
    assert!(
        travel::supply_arrival(120, 30, 85, None)
            .unwrap()
            .return_to_hold
    );
}

#[test]
fn invalid_travel_geometry_and_ammunition_fail_closed() {
    assert!(travel::boarding(true, Vector3::NAN, Vector3::ZERO, 1, false, false, false).is_err());
    assert!(travel::after_boarding_move(
        Vector3::ZERO,
        Vector3::ZERO,
        Vector3::INFINITY,
        false,
        false
    )
    .is_err());
    assert!(travel::tunnel_arrival(Vector3::ZERO, Vector3::INFINITY, false).is_err());
    assert!(travel::ordered_throw(Vector3::ZERO, Vector3::ZERO, -1).is_err());
    assert!(travel::supply_arrival(120, 30, 10, Some(-1)).is_err());
}
