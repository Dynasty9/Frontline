use frontline_core::collision::{BoxShape, CollisionWorld, Mat3};
use frontline_core::drone::{DroneFlight, Phase};
use frontline_core::vector::Vector3;

#[test]
fn checkpoint_resumes_every_flight_phase_and_loss_of_control() {
    let mut world = CollisionWorld::default();
    for phase in [
        Phase::Climb,
        Phase::Cruise,
        Phase::Dive,
        Phase::Uncontrolled,
    ] {
        let mut drone = DroneFlight::new(Vector3::new(0.0, 5.0, 0.0), 0.0);
        drone.phase = phase;
        drone.velocity = Vector3::new(1.0, 2.0, -3.0);
        drone.diving = phase == Phase::Dive;
        let mut restored = DroneFlight::restore(&drone.checkpoint()).unwrap();
        for tick in 0..2000 {
            let target = (tick < 90).then_some(Vector3::new(60.0, 1.5, 3.0));
            if tick == 200 {
                drone.lose_control();
                restored.lose_control();
            }
            assert_eq!(
                drone.advance(1.0 / 30.0, target, &mut world, 512.0),
                restored.advance(1.0 / 30.0, target, &mut world, 512.0)
            );
            assert_eq!(drone, restored);
            if drone.dead {
                break;
            }
        }
        assert!(drone.dead);
        let dead = drone;
        assert!(!drone.advance(1.0, None, &mut world, 512.0));
        assert_eq!(dead, drone);
    }
}

#[test]
fn obstacles_and_map_boundary_detonate_once() {
    let mut world = CollisionWorld::default();
    assert!(world.replace(
        7,
        &[BoxShape {
            body: 7,
            shape: 0,
            center: Vector3::new(2.0, 5.0, 0.0),
            basis: Mat3::IDENTITY,
            half: Vector3::new(0.1, 8.0, 5.0)
        }]
    ));
    let mut drone = DroneFlight::new(Vector3::new(0.0, 5.0, 0.0), 0.0);
    drone.phase = Phase::Dive;
    drone.velocity = Vector3::X * 26.0;
    assert!(drone.advance(0.1, Some(Vector3::X * 100.0), &mut world, 512.0));
    assert!((drone.position.x - 1.9).abs() < 0.0001);
    assert!(!drone.advance(0.1, None, &mut world, 512.0));
    let mut edge = DroneFlight::new(Vector3::new(512.0, 5.0, 0.0), 0.0);
    assert!(edge.advance(0.0, None, &mut world, 512.0));
}

#[test]
fn malformed_drone_state_is_rejected() {
    let original = DroneFlight::new(Vector3::Y, 0.0).checkpoint();
    for n in 0..original.len() {
        assert!(DroneFlight::restore(&original[..n]).is_err());
    }
    for (offset, value) in [(4, 2), (8, 4), (9, 2), (10, 2)] {
        let mut bytes = original.clone();
        bytes[offset] = value;
        assert!(DroneFlight::restore(&bytes).is_err());
    }
    let mut bytes = original.clone();
    bytes[11..15].copy_from_slice(&f32::NAN.to_le_bytes());
    assert!(DroneFlight::restore(&bytes).is_err());
    let mut bytes = original.clone();
    bytes[47..55].copy_from_slice(&f64::INFINITY.to_le_bytes());
    assert!(DroneFlight::restore(&bytes).is_err());
    let mut bytes = original;
    bytes.push(0);
    assert!(DroneFlight::restore(&bytes).is_err());
}
