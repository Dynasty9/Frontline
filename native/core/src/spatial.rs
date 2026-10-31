//! Bucket membership is retained separately from actor positions: units move within a simulation step.
use crate::actors::{Actor, Actors};
use crate::infantry_vitals::Life;
use crate::state_codec::{Reader, Writer};
use crate::vector::Vector3;
use std::collections::{BTreeMap, HashMap, HashSet};

pub const UNIT_CELL: f64 = 12.0;
pub const STRUCTURE_CELL: f64 = 16.0;
pub const DOOR_CELL: f64 = 1.5;
const MAX_CELLS: usize = 1_000_000;
const MAX_ENTRIES: usize = 10_000_000;
type Cell = (i32, i32);

#[derive(Clone, Debug)]
pub struct SpatialIndex {
    cell_size: f64,
    cells: BTreeMap<Cell, Vec<u32>>,
    membership: HashMap<u32, Vec<Cell>>,
    entries: usize,
}
fn point(p: Vector3) -> bool {
    p.is_finite() && p.abs().max_element() <= 1_000_000.0
}
fn size(v: f64) -> bool {
    v.is_finite() && (0.25..=1024.0).contains(&v)
}
fn radius(v: f64) -> bool {
    v.is_finite() && (0.0..=1_000_000.0).contains(&v)
}
fn cell_ok((x, z): Cell) -> bool {
    (-8_000_000..=8_000_000).contains(&x) && (-8_000_000..=8_000_000).contains(&z)
}

