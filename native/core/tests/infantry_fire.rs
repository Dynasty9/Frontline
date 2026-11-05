use frontline_core::actors::{Actor, Actors};
use frontline_core::collision::{BoxShape, CollisionWorld, Mat3};
use frontline_core::infantry::Infantry;
use frontline_core::infantry_aim::AimResult;
use frontline_core::infantry_fire::{FireProfile, MountedGun};
use frontline_core::infantry_vitals::Life;
use frontline_core::infantry_weapon::Weapon;
use frontline_core::random::SimulationRandom;
use frontline_core::squad::{Contact, Report, Squad};
use frontline_core::structure::Structure;
use frontline_core::vector::Vector3;
use frontline_core::visibility::Visibility;

fn soldier(id: u32, position: Vector3) -> Infantry {
    let mut s = Infantry::default();
    s.identity.id = id;
    s.identity.team = 0;
    s.identity.squad = 1;
    s.identity.unit = "rifleman".into();
    s.identity.weapon = "rifle".into();
    s.motion.position = position;
    s
}
fn actors(s: Infantry, others: Vec<Infantry>) -> Actors {
    let mut entries = vec![Actor::Soldier(Box::new(s))];
    entries.extend(others.into_iter().map(|s| Actor::Soldier(Box::new(s))));
    Actors::from_entries(100, entries).unwrap()
}
fn squad() -> Squad {
    Squad {
        id: 1,
        members: vec![1, 3, 2],
        ..Default::default()
    }
}
fn aim(
    a: &mut Actors,
    now: f64,
    q: Option<&Squad>,
    c: &mut CollisionWorld,
    v: &mut Visibility,
    rng: &mut SimulationRandom,
) -> AimResult {
    a.aim_infantry(1, now, 50.0, q, c, v, rng).unwrap()
}
fn wall(c: &mut CollisionWorld) {
    assert!(c.replace(
        99,
        &[BoxShape {
            body: 99,
            shape: 0,
            center: Vector3::new(0.0, 1.0, -10.0),
            basis: Mat3::IDENTITY,
            half: Vector3::new(8.0, 4.0, 0.5)
        }]
    ));
}

#[test]
fn owned_target_pose_and_short_sight_cache_resume_with_the_random_cursor() {
    let mut s = soldier(1, Vector3::ZERO);
    s.fight.target = 2;
    let mut a = actors(s, vec![soldier(2, Vector3::NEG_Z * 20.0)]);
    let mut c = CollisionWorld::default();
    let mut vis = Visibility::default();
    let mut rng = SimulationRandom::new(137);
    assert_eq!(
        aim(&mut a, 10.0, None, &mut c, &mut vis, &mut rng).target,
        2
    );
    wall(&mut c);
    assert_eq!(
        aim(&mut a, 10.2, None, &mut c, &mut vis, &mut rng).target,
        2
    );
    let mut restored = Actors::restore(&a.checkpoint().unwrap()).unwrap();
    let mut random = rng;
    let expected = aim(&mut a, 10.31, None, &mut c, &mut vis, &mut rng);
    let actual = aim(
        &mut restored,
        10.31,
        None,
        &mut c,
        &mut Visibility::default(),
        &mut random,
    );
    assert_eq!(expected, actual);
    assert!(actual.point.is_none());
    assert_eq!(random, rng);
    assert_eq!(a.checkpoint().unwrap(), restored.checkpoint().unwrap());
}

#[test]
fn blind_fire_uses_the_target_without_updating_the_sight_cache() {
    let mut s = soldier(1, Vector3::ZERO);
    s.fight.target = 2;
    s.weapon.blind = true;
    let mut a = actors(s, vec![soldier(2, Vector3::NEG_Z * 20.0)]);
    let mut c = CollisionWorld::default();
    wall(&mut c);
    let mut vis = Visibility::default();
    let mut rng = SimulationRandom::new(137);
    let result = aim(&mut a, 10.0, None, &mut c, &mut vis, &mut rng);
    assert_eq!(result.target, 2);
    assert!(result.point.is_some());
    assert_eq!(vis.rays, 0);
    assert_eq!(a.soldier(1).unwrap().aim.sight_target, 0);
}

#[test]
fn personal_covering_fire_precedes_the_squad_order_until_its_deadline() {
    let mut s = soldier(1, Vector3::ZERO);
    s.fight.covering_until = 11.0;
    s.fight.covering_position = Vector3::X * 20.0;
    let mut a = actors(s, vec![]);
    let q = Squad {
        cover_fire_until: 20.0,
        cover_fire_position: Vector3::NEG_X * 20.0,
        ..squad()
    };
    let mut c = CollisionWorld::default();
    let mut vis = Visibility::default();
    let mut rng = SimulationRandom::new(137);
    assert!(
        aim(&mut a, 10.0, Some(&q), &mut c, &mut vis, &mut rng)
            .point
            .unwrap()
            .x
            > 17.0
    );
    assert!(
        aim(&mut a, 11.0, Some(&q), &mut c, &mut vis, &mut rng)
            .point
            .unwrap()
            .x
            < -17.0
    );
}

