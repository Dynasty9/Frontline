//! Construction, casualty carrying and prisoner escort decisions between actor effects.
use crate::path_planner::PathPlanner;
use crate::random::SimulationRandom;
use crate::state_codec::{Reader, Writer};
use crate::vector::{normalized, turn_yaw, Vector3};

const SCHEMA: &[u8; 8] = b"FLDU\x01\0\0\0";

#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct Duty {
    pub phase: u8,
    pub timer: f64,
    pub build_sound: f64,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Build {
    Done,
    Suppressed,
    Move,
    Approach,
    Fight,
    Work,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Carry {
    Cancel,
    Move,
    Approach,
    Ready,
    Wait,
    Lift,
    Lead,
    TakeOver,
    Follow,
}

#[derive(Clone, Copy, Debug)]
pub struct Stretcher {
    pub valid: bool,
    pub position: Vector3,
    pub casualty: Vector3,
    pub moving: bool,
    pub partner_phase: Option<u8>,
    pub front: bool,
    pub dt: f64,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Captor {
    Cancel,
    Approach { repath: bool },
    Claim,
    Guard,
    Wait,
}

#[derive(Clone, Copy, Debug)]
pub struct Guard {
    pub position: Vector3,
    pub yaw: f64,
    pub prisoner: Vector3,
    pub dt: f64,
    pub mount: Option<(Vector3, f64)>,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct GuardPose {
    pub position: Vector3,
    pub yaw: f64,
    pub walking: bool,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct CarryPose {
    pub yaw: f64,
    pub casualty: Vector3,
    pub casualty_yaw: f64,
}

fn point(value: Vector3) -> bool {
    value.is_finite() && value.abs().max_element() <= 1_000_000.0
}
fn time(value: f64) -> bool {
    value.is_finite() && value.abs() <= 1e12
}
fn dt(value: f64) -> bool {
    value.is_finite() && (0.0..=10.0).contains(&value)
}
fn flat(value: Vector3) -> Vector3 {
    Vector3::new(value.x, 0.0, value.z)
}
fn direction(yaw: f64) -> Vector3 {
    Vector3::new(-libm::sin(yaw) as f32, 0.0, -libm::cos(yaw) as f32)
}
fn mount(value: Option<(Vector3, f64)>) -> bool {
    value.is_none_or(|(position, rate)| {
        point(position) && rate.is_finite() && (0.0..=1000.0).contains(&rate)
    })
}

pub fn build(
    done: bool,
    suppression: f64,
    moving: bool,
    position: Vector3,
    destination: Vector3,
    target: Option<Vector3>,
) -> Result<Build, &'static str> {
    if !suppression.is_finite()
        || !(0.0..=100.0).contains(&suppression)
        || !point(position)
        || !point(destination)
        || target.is_some_and(|p| !point(p))
    {
        return Err("invalid construction input");
    }
    Ok(if done {
        Build::Done
    } else if suppression > 55.0 {
        Build::Suppressed
    } else if moving {
        Build::Move
    } else if f64::from(flat(position - destination).length()) > 1.6 {
        Build::Approach
    } else if target.is_some_and(|p| flat(p - position).length() < 18.0) {
        Build::Fight
    } else {
        Build::Work
    })
}

pub fn build_pose(
    position: Vector3,
    yaw: f64,
    work: Vector3,
    delta: f64,
    mounting: Option<(Vector3, f64)>,
) -> Result<f64, &'static str> {
    if !point(position) || !point(work) || !time(yaw) || !dt(delta) || !mount(mounting) {
        return Err("invalid construction pose");
    }
    Ok(turn_yaw(
        yaw,
        flat(work - position),
        position,
        delta,
        8.0,
        mounting,
    ))
}

impl Duty {
    pub fn valid(self) -> bool {
        self.phase <= 3 && time(self.timer) && time(self.build_sound)
    }

    // Construction can finish a building and consume RNG before its sound timer advances.
    pub fn finish_build(
        &mut self,
        delta: f64,
        rng: &mut SimulationRandom,
    ) -> Result<bool, &'static str> {
        if !self.valid() || !dt(delta) {
            return Err("invalid construction timer");
        }
        self.build_sound -= delta;
        let sound = self.build_sound <= 0.0;
        if sound {
            self.build_sound = f64::from(rng.randf_range(0.5, 0.9));
        }
        Ok(sound)
    }

    pub fn stretcher(&mut self, input: Stretcher) -> Result<Carry, &'static str> {
        if !self.valid()
            || !point(input.position)
            || !point(input.casualty)
            || !dt(input.dt)
            || (self.phase == 1 && !time(self.timer - input.dt))
            || input.partner_phase.is_some_and(|phase| phase > 3)
        {
            return Err("invalid stretcher input");
        }
        if !input.valid {
            return Ok(Carry::Cancel);
        }
        Ok(match self.phase {
            0 => {
                if input.moving {
                    Carry::Move
                } else if f64::from(flat(input.casualty - input.position).length()) > 1.8 {
                    Carry::Approach
                } else {
                    self.phase = 1;
                    self.timer = 1.4;
                    Carry::Ready
                }
            }
            1 => {
                self.timer -= input.dt;
                if (input.partner_phase == Some(0) && self.timer > -8.0) || self.timer > 0.0 {
                    Carry::Wait
                } else if input.front || input.partner_phase.is_none() {
                    self.phase = 2;
                    Carry::Lift
                } else {
                    Carry::Wait
                }
            }
            2 => Carry::Lead,
            3 => {
                if input.partner_phase == Some(2) {
                    Carry::Follow
                } else {
                    self.phase = 2;
                    Carry::TakeOver
                }
            }
            _ => unreachable!(),
        })
    }

    pub fn captor(
        &mut self,
        valid: bool,
        position: Vector3,
        prisoner: Vector3,
        moving: bool,
    ) -> Result<Captor, &'static str> {
        if !self.valid() || !point(position) || !point(prisoner) {
            return Err("invalid prisoner escort input");
        }
        if !valid {
            return Ok(Captor::Cancel);
        }
        Ok(match self.phase {
            0 => {
                if f64::from(flat(prisoner - position).length()) < 2.6 {
                    self.phase = 1;
                    Captor::Claim
                } else {
                    Captor::Approach { repath: !moving }
                }
            }
            1 => Captor::Guard,
            _ => Captor::Wait,
        })
    }

    pub fn checkpoint(self) -> Vec<u8> {
        let mut out = Writer::new(SCHEMA);
        out.byte(self.phase);
        out.f64(self.timer);
        out.f64(self.build_sound);
        out.0
    }

    pub fn restore(bytes: &[u8]) -> Result<Self, &'static str> {
        let mut input = Reader::new(bytes, SCHEMA)?;
        let state = Self {
            phase: input.byte()?,
            timer: input.f64()?,
            build_sound: input.f64()?,
        };
        input.finish()?;
        state
            .valid()
            .then_some(state)
            .ok_or("invalid duty checkpoint")
    }
}

