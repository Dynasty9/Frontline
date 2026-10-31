//! Squad knowledge and orders are authoritative, including caches that delay decisions.
use crate::actors::{Actor, Actors};
use crate::infantry::{Infantry, Opening};
use crate::infantry_controller::Task;
use crate::infantry_vitals::Life;
use crate::random::SimulationRandom;
use crate::state_codec::{Reader, Writer};
use crate::vector::Vector3;
use std::collections::HashSet;

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Report {
    pub position: Vector3,
    pub time: f64,
}
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Contact {
    pub id: u32,
    pub report: Report,
}
#[derive(Clone, Debug, PartialEq)]
pub struct SavedOrder {
    pub order: String,
    pub position: Vector3,
    pub facing: Vector3,
    pub mode: u8,
}
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct ClearHouse {
    pub house: u32,
    pub opening: Opening,
    pub soldier: u32,
    pub buddy: u32,
}
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Speech {
    pub soldier: u32,
    pub cue: u8,
}

#[derive(Clone, Debug, PartialEq)]
pub struct Squad {
    pub id: u32,
    pub team: i8,
    pub owner: i32,
    pub kind: String,
    pub members: Vec<u32>,
    pub known: Vec<Contact>,
    pub heard: Vec<Report>,
    pub combat_at: f64,
    pub combat: bool,
    pub centroid_at: f64,
    pub center: Vector3,
    pub briefing_at: f64,
    pub briefing: Vec<Vector3>,
    pub buildings_at: f64,
    pub buildings: Vec<(u32, u32)>,
    pub order: String,
    pub order_position: Vector3,
    pub order_number: u64,
    pub shown_order: String,
    pub facing: Vector3,
    pub cover_fire_until: f64,
    pub cover_fire_position: Vector3,
    pub think_timer: f64,
    pub smoked: Vec<(u32, f64)>,
    pub build_target: u32,
    pub tunnel_exit: Option<Vector3>,
    pub fire_queue: Vec<(Vector3, bool)>,
    pub bound_team: u8,
    pub bound_time: f64,
    pub contact_time: f64,
    pub alert_time: f64,
    pub leader: u32,
    pub travel: bool,
    pub travel_mode: u8,
    pub final_slots: Vec<(u32, Vector3)>,
    pub plan: u32,
    pub breach_by: u32,
    pub morale: f64,
    pub drill: String,
    pub drill_time: f64,
    pub drill_position: Vector3,
    pub halt_destination: Vector3,
    pub halt_face: Vector3,
    pub halt_mode: u8,
    pub move_mode: u8,
    pub known_at_order: Vec<Contact>,
    pub impacts: Vec<Report>,
    pub last_casualty: f64,
    pub displace_cooldown: f64,
    pub previous_order: Option<SavedOrder>,
    pub ammo_timer: f64,
    pub cooldowns: Vec<(String, f64)>,
    pub ambush: bool,
    pub ambush_time: f64,
    pub offsets: Vec<(u32, [f32; 2])>,
    pub technique: String,
    pub overwatch_team: u8,
    pub overwatch_time: f64,
    pub recon_fire_time: f64,
    pub then_defend: Option<[Vector3; 2]>,
    pub cleared: Vec<(u32, f64)>,
    pub clear_house: Option<ClearHouse>,
    pub clear_call: Option<(u32, f64)>,
    pub ambush_plan: u32,
    pub halt_then: Option<[Vector3; 2]>,
}

