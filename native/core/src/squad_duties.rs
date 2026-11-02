//! Squads assign care and construction against the same claims their soldiers update.
use crate::actors::Actor;
use crate::cover::{rotation, transform};
use crate::infantry::{Goal, Infantry};
use crate::infantry_action::Round;
use crate::infantry_commands::Command;
use crate::infantry_controller::Task;
use crate::infantry_pose::Posture;
use crate::infantry_vitals::Life;
use crate::squad_brain::{Call, Event};
use crate::squad_movement::{available, flat, set_cooldown, Context};
use crate::vector::{normalized, Vector3};

#[derive(Clone, Copy, Default)]
pub struct Role {
    pub medic: bool,
    pub engineer: bool,
}
impl Context<'_> {
    fn clear_squad_duty(&mut self, id: u32) {
        self.actors
            .clear_infantry_duty(id, &self.geometry.navigation.planner, self.squads)
            .unwrap();
    }
    fn duty_route(
        &mut self,
        id: u32,
        position: Vector3,
        goal: Goal,
        mode: u8,
    ) -> Result<(), &'static str> {
        let s = self.actors.soldier_mut(id).unwrap();
        let route = s.go_to(position, goal, mode)?;
        self.geometry
            .navigation
            .submit_infantry(s, route, self.now, self.rng)?;
        Ok(())
    }
    pub fn squad_rescue(
        &mut self,
        id: u32,
        role: &dyn Fn(&Infantry) -> Role,
    ) -> Result<Vec<Event>, &'static str> {
        let i = self.index(id)?;
        let mut out = vec![];
        let members = self.squads[i].members.clone();
        for patient in members {
            let Some(w) = self.actors.soldier(patient) else {
                continue;
            };
            if w.vitals.life != Life::Downed || !w.links.carried_by.is_empty() {
                continue;
            }
            let at = w.motion.position;
            if self
                .actors
                .soldier(w.links.rescue_claimed as u32)
                .is_some_and(|s| {
                    s.vitals.life == Life::Alive
                        && s.duty.kind == Task::Rescue
                        && s.duty.entity == patient.into()
                })
            {
                let q = &mut self.squads[i];
                if q.cover_fire_until < self.now + 1.0 {
                    if let Some(k) = q.last_known_near(self.actors, at, 55.0, 10.0, self.now) {
                        q.cover_fire_until = self.now + 3.0;
                        q.cover_fire_position = k.report.position;
                    }
                }
                continue;
            }
            self.actors
                .soldier_mut(patient)
                .unwrap()
                .links
                .rescue_claimed = 0;
            let mut candidates = self.squads[i]
                .alive(self.actors)
                .filter(|m| {
                    m.identity.id != patient
                        && !(self.man)(m).bearer
                        && m.vitals.suppression <= 78.0
                        && matches!(m.duty.kind, Task::Fight | Task::Escort | Task::Build)
                        && flat(m.motion.position - at).length() <= 55.0
                })
                .map(|m| m.identity.id)
                .collect::<Vec<_>>();
            if candidates.is_empty() {
                continue;
            }
            let danger = self.squads[i]
                .last_known_near(self.actors, at, 55.0, 10.0, self.now)
                .map(|k| k.report.position);
            if let Some(enemy) = danger {
                let q = &mut self.squads[i];
                let newly = q.cover_fire_until < self.now;
                q.cover_fire_until = self.now + 7.0;
                q.cover_fire_position = enemy;
                if newly {
                    let cue = (self.rng.randi() % 3) as u8;
                    self.brain_say(candidates[0], Call::CoverRescue, cue, true, None, &mut out);
                    let alive = self.squads[i]
                        .alive(self.actors)
                        .map(|s| s.identity.id)
                        .collect::<Vec<_>>();
                    for id in alive {
                        self.actors.soldier_mut(id).unwrap().cover.evaluate_at = self.now + 2.0;
                    }
                }
                if self.squads[i]
                    .smoked
                    .iter()
                    .find(|v| v.0 == patient)
                    .is_none_or(|v| self.now - v.1 > 30.0)
                {
                    let mut thrower = None;
                    let mut distance = 35.0;
                    for &id in &candidates {
                        let m = self.actors.soldier(id).unwrap();
                        let d = f64::from(flat(m.motion.position - at).length());
                        if m.fight.smokes > 0 && d < distance {
                            distance = d;
                            thrower = Some(id);
                        }
                    }
                    if let Some(id) = thrower {
                        let smoked = &mut self.squads[i].smoked;
                        if let Some(v) = smoked.iter_mut().find(|v| v.0 == patient) {
                            v.1 = self.now;
                        } else {
                            smoked.push((patient, self.now));
                        }
                        let to = flat(enemy - at);
                        let position =
                            at + normalized(to) * (5.0f64.min(f64::from(to.length()) * 0.4)) as f32;
                        self.command(
                            id,
                            Command::Throw {
                                position,
                                round: Round::Smoke,
                            },
                        )?;
                        candidates.retain(|&who| who != id);
                        if candidates.is_empty() {
                            continue;
                        }
                    }
                }
                if newly {
                    continue;
                }
            }
            let medic = candidates.iter().copied().find(|&id| {
                let m = self.actors.soldier(id).unwrap();
                role(m).medic && flat(m.motion.position - at).length() < 45.0
            });
            let rescuer = medic.unwrap_or_else(|| {
                let mut best = candidates[0];
                let mut distance = 1e9;
                for &id in &candidates {
                    let d = f64::from(
                        flat(self.actors.soldier(id).unwrap().motion.position - at).length(),
                    );
                    if d < distance {
                        distance = d;
                        best = id;
                    }
                }
                best
            });
            self.clear_squad_duty(rescuer);
            let s = self.actors.soldier_mut(rescuer).unwrap();
            s.duty.kind = Task::Rescue;
            s.duty.entity = patient.into();
            s.duty.phase = 0;
            s.posture = Posture::Stand;
            self.actors
                .soldier_mut(patient)
                .unwrap()
                .links
                .rescue_claimed = rescuer.into();
            self.duty_route(rescuer, at, Goal::Task, 2)?;
            out.push(Event::Stat("rescue"));
            if danger.is_some() {
                let position = self.actors.soldier(rescuer).unwrap().motion.position;
                let mut escort = None;
                let mut distance = 1e9;
                for id in candidates {
                    let s = self.actors.soldier(id).unwrap();
                    if id == rescuer || s.duty.kind != Task::Fight {
                        continue;
                    }
                    let d = f64::from(flat(s.motion.position - position).length());
                    if d < distance {
                        distance = d;
                        escort = Some(id);
                    }
                }
                if let Some(id) = escort {
                    self.clear_squad_duty(id);
                    let s = self.actors.soldier_mut(id).unwrap();
                    s.duty.kind = Task::Escort;
                    s.duty.entity = patient.into();
                    s.duty.partner = rescuer.into();
                    out.push(Event::Stat("escort"));
                }
            }
        }
        Ok(out)
    }
    pub fn squad_medics(
        &mut self,
        id: u32,
        role: &dyn Fn(&Infantry) -> Role,
    ) -> Result<(), &'static str> {
        let i = self.index(id)?;
        if self.squads[i].in_combat(self.now) {
            return Ok(());
        }
        let alive = self.squads[i]
            .alive(self.actors)
            .map(|s| s.identity.id)
            .collect::<Vec<_>>();
        for &id in &alive {
            let s = self.actors.soldier(id).unwrap();
            if !role(s).medic || s.duty.kind != Task::Fight {
                continue;
            }
            for &patient in &alive {
                let w = self.actors.soldier(patient).unwrap();
                if patient == id
                    || w.vitals.hp >= w.vitals.max_hp * 0.7
                    || w.duty.kind != Task::Fight
                {
                    continue;
                }
                let at = w.motion.position;
                self.clear_squad_duty(id);
                let s = self.actors.soldier_mut(id).unwrap();
                s.duty.kind = Task::Heal;
                s.duty.entity = patient.into();
                s.duty.phase = 0;
                self.duty_route(id, at, Goal::Task, 0)?;
                return Ok(());
            }
        }
        Ok(())
    }
    fn squad_work_spot(&mut self, id: u32, target: u32) -> Vector3 {
        let position = self.actors.soldier(id).unwrap().motion.position;
        let a = self.actors.get(target).unwrap();
        let radius = if let Actor::Structure(st) = a {
            if !st.cover_points.is_empty() {
                let scores = st
                    .cover_points
                    .iter()
                    .map(|p| f64::from(flat(*p - position).length()))
                    .collect::<Vec<_>>();
                let order = crate::godot_sort::score_order(&scores);
                return st.cover_points[order[self.rng.randi() as usize % order.len().min(5)]];
            }
            st.radius + 0.8
        } else {
            2.6
        };
        let at = a.position();
        let mut direction = flat(position - at);
        if direction.length() < 0.1 {
            direction = Vector3::NEG_Z;
        }
        let direction = transform(
            rotation(f64::from(self.rng.randf_range(-0.8, 0.8))),
            normalized(direction),
        );
        self.geometry
            .navigation
            .planner
            .nearest_walkable(at + direction * radius as f32)
            .unwrap()
    }
    pub fn squad_engineers(
        &mut self,
        id: u32,
        role: &dyn Fn(&Infantry) -> Role,
    ) -> Result<(), &'static str> {
        let i = self.index(id)?;
        let q = &mut self.squads[i];
        if q.in_combat(self.now) {
            let center = q.centroid(self.now, self.actors);
            if q.last_known_near(self.actors, center, 30.0, 10.0, self.now)
                .is_some()
            {
                return Ok(());
            }
        }
        let members = q
            .alive(self.actors)
            .map(|s| s.identity.id)
            .collect::<Vec<_>>();
        for id in members {
            let m = self.actors.soldier(id).unwrap();
            if m.duty.kind != Task::Fight || m.is_moving() {
                continue;
            }
            let engineer = role(m).engineer;
            if !engineer && self.squads[i].order != "build" {
                continue;
            }
            let mut distance = if engineer { 60.0 } else { 18.0 };
            let position = m.motion.position;
            let team = self.squads[i].team;
            let mut best = None;
            for id in
                self.actors
                    .structures_near(&self.geometry.structures, position, distance, false)?
            {
                let st = self.actors.structure(id).unwrap();
                if st.team != team || !st.needs_work() || st.kind == "depot" {
                    continue;
                }
                let d = f64::from(flat(st.position - position).length());
                if d < distance {
                    distance = d;
                    best = Some(id);
                }
            }
            if best.is_none() && engineer {
                best = self
                    .actors
                    .units_near(self.units, position, 25.0, -1)?
                    .into_iter()
                    .find(|&id| {
                        self.actors
                            .vehicle(id)
                            .is_some_and(|v| v.team == team && v.needs_repair())
                    });
            }
            if let Some(target) = best {
                self.clear_squad_duty(id);
                {
                    let s = self.actors.soldier_mut(id).unwrap();
                    s.duty.kind = Task::Build;
                    s.duty.entity = target.into();
                    s.duty.phase = 0;
                }
                let at = self.squad_work_spot(id, target);
                self.actors.soldier_mut(id).unwrap().duty.position = at;
                self.duty_route(id, at, Goal::Task, 1)?;
            }
        }
        Ok(())
    }
    pub fn squad_surrender(&mut self, id: u32) -> Result<Vec<Event>, &'static str> {
        let i = self.index(id)?;
        let q = &self.squads[i];
        let mut out = vec![];
        if q.members.len() < 2 || q.alive(self.actors).count() != 1 {
            return Ok(out);
        }
        let s = q.alive(self.actors).next().unwrap();
        if s.duty.kind != Task::Fight || s.vitals.suppression < 45.0 || (self.man)(s).bearer {
            return Ok(out);
        }
        let id = s.identity.id;
        let position = s.motion.position;
        let team = q.team;
        for who in self.actors.units_near(self.units, position, 25.0, -1)? {
            if who != id
                && self
                    .actors
                    .soldier(who)
                    .is_some_and(|s| s.identity.team == team && s.vitals.life == Life::Alive)
            {
                return Ok(out);
            }
        }
        let enemy = self
            .actors
            .units_near(self.units, position, 40.0, team)?
            .into_iter()
            .any(|who| {
                self.actors
                    .soldier(who)
                    .is_some_and(|s| s.vitals.life == Life::Alive)
            });
        if !enemy || f64::from(self.rng.randf()) >= 0.035 {
            return Ok(out);
        }
        let released = self.actors.soldier_mut(id).unwrap().release_all()?;
        self.actors.release_links(id, released);
        if let Some(q) = self
            .squads
            .iter_mut()
            .find(|q| q.id == released.squad && q.breach_by == id)
        {
            q.breach_by = 0;
        }
        let s = self.actors.soldier_mut(id).unwrap();
        s.vitals.life = Life::Surrender;
        s.activity = 20;
        s.posture = Posture::Stand;
        s.stop_moving()?;
        self.geometry.navigation.planner.cancel(id.into());
        let angle = s.motion.yaw + std::f64::consts::PI * 0.5;
        let drop_direction = Vector3::new(-libm::sin(angle) as f32, 0.0, -libm::cos(angle) as f32);
        out.push(Event::Stat("surrender"));
        let cue = (self.rng.randi() % 3) as u8;
        self.brain_say(id, Call::Surrender, cue, true, None, &mut out);
        self.squads[i].remove_member(id, self.actors)?;
        let s = self.actors.soldier_mut(id).unwrap();
        s.identity.weapon.clear();
        s.weapon.magazine = 0;
        s.weapon.reserve = 0;
        out.push(Event::Surrendered {
            soldier: id,
            team,
            position,
            drop_direction,
        });
        Ok(out)
    }
    pub fn squad_straggler_tick(
        &mut self,
        id: u32,
        battle: &mut crate::battle_stats::BattleStats,
    ) -> Result<Vec<Event>, &'static str> {
        let i = self.index(id)?;
        let q = &mut self.squads[i];
        let mut out = vec![];
        if self.now
            < q.cooldowns
                .iter()
                .find(|v| v.0 == "straggle")
                .map_or(-1.0, |v| v.1)
            || matches!(q.kind.as_str(), "crew" | "r_crew")
        {
            return Ok(out);
        }
        set_cooldown(q, "straggle", self.now + 2.0)?;
        if q.alive(self.actors).count() != 1
            || q.members.len() < 2
            || q.members.iter().any(|&id| {
                self.actors
                    .soldier(id)
                    .is_some_and(|m| matches!(m.vitals.life, Life::Downed | Life::Hidden))
            })
        {
            return Ok(out);
        }
        let s = q.alive(self.actors).next().unwrap();
        if s.duty.kind != Task::Fight
            || s.emplacement.structure != 0
            || s.links.vehicle != 0
            || !available(s)
        {
            return Ok(out);
        }
        let soldier = s.identity.id;
        let position = s.motion.position;
        let owner = q.owner;
        let team = q.team;
        let mut best = None;
        let mut distance = 80.0;
        for (j, o) in self.squads.iter_mut().enumerate() {
            if i == j
                || o.owner != owner
                || o.team != team
                || matches!(o.kind.as_str(), "crew" | "r_crew")
                || o.drill == "rout"
                || o.members.len() >= 9
                || o.alive(self.actors).count() < 2
            {
                continue;
            }
            let d = f64::from(flat(o.centroid(self.now, self.actors) - position).length());
            if d < distance {
                distance = d;
                best = Some(j);
            }
        }
        let Some(j) = best else {
            return Ok(out);
        };
        self.squads[i].remove_member(soldier, self.actors)?;
        self.squads[j].add_member(soldier, self.actors)?;
        battle.squad_grew(&self.squads[j]);
        let mut events = vec![];
        let leader = self.leader(j, &mut events);
        out.extend(events.into_iter().map(Event::Movement));
        let at = self
            .actors
            .soldier(leader)
            .map(|s| s.motion.position)
            .unwrap_or_else(|| self.squads[j].centroid(self.now, self.actors));
        let at = self
            .geometry
            .navigation
            .planner
            .nearest_walkable(at + normalized(flat(position - at)) * 3.0)
            .unwrap();
        let s = self.actors.soldier_mut(soldier).unwrap();
        s.orders.hold_position = at;
        s.orders.hold_face = self.squads[j].facing;
        s.orders.leash = 7.0;
        s.cover.at_cover = false;
        s.cover.evaluate_at = 0.0;
        self.duty_route(soldier, at, Goal::Slot, 1)?;
        let cue = (self.rng.randi() % if team == 0 { 3 } else { 2 }) as u8;
        self.brain_say(soldier, Call::Straggler, cue, true, None, &mut out);
        if leader != 0 {
            let cue = (self.rng.randi() % 3) as u8;
            self.brain_say(leader, Call::Welcome, cue, false, None, &mut out);
        }
        out.push(Event::Joined {
            from: id,
            to: self.squads[j].id,
            soldier,
            position,
        });
        out.push(Event::Stat("straggler_joined"));
        Ok(out)
    }
    pub fn squad_then_defend_tick(&mut self, id: u32) -> Result<Vec<Event>, &'static str> {
        let i = self.index(id)?;
        let q = &mut self.squads[i];
        let Some([at, face]) = q.then_defend else {
            return Ok(vec![]);
        };
        if !q.technique.is_empty()
            || q.order != "move"
            || !q.drill.is_empty()
            || q.alive(self.actors).next().is_none()
        {
            return Ok(vec![]);
        }
        if flat(at - q.centroid(self.now, self.actors)).length() < 12.0
            || !q.travel && q.alive(self.actors).all(|s| !s.is_moving())
        {
            q.then_defend = None;
            return Ok(self
                .order_defend(id, at, face, true)?
                .into_iter()
                .map(Event::Movement)
                .collect());
        }
        Ok(vec![])
    }
    pub fn squad_clear_call_tick(&mut self, id: u32) -> Result<Vec<Event>, &'static str> {
        let i = self.index(id)?;
        let q = &mut self.squads[i];
        let mut out = vec![];
        let Some((soldier, at)) = q.clear_call else {
            return Ok(out);
        };
        if self.now < at {
            return Ok(out);
        }
        q.clear_call = None;
        if self
            .actors
            .soldier(soldier)
            .is_some_and(|s| s.vitals.life == Life::Alive && s.fight.visible_targets.is_empty())
        {
            let cue = (self.rng.randi() % if q.team == 0 { 4 } else { 3 }) as u8;
            self.brain_say(soldier, Call::ClearDone, cue, true, None, &mut out);
            out.push(Event::Stat("house_cleared"));
        }
        Ok(out)
    }
}
