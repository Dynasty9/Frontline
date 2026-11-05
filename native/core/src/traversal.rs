//! Exact foot clearance shares the planning grid's obstacle ownership.
use crate::state_codec::{Reader, Writer};
use crate::terrain::Terrain;
use crate::vector::Vector3;
use glam::Vec2;
use std::collections::BTreeMap;

pub(crate) const MAX_REFERENCES: usize = 10_000_000;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Obstacle {
    pub id: u32,
    pub infantry: u8,
    pub vehicle: u8,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Footprint {
    pub center: Vec2,
    pub half: Vec2,
    pub yaw: f64,
}
impl Footprint {
    fn valid(&self) -> bool {
        self.center.is_finite()
            && self.center.abs().max_element() <= 1_000_000.
            && self.half.is_finite()
            && self.half.min_element() >= 0.
            && self.half.max_element() <= 4096.
            && self.yaw.is_finite()
            && self.yaw.abs() <= 1_000_000.
    }
    fn contains(&self, p: Vector3) -> bool {
        let (s, c) = (libm::sin(self.yaw) as f32, libm::cos(self.yaw) as f32);
        let d = Vec2::new(p.x, p.z) - self.center;
        d.dot(Vec2::new(c, -s)).abs() <= self.half.x && d.dot(Vec2::new(s, c)).abs() <= self.half.y
    }
}

#[derive(Default)]
pub struct Occupancy {
    pub(crate) cells: BTreeMap<u32, Vec<Obstacle>>,
    pub(crate) references: usize,
    footprints: BTreeMap<u32, Vec<Footprint>>,
}
impl Occupancy {
    pub fn set_cell(&mut self, index: u32, items: Vec<Obstacle>) -> bool {
        let previous = self.cells.get(&index).map_or(0, Vec::len);
        if items.len() > MAX_REFERENCES - (self.references - previous)
            || items.iter().any(|o| {
                o.id == 0 || o.infantry > 3 || o.vehicle > 3 || (o.infantry == 0 && o.vehicle == 0)
            })
        {
            return false;
        }
        self.references = self.references - previous + items.len();
        if items.is_empty() {
            self.cells.remove(&index);
        } else {
            self.cells.insert(index, items);
        }
        true
    }
    pub fn set_footprints(&mut self, id: u32, parts: Vec<Footprint>) -> bool {
        if id == 0
            || parts.len() > 4096
            || parts.iter().any(|p| !p.valid())
            || (!self.footprints.contains_key(&id) && self.footprints.len() >= 100_000)
        {
            return false;
        }
        if parts.is_empty() {
            self.footprints.remove(&id);
        } else {
            self.footprints.insert(id, parts);
        }
        true
    }
    pub fn remove_footprints(&mut self, id: u32) {
        self.footprints.remove(&id);
    }

    pub(crate) fn clear(&self, index: usize, p: Vector3) -> bool {
        let Some(objects) = self.cells.get(&(index as u32)) else {
            return false;
        };
        for object in objects {
            if object.infantry != 3 {
                continue;
            }
            let Some(parts) = self.footprints.get(&object.id) else {
                return false;
            };
            if parts.iter().any(|part| part.contains(p)) {
                return false;
            }
        }
        true
    }
    pub(crate) fn write(&self, out: &mut Writer) {
        out.u32(self.cells.len() as u32);
        for (index, items) in &self.cells {
            out.u32(*index);
            out.u32(items.len() as u32);
            for o in items {
                out.u32(o.id);
                out.byte(o.infantry);
                out.byte(o.vehicle);
            }
        }
        out.u32(self.footprints.len() as u32);
        for (id, parts) in &self.footprints {
            out.u32(*id);
            out.u32(parts.len() as u32);
            for p in parts {
                for n in [p.center.x, p.center.y, p.half.x, p.half.y] {
                    out.f32(n);
                }
                out.f64(p.yaw);
            }
        }
    }
    pub(crate) fn read(input: &mut Reader<'_>, side: usize) -> Result<Self, &'static str> {
        let mut out = Self::default();
        let count = input.u32()? as usize;
        if count > side * side {
            return Err("too many occupied navigation cells");
        }
        for _ in 0..count {
            let index = input.u32()?;
            let count = input.u32()? as usize;
            if index as usize >= side * side
                || count == 0
                || count > MAX_REFERENCES - out.references
                || out.cells.contains_key(&index)
            {
                return Err("invalid navigation occupancy");
            }
            let mut items = Vec::new();
            for _ in 0..count {
                items.push(Obstacle {
                    id: input.u32()?,
                    infantry: input.byte()?,
                    vehicle: input.byte()?,
                });
            }
            if !out.set_cell(index, items) {
                return Err("invalid navigation obstacle");
            }
        }
        let count = input.u32()? as usize;
        if count > 100_000 {
            return Err("too many navigation footprints");
        }
        for _ in 0..count {
            let id = input.u32()?;
            let count = input.u32()? as usize;
            if count == 0 || count > 4096 || out.footprints.contains_key(&id) {
                return Err("invalid navigation footprint count");
            }
            let mut parts = Vec::new();
            for _ in 0..count {
                parts.push(Footprint {
                    center: Vec2::new(input.f32()?, input.f32()?),
                    half: Vec2::new(input.f32()?, input.f32()?),
                    yaw: input.f64()?,
                });
            }
            if !out.set_footprints(id, parts) {
                return Err("invalid navigation footprint");
            }
        }
        Ok(out)
    }
}

/// The planner borrows the live heightfield; geometry edits never copy it.
#[derive(Clone, Copy, Default)]
pub struct Ground<'a> {
    pub terrain: Option<&'a Terrain>,
    pub deck: &'a [u8],
}
impl<'a> Ground<'a> {
    pub fn new(terrain: &'a Terrain, deck: &'a [u8]) -> Self {
        Self {
            terrain: Some(terrain),
            deck,
        }
    }
    pub fn valid_for(self, side: usize) -> bool {
        self.terrain.is_none_or(|t| t.n == side)
            && (self.deck.is_empty() || self.deck.len() == side * side)
    }
    pub fn too_deep(self, p: Vector3) -> bool {
        self.terrain.is_some_and(|t| t.too_deep(p, self.deck))
    }
    pub fn height(self, p: Vector3) -> f64 {
        self.terrain.map_or(0.0, |t| {
            t.ground_y(p, self.deck.get(t.index(p)) == Some(&1))
        })
    }
    pub fn depth(self, p: Vector3) -> f64 {
        self.terrain.map_or(0.0, |t| t.water_depth(p, self.deck))
    }
}
