use frontline_core::water::{Bridge, Pond, River, Water};
use godot::prelude::*;
use std::thread::JoinHandle;

#[derive(GodotClass)]
#[class(base=RefCounted, init)]
struct WaterRaster {
    base: Base<RefCounted>,
    core: Option<Water>,
    loading: Option<JoinHandle<Result<frontline_core::water::GroundLoad, &'static str>>>,
}

impl Drop for WaterRaster {
    fn drop(&mut self) {
        if let Some(worker) = self.loading.take() {
            let _ = worker.join();
        }
    }
}

fn shapes(side: i32, data: VarDictionary) -> Option<Water> {
    let shore = data.get("coast")?.try_to::<VarDictionary>().ok()?;
    let coast = if shore.is_empty() {
        None
    } else {
        Some([
            shore.get("x")?.try_to::<f64>().ok()?,
            shore.get("s")?.try_to::<f64>().ok()?,
        ])
    };
    let river_rows = data.get("rivers")?.try_to::<Array<Variant>>().ok()?;
    let pond_rows = data.get("ponds")?.try_to::<Array<Variant>>().ok()?;
    let ford_rows = data.get("fords")?.try_to::<Array<Variant>>().ok()?;
    let bridge_rows = data.get("bridges")?.try_to::<Array<Variant>>().ok()?;
    if [
        river_rows.len(),
        pond_rows.len(),
        ford_rows.len(),
        bridge_rows.len(),
    ]
    .into_iter()
    .any(|n| n > 4096)
    {
        return None;
    }
    let mut rivers = Vec::new();
    let mut total = 0;
    for row in river_rows.iter_shared() {
        let row = row.try_to::<VarDictionary>().ok()?;
        let points = row.get("pts")?.try_to::<PackedVector3Array>().ok()?;
        total += points.len();
        if total > 65_536 {
            return None;
        }
        rivers.push(River {
            points: points
                .as_slice()
                .iter()
                .copied()
                .map(crate::point)
                .collect(),
            width: row.get("w")?.try_to::<f64>().ok()?,
        });
    }
    let mut ponds = Vec::new();
    for row in pond_rows.iter_shared() {
        let row = row.try_to::<VarDictionary>().ok()?;
        ponds.push(Pond {
            center: crate::point(row.get("c")?.try_to::<Vector3>().ok()?),
            radius: row.get("r")?.try_to::<f64>().ok()?,
            seed: row.get("s")?.try_to::<f64>().ok()?,
        });
    }
    let mut fords = Vec::new();
    for row in ford_rows.iter_shared() {
        fords.push(crate::point(row.try_to::<Vector3>().ok()?));
    }
    let mut bridges = Vec::new();
    for row in bridge_rows.iter_shared() {
        let row = row.try_to::<Array<Variant>>().ok()?;
        if !(3..=4).contains(&row.len()) {
            return None;
        }
        bridges.push(Bridge {
            a: crate::point(row.get(0)?.try_to::<Vector3>().ok()?),
            b: crate::point(row.get(1)?.try_to::<Vector3>().ok()?),
            half_width: row.get(2)?.try_to::<f64>().ok()?,
            quay: row.len() == 4 && row.get(3)?.try_to::<GString>().ok()? == "quay",
        });
    }
    let water = Water {
        side: side as usize,
        coast,
        rivers,
        ponds,
        fords,
        bridges,
    };
    water.valid().then_some(water)
}

#[godot_api]
impl WaterRaster {
    #[func]
    fn configure(&mut self, side: i32, data: VarDictionary) -> bool {
        if self.loading.is_some() {
            return false;
        }
        let Some(water) = shapes(side, data) else {
            return false;
        };
        self.core = Some(water);
        true
    }

    #[func]
    fn checkpoint(&self) -> PackedByteArray {
        self.core
            .as_ref()
            .map_or_else(PackedByteArray::new, |w| w.checkpoint().as_slice().into())
    }

