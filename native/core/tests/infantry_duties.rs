use frontline_core::infantry_duties::{
    self as duties, Build, Captor, Carry, Duty, Guard, Stretcher,
};
use frontline_core::path_planner::PathPlanner;
use frontline_core::random::SimulationRandom;
use frontline_core::vector::Vector3;

#[test]
fn construction_priority_and_sound_draws_follow_completed_work() {
    let p = Vector3::ZERO;
    assert_eq!(
        duties::build(true, 100.0, true, p, p, Some(p)),
        Ok(Build::Done)
    );
    assert_eq!(
        duties::build(false, 55.01, true, p, p, Some(p)),
        Ok(Build::Suppressed)
    );
    assert_eq!(
        duties::build(false, 55.0, true, p, p, Some(p)),
        Ok(Build::Move)
    );
    assert_eq!(
        duties::build(false, 55.0, false, p, Vector3::X * 2.0, Some(p)),
        Ok(Build::Approach)
    );
    assert_eq!(
        duties::build(false, 55.0, false, p, p, Some(Vector3::X * 17.9)),
        Ok(Build::Fight)
    );
    assert_eq!(
        duties::build(false, 55.0, false, p, p, Some(Vector3::X * 18.0)),
        Ok(Build::Work)
    );
    let mut duty = Duty {
        build_sound: 0.01,
        ..Duty::default()
    };
    let mut rng = SimulationRandom::new(137);
    let mut expected = rng;
    assert!(!duty.finish_build(0.001, &mut rng).unwrap());
    assert_eq!(rng, expected);
    assert!(duty.finish_build(0.01, &mut rng).unwrap());
    assert_eq!(duty.build_sound, f64::from(expected.randf_range(0.5, 0.9)));
    assert_eq!(rng, expected);
}

#[test]
fn stretcher_waits_for_the_pair_and_surviving_bearer_takes_over() {
    let mut duty = Duty::default();
    let mut input = Stretcher {
        valid: true,
        position: Vector3::ZERO,
        casualty: Vector3::X * 3.0,
        moving: true,
        partner_phase: Some(0),
        front: true,
        dt: 0.1,
    };
    assert_eq!(duty.stretcher(input), Ok(Carry::Move));
    input.moving = false;
    assert_eq!(duty.stretcher(input), Ok(Carry::Approach));
    input.casualty = Vector3::ZERO;
    assert_eq!(duty.stretcher(input), Ok(Carry::Ready));
    assert_eq!((duty.phase, duty.timer), (1, 1.4));
    duty.timer = -7.8;
    assert_eq!(duty.stretcher(input), Ok(Carry::Wait));
    duty.timer = -7.95;
    assert_eq!(duty.stretcher(input), Ok(Carry::Lift));
    assert_eq!(duty.phase, 2);
    assert_eq!(duty.stretcher(input), Ok(Carry::Lead));
    duty.phase = 1;
    duty.timer = 0.01;
    input.front = false;
    input.partner_phase = Some(1);
    assert_eq!(duty.stretcher(input), Ok(Carry::Wait));
    input.partner_phase = None;
    assert_eq!(duty.stretcher(input), Ok(Carry::Lift));
    duty.phase = 3;
    input.partner_phase = Some(2);
    assert_eq!(duty.stretcher(input), Ok(Carry::Follow));
    input.partner_phase = Some(3);
    assert_eq!(duty.stretcher(input), Ok(Carry::TakeOver));
    assert_eq!(duty.phase, 2);
    input.valid = false;
    let before = duty;
    assert_eq!(duty.stretcher(input), Ok(Carry::Cancel));
    assert_eq!(duty, before);
}

