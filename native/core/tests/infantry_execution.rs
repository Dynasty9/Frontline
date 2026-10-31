use frontline_core::infantry::{Identity, Infantry};
use frontline_core::infantry_action::{Action, Related, Round, Throw};
use frontline_core::infantry_controller::{Stage, Task};
use frontline_core::infantry_pose::Posture;
use frontline_core::path_planner::PathPlanner;
use frontline_core::random::SimulationRandom;
use frontline_core::vector::Vector3;

fn soldier() -> Infantry {
    Infantry {
        identity: Identity {
            id: 1,
            unit: "rifleman".into(),
            ..Default::default()
        },
        ..Default::default()
    }
}

#[test]
fn cooking_stops_the_route_then_begins_the_queued_throw_with_one_shout_draw() {
    let mut s = soldier();
    s.posture = Posture::Prone;
    s.motion.path = vec![Vector3::X * 10.0];
    let throw = Throw {
        position: Vector3::Z * 15.0,
        round: Round::Frag,
        fuse: 1.2,
    };
    s.action.queued_throw = Some(throw);
    s.begin_action(Action::Cook, 0.05, None).unwrap();
    assert!(!s.is_moving());
    assert_eq!(s.activity, 35);
    assert_eq!(s.orders.path_revision, 1);
    let mut rng = SimulationRandom::new(137);
    let mut expected = rng;
    assert_eq!(s.alive_stage(0.1, &mut rng).unwrap(), Stage::Action);
    let out = s.action_tick(None, &mut rng).unwrap();
    assert!(out.cancel_path);
    assert_eq!(out.effect, Action::None);
    assert_eq!(out.speech, Some((expected.randi() % 3) as u8));
    assert_eq!(rng, expected);
    assert_eq!(s.orders.path_revision, 2);
    assert_eq!(s.action.current, Action::Throw(throw));
    assert_eq!(s.action.remaining, 0.6);
    assert_eq!(s.posture, Posture::Prone);
    assert_eq!(s.activity, 5);
    assert_eq!(s.vitals.speech_cooldown, 2.6);
    assert_eq!(s.alive_stage(0.7, &mut rng).unwrap(), Stage::Action);
    let out = s.action_tick(None, &mut rng).unwrap();
    assert_eq!(out.effect, Action::Throw(throw));
    assert_eq!(s.posture, Posture::Stand);
    assert_eq!(s.activity, 0);
    assert_eq!(s.action.current, Action::None);
}

#[test]
fn dazed_and_diving_stages_precede_actions_and_expired_flinches_allow_thought() {
    let nav = PathPlanner::new(32).unwrap();
    let mut s = soldier();
    let mut rng = SimulationRandom::new(137);
    s.shock.dazed_timer = 0.05;
    s.controller.dive_timer = 0.05;
    s.action.remaining = 0.05;
    s.shock.flinch_timer = 0.05;
    s.cover.at_cover = true;
    assert_eq!(s.alive_stage(0.1, &mut rng).unwrap(), Stage::Dazed);
    assert_eq!(s.action.remaining, 0.05);
    s.dazed_tick(0.1, None, &nav, &mut rng).unwrap();
    assert_eq!(s.activity, 0);
    assert!(!s.cover.at_cover);
    assert_eq!(s.cover.evaluate_at, 0.0);
    assert_eq!(s.alive_stage(0.1, &mut rng).unwrap(), Stage::Dive);
    s.dive_tick(0.1, 100.0, &nav).unwrap();
    assert_eq!(s.posture, Posture::Prone);
    assert_eq!(s.cover.evaluate_at, 100.8);
    assert_eq!(s.alive_stage(0.1, &mut rng).unwrap(), Stage::Action);
    s.action_tick(None, &mut rng).unwrap();
    assert_eq!(s.alive_stage(0.1, &mut rng).unwrap(), Stage::Think);
    assert_eq!(s.activity, 0);
    assert!((0.24..=0.34).contains(&s.controller.think_timer));
}

