//! Exact persisted bytes, shared by Windows, Linux and ARM CI, without tolerance comparisons.
use frontline_core::blast::{Blast, Infantry, Protection as BlastProtection};
use frontline_core::breach::{self, Breach, Decision, Input as BreachInput};
use frontline_core::breach_selection as buildings;
use frontline_core::bullet::{self, Body, Bullet, TargetEffect, ThroughContact};
use frontline_core::collision::{BoxShape, CollisionWorld, Mat3};
use frontline_core::cover::{generate, Part};
use frontline_core::drone::{DroneFlight, Phase};
use frontline_core::grenade_attack::{
    Contact as GrenadeContact, GrenadeAttack, Input as GrenadeInput,
};
use frontline_core::grenade_reaction as reflex;
use frontline_core::grenade_task;
use frontline_core::guided::{GuidedFlight, Kind as GuidedKind};
use frontline_core::infantry_aim::{AimInput, InfantryAim, Target, TargetKind};
use frontline_core::infantry_motion::{InfantryMotion, MoveInput};
use frontline_core::infantry_pose::{InfantryPose, Posture};
use frontline_core::infantry_shock::{InfantryShock, Stagger};
use frontline_core::infantry_vitals::{
    DamageResult, FatigueInput, InfantryVitals, Life, Protection,
};
use frontline_core::infantry_weapon::{CoverInput, InfantryWeapon, ShotInput, StanceInput, Weapon};
use frontline_core::path_planner::PathPlanner;
use frontline_core::projectile::{Flight, Holder, Kind};
use frontline_core::random::SimulationRandom;
use frontline_core::support::{Event, Kind as SupportKind, SupportFlight};
use frontline_core::terrain::{Terrain, BASE, MUD};
use frontline_core::vector::{slerp, Vector3};
use frontline_core::visibility::{Smoke, Visibility};
use frontline_core::water::{Pond, River, Water};
use std::path::PathBuf;

fn block(out: &mut Vec<u8>, bytes: &[u8]) {
    out.extend_from_slice(&(bytes.len() as u32).to_le_bytes());
    out.extend_from_slice(bytes);
}

#[test]
fn infantry_control_is_identical_across_platforms() {
    use frontline_core::infantry_control::{
        self as control, Control, Hidden, HiddenReason, Status,
    };
    let mut bytes = Vec::new();
    for trial in 0..4096 {
        let mut state = Control {
            hidden: HiddenReason::try_from((trial % 7) as u8).unwrap(),
            hidden_timer: [0.0, 0.01, 0.2, 9999.0][trial % 4],
            previous_position: Vector3::new(0.3, 0.0, -1.7),
        };
        let position =
            state.previous_position + Vector3::X * [0.0, 0.01, 0.3, 3.2, 3.21][trial % 5];
        let dt = [0.0, 1.0 / 30.0, 0.1, 1.0][trial % 4];
        let hidden = state
            .hidden_step(dt, (trial % 3 == 0).then_some(position))
            .unwrap();
        bytes.push(match hidden {
            Hidden::Wait => 0,
            Hidden::FollowVehicle(_) => 1,
            Hidden::BailOut => 2,
            Hidden::LeaveTent => 3,
            Hidden::LeaveTunnel => 4,
            Hidden::PrisonerDone => 5,
        });
        if let Hidden::FollowVehicle(p) = hidden {
            point(&mut bytes, p);
        }
        let posture = Posture::try_from((trial % 5) as u8).unwrap();
        let life = Life::try_from((trial % 6) as u8).unwrap();
        let result = state
            .motion_posture(dt, position, life, posture, (trial % 37) as u8)
            .unwrap();
        bytes.extend_from_slice(&[result.posture as u8, result.activity, result.corrected]);
        let flags = control::flags(Status {
            suppression: [0.0, 25.0, 25.01, 59.99, 60.0, 100.0][trial % 6],
            ammunition: (trial % 3 != 0)
                .then_some(([30, 100, 8999, 9000][trial % 4], (trial % 31) as i32)),
            time: 10.0,
            last_shot: [0.0, 9.4, 9.40001, 10.1][trial % 4],
            life,
            leader: trial % 2 == 0,
            at_cover: trial % 3 != 0,
            cover_kind: (trial % 4) as u8,
            peeking: trial % 2 == 0,
            blind: trial % 7 == 0,
            cover_height: [-0.1, 0.0, 0.1][trial % 3],
            posture,
        })
        .unwrap();
        bytes.push(flags);
        let yaw = control::pilot_yaw(
            position,
            trial as f64 * 0.17,
            dt,
            (trial % 7 != 0).then_some(Vector3::new(-3.7, 4.2, -9.1)),
            (trial % 3 != 0).then_some((position, 0.3490658503988659)),
        )
        .unwrap();
        bytes.push(u8::from(yaw.is_some()));
        bytes.extend_from_slice(&yaw.unwrap_or(0.0).to_le_bytes());
        block(&mut bytes, &state.checkpoint());
        assert_eq!(Control::restore(&state.checkpoint()).unwrap(), state);
    }
    golden("infantry_control", &bytes);
}

#[test]
fn infantry_action_is_identical_across_platforms() {
    use frontline_core::infantry_action::{Action, ActionState, Context, Related, Round, Throw};
    let mut bytes = Vec::new();
    for trial in 0..1024 {
        let position = Vector3::new(trial as f32 * 0.07, 0.0, -3.1);
        let target = Vector3::new(-5.7, 1.1, trial as f32 * -0.03);
        let throw = Throw {
            position: target,
            round: if trial % 2 == 0 {
                Round::Frag
            } else {
                Round::Smoke
            },
            fuse: trial as f64 * 0.00017,
        };
        let actions = [
            Action::None,
            Action::Throw(throw),
            Action::Rethrow {
                grenade: 2,
                position: target,
            },
            Action::ThrowIn {
                position: target,
                fuse: 0.3,
            },
            Action::Kick {
                grenade: 2,
                velocity: target,
            },
            Action::DoorKick {
                door: 2,
                position: target,
            },
            Action::Cook,
            Action::Melee { target: 2 },
            Action::Pickup { grenade: 2 },
            Action::Launch { target: 2 },
            Action::LaunchDrone { target: 2 },
            Action::Mortar {
                position: target,
                round: if trial % 2 == 0 {
                    Round::Smoke
                } else {
                    Round::HighExplosive
                },
            },
        ];
        for action in actions {
            let context = Context {
                actor: 1,
                position,
                related: (trial % 7 != 0).then_some(Related {
                    id: 2,
                    position: position + Vector3::new([1.0, 1.4, 1.5][trial % 3], 0.0, -0.1),
                    gone: trial % 11 == 0,
                    holder: (trial % 3) as u64,
                }),
            };
            let mut state = ActionState {
                current: action,
                remaining: trial as f64 * 0.0001,
                queued_throw: (trial % 2 == 0).then_some(throw),
            };
            for yaw in [
                action.begin_yaw(context).unwrap(),
                action.pose(context).unwrap().yaw,
            ] {
                bytes.push(u8::from(yaw.is_some()));
                bytes.extend_from_slice(&yaw.unwrap_or(0.0).to_le_bytes());
            }
            bytes.push(
                action
                    .pose(context)
                    .unwrap()
                    .posture
                    .map_or(255, |p| p as u8),
            );
            bytes.push(u8::from(state.advance(1.0 / 30.0).unwrap()));
            block(&mut bytes, &state.checkpoint());
            state = ActionState::restore(&state.checkpoint()).unwrap();
            let done = state.finish(context).unwrap();
            bytes.extend_from_slice(&[u8::from(done.begin_throw), u8::from(done.duck_after)]);
            block(
                &mut bytes,
                &ActionState {
                    current: done.effect,
                    ..Default::default()
                }
                .checkpoint(),
            );
            block(&mut bytes, &state.checkpoint());
        }
    }
    golden("infantry_action", &bytes);
}

#[test]
fn infantry_mount_is_identical_across_platforms() {
    use frontline_core::infantry_mount::{self as crew, GunPose, Mount, Station};
    let mut bytes = Vec::new();
    for trial in 0..256 {
        let mut state = Mount {
            phase: (trial % 3) as u8,
            timer: trial as f64 * 0.0031,
            scan_timer: trial as f64 * 0.0017,
            target: trial + 1,
        };
        let position = Vector3::new(trial as f32 * 0.11, 0.0, -3.7);
        let mut yaw = trial as f64 * 0.11 - 10.0;
        for tick in 0..32 {
            let dt = [1.0 / 30.0, 0.017, 0.2, 1.7][(trial as usize + tick) % 4];
            let station = state.station(dt, trial % 2 == 0, tick % 7 == 0).unwrap();
            bytes.push(match station {
                Station::Move => 0,
                Station::StartClimb => 1,
                Station::Climb { .. } => 2,
                Station::Man => 3,
                Station::Ready => 4,
            });
            if let Station::Climb { height, finished } = station {
                bytes.extend_from_slice(&height.to_le_bytes());
                bytes.push(u8::from(finished));
            }
            bytes.push(u8::from(state.scan_due(dt).unwrap()));
            let pose = GunPose {
                position,
                yaw,
                dt,
                mount: (trial % 3 != 0).then_some((position, 0.20943951023931956)),
            };
            let target = Vector3::new(-17.1, tick as f32 * 0.1, trial as f32 * 0.07);
            let aim = crew::mortar_aim(pose, target).unwrap();
            bytes.extend_from_slice(&aim.yaw.to_le_bytes());
            bytes.push(u8::from(aim.aligned));
            let (aim, dir) = crew::antitank_aim(pose, position + Vector3::X * 0.1, target).unwrap();
            bytes.extend_from_slice(&aim.yaw.to_le_bytes());
            bytes.push(u8::from(aim.aligned));
            point(&mut bytes, dir);
            yaw = aim.yaw;
            block(&mut bytes, &state.checkpoint());
            if tick == 9 {
                state = Mount::restore(&state.checkpoint()).unwrap();
            }
        }
    }
    golden("infantry_mount", &bytes);
}

#[test]
fn infantry_travel_is_identical_across_platforms() {
    use frontline_core::infantry_travel::{self as travel, AfterBoarding, Throw};
    let mut out = Vec::new();
    let distances = [0.0f32, 2.5, 3.6, 8.0, 18.0, 25.0, 30.0];
    for case in 0..4096 {
        let boundary = distances[case % distances.len()];
        let d = if boundary == 0.0 {
            0.0
        } else {
            f32::from_bits((boundary.to_bits() as i64 + (case % 3) as i64 - 1) as u32)
        };
        let position = Vector3::new((case % 47) as f32 - 23.0, 0.0, (case % 31) as f32 - 15.0);
        let target = position + Vector3::new(d, if case % 2 == 0 { 1.0 } else { 1.01 }, 0.0);
        let boat = case % 2 == 0;
        let moved = case % 3 == 0;
        out.push(
            travel::boarding(
                case % 13 != 0,
                position,
                target,
                (case % 4) as i32 - 1,
                case % 5 == 0,
                boat,
                moved,
            )
            .unwrap() as u8,
        );
        let after = travel::after_boarding_move(
            position,
            target,
            target + Vector3::Z * (case % 5) as f32,
            boat,
            moved,
        )
        .unwrap();
        out.push(match after {
            AfterBoarding::Enter => 2,
            AfterBoarding::Continue { repath } => u8::from(repath),
        });
        out.push(travel::tunnel_arrival(position, target, moved).unwrap() as u8);
        let remaining = match travel::ordered_throw(position, target, (case % 5) as i32).unwrap() {
            Throw::Move => -2,
            Throw::Cancel => -1,
            Throw::Release { remaining } => remaining,
        };
        out.extend_from_slice(&remaining.to_le_bytes());
        let supply = travel::supply_arrival(
            120,
            (case % 32) as i32,
            (case % 128) as i32,
            (case % 2 == 0).then_some((case % 80) as i32),
        )
        .unwrap();
        out.extend_from_slice(&supply.rounds.to_le_bytes());
        out.extend_from_slice(&[u8::from(supply.announce), u8::from(supply.return_to_hold)]);
    }
    golden("infantry_travel", &out);
}

