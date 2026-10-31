use frontline_core::boat_navigation::{BoatNavigation, LEVEL};
use frontline_core::vector::Vector3;
use frontline_core::vehicle::Vehicle;
use frontline_core::vehicle_boat::BoatProfile;
use frontline_core::vehicle_motion::Traffic;

fn profile() -> BoatProfile {
    BoatProfile {
        hull: Vector3::new(2.0, 1.5, 6.0),
        speed: 12.0,
        response: [2.5, 2.6, 0.45, 0.65, 0.6, 4.2, 0.85, 0.28, 0.45],
        cannon: false,
    }
}
fn water() -> BoatNavigation {
    BoatNavigation::new(128, &vec![0; 128 * 128], &vec![1.0; 128 * 128]).unwrap()
}
fn boat() -> Vehicle {
    Vehicle {
        id: 1,
        position: Vector3::new(0.0, LEVEL, 0.0),
        path: vec![Vector3::NEG_Z * 80.0],
        ..Default::default()
    }
}

#[test]
fn helm_and_engines_reach_a_destination_and_take_off_the_way() {
    let mut nav = water();
    let mut v = boat();
    for tick in 0..2700 {
        v.boat_drive(
            1.0 / 30.0,
            tick as f64 / 30.0,
            profile(),
            None,
            &mut nav,
            None,
            &[],
        )
        .unwrap();
    }
    assert_eq!(v.path_index, v.path.len() as u32);
    assert!((v.position.z + 80.0).abs() < 10.0);
    assert!(v.speed.abs() < 0.1);
    assert_eq!(v.position.y, LEVEL);
}

#[test]
fn nearby_destination_astern_is_backed_into() {
    let mut nav = water();
    let mut v = Vehicle {
        path: vec![Vector3::Z * 6.0],
        ..boat()
    };
    for tick in 0..300 {
        v.boat_drive(
            1.0 / 30.0,
            tick as f64 / 30.0,
            profile(),
            None,
            &mut nav,
            None,
            &[],
        )
        .unwrap();
    }
    assert!(v.reverse);
    assert!(v.position.z > 1.0);
    assert!(v.yaw.abs() < 0.1);
}

#[test]
fn watchdog_replans_and_backs_off_without_resetting_repeated_attempts() {
    let mut nav = water();
    let mut v = Vehicle {
        stuck_timer: 4.1,
        ..boat()
    };
    let e = v
        .boat_drive(1.0 / 30.0, 12.0, profile(), None, &mut nav, None, &[])
        .unwrap();
    assert!(e.unstuck && v.astern);
    assert_eq!(v.tries, 1);
    assert_eq!(v.astern_timer, 12.0);
    assert!(!v.path.is_empty());
    let state = v.checkpoint().unwrap();
    let mut resumed = Vehicle::restore(&state).unwrap();
    for tick in 0..300 {
        let now = 12.0 + tick as f64 / 30.0;
        let e = v
            .boat_drive(1.0 / 30.0, now, profile(), None, &mut nav, None, &[])
            .unwrap();
        assert_eq!(
            resumed
                .boat_drive(1.0 / 30.0, now, profile(), None, &mut nav, None, &[])
                .unwrap(),
            e
        );
        assert_eq!(resumed.checkpoint().unwrap(), v.checkpoint().unwrap());
    }
}

#[test]
fn bank_contact_takes_off_speed_and_ends_a_landing_near_the_goal() {
    let side = 64;
    let solid: Vec<_> = (0..side * side).map(|i| u8::from(i / side < 32)).collect();
    let mut nav = BoatNavigation::new(side, &solid, &vec![1.0; side * side]).unwrap();
    let mut v = Vehicle {
        position: Vector3::new(0.0, LEVEL, 0.01),
        speed: 8.0,
        passengers: vec![7],
        path: vec![Vector3::NEG_Z * 5.0],
        ..boat()
    };
    let e = v
        .boat_drive(0.1, 0.0, profile(), None, &mut nav, None, &[])
        .unwrap();
    assert!(v.grounded && v.landing);
    assert!(v.speed < 4.0);
    assert_eq!(v.path_index, v.path.len() as u32);
    assert!(!e.aground);
}

#[test]
fn targets_astern_stop_attack_runs_and_stationary_traffic_is_avoided() {
    let mut nav = water();
    let mut v = Vehicle {
        assault: true,
        speed: 3.0,
        ..boat()
    };
    let mut free = v.clone();
    for tick in 0..300 {
        v.boat_drive(
            1.0 / 30.0,
            tick as f64 / 30.0,
            profile(),
            Some(Vector3::Z * 5.0),
            &mut nav,
            None,
            &[],
        )
        .unwrap();
        free.boat_drive(
            1.0 / 30.0,
            tick as f64 / 30.0,
            profile(),
            None,
            &mut nav,
            None,
            &[],
        )
        .unwrap();
    }
    assert!(v.speed.abs() < 0.5 && free.position.z < v.position.z - 20.0);
    let mut v = boat();
    let traffic = [Traffic {
        id: 2,
        position: Vector3::NEG_Z * 5.0,
        yaw: 0.0,
        speed: 0.0,
        hull: profile().hull,
        air: false,
    }];
    v.boat_drive(1.0 / 30.0, 0.0, profile(), None, &mut nav, None, &traffic)
        .unwrap();
    assert_eq!(v.avoid_cap, Some(3.0));
}

#[test]
fn malformed_steps_leave_vehicle_and_navigation_unchanged() {
    let mut nav = water();
    let mut v = boat();
    let state = v.checkpoint().unwrap();
    let grid = nav.checkpoint();
    assert!(v
        .boat_drive(f64::NAN, 0.0, profile(), None, &mut nav, None, &[])
        .is_err());
    let mut p = profile();
    p.response[3] = 0.0;
    assert!(v
        .boat_drive(0.1, 0.0, p, None, &mut nav, None, &[])
        .is_err());
    assert!(v
        .boat_drive(0.1, 0.0, profile(), Some(Vector3::NAN), &mut nav, None, &[])
        .is_err());
    assert_eq!(v.checkpoint().unwrap(), state);
    assert_eq!(nav.checkpoint(), grid);
    v.tries = 1_000_000;
    let state = v.checkpoint().unwrap();
    assert!(v
        .boat_drive(0.1, 0.0, profile(), None, &mut nav, None, &[])
        .is_err());
    assert_eq!(v.checkpoint().unwrap(), state);
}
