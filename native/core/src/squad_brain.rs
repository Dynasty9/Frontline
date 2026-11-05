//! Battle drills use the same retained orders and random stream as individual soldiers.
use crate::actors::Actor;
use crate::attack_plan::{AttackPlan, Phase};
use crate::infantry::{Goal, Infantry};
use crate::infantry_action::Round;
use crate::infantry_commands::Command;
use crate::infantry_controller::Task;
use crate::infantry_vitals::Life;
use crate::infantry_weapon::Weapon;
use crate::squad::{Report, SavedOrder};
use crate::squad_movement::{available, flat, Context, Event as Movement};
use crate::vector::{normalized, Vector3};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Call {
    Retreat,
    Rout,
    Rally,
    Displace,
    BackToLine,
    Withdraw,
    WithdrawDone,
    NearAmbush,
    Contact,
    Ambush,
    NeedAmmo,
    GiveAmmo,
    Reload,
    Clear,
    CoverRescue,
    Straggler,
    Welcome,
    ClearDone,
    Surrender,
    AmbushSetOut,
    AmbushSpring,
    AmbushWithdraw,
}
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Message {
    Rout,
    Rally,
    Displace,
    Withdraw,
    NearAmbush,
    AmbushSprang,
}
#[derive(Clone, Debug, PartialEq)]
pub enum Event {
    Movement(Movement),
    Speech {
        soldier: u32,
        call: Call,
        variant: u8,
        target: Option<Vector3>,
    },
    Message {
        squad: u32,
        message: Message,
        position: Vector3,
    },
    Stat(&'static str),
    Joined {
        from: u32,
        to: u32,
        soldier: u32,
        position: Vector3,
    },
    Surrendered {
        soldier: u32,
        team: i8,
        position: Vector3,
        drop_direction: Vector3,
    },
}
pub struct Profile<'a> {
    pub plans: &'a [AttackPlan],
    pub impacts: &'a [Report],
    pub armor: &'a dyn Fn(&str) -> i32,
    pub weapon: &'a dyn Fn(&Infantry) -> Option<Weapon>,
}
fn movement(out: &mut Vec<Event>, events: Vec<Movement>) {
    out.extend(events.into_iter().map(Event::Movement));
}
impl Context<'_> {
    pub(crate) fn squad_enemy_direction(&mut self, i: usize) -> Vector3 {
        let q = &mut self.squads[i];
        let c = q.centroid(self.now, self.actors);
        let mut direction = Vector3::ZERO;
        for p in q.threat_points(c, 3, self.now, self.actors) {
            direction += normalized(flat(p - c));
        }
        if direction.length() < 0.1 {
            q.facing
        } else {
            normalized(direction)
        }
    }
    fn near_fob(&mut self, i: usize, radius: f32) -> bool {
        let q = &mut self.squads[i];
        let c = q.centroid(self.now, self.actors);
        self.actors
            .nearest_fob(q.team, c)
            .is_some_and(|f| flat(f.position - c).length() < radius)
    }
    pub(crate) fn squad_suppression(&self, i: usize) -> f64 {
        let mut sum = 0.0;
        let mut n = 0;
        for s in self.squads[i].alive(self.actors) {
            sum += s.vitals.suppression;
            n += 1;
        }
        if n == 0 {
            0.0
        } else {
            sum / n as f64
        }
    }
    pub(crate) fn brain_say(
        &mut self,
        id: u32,
        call: Call,
        variant: u8,
        force: bool,
        target: Option<Vector3>,
        out: &mut Vec<Event>,
    ) {
        let s = self.actors.soldier_mut(id).unwrap();
        if force || s.vitals.speech_cooldown <= 0.0 {
            s.vitals.speech_cooldown = 2.6;
            out.push(Event::Speech {
                soldier: id,
                call,
                variant,
                target,
            });
        }
    }
    pub(crate) fn brain_call(
        &mut self,
        i: usize,
        call: Call,
        count: u32,
        target: Option<Vector3>,
        out: &mut Vec<Event>,
    ) {
        let mut events = vec![];
        let mut id = self.leader(i, &mut events);
        movement(out, events);
        if id == 0 {
            id = self.squads[i]
                .alive(self.actors)
                .next()
                .map_or(0, |s| s.identity.id);
        }
        if id != 0 {
            let variant = (self.rng.randi() % count) as u8;
            self.brain_say(id, call, variant, true, target, out);
        }
    }
    fn brain_message(&self, i: usize, message: Message, position: Vector3, out: &mut Vec<Event>) {
        out.push(Event::Message {
            squad: self.squads[i].id,
            message,
            position,
        });
    }
    pub fn squad_morale_tick(
        &mut self,
        id: u32,
        dt: f64,
        profile: &Profile<'_>,
    ) -> Result<(), &'static str> {
        let i = self.index(id)?;
        if !dt.is_finite() || !(0.0..=10.0).contains(&dt) {
            return Err("invalid squad morale step");
        }
        let alive = self.squads[i].alive(self.actors).count();
        if alive == 0 {
            return Ok(());
        }
        let supp = self.squad_suppression(i);
        let dug = self.squads[i]
            .alive(self.actors)
            .filter(|s| s.motion.ground < -0.6 || s.cover.at_cover && s.cover.material >= 2)
            .count();
        let can_fight_armor = self.squads[i].alive(self.actors).any(|s| {
            s.arsenal.rockets > 0 || matches!(s.identity.unit.as_str(), "at_soldier" | "rpg")
        });
        let q = &mut self.squads[i];
        let center = q.centroid(self.now, self.actors);
        let contact = q.in_combat(self.now);
        let team = q.team;
        let led = self
            .actors
            .soldier(q.leader)
            .is_some_and(|s| !s.identity.gone && s.vitals.life == Life::Alive);
        let mut drain = if supp > 30.0 {
            (supp - 30.0) / 70.0 * 1.4
        } else {
            0.0
        };
        if !can_fight_armor
            && self
                .actors
                .units_near(self.units, center, 70.0, team)?
                .into_iter()
                .any(|id| {
                    self.actors.vehicle(id).is_some_and(|v| {
                        (profile.armor)(&v.kind) >= 1 && v.visible & (1 << team) != 0
                    })
                })
        {
            drain += 0.9;
        }
        if !led {
            drain += 0.2;
        }
        if dug * 2 >= alive {
            drain *= 0.5;
        } else if profile
            .plans
            .iter()
            .any(|p| p.id == q.plan && p.support_set)
        {
            drain *= 0.7;
        }
        let mut friends = 0;
        for (other, q) in self.squads.iter_mut().enumerate() {
            if other != i
                && q.team == team
                && q.drill != "rout"
                && q.alive(self.actors).next().is_some()
                && flat(q.centroid(self.now, self.actors) - center).length() < 45.0
            {
                friends += 1;
            }
        }
        for id in self.actors.units_near(self.units, center, 45.0, -1)? {
            if self
                .actors
                .vehicle(id)
                .is_some_and(|v| v.team == team && (profile.armor)(&v.kind) >= 1)
            {
                friends += 1;
            }
        }
        if friends == 0 && contact {
            drain += 0.15;
        }
        let mut recovery = if !contact {
            1.4 + if self.near_fob(i, 45.0) { 0.8 } else { 0.0 }
        } else if supp < 15.0 {
            0.35
        } else {
            0.0
        };
        if led {
            recovery *= 1.25;
        }
        recovery += 0.2 * friends.min(3) as f64;
        let q = &mut self.squads[i];
        let base = if team == 0 { 78.0 } else { 72.0 };
        let mut morale = q.morale - drain * dt;
        if morale < base {
            morale = base.min(morale + recovery * dt);
        } else if !contact {
            morale = base.max(morale - 0.15 * dt);
        }
        q.morale = morale.clamp(0.0, 100.0);
        Ok(())
    }
    pub fn squad_retreat(&mut self, id: u32) -> Result<Vec<Event>, &'static str> {
        let i = self.index(id)?;
        let q = &mut self.squads[i];
        let c = q.centroid(self.now, self.actors);
        let Some(f) = self.actors.nearest_fob(q.team, c) else {
            return Ok(vec![]);
        };
        let position = f.position;
        let mut events = vec![];
        self.regroup(i, &mut events);
        let mut out = events.into_iter().map(Event::Movement).collect::<Vec<_>>();
        let q = &mut self.squads[i];
        q.order = "move".into();
        q.shown_order = "retreat".into();
        q.order_position = position;
        q.facing = normalized(flat(q.centroid(self.now, self.actors) - position));
        let members = q.members.clone();
        for (n, &id) in members.iter().enumerate() {
            let angle = n as f64 * 1.3;
            let offset = Vector3::new(libm::cos(angle) as f32, 0.0, libm::sin(angle) as f32) * 4.0;
            let position = self
                .geometry
                .navigation
                .planner
                .nearest_walkable(
                    position + offset,
                    crate::traversal::Ground::new(&self.geometry.terrain, &self.geometry.deck),
                )
                .unwrap();
            self.command(id, Command::Retreat { position })?;
        }
        if let Some(&id) = members.first() {
            self.brain_say(id, Call::Retreat, 0, true, None, &mut out);
        }
        Ok(out)
    }
    fn shells_on_squad(&mut self, i: usize, profile: &Profile<'_>) -> bool {
        let q = &mut self.squads[i];
        if matches!(q.drill.as_str(), "rout" | "withdraw" | "displace")
            || self.now < q.displace_cooldown
            || profile
                .plans
                .iter()
                .any(|p| p.id == q.plan && p.phase == Phase::Assault)
        {
            return false;
        }
        let center = q.centroid(self.now, self.actors);
        q.impacts.retain(|r| self.now - r.time < 20.0);
        if q.impacts
            .iter()
            .filter(|r| flat(r.position - center).length() < 32.0)
            .count()
            < 2
        {
            return false;
        }
        let alive = q.alive(self.actors).count();
        alive > 0
            && q.alive(self.actors)
                .filter(|s| s.motion.ground < -0.6)
                .count()
                * 2
                < alive
    }
    fn squad_displace(&mut self, i: usize, out: &mut Vec<Event>) -> Result<bool, &'static str> {
        let q = &mut self.squads[i];
        let c = q.centroid(self.now, self.actors);
        let mut impact = Vector3::ZERO;
        for r in &q.impacts {
            impact += r.position;
        }
        impact /= q.impacts.len().max(1) as f32;
        let ed = self.squad_enemy_direction(i);
        let mut best = None;
        let mut score = -1e9;
        for k in 0..12 {
            let angle = std::f64::consts::TAU * k as f64 / 12.0;
            let direction = Vector3::new(libm::sin(angle) as f32, 0.0, libm::cos(angle) as f32);
            let p = self
                .geometry
                .navigation
                .planner
                .nearest_walkable(
                    c + direction * 55.0,
                    crate::traversal::Ground::new(&self.geometry.terrain, &self.geometry.deck),
                )
                .unwrap();
            let limit = self.geometry.terrain.half() - 10.0;
            if f64::from(p.x.abs()) >= limit || f64::from(p.z.abs()) >= limit {
                continue;
            }
            let value = f64::from(flat(p - impact).length())
                - f64::from(direction.dot(ed)).max(0.0) * 45.0
                + (self.geometry.terrain.cover(p) + 1) as f64 * 4.0;
            if value > score {
                score = value;
                best = Some(p);
            }
        }
        let Some(best) = best else {
            return Ok(false);
        };
        let q = &mut self.squads[i];
        q.previous_order = Some(SavedOrder {
            order: q.order.clone(),
            position: q.order_position,
            facing: q.facing,
            mode: q.move_mode,
        });
        let id = q.id;
        movement(out, self.order_move(id, best, ed, 2, true)?);
        let q = &mut self.squads[i];
        q.drill = "displace".into();
        q.drill_time = self.now;
        q.drill_position = best;
        q.displace_cooldown = self.now + 45.0;
        q.shown_order = "displace".into();
        self.brain_call(i, Call::Displace, 4, None, out);
        self.brain_message(i, Message::Displace, best, out);
        out.push(Event::Stat("displace"));
        Ok(true)
    }
    fn squad_displace_tick(
        &mut self,
        i: usize,
        profile: &Profile<'_>,
        out: &mut Vec<Event>,
    ) -> Result<(), &'static str> {
        let q = &mut self.squads[i];
        let elapsed = self.now - q.drill_time;
        if elapsed < 12.0 || elapsed < 40.0 && q.alive(self.actors).any(|s| s.is_moving()) {
            return Ok(());
        }
        q.drill.clear();
        let pre = q.previous_order.clone();
        let hot = pre.as_ref().is_some_and(|o| {
            profile
                .impacts
                .iter()
                .any(|r| self.now - r.time < 15.0 && flat(r.position - o.position).length() < 35.0)
        });
        let id = q.id;
        match pre {
            Some(o) if o.order == "move" && !hot => movement(
                out,
                self.order_move(id, o.position, o.facing, o.mode, true)?,
            ),
            Some(o) if o.order == "assault" => {
                movement(out, self.order_assault_bounds(id, o.position, o.facing)?)
            }
            Some(o) if o.order == "defend" && !hot => {
                movement(out, self.order_defend(id, o.position, o.facing, false)?);
                self.brain_call(i, Call::BackToLine, 2, None, out);
            }
            _ => {
                let at = self.squads[i].drill_position;
                let ed = self.squad_enemy_direction(i);
                movement(out, self.order_defend(id, at, ed, false)?);
            }
        }
        Ok(())
    }
    fn squad_should_break(&mut self, i: usize) -> bool {
        let q = &mut self.squads[i];
        if matches!(q.drill.as_str(), "rout" | "withdraw")
            || q.shown_order == "retreat"
            || !q.in_combat(self.now)
        {
            return false;
        }
        let alive = q.alive(self.actors).count();
        if alive == 0 || q.plan != 0 && q.morale >= 22.0 {
            return false;
        }
        if q.order == "defend" && self.near_fob(i, 40.0) {
            return false;
        }
        let q = &mut self.squads[i];
        if q.alive(self.actors).any(|s| s.emplacement.structure != 0) {
            return q.morale < 18.0;
        }
        if q.morale < 33.0 {
            return true;
        }
        if q.owner >= 0 || q.members.len() < 4 || q.order == "defend" {
            return false;
        }
        let c = q.centroid(self.now, self.actors);
        alive * 2 <= q.members.len()
            && q.known
                .iter()
                .filter(|k| {
                    self.now - k.report.time < 12.0
                        && flat(k.report.position - c).length() < 110.0
                        && self
                            .actors
                            .soldier(k.id)
                            .is_some_and(|s| !s.identity.gone && s.vitals.life == Life::Alive)
                })
                .count()
                >= alive * 2
    }
    pub(crate) fn squad_start_withdraw(
        &mut self,
        i: usize,
        out: &mut Vec<Event>,
    ) -> Result<(), &'static str> {
        let c = self.squads[i].centroid(self.now, self.actors);
        let ed = self.squad_enemy_direction(i);
        let mut rally = c - ed * 75.0;
        if let Some(f) = self.actors.nearest_fob(self.squads[i].team, c) {
            if flat(f.position - c).length() < 220.0
                && normalized(flat(f.position - c)).dot(-ed) > 0.2
            {
                rally = f.position + ed * 12.0;
            }
        }
        rally = self
            .geometry
            .navigation
            .planner
            .nearest_walkable(
                rally,
                crate::traversal::Ground::new(&self.geometry.terrain, &self.geometry.deck),
            )
            .unwrap();
        let mut events = vec![];
        self.regroup(i, &mut events);
        movement(out, events);
        let q = &mut self.squads[i];
        q.order = "withdraw".into();
        q.order_position = rally;
        q.facing = ed;
        q.shown_order = "retreat".into();
        q.drill = "withdraw".into();
        q.drill_time = self.now;
        q.bound_team = 0;
        q.bound_time = 0.0;
        self.squad_smoke_screen(i, ed)?;
        self.cover_squad(i, c, 150.0, 6.0);
        self.brain_call(i, Call::Withdraw, 3, None, out);
        self.brain_message(i, Message::Withdraw, c, out);
        out.push(Event::Stat("break_contact"));
        Ok(())
    }
    pub(crate) fn squad_smoke_screen(&mut self, i: usize, ed: Vector3) -> Result<(), &'static str> {
        let c = self.squads[i].centroid(self.now, self.actors);
        let mut best = None;
        let mut distance = 1e9;
        for m in self.squads[i].alive(self.actors) {
            if m.fight.smokes <= 0 || !available(m) || m.duty.kind != Task::Fight {
                continue;
            }
            let d = -f64::from(flat(m.motion.position - c).dot(ed));
            if d < distance {
                distance = d;
                best = Some((m.identity.id, m.motion.position));
            }
        }
        if let Some((id, at)) = best {
            self.command(
                id,
                Command::Throw {
                    position: at + ed * 14.0,
                    round: Round::Smoke,
                },
            )?;
        }
        Ok(())
    }
    fn cover_squad(&mut self, i: usize, c: Vector3, radius: f64, duration: f64) -> Option<Vector3> {
        let q = &mut self.squads[i];
        let target = q
            .last_known_near(self.actors, c, radius, 10.0, self.now)
            .map(|k| k.report.position);
        if let Some(p) = target {
            q.cover_fire_position = p;
            q.cover_fire_until = self.now + duration;
        }
        target
    }
    fn squad_withdraw_tick(&mut self, i: usize, out: &mut Vec<Event>) -> Result<(), &'static str> {
        if self.squads[i].alive(self.actors).next().is_none() {
            return Ok(());
        }
        let c = self.squads[i].centroid(self.now, self.actors);
        let ed = self.squad_enemy_direction(i);
        let q = &mut self.squads[i];
        q.facing = ed;
        let there = flat(q.order_position - c).length() < 8.0;
        let elapsed = self.now - q.drill_time;
        if there || elapsed > 25.0 && !q.in_combat(self.now) || elapsed > 120.0 {
            q.drill.clear();
            let id = q.id;
            let at = if there {
                q.order_position
            } else {
                self.geometry
                    .navigation
                    .planner
                    .nearest_walkable(
                        c,
                        crate::traversal::Ground::new(&self.geometry.terrain, &self.geometry.deck),
                    )
                    .unwrap()
            };
            movement(out, self.order_defend(id, at, ed, false)?);
            self.brain_call(i, Call::WithdrawDone, 3, None, out);
            out.push(Event::Stat("withdraw_done"));
            return Ok(());
        }
        if self.now < q.bound_time
            && q.alive(self.actors)
                .any(|s| !s.orders.detached && s.orders.purpose == Goal::Slot && s.is_moving())
        {
            return Ok(());
        }
        self.cover_squad(i, c, 150.0, 6.0);
        let mut events = vec![];
        self.next_assault_bound(i, 20.0, &mut events)?;
        movement(out, events);
        Ok(())
    }
    fn squad_contact_on_move(&mut self, i: usize) -> bool {
        let q = &mut self.squads[i];
        if q.order != "move"
            || !q.drill.is_empty()
            || q.plan != 0
            || !q.shown_order.is_empty()
            || q.move_mode >= 2
        {
            return false;
        }
        let c = q.centroid(self.now, self.actors);
        if flat(q.order_position - c).length() < 15.0
            || q.alive(self.actors).next().is_none()
            || q.members.iter().any(|&id| {
                self.actors
                    .soldier(id)
                    .is_some_and(|s| s.links.vehicle != 0)
            })
        {
            return false;
        }
        if self.squad_suppression(i) > 28.0 {
            return true;
        }
        let q = &self.squads[i];
        q.known.iter().any(|k| {
            !q.known_at_order.iter().any(|old| old.id == k.id)
                && self.now - k.report.time <= 2.0
                && self.actors.get(k.id).is_some_and(
                    |a| !matches!(a, Actor::Soldier(s) if s.vitals.life != Life::Alive),
                )
                && flat(k.report.position - c).length() < 220.0
        })
    }
    fn squad_react_contact(&mut self, i: usize, out: &mut Vec<Event>) -> Result<(), &'static str> {
        let c = self.squads[i].centroid(self.now, self.actors);
        let ed = self.squad_enemy_direction(i);
        let q = &mut self.squads[i];
        q.halt_then = q.then_defend;
        let near = q
            .last_known_near(self.actors, c, 40.0, 10.0, self.now)
            .map(|k| k.report.position);
        let alive = q.alive(self.actors).count();
        if let Some(at) = near.filter(|at| {
            q.morale >= 55.0
                && !matches!(q.kind.as_str(), "crew" | "r_crew")
                && alive >= 3
                && flat(*at - c).length() <= 32.0
                && q.known
                    .iter()
                    .filter(|k| {
                        self.now - k.report.time < 4.0
                            && flat(k.report.position - c).length() < 60.0
                    })
                    .count()
                    <= alive
        }) {
            let id = q.id;
            let count = if q.team == 0 { 3 } else { 2 };
            let at = self
                .geometry
                .navigation
                .planner
                .nearest_walkable(
                    at,
                    crate::traversal::Ground::new(&self.geometry.terrain, &self.geometry.deck),
                )
                .unwrap();
            // Facing uses the observed threat, before the destination snaps to the grid.
            let face = normalized(flat(near.unwrap() - c));
            movement(out, self.order_assault_bounds(id, at, face)?);
            self.brain_call(i, Call::NearAmbush, count, None, out);
            self.brain_message(i, Message::NearAmbush, c, out);
            out.push(Event::Stat("near_ambush_assault"));
            return Ok(());
        }
        q.technique.clear();
        q.halt_destination = q.order_position;
        q.halt_face = q.facing;
        q.halt_mode = q.move_mode;
        q.travel = false;
        q.order = "hold".into();
        q.shown_order = "contact".into();
        q.drill = "contact".into();
        q.drill_time = self.now;
        let members = q.members.clone();
        for id in members {
            if self
                .actors
                .soldier(id)
                .is_some_and(|s| available(s) && !s.orders.detached && s.duty.kind == Task::Fight)
            {
                self.command(id, Command::Halt { face: ed })?;
            }
        }
        let target = self.cover_squad(i, c, 250.0, 8.0).unwrap_or(c + ed * 100.0);
        self.brain_call(i, Call::Contact, 3, Some(target), out);
        out.push(Event::Stat("react_to_contact"));
        Ok(())
    }
    fn squad_can_resume(&self, i: usize) -> bool {
        let q = &self.squads[i];
        if q.drill != "contact"
            || self.now - q.drill_time < 8.0
            || q.alive(self.actors).next().is_none()
            || self.squad_suppression(i) > 18.0
        {
            return false;
        }
        !q.known.iter().any(|k| {
            self.now - k.report.time < 6.0
                && self.actors.get(k.id).is_some_and(
                    |a| !matches!(a, Actor::Soldier(s) if s.vitals.life != Life::Alive),
                )
        }) || self.now - q.drill_time > 25.0
    }
    /// Returns whether any branch of the priority tree handled the decision.
    pub fn squad_think(
        &mut self,
        id: u32,
        profile: &Profile<'_>,
    ) -> Result<(bool, Vec<Event>), &'static str> {
        let i = self.index(id)?;
        let mut out = vec![];
        let q = &mut self.squads[i];
        if q.drill == "rout" {
            if q.morale > 45.0
                || q.morale > 30.0 && !q.in_combat(self.now) && self.near_fob(i, 40.0)
            {
                self.squads[i].drill.clear();
                let c = self.squads[i].centroid(self.now, self.actors);
                let at = self
                    .geometry
                    .navigation
                    .planner
                    .nearest_walkable(
                        c,
                        crate::traversal::Ground::new(&self.geometry.terrain, &self.geometry.deck),
                    )
                    .unwrap();
                let ed = self.squad_enemy_direction(i);
                movement(&mut out, self.order_defend(id, at, ed, false)?);
                self.brain_call(i, Call::Rally, 3, None, &mut out);
                self.brain_message(i, Message::Rally, c, &mut out);
                out.push(Event::Stat("squad_rally"));
            }
            return Ok((true, out));
        }
        if q.morale < 12.0
            && q.alive(self.actors).next().is_some()
            && (q.in_combat(self.now) || self.now - q.last_casualty < 20.0)
        {
            out.extend(self.squad_retreat(id)?);
            if self.squads[i].order != "move" {
                let c = self.squads[i].centroid(self.now, self.actors);
                let ed = self.squad_enemy_direction(i);
                let at = self
                    .geometry
                    .navigation
                    .planner
                    .nearest_walkable(
                        c - ed * 90.0,
                        crate::traversal::Ground::new(&self.geometry.terrain, &self.geometry.deck),
                    )
                    .unwrap();
                movement(&mut out, self.order_move(id, at, -ed, 2, true)?);
            }
            let q = &mut self.squads[i];
            q.drill = "rout".into();
            q.drill_time = self.now;
            q.shown_order = "rout".into();
            self.brain_call(i, Call::Rout, 4, None, &mut out);
            let c = self.squads[i].centroid(self.now, self.actors);
            self.brain_message(i, Message::Rout, c, &mut out);
            out.push(Event::Stat("squad_rout"));
            return Ok((true, out));
        }
        if self.shells_on_squad(i, profile) && self.squad_displace(i, &mut out)? {
            return Ok((true, out));
        }
        // Displacement deliberately falls through: medics and lower-priority drills still run.
        if self.squads[i].drill == "displace" {
            self.squad_displace_tick(i, profile, &mut out)?;
        }
        if self.squad_should_break(i) {
            self.squad_start_withdraw(i, &mut out)?;
            return Ok((true, out));
        }
        if self.squads[i].drill == "withdraw" {
            self.squad_withdraw_tick(i, &mut out)?;
            return Ok((true, out));
        }
        if self.squad_contact_on_move(i) {
            self.squad_react_contact(i, &mut out)?;
            return Ok((true, out));
        }
        if self.squad_can_resume(i) {
            let q = &mut self.squads[i];
            let dest = q.halt_destination;
            let face = q.halt_face;
            let mode = q.halt_mode;
            q.drill.clear();
            let c = q.centroid(self.now, self.actors);
            if q.last_known_near(self.actors, c, 160.0, 10.0, self.now)
                .is_some()
            {
                movement(&mut out, self.order_assault_bounds(id, dest, face)?);
            } else {
                movement(&mut out, self.order_move(id, dest, face, mode, true)?);
                self.squads[i].then_defend = self.squads[i].halt_then;
            }
            out.push(Event::Stat("contact_resume"));
            return Ok((true, out));
        }
        let handled = self.squad_clear_house(i, &mut out)?;
        Ok((handled, out))
    }
    fn squad_clear_house(&mut self, i: usize, out: &mut Vec<Event>) -> Result<bool, &'static str> {
        use crate::infantry_decision::{building, Decision};
        use crate::squad_movement::set_cooldown;
        let q = &mut self.squads[i];
        if q.order != "defend"
            || !q.drill.is_empty()
            || q.plan != 0
            || q.ambush_plan != 0
            || matches!(q.kind.as_str(), "crew" | "r_crew")
            || self.now
                < q.cooldowns
                    .iter()
                    .find(|v| v.0 == "clear")
                    .map_or(-1.0, |v| v.1)
        {
            return Ok(false);
        }
        set_cooldown(q, "clear", self.now + 2.0)?;
        if self
            .actors
            .soldier(q.breach_by)
            .is_some_and(|s| s.vitals.life == Life::Alive && s.duty.kind == Task::Breach)
        {
            return Ok(false);
        }
        if q.alive(self.actors).count() < 2 || self.squad_suppression(i) > 25.0 {
            return Ok(false);
        }
        let q = &self.squads[i];
        if self.now - q.alert_time > 150.0 {
            let mut enemy = false;
            for id in self
                .actors
                .units_near(self.units, q.order_position, 150.0, q.team)?
            {
                enemy |= match self.actors.get(id).unwrap() {
                    Actor::Soldier(s) => {
                        s.vitals.life == Life::Alive && s.identity.visible & (1 << q.team) != 0
                    }
                    Actor::Vehicle(v) => v.visible & (1 << q.team) != 0,
                    _ => false,
                };
            }
            if !enemy {
                return Ok(false);
            }
        }
        let houses = self.actors.structures_near(
            &self.geometry.structures,
            q.order_position,
            22.0,
            false,
        )?;
        for house in houses {
            let h = self.actors.structure(house).unwrap();
            let q = &self.squads[i];
            if h.kind != "floor"
                || flat(h.position - q.order_position).length() > 18.0
                || self.now
                    - q.cleared
                        .iter()
                        .find(|v| v.0 == house)
                        .map_or(-1e9, |v| v.1)
                    < 600.0
            {
                continue;
            }
            let mut occupied = false;
            for id in self.actors.units_near(
                self.units,
                h.position,
                f64::from(h.size.x.max(h.size.z)) * 0.6 + 1.0,
                -1,
            )? {
                if let Some(s) = self.actors.soldier(id) {
                    if s.identity.team == q.team
                        && s.vitals.life == Life::Alive
                        && self
                            .actors
                            .infantry_house_at(s.motion.position, &self.geometry.structures)?
                            == Some(house)
                    {
                        occupied = true;
                        break;
                    }
                }
            }
            if occupied {
                self.mark_house_cleared(i, house);
                continue;
            }
            let walls = self
                .actors
                .structures_near(
                    &self.geometry.structures,
                    h.position,
                    f64::from(h.size.x.max(h.size.z)) * 0.5 + 1.5,
                    false,
                )?
                .into_iter()
                .filter_map(|id| self.actors.structure(id))
                .map(building)
                .collect::<Vec<_>>();
            let center = self.squads[i].centroid(self.now, self.actors);
            let mut door = None;
            let mut distance = 1e9;
            for o in crate::breach_selection::openings(building(h), &walls)? {
                if o.door {
                    let d = f64::from(flat(o.center - center).length());
                    if d < distance {
                        distance = d;
                        door = Some(o);
                    }
                }
            }
            let Some(door) = door else {
                continue;
            };
            let candidates = self.squads[i]
                .alive(self.actors)
                .filter(|s| {
                    available(s)
                        && s.duty.kind == Task::Fight
                        && !s.orders.detached
                        && s.emplacement.structure == 0
                        && (self.man)(s).weapon_range.is_some()
                        && !matches!(
                            s.identity.unit.as_str(),
                            "mg_gunner"
                                | "pkm"
                                | "medic"
                                | "r_medic"
                                | "mortar_gunner"
                                | "r_mortar"
                                | "fpv_op"
                        )
                })
                .map(|s| {
                    (
                        s.identity.id,
                        f64::from(flat(s.motion.position - door.center).length()),
                    )
                })
                .collect::<Vec<_>>();
            if candidates.is_empty() {
                return Ok(false);
            }
            let order =
                crate::godot_sort::score_order(&candidates.iter().map(|v| v.1).collect::<Vec<_>>());
            let id = candidates[order[0]].0;
            let buddy = order.get(1).map_or(0, |&j| candidates[j].0);
            self.squads[i].clear_house = Some(crate::squad::ClearHouse {
                house,
                opening: door,
                soldier: id,
                buddy,
            });
            self.mark_house_cleared(i, house);
            self.actors.soldier_mut(id).unwrap().entry.selected =
                Some(crate::infantry::BreachChoice {
                    house: house.into(),
                    opening: door,
                    enemy: 0,
                });
            let mut decision = Decision::default();
            self.actors.begin_infantry_breach(
                id,
                self.now,
                &mut self.squads[i],
                &self.geometry.navigation.planner,
                true,
                self.rng,
                &mut decision,
                crate::traversal::Ground::new(&self.geometry.terrain, &self.geometry.deck),
            )?;
            if let Some(route) = decision.route {
                self.geometry.navigation.submit_infantry(
                    self.actors.soldier_mut(id).unwrap(),
                    route,
                    self.now,
                    self.rng,
                    crate::traversal::Ground::new(&self.geometry.terrain, &self.geometry.deck),
                )?;
            }
            let cue = (self.rng.randi() % 4) as u8;
            self.brain_say(id, Call::Clear, cue, true, None, out);
            if buddy != id
                && self
                    .actors
                    .soldier(buddy)
                    .is_some_and(|s| available(s) && s.duty.kind == Task::Fight)
            {
                let at = self.actors.soldier(id).unwrap().duty.position;
                let along = Vector3::new(door.normal.z, 0.0, -door.normal.x);
                let side = if (at - door.center).dot(along) >= 0.0 {
                    1.0
                } else {
                    -1.0
                };
                let slot = self
                    .geometry
                    .navigation
                    .planner
                    .nearest_walkable(
                        at + along * (side * 0.9) + door.normal * 0.3,
                        crate::traversal::Ground::new(&self.geometry.terrain, &self.geometry.deck),
                    )
                    .unwrap();
                let s = self.actors.soldier_mut(buddy).unwrap();
                s.orders.hold_position = slot;
                s.orders.hold_face = -door.normal;
                s.orders.leash = 2.0;
                s.cover.at_cover = false;
                let route = s.go_to(slot, Goal::Slot, 1)?;
                self.geometry.navigation.submit_infantry(
                    s,
                    route,
                    self.now,
                    self.rng,
                    crate::traversal::Ground::new(&self.geometry.terrain, &self.geometry.deck),
                )?;
            }
            out.push(Event::Stat("clear_house"));
            return Ok(true);
        }
        Ok(false)
    }
    fn mark_house_cleared(&mut self, i: usize, house: u32) {
        if let Some(v) = self.squads[i].cleared.iter_mut().find(|v| v.0 == house) {
            v.1 = self.now;
        } else {
            self.squads[i].cleared.push((house, self.now));
        }
    }
    pub fn squad_ambush_tick(&mut self, id: u32) -> Result<Vec<Event>, &'static str> {
        let i = self.index(id)?;
        let mut out = vec![];
        if !self.squads[i].ambush {
            return Ok(out);
        }
        if self.squads[i].alive(self.actors).next().is_none() {
            self.squads[i].ambush = false;
            return Ok(out);
        }
        let mut spring =
            self.squad_suppression(i) > 8.0 || self.now - self.squads[i].last_casualty < 3.0;
        let mut close = 999.0f32;
        let mut seen = 0;
        for m in self.squads[i].alive(self.actors) {
            let target = m.fight.target as u32;
            if self.actors.infantry_target_valid(target) {
                let a = self.actors.get(target).unwrap();
                if !matches!(a, Actor::Structure(_)) {
                    seen += 1;
                    close = close.min(flat(a.position() - m.motion.position).length());
                }
            }
            if m.fight.forced_target != 0 {
                spring = true;
            }
        }
        spring |= close < 38.0 || seen >= 3 && f64::from(close) < 38.0 * 1.4;
        if spring {
            self.squads[i].ambush = false;
            if seen > 0 {
                self.squads[i].ambush_time = self.now + 4.0;
                self.brain_call(
                    i,
                    Call::Ambush,
                    if self.squads[i].team == 0 { 4 } else { 3 },
                    None,
                    &mut out,
                );
                out.push(Event::Stat("ambush"));
            }
        }
        Ok(out)
    }
    pub fn squad_share_ammo(
        &mut self,
        id: u32,
        profile: &Profile<'_>,
    ) -> Result<Vec<Event>, &'static str> {
        let i = self.index(id)?;
        let mut out = vec![];
        if self.now < self.squads[i].ammo_timer {
            return Ok(out);
        }
        let members = self.squads[i]
            .alive(self.actors)
            .map(|s| s.identity.id)
            .collect::<Vec<_>>();
        let weapons = members
            .iter()
            .map(|&id| (profile.weapon)(self.actors.soldier(id).unwrap()))
            .collect::<Vec<_>>();
        if weapons.iter().any(|w| w.is_some_and(|w| !w.valid())) {
            return Err("invalid squad ammunition profile");
        }
        self.squads[i].ammo_timer = self.now + 5.0;
        for (&id, &w) in members.iter().zip(&weapons) {
            let Some(w) = w else {
                continue;
            };
            let m = self.actors.soldier(id).unwrap();
            if w.ammunition >= 9000
                || m.duty.kind != Task::Fight
                || m.vitals.suppression > 70.0
                || f64::from(m.weapon.magazine + m.weapon.reserve) > f64::from(w.ammunition) * 0.3
            {
                continue;
            }
            let at = m.motion.position;
            for (&donor, &dw) in members.iter().zip(&weapons) {
                let Some(dw) = dw else {
                    continue;
                };
                let d = self.actors.soldier(donor).unwrap();
                if donor == id
                    || dw.ammunition >= 9000
                    || d.duty.kind != Task::Fight
                    || f64::from(d.weapon.magazine + d.weapon.reserve)
                        < f64::from(dw.ammunition) * 0.6
                    || d.weapon.reserve < (f64::from(dw.ammunition) * 0.2) as i32
                    || flat(d.motion.position - at).length() > 9.0
                {
                    continue;
                }
                self.actors.soldier_mut(donor).unwrap().weapon.reserve -=
                    (f64::from(dw.ammunition) * 0.15) as i32;
                let m = self.actors.soldier_mut(id).unwrap();
                m.weapon.reserve += (f64::from(w.ammunition) * 0.15) as i32;
                m.fight.out_of_ammo_said = false;
                m.weapon.low_ammo_said = false;
                let cue = (self.rng.randi() % 3) as u8;
                self.brain_say(id, Call::NeedAmmo, cue, false, None, &mut out);
                let cue = (self.rng.randi() % 3) as u8;
                self.brain_say(donor, Call::GiveAmmo, cue, false, None, &mut out);
                out.push(Event::Stat("ammo_shared"));
                if self.actors.soldier(id).unwrap().weapon.magazine <= 0 {
                    if let Some(cue) = self
                        .actors
                        .soldier_mut(id)
                        .unwrap()
                        .weapon
                        .reload(w, self.rng)
                    {
                        self.brain_say(id, Call::Reload, cue, false, None, &mut out);
                    }
                }
                break;
            }
        }
        Ok(out)
    }
}
