use frontline_core::collision::{BoxShape, CollisionWorld, Mat3};
use frontline_core::infantry_aim::{AimInput, InfantryAim, Target, TargetKind};
use frontline_core::random::SimulationRandom;
use frontline_core::vector::Vector3 as V;
use frontline_core::visibility::{Smoke, Visibility};

fn input() -> AimInput<'static> {
    AimInput {
        time: 0.0,
        position: V::ZERO,
        eye: V::Y,
        target: None,
        blind: false,
        cache_obstruction: true,
        cover_fire: None,
        last_known: None,
        weapon_range: 50.0,
    }
}

const POINTS: &[V] = &[V::new(10.0, 1.0, 0.0)];

fn target() -> Target<'static> {
    Target {
        id: 5,
        kind: TargetKind::Other,
        position: V::new(10.0, 0.0, 0.0),
        center: V::new(10.0, 1.0, 0.0),
        points: POINTS,
        excluded: &[],
    }
}

fn wall(id: i64, x: f32) -> BoxShape {
    BoxShape {
        body: id,
        shape: 0,
        center: V::new(x, 1.0, 0.0),
        basis: Mat3::IDENTITY,
        half: V::new(0.5, 3.0, 3.0),
    }
}

#[test]
fn sight_refresh_uses_target_identity_and_strict_timer_boundary() {
    let (mut aim, mut geometry, mut sight, mut rng) = (
        InfantryAim::default(),
        CollisionWorld::default(),
        Visibility::default(),
        SimulationRandom::new(1),
    );
    let mut i = AimInput {
        target: Some(target()),
        ..input()
    };
    let visible = aim.choose(i, &mut geometry, &mut sight, &mut rng).unwrap();
    assert_eq!(visible.target, 5);
    assert!(geometry.replace(10, &[wall(10, 5.0)]));
    i.time = 0.3;
    assert_eq!(
        aim.choose(i, &mut geometry, &mut sight, &mut rng).unwrap(),
        visible
    );
    i.time += 0.0001;
    assert!(aim
        .choose(i, &mut geometry, &mut sight, &mut rng)
        .unwrap()
        .point
        .is_none());
    i.time += 0.4;
    assert!(
        aim.choose(i, &mut geometry, &mut sight, &mut rng)
            .unwrap()
            .reused_obstruction
    );
    geometry.remove(10);
    i.target.as_mut().unwrap().id = 6;
    assert_eq!(
        aim.choose(i, &mut geometry, &mut sight, &mut rng)
            .unwrap()
            .target,
        6
    );
}

#[test]
fn structures_allow_their_own_walls_and_keep_existing_smoke_rules() {
    let (mut geometry, mut sight, mut rng) = (
        CollisionWorld::default(),
        Visibility::default(),
        SimulationRandom::new(2),
    );
    assert!(geometry.replace(5, &[wall(5, 10.0)]));
    assert!(sight.set_projectile(
        1,
        Smoke {
            center: V::new(5.0, 1.0, 0.0),
            radius: 3.0
        }
    ));
    let mut i = AimInput {
        target: Some(Target {
            kind: TargetKind::Structure,
            ..target()
        }),
        ..input()
    };
    assert_eq!(
        InfantryAim::default()
            .choose(i, &mut geometry, &mut sight, &mut rng)
            .unwrap()
            .target,
        5
    );
    assert!(geometry.replace(9, &[wall(9, 5.0)]));
    assert!(InfantryAim::default()
        .choose(i, &mut geometry, &mut sight, &mut rng)
        .unwrap()
        .point
        .is_none());
    geometry.remove(5);
    geometry.remove(9);
    i.target.as_mut().unwrap().kind = TargetKind::Drone;
    assert!(InfantryAim::default()
        .choose(i, &mut geometry, &mut sight, &mut rng)
        .unwrap()
        .point
        .is_none());
    sight.remove_projectile(1);
    assert_eq!(
        InfantryAim::default()
            .choose(i, &mut geometry, &mut sight, &mut rng)
            .unwrap()
            .point,
        Some(target().position)
    );
}

