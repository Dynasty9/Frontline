use frontline_core::infantry_weapon::{CoverInput, InfantryWeapon, ShotInput, StanceInput, Weapon};
use frontline_core::random::SimulationRandom;
use frontline_core::vector::Vector3;

fn input() -> CoverInput {
    CoverInput {
        dt: 1.0 / 30.0,
        time: 10.0,
        team: 0,
        suppression: 0.0,
        last_suppression: -99.0,
        hit_dirt_timer: 0.0,
        ground: 0.0,
        cover_kind: 1,
        cover_height: 1.0,
        cover_material: 2,
        want_fire: false,
        pinned: false,
        target_valid: false,
        buddy_up: false,
        weapon: Some(Weapon {
            ammunition: 120,
            magazine: 30,
            reload_time: 2.4,
        }),
    }
}

#[test]
fn quiet_watch_fighting_extension_and_reload_keep_ordered_random_draws() {
    let mut state = InfantryWeapon {
        magazine: 8,
        reserve: 90,
        ..Default::default()
    };
    let mut rng = SimulationRandom::new(142);
    let mut expected_rng = rng;
    let mut i = input();
    assert_eq!(state.cover_cycle(i, &mut rng).unwrap(), Default::default());
    assert!(state.watching && state.peek_up);
    assert_eq!(rng, expected_rng);
    i.want_fire = true;
    state.cover_cycle(i, &mut rng).unwrap();
    assert_eq!(
        state.peek_timer,
        f64::from(expected_rng.randf_range(2.2, 4.0))
    );
    assert_eq!(state.peek_from, 9.6);
    assert_eq!(rng, expected_rng);
    state.peek_timer = 0.0;
    state.cover_cycle(i, &mut rng).unwrap();
    assert!(state.stayed && state.peek_up);
    assert_eq!(
        state.peek_timer,
        f64::from(expected_rng.randf_range(0.8, 1.6))
    );
    i.time += 2.0;
    i.suppression = 50.0;
    let result = state.cover_cycle(i, &mut rng).unwrap();
    let down_time = f64::from(expected_rng.randf_range(0.6, 1.4)) * 1.8 * 2.2;
    let speech = (expected_rng.randf() < 0.3).then(|| (expected_rng.randi() % 3) as u8);
    assert!(result.drew_fire && result.call_cover && !result.shift_along);
    assert_eq!(result.reload_speech, speech);
    assert_eq!(state.peek_timer, down_time);
    assert_eq!(state.reload_timer, 2.4);
    assert!(!state.peek_up && !state.blind);
    assert_eq!(rng, expected_rng);
}

#[test]
fn pinned_fire_and_checkpoint_resume_keep_the_same_decisions_and_rng() {
    let mut saw_blind = false;
    let mut saw_snap = false;
    let mut saw_wait = false;
    for seed in 0..120 {
        let mut state = InfantryWeapon {
            magazine: 30,
            reserve: 90,
            ..Default::default()
        };
        let mut rng = SimulationRandom::new(seed);
        let mut i = input();
        i.team = 1;
        i.want_fire = true;
        i.target_valid = true;
        i.pinned = true;
        i.suppression = 75.0;
        for tick in 0..200 {
            let saved = state.checkpoint();
            let mut restored = InfantryWeapon::restore(&saved).unwrap();
            let mut restored_rng = rng;
            i.time = 10.0 + tick as f64 / 30.0;
            let result = state.cover_cycle(i, &mut rng).unwrap();
            assert_eq!(result, restored.cover_cycle(i, &mut restored_rng).unwrap());
            assert_eq!(state, restored);
            assert_eq!(rng, restored_rng);
            saw_blind |= result.blind_fire;
            saw_snap |= result.peeked && !result.blind_fire;
            saw_wait |= !state.peek_up;
        }
    }
    assert!(saw_blind && saw_snap && saw_wait);
}

#[test]
fn bad_states_and_inputs_fail_without_mutating_state_or_randomness() {
    let mut state = InfantryWeapon::default();
    let saved = state.checkpoint();
    for size in 0..saved.len() {
        assert!(InfantryWeapon::restore(&saved[..size]).is_err());
    }
    for (offset, value) in [(4, 2), (6, 0), (40, 2), (44, 255)] {
        let mut bad = saved.clone();
        bad[offset] = value;
        if offset == 44 {
            bad[44..48].copy_from_slice(&u32::MAX.to_le_bytes());
        }
        assert!(InfantryWeapon::restore(&bad).is_err());
    }
    let mut rng = SimulationRandom::new(3);
    let before_rng = rng;
    let mut i = input();
    i.dt = f64::NAN;
    assert!(state.cover_cycle(i, &mut rng).is_err());
    assert_eq!(state.checkpoint(), saved);
    assert_eq!(rng, before_rng);
}

fn shot() -> ShotInput {
    ShotInput {
        weapon: input().weapon.unwrap(),
        burst_min: 2,
        burst_max: 5,
        time: 10.0,
        stamina: 0.2,
        moving: true,
        gun_override: true,
        squad_accuracy: 0.7,
        ambush: true,
    }
}

