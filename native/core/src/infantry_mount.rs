//! Mounted infantry: climbing, gun laying and ordered anti-tank contact selection.
use crate::collision::CollisionWorld;
use crate::state_codec::{Reader, Writer};
use crate::vector::{normalized, turn_yaw, Vector3};
use crate::visibility::{Sight, Visibility};

#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct Mount {
    pub phase: u8,
    pub timer: f64,
    pub scan_timer: f64,
    pub target: u64,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum Station {
    Move,
    StartClimb,
    Climb { height: f32, finished: bool },
    Man,
    Ready,
}

#[derive(Clone, Copy, Debug)]
pub struct GunPose {
    pub position: Vector3,
    pub yaw: f64,
    pub dt: f64,
    pub mount: Option<(Vector3, f64)>,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Aim {
    pub yaw: f64,
    pub aligned: bool,
}

#[derive(Clone, Debug)]
pub struct Contact {
    pub id: u64,
    pub team: i32,
    pub revealed: bool,
    pub position: Vector3,
    pub points: Vec<Vector3>,
    pub excluded: Vec<i64>,
}

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct Scan {
    pub target: u64,
    pub reused: usize,
}

fn point(p: Vector3) -> bool {
    p.is_finite() && p.abs().max_element() <= 1_000_000.0
}
fn time(t: f64) -> bool {
    t.is_finite() && t.abs() <= 1e12
}
fn delta(dt: f64) -> bool {
    dt.is_finite() && (0.0..=10.0).contains(&dt)
}
fn flat(v: Vector3) -> Vector3 {
    Vector3::new(v.x, 0.0, v.z)
}

impl Mount {
    pub fn valid(self) -> bool {
        self.phase <= 2
            && time(self.timer)
            && time(self.scan_timer)
            && self.target <= i64::MAX as u64
    }

    pub fn station(&mut self, dt: f64, tower: bool, moving: bool) -> Result<Station, &'static str> {
        if !self.valid() || !delta(dt) || !time(self.timer - dt) {
            return Err("invalid mounted infantry state");
        }
        Ok(match self.phase {
            0 if moving => Station::Move,
            0 if tower => {
                self.phase = 1;
                self.timer = 1.6;
                Station::StartClimb
            }
            0 => {
                self.phase = 2;
                Station::Man
            }
            1 => {
                self.timer -= dt;
                let finished = self.timer <= 0.0;
                if finished {
                    self.phase = 2;
                }
                Station::Climb {
                    height: (4.25 * (1.0 - self.timer / 1.6).clamp(0.0, 1.0)) as f32,
                    finished,
                }
            }
            _ => Station::Ready,
        })
    }

    pub fn scan_due(&mut self, dt: f64) -> Result<bool, &'static str> {
        if !self.valid() || !delta(dt) || !time(self.scan_timer - dt) {
            return Err("invalid mounted scan clock");
        }
        self.scan_timer -= dt;
        if self.scan_timer > 0.0 {
            return Ok(false);
        }
        self.scan_timer = 0.7;
        self.target = 0;
        Ok(true)
    }

    pub fn checkpoint(self) -> Vec<u8> {
        let mut out = Writer::new(b"FLMT\x01\0\0\0");
        out.byte(self.phase);
        out.f64(self.timer);
        out.f64(self.scan_timer);
        out.u64(self.target);
        out.0
    }

    pub fn restore(bytes: &[u8]) -> Result<Self, &'static str> {
        let mut input = Reader::new(bytes, b"FLMT\x01\0\0\0")?;
        let state = Self {
            phase: input.byte()?,
            timer: input.f64()?,
            scan_timer: input.f64()?,
            target: input.u64()?,
        };
        input.finish()?;
        if !state.valid() {
            return Err("invalid mounted infantry checkpoint");
        }
        Ok(state)
    }
}

// Both guns finish their traverse before testing the firing tolerance.
pub fn aim(pose: GunPose, direction: Vector3, rate: f64) -> Result<Aim, &'static str> {
    if !point(pose.position)
        || !time(pose.yaw)
        || !delta(pose.dt)
        || !point(direction)
        || !rate.is_finite()
        || !(0.0..=1000.0).contains(&rate)
        || pose.mount.is_some_and(|(p, speed)| {
            !point(p) || !speed.is_finite() || !(0.0..=1000.0).contains(&speed)
        })
    {
        return Err("invalid mounted aim");
    }
    let yaw = turn_yaw(
        pose.yaw,
        direction,
        pose.position,
        pose.dt,
        rate,
        pose.mount,
    );
    let difference = libm::atan2(-f64::from(direction.x), -f64::from(direction.z)) - yaw;
    let wrapped = difference
        - std::f64::consts::TAU
            * ((difference + std::f64::consts::PI) / std::f64::consts::TAU).floor();
    Ok(Aim {
        yaw,
        aligned: wrapped.abs() <= 0.035,
    })
}

pub fn mortar_aim(pose: GunPose, target: Vector3) -> Result<Aim, &'static str> {
    if !point(target) {
        return Err("invalid mortar target");
    }
    aim(pose, flat(target - pose.position), 9.0)
}

pub fn antitank_aim(
    pose: GunPose,
    structure: Vector3,
    target: Vector3,
) -> Result<(Aim, Vector3), &'static str> {
    if !point(structure) || !point(target) {
        return Err("invalid anti-tank target");
    }
    let direction = normalized(flat(target - structure));
    Ok((aim(pose, direction, 9.0)?, direction))
}

pub fn scan(
    team: i32,
    position: Vector3,
    contacts: &[Contact],
    collision: &mut CollisionWorld,
    visibility: &mut Visibility,
) -> Result<Scan, &'static str> {
    if !(-1..=1).contains(&team)
        || !point(position)
        || contacts.len() > 100_000
        || contacts.iter().any(|c| {
            c.id == 0
                || c.id > i64::MAX as u64
                || !(-1..=1).contains(&c.team)
                || !point(c.position)
                || c.points.len() > 256
                || c.points.iter().any(|p| !point(*p))
                || c.excluded.len() > 4096
                || c.excluded.iter().any(|id| *id < 0)
        })
    {
        return Err("invalid mounted anti-tank scan");
    }
    let eye = position + Vector3::new(0.0, 1.3, 0.0);
    let mut out = Scan::default();
    let mut best = 130.0;
    for c in contacts {
        if c.team == team || c.team < 0 || !c.revealed {
            continue;
        }
        let distance = f64::from(flat(c.position - position).length());
        if distance > best {
            continue;
        }
        match visibility.can_see(collision, eye, c.id, &c.points, &c.excluded, true) {
            Some(Sight::Visible) => {
                best = distance;
                out.target = c.id;
            }
            Some(Sight::ReusedObstruction) => out.reused += 1,
            _ => (),
        }
    }
    Ok(out)
}