impl Default for Squad {
    fn default() -> Self {
        Self {
            id: 0,
            team: 0,
            owner: 0,
            kind: String::new(),
            members: vec![],
            known: vec![],
            heard: vec![],
            combat_at: -1.0,
            combat: false,
            centroid_at: -1.0,
            center: Vector3::ZERO,
            briefing_at: -1.0,
            briefing: vec![],
            buildings_at: -1.0,
            buildings: vec![],
            order: "hold".into(),
            order_position: Vector3::ZERO,
            order_number: 0,
            shown_order: String::new(),
            facing: Vector3::NEG_Z,
            cover_fire_until: 0.0,
            cover_fire_position: Vector3::ZERO,
            think_timer: 0.0,
            smoked: vec![],
            build_target: 0,
            tunnel_exit: None,
            fire_queue: vec![],
            bound_team: 0,
            bound_time: 0.0,
            contact_time: -99.0,
            alert_time: -99.0,
            leader: 0,
            travel: false,
            travel_mode: 0,
            final_slots: vec![],
            plan: 0,
            breach_by: 0,
            morale: -1.0,
            drill: String::new(),
            drill_time: 0.0,
            drill_position: Vector3::ZERO,
            halt_destination: Vector3::ZERO,
            halt_face: Vector3::NEG_Z,
            halt_mode: 0,
            move_mode: 0,
            known_at_order: vec![],
            impacts: vec![],
            last_casualty: -99.0,
            displace_cooldown: 0.0,
            previous_order: None,
            ammo_timer: 0.0,
            cooldowns: vec![],
            ambush: false,
            ambush_time: 0.0,
            offsets: vec![],
            technique: String::new(),
            overwatch_team: 0,
            overwatch_time: 0.0,
            recon_fire_time: 0.0,
            then_defend: None,
            cleared: vec![],
            clear_house: None,
            clear_call: None,
            ambush_plan: 0,
            halt_then: None,
        }
    }
}

fn point(p: Vector3) -> bool {
    p.is_finite() && p.abs().max_element() <= 1_000_000.0
}
fn time(t: f64) -> bool {
    t.is_finite() && t.abs() <= 1e12
}
fn unique(ids: impl Iterator<Item = u32>) -> bool {
    let mut seen = HashSet::new();
    ids.into_iter().all(|id| id != 0 && seen.insert(id))
}
fn order(s: &str) -> bool {
    matches!(
        s,
        "hold" | "move" | "attack" | "build" | "tunnel" | "defend" | "assault" | "withdraw"
    )
}
fn valid_contacts(v: &[Contact]) -> bool {
    v.len() <= 100_000
        && unique(v.iter().map(|c| c.id))
        && v.iter()
            .all(|c| point(c.report.position) && time(c.report.time))
}
fn valid_pairs(v: &[(u32, f64)]) -> bool {
    v.len() <= 100_000 && unique(v.iter().map(|p| p.0)) && v.iter().all(|p| time(p.1))
}

