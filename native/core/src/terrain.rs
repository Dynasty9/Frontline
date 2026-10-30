use crate::random::SimulationRandom;
use crate::state_codec::{Reader, Writer};
use crate::terrain_scene::CoverScene;
use crate::vector::Vector3;
use glam::Vec2;

pub const BASE: usize = 0;
pub const CRATER: usize = 1;
pub const RUBBLE: usize = 2;
pub const WOODS: usize = 3;
pub const COVER: usize = 4;
pub const DIRECTION: usize = 5;
pub const SOLID: usize = 6;
pub const TRENCH: usize = 7;
pub const NETTED: usize = 8;
pub const ROAD: u8 = 1;
pub const MUD: u8 = 3;
pub const WATER: u8 = 7;
pub const SHALLOW: u8 = 8;
pub const OMNI: u8 = 8;
pub const DRES: usize = 2;

#[derive(Clone, Debug, PartialEq)]
pub struct Terrain {
    pub scene: CoverScene,
    pub n: usize,
    pub layers: [Vec<u8>; 9],
    pub heights: Vec<f32>,
    pub version: u64,
    pub fresh: bool,
    queue: Vec<u32>,
    head: usize,
    dirty: Vec<bool>,
}

impl Terrain {
    pub fn new(n: usize, layers: [Vec<u8>; 9], heights: Vec<f32>) -> Option<Self> {
        if !(2..=3072).contains(&n)
            || layers.iter().any(|v| v.len() != n * n)
            || heights.len() != n * n * DRES * DRES
            || heights.iter().any(|h| !h.is_finite())
            || !valid_layers(&layers)
        {
            return None;
        }
        Some(Self {
            scene: CoverScene::default(),
            n,
            layers,
            heights,
            version: 0,
            fresh: true,
            queue: Vec::new(),
            head: 0,
            dirty: vec![false; n * n],
        })
    }

    pub fn blank(n: usize) -> Option<Self> {
        if !(2..=3072).contains(&n) {
            return None;
        }
        let mut layers = std::array::from_fn(|_| vec![0; n * n]);
        layers[COVER].fill(1);
        layers[DIRECTION].fill(255);
        Self::new(n, layers, vec![0.0; n * n * DRES * DRES])
    }

    pub fn half(&self) -> f64 {
        self.n as f64 * 0.5
    }

    pub fn index(&self, p: Vector3) -> usize {
        let x = (f64::from(p.x) + self.half())
            .floor()
            .clamp(0.0, (self.n - 1) as f64) as usize;
        let z = (f64::from(p.z) + self.half())
            .floor()
            .clamp(0.0, (self.n - 1) as f64) as usize;
        z * self.n + x
    }

    pub fn center(&self, i: usize) -> Vector3 {
        Vector3::new(
            (i % self.n) as f32 - self.half() as f32 + 0.5,
            0.0,
            (i / self.n) as f32 - self.half() as f32 + 0.5,
        )
    }

    pub fn cell(&self, i: usize) -> [u8; 9] {
        std::array::from_fn(|layer| self.layers[layer][i])
    }

    pub fn kind(&self, p: Vector3) -> u8 {
        let v = self.cell(self.index(p));
        if v[BASE] >= WATER {
            v[BASE]
        } else if v[TRENCH] > 0 {
            6
        } else if v[CRATER] > 0 {
            4
        } else if v[RUBBLE] > 0 {
            5
        } else if v[WOODS] > 0 && v[BASE] != ROAD {
            2
        } else {
            v[BASE]
        }
    }

    pub fn cover(&self, p: Vector3) -> i32 {
        i32::from(self.layers[COVER][self.index(p)]) - 1
    }

