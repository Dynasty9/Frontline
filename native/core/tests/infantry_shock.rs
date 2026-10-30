use frontline_core::infantry_shock::{InfantryShock, Stagger};
use frontline_core::infantry_vitals::Life;
use frontline_core::path_planner::PathPlanner;
use frontline_core::random::SimulationRandom;
use frontline_core::vector::Vector3 as V;

#[test]
fn fling_guards_preserve_randomness_and_low_obstacles_bounce_only_horizontal_motion() {
    let mut rng = SimulationRandom::new(17);
    for (life, power, carried, flinging) in [
        (Life::Hidden, 8.0, false, false),
        (Life::Alive, 0.8, false, false),
        (Life::Alive, 8.0, true, false),
        (Life::Dead, 8.0, false, true),
    ] {
        let mut shock = InfantryShock {
            flinging,
            ..Default::default()
        };
        let before = (shock, rng);
        assert!(!shock
            .fling(V::ZERO, V::ZERO, power, life, carried, &mut rng)
            .unwrap());
        assert_eq!((shock, rng), before);
    }
    let mut nav = PathPlanner::new(16).unwrap();
    assert!(nav.load_cells(&[3; 256], &[0; 256], &[0; 256]));
    let mut shock = InfantryShock::default();
    assert!(shock
        .fling(V::X, V::ZERO, 8.0, Life::Dead, false, &mut rng)
        .unwrap());
    assert_eq!(shock.velocity, V::new(8.0, 6.1, 0.0));
    let landed = shock
        .fling_step(V::ZERO, Life::Dead, 0.1, &nav, &mut rng)
        .unwrap();
    assert_eq!(landed.position.x, 0.0);
    assert_eq!(shock.velocity.x, -1.6);
    assert!(!landed.landed);
    let landed = shock
        .fling_step(V::Y * 3.0, Life::Dead, 0.1, &nav, &mut rng)
        .unwrap();
    assert!(landed.position.x < 0.0);
    shock.velocity = -V::Y * 4.0;
    let before = rng;
    let landed = shock
        .fling_step(V::ZERO, Life::Dead, 0.1, &nav, &mut rng)
        .unwrap();
    assert!(landed.landed && !landed.dazed && !landed.speak && !shock.flinging);
    assert_eq!(landed.position.y, 0.0);
    assert_eq!(rng, before);
}

#[test]
fn flinch_protects_bearers_without_suppressing_the_near_miss() {
    let mut shock = InfantryShock::default();
    let mut suppression = 70.0;
    assert!(!shock
        .flinch(&mut suppression, Life::Alive, 1.0, 10.0, true)
        .unwrap());
    assert_eq!(suppression, 100.0);
    assert_eq!(shock.flinch_timer, 0.0);
    assert!(shock
        .flinch(&mut suppression, Life::Alive, 1.0, 10.0, false)
        .unwrap());
    assert_eq!(shock.flinch_timer, 0.5);
    shock.dazed_timer = 1.0;
    let before = (shock, suppression);
    assert!(!shock
        .flinch(&mut suppression, Life::Alive, 1.0, 10.0, false)
        .unwrap());
    assert_eq!((shock, suppression), before);
}

#[test]
fn shock_checkpoint_resumes_landing_stagger_and_random_draws() {
    let nav = PathPlanner::new(16).unwrap();
    let mut rng = SimulationRandom::new(73);
    let mut shock = InfantryShock::default();
    shock
        .fling(V::ZERO, V::ZERO, 7.0, Life::Alive, false, &mut rng)
        .unwrap();
    let mut restored = InfantryShock::restore(&shock.checkpoint()).unwrap();
    let mut replay_rng = rng;
    let mut pos = V::ZERO;
    for _ in 0..240 {
        let next = shock
            .fling_step(pos, Life::Alive, 1.0 / 30.0, &nav, &mut rng)
            .unwrap();
        assert_eq!(
            next,
            restored
                .fling_step(pos, Life::Alive, 1.0 / 30.0, &nav, &mut replay_rng)
                .unwrap()
        );
        assert_eq!(shock, restored);
        assert_eq!(rng, replay_rng);
        pos = next.position;
        if next.landed {
            break;
        }
    }
    assert!(!shock.flinging && shock.dazed_timer > 0.0);
    let mut state = Stagger {
        position: pos,
        yaw: 0.0,
        task_timer: 0.0,
        direction: V::ZERO,
    };
    while shock.dazed_timer > 0.0 {
        let next = shock
            .stagger(state, 1.0 / 30.0, None, &nav, &mut rng)
            .unwrap();
        assert_eq!(
            next,
            restored
                .stagger(state, 1.0 / 30.0, None, &nav, &mut replay_rng)
                .unwrap()
        );
        assert_eq!(shock.checkpoint(), restored.checkpoint());
        assert_eq!(rng, replay_rng);
        state = next;
    }
}

#[test]
fn invalid_shock_input_is_transactional_and_checkpoint_is_strict() {
    let mut shock = InfantryShock::default();
    let mut rng = SimulationRandom::new(17);
    let before = (shock, rng);
    assert!(shock
        .fling(V::NAN, V::ZERO, 8.0, Life::Alive, false, &mut rng)
        .is_err());
    assert_eq!((shock, rng), before);
    let bytes = shock.checkpoint();
    for len in 0..bytes.len() {
        assert!(InfantryShock::restore(&bytes[..len]).is_err());
    }
    let mut bad = bytes.clone();
    bad.push(0);
    assert!(InfantryShock::restore(&bad).is_err());
    let mut bad = bytes.clone();
    bad[8] = 2;
    assert!(InfantryShock::restore(&bad).is_err());
    let mut bad = bytes;
    bad[6] = 0;
    assert!(InfantryShock::restore(&bad).is_err());
}
