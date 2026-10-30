use crate::terrain::{ground_cover, Terrain, BASE, CRATER, OMNI, WOODS};
use crate::vector::Vector3;
use glam::Vec2;
pub use glam::Vec2 as Point2;

/// Immutable geometry in the spatial index's encounter order; workers never access scene objects.
#[derive(Clone, Debug, PartialEq)]
pub struct CoverLayout {
    pub bucket_origin: i32,
    pub bucket_side: usize,
    pub buckets: Vec<i32>,
    pub starts: Vec<usize>,
    pub indices: Vec<usize>,
    pub structures: Vec<CoverStructure>,
}

#[derive(Clone, Debug, PartialEq)]
pub struct CoverStructure {
    pub position: Vector3,
    pub radius: f64,
    pub kind: u8,
    pub rubble: bool,
    pub dug: bool,
    pub parts: Vec<CoverPart>,
    pub footprint: [Vec2; 5],
    pub trench: [Vector3; 2],
}

#[derive(Clone, Debug, PartialEq)]
pub struct CoverPart {
    pub center: Vector3,
    pub cosine: f64,
    pub sine: f64,
    pub half_x: f64,
    pub half_z: f64,
    pub level: i32,
}

impl CoverLayout {
    pub fn valid(&self, terrain: &Terrain) -> bool {
        let origin = ((-terrain.half() - 1.6) / 16.0).floor() as i32;
        let side = ((terrain.half() + 1.6) / 16.0).floor() as i32 - origin + 1;
        self.bucket_origin == origin
            && self.bucket_side == side as usize
            && self.buckets.len() == self.bucket_side * self.bucket_side
            && self
                .buckets
                .iter()
                .all(|b| *b == -1 || (*b >= 0 && (*b as usize + 1) * 101 <= self.starts.len()))
            && self.starts.len() % 101 == 0
            && self.starts.iter().all(|i| *i <= self.indices.len())
            && self.starts.windows(2).all(|w| w[0] <= w[1])
            && self.indices.iter().all(|s| *s < self.structures.len())
            && self.structures.len() <= 1_000_000
            && self.structures.iter().all(|s| {
                s.position.is_finite()
                    && s.radius.is_finite()
                    && (0.0..=8192.0).contains(&s.radius)
                    && s.kind <= 3
                    && s.footprint.iter().all(|p| p.is_finite())
                    && s.trench.iter().all(|p| p.is_finite())
                    && s.parts.iter().all(|p| {
                        p.center.is_finite()
                            && p.cosine.is_finite()
                            && p.sine.is_finite()
                            && p.half_x.is_finite()
                            && p.half_z.is_finite()
                            && p.half_x >= 0.0
                            && p.half_z >= 0.0
                            && (1..=2).contains(&p.level)
                    })
            })
    }

