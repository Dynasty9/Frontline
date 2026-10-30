use frontline_core::terrain::{self, Terrain};
use frontline_core::terrain_cover::{CoverPart, CoverStructure};
use godot::prelude::*;

#[derive(GodotClass)]
#[class(base=RefCounted, init)]
struct TerrainCore {
    base: Base<RefCounted>,
    core: Option<Terrain>,
}

fn valid_point(p: Vector3) -> bool {
    p.is_finite() && p.abs().x.max(p.abs().y).max(p.abs().z) <= 1_000_000.0
}
fn indices(cells: &PackedInt32Array, n: usize) -> Option<Vec<u32>> {
    if cells.len() > n * n * 16
        || cells
            .as_slice()
            .iter()
            .any(|i| *i < 0 || *i as usize >= n * n)
    {
        return None;
    }
    Some(cells.as_slice().iter().map(|i| *i as u32).collect())
}
fn packed(cells: Vec<u32>) -> PackedInt32Array {
    cells.into_iter().map(|i| i as i32).collect()
}

fn ground(n: i32, layers: Array<Variant>, heights: PackedFloat32Array) -> Option<Terrain> {
    if !(2..=3072).contains(&n) || layers.len() != 9 {
        return None;
    }
    let mut planes = std::array::from_fn(|_| Vec::new());
    for (i, value) in layers.iter_shared().enumerate() {
        let plane = value.try_to::<PackedByteArray>().ok()?;
        if plane.len() != n as usize * n as usize {
            return None;
        }
        planes[i] = plane.as_slice().to_vec();
    }
    Terrain::new(n as usize, planes, heights.as_slice().to_vec())
}

#[godot_api]
impl TerrainCore {
    #[func]
    fn configure(&mut self, n: i32, layers: Array<Variant>, heights: PackedFloat32Array) -> bool {
        let Some(core) = ground(n, layers, heights) else {
            return false;
        };
        self.core = Some(core);
        true
    }

    #[func]
    fn replace_ground(&mut self, layers: Array<Variant>, heights: PackedFloat32Array) -> bool {
        let Some(core) = self.core.as_mut() else {
            return false;
        };
        let Some(loaded) = ground(core.n as i32, layers, heights) else {
            return false;
        };
        // Loading the map must retain pending cover work and structure registration order.
        core.layers = loaded.layers;
        core.heights = loaded.heights;
        true
    }

    #[func]
    fn query(&self, p: Vector3, from: Vector3, kind: i32, vehicle: bool, tracked: bool) -> f64 {
        let Some(core) = &self.core else {
            return 0.0;
        };
        if !valid_point(p) || !valid_point(from) {
            return 0.0;
        }
        let p = crate::point(p);
        let from = crate::point(from);
        match kind {
            0 => core.kind(p) as f64,
            1 => core.cover(p) as f64,
            2 => core.cover_vs(p, from) as f64,
            3 => core.speed(p, vehicle, tracked),
            4 => core.hit(p, from),
            5 => {
                if core.layers[terrain::CRATER][core.index(p)] > 0 {
                    0.6
                } else {
                    1.0
                }
            }
            6 => {
                if core.layers[terrain::TRENCH][core.index(p)] > 0 {
                    1.0
                } else {
                    0.0
                }
            }
            7 => core.concealment(p),
            8 => {
                if core.layers[terrain::NETTED][core.index(p)] > 0 {
                    0.5
                } else {
                    1.0
                }
            }
            9 => core.nav_weight(core.index(p), vehicle),
            10 => core.deform_at(p),
            _ => 0.0,
        }
    }

    #[func]
    fn nav_weight(&self, index: i32, vehicle: bool) -> f64 {
        self.core
            .as_ref()
            .filter(|t| index >= 0 && (index as usize) < t.n * t.n)
            .map_or(1.0, |t| t.nav_weight(index as usize, vehicle))
    }

    #[func]
    fn ground_y(&self, p: Vector3, on_deck: bool) -> f64 {
        self.core
            .as_ref()
            .filter(|_| valid_point(p))
            .map_or(0.0, |t| t.ground_y(crate::point(p), on_deck))
    }

