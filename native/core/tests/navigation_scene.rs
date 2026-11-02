use frontline_core::navigation_scene::NavigationScene;
use frontline_core::structure::{Part, Structure};
use frontline_core::terrain::{Terrain, BASE, WATER};
use frontline_core::vector::Vector3;

fn obstacle(id: u32, kind: u8) -> Structure {
    Structure {
        id,
        kind: "sandbags".into(),
        built: true,
        parts: vec![Part {
            position: Vector3::ZERO,
            size: Vector3::new(4.0, 1.0, 1.0),
            yaw: 0.731,
            infantry: kind,
            vehicle: 3,
            cover: true,
            collision: true,
            door: false,
        }],
        ..Default::default()
    }
}

#[test]
fn overlapping_parts_keep_ownership_until_the_last_wall_is_removed() {
    let terrain = Terrain::blank(32).unwrap();
    let mut nav = NavigationScene::new(&terrain, &[], 16).unwrap();
    let mut low = obstacle(1, 1);
    low.parts.push(low.parts[0]);
    let mut high = obstacle(2, 3);
    nav.add_structure(&mut low, &terrain, &[]).unwrap();
    assert!(low.nav_cells.len() > nav.obstacles().len());
    nav.add_structure(&mut high, &terrain, &[]).unwrap();
    let cell = terrain.index(Vector3::new(0.5, 0.0, 0.5));
    assert_eq!(nav.planner.cell_state(cell), Some([3, 3, 0]));
    assert!(nav.finalize(2));
    high.gone = true;
    nav.remove_structure(&mut high, &terrain, &[]).unwrap();
    assert!(high.nav_cells.is_empty());
    assert_eq!(nav.planner.cell_state(cell), Some([1, 3, 0]));
    assert!(nav.infantry.has_work());
    assert!(!nav.vehicles.has_work());
    nav.remove_structure(&mut low, &terrain, &[]).unwrap();
    assert!(nav.obstacles().is_empty());
    assert_eq!(nav.planner.cell_state(cell), Some([0, 0, 0]));
    assert!(nav.vehicles.has_work());
    assert!(nav.update_hierarchy(100));
    assert!(!nav.infantry.has_work() && !nav.vehicles.has_work());
}

#[test]
fn water_bridges_and_vehicle_rim_survive_obstacle_removal() {
    let mut terrain = Terrain::blank(32).unwrap();
    terrain.layers[BASE].fill(WATER);
    let mut deck = vec![0; 32 * 32];
    let center = terrain.index(Vector3::ZERO);
    deck[center] = 1;
    deck[center - 1] = 2;
    let mut nav = NavigationScene::new(&terrain, &deck, 16).unwrap();
    assert_eq!(nav.planner.cell_state(center), Some([0, 0, 0]));
    assert_eq!(nav.planner.cell_state(center - 1), Some([3, 3, 0]));
    let mut wall = obstacle(1, 3);
    nav.add_structure(&mut wall, &terrain, &deck).unwrap();
    nav.remove_structure(&mut wall, &terrain, &deck).unwrap();
    assert_eq!(nav.planner.cell_state(center), Some([0, 0, 0]));
    assert_eq!(nav.planner.cell_state(center - 1), Some([3, 3, 0]));
    terrain.layers[BASE][0] = 0;
    nav.terrain_changed(0, &terrain, &deck).unwrap();
    assert!(!nav.infantry.is_solid([0, 0]));
    assert!(nav.vehicles.is_solid([0, 0]));
    deck[center] = 0;
    nav.terrain_changed(center, &terrain, &deck).unwrap();
    assert!(nav.infantry.is_solid([16, 16]));
}

