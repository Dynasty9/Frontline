use frontline_core::terrain::Terrain;
use frontline_core::vector::Vector3;
use frontline_core::vehicle::Vehicle;
use frontline_core::vehicle_flight::FlightProfile;

fn profile() -> FlightProfile {
    FlightProfile {
        speed: 22.0,
        accel: 5.0,
        brake: 6.0,
        turn: 0.7,
        turn_accel: 0.95,
    }
}
fn helicopter() -> Vehicle {
    Vehicle {
        id: 1,
        flight: Some([0.0; 3]),
        position: Vector3::Y * 0.15,
        ..Default::default()
    }
}

#[test]
fn helicopters_brake_to_hover_and_settle_without_snapping() {
    let terrain = Terrain::blank(128).unwrap();
    let mut v = helicopter();
    let goal = Vector3::new(31.7, 16.0, -21.3);
    let mut settled = false;
    for _ in 0..1500 {
        settled = v
            .fly_to(goal, 1.0 / 30.0, None, profile(), &terrain, &[])
            .unwrap();
    }
    assert!(settled);
    assert!(v.position.distance(goal) < 0.001);
    assert!(v.velocity.length() < 0.001);
    assert!(v.flight_pitch.abs() < 0.001 && v.flight_roll.abs() < 0.001);
}

#[test]
fn coarse_flight_steps_use_the_same_fixed_substeps() {
    let terrain = Terrain::blank(128).unwrap();
    let goal = Vector3::new(31.7, 16.0, -21.3);
    let mut a = helicopter();
    let mut b = a.clone();
    for _ in 0..100 {
        a.fly_to(goal, 0.1, Some(1.2), profile(), &terrain, &[])
            .unwrap();
        for _ in 0..3 {
            b.fly_to(goal, 1.0 / 30.0, Some(1.2), profile(), &terrain, &[])
                .unwrap();
        }
        assert_eq!(a, b);
    }
}

#[test]
fn ground_and_bridge_clearance_prevent_descending_through_the_surface() {
    let terrain = Terrain::blank(32).unwrap();
    for deck in [vec![], vec![1; 32 * 32]] {
        let mut v = helicopter();
        v.position.y = 0.0;
        v.velocity.y = -6.0;
        v.fly_to(Vector3::ZERO, 0.1, None, profile(), &terrain, &deck)
            .unwrap();
        let floor = if deck.is_empty() { 0.15 } else { 0.21 };
        assert!((f64::from(v.position.y) - floor).abs() < 1e-7);
        // The float32 height can sit a few nanometres above the double-precision floor.
        assert!(v.velocity.y >= -1e-7);
    }
}

#[test]
fn sling_cargo_reduces_acceleration_and_yaw_authority() {
    let terrain = Terrain::blank(128).unwrap();
    let mut light = helicopter();
    let mut loaded = light.clone();
    loaded.sling_cargo = 9;
    let goal = Vector3::new(40.0, 16.0, 20.0);
    for _ in 0..60 {
        light
            .fly_to(goal, 1.0 / 30.0, None, profile(), &terrain, &[])
            .unwrap();
        loaded
            .fly_to(goal, 1.0 / 30.0, None, profile(), &terrain, &[])
            .unwrap();
    }
    assert!(light.speed > loaded.speed);
    assert!(light.yaw.abs() > loaded.yaw.abs());
}

#[test]
fn flight_checkpoints_resume_momentum_and_cyclic_without_divergence() {
    let terrain = Terrain::blank(128).unwrap();
    let mut a = helicopter();
    let goal = Vector3::new(31.7, 16.0, -21.3);
    a.fly_to(goal, 1.3, None, profile(), &terrain, &[]).unwrap();
    let mut b = Vehicle::restore(&a.checkpoint().unwrap()).unwrap();
    for i in 0..500 {
        let goal = if i < 100 {
            goal
        } else {
            Vector3::new(-13.2, 0.15, 7.9)
        };
        let left = a
            .fly_to(goal, 1.0 / 30.0, None, profile(), &terrain, &[])
            .unwrap();
        let right = b
            .fly_to(goal, 1.0 / 30.0, None, profile(), &terrain, &[])
            .unwrap();
        assert_eq!(left, right);
        assert_eq!(a, b);
    }
    let saved = a.clone();
    assert!(a
        .fly_to(goal, f64::NAN, None, profile(), &terrain, &[])
        .is_err());
    assert_eq!(a, saved);
    assert!(a
        .fly_to(goal, 0.1, None, profile(), &terrain, &[0])
        .is_err());
    assert_eq!(a, saved);
}

#[test]
fn uav_orbits_resume_the_same_position_and_heading() {
    let mut a = Vehicle {
        id: 1,
        uav_destination: Some(Vector3::new(7.3, 0.0, -21.7)),
        ..Default::default()
    };
    for _ in 0..200 {
        a.fly_uav(1.0 / 30.0, 25.0, 16.0, profile()).unwrap();
    }
    let mut b = Vehicle::restore(&a.checkpoint().unwrap()).unwrap();
    for _ in 0..500 {
        a.fly_uav(1.0 / 30.0, 25.0, 16.0, profile()).unwrap();
        b.fly_uav(1.0 / 30.0, 25.0, 16.0, profile()).unwrap();
        assert_eq!(a, b);
    }
    assert!((a.position.y - 25.0).abs() < 1e-5);
    assert!(a.orbit > 0.0);
}