    #[func]
    fn in_trench(&self, p: Vector3) -> bool {
        valid_point(p)
            && self
                .core
                .as_ref()
                .is_some_and(|t| t.scene.in_trench(crate::point(p), 0.05))
    }

    #[func]
    fn trench_enfiladed(&self, p: Vector3, from: Vector3) -> bool {
        valid_point(p)
            && valid_point(from)
            && self.core.as_ref().is_some_and(|t| {
                t.scene
                    .trench_enfiladed(crate::point(p), crate::point(from))
            })
    }

    #[func]
    fn rows(&self, cells: PackedInt32Array) -> PackedByteArray {
        let Some(core) = &self.core else {
            return PackedByteArray::new();
        };
        let Some(cells) = indices(&cells, core.n) else {
            return PackedByteArray::new();
        };
        cells.iter().flat_map(|i| core.cell(*i as usize)).collect()
    }

    #[func]
    fn import_rows(
        &mut self,
        cells: PackedInt32Array,
        values: PackedByteArray,
        refresh: bool,
    ) -> bool {
        let Some(core) = self.core.as_mut() else {
            return false;
        };
        let Some(cells) = indices(&cells, core.n) else {
            return false;
        };
        if values.len() != cells.len() * 9 {
            return false;
        }
        let rows: Vec<[u8; 9]> = values
            .as_slice()
            .chunks_exact(9)
            .map(|r| r.try_into().unwrap())
            .collect();
        if rows.iter().any(|r| {
            r[0] > 8
                || r[4] > 3
                || !(r[5] <= 8 || r[5] == 255)
                || [1, 2, 6, 7, 8].iter().any(|i| r[*i] > 1)
        }) {
            return false;
        }
        for (&i, row) in cells.iter().zip(rows) {
            for (layer, value) in core.layers.iter_mut().zip(row) {
                layer[i as usize] = value;
            }
        }
        if refresh {
            core.refresh_ground(&cells);
        }
        true
    }

    #[func]
    fn replace_heights(&mut self, heights: PackedFloat32Array) -> bool {
        let Some(core) = self.core.as_mut() else {
            return false;
        };
        if heights.len() != core.heights.len() || heights.as_slice().iter().any(|v| !v.is_finite())
        {
            return false;
        }
        core.heights.copy_from_slice(heights.as_slice());
        true
    }

    #[func]
    fn heights(&self, rect: Rect2i) -> PackedFloat32Array {
        let Some(core) = &self.core else {
            return PackedFloat32Array::new();
        };
        let n = core.n * terrain::DRES;
        if rect.position.x < 0
            || rect.position.y < 0
            || rect.size.x < 0
            || rect.size.y < 0
            || i64::from(rect.position.x) + i64::from(rect.size.x) > n as i64
            || i64::from(rect.position.y) + i64::from(rect.size.y) > n as i64
        {
            return PackedFloat32Array::new();
        }
        let mut output = Vec::with_capacity(rect.size.x as usize * rect.size.y as usize);
        for z in rect.position.y..rect.position.y + rect.size.y {
            let i = z as usize * n + rect.position.x as usize;
            output.extend_from_slice(&core.heights[i..i + rect.size.x as usize]);
        }
        output.as_slice().into()
    }

    #[func]
    fn paint_box(&mut self, p: Vector3, half: Vector2, yaw: f64, kind: i32) -> PackedInt32Array {
        let Some(core) = self.core.as_mut() else {
            return PackedInt32Array::new();
        };
        if !valid_point(p)
            || !half.is_finite()
            || half.x < 0.0
            || half.y < 0.0
            || half.x > 8192.0
            || half.y > 8192.0
            || !yaw.is_finite()
            || !(0..=8).contains(&kind)
        {
            return PackedInt32Array::new();
        }
        packed(core.paint_box(crate::point(p), glam_point(half), yaw, kind as u8))
    }

    #[func]
    fn tree(&mut self, p: Vector3, delta: i32) -> PackedInt32Array {
        let Some(core) = self.core.as_mut() else {
            return PackedInt32Array::new();
        };
        if !valid_point(p) || !(-1..=1).contains(&delta) {
            return PackedInt32Array::new();
        }
        packed(core.tree(crate::point(p), delta))
    }