#[test]
fn machine_gunners_use_the_nearest_live_recent_report_with_strict_range_ties() {
    let mut s = soldier(1, Vector3::ZERO);
    s.identity.unit = "pkm".into();
    let mut downed = soldier(2, Vector3::ZERO);
    downed.vitals.life = Life::Downed;
    let mut a = actors(
        s,
        vec![downed, soldier(3, Vector3::ZERO), soldier(4, Vector3::ZERO)],
    );
    let q = Squad {
        known: vec![
            Contact {
                id: 2,
                report: Report {
                    position: Vector3::X * 5.0,
                    time: 10.0,
                },
            },
            Contact {
                id: 3,
                report: Report {
                    position: Vector3::X * 20.0,
                    time: 5.0,
                },
            },
            Contact {
                id: 4,
                report: Report {
                    position: Vector3::NEG_X * 20.0,
                    time: 5.0,
                },
            },
        ],
        ..squad()
    };
    let mut c = CollisionWorld::default();
    let mut vis = Visibility::default();
    let mut rng = SimulationRandom::new(137);
    assert_eq!(q.last_known_near(&a, Vector3::ZERO, 20.0, 5.0, 10.0), None);
    let r = aim(&mut a, 10.0, Some(&q), &mut c, &mut vis, &mut rng);
    assert_eq!(r.target, 0);
    assert!(r.point.unwrap().x > 18.0);
    assert!(aim(&mut a, 10.001, Some(&q), &mut c, &mut vis, &mut rng)
        .point
        .is_none());
}

#[test]
fn covering_response_keeps_member_order_and_consumes_speech_draws_even_when_muted() {
    let mut replies = 0;
    for seed in 0..128 {
        let mut s = soldier(1, Vector3::ZERO);
        s.fight.visible_targets = vec![8];
        let mut near = soldier(2, Vector3::X);
        near.cover.at_cover = true;
        near.weapon.peek_timer = 3.0;
        let mut first = soldier(3, Vector3::X * 8.0);
        first.cover.at_cover = true;
        first.weapon.peek_timer = 3.0;
        let mut loud = actors(s.clone(), vec![near.clone(), first.clone()]);
        first.vitals.speech_cooldown = 9.0;
        let mut muted = actors(s, vec![near, first]);
        let q = squad();
        let mut a = SimulationRandom::new(seed);
        let mut b = a;
        let reply = loud.call_cover(1, Some(&q), &mut a).unwrap();
        let quiet = muted.call_cover(1, Some(&q), &mut b).unwrap();
        assert_eq!(reply.soldier, 3);
        assert_eq!(quiet.speech, None);
        assert_eq!(a, b);
        assert_eq!(loud.soldier(3).unwrap().weapon.peek_timer, 0.2);
        assert_eq!(loud.soldier(2).unwrap().weapon.peek_timer, 3.0);
        replies += usize::from(reply.speech.is_some());
    }
    assert!(replies > 0 && replies < 128);
}

#[test]
fn nearby_cover_or_recent_fire_counts_as_support_and_wrong_squads_are_atomic() {
    let s = soldier(1, Vector3::ZERO);
    let mut mate = soldier(2, Vector3::X * 14.0);
    mate.weapon.last_shot = 9.5;
    let mut a = actors(s, vec![mate]);
    let q = squad();
    assert!(a.buddy_up(1, 10.0, Some(&q)).unwrap());
    assert!(!a.buddy_up(1, 10.2, Some(&q)).unwrap());
    let before = a.checkpoint().unwrap();
    let mut rng = SimulationRandom::new(137);
    let random = rng;
    let wrong = Squad { id: 2, ..q };
    assert!(a.call_cover(1, Some(&wrong), &mut rng).is_err());
    assert!(a
        .aim_infantry(
            1,
            10.0,
            f64::NAN,
            None,
            &mut CollisionWorld::default(),
            &mut Visibility::default(),
            &mut rng
        )
        .is_err());
    assert_eq!(rng, random);
    assert_eq!(a.checkpoint().unwrap(), before);
}

fn profile() -> FireProfile {
    FireProfile {
        weapon: Weapon {
            ammunition: 120,
            magazine: 30,
            reload_time: 2.0,
        },
        burst_min: 2,
        burst_max: 4,
    }
}
fn gun() -> MountedGun {
    MountedGun {
        bore: 0.07,
        muzzle: 0.78,
        grip_z: 0.21,
        nest_height: 0.38,
        trench_height: 0.3,
    }
}
#[test]
fn morale_thresholds_match_routing_pin_and_accuracy_rules() {
    for (morale, state) in [
        (-1.0, 0),
        (55.0, 0),
        (54.999, 1),
        (33.0, 1),
        (32.999, 2),
        (12.0, 2),
        (11.999, 3),
    ] {
        let q = Squad { morale, ..squad() };
        assert_eq!(q.morale_state(), state);
        assert_eq!(q.accuracy_multiplier(), [1.0, 0.85, 0.7, 0.45][state]);
        assert_eq!(q.pin_at(), [60.0, 52.0, 44.0, 30.0][state]);
    }
    assert_eq!(
        Squad {
            morale: 100.0,
            drill: "rout".into(),
            ..squad()
        }
        .morale_state(),
        3
    );
}

