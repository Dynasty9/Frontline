use frontline_core::terrain::*;
use frontline_core::vector::Vector3;
use glam::Vec2;

#[test]
fn terrain_edits_and_pending_repairs_resume_in_order() {
    let mut terrain = Terrain::blank(64).unwrap();
    terrain.paint_box(Vector3::ZERO, Vec2::new(6.0, 3.0), 0.4, MUD);
    terrain.tree(Vector3::new(-4.0, 0.0, 2.0), 1);
    terrain.paint_roads(
        &[vec![
            Vector3::new(-24.0, 0.0, -18.0),
            Vector3::new(19.0, 0.0, 22.0),
        ]],
        2.4,
        true,
    );
    terrain.crater(Vector3::new(2.0, 0.0, 1.0), 3.0);
    terrain.queue_rect([-10.0, -10.0, 4.0, 4.0]);
    terrain.queue_rect([-4.0, -4.0, 10.0, 10.0]);
    assert!(terrain.finish_cover(&vec![[0, 0, 0, 3, 2]; 19]));
    let encoded = terrain.checkpoint();
    let mut restored = Terrain::restore(&encoded).unwrap();
    assert_eq!(restored.checkpoint(), encoded);
    for tick in 0..25 {
        let p = Vector3::new(tick as f32 - 10.0, 0.0, 3.0);
        assert_eq!(terrain.tree(p, -1), restored.tree(p, -1));
        assert_eq!(terrain.crater(p, 1.0), restored.crater(p, 1.0));
        terrain.queue_rect([-8.0, 0.0, tick as f64 - 5.0, 6.0]);
        restored.queue_rect([-8.0, 0.0, tick as f64 - 5.0, 6.0]);
        assert_eq!(terrain.pending(53), restored.pending(53));
        let output = vec![[1, 0, 0, 2, OMNI]; terrain.pending(53).len()];
        assert!(terrain.finish_cover(&output));
        assert!(restored.finish_cover(&output));
        assert_eq!(terrain.checkpoint(), restored.checkpoint());
        assert_eq!(terrain.deform_at(p), restored.deform_at(p));
    }
}

#[test]
fn terrain_priorities_water_ground_and_directional_cover() {
    let mut t = Terrain::blank(16).unwrap();
    let p = Vector3::new(0.5, 0.0, 0.5);
    let i = t.index(p);
    t.layers[BASE][i] = ROAD;
    t.layers[WOODS][i] = 1;
    t.refresh_ground(&[i as u32]);
    assert_eq!(t.kind(p), ROAD);
    assert_eq!(t.cover(p), -1);
    assert_eq!(t.speed(p, true, true), 1.35);
    t.layers[COVER][i] = 3;
    t.layers[DIRECTION][i] = 0;
    assert_eq!(t.cover_vs(p, p + Vector3::X), 2);
    assert_eq!(t.cover_vs(p, p - Vector3::X), -1);
    t.layers[CRATER][i] = 1;
    t.layers[RUBBLE][i] = 1;
    t.layers[TRENCH][i] = 1;
    t.layers[NETTED][i] = 1;
    assert_eq!(t.kind(p), 6);
    assert_eq!(t.concealment(p), 0.35);
    assert_eq!(t.speed(p, true, false), 0.12);
    t.layers[BASE][i] = WATER;
    assert_eq!(t.kind(p), WATER);
    assert_eq!(t.concealment(p), 0.35);
    let before = t.checkpoint();
    assert_eq!(t.crater(p, 4.0), (vec![], None));
    assert_eq!(t.checkpoint(), before);
    assert_eq!(t.index(Vector3::splat(-1000.0)), 0);
    assert_eq!(t.index(Vector3::splat(1000.0)), 255);
}

#[test]
fn crater_thresholds_edges_and_overlaps() {
    let mut t = Terrain::blank(32).unwrap();
    assert_eq!(t.crater(Vector3::ZERO, 0.54), (vec![], None));
    let (cells, rect) = t.crater(Vector3::ZERO, 0.55);
    assert!(cells.is_empty());
    assert!(rect.is_some());
    let depth = t.deform_at(Vector3::ZERO);
    assert!(depth < 0.0);
    t.crater(Vector3::ZERO, 0.55);
    assert!(t.deform_at(Vector3::ZERO) < depth);
    assert_eq!(t.crater(Vector3::new(0.0, 1.6, 0.0), 4.0), (vec![], None));
    assert_eq!(
        t.crater(Vector3::new(1000.0, 0.0, 1000.0), 4.0),
        (vec![], None)
    );
    assert!(t.crater(Vector3::new(15.9, 0.0, 15.9), 4.0).1.is_some());
    assert!(t.heights.iter().all(|h| (-1.4..=0.55).contains(h)));
}

#[test]
fn terrain_decoder_rejects_invalid_layers_heights_and_queues() {
    let mut t = Terrain::blank(4).unwrap();
    t.queue_rect([-1.0, -1.0, 1.0, 1.0]);
    let bytes = t.checkpoint();
    for end in 0..bytes.len() {
        assert!(Terrain::restore(&bytes[..end]).is_err());
    }
    for (offset, value) in [
        (4, 1),
        (8, 0),
        (20, 2),
        (25, 9),
        (25 + 4 * 20, 4),
        (25 + 5 * 20, 9),
    ] {
        let mut bad = bytes.clone();
        bad[offset] = value;
        assert!(Terrain::restore(&bad).is_err(), "offset {offset}");
    }
    let mut bad = bytes.clone();
    bad[205..209].copy_from_slice(&f32::NAN.to_le_bytes());
    assert!(Terrain::restore(&bad).is_err());
    let mut bad = bytes.clone();
    let last = 465 + (t.pending(usize::MAX).len() - 1) * 4;
    bad[last..last + 4].copy_from_slice(&100_u32.to_le_bytes());
    assert!(Terrain::restore(&bad).is_err());
    let mut bad = bytes.clone();
    bad[last..last + 4].copy_from_slice(&bytes[last - 4..last]);
    assert!(Terrain::restore(&bad).is_err());
    let mut bad = bytes;
    bad.push(0);
    assert!(Terrain::restore(&bad).is_err());
    assert!(Terrain::blank(0).is_none());
    assert!(Terrain::blank(3073).is_none());
}