    pub fn cover_vs(&self, p: Vector3, from: Vector3) -> i32 {
        let v = self.cell(self.index(p));
        let level = i32::from(v[COVER]) - 1;
        let dir = v[DIRECTION];
        if level <= 0 || dir == OMNI || dir == 255 {
            return level;
        }
        // GDScript scalar subtraction is double precision before Vector2's cast.
        let to = Vec2::new(
            (f64::from(from.x) - f64::from(p.x)) as f32,
            (f64::from(from.z) - f64::from(p.z)) as f32,
        );
        if f64::from(to.length_squared()) < 0.01 {
            return level;
        }
        let angle = std::f64::consts::TAU * f64::from(dir) / 8.0;
        let direction = Vec2::new(angle.cos() as f32, angle.sin() as f32);
        let length = to.length();
        let toward = Vec2::new(to.x / length, to.y / length);
        if direction.dot(toward) > 0.25 {
            level
        } else {
            ground_cover(v[CRATER], v[RUBBLE], v[WOODS], v[BASE])
        }
    }

    pub fn speed(&self, p: Vector3, vehicle: bool, tracked: bool) -> f64 {
        match self.kind(p) {
            6 => {
                if vehicle {
                    if tracked {
                        0.42
                    } else {
                        0.12
                    }
                } else {
                    0.95
                }
            }
            1 => {
                if vehicle {
                    1.35
                } else {
                    1.12
                }
            }
            3 => {
                if vehicle {
                    0.6
                } else {
                    0.82
                }
            }
            2 => {
                if vehicle {
                    0.65
                } else {
                    0.9
                }
            }
            4 => {
                if vehicle {
                    0.65
                } else {
                    0.85
                }
            }
            5 => {
                if vehicle {
                    0.8
                } else {
                    0.85
                }
            }
            8 => {
                if vehicle {
                    0.45
                } else {
                    0.5
                }
            }
            _ => 1.0,
        }
    }

    pub fn hit(&self, p: Vector3, from: Vector3) -> f64 {
        match self.kind(p) {
            4 => 0.6,
            2 => 0.75,
            5 => 0.85,
            1 if self.cover_vs(p, from) <= 0 => 1.12,
            3 if self.cover_vs(p, from) <= 0 => 1.15,
            8 => 1.2,
            _ => 1.0,
        }
    }

    pub fn concealment(&self, p: Vector3) -> f64 {
        let v = self.cell(self.index(p));
        let net = if v[NETTED] > 0 { 0.5 } else { 1.0 };
        net * if v[TRENCH] > 0 {
            0.7
        } else if v[BASE] >= WATER {
            1.0
        } else if v[CRATER] > 0 {
            0.85
        } else if v[RUBBLE] == 0 && v[WOODS] > 0 && v[BASE] != ROAD {
            0.6
        } else {
            1.0
        }
    }

    pub fn nav_weight(&self, i: usize, vehicle: bool) -> f64 {
        let v = self.cell(i);
        if v[TRENCH] > 0 {
            return if vehicle { 7.0 } else { 0.7 };
        }
        if v[CRATER] > 0 {
            return if vehicle { 2.8 } else { 1.2 };
        }
        if v[RUBBLE] > 0 {
            return if vehicle { 2.2 } else { 1.2 };
        }
        match v[BASE] {
            ROAD => return if vehicle { 0.6 } else { 0.85 },
            MUD => return if vehicle { 2.8 } else { 1.25 },
            SHALLOW => return if vehicle { 4.0 } else { 2.4 },
            _ => (),
        }
        if v[WOODS] > 0 {
            if vehicle {
                2.6
            } else {
                1.05
            }
        } else if vehicle {
            1.45
        } else {
            1.0
        }
    }

    pub fn refresh_ground(&mut self, cells: &[u32]) {
        for &i in cells {
            let i = i as usize;
            let v = self.cell(i);
            if v[COVER] <= 2 && (v[DIRECTION] == 255 || v[DIRECTION] == OMNI) {
                let cover = ground_cover(v[CRATER], v[RUBBLE], v[WOODS], v[BASE]);
                self.layers[COVER][i] = (cover + 1) as u8;
                self.layers[DIRECTION][i] = if cover == 1 { OMNI } else { 255 };
            }
        }
    }

    pub fn queue_rect(&mut self, bounds: [f64; 4]) {
        let [x0, z0, x1, z1] = self.bounds(bounds, 1);
        for z in z0..=z1 {
            for x in x0..=x1 {
                let i = z as usize * self.n + x as usize;
                if !self.dirty[i] {
                    self.dirty[i] = true;
                    self.queue.push(i as u32);
                }
            }
        }
    }

