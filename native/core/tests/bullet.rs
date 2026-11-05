use frontline_core::bullet::{
    self, Body, Bullet, ShotInput, Target, TargetEffect, TargetKind, TargetLocation,
    ThroughContact, Weapon,
};
use frontline_core::collision::{BoxShape, CollisionWorld, Mat3};
use frontline_core::random::SimulationRandom;
use frontline_core::vector::Vector3 as V;
use frontline_core::visibility::{Smoke, Visibility};

fn input() -> ShotInput<'static> {
    ShotInput {
        muzzle: V::Y,
        aim: V::new(10.0, 1.0, 0.0),
        target: Some(Target {
            kind: TargetKind::Infantry,
            hit_factor: 1.0,
            terrain_multiplier: 1.0,
            trench_protected: false,
        }),
        weapon: Weapon {
            accuracy: 10.0,
            range: 50.0,
            damage: 30.0,
            anti_air: false,
            penetration: 3,
            drone_accuracy: 0.08,
            explosive_radius: None,
            airburst: false,
        },
        accuracy_multiplier: 1.0,
        soldier_suppression: None,
        optics: false,
        excluded: &[],
    }
}

fn wall() -> CollisionWorld {
    let mut world = CollisionWorld::default();
    assert!(world.replace(
        1,
        &[BoxShape {
            body: 1,
            shape: 0,
            center: V::new(5.0, 1.0, 0.0),
            basis: Mat3::IDENTITY,
            half: V::new(0.5, 20.0, 20.0)
        }]
    ));
    world
}

#[test]
fn missed_rounds_preserve_draws_and_do_not_damage_the_named_target() {
    let mut rng = SimulationRandom::new(100);
    let mut expected = rng;
    let mut i = input();
    i.target = None;
    let mut shot = Bullet::fire(
        i,
        &mut CollisionWorld::default(),
        &Visibility::default(),
        &mut rng,
    )
    .unwrap();
    expected.randf_range(0.5, 2.0);
    expected.randf_range(-1.0, 1.0);
    expected.randf_range(-0.5, 0.9);
    assert_eq!(rng, expected);
    assert!(!shot.hit && shot.ray.is_none());
    let effects = shot.resolve_obstacle(Body::Other, &mut rng).unwrap();
    assert!(!effects.penetrated && !effects.vehicle_hit && !effects.structure_surface);
    assert_eq!(shot.finish_target(&mut rng).unwrap(), TargetEffect::None);
    assert!(shot.explosion(None, &mut rng).unwrap().is_none());
    assert_eq!(rng, expected);
}

#[test]
fn penetration_and_target_damage_preserve_intervening_random_draws() {
    let mut rng = SimulationRandom::new(101);
    let mut expected = rng;
    let mut shot = Bullet::fire(input(), &mut wall(), &Visibility::default(), &mut rng).unwrap();
    expected.randf();
    assert!(shot.hit);
    let effects = shot
        .resolve_obstacle(Body::Structure { material: 0 }, &mut rng)
        .unwrap();
    expected.randf();
    assert!(effects.penetrated);
    assert_eq!(effects.penetration_damage, 1.5);
    assert!(!effects.structure_surface && effects.through_end.is_none());
    assert_eq!(shot.end, input().aim);
    for _ in 0..7 {
        rng.randi();
        expected.randi();
    }
    let mut damage = 30.0 * f64::from(expected.randf_range(0.8, 1.2)) * 0.7;
    if f64::from(expected.randf()) < 0.08 {
        damage *= 2.5;
    }
    assert_eq!(
        shot.finish_target(&mut rng).unwrap(),
        TargetEffect::Damage(damage)
    );
    assert_eq!(rng, expected);
    assert_eq!(shot.impact, 2);
}

#[test]
fn blocked_rounds_and_penetrating_misses_keep_both_surface_effects() {
    let mut rng = SimulationRandom::new(102);
    let mut shot = Bullet::fire(input(), &mut wall(), &Visibility::default(), &mut rng).unwrap();
    let effects = shot
        .resolve_obstacle(Body::Structure { material: 3 }, &mut rng)
        .unwrap();
    assert!(!effects.penetrated && effects.structure_surface);
    assert!(!shot.hit);
    assert_eq!(shot.end.x, 4.5);
    shot.set_surface(5).unwrap();
    assert_eq!(shot.finish_target(&mut rng).unwrap(), TargetEffect::None);
    assert_eq!(shot.impact, 5);
    let mut i = input();
    i.target = None;
    let mut shot = Bullet::fire(i, &mut wall(), &Visibility::default(), &mut rng).unwrap();
    let traced_end = shot.end;
    let effects = shot
        .resolve_obstacle(Body::Structure { material: 0 }, &mut rng)
        .unwrap();
    assert!(effects.penetrated && effects.structure_surface);
    assert_eq!(effects.through_end, Some(traced_end));
    assert_eq!(effects.penetration_damage + effects.structure_damage, 3.0);
    assert_ne!(shot.end, traced_end);
}