#[test]
fn overlapping_heat_counts_saturate_and_only_queue_changed_costs() {
    let terrain = Terrain::blank(32).unwrap();
    let mut nav = NavigationScene::new(&terrain, &[], 16).unwrap();
    assert!(nav.finalize(1));
    let p = Vector3::new(0.5, 0.0, 0.5);
    let center = terrain.index(p);
    nav.stamp_heat(p, 0.0, 1, &terrain, &[]).unwrap();
    let revision = nav.infantry.terrain_revision;
    assert_eq!(revision, 1);
    for _ in 0..300 {
        nav.stamp_heat(p, 0.0, 1, &terrain, &[]).unwrap();
    }
    assert_eq!(nav.planner.cell_state(center), Some([0, 0, 255]));
    assert_eq!(nav.infantry.terrain_revision, revision);
    for _ in 0..300 {
        nav.stamp_heat(p, 0.0, -1, &terrain, &[]).unwrap();
    }
    assert_eq!(nav.planner.cell_state(center), Some([0, 0, 0]));
    assert_eq!(nav.infantry.terrain_revision, revision + 1);
}

#[test]
fn checkpoint_resumes_pending_repairs_routes_and_owned_cells() {
    for cluster in [16, 32] {
        let terrain = Terrain::blank(64).unwrap();
        let mut nav = NavigationScene::new(&terrain, &[], cluster).unwrap();
        assert!(nav.finalize(2));
        let mut wall = obstacle(1, 3);
        nav.add_structure(&mut wall, &terrain, &[]).unwrap();
        nav.stamp_heat(Vector3::new(10.3, 0.0, -9.7), 4.7, 1, &terrain, &[])
            .unwrap();
        let mut resumed = NavigationScene::restore(&nav.checkpoint()).unwrap();
        assert_eq!(nav.checkpoint(), resumed.checkpoint());
        for tick in 0..12 {
            assert!(nav.update_hierarchy(1) && resumed.update_hierarchy(1));
            let from = Vector3::new(-20.3 + tick as f32 * 0.1, 0.0, -25.7);
            let to = Vector3::new(22.7, 0.0, 20.3);
            let expected = nav.planner.find_path(
                &mut nav.infantry,
                from,
                to,
                false,
                0,
                1.0,
                false,
                frontline_core::traversal::Ground::new(&terrain, &[]),
            );
            assert_eq!(
                expected,
                resumed.planner.find_path(
                    &mut resumed.infantry,
                    from,
                    to,
                    false,
                    0,
                    1.0,
                    false,
                    frontline_core::traversal::Ground::new(&terrain, &[])
                )
            );
            assert_eq!(nav.checkpoint(), resumed.checkpoint());
        }
        nav.remove_structure(&mut wall.clone(), &terrain, &[])
            .unwrap();
        resumed.remove_structure(&mut wall, &terrain, &[]).unwrap();
        assert_eq!(nav.checkpoint(), resumed.checkpoint());
    }
}

#[test]
fn invalid_edits_and_checkpoints_do_not_partly_change_the_scene() {
    let terrain = Terrain::blank(16).unwrap();
    let mut nav = NavigationScene::new(&terrain, &[], 16).unwrap();
    let before = nav.checkpoint();
    let mut wall = obstacle(1, 3);
    wall.parts[0].size.x = -1.0;
    assert!(nav.add_structure(&mut wall, &terrain, &[]).is_err());
    assert!(wall.nav_cells.is_empty());
    wall.nav_cells.push(256);
    assert!(nav.remove_structure(&mut wall, &terrain, &[]).is_err());
    assert_eq!(wall.nav_cells, [256]);
    assert!(nav.terrain_changed(256, &terrain, &[]).is_err());
    for (p, r, d) in [
        (Vector3::NAN, 2.0, 1),
        (Vector3::ZERO, -1.0, 1),
        (Vector3::ZERO, 1.0, 0),
    ] {
        assert!(nav.stamp_heat(p, r, d, &terrain, &[]).is_err());
    }
    assert_eq!(before, nav.checkpoint());
    for end in [0, 8, 12, before.len() - 1] {
        assert!(NavigationScene::restore(&before[..end]).is_err());
    }
    let mut bad = before.clone();
    bad.push(0);
    assert!(NavigationScene::restore(&bad).is_err());
    bad = before;
    bad[4] = 3;
    assert!(NavigationScene::restore(&bad).is_err());
    assert!(NavigationScene::new(&terrain, &[0], 16).is_err());
    assert!(NavigationScene::new(&terrain, &[], 4).is_err());
}