    pub fn pending(&self, budget: usize) -> &[u32] {
        &self.queue[self.head..self.head + budget.min(self.queue.len() - self.head)]
    }

    pub fn queue_cells(&mut self, cells: &[u32]) -> bool {
        if cells.iter().any(|i| *i as usize >= self.n * self.n) {
            return false;
        }
        for &i in cells {
            if !self.dirty[i as usize] {
                self.dirty[i as usize] = true;
                self.queue.push(i);
            }
        }
        true
    }

    pub fn finish_cover(&mut self, output: &[[u8; 5]]) -> bool {
        if output.len() > self.queue.len() - self.head
            || output.iter().any(|v| {
                v[0] > 1 || v[1] > 1 || v[2] > 1 || v[3] > 3 || !(v[4] <= OMNI || v[4] == 255)
            })
        {
            return false;
        }
        if output.is_empty() {
            return true;
        }
        for (q, v) in output.iter().enumerate() {
            let i = self.queue[self.head + q] as usize;
            self.dirty[i] = false;
            for (layer, value) in [RUBBLE, TRENCH, SOLID, COVER, DIRECTION].into_iter().zip(v) {
                self.layers[layer][i] = *value;
            }
        }
        self.head += output.len();
        if self.head == self.queue.len() {
            self.queue.clear();
            self.head = 0;
        }
        self.fresh = false;
        self.version += 1;
        true
    }

    pub fn tick_cover(&mut self, budget: usize) -> Vec<u32> {
        let cells = self.pending(budget).to_vec();
        if cells.is_empty() {
            return cells;
        }
        let layout = self.scene.layout(self, &cells);
        let output = layout.calculate(self, &cells);
        assert!(self.finish_cover(&output));
        cells
    }

    fn bounds(&self, rect: [f64; 4], res: usize) -> [i32; 4] {
        let half = self.half();
        let max = (self.n * res - 1) as f64;
        [
            ((rect[0] + half) * res as f64).floor().max(0.0) as i32,
            ((rect[1] + half) * res as f64).floor().max(0.0) as i32,
            ((rect[2] + half) * res as f64).floor().min(max) as i32,
            ((rect[3] + half) * res as f64).floor().min(max) as i32,
        ]
    }

    pub fn paint_box(&mut self, p: Vector3, half: Vec2, yaw: f64, kind: u8) -> Vec<u32> {
        let radius = f64::from(half.length()) + 1.0;
        let [x0, z0, x1, z1] = self.bounds(
            [
                p.x as f64 - radius,
                p.z as f64 - radius,
                p.x as f64 + radius,
                p.z as f64 + radius,
            ],
            1,
        );
        let ax = Vec2::new(yaw.cos() as f32, -yaw.sin() as f32);
        let az = Vec2::new(yaw.sin() as f32, yaw.cos() as f32);
        let mut changed = Vec::new();
        for z in z0..=z1 {
            for x in x0..=x1 {
                let i = z as usize * self.n + x as usize;
                let c = self.center(i);
                let d = Vec2::new(c.x, c.z) - Vec2::new(p.x, p.z);
                if d.dot(ax).abs() <= half.x && d.dot(az).abs() <= half.y {
                    self.layers[BASE][i] = kind;
                    changed.push(i as u32);
                }
            }
        }
        self.refresh_ground(&changed);
        self.version += 1;
        changed
    }

    pub fn tree(&mut self, p: Vector3, delta: i32) -> Vec<u32> {
        let c = self.index(p);
        let cx = (c % self.n) as i32;
        let cz = (c / self.n) as i32;
        let mut changed = Vec::new();
        for z in (cz - 4).max(0)..(cz + 5).min(self.n as i32) {
            for x in (cx - 4).max(0)..(cx + 5).min(self.n as i32) {
                let i = z as usize * self.n + x as usize;
                let d = self.center(i) - p;
                if f64::from(Vector3::new(d.x, 0.0, d.z).length()) < 3.8 {
                    self.layers[WOODS][i] =
                        (i64::from(self.layers[WOODS][i]) + i64::from(delta)).clamp(0, 255) as u8;
                    changed.push(i as u32);
                }
            }
        }
        self.refresh_ground(&changed);
        self.version += 1;
        changed
    }