#[test]
fn smoke_prevents_hits_and_explosions_read_the_post_damage_center() {
    let mut visibility = Visibility::default();
    assert!(visibility.set_projectile(
        1,
        Smoke {
            center: V::new(5.0, 1.0, 0.0),
            radius: 2.0
        }
    ));
    let mut rng = SimulationRandom::new(103);
    assert!(
        !Bullet::fire(
            input(),
            &mut CollisionWorld::default(),
            &visibility,
            &mut rng
        )
        .unwrap()
        .hit
    );
    let mut i = input();
    i.weapon.explosive_radius = Some(3.0);
    let mut shot = Bullet::fire(
        i,
        &mut CollisionWorld::default(),
        &Visibility::default(),
        &mut rng,
    )
    .unwrap();
    shot.resolve_obstacle(Body::Other, &mut rng).unwrap();
    assert!(matches!(
        shot.finish_target(&mut rng).unwrap(),
        TargetEffect::Damage(_)
    ));
    let location = TargetLocation {
        position: V::X * 10.0,
        center: V::new(10.0, 0.2, 0.0),
        in_trench: true,
    };
    let explosion = shot.explosion(Some(location), &mut rng).unwrap().unwrap();
    assert_eq!(explosion.position, location.center);
    assert_eq!(explosion.damage, 48.0);
    i.weapon.airburst = true;
    let mut shot = Bullet::fire(
        i,
        &mut CollisionWorld::default(),
        &Visibility::default(),
        &mut rng,
    )
    .unwrap();
    shot.resolve_obstacle(Body::Other, &mut rng).unwrap();
    shot.finish_target(&mut rng).unwrap();
    let mut expected = rng;
    let point = V::new(10.0, 1.4, 0.0)
        + V::new(
            expected.randf_range(-0.8, 0.8),
            0.0,
            expected.randf_range(-0.8, 0.8),
        );
    assert_eq!(
        shot.explosion(Some(location), &mut rng)
            .unwrap()
            .unwrap()
            .position,
        point
    );
    assert_eq!(rng, expected);
}

#[test]
fn stray_hits_stop_at_the_first_eligible_man_and_suppression_keeps_the_three_meter_edge() {
    let contacts = [
        ThroughContact {
            id: 1,
            team: 0,
            alive: true,
            center: V::new(1.0, 1.0, 0.0),
        },
        ThroughContact {
            id: 2,
            team: 1,
            alive: false,
            center: V::new(1.0, 1.0, 0.0),
        },
        ThroughContact {
            id: 3,
            team: 1,
            alive: true,
            center: V::new(2.0, 1.0, 0.0),
        },
        ThroughContact {
            id: 4,
            team: 1,
            alive: true,
            center: V::new(1.0, 1.0, 0.0),
        },
    ];
    for seed in 0..128 {
        let mut rng = SimulationRandom::new(seed);
        let mut expected = rng;
        let hits = f64::from(expected.randf()) < 0.35;
        let damage = if hits {
            30.0 * 0.7 * f64::from(expected.randf_range(0.8, 1.2))
        } else {
            0.0
        };
        let hit = bullet::through_hit(
            V::Y,
            V::new(10.0, 1.0, 0.0),
            &contacts,
            0,
            30.0,
            0.7,
            &mut rng,
        )
        .unwrap();
        assert_eq!(hit.is_some(), hits);
        if let Some(hit) = hit {
            assert_eq!(hit.target, 3);
            assert_eq!(hit.damage, damage);
        }
        assert_eq!(rng, expected);
    }
    assert_eq!(
        bullet::suppression(
            V::Y,
            V::new(10.0, 1.0, 0.0),
            &[
                V::new(5.0, 0.0, 0.0),
                V::new(5.0, 0.0, 1.5),
                V::new(5.0, 0.0, 3.0)
            ],
            20.0
        )
        .unwrap(),
        vec![20.0, 10.0, -1.0]
    );
}

#[test]
fn malformed_inputs_and_out_of_order_stages_leave_rng_unchanged() {
    let mut rng = SimulationRandom::new(104);
    let before = rng;
    let mut i = input();
    i.weapon.range = 0.0;
    assert!(Bullet::fire(i, &mut wall(), &Visibility::default(), &mut rng).is_err());
    assert_eq!(rng, before);
    let mut shot = Bullet::fire(input(), &mut wall(), &Visibility::default(), &mut rng).unwrap();
    let before = rng;
    assert!(shot.finish_target(&mut rng).is_err());
    assert!(shot
        .resolve_obstacle(Body::Structure { material: 4 }, &mut rng)
        .is_err());
    assert_eq!(rng, before);
    shot.resolve_obstacle(Body::Structure { material: 1 }, &mut rng)
        .unwrap();
    let before = rng;
    assert!(shot.resolve_obstacle(Body::Other, &mut rng).is_err());
    assert_eq!(rng, before);
    assert!(bullet::suppression(V::ZERO, V::ONE, &[V::INFINITY], 1.0).is_err());
    assert!(bullet::through_hit(
        V::ZERO,
        V::ONE,
        &[ThroughContact {
            id: 0,
            team: 1,
            alive: true,
            center: V::ZERO
        }],
        0,
        30.0,
        0.7,
        &mut rng
    )
    .is_err());
    assert_eq!(rng, before);
}
