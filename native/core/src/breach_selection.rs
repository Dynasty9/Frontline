//! House contacts keep encounter order; the nearest opening only wins within that contact.
use crate::breach::stack_spot;
use crate::cover::{rotation, transform};
use crate::path_planner::PathPlanner;
use crate::vector::{normalized, Vector3};

#[derive(Clone, Copy, Debug)]
pub struct Building {
    pub id: u64,
    pub position: Vector3,
    pub size: Vector3,
    pub yaw: f64,
    /// 0 floor, 1 window, 2 door, 3 other structure.
    pub kind: u8,
    pub gone: bool,
    pub wrecked: bool,
}

impl Building {
    pub fn valid(&self) -> bool {
        self.id > 0
            && self.id <= i64::MAX as u64
            && point(self.position)
            && point(self.size)
            && self.size.min_element() >= 0.0
            && self.yaw.is_finite()
            && self.yaw.abs() <= 1_000_000.0
            && self.kind <= 3
    }
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Opening {
    pub id: u64,
    pub center: Vector3,
    pub normal: Vector3,
    pub door: bool,
}

impl Opening {
    pub fn valid(&self) -> bool {
        self.id > 0 && self.id <= i64::MAX as u64 && point(self.center) && point(self.normal)
    }
}

fn point(p: Vector3) -> bool {
    p.is_finite() && p.abs().max_element() <= 1_000_000.0
}
fn flat(p: Vector3) -> Vector3 {
    Vector3::new(p.x, 0.0, p.z)
}

pub fn house_at(position: Vector3, houses: &[Building]) -> Result<Option<u64>, &'static str> {
    if !point(position) || houses.len() > 100_000 || houses.iter().any(|h| !h.valid()) {
        return Err("invalid house query");
    }
    Ok(houses
        .iter()
        .find(|h| {
            if h.kind != 0 || h.gone {
                return false;
            }
            let local = transform(rotation(-h.yaw), position - h.position);
            f64::from(local.x.abs()) < f64::from(h.size.x) * 0.5
                && f64::from(local.z.abs()) < f64::from(h.size.z) * 0.5
        })
        .map(|h| h.id))
}

pub fn openings(house: Building, walls: &[Building]) -> Result<Vec<Opening>, &'static str> {
    if !house.valid() || walls.len() > 100_000 || walls.iter().any(|h| !h.valid()) {
        return Err("invalid opening query");
    }
    let inverse = rotation(-house.yaw);
    Ok(walls
        .iter()
        .filter_map(|w| {
            if w.gone || w.wrecked || !matches!(w.kind, 1 | 2) {
                return None;
            }
            let local = transform(inverse, w.position - house.position);
            if f64::from(local.x.abs()) > f64::from(house.size.x) * 0.5 + 0.6
                || f64::from(local.z.abs()) > f64::from(house.size.z) * 0.5 + 0.6
            {
                return None;
            }
            let mut normal = transform(rotation(w.yaw), Vector3::Z);
            if normal.dot(flat(w.position - house.position)) < 0.0 {
                normal = -normal;
            }
            Some(Opening {
                id: w.id,
                center: flat(w.position),
                normal: normalized(flat(normal)),
                door: w.kind == 2,
            })
        })
        .collect())
}

#[derive(Clone, Debug)]
pub struct Contact {
    pub house: Building,
    pub enemy_alive: bool,
    pub openings: Vec<Opening>,
}

#[derive(Clone, Copy, Debug)]
pub struct Mate {
    pub position: Vector3,
    pub other: bool,
    pub alive: bool,
    pub idle: bool,
    pub frags: i32,
    pub mounted: bool,
}

/// Caller checks the decision timer, weapons, suppression and the squad's existing claim first.
pub fn choose(
    position: Vector3,
    hold: Vector3,
    own_house: Option<u64>,
    contacts: &[Contact],
    mates: &[Mate],
    nav: &PathPlanner,
) -> Result<Option<(usize, usize)>, &'static str> {
    if !point(position)
        || !point(hold)
        || contacts.len() > 100_000
        || mates.len() > 100_000
        || contacts.iter().map(|c| c.openings.len()).sum::<usize>() > 100_000
        || contacts
            .iter()
            .any(|c| !c.house.valid() || c.openings.iter().any(|o| !o.valid()))
        || mates.iter().any(|m| !point(m.position))
    {
        return Err("invalid breach candidates");
    }
    for (ci, c) in contacts.iter().enumerate() {
        if !c.enemy_alive
            || c.house.gone
            || Some(c.house.id) == own_house
            || f64::from(flat(c.house.position - position).length()) > 30.0
            || f64::from(flat(c.house.position - hold).length()) > 32.0
        {
            continue;
        }
        let mut best = None;
        let mut distance = 1e9;
        for (oi, o) in c.openings.iter().enumerate() {
            let stack = nav
                .nearest_walkable(stack_spot(position, o.center, o.normal, o.door)?)
                .unwrap();
            let d = f64::from(flat(stack - position).length()) + if o.door { 0.0 } else { 3.0 };
            if d < distance {
                distance = d;
                best = Some(oi);
            }
        }
        let Some(oi) = best.filter(|_| distance <= 26.0) else {
            continue;
        };
        let center = c.openings[oi].center;
        if mates.iter().any(|m| {
            m.other
                && m.alive
                && m.idle
                && m.frags > 0
                && !m.mounted
                && f64::from(flat(m.position - center).length()) < distance - 3.0
        }) {
            return Ok(None);
        }
        return Ok(Some((ci, oi)));
    }
    Ok(None)
}
