use frontline_core::infantry_control::{self as control, Control, Hidden, HiddenReason, Status};
use frontline_core::infantry_pose::Posture;
use frontline_core::infantry_vitals::Life;
use frontline_core::vector::Vector3;

#[test]
fn hidden_units_keep_vehicle_following_separate_from_timed_releases() {
    let mut c = Control {
        hidden: HiddenReason::Vehicle,
        hidden_timer: 0.1,
        ..Default::default()
    };
    assert_eq!(
        c.hidden_step(0.2, Some(Vector3::X)),
        Ok(Hidden::FollowVehicle(Vector3::X))
    );
    assert_eq!(c.hidden_timer, 0.1);
    assert_eq!(c.hidden_step(0.2, None), Ok(Hidden::BailOut));
    for (reason, result) in [
        (HiddenReason::Tent, Hidden::LeaveTent),
        (HiddenReason::TunnelTravel, Hidden::LeaveTunnel),
        (HiddenReason::Interrogation, Hidden::PrisonerDone),
        (HiddenReason::Held, Hidden::PrisonerDone),
    ] {
        c.hidden = reason;
        c.hidden_timer = 0.1;
        assert_eq!(c.hidden_step(0.05, None), Ok(Hidden::Wait));
        assert_eq!(c.hidden_step(0.05, None), Ok(result));
    }
    for reason in [HiddenReason::Waiting, HiddenReason::TunnelWait] {
        c.hidden = reason;
        c.hidden_timer = 0.0;
        assert_eq!(c.hidden_step(0.1, None), Ok(Hidden::Wait));
        assert_eq!(c.hidden_timer, 9999.0);
    }
}

#[test]
fn moving_posture_preserves_deliberate_ground_motion_and_boundary_rules() {
    for activity in [11, 12, 13, 14, 15, 16, 17, 34] {
        let result = Control::default()
            .motion_posture(1.0, Vector3::X * 4.0, Life::Alive, Posture::Prone, activity)
            .unwrap();
        assert_eq!(
            (result.posture, result.activity, result.corrected),
            (Posture::Prone, activity, 0)
        );
    }
    let result = Control::default()
        .motion_posture(1.0, Vector3::X, Life::Alive, Posture::Prone, 0)
        .unwrap();
    assert_eq!(
        (result.posture, result.activity, result.corrected),
        (Posture::Crouch, 1, 3)
    );
    let result = Control::default()
        .motion_posture(1.0, Vector3::X * 4.0, Life::Alive, Posture::Prone, 0)
        .unwrap();
    assert_eq!(
        (result.posture, result.activity, result.corrected),
        (Posture::Stand, 2, 3)
    );
    let mut c = Control::default();
    let result = c
        .motion_posture(0.0, Vector3::X * 4.0, Life::Alive, Posture::Prone, 0)
        .unwrap();
    assert_eq!(result.corrected, 0);
    assert_eq!(c.previous_position, Vector3::X * 4.0);
    assert_eq!(
        c.motion_posture(0.1, Vector3::X * 4.0, Life::Alive, Posture::Prone, 0)
            .unwrap()
            .corrected,
        0
    );
}

fn status() -> Status {
    Status {
        suppression: 60.0,
        ammunition: Some((100, 29)),
        time: 2.0,
        last_shot: 1.5,
        life: Life::Downed,
        leader: true,
        at_cover: true,
        cover_kind: 1,
        peeking: true,
        blind: false,
        cover_height: 1.0,
        posture: Posture::Crouch,
    }
}

#[test]
fn status_flags_preserve_ammunition_suppression_and_cover_thresholds() {
    let mut i = status();
    assert_eq!(control::flags(i), Ok(1 | 2 | 4 | 16 | 32 | 64 | 128));
    i.ammunition = Some((100, 0));
    assert_eq!(control::flags(i), Ok(1 | 2 | 8 | 16 | 32 | 64 | 128));
    i.ammunition = Some((9000, 0));
    i.suppression = 25.0;
    i.last_shot = 0.0;
    i.life = Life::Alive;
    i.leader = false;
    i.blind = true;
    assert_eq!(control::flags(i), Ok(0));
    i.ammunition = Some((100, 30));
    i.blind = false;
    i.cover_height = 0.0;
    assert_eq!(control::flags(i), Ok(0));
    i.posture = Posture::Stand;
    assert_eq!(control::flags(i), Ok(128));
}

#[test]
fn pilots_follow_the_aircraft_and_keep_mounted_turn_limits() {
    let p = Vector3::ZERO;
    assert_eq!(control::pilot_yaw(p, 0.0, 0.1, None, None), Ok(None));
    assert_eq!(
        control::pilot_yaw(p, 0.0, 0.1, Some(Vector3::X), Some((p, 0.2))),
        Ok(Some(f64::from(-0.02f32)))
    );
    assert_eq!(
        control::pilot_yaw(p, 0.0, 0.1, Some(Vector3::NEG_Z), None),
        Ok(Some(0.0))
    );
}

#[test]
fn control_checkpoint_resumes_and_invalid_updates_are_atomic() {
    let mut c = Control {
        hidden: HiddenReason::Tent,
        hidden_timer: 0.2,
        previous_position: Vector3::ONE,
    };
    let bytes = c.checkpoint();
    let mut restored = Control::restore(&bytes).unwrap();
    for _ in 0..20 {
        assert_eq!(
            c.hidden_step(0.033, None),
            restored.hidden_step(0.033, None)
        );
        assert_eq!(c.checkpoint(), restored.checkpoint());
    }
    let before = c;
    assert!(c.hidden_step(f64::NAN, None).is_err());
    assert!(c
        .motion_posture(0.1, Vector3::X, Life::Alive, Posture::Stand, 37)
        .is_err());
    assert_eq!(c, before);
    for n in 0..bytes.len() {
        assert!(Control::restore(&bytes[..n]).is_err());
    }
    let mut extra = bytes.clone();
    extra.push(0);
    assert!(Control::restore(&extra).is_err());
    for (index, value) in [(4, 2), (6, 0), (8, 7)] {
        let mut bad = bytes.clone();
        bad[index] = value;
        assert!(Control::restore(&bad).is_err());
    }
    let mut input = status();
    input.suppression = f64::NAN;
    assert!(control::flags(input).is_err());
}
