use frontline_core::terrain::{Terrain, BASE, COVER, DIRECTION, ROAD, WATER};
use frontline_core::vector::Vector3;
use frontline_core::water::{Bridge, Pond, River, Water};

fn shapes() -> Water {
    Water {
        side: 64,
        coast: Some([12.0, 7.0]),
        rivers: vec![River {
            points: vec![
                Vector3::new(-10.0, 0.0, -40.0),
                Vector3::new(-12.0, 0.0, 0.0),
                Vector3::new(-8.0, 0.0, 40.0),
            ],
            width: 12.0,
        }],
        ponds: vec![Pond {
            center: Vector3::new(12.0, 0.0, -8.0),
            radius: 12.0,
            seed: 3.2,
        }],
        fords: vec![Vector3::new(-12.0, 0.0, -14.0)],
        bridges: vec![Bridge {
            a: Vector3::new(-25.0, 0.0, 9.0),
            b: Vector3::new(0.0, 0.0, 9.0),
            half_width: 3.0,
            quay: false,
        }],
    }
}

#[test]
fn water_shapes_resume_exact_rasters_currents_and_bridge_queries() {
    let water = shapes();
    let saved = water.checkpoint();
    let restored = Water::restore(&saved).unwrap();
    assert_eq!(water, restored);
    assert_eq!(saved, restored.checkpoint());
    let mut a = vec![WATER; 64 * 64];
    let mut b = a.clone();
    let paint = water.paint(&mut a, true).unwrap();
    assert_eq!(paint, restored.paint(&mut b, true).unwrap());
    assert_eq!(a, b);
    assert!(a.contains(&ROAD));
    assert!(paint.deck.contains(&1));
    assert!(paint.mask.contains(&255));
    let mut a = vec![0.0; 128 * 128];
    let mut b = a.clone();
    assert_eq!(water.carve(&mut a, true), restored.carve(&mut b, true));
    assert_eq!(a, b);
    assert!(a.iter().any(|h| *h < -2.0));
    assert!(a.iter().all(|h| *h <= 0.0));
    assert!(water.in_bridge(-12.0, 9.0, 0.0));
    assert!(!water.in_bridge(-12.0, 12.0, 0.0));
    assert!(water.in_bridge(-12.0, 12.0, 0.6));
    let flow = water.current(Vector3::new(-12.0, 0.0, 0.0));
    assert!(flow.z < 0.0 && flow.length() <= 0.45);
    assert_eq!(flow, restored.current(Vector3::new(-12.0, 0.0, 0.0)));
}

#[test]
fn water_rejects_truncated_or_invalid_state_without_editing_terrain() {
    let mut water = shapes();
    let saved = water.checkpoint();
    for end in 0..saved.len() {
        assert!(Water::restore(&saved[..end]).is_err());
    }
    let mut bad = saved.clone();
    bad.push(0);
    assert!(Water::restore(&bad).is_err());
    bad = saved.clone();
    bad[4] = 2;
    assert!(Water::restore(&bad).is_err());
    water.rivers[0].width = f64::NAN;
    let mut ground = vec![0; 4096];
    assert!(water.paint(&mut ground, true).is_err());
    assert_eq!(ground, vec![0; 4096]);
    assert!(Water::restore(&water.checkpoint()).is_err());
    let mut heights = vec![0.0; 16384];
    assert!(water.carve(&mut heights, false).is_err());
    assert_eq!(heights, vec![0.0; 16384]);
}

#[test]
fn off_map_shapes_empty_rivers_and_overlapping_quays_are_bounded() {
    let mut water = shapes();
    water.coast = Some([1_000_000.0, 0.0]);
    water.rivers = vec![River {
        width: 2.0,
        points: Vec::new(),
    }];
    water.ponds.clear();
    water.bridges[0].a = Vector3::splat(-1_000_000.0);
    water.bridges[0].b = Vector3::splat(-999_999.0);
    let mut ground = vec![0; 4096];
    assert!(water.paint(&mut ground, true).unwrap().changed.is_empty());
    water = shapes();
    let mut quay = water.bridges[0];
    quay.quay = true;
    water.bridges.push(quay);
    let painted = water.paint(&mut ground, true).unwrap();
    for (i, deck) in painted.deck.iter().enumerate() {
        if *deck == 1 {
            assert_eq!(painted.mask[i * 4 + 3], 0);
        }
    }
}

#[test]
fn loading_on_a_rust_worker_keeps_host_overrides_after_water_and_preserves_cover() {
    let water = shapes();
    let mut initial = Terrain::blank(64).unwrap();
    initial.layers[COVER][5] = 3;
    initial.layers[DIRECTION][5] = 4;
    let joined: Vec<_> = (0..4096)
        .map(|i| if i % 3 == 0 { ROAD } else { 0 })
        .collect();
    let mut expected = initial.clone();
    let painted = water.paint(&mut expected.layers[BASE], true).unwrap();
    expected.refresh_ground(&painted.changed);
    for (i, &kind) in joined.iter().enumerate() {
        if expected.layers[BASE][i] != kind {
            expected.layers[BASE][i] = kind;
            expected.refresh_ground(&[i as u32]);
        }
    }
    water.carve(&mut expected.heights, false).unwrap();
    let loaded = std::thread::spawn(move || water.load(initial, &joined, true).unwrap())
        .join()
        .unwrap();
    assert_eq!(loaded.terrain, expected);
    assert_eq!(loaded.deck, painted.deck);
    assert_eq!(loaded.mask, painted.mask);
    assert_eq!(loaded.terrain.layers[COVER][5], 3);
    assert_eq!(loaded.terrain.layers[DIRECTION][5], 4);
    assert!(shapes()
        .load(Terrain::blank(64).unwrap(), &[0; 1], false)
        .is_err());
}
