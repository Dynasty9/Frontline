use frontline_core::collision::{BoxShape, CollisionWorld, Mat3};
use frontline_core::vector::Vector3;
use frontline_core::visibility::{Sight, Smoke, Visibility};

fn wall(body: i64, center: Vector3) -> BoxShape {
    BoxShape {
        body,
        shape: 0,
        center,
        basis: Mat3::IDENTITY,
        half: Vector3::new(0.5, 2.0, 2.0),
    }
}

#[test]
fn proofs_require_unchanged_geometry_points_and_exclusions() {
    let mut geometry = CollisionWorld::default();
    geometry.replace(1, &[wall(1, Vector3::new(5.0, 1.0, 0.0))]);
    let mut sight = Visibility::default();
    let eye = Vector3::new(0.0, 1.0, 0.0);
    let mut points = vec![Vector3::new(10.0, 1.0, 0.0), Vector3::new(10.0, 1.5, 0.0)];
    assert_eq!(
        sight.can_see(&mut geometry, eye, 7, &points, &[], true),
        Some(Sight::Hidden)
    );
    let rays = sight.rays;
    assert_eq!(
        sight.can_see(&mut geometry, eye, 7, &points, &[], true),
        Some(Sight::ReusedObstruction)
    );
    assert_eq!(sight.rays, rays);
    assert_eq!(
        sight.can_see(&mut geometry, eye, 7, &points, &[], false),
        Some(Sight::Hidden)
    );
    assert_eq!(sight.rays, rays + 2);
    points[0].y = 1.2;
    assert_eq!(
        sight.can_see(&mut geometry, eye, 7, &points, &[], true),
        Some(Sight::Hidden)
    );
    assert_eq!(sight.rays, rays + 4);
    assert_eq!(
        sight.can_see(&mut geometry, eye, 7, &points, &[1], true),
        Some(Sight::Visible)
    );
    assert_eq!(
        sight.can_see(&mut geometry, eye, 7, &points, &[], true),
        Some(Sight::Hidden)
    );
    geometry.replace(1, &[wall(1, Vector3::new(5.0, 1.0, 10.0))]);
    assert_eq!(
        sight.can_see(&mut geometry, eye, 7, &points, &[], true),
        Some(Sight::Visible)
    );
    geometry.replace(1, &[wall(1, Vector3::new(5.0, 1.0, 0.0))]);
    assert_eq!(
        sight.can_see(&mut geometry, eye, 7, &points, &[], true),
        Some(Sight::Hidden)
    );
    geometry.remove(1);
    assert_eq!(
        sight.can_see(&mut geometry, eye, 7, &points, &[], true),
        Some(Sight::Visible)
    );
    assert_eq!(
        sight.can_see(
            &mut geometry,
            Vector3::splat(f32::NAN),
            7,
            &points,
            &[],
            true
        ),
        None
    );
}

#[test]
fn smoke_changes_apply_immediately_and_never_become_geometry_proofs() {
    let mut geometry = CollisionWorld::default();
    let mut sight = Visibility::default();
    let eye = Vector3::ZERO;
    let points = [Vector3::X * 10.0];
    let smoke = Smoke {
        center: Vector3::X * 5.0,
        radius: 0.8,
    };
    assert!(sight.set_projectile(1, smoke));
    assert_eq!(
        sight.can_see(&mut geometry, eye, 2, &points, &[], true),
        Some(Sight::Visible)
    );
    assert!(sight.set_projectile(
        1,
        Smoke {
            radius: 0.80000001,
            ..smoke
        }
    ));
    for _ in 0..3 {
        assert_eq!(
            sight.can_see(&mut geometry, eye, 2, &points, &[], true),
            Some(Sight::Hidden)
        );
    }
    assert!(sight.set_projectile(
        1,
        Smoke {
            center: Vector3::Z * 10.0,
            radius: 4.0
        }
    ));
    assert_eq!(
        sight.can_see(&mut geometry, eye, 2, &points, &[], true),
        Some(Sight::Visible)
    );
    sight.set_fires(&[Smoke {
        radius: 4.0,
        ..smoke
    }]);
    assert_eq!(
        sight.can_see(&mut geometry, eye, 2, &points, &[], false),
        Some(Sight::Hidden)
    );
    sight.set_fires(&[]);
    assert_eq!(
        sight.can_see(&mut geometry, eye, 2, &points, &[], true),
        Some(Sight::Visible)
    );
    sight.set_projectile(
        1,
        Smoke {
            radius: 1.0,
            ..smoke
        },
    );
    assert!(sight.smoke_blocks(smoke.center, smoke.center));
    assert!(!sight.smoke_blocks(smoke.center + Vector3::Y, smoke.center + Vector3::Y));
    sight.remove_projectile(1);
    assert!(!sight.smoke_blocks(smoke.center, smoke.center));
}

