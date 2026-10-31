use frontline_core::terrain::Terrain;
use frontline_core::terrain_cover::{CoverPart, CoverStructure};
use frontline_core::terrain_scene::CoverScene;
use frontline_core::vector::Vector3;
use glam::Vec2;

fn wall(x: f32) -> CoverStructure {
    CoverStructure {
        position: Vector3::new(x, 0.0, 0.5),
        radius: 5.0,
        kind: 1,
        rubble: false,
        dug: false,
        parts: vec![CoverPart {
            center: Vector3::new(x, 1.0, 0.5),
            cosine: 1.0,
            sine: 0.0,
            half_x: 0.5,
            half_z: 4.0,
            level: 2,
        }],
        footprint: [
            Vec2::new(x, 0.5),
            Vec2::new(0.9, 4.4),
            Vec2::new(0.5, 4.0),
            Vec2::X,
            Vec2::Y,
        ],
        trench: [Vector3::ZERO; 2],
    }
}

#[test]
fn geometry_rebuilds_preserve_encounter_order_across_changes_and_restore() {
    let mut terrain = Terrain::blank(32).unwrap();
    let cells = vec![(-1, -1), (-1, 0), (0, -1), (0, 0)];
    assert!(terrain.scene.register(9, wall(-1.0), cells.clone()));
    assert!(terrain.scene.register(1, wall(2.0), cells.clone()));
    let p = Vector3::new(0.5, 0.0, 0.5);
    let i = terrain.index(p) as u32;
    terrain.queue_cells(&[i]);
    terrain.tick_cover(1);
    assert_eq!(terrain.cell(i as usize)[4..6], [3, 4]);
    // Updating a standing wall retains its order; removing and adding it changes it.
    assert!(terrain.scene.update(9, wall(-1.0)));
    terrain.queue_cells(&[i]);
    terrain.tick_cover(1);
    assert_eq!(terrain.cell(i as usize)[5], 4);
    terrain.scene.remove(9);
    assert!(terrain.scene.register(9, wall(-1.0), cells));
    terrain.queue_rect([-8.0, -8.0, 8.0, 8.0]);
    terrain.tick_cover(27);
    let saved = terrain.checkpoint();
    let mut resumed = Terrain::restore(&saved).unwrap();
    assert_eq!(resumed.scene, terrain.scene);
    assert_eq!(resumed.checkpoint(), saved);
    while !terrain.pending(usize::MAX).is_empty() {
        assert_eq!(terrain.tick_cover(13), resumed.tick_cover(13));
        assert_eq!(terrain.checkpoint(), resumed.checkpoint());
    }
    assert_eq!(terrain.cell(i as usize)[5], 0);
    assert!(terrain.scene.update(1, wall(10.0)));
    terrain.queue_cells(&[i]);
    terrain.tick_cover(1);
    assert_eq!(terrain.cell(i as usize)[5], 4);
}

#[test]
fn cover_scene_rejects_invalid_data_atomically_and_bounded_checkpoints() {
    let mut scene = CoverScene::default();
    assert!(scene.register(7, wall(0.0), vec![(-1, -1), (0, 0)]));
    let saved = scene.checkpoint();
    let mut bad_shape = wall(1.0);
    bad_shape.parts[0].half_x = f64::NAN;
    assert!(!scene.update(7, bad_shape));
    assert!(!scene.register(7, wall(1.0), vec![(0, 0), (0, 0)]));
    assert!(!scene.register(0, wall(1.0), vec![]));
    assert!(!scene.register(9, wall(1.0), vec![(i32::MIN, 0)]));
    assert_eq!(scene.checkpoint(), saved);
    for end in 0..saved.len() {
        assert!(CoverScene::restore(&saved[..end]).is_err());
    }
    for (i, value) in [(4, 2), (8, 0), (20, 0), (28, 0), (56, 4), (57, 2), (58, 2)] {
        let mut bad = saved.clone();
        bad[i] = value;
        assert!(CoverScene::restore(&bad).is_err(), "offset {i}");
    }
    let mut bad = saved.clone();
    bad[40..44].copy_from_slice(&f32::NAN.to_le_bytes());
    assert!(CoverScene::restore(&bad).is_err());
    let mut bad = saved;
    bad.push(0);
    assert!(CoverScene::restore(&bad).is_err());
}

#[test]
fn exact_trench_ground_and_enfilade_follow_geometry_and_registration_order() {
    let mut terrain = Terrain::blank(32).unwrap();
    let cells = vec![(-1, -1), (-1, 0), (0, -1), (0, 0)];
    let mut trench = wall(0.0);
    trench.kind = 2;
    trench.dug = true;
    trench.position = Vector3::ZERO;
    trench.trench = [Vector3::X * -4.0, Vector3::X * 4.0];
    assert!(terrain.scene.register(5, trench.clone(), cells.clone()));
    assert!(terrain.scene.in_trench(Vector3::ZERO, 0.05));
    assert!(terrain.scene.in_trench(Vector3::new(0.0, 0.0, 0.669), 0.05));
    assert!(!terrain.scene.in_trench(Vector3::new(0.0, 0.0, 0.671), 0.05));
    assert_eq!(terrain.ground_y(Vector3::ZERO, false), -1.2 + 0.15);
    assert_eq!(terrain.ground_y(Vector3::ZERO, true), 0.06);
    assert!(terrain
        .scene
        .trench_enfiladed(Vector3::ZERO, Vector3::X * 20.0));
    assert!(!terrain
        .scene
        .trench_enfiladed(Vector3::ZERO, Vector3::Z * 20.0));
    let mut crossing = trench.clone();
    crossing.trench = [Vector3::Z * -4.0, Vector3::Z * 4.0];
    assert!(terrain.scene.register(1, crossing, cells.clone()));
    let saved = terrain.checkpoint();
    terrain = Terrain::restore(&saved).unwrap();
    assert!(!terrain
        .scene
        .trench_enfiladed(Vector3::ZERO, Vector3::Z * 20.0));
    terrain.scene.remove(5);
    assert!(terrain.scene.register(5, trench.clone(), cells));
    assert!(terrain
        .scene
        .trench_enfiladed(Vector3::ZERO, Vector3::Z * 20.0));
    terrain.scene.remove(1);
    trench.dug = false;
    assert!(terrain.scene.update(5, trench));
    assert!(!terrain.scene.in_trench(Vector3::ZERO, 0.05));
    assert_eq!(terrain.ground_y(Vector3::ZERO, false), 0.0);
    assert!(terrain
        .scene
        .trench_enfiladed(Vector3::ZERO, Vector3::X * 0.5));
}
