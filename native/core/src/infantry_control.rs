//! Noncombat lifecycle, motion posture and replicated status flags.
use crate::infantry_pose::Posture;
use crate::infantry_vitals::Life;
use crate::state_codec::{Reader, Writer};
use crate::vector::{turn_yaw, Vector3};

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
#[repr(u8)]
pub enum HiddenReason {
    #[default]
    Waiting,
    TunnelWait,
    Vehicle,
    Tent,
    TunnelTravel,
    Interrogation,
    Held,
}

impl TryFrom<u8> for HiddenReason {
    type Error = &'static str;
    fn try_from(value: u8) -> Result<Self, Self::Error> {
        match value {
            0 => Ok(Self::Waiting),
            1 => Ok(Self::TunnelWait),
            2 => Ok(Self::Vehicle),
            3 => Ok(Self::Tent),
            4 => Ok(Self::TunnelTravel),
            5 => Ok(Self::Interrogation),
            6 => Ok(Self::Held),
            _ => Err("invalid hidden reason"),
        }
    }
}

#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct Control {
    pub hidden: HiddenReason,
    pub hidden_timer: f64,
    pub previous_position: Vector3,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum Hidden {
    Wait,
    FollowVehicle(Vector3),
    BailOut,
    LeaveTent,
    LeaveTunnel,
    PrisonerDone,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct MotionPosture {
    pub posture: Posture,
    pub activity: u8,
    pub corrected: u8,
}

#[derive(Clone, Copy, Debug)]
pub struct Status {
    pub suppression: f64,
    pub ammunition: Option<(i32, i32)>,
    pub time: f64,
    pub last_shot: f64,
    pub life: Life,
    pub leader: bool,
    pub at_cover: bool,
    pub cover_kind: u8,
    pub peeking: bool,
    pub blind: bool,
    pub cover_height: f64,
    pub posture: Posture,
}

fn point(p: Vector3) -> bool {
    p.is_finite() && p.abs().max_element() <= 1_000_000.0
}
fn time(v: f64) -> bool {
    v.is_finite() && v.abs() <= 1e12
}
fn dt(v: f64) -> bool {
    v.is_finite() && (0.0..=10.0).contains(&v)
}
fn flat(p: Vector3) -> Vector3 {
    Vector3::new(p.x, 0.0, p.z)
}

impl Control {
    pub fn valid(self) -> bool {
        time(self.hidden_timer) && point(self.previous_position)
    }

    pub fn hidden_step(
        &mut self,
        delta: f64,
        vehicle: Option<Vector3>,
    ) -> Result<Hidden, &'static str> {
        if !self.valid()
            || !dt(delta)
            || vehicle.is_some_and(|p| !point(p))
            || !time(self.hidden_timer - delta)
        {
            return Err("invalid hidden infantry");
        }
        if self.hidden == HiddenReason::Vehicle {
            return Ok(vehicle.map_or(Hidden::BailOut, Hidden::FollowVehicle));
        }
        self.hidden_timer -= delta;
        if self.hidden_timer > 0.0 {
            return Ok(Hidden::Wait);
        }
        Ok(match self.hidden {
            HiddenReason::Tent => Hidden::LeaveTent,
            HiddenReason::TunnelTravel => Hidden::LeaveTunnel,
            HiddenReason::Interrogation | HiddenReason::Held => Hidden::PrisonerDone,
            _ => {
                self.hidden_timer = 9999.0;
                Hidden::Wait
            }
        })
    }

    pub fn motion_posture(
        &mut self,
        delta: f64,
        position: Vector3,
        life: Life,
        posture: Posture,
        activity: u8,
    ) -> Result<MotionPosture, &'static str> {
        if !self.valid()
            || !delta.is_finite()
            || delta.abs() > 10.0
            || !point(position)
            || activity > 36
        {
            return Err("invalid infantry motion posture");
        }
        let before = self.previous_position;
        self.previous_position = position;
        let mut out = MotionPosture {
            posture,
            activity,
            corrected: 0,
        };
        if life != Life::Alive || delta <= 0.0 {
            return Ok(out);
        }
        let speed = f64::from(flat(position - before).length()) / delta;
        // Soldier.Act codes are also the existing animation wire values.
        const IDLE: u8 = 0;
        const WALK: u8 = 1;
        const RUN: u8 = 2;
        const CRAWL: u8 = 11;
        const DRAGGED: u8 = 12;
        const CARRIED: u8 = 13;
        const VAULT: u8 = 14;
        const DIVE: u8 = 15;
        const SLIDE: u8 = 16;
        const FLUNG: u8 = 17;
        const FLINCH: u8 = 19;
        const CHAT: u8 = 26;
        const CHECK: u8 = 31;
        const LOOK: u8 = 32;
        const SMOTHER: u8 = 34;
        if speed < 0.3
            || matches!(
                activity,
                CRAWL | DIVE | FLUNG | SLIDE | DRAGGED | CARRIED | VAULT | SMOTHER
            )
        {
            return Ok(out);
        }
        if posture == Posture::Prone {
            out.posture = if speed < 3.2 {
                Posture::Crouch
            } else {
                Posture::Stand
            };
            out.corrected |= 1;
        }
        if matches!(activity, IDLE | CHAT | LOOK | CHECK | FLINCH) {
            out.activity = if speed > 3.2 { RUN } else { WALK };
            out.corrected |= 2;
        }
        Ok(out)
    }

    pub fn checkpoint(self) -> Vec<u8> {
        let mut out = Writer::new(b"FLCT\x01\0\0\0");
        out.byte(self.hidden as u8);
        out.f64(self.hidden_timer);
        out.point(self.previous_position);
        out.0
    }
    pub fn restore(bytes: &[u8]) -> Result<Self, &'static str> {
        let mut input = Reader::new(bytes, b"FLCT\x01\0\0\0")?;
        let state = Self {
            hidden: input.byte()?.try_into()?,
            hidden_timer: input.f64()?,
            previous_position: input.point()?,
        };
        input.finish()?;
        if !state.valid() {
            return Err("invalid infantry control checkpoint");
        }
        Ok(state)
    }
}