#[test]
fn infantry_duties_are_identical_across_platforms() {
    use frontline_core::infantry_duties::{self as duties, Captor, Duty, Guard, Stretcher};
    let mut out = Vec::new();
    let mut nav = PathPlanner::new(64).unwrap();
    let kinds: Vec<_> = (0..4096).map(|i| if i % 13 == 0 { 3 } else { 0 }).collect();
    assert!(nav.load_cells(&kinds, &[0; 4096], &[0; 4096]));
    for case in 0..256 {
        let mut duty = Duty {
            phase: (case % 4) as u8,
            timer: f64::from(case % 17) * 0.13 - 1.0,
            build_sound: f64::from(case % 11) / 19.0,
        };
        let mut rng = SimulationRandom::new(783 + case as u64);
        let mut position = Vector3::new(
            (case % 31) as f32 - 15.0,
            (case % 5) as f32 / 3.0,
            (case % 23) as f32 - 11.0,
        );
        let mut yaw = f64::from(case) * 0.23 - 15.0;
        for tick in 0..32 {
            let dt = [0.0, 1.0 / 30.0, 0.1, 0.5][(case + tick) as usize % 4];
            let casualty = position + Vector3::new((case % 7) as f32 - 3.0, 2.0, (tick % 5) as f32);
            let target = (case % 3 != 0).then_some(casualty);
            out.push(
                duties::build(
                    case % 13 == 0,
                    f64::from((case + tick) % 101),
                    tick % 4 == 0,
                    position,
                    casualty,
                    target,
                )
                .unwrap() as u8,
            );
            out.push(u8::from(duty.finish_build(dt, &mut rng).unwrap()));
            out.push(
                duty.stretcher(Stretcher {
                    valid: case % 17 != 0,
                    position,
                    casualty,
                    moving: tick % 5 == 0,
                    partner_phase: (case % 3 != 0).then_some((tick % 4) as u8),
                    front: case % 2 == 0,
                    dt,
                })
                .unwrap() as u8,
            );
            let mount = (case % 3 == 0).then_some((position + Vector3::X * 0.3, 0.7));
            out.extend_from_slice(
                &duties::build_pose(position, yaw, casualty, dt, mount)
                    .unwrap()
                    .to_le_bytes(),
            );
            let last_direction = frontline_core::vector::normalized(Vector3::new(
                (case % 7) as f32 - 3.0,
                0.0,
                -2.0,
            ));
            let carried =
                duties::carry_pose(position, yaw, last_direction, dt, case % 2 == 0, mount)
                    .unwrap();
            out.extend_from_slice(&carried.yaw.to_le_bytes());
            point(&mut out, carried.casualty);
            out.extend_from_slice(&carried.casualty_yaw.to_le_bytes());
            point(
                &mut out,
                duties::follow_bearer(position, casualty, yaw, dt).unwrap(),
            );
            let action = duty
                .captor(case % 11 != 0, position, casualty, tick % 2 == 0)
                .unwrap();
            out.push(match action {
                Captor::Cancel => 0,
                Captor::Approach { repath: false } => 1,
                Captor::Approach { repath: true } => 2,
                Captor::Claim => 3,
                Captor::Guard => 4,
                Captor::Wait => 5,
            });
            let guard = duties::guard(
                Guard {
                    position,
                    yaw,
                    prisoner: casualty,
                    dt,
                    mount,
                },
                &nav,
                &mut rng,
            )
            .unwrap();
            position = guard.position;
            yaw = guard.yaw;
            point(&mut out, position);
            out.extend_from_slice(&yaw.to_le_bytes());
            out.push(u8::from(guard.walking));
            out.extend_from_slice(&rng.state().to_le_bytes());
            block(&mut out, &duty.checkpoint());
            if tick == 15 {
                duty = Duty::restore(&duty.checkpoint()).unwrap();
            }
        }
    }
    golden("infantry_duties", &out);
}

#[test]
fn infantry_medicine_is_identical_across_platforms() {
    use frontline_core::infantry_medicine::{
        self as medicine, EscortInput, Heal, Rescue, Treatment,
    };
    let mut bytes = Vec::new();
    let mut nav = PathPlanner::new(64).unwrap();
    let kinds: Vec<_> = (0..4096).map(|i| if i % 17 == 0 { 3 } else { 0 }).collect();
    assert!(nav.load_cells(&kinds, &[0; 4096], &[0; 4096]));
    for case in 0..=255 {
        let mut treatment = Treatment {
            phase: case % 3,
            timer: f64::from(case) / 17.0,
        };
        let duration = medicine::heal_time(0.5 + f64::from(case) / 31.0, case % 2 == 0).unwrap();
        let mut position = Vector3::new(f32::from(case % 17) * 0.13, 0.7, -0.3);
        let patient = Vector3::new(0.6, 0.0, f32::from(case % 7) * 0.21);
        let mut yaw = f64::from(case) * 0.17;
        for tick in 0..16 {
            let decision = treatment
                .rescue(
                    case % 5 != 0,
                    position,
                    patient,
                    tick % 2 == 0,
                    Vector3::ZERO,
                )
                .unwrap();
            bytes.push(match decision {
                Rescue::Cancel => 0,
                Rescue::Approach { repath: false } => 1,
                Rescue::Approach { repath: true } => 2,
                Rescue::Claim => 3,
                Rescue::Drag => 4,
                Rescue::Treat => 5,
            });
            bytes.push(u8::from(
                treatment.finish_drag(tick % 3 == 0, duration).unwrap(),
            ));
            let decision = treatment
                .heal(case % 7 != 0, position, patient, tick % 2 == 0, duration)
                .unwrap();
            bytes.push(match decision {
                Heal::Cancel => 0,
                Heal::Approach { repath: false } => 1,
                Heal::Approach { repath: true } => 2,
                Heal::Start => 3,
                Heal::Treat => 4,
            });
            bytes.push(u8::from(treatment.treat(1.0 / 30.0).unwrap()));
            let pose = medicine::escort(
                EscortInput {
                    position,
                    yaw,
                    rescuer: patient,
                    threat: Vector3::new(0.13, 0.0, -0.71),
                    dt: 1.0 / 30.0,
                    mount: (case % 3 == 0).then_some((patient, 0.3)),
                },
                &nav,
            )
            .unwrap();
            position = pose.position;
            yaw = pose.yaw;
            point(&mut bytes, position);
            bytes.extend_from_slice(&yaw.to_le_bytes());
            bytes.extend_from_slice(&[u8::from(pose.walking), u8::from(pose.backwards)]);
            let dragged = medicine::drag_pose(
                position,
                yaw,
                Vector3::new(0.27, 0.0, 0.4),
                1.0 / 30.0,
                None,
            )
            .unwrap();
            point(&mut bytes, dragged.patient);
            bytes.extend_from_slice(&dragged.yaw.to_le_bytes());
            point(
                &mut bytes,
                medicine::safe_anchor(
                    patient,
                    Vector3::Z,
                    (case % 2 == 0).then_some(Vector3::Z * 19.0),
                    &nav,
                )
                .unwrap(),
            );
            block(&mut bytes, &treatment.checkpoint());
            if tick == 7 {
                treatment = Treatment::restore(&treatment.checkpoint()).unwrap();
            }
        }
    }
    golden("infantry_medicine", &bytes);
}

#[test]
fn stationary_infantry_is_identical_across_platforms() {
    use frontline_core::infantry_motion::{separation, Neighbor, StationaryInput};
    let mut bytes = Vec::new();
    for case in 0..64 {
        let mut rng = SimulationRandom::new(case + 193);
        let mut terrain = Terrain::blank(32).unwrap();
        terrain.heights.fill(-0.03 * (case % 9) as f32);
        let mut nav = PathPlanner::new(32).unwrap();
        let kinds: Vec<_> = (0..1024)
            .map(|i| if (i + case) % 13 == 0 { 3 } else { 0 })
            .collect();
        assert!(nav.load_cells(&kinds, &[0; 1024], &[0; 1024]));
        let decks: Vec<_> = (0..1024).map(|i| u8::from((i + case) % 11 == 0)).collect();
        let mut motion = InfantryMotion {
            position: Vector3::new(0.17 * (case % 5) as f32, 0.7, -0.23),
            yaw: case as f64 * 0.3,
            ..Default::default()
        };
        for tick in 0..32 {
            let neighbor = Neighbor {
                id: 2,
                position: if tick % 7 == 0 {
                    motion.position
                } else {
                    Vector3::ZERO
                },
                life: Life::Alive,
            };
            let sep = separation(1, motion.position, case % 3 != 0, &[neighbor], &mut rng).unwrap();
            let i = StationaryInput {
                dt: 1.0 / 30.0,
                time: tick as f64 / 30.0,
                base_y: (case % 2) as f64 * 0.06,
                separation: sep,
                prone: case % 5 == 0,
                at_cover: case % 3 == 0,
                cover_position: Vector3::new(0.2, 0.0, -0.1),
                cover_normal: Vector3::new(0.3, 0.0, 0.9),
                cover_kind: (case % 4) as u8,
                last_shot: -0.5 * (case % 5) as f64,
                peek_up: case % 7 == 0,
                target_valid: case % 2 == 0,
                sector: Vector3::new(-0.7, 0.0, 0.3),
                mount: (case % 3 == 0).then_some((Vector3::ZERO, 0.3)),
            };
            bytes.push(u8::from(
                motion.stationary(i, &nav, &terrain, &decks).unwrap(),
            ));
            point(&mut bytes, sep);
            block(&mut bytes, &motion.checkpoint());
            bytes.extend_from_slice(&rng.state().to_le_bytes());
            if tick == 15 {
                motion = InfantryMotion::restore(&motion.checkpoint()).unwrap();
            }
        }
    }
    golden("infantry_stationary", &bytes);
}

