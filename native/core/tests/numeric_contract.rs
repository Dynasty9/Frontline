//! Exact persisted bytes, shared by Windows, Linux and ARM CI, without tolerance comparisons.
use frontline_core::blast::{Blast, Infantry, Protection as BlastProtection};
use frontline_core::bullet::{self, Body, Bullet, TargetEffect, ThroughContact};
use frontline_core::collision::{BoxShape, CollisionWorld, Mat3};
use frontline_core::cover::{generate, Part};
use frontline_core::drone::{DroneFlight, Phase};
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

fn point(out: &mut Vec<u8>, p: Vector3) {
    for v in p.to_array() {
        out.extend_from_slice(&v.to_le_bytes());
    }
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
