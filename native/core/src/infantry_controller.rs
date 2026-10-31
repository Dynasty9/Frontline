//! Soldier update scheduling. Interruption stages precede thinking and ordinary duties.
use crate::infantry_action::ActionState;
use crate::infantry_shock::InfantryShock;
use crate::infantry_vitals::Life;
use crate::path_planner::PathPlanner;
use crate::random::SimulationRandom;
use crate::state_codec::{Reader, Writer};
use crate::vector::Vector3;

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
#[repr(u8)]
pub enum Task {
    #[default]
    Fight,
    Rescue,
    Escort,
    Heal,
    Build,
    Stretcher,
    Limp,
    Captor,
    Man,
    Tunnel,
    Board,
    Resupply,
    GrenadePickup,
    Smother,
    GrenadeKick,
    Breach,
    Retreat,
    Throw,
    Pilot,
    Unknown,
}

impl TryFrom<u8> for Task {
    type Error = &'static str;
    fn try_from(value: u8) -> Result<Self, Self::Error> {
        Ok(match value {
            0 => Self::Fight,
            1 => Self::Rescue,
            2 => Self::Escort,
            3 => Self::Heal,
            4 => Self::Build,
            5 => Self::Stretcher,
            6 => Self::Limp,
            7 => Self::Captor,
            8 => Self::Man,
            9 => Self::Tunnel,
            10 => Self::Board,
            11 => Self::Resupply,
            12 => Self::GrenadePickup,
            13 => Self::Smother,
            14 => Self::GrenadeKick,
            15 => Self::Breach,
            16 => Self::Retreat,
            17 => Self::Throw,
            18 => Self::Pilot,
            19 => Self::Unknown,
            _ => return Err("invalid infantry task"),
        })
    }
}

impl Task {
    pub fn can_take_orders(self, life: Life, phase: u8) -> bool {
        life == Life::Alive
            && !matches!(
                self,
                Self::Stretcher | Self::Captor | Self::Limp | Self::Tunnel
            )
            && !(self == Self::Rescue && phase >= 1)
    }
    pub fn can_retreat(self, life: Life) -> bool {
        life == Life::Alive
            && !matches!(
                self,
                Self::Stretcher | Self::Captor | Self::Limp | Self::Tunnel
            )
    }
    pub fn busy(self, phase: u8, bearer: bool) -> bool {
        bearer
            || matches!(
                self,
                Self::Stretcher | Self::Limp | Self::Tunnel | Self::Retreat | Self::Captor
            )
            || (self == Self::Rescue && phase >= 1)
    }
}

#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct Controller {
    pub think_timer: f64,
    pub scan_number: u64,
    pub activity_timer: f64,
    pub dive_timer: f64,
    pub dive_direction: Vector3,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
#[repr(u8)]
pub enum Stage {
    Duty,
    Dazed,
    Dive,
    Action,
    Flinch,
    Think,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Advance {
    pub stage: Stage,
    pub flinch_ended: bool,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Dive {
    pub position: Vector3,
    pub finished: bool,
}

fn time(v: f64) -> bool {
    v.is_finite() && v.abs() <= 1e12
}
fn point(p: Vector3) -> bool {
    p.is_finite() && p.abs().max_element() <= 1_000_000.0
}
fn delta(v: f64) -> bool {
    v.is_finite() && (0.0..=10.0).contains(&v)
}

impl Controller {
    pub fn valid(self) -> bool {
        [self.think_timer, self.activity_timer, self.dive_timer]
            .into_iter()
            .all(time)
            && self.scan_number <= i64::MAX as u64
            && point(self.dive_direction)
    }

    pub fn activity_due(&mut self, dt: f64) -> Result<bool, &'static str> {
        if !self.valid() || !delta(dt) || !time(self.activity_timer - dt) {
            return Err("invalid activity timer");
        }
        self.activity_timer -= dt;
        let due = self.activity_timer <= 0.0;
        if due {
            self.activity_timer = 0.25;
        }
        Ok(due)
    }

    pub fn scan_due(&mut self, target_present: bool) -> Result<bool, &'static str> {
        if !self.valid() || self.scan_number == i64::MAX as u64 {
            return Err("invalid infantry scan cursor");
        }
        self.scan_number += 1;
        Ok(self.scan_number % 2 == 0 || !target_present)
    }