#[test]
fn feet_can_enter_planning_padding_but_not_a_wall_or_diagonal_corner() {
    let terrain = Terrain::blank(32).unwrap();
    let mut nav = NavigationScene::new(&terrain, &[], 16).unwrap();
    let mut wall = obstacle(1, 3);
    wall.parts[0].yaw = 0.;
    wall.parts[0].size = Vector3::new(0.6, 2., 4.);
    wall.position = Vector3::new(0.6, 0., 0.);
    nav.add_structure(&mut wall, &terrain, &[]).unwrap();
    let a = Vector3::new(-0.5, 0., 0.5);
    let padding = Vector3::new(0.1, 0., 0.5);
    assert_eq!(nav.planner.kind_at(padding, false), 3);
    assert!(nav.planner.can_step(a, padding, false, &terrain, &[]));
    assert!(!nav
        .planner
        .can_step(a, Vector3::new(1.5, 0., 0.5), false, &terrain, &[]));
    let restored = NavigationScene::restore(&nav.checkpoint()).unwrap();
    assert!(restored.planner.can_step(a, padding, false, &terrain, &[]));
    assert!(!restored
        .planner
        .can_step(a, Vector3::new(1.5, 0., 0.5), false, &terrain, &[]));
    nav.remove_structure(&mut wall, &terrain, &[]).unwrap();
    assert!(nav
        .planner
        .can_step(a, Vector3::new(1.5, 0., 0.5), false, &terrain, &[]));
    nav.planner.set_cell(16 * 32 + 17, 3, 3, 0);
    assert!(!nav.planner.can_step(
        Vector3::new(0.8, 0., 0.8),
        Vector3::new(1.2, 0., 1.2),
        false,
        &terrain,
        &[]
    ));
}

#[test]
fn shallow_labels_do_not_override_depth_and_decks_restore_crossings() {
    let mut terrain = Terrain::blank(32).unwrap();
    terrain.layers[BASE].fill(frontline_core::terrain::SHALLOW);
    terrain.heights.fill(-2.);
    let mut nav = NavigationScene::new(&terrain, &[], 16).unwrap();
    let a = Vector3::new(-4., 0., 0.5);
    let b = Vector3::new(4., 0., 0.5);
    assert!(!nav.planner.can_step(a, b, false, &terrain, &[]));
    assert_eq!(nav.planner.kind_at(b, false), 3);
    let deck = vec![1; 32 * 32];
    for i in 0..32 * 32 {
        nav.terrain_changed(i, &terrain, &deck).unwrap();
    }
    assert!(nav.planner.can_step(a, b, false, &terrain, &deck));
    terrain.heights.fill(-0.85);
    for i in 0..32 * 32 {
        nav.terrain_changed(i, &terrain, &[]).unwrap();
    }
    assert!(nav.planner.can_step(a, b, false, &terrain, &[]));
}

#[test]
fn terrain_selects_three_movement_classes_and_repairs_rotate_fairly() {
    let mut terrain = Terrain::blank(32).unwrap();
    assert!(terrain.set_landform((0..81).map(|i| (i % 9) as f32 * 4. * 0.55).collect()));
    let mut nav = NavigationScene::new(&terrain, &[], 16).unwrap();
    assert!(!nav.infantry.is_solid([16, 16]));
    assert!(nav.vehicles.is_solid([16, 16]));
    assert!(!nav.tracked.is_solid([16, 16]));
    assert!(nav.finalize(1));
    let mut wall = obstacle(1, 3);
    nav.add_structure(&mut wall, &terrain, &[]).unwrap();
    assert!(nav.update_hierarchy(1));
    let mut restored = NavigationScene::restore(&nav.checkpoint()).unwrap();
    for _ in 0..8 {
        assert!(nav.update_hierarchy(1) && restored.update_hierarchy(1));
        assert_eq!(nav.checkpoint(), restored.checkpoint());
    }
}