    pub fn nets(&mut self, p: Vector3, radius: f64, footprints: &[[Vec2; 4]]) -> Vec<u32> {
        let [x0, z0, x1, z1] = self.bounds(
            [
                p.x as f64 - radius,
                p.z as f64 - radius,
                p.x as f64 + radius,
                p.z as f64 + radius,
            ],
            1,
        );
        let mut changed = Vec::new();
        for z in z0..=z1 {
            for x in x0..=x1 {
                let i = z as usize * self.n + x as usize;
                let c = self.center(i);
                self.layers[NETTED][i] = u8::from(footprints.iter().any(|f| {
                    let d = Vec2::new(c.x, c.z) - f[0];
                    d.dot(f[2]).abs() <= f[1].x && d.dot(f[3]).abs() <= f[1].y
                }));
                changed.push(i as u32);
            }
        }
        changed
    }

    pub fn paint_roads(&mut self, roads: &[Vec<Vector3>], width: f64, keep: bool) -> Vec<u32> {
        let mut changed = Vec::new();
        for road in roads {
            for pair in road.windows(2) {
                let a = pair[0];
                let b = pair[1];
                let [x0, z0, x1, z1] = self.bounds(
                    [
                        f64::from(a.x.min(b.x)) - width - 1.0,
                        f64::from(a.z.min(b.z)) - width - 1.0,
                        f64::from(a.x.max(b.x)) + width + 1.0,
                        f64::from(a.z.max(b.z)) + width + 1.0,
                    ],
                    1,
                );
                let start = Vector3::new(a.x, 0.0, a.z);
                let ab = Vector3::new(b.x, 0.0, b.z) - start;
                let length2 = f64::from(ab.length_squared());
                for z in z0..=z1 {
                    let mut lo = x0;
                    let mut hi = x1;
                    if f64::from(ab.z.abs()) > 0.0001 {
                        let ta = ((z as f64 - self.half() + 0.5 - width - a.z as f64)
                            / ab.z as f64)
                            .clamp(0.0, 1.0);
                        let tb = ((z as f64 - self.half() + 0.5 + width - a.z as f64)
                            / ab.z as f64)
                            .clamp(0.0, 1.0);
                        let xa = a.x as f64 + ab.x as f64 * ta;
                        let xb = a.x as f64 + ab.x as f64 * tb;
                        lo = lo.max((xa.min(xb) - width + self.half() - 1.0).floor() as i32);
                        hi = hi.min((xa.max(xb) + width + self.half() + 1.0).ceil() as i32);
                    }
                    for x in lo.max(0)..=hi.min(self.n as i32 - 1) {
                        let i = z as usize * self.n + x as usize;
                        let was = self.layers[BASE][i];
                        if was >= WATER || (keep && was == ROAD) {
                            continue;
                        }
                        let c = self.center(i);
                        let nearest = if length2 >= 0.0001 {
                            start
                                + ab * (f64::from((c - start).dot(ab)) / length2).clamp(0.0, 1.0)
                                    as f32
                        } else {
                            start
                        };
                        if f64::from(c.distance(nearest)) <= width {
                            self.layers[BASE][i] = ROAD;
                            changed.push(i as u32);
                        }
                    }
                }
            }
        }
        self.refresh_ground(&changed);
        self.version += 1;
        changed
    }

    pub fn deform_at(&self, p: Vector3) -> f64 {
        let n = self.n * DRES;
        let fx = (f64::from(p.x) + self.half()) * DRES as f64 - 0.5;
        let fz = (f64::from(p.z) + self.half()) * DRES as f64 - 0.5;
        let x = fx.floor().clamp(0.0, (n - 2) as f64) as usize;
        let z = fz.floor().clamp(0.0, (n - 2) as f64) as usize;
        let tx = (fx - x as f64).clamp(0.0, 1.0);
        let tz = (fz - z as f64).clamp(0.0, 1.0);
        let i = z * n + x;
        let lerp = |a: f64, b: f64, t: f64| a + (b - a) * t;
        let a = lerp(self.heights[i] as f64, self.heights[i + 1] as f64, tx);
        let b = lerp(
            self.heights[i + n] as f64,
            self.heights[i + n + 1] as f64,
            tx,
        );
        lerp(a, b, tz)
    }

