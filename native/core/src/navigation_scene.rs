//! Shared obstacle ownership keeps geometry edits, fire costs and both route hierarchies together.
use crate::cover::{rotation, transform};
use crate::hierarchy::{self, Hierarchy};
use crate::path_planner::PathPlanner;
use crate::state_codec::{Reader, Writer};
use crate::structure::Structure;
use crate::terrain::{Terrain, BASE, WATER};
use crate::vector::Vector3;
use glam::Vec2;
use std::collections::{BTreeMap, HashSet};

const MAX_REFERENCES: usize = 10_000_000;
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Obstacle {
    pub id: u32,
    pub infantry: u8,
    pub vehicle: u8,
}
pub struct NavigationScene {
    pub planner: PathPlanner,
    pub infantry: Hierarchy,
    pub vehicles: Hierarchy,
    cells: BTreeMap<u32, Vec<Obstacle>>,
    references: usize,
}
impl NavigationScene {
    pub fn new(terrain: &Terrain, deck: &[u8], cluster_side: usize) -> Result<Self, &'static str> {
        let n = terrain.n;
        if !matches!(cluster_side, 16 | 32) || n > 3072 || (!deck.is_empty() && deck.len() != n * n)
        {
            return Err("invalid navigation deck");
        }
        let mut out = Self {
            planner: PathPlanner::new(n).ok_or("invalid navigation size")?,
            infantry: Hierarchy::new(n, cluster_side).ok_or("invalid navigation size")?,
            vehicles: Hierarchy::new(n, cluster_side).ok_or("invalid navigation size")?,
            cells: BTreeMap::new(),
            references: 0,
        };
        for index in 0..n * n {
            out.recompute(index, terrain, deck);
        }
        Ok(out)
    }
    pub fn obstacles(&self) -> &BTreeMap<u32, Vec<Obstacle>> {
        &self.cells
    }
    pub fn finalize(&mut self, workers: usize) -> bool {
        hierarchy::build_all(&mut [&mut self.infantry, &mut self.vehicles], workers)
    }
    pub fn update_hierarchy(&mut self, clusters: usize) -> bool {
        for _ in 0..clusters {
            let graph = if self.infantry.has_work() {
                &mut self.infantry
            } else if self.vehicles.has_work() {
                &mut self.vehicles
            } else {
                return true;
            };
            if !graph.update(1) {
                return false;
            }
        }
        true
    }
    fn context(&self, terrain: &Terrain, deck: &[u8]) -> bool {
        terrain.n == self.planner.side() && (deck.is_empty() || deck.len() == terrain.n * terrain.n)
    }
    fn recompute(&mut self, index: usize, terrain: &Terrain, deck: &[u8]) {
        let n = terrain.n;
        let mut kinds = [0, 0];
        for obstacle in self.cells.get(&(index as u32)).into_iter().flatten() {
            kinds[0] = kinds[0].max(obstacle.infantry);
            kinds[1] = kinds[1].max(obstacle.vehicle);
        }
        if terrain.layers[BASE][index] == WATER && deck.get(index).copied().unwrap_or(0) == 0 {
            kinds = [3, 3];
        }
        let heat = self.planner.cell_state(index).unwrap()[2];
        self.planner.set_cell(index, kinds[0], kinds[1], heat);
        let mut infantry = terrain.nav_weight(index, false);
        let mut vehicle = terrain.nav_weight(index, true);
        if heat > 0 {
            infantry *= 8.0;
            vehicle *= 2.5;
        }
        infantry *= [1.0, 4.0, 7.0, 1.0][kinds[0] as usize];
        vehicle *= if kinds[1] == 0 { 1.0 } else { 9.0 };
        let x = index % n;
        let z = index / n;
        let cell = [x as i32, z as i32];
        self.infantry.set_cell(cell, kinds[0] == 3, infantry as f32);
        self.vehicles.set_cell(
            cell,
            kinds[1] == 3 || x < 3 || z < 3 || x >= n - 3 || z >= n - 3,
            vehicle as f32,
        );
    }
    pub fn terrain_changed(
        &mut self,
        index: usize,
        terrain: &Terrain,
        deck: &[u8],
    ) -> Result<(), &'static str> {
        if !self.context(terrain, deck) || index >= terrain.n * terrain.n {
            return Err("invalid navigation terrain edit");
        }
        self.recompute(index, terrain, deck);
        Ok(())
    }
    pub fn add_structure(
        &mut self,
        st: &mut Structure,
        terrain: &Terrain,
        deck: &[u8],
    ) -> Result<(), &'static str> {
        if !self.context(terrain, deck)
            || !st.valid()
            || st.gone
            || st.parts.iter().any(|p| p.size.min_element() < 0.0)
        {
            return Err("invalid navigation structure");
        }
        let n = terrain.n;
        let half = n as f64 * 0.5;
        let basis = rotation(st.yaw);
        let mut added = vec![];
        for part in &st.parts {
            if part.infantry == 0 && part.vehicle == 0 {
                continue;
            }
            let center = st.position + transform(basis, part.position);
            let center = Vec2::new(center.x, center.z);
            let h = Vec2::new(part.size.x * 0.5, part.size.z * 0.5);
            let yaw = st.yaw + part.yaw;
            let cosine = libm::cos(yaw);
            let sine = libm::sin(yaw);
            let axes = [
                Vec2::new(cosine as f32, -sine as f32),
                Vec2::new(sine as f32, cosine as f32),
            ];
            let pad = if part.vehicle != 0 { 1.7 } else { 0.25 };
            let ex = cosine.abs() * (f64::from(h.x) + pad) + sine.abs() * (f64::from(h.y) + pad);
            let ez = sine.abs() * (f64::from(h.x) + pad) + cosine.abs() * (f64::from(h.y) + pad);
            let bound = |value: f64| libm::floor(value + half).clamp(0.0, n as f64 - 1.0) as usize;
            let hi = h + Vec2::splat(0.25);
            let hv = h + Vec2::splat(1.7);
            for x in bound(f64::from(center.x) - ex)..=bound(f64::from(center.x) + ex) {
                for z in bound(f64::from(center.y) - ez)..=bound(f64::from(center.y) + ez) {
                    let p = Vec2::new(
                        (x as f64 - half + 0.5) as f32,
                        (z as f64 - half + 0.5) as f32,
                    ) - center;
                    let inside =
                        |h: Vec2| p.dot(axes[0]).abs() <= h.x && p.dot(axes[1]).abs() <= h.y;
                    let infantry = if part.infantry != 0 && inside(hi) {
                        part.infantry
                    } else {
                        0
                    };
                    let vehicle = if part.vehicle != 0 && inside(hv) {
                        part.vehicle
                    } else {
                        0
                    };
                    if infantry == 0 && vehicle == 0 {
                        continue;
                    }
                    if self.references + added.len() >= MAX_REFERENCES
                        || st.nav_cells.len() + added.len() >= MAX_REFERENCES
                    {
                        return Err("navigation obstacle limit exceeded");
                    }
                    added.push((
                        (z * n + x) as u32,
                        Obstacle {
                            id: st.id,
                            infantry,
                            vehicle,
                        },
                    ));
                }
            }
        }
        self.references += added.len();
        for (index, obstacle) in added {
            self.cells.entry(index).or_default().push(obstacle);
            st.nav_cells.push(index);
            self.recompute(index as usize, terrain, deck);
        }
        Ok(())
    }
    pub fn remove_structure(
        &mut self,
        st: &mut Structure,
        terrain: &Terrain,
        deck: &[u8],
    ) -> Result<(), &'static str> {
        if !self.context(terrain, deck)
            || st
                .nav_cells
                .iter()
                .any(|&i| i as usize >= terrain.n * terrain.n)
        {
            return Err("invalid navigation removal");
        }
        let mut touched = HashSet::new();
        for index in st.nav_cells.drain(..) {
            if !touched.insert(index) {
                continue;
            }
            if let Some(obstacles) = self.cells.get_mut(&index) {
                let count = obstacles.len();
                obstacles.retain(|o| o.id != st.id);
                self.references -= count - obstacles.len();
                if obstacles.is_empty() {
                    self.cells.remove(&index);
                }
            }
            self.recompute(index as usize, terrain, deck);
        }
        Ok(())
    }
    pub fn stamp_heat(
        &mut self,
        p: Vector3,
        radius: f64,
        delta: i8,
        terrain: &Terrain,
        deck: &[u8],
    ) -> Result<(), &'static str> {
        if !self.context(terrain, deck)
            || !p.is_finite()
            || p.abs().max_element() > 1_000_000.0
            || !radius.is_finite()
            || !(0.0..=8192.0).contains(&radius)
            || ![-1, 1].contains(&delta)
        {
            return Err("invalid navigation heat");
        }
        let n = terrain.n as i32;
        let half = f64::from(n) * 0.5;
        let cell = [p.x, p.z]
            .map(|v| libm::floor(f64::from(v) + half).clamp(0.0, f64::from(n - 1)) as i32);
        let reach = libm::ceil(radius) as i32;
        for z in (cell[1] - reach).max(0)..(cell[1] + reach + 1).min(n) {
            for x in (cell[0] - reach).max(0)..(cell[0] + reach + 1).min(n) {
                let d = Vec2::new(
                    (f64::from(x) + 0.5 - half - f64::from(p.x)) as f32,
                    (f64::from(z) + 0.5 - half - f64::from(p.z)) as f32,
                );
                if f64::from(d.length()) > radius {
                    continue;
                }
                let index = (z * n + x) as usize;
                let [i, v, old] = self.planner.cell_state(index).unwrap();
                let heat = (i16::from(old) + i16::from(delta)).clamp(0, 255) as u8;
                self.planner.set_cell(index, i, v, heat);
                if (heat > 0) != (old > 0) {
                    self.recompute(index, terrain, deck);
                }
            }
        }
        Ok(())
    }
    pub fn checkpoint(&self) -> Vec<u8> {
        let mut w = Writer::new(b"FLNS\x01\0\0\0");
        w.bytes(&self.planner.checkpoint());
        w.bytes(&self.infantry.checkpoint());
        w.bytes(&self.vehicles.checkpoint());
        w.u32(self.cells.len() as u32);
        for (index, obstacles) in &self.cells {
            w.u32(*index);
            w.u32(obstacles.len() as u32);
            for o in obstacles {
                w.u32(o.id);
                w.byte(o.infantry);
                w.byte(o.vehicle);
            }
        }
        w.0
    }
    pub fn restore(bytes: &[u8]) -> Result<Self, &'static str> {
        let mut r = Reader::new(bytes, b"FLNS\x01\0\0\0")?;
        let planner = PathPlanner::restore(r.bytes(512 * 1024 * 1024)?)?;
        let infantry = Hierarchy::restore(r.bytes(512 * 1024 * 1024)?)?;
        let vehicles = Hierarchy::restore(r.bytes(512 * 1024 * 1024)?)?;
        let n = planner.side();
        let count = r.u32()? as usize;
        if n > 3072
            || n != infantry.side()
            || n != vehicles.side()
            || count > n * n
            || !matches!(infantry.cluster_side(), 16 | 32)
            || infantry.cluster_side() != vehicles.cluster_side()
        {
            return Err("invalid navigation checkpoint dimensions");
        }
        let mut cells = BTreeMap::new();
        let mut references = 0;
        for _ in 0..count {
            let index = r.u32()?;
            let count = r.u32()? as usize;
            if index as usize >= n * n
                || count == 0
                || count > MAX_REFERENCES - references
                || cells.contains_key(&index)
            {
                return Err("invalid navigation occupancy");
            }
            let mut obstacles = vec![];
            for _ in 0..count {
                let o = Obstacle {
                    id: r.u32()?,
                    infantry: r.byte()?,
                    vehicle: r.byte()?,
                };
                if o.id == 0 || o.infantry > 3 || o.vehicle > 3 || o.infantry == 0 && o.vehicle == 0
                {
                    return Err("invalid navigation obstacle");
                }
                obstacles.push(o);
            }
            references += count;
            cells.insert(index, obstacles);
        }
        r.finish()?;
        Ok(Self {
            planner,
            infantry,
            vehicles,
            cells,
            references,
        })
    }
}
