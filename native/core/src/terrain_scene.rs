use crate::state_codec::{Reader, Writer};
use crate::terrain::Terrain;
use crate::terrain_cover::{CoverLayout, CoverPart, CoverStructure};
use glam::Vec2;
use std::collections::{BTreeMap, BTreeSet};

#[derive(Clone, Debug, PartialEq)]
struct Entry {
    order: u64,
    shape: CoverStructure,
    cells: Vec<(i32, i32)>,
}

#[derive(Clone, Debug, PartialEq)]
pub struct CoverScene {
    entries: BTreeMap<u64, Entry>,
    buckets: BTreeMap<(i32, i32), Vec<u64>>,
    next_order: u64,
    references: usize,
    parts: usize,
}

impl Default for CoverScene {
    fn default() -> Self {
        Self {
            entries: BTreeMap::new(),
            buckets: BTreeMap::new(),
            next_order: 1,
            references: 0,
            parts: 0,
        }
    }
}

fn valid(shape: &CoverStructure) -> bool {
    shape.position.is_finite()
        && shape.position.abs().max_element() <= 1_000_000.0
        && shape.radius.is_finite()
        && (0.0..=8192.0).contains(&shape.radius)
        && shape.kind <= 3
        && shape.parts.len() <= 4096
        && shape.footprint.iter().all(|v| v.is_finite())
        && shape.trench.iter().all(|v| v.is_finite())
        && shape.parts.iter().all(|p| {
            p.center.is_finite()
                && p.cosine.is_finite()
                && p.sine.is_finite()
                && p.half_x.is_finite()
                && p.half_x >= 0.0
                && p.half_z.is_finite()
                && p.half_z >= 0.0
                && (1..=2).contains(&p.level)
        })
}

impl CoverScene {
    pub fn register(&mut self, id: u64, shape: CoverStructure, cells: Vec<(i32, i32)>) -> bool {
        let old = self.entries.get(&id).map_or(0, |e| e.cells.len());
        let old_parts = self.entries.get(&id).map_or(0, |e| e.shape.parts.len());
        if id == 0
            || id > i64::MAX as u64
            || !valid(&shape)
            || cells.len() > 1_048_576
            || self.references - old + cells.len() > 16_777_216
            || self.parts - old_parts + shape.parts.len() > 4_000_000
            || self.entries.len() >= 1_000_000 && !self.entries.contains_key(&id)
            || cells
                .iter()
                .any(|c| i64::from(c.0).abs() > 65536 || i64::from(c.1).abs() > 65536)
            || cells.windows(2).any(|c| c[0] >= c[1])
            || self.next_order >= i64::MAX as u64 / 2
        {
            return false;
        }
        self.remove(id);
        for &cell in &cells {
            self.buckets.entry(cell).or_default().push(id);
        }
        self.references += cells.len();
        self.parts += shape.parts.len();
        self.entries.insert(
            id,
            Entry {
                order: self.next_order,
                shape,
                cells,
            },
        );
        self.next_order += 1;
        true
    }

    pub fn update(&mut self, id: u64, shape: CoverStructure) -> bool {
        if !valid(&shape) {
            return false;
        }
        let Some(entry) = self.entries.get_mut(&id) else {
            return false;
        };
        let parts = self.parts - entry.shape.parts.len() + shape.parts.len();
        if parts > 4_000_000 {
            return false;
        }
        self.parts = parts;
        entry.shape = shape;
        true
    }

    pub fn remove(&mut self, id: u64) {
        let Some(entry) = self.entries.remove(&id) else {
            return;
        };
        self.references -= entry.cells.len();
        self.parts -= entry.shape.parts.len();
        for cell in entry.cells {
            if let Some(bucket) = self.buckets.get_mut(&cell) {
                bucket.retain(|i| *i != id);
                if bucket.is_empty() {
                    self.buckets.remove(&cell);
                }
            }
        }
    }