    #[func]
    fn nets(
        &mut self,
        p: Vector3,
        radius: f64,
        footprints: PackedVector2Array,
    ) -> PackedInt32Array {
        let Some(core) = self.core.as_mut() else {
            return PackedInt32Array::new();
        };
        if !valid_point(p)
            || !radius.is_finite()
            || !(0.0..=8192.0).contains(&radius)
            || footprints.len() > 4_000_000
            || footprints.len() % 4 != 0
            || footprints.as_slice().iter().any(|v| !v.is_finite())
        {
            return PackedInt32Array::new();
        }
        let footprints: Vec<[frontline_core::terrain_cover::Point2; 4]> = footprints
            .as_slice()
            .chunks_exact(4)
            .map(|s| std::array::from_fn(|i| glam_point(s[i])))
            .collect();
        packed(core.nets(crate::point(p), radius, &footprints))
    }

    #[func]
    fn paint_roads(&mut self, paths: Array<Variant>, width: f64, keep: bool) -> PackedInt32Array {
        let Some(core) = self.core.as_mut() else {
            return PackedInt32Array::new();
        };
        if !width.is_finite() || !(0.0..=512.0).contains(&width) || paths.len() > 16384 {
            return PackedInt32Array::new();
        }
        let mut roads = Vec::new();
        let mut count = 0;
        for road in paths.iter_shared() {
            let Ok(points) = road.try_to::<PackedVector3Array>() else {
                return PackedInt32Array::new();
            };
            count += points.len();
            if count > 1_000_000 || !points.as_slice().iter().all(|p| valid_point(*p)) {
                return PackedInt32Array::new();
            }
            roads.push(points.as_slice().iter().map(|p| crate::point(*p)).collect());
        }
        packed(core.paint_roads(&roads, width, keep))
    }

    #[func]
    fn crater(&mut self, p: Vector3, size: f64) -> VarDictionary {
        let Some(core) = self.core.as_mut() else {
            return Dictionary::new();
        };
        if !valid_point(p) || !size.is_finite() || !(0.0..=1024.0).contains(&size) {
            return Dictionary::new();
        }
        let (cells, rect) = core.crater(crate::point(p), size);
        let rect = rect.map_or(Rect2i::default(), |r| {
            Rect2i::from_components(r[0], r[1], r[2], r[3])
        });
        dict! { "cells" => &packed(cells), "rect" => rect }
    }

    #[func]
    fn queue_rect(&mut self, bounds: PackedFloat64Array) -> bool {
        let Some(core) = self.core.as_mut() else {
            return false;
        };
        if bounds.len() != 4
            || bounds
                .as_slice()
                .iter()
                .any(|v| !v.is_finite() || v.abs() > 1_000_000.0)
        {
            return false;
        }
        core.queue_rect(bounds.as_slice().try_into().unwrap());
        true
    }

    #[func]
    fn pending(&self, budget: i32) -> PackedInt32Array {
        self.core
            .as_ref()
            .map_or_else(PackedInt32Array::new, |core| {
                packed(core.pending(budget.max(0) as usize).to_vec())
            })
    }

    #[func]
    fn pending_count(&self) -> i32 {
        self.core
            .as_ref()
            .map_or(0, |core| core.pending(usize::MAX).len() as i32)
    }

    #[func]
    fn queue_cells(&mut self, cells: PackedInt32Array) -> bool {
        let Some(core) = self.core.as_mut() else {
            return false;
        };
        let Some(cells) = indices(&cells, core.n) else {
            return false;
        };
        core.queue_cells(&cells)
    }

    #[func]
    fn tick_cover(&mut self, budget: i32) -> PackedInt32Array {
        let Some(core) = self.core.as_mut() else {
            return PackedInt32Array::new();
        };
        packed(core.tick_cover(budget.max(0) as usize))
    }