impl SpatialIndex {
    pub fn new(cell_size: f64) -> Result<Self, &'static str> {
        if !size(cell_size) {
            return Err("invalid spatial cell size");
        }
        Ok(Self {
            cell_size,
            cells: BTreeMap::new(),
            membership: HashMap::new(),
            entries: 0,
        })
    }
    pub fn from_cells(cell_size: f64, cells: Vec<(Cell, Vec<u32>)>) -> Result<Self, &'static str> {
        let mut index = Self::new(cell_size)?;
        if cells.len() > MAX_CELLS {
            return Err("too many spatial cells");
        }
        let mut seen = HashSet::new();
        for (key, ids) in cells {
            if !cell_ok(key)
                || index.cells.contains_key(&key)
                || ids.is_empty()
                || index.entries + ids.len() > MAX_ENTRIES
            {
                return Err("invalid spatial cells");
            }
            seen.clear();
            if ids.iter().any(|&id| id == 0 || !seen.insert(id)) {
                return Err("invalid spatial identities");
            }
            for &id in &ids {
                index.membership.entry(id).or_default().push(key);
            }
            index.entries += ids.len();
            index.cells.insert(key, ids);
        }
        Ok(index)
    }
    pub fn cell_size(&self) -> f64 {
        self.cell_size
    }
    pub fn cells(&self) -> impl Iterator<Item = (Cell, &[u32])> {
        self.cells.iter().map(|(&cell, ids)| (cell, ids.as_slice()))
    }
    pub fn clear(&mut self) {
        self.cells.clear();
        self.membership.clear();
        self.entries = 0;
    }
    pub fn remove(&mut self, id: u32) -> bool {
        let Some(keys) = self.membership.remove(&id) else {
            return false;
        };
        for key in keys {
            let ids = self.cells.get_mut(&key).unwrap();
            ids.retain(|&v| v != id);
            self.entries -= 1;
            if ids.is_empty() {
                self.cells.remove(&key);
            }
        }
        true
    }
    fn bounds(&self, p: Vector3, r: f64) -> Result<(Cell, Cell), &'static str> {
        if !point(p) || !radius(r) {
            return Err("invalid spatial query");
        }
        let coordinate = |v: f64| libm::floor(v / self.cell_size) as i32;
        Ok((
            (
                coordinate(f64::from(p.x) - r),
                coordinate(f64::from(p.z) - r),
            ),
            (
                coordinate(f64::from(p.x) + r),
                coordinate(f64::from(p.z) + r),
            ),
        ))
    }
    pub fn insert(&mut self, id: u32, p: Vector3, r: f64) -> Result<(), &'static str> {
        let bounds = self.bounds(p, r)?;
        self.insert_cells(id, bounds)
    }
    pub fn insert_door(&mut self, id: u32, p: Vector3) -> Result<(), &'static str> {
        if self.cell_size != DOOR_CELL {
            return Err("invalid door grid");
        }
        let ((x, z), _) = self.bounds(p, 0.0)?;
        self.insert_cells(id, ((x - 1, z - 1), (x + 1, z + 1)))
    }
    fn insert_cells(
        &mut self,
        id: u32,
        ((x0, z0), (x1, z1)): (Cell, Cell),
    ) -> Result<(), &'static str> {
        if id == 0 {
            return Err("invalid spatial identity");
        }
        let count = (i64::from(x1) - i64::from(x0) + 1) * (i64::from(z1) - i64::from(z0) + 1);
        if count > MAX_CELLS as i64
            || self.entries - self.membership.get(&id).map_or(0, Vec::len) + count as usize
                > MAX_ENTRIES
        {
            return Err("spatial membership exceeds limit");
        }
        let mut keys = Vec::with_capacity(count as usize);
        let mut new_cells = 0;
        for x in x0..=x1 {
            for z in z0..=z1 {
                let key = (x, z);
                if !self.cells.contains_key(&key) {
                    new_cells += 1;
                }
                keys.push(key);
            }
        }
        // Count cells removed by replacing this identity before accepting an expansion.
        let removed = self.membership.get(&id).map_or(0, |old| {
            old.iter()
                .filter(|&&key| {
                    self.cells[&key].len() == 1
                        && (key.0 < x0 || key.0 > x1 || key.1 < z0 || key.1 > z1)
                })
                .count()
        });
        if self.cells.len() + new_cells - removed > MAX_CELLS {
            return Err("spatial index exceeds limit");
        }
        self.remove(id);
        for &key in &keys {
            self.cells.entry(key).or_default().push(id);
        }
        self.entries += keys.len();
        self.membership.insert(id, keys);
        Ok(())
    }
    pub fn candidates(
        &self,
        p: Vector3,
        r: f64,
    ) -> Result<impl Iterator<Item = u32> + '_, &'static str> {
        let ((x0, z0), (x1, z1)) = self.bounds(p, r)?;
        // Visit occupied cells in the game's x-then-z order without scanning a huge empty rectangle.
        Ok(self
            .cells
            .range((x0, i32::MIN)..=(x1, i32::MAX))
            .filter(move |(&(.., z), _)| z >= z0 && z <= z1)
            .flat_map(|(_, ids)| ids.iter().copied()))
    }
    pub fn at(&self, p: Vector3) -> Result<&[u32], &'static str> {
        let (key, _) = self.bounds(p, 0.0)?;
        Ok(self.cells.get(&key).map_or(&[], Vec::as_slice))
    }
    pub fn checkpoint(&self) -> Vec<u8> {
        let mut w = Writer::new(b"FLSX\x01\0\0\0");
        w.f64(self.cell_size);
        w.u32(self.cells.len() as u32);
        for ((x, z), ids) in self.cells() {
            w.u32(x as u32);
            w.u32(z as u32);
            w.u32(ids.len() as u32);
            for &id in ids {
                w.u32(id);
            }
        }
        w.0
    }
    pub fn restore(bytes: &[u8]) -> Result<Self, &'static str> {
        if bytes.len() > 64 * 1024 * 1024 {
            return Err("spatial checkpoint exceeds limit");
        }
        let mut r = Reader::new(bytes, b"FLSX\x01\0\0\0")?;
        let cell_size = r.f64()?;
        let count = r.u32()? as usize;
        if count > MAX_CELLS || !size(cell_size) {
            return Err("invalid spatial checkpoint");
        }
        let mut cells = Vec::new();
        let mut entries = 0;
        let mut previous = None;
        for _ in 0..count {
            let key = (r.u32()? as i32, r.u32()? as i32);
            let n = r.u32()? as usize;
            if previous.is_some_and(|p| p >= key) || n == 0 || entries + n > MAX_ENTRIES {
                return Err("invalid spatial checkpoint cells");
            }
            let mut ids = Vec::new();
            for _ in 0..n {
                ids.push(r.u32()?);
            }
            cells.push((key, ids));
            entries += n;
            previous = Some(key);
        }
        r.finish()?;
        Self::from_cells(cell_size, cells)
    }
}