#[test]
fn carried_casualties_and_followers_keep_original_ground_offsets() {
    let pose = duties::carry_pose(
        Vector3::new(4.0, 2.0, 3.0),
        0.0,
        Vector3::NEG_Z,
        0.0,
        true,
        None,
    )
    .unwrap();
    assert_eq!(pose.casualty, Vector3::new(4.0, 1.45, 1.5));
    assert_eq!(pose.casualty_yaw, pose.yaw);
    let pair = duties::carry_pose(
        Vector3::new(4.0, 2.0, 3.0),
        0.0,
        Vector3::NEG_Z,
        0.0,
        false,
        None,
    )
    .unwrap();
    assert_eq!(pair.casualty, Vector3::new(4.0, 0.0, 4.15));
    let following =
        duties::follow_bearer(Vector3::new(1.0, 3.0, 1.0), Vector3::ZERO, 0.0, 0.1).unwrap();
    assert_eq!(following.y, 0.0);
    assert!(following.z > 1.0 && following.z < 2.3);
    assert_eq!(
        duties::follow_bearer(Vector3::new(1.0, 3.0, 1.0), Vector3::ZERO, 0.0, 0.0).unwrap(),
        Vector3::new(1.0, 0.0, 1.0)
    );
}

#[test]
fn captor_keeps_idle_rng_draw_and_blocked_ground_fallback() {
    let mut duty = Duty::default();
    assert_eq!(
        duty.captor(true, Vector3::ZERO, Vector3::X * 3.0, false),
        Ok(Captor::Approach { repath: true })
    );
    assert_eq!(
        duty.captor(true, Vector3::ZERO, Vector3::X * 2.5, false),
        Ok(Captor::Claim)
    );
    assert_eq!(
        duty.captor(true, Vector3::ZERO, Vector3::X * 2.5, false),
        Ok(Captor::Guard)
    );
    assert_eq!(
        duty.captor(false, Vector3::ZERO, Vector3::X, false),
        Ok(Captor::Cancel)
    );
    let mut nav = PathPlanner::new(64).unwrap();
    let mut rng = SimulationRandom::new(137);
    let mut expected = rng;
    let mut input = Guard {
        position: Vector3::ZERO,
        yaw: 0.0,
        prisoner: Vector3::X,
        dt: 0.1,
        mount: None,
    };
    let idle = duties::guard(input, &nav, &mut rng).unwrap();
    assert!(!idle.walking && idle.position == Vector3::ZERO);
    expected.randf();
    assert_eq!(rng, expected);
    input.prisoner = Vector3::X * 4.0;
    let walking = duties::guard(input, &nav, &mut rng).unwrap();
    assert!(walking.walking && walking.position.x > 0.0);
    assert_eq!(rng, expected);
    assert!(nav.load_cells(&[3; 4096], &[0; 4096], &[0; 4096]));
    let blocked = duties::guard(input, &nav, &mut rng).unwrap();
    assert_eq!(blocked.position, Vector3::X * 0.08);
    assert!(blocked.walking);
    assert_eq!(rng, expected);
}

#[test]
fn duty_checkpoints_resume_and_invalid_inputs_preserve_state_and_rng() {
    let mut duty = Duty {
        phase: 1,
        timer: -7.8,
        build_sound: 0.1,
    };
    let mut rng = SimulationRandom::new(137);
    let mut restored = Duty::restore(&duty.checkpoint()).unwrap();
    let mut resumed_rng = rng;
    let input = Stretcher {
        valid: true,
        position: Vector3::ZERO,
        casualty: Vector3::ZERO,
        moving: false,
        partner_phase: Some(0),
        front: true,
        dt: 0.1,
    };
    for _ in 0..20 {
        assert_eq!(duty.stretcher(input), restored.stretcher(input));
        assert_eq!(
            duty.finish_build(0.1, &mut rng),
            restored.finish_build(0.1, &mut resumed_rng)
        );
        assert_eq!(duty.checkpoint(), restored.checkpoint());
        assert_eq!(rng, resumed_rng);
    }
    let before = duty.checkpoint();
    let rng_before = rng;
    assert!(duty.stretcher(Stretcher { dt: -1.0, ..input }).is_err());
    assert!(duty.finish_build(f64::NAN, &mut rng).is_err());
    assert_eq!(duty.checkpoint(), before);
    assert_eq!(rng, rng_before);
    for size in 0..before.len() {
        assert!(Duty::restore(&before[..size]).is_err());
    }
    for (i, value) in [(0, b'X'), (4, 99), (6, 0), (8, 4)] {
        let mut bad = before.clone();
        bad[i] = value;
        assert!(Duty::restore(&bad).is_err());
    }
    let mut bad = before;
    bad.push(0);
    assert!(Duty::restore(&bad).is_err());
}