    // The actor recovers fatigue before entering this stage, and applies the returned stage once.
    pub fn advance(
        &mut self,
        dt: f64,
        shock: &mut InfantryShock,
        action: &mut ActionState,
        rng: &mut SimulationRandom,
    ) -> Result<Advance, &'static str> {
        if !self.valid()
            || !delta(dt)
            || !shock.valid()
            || !action.valid()
            || ![
                self.think_timer - dt,
                shock.flinch_timer - dt,
                action.remaining - dt,
            ]
            .into_iter()
            .all(time)
        {
            return Err("invalid infantry update clock");
        }
        let mut out = Advance {
            stage: Stage::Duty,
            flinch_ended: false,
        };
        if shock.dazed_timer > 0.0 {
            out.stage = Stage::Dazed;
            return Ok(out);
        }
        if self.dive_timer > 0.0 {
            out.stage = Stage::Dive;
            return Ok(out);
        }
        if action.remaining > 0.0 {
            action.advance(dt)?;
            out.stage = Stage::Action;
            return Ok(out);
        }
        if shock.flinch_timer > 0.0 {
            shock.flinch_timer -= dt;
            if shock.flinch_timer > 0.0 {
                out.stage = Stage::Flinch;
                return Ok(out);
            }
            out.flinch_ended = true;
        }
        self.think_timer -= dt;
        if self.think_timer <= 0.0 {
            self.think_timer = 0.24 + f64::from(rng.randf()) * 0.1;
            out.stage = Stage::Think;
        }
        Ok(out)
    }

    pub fn dive(
        &mut self,
        position: Vector3,
        base: f64,
        dt: f64,
        nav: &PathPlanner,
    ) -> Result<Dive, &'static str> {
        if !self.valid()
            || !point(position)
            || !time(base)
            || base.abs() > 1_000_000.0
            || !delta(dt)
            || !time(self.dive_timer - dt)
        {
            return Err("invalid infantry dive");
        }
        let next = position + self.dive_direction * 5.5 * dt as f32;
        if !point(next) {
            return Err("invalid dive destination");
        }
        self.dive_timer -= dt;
        let mut position = if nav.kind_at(next, false) != 3 {
            next
        } else {
            position
        };
        position.y = base.max(f64::from(position.y) - dt * 3.0) as f32;
        Ok(Dive {
            position,
            finished: self.dive_timer <= 0.0,
        })
    }

    pub fn checkpoint(self) -> Vec<u8> {
        let mut out = Writer::new(b"FLSC\x01\0\0\0");
        out.f64(self.think_timer);
        out.u64(self.scan_number);
        out.f64(self.activity_timer);
        out.f64(self.dive_timer);
        out.point(self.dive_direction);
        out.0
    }
    pub fn restore(bytes: &[u8]) -> Result<Self, &'static str> {
        let mut input = Reader::new(bytes, b"FLSC\x01\0\0\0")?;
        let state = Self {
            think_timer: input.f64()?,
            scan_number: input.u64()?,
            activity_timer: input.f64()?,
            dive_timer: input.f64()?,
            dive_direction: input.point()?,
        };
        input.finish()?;
        state
            .valid()
            .then_some(state)
            .ok_or("invalid infantry controller checkpoint")
    }
}

pub fn continue_after_think(
    life: Life,
    action_timer: f64,
    dive_timer: f64,
) -> Result<bool, &'static str> {
    if !time(action_timer) || !time(dive_timer) {
        return Err("invalid thought completion");
    }
    Ok(life == Life::Alive && action_timer <= 0.0 && dive_timer <= 0.0)
}