    pub fn layout(&self, terrain: &Terrain, cells: &[u32]) -> CoverLayout {
        let origin = ((-terrain.half() - 1.6) / 16.0).floor() as i32;
        let side = (((terrain.half() + 1.6) / 16.0).floor() as i32 - origin + 1) as usize;
        let mut layout = CoverLayout {
            bucket_origin: origin,
            bucket_side: side,
            buckets: vec![-1; side * side],
            starts: Vec::new(),
            indices: Vec::new(),
            structures: Vec::new(),
        };
        let mut want = BTreeSet::new();
        let mut low = Vec2::splat(f32::INFINITY);
        let mut high = Vec2::splat(f32::NEG_INFINITY);
        for &i in cells {
            let p = terrain.center(i as usize);
            low = low.min(Vec2::new(p.x, p.z));
            high = high.max(Vec2::new(p.x, p.z));
            for x in ((p.x as f64 - 1.6) / 16.0).floor() as i32
                ..=((p.x as f64 + 1.6) / 16.0).floor() as i32
            {
                for z in ((p.z as f64 - 1.6) / 16.0).floor() as i32
                    ..=((p.z as f64 + 1.6) / 16.0).floor() as i32
                {
                    want.insert((x, z));
                }
            }
        }
        let mut slots = BTreeMap::new();
        for (bx, bz) in want {
            let Some(bucket) = self.buckets.get(&(bx, bz)) else {
                continue;
            };
            let mut list = Vec::new();
            for id in bucket {
                let shape = &self.entries[id].shape;
                let r = shape.radius + 1.7;
                let p = shape.position;
                if p.x as f64 + r < low.x as f64
                    || p.x as f64 - r > high.x as f64
                    || p.z as f64 + r < low.y as f64
                    || p.z as f64 - r > high.y as f64
                {
                    continue;
                }
                let slot = *slots.entry(*id).or_insert_with(|| {
                    let slot = layout.structures.len();
                    layout.structures.push(shape.clone());
                    slot
                });
                list.push(slot);
            }
            if list.is_empty() {
                continue;
            }
            layout.buckets[(bx - origin) as usize * side + (bz - origin) as usize] =
                (layout.starts.len() / 101) as i32;
            let ox = bx as f64 * 16.0 - 2.0;
            let oz = bz as f64 * 16.0 - 2.0;
            let mut sub: [Vec<usize>; 100] = std::array::from_fn(|_| Vec::new());
            for s in list {
                let shape = &layout.structures[s];
                let p = shape.position;
                let r = 1.6 + shape.radius + 0.05;
                let x0 = ((p.x as f64 - r - ox) / 2.0).floor().max(0.0) as i32;
                let x1 = ((p.x as f64 + r - ox) / 2.0).floor().min(9.0) as i32;
                let z0 = ((p.z as f64 - r - oz) / 2.0).floor().max(0.0) as i32;
                let z1 = ((p.z as f64 + r - oz) / 2.0).floor().min(9.0) as i32;
                for z in z0..=z1 {
                    for x in x0..=x1 {
                        sub[z as usize * 10 + x as usize].push(s);
                    }
                }
            }
            for list in sub {
                layout.starts.push(layout.indices.len());
                layout.indices.extend(list);
            }
            layout.starts.push(layout.indices.len());
        }
        layout
    }

    pub fn checkpoint(&self) -> Vec<u8> {
        let mut out = Writer::new(b"FLTC\x01\0\0\0");
        out.u64(self.next_order);
        out.u32(self.entries.len() as u32);
        let mut ordered: Vec<_> = self.entries.iter().collect();
        ordered.sort_unstable_by_key(|(_, entry)| entry.order);
        for (&id, entry) in ordered {
            out.u64(id);
            out.u64(entry.order);
            let shape = &entry.shape;
            out.point(shape.position);
            out.f64(shape.radius);
            out.byte(shape.kind);
            out.byte(u8::from(shape.rubble));
            out.byte(u8::from(shape.dug));
            for p in shape.footprint {
                out.f32(p.x);
                out.f32(p.y);
            }
            for p in shape.trench {
                out.point(p);
            }
            out.u32(shape.parts.len() as u32);
            for p in &shape.parts {
                out.point(p.center);
                for n in [p.cosine, p.sine, p.half_x, p.half_z] {
                    out.f64(n);
                }
                out.byte(p.level as u8);
            }
            out.u32(entry.cells.len() as u32);
            for &(x, z) in &entry.cells {
                out.u32(x as u32);
                out.u32(z as u32);
            }
        }
        out.0
    }

    pub fn restore(bytes: &[u8]) -> Result<Self, &'static str> {
        let mut input = Reader::new(bytes, b"FLTC\x01\0\0\0")?;
        let next = input.u64()?;
        if next == 0 || next >= i64::MAX as u64 / 2 {
            return Err("invalid cover insertion cursor");
        }
        let count = input.u32()?;
        if count > 1_000_000 {
            return Err("too many cover structures");
        }
        let mut scene = Self::default();
        let mut previous = 0;
        let mut total_parts = 0;
        for _ in 0..count {
            let id = input.u64()?;
            let order = input.u64()?;
            if order <= previous || order >= next || scene.entries.contains_key(&id) {
                return Err("invalid cover insertion order");
            }
            previous = order;
            let position = input.point()?;
            let radius = input.f64()?;
            let kind = input.byte()?;
            let rubble = input.boolean()?;
            let dug = input.boolean()?;
            let mut footprint = [Vec2::ZERO; 5];
            for p in &mut footprint {
                *p = Vec2::new(input.f32()?, input.f32()?);
            }
            let trench = [input.point()?, input.point()?];
            let part_count = input.u32()? as usize;
            total_parts += part_count;
            if part_count > 4096 || total_parts > 4_000_000 {
                return Err("too many cover parts");
            }
            let mut parts = Vec::new();
            for _ in 0..part_count {
                parts.push(CoverPart {
                    center: input.point()?,
                    cosine: input.f64()?,
                    sine: input.f64()?,
                    half_x: input.f64()?,
                    half_z: input.f64()?,
                    level: input.byte()? as i32,
                });
            }
            let cell_count = input.u32()?;
            if cell_count > 1_048_576 {
                return Err("too many cover index cells");
            }
            let mut cells = Vec::new();
            for _ in 0..cell_count {
                cells.push((input.u32()? as i32, input.u32()? as i32));
            }
            scene.next_order = order;
            if !scene.register(
                id,
                CoverStructure {
                    position,
                    radius,
                    kind,
                    rubble,
                    dug,
                    footprint,
                    trench,
                    parts,
                },
                cells,
            ) {
                return Err("invalid cover structure");
            }
        }
        input.finish()?;
        scene.next_order = next;
        Ok(scene)
    }
}
