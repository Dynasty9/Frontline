//! Crews preserve their orders while withdrawing, evading and waiting for infantry.
use crate::path_planner::PathPlanner;
use crate::random::SimulationRandom;
use crate::vector::{normalized, Vector3};
use crate::vehicle::{Resume, Route, Vehicle};

#[derive(Clone, Copy, Debug)]
pub struct CrewProfile<'a> {
    pub base: &'a str,
    pub helicopter: bool,
    pub automatic: bool,
    pub artillery: bool,
    pub tracked: bool,
    pub armor: u8,
}
#[derive(Clone, Copy, Debug, PartialEq)]
pub enum UnitKind {
    Soldier {
        alive: bool,
        rockets: i32,
        antitank: bool,
        riding: bool,
    },
    Vehicle {
        air: bool,
        cannon: bool,
        missiles: i32,
    },
}
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Contact {
    pub id: u32,
    pub position: Vector3,
    pub team: i8,
    pub visible: bool,
    pub gone: bool,
    pub kind: UnitKind,
}
#[derive(Clone, Copy, Debug)]
pub struct Perception<'a> {
    // These use the world's existing spatial membership and tie order.
    pub threats: &'a [Contact],
    pub ahead: &'a [Contact],
    pub support: &'a [Contact],
    pub fob: Option<(u32, Vector3)>,
    pub mission: bool,
}
#[derive(Clone, Copy, Debug, PartialEq)]
pub enum CrewEvent {
    Withdraw(u32),
    PatchedUp,
    WaitInfantry,
    Evade,
}
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct CrewResult {
    pub route: Route,
    pub event: Option<CrewEvent>,
    pub repaired_track: bool,
}
impl Default for CrewResult {
    fn default() -> Self {
        Self {
            route: Route::None,
            event: None,
            repaired_track: false,
        }
    }
}
fn point(p: Vector3) -> bool {
    p.is_finite() && p.abs().max_element() <= 1_000_000.0
}
fn flat(p: Vector3) -> Vector3 {
    Vector3::new(p.x, 0.0, p.z)
}
fn distance(a: Vector3, b: Vector3) -> f64 {
    f64::from(flat(a - b).length())
}
fn valid_units(units: &[Contact]) -> bool {
    units.len() <= 100_000
        && units.iter().all(|c| {
            c.id != 0
                && point(c.position)
                && (-1..=1).contains(&c.team)
                && match c.kind {
                    UnitKind::Soldier { rockets, .. } => (0..=1_000_000).contains(&rockets),
                    UnitKind::Vehicle { missiles, .. } => (0..=1_000_000).contains(&missiles),
                }
        })
}
impl CrewProfile<'_> {
    fn valid(self) -> bool {
        self.base.len() <= 128 && self.armor <= 16
    }
    pub fn applies(self, v: &Vehicle) -> bool {
        !(self.helicopter && v.position.y > 3.0)
            && !self.automatic
            && !self.artillery
            && matches!(self.base, "tank" | "afv" | "car" | "spaa")
    }
}
impl Contact {
    fn dangerous(self) -> bool {
        match self.kind {
            UnitKind::Soldier {
                alive,
                rockets,
                antitank,
                ..
            } => alive && (rockets > 0 || antitank),
            UnitKind::Vehicle {
                air,
                cannon,
                missiles,
            } => !air && (cannon || missiles > 0),
        }
    }
}
impl Vehicle {
    fn crew_watch(&mut self, p: CrewProfile<'_>, units: &[Contact]) {
        self.face_yaw = None;
        if !p.tracked || p.armor < 2 {
            return;
        }
        let mut best = 120.0;
        for c in units {
            if c.team == self.team || c.team < 0 || c.gone || !c.visible || !c.dangerous() {
                continue;
            }
            let d = distance(c.position, self.position);
            if d < best {
                best = d;
                let to = flat(c.position - self.position);
                self.face_yaw = Some(libm::atan2(-f64::from(to.x), -f64::from(to.z)));
            }
        }
    }
    fn crew_waits(&self, now: f64, s: Perception<'_>) -> bool {
        let cooldown = self
            .cooldowns
            .iter()
            .find(|(k, _)| k == "push_on")
            .map_or(-1.0, |(_, t)| *t);
        if self.owner >= 0
            || !self.assault
            || self.path_index as usize >= self.path.len()
            || now < cooldown
        {
            return false;
        }
        let fwd = Vector3::new(
            -libm::sin(self.yaw) as f32,
            0.0,
            -libm::cos(self.yaw) as f32,
        );
        if !s.ahead.iter().any(|c| c.team != self.team && c.team >= 0 && c.visible
            && matches!(c.kind, UnitKind::Soldier { alive: true, rockets, antitank, .. } if rockets > 0 || antitank)
            && flat(c.position - self.position).dot(fwd) > 0.0) { return false; }
        !s.support.iter().any(|c| {
            c.team == self.team
                && matches!(
                    c.kind,
                    UnitKind::Soldier {
                        alive: true,
                        riding: false,
                        ..
                    }
                )
        })
    }
    fn crew_move(&mut self, p: Vector3, profile: CrewProfile<'_>) -> Result<Route, &'static str> {
        let was = self.brain_order;
        self.brain_order = true;
        let out = self.order_move(p, profile.base, p);
        self.brain_order = if out.is_ok() { false } else { was };
        out
    }
    fn crew_resume(&mut self, profile: CrewProfile<'_>) -> Result<Route, &'static str> {
        let mut route = Route::None;
        if let Some(r) = self.resume {
            if r.assault && r.assault_destination.is_some() {
                route = self.crew_move(r.assault_destination.unwrap(), profile)?;
                self.assault = true;
            } else if let Some(p) = r.destination {
                route = self.crew_move(p, profile)?;
            }
        }
        self.brain_state.clear();
        self.brain_hold = false;
        self.resume = None;
        Ok(route)
    }
    pub fn crew_think(
        &mut self,
        now: f64,
        profile: CrewProfile<'_>,
        s: Perception<'_>,
        nav: &PathPlanner,
    ) -> Result<CrewResult, &'static str> {
        if !now.is_finite()
            || !(0.0..=1e12).contains(&now)
            || !profile.valid()
            || !valid_units(s.threats)
            || !valid_units(s.ahead)
            || !valid_units(s.support)
            || s.fob.is_some_and(|(id, p)| id == 0 || !point(p))
        {
            return Err("invalid crew step");
        }
        let mut out = CrewResult::default();
        if !profile.applies(self) {
            return Ok(out);
        }
        if !matches!(self.brain_state.as_str(), "withdraw" | "evade")
            && !self.brain_overruled
            && !self.track_broken
            && self.hp <= self.max_hp * 0.35
        {
            if let Some((id, fob)) = s.fob.filter(|&(_, p)| {
                let d = distance(p, self.position);
                d > 25.0 && (!s.mission || d < 200.0)
            }) {
                let wanted = fob + normalized(flat(self.position - fob)) * 12.0;
                let p = nav
                    .nearest_walkable_for(wanted, true)
                    .ok_or("invalid retreat point")?;
                out.route = self.crew_move(p, profile)?;
                self.brain_state = "withdraw".into();
                self.brain_time = now;
                self.resume = None;
                self.assault = false;
                self.brain_hold = false;
                out.event = Some(CrewEvent::Withdraw(id));
                return Ok(out);
            }
        }
        if self.brain_state == "withdraw" {
            if s.fob
                .is_some_and(|(_, p)| self.speed.abs() < 0.5 && distance(p, self.position) < 26.0)
            {
                out.repaired_track = self.repair(0.15)?;
            }
            if self.hp > self.max_hp * 0.8 {
                self.brain_state.clear();
                out.event = Some(CrewEvent::PatchedUp);
            }
            self.crew_watch(profile, s.threats);
        } else if self.brain_state == "evade" {
            if self.path_index as usize >= self.path.len() || now - self.brain_time > 9.0 {
                out.route = self.crew_resume(profile)?;
            }
            self.crew_watch(profile, s.threats);
        } else if self.crew_waits(now, s) {
            if self.brain_state != "wait" {
                self.brain_state = "wait".into();
                self.brain_time = now;
                out.event = Some(CrewEvent::WaitInfantry);
            } else if now - self.brain_time > 45.0 {
                if now > 1e12 - 60.0 {
                    return Err("vehicle cooldown deadline out of range");
                }
                if let Some((_, time)) = self.cooldowns.iter_mut().find(|(k, _)| k == "push_on") {
                    *time = now + 60.0;
                } else {
                    if self.cooldowns.len() >= 4096 {
                        return Err("vehicle cooldown limit");
                    }
                    self.cooldowns.push(("push_on".into(), now + 60.0));
                }
                self.brain_state.clear();
                self.brain_hold = false;
                return Ok(out);
            }
            self.brain_hold = true;
            self.crew_watch(profile, s.threats);
        } else {
            if self.brain_state == "wait" {
                self.brain_state.clear();
            }
            self.brain_hold = false;
            if self.brain_overruled && self.hp > self.max_hp * 0.8 {
                self.brain_overruled = false;
            }
            self.crew_watch(profile, s.threats);
        }
        Ok(out)
    }
    pub fn crew_threat(
        &mut self,
        now: f64,
        from: Vector3,
        profile: CrewProfile<'_>,
        nav: &PathPlanner,
        rng: &mut SimulationRandom,
    ) -> Result<CrewResult, &'static str> {
        if !now.is_finite() || !(0.0..=1e12).contains(&now) || !point(from) || !profile.valid() {
            return Err("invalid crew threat");
        }
        let mut out = CrewResult::default();
        if !profile.applies(self)
            || matches!(self.brain_state.as_str(), "withdraw" | "evade")
            || self.track_broken
            || profile.armor < 1
        {
            return Ok(out);
        }
        let saved = Resume {
            destination: if self.path_pending {
                self.path_destination
            } else if (self.path_index as usize) < self.path.len() {
                self.path.last().copied()
            } else {
                None
            },
            assault: self.assault,
            assault_destination: self.assault_destination,
        };
        let mut next_rng = rng.clone();
        let away = normalized(flat(self.position - from));
        let side = away.cross(Vector3::Y) * if next_rng.randf() < 0.5 { 1.0 } else { -1.0 };
        let p = nav
            .nearest_walkable_for(self.position + away * 16.0 + side * 6.0, true)
            .ok_or("invalid evasive point")?;
        out.route = self.crew_move(p, profile)?;
        *rng = next_rng;
        self.resume = Some(saved);
        self.brain_state = "evade".into();
        self.brain_time = now;
        self.brain_hold = false;
        self.assault = false;
        out.event = Some(CrewEvent::Evade);
        Ok(out)
    }
}
