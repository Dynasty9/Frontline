//! Boats share weighted water routes, shore searches and connected-water labels.
use crate::navigation_grid::NavigationGrid;
use crate::state_codec::{Reader, Writer};
use crate::terrain::{Terrain, BASE, SHALLOW, WATER};
use crate::vector::Vector3;

pub const LEVEL: f32 = -0.45;
const CELL: f64 = 2.0;

pub struct BoatNavigation {
    side: usize,
    grid: NavigationGrid,
    bodies: Vec<i32>,
}

fn point(p: Vector3) -> bool {
    p.is_finite() && p.abs().max_element() <= 1_000_000.0
}

impl BoatNavigation {
    pub fn from_terrain(terrain: &Terrain, decks: &[u8]) -> Result<Self, &'static str> {
        if terrain.n % 2 != 0
            || decks.len() != terrain.n * terrain.n
            || decks.iter().any(|&v| v > 1)
        {
            return Err("invalid boat terrain");
        }
        let side = terrain.n / 2;
        let mut solid = vec![1; side * side];
        let mut weight = vec![1.0; side * side];
        let base = &terrain.layers[BASE];
        for z in 0..side {
            for x in 0..side {
                let first = z * 2 * terrain.n + x * 2;
                if base[first] < WATER {
                    continue;
                }
                let mut wet = 0;
                let mut deep = 0;
                for dz in 0..2 {
                    for dx in 0..2 {
                        let i = first + dz * terrain.n + dx;
                        if base[i] == WATER && decks[i] == 0 {
                            deep += 1;
                            wet += 1;
                        } else if base[i] == SHALLOW {
                            wet += 1;
                        }
                    }
                }
                if wet == 4 {
                    solid[z * side + x] = 0;
                    if deep < 4 {
                        weight[z * side + x] = 5.0;
                    }
                }
            }
        }
        Self::new(side, &solid, &weight)
    }
    pub fn new(side: usize, solid: &[u8], weight: &[f32]) -> Result<Self, &'static str> {
        if side == 0
            || side > 2048
            || solid.len() != side * side
            || weight.len() != solid.len()
            || solid.iter().any(|&v| v > 1)
            || weight
                .iter()
                .any(|&v| !v.is_finite() || !(1.0..=1000.0).contains(&v))
        {
            return Err("invalid boat grid");
        }
        let mut grid = NavigationGrid::new([0, 0], side as i32, side as i32).unwrap();
        if !grid.load_cells(solid, weight) {
            return Err("invalid boat cells");
        }
        let mut nav = Self {
            side,
            grid,
            bodies: vec![-1; side * side],
        };
        let mut label = 0;
        let mut stack = Vec::new();
        for i in 0..side * side {
            if nav.bodies[i] >= 0 || solid[i] != 0 {
                continue;
            }
            stack.push(i);
            nav.bodies[i] = label;
            while let Some(j) = stack.pop() {
                let x = (j % side) as i32;
                let z = (j / side) as i32;
                for [dx, dz] in [[1, 0], [-1, 0], [0, 1], [0, -1]] {
                    let q = [x + dx, z + dz];
                    if !nav.grid.contains(q) || nav.grid.is_solid(q) {
                        continue;
                    }
                    let k = q[1] as usize * side + q[0] as usize;
                    if nav.bodies[k] < 0 {
                        nav.bodies[k] = label;
                        stack.push(k);
                    }
                }
            }
            label += 1;
        }
        Ok(nav)
    }
    pub fn half(&self) -> f64 {
        self.side as f64
    }
    fn cell(&self, p: Vector3) -> [i32; 2] {
        let coordinate = |v: f32| {
            (libm::floor((f64::from(v) + self.half()) / CELL) as i32).clamp(0, self.side as i32 - 1)
        };
        [coordinate(p.x), coordinate(p.z)]
    }
    fn center(&self, p: [i32; 2]) -> Vector3 {
        Vector3::new(
            ((f64::from(p[0]) + 0.5) * CELL - self.half()) as f32,
            LEVEL,
            ((f64::from(p[1]) + 0.5) * CELL - self.half()) as f32,
        )
    }
    pub fn body(&self, p: Vector3) -> i32 {
        if !point(p) {
            return -1;
        }
        let c = self.cell(p);
        self.bodies[c[1] as usize * self.side + c[0] as usize]
    }
    pub fn open(&self, p: Vector3) -> bool {
        point(p) && !self.grid.is_solid(self.cell(p))
    }
    pub fn line(&self, a: Vector3, b: Vector3, half_width: f64) -> bool {
        if !point(a)
            || !point(b)
            || !half_width.is_finite()
            || !(0.0..=1000.0).contains(&half_width)
        {
            return false;
        }
        let d = Vector3::new(b.x - a.x, 0.0, b.z - a.z);
        let dist = f64::from(d.length());
        if dist < 0.01 {
            return self.open(a);
        }
        let side = Vector3::new(-d.z, 0.0, d.x) / dist as f32 * half_width as f32;
        for k in 0..=(dist / CELL) as usize {
            let p = a + d * (k as f64 * CELL / dist).min(1.0) as f32;
            if !self.open(p) || (half_width > 0.0 && (!self.open(p + side) || !self.open(p - side)))
            {
                return false;
            }
        }
        self.open(b)
    }
    pub fn nearest(&self, p: Vector3, radius: f64, body: i32) -> Option<Vector3> {
        if !point(p) || !radius.is_finite() || !(0.0..=4096.0).contains(&radius) || body < -1 {
            return None;
        }
        let c = self.cell(p);
        if self.open(p) && (body < 0 || self.body(p) == body) {
            return Some(self.center(c));
        }
        for k in 1..=(radius / CELL) as i32 {
            let mut best = None;
            let mut distance = i64::MAX;
            for dz in -k..=k {
                for dx in (-k..=k).step_by(if dz.abs() != k { 2 * k as usize } else { 1 }) {
                    let q = [c[0] + dx, c[1] + dz];
                    if !self.grid.contains(q) || self.grid.is_solid(q) {
                        continue;
                    }
                    if body >= 0 && self.bodies[q[1] as usize * self.side + q[0] as usize] != body {
                        continue;
                    }
                    let d = i64::from(dx) * i64::from(dx) + i64::from(dz) * i64::from(dz);
                    if d < distance {
                        distance = d;
                        best = Some(q);
                    }
                }
            }
            if let Some(q) = best {
                return Some(self.center(q));
            }
        }
        None
    }
    pub fn path(&mut self, from: Vector3, to: Vector3) -> Vec<Vector3> {
        if !point(from) || !point(to) {
            return Vec::new();
        }
        let Some(a) = self.nearest(from, 30.0, -1) else {
            return Vec::new();
        };
        let Some(b) = self.nearest(to, 160.0, self.body(a)) else {
            return Vec::new();
        };
        let points = self.grid.path(self.cell(a), self.cell(b));
        points
            .iter()
            .enumerate()
            .filter(|&(i, _)| i % 3 == 0 || i == points.len() - 1)
            .map(|(_, &p)| self.center(p))
            .collect()
    }
    pub fn checkpoint(&self) -> Vec<u8> {
        let mut w = Writer::new(b"FLBN\x01\0\0\0");
        w.u32(self.side as u32);
        w.bytes(&self.grid.checkpoint());
        w.0
    }
    pub fn restore(bytes: &[u8]) -> Result<Self, &'static str> {
        let mut r = Reader::new(bytes, b"FLBN\x01\0\0\0")?;
        let side = r.u32()? as usize;
        if side == 0 || side > 2048 {
            return Err("invalid boat dimensions");
        }
        let encoded = r.bytes(24 + side * side * 5)?;
        r.finish()?;
        if encoded.len() < 24
            || encoded[8..24]
                != [0i32, 0, side as i32, side as i32]
                    .into_iter()
                    .flat_map(i32::to_le_bytes)
                    .collect::<Vec<_>>()
        {
            return Err("invalid boat region");
        }
        let grid = NavigationGrid::restore(encoded)?;
        let mut solid = Vec::with_capacity(side * side);
        let mut weights = Vec::with_capacity(side * side);
        for z in 0..side {
            for x in 0..side {
                let c = [x as i32, z as i32];
                solid.push(u8::from(grid.is_solid(c)));
                weights.push(grid.weight(c).unwrap());
            }
        }
        Self::new(side, &solid, &weights)
    }
}
