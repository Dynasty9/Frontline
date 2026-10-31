use frontline_core::hierarchy::{build_all, Hierarchy};

#[test]
fn map_edits_queue_once_and_repair_with_fixed_work_quotas() {
    let mut nav = Hierarchy::new(64, 16).unwrap();
    assert!(build_all(&mut [&mut nav], 2));
    assert!(!nav.route([2, 2], [61, 61], 0, 0.0).is_empty());
    for z in 0..64 {
        assert!(nav.set_cell([31, z], true, 1.0));
    }
    assert_eq!(nav.pending_clusters(), vec![1, 5, 9, 13]);
    assert_eq!(nav.terrain_revision, 64);
    assert!(nav.set_cell([31, 4], true, 1.0));
    assert_eq!(nav.terrain_revision, 64);
    assert!(nav.update(1));
    assert_eq!(nav.pending_clusters(), vec![5, 9, 13]);
    assert!(nav.update(3));
    assert!(!nav.has_work());
    assert!(nav.route([2, 2], [61, 61], 0, 0.0).is_empty());
    nav.set_cell([31, 20], false, 0.3);
    nav.update(1);
    let path = nav.route([2, 2], [61, 61], 0, 0.0);
    assert!(path.contains(&[31, 20]));
    assert_eq!(path.first(), Some(&[2, 2]));
    assert_eq!(path.last(), Some(&[61, 61]));
}

#[test]
fn parallel_builds_and_subsequent_terrain_and_danger_edits_are_repeatable() {
    let mut a = Hierarchy::new(96, 16).unwrap();
    let mut b = Hierarchy::new(96, 16).unwrap();
    for nav in [&mut a, &mut b] {
        for x in 0..96 {
            nav.set_cell([x, 18], false, 0.3);
            if !(20..24).contains(&x) {
                nav.set_cell([x, 50], true, 1.0);
            }
        }
    }
    assert!(build_all(&mut [&mut a], 1));
    assert!(build_all(&mut [&mut b], 8));
    let mut danger = vec![0.0; 36];
    for iteration in 0..25 {
        for (team, care) in [(-1, 0.0), (0, 1.0), (1, 1.0)] {
            assert_eq!(
                a.route([4, 4], [85, 85], team, care),
                b.route([4, 4], [85, 85], team, care)
            );
        }
        danger[iteration % 36] = 0.025 * iteration as f32;
        for nav in [&mut a, &mut b] {
            nav.set_danger(0, &danger);
            nav.set_cell([30, iteration as i32], iteration % 2 == 0, 2.5);
            nav.update(1);
        }
        assert_eq!(a.counts(), b.counts());
        assert_eq!(a.danger_revision, b.danger_revision);
    }
}

#[test]
fn local_grid_eviction_preserves_mutations_and_rejects_invalid_input() {
    assert!(Hierarchy::new(0, 16).is_none());
    assert!(Hierarchy::new(4097, 16).is_none());
    assert!(Hierarchy::new(64, 17).is_none());
    let mut nav = Hierarchy::new(512, 32).unwrap();
    nav.set_cell([2, 2], true, 2.5);
    for cluster in 0..130 {
        let cell = [(cluster % 16 * 32) as i32, (cluster / 16 * 32) as i32];
        nav.local_path(cluster, cell, cell);
    }
    assert_eq!(nav.cached_clusters().len(), 128);
    assert!(!nav.cached_clusters().contains(&0));
    assert!(nav.local_path(0, [2, 2], [3, 3]).is_empty());
    assert!(!nav.set_cell([-1, 0], false, 1.0));
    assert!(!nav.set_cell([2, 2], false, f32::NAN));
    assert!(!nav.set_danger(2, &vec![0.0; 256]));
    assert!(!nav.set_danger(0, &[0.0]));
    assert!(nav.local_path(0, [2, 2], [3, 3]).is_empty());
}

#[test]
fn checkpoint_restores_pending_repairs_danger_and_future_route_ties() {
    let mut nav = Hierarchy::new(64, 16).unwrap();
    for z in 0..64 {
        nav.set_cell([31, z], z != 20, 1.4);
    }
    let initial = nav.checkpoint();
    let mut restored = Hierarchy::restore(&initial).unwrap();
    assert!(build_all(&mut [&mut nav], 1));
    assert!(build_all(&mut [&mut restored], 4));
    assert_eq!(nav.checkpoint(), restored.checkpoint());
    for tick in 0..60 {
        if tick % 5 == 0 {
            restored = Hierarchy::restore(&nav.checkpoint()).unwrap();
            // Search history and cache warmth do not belong in an authoritative save.
            restored.local_path(0, [1, 1], [12, 12]);
            assert_eq!(nav.checkpoint(), restored.checkpoint());
        }
        for team in [-1, 0, 1] {
            assert_eq!(
                nav.route([2, 2], [60, 60], team, 1.0),
                restored.route([2, 2], [60, 60], team, 1.0)
            );
        }
        let mut danger = vec![0.0; 16];
        danger[tick % 16] = 1.0 + tick as f32 * 0.01;
        for graph in [&mut nav, &mut restored] {
            graph.set_cell([31, tick as i32], tick % 3 != 0, 0.3);
            graph.set_danger(tick % 2, &danger);
            if tick % 2 == 0 {
                graph.update(1);
            }
        }
        assert_eq!(nav.checkpoint(), restored.checkpoint());
    }
}

#[test]
fn hierarchy_decoder_rejects_truncation_invalid_dimensions_and_foreign_state() {
    let mut nav = Hierarchy::new(16, 8).unwrap();
    build_all(&mut [&mut nav], 1);
    nav.set_cell([7, 1], true, 1.0);
    let bytes = nav.checkpoint();
    for end in (0..bytes.len()).step_by(23) {
        assert!(Hierarchy::restore(&bytes[..end]).is_err());
    }
    assert!(Hierarchy::restore(&bytes[..bytes.len() - 1]).is_err());
    for (offset, value) in [(4, 2), (8, 0), (12, 3), (16, 2), (53, 2)] {
        let mut bad = bytes.clone();
        bad[offset] = value;
        assert!(Hierarchy::restore(&bad).is_err(), "offset {offset}");
    }
    for offset in [17, 25, 33, 41, 57 + 16 * 16 * 5] {
        let mut bad = bytes.clone();
        bad[offset..offset + 8].copy_from_slice(&u64::MAX.to_le_bytes());
        assert!(Hierarchy::restore(&bad).is_err(), "counter offset {offset}");
    }
    let mut bad = bytes;
    bad.push(0);
    assert!(Hierarchy::restore(&bad).is_err());
}