    pub fn ground_y(&self, p: Vector3, on_deck: bool) -> f64 {
        if on_deck {
            0.06
        } else if self.scene.in_trench(p, 0.05) {
            -1.2 + 0.15
        } else {
            self.deform_at(p)
        }
    }

    pub fn crater(&mut self, p: Vector3, size: f64) -> (Vec<u32>, Option<[i32; 4]>) {
        if self.layers[BASE][self.index(p)] >= WATER || f64::from(p.y) > 1.6 {
            return (Vec::new(), None);
        }
        let rect = if size >= 0.55 {
            self.stamp_crater(p, size)
        } else {
            None
        };
        let mut changed = Vec::new();
        if size >= 0.9 {
            let radius = 0.7 + 0.75 * size;
            let i = self.index(p);
            let cx = (i % self.n) as i32;
            let cz = (i / self.n) as i32;
            let ri = radius.ceil() as i32;
            for z in (cz - ri).max(0)..(cz + ri + 1).min(self.n as i32) {
                for x in (cx - ri).max(0)..(cx + ri + 1).min(self.n as i32) {
                    let i = z as usize * self.n + x as usize;
                    let d = self.center(i) - p;
                    if f64::from(Vector3::new(d.x, 0.0, d.z).length()) <= radius {
                        self.layers[CRATER][i] = 1;
                        changed.push(i as u32);
                    }
                }
            }
            self.refresh_ground(&changed);
            self.version += 1;
        }
        (changed, rect)
    }

    fn stamp_crater(&mut self, p: Vector3, size: f64) -> Option<[i32; 4]> {
        let radius = 0.6 + 0.8 * size;
        let depth = (0.14 + 0.3 * size).min(1.15);
        let rim = 0.06 + 0.06 * size;
        let mut rng = SimulationRandom::new(u64::from(crater_seed(p)));
        let phase1 = f64::from(rng.randf()) * std::f64::consts::TAU;
        let phase2 = f64::from(rng.randf()) * std::f64::consts::TAU;
        let k = f64::from(rng.randi_range(3, 5));
        let amp = f64::from(rng.randf_range(0.06, 0.13));
        let extent = radius * 1.9;
        let cx = (f64::from(p.x) + self.half()) * DRES as f64;
        let cz = (f64::from(p.z) + self.half()) * DRES as f64;
        let n = self.n * DRES;
        let x0 = (cx - extent * DRES as f64).floor().max(0.0) as i32;
        let x1 = (cx + extent * DRES as f64).ceil().min((n - 1) as f64) as i32;
        let z0 = (cz - extent * DRES as f64).floor().max(0.0) as i32;
        let z1 = (cz + extent * DRES as f64).ceil().min((n - 1) as f64) as i32;
        if x1 < x0 || z1 < z0 {
            return None;
        }
        for z in z0..=z1 {
            for x in x0..=x1 {
                let dx = (x as f64 + 0.5) / DRES as f64 - self.half() - f64::from(p.x);
                let dz = (z as f64 + 0.5) / DRES as f64 - self.half() - f64::from(p.z);
                let r = (dx * dx + dz * dz).sqrt();
                if r > extent {
                    continue;
                }
                let angle = dz.atan2(dx);
                let rr = r
                    / (radius
                        * (1.0
                            + amp * (angle * k + phase1).sin()
                            + amp * 0.5 * (angle * (k + 2.0) + phase2).sin()));
                let i = z as usize * n + x as usize;
                let old = f64::from(self.heights[i]);
                let mut height = old;
                if rr < 1.0 {
                    let bowl = -depth * (1.0 - rr * rr).powf(1.25);
                    height = (old + bowl * 0.35).min(bowl + old * 0.25);
                }
                height += rim
                    * (-((rr - 1.02) / 0.3).powf(2.0)).exp()
                    * (1.0 + 0.35 * (angle * 7.0 + phase2).sin());
                self.heights[i] = height.clamp(-1.4, 0.55) as f32;
            }
        }
        Some([x0, z0, x1 - x0 + 1, z1 - z0 + 1])
    }

