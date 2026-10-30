//! Grenade reflex priority and random draws, using battlefield geometry rather than models.
use crate::collision::CollisionWorld;
use crate::infantry_pose::Posture;
use crate::infantry_vitals::Life;
use crate::random::SimulationRandom;
use crate::state_codec::{Reader, Writer};
use crate::vector::{normalized, Vector3};

// Mortar warnings share this memory and only a new nearby grenade evicts it.
pub const MAX_REMEMBERED_ROUNDS: usize = 100_000;

#[derive(Clone, Copy, Debug)]
pub struct Grenade {
    pub id: u64,
    pub position: Vector3,
    pub fuse: f64,
    pub held: bool,
    pub gone: bool,
    pub flying: bool,
    pub free: bool,
    pub smothered: bool,
    pub thrown_back: u32,
}

#[derive(Clone, Copy, Debug)]
pub struct Soldier {
    pub id: u64,
    pub position: Vector3,
    pub center: Vector3,
    pub yaw: f64,
    pub team: i32,
    pub suppression: f64,
    pub posture: Posture,
    pub squad: bool,
    pub mounted: bool,
    pub riding: bool,
    pub armed: bool,
}

#[derive(Clone, Copy, Debug)]
pub struct Mate {
    pub id: u64,
    pub position: Vector3,
    pub center: Vector3,
    pub team: i32,
    pub life: Life,
    pub helpless: bool,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Reaction {
    Smother,
    ThrowBack,
    Kick,
    Shelter(i64), // The owning world checks whether this hit body is a structure.
    Dive,
}

#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct GrenadeMemory {
    pub seen: Vec<u64>,
}

fn point(p: Vector3) -> bool {
    p.is_finite() && p.abs().max_element() <= 1_000_000.0
}
fn scalar(v: f64) -> bool {
    v.is_finite() && v.abs() <= 1e12
}
fn id(id: u64) -> bool {
    id > 0 && id <= i64::MAX as u64
}
fn flat(p: Vector3) -> Vector3 {
    Vector3::new(p.x, 0.0, p.z)
}
fn direction(yaw: f64) -> Vector3 {
    Vector3::new(-libm::sin(yaw) as f32, 0.0, -libm::cos(yaw) as f32)
}

impl Grenade {
    pub fn valid(self) -> bool {
        id(self.id) && point(self.position) && scalar(self.fuse) && self.thrown_back <= 1_000_000
    }
}
impl Soldier {
    pub fn valid(self) -> bool {
        id(self.id)
            && point(self.position)
            && point(self.center)
            && scalar(self.yaw)
            && scalar(self.suppression)
            && (-1..=1).contains(&self.team)
    }
}
impl Mate {
    fn valid(self) -> bool {
        id(self.id) && point(self.position) && point(self.center) && (-1..=1).contains(&self.team)
    }
}

impl GrenadeMemory {
    pub fn valid(&self) -> bool {
        if self.seen.len() > MAX_REMEMBERED_ROUNDS || !self.seen.iter().copied().all(id) {
            return false;
        }
        if self.seen.len() <= 25 {
            self.seen
                .iter()
                .enumerate()
                .all(|(i, id)| !self.seen[..i].contains(id))
        } else {
            self.seen_index().is_some()
        }
    }

    fn seen_index(&self) -> Option<std::collections::HashSet<u64>> {
        if self.seen.len() > MAX_REMEMBERED_ROUNDS {
            return None;
        }
        let mut unique = std::collections::HashSet::with_capacity(self.seen.len());
        self.seen
            .iter()
            .all(|v| id(*v) && unique.insert(*v))
            .then_some(unique)
    }

    pub fn notice(
        &mut self,
        position: Vector3,
        grenades: &[Grenade],
        skip_gone: bool,
    ) -> Result<Option<u64>, &'static str> {
        if !point(position) || grenades.len() > 100_000 || grenades.iter().any(|g| !g.valid()) {
            return Err("invalid grenade notice input");
        }
        // Long mortar histories need one lookup set, not a history scan for every grenade.
        let index = if self.seen.len() > 25 {
            Some(self.seen_index().ok_or("invalid grenade notice memory")?)
        } else {
            if !self.valid() {
                return Err("invalid grenade notice memory");
            }
            None
        };
        for g in grenades {
            if g.held || (skip_gone && g.gone) {
                continue;
            }
            let distance = f64::from(flat(g.position - position).length());
            if distance > 7.5
                || index
                    .as_ref()
                    .map_or_else(|| self.seen.contains(&g.id), |seen| seen.contains(&g.id))
                || (g.flying && g.fuse > 2.2 && distance > 4.0)
            {
                continue;
            }
            if self.seen.len() > 24 {
                self.seen.clear();
            }
            self.seen.push(g.id);
            return Ok(Some(g.id));
        }
        Ok(None)
    }

    pub fn checkpoint(&self) -> Vec<u8> {
        let mut out = Writer::new(b"FLGR\x01\0\0\0");
        out.u32(self.seen.len() as u32);
        for id in &self.seen {
            out.u64(*id);
        }
        out.0
    }

    pub fn restore(bytes: &[u8]) -> Result<Self, &'static str> {
        let mut input = Reader::new(bytes, b"FLGR\x01\0\0\0")?;
        let count = input.u32()? as usize;
        if count > MAX_REMEMBERED_ROUNDS {
            return Err("too many remembered grenades");
        }
        let mut seen = Vec::with_capacity(count);
        for _ in 0..count {
            seen.push(input.u64()?);
        }
        input.finish()?;
        let state = Self { seen };
        if !state.valid() {
            return Err("invalid grenade memory");
        }
        Ok(state)
    }
}