#[test]
fn scarce_rounds_use_single_shots_and_resume_across_combat_randomness() {
    let mut state = InfantryWeapon {
        magazine: 1,
        reserve: 8,
        blind: true,
        ..Default::default()
    };
    let mut rng = SimulationRandom::new(99);
    let mut expected_rng = rng;
    let i = shot();
    let result = state.prepare_shot(i, &mut rng).unwrap();
    assert!(result.fired && result.low_ammo && result.announce_low_ammo);
    assert_eq!(state.magazine, 0);
    assert_eq!(state.burst_left, 0);
    assert_eq!(state.last_shot, i.time);
    assert_eq!(
        result.accuracy,
        0.12 * 0.55 * 1.15 * 0.7 * 1.3 * (0.75 + 0.25 * 0.4)
    );
    assert_eq!(rng, expected_rng, "low ammo does not draw a burst size");
    let mut restored = InfantryWeapon::restore(&state.checkpoint()).unwrap();
    for _ in 0..7 {
        rng.randi();
        expected_rng.randi();
    }
    let mut restored_rng = rng;
    let recovery = state
        .finish_shot(i.weapon, 0.12, 64.0, true, true, &mut rng)
        .unwrap();
    assert_eq!(
        recovery,
        restored
            .finish_shot(i.weapon, 0.12, 64.0, true, true, &mut restored_rng)
            .unwrap()
    );
    let expected_pause = f64::from(expected_rng.randf_range(0.5, 1.2)) * 2.4 * 0.65 * 2.1;
    let expected_speech = (expected_rng.randf() < 0.3).then(|| (expected_rng.randi() % 3) as u8);
    assert_eq!(state.fire_timer, expected_pause);
    assert_eq!(recovery, expected_speech);
    assert_eq!(state, restored);
    assert_eq!(rng, restored_rng);
    assert_eq!(rng, expected_rng);
    state.advance_timers(2.4, i.weapon).unwrap();
    assert_eq!((state.magazine, state.reserve), (8, 0));
    assert!(!state.prepare_shot(i, &mut rng).unwrap().announce_low_ammo);
}

#[test]
fn empty_weapons_reload_without_firing_and_infinite_weapons_keep_ammunition() {
    let mut state = InfantryWeapon {
        magazine: 0,
        reserve: 40,
        burst_left: 3,
        ..Default::default()
    };
    let mut rng = SimulationRandom::new(71);
    let mut i = shot();
    let result = state.prepare_shot(i, &mut rng).unwrap();
    assert!(!result.fired);
    assert_eq!(state.reload_timer, 2.4);
    assert_eq!(state.burst_left, 0);
    state.advance_timers(2.4, i.weapon).unwrap();
    assert_eq!((state.magazine, state.reserve), (30, 10));
    state.magazine = 0;
    i.weapon.ammunition = 99999;
    let result = state.prepare_shot(i, &mut rng).unwrap();
    assert!(result.fired && !result.low_ammo);
    assert_eq!(state.magazine, 0);
    assert_eq!(state.reserve, 10);
    let mut expected = rng;
    let expected_pause = 0.08 * f64::from(expected.randf_range(0.9, 1.25));
    assert_eq!(
        state
            .finish_shot(i.weapon, 0.08, 20.0, false, false, &mut rng)
            .unwrap(),
        None
    );
    assert_eq!(state.fire_timer, expected_pause);
    assert_eq!(rng, expected);
    assert!(state.reload_timer <= 0.0);
}

#[test]
fn reload_adds_rounds_to_a_partial_magazine_and_rejects_overflow_atomically() {
    let mut state = InfantryWeapon {
        magazine: 6,
        reserve: 90,
        reload_timer: 1.0,
        ..Default::default()
    };
    let w = shot().weapon;
    state.advance_timers(1.0, w).unwrap();
    assert_eq!(
        (state.magazine, state.reserve),
        (36, 60),
        "preserve the existing game's partial reload rule"
    );
    state.magazine = 999999;
    state.reload_timer = 1.0;
    let saved = state;
    assert!(state.advance_timers(1.0, w).is_err());
    assert_eq!(state, saved);
    let mut rng = SimulationRandom::new(1);
    let previous_rng = rng;
    let mut invalid = shot();
    invalid.burst_max = 0;
    assert!(state.prepare_shot(invalid, &mut rng).is_err());
    assert!(state
        .finish_shot(w, f64::NAN, 0.0, false, false, &mut rng)
        .is_err());
    assert_eq!(state, saved);
    assert_eq!(rng, previous_rng);
}

#[test]
fn stance_handles_cover_shifts_escorts_bays_and_ambush_without_randomness() {
    let mut state = InfantryWeapon {
        peek_up: true,
        peek_from: 0.0,
        ..Default::default()
    };
    let mut i = StanceInput {
        time: 10.0,
        at_cover: true,
        cover_kind: 1,
        cover_height: 1.1,
        armed: true,
        ..Default::default()
    };
    assert!(i.cycles_cover());
    let pose = state.stance(i, true).unwrap();
    assert_eq!(pose.posture, 1);
    assert!(pose.can_aim);
    // Shifting to a different anchor can lower its height before posture is selected.
    i.at_cover = false;
    i.cover_height = 0.4;
    state.peek_up = false;
    let pose = state.stance(i, true).unwrap();
    assert_eq!(pose.posture, 2);
    assert!(!pose.can_aim);
    i.mode = 1;
    i.suppression = 100.0;
    i.pinned = true;
    i.hit_dirt_timer = 1.0;
    i.ambush = true;
    let pose = state.stance(i, false).unwrap();
    assert_eq!(pose.posture, 0);
    assert!(pose.can_aim);
    i.mode = 2;
    i.bay = true;
    i.hit_dirt_timer = 0.0;
    let pose = state.stance(i, false).unwrap();
    assert_eq!(pose.posture, 1);
    assert_eq!(pose.face_threat, 1);
    assert!(!pose.can_aim);
    i.mode = 0;
    i.suppression = 0.0;
    i.pinned = false;
    assert!(!state.stance(i, false).unwrap().can_aim);
    i.forced_target = true;
    assert!(state.stance(i, false).unwrap().can_aim);
    let saved = state;
    i.threat = Vector3::splat(f32::NAN);
    assert!(state.stance(i, false).is_err());
    assert_eq!(state, saved);
}