#[test]
fn aim_priority_preserves_draw_order_and_cover_range() {
    let (mut geometry, mut sight) = (CollisionWorld::default(), Visibility::default());
    for seed in 0..128 {
        let mut rng = SimulationRandom::new(seed);
        let mut expected = rng;
        let cover = V::new(4.0, 0.0, 2.0);
        let known = V::new(3.0, 0.0, 7.0);
        let mut i = AimInput {
            target: Some(target()),
            blind: true,
            cover_fire: Some(cover),
            last_known: Some(known),
            ..input()
        };
        let mut aim = InfantryAim::default();
        let result = aim.choose(i, &mut geometry, &mut sight, &mut rng).unwrap();
        assert_eq!(
            result.point,
            Some(
                target().position
                    + V::new(
                        expected.randf_range(-1.5, 1.5),
                        expected.randf_range(0.5, 1.8),
                        expected.randf_range(-1.5, 1.5)
                    )
            )
        );
        assert_eq!(rng, expected);
        assert_eq!(
            aim,
            InfantryAim::default(),
            "blind fire does not refresh the sight cache"
        );
        i.target = None;
        let result = aim.choose(i, &mut geometry, &mut sight, &mut rng).unwrap();
        assert_eq!(
            result.point,
            Some(
                cover
                    + V::new(
                        expected.randf_range(-2.5, 2.5),
                        expected.randf_range(0.6, 1.4),
                        expected.randf_range(-2.5, 2.5)
                    )
            )
        );
        assert_eq!(result.target, 0);
        i.weapon_range = 0.0;
        let result = aim.choose(i, &mut geometry, &mut sight, &mut rng).unwrap();
        assert_eq!(
            result.point,
            Some(
                known
                    + V::new(
                        expected.randf_range(-1.5, 1.5),
                        1.0,
                        expected.randf_range(-1.5, 1.5)
                    )
            )
        );
        i.last_known = None;
        assert!(aim
            .choose(i, &mut geometry, &mut sight, &mut rng)
            .unwrap()
            .point
            .is_none());
        assert_eq!(rng, expected);
    }
}

#[test]
fn infantry_cover_shots_and_checkpoint_resume_preserve_rng() {
    let (mut geometry, mut sight) = (CollisionWorld::default(), Visibility::default());
    let pts = [
        V::new(10.0, 1.7, 0.0),
        V::new(10.0, 0.8, 0.0),
        V::new(10.0, 0.3, 0.0),
    ];
    for seed in 0..128 {
        let mut rng = SimulationRandom::new(seed);
        let mut expected = rng;
        let mut aim = InfantryAim::default();
        let mut i = AimInput {
            target: Some(Target {
                kind: TargetKind::Infantry {
                    over_cover: seed % 2 == 0,
                    cover_height: 0.8,
                },
                points: &pts,
                ..target()
            }),
            ..input()
        };
        for tick in 0..40 {
            i.time = f64::from(tick) / 30.0;
            let point = if seed % 2 == 0 && f64::from(expected.randf()) < 0.35 {
                target().position + V::new(0.0, 0.68, 0.0)
            } else {
                pts[expected.randi() as usize % pts.len()]
            };
            let result = aim.choose(i, &mut geometry, &mut sight, &mut rng).unwrap();
            assert_eq!(result.point, Some(point));
            assert_eq!(rng, expected);
            let bytes = aim.checkpoint();
            aim = InfantryAim::restore(&bytes).unwrap();
            assert_eq!(aim.checkpoint(), bytes);
        }
    }
}

#[test]
fn invalid_inputs_and_checkpoints_are_rejected_without_changes() {
    let (mut aim, mut geometry, mut sight, mut rng) = (
        InfantryAim::default(),
        CollisionWorld::default(),
        Visibility::default(),
        SimulationRandom::new(3),
    );
    let before = (aim, rng, sight.checkpoint());
    for i in [
        AimInput {
            time: f64::NAN,
            ..input()
        },
        AimInput {
            last_known: Some(V::INFINITY),
            ..input()
        },
        AimInput {
            target: Some(Target { id: 0, ..target() }),
            ..input()
        },
        AimInput {
            target: Some(Target {
                excluded: &[-1],
                ..target()
            }),
            ..input()
        },
        AimInput {
            target: Some(Target {
                kind: TargetKind::Infantry {
                    over_cover: true,
                    cover_height: 1.0,
                },
                points: &[],
                ..target()
            }),
            ..input()
        },
    ] {
        assert!(aim.choose(i, &mut geometry, &mut sight, &mut rng).is_err());
        assert_eq!((aim, rng, sight.checkpoint()), before);
    }
    let bytes = aim.checkpoint();
    for end in 0..bytes.len() {
        assert!(InfantryAim::restore(&bytes[..end]).is_err());
    }
    let mut invalid = bytes.clone();
    invalid.push(0);
    assert!(InfantryAim::restore(&invalid).is_err());
    let mut invalid = bytes.clone();
    invalid[6] = 0;
    assert!(InfantryAim::restore(&invalid).is_err());
    let mut invalid = bytes;
    invalid[24] = 2;
    assert!(InfantryAim::restore(&invalid).is_err());
}