    #[func]
    fn restore(&mut self, data: PackedByteArray) -> bool {
        if self.loading.is_some() {
            return false;
        }
        let Ok(water) = Water::restore(data.as_slice()) else {
            return false;
        };
        self.core = Some(water);
        true
    }

    #[func]
    fn paint(&self, mut base: PackedByteArray, view: bool) -> Array<Variant> {
        let Some(water) = &self.core else {
            return Array::new();
        };
        let Ok(output) = water.paint(base.as_mut_slice(), view) else {
            godot_error!("Invalid water terrain");
            return Array::new();
        };
        let deck: PackedByteArray = output.deck.as_slice().into();
        let mask: PackedByteArray = output.mask.as_slice().into();
        let changed: PackedInt32Array = output.changed.into_iter().map(|i| i as i32).collect();
        varray![&base, &deck, &mask, &changed]
    }

    #[func]
    fn carve(&self, mut heights: PackedFloat32Array, listing: bool) -> Array<Variant> {
        let Some(water) = &self.core else {
            return Array::new();
        };
        let Ok(changed) = water.carve(heights.as_mut_slice(), listing) else {
            godot_error!("Invalid water heights");
            return Array::new();
        };
        let changed: PackedInt32Array = changed.into_iter().map(|i| i as i32).collect();
        varray![&heights, &changed]
    }

    #[func]
    fn coast_x(&self, z: f64) -> f64 {
        self.core.as_ref().map_or(f64::INFINITY, |w| w.coast_x(z))
    }

    #[func]
    fn current(&self, point: Vector3) -> Vector3 {
        let flow = self
            .core
            .as_ref()
            .map_or(frontline_core::vector::Vector3::ZERO, |w| {
                w.current(crate::point(point))
            });
        Vector3::new(flow.x, flow.y, flow.z)
    }

    #[func]
    fn in_bridge(&self, x: f64, z: f64, pad: f64) -> bool {
        self.core.as_ref().is_some_and(|w| w.in_bridge(x, z, pad))
    }

    #[func]
    fn start_loading(
        &mut self,
        layers: Array<Variant>,
        heights: PackedFloat32Array,
        joined: PackedByteArray,
        view: bool,
    ) -> bool {
        if self.loading.is_some() {
            return false;
        }
        let Some(water) = self.core.clone() else {
            return false;
        };
        let Some(terrain) = crate::terrain::ground(water.side as i32, layers, heights) else {
            return false;
        };
        if !joined.is_empty()
            && (joined.len() != water.side * water.side || joined.as_slice().iter().any(|b| *b > 8))
        {
            return false;
        }
        let joined = joined.as_slice().to_vec();
        self.loading = std::thread::Builder::new()
            .name("frontline-ground".into())
            .spawn(move || water.load(terrain, &joined, view))
            .ok();
        self.loading.is_some()
    }

    #[func]
    fn loading_ready(&self) -> bool {
        self.loading.as_ref().is_some_and(|job| job.is_finished())
    }

    #[func]
    fn finish_loading(&mut self) -> Array<Variant> {
        let Some(job) = self.loading.take() else {
            return Array::new();
        };
        let Ok(Ok(output)) = job.join() else {
            godot_error!("Water loading failed");
            return Array::new();
        };
        let base: PackedByteArray = output.terrain.layers[frontline_core::terrain::BASE]
            .as_slice()
            .into();
        let cover: PackedByteArray = output.terrain.layers[frontline_core::terrain::COVER]
            .as_slice()
            .into();
        let direction: PackedByteArray = output.terrain.layers[frontline_core::terrain::DIRECTION]
            .as_slice()
            .into();
        let heights: PackedFloat32Array = output.terrain.heights.as_slice().into();
        let deck: PackedByteArray = output.deck.as_slice().into();
        let mask: PackedByteArray = output.mask.as_slice().into();
        varray![&base, &cover, &direction, &heights, &deck, &mask]
    }
}
