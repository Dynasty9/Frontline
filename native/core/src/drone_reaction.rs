//! Infantry hears nearby aircraft before deciding whether to dive from an attack.
use crate::random::SimulationRandom;
use crate::state_codec::{Reader, Writer};
use crate::vector::Vector3;

#[derive(Clone, Copy, Debug)]
pub struct Drone {
    pub id: u64,
    pub position: Vector3,
    pub target: Vector3,
    pub team: i32,
    pub dead: bool,
    pub diving: bool,
}

#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct DroneMemory {
    pub heard: Vec<u64>,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Warning {
    pub drone: u64,
    pub variant: u8,
}

#[derive(Clone, Debug, Default, PartialEq)]
pub struct Reaction {
    pub warnings: Vec<Warning>,
    pub dive_from: Option<Vector3>,
}

fn id(id: u64) -> bool {
    id > 0 && id <= i64::MAX as u64
}
fn point(p: Vector3) -> bool {
    p.is_finite() && p.abs().max_element() <= 1_000_000.0
}

impl DroneMemory {
    pub fn valid(&self) -> bool {
        self.heard.len() <= 17
            && self
                .heard
                .iter()
                .enumerate()
                .all(|(i, v)| id(*v) && !self.heard[..i].contains(v))
    }

    pub fn react(
        &mut self,
        position: Vector3,
        team: i32,
        drones: &[Drone],
        rng: &mut SimulationRandom,
    ) -> Result<Reaction, &'static str> {
        if !self.valid()
            || !point(position)
            || !(-1..=1).contains(&team)
            || drones.len() > 100_000
            || drones.iter().any(|d| {
                !id(d.id) || !point(d.position) || !point(d.target) || !(-1..=1).contains(&d.team)
            })
        {
            return Err("invalid drone reaction input");
        }
        let mut result = Reaction::default();
        for d in drones {
            if d.team == team || d.dead {
                continue;
            }
            let distance = f64::from(position.distance(d.position));
            if distance > 45.0 {
                continue;
            }
            if !self.heard.contains(&d.id) {
                if self.heard.len() > 16 {
                    self.heard.clear();
                }
                self.heard.push(d.id);
                result.warnings.push(Warning {
                    drone: d.id,
                    variant: (rng.randi() % 3) as u8,
                });
            }
            let target = d.target - position;
            if d.diving
                && distance < 9.0
                && f64::from(Vector3::new(target.x, 0.0, target.z).length()) < 5.5
                && f64::from(rng.randf()) < 0.8
            {
                result.dive_from = Some(d.position);
                break;
            }
        }
        Ok(result)
    }

    pub fn checkpoint(&self) -> Vec<u8> {
        let mut out = Writer::new(b"FLDM\x01\0\0\0");
        out.u32(self.heard.len() as u32);
        for id in &self.heard {
            out.u64(*id);
        }
        out.0
    }

    pub fn restore(bytes: &[u8]) -> Result<Self, &'static str> {
        let mut input = Reader::new(bytes, b"FLDM\x01\0\0\0")?;
        let count = input.u32()? as usize;
        if count > 17 {
            return Err("too many remembered drones");
        }
        let mut heard = Vec::with_capacity(count);
        for _ in 0..count {
            heard.push(input.u64()?);
        }
        input.finish()?;
        let state = Self { heard };
        if !state.valid() {
            return Err("invalid drone memory");
        }
        Ok(state)
    }
}