pub fn flags(i: Status) -> Result<u8, &'static str> {
    if !i.suppression.is_finite()
        || !(0.0..=100.0).contains(&i.suppression)
        || !time(i.time)
        || !time(i.last_shot)
        || i.cover_kind > 3
        || !i.cover_height.is_finite()
        || i.cover_height.abs() > 1_000_000.0
        || i.ammunition.is_some_and(|(capacity, total)| {
            !(0..=1_000_000).contains(&capacity) || !(0..=2_000_000).contains(&total)
        })
    {
        return Err("invalid infantry status");
    }
    let mut out = 0;
    if i.suppression > 25.0 {
        out |= 1;
    }
    if i.suppression >= 60.0 {
        out |= 2;
    }
    if let Some((capacity, total)) = i.ammunition.filter(|(capacity, _)| *capacity < 9000) {
        if total <= 0 {
            out |= 8;
        } else if total < (f64::from(capacity) * 0.3) as i32 {
            out |= 4;
        }
    }
    if i.time - i.last_shot < 0.6 {
        out |= 16;
    }
    if i.life == Life::Downed {
        out |= 32;
    }
    if i.leader {
        out |= 64;
    }
    if i.at_cover
        && i.cover_kind == 1
        && i.peeking
        && !i.blind
        && (i.cover_height > 0.0 || i.posture == Posture::Stand)
    {
        out |= 128;
    }
    Ok(out)
}

pub fn pilot_yaw(
    position: Vector3,
    yaw: f64,
    delta: f64,
    drone: Option<Vector3>,
    mount: Option<(Vector3, f64)>,
) -> Result<Option<f64>, &'static str> {
    if !point(position)
        || !time(yaw)
        || !dt(delta)
        || drone.is_some_and(|p| !point(p))
        || mount.is_some_and(|(p, s)| !point(p) || !s.is_finite() || !(0.0..=1000.0).contains(&s))
    {
        return Err("invalid drone operator pose");
    }
    Ok(drone.map(|p| turn_yaw(yaw, flat(p - position), position, delta, 4.0, mount)))
}