#[test]
fn cover_search_is_identical_across_platforms() {
    use frontline_core::cover::{Anchor, AnchorKind};
    use frontline_core::cover_search::{self, Input, NearbyClaim, Scene, SquadClaim, Structure};
    use frontline_core::terrain::{COVER, CRATER, RUBBLE, WOODS};
    let mut bytes = Vec::new();
    let mut collision = CollisionWorld::default();
    collision.replace(
        10,
        &[BoxShape {
            body: 10,
            shape: 0,
            center: Vector3::new(0.0, 0.6, 1.0),
            basis: Mat3::IDENTITY,
            half: Vector3::new(8.0, 0.6, 0.2),
        }],
    );
    for case in 0..512 {
        let mut terrain = Terrain::blank(64).unwrap();
        let mut nav = PathPlanner::new(64).unwrap();
        let mut kinds = vec![0; 4096];
        let mut heat = vec![0; 289];
        for (i, kind) in kinds.iter_mut().enumerate() {
            if (i + case) % 37 == 0 {
                *kind = 3;
            }
            if (i + case) % 7 == 0 {
                terrain.layers[COVER][i] = 2;
                terrain.layers[[CRATER, RUBBLE, WOODS][case % 3]][i] = 1;
            }
        }
        for (i, value) in heat.iter_mut().enumerate() {
            *value = u8::from((i + case) % 17 == 0);
        }
        assert!(nav.load_cells(&kinds, &[0; 4096], &[0; 4096]));
        let structures = [Structure {
            id: 10,
            built: case % 13 != 0,
            burn: if case % 17 == 0 { 1.0 } else { 0.0 },
            material: (case % 4) as u8,
            positions: (0..(case % 64 + 1))
                .map(|i| Anchor {
                    position: Vector3::new(
                        if case % 5 == 0 {
                            0.0
                        } else {
                            (i % 21) as f32 * 0.7 - 7.0
                        },
                        0.0,
                        0.0,
                    ),
                    normal: Vector3::Z,
                    height: 1.2,
                    kind: [
                        AnchorKind::Over,
                        AnchorKind::EdgeLeft,
                        AnchorKind::EdgeRight,
                        AnchorKind::Shelter,
                        AnchorKind::Stack,
                    ][case % 5],
                })
                .collect(),
        }];
        let claims = [SquadClaim {
            id: 2,
            alive: case % 3 != 0,
            covering: case % 2 == 0,
            position: Vector3::new(case as f32 % 5.0, 0.0, 0.0),
        }];
        let nearby = [NearbyClaim {
            id: 3,
            team: (case % 2) as i32,
            alive: case % 3 != 1,
            gone: false,
            position: Vector3::new(-1.0, 0.0, 0.0),
            cover_position: Vector3::ZERO,
            cell: if case % 5 == 0 { [10, 10] } else { [-1, 0] },
        }];
        let input = Input {
            id: 1,
            team: 0,
            position: Vector3::new(0.0, 0.0, (case % 7) as f32 * 0.3),
            anchor: Vector3::ZERO,
            radius: [0.0, 3.0, 8.0, 16.0][case % 4],
            grouped: case % 3 == 0,
            prone: case % 2 == 0,
            unarmed: case % 7 == 0,
            weapon_range: if case % 3 == 0 { 8.0 } else { 50.0 },
            current_structure: 10,
            current_anchor: (case % 32) as i32,
        };
        let threats = [
            Vector3::new((case % 7) as f32 - 3.0, 1.6, 20.0),
            Vector3::new(-13.7, 1.7, -3.1),
        ];
        let result = cover_search::find(
            input,
            &threats[..case % 3],
            &mut Scene {
                terrain: &terrain,
                navigation: &nav,
                collision: &mut collision,
                heat: &heat,
                deck: &[],
                structures: &structures,
                squad_claims: &claims,
                nearby_claims: &nearby,
            },
        )
        .unwrap();
        bytes.extend_from_slice(&(result.candidates as u32).to_le_bytes());
        bytes.extend_from_slice(&(result.evaluations as u32).to_le_bytes());
        bytes.push(u8::from(result.choice.is_some()));
        if let Some(c) = result.choice {
            bytes.extend_from_slice(&c.structure.to_le_bytes());
            bytes.extend_from_slice(&c.anchor.to_le_bytes());
            bytes.extend_from_slice(&[
                c.material,
                c.evaluation.kind as u8,
                u8::from(c.evaluation.fire),
            ]);
            for v in [
                c.position,
                c.normal,
                c.evaluation.lean,
                c.evaluation.threat_direction,
            ] {
                point(&mut bytes, v);
            }
            bytes.extend_from_slice(&c.height.to_le_bytes());
            bytes.extend_from_slice(&c.evaluation.protection.to_le_bytes());
        }
    }
    golden("cover_search", &bytes);
}

#[test]
fn infantry_supply_is_identical_across_platforms() {
    use frontline_core::infantry_supply::{
        self as supply, Body, Cache, Depot, Search, SupplyTimers,
    };
    let mut bytes = Vec::new();
    for case in 0..256 {
        let mut rng = SimulationRandom::new(case + 991);
        let mut timers = SupplyTimers::default();
        let mut stock = [0; 5];
        let mut reserve = (case % 75) as i32;
        let capacity = (case % 250) as i32;
        let position = Vector3::new((case % 7) as f32 * 0.7, 0.0, (case % 9) as f32 * 0.3);
        let mut bodies: Vec<_> = (1..7)
            .map(|id| Body {
                id,
                position: Vector3::new(
                    (case % 20) as f32 * 1.2 + id as f32 * 0.13,
                    0.0,
                    (case % 7) as f32,
                ),
                dead: (case + id) % 3 != 0,
                loot: ((case + id) % 40) as i32,
            })
            .collect();
        for step in 0..8 {
            let now = step as f64 * 1.5;
            let result = timers
                .scavenge(now, reserve, Some(capacity), &bodies)
                .unwrap();
            bytes.extend_from_slice(&result.map_or(0, |t| t.body).to_le_bytes());
            bytes.extend_from_slice(&result.map_or(0, |t| t.rounds).to_le_bytes());
            if let Some(t) = result {
                bodies.iter_mut().find(|b| b.id == t.body).unwrap().loot -= t.rounds;
                reserve += t.rounds;
            }
            let found = timers.search_bodies(now, position, &bodies).unwrap();
            let code = match found {
                Search::Wait => 0,
                Search::Depots => 1,
                Search::Body(id) => id + 1,
            };
            bytes.extend_from_slice(&code.to_le_bytes());
            let fob = (case % 3 != 0).then_some(Depot {
                id: 100,
                position: Vector3::new((case % 100) as f32, 0.0, 5.3),
            });
            let caches: Vec<_> = (200..204)
                .map(|id| Cache {
                    depot: Depot {
                        id,
                        position: Vector3::new((case % 40) as f32, 0.0, (id - 200) as f32 * 4.1),
                    },
                    team: ((case + id) % 2) as i32,
                    built: (case + id) % 3 != 0,
                    gone: (case + id) % 7 == 0,
                    ammo_cache: true,
                })
                .collect();
            let destination = supply::choose_depot(position, 0, fob, &caches, &mut rng).unwrap();
            bytes.push(u8::from(destination.is_some()));
            if let Some(d) = destination {
                bytes.extend_from_slice(&d.depot.to_le_bytes());
                bytes.push(u8::from(d.cache));
                point(&mut bytes, d.position);
            }
            let dt = [0.0, 0.5, 1.0][case as usize % 3];
            let (new_reserve, refilled) = supply::refill_reserve(capacity, 0, reserve, dt).unwrap();
            reserve = new_reserve;
            bytes.push(u8::from(refilled));
            bytes.extend_from_slice(&reserve.to_le_bytes());
            rng.randi();
            supply::refill_special(&mut stock, [2, 3, 4, 5, 6], dt, &mut rng).unwrap();
            for rounds in stock {
                bytes.extend_from_slice(&rounds.to_le_bytes());
            }
            bytes.extend_from_slice(&rng.state().to_le_bytes());
            block(&mut bytes, &timers.checkpoint());
            timers = SupplyTimers::restore(&timers.checkpoint()).unwrap();
        }
    }
    golden("infantry_supply", &bytes);
}

#[test]
fn infantry_special_attacks_are_identical_across_platforms() {
    use frontline_core::infantry_arsenal::{
        InfantryArsenal, MeleeContact, MortarDecision, MortarTarget, RocketContact, RocketInput,
    };
    let mut bytes = Vec::new();
    let mut collision = CollisionWorld::default();
    collision.replace(
        100,
        &[BoxShape {
            body: 100,
            shape: 0,
            center: Vector3::new(15.0, 1.6, 0.0),
            basis: Mat3::IDENTITY,
            half: Vector3::ONE,
        }],
    );
    let mut visibility = Visibility::default();
    visibility.set_projectile(
        101,
        Smoke {
            center: Vector3::new(10.0, 1.6, 20.0),
            radius: 3.0,
        },
    );
    for case in 0..256 {
        let mut rng = SimulationRandom::new(case + 691);
        let mut state = InfantryArsenal {
            rockets: (case % 4) as i32,
            drones: (case % 3) as i32,
            mortar_rounds: (case % 5) as i32,
            rocket_ready: (case % 17) as f64,
            drone_ready: (case % 19) as f64,
            mortar_ready: (case % 7) as f64,
            melee_ready: (case % 13) as f64,
        };
        for step in 0..6 {
            let now = 10.0 + step as f64 * 5.0;
            let contacts: Vec<_> = (1..7)
                .map(|id| RocketContact {
                    id,
                    position: Vector3::new(
                        [20.0, 60.0, 69.99, 70.0, 74.99, 75.0][(case + id + step) as usize % 6],
                        0.0,
                        ((case + id) % 3) as f32 * 10.0,
                    ),
                    center: Vector3::new(50.0, 1.6, ((case + id) % 3) as f32 * 10.0),
                    gone: (case + id) % 11 == 0,
                    age: ((case + id) % 8) as f64,
                    excluded: if case % 3 == 0 { vec![100] } else { vec![] },
                })
                .collect();
            let visible = if case % 3 == 0 { &contacts[..2] } else { &[] };
            let rocket = state
                .rocket(
                    RocketInput {
                        time: now,
                        position: Vector3::ZERO,
                        eye: Vector3::new(0.0, 1.6, 0.0),
                        ambush: case % 7 == 0,
                        visible,
                        reported: &contacts[2..],
                        forced: (case % 5 == 0).then(|| contacts[0].clone()),
                    },
                    &mut collision,
                    &visibility,
                )
                .unwrap();
            bytes.extend_from_slice(&rocket.unwrap_or(0).to_le_bytes());
            let melee: Vec<_> = (1..7)
                .map(|id| MeleeContact {
                    id,
                    team: ((case + id) % 3) as i32 - 1,
                    life: if (case + id) % 4 == 0 {
                        Life::Downed
                    } else {
                        Life::Alive
                    },
                    flinging: (case + id) % 5 == 0,
                })
                .collect();
            bytes.extend_from_slice(
                &state
                    .melee(now, 0, case % 11 != 0, &melee)
                    .unwrap()
                    .unwrap_or(0)
                    .to_le_bytes(),
            );
            bytes.extend_from_slice(
                &state
                    .drone(now, case % 13 == 0, (case % 5 != 0).then_some(2), &mut rng)
                    .unwrap()
                    .unwrap_or(0)
                    .to_le_bytes(),
            );
            let p = Vector3::new(
                [24.99, 25.0, 80.0, 140.0, 140.01][case as usize % 5],
                20.0,
                0.0,
            );
            let target = if case % 2 == 0 {
                MortarTarget::Queued(p)
            } else {
                MortarTarget::Automatic((case % 3 != 0).then_some(p))
            };
            let result = state
                .mortar(now, Vector3::ZERO, case % 17 == 0, case % 19 != 0, target)
                .unwrap();
            bytes.push(match result {
                MortarDecision::Wait => 0,
                MortarDecision::CancelQueue => 1,
                MortarDecision::Fire(_) => 2,
            });
            if let MortarDecision::Fire(p) = result {
                point(&mut bytes, p);
            }
            block(&mut bytes, &state.checkpoint());
            bytes.extend_from_slice(&rng.state().to_le_bytes());
            state = InfantryArsenal::restore(&state.checkpoint()).unwrap();
        }
    }
    golden("infantry_arsenal", &bytes);
}

