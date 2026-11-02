//! Shared obstacle ownership keeps geometry edits, fire costs and both route hierarchies together.
use crate::cover::{rotation, transform};
use crate::hierarchy::{self, Hierarchy};
use crate::path_planner::PathPlanner;
use crate::state_codec::{Reader, Writer};
use crate::structure::Structure;
use crate::terrain::Terrain;
use crate::vector::Vector3;
use glam::Vec2;
use std::collections::{BTreeMap, HashSet};

pub use crate::traversal::Obstacle;
use crate::traversal::{Footprint, MAX_REFERENCES};
pub struct NavigationScene {
    pub planner: PathPlanner,
    pub infantry: Hierarchy,
    pub vehicles: Hierarchy,
    pub tracked: Hierarchy,
    next_hierarchy: u8,
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
            tracked: Hierarchy::new(n, cluster_side).ok_or("invalid navigation size")?,
            next_hierarchy: 0,
        };
        for index in 0..n * n {
            out.recompute(index, terrain, deck);
        }
        Ok(out)
    }
    pub fn obstacles(&self) -> &BTreeMap<u32, Vec<Obstacle>> {
        &self.planner.occupancy.cells
    }
    pub fn finalize(&mut self, workers: usize) -> bool {
        hierarchy::build_all(
            &mut [&mut self.infantry, &mut self.vehicles, &mut self.tracked],
            workers,
        )
    }
    pub fn update_hierarchy(&mut self, clusters: usize) -> bool {
        for _ in 0..clusters {
            let mut found = false;
            for _ in 0..3 {
                let graph = match self.next_hierarchy {
                    0 => &mut self.infantry,
                    1 => &mut self.vehicles,
                    _ => &mut self.tracked,
                };
                self.next_hierarchy = (self.next_hierarchy + 1) % 3;
                if graph.has_work() {
                    if !graph.update(1) {
                        return false;
                    }
                    found = true;
                    break;
                }
            }
            if !found {
                return true;
            }
        }
        true
    }
    fn context(&self, terrain: &Terrain, deck: &[u8]) -> bool {
        terrain.n == self.planner.side() && (deck.is_empty() || deck.len() == terrain.n * terrain.n)
    }
    fn recompute(&mut self, index: usize, terrain: &Terrain, deck: &[u8]) {
        let n = terrain.n;
        let mut kinds = [
            u8::from(terrain.landform.cell_slope(index) > 0.85) * 3,
            u8::from(terrain.landform.vehicle_slope(index) > 0.48) * 3,
            u8::from(terrain.landform.vehicle_slope(index) > 0.65) * 3,
        ];
        for obstacle in self
            .planner
            .occupancy
            .cells
            .get(&(index as u32))
            .into_iter()
            .flatten()
        {
            kinds[0] = kinds[0].max(obstacle.infantry);
            kinds[1] = kinds[1].max(obstacle.vehicle);
            kinds[2] = kinds[2].max(obstacle.vehicle);
        }
        if terrain.cell_too_deep(terrain.center(index), deck) {
            kinds = [3, 3, 3];
        }
        let heat = self.planner.cell_state(index).unwrap()[2];
        self.planner.set_cell(index, kinds[0], kinds[1], heat);
        self.planner.set_tracked(index, kinds[2]);
        let mut infantry = terrain.nav_weight(index, false);
        let mut vehicle = terrain.nav_weight(index, true);
        if heat > 0 {
            infantry *= 8.0;
            vehicle *= 2.5;
        }
        infantry *= [1.0, 4.0, 7.0, 1.0][kinds[0] as usize];
        let tracked = vehicle * if kinds[2] == 0 { 1.0 } else { 9.0 };
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
        self.tracked.set_cell(
            cell,
            kinds[2] == 3 || x < 3 || z < 3 || x >= n - 3 || z >= n - 3,
            tracked as f32,
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
                    if self.planner.occupancy.references + added.len() >= MAX_REFERENCES
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
        let footprints = st
            .parts
            .iter()
            .filter(|p| p.infantry == 3)
            .map(|p| {
                let center = st.position + transform(basis, p.position);
                Footprint {
                    center: Vec2::new(center.x, center.z),
                    half: Vec2::new(p.size.x * 0.5, p.size.z * 0.5),
                    yaw: st.yaw + p.yaw,
                }
            })
            .collect();
        if !self.planner.occupancy.set_footprints(st.id, footprints) {
            return Err("invalid navigation footprints");
        }
        self.planner.occupancy.references += added.len();
        for (index, obstacle) in added {
            self.planner
                .occupancy
                .cells
                .entry(index)
                .or_default()
                .push(obstacle);
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
        self.planner.occupancy.remove_footprints(st.id);
        let mut touched = HashSet::new();
        for index in st.nav_cells.drain(..) {
            if !touched.insert(index) {
                continue;
            }
            if let Some(obstacles) = self.planner.occupancy.cells.get_mut(&index) {
                let count = obstacles.len();
                obstacles.retain(|o| o.id != st.id);
                self.planner.occupancy.references -= count - obstacles.len();
                if obstacles.is_empty() {
                    self.planner.occupancy.cells.remove(&index);
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
        let mut w = Writer::new(b"FLNS\x02\0\0\0");
        w.bytes(&self.planner.checkpoint());
        w.bytes(&self.infantry.checkpoint());
        w.bytes(&self.vehicles.checkpoint());
        w.bytes(&self.tracked.checkpoint());
        w.byte(self.next_hierarchy);
        w.0
    }
    pub fn restore(bytes: &[u8]) -> Result<Self, &'static str> {
        let mut r = Reader::new(bytes, b"FLNS\x02\0\0\0")?;
        let planner = PathPlanner::restore(r.bytes(512 * 1024 * 1024)?)?;
        let infantry = Hierarchy::restore(r.bytes(512 * 1024 * 1024)?)?;
        let vehicles = Hierarchy::restore(r.bytes(512 * 1024 * 1024)?)?;
        let tracked = Hierarchy::restore(r.bytes(512 * 1024 * 1024)?)?;
        let next_hierarchy = r.byte()?;
        let n = planner.side();
        if next_hierarchy > 2
            || tracked.side() != n
            || tracked.cluster_side() != infantry.cluster_side()
            || n > 3072
            || n != infantry.side()
            || n != vehicles.side()
            || !matches!(infantry.cluster_side(), 16 | 32)
            || infantry.cluster_side() != vehicles.cluster_side()
        {
            return Err("invalid navigation checkpoint dimensions");
        }
        r.finish()?;
        Ok(Self {
            planner,
            infantry,
            vehicles,
            tracked,
            next_hierarchy,
        })
    }
}
