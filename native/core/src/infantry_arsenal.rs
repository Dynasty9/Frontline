//! Special-weapon admission, target priority and ammunition between infantry actions.
use crate::collision::CollisionWorld;
use crate::infantry_vitals::Life;
use crate::random::SimulationRandom;
use crate::state_codec::{Reader, Writer};
use crate::vector::Vector3;
use crate::visibility::Visibility;

#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct InfantryArsenal {
    pub rockets: i32,
    pub rocket_ready: f64,
    pub drones: i32,
    pub drone_ready: f64,
    pub mortar_rounds: i32,
    pub mortar_ready: f64,
    pub melee_ready: f64,
}

#[derive(Clone, Debug)]
pub struct RocketContact {
    pub id: u64,
    pub position: Vector3,
    pub center: Vector3,
    pub gone: bool,
    pub age: f64,
    pub excluded: Vec<i64>,
}

pub struct RocketInput<'a> {
    pub time: f64,
    pub position: Vector3,
    pub eye: Vector3,
    pub ambush: bool,
    pub visible: &'a [RocketContact],
    pub reported: &'a [RocketContact],
    pub forced: Option<RocketContact>,
}

#[derive(Clone, Copy, Debug)]
pub struct MeleeContact {
    pub id: u64,
    pub team: i32,
    pub life: Life,
    pub flinging: bool,
}

#[derive(Clone, Copy, Debug)]
pub enum MortarTarget {
    Queued(Vector3),
    Automatic(Option<Vector3>),
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum MortarDecision {
    Wait,
    CancelQueue,
    Fire(Vector3),
}

fn point(v: Vector3) -> bool {
    v.is_finite() && v.abs().max_element() <= 1_000_000.0
}
fn time(v: f64) -> bool {
    v.is_finite() && v.abs() <= 1e12
}
fn action_time(v: f64) -> bool {
    time(v) && v.abs() <= 1e12 - 100.0
}
fn id(v: u64) -> bool {
    v > 0 && v <= i64::MAX as u64
}
fn distance(a: Vector3, b: Vector3) -> f64 {
    let d = a - b;
    f64::from(Vector3::new(d.x, 0.0, d.z).length())
}
impl RocketContact {
    fn valid(&self) -> bool {
        id(self.id)
            && point(self.position)
            && point(self.center)
            && time(self.age)
            && self.excluded.len() <= 4096
            && self.excluded.iter().all(|id| *id >= 0)
    }
}

impl InfantryArsenal {
    pub fn valid(self) -> bool {
        [self.rockets, self.drones, self.mortar_rounds]
            .iter()
            .all(|v| (0..=1_000_000).contains(v))
            && [
                self.rocket_ready,
                self.drone_ready,
                self.mortar_ready,
                self.melee_ready,
            ]
            .into_iter()
            .all(time)
    }

    pub fn rocket(
        &mut self,
        i: RocketInput<'_>,
        collision: &mut CollisionWorld,
        visibility: &Visibility,
    ) -> Result<Option<u64>, &'static str> {
        if !self.valid()
            || !action_time(i.time)
            || !point(i.position)
            || !point(i.eye)
            || i.visible.len() > 100_000
            || i.reported.len() > 100_000
            || i.visible.iter().chain(i.reported).any(|c| !c.valid())
            || i.forced.as_ref().is_some_and(|c| !c.valid())
        {
            return Err("invalid infantry rocket input");
        }
        if self.rockets == 0 || i.time < self.rocket_ready || i.ambush {
            return Ok(None);
        }
        let mut target = i
            .visible
            .iter()
            .find(|c| distance(c.position, i.position) < 75.0)
            .map(|c| c.id);
        if target.is_none() {
            target = i
                .reported
                .iter()
                .find(|c| {
                    !c.gone
                        && c.age < 6.0
                        && distance(c.position, i.position) < 70.0
                        && collision.ray(i.eye, c.center, &c.excluded).is_none()
                        && !visibility.smoke_blocks(i.eye, c.center)
                })
                .map(|c| c.id);
        }
        if target.is_none() {
            target = i
                .forced
                .filter(|c| !c.gone && distance(c.position, i.position) < 60.0)
                .map(|c| c.id);
        }
        if target.is_some() {
            self.rockets -= 1;
            self.rocket_ready = i.time + 4.5;
        }
        Ok(target)
    }