#[test]
fn drone_reactions_are_identical_across_platforms() {
    use frontline_core::drone_reaction::{Drone, DroneMemory};
    let mut bytes = Vec::new();
    for case in 0..256 {
        let mut rng = SimulationRandom::new(case + 337);
        let mut state = DroneMemory {
            heard: if case % 7 == 0 {
                (100..117).collect()
            } else {
                vec![]
            },
        };
        let mut drones: Vec<Drone> = (1..11)
            .map(|id| Drone {
                id,
                position: Vector3::new(
                    [0.0, 8.99, 9.0, 44.99, 45.0, 45.01][(case + id) as usize % 6],
                    ((case + id) % 3) as f32,
                    0.0,
                ),
                target: Vector3::new([0.0, 5.49, 5.5][(case + id) as usize % 3], 200.0, 0.0),
                team: ((case + id) % 2) as i32,
                dead: (case + id) % 11 == 0,
                diving: (case + id) % 3 != 0,
            })
            .collect();
        for _ in 0..5 {
            let result = state.react(Vector3::ZERO, 0, &drones, &mut rng).unwrap();
            block(&mut bytes, &state.checkpoint());
            bytes.extend_from_slice(&rng.state().to_le_bytes());
            bytes.extend_from_slice(&(result.warnings.len() as u32).to_le_bytes());
            for w in result.warnings {
                bytes.extend_from_slice(&w.drone.to_le_bytes());
                bytes.push(w.variant);
            }
            bytes.push(u8::from(result.dive_from.is_some()));
            if let Some(origin) = result.dive_from {
                point(&mut bytes, origin);
            }
            state = DroneMemory::restore(&state.checkpoint()).unwrap();
            for d in &mut drones {
                d.position.x -= 0.3;
            }
        }
    }
    golden("drone_reaction", &bytes);
}

#[test]
fn house_entry_tasks_are_identical_across_platforms() {
    let mut out = Vec::new();
    for case in 0..256 {
        let mut rng = SimulationRandom::new(209 + case);
        let mut task = Breach {
            started: 0.0,
            cook_started: -1.0,
            clear: case % 2 == 0,
            ..Default::default()
        };
        let mut time = 0.0;
        let mut distance = 6.0;
        let mut shut = case % 3 == 0;
        for tick in 0..180 {
            time += [0.1, 0.3, 0.5][case as usize % 3];
            distance = (distance - 0.3_f64).max(0.0);
            let i = BreachInput {
                time,
                moving: distance > 0.0,
                distance,
                enemy_inside: case % 7 != 0,
                door_shut: shut,
                frags: if case % 5 == 0 { 0 } else { 2 },
                team: (case % 2) as i32,
                enemy_hard_cover: case % 4 == 0,
                exploded: tick > 60,
                reordered: case % 13 == 0,
            };
            let decision = task.advance(i, &mut rng).unwrap();
            let (action, value) = match decision {
                Decision::Wait => (0, 0.0),
                Decision::Cancel => (1, 0.0),
                Decision::RetryStack => (2, 0.0),
                Decision::Stacked => (3, 0.0),
                Decision::ApproachDoor {
                    cook,
                    distance: next,
                } => {
                    distance = f64::from(next);
                    (4, cook)
                }
                Decision::KickDoor => {
                    shut = false;
                    (5, 0.0)
                }
                Decision::EnterWait => (6, 0.0),
                Decision::Throw { fuse } => (7, fuse),
                Decision::FollowSquad => (8, 0.0),
                Decision::Enter => (9, 0.0),
            };
            if tick % 7 == 0 || action != 0 {
                block(&mut out, &task.checkpoint());
                out.push(action);
                out.extend_from_slice(&value.to_le_bytes());
                out.extend_from_slice(&rng.state().to_le_bytes());
                assert_eq!(Breach::restore(&task.checkpoint()).unwrap(), task);
            }
            if matches!(
                decision,
                Decision::Cancel | Decision::Enter | Decision::FollowSquad
            ) {
                break;
            }
        }
        let yaw = case as f64 * 0.17;
        let normal = Vector3::new(libm::sin(yaw) as f32, 0.0, libm::cos(yaw) as f32);
        let center = Vector3::new(1.3, 0.0, -2.1);
        let target = Vector3::new(case as f32 * 0.1 - 12.0, 0.0, -8.0);
        point(
            &mut out,
            breach::room_target(center, normal, target).unwrap(),
        );
        point(
            &mut out,
            breach::stack_spot(target, center, normal, case % 4 != 0).unwrap(),
        );
    }
    golden("breach", &out);
}

#[test]
fn house_and_opening_choices_are_identical_across_platforms() {
    let mut out = Vec::new();
    let mut nav = PathPlanner::new(64).unwrap();
    let kinds: Vec<_> = (0..4096)
        .map(|i| if (i / 64 + i % 64) % 7 == 0 { 3 } else { 0 })
        .collect();
    nav.load_cells(&kinds, &kinds, &[0; 4096]);
    for case in 0..512 {
        let h = buildings::Building {
            id: 1,
            position: Vector3::ZERO,
            size: Vector3::new(8.0, 0.2, 6.0),
            yaw: (case % 37) as f64 * 0.17,
            kind: 0,
            gone: case % 13 == 0,
            wrecked: false,
        };
        let c = libm::cosf(h.yaw as f32);
        let s = libm::sinf(h.yaw as f32);
        let basis = Mat3::from_cols(
            Vector3::new(c, 0.0, -s),
            Vector3::Y,
            Vector3::new(s, 0.0, c),
        );
        let walls: Vec<_> = (0..3)
            .map(|side| buildings::Building {
                id: side + 3,
                position: basis * Vector3::new((side as f32 - 1.0) * 2.0, 0.0, 3.0),
                yaw: h.yaw + side as f64 * std::f64::consts::PI,
                kind: if (case + side) % 3 == 0 { 1 } else { 2 },
                gone: (case + side) % 17 == 0,
                wrecked: (case + side) % 19 == 0,
                ..h
            })
            .collect();
        let openings = buildings::openings(h, &walls).unwrap();
        out.extend_from_slice(&(openings.len() as u64).to_le_bytes());
        for o in &openings {
            out.extend_from_slice(&o.id.to_le_bytes());
            point(&mut out, o.center);
            point(&mut out, o.normal);
            out.push(o.door.into());
        }
        for offset in [
            Vector3::ZERO,
            Vector3::new(3.9, 0.0, 2.9),
            Vector3::X * 4.1,
            Vector3::Z * 3.1,
        ] {
            out.extend_from_slice(
                &buildings::house_at(basis * offset, &[h])
                    .unwrap()
                    .unwrap_or(0)
                    .to_le_bytes(),
            );
        }
        let contacts = [buildings::Contact {
            house: h,
            enemy_alive: case % 53 != 0,
            openings,
        }];
        let mate = buildings::Mate {
            position: Vector3::ZERO,
            other: true,
            alive: case % 5 != 0,
            idle: case % 7 != 0,
            frags: (case % 2) as i32,
            mounted: case % 4 == 0,
        };
        let p = Vector3::new(
            -9.0 + (case % 35) as f32,
            0.0,
            3.0 + (case / 35 % 25) as f32,
        );
        let choice = buildings::choose(
            p,
            Vector3::ZERO,
            (case % 13 == 0).then_some(1),
            &contacts,
            &[mate],
            &nav,
        )
        .unwrap();
        let indices = choice
            .map(|(a, b)| [a as i64, b as i64])
            .unwrap_or([-1, -1]);
        for v in indices {
            out.extend_from_slice(&v.to_le_bytes());
        }
        point(&mut out, nav.nearest_walkable(p).unwrap());
    }
    golden("breach_selection", &out);
}

#[test]
fn automatic_grenade_attacks_are_identical_across_platforms() {
    let mut out = Vec::new();
    for case in 0..512 {
        let mut s = GrenadeAttack {
            frags: (case % 5) as i32,
            cooldown: if case % 7 == 0 { 11.0 } else { 0.0 },
        };
        let mut rng = SimulationRandom::new(case + 2291);
        let contacts: Vec<_> = (3..8)
            .map(|id| GrenadeContact {
                id,
                position: Vector3::new(
                    7.0 + (case % 24) as f32 + (id as f32 - 3.0) * 0.6,
                    0.0,
                    (id as f32 - 5.0) * 0.5,
                ),
                alive: (case + id) % 5 != 0 && (case + id) % 19 != 0,
                age: ((case + id) % 8) as f64,
                visible: (case + id) % 3 == 0,
                posture: Posture::try_from(((case + id) % 5) as u8).unwrap(),
                hard_cover: (case + id) % 3 == 0,
                nearby_allies: ((case + id) % 5) as u32,
            })
            .collect();
        for time in [10.0, 13.0, 43.0] {
            let i = GrenadeInput {
                position: Vector3::ZERO,
                time,
                suppression: (case % 90) as f64,
                squad: case % 13 != 0,
                ambush: case % 17 == 0,
                moving: case % 11 == 0,
            };
            let t = s.advance(i, &contacts, &mut rng).unwrap();
            block(&mut out, &s.checkpoint());
            out.extend_from_slice(&rng.state().to_le_bytes());
            if let Some(t) = t {
                out.extend_from_slice(&t.target.to_le_bytes());
                point(&mut out, t.position);
                out.extend_from_slice(&t.distance.to_le_bytes());
            } else {
                out.extend_from_slice(&0_u64.to_le_bytes());
            }
            assert_eq!(GrenadeAttack::restore(&s.checkpoint()).unwrap(), s);
        }
    }
    golden("grenade_attack", &out);
}

