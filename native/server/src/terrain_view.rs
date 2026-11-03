//! Absolute surface tiles survive lost effects, late joins and replay seeks.
use frontline_core::{
    state_codec::Writer,
    terrain::{Terrain, BASE, CRATER, DRES, WATER},
    vector::Vector3,
};
use std::{
    collections::{BTreeMap, BTreeSet},
    sync::Arc,
};

pub const TILE: usize = 32;

pub fn heights(t: &Terrain) -> Vec<u8> {
    t.heights.iter().flat_map(|v| v.to_le_bytes()).collect()
}

pub fn tile(t: &Terrain, x: usize, z: usize) -> Result<Vec<u8>, &'static str> {
    if x >= t.n || z >= t.n || x % TILE != 0 || z % TILE != 0 {
        return Err("invalid surface tile");
    }
    let width = TILE.min(t.n - x);
    let height = TILE.min(t.n - z);
    let mut w = Writer::new(b"FLVT\x01\0\0\0");
    for value in [x, z, width, height] {
        w.u32(value as u32);
    }
    for layer in [BASE, CRATER] {
        w.u32((width * height) as u32);
        for row in z..z + height {
            w.0.extend_from_slice(&t.layers[layer][row * t.n + x..row * t.n + x + width]);
        }
    }
    w.u32((width * height * DRES * DRES * 4) as u32);
    for row in z * DRES..(z + height) * DRES {
        let start = row * t.n * DRES + x * DRES;
        for &value in &t.heights[start..start + width * DRES] {
            w.f32(value);
        }
    }
    Ok(w.0)
}

#[derive(Default)]
pub struct Surface {
    pub tiles: BTreeMap<(usize, usize), Arc<Vec<u8>>>,
}
impl Surface {
    pub fn update(
        &mut self,
        t: &Terrain,
        blasts: &[(Vector3, f64)],
    ) -> Result<Vec<Arc<Vec<u8>>>, &'static str> {
        let mut changed = BTreeSet::new();
        for &(position, size) in blasts {
            if !position.is_finite()
                || !size.is_finite()
                || size < 0.55
                || t.layers[BASE][t.index(position)] >= WATER
                || f64::from(position.y) > t.landform.height(position) + 1.6
            {
                continue;
            }
            // Include the entire thrown-up rim, with a sample of padding at tile edges.
            let radius = (0.6 + 0.8 * size) * 1.9 + 1.0;
            let bound = |v: f64| (v.floor().clamp(0.0, (t.n - 1) as f64) as usize) / TILE;
            for z in bound(f64::from(position.z) + t.half() - radius)
                ..=bound(f64::from(position.z) + t.half() + radius)
            {
                for x in bound(f64::from(position.x) + t.half() - radius)
                    ..=bound(f64::from(position.x) + t.half() + radius)
                {
                    changed.insert((x * TILE, z * TILE));
                }
            }
        }
        let mut out = Vec::with_capacity(changed.len());
        for key in changed {
            let bytes = Arc::new(tile(t, key.0, key.1)?);
            self.tiles.insert(key, bytes.clone());
            out.push(bytes);
        }
        Ok(out)
    }
}