    #[func]
    fn set_structure(
        &mut self,
        id: i64,
        data: VarDictionary,
        cells: PackedInt32Array,
        reindex: bool,
    ) -> bool {
        let Some(core) = self.core.as_mut() else {
            return false;
        };
        if id <= 0 || cells.len() % 2 != 0 || cells.len() > 2_097_152 {
            return false;
        }
        let Some(shape) = cover_shape(&data) else {
            return false;
        };
        if reindex {
            core.scene.register(
                id as u64,
                shape,
                cells
                    .as_slice()
                    .chunks_exact(2)
                    .map(|p| (p[0], p[1]))
                    .collect(),
            )
        } else {
            core.scene.update(id as u64, shape)
        }
    }

    #[func]
    fn remove_structure(&mut self, id: i64) {
        if let Some(core) = self.core.as_mut() {
            core.scene.remove(id as u64);
        }
    }

    #[func]
    fn checkpoint(&self) -> PackedByteArray {
        self.core
            .as_ref()
            .map_or_else(PackedByteArray::new, |core| {
                core.checkpoint().as_slice().into()
            })
    }
    #[func]
    fn restore(&mut self, bytes: PackedByteArray) -> bool {
        let Ok(core) = Terrain::restore(bytes.as_slice()) else {
            return false;
        };
        self.core = Some(core);
        true
    }
}

fn glam_point(p: Vector2) -> frontline_core::terrain_cover::Point2 {
    frontline_core::terrain_cover::Point2::new(p.x, p.y)
}

fn cover_shape(data: &VarDictionary) -> Option<CoverStructure> {
    let positions = data.get("pos")?.try_to::<PackedVector3Array>().ok()?;
    let radii = data.get("rad")?.try_to::<PackedFloat64Array>().ok()?;
    let kinds = data.get("kind")?.try_to::<PackedByteArray>().ok()?;
    let rubble = data.get("rub")?.try_to::<PackedByteArray>().ok()?;
    let dug = data.get("dug")?.try_to::<PackedByteArray>().ok()?;
    let p0 = data.get("p0")?.try_to::<PackedInt32Array>().ok()?;
    let p1 = data.get("p1")?.try_to::<PackedInt32Array>().ok()?;
    let centers = data.get("wc")?.try_to::<PackedVector3Array>().ok()?;
    let parts = data.get("pf")?.try_to::<PackedFloat64Array>().ok()?;
    let obb = data.get("obb")?.try_to::<PackedVector2Array>().ok()?;
    let seg = data.get("seg")?.try_to::<PackedVector3Array>().ok()?;
    let count = positions.len();
    if count != 1
        || [
            radii.len(),
            kinds.len(),
            rubble.len(),
            dug.len(),
            p0.len(),
            p1.len(),
        ]
        .iter()
        .any(|n| *n != count)
        || obb.len() != count * 5
        || seg.len() != count * 2
        || parts.len() != centers.len() * 5
        || centers.len() > 4096
    {
        return None;
    }
    let mut structures = Vec::new();
    for i in 0..count {
        let begin = p0[i];
        let end = p1[i];
        if begin < 0
            || end < begin
            || end as usize > centers.len()
            || end - begin > 4096
            || rubble[i] > 1
            || dug[i] > 1
        {
            return None;
        }
        let mut shape_parts = Vec::new();
        for j in begin as usize..end as usize {
            let level = parts[j * 5 + 4];
            if level != 1.0 && level != 2.0 {
                return None;
            }
            shape_parts.push(CoverPart {
                center: crate::point(centers[j]),
                cosine: parts[j * 5],
                sine: parts[j * 5 + 1],
                half_x: parts[j * 5 + 2],
                half_z: parts[j * 5 + 3],
                level: level as i32,
            });
        }
        structures.push(CoverStructure {
            position: crate::point(positions[i]),
            radius: radii[i],
            kind: kinds[i],
            rubble: rubble[i] != 0,
            dug: dug[i] != 0,
            parts: shape_parts,
            footprint: std::array::from_fn(|j| glam_point(obb[i * 5 + j])),
            trench: [crate::point(seg[i * 2]), crate::point(seg[i * 2 + 1])],
        });
    }
    structures.pop()
}