#[test]
fn vanished_action_targets_are_ignored_and_a_kicking_soldier_still_ducks() {
    let mut s = soldier();
    let mut rng = SimulationRandom::new(137);
    s.begin_action(Action::Launch { target: 7 }, 0.0, None)
        .unwrap();
    assert_eq!(s.action_tick(None, &mut rng).unwrap().effect, Action::None);
    assert_eq!(s.posture, Posture::Crouch);
    s.begin_action(
        Action::Kick {
            grenade: 8,
            velocity: Vector3::X * 5.0,
        },
        0.0,
        None,
    )
    .unwrap();
    let gone = Related {
        id: 8,
        position: Vector3::X,
        gone: true,
        holder: 0,
    };
    assert_eq!(
        s.action_tick(Some(gone), &mut rng).unwrap().effect,
        Action::None
    );
    assert_eq!(s.vitals.hit_dirt_timer, 1.6);
    s.begin_action(
        Action::Rethrow {
            grenade: 8,
            position: Vector3::Z * 20.0,
        },
        0.0,
        None,
    )
    .unwrap();
    let held = Related {
        gone: false,
        holder: 1,
        ..gone
    };
    let out = s.action_tick(Some(held), &mut rng).unwrap();
    assert!(matches!(out.effect, Action::Rethrow { grenade: 8, .. }));
    assert_eq!(out.speech, Some(3));
}

#[test]
fn landing_and_flinching_apply_the_actor_pose_and_keep_busy_rescuers_working() {
    let nav = PathPlanner::new(32).unwrap();
    let mut s = soldier();
    let mut rng = SimulationRandom::new(137);
    s.shock.flinging = true;
    s.shock.velocity = Vector3::new(1.0, -1.0, 0.0);
    s.motion.position.y = 0.01;
    s.duty.timer = 3.0;
    let (dazed, speech) = s.fling_tick(0.1, &nav, &mut rng).unwrap();
    assert!(dazed);
    assert_eq!(s.motion.position.y, 0.0);
    assert_eq!(s.duty.timer, 0.0);
    assert_eq!(s.posture, Posture::Stand);
    assert_eq!(s.activity, 0);
    if speech.is_some() {
        assert_eq!(s.vitals.speech_cooldown, 2.6);
    }
    s.shock.dazed_timer = 0.0;
    s.duty.kind = Task::Rescue;
    s.duty.phase = 1;
    s.flinch_from(0.2, 3.0).unwrap();
    assert_eq!(s.shock.flinch_timer, 0.0);
    assert!(s.vitals.suppression > 0.0);
    s.duty.phase = 0;
    s.flinch_from(0.2, 3.0).unwrap();
    assert_eq!(s.shock.flinch_timer, 0.5);
    assert_eq!(s.activity, 19);
}

#[test]
fn invalid_actions_and_stages_do_not_change_retained_state_or_random_draws() {
    let mut s = soldier();
    s.motion.path = vec![Vector3::X * 10.0];
    let before = s.clone();
    let mut rng = SimulationRandom::new(137);
    let random = rng;
    assert!(s.begin_action(Action::Cook, -0.1, None).is_err());
    assert!(s
        .begin_action(
            Action::Melee {
                target: u32::MAX as u64 + 1
            },
            0.5,
            None
        )
        .is_err());
    assert!(s.alive_stage(f64::NAN, &mut rng).is_err());
    assert!(s
        .action_tick(
            Some(Related {
                id: 3,
                position: Vector3::splat(f32::NAN),
                gone: false,
                holder: 0
            }),
            &mut rng
        )
        .is_err());
    assert_eq!(s, before);
    assert_eq!(rng, random);
}

#[test]
fn interruption_stages_resume_identically_from_full_actor_checkpoints() {
    let nav = PathPlanner::new(32).unwrap();
    let mut continuous = soldier();
    continuous.shock.dazed_timer = 1.5;
    continuous.controller.dive_timer = 0.3;
    continuous.shock.flinch_timer = 0.2;
    continuous.action.queued_throw = Some(Throw {
        position: Vector3::Z * 15.0,
        round: Round::Frag,
        fuse: 1.1,
    });
    continuous.begin_action(Action::Cook, 0.3, None).unwrap();
    let mut restored = continuous.clone();
    let mut randoms = [SimulationRandom::new(137); 2];
    for tick in 0..240 {
        let mut effects = Vec::new();
        for (s, rng) in [&mut continuous, &mut restored]
            .into_iter()
            .zip(randoms.iter_mut())
        {
            let stage = s.alive_stage(1.0 / 30.0, rng).unwrap();
            let effect = match stage {
                Stage::Dazed => {
                    s.dazed_tick(1.0 / 30.0, None, &nav, rng).unwrap();
                    None
                }
                Stage::Dive => {
                    s.dive_tick(1.0 / 30.0, 100.0 + tick as f64 / 30.0, &nav)
                        .unwrap();
                    None
                }
                Stage::Action => Some(s.action_tick(None, rng).unwrap()),
                _ => None,
            };
            effects.push((stage, effect));
        }
        assert_eq!(effects[0], effects[1]);
        assert_eq!(continuous, restored);
        assert_eq!(randoms[0], randoms[1]);
        restored = Infantry::restore(&restored.checkpoint().unwrap()).unwrap();
    }
}