    pub fn checkpoint(&self) -> Vec<u8> {
        let mut out = Writer::new(b"FLTR\x02\0\0\0");
        out.u32(self.n as u32);
        out.u64(self.version);
        out.byte(u8::from(self.fresh));
        for layer in &self.layers {
            out.bytes(layer);
        }
        out.u32(self.heights.len() as u32);
        for &h in &self.heights {
            out.f32(h);
        }
        // Consumed queue slots do not affect later append order or decisions.
        out.u32((self.queue.len() - self.head) as u32);
        for &i in &self.queue[self.head..] {
            out.u32(i);
        }
        out.bytes(&self.scene.checkpoint());
        out.0
    }

    pub fn restore(bytes: &[u8]) -> Result<Self, &'static str> {
        let mut input = Reader::new(bytes, b"FLTR\x02\0\0\0")?;
        let n = input.u32()? as usize;
        if !(2..=3072).contains(&n) {
            return Err("invalid terrain dimensions");
        }
        let version = input.u64()?;
        if version > i64::MAX as u64 / 2 {
            return Err("invalid terrain revision");
        }
        let fresh = input.boolean()?;
        let mut layers = std::array::from_fn(|_| Vec::new());
        for layer in &mut layers {
            *layer = input.bytes(n * n)?.to_vec();
            if layer.len() != n * n {
                return Err("wrong terrain layer length");
            }
        }
        let count = input.u32()? as usize;
        if count != n * n * DRES * DRES {
            return Err("wrong terrain height length");
        }
        // Validate the encoded height block before reserving its full size.
        let mut heights = Vec::new();
        for _ in 0..count {
            heights.push(input.f32()?);
        }
        let mut state = Self::new(n, layers, heights).ok_or("invalid terrain data")?;
        state.version = version;
        state.fresh = fresh;
        let count = input.u32()? as usize;
        if count > n * n {
            return Err("too many pending terrain cells");
        }
        for _ in 0..count {
            let i = input.u32()? as usize;
            if i >= n * n || state.dirty[i] {
                return Err("invalid pending terrain cell");
            }
            state.dirty[i] = true;
            state.queue.push(i as u32);
        }
        state.scene = CoverScene::restore(input.bytes(512 * 1024 * 1024)?)?;
        input.finish()?;
        Ok(state)
    }
}

pub fn ground_cover(crater: u8, rubble: u8, woods: u8, base: u8) -> i32 {
    if crater > 0 || rubble > 0 || (woods > 0 && base != ROAD) {
        1
    } else if base == ROAD || base == MUD {
        -1
    } else {
        0
    }
}

fn valid_layers(layers: &[Vec<u8>; 9]) -> bool {
    layers[BASE].iter().all(|v| *v <= SHALLOW)
        && layers[COVER].iter().all(|v| *v <= 3)
        && layers[DIRECTION].iter().all(|v| *v <= OMNI || *v == 255)
        && [CRATER, RUBBLE, SOLID, TRENCH, NETTED]
            .iter()
            .all(|i| layers[*i].iter().all(|v| *v <= 1))
}

// Godot 4.7 Vector2i::hash and Murmur3, retained for identical crater shapes.
pub fn crater_seed(p: Vector3) -> u32 {
    fn mix(value: u32, seed: u32) -> u32 {
        let k = value
            .wrapping_mul(0xcc9e2d51)
            .rotate_left(15)
            .wrapping_mul(0x1b873593);
        (seed ^ k)
            .rotate_left(13)
            .wrapping_mul(5)
            .wrapping_add(0xe6546b64)
    }
    let x = (f64::from(p.x) * 8.0).round() as i32;
    let z = (f64::from(p.z) * 8.0).round() as i32;
    let mut h = mix(z as u32, mix(x as u32, 0x07f07c65));
    h ^= h >> 16;
    h = h.wrapping_mul(0x85ebca6b);
    h ^= h >> 13;
    h = h.wrapping_mul(0xc2b2ae35);
    h ^ (h >> 16)
}
