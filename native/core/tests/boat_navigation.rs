use frontline_core::boat_navigation::{BoatNavigation, LEVEL};
use frontline_core::vector::Vector3;

fn water(side: usize) -> BoatNavigation {
    BoatNavigation::new(side, &vec![0; side * side], &vec![1.0; side * side]).unwrap()
}

#[test]
fn terrain_import_blocks_partial_land_and_bridge_decks() {
    use frontline_core::terrain::{Terrain, BASE, SHALLOW, WATER};
    let mut layers = std::array::from_fn(|_| vec![0; 16 * 16]);
    layers[BASE].fill(WATER);
    layers[BASE][4 * 16 + 4] = SHALLOW;
    layers[BASE][6 * 16 + 6] = 0;
    let terrain = Terrain::new(16, layers, vec![0.0; 32 * 32]).unwrap();
    let mut decks = vec![0; 16 * 16];
    decks[8 * 16 + 8] = 1;
    let n = BoatNavigation::from_terrain(&terrain, &decks).unwrap();
    assert!(n.open(Vector3::new(-3.0, 0.0, -3.0)));
    assert!(!n.open(Vector3::new(-1.0, 0.0, -1.0)));
    assert!(!n.open(Vector3::new(1.0, 0.0, 1.0)));
    assert!(n.open(Vector3::new(3.0, 0.0, 3.0)));
    assert!(BoatNavigation::from_terrain(&terrain, &[]).is_err());
}

#[test]
fn open_water_paths_keep_six_metre_waypoints_and_the_last_cell() {
    let mut n = water(32);
    let from = Vector3::new(-25.0, 18.0, -25.0);
    let to = Vector3::new(25.0, -3.0, -25.0);
    let path = n.path(from, to);
    assert_eq!(path.first().unwrap(), &Vector3::new(-25.0, LEVEL, -25.0));
    assert_eq!(path.last().unwrap(), &Vector3::new(25.0, LEVEL, -25.0));
    assert_eq!(path.len(), 10);
    assert!(path.windows(2).all(|p| (p[1].x - p[0].x) <= 6.0));
    assert_eq!(n.body(from), 0);
}

#[test]
fn disconnected_water_stays_on_its_own_bank() {
    let side = 256;
    let solid: Vec<_> = (0..side * side)
        .map(|i| u8::from((120..136).contains(&(i % side))))
        .collect();
    let mut n = BoatNavigation::new(side, &solid, &vec![1.0; side * side]).unwrap();
    assert_eq!(n.body(Vector3::NEG_X * 100.0), 0);
    assert_eq!(n.body(Vector3::X * 100.0), 1);
    assert_eq!(n.body(Vector3::ZERO), -1);
    let a = Vector3::NEG_X * 100.0;
    assert!(n.path(a, Vector3::X * 240.0).is_empty());
    let p = n.path(a, Vector3::X * 100.0);
    assert!(!p.is_empty());
    assert!(p.iter().all(|&p| n.body(p) == 0));
}

#[test]
fn hull_width_checks_both_sides_and_shore_search_keeps_tie_order() {
    let solid: Vec<_> = (0..32 * 32).map(|i| u8::from(i % 32 != 16)).collect();
    let n = BoatNavigation::new(32, &solid, &vec![1.0; 32 * 32]).unwrap();
    let a = Vector3::new(1.0, 0.0, -20.0);
    let b = Vector3::new(1.0, 0.0, 20.0);
    assert!(n.line(a, b, 0.0));
    assert!(!n.line(a, b, 2.0));
    assert_eq!(
        n.nearest(Vector3::new(5.0, 0.0, 0.0), 4.0, -1),
        Some(Vector3::new(1.0, LEVEL, 1.0))
    );
    assert!(n.nearest(Vector3::new(5.0, 0.0, 0.0), 2.0, -1).is_none());
    let mut blocked = vec![0; 64];
    blocked[4 * 8 + 4] = 1;
    let n = BoatNavigation::new(8, &blocked, &vec![1.0; 64]).unwrap();
    assert_eq!(
        n.nearest(Vector3::ONE, 2.0, -1),
        Some(Vector3::new(1.0, LEVEL, -1.0))
    );
}

#[test]
fn shallow_water_costs_and_saved_routes_are_retained() {
    let mut weight = vec![1.0; 32 * 32];
    for z in 14..18 {
        for x in 10..22 {
            weight[z * 32 + x] = 5.0;
        }
    }
    let mut n = BoatNavigation::new(32, &vec![0; 32 * 32], &weight).unwrap();
    let a = Vector3::new(-29.0, 0.0, 1.0);
    let b = Vector3::new(29.0, 0.0, 1.0);
    let path = n.path(a, b);
    assert!(path.iter().any(|p| p.z.abs() > 3.0));
    let bytes = n.checkpoint();
    let mut restored = BoatNavigation::restore(&bytes).unwrap();
    assert_eq!(restored.checkpoint(), bytes);
    assert_eq!(restored.path(a, b), path);
    assert_eq!(restored.path(b, a), n.path(b, a));
}

#[test]
fn invalid_grids_queries_and_checkpoints_fail_closed() {
    assert!(BoatNavigation::new(2049, &[], &[]).is_err());
    assert!(BoatNavigation::new(2, &[0; 3], &[1.0; 4]).is_err());
    assert!(BoatNavigation::new(2, &[2; 4], &[1.0; 4]).is_err());
    assert!(BoatNavigation::new(2, &[0; 4], &[f32::NAN; 4]).is_err());
    let mut n = water(8);
    let bytes = n.checkpoint();
    assert!(!n.open(Vector3::NAN));
    assert!(!n.line(Vector3::ZERO, Vector3::ONE, -1.0));
    assert!(n.path(Vector3::NAN, Vector3::ZERO).is_empty());
    assert!(n.nearest(Vector3::ZERO, f64::INFINITY, -1).is_none());
    assert_eq!(n.checkpoint(), bytes);
    for len in 0..bytes.len() {
        assert!(BoatNavigation::restore(&bytes[..len]).is_err());
    }
    let mut extra = bytes.clone();
    extra.push(0);
    assert!(BoatNavigation::restore(&extra).is_err());
    extra = bytes;
    extra[8..12].copy_from_slice(&7u32.to_le_bytes());
    assert!(BoatNavigation::restore(&extra).is_err());
}
