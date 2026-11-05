use frontline_core::infantry_action::{
    Action, ActionState, Context, Gesture, Related, Round, Throw,
};
use frontline_core::infantry_pose::Posture;
use frontline_core::vector::Vector3;

fn throw() -> Throw {
    Throw {
        position: Vector3::new(20.0, 0.0, -10.0),
        round: Round::Frag,
        fuse: 2.2,
    }
}
fn context() -> Context {
    Context {
        actor: 1,
        position: Vector3::ZERO,
        related: Some(Related {
            id: 2,
            position: Vector3::X,
            gone: false,
            holder: 1,
        }),
    }
}
fn actions() -> Vec<Action> {
    vec![
        Action::None,
        Action::Throw(throw()),
        Action::Rethrow {
            grenade: 2,
            position: Vector3::Z,
        },
        Action::ThrowIn {
            position: Vector3::Z,
            fuse: 1.0,
        },
        Action::Kick {
            grenade: 2,
            velocity: Vector3::X * 10.0,
        },
        Action::DoorKick {
            door: 2,
            position: Vector3::X,
        },
        Action::Cook,
        Action::Melee { target: 2 },
        Action::Pickup { grenade: 2 },
        Action::Launch { target: 2 },
        Action::LaunchDrone { target: 2 },
        Action::Mortar {
            position: Vector3::Z * 60.0,
            round: Round::HighExplosive,
        },
    ]
}

#[test]
fn starting_and_advancing_an_action_preserves_queued_work() {
    let mut state = ActionState {
        queued_throw: Some(throw()),
        ..Default::default()
    };
    assert_eq!(state.begin(Action::Cook, 0.6), Ok(Some(Gesture::Cook)));
    assert_eq!(state.queued_throw, Some(throw()));
    assert!(!state.advance(0.2).unwrap());
    assert!(state.advance(0.5).unwrap());
    let completed = state.finish(context()).unwrap();
    assert!(completed.begin_throw);
    assert_eq!(completed.effect, Action::Throw(throw()));
    assert_eq!(state.current, Action::None);
    assert!(state.queued_throw.is_none());
    assert!(state.remaining < 0.0);
    state.begin(completed.effect, 0.6).unwrap();
    assert_eq!(state.finish(context()).unwrap().effect, completed.effect);
}

#[test]
fn action_poses_keep_cooking_stance_and_only_launches_track_a_target() {
    let mut c = context();
    assert_eq!(Action::Cook.pose(c).unwrap().posture, None);
    assert_eq!(
        Action::LaunchDrone { target: 2 }.pose(c).unwrap().posture,
        None
    );
    assert_eq!(
        Action::Throw(throw()).pose(c).unwrap().posture,
        Some(Posture::Stand)
    );
    assert_eq!(
        Action::Launch { target: 2 }.pose(c).unwrap().posture,
        Some(Posture::Crouch)
    );
    let yaw = Action::Launch { target: 2 }.begin_yaw(c).unwrap();
    assert_eq!(Action::Launch { target: 2 }.pose(c).unwrap().yaw, yaw);
    c.related.as_mut().unwrap().gone = true;
    assert_eq!(Action::Launch { target: 2 }.begin_yaw(c).unwrap(), yaw);
    assert_eq!(Action::Launch { target: 2 }.pose(c).unwrap().yaw, None);
    assert_eq!(Action::Throw(throw()).pose(c).unwrap().yaw, None);
    c.related = None;
    assert_eq!(Action::Melee { target: 2 }.begin_yaw(c).unwrap(), None);
}

#[test]
fn grenade_completion_requires_the_current_holder_and_kicks_still_duck_on_failure() {
    let mut c = context();
    for action in [
        Action::Pickup { grenade: 2 },
        Action::Rethrow {
            grenade: 2,
            position: Vector3::Z,
        },
    ] {
        let mut state = ActionState {
            current: action,
            ..Default::default()
        };
        assert_eq!(state.finish(c).unwrap().effect, action);
        state.current = action;
        c.related.as_mut().unwrap().holder = 3;
        assert_eq!(state.finish(c).unwrap().effect, Action::None);
        c.related.as_mut().unwrap().holder = 1;
    }
    let kick = Action::Kick {
        grenade: 2,
        velocity: Vector3::X,
    };
    for (holder, distance, allowed) in [(1, 1.0, false), (0, 1.0, true), (0, 1.5, false)] {
        c.related.as_mut().unwrap().holder = holder;
        c.related.as_mut().unwrap().position = Vector3::X * distance;
        let mut state = ActionState {
            current: kick,
            ..Default::default()
        };
        let result = state.finish(c).unwrap();
        assert!(result.duck_after);
        assert_eq!(result.effect, if allowed { kick } else { Action::None });
    }
}

#[test]
fn removed_targets_cancel_launches_and_doors_without_consuming_other_queued_actions() {
    let mut c = context();
    c.related = None;
    for action in [
        Action::Launch { target: 2 },
        Action::LaunchDrone { target: 2 },
        Action::DoorKick {
            door: 2,
            position: Vector3::X,
        },
    ] {
        let mut state = ActionState {
            current: action,
            queued_throw: Some(throw()),
            ..Default::default()
        };
        assert_eq!(state.finish(c).unwrap().effect, Action::None);
        assert_eq!(state.queued_throw, Some(throw()));
    }
    let mut state = ActionState {
        current: Action::Melee { target: 2 },
        ..Default::default()
    };
    assert_eq!(state.finish(c).unwrap().effect, Action::Melee { target: 0 });
}

#[test]
fn all_action_checkpoints_resume_and_reject_malformed_input_atomically() {
    for action in actions() {
        let original = ActionState {
            current: action,
            remaining: 0.01,
            queued_throw: Some(throw()),
        };
        let bytes = original.checkpoint();
        let mut restored = ActionState::restore(&bytes).unwrap();
        let mut expected = original;
        assert_eq!(restored.advance(0.033), expected.advance(0.033));
        assert_eq!(restored.finish(context()), expected.finish(context()));
        assert_eq!(restored.checkpoint(), expected.checkpoint());
        for n in 0..bytes.len() {
            assert!(ActionState::restore(&bytes[..n]).is_err());
        }
        let mut extra = bytes.clone();
        extra.push(0);
        assert!(ActionState::restore(&extra).is_err());
        for (index, value) in [(4, 2), (6, 0), (8, 255)] {
            let mut bad = bytes.clone();
            bad[index] = value;
            assert!(ActionState::restore(&bad).is_err());
        }
        let mut state = original;
        for dt in [f64::NAN, -0.1, 10.1] {
            assert!(state.advance(dt).is_err());
            assert_eq!(state, original);
        }
        let mut bad = context();
        bad.position.x = f32::NAN;
        assert!(state.finish(bad).is_err());
        assert_eq!(state, original);
        assert!(state
            .begin(
                Action::Throw(Throw {
                    fuse: -1.0,
                    ..throw()
                }),
                1.0
            )
            .is_err());
        assert_eq!(state, original);
    }
}
