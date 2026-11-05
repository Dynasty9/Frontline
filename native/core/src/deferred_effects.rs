//! Delayed damage follows simulation time and survives checkpoints, independently of rendering.
use crate::projectile_actor::Explosion;
use crate::random::SimulationRandom;
use crate::state_codec::{Reader, Writer};
use crate::vector::Vector3;
use std::collections::{BTreeMap, HashSet};

const MAX_EVENTS: usize = 100_000;
const MAX_TIME: f64 = 1e12;
#[derive(Clone, Debug, Default, PartialEq)]
pub struct DeferredEffects {
    time: f64,
    next_sequence: u64,
    // Nonnegative finite IEEE floats sort numerically by their bits; sequence breaks equal-time ties.
    pending: BTreeMap<(u64, u64), Explosion>,
    rubble: Vec<Rubble>,
}
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Rubble {
    pub position: Vector3,
    pub yaw: f64,
    pub size: Vector3,
}
impl Rubble {
    fn valid(self) -> bool {
        point(self.position)
            && point(self.size)
            && self.size.min_element() >= 0.0
            && self.yaw.is_finite()
            && self.yaw.abs() <= 1e12
    }
}
fn point(p: Vector3) -> bool {
    p.is_finite() && p.abs().max_element() <= 1_000_000.0
}
fn time(t: f64) -> bool {
    t.is_finite() && (0.0..=MAX_TIME).contains(&t) && !t.is_sign_negative()
}
fn valid(e: Explosion) -> bool {
    point(e.position)
        // Only cache cook-offs are delayed damage; they have no attacker or directional warhead.
        && e.direction.is_none()
        && e.source == 0
        && e.team == -1
        && e.called_by == 0
        && !e.top
        && e.track == 0.3
        && e.structure_multiplier == 1.0
        && [
            e.damage,
            e.radius,
            e.fling,
            e.antitank,
            e.track,
            e.size,
            e.structure_multiplier,
        ]
        .into_iter()
        .all(|v| v.is_finite() && (0.0..=1_000_000.0).contains(&v))
}
impl DeferredEffects {
    pub fn time(&self) -> f64 {
        self.time
    }
    pub fn len(&self) -> usize {
        self.pending.len() + self.rubble.len()
    }
    pub fn is_empty(&self) -> bool {
        self.pending.is_empty() && self.rubble.is_empty()
    }
    pub fn pending(&self) -> impl Iterator<Item = (f64, u64, Explosion)> + '_ {
        self.pending
            .iter()
            .map(|(&(deadline, sequence), &e)| (f64::from_bits(deadline), sequence, e))
    }
    pub fn defer_rubble(&mut self, rubble: Rubble) -> Result<(), &'static str> {
        if !rubble.valid() || self.rubble.len() >= MAX_EVENTS {
            return Err("invalid deferred rubble");
        }
        self.rubble.push(rubble);
        Ok(())
    }
    /// Drain after due explosions so the ruins they create register before the next simulation step.
    pub fn take_rubble(&mut self) -> Vec<Rubble> {
        std::mem::take(&mut self.rubble)
    }
    pub fn cook_off(
        &mut self,
        now: f64,
        position: Vector3,
        supply: f64,
        rng: &mut SimulationRandom,
    ) -> Result<usize, &'static str> {
        if !time(now)
            || now < self.time
            || !point(position)
            || !supply.is_finite()
            || supply.abs() > 1e12
        {
            return Err("invalid cache cook-off");
        }
        let left = (supply / 160.0).clamp(0.2, 1.0);
        let count = (4.0 + 5.0 * left) as usize;
        if self.pending.len() + count > MAX_EVENTS
            || self.next_sequence.checked_add(count as u64).is_none()
        {
            return Err("explosion queue exhausted");
        }
        let mut draws = *rng;
        let origin = position + Vector3::new(0.0, 0.6, 0.0);
        let mut events = Vec::with_capacity(count);
        for i in 0..count {
            let big = i == 0;
            let position = if big {
                origin
            } else {
                origin
                    + Vector3::new(
                        draws.randf_range(-1.5, 1.5),
                        0.0,
                        draws.randf_range(-1.5, 1.5),
                    )
            };
            let delay = if big {
                0.05
            } else {
                0.5 + i as f64 * f64::from(draws.randf_range(0.35, 0.9))
            };
            let deadline = now + delay;
            let e = Explosion {
                position,
                damage: if big { 90.0 * left + 40.0 } else { 35.0 },
                radius: if big { 4.0 + 2.0 * left } else { 2.5 },
                fling: if big { 8.0 } else { 4.0 },
                antitank: if big { 60.0 } else { 0.0 },
                size: if big { 1.2 + left } else { 0.5 },
                source: 0,
                team: -1,
                called_by: 0,
                direction: None,
                top: false,
                track: 0.3,
                structure_multiplier: 1.0,
            };
            if !time(deadline) || deadline <= now || !valid(e) {
                return Err("cache explosion exceeds limits");
            }
            events.push((deadline, e));
        }
        for (deadline, e) in events {
            self.pending
                .insert((deadline.to_bits(), self.next_sequence), e);
            self.next_sequence += 1;
        }
        *rng = draws;
        Ok(count)
    }
    /// Called once at the end of the simulation step. New chain reactions wait for a later step.
    pub fn advance_to(&mut self, now: f64) -> Result<Vec<Explosion>, &'static str> {
        if !time(now) || now < self.time {
            return Err("invalid explosion clock");
        }
        self.time = now;
        let mut due = Vec::new();
        while self
            .pending
            .first_key_value()
            .is_some_and(|(&(deadline, _), _)| f64::from_bits(deadline) <= now)
        {
            due.push(self.pending.pop_first().unwrap().1);
        }
        Ok(due)
    }
    pub fn checkpoint(&self) -> Vec<u8> {
        let mut w = Writer::new(b"FLDE\x01\0\0\0");
        w.f64(self.time);
        w.u64(self.next_sequence);
        w.u32(self.pending.len() as u32);
        for (deadline, sequence, e) in self.pending() {
            w.f64(deadline);
            w.u64(sequence);
            w.point(e.position);
            for v in [
                e.damage,
                e.radius,
                e.fling,
                e.antitank,
                e.track,
                e.size,
                e.structure_multiplier,
            ] {
                w.f64(v);
            }
            w.byte(u8::from(e.direction.is_some()));
            if let Some(p) = e.direction {
                w.point(p);
            }
            w.byte(u8::from(e.top));
            w.u32(e.source);
            w.byte(e.team as u8);
            w.u32(e.called_by as u32);
        }
        w.u32(self.rubble.len() as u32);
        for r in &self.rubble {
            w.point(r.position);
            w.f64(r.yaw);
            w.point(r.size);
        }
        w.0
    }
    pub fn restore(bytes: &[u8]) -> Result<Self, &'static str> {
        if bytes.len() > 16 * 1024 * 1024 {
            return Err("explosion checkpoint exceeds limit");
        }
        let mut r = Reader::new(bytes, b"FLDE\x01\0\0\0")?;
        let now = r.f64()?;
        let next_sequence = r.u64()?;
        let count = r.u32()? as usize;
        if !time(now) || count > MAX_EVENTS {
            return Err("invalid explosion checkpoint");
        }
        let mut pending = BTreeMap::new();
        let mut sequences = HashSet::new();
        let mut previous = None;
        for _ in 0..count {
            let deadline = r.f64()?;
            let sequence = r.u64()?;
            let position = r.point()?;
            let damage = r.f64()?;
            let radius = r.f64()?;
            let fling = r.f64()?;
            let antitank = r.f64()?;
            let track = r.f64()?;
            let size = r.f64()?;
            let structure_multiplier = r.f64()?;
            let direction = if r.boolean()? { Some(r.point()?) } else { None };
            let top = r.boolean()?;
            let source = r.u32()?;
            let team = r.byte()? as i8;
            let called_by = r.u32()? as i32;
            let e = Explosion {
                position,
                damage,
                radius,
                fling,
                antitank,
                direction,
                top,
                track,
                source,
                team,
                called_by,
                size,
                structure_multiplier,
            };
            let key = (deadline.to_bits(), sequence);
            if !time(deadline)
                || deadline <= now
                || sequence >= next_sequence
                || !sequences.insert(sequence)
                || previous.is_some_and(|p| p >= key)
                || !valid(e)
            {
                return Err("invalid pending explosion");
            }
            previous = Some(key);
            pending.insert(key, e);
        }
        let count = r.u32()? as usize;
        if count > MAX_EVENTS {
            return Err("deferred rubble exceeds limit");
        }
        let mut rubble = Vec::new();
        for _ in 0..count {
            let spawn = Rubble {
                position: r.point()?,
                yaw: r.f64()?,
                size: r.point()?,
            };
            if !spawn.valid() {
                return Err("invalid deferred rubble");
            }
            rubble.push(spawn);
        }
        r.finish()?;
        Ok(Self {
            time: now,
            next_sequence,
            pending,
            rubble,
        })
    }
}