#[test]
fn incoming_shell_notices_are_identical_across_platforms() {
    let mut out = Vec::new();
    for case in 0..128 {
        let mut memory = reflex::GrenadeMemory {
            seen: if case % 7 == 0 {
                (200..265).collect()
            } else {
                vec![]
            },
        };
        let mut shells: Vec<_> = (100..110)
            .map(|id| reflex::Shell {
                id,
                target: Vector3::new(
                    [0.0, 4.49, 4.5, 7.99, 8.0, 14.0, 14.01, 20.0][(case + id) as usize % 8],
                    (case % 3) as f32,
                    0.0,
                ),
                flight_time: [1.6, 1.61, 2.2][(case + id) as usize % 3],
                age: 0.0,
            })
            .collect();
        for _ in 0..4 {
            let notices = memory
                .incoming_shells(Vector3::ZERO, &shells, case % 2 == 0)
                .unwrap();
            block(&mut out, &memory.checkpoint());
            out.extend_from_slice(&(notices.len() as u32).to_le_bytes());
            for n in notices {
                out.extend_from_slice(&n.id.to_le_bytes());
                point(&mut out, n.target);
                out.push(n.force_warning.into());
                out.push(n.dive.into());
            }
            assert_eq!(
                reflex::GrenadeMemory::restore(&memory.checkpoint()).unwrap(),
                memory
            );
            for s in &mut shells {
                s.age += 0.3;
            }
        }
    }
    golden("incoming_shells", &out);
}

fn point(out: &mut Vec<u8>, p: Vector3) {
    for v in p.to_array() {
        out.extend_from_slice(&v.to_le_bytes());
    }
}

#[test]
fn infantry_idle_numeric_contract() {
    use frontline_core::infantry_idle::{self as idle, Calm, Idle};
    let mut bytes = Vec::new();
    for trial in 0..1024 {
        let mut rng = SimulationRandom::new(719 + trial);
        let mut a = Idle {
            calm: 11.9,
            ..Default::default()
        };
        let mut b = Idle::default();
        let now = 31.7 + trial as f64 * 0.13;
        a.tick(
            0.1,
            now,
            Calm {
                moving: false,
                danger: false,
                sector: Vector3::ZERO,
                reload: 0.0,
                last_shot: 0.0,
                mounted: false,
                target: false,
            },
            true,
        )
        .unwrap();
        bytes.push(a.begin(now, -99.0, &mut rng).unwrap() as u8);
        if trial % 3 == 0 {
            a.start_chat(
                &mut b,
                1,
                2,
                now,
                (trial % 2) as i32,
                "Alex",
                "Mikhail",
                &mut rng,
            )
            .unwrap();
        } else {
            if let Some(line) = a.solo(now, (trial % 2) as i32, &mut rng).unwrap() {
                block(&mut bytes, line.as_bytes());
            }
        }
        block(&mut bytes, &a.checkpoint());
        block(&mut bytes, &b.checkpoint());
        for step in 0..15 {
            let time = now + step as f64;
            for state in [&mut a, &mut b] {
                while let Some(line) = state.next_line(time, &mut rng).unwrap() {
                    if let Some(line) = line {
                        block(&mut bytes, line.as_bytes());
                    }
                    bytes.extend_from_slice(&rng.state().to_le_bytes());
                }
            }
        }
        let yaw = idle::chat_yaw(
            Vector3::ZERO,
            Vector3::new(1.3, 0.0, -0.7),
            trial as f64 * 0.13,
            1.0 / 30.0,
            None,
        )
        .unwrap();
        bytes.extend_from_slice(&yaw.to_le_bytes());
        a.end(now + 30.0, &mut rng).unwrap();
        block(&mut bytes, &a.checkpoint());
        block(&mut bytes, &b.checkpoint());
        bytes.extend_from_slice(&rng.state().to_le_bytes());
    }
    golden("infantry_idle", &bytes);
}

#[test]
fn infantry_controller_numeric_contract() {
    use frontline_core::infantry_action::ActionState;
    use frontline_core::infantry_controller::{Controller, Stage};
    use frontline_core::infantry_shock::InfantryShock;
    let mut nav = PathPlanner::new(16).unwrap();
    let cells: Vec<u8> = (0..256).map(|i| if i % 5 == 0 { 3 } else { 0 }).collect();
    nav.load_cells(&cells, &cells, &vec![0; 256]);
    let mut bytes = Vec::new();
    for trial in 0..1024 {
        let mut c = Controller {
            think_timer: (trial % 7) as f64 * 0.03,
            scan_number: trial,
            activity_timer: (trial % 3) as f64 * 0.1,
            dive_timer: if trial % 5 == 0 { 0.2 } else { 0.0 },
            dive_direction: Vector3::new(0.3, 0.1, -0.7),
        };
        let mut shock = InfantryShock {
            dazed_timer: if trial % 7 == 0 { 0.2 } else { 0.0 },
            flinch_timer: (trial % 4) as f64 * 0.03,
            ..Default::default()
        };
        let mut action = ActionState {
            remaining: if trial % 3 == 0 { 0.1 } else { 0.0 },
            ..Default::default()
        };
        let mut rng = SimulationRandom::new(313 + trial);
        let mut position = Vector3::new(1.3, 0.7, -0.1);
        let dt = [1.0 / 30.0, 0.1, 0.3, 1.0][trial as usize % 4];
        for _ in 0..4 {
            bytes.push(c.activity_due(dt).unwrap() as u8);
            let out = c.advance(dt, &mut shock, &mut action, &mut rng).unwrap();
            bytes.extend_from_slice(&[out.stage as u8, out.flinch_ended as u8]);
            match out.stage {
                Stage::Dazed => shock.dazed_timer -= dt,
                Stage::Dive => position = c.dive(position, 0.0, dt, &nav).unwrap().position,
                Stage::Think => {
                    bytes.push(c.scan_due(trial % 3 != 0).unwrap() as u8);
                }
                _ => {}
            }
            block(&mut bytes, &c.checkpoint());
            block(&mut bytes, &shock.checkpoint());
            block(&mut bytes, &action.checkpoint());
            point(&mut bytes, position);
            bytes.extend_from_slice(&rng.state().to_le_bytes());
        }
    }
    golden("infantry_controller", &bytes);
}

fn golden(name: &str, actual: &[u8]) {
    let path = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("tests/numeric_v1")
        .join(format!("{name}.bin"));
    if std::env::var_os("FL_WRITE_NUMERIC_GOLDENS").is_some() {
        assert!(
            std::env::var_os("CI").is_none(),
            "CI must never rewrite goldens"
        );
        std::fs::create_dir_all(path.parent().unwrap()).unwrap();
        std::fs::write(&path, actual).unwrap();
    }
    let expected = std::fs::read(path).expect("Missing committed numeric fixture");
    assert_eq!(actual.len(), expected.len(), "{name}: byte count changed");
    if let Some((i, (a, b))) = actual
        .iter()
        .zip(&expected)
        .enumerate()
        .find(|(_, (a, b))| a != b)
    {
        panic!("{name}: first differing byte {i}: actual {a:02x}, expected {b:02x}");
    }
}

#[test]
fn grenade_task_motion_is_identical_across_platforms() {
    let mut bytes = Vec::new();
    let mut nav = PathPlanner::new(64).unwrap();
    let kinds: Vec<u8> = (0..4096).map(|i| if i % 7 == 0 { 3 } else { 0 }).collect();
    nav.load_cells(&kinds, &[0; 4096], &[0; 4096]);
    for case in 0..128 {
        let mut rng = SimulationRandom::new(case + 913);
        let mut input = grenade_task::Input {
            task: [
                grenade_task::Task::Smother,
                grenade_task::Task::Kick,
                grenade_task::Task::Pickup,
            ][case as usize % 3],
            position: Vector3::new((case % 7) as f32 - 3.0, 0.0, ((case / 7) % 7) as f32 - 3.0),
            yaw: (case % 20) as f64 * 0.13,
            time: 0.0,
            started: 0.0,
            dt: [1.0 / 30.0, 0.02, 0.08][case as usize % 3],
            grenade: None,
            mount: (case % 11 == 0).then_some((Vector3::ZERO, 0.61)),
        };
        input.grenade = Some(grenade_task::Grenade {
            position: input.position + Vector3::new(0.4 + (case % 8) as f32 * 0.7, 0.1, 0.2),
            fuse: [0.3, 0.5, 0.8, 2.0, 4.0][case as usize % 5],
            gone: false,
            held: case % 17 == 0 || case % 19 == 0,
            held_by_self: case % 17 == 0,
        });
        for tick in 0..120 {
            input.time += input.dt;
            let g = input.grenade.as_mut().unwrap();
            g.fuse -= input.dt;
            g.gone = g.fuse <= 0.0;
            let result = grenade_task::advance(input, &nav).unwrap();
            input.position = result.position;
            input.yaw = result.yaw;
            let terminal = matches!(
                result.action,
                grenade_task::Action::Cancel
                    | grenade_task::Action::DiveAway
                    | grenade_task::Action::Kick
                    | grenade_task::Action::Pickup
            );
            if tick % 7 == 0 || terminal {
                point(&mut bytes, result.position);
                bytes.extend_from_slice(&result.yaw.to_le_bytes());
                bytes.push(result.action as u8);
                bytes.push(u8::from(
                    grenade_task::covers_grenade(
                        result.position,
                        result.yaw,
                        input.grenade.unwrap().position,
                    )
                    .unwrap(),
                ));
            }
            if result.action == grenade_task::Action::DiveAway {
                point(
                    &mut bytes,
                    grenade_task::dive_direction(
                        result.position,
                        input.grenade.unwrap().position,
                        &mut rng,
                    )
                    .unwrap(),
                );
            }
            if terminal {
                break;
            }
        }
        point(
            &mut bytes,
            grenade_task::dive_direction(input.position, input.position, &mut rng).unwrap(),
        );
        bytes.extend_from_slice(&rng.state().to_le_bytes());
    }
    golden("grenade_tasks", &bytes);
}

