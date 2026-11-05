use frontline_core::{random::SimulationRandom, terrain::Terrain, vector::Vector3};
use glam::Vec2;

pub fn transcript() -> Vec<u8> {
    let mut out = Vec::new();
    for seed in 0..4 {
        let mut t = Terrain::blank(64).unwrap();
        let mut heights = Vec::new();
        for z in 0..17 {
            for x in 0..17 {
                heights.push(
                    (20. + 9. * libm::sin(x as f64 * 0.3 + seed as f64)
                        + 6. * libm::cos(z as f64 * 0.2)) as f32,
                );
            }
        }
        assert!(t.set_landform(heights));
        for z in 0..128 {
            for x in 0..128 {
                let p = Vector3::new(
                    (x as f32 + 0.5) * 0.5 - 32.,
                    0.,
                    (z as f32 + 0.5) * 0.5 - 32.,
                );
                t.heights[z * 128 + x] = t.landform.height(p) as f32;
            }
        }
        let mut rng = SimulationRandom::new(73480 + seed);
        let mut previous = Vec::new();
        for tick in 0..32 {
            let mut p = Vector3::new(rng.randf_range(-28., 28.), 0., rng.randf_range(-28., 28.));
            p.y = t.ground_y(p, false) as f32;
            t.crater(p, 0.6 + tick as f64 * 0.04);
            let saved = t.checkpoint();
            let restored = Terrain::restore(&saved).unwrap();
            assert_eq!(t, restored);
            super::squad_orders::delta(&mut out, &mut previous, saved);
            for state in [&t, &restored] {
                for value in [
                    state.landform.height(p),
                    state.landform.cell_slope(state.index(p)),
                    state.landform.vehicle_slope(state.index(p)),
                    state.ground_y(p, false),
                    state.speed(p, false, false),
                    state.speed(p, true, false),
                    state.speed(p, true, true),
                    state.nav_weight(state.index(p), false),
                    state.nav_weight(state.index(p), true),
                ] {
                    out.extend_from_slice(&value.to_le_bytes());
                }
                out.push(u8::from(state.landform.fits(
                    p,
                    Vec2::new(2., 5.),
                    tick as f64 * 0.1,
                    0.35,
                )));
                for a in [p + Vector3::Y * 3., p + Vector3::X * 12. + Vector3::Y * 0.5] {
                    let hit = state.ray_ground(a, p - Vector3::Y * 3., &[]);
                    out.push(u8::from(hit.is_some()));
                    if let Some(hit) = hit {
                        for value in hit
                            .position
                            .to_array()
                            .into_iter()
                            .chain(hit.normal.to_array())
                            .chain([hit.fraction])
                        {
                            out.extend_from_slice(&value.to_le_bytes());
                        }
                    }
                }
            }
            t = restored;
        }
    }
    out
}
