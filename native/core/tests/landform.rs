use frontline_core::{landform::Landform, terrain::Terrain, vector::Vector3};
use glam::Vec2;

fn ground(side: usize, height: impl Fn(f32, f32) -> f32) -> Terrain {
    let mut t = Terrain::blank(side).unwrap();
    let n = side / 4 + 1;
    let half = side as f32 * 0.5;
    let mut samples = Vec::new();
    for z in 0..n {
        for x in 0..n {
            samples.push(height(x as f32 * 4. - half, z as f32 * 4. - half));
        }
    }
    assert!(t.set_landform(samples));
    for z in 0..side * 2 {
        for x in 0..side * 2 {
            let p = Vector3::new(
                (x as f32 + 0.5) / 2. - half,
                0.,
                (z as f32 + 0.5) / 2. - half,
            );
            t.heights[z * side * 2 + x] = t.landform.height(p) as f32;
        }
    }
    t
}

#[test]
fn height_slopes_and_hull_envelopes_keep_the_reference_sampling() {
    let t = ground(64, |x, _| (x + 32.) * 0.55);
    let p = Vector3::new(0.5, 0., 0.5);
    assert!((t.landform.height(p) - 17.875).abs() < 0.00001);
    assert!((t.landform.cell_slope(t.index(p)) - 0.55).abs() < 0.00001);
    assert!(t.speed(p, false, false) < 0.59);
    assert!(t.nav_weight(t.index(p), true) > 3.8);
    assert!(!t.landform.fits(p, Vec2::splat(3.), 0., 0.35));
    let t = ground(64, |x, _| if x >= 4. { 10. } else { 0. });
    let p = Vector3::new(-1.5, 0., 0.5);
    assert!(t.landform.cell_slope(t.index(p)) < 0.48);
    assert!(t.landform.vehicle_slope(t.index(p)) > 0.65);
    for i in 0..64 * 64 {
        assert!(t.landform.vehicle_slope(i) >= t.landform.cell_slope(i));
    }
}

#[test]
fn ridge_rays_stop_at_the_first_ground_hit_and_allow_clear_flight() {
    let t = ground(64, |x, _| 12. * (1. - x.abs() / 12.).max(0.));
    let a = Vector3::new(-20., 1.5, 0.);
    let b = Vector3::new(20., 1.5, 0.);
    let hit = t.ray_ground(a, b, &[]).unwrap();
    assert!((-11. ..-10.).contains(&hit.position.x));
    assert!(hit.normal.x < -0.5 && hit.normal.y > 0.5);
    assert_eq!((hit.body, hit.shape), (0, -1));
    assert!(t
        .ray_ground(a + Vector3::Y * 14., b + Vector3::Y * 14., &[])
        .is_none());
    let vertical = t
        .ray_ground(Vector3::new(0., 20., 0.), Vector3::ZERO, &[])
        .unwrap();
    assert!((vertical.position.y - 11.75).abs() < 0.08);
    assert!(t.ray_ground(Vector3::NAN, b, &[]).is_none());
    assert!(t.ray_ground(a, b, &[1]).is_none());
    assert!(t.ray_ground(a, Vector3::splat(1e30), &[]).is_none());
    assert!(Terrain::blank(64).unwrap().ray_ground(a, b, &[]).is_none());
}

#[test]
fn craters_are_dug_relative_to_geology_and_resume_exactly() {
    let mut t = ground(32, |_, _| 12.);
    let p = Vector3::new(0., 12., 0.);
    assert_eq!(t.ground_y(p, false), 12.);
    assert_eq!(t.ground_y(p, true), 0.06);
    let initial = t.checkpoint();
    assert_eq!(initial[4], 3);
    assert_eq!(t.crater(p + Vector3::Y * 2., 3.), (vec![], None));
    assert_eq!(initial, t.checkpoint());
    t.crater(p, 2.);
    assert!(t.deform_at(p) < 12. && t.deform_at(p) > 10.5);
    assert_eq!(t.landform.height(p), 12.);
    let mut restored = Terrain::restore(&t.checkpoint()).unwrap();
    assert_eq!(t, restored);
    for i in 0..20 {
        let q = p + Vector3::new(i as f32 * 0.17, 0., -i as f32 * 0.21);
        assert_eq!(t.crater(q, 1.2), restored.crater(q, 1.2));
        assert_eq!(t.checkpoint(), restored.checkpoint());
        assert_eq!(
            t.ray_ground(q + Vector3::Y * 4., q - Vector3::Y * 4., &[]),
            restored.ray_ground(q + Vector3::Y * 4., q - Vector3::Y * 4., &[])
        );
    }
}

#[test]
fn elevated_trench_floors_and_bridge_decks_control_ground_intersections() {
    use frontline_core::terrain::TRENCH;
    use frontline_core::terrain_cover::CoverStructure;
    let mut t = ground(32, |_, _| 12.);
    let p = Vector3::ZERO;
    let i = t.index(p);
    t.layers[TRENCH][i] = 1;
    assert!(t.scene.register(
        5,
        CoverStructure {
            position: Vector3::Y * 12.,
            radius: 8.,
            kind: 0,
            rubble: false,
            dug: true,
            parts: vec![],
            footprint: [
                Vec2::ZERO,
                Vec2::new(4., 1.),
                Vec2::new(4., 1.),
                Vec2::X,
                Vec2::Y
            ],
            trench: [Vector3::new(-4., 12., 0.), Vector3::new(4., 12., 0.)],
        },
        vec![(-1, -1), (-1, 0), (0, -1), (0, 0)]
    ));
    assert_eq!(t.ground_y(p, false), 12. - 1.2 + 0.15);
    let hit = t.ray_ground(Vector3::Y * 20., p, &[]).unwrap();
    assert!((hit.position.y - 10.95).abs() < 0.08);
    let mut deck = vec![0; 32 * 32];
    deck[i] = 1;
    let hit = t.ray_ground(Vector3::Y * 20., p, &deck).unwrap();
    assert!((hit.position.y - 0.06).abs() < 0.08);
    let restored = Terrain::restore(&t.checkpoint()).unwrap();
    assert_eq!(
        t.ray_ground(Vector3::Y * 20., p, &deck),
        restored.ray_ground(Vector3::Y * 20., p, &deck)
    );
}

#[test]
fn bad_geology_and_incompatible_checkpoints_fail_without_mutation() {
    let mut t = ground(16, |x, z| 12. + x * 0.1 + z * 0.2);
    let saved = t.checkpoint();
    for bad in [
        vec![0.; 24],
        vec![f32::NAN; 25],
        vec![-1.; 25],
        vec![513.; 25],
    ] {
        assert!(!t.set_landform(bad));
        assert_eq!(t.checkpoint(), saved);
    }
    for length in [0, 1, 7, 8, 20, saved.len() / 2, saved.len() - 1] {
        assert!(Terrain::restore(&saved[..length]).is_err());
    }
    let mut bad = saved.clone();
    bad.push(0);
    assert!(Terrain::restore(&bad).is_err());
    let mut bad = saved.clone();
    bad[4] = 4;
    assert!(Terrain::restore(&bad).is_err());
    let mut bad = saved;
    bad[4] = 2;
    assert!(Terrain::restore(&bad).is_err());
    assert!(Landform::new(2, vec![0.]).is_none());
    assert!(!t.landform.fits(Vector3::ZERO, Vec2::ONE, f64::NAN, 0.35));
    assert!(t.set_landform(vec![]));
    assert_eq!(t.checkpoint()[4], 2);
    assert_eq!(
        Terrain::restore(&t.checkpoint()).unwrap().checkpoint(),
        t.checkpoint()
    );
}
