use frontline_core::deferred_effects::{DeferredEffects, Rubble};
use frontline_core::random::SimulationRandom;
use frontline_core::vector::Vector3;

#[test]
fn cache_damage_waits_for_game_time_and_equal_deadlines_keep_insertion_order() {
    let mut q = DeferredEffects::default();
    let mut rng = SimulationRandom::new(137);
    assert_eq!(q.cook_off(1.0, Vector3::X, 160.0, &mut rng).unwrap(), 9);
    assert_eq!(q.cook_off(1.0, Vector3::NEG_X, 0.0, &mut rng).unwrap(), 5);
    assert!(q.advance_to(1.0).unwrap().is_empty());
    assert!(q.advance_to(1.049).unwrap().is_empty());
    let first = q.advance_to(1.05).unwrap();
    assert_eq!(first.len(), 2);
    assert_eq!(first[0].position, Vector3::new(1.0, 0.6, 0.0));
    assert_eq!(first[0].damage, 130.0);
    assert_eq!(first[1].position, Vector3::new(-1.0, 0.6, 0.0));
    assert_eq!(first[1].damage, 58.0);
    assert!(q.advance_to(1.05).unwrap().is_empty());
    assert_eq!(q.advance_to(20.0).unwrap().len(), 12);
    assert!(q.is_empty());
}
#[test]
fn restored_events_and_new_chain_reactions_preserve_the_random_cursor_and_order() {
    let mut q = DeferredEffects::default();
    let mut rng = SimulationRandom::new(371);
    q.cook_off(0.0, Vector3::ZERO, 77.3, &mut rng).unwrap();
    q.advance_to(0.1).unwrap();
    let mut restored = DeferredEffects::restore(&q.checkpoint()).unwrap();
    let mut other = rng;
    for tick in 4..360 {
        let time = f64::from(tick) / 30.0;
        if tick % 71 == 0 {
            q.cook_off(time, Vector3::X, 25.0, &mut rng).unwrap();
            restored
                .cook_off(time, Vector3::X, 25.0, &mut other)
                .unwrap();
        }
        assert_eq!(
            q.advance_to(time).unwrap(),
            restored.advance_to(time).unwrap()
        );
        assert_eq!(q.checkpoint(), restored.checkpoint());
        assert_eq!(rng, other);
        if tick % 17 == 0 {
            restored = DeferredEffects::restore(&restored.checkpoint()).unwrap();
        }
    }
}
#[test]
fn invalid_schedule_and_backwards_clock_are_atomic_including_random_draws() {
    let mut q = DeferredEffects::default();
    let mut rng = SimulationRandom::new(371);
    q.advance_to(10.0).unwrap();
    let before = q.checkpoint();
    let draws = rng;
    for (time, pos, supply) in [
        (9.0, Vector3::ZERO, 160.0),
        (f64::NAN, Vector3::ZERO, 1.0),
        (10.0, Vector3::ZERO, f64::INFINITY),
        (1e12, Vector3::ZERO, 160.0),
        (10.0, Vector3::new(0.0, 1_000_000.0, 0.0), 160.0),
    ] {
        assert!(q.cook_off(time, pos, supply, &mut rng).is_err());
        assert_eq!(q.checkpoint(), before);
        assert_eq!(rng, draws);
    }
    for now in [9.0, -0.0, f64::NAN, f64::INFINITY] {
        assert!(q.advance_to(now).is_err());
        assert_eq!(q.checkpoint(), before);
    }
}
#[test]
fn checkpoint_rejects_truncation_unknown_versions_duplicate_sequences_and_overdue_events() {
    let mut q = DeferredEffects::default();
    let mut rng = SimulationRandom::new(371);
    q.cook_off(0.0, Vector3::ZERO, 160.0, &mut rng).unwrap();
    let bytes = q.checkpoint();
    for n in 0..bytes.len() {
        assert!(DeferredEffects::restore(&bytes[..n]).is_err());
    }
    let mut bad = bytes.clone();
    bad.push(0);
    assert!(DeferredEffects::restore(&bad).is_err());
    let mut bad = bytes.clone();
    bad[6..8].copy_from_slice(&0u16.to_le_bytes());
    assert!(DeferredEffects::restore(&bad).is_err());
    let mut bad = bytes.clone();
    bad[8..16].copy_from_slice(&1.0f64.to_le_bytes());
    assert!(DeferredEffects::restore(&bad).is_err());
    // Cache events have no optional direction: each record is 95 bytes.
    let mut bad = bytes.clone();
    let first = &bytes[36..44];
    bad[131..139].copy_from_slice(first);
    assert!(DeferredEffects::restore(&bad).is_err());
    let mut bad = bytes.clone();
    bad[24..28].copy_from_slice(&u32::MAX.to_le_bytes());
    assert!(DeferredEffects::restore(&bad).is_err());
    let mut bad = bytes.clone();
    bad[114..118].copy_from_slice(&1u32.to_le_bytes());
    assert!(
        DeferredEffects::restore(&bad).is_err(),
        "a cache blast cannot gain an attacker on restore"
    );
}

#[test]
fn deferred_rubble_keeps_spawn_order_across_checkpoints_and_drains_once() {
    let mut q = DeferredEffects::default();
    let first = Rubble {
        position: Vector3::X,
        yaw: 0.731,
        size: Vector3::new(8.0, 0.0, 2.4),
    };
    let second = Rubble {
        position: Vector3::NEG_X,
        ..first
    };
    q.defer_rubble(first).unwrap();
    q.defer_rubble(second).unwrap();
    let before = q.checkpoint();
    assert!(q
        .defer_rubble(Rubble {
            size: Vector3::NEG_X,
            ..first
        })
        .is_err());
    assert!(q
        .defer_rubble(Rubble {
            yaw: f64::NAN,
            ..first
        })
        .is_err());
    assert_eq!(q.checkpoint(), before);
    let mut restored = DeferredEffects::restore(&before).unwrap();
    assert_eq!(restored.len(), 2);
    assert!(!restored.is_empty());
    assert_eq!(restored.take_rubble(), vec![first, second]);
    assert!(restored.take_rubble().is_empty());
    assert!(restored.is_empty());
    for n in 0..before.len() {
        assert!(DeferredEffects::restore(&before[..n]).is_err());
    }
}