impl Squad {
    pub fn new(id: u32, team: i8, owner: i32, kind: String) -> Result<Self, &'static str> {
        let q = Self {
            id,
            team,
            owner,
            kind,
            think_timer: (f64::from(id) * 0.309016994) % 0.5,
            ..Default::default()
        };
        if !q.valid() {
            return Err("invalid squad birth");
        }
        Ok(q)
    }

    pub fn add_member(&mut self, id: u32, actors: &mut Actors) -> Result<bool, &'static str> {
        if !self.valid() {
            return Err("invalid squad");
        }
        if self.members.contains(&id) {
            return Ok(false);
        }
        if self.members.len() == 4096 {
            return Err("squad member limit exceeded");
        }
        let s = actors.soldier_mut(id).ok_or("missing squad recruit")?;
        self.members.push(id);
        self.centroid_at = -1.0;
        s.identity.squad = self.id;
        if self.order_position == Vector3::ZERO {
            self.order_position = s.motion.position;
        }
        Ok(true)
    }

    pub fn valid(&self) -> bool {
        self.id != 0
            && (-1..=1).contains(&self.team)
            && self.owner >= -2
            && self.kind.len() <= 128
            && self.members.len() <= 4096
            && unique(self.members.iter().copied())
            && valid_contacts(&self.known)
            && valid_contacts(&self.known_at_order)
            && self.heard.len() <= 8
            && self.impacts.len() <= 100_000
            && self
                .heard
                .iter()
                .chain(&self.impacts)
                .all(|r| point(r.position) && time(r.time))
            && [
                self.combat_at,
                self.centroid_at,
                self.briefing_at,
                self.buildings_at,
                self.cover_fire_until,
                self.think_timer,
                self.bound_time,
                self.contact_time,
                self.alert_time,
                self.drill_time,
                self.last_casualty,
                self.displace_cooldown,
                self.ammo_timer,
                self.ambush_time,
                self.overwatch_time,
                self.recon_fire_time,
            ]
            .into_iter()
            .all(time)
            && [
                self.center,
                self.order_position,
                self.facing,
                self.cover_fire_position,
                self.drill_position,
                self.halt_destination,
                self.halt_face,
            ]
            .into_iter()
            .all(point)
            && self.briefing.len() <= 3
            && self.briefing.iter().copied().all(point)
            && self.buildings.len() <= 100_000
            && order(&self.order)
            && self.order_number <= i64::MAX as u64
            && self.shown_order.len() <= 128
            && valid_pairs(&self.smoked)
            && valid_pairs(&self.cleared)
            && self.tunnel_exit.is_none_or(point)
            && self.fire_queue.len() <= 100_000
            && self.fire_queue.iter().all(|(p, _)| point(*p))
            && self.bound_team <= 1
            && self.overwatch_team <= 1
            && [self.travel_mode, self.halt_mode, self.move_mode]
                .into_iter()
                .all(|m| m <= 2)
            && self.final_slots.len() <= 4096
            && unique(self.final_slots.iter().map(|p| p.0))
            && self.final_slots.iter().all(|p| point(p.1))
            && self.morale.is_finite()
            && (-1.0..=100.0).contains(&self.morale)
            && matches!(
                self.drill.as_str(),
                "" | "contact" | "displace" | "withdraw" | "rout"
            )
            && self.previous_order.as_ref().is_none_or(|o| {
                order(&o.order) && point(o.position) && point(o.facing) && o.mode <= 2
            })
            && self.cooldowns.len() <= 1024
            && self
                .cooldowns
                .iter()
                .all(|(k, v)| !k.is_empty() && k.len() <= 128 && time(*v))
            && self
                .cooldowns
                .iter()
                .map(|p| &p.0)
                .collect::<HashSet<_>>()
                .len()
                == self.cooldowns.len()
            && self.offsets.len() <= 4096
            && unique(self.offsets.iter().map(|o| o.0))
            && self.offsets.iter().all(|o| {
                o.1.into_iter()
                    .all(|v| v.is_finite() && v.abs() <= 1_000_000.0)
            })
            && matches!(self.technique.as_str(), "" | "bound")
            && self.then_defend.is_none_or(|p| p.into_iter().all(point))
            && self.halt_then.is_none_or(|p| p.into_iter().all(point))
            && self.clear_house.is_none_or(|c| {
                c.opening.id <= u32::MAX as u64
                    && point(c.opening.center)
                    && point(c.opening.normal)
            })
            && self.clear_call.is_none_or(|(_, t)| time(t))
    }

    pub fn alive<'a>(&'a self, actors: &'a Actors) -> impl Iterator<Item = &'a Infantry> {
        self.members
            .iter()
            .filter_map(|&id| actors.soldier(id))
            .filter(|s| s.vitals.life == Life::Alive)
    }
    pub fn centroid(&mut self, now: f64, actors: &Actors) -> Vector3 {
        if self.centroid_at == now {
            return self.center;
        }
        let mut center = Vector3::ZERO;
        let mut count = 0;
        for s in self.members.iter().filter_map(|&id| actors.soldier(id)) {
            if !matches!(s.vitals.life, Life::Dead | Life::Hidden) {
                center += s.motion.position;
                count += 1;
            }
        }
        self.centroid_at = now;
        self.center = if count == 0 {
            self.order_position
        } else {
            center / count as f32
        };
        self.center
    }
    pub fn report(&mut self, contact: Contact) -> Result<(), &'static str> {
        if contact.id == 0 || !point(contact.report.position) || !time(contact.report.time) {
            return Err("invalid squad contact");
        }
        if let Some(old) = self.known.iter_mut().find(|c| c.id == contact.id) {
            *old = contact;
        } else {
            if self.known.len() == 100_000 {
                return Err("squad contact limit exceeded");
            }
            self.known.push(contact);
            self.briefing_at = -1.0;
            self.buildings_at = -1.0;
        }
        self.combat_at = contact.report.time;
        self.combat = true;
        Ok(())
    }
    pub fn report_position(&mut self, position: Vector3, now: f64) -> Result<(), &'static str> {
        if !point(position) || !time(now) {
            return Err("invalid squad report");
        }
        if self.briefing.is_empty() {
            self.briefing_at = -1.0;
        }
        self.combat_at = -1.0;
        self.heard.push(Report {
            position,
            time: now,
        });
        if self.heard.len() > 8 {
            self.heard.remove(0);
        }
        Ok(())
    }
    pub fn in_combat(&mut self, now: f64) -> bool {
        if self.combat_at == now {
            return self.combat;
        }
        self.combat = self.combat_status(now);
        self.combat_at = now;
        self.combat
    }
    pub fn combat_status(&self, now: f64) -> bool {
        if self.combat_at == now {
            self.combat
        } else {
            self.known.iter().any(|k| now - k.report.time < 8.0)
                || self.heard.last().is_some_and(|r| now - r.time < 6.0)
        }
    }
    pub fn tactical(&self, now: f64) -> bool {
        self.plan != 0
            || matches!(self.order.as_str(), "assault" | "attack" | "defend")
            || now - self.alert_time < 60.0
    }
    pub fn get_leader(
        &mut self,
        actors: &mut Actors,
        mut bearer: impl FnMut(&Infantry) -> bool,
        rng: &mut SimulationRandom,
    ) -> (u32, Option<Speech>) {
        if actors
            .soldier(self.leader)
            .is_some_and(|s| s.vitals.life == Life::Alive && s.identity.squad == self.id)
        {
            return (self.leader, None);
        }
        let had = self.leader != 0;
        let leader = self
            .alive(actors)
            .find(|s| !bearer(s) && matches!(s.duty.kind, Task::Fight | Task::Retreat))
            .map_or(0, |s| s.identity.id);
        self.leader = leader;
        let speech = if self.leader != 0 && had {
            let cue = (rng.randi() % 3) as u8;
            actors
                .soldier_mut(self.leader)
                .unwrap()
                .vitals
                .speech_cooldown = 2.6;
            Some(Speech {
                soldier: self.leader,
                cue,
            })
        } else {
            None
        };
        (self.leader, speech)
    }
    pub fn casualty(
        &mut self,
        id: u32,
        now: f64,
        actors: &mut Actors,
        rng: &mut SimulationRandom,
    ) -> Result<Option<Speech>, &'static str> {
        if !time(now) {
            return Err("invalid casualty time");
        }
        let s = actors.soldier(id).ok_or("missing casualty")?;
        let mut hit = match s.vitals.life {
            Life::Downed => 7.0,
            Life::Dead if s.vitals.times_downed > 0 || s.vitals.downed_at > 0.0 => 4.0,
            Life::Dead => 10.0,
            _ => 0.0,
        };
        if self.leader == id || self.leader == 0 && self.members.first() == Some(&id) {
            hit += 6.0;
        }
        self.morale = (self.morale - hit).max(0.0);
        self.last_casualty = now;
        let position = s.motion.position;
        let speaker = if s.vitals.life == Life::Downed {
            self.alive(actors)
                .find(|m| {
                    let d = m.motion.position - position;
                    f64::from(Vector3::new(d.x, 0.0, d.z).length()) < 30.0
                })
                .map(|m| m.identity.id)
        } else {
            None
        };
        Ok(speaker.map(|id| {
            let cue = (rng.randi() % 4) as u8;
            actors.soldier_mut(id).unwrap().vitals.speech_cooldown = 2.6;
            Speech { soldier: id, cue }
        }))
    }
    pub fn threat_points(
        &self,
        origin: Vector3,
        count: usize,
        now: f64,
        actors: &Actors,
    ) -> Vec<Vector3> {
        let count = count.min(100_000);
        if count == 0 {
            return vec![];
        }
        let mut nearest: Vec<(f64, Vector3)> =
            Vec::with_capacity(count.min(self.known.len() + self.heard.len()));
        let mut insert = |p: Vector3, extra: f64| {
            let difference = p - origin;
            let dx = f64::from(difference.x);
            let dz = f64::from(difference.z);
            let distance = dx * dx + dz * dz + extra;
            if distance > 120.0 * 120.0
                || nearest.len() >= count && distance >= nearest.last().unwrap().0
            {
                return;
            }
            let at = nearest.partition_point(|v| v.0 <= distance);
            nearest.insert(at, (distance, p));
            if nearest.len() > count {
                nearest.pop();
            }
        };
        for contact in &self.known {
            if now - contact.report.time <= 15.0
                && actors.get(contact.id).is_some_and(
                    |e| !matches!(e, Actor::Soldier(s) if s.vitals.life != Life::Alive),
                )
            {
                insert(contact.report.position, 0.0);
            }
        }
        for r in &self.heard {
            if now - r.time < 8.0 {
                insert(r.position, 400.0);
            }
        }
        nearest
            .into_iter()
            .map(|(_, p)| p + Vector3::Y * 1.5)
            .collect()
    }
    pub fn sector_threats(&mut self, origin: Vector3, now: f64, actors: &Actors) -> Vec<Vector3> {
        let center = self.centroid(now, actors);
        if f64::from(origin.distance_squared(center)) > 25.0 * 25.0 {
            return self.threat_points(origin, 3, now, actors);
        }
        if self.briefing_at < 0.0 || now - self.briefing_at >= 0.25 {
            self.briefing = self.threat_points(center, 3, now, actors);
            self.briefing_at = now;
        }
        self.briefing.clone()
    }

    pub fn checkpoint(&self) -> Result<Vec<u8>, &'static str> {
        if !self.valid() {
            return Err("invalid squad state");
        }
        let mut out = Writer::new(b"FLSQ\x01\0\0\0");
        for s in [
            &self.kind,
            &self.order,
            &self.shown_order,
            &self.drill,
            &self.technique,
        ] {
            out.bytes(s.as_bytes());
        }
        for id in [
            self.id,
            self.leader,
            self.plan,
            self.ambush_plan,
            self.build_target,
            self.breach_by,
        ] {
            out.u32(id);
        }
        out.byte(self.team as u8);
        out.u32(self.owner as u32);
        out.u64(self.order_number);
        for b in [self.combat, self.travel, self.ambush] {
            out.byte(u8::from(b));
        }
        for b in [
            self.bound_team,
            self.travel_mode,
            self.halt_mode,
            self.move_mode,
            self.overwatch_team,
        ] {
            out.byte(b);
        }
        for t in [
            self.combat_at,
            self.centroid_at,
            self.briefing_at,
            self.buildings_at,
            self.cover_fire_until,
            self.think_timer,
            self.bound_time,
            self.contact_time,
            self.alert_time,
            self.morale,
            self.drill_time,
            self.last_casualty,
            self.displace_cooldown,
            self.ammo_timer,
            self.ambush_time,
            self.overwatch_time,
            self.recon_fire_time,
        ] {
            out.f64(t);
        }
        for p in [
            self.center,
            self.order_position,
            self.facing,
            self.cover_fire_position,
            self.drill_position,
            self.halt_destination,
            self.halt_face,
        ] {
            out.point(p);
        }
        out.u32(self.members.len() as u32);
        for &id in &self.members {
            out.u32(id);
        }
        for contacts in [&self.known, &self.known_at_order] {
            out.u32(contacts.len() as u32);
            for c in contacts {
                out.u32(c.id);
                out.point(c.report.position);
                out.f64(c.report.time);
            }
        }
        for reports in [&self.heard, &self.impacts] {
            out.u32(reports.len() as u32);
            for r in reports {
                out.point(r.position);
                out.f64(r.time);
            }
        }
        out.u32(self.briefing.len() as u32);
        for &p in &self.briefing {
            out.point(p);
        }
        out.u32(self.buildings.len() as u32);
        for &(s, h) in &self.buildings {
            out.u32(s);
            out.u32(h);
        }
        for pairs in [&self.smoked, &self.cleared] {
            out.u32(pairs.len() as u32);
            for &(id, t) in pairs {
                out.u32(id);
                out.f64(t);
            }
        }
        out.u32(self.final_slots.len() as u32);
        for &(id, p) in &self.final_slots {
            out.u32(id);
            out.point(p);
        }
        out.u32(self.offsets.len() as u32);
        for &(id, p) in &self.offsets {
            out.u32(id);
            out.f32(p[0]);
            out.f32(p[1]);
        }
        out.u32(self.cooldowns.len() as u32);
        for (k, t) in &self.cooldowns {
            out.bytes(k.as_bytes());
            out.f64(*t);
        }
        out.u32(self.fire_queue.len() as u32);
        for &(p, smoke) in &self.fire_queue {
            out.point(p);
            out.byte(u8::from(smoke));
        }
        out.byte(u8::from(self.tunnel_exit.is_some()));
        if let Some(p) = self.tunnel_exit {
            out.point(p);
        }
        out.byte(u8::from(self.previous_order.is_some()));
        if let Some(o) = &self.previous_order {
            out.bytes(o.order.as_bytes());
            out.point(o.position);
            out.point(o.facing);
            out.byte(o.mode);
        }
        for p in [self.then_defend, self.halt_then] {
            out.byte(u8::from(p.is_some()));
            if let Some(p) = p {
                out.point(p[0]);
                out.point(p[1]);
            }
        }
        out.byte(u8::from(self.clear_house.is_some()));
        if let Some(c) = self.clear_house {
            for id in [c.house, c.soldier, c.buddy, c.opening.id as u32] {
                out.u32(id);
            }
            out.point(c.opening.center);
            out.point(c.opening.normal);
            out.byte(u8::from(c.opening.door));
        }
        out.byte(u8::from(self.clear_call.is_some()));
        if let Some((id, t)) = self.clear_call {
            out.u32(id);
            out.f64(t);
        }
        Ok(out.0)
    }

    pub fn restore(bytes: &[u8]) -> Result<Self, &'static str> {
        if bytes.len() > 64 * 1024 * 1024 {
            return Err("squad checkpoint exceeds limit");
        }
        let mut input = Reader::new(bytes, b"FLSQ\x01\0\0\0")?;
        let kind = text(&mut input)?;
        let order = text(&mut input)?;
        let shown_order = text(&mut input)?;
        let drill = text(&mut input)?;
        let technique = text(&mut input)?;
        let id = input.u32()?;
        let leader = input.u32()?;
        let plan = input.u32()?;
        let ambush_plan = input.u32()?;
        let build_target = input.u32()?;
        let breach_by = input.u32()?;
        let team = input.byte()? as i8;
        let owner = input.u32()? as i32;
        let order_number = input.u64()?;
        let combat = input.boolean()?;
        let travel = input.boolean()?;
        let ambush = input.boolean()?;
        let bound_team = input.byte()?;
        let travel_mode = input.byte()?;
        let halt_mode = input.byte()?;
        let move_mode = input.byte()?;
        let overwatch_team = input.byte()?;
        let mut timers = [0.0; 17];
        for t in &mut timers {
            *t = input.f64()?;
        }
        let [combat_at, centroid_at, briefing_at, buildings_at, cover_fire_until, think_timer, bound_time, contact_time, alert_time, morale, drill_time, last_casualty, displace_cooldown, ammo_timer, ambush_time, overwatch_time, recon_fire_time] =
            timers;
        let mut points = [Vector3::ZERO; 7];
        for p in &mut points {
            *p = input.point()?;
        }
        let [center, order_position, facing, cover_fire_position, drill_position, halt_destination, halt_face] =
            points;
        let members = list(&mut input, 4096, |r| r.u32())?;
        let known = contacts(&mut input)?;
        let known_at_order = contacts(&mut input)?;
        let heard = reports(&mut input, 8)?;
        let impacts = reports(&mut input, 100_000)?;
        let briefing = list(&mut input, 3, |r| r.point())?;
        let buildings = list(&mut input, 100_000, |r| Ok((r.u32()?, r.u32()?)))?;
        let smoked = list(&mut input, 100_000, |r| Ok((r.u32()?, r.f64()?)))?;
        let cleared = list(&mut input, 100_000, |r| Ok((r.u32()?, r.f64()?)))?;
        let final_slots = list(&mut input, 4096, |r| Ok((r.u32()?, r.point()?)))?;
        let offsets = list(&mut input, 4096, |r| Ok((r.u32()?, [r.f32()?, r.f32()?])))?;
        let cooldowns = list(&mut input, 1024, |r| Ok((text(r)?, r.f64()?)))?;
        let fire_queue = list(&mut input, 100_000, |r| Ok((r.point()?, r.boolean()?)))?;
        let tunnel_exit = if input.boolean()? {
            Some(input.point()?)
        } else {
            None
        };
        let previous_order = if input.boolean()? {
            Some(SavedOrder {
                order: text(&mut input)?,
                position: input.point()?,
                facing: input.point()?,
                mode: input.byte()?,
            })
        } else {
            None
        };
        let then_defend = if input.boolean()? {
            Some([input.point()?, input.point()?])
        } else {
            None
        };
        let halt_then = if input.boolean()? {
            Some([input.point()?, input.point()?])
        } else {
            None
        };
        let clear_house = if input.boolean()? {
            Some(ClearHouse {
                house: input.u32()?,
                soldier: input.u32()?,
                buddy: input.u32()?,
                opening: Opening {
                    id: u64::from(input.u32()?),
                    center: input.point()?,
                    normal: input.point()?,
                    door: input.boolean()?,
                },
            })
        } else {
            None
        };
        let clear_call = if input.boolean()? {
            Some((input.u32()?, input.f64()?))
        } else {
            None
        };
        input.finish()?;
        let s = Self {
            id,
            team,
            owner,
            kind,
            members,
            known,
            heard,
            combat_at,
            combat,
            centroid_at,
            center,
            briefing_at,
            briefing,
            buildings_at,
            buildings,
            order,
            order_position,
            order_number,
            shown_order,
            facing,
            cover_fire_until,
            cover_fire_position,
            think_timer,
            smoked,
            build_target,
            tunnel_exit,
            fire_queue,
            bound_team,
            bound_time,
            contact_time,
            alert_time,
            leader,
            travel,
            travel_mode,
            final_slots,
            plan,
            breach_by,
            morale,
            drill,
            drill_time,
            drill_position,
            halt_destination,
            halt_face,
            halt_mode,
            move_mode,
            known_at_order,
            impacts,
            last_casualty,
            displace_cooldown,
            previous_order,
            ammo_timer,
            cooldowns,
            ambush,
            ambush_time,
            offsets,
            technique,
            overwatch_team,
            overwatch_time,
            recon_fire_time,
            then_defend,
            cleared,
            clear_house,
            clear_call,
            ambush_plan,
            halt_then,
        };
        if !s.valid() {
            return Err("invalid squad checkpoint");
        }
        Ok(s)
    }
}

fn text(input: &mut Reader<'_>) -> Result<String, &'static str> {
    std::str::from_utf8(input.bytes(128)?)
        .map(str::to_owned)
        .map_err(|_| "invalid squad text")
}
fn list<T>(
    input: &mut Reader<'_>,
    limit: usize,
    mut read: impl FnMut(&mut Reader<'_>) -> Result<T, &'static str>,
) -> Result<Vec<T>, &'static str> {
    let count = input.u32()? as usize;
    if count > limit {
        return Err("squad collection exceeds limit");
    }
    let mut out = Vec::new();
    for _ in 0..count {
        out.push(read(input)?);
    }
    Ok(out)
}
fn contacts(input: &mut Reader<'_>) -> Result<Vec<Contact>, &'static str> {
    list(input, 100_000, |r| {
        Ok(Contact {
            id: r.u32()?,
            report: Report {
                position: r.point()?,
                time: r.f64()?,
            },
        })
    })
}
fn reports(input: &mut Reader<'_>, limit: usize) -> Result<Vec<Report>, &'static str> {
    list(input, limit, |r| {
        Ok(Report {
            position: r.point()?,
            time: r.f64()?,
        })
    })
}
