use frontline_core::{
    formation::FormationGround, perception::PerceptionSearch, route_graph::RouteGraph,
    vector::Vector3,
};

#[test]
fn perception_orders_equal_distance_by_id_and_keeps_seven() {
    let mut search = PerceptionSearch::default();
    let mut meta = Vec::new();
    let mut values = Vec::new();
    for id in (1..=12).rev() {
        meta.extend([id, 1, 0]);
        values.extend([3.0, 4.0, 1.0]);
    }
    assert!(search.rebuild(&meta, &values));
    assert_eq!(search.nearest(0.0, 0.0, 0, 56.0), vec![1, 2, 3, 4, 5, 6, 7]);
    assert!(search.nearest(0.0, 0.0, 1, 56.0).is_empty());
    assert!(!search.rebuild(&[1], &[]));
    assert!(search.nearest(0.0, 0.0, 0, 56.0).is_empty());
}

#[test]
fn perception_preserves_range_factors_vehicle_range_and_negative_cells() {
    let mut search = PerceptionSearch::default();
    assert!(search.rebuild(
        &[1, 1, 0, 2, 1, 0, 3, 1, 1, 4, -1, 0],
        &[30.0, 0.0, 0.5, -20.0, 0.0, 0.5, 80.0, 0.0, 1.0, 1.0, 0.0, 1.0]
    ));
    assert_eq!(search.nearest(0.0, 0.0, 0, 56.0), vec![2, 3]);
}

#[test]
fn formation_preserves_first_tie_and_occupancy_penalty() {
    let mut formation = FormationGround::default();
    let a = Vector3::new(-1.0, 0.0, 0.0);
    let b = Vector3::new(1.0, 0.0, 0.0);
    assert!(formation.prepare([a, b].into_iter(), &[10.0, 2.0, 10.0, 2.0]));
    assert_eq!(formation.best(Vector3::ZERO), [0.0, 11.4]);
    formation.add_taken(a);
    assert_eq!(formation.best(Vector3::ZERO), [1.0, 11.4]);
    assert!(!formation.prepare([a].into_iter(), &[f64::NAN, 0.0]));
    assert_eq!(formation.best(Vector3::ZERO), [-1.0, -1e9]);
}

#[test]
fn route_graph_survives_cost_edits_deletion_and_slot_reuse() {
    let mut graph = RouteGraph::new();
    for (id, x, z) in [(1, 0.0, 0.0), (2, 1.0, 0.0), (3, 2.0, 0.0), (4, 1.0, 1.0)] {
        graph.add_point(id, Vector3::new(x, 0.0, z), 1.0);
    }
    for (a, b) in [(1, 2), (2, 3), (1, 4), (4, 3)] {
        graph.connect_points(a, b);
    }
    assert_eq!(graph.get_id_path(1, 3), vec![1, 2, 3]);
    graph.set_point_weight_scale(2, 10.0);
    assert_eq!(graph.get_id_path(1, 3), vec![1, 4, 3]);
    graph.remove_point(4);
    assert_eq!(graph.get_id_path(1, 3), vec![1, 2, 3]);
    graph.add_point(5, Vector3::new(1.0, 0.0, 0.5), 1.0);
    graph.connect_points(1, 5);
    graph.connect_points(5, 3);
    assert_eq!(graph.get_id_path(1, 3), vec![1, 5, 3]);
    graph.remove_point(2);
    graph.remove_point(5);
    assert!(graph.get_id_path(1, 3).is_empty());
    assert_eq!(graph.get_id_path(1, 1), vec![1]);
}