#[test]
fn grenade_reflex_transcripts_are_identical_across_platforms() {
    let mut bytes = Vec::new();
    for case in 0..512 {
        let mut rng = SimulationRandom::new(case + 317);
        let mut memory = reflex::GrenadeMemory::default();
        if case % 31 == 0 {
            memory.seen = (100..125).collect();
        }
        let actor = reflex::Soldier {
            id: 1,
            position: Vector3::ZERO,
            center: Vector3::Y,
            yaw: case as f64 * 0.13,
            team: (case % 2) as i32,
            suppression: (case % 90) as f64,
            posture: Posture::try_from((case % 5) as u8).unwrap(),
            squad: case % 11 != 0,
            mounted: case % 17 == 0,
            riding: case % 23 == 0,
            armed: case % 7 != 0,
        };
        let grenade = reflex::Grenade {
            id: 2,
            position: Vector3::new((case % 9) as f32 * 0.7, (case % 3) as f32 * 0.2, 0.0),
            fuse: 0.4 + (case % 12) as f64 * 0.25,
            held: case % 31 == 0,
            gone: case % 29 == 0,
            flying: case % 3 == 0,
            free: case % 37 != 0,
            smothered: case % 41 == 0,
            thrown_back: u32::from(case % 11 == 0),
        };
        let rounds = [
            grenade,
            reflex::Grenade {
                id: 3,
                position: Vector3::new(5.5, 0.4, 0.0),
                ..grenade
            },
        ];
        let mates: Vec<_> = (4..8)
            .map(|id| reflex::Mate {
                id,
                position: Vector3::new(2.0, 0.0, (id - 4) as f32 * 0.2),
                center: Vector3::new(2.0, 0.3, (id - 4) as f32 * 0.2),
                team: 0,
                life: if (case + id) % 3 == 0 {
                    Life::Downed
                } else {
                    Life::Alive
                },
                helpless: case % 3 == 0,
            })
            .collect();
        let mut collision = CollisionWorld::default();
        if case % 3 == 0 {
            collision.replace(
                10,
                &[BoxShape {
                    body: 10,
                    shape: 0,
                    center: Vector3::new(1.0, 1.0, 0.0),
                    basis: Mat3::IDENTITY,
                    half: Vector3::new(0.1, 1.0, 2.0),
                }],
            );
        }
        for _ in 0..3 {
            if let Some(id) = memory.notice(actor.position, &rounds, true).unwrap() {
                rng.randi();
                let g = *rounds.iter().find(|g| g.id == id).unwrap();
                let result = reflex::react(actor, g, &mates, &mut collision, &mut rng).unwrap();
                let (kind, body): (u8, i64) = match result {
                    reflex::Reaction::Smother => (0, 0),
                    reflex::Reaction::ThrowBack => (1, 0),
                    reflex::Reaction::Kick => (2, 0),
                    reflex::Reaction::Shelter(id) => (3, id),
                    reflex::Reaction::Dive => (4, 0),
                };
                bytes.push(kind);
                bytes.extend_from_slice(&body.to_le_bytes());
            }
            block(&mut bytes, &memory.checkpoint());
        }
        let velocity = reflex::kick_velocity(
            actor,
            grenade,
            &mates,
            (case % 2 == 0).then_some(Vector3::new(11.3, 0.0, -4.7)),
        )
        .unwrap();
        point(&mut bytes, velocity);
        let cooking =
            reflex::cook_time(actor.team, (case % 31) as f64, case % 2 == 0, &mut rng).unwrap();
        bytes.extend_from_slice(&cooking.to_le_bytes());
        bytes.extend_from_slice(&rng.state().to_le_bytes());
    }
    golden("grenade_reflex", &bytes);
}

#[test]
fn wounded_infantry_transcripts_are_identical_across_platforms() {
    let mut bytes = Vec::new();
    for seed in 0..32 {
        let mut rng = SimulationRandom::new(seed + 831);
        let mut state = InfantryVitals {
            life: Life::Downed,
            bleed: [0.05, 50.0, 10.0, 3.0][seed as usize % 4],
            bleed_max: 50.0,
            ..Default::default()
        };
        let mut height = 2.0f32;
        let mut crawling = false;
        for tick in 0..480 {
            let time = tick as f64 / 30.0;
            let carried = seed % 3 == 1 && tick < 90;
            let dragged = seed % 3 == 0 && tick < 120;
            if state.life == Life::Downed {
                if state
                    .bleed_step(1.0 / 30.0, carried || dragged, seed % 2 == 0)
                    .unwrap()
                {
                    state.die(time).unwrap();
                } else {
                    if state.scream_step(1.0 / 30.0, &mut rng).unwrap() {
                        rng.randi();
                    }
                    if !carried {
                        if state.pistol_step(1.0 / 30.0, &mut rng).unwrap() {
                            rng.randf();
                        }
                        if !dragged && !crawling {
                            crawling = state.crawl_step(1.0 / 30.0).unwrap();
                        }
                    }
                }
            } else {
                let result = state
                    .corpse_step(
                        height,
                        -0.65,
                        time + 300.0,
                        carried,
                        tick < 80,
                        seed % 13 == 0,
                    )
                    .unwrap();
                height = result.height;
                bytes.extend_from_slice(&[
                    u8::from(result.carried),
                    u8::from(result.clear_carriers),
                    u8::from(result.despawn),
                ]);
            }
            if tick == 200 {
                state = InfantryVitals::restore(&state.checkpoint()).unwrap();
            }
            if tick % 40 == 0 {
                block(&mut bytes, &state.checkpoint());
                bytes.extend_from_slice(&height.to_le_bytes());
                bytes.extend_from_slice(&rng.state().to_le_bytes());
                bytes.push(u8::from(crawling));
            }
        }
    }
    golden("wounded", &bytes);
}

#[test]
fn infantry_shock_transcripts_are_identical_across_platforms() {
    let mut bytes = Vec::new();
    let mut nav = PathPlanner::new(32).unwrap();
    let kinds: Vec<u8> = (0..1024).map(|i| if i % 7 == 0 { 3 } else { 0 }).collect();
    assert!(nav.load_cells(&kinds, &[0; 1024], &[0; 1024]));
    for seed in 0..64 {
        let mut rng = SimulationRandom::new(seed + 731);
        let mut shock = InfantryShock::default();
        let life = Life::try_from((seed % 6) as u8).unwrap();
        let mut state = Stagger {
            position: Vector3::new(1.13, 0.0, -2.73),
            yaw: 0.71,
            task_timer: 0.0,
            direction: Vector3::ZERO,
        };
        let mut suppression = seed as f64;
        let center = if seed % 2 == 0 {
            state.position
        } else {
            Vector3::new(-0.13, 0.0, -1.11)
        };
        shock
            .fling(
                state.position,
                center,
                1.0 + (seed % 20) as f64,
                life,
                seed % 17 == 0,
                &mut rng,
            )
            .unwrap();
        for tick in 0..240 {
            if tick % 11 == 0 {
                shock
                    .flinch(
                        &mut suppression,
                        life,
                        (seed % 9) as f64,
                        10.0,
                        seed % 7 == 0,
                    )
                    .unwrap();
            }
            if shock.flinging {
                let result = shock
                    .fling_step(state.position, life, 1.0 / 30.0, &nav, &mut rng)
                    .unwrap();
                state.position = result.position;
                if result.dazed {
                    state.task_timer = 0.0;
                }
                if result.speak {
                    rng.randi();
                }
            } else if shock.dazed_timer > 0.0 {
                let mount = (seed % 2 == 0).then_some((Vector3::ZERO, 0.61));
                state = shock
                    .stagger(state, 1.0 / 30.0, mount, &nav, &mut rng)
                    .unwrap();
            }
            if tick == 100 {
                shock = InfantryShock::restore(&shock.checkpoint()).unwrap();
            }
            if tick % 20 == 0 {
                block(&mut bytes, &shock.checkpoint());
                point(&mut bytes, state.position);
                point(&mut bytes, state.direction);
                for v in [state.yaw, state.task_timer, suppression] {
                    bytes.extend_from_slice(&v.to_le_bytes());
                }
                bytes.extend_from_slice(&rng.state().to_le_bytes());
            }
        }
    }
    golden("shock", &bytes);
}

#[test]
fn blast_exposure_transcripts_are_identical_across_platforms() {
    let mut bytes = Vec::new();
    for case in 0..512 {
        let blast = Blast {
            position: Vector3::new(13.35, 0.1, -24.04),
            damage: 20.0 + f64::from(case % 150),
            radius: if case % 31 == 0 {
                0.0
            } else {
                0.25 + f64::from(case % 12) * 0.8
            },
            fling: if case % 4 == 0 { 0.0 } else { 7.0 },
            in_trench: case % 3 == 0,
        };
        let center = blast.position
            + Vector3::new((case % 9) as f32 * 0.6, 0.73, (case % 7) as f32 * 0.4 - 2.0);
        let result = blast
            .infantry(
                Infantry {
                    center,
                    life: Life::try_from((case % 6) as u8).unwrap(),
                    posture: Posture::try_from((case % 5) as u8).unwrap(),
                    in_trench: case % 2 == 0,
                    terrain_multiplier: 0.45 + f64::from((case / 7) % 3) * 0.2,
                },
                BlastProtection {
                    blocked: case % 2 == 0,
                    material: (case % 3 != 0).then_some(((case / 7) % 4) as u8),
                },
            )
            .unwrap();
        for value in [
            result.damage,
            result.fling,
            result.distance,
            result.flinch_radius,
            result.before_posture,
        ] {
            bytes.extend_from_slice(&value.to_le_bytes());
        }
        point(&mut bytes, result.direction);
        bytes.extend_from_slice(&[u8::from(result.sheltered), u8::from(result.blocked)]);
        let damage = blast
            .structure(
                center,
                0.5 + f64::from(case % 4) * 0.5,
                case % 7 == 0,
                1.0 + f64::from(case % 3) * 0.25,
            )
            .unwrap();
        bytes.push(u8::from(damage.is_some()));
        if let Some(damage) = damage {
            bytes.extend_from_slice(&damage.to_le_bytes());
        }
    }
    golden("blast", &bytes);
}

#[test]
fn bullet_resolution_transcripts_are_identical_across_platforms() {
    let mut bytes = Vec::new();
    for case in 0..512 {
        let mut rng = SimulationRandom::new(case);
        let mut collision = CollisionWorld::default();
        let mut sight = Visibility::default();
        if case % 3 != 0 {
            assert!(collision.replace(
                1,
                &[BoxShape {
                    body: 1,
                    shape: 0,
                    center: Vector3::new(8.0, 1.0, 4.0),
                    basis: Mat3::IDENTITY,
                    half: Vector3::new(1.12, 4.0, 12.0)
                }]
            ));
        }
        if case % 11 == 0 {
            assert!(sight.set_projectile(
                4,
                Smoke {
                    center: Vector3::new(4.0, 1.0, 2.0),
                    radius: 3.5
                }
            ));
        }
        let target = (case % 5 != 0).then_some(bullet::Target {
            kind: match case % 4 {
                0 => bullet::TargetKind::Infantry,
                1 => bullet::TargetKind::Drone,
                2 => bullet::TargetKind::AirVehicle,
                _ => bullet::TargetKind::Other,
            },
            hit_factor: 0.75,
            terrain_multiplier: 0.7,
            trench_protected: case % 3 == 0,
        });
        let mut shot = Bullet::fire(
            bullet::ShotInput {
                muzzle: Vector3::new(-2.1, 1.6, 0.35),
                aim: Vector3::new(22.4, if case % 7 == 0 { -0.4 } else { 0.85 }, 12.39),
                target,
                weapon: bullet::Weapon {
                    accuracy: 0.95,
                    range: 80.0,
                    damage: 36.0,
                    anti_air: case % 7 == 0,
                    penetration: (case % 4) as u8,
                    drone_accuracy: [0.03, 0.045, 0.08][(case % 3) as usize],
                    explosive_radius: (case % 2 == 0).then_some(2.4),
                    airburst: case % 4 == 0,
                },
                accuracy_multiplier: 1.15,
                soldier_suppression: (case % 2 == 0).then_some((case % 100) as f64),
                optics: case % 3 == 0,
                excluded: if case % 13 == 0 { &[1] } else { &[] },
            },
            &mut collision,
            &sight,
            &mut rng,
        )
        .unwrap();
        point(&mut bytes, shot.direction);
        let effects = shot
            .resolve_obstacle(
                if case % 7 == 0 {
                    Body::Vehicle
                } else {
                    Body::Structure {
                        material: ((case / 4) % 4) as u8,
                    }
                },
                &mut rng,
            )
            .unwrap();
        bytes.extend_from_slice(&[
            u8::from(effects.penetrated),
            u8::from(effects.structure_surface),
            u8::from(effects.vehicle_hit),
        ]);
        bytes.extend_from_slice(&effects.penetration_damage.to_le_bytes());
        if effects.penetrated {
            rng.randi();
        }
        if let Some(end) = effects.through_end {
            let from = shot.ray.unwrap().position;
            let contacts = [ThroughContact {
                id: 2,
                team: 1,
                alive: true,
                center: from + frontline_core::vector::normalized(end - from),
            }];
            let hit = bullet::through_hit(
                from,
                end,
                &contacts,
                0,
                shot.damage(),
                shot.penetration_multiplier(),
                &mut rng,
            )
            .unwrap();
            bytes.push(u8::from(hit.is_some()));
            if let Some(hit) = hit {
                bytes.extend_from_slice(&hit.damage.to_le_bytes());
                point(&mut bytes, hit.direction);
                rng.randi();
            }
        }
        if effects.structure_surface || effects.vehicle_hit {
            rng.randi();
            shot.set_surface(if effects.vehicle_hit { 3 } else { 5 })
                .unwrap();
        }
        match shot.finish_target(&mut rng).unwrap() {
            TargetEffect::None => bytes.push(0),
            TargetEffect::Damage(damage) => {
                bytes.push(1);
                bytes.extend_from_slice(&damage.to_le_bytes());
                rng.randi();
            }
            TargetEffect::DownDrone => {
                bytes.push(2);
                rng.randi();
            }
        }
        let location = target.map(|_| bullet::TargetLocation {
            position: Vector3::new(22.4, 0.0, 12.39),
            center: Vector3::new(22.4, 0.2, 12.39),
            in_trench: case % 3 == 0,
        });
        let explosion = shot.explosion(location, &mut rng).unwrap();
        bytes.push(u8::from(explosion.is_some()));
        if let Some(e) = explosion {
            point(&mut bytes, e.position);
            bytes.extend_from_slice(&e.damage.to_le_bytes());
            bytes.extend_from_slice(&e.radius.to_le_bytes());
        }
        bytes.extend_from_slice(&[u8::from(shot.hit), shot.impact]);
        point(&mut bytes, shot.end);
        for amount in bullet::suppression(
            shot.muzzle(),
            shot.end,
            &[Vector3::new(1.3, 0.0, 1.4), Vector3::new(10.5, 0.0, 7.8)],
            18.0,
        )
        .unwrap()
        {
            bytes.extend_from_slice(&amount.to_le_bytes());
        }
        bytes.extend_from_slice(&rng.state().to_le_bytes());
    }
    golden("bullet", &bytes);
}

