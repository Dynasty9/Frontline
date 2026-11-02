//! Squad travel and fire-team bounds operate directly on retained soldiers and navigation.
use crate::actors::{Actor, Actors};
use crate::entities::Kind;
use crate::infantry::{Goal, Infantry};
use crate::infantry_commands::Command;
use crate::infantry_controller::Task;
use crate::infantry_vitals::Life;
use crate::random::SimulationRandom;
use crate::spatial::SpatialIndex;
use crate::squad::Squad;
use crate::vector::{normalized, Vector3};
use crate::world_geometry::WorldGeometry;

#[derive(Clone, Copy, Debug, Default)]
pub struct ManProfile {
    pub bearer: bool,
    pub weapon_range: Option<f64>,
}
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Call {
    Leader,
    Move,
    Bound,
    Moving,
    Set,
    Recon,
    Defend,
    Assault,
    AssaultBound,
    Pinned,
}
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Event {
    Speech {
        soldier: u32,
        call: Call,
        variant: u8,
    },
    CancelAmbush(u32),
    CrewHome {
        squad: u32,
        fob: u32,
    },
    Despawn(u32),
    Stat(&'static str),
}
pub struct Context<'a> {
    pub actors: &'a mut Actors,
    pub geometry: &'a mut WorldGeometry,
    pub units: &'a SpatialIndex,
    pub squads: &'a mut [Squad],
    pub rng: &'a mut SimulationRandom,
    pub now: f64,
    pub town: [f32; 4],
    /// These read immutable unit, vehicle and building definitions.
    pub man: &'a dyn Fn(&Infantry) -> ManProfile,
    pub automatic: &'a dyn Fn(&str) -> bool,
    pub player_building: &'a dyn Fn(&str) -> bool,
}
pub(crate) fn flat(p: Vector3) -> Vector3 {
    Vector3::new(p.x, 0.0, p.z)
}
pub(crate) fn point(p: Vector3) -> bool {
    p.is_finite() && p.abs().max_element() <= 1_000_000.0
}
pub(crate) fn available(s: &Infantry) -> bool {
    s.duty.kind.can_take_orders(s.vitals.life, s.duty.phase)
}
pub(crate) fn set_cooldown(q: &mut Squad, key: &str, value: f64) -> Result<(), &'static str> {
    if let Some(pair) = q.cooldowns.iter_mut().find(|v| v.0 == key) {
        pair.1 = value;
    } else {
        if q.cooldowns.len() >= 1024 {
            return Err("squad cooldown limit exceeded");
        }
        q.cooldowns.push((key.into(), value));
    }
    Ok(())
}
impl Context<'_> {
    pub fn crew_tick(&mut self, id: u32) -> Result<Vec<Event>, &'static str> {
        let i = self.index(id)?;
        let mut out = vec![];
        let q = &mut self.squads[i];
        if !matches!(q.kind.as_str(), "crew" | "r_crew")
            || self.now
                < q.cooldowns
                    .iter()
                    .find(|v| v.0 == "crew")
                    .map_or(-1.0, |v| v.1)
        {
            return Ok(out);
        }
        set_cooldown(q, "crew", self.now + 1.0)?;
        if q.alive(self.actors).next().is_none() {
            return Ok(out);
        }
        let center = q.centroid(self.now, self.actors);
        let Some(fob) = self.actors.nearest_fob(q.team, center) else {
            return Ok(out);
        };
        let fob_id = fob.id;
        let position = fob.position;
        let own = q
            .cooldowns
            .iter()
            .find(|v| v.0 == "crew_n")
            .is_none_or(|v| q.order_number as i64 == v.1 as i64);
        if flat(position - center).length() < 16.0 && !q.in_combat(self.now) {
            let refund = q
                .cooldowns
                .iter()
                .find(|v| v.0 == "refund")
                .map_or(0, |v| v.1 as i64);
            let Actor::Structure(fob) = self.actors.get_mut(fob_id).unwrap() else {
                unreachable!();
            };
            fob.supply += refund as f64;
            out.push(Event::CrewHome {
                squad: id,
                fob: fob_id,
            });
            out.push(Event::Stat("crew_home"));
            let members = q.members.clone();
            for member in members {
                if self
                    .actors
                    .soldier(member)
                    .is_some_and(|s| !s.identity.gone && s.vitals.life == Life::Alive)
                {
                    q.remove_member(member, self.actors)?;
                    self.actors.remove(member);
                    out.push(Event::Despawn(member));
                }
            }
            return Ok(out);
        }
        if own
            && q.drill.is_empty()
            && (q.order != "move" || flat(q.order_position - position).length() > 20.0)
        {
            let dest = self
                .geometry
                .navigation
                .planner
                .nearest_walkable(position + normalized(flat(center - position)) * 8.0)
                .unwrap();
            self.move_inner(
                i,
                dest,
                normalized(flat(position - center)),
                2,
                true,
                &mut out,
            )?;
            let q = &mut self.squads[i];
            set_cooldown(q, "crew_n", q.order_number as f64)?;
        }
        Ok(out)
    }
    pub(crate) fn index(&self, id: u32) -> Result<usize, &'static str> {
        if !self.now.is_finite()
            || self.now.abs() > 1e12 - 100.0
            || self
                .town
                .iter()
                .any(|v| !v.is_finite() || v.abs() > 1_000_000.0)
            || self.town[2] < 0.0
            || self.town[3] < 0.0
        {
            return Err("invalid squad movement context");
        }
        self.squads
            .iter()
            .position(|q| q.id == id && q.valid())
            .ok_or("missing moving squad")
    }
    pub(crate) fn command(&mut self, id: u32, order: Command) -> Result<(), &'static str> {
        self.actors.command_infantry(
            id,
            order,
            &mut self.geometry.navigation,
            self.squads,
            self.now,
            self.rng,
        )?;
        Ok(())
    }
    pub(crate) fn leader(&mut self, i: usize, out: &mut Vec<Event>) -> u32 {
        let (id, speech) =
            self.squads[i].get_leader(self.actors, |s| (self.man)(s).bearer, self.rng);
        if let Some(s) = speech {
            out.push(Event::Stat("leader_succession"));
            out.push(Event::Speech {
                soldier: s.soldier,
                call: Call::Leader,
                variant: s.cue,
            });
        }
        id
    }
    fn say(&mut self, id: u32, call: Call, count: u32, force: bool, out: &mut Vec<Event>) {
        let variant = (self.rng.randi() % count) as u8;
        let s = self.actors.soldier_mut(id).unwrap();
        if force || s.vitals.speech_cooldown <= 0.0 {
            s.vitals.speech_cooldown = 2.6;
            out.push(Event::Speech {
                soldier: id,
                call,
                variant,
            });
        }
    }
    fn squad_say(&mut self, i: usize, call: Call, count: u32, out: &mut Vec<Event>) {
        let mut id = self.leader(i, out);
        if id == 0 {
            id = self.squads[i]
                .alive(self.actors)
                .next()
                .map_or(0, |s| s.identity.id);
        }
        if id != 0 {
            self.say(id, call, count, true, out);
        }
    }
    pub(crate) fn formation(
        &self,
        center: Vector3,
        face: Vector3,
        members: &[u32],
        wide: bool,
    ) -> Result<Vec<Vector3>, &'static str> {
        let mut free = self
            .geometry
            .formation_slots(self.actors, center, face, members.len(), wide)?
            .into_iter()
            .map(|slot| {
                if slot.anchor.is_some() {
                    slot.position
                } else {
                    self.geometry
                        .navigation
                        .planner
                        .nearest_walkable(slot.position)
                        .unwrap()
                }
            })
            .collect::<Vec<_>>();
        let mut out = Vec::with_capacity(members.len());
        for &id in members {
            let position = self.actors.soldier(id).unwrap().motion.position;
            let mut best = 0;
            let mut distance = 1e9;
            for (index, &slot) in free.iter().enumerate() {
                let d = f64::from(flat(slot - position).length());
                if d < distance {
                    distance = d;
                    best = index;
                }
            }
            out.push(free.remove(best));
        }
        Ok(out)
    }
    pub(crate) fn regroup(&mut self, i: usize, out: &mut Vec<Event>) {
        let q = &mut self.squads[i];
        q.plan = 0;
        q.shown_order.clear();
        q.travel = false;
        q.drill.clear();
        q.ambush = false;
        q.technique.clear();
        q.then_defend = None;
        if q.ambush_plan != 0 {
            out.push(Event::CancelAmbush(q.ambush_plan));
            q.ambush_plan = 0;
        }
        for &id in &q.members {
            if let Some(s) = self.actors.soldier_mut(id) {
                s.orders.detached = false;
            }
        }
    }
    pub fn order_move(
        &mut self,
        id: u32,
        position: Vector3,
        face: Vector3,
        mode: u8,
        tactical: bool,
    ) -> Result<Vec<Event>, &'static str> {
        let i = self.index(id)?;
        if !point(position) || !point(face) || mode > 2 {
            return Err("invalid squad move");
        }
        let mut out = vec![];
        self.move_inner(i, position, face, mode, tactical, &mut out)?;
        Ok(out)
    }
    pub fn order_defend(
        &mut self,
        id: u32,
        position: Vector3,
        face: Vector3,
        direct: bool,
    ) -> Result<Vec<Event>, &'static str> {
        let i = self.index(id)?;
        if !point(position) || !point(face) {
            return Err("invalid squad defense");
        }
        let mut out = vec![];
        let q = &mut self.squads[i];
        if !direct
            && flat(position - q.centroid(self.now, self.actors)).length() > 45.0
            && q.drill.is_empty()
        {
            self.move_inner(i, position, face, 0, true, &mut out)?;
            self.squads[i].then_defend = Some([position, face]);
            return Ok(out);
        }
        self.regroup(i, &mut out);
        self.set_objective(i, "defend", position, face);
        let members = self.squads[i]
            .members
            .iter()
            .copied()
            .filter(|&id| self.actors.soldier(id).is_some_and(available))
            .collect::<Vec<_>>();
        if members.is_empty() {
            return Ok(out);
        }
        let face = self.squads[i].facing;
        let slots = self.formation(position, face, &members, true)?;
        for (&id, slot) in members.iter().zip(slots) {
            self.command(
                id,
                Command::Move {
                    slot,
                    mode: 0,
                    face,
                },
            )?;
            self.actors.soldier_mut(id).unwrap().orders.leash = 7.0;
        }
        self.squads[i].ambush = !self.squads[i].in_combat(self.now);
        self.say(members[0], Call::Defend, 5, true, &mut out);
        Ok(out)
    }
    fn set_objective(&mut self, i: usize, order: &str, position: Vector3, face: Vector3) {
        let q = &mut self.squads[i];
        q.order = order.into();
        q.order_position = position;
        q.facing = if f64::from(face.length()) > 0.1 {
            face
        } else {
            normalized(flat(position - q.centroid(self.now, self.actors)))
        };
        if f64::from(q.facing.length()) < 0.1 {
            q.facing = Vector3::NEG_Z;
        }
        q.build_target = 0;
    }
    pub(crate) fn prepare_assault(
        &mut self,
        id: u32,
        position: Vector3,
        face: Vector3,
        out: &mut Vec<Event>,
    ) -> Result<usize, &'static str> {
        let i = self.index(id)?;
        if !point(position) || !point(face) {
            return Err("invalid squad assault");
        }
        self.regroup(i, out);
        self.set_objective(i, "assault", position, face);
        let q = &mut self.squads[i];
        q.bound_team = 0;
        q.bound_time = 0.0;
        q.contact_time = -99.0;
        for &id in &q.members {
            if let Some(s) = self.actors.soldier_mut(id).filter(|s| available(s)) {
                s.fight.forced_target = 0;
            }
        }
        Ok(i)
    }
    /// Small squads and reinforcements bound without creating a separate attack plan.
    pub fn order_assault_bounds(
        &mut self,
        id: u32,
        position: Vector3,
        face: Vector3,
    ) -> Result<Vec<Event>, &'static str> {
        let mut out = vec![];
        let i = self.prepare_assault(id, position, face, &mut out)?;
        self.start_assault_bounds(i, &mut out)?;
        Ok(out)
    }
    pub(crate) fn start_assault_bounds(
        &mut self,
        i: usize,
        out: &mut Vec<Event>,
    ) -> Result<(), &'static str> {
        self.next_assault_bound(i, 14.0, out)?;
        let leader = self.squads[i]
            .alive(self.actors)
            .next()
            .map(|s| s.identity.id);
        if let Some(id) = leader {
            self.say(id, Call::Assault, 4, true, out);
        }
        Ok(())
    }
    pub(crate) fn next_assault_bound(
        &mut self,
        i: usize,
        leg_max: f64,
        out: &mut Vec<Event>,
    ) -> Result<(), &'static str> {
        let q = &mut self.squads[i];
        let members = q
            .members
            .iter()
            .copied()
            .filter(|&id| {
                self.actors
                    .soldier(id)
                    .is_some_and(|s| available(s) && !s.orders.detached)
            })
            .collect::<Vec<_>>();
        if members.is_empty() {
            return Ok(());
        }
        let center = q.centroid(self.now, self.actors);
        let to = flat(q.order_position - center);
        let leg = f64::from(to.length()).min(leg_max);
        let dest = if to.length() > 0.5 {
            center + normalized(to) * leg as f32
        } else {
            q.order_position
        };
        let group = members
            .iter()
            .copied()
            .enumerate()
            .filter_map(|(k, id)| {
                (members.len() <= 2 || k % 2 == q.bound_team as usize).then_some(id)
            })
            .collect::<Vec<_>>();
        let face = q.facing;
        let slots = self.formation(dest, face, &group, false)?;
        for (&id, slot) in group.iter().zip(slots) {
            self.command(
                id,
                Command::Move {
                    slot,
                    mode: 1,
                    face,
                },
            )?;
        }
        let q = &mut self.squads[i];
        q.bound_team = 1 - q.bound_team;
        q.bound_time = self.now + 12.0;
        if !group.is_empty() && members.len() > 2 && f64::from(self.rng.randf()) < 0.35 {
            self.say(group[0], Call::AssaultBound, 4, false, out);
        }
        Ok(())
    }
    pub fn assault_bounds_tick(&mut self, id: u32) -> Result<Vec<Event>, &'static str> {
        let i = self.index(id)?;
        let q = &mut self.squads[i];
        let mut out = vec![];
        if q.order != "assault" {
            return Ok(out);
        }
        if q.plan != 0 {
            return Err("planned assault requires its attack plan");
        }
        let alive = q
            .alive(self.actors)
            .map(|s| s.identity.id)
            .collect::<Vec<_>>();
        if alive.is_empty() {
            return Ok(out);
        }
        let contact = q.in_combat(self.now);
        if contact {
            q.contact_time = self.now;
        }
        let supp = alive
            .iter()
            .map(|&id| self.actors.soldier(id).unwrap().vitals.suppression)
            .sum::<f64>()
            / alive.len() as f64;
        if contact && (supp > 55.0 || alive.len() * 2 < q.members.len()) {
            if self.now > q.bound_time {
                q.bound_time = self.now + 5.0;
                if f64::from(self.rng.randf()) < 0.3 {
                    self.say(alive[0], Call::Pinned, 3, true, &mut out);
                }
            }
            return Ok(out);
        }
        let center = q.centroid(self.now, self.actors);
        if flat(q.order_position - center).length() < 7.0 {
            let (position, face) = (q.order_position, q.facing);
            return self.order_defend(id, position, face, false);
        }
        if self.now < q.bound_time
            && alive.iter().any(|&id| {
                let s = self.actors.soldier(id).unwrap();
                !s.orders.detached && s.orders.purpose == Goal::Slot && s.is_moving()
            })
        {
            return Ok(out);
        }
        if contact {
            q.cover_fire_position = q
                .last_known_near(self.actors, center, 90.0, 10.0, self.now)
                .map_or(q.order_position, |c| c.report.position);
            q.cover_fire_until = self.now + 6.0;
        }
        self.next_assault_bound(i, if contact { 9.0 } else { 14.0 }, &mut out)?;
        Ok(out)
    }
    fn move_inner(
        &mut self,
        i: usize,
        position: Vector3,
        face: Vector3,
        mode: u8,
        tactical: bool,
        out: &mut Vec<Event>,
    ) -> Result<(), &'static str> {
        self.regroup(i, out);
        let q = &mut self.squads[i];
        q.order = "move".into();
        q.order_position = position;
        q.facing = if f64::from(face.length()) > 0.1 {
            face
        } else {
            normalized(flat(position - q.centroid(self.now, self.actors)))
        };
        if f64::from(q.facing.length()) < 0.1 {
            q.facing = Vector3::NEG_Z;
        }
        q.build_target = 0;
        q.move_mode = mode;
        q.known_at_order.clone_from(&q.known);
        let members = q
            .members
            .iter()
            .copied()
            .filter(|&id| self.actors.soldier(id).is_some_and(available))
            .collect::<Vec<_>>();
        if members.is_empty() {
            return Ok(());
        }
        let face = q.facing;
        let slots = self.formation(position, face, &members, false)?;
        self.squads[i].final_slots = members.iter().copied().zip(slots.iter().copied()).collect();
        if tactical && self.bounding_wanted(i, position, mode)? {
            self.start_bounding(i, out)?;
            return Ok(());
        }
        let leader = self.leader(i, out);
        let q = &mut self.squads[i];
        q.travel = leader != 0
            && members.contains(&leader)
            && members.len() > 1
            && flat(position - q.centroid(self.now, self.actors)).length() > 26.0;
        q.travel_mode = mode;
        if q.travel {
            let slot = q.final_slots.iter().find(|v| v.0 == leader).unwrap().1;
            self.command(leader, Command::Move { slot, mode, face })?;
            let q = &mut self.squads[i];
            q.offsets.clear();
            for (k, &id) in members.iter().filter(|&&id| id != leader).enumerate() {
                let angle = k as f64 * 2.399963;
                let radius = 3.5f64.min(libm::sqrt((k + 1) as f64) * 1.4);
                q.offsets.push((
                    id,
                    [
                        (libm::cos(angle) * radius) as f32,
                        (3.8 + libm::sin(angle) * radius) as f32,
                    ],
                ));
            }
            self.follow_inner(i, out)?;
        } else {
            for (&id, &slot) in members.iter().zip(&slots) {
                self.command(id, Command::Move { slot, mode, face })?;
            }
        }
        self.say(
            if leader != 0 { leader } else { members[0] },
            Call::Move,
            if self.squads[i].owner >= 0 { 5 } else { 3 },
            true,
            out,
        );
        Ok(())
    }
    pub fn follow_tick(&mut self, id: u32) -> Result<Vec<Event>, &'static str> {
        let i = self.index(id)?;
        let mut out = vec![];
        self.follow_inner(i, &mut out)?;
        Ok(out)
    }
    fn follow_inner(&mut self, i: usize, out: &mut Vec<Event>) -> Result<(), &'static str> {
        let leader = self.leader(i, out);
        if leader == 0 {
            self.squads[i].travel = false;
            return Ok(());
        }
        let q = &self.squads[i];
        let s = self.actors.soldier(leader).unwrap();
        let position = s.motion.position;
        let goal = q
            .final_slots
            .iter()
            .find(|v| v.0 == leader)
            .map_or(q.order_position, |v| v.1);
        let mode = q.travel_mode;
        let face = q.facing;
        let members = q
            .members
            .iter()
            .copied()
            .filter(|&id| {
                id != leader
                    && self
                        .actors
                        .soldier(id)
                        .is_some_and(|s| available(s) && !s.orders.detached)
            })
            .collect::<Vec<_>>();
        if flat(goal - position).length() < 9.0 || !s.is_moving() && s.orders.purpose != Goal::Slot
        {
            self.squads[i].travel = false;
            for id in members {
                if let Some(&(_, position)) = self.squads[i].final_slots.iter().find(|v| v.0 == id)
                {
                    self.command(
                        id,
                        Command::Follow {
                            position,
                            mode,
                            face,
                        },
                    )?;
                }
            }
            return Ok(());
        }
        let mut head = if s.is_moving() {
            s.motion.last_direction
        } else {
            normalized(flat(goal - position))
        };
        head = normalized(flat(head));
        if f64::from(head.length()) < 0.1 {
            head = face;
        }
        let side = head.cross(Vector3::Y);
        let mut lag: f32 = 0.0;
        for id in members {
            let Some(&(_, offset)) = self.squads[i].offsets.iter().find(|v| v.0 == id) else {
                continue;
            };
            let nav = &self.geometry.navigation.planner;
            let mut target = nav
                .nearest_walkable(position + side * offset[0] - head * offset[1])
                .unwrap();
            if !nav.line_free(position, target, false) {
                target = position;
            }
            let distance = flat(target - self.actors.soldier(id).unwrap().motion.position).length();
            lag = lag.max(distance);
            self.command(
                id,
                Command::Follow {
                    position: target,
                    mode: if distance > 9.0 {
                        2
                    } else if distance > 3.5 {
                        mode.max(1)
                    } else {
                        mode
                    },
                    face,
                },
            )?;
        }
        self.actors.soldier_mut(leader).unwrap().orders.move_mode =
            if lag > 8.0 { 0 } else { mode };
        Ok(())
    }
    fn bounding_wanted(&mut self, i: usize, dest: Vector3, mode: u8) -> Result<bool, &'static str> {
        let q = &mut self.squads[i];
        if mode >= 1 || matches!(q.kind.as_str(), "crew" | "r_crew") {
            return Ok(false);
        }
        let mut count = 0;
        for &id in &q.members {
            let Some(s) = self.actors.soldier(id) else {
                continue;
            };
            if s.links.vehicle != 0 || s.emplacement.structure != 0 {
                return Ok(false);
            }
            if available(s) && !s.orders.detached {
                count += 1;
            }
        }
        if count < 2 {
            return Ok(false);
        }
        let center = q.centroid(self.now, self.actors);
        if flat(dest - center).length() < 42.0 {
            return Ok(false);
        }
        if self.now - q.alert_time < 75.0 {
            return Ok(true);
        }
        for p in [dest, center + (dest - center) * 0.5] {
            for id in self.actors.units_near(self.units, p, 170.0, q.team)? {
                let visible = match self.actors.get(id).unwrap() {
                    Actor::Soldier(s) => {
                        s.vitals.life == Life::Alive
                            && !s.identity.gone
                            && s.identity.visible & (1 << q.team) != 0
                    }
                    Actor::Vehicle(v) => {
                        !v.gone && !(self.automatic)(&v.kind) && v.visible & (1 << q.team) != 0
                    }
                    _ => false,
                };
                if visible {
                    return Ok(true);
                }
            }
        }
        Ok(self.actors.iter_kind(Kind::Structure).any(|a| match a {
            Actor::Structure(st) => {
                !st.gone
                    && st.team != q.team
                    && (self.player_building)(&st.kind)
                    && (st.team < 0 || st.visible & (1 << q.team) != 0)
                    && f64::from(flat(st.position - dest).length()) <= 150.0 + st.radius
            }
            _ => false,
        }))
    }
    fn teams(&self, i: usize) -> [Vec<u32>; 2] {
        let mut members = self.squads[i]
            .members
            .iter()
            .copied()
            .filter(|&id| {
                self.actors.soldier(id).is_some_and(|s| {
                    available(s)
                        && !s.orders.detached
                        && s.duty.kind == Task::Fight
                        && s.emplacement.structure == 0
                })
            })
            .collect::<Vec<_>>();
        members.sort_unstable();
        let mut teams = [vec![], vec![]];
        for (i, id) in members.into_iter().enumerate() {
            teams[i % 2].push(id);
        }
        teams
    }
    fn center(&mut self, i: usize, members: &[u32]) -> Vector3 {
        // Godot evaluates the fallback centroid even when the fire team is nonempty.
        let fallback = self.squads[i].centroid(self.now, self.actors);
        if members.is_empty() {
            return fallback;
        }
        let mut sum = Vector3::ZERO;
        for &id in members {
            sum += self.actors.soldier(id).unwrap().motion.position;
        }
        sum / members.len() as f32
    }
    fn enemy_dir(&mut self, i: usize) -> Vector3 {
        let q = &mut self.squads[i];
        let center = q.centroid(self.now, self.actors);
        let mut direction = Vector3::ZERO;
        for p in q.threat_points(center, 3, self.now, self.actors) {
            direction += normalized(flat(p - center));
        }
        if f64::from(direction.length()) < 0.1 {
            q.facing
        } else {
            normalized(direction)
        }
    }
    fn start_bounding(&mut self, i: usize, out: &mut Vec<Event>) -> Result<(), &'static str> {
        let q = &mut self.squads[i];
        q.technique = "bound".into();
        q.overwatch_team = 0;
        q.travel = false;
        let teams = self.teams(i);
        let face = self.enemy_dir(i);
        for &id in &teams[1] {
            self.command(id, Command::Halt { face })?;
        }
        self.bound_next(i, out)?;
        self.squad_say(
            i,
            Call::Bound,
            if self.squads[i].team == 0 { 4 } else { 3 },
            out,
        );
        out.push(Event::Stat("bounding"));
        Ok(())
    }
    fn bound_next(&mut self, i: usize, out: &mut Vec<Event>) -> Result<(), &'static str> {
        let mut teams = self.teams(i);
        let team = usize::from(self.squads[i].overwatch_team);
        if teams[team].is_empty() {
            teams.swap(0, 1);
        }
        let mover = &teams[team];
        let cover = &teams[1 - team];
        if mover.is_empty() {
            return Ok(());
        }
        let cc = self.center(i, cover);
        let q = &self.squads[i];
        let to = flat(q.order_position - cc);
        let start = glam::Vec2::new(self.town[0], self.town[1]) + glam::Vec2::splat(4.0);
        let size = glam::Vec2::new(self.town[2], self.town[3]) - glam::Vec2::splat(8.0);
        let end = start + size;
        let urban = self.town[2] > 8.0
            && cc.x >= start.x
            && cc.z >= start.y
            && cc.x < end.x
            && cc.z < end.y;
        let leg = 34.0 * if urban { 0.65 } else { 1.0 };
        if f64::from(to.length()) <= leg + 6.0 {
            let defend = q.then_defend;
            let position = q.order_position;
            let face = q.facing;
            self.squads[i].technique.clear();
            self.move_inner(i, position, face, 0, false, out)?;
            self.squads[i].then_defend = defend;
            return Ok(());
        }
        let face = self.enemy_dir(i);
        let direction = normalized(to);
        let side = direction.cross(Vector3::Y) * if team == 0 { 5.0 } else { -5.0 };
        let dest = self
            .geometry
            .navigation
            .planner
            .nearest_walkable(cc + direction * leg as f32 + side)
            .unwrap();
        let slots = self.formation(dest, face, mover, true)?;
        for (&id, slot) in mover.iter().zip(slots) {
            self.command(
                id,
                Command::Move {
                    slot,
                    mode: 1,
                    face,
                },
            )?;
        }
        self.squads[i].overwatch_time = self.now + 22.0;
        if self.rng.randf() < 0.5 {
            self.say(mover[0], Call::Moving, 4, false, out);
        }
        Ok(())
    }
    pub fn overwatch_tick(&mut self, id: u32) -> Result<Vec<Event>, &'static str> {
        let i = self.index(id)?;
        let mut out = vec![];
        let q = &mut self.squads[i];
        if q.technique != "bound" {
            return Ok(out);
        }
        if q.order != "move" || !q.drill.is_empty() {
            q.technique.clear();
            return Ok(out);
        }
        let team = usize::from(q.overwatch_team);
        let teams = self.teams(i);
        let mover = &teams[team];
        let cover = &teams[1 - team];
        if mover
            .iter()
            .any(|&id| self.actors.soldier(id).unwrap().is_moving())
            && self.now < self.squads[i].overwatch_time
        {
            self.recon_by_fire(i, cover, &mut out)?;
            return Ok(out);
        }
        if !mover.is_empty() && f64::from(self.rng.randf()) < 0.45 {
            self.say(mover[0], Call::Set, 4, false, &mut out);
        }
        self.squads[i].overwatch_team = 1 - team as u8;
        self.bound_next(i, &mut out)?;
        Ok(out)
    }
    fn recon_by_fire(
        &mut self,
        i: usize,
        cover: &[u32],
        out: &mut Vec<Event>,
    ) -> Result<(), &'static str> {
        if self.now < self.squads[i].recon_fire_time || cover.is_empty() {
            return Ok(());
        }
        self.squads[i].recon_fire_time = self.now + 14.0;
        let center = self.center(i, cover);
        let q = &self.squads[i];
        let valid = |p| {
            let d = flat(p - center).length();
            d > 25.0 && d < 150.0
        };
        let spot = q
            .heard
            .iter()
            .rev()
            .find(|r| self.now - r.time < 60.0 && valid(r.position))
            .map(|r| r.position)
            .or_else(|| {
                q.known
                    .iter()
                    .find(|k| self.now - k.report.time > 5.0 && valid(k.report.position))
                    .map(|k| k.report.position)
            });
        let Some(spot) = spot else {
            return Ok(());
        };
        if self
            .actors
            .units_near(self.units, spot, 14.0, -1)?
            .iter()
            .any(|&id| {
                self.actors
                    .soldier(id)
                    .is_some_and(|s| s.identity.team == q.team && s.vitals.life == Life::Alive)
            })
        {
            return Ok(());
        }
        let mut gunner = None;
        for &id in cover {
            let s = self.actors.soldier(id).unwrap();
            let profile = (self.man)(s);
            if profile.weapon_range.is_none()
                || matches!(s.identity.unit.as_str(), "medic" | "r_medic")
                || s.vitals.suppression > 30.0
            {
                continue;
            }
            if gunner.is_none() || matches!(s.identity.unit.as_str(), "mg_gunner" | "pkm") {
                gunner = Some((id, profile.weapon_range.unwrap()));
            }
        }
        let Some((id, range)) = gunner else {
            return Ok(());
        };
        if !range.is_finite() || range < 0.0 {
            return Err("invalid recon weapon range");
        }
        let s = self.actors.soldier_mut(id).unwrap();
        if f64::from(flat(spot - s.motion.position).length()) > range {
            return Ok(());
        }
        s.fight.covering_position = spot + Vector3::Y * 0.6;
        s.fight.covering_until = self.now + 2.6;
        if f64::from(self.rng.randf()) < 0.6 {
            self.say(id, Call::Recon, if q.team == 0 { 4 } else { 2 }, false, out);
        }
        out.push(Event::Stat("recon_by_fire"));
        Ok(())
    }
}