#[test]
fn cache_eviction_and_checkpoint_resume_do_not_change_visibility() {
    let mut geometry = CollisionWorld::default();
    geometry.replace(1, &[wall(1, Vector3::X * 5.0)]);
    let mut sight = Visibility::default();
    sight.set_projectile(
        2,
        Smoke {
            center: Vector3::Z * 5.0,
            radius: 2.5,
        },
    );
    sight.set_fires(&[Smoke {
        center: Vector3::X * -5.0,
        radius: 2.0,
    }]);
    let checkpoint = sight.checkpoint();
    for id in 1..=4097 {
        assert_eq!(
            sight.can_see(
                &mut geometry,
                Vector3::ZERO,
                id,
                &[Vector3::X * 10.0],
                &[],
                true
            ),
            Some(Sight::Hidden)
        );
    }
    assert_eq!(sight.checkpoint(), checkpoint);
    assert_eq!(
        sight.can_see(
            &mut geometry,
            Vector3::ZERO,
            1,
            &[Vector3::X * 10.0],
            &[],
            true
        ),
        Some(Sight::Hidden)
    );
    for _ in 0..10_000 {
        assert_eq!(
            sight.can_see(
                &mut geometry,
                Vector3::ZERO,
                1,
                &[Vector3::X * 10.0],
                &[],
                true
            ),
            Some(Sight::ReusedObstruction)
        );
    }
    let mut resumed = Visibility::restore(&checkpoint).unwrap();
    let mut restored_geometry = CollisionWorld::restore(&geometry.checkpoint()).unwrap();
    for i in 0..100 {
        let target = Vector3::new(
            (i % 3 * 10 - 10) as f32,
            (i % 4) as f32,
            (i % 5 * 5 - 10) as f32,
        );
        let a = sight
            .can_see(&mut geometry, Vector3::ZERO, i as u64, &[target], &[], true)
            .unwrap();
        let b = resumed
            .can_see(
                &mut restored_geometry,
                Vector3::ZERO,
                i as u64,
                &[target],
                &[],
                true,
            )
            .unwrap();
        assert_eq!(a == Sight::Visible, b == Sight::Visible);
    }
    assert_eq!(sight.checkpoint(), resumed.checkpoint());
    for end in 0..checkpoint.len() {
        assert!(Visibility::restore(&checkpoint[..end]).is_err());
    }
    for offset in [4, 8] {
        let mut bad = checkpoint.clone();
        bad[offset] = 255;
        assert!(Visibility::restore(&bad).is_err());
    }
    let mut bad = checkpoint.clone();
    bad[20..24].copy_from_slice(&f32::NAN.to_le_bytes());
    assert!(Visibility::restore(&bad).is_err());
    let mut bad = checkpoint;
    bad.push(0);
    assert!(Visibility::restore(&bad).is_err());
}

#[test]
fn collision_checkpoints_preserve_ties_changes_and_bounds() {
    let mut geometry = CollisionWorld::default();
    for body in (1..20).rev() {
        geometry.replace(body, &[wall(body, Vector3::X * body as f32)]);
    }
    let checkpoint = geometry.checkpoint();
    let mut resumed = CollisionWorld::restore(&checkpoint).unwrap();
    assert_eq!(resumed.checkpoint(), checkpoint);
    for body in 1..20 {
        assert_eq!(
            geometry.ray(Vector3::ZERO, Vector3::X * 30.0, &[]),
            resumed.ray(Vector3::ZERO, Vector3::X * 30.0, &[])
        );
        geometry.remove(body);
        resumed.remove(body);
        assert_eq!(geometry.checkpoint(), resumed.checkpoint());
    }
    assert!(!geometry.replace(1, &[wall(1, Vector3::ZERO), wall(1, Vector3::ONE)]));
    for end in (0..checkpoint.len()).step_by(7) {
        assert!(CollisionWorld::restore(&checkpoint[..end]).is_err());
    }
    for offset in [4, 8, 27] {
        let mut bad = checkpoint.clone();
        bad[offset] = 255;
        assert!(CollisionWorld::restore(&bad).is_err(), "offset {offset}");
    }
    let mut bad = checkpoint;
    bad.push(0);
    assert!(CollisionWorld::restore(&bad).is_err());
}
