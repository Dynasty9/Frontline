use frontline_core::navigation_grid::NavigationGrid;
use frontline_core::random::SimulationRandom;

#[test]
fn parallel_cluster_builds_preserve_costs_and_order() {
    use frontline_core::navigation_grid::{cluster_costs, ClusterQuery};
    let mut rng = SimulationRandom::new(317);
    let mut solid = vec![0; 128 * 128];
    let mut weight = vec![1.0; solid.len()];
    for i in 0..solid.len() {
        solid[i] = u8::from(rng.randf() < 0.2);
        weight[i] = rng.randf_range(0.3, 4.0);
    }
    let mut clusters = Vec::new();
    for y in (0..128).step_by(16) {
        for x in (0..128).step_by(16) {
            clusters.push(ClusterQuery {
                origin: [x, y],
                entrances: vec![[x, y], [x + 15, y + 15], [x + 7, y], [x, y + 7]],
            });
        }
    }
    let single = cluster_costs(128, 16, &solid, &weight, &clusters, 1).unwrap();
    for workers in [2, 3, 8] {
        assert_eq!(
            cluster_costs(128, 16, &solid, &weight, &clusters, workers).unwrap(),
            single
        );
    }
    clusters[0].entrances.push([-1, 0]);
    assert!(cluster_costs(128, 16, &solid, &weight, &clusters, 8).is_none());
    assert!(cluster_costs(128, 16, &solid[..10], &weight, &[], 8).is_none());
}

#[test]
fn walls_corners_and_weight_edits_change_the_next_route() {
    let mut grid = NavigationGrid::new([-4, 7], 8, 8).unwrap();
    assert_eq!(grid.path([-4, 7], [-2, 9]), vec![[-4, 7], [-3, 8], [-2, 9]]);
    grid.set_solid([-3, 7], true);
    grid.set_solid([-4, 8], true);
    assert!(
        grid.path([-4, 7], [-2, 9]).is_empty(),
        "Cannot cut a blocked corner"
    );
    grid.set_solid([-4, 8], false);
    let path = grid.path([-4, 7], [-2, 9]);
    assert_eq!(path[1], [-4, 8]);
    grid.set_weight([-3, 8], 40.0);
    assert!(!grid.path([-4, 7], [-2, 9]).contains(&[-3, 8]));
    assert!(grid.path([4, 7], [-2, 9]).is_empty());
    assert!(!grid.set_weight([-4, 7], f32::NAN));
    assert!(!grid.set_solid([i32::MIN, i32::MAX], true));
    grid.fill_solid([-100, -100], [200, 200], true);
    assert!(grid.path([-4, 7], [-4, 7]).is_empty());
    grid.set_solid([-4, 7], false);
    assert_eq!(grid.path([-4, 7], [-4, 7]), vec![[-4, 7]]);
}

#[test]
fn restored_terrain_reproduces_routes_after_searches_and_edits() {
    let mut rng = SimulationRandom::new(28371);
    let mut grid = NavigationGrid::new([0, 0], 32, 32).unwrap();
    for y in 0..32 {
        for x in 0..32 {
            grid.set_solid([x, y], rng.randf() < 0.2);
            grid.set_weight([x, y], rng.randf_range(0.3, 6.0));
        }
    }
    for _ in 0..100 {
        grid.path([rng.randi_range(0, 31), 0], [rng.randi_range(0, 31), 31]);
    }
    let checkpoint = grid.checkpoint();
    let mut restored = NavigationGrid::restore(&checkpoint).unwrap();
    for _ in 0..500 {
        let from = [rng.randi_range(0, 31), rng.randi_range(0, 31)];
        let to = [rng.randi_range(0, 31), rng.randi_range(0, 31)];
        assert_eq!(grid.path(from, to), restored.path(from, to));
        assert_eq!(grid.path_cost(from, to), restored.path_cost(from, to));
        let solid = rng.randf() < 0.3;
        grid.set_solid(to, solid);
        restored.set_solid(to, solid);
        let weight = rng.randf_range(0.2, 5.0);
        grid.set_weight(from, weight);
        restored.set_weight(from, weight);
    }
    assert_eq!(grid.checkpoint(), restored.checkpoint());
}

#[test]
fn invalid_checkpoints_and_bulk_edits_are_rejected() {
    let mut grid = NavigationGrid::new([0, 0], 4, 4).unwrap();
    let bytes = grid.checkpoint();
    for size in 0..bytes.len() {
        assert!(NavigationGrid::restore(&bytes[..size]).is_err());
    }
    let mut trailing = bytes.clone();
    trailing.push(0);
    assert!(NavigationGrid::restore(&trailing).is_err());
    for (offset, value) in [(4, 2), (24, 2)] {
        let mut bad = bytes.clone();
        bad[offset] = value;
        assert!(NavigationGrid::restore(&bad).is_err());
    }
    for value in [f32::NAN, f32::INFINITY, -1.0] {
        let mut bad = bytes.clone();
        bad[25..29].copy_from_slice(&value.to_le_bytes());
        assert!(NavigationGrid::restore(&bad).is_err());
        assert!(!grid.load_cells(&[1; 16], &[value; 16]));
        assert_eq!(grid.checkpoint(), bytes);
    }
    assert!(NavigationGrid::new([i32::MAX, 0], 4, 4).is_none());
    assert!(NavigationGrid::new([0, 0], i32::MAX, i32::MAX).is_none());
}
