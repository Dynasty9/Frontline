use frontline_core::random::SimulationRandom;

#[test]
fn seeded_sequence_matches_godot_47_reference() {
    let mut rng = SimulationRandom::new(3);
    let expected = [
        1282583244, 4290596118, 3518853771, 923096409, 1603255823, 2895522225, 1060061534,
        1969238970,
    ];
    for value in expected {
        assert_eq!(rng.randi(), value);
    }
    assert_eq!(rng.state(), (-6751205313363611295i64) as u64);
}

#[test]
fn restoring_state_reproduces_mixed_draws_and_equal_bounds_do_not_draw() {
    let mut rng = SimulationRandom::new(u64::MAX);
    for _ in 0..111 {
        rng.randf();
    }
    let saved = rng.state();
    let mut values = Vec::new();
    for _ in 0..200 {
        values.push((
            rng.randf().to_bits(),
            rng.randi_range(i32::MIN, 1),
            rng.randi(),
        ));
    }
    let final_state = rng.state();
    rng.set_state(saved);
    assert_eq!(rng.randi_range(17, 17), 17);
    assert_eq!(rng.state(), saved);
    for (real, integer, word) in values {
        assert_eq!(rng.randf().to_bits(), real);
        assert_eq!(rng.randi_range(i32::MIN, 1), integer);
        assert_eq!(rng.randi(), word);
    }
    assert_eq!(rng.state(), final_state);
}
