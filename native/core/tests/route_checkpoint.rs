use frontline_core::route_graph::RouteGraph;
use frontline_core::vector::Vector3;

#[test]
fn restored_routes_preserve_equal_cost_ties_slot_reuse_and_mutations() {
    let mut graph = RouteGraph::new();
    for i in 0..36 {
        graph.add_point(i, Vector3::new((i % 6) as f32, 0.0, (i / 6) as f32), 1.0);
    }
    for i in 0..36 {
        if i % 6 < 5 {
            graph.connect_points(i, i + 1);
        }
        if i < 30 {
            graph.connect_points(i, i + 6);
        }
    }
    graph.set_point_weight_scale(7, 0.3);
    graph.remove_point(7);
    graph.remove_point(22);
    let mut restored = RouteGraph::restore(&graph.checkpoint()).unwrap();
    for edit in 0..30 {
        for start in 0..36 {
            for end in [0, 5, 35] {
                assert_eq!(
                    graph.get_id_path(start, end),
                    restored.get_id_path(start, end)
                );
            }
        }
        for g in [&mut graph, &mut restored] {
            g.add_point(100 + edit, Vector3::new(2.5, 0.0, 2.5), 0.7);
            g.connect_points(100 + edit, 14);
            g.connect_points(100 + edit, 21);
            if edit > 0 {
                g.remove_point(99 + edit);
            }
            g.set_point_weight_scale(edit % 36, 1.3);
        }
        assert_eq!(graph.checkpoint(), restored.checkpoint());
        restored = RouteGraph::restore(&restored.checkpoint()).unwrap();
    }
}

#[test]
fn malformed_route_graphs_do_not_load() {
    let mut graph = RouteGraph::new();
    graph.add_point(1, Vector3::ZERO, 1.0);
    graph.add_point(2, Vector3::X, 1.0);
    graph.connect_points(1, 2);
    let bytes = graph.checkpoint();
    for end in 0..bytes.len() {
        assert!(RouteGraph::restore(&bytes[..end]).is_err());
    }
    for (offset, value) in [(4, 2), (20, 2), (53, 9)] {
        let mut bad = bytes.clone();
        bad[offset] = value;
        assert!(RouteGraph::restore(&bad).is_err());
    }
    let mut bad = bytes.clone();
    bad[16..20].copy_from_slice(&u32::MAX.to_le_bytes());
    assert!(RouteGraph::restore(&bad).is_err());
    let mut bad = bytes.clone();
    bad[8..16].copy_from_slice(&f64::NAN.to_le_bytes());
    assert!(RouteGraph::restore(&bad).is_err());
    let mut bad = bytes;
    bad.push(0);
    assert!(RouteGraph::restore(&bad).is_err());
}
