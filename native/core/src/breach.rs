//! House-entry task decisions. Movement and weapon effects run before each phase's decision.
use crate::grenade_reaction::cook_time;
use crate::random::SimulationRandom;
use crate::state_codec::{Reader, Writer};
use crate::vector::Vector3;

const SCHEMA: &[u8; 8] = b"FLBC\x01\0\0\0";

#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct Breach {
    pub phase: u8,
    pub started: f64,
    pub wait_until: f64,
    pub cook_started: f64,
    pub clear: bool,
    pub no_frag: bool,
}

#[derive(Clone, Copy, Debug)]
pub struct Input {
    pub time: f64,
    pub moving: bool,
    pub distance: f64,
    pub enemy_inside: bool,
    pub door_shut: bool,
    pub frags: i32,
    pub team: i32,
    pub enemy_hard_cover: bool,
    pub exploded: bool,
    pub reordered: bool,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum Decision {
    Wait,
    Cancel,
    RetryStack,
    Stacked,
    ApproachDoor { cook: f64, distance: f32 },
    KickDoor,
    EnterWait,
    Throw { fuse: f64 },
    FollowSquad,
    Enter,
}

impl Breach {
    pub fn valid(&self) -> bool {
        self.phase <= 4
            && [self.started, self.wait_until, self.cook_started]
                .into_iter()
                .all(scalar)
    }

    pub fn expired(&self, time: f64, building_valid: bool) -> Result<bool, &'static str> {
        if !self.valid() || !scalar(time) {
            return Err("invalid breach deadline");
        }
        Ok(!building_valid || time - self.started > 45.0)
    }

    pub fn advance(
        &mut self,
        i: Input,
        rng: &mut SimulationRandom,
    ) -> Result<Decision, &'static str> {
        if !self.valid() || !scalar(i.time) || !scalar(i.distance) || i.distance < 0.0 {
            return Err("invalid breach input");
        }
        Ok(match self.phase {
            0 => {
                if !i.enemy_inside && !self.clear {
                    Decision::Cancel
                } else if !i.moving && i.distance >= 0.9 {
                    if i.time - self.started > 20.0 {
                        Decision::Cancel
                    } else {
                        Decision::RetryStack
                    }
                } else if i.distance < 0.9 {
                    self.phase = 1;
                    self.wait_until = i.time + f64::from(rng.randf_range(0.5, 0.9));
                    Decision::Stacked
                } else {
                    Decision::Wait
                }
            }
            1 => {
                if i.time < self.wait_until {
                    Decision::Wait
                } else {
                    self.phase = 2;
                    self.no_frag |= self.clear && (!i.enemy_inside || i.frags <= 0);
                    let cook = if i.door_shut || self.no_frag {
                        0.0
                    } else {
                        cook_time(i.team, 3.0, i.enemy_hard_cover, rng)?
                    };
                    if cook > 0.0 {
                        self.cook_started = i.time;
                    }
                    Decision::ApproachDoor {
                        cook,
                        distance: if i.door_shut { 0.8 } else { 1.25 },
                    }
                }
            }
            2 => {
                if i.moving && i.distance >= 0.5 {
                    Decision::Wait
                } else if i.door_shut {
                    Decision::KickDoor
                } else if self.no_frag {
                    self.phase = 4;
                    self.wait_until = i.time + f64::from(rng.randf_range(0.2, 0.5));
                    Decision::EnterWait
                } else {
                    let fuse = if self.cook_started >= 0.0 {
                        (3.4 - (i.time - self.cook_started)).max(1.3)
                    } else {
                        3.4
                    };
                    self.phase = 3;
                    self.wait_until = i.time + 4.5;
                    Decision::Throw { fuse }
                }
            }
            3 => {
                if i.exploded || i.time > self.wait_until {
                    self.phase = 4;
                    self.wait_until = i.time + f64::from(rng.randf_range(0.15, 0.4));
                }
                Decision::Wait
            }
            4 => {
                if i.time < self.wait_until {
                    Decision::Wait
                } else if i.reordered {
                    Decision::FollowSquad
                } else {
                    Decision::Enter
                }
            }
            _ => unreachable!(),
        })
    }

    pub fn checkpoint(&self) -> Vec<u8> {
        let mut w = Writer::new(SCHEMA);
        w.byte(self.phase);
        w.f64(self.started);
        w.f64(self.wait_until);
        w.f64(self.cook_started);
        w.byte(self.clear.into());
        w.byte(self.no_frag.into());
        w.0
    }

    pub fn restore(bytes: &[u8]) -> Result<Self, &'static str> {
        let mut r = Reader::new(bytes, SCHEMA)?;
        let result = Self {
            phase: r.byte()?,
            started: r.f64()?,
            wait_until: r.f64()?,
            cook_started: r.f64()?,
            clear: r.boolean()?,
            no_frag: r.boolean()?,
        };
        r.finish()?;
        if !result.valid() {
            return Err("invalid breach state");
        }
        Ok(result)
    }
}

fn scalar(v: f64) -> bool {
    v.is_finite() && v.abs() <= 1e12
}
fn point(p: Vector3) -> bool {
    p.is_finite() && p.abs().max_element() <= 1_000_000.0
}

pub fn room_target(
    center: Vector3,
    normal: Vector3,
    target: Vector3,
) -> Result<Vector3, &'static str> {
    if !point(center) || !point(normal) || !point(target) {
        return Err("invalid room target");
    }
    let along = Vector3::new(normal.z, 0.0, -normal.x);
    let delta = target - center;
    let depth = f64::from(delta.dot(-normal)).clamp(1.2, 3.6) as f32;
    let lateral = f64::from(delta.dot(along)).clamp(-1.4, 1.4) as f32;
    Ok(center - normal * depth + along * lateral + Vector3::Y * 0.06)
}

/// The owning navigation grid resolves this point to the nearest walkable cell.
pub fn stack_spot(
    position: Vector3,
    center: Vector3,
    normal: Vector3,
    door: bool,
) -> Result<Vector3, &'static str> {
    if !point(position) || !point(center) || !point(normal) {
        return Err("invalid stack position");
    }
    let along = Vector3::new(normal.z, 0.0, -normal.x);
    let side = if (position - center).dot(along) >= 0.0 {
        1.0
    } else {
        -1.0
    };
    let half = if door { 0.95_f64 } else { 0.65 };
    Ok(center + normal * 0.5 + along * side * (half + 0.6) as f32)
}

/// 0 keeps the current path, 1 retreats to the stack and 2 stops there.
pub fn retreat(distance: f64, moving: bool, grenade_present: bool) -> Result<u8, &'static str> {
    if !scalar(distance) || distance < 0.0 {
        return Err("invalid breach retreat");
    }
    Ok(if grenade_present && distance > 0.9 && !moving {
        1
    } else if distance <= 0.9 && moving {
        2
    } else {
        0
    })
}