pub fn carry_pose(
    position: Vector3,
    yaw: f64,
    last_direction: Vector3,
    delta: f64,
    solo: bool,
    mounting: Option<(Vector3, f64)>,
) -> Result<CarryPose, &'static str> {
    if !point(position) || !point(last_direction) || !time(yaw) || !dt(delta) || !mount(mounting) {
        return Err("invalid casualty carrying pose");
    }
    Ok(if solo {
        let yaw = turn_yaw(yaw, -last_direction, position, delta, 10.0, mounting);
        CarryPose {
            yaw,
            casualty: position + direction(yaw) * 1.5 + Vector3::new(0.0, -0.55, 0.0),
            casualty_yaw: yaw,
        }
    } else {
        CarryPose {
            yaw,
            casualty: flat(position - last_direction * 1.15),
            casualty_yaw: f64::from(libm::atan2(
                f64::from(last_direction.x),
                f64::from(last_direction.z),
            ) as f32),
        }
    })
}

pub fn follow_bearer(
    position: Vector3,
    partner: Vector3,
    partner_yaw: f64,
    delta: f64,
) -> Result<Vector3, &'static str> {
    if !point(position) || !point(partner) || !time(partner_yaw) || !dt(delta) {
        return Err("invalid stretcher follower pose");
    }
    let destination = partner - direction(partner_yaw) * 2.3;
    Ok(flat(
        position + (destination - position) * (1.0 - libm::exp(-delta * 10.0)) as f32,
    ))
}

pub fn guard(
    input: Guard,
    nav: &PathPlanner,
    rng: &mut SimulationRandom,
) -> Result<GuardPose, &'static str> {
    if !point(input.position)
        || !point(input.prisoner)
        || !time(input.yaw)
        || !dt(input.dt)
        || !mount(input.mount)
    {
        return Err("invalid prisoner guard pose");
    }
    let delta = flat(input.prisoner - input.position);
    let distance = f64::from(delta.length());
    let walking = distance > 2.3;
    let mut position = input.position;
    if walking {
        let next = position + normalized(delta) * (distance - 2.0).min(1.9 * input.dt) as f32;
        position = if nav.kind_at(next, false) != 3 {
            next
        } else {
            position + (input.prisoner - position) * 0.02
        };
    } else {
        // The existing idle guard still draws once for its zero-chance firing choice.
        rng.randf();
    }
    Ok(GuardPose {
        position,
        yaw: turn_yaw(input.yaw, delta, position, input.dt, 8.0, input.mount),
        walking,
    })
}