#[test]
fn firing_and_recovery_resume_around_intervening_combat_draws() {
    for seed in 0..128 {
        let mut s = soldier(1, Vector3::ZERO);
        s.weapon.magazine = 1;
        s.weapon.reserve = 10;
        s.weapon.blind = seed % 2 == 0;
        s.vitals.stamina = 0.4;
        let q = Squad {
            morale: 30.0,
            ambush_time: 11.0,
            ..squad()
        };
        let mut a = actors(s, vec![]);
        let mut rng = SimulationRandom::new(seed);
        let shot = a
            .prepare_infantry_shot(1, 10.0, true, profile(), None, Some(&q), &mut rng)
            .unwrap();
        assert!(shot.shot.fired && shot.shot.announce_low_ammo && shot.shot.low_ammo);
        assert_eq!(a.soldier(1).unwrap().activity, 3);
        assert_eq!(a.soldier(1).unwrap().vitals.speech_cooldown, 2.6);
        let mut restored = Actors::restore(&a.checkpoint().unwrap()).unwrap();
        let mut resumed_random = rng;
        // These are the draws made by the intervening shared damage dispatcher.
        for _ in 0..seed % 7 {
            assert_eq!(rng.randi(), resumed_random.randi());
        }
        let after = Weapon {
            reload_time: 0.25,
            ..profile().weapon
        };
        assert_eq!(
            a.finish_infantry_shot(1, after, 0.1, true, true, &mut rng)
                .unwrap(),
            restored
                .finish_infantry_shot(1, after, 0.1, true, true, &mut resumed_random)
                .unwrap()
        );
        assert_eq!(a.checkpoint().unwrap(), restored.checkpoint().unwrap());
        assert_eq!(rng, resumed_random);
        assert_eq!(a.soldier(1).unwrap().weapon.reload_timer, 0.25);
    }
}

#[test]
fn mounted_muzzles_require_the_crew_position_and_blind_fire_overrides_them() {
    let st = Structure {
        id: 9,
        kind: "mg_nest".into(),
        position: Vector3::new(10.0, 0.0, -12.0),
        yaw: 0.731,
        variant: 1,
        ..Default::default()
    };
    for mode in 0..3 {
        let mut s = soldier(1, st.mg_mount_position(gun()));
        s.emplacement.structure = 9;
        s.motion.yaw = 2.8;
        s.weapon.magazine = 7;
        s.weapon.blind = mode == 2;
        s.cover.normal = Vector3::X;
        s.cover.height = 0.8;
        if mode == 1 {
            s.motion.position += Vector3::X;
        }
        let a = Actors::from_entries(
            100,
            vec![
                Actor::Soldier(Box::new(s.clone())),
                Actor::Structure(Box::new(st.clone())),
            ],
        )
        .unwrap();
        let muzzle = a.infantry_bullet_origin(1, Some(gun())).unwrap();
        if mode == 0 {
            assert_eq!(muzzle, st.mg_muzzle(s.motion.yaw, gun()));
        } else if mode == 1 {
            assert_ne!(muzzle, st.mg_muzzle(s.motion.yaw, gun()));
        } else {
            assert_eq!(
                muzzle,
                s.motion.position + Vector3::X * 0.55 + Vector3::new(0.0, 0.92, 0.0)
            );
        }
    }
}

#[test]
fn empty_magazines_reload_without_a_shot_and_invalid_content_preserves_state() {
    let mut s = soldier(1, Vector3::ZERO);
    s.weapon.reserve = 50;
    let mut a = actors(s, vec![]);
    let mut rng = SimulationRandom::new(137);
    let shot = a
        .prepare_infantry_shot(1, 10.0, false, profile(), None, None, &mut rng)
        .unwrap();
    assert!(!shot.shot.fired && shot.origin.is_none());
    assert_eq!(a.soldier(1).unwrap().weapon.reload_timer, 2.0);
    let before = a.checkpoint().unwrap();
    let random = rng;
    let bad = FireProfile {
        burst_min: 0,
        ..profile()
    };
    assert!(a
        .prepare_infantry_shot(1, 10.0, false, bad, None, None, &mut rng)
        .is_err());
    assert!(a
        .finish_infantry_shot(1, profile().weapon, f64::NAN, false, false, &mut rng)
        .is_err());
    assert_eq!(a.checkpoint().unwrap(), before);
    assert_eq!(rng, random);
}