pub fn react(
    s: Soldier,
    g: Grenade,
    mates: &[Mate],
    collision: &mut CollisionWorld,
    rng: &mut SimulationRandom,
) -> Result<Reaction, &'static str> {
    if !s.valid() || !g.valid() || mates.len() > 100_000 || mates.iter().any(|m| !m.valid()) {
        return Err("invalid grenade reaction input");
    }
    let distance = f64::from(flat(g.position - s.position).length());
    if !g.gone
        && !g.smothered
        && g.free
        && s.squad
        && !s.mounted
        && !s.riding
        && distance <= 3.2
        && g.fuse >= 0.5
        && g.fuse <= 2.6
        && f64::from(g.position.y) <= 0.7
    {
        let mut risk = 0;
        let mut helpless = 0;
        let from = g.position + Vector3::new(0.0, 0.35, 0.0);
        for m in mates {
            if m.id == s.id || m.team != s.team || !matches!(m.life, Life::Alive | Life::Downed) {
                continue;
            }
            if collision.ray(from, m.center, &[]).is_some() {
                continue;
            }
            risk += 1;
            if m.life == Life::Downed || m.helpless {
                helpless += 1;
            }
        }
        if helpless > 0 || risk >= 3 {
            let mut probability = 0.06 * f64::from(risk) + 0.22 * f64::from(helpless);
            if g.fuse > 1.8 {
                probability *= 0.5;
            }
            if f64::from(rng.randf()) < probability.min(0.55) {
                return Ok(Reaction::Smother);
            }
        }
    }
    if !g.gone
        && g.free
        && distance < 3.8
        && g.fuse > 1.8
        && g.thrown_back < 1
        && s.suppression < 75.0
        && s.armed
        && rng.randf() < 0.25
    {
        return Ok(Reaction::ThrowBack);
    }
    if !g.gone
        && g.free
        && f64::from(g.position.y) < 0.45
        && distance <= 2.0
        && g.fuse > 1.0
        && s.suppression < 80.0
        && s.posture != Posture::Prone
        && rng.randf() < 0.4
    {
        return Ok(Reaction::Kick);
    }
    if !g.gone && distance >= 1.2 {
        if let Some(hit) = collision.ray(g.position + Vector3::new(0.0, 0.35, 0.0), s.center, &[]) {
            return Ok(Reaction::Shelter(hit.body));
        }
    }
    Ok(Reaction::Dive)
}

pub fn kick_velocity(
    s: Soldier,
    g: Grenade,
    mates: &[Mate],
    thrower: Option<Vector3>,
) -> Result<Vector3, &'static str> {
    if !s.valid()
        || !g.valid()
        || mates.len() > 100_000
        || mates.iter().any(|m| !m.valid())
        || thrower.is_some_and(|p| !point(p))
    {
        return Err("invalid grenade kick input");
    }
    let mut dir = normalized(flat(g.position - s.position));
    if f64::from(dir.length()) < 0.5 {
        dir = direction(s.yaw);
    }
    let mut group = Vector3::ZERO;
    for m in mates {
        if m.id != s.id && m.team == s.team && m.life == Life::Alive {
            group += flat(m.position - g.position);
        }
    }
    if f64::from(group.length()) > 0.1 {
        dir = normalized(dir - normalized(group) * 0.6);
    }
    if let Some(p) = thrower {
        dir = normalized(dir + normalized(flat(p - g.position)) * 0.7);
    }
    Ok(dir * 9.0 + Vector3::new(0.0, 3.0, 0.0))
}

pub fn cook_time(
    team: i32,
    distance: f64,
    hard_cover: bool,
    rng: &mut SimulationRandom,
) -> Result<f64, &'static str> {
    if !(-1..=1).contains(&team) || !scalar(distance) || distance < 0.0 {
        return Err("invalid grenade cook input");
    }
    if distance > 20.0 {
        return Ok(0.0);
    }
    let probability = if team == 1 { 0.3 } else { 0.45 } + if hard_cover { 0.25 } else { 0.0 };
    if f64::from(rng.randf()) > probability {
        return Ok(0.0);
    }
    Ok(f64::from(rng.randf_range(0.8, 1.4)))
}
