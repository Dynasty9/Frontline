//! Ordered scavenging and resupply decisions; movement and shared stores belong to the world.
use crate::random::SimulationRandom;
use crate::state_codec::{Reader, Writer};
use crate::vector::{normalized, Vector3};

#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct SupplyTimers {
    pub scavenge_at: f64,
    pub search_at: f64,
}

#[derive(Clone, Copy, Debug)]
pub struct Body {
    pub id: u64,
    pub position: Vector3,
    pub dead: bool,
    pub loot: i32,
}

#[derive(Clone, Copy, Debug)]
pub struct Depot {
    pub id: u64,
    pub position: Vector3,
}

#[derive(Clone, Copy, Debug)]
pub struct Cache {
    pub depot: Depot,
    pub team: i32,
    pub built: bool,
    pub gone: bool,
    pub ammo_cache: bool,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Transfer {
    pub body: u64,
    pub rounds: i32,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Search {
    Wait,
    Body(u64),
    Depots,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Destination {
    pub depot: u64,
    pub cache: bool,
    pub position: Vector3,
}

fn time(v: f64) -> bool {
    v.is_finite() && v.abs() <= 1e12
}
fn point(p: Vector3) -> bool {
    p.is_finite() && p.abs().max_element() <= 1_000_000.0
}
fn id(v: u64) -> bool {
    v > 0 && v <= i64::MAX as u64
}
fn rounds(v: i32) -> bool {
    (0..=1_000_000).contains(&v)
}
fn flat(v: Vector3) -> Vector3 {
    Vector3::new(v.x, 0.0, v.z)
}
fn bodies_valid(bodies: &[Body]) -> bool {
    bodies.len() <= 100_000
        && bodies
            .iter()
            .all(|b| id(b.id) && point(b.position) && rounds(b.loot))
}

impl SupplyTimers {
    pub fn valid(self) -> bool {
        time(self.scavenge_at) && time(self.search_at)
    }

    // Candidates retain the world's 3.2 m query order, regardless of their former side.
    pub fn scavenge(
        &mut self,
        now: f64,
        total: i32,
        capacity: Option<i32>,
        bodies: &[Body],
    ) -> Result<Option<Transfer>, &'static str> {
        if !self.valid()
            || !time(now)
            || now.abs() > 1e12 - 10.0
            || !(0..=2_000_000).contains(&total)
            || capacity.is_some_and(|v| !rounds(v))
            || !bodies_valid(bodies)
        {
            return Err("invalid scavenging input");
        }
        let Some(capacity) = capacity else {
            return Ok(None);
        };
        if now < self.scavenge_at
            || capacity >= 9000
            || total >= (f64::from(capacity) * 0.65) as i32
        {
            return Ok(None);
        }
        self.scavenge_at = now + 1.5;
        Ok(bodies
            .iter()
            .find(|b| b.dead && b.loot > 0)
            .map(|b| Transfer {
                body: b.id,
                rounds: (capacity - total).min(b.loot),
            }))
    }

    pub fn search_bodies(
        &mut self,
        now: f64,
        position: Vector3,
        bodies: &[Body],
    ) -> Result<Search, &'static str> {
        if !self.valid()
            || !time(now)
            || now.abs() > 1e12 - 10.0
            || !point(position)
            || !bodies_valid(bodies)
        {
            return Err("invalid resupply search");
        }
        if now < self.search_at {
            return Ok(Search::Wait);
        }
        self.search_at = now + 6.0;
        let mut result = Search::Depots;
        let mut nearest = 25.0;
        for b in bodies {
            if !b.dead || b.loot <= 0 {
                continue;
            }
            let distance = f64::from(flat(b.position - position).length());
            if distance < nearest {
                nearest = distance;
                result = Search::Body(b.id);
            }
        }
        Ok(result)
    }

    pub fn checkpoint(self) -> Vec<u8> {
        let mut out = Writer::new(b"FLSU\x01\0\0\0");
        out.f64(self.scavenge_at);
        out.f64(self.search_at);
        out.0
    }
    pub fn restore(bytes: &[u8]) -> Result<Self, &'static str> {
        let mut input = Reader::new(bytes, b"FLSU\x01\0\0\0")?;
        let state = Self {
            scavenge_at: input.f64()?,
            search_at: input.f64()?,
        };
        input.finish()?;
        if !state.valid() {
            return Err("invalid supply timers");
        }
        Ok(state)
    }
}

// The world supplies caches from its min(FOB distance, 70 m) spatial query.
pub fn choose_depot(
    position: Vector3,
    team: i32,
    fob: Option<Depot>,
    caches: &[Cache],
    rng: &mut SimulationRandom,
) -> Result<Option<Destination>, &'static str> {
    let valid = |d: Depot| id(d.id) && point(d.position);
    if !point(position)
        || !(-1..=1).contains(&team)
        || fob.is_some_and(|f| !valid(f))
        || caches.len() > 100_000
        || caches
            .iter()
            .any(|c| !valid(c.depot) || !(-1..=1).contains(&c.team))
    {
        return Err("invalid resupply depot input");
    }
    let mut distance = fob.map_or(f64::INFINITY, |f| {
        f64::from(flat(f.position - position).length())
    });
    let mut cache = None;
    for c in caches {
        if c.team != team || !c.built || c.gone || !c.ammo_cache {
            continue;
        }
        let d = f64::from(flat(c.depot.position - position).length());
        if d < distance {
            distance = d;
            cache = Some(c.depot);
        }
    }
    if let Some(c) = cache {
        return Ok(Some(Destination {
            depot: c.id,
            cache: true,
            position: c.position
                + normalized(flat(position - c.position)) * 2.2
                + Vector3::new(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0)),
        }));
    }
    Ok(fob.filter(|_| distance < 90.0).map(|f| Destination {
        depot: f.id,
        cache: false,
        position: f.position
            + Vector3::new(rng.randf_range(-4.0, 4.0), 0.0, rng.randf_range(-4.0, 4.0)),
    }))
}

pub fn refill_reserve(
    capacity: i32,
    magazine: i32,
    reserve: i32,
    dt: f64,
) -> Result<(i32, bool), &'static str> {
    if !rounds(capacity)
        || !rounds(magazine)
        || !rounds(reserve)
        || !dt.is_finite()
        || !(0.0..=3600.0).contains(&dt)
    {
        return Err("invalid ammunition refill");
    }
    if capacity >= 9000 || magazine + reserve >= capacity {
        return Ok((reserve, false));
    }
    Ok((
        (capacity - magazine).min(reserve + (60.0 * dt) as i32 + 1),
        true,
    ))
}

// Frag and smoke share one draw, followed by rockets, drones and mortar rounds.
// Reload and its speech must finish before these draws.
pub fn refill_special(
    stock: &mut [i32; 5],
    capacity: [i32; 5],
    dt: f64,
    rng: &mut SimulationRandom,
) -> Result<(), &'static str> {
    if !stock.iter().copied().all(rounds)
        || !capacity.into_iter().all(rounds)
        || !dt.is_finite()
        || !(0.0..=3600.0).contains(&dt)
    {
        return Err("invalid special ammunition refill");
    }
    if f64::from(rng.randf()) < dt * 0.1 {
        stock[0] = capacity[0].min(stock[0] + 1);
        stock[1] = capacity[1].min(stock[1] + 1);
    }
    for (index, rate) in [(2, 0.12), (3, 0.05), (4, 0.2)] {
        if f64::from(rng.randf()) < dt * rate {
            stock[index] = capacity[index].min(stock[index] + 1);
        }
    }
    Ok(())
}