#[test]
fn infantry_pose_geometry_is_identical_across_platforms() {
    let mut bytes = Vec::new();
    for case in 0..360 {
        let p = InfantryPose {
            position: Vector3::new(30.17, -1.12, -44.32),
            posture: Posture::try_from((case % 5) as u8).unwrap(),
            life: Life::try_from((case % 6) as u8).unwrap(),
            at_cover: case % 3 != 0,
            cover_kind: (case % 4) as u8,
            cover_height: [0.0, 0.619999, 0.62, 0.8, 1.119999, 1.12][(case / 7) % 6],
            cover_normal: Vector3::new(0.3, 0.0, -0.7),
            lean_direction: Vector3::new(-0.7, 0.0, -0.3),
            mounted: case % 7 == 0,
            gun_mount: case % 14 == 0,
            tower_mount: case % 28 == 0,
            peek_up: case % 2 == 0,
            blind: case % 11 == 0,
            moving: case % 13 != 0,
            move_mode: (case % 3) as i32,
            ground: if case % 2 == 0 { -1.0 } else { 0.0 },
        };
        assert!(p.valid());
        point(&mut bytes, p.eye());
        point(&mut bytes, p.scan_eye());
        point(&mut bytes, p.center());
        let exposed = p.exposed_points();
        bytes.push(exposed.as_slice().len() as u8);
        for p in exposed.as_slice() {
            point(&mut bytes, *p);
        }
        bytes.extend_from_slice(&p.hit_factor().to_le_bytes());
        bytes.push(p.cover_posture(false) as u8);
        bytes.push(p.cover_posture(true) as u8);
    }
    golden("infantry_pose", &bytes);
}

#[test]
fn infantry_aim_transcripts_are_identical_across_platforms() {
    let mut bytes = Vec::new();
    for seed in 0..12 {
        let mut rng = SimulationRandom::new(seed);
        let mut aim = InfantryAim::default();
        let mut collision = CollisionWorld::default();
        let mut sight = Visibility::default();
        for tick in 0..48 {
            let position = Vector3::new(31.17, 0.0, (tick % 3) as f32 * 1.1);
            let points = [position + Vector3::Y * 1.16, position + Vector3::Y * 1.68];
            let kind = match seed % 4 {
                0 => TargetKind::Infantry {
                    over_cover: true,
                    cover_height: 0.73,
                },
                1 => TargetKind::Drone,
                2 => TargetKind::Structure,
                _ => TargetKind::Other,
            };
            assert!(collision.replace(
                8,
                &[BoxShape {
                    body: 8,
                    shape: 0,
                    center: Vector3::new(15.0, 1.0, if tick % 16 < 8 { 0.0 } else { 40.0 }),
                    basis: Mat3::IDENTITY,
                    half: Vector3::new(1.0, 3.0, 4.0)
                }]
            ));
            assert!(sight.set_projectile(
                9,
                Smoke {
                    center: Vector3::new(5.0, 1.0, 0.0),
                    radius: if tick % 7 == 0 { 4.0 } else { 0.0 }
                }
            ));
            let result = aim
                .choose(
                    AimInput {
                        time: f64::from(tick) * 0.1,
                        position: Vector3::ZERO,
                        eye: Vector3::Y * 1.45,
                        target: (tick % 3 != 0).then_some(Target {
                            id: 5,
                            kind,
                            position,
                            center: position + Vector3::Y * 0.72,
                            points: &points,
                            excluded: &[],
                        }),
                        blind: tick % 5 == 0,
                        cache_obstruction: true,
                        cover_fire: (tick % 2 == 0).then_some(Vector3::new(20.0, 0.0, -5.0)),
                        last_known: Some(Vector3::new(15.0, 0.0, 9.0)),
                        weapon_range: 50.0,
                    },
                    &mut collision,
                    &mut sight,
                    &mut rng,
                )
                .unwrap();
            bytes.push(u8::from(result.point.is_some()));
            if let Some(p) = result.point {
                point(&mut bytes, p);
            }
            bytes.extend_from_slice(&result.target.to_le_bytes());
            bytes.extend_from_slice(&rng.state().to_le_bytes());
            if tick % 8 == 0 {
                block(&mut bytes, &aim.checkpoint());
                aim = InfantryAim::restore(&aim.checkpoint()).unwrap();
            }
        }
    }
    golden("infantry_aim", &bytes);
}

#[test]
fn infantry_vitals_transcripts_are_identical_across_platforms() {
    let mut bytes = Vec::new();
    for seed in 0..24 {
        let mut rng = SimulationRandom::new(seed);
        let mut state = InfantryVitals {
            life: Life::try_from((seed % 6) as u8).unwrap(),
            bleed: 45.0,
            times_downed: (seed % 4) as u32,
            hit_dirt_timer: 0.3,
            ..Default::default()
        };
        let cover = Protection {
            at_cover: seed % 3 != 0,
            cover_kind: 1,
            material: Some((seed % 4) as u8),
            in_trench: seed % 5 == 0,
            peek_up: seed % 2 == 0,
            protected_mount: seed % 7 == 0,
        };
        for tick in 0..120 {
            let time = 10.0 + f64::from(tick) * 0.1;
            state.recover(0.1, time, cover).unwrap();
            state
                .fatigue(
                    0.1,
                    FatigueInput {
                        moving_or_diving: tick % 3 != 0,
                        move_mode: tick % 3,
                        crawling: seed % 3 == 0,
                        heavy_task: seed % 4 == 0,
                        carrying: false,
                        standing: tick % 2 == 0,
                    },
                )
                .unwrap();
            if tick % 7 == 0 {
                let result = state
                    .suppress(48.0, time, seed % 2 == 0, true, cover, &mut rng)
                    .unwrap();
                bytes.extend_from_slice(&[
                    u8::from(result.report_position),
                    result.speech.unwrap_or(255),
                ]);
            }
            if tick % 19 == 0 {
                let outcome = state
                    .damage(
                        f64::from(tick % 50) + 7.0,
                        seed % 3 == 0,
                        seed % 7 == 0,
                        &mut rng,
                    )
                    .unwrap();
                let event = match outcome {
                    DamageResult::Ignored => 0,
                    DamageResult::Survived(s) => s.map_or(1, |s| 4 + s),
                    DamageResult::Down => 2,
                    DamageResult::Die => 3,
                };
                bytes.push(event);
                match outcome {
                    DamageResult::Down => state.go_down(time).unwrap(),
                    DamageResult::Die => state.die(time).unwrap(),
                    _ => {}
                }
            }
            if tick % 37 == 0 && state.life == Life::Downed {
                state.revive(seed % 2 == 0).unwrap();
            }
            if tick % 10 == 0 {
                let saved = state.checkpoint();
                assert_eq!(state, InfantryVitals::restore(&saved).unwrap());
                block(&mut bytes, &saved);
                bytes.extend_from_slice(&rng.state().to_le_bytes());
            }
        }
    }
    golden("infantry_vitals", &bytes);
}