    // Candidates come from the world's ordered 1.9 m soldier query.
    pub fn melee(
        &mut self,
        now: f64,
        team: i32,
        armed: bool,
        nearby: &[MeleeContact],
    ) -> Result<Option<u64>, &'static str> {
        if !self.valid()
            || !action_time(now)
            || !(-1..=1).contains(&team)
            || nearby.len() > 100_000
            || nearby
                .iter()
                .any(|c| !id(c.id) || !(-1..=1).contains(&c.team))
        {
            return Err("invalid infantry melee input");
        }
        if now < self.melee_ready || !armed {
            return Ok(None);
        }
        let target = nearby
            .iter()
            .find(|c| c.team >= 0 && c.team != team && c.life == Life::Alive && !c.flinging)
            .map(|c| c.id);
        if target.is_some() {
            self.melee_ready = now + 1.4;
        }
        Ok(target)
    }

    pub fn drone(
        &mut self,
        now: f64,
        controlling: bool,
        target: Option<u64>,
        rng: &mut SimulationRandom,
    ) -> Result<Option<u64>, &'static str> {
        if !self.valid() || !action_time(now) || target.is_some_and(|v| !id(v)) {
            return Err("invalid infantry drone input");
        }
        if self.drones == 0 || now < self.drone_ready || controlling {
            return Ok(None);
        }
        self.drone_ready = now + 3.0;
        if target.is_some() {
            self.drones -= 1;
            self.drone_ready = now + f64::from(rng.randf_range(18.0, 26.0));
        }
        Ok(target)
    }

    pub fn mortar(
        &mut self,
        now: f64,
        position: Vector3,
        moving: bool,
        squad: bool,
        target: MortarTarget,
    ) -> Result<MortarDecision, &'static str> {
        let target_point = match target {
            MortarTarget::Queued(p) => Some(p),
            MortarTarget::Automatic(p) => p,
        };
        if !self.valid()
            || !action_time(now)
            || !point(position)
            || target_point.is_some_and(|p| !point(p))
        {
            return Err("invalid infantry mortar input");
        }
        if self.mortar_rounds == 0 || now < self.mortar_ready || moving || !squad {
            return Ok(MortarDecision::Wait);
        }
        match target {
            MortarTarget::Queued(p) => {
                if !(25.0..=140.0).contains(&distance(p, position)) {
                    return Ok(MortarDecision::CancelQueue);
                }
            }
            MortarTarget::Automatic(_) => self.mortar_ready = now + 2.0,
        }
        let Some(p) = target_point else {
            return Ok(MortarDecision::Wait);
        };
        self.mortar_rounds -= 1;
        self.mortar_ready = now + 3.5;
        Ok(MortarDecision::Fire(p))
    }

    pub fn checkpoint(self) -> Vec<u8> {
        let mut out = Writer::new(b"FLAR\x01\0\0\0");
        out.u32(self.rockets as u32);
        out.f64(self.rocket_ready);
        out.u32(self.drones as u32);
        out.f64(self.drone_ready);
        out.u32(self.mortar_rounds as u32);
        out.f64(self.mortar_ready);
        out.f64(self.melee_ready);
        out.0
    }

    pub fn restore(bytes: &[u8]) -> Result<Self, &'static str> {
        let mut input = Reader::new(bytes, b"FLAR\x01\0\0\0")?;
        let state = Self {
            rockets: i32::try_from(input.u32()?).map_err(|_| "invalid rocket count")?,
            rocket_ready: input.f64()?,
            drones: i32::try_from(input.u32()?).map_err(|_| "invalid drone count")?,
            drone_ready: input.f64()?,
            mortar_rounds: i32::try_from(input.u32()?).map_err(|_| "invalid mortar count")?,
            mortar_ready: input.f64()?,
            melee_ready: input.f64()?,
        };
        input.finish()?;
        if !state.valid() {
            return Err("invalid infantry arsenal");
        }
        Ok(state)
    }
}
