use frontline_core::drone_reaction::{Drone, DroneMemory};
use frontline_core::random::SimulationRandom;
use frontline_core::vector::Vector3;

fn drone(id: u64, distance: f32) -> Drone {
    Drone {
        id,
        position: Vector3::new(distance, 0.0, 0.0),
        target: Vector3::ZERO,
        team: 1,
        dead: false,
        diving: false,
    }
}

#[test]
fn hearing_preserves_order_range_altitude_and_eviction() {
    let mut state = DroneMemory {
        heard: (100..117).collect(),
    };
    let mut rng = SimulationRandom::new(337);
    let mut expected = rng;
    let mut friendly = drone(3, 1.0);
    friendly.team = 0;
    let mut dead = drone(4, 1.0);
    dead.dead = true;
    let mut high = drone(5, 44.0);
    high.position.y = 10.0;
    let result = state
        .react(
            Vector3::ZERO,
            0,
            &[
                drone(100, 1.0),
                friendly,
                dead,
                high,
                drone(6, 45.0),
                drone(7, 45.01),
                drone(8, 2.0),
            ],
            &mut rng,
        )
        .unwrap();
    assert_eq!(state.heard, vec![6, 8]);
    assert_eq!(
        result
            .warnings
            .iter()
            .map(|w| (w.drone, w.variant))
            .collect::<Vec<_>>(),
        vec![
            (6, (expected.randi() % 3) as u8),
            (8, (expected.randi() % 3) as u8)
        ]
    );
    assert_eq!(rng, expected);
    assert_eq!(result.dive_from, None);
    assert!(state
        .react(Vector3::ZERO, 0, &[drone(6, 1.0), drone(8, 2.0)], &mut rng)
        .unwrap()
        .warnings
        .is_empty());
    assert_eq!(rng, expected);
}

#[test]
fn dive_chance_follows_the_warning_and_stops_the_scan() {
    for seed in 0..256 {
        let mut rng = SimulationRandom::new(seed);
        let mut expected = rng;
        let mut state = DroneMemory::default();
        let mut first = drone(1, 9.0);
        first.diving = true;
        let mut second = drone(2, 8.0);
        second.diving = true;
        second.target.x = 5.5;
        let mut third = drone(3, 8.99);
        third.diving = true;
        third.target = Vector3::new(5.49, 200.0, 0.0);
        let result = state
            .react(
                Vector3::ZERO,
                0,
                &[first, second, third, drone(4, 1.0)],
                &mut rng,
            )
            .unwrap();
        for i in 0..3 {
            assert_eq!(result.warnings[i].variant, (expected.randi() % 3) as u8);
        }
        let dive = f64::from(expected.randf()) < 0.8;
        assert_eq!(result.dive_from, dive.then_some(third.position));
        if !dive {
            assert_eq!(result.warnings[3].variant, (expected.randi() % 3) as u8);
        }
        assert_eq!(result.warnings.len(), if dive { 3 } else { 4 });
        assert_eq!(rng, expected);
    }
}

#[test]
fn invalid_input_and_checkpoints_preserve_memory_and_randomness() {
    let mut state = DroneMemory {
        heard: vec![23, 41],
    };
    let checkpoint = state.checkpoint();
    assert_eq!(DroneMemory::restore(&checkpoint).unwrap(), state);
    for len in 0..checkpoint.len() {
        assert!(DroneMemory::restore(&checkpoint[..len]).is_err());
    }
    let mut trailing = checkpoint.clone();
    trailing.push(0);
    assert!(DroneMemory::restore(&trailing).is_err());
    for bad in [vec![0], vec![23, 23], (1..19).collect(), vec![u64::MAX]] {
        assert!(DroneMemory::restore(&DroneMemory { heard: bad }.checkpoint()).is_err());
    }
    let mut rng = SimulationRandom::new(337);
    let initial = rng;
    let mut bad = drone(1, 1.0);
    bad.target.x = f32::NAN;
    assert!(state
        .react(Vector3::ZERO, 0, &[drone(2, 1.0), bad], &mut rng)
        .is_err());
    assert_eq!(rng, initial);
    assert_eq!(state.checkpoint(), checkpoint);
}
