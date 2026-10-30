use frontline_core::infantry_vitals::{
    DamageResult, FatigueInput, InfantryVitals, Life, Protection,
};
use frontline_core::random::SimulationRandom;

#[test]
fn protection_caps_suppression_without_erasing_existing_pressure() {
    let mut state = InfantryVitals::default();
    let mut rng = SimulationRandom::new(19);
    let before = rng;
    let p = Protection {
        at_cover: true,
        cover_kind: 1,
        material: Some(3),
        in_trench: true,
        ..Default::default()
    };
    let result = state.suppress(80.0, 10.0, true, true, p, &mut rng).unwrap();
    assert_eq!(state.suppression, 7.0);
    assert_eq!(state.reveal_until, 11.0);
    assert!(result.report_position && result.speech.is_none());
    assert_eq!(rng, before);
    state.suppression = 80.0;
    let mut expected_rng = rng;
    let speech = (expected_rng.randf() < 0.05).then(|| (expected_rng.randi() % 4) as u8);
    let result = state
        .suppress(80.0, 10.5, false, true, p, &mut rng)
        .unwrap();
    assert_eq!(
        state.suppression, 80.0,
        "cover caps new suppression, it does not remove old pressure instantly"
    );
    assert!(!result.report_position);
    assert_eq!(result.speech, speech);
    assert_eq!(rng, expected_rng);
    state.recover(0.5, 11.0, p).unwrap();
    assert_eq!(state.suppression, 72.0);
    state.recover(0.5, 12.1, p).unwrap();
    assert_eq!(state.suppression, 62.0);
    state.life = Life::Downed;
    let saved = state;
    let previous_rng = rng;
    assert_eq!(
        state
            .suppress(50.0, 13.0, false, true, p, &mut rng)
            .unwrap(),
        Default::default()
    );
    assert_eq!(state, saved);
    assert_eq!(rng, previous_rng);
}

#[test]
fn damage_short_circuits_preserve_random_draws_and_life_transitions() {
    for life in [
        Life::Dead,
        Life::Hidden,
        Life::Captive,
        Life::Surrender,
        Life::Downed,
    ] {
        let mut state = InfantryVitals {
            life,
            hp: 1.0,
            bleed: 1.0,
            ..Default::default()
        };
        let mut rng = SimulationRandom::new(73);
        let before = rng;
        let result = state.damage(50.0, true, true, &mut rng).unwrap();
        assert_eq!(
            result,
            if life == Life::Dead || life == Life::Hidden {
                DamageResult::Ignored
            } else {
                DamageResult::Die
            }
        );
        assert_eq!(rng, before, "guaranteed outcomes do not draw randomness");
    }
    for seed in 0..200 {
        let mut state = InfantryVitals {
            hp: 10.0,
            ..Default::default()
        };
        let mut rng = SimulationRandom::new(seed);
        let mut expected = rng;
        let should_die = f64::from(expected.randf()) < 0.14 + 10.0 / 150.0;
        assert_eq!(
            state.damage(20.0, false, false, &mut rng).unwrap(),
            if should_die {
                DamageResult::Die
            } else {
                DamageResult::Down
            }
        );
        assert_eq!(rng, expected);
        assert_eq!(state.hp, -10.0);
        assert_eq!(state.suppression, 22.0);
        assert_eq!(
            state.life,
            Life::Alive,
            "the actor applies the transition after hit attribution"
        );
        if should_die {
            state.die(5.0).unwrap();
            assert_eq!(state.dead_at, 5.0);
        } else {
            state.go_down(5.0).unwrap();
            assert_eq!(state.bleed, 50.0);
            assert_eq!(state.downed_at, 5.0);
        }
        assert_eq!(state.hp, 0.0);
    }
}

#[test]
fn repeat_wounds_limit_revival_health_and_future_survival() {
    let mut state = InfantryVitals {
        base_hp: 120.0,
        ..Default::default()
    };
    for (index, health) in [96.0, 74.4, 54.0, 42.0, 42.0].into_iter().enumerate() {
        state.go_down(index as f64).unwrap();
        assert_eq!(state.bleed_max, [50.0, 38.0, 26.0, 16.0][index.min(3)]);
        assert_eq!(
            (state.scream_timer, state.pistol_timer, state.crawl_timer),
            (0.4, 2.5, 1.5)
        );
        state.revive(index % 2 == 0).unwrap();
        assert_eq!(state.max_hp, health);
        assert_eq!(state.hp, health * if index % 2 == 0 { 1.0 } else { 0.85 });
        assert_eq!(state.suppression, 25.0);
    }
    let mut rng = SimulationRandom::new(3);
    let mut expected = rng;
    expected.randf();
    assert_eq!(
        state.damage(50.0, false, false, &mut rng).unwrap(),
        DamageResult::Die
    );
    assert_eq!(
        rng, expected,
        "the original repeated-wound rule still draws its probability"
    );
}

#[test]
fn fatigue_and_recovery_resume_bit_for_bit_and_keep_limits() {
    let mut state = InfantryVitals {
        suppression: 53.0,
        hit_dirt_timer: 0.1,
        speech_cooldown: 2.6,
        ..Default::default()
    };
    for tick in 0..1000 {
        let mut restored = InfantryVitals::restore(&state.checkpoint()).unwrap();
        let fatigue = FatigueInput {
            moving_or_diving: tick % 3 != 0,
            move_mode: tick % 4,
            crawling: tick % 7 == 0,
            heavy_task: tick % 5 == 0,
            carrying: tick % 11 == 0,
            standing: tick % 2 == 0,
        };
        for s in [&mut state, &mut restored] {
            s.recover(0.1, f64::from(tick) * 0.1, Protection::default())
                .unwrap();
            s.fatigue(0.1, fatigue).unwrap();
        }
        assert_eq!(state, restored);
        assert!((0.0..=1.0).contains(&state.stamina));
        assert!(state.suppression >= 0.0);
    }
    assert_eq!(state.hit_dirt_timer, 0.0);
    assert!(state.speech_cooldown < 0.0);
}

#[test]
fn checkpoints_and_bad_inputs_are_strict_and_atomic() {
    let mut state = InfantryVitals::default();
    let saved = state;
    let bytes = state.checkpoint();
    for size in 0..bytes.len() {
        assert!(InfantryVitals::restore(&bytes[..size]).is_err());
    }
    let mut trailing = bytes.clone();
    trailing.push(0);
    assert!(InfantryVitals::restore(&trailing).is_err());
    for (offset, value) in [(4, 2), (6, 0), (8, 6), (12, 255)] {
        let mut bad = bytes.clone();
        bad[offset] = value;
        assert!(InfantryVitals::restore(&bad).is_err());
    }
    let mut bad = bytes;
    bad[13..21].copy_from_slice(&f64::NAN.to_le_bytes());
    assert!(InfantryVitals::restore(&bad).is_err());
    let mut rng = SimulationRandom::new(99);
    let before = rng;
    assert!(state.damage(-1.0, false, false, &mut rng).is_err());
    assert!(state
        .suppress(
            10.0,
            1.0,
            false,
            false,
            Protection {
                material: Some(4),
                ..Default::default()
            },
            &mut rng
        )
        .is_err());
    assert!(state
        .recover(f64::INFINITY, 0.0, Protection::default())
        .is_err());
    assert!(state.fatigue(-1.0, FatigueInput::default()).is_err());
    assert_eq!(state, saved);
    assert_eq!(rng, before);
    state.hp = -1e12;
    let limit = state;
    assert!(state.damage(1.0, false, false, &mut rng).is_err());
    assert_eq!(state, limit);
    assert_eq!(rng, before);
}