    pub fn calculate(&self, terrain: &Terrain, cells: &[u32]) -> Vec<[u8; 5]> {
        let mut met = vec![usize::MAX; self.structures.len()];
        cells
            .iter()
            .enumerate()
            .map(|(q, &cell)| {
                let c = terrain.center(cell as usize);
                let mut best = 0;
                let mut direction = 255;
                let mut rubble = false;
                let mut trench = false;
                let mut solid = false;
                for bx in ((c.x as f64 - 1.6) / 16.0).floor() as i32
                    ..=((c.x as f64 + 1.6) / 16.0).floor() as i32
                {
                    for bz in ((c.z as f64 - 1.6) / 16.0).floor() as i32
                        ..=((c.z as f64 + 1.6) / 16.0).floor() as i32
                    {
                        let b = self.buckets[(bx - self.bucket_origin) as usize * self.bucket_side
                            + (bz - self.bucket_origin) as usize];
                        if b < 0 {
                            continue;
                        }
                        let sub = b as usize * 101
                            + ((c.z as f64 - (bz as f64 * 16.0 - 2.0)) / 2.0).floor() as usize * 10
                            + ((c.x as f64 - (bx as f64 * 16.0 - 2.0)) / 2.0).floor() as usize;
                        for &index in &self.indices[self.starts[sub]..self.starts[sub + 1]] {
                            if met[index] == q {
                                continue;
                            }
                            met[index] = q;
                            let s = &self.structures[index];
                            let dv = s.position - c;
                            if f64::from(Vector3::new(dv.x, 0.0, dv.z).length()) > 1.6 + s.radius {
                                continue;
                            }
                            let inside_trench =
                                s.dug && trench_distance(s.trench[0], s.trench[1], c) < 0.0;
                            trench |= inside_trench;
                            let d = Vec2::new(c.x, c.z) - s.footprint[0];
                            let inside = |half: Vec2| {
                                d.dot(s.footprint[3]).abs() <= half.x
                                    && d.dot(s.footprint[4]).abs() <= half.y
                            };
                            rubble |= s.rubble && inside(s.footprint[1]);
                            if s.kind == 0 || s.parts.is_empty() {
                                continue;
                            }
                            if s.kind == 2 {
                                if inside_trench && best < 2 {
                                    best = 2;
                                    direction = OMNI;
                                }
                                continue;
                            }
                            if s.kind == 3 && inside(s.footprint[2]) {
                                if best < 2 {
                                    best = 2;
                                    direction = OMNI;
                                }
                                continue;
                            }
                            let mut level = 0;
                            let mut facing = 0;
                            for part in &s.parts {
                                let d = c - part.center;
                                let lx = d.x as f64 * part.cosine - d.z as f64 * part.sine;
                                let lz = d.x as f64 * part.sine + d.z as f64 * part.cosine;
                                let qx = lx.clamp(-part.half_x, part.half_x);
                                let qz = lz.clamp(-part.half_z, part.half_z);
                                let gap = f64::from(
                                    Vec2::new((lx - qx) as f32, (lz - qz) as f32).length(),
                                );
                                if gap < 0.001 {
                                    solid |= !s.rubble;
                                    continue;
                                }
                                if gap > 1.35 || part.level <= level {
                                    continue;
                                }
                                let lv = Vec2::new((qx - lx) as f32, (qz - lz) as f32);
                                let wx = lv.x as f64 * part.cosine + lv.y as f64 * part.sine;
                                let wz = -(lv.x as f64) * part.sine + lv.y as f64 * part.cosine;
                                level = part.level;
                                facing = ((wz.atan2(wx) / (std::f64::consts::TAU / 8.0)).round()
                                    as i32)
                                    .rem_euclid(8) as u8;
                            }
                            if level > best {
                                best = level;
                                direction = facing;
                            }
                        }
                    }
                }
                let i = cell as usize;
                let ground = ground_cover(
                    terrain.layers[CRATER][i],
                    u8::from(rubble),
                    terrain.layers[WOODS][i],
                    terrain.layers[BASE][i],
                );
                if ground > best || (ground == best && best == 1) {
                    best = ground;
                    direction = if ground == 1 { OMNI } else { 255 };
                }
                [
                    u8::from(rubble),
                    u8::from(trench),
                    u8::from(solid),
                    (best + 1) as u8,
                    direction,
                ]
            })
            .collect()
    }
}

fn trench_distance(a: Vector3, b: Vector3, p: Vector3) -> f64 {
    let flat = |v: Vector3| Vector3::new(v.x, 0.0, v.z);
    let mut d = flat(b - a);
    let len = d.length();
    if f64::from(len) < 0.001 {
        return f64::from(flat(p - a).length()) - 0.72;
    }
    // Godot Vector3 division multiplies by the scalar reciprocal here.
    d /= len;
    let center = (a + b) * 0.5;
    let rel = flat(p - center);
    let u = f64::from(rel.dot(d).abs()) - (f64::from(len) * 0.5 + 0.72 - 0.18);
    let v = f64::from(rel.dot(Vector3::new(-d.z, 0.0, d.x)).abs()) - (0.72 - 0.18);
    f64::from(Vec2::new(u.max(0.0) as f32, v.max(0.0) as f32).length()) + u.max(v).min(0.0) - 0.18
}