impl Actors {
    pub fn rebuild_units(&self, index: &mut SpatialIndex) -> Result<(), &'static str> {
        if index.cell_size() != UNIT_CELL {
            return Err("invalid unit grid");
        }
        // Validate before touching live buckets, then reuse their capacity for the next step.
        for actor in self.iter() {
            if let Actor::Soldier(s) = actor {
                if s.vitals.life != Life::Hidden {
                    index.bounds(s.motion.position, 0.0)?;
                }
            }
            if let Actor::Vehicle(v) = actor {
                index.bounds(v.position, 0.0)?;
            }
        }
        for ids in index.cells.values_mut() {
            ids.clear();
        }
        for keys in index.membership.values_mut() {
            keys.clear();
        }
        index.entries = 0;
        for actor in self.iter() {
            if let Actor::Soldier(s) = actor {
                if s.vitals.life != Life::Hidden {
                    let (key, _) = index.bounds(s.motion.position, 0.0).unwrap();
                    index.cells.entry(key).or_default().push(s.identity.id);
                    index.membership.entry(s.identity.id).or_default().push(key);
                    index.entries += 1;
                }
            }
        }
        // World registers soldiers first, then vehicles, even when their entity IDs interleave.
        for actor in self.iter() {
            if let Actor::Vehicle(v) = actor {
                let (key, _) = index.bounds(v.position, 0.0).unwrap();
                index.cells.entry(key).or_default().push(v.id);
                index.membership.entry(v.id).or_default().push(key);
                index.entries += 1;
            }
        }
        index.cells.retain(|_, ids| !ids.is_empty());
        index.membership.retain(|_, keys| !keys.is_empty());
        Ok(())
    }
    pub fn units_near(
        &self,
        index: &SpatialIndex,
        p: Vector3,
        r: f64,
        enemy_of: i8,
    ) -> Result<Vec<u32>, &'static str> {
        if !(-1..=1).contains(&enemy_of) || index.cell_size() != UNIT_CELL {
            return Err("invalid unit query");
        }
        let mut found = Vec::new();
        for id in index.candidates(p, r)? {
            let (position, team) = match self.get(id) {
                Some(Actor::Soldier(s)) => (s.motion.position, s.identity.team),
                Some(Actor::Vehicle(v)) => (v.position, v.team),
                _ => continue,
            };
            if enemy_of >= 0 && (team == enemy_of || team < 0) {
                continue;
            }
            let dx = f64::from(position.x) - f64::from(p.x);
            let dz = f64::from(position.z) - f64::from(p.z);
            if dx * dx + dz * dz <= r * r {
                found.push(id);
            }
        }
        Ok(found)
    }
    pub fn structures_near(
        &self,
        index: &SpatialIndex,
        p: Vector3,
        r: f64,
        floors_only: bool,
    ) -> Result<Vec<u32>, &'static str> {
        if index.cell_size() != STRUCTURE_CELL {
            return Err("invalid structure grid");
        }
        let mut found = Vec::new();
        let mut seen = HashSet::new();
        for id in index.candidates(p, r)? {
            let Some(s) = self.structure(id) else {
                continue;
            };
            if floors_only && s.kind != "floor" || !seen.insert(id) {
                continue;
            }
            let d = s.position - p;
            if f64::from(Vector3::new(d.x, 0.0, d.z).length()) <= r + s.radius {
                found.push(id);
            }
        }
        Ok(found)
    }
    pub fn door_in_way(
        &self,
        index: &SpatialIndex,
        p: Vector3,
        direction: Vector3,
    ) -> Result<Option<u32>, &'static str> {
        if index.cell_size() != DOOR_CELL || !point(direction) {
            return Err("invalid door query");
        }
        Ok(index.at(p)?.iter().copied().find(|&id| {
            self.structure(id)
                .is_some_and(|s| s.door_blocks(p, direction))
        }))
    }
}
