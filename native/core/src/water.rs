//! Numeric water shapes, bridge decks and ordered terrain rasterization.
use crate::state_codec::{Reader, Writer};
use crate::terrain::{Terrain, BASE, DRES, ROAD, SHALLOW, WATER};
use crate::vector::{normalized, Vector3};
use glam::Vec2;

pub const LEVEL: f64 = -0.45;
pub const WADE: f64 = -1.0;

#[derive(Clone, Debug, PartialEq)]
pub struct River {
    pub points: Vec<Vector3>,
    pub width: f64,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Pond {
    pub center: Vector3,
    pub radius: f64,
    pub seed: f64,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Bridge {
    pub a: Vector3,
    pub b: Vector3,
    pub half_width: f64,
    pub quay: bool,
}

#[derive(Clone, Debug, PartialEq)]
pub struct Water {
    pub side: usize,
    pub coast: Option<[f64; 2]>,
    pub rivers: Vec<River>,
    pub ponds: Vec<Pond>,
    pub fords: Vec<Vector3>,
    pub bridges: Vec<Bridge>,
}

#[derive(Debug, PartialEq)]
pub struct Paint {
    pub changed: Vec<u32>,
    pub deck: Vec<u8>,
    pub mask: Vec<u8>,
}

pub struct GroundLoad {
    pub terrain: Terrain,
    pub deck: Vec<u8>,
    pub mask: Vec<u8>,
}

fn valid_point(p: Vector3) -> bool {
    p.is_finite() && p.abs().max_element() <= 1_000_000.0
}
fn lerp(a: f64, b: f64, t: f64) -> f64 {
    a + (b - a) * t
}
fn smooth(a: f64, b: f64, x: f64) -> f64 {
    let t = ((x - a) / (b - a)).clamp(0.0, 1.0);
    t * t * (3.0 - 2.0 * t)
}
fn bed(into: f64, deep: f64, shelf: f64, bank: f64) -> f64 {
    if into <= 0.0 {
        lerp(LEVEL + 0.07, 0.0, (-into / bank).clamp(0.0, 1.0))
    } else if into < shelf {
        lerp(LEVEL - 0.05, WADE - 0.05, into / shelf)
    } else {
        lerp(WADE - 0.05, deep, ((into - shelf) / 8.0).clamp(0.0, 1.0))
    }
}

impl Water {
    pub fn load(
        &self,
        mut terrain: Terrain,
        joined: &[u8],
        view: bool,
    ) -> Result<GroundLoad, &'static str> {
        if !self.valid()
            || terrain.n != self.side
            || !joined.is_empty()
                && (joined.len() != self.side * self.side || joined.iter().any(|b| *b > SHALLOW))
        {
            return Err("invalid joining terrain");
        }
        let painted = if self.is_empty() {
            Paint {
                changed: Vec::new(),
                deck: Vec::new(),
                mask: Vec::new(),
            }
        } else {
            self.paint(&mut terrain.layers[BASE], view)?
        };
        terrain.refresh_ground(&painted.changed);
        for (i, &base) in joined.iter().enumerate() {
            if terrain.layers[BASE][i] != base {
                terrain.layers[BASE][i] = base;
                terrain.refresh_ground(&[i as u32]);
            }
        }
        if !self.is_empty() {
            self.carve(&mut terrain.heights, false)?;
        }
        Ok(GroundLoad {
            terrain,
            deck: painted.deck,
            mask: painted.mask,
        })
    }

    pub fn valid(&self) -> bool {
        (2..=3072).contains(&self.side)
            && self
                .coast
                .is_none_or(|v| v.iter().all(|n| n.is_finite() && n.abs() <= 1_000_000.0))
            && self.rivers.len() <= 4096
            && self.ponds.len() <= 4096
            && self.fords.len() <= 4096
            && self.bridges.len() <= 4096
            && self.rivers.iter().map(|r| r.points.len()).sum::<usize>() <= 65_536
            && self.rivers.iter().all(|r| {
                r.width.is_finite()
                    && (0.01..=8192.0).contains(&r.width)
                    && r.points.iter().all(|p| valid_point(*p))
            })
            && self.ponds.iter().all(|p| {
                valid_point(p.center)
                    && p.radius.is_finite()
                    && (0.0..=8192.0).contains(&p.radius)
                    && p.seed.is_finite()
                    && p.seed.abs() <= 1_000_000.0
            })
            && self.fords.iter().all(|p| valid_point(*p))
            && self.bridges.iter().all(|b| {
                valid_point(b.a)
                    && valid_point(b.b)
                    && b.half_width.is_finite()
                    && (0.0..=8192.0).contains(&b.half_width)
            })
    }

    pub fn is_empty(&self) -> bool {
        self.coast.is_none() && self.rivers.is_empty() && self.ponds.is_empty()
    }

    pub fn coast_x(&self, z: f64) -> f64 {
        self.coast.map_or(f64::INFINITY, |[x, s]| {
            x + 22.0 * (z * 0.0105 + s).sin()
                + 9.0 * (z * 0.031 + s * 2.3).sin()
                + 4.0 * (z * 0.077 + s * 0.7).sin()
        })
    }

    pub fn current(&self, p: Vector3) -> Vector3 {
        for river in &self.rivers {
            let half = river.width * 0.5;
            let mut best = half;
            let mut flow = Vector3::ZERO;
            for pair in river.points.windows(2) {
                let [a, b] = [pair[0], pair[1]];
                if f64::from(p.z) < f64::from(a.z.min(b.z)) - half
                    || f64::from(p.z) > f64::from(a.z.max(b.z)) + half
                    || f64::from(p.x) < f64::from(a.x.min(b.x)) - half
                    || f64::from(p.x) > f64::from(a.x.max(b.x)) + half
                {
                    continue;
                }
                let ab = Vector3::new(
                    (f64::from(b.x) - f64::from(a.x)) as f32,
                    0.0,
                    (f64::from(b.z) - f64::from(a.z)) as f32,
                );
                let x = f64::from(p.x) - f64::from(a.x);
                let z = f64::from(p.z) - f64::from(a.z);
                let t = ((x * f64::from(ab.x) + z * f64::from(ab.z))
                    / f64::from(ab.length_squared()).max(0.0001))
                .clamp(0.0, 1.0);
                let distance = f64::from(
                    Vec2::new(
                        (x - f64::from(ab.x) * t) as f32,
                        (z - f64::from(ab.z) * t) as f32,
                    )
                    .length(),
                );
                if distance < best {
                    best = distance;
                    flow = normalized(ab) * if ab.z > 0.0 { -1.0 } else { 1.0 };
                }
            }
            if flow != Vector3::ZERO {
                return flow * 0.45 * (1.0 - (best / half) * (best / half)) as f32;
            }
        }
        Vector3::ZERO
    }

    pub fn in_bridge(&self, x: f64, z: f64, pad: f64) -> bool {
        self.bridges.iter().any(|b| {
            let dx = f64::from(b.b.x) - f64::from(b.a.x);
            let dz = f64::from(b.b.z) - f64::from(b.a.z);
            let t = ((x - f64::from(b.a.x)) * dx + (z - f64::from(b.a.z)) * dz)
                / (dx * dx + dz * dz).max(0.0001);
            if !(-0.02..=1.02).contains(&t) {
                return false;
            }
            let px = x - f64::from(b.a.x) - dx * t;
            let pz = z - f64::from(b.a.z) - dz * t;
            (px * px + pz * pz).sqrt() < b.half_width + pad
        })
    }

    fn quay(&self, x: f64, z: f64) -> bool {
        self.bridges.iter().filter(|b| b.quay).any(|b| {
            let ab = b.b - b.a;
            let flat = Vector3::new(ab.x, 0.0, ab.z);
            let t = ((x - f64::from(b.a.x)) * (f64::from(b.b.x) - f64::from(b.a.x))
                + (z - f64::from(b.a.z)) * (f64::from(b.b.z) - f64::from(b.a.z)))
                / f64::from(flat.length_squared()).max(0.0001);
            if !(-0.02..=1.02).contains(&t) {
                return false;
            }
            let p = Vector3::new(x as f32, 0.0, z as f32);
            let l2 = ab.length_squared();
            let distance = if f64::from(l2) < 0.0001 {
                p.distance(b.a)
            } else {
                let t = (f64::from((p - b.a).dot(ab)) / f64::from(l2)).clamp(0.0, 1.0);
                p.distance(b.a + ab * t as f32)
            };
            f64::from(distance) < b.half_width + 0.6
        })
    }

    fn span(&self, res: usize, pad: f64, quays: bool) -> Vec<u8> {
        let n = self.side * res;
        let half = self.side as f64 * 0.5;
        let mut output = vec![0; n * n];
        for bridge in &self.bridges {
            if quays && !bridge.quay {
                continue;
            }
            let delta = bridge.b - bridge.a;
            let r = bridge.half_width
                + pad
                + 1.0
                + 0.03 * f64::from(Vector3::new(delta.x, 0.0, delta.z).length());
            let [x0, x1, z0, z1] = bounds(bridge.a, bridge.b, r, half, res, n);
            for z in z0..=z1 {
                let wz = (z as f64 + 0.5) / res as f64 - half;
                for x in x0..=x1 {
                    let wx = (x as f64 + 0.5) / res as f64 - half;
                    let i = z as usize * n + x as usize;
                    if output[i] == 0
                        && if quays {
                            self.quay(wx, wz)
                        } else {
                            self.in_bridge(wx, wz, pad)
                        }
                    {
                        output[i] = 1;
                    }
                }
            }
        }
        output
    }

    // Rows and shapes retain the original order; worker partitioning cannot alter ties.
    fn samples(&self, res: usize, mut write: impl FnMut(usize, f64, f64, bool, f64)) {
        let n = self.side * res;
        let half = self.side as f64 * 0.5;
        let sea_x = self.coast.map_or(0, |[x, _]| {
            ((x - 36.0 - 14.0 + half) * res as f64).floor().max(0.0) as usize
        });
        let mut segments = Vec::new();
        for river in &self.rivers {
            for pair in river.points.windows(2) {
                let a = pair[0];
                let b = pair[1];
                let hw = river.width * 0.5;
                let dx = f64::from(b.x) - f64::from(a.x);
                let dz = f64::from(b.z) - f64::from(a.z);
                segments.push((
                    a,
                    dx,
                    dz,
                    (dx * dx + dz * dz).max(0.0001),
                    hw,
                    bounds(a, b, hw + 5.0, half, res, n),
                ));
            }
        }
        for z in 0..n {
            let wz = (z as f64 + 0.5) / res as f64 - half;
            let row = z * n;
            if self.coast.is_some() {
                let coast = self.coast_x(wz);
                for x in sea_x..n {
                    let into = (x as f64 + 0.5) / res as f64 - half - coast;
                    if into >= -14.0 {
                        write(row + x, bed(into, -3.2, 9.0, 14.0), into, true, 14.0);
                    }
                }
            }
            for &(a, dx, dz, ll, hw, [x0, x1, z0, z1]) in &segments {
                if (z as i32) < z0 || (z as i32) > z1 {
                    continue;
                }
                for x in x0..=x1 {
                    let wx = (x as f64 + 0.5) / res as f64 - half;
                    let t = (((wx - f64::from(a.x)) * dx + (wz - f64::from(a.z)) * dz) / ll)
                        .clamp(0.0, 1.0);
                    let px = wx - f64::from(a.x) - dx * t;
                    let pz = wz - f64::from(a.z) - dz * t;
                    let into = hw - (px * px + pz * pz).sqrt();
                    if into < -5.0 {
                        continue;
                    }
                    let mut height = bed(into, -2.3, 3.0, 5.0);
                    for ford in &self.fords {
                        let distance = f64::from(
                            Vec2::new(
                                (wx - f64::from(ford.x)) as f32,
                                (wz - f64::from(ford.z)) as f32,
                            )
                            .length(),
                        );
                        if distance < 10.0 {
                            height = height.max(lerp(-0.8, height, smooth(6.0, 10.0, distance)));
                        }
                    }
                    write(row + x as usize, height, into, false, 5.0);
                }
            }
            for pond in &self.ponds {
                let [x0, x1, z0, z1] = bounds(
                    pond.center,
                    pond.center,
                    pond.radius * 1.3 + 6.0,
                    half,
                    res,
                    n,
                );
                if (z as i32) < z0 || (z as i32) > z1 {
                    continue;
                }
                for x in x0..=x1 {
                    let wx = (x as f64 + 0.5) / res as f64 - half;
                    let rel = Vec2::new(
                        (wx - f64::from(pond.center.x)) as f32,
                        (wz - f64::from(pond.center.z)) as f32,
                    );
                    let angle = f64::from(rel.y.atan2(rel.x));
                    let into = pond.radius
                        * (1.0
                            + 0.18 * (angle * 3.0 + pond.seed).sin()
                            + 0.1 * (angle * 5.0 + pond.seed * 1.7).sin())
                        - f64::from(rel.length());
                    if into >= -6.0 {
                        write(
                            row + x as usize,
                            bed(into, -2.0, 4.0, 6.0),
                            into,
                            false,
                            6.0,
                        );
                    }
                }
            }
        }
    }

    pub fn paint(&self, base: &mut [u8], view: bool) -> Result<Paint, &'static str> {
        if !self.valid() || base.len() != self.side * self.side || base.iter().any(|b| *b > SHALLOW)
        {
            return Err("invalid water terrain");
        }
        let mut output = Paint {
            changed: Vec::new(),
            deck: vec![0; base.len()],
            mask: if view {
                vec![0; base.len() * 4]
            } else {
                Vec::new()
            },
        };
        let mut seen = vec![false; base.len()];
        let span = self.span(1, 0.0, false);
        let quays = if view {
            self.span(1, 0.6, true)
        } else {
            Vec::new()
        };
        self.samples(1, |i, height, into, salt, bank| {
            let on_bridge = height < LEVEL && span[i] == 1;
            let was = base[i];
            if on_bridge {
                output.deck[i] = 1;
                if was >= WATER {
                    base[i] = ROAD;
                }
            } else if height < WADE {
                base[i] = WATER;
            } else if height < LEVEL && was != WATER {
                base[i] = SHALLOW;
            }
            if was != base[i] && !seen[i] {
                seen[i] = true;
                output.changed.push(i as u32);
            }
            if !view || on_bridge && quays[i] == 1 {
                return;
            }
            let depth = (((LEVEL - height) / 3.0).clamp(0.0, 1.0) * 255.0) as u8;
            let shore = if into > 0.0 {
                255
            } else {
                ((1.0 + into / bank).clamp(0.0, 1.0) * 255.0) as u8
            };
            output.mask[i * 4] = output.mask[i * 4].max(depth);
            output.mask[i * 4 + 1] = output.mask[i * 4 + 1].max(shore);
            if salt {
                output.mask[i * 4 + 2] = 255;
            }
            if height < LEVEL {
                output.mask[i * 4 + 3] = 255;
            }
        });
        Ok(output)
    }