#[test]
fn infantry_weapon_transcripts_are_identical_across_platforms() {
    let mut bytes = Vec::new();
    let weapon = Weapon {
        ammunition: 210,
        magazine: 30,
        reload_time: 2.4,
    };
    for seed in 0..16 {
        let mut state = InfantryWeapon {
            magazine: 6,
            reserve: 60,
            ..Default::default()
        };
        let mut rng = SimulationRandom::new(seed);
        for tick in 0..240 {
            let time = 10.0 + f64::from(tick) / 30.0;
            let suppression = [0.0, 40.0, 75.0, 95.0][(tick as usize / 60) % 4];
            state.advance_timers(1.0 / 30.0, weapon).unwrap();
            let events = state
                .cover_cycle(
                    CoverInput {
                        dt: 1.0 / 30.0,
                        time,
                        team: (seed % 2) as i32,
                        suppression,
                        last_suppression: time - 0.1,
                        hit_dirt_timer: 0.0,
                        ground: -0.7,
                        cover_kind: 1,
                        cover_height: 0.9,
                        cover_material: 2,
                        want_fire: true,
                        pinned: suppression >= 60.0,
                        target_valid: true,
                        buddy_up: seed % 3 == 0,
                        weapon: Some(weapon),
                    },
                    &mut rng,
                )
                .unwrap();
            bytes.extend_from_slice(&[
                u8::from(events.drew_fire),
                u8::from(events.peeked),
                u8::from(events.blind_fire),
                events.reload_speech.unwrap_or(255),
                u8::from(events.call_cover),
                u8::from(events.shift_along),
            ]);
            let pose = state
                .stance(
                    StanceInput {
                        time,
                        entity: seed + 1,
                        at_cover: true,
                        cover_kind: if seed % 3 == 0 { 2 } else { 1 },
                        cover_height: 0.9,
                        suppression,
                        pinned: suppression >= 60.0,
                        armed: true,
                        threat: Vector3::new(0.3, 0.0, -0.8),
                        lean_direction: Vector3::new(0.8, 0.0, 0.3),
                        ..Default::default()
                    },
                    true,
                )
                .unwrap();
            bytes.extend_from_slice(&[pose.posture, u8::from(pose.can_aim), pose.face_threat]);
            if pose.can_aim {
                let shot = state
                    .prepare_shot(
                        ShotInput {
                            weapon,
                            burst_min: 2,
                            burst_max: 4,
                            time,
                            stamina: f64::from(tick % 20) * 0.03,
                            moving: false,
                            gun_override: false,
                            squad_accuracy: 0.85,
                            ambush: tick < 30,
                        },
                        &mut rng,
                    )
                    .unwrap();
                bytes.extend_from_slice(&shot.accuracy.to_le_bytes());
                bytes.extend_from_slice(&[
                    u8::from(shot.fired),
                    u8::from(shot.low_ammo),
                    u8::from(shot.announce_low_ammo),
                    shot.reload_speech.unwrap_or(255),
                ]);
                if shot.fired {
                    rng.randf(); // Combat has its own draws between shot and recovery.
                    let speech = state
                        .finish_shot(weapon, 0.12, suppression, shot.low_ammo, true, &mut rng)
                        .unwrap();
                    bytes.push(speech.unwrap_or(255));
                }
            }
            if tick % 20 == 0 {
                let saved = state.checkpoint();
                assert_eq!(state, InfantryWeapon::restore(&saved).unwrap());
                block(&mut bytes, &saved);
                bytes.extend_from_slice(&rng.state().to_le_bytes());
            }
        }
    }
    golden("infantry_weapon", &bytes);
}

#[test]
fn flight_transcripts_are_identical_across_platforms() {
    let mut bytes = Vec::new();
    for kind in [
        Kind::Frag,
        Kind::Smoke,
        Kind::Rocket,
        Kind::Recoilless,
        Kind::Mortar,
        Kind::MortarSmoke,
        Kind::Grad,
        Kind::Arty,
        Kind::Ac105,
        Kind::Ac40,
        Kind::Ac25,
        Kind::Bomb,
    ] {
        let mut flight = Flight {
            kind,
            position: Vector3::new(-37.2, 20.3, 15.4),
            velocity: Vector3::new(5.72, 13.41, -2.63),
            origin: Vector3::new(-37.2, 20.3, 15.4),
            target: Vector3::new(35.7, 0.2, -11.3),
            fuse: 3.4,
            flying: true,
            life: 0.0,
            smoke_time: 0.0,
            smoke_radius: 0.0,
            shell_duration: 3.0,
        };
        for tick in 0..240 {
            flight.advance(1.0 / 30.0, Holder::Free, None);
            if tick % 23 == 0 {
                block(&mut bytes, &flight.checkpoint());
            }
            if tick == 71 {
                flight = Flight::restore(&flight.checkpoint()).unwrap();
            }
        }
    }
    let mut collision = CollisionWorld::default();
    for phase in [
        Phase::Climb,
        Phase::Cruise,
        Phase::Dive,
        Phase::Uncontrolled,
    ] {
        let mut drone = DroneFlight::new(Vector3::new(-35.6, 7.2, 18.1), 0.7);
        drone.phase = phase;
        drone.diving = phase == Phase::Dive;
        for tick in 0..240 {
            drone.advance(
                1.0 / 30.0,
                Some(Vector3::new(90.5, 2.2, tick as f32 * 0.15)),
                &mut collision,
                512.0,
            );
            if tick % 23 == 0 {
                block(&mut bytes, &drone.checkpoint());
            }
        }
    }
    for kind in [GuidedKind::AntiTank, GuidedKind::SurfaceToAir] {
        let mut missile = GuidedFlight {
            kind,
            position: Vector3::new(-35.6, 7.2, 18.1),
            velocity: Vector3::new(31.1, 2.7, 9.2),
            target: Vector3::ZERO,
            life: 0.0,
            locked: true,
            dead: false,
        };
        for tick in 0..240 {
            missile.advance(
                1.0 / 30.0,
                Some(Vector3::new(90.5, 2.2, tick as f32 * 0.15)),
                tick > 53,
                &mut collision,
                &[],
            );
            if tick % 23 == 0 {
                block(&mut bytes, &missile.checkpoint());
            }
        }
    }
    for kind in [SupportKind::Jet, SupportKind::GunRun, SupportKind::Orbit] {
        let mut flight = SupportFlight::new(
            kind,
            Vector3::new(-420.2, 61.7, 5.8),
            Vector3::X * 58.3,
            Vector3::new(3.7, 0.0, 7.3),
        );
        flight.sight = 65.0;
        let mut rng = SimulationRandom::new(9776);
        for tick in 0..900 {
            let events = flight.advance(
                1.0 / 30.0,
                tick as f64 / 30.0,
                0,
                512.0,
                &[Vector3::new(4.3, 0.0, 7.3)],
                &mut rng,
            );
            for event in events {
                match event {
                    Event::Bomb { position, velocity } => {
                        bytes.push(0);
                        point(&mut bytes, position);
                        point(&mut bytes, velocity);
                    }
                    Event::GunRunStarted => bytes.push(1),
                    Event::Impact(p) => {
                        bytes.push(2);
                        point(&mut bytes, p);
                    }
                    Event::Shell {
                        kind,
                        position,
                        target,
                        duration,
                    } => {
                        bytes.push(3);
                        block(&mut bytes, kind.as_bytes());
                        point(&mut bytes, position);
                        point(&mut bytes, target);
                        bytes.extend_from_slice(&duration.to_le_bytes());
                    }
                    Event::Sound { name, volume } => {
                        bytes.push(4);
                        block(&mut bytes, name.as_bytes());
                        bytes.extend_from_slice(&volume.to_le_bytes());
                    }
                    Event::Photograph => bytes.push(5),
                    Event::Despawn => bytes.push(6),
                }
            }
            if tick % 53 == 0 {
                block(&mut bytes, &flight.checkpoint());
                bytes.extend_from_slice(&rng.state().to_le_bytes());
            }
        }
    }
    golden("flight", &bytes);
}

#[test]
fn geometry_and_movement_transcripts_are_identical_across_platforms() {
    let mut terrain = Terrain::blank(32).unwrap();
    let water = Water {
        side: 32,
        coast: Some([10.3, 7.91]),
        rivers: vec![River {
            points: vec![
                Vector3::new(-9.1, 0.0, -20.2),
                Vector3::new(-1.7, 0.0, 18.2),
            ],
            width: 9.3,
        }],
        ponds: vec![Pond {
            center: Vector3::new(10.2, 0.0, -3.5),
            radius: 8.7,
            seed: 3.29,
        }],
        fords: vec![Vector3::new(-6.3, 0.0, 0.1)],
        bridges: vec![],
    };
    water.paint(&mut terrain.layers[BASE], false).unwrap();
    water.carve(&mut terrain.heights, false).unwrap();
    for i in 0..7 {
        terrain.crater(
            Vector3::new(i as f32 * 3.1 - 9.2, 0.0, i as f32 * 1.7 - 5.4),
            1.5 + i as f64 * 0.15,
        );
    }
    terrain.paint_box(
        Vector3::new(7.7, 0.0, 4.9),
        glam::Vec2::new(3.7, 6.3),
        0.731,
        MUD,
    );
    let mut bytes = terrain.checkpoint();
    block(&mut bytes, &water.checkpoint());
    let mut collision = CollisionWorld::default();
    collision.replace(
        5,
        &[BoxShape {
            body: 5,
            shape: 0,
            center: Vector3::new(0.0, 0.4, -1.0),
            basis: Mat3::from_rotation_y(0.731),
            half: Vector3::new(15.0, 0.4, 0.3),
        }],
    );
    block(&mut bytes, &collision.checkpoint());
    for i in 0..20 {
        let a = Vector3::new(i as f32 * 1.17 - 11.71, 0.4, 15.3);
        if let Some(hit) = collision.ray(a, Vector3::new(-3.7, 0.6, -13.7), &[]) {
            point(&mut bytes, hit.position);
            point(&mut bytes, hit.normal);
            bytes.extend_from_slice(&hit.fraction.to_le_bytes());
        }
        point(
            &mut bytes,
            slerp(a, Vector3::new(-3.1, 2.2, 5.7), i as f32 / 21.0),
        );
    }
    let parts = [Part {
        position: Vector3::new(0.0, 0.7, 0.0),
        size: Vector3::new(11.3, 1.4, 0.6),
        yaw: 0.731,
        cover: true,
        collision: true,
        blocks_navigation: true,
    }];
    for i in 0..7 {
        for anchor in generate(
            "low_wall",
            i % 3,
            Vector3::new(1.2, 0.0, 3.7),
            i as f64 * 0.37,
            Vector3::ONE,
            &parts,
            16.0,
        )
        .unwrap()
        {
            point(&mut bytes, anchor.position);
            point(&mut bytes, anchor.normal);
            bytes.extend_from_slice(&anchor.height.to_le_bytes());
            bytes.push(anchor.kind as u8);
        }
    }
    let mut nav = PathPlanner::new(32).unwrap();
    nav.load_cells(&vec![1; 1024], &vec![0; 1024], &vec![0; 1024]);
    let mut motion = InfantryMotion {
        position: Vector3::new(-3.2, 0.0, 10.7),
        path: vec![Vector3::new(1.1, 0.0, -0.7), Vector3::new(-7.3, 0.0, -12.1)],
        ..Default::default()
    };
    let mut rng = SimulationRandom::new(137);
    for tick in 0..360 {
        let input = MoveInput {
            dt: 1.0 / 30.0,
            time: tick as f64 / 30.0,
            speed: 3.4,
            base_y: 0.0,
            alive: true,
            path_pending: false,
            cover_goal: true,
            move_mode: 1,
            suppression: 30.0,
            backwards: false,
            danger: true,
            has_doors: false,
            door_still_closed: false,
            mount: None,
        };
        motion
            .step(input, &nav, &terrain, &mut collision, &mut rng, &[], &[])
            .unwrap();
        if tick % 17 == 0 {
            block(&mut bytes, &motion.checkpoint());
        }
        if tick == 113 {
            motion = InfantryMotion::restore(&motion.checkpoint()).unwrap();
        }
    }
    golden("geometry", &bytes);
}

#[test]
fn checkpoints_reject_previous_or_unknown_numeric_contracts() {
    let motion = InfantryMotion::default();
    let encoded = motion.checkpoint();
    assert_eq!(
        &encoded[6..8],
        &frontline_core::NUMERIC_VERSION.to_le_bytes()
    );
    for version in [0, frontline_core::NUMERIC_VERSION + 1, u16::MAX] {
        let mut incompatible = encoded.clone();
        incompatible[6..8].copy_from_slice(&version.to_le_bytes());
        assert!(InfantryMotion::restore(&incompatible).is_err());
    }
}
