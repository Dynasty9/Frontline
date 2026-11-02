//! Explicit squad orders share the same claims, routes and random stream as autonomous duties.
use crate::actors::Actor;
use crate::infantry::{Goal, Infantry};
use crate::infantry_action::Round;
use crate::infantry_commands::Command;
use crate::infantry_controller::Task;
use crate::infantry_fire::MountedGun;
use crate::squad_movement::{available, flat, point, Call, Context, Event};
use crate::vector::{normalized, Vector3};

impl Context<'_> {
    pub fn order_attack(&mut self, id: u32, target: u32) -> Result<Vec<Event>, &'static str> {
        let i = self.index(id)?;
        let actor = self.actors.get(target).ok_or("missing attack target")?;
        let at = actor.position();
        let stand = if matches!(actor, Actor::Structure(_)) {
            30.
        } else {
            35.
        };
        let mut out = vec![];
        self.regroup(i, &mut out);
        let q = &mut self.squads[i];
        q.order = "attack".into();
        let center = q.centroid(self.now, self.actors);
        let direction = flat(at - center);
        let distance = f64::from(direction.length());
        let position = if distance > stand {
            at - normalized(direction) * distance.min(stand) as f32
        } else {
            center
        };
        q.order_position = position;
        if distance > 0.1 {
            q.facing = normalized(direction);
        }
        let face = q.facing;
        let members: Vec<_> = q
            .members
            .iter()
            .copied()
            .filter(|&id| self.actors.soldier(id).is_some_and(available))
            .collect();
        if members.is_empty() {
            return Ok(out);
        }
        let slots = self.formation(position, face, &members, false)?;
        for (&id, slot) in members.iter().zip(slots) {
            self.command(
                id,
                Command::Attack {
                    target,
                    position: at,
                    slot,
                },
            )?;
        }
        self.say(members[0], Call::Attack, 3, true, &mut out);
        Ok(out)
    }
    pub fn order_stop(&mut self, id: u32) -> Result<Vec<Event>, &'static str> {
        let i = self.index(id)?;
        let mut out = vec![];
        self.regroup(i, &mut out);
        let q = &mut self.squads[i];
        q.order = "hold".into();
        q.order_position = q.centroid(self.now, self.actors);
        let members = q.members.clone();
        for id in members {
            if self.actors.soldier(id).is_some() {
                self.command(id, Command::Stop)?;
            }
        }
        Ok(out)
    }
    pub(crate) fn assign_build(&mut self, id: u32, target: u32) -> Result<(), &'static str> {
        self.clear_squad_duty(id);
        let s = self.actors.soldier_mut(id).unwrap();
        s.duty.kind = Task::Build;
        s.duty.entity = target.into();
        s.duty.phase = 0;
        let at = self.squad_work_spot(id, target);
        self.actors.soldier_mut(id).unwrap().duty.position = at;
        self.duty_route(id, at, Goal::Task, 1)
    }
    pub fn order_work(&mut self, id: u32, target: u32) -> Result<Vec<Event>, &'static str> {
        let i = self.index(id)?;
        let at = self
            .actors
            .get(target)
            .ok_or("missing work target")?
            .position();
        let mut out = vec![];
        self.regroup(i, &mut out);
        let q = &mut self.squads[i];
        q.order = "build".into();
        q.build_target = target;
        q.order_position = at;
        let members = q.members.clone();
        for &id in &members {
            if self.actors.soldier(id).is_some_and(available) {
                self.actors.soldier_mut(id).unwrap().orders.hold_position = at;
                self.assign_build(id, target)?;
            }
        }
        if let Some(&id) = members.first() {
            self.say(id, Call::Work, 3, true, &mut out);
        }
        Ok(out)
    }
    pub(crate) fn assign_travel(
        &mut self,
        id: u32,
        target: u32,
        task: Task,
    ) -> Result<(), &'static str> {
        if !self.actors.soldier(id).is_some_and(available) {
            return Ok(());
        }
        let at = self
            .actors
            .get(target)
            .ok_or("missing transport target")?
            .position();
        self.clear_squad_duty(id);
        let s = self.actors.soldier_mut(id).unwrap();
        s.duty.kind = task;
        s.duty.entity = target.into();
        self.duty_route(id, at, Goal::Task, 1)
    }
    pub fn order_board(
        &mut self,
        id: u32,
        target: u32,
        seats: i32,
    ) -> Result<Vec<Event>, &'static str> {
        let i = self.index(id)?;
        if !(0..=100_000).contains(&seats) {
            return Err("invalid transport seats");
        }
        let v = self.actors.vehicle(target).ok_or("missing transport")?;
        let at = v.position;
        let free = seats
            - v.passengers
                .iter()
                .filter(|&&id| self.actors.soldier(id).is_some_and(|s| !s.identity.gone))
                .count() as i32;
        let mut out = vec![];
        self.regroup(i, &mut out);
        let q = &mut self.squads[i];
        q.order = "move".into();
        q.order_position = at;
        let members: Vec<_> = q
            .alive(self.actors)
            .filter(|s| available(s))
            .take(free.max(0) as usize)
            .map(|s| s.identity.id)
            .collect();
        for &id in &members {
            self.assign_travel(id, target, Task::Board)?;
        }
        if !members.is_empty() {
            self.say(self.squads[i].members[0], Call::Board, 3, true, &mut out);
        }
        Ok(out)
    }
    pub fn order_enter(
        &mut self,
        id: u32,
        target: u32,
        gun: Option<MountedGun>,
    ) -> Result<Vec<Event>, &'static str> {
        let i = self.index(id)?;
        let st = self
            .actors
            .structure(target)
            .ok_or("missing entered structure")?;
        let at = st.position;
        let face = st.front();
        let kind = st.kind.clone();
        let work = st.needs_work();
        let mount = matches!(
            kind.as_str(),
            "mg_nest" | "hmg_nest" | "mortar_pit" | "at_post" | "watchtower"
        );
        if mount {
            st.mount_position(gun)?;
        }
        let mut out = vec![];
        self.regroup(i, &mut out);
        if kind == "tunnel" {
            self.squads[i].order = "tunnel".into();
            let members = self.squads[i].members.clone();
            for id in members {
                self.assign_travel(id, target, Task::Tunnel)?;
            }
            return Ok(out);
        }
        if kind == "bunker" {
            let q = &mut self.squads[i];
            q.order = "move".into();
            q.order_position = at;
            q.facing = face;
            let members = q.members.clone();
            for &id in &members {
                if self.actors.soldier(id).is_some_and(available) {
                    self.command(
                        id,
                        Command::Move {
                            slot: at,
                            mode: 1,
                            face,
                        },
                    )?;
                    self.actors.soldier_mut(id).unwrap().orders.leash = 2.6;
                }
            }
            if let Some(&id) = members.first() {
                self.say(id, Call::Bunker, 3, true, &mut out);
            }
            return Ok(out);
        }
        if mount {
            let preferred: &[&str] = match kind.as_str() {
                "mg_nest" | "hmg_nest" => &["mg_gunner", "pkm"],
                "mortar_pit" => &["mortar_gunner", "r_mortar"],
                "at_post" => &["at_soldier", "rpg"],
                _ => &[],
            };
            let mut best = None;
            let mut distance = 1e9;
            for s in self.squads[i].alive(self.actors) {
                let d = f64::from(flat(s.motion.position - at).length())
                    - if preferred.contains(&s.identity.unit.as_str()) {
                        20.
                    } else {
                        0.
                    };
                if d < distance && available(s) {
                    distance = d;
                    best = Some(s.identity.id);
                }
            }
            out.extend(self.order_move(id, at - face * 2., face, 0, true)?);
            if let Some(id) = best {
                self.assign_mount(id, target, gun)?;
                out.push(Event::Stat("manned"));
            }
        } else if work {
            out.extend(self.order_work(id, target)?);
        } else {
            out.extend(self.order_move(id, at, self.squads[i].facing, 0, true)?);
        }
        Ok(out)
    }
    pub fn order_fire_mission(
        &mut self,
        id: u32,
        position: Vector3,
        smoke: bool,
        mortar: &dyn Fn(&Infantry) -> bool,
    ) -> Result<Vec<Event>, &'static str> {
        let i = self.index(id)?;
        if !point(position) {
            return Err("invalid fire mission");
        }
        let Some(man) = self.squads[i]
            .alive(self.actors)
            .find(|s| mortar(s))
            .map(|s| s.identity.id)
        else {
            return Ok(vec![]);
        };
        self.squads[i].fire_queue = vec![(position, smoke); 4];
        self.actors.soldier_mut(man).unwrap().vitals.speech_cooldown = 2.6;
        self.actors.soldier_mut(man).unwrap().arsenal.mortar_ready = 0.;
        Ok(vec![Event::Speech {
            soldier: man,
            call: Call::FireMission,
            variant: u8::from(smoke),
        }])
    }
    pub fn order_throw(
        &mut self,
        id: u32,
        position: Vector3,
        round: Round,
    ) -> Result<Vec<Event>, &'static str> {
        let i = self.index(id)?;
        if !point(position) || round == Round::HighExplosive {
            return Err("invalid grenade order");
        }
        let mut best = None;
        let mut distance = 1e9;
        for s in self.squads[i].alive(self.actors) {
            if !available(s)
                || (round == Round::Smoke && s.fight.smokes <= 0)
                || (round == Round::Frag && s.grenades.frags <= 0)
            {
                continue;
            }
            let d = f64::from(flat(s.motion.position - position).length());
            if d < distance {
                distance = d;
                best = Some(s.identity.id);
            }
        }
        if let Some(id) = best {
            self.command(id, Command::Throw { position, round })?;
        }
        Ok(vec![])
    }
}