    pub fn carve(&self, heights: &mut [f32], listing: bool) -> Result<Vec<u32>, &'static str> {
        if !self.valid()
            || heights.len() != self.side * self.side * DRES * DRES
            || heights.iter().any(|h| !h.is_finite())
        {
            return Err("invalid water heights");
        }
        let span = self.span(DRES, 0.6, false);
        let mut changed = Vec::new();
        let mut seen = if listing {
            vec![false; heights.len()]
        } else {
            Vec::new()
        };
        self.samples(DRES, |i, height, _, _, _| {
            if height < f64::from(heights[i]) && (height < LEVEL || span[i] == 0) {
                heights[i] = height as f32;
                if listing && !seen[i] {
                    seen[i] = true;
                    changed.push(i as u32);
                }
            }
        });
        Ok(changed)
    }

    pub fn checkpoint(&self) -> Vec<u8> {
        let mut out = Writer::new(b"FLWA\x01\0\0\0");
        out.u32(self.side as u32);
        out.byte(u8::from(self.coast.is_some()));
        if let Some([x, seed]) = self.coast {
            out.f64(x);
            out.f64(seed);
        }
        out.u32(self.rivers.len() as u32);
        for river in &self.rivers {
            out.f64(river.width);
            out.u32(river.points.len() as u32);
            for p in &river.points {
                out.point(*p);
            }
        }
        out.u32(self.ponds.len() as u32);
        for p in &self.ponds {
            out.point(p.center);
            out.f64(p.radius);
            out.f64(p.seed);
        }
        out.u32(self.fords.len() as u32);
        for p in &self.fords {
            out.point(*p);
        }
        out.u32(self.bridges.len() as u32);
        for b in &self.bridges {
            out.point(b.a);
            out.point(b.b);
            out.f64(b.half_width);
            out.byte(u8::from(b.quay));
        }
        out.0
    }

    pub fn restore(bytes: &[u8]) -> Result<Self, &'static str> {
        let mut input = Reader::new(bytes, b"FLWA\x01\0\0\0")?;
        let side = input.u32()? as usize;
        let coast = if input.boolean()? {
            Some([input.f64()?, input.f64()?])
        } else {
            None
        };
        let count = |input: &mut Reader| -> Result<usize, &'static str> {
            let n = input.u32()? as usize;
            if n > 4096 {
                return Err("too many water shapes");
            }
            Ok(n)
        };
        let mut rivers = Vec::new();
        let mut total_points = 0;
        for _ in 0..count(&mut input)? {
            let width = input.f64()?;
            let n = input.u32()? as usize;
            total_points += n;
            if total_points > 65_536 {
                return Err("too many river points");
            }
            let mut points = Vec::new();
            for _ in 0..n {
                points.push(input.point()?);
            }
            rivers.push(River { points, width });
        }
        let mut ponds = Vec::new();
        for _ in 0..count(&mut input)? {
            ponds.push(Pond {
                center: input.point()?,
                radius: input.f64()?,
                seed: input.f64()?,
            });
        }
        let mut fords = Vec::new();
        for _ in 0..count(&mut input)? {
            fords.push(input.point()?);
        }
        let mut bridges = Vec::new();
        for _ in 0..count(&mut input)? {
            bridges.push(Bridge {
                a: input.point()?,
                b: input.point()?,
                half_width: input.f64()?,
                quay: input.boolean()?,
            });
        }
        input.finish()?;
        let water = Self {
            side,
            coast,
            rivers,
            ponds,
            fords,
            bridges,
        };
        if !water.valid() {
            return Err("invalid water shapes");
        }
        Ok(water)
    }
}

fn bounds(a: Vector3, b: Vector3, r: f64, half: f64, res: usize, n: usize) -> [i32; 4] {
    let lower = |v: f32| ((f64::from(v) - r + half) * res as f64).floor().max(0.0) as i32;
    let upper = |v: f32| {
        ((f64::from(v) + r + half) * res as f64)
            .ceil()
            .min(n as f64 - 1.0) as i32
    };
    [
        lower(a.x.min(b.x)),
        upper(a.x.max(b.x)),
        lower(a.z.min(b.z)),
        upper(a.z.max(b.z)),
    ]
}
