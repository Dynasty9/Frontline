//! Automatic grenade targeting keeps the first equally valuable squad contact.
use crate::infantry_pose::Posture;
use crate::random::SimulationRandom;
use crate::state_codec::{Reader, Writer};
use crate::vector::Vector3;

const SCHEMA: &[u8; 8] = b"FLGA\x01\0\0\0";

#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct GrenadeAttack {
    pub frags: i32,
    pub cooldown: f64,
}

#[derive(Clone, Copy, Debug)]
pub struct Input {
    pub position: Vector3,
    pub time: f64,
    pub suppression: f64,
    pub squad: bool,
    pub ambush: bool,
    pub moving: bool,
}

#[derive(Clone, Copy, Debug)]
pub struct Contact {
    pub id: u64,
    pub position: Vector3,
    pub alive: bool,
    pub age: f64,
    pub visible: bool,
    pub posture: Posture,
    pub hard_cover: bool,
    pub nearby_allies: u32,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Throw {
    pub target: u64,
    pub position: Vector3,
    pub distance: f64,
}

fn scalar(v: f64) -> bool {
    v.is_finite() && v.abs() <= 1e12
}
fn point(p: Vector3) -> bool {
    p.is_finite() && p.abs().max_element() <= 1_000_000.0
}
fn flat(p: Vector3) -> Vector3 {
    Vector3::new(p.x, 0.0, p.z)
}

impl GrenadeAttack {
    pub fn valid(&self) -> bool {
        (-1_000_000..=1_000_000).contains(&self.frags) && scalar(self.cooldown)
    }

    pub fn advance(
        &mut self,
        i: Input,
        contacts: &[Contact],
        rng: &mut SimulationRandom,
    ) -> Result<Option<Throw>, &'static str> {
        if !self.valid()
            || !point(i.position)
            || !scalar(i.time)
            || !scalar(i.suppression)
            || contacts.len() > 100_000
            || contacts.iter().any(|c| {
                c.id == 0
                    || c.id > i64::MAX as u64
                    || !point(c.position)
                    || !scalar(c.age)
                    || c.nearby_allies > 100_000
            })
        {
            return Err("invalid grenade attack");
        }
        if self.frags <= 0
            || i.time < self.cooldown
            || i.suppression > 70.0
            || !i.squad
            || i.ambush
            || i.moving
        {
            return Ok(None);
        }
        self.cooldown = i.time + 2.5;
        let mut best = None;
        let mut best_score = 0;
        for c in contacts {
            if !c.alive || c.age > 6.0 {
                continue;
            }
            let d = f64::from(flat(c.position - i.position).length());
            if !(9.0..=27.0).contains(&d)
                || (c.visible && !matches!(c.posture, Posture::Crouch | Posture::Prone))
            {
                continue;
            }
            let score = 1 + u32::from(c.hard_cover) + c.nearby_allies;
            if score > best_score {
                best = Some(c);
                best_score = score;
            }
        }
        let Some(best) = best else {
            return Ok(None);
        };
        if f64::from(rng.randf()) > 0.3 + 0.12 * f64::from(best_score) {
            return Ok(None);
        }
        let distance = f64::from(flat(best.position - i.position).length());
        let scatter = Vector3::new(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0));
        let position = best.position + scatter * distance as f32 * 0.07;
        self.frags -= 1;
        self.cooldown = i.time + f64::from(rng.randf_range(12.0, 20.0));
        Ok(Some(Throw {
            target: best.id,
            position,
            distance,
        }))
    }

    pub fn checkpoint(&self) -> Vec<u8> {
        let mut w = Writer::new(SCHEMA);
        w.u32(self.frags as u32);
        w.f64(self.cooldown);
        w.0
    }

    pub fn restore(bytes: &[u8]) -> Result<Self, &'static str> {
        let mut r = Reader::new(bytes, SCHEMA)?;
        let state = Self {
            frags: r.u32()? as i32,
            cooldown: r.f64()?,
        };
        r.finish()?;
        if !state.valid() {
            return Err("invalid grenade attack checkpoint");
        }
        Ok(state)
    }
}
