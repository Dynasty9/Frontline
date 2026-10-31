//! House entry sees the results of approach fire before choosing the next breach phase.
use crate::breach::{self, Breach, Decision, Input};
use crate::bullet_world::Gunfire;
use crate::infantry::{Goal, Infantry};
use crate::infantry_action::Action;
use crate::infantry_controller::Task;
use crate::infantry_fight_world::{valid_step, Event, Profile};
use crate::infantry_fighting::Mode;
use crate::infantry_fire::MountedGun;
use crate::infantry_pose::Posture;
use crate::infantry_travel_owned::Event as Movement;
use crate::infantry_vitals::Life;
use crate::squad::Report;
use crate::supply_network::SupplyNetwork;
use crate::vector::{normalized, turn_yaw, Vector3};
use crate::vehicle::Vehicle;
use crate::vehicle_damage::Armor;
use crate::vehicle_loss_world::Context;
use crate::world_combat;

fn flat(p: Vector3) -> Vector3 {
    Vector3::new(p.x, 0.0, p.z)
}
impl Context<'_> {
    fn breach_enemy(&self, id: u32, house: u32) -> Result<Option<u32>, &'static str> {
        let s = self.actors.soldier(id).unwrap();
        let Some(q) = self.squads.iter().find(|q| q.id == s.identity.squad) else {
            return Ok(None);
        };
        for contact in &q.known {
            let Some(enemy) = self.actors.soldier(contact.id).filter(|e| {
                !e.identity.gone
                    && e.vitals.life == Life::Alive
                    && self.now - contact.report.time < 30.0
            }) else {
                continue;
            };
            if self
                .actors
                .infantry_house_at(enemy.motion.position, &self.geometry.structures)?
                == Some(house)
            {
                return Ok(Some(contact.id));
            }
        }
        Ok(None)
    }
    fn end_breach(&mut self, id: u32) {
        let s = self.actors.soldier_mut(id).unwrap();
        s.duty.kind = Task::Fight;
        s.duty.entity = 0;
        s.duty.partner = 0;
        s.duty.phase = 0;
        if let Some(q) = self
            .squads
            .iter_mut()
            .find(|q| q.id == s.identity.squad && q.breach_by == id)
        {
            q.breach_by = 0;
        }
    }
    fn breach_route(
        &mut self,
        id: u32,
        position: Vector3,
        goal: Goal,
        mode: u8,
    ) -> Result<(), &'static str> {
        let route = self
            .actors
            .soldier_mut(id)
            .unwrap()
            .go_to(position, goal, mode)?;
        self.apply_infantry_movement(id, Movement::Route(route))
    }
    fn breach_stop(&mut self, id: u32) -> Result<(), &'static str> {
        self.actors.soldier_mut(id).unwrap().stop_moving()?;
        self.geometry.navigation.planner.cancel(u64::from(id));
        Ok(())
    }
    fn breach_action(
        &mut self,
        id: u32,
        action: Action,
        duration: f64,
    ) -> Result<(), &'static str> {
        self.actors
            .soldier_mut(id)
            .unwrap()
            .begin_action(action, duration, None)?;
        self.geometry.navigation.planner.cancel(u64::from(id));
        Ok(())
    }
    fn breach_speech(&mut self, id: u32, lines: &[&str], out: &mut Vec<Event>) {
        let text = lines[self.rng.randi() as usize % lines.len()].into();
        self.actors.soldier_mut(id).unwrap().vitals.speech_cooldown = 2.6;
        out.push(Event::Speech { id, text });
    }
    fn breach_movement(
        &mut self,
        id: u32,
        dt: f64,
        gun: Option<MountedGun>,
        out: &mut Vec<Event>,
    ) -> Result<bool, &'static str> {
        let speed = self.actors.infantry_speed(id, self.now, self.squads);
        let (moving, events) = self.move_infantry_world(id, dt, speed, gun)?;
        out.extend(
            events
                .into_iter()
                .map(|event| Event::Movement { id, event }),
        );
        Ok(moving)
    }
    fn enter_room(
        &mut self,
        id: u32,
        center: Vector3,
        normal: Vector3,
        out: &mut Vec<Event>,
    ) -> Result<(), &'static str> {
        let inside = self
            .geometry
            .navigation
            .planner
            .nearest_walkable(center - normal * 2.2)
            .ok_or("invalid room entry")?;
        self.breach_speech(
            id,
            &["Go! Go! Go!", "Moving in!", "In! In!", "Clear the room!"],
            out,
        );
        let s = self.actors.soldier(id).unwrap();
        let squad_id = s.identity.squad;
        if s.entry.clear {
            if let Some(q) = self.squads.iter_mut().find(|q| q.id == squad_id) {
                q.clear_call = Some((id, self.now + 2.5));
            }
        }
        self.end_breach(id);
        self.enter_room_order(id, inside, normal)?;
        out.push(Event::World(world_combat::Event::Stat("room_entry")));
        let mut buddy = 0;
        let mut nearest = 14.0;
        if let Some(q) = self.squads.iter().find(|q| q.id == squad_id) {
            for who in &q.members {
                let Some(m) = self.actors.soldier(*who).filter(|m| {
                    m.identity.id != id
                        && m.vitals.life == Life::Alive
                        && m.duty.kind == Task::Fight
                        && m.emplacement.structure == 0
                }) else {
                    continue;
                };
                let distance = f64::from(flat(m.motion.position - center).length());
                if distance < nearest {
                    nearest = distance;
                    buddy = *who;
                }
            }
        }
        if buddy != 0 {
            let along = Vector3::new(normal.z, 0.0, -normal.x);
            let position = self
                .geometry
                .navigation
                .planner
                .nearest_walkable(center - normal * 2.0 + along * 1.4)
                .ok_or("invalid room buddy entry")?;
            self.enter_room_order(buddy, position, normal)?;
            self.breach_speech(buddy, &["Right behind you!", "With you!", "Going in!"], out);
        }
        Ok(())
    }
    fn enter_room_order(
        &mut self,
        id: u32,
        position: Vector3,
        normal: Vector3,
    ) -> Result<(), &'static str> {
        let s = self.actors.soldier_mut(id).unwrap();
        s.orders.hold_position = position;
        s.orders.hold_face = -normal;
        s.orders.leash = 2.5;
        s.cover.at_cover = false;
        s.cover.evaluate_at = 0.0;
        self.breach_route(id, position, Goal::Slot, 2)
    }

    pub fn advance_breach<'a>(
        &mut self,
        id: u32,
        dt: f64,
        gun: Option<MountedGun>,
        profile: &dyn Fn(&Infantry) -> Option<Profile<'a>>,
        gunfire: &mut Gunfire,
        network: &mut SupplyNetwork,
        impacts: &mut Vec<Report>,
        armor: &dyn Fn(&Vehicle) -> Armor,
        vehicle_hit: &dyn Fn(&Vehicle) -> f64,
    ) -> Result<Vec<Event>, &'static str> {
        let s = self
            .actors
            .soldier(id)
            .ok_or("missing breaching infantry")?;
        if !valid_step(dt, self.now, gun)
            || profile(s).is_some_and(|p| !p.valid())
            || s.vitals.life != Life::Alive
            || s.duty.kind != Task::Breach
            || s.duty.phase > 4
        {
            return Err("invalid house entry step");
        }
        let wall_id = s.duty.entity as u32;
        let house_id = s.entry.house as u32;
        let valid = self.actors.structure(wall_id).is_some_and(|w| !w.gone)
            && self.actors.structure(house_id).is_some_and(|h| !h.gone);
        let mut state = Breach {
            phase: s.duty.phase,
            started: s.duty.timer,
            wait_until: s.entry.wait_until,
            cook_started: s.entry.cooking_started,
            clear: s.entry.clear,
            no_frag: s.entry.no_frag,
        };
        if state.expired(self.now, valid)? {
            self.end_breach(id);
            return Ok(vec![]);
        }
        let opening = s.entry.opening.ok_or("missing breach opening")?;
        let c = opening.center;
        let n = opening.normal;
        let mut out = vec![];
        let mut moving = false;
        let mut distance = 0.0;
        match state.phase {
            0 => {
                moving = self.breach_movement(id, dt, gun, &mut out)?;
                out.extend(self.advance_infantry_weapon(
                    id,
                    dt,
                    moving,
                    Mode::Normal,
                    gun,
                    profile,
                    gunfire,
                    network,
                    impacts,
                    armor,
                    vehicle_hit,
                )?);
                let s = self.actors.soldier_mut(id).unwrap();
                distance = f64::from(flat(s.duty.position - s.motion.position).length());
                if distance < 5.0 {
                    s.posture = Posture::Crouch;
                }
                self.actors
                    .choose_infantry_activity(id, moving, self.now, self.squads);
            }
            1 => {
                let s = self.actors.soldier(id).unwrap();
                let mount = self.actors.mount_turn(s, gun)?;
                let s = self.actors.soldier_mut(id).unwrap();
                s.posture = Posture::Crouch;
                s.activity = 0;
                s.motion.yaw = turn_yaw(
                    s.motion.yaw,
                    normalized(flat(c - s.motion.position)),
                    s.motion.position,
                    dt,
                    8.0,
                    mount,
                );
            }
            2 => {
                moving = self.breach_movement(id, dt, gun, &mut out)?;
                let s = self.actors.soldier_mut(id).unwrap();
                s.posture = Posture::Stand;
                distance = f64::from(flat(s.duty.second_position - s.motion.position).length());
                self.actors
                    .choose_infantry_activity(id, moving, self.now, self.squads);
            }
            3 => {
                let s = self.actors.soldier(id).unwrap();
                match breach::retreat(
                    f64::from(flat(s.motion.position - s.duty.position).length()),
                    s.is_moving(),
                    s.entry.grenade != 0,
                )? {
                    1 => self.breach_route(id, s.duty.position, Goal::Task, 2)?,
                    2 => self.breach_stop(id)?,
                    _ => {}
                }
                moving = self.breach_movement(id, dt, gun, &mut out)?;
                self.actors.soldier_mut(id).unwrap().posture = Posture::Crouch;
                self.actors
                    .choose_infantry_activity(id, moving, self.now, self.squads);
            }
            4 => self.actors.soldier_mut(id).unwrap().posture = Posture::Crouch,
            _ => unreachable!(),
        }
        let enemy = if state.phase < 2 {
            self.breach_enemy(id, house_id)?
        } else {
            None
        };
        let s = self.actors.soldier(id).unwrap();
        let decision = state.advance(
            Input {
                time: self.now,
                moving,
                distance,
                enemy_inside: enemy.is_some(),
                door_shut: self
                    .actors
                    .structure(wall_id)
                    .is_some_and(|w| w.door_closed),
                frags: s.grenades.frags,
                team: s.identity.team.into(),
                enemy_hard_cover: enemy
                    .and_then(|id| self.actors.soldier(id))
                    .is_some_and(|e| e.cover.at_cover && e.cover.material >= 2),
                exploded: s.entry.grenade != 0 && self.actors.get(s.entry.grenade as u32).is_none(),
                reordered: s.entry.reordered,
            },
            self.rng,
        )?;
        let s = self.actors.soldier_mut(id).unwrap();
        s.duty.phase = state.phase;
        s.entry.wait_until = state.wait_until;
        s.entry.cooking_started = state.cook_started;
        s.entry.no_frag = state.no_frag;
        if matches!(
            decision,
            Decision::KickDoor | Decision::EnterWait | Decision::Throw { .. }
        ) {
            self.breach_stop(id)?;
        }
        match decision {
            Decision::Cancel => self.end_breach(id),
            Decision::RetryStack => self.breach_route(
                id,
                self.actors.soldier(id).unwrap().duty.position,
                Goal::Task,
                1,
            )?,
            Decision::Stacked => self.breach_stop(id)?,
            Decision::ApproachDoor { cook, distance } => {
                if cook > 0.0 {
                    self.breach_action(id, Action::Cook, cook)?;
                }
                let position = self
                    .geometry
                    .navigation
                    .planner
                    .nearest_walkable(c + n * distance)
                    .ok_or("invalid breach approach")?;
                self.actors.soldier_mut(id).unwrap().duty.second_position = position;
                self.breach_route(id, position, Goal::Task, 1)?;
            }
            Decision::KickDoor => {
                self.breach_action(
                    id,
                    Action::DoorKick {
                        door: wall_id.into(),
                        position: c,
                    },
                    0.45,
                )?;
                out.push(Event::World(world_combat::Event::Stat("breach_door_kick")));
            }
            Decision::Throw { fuse } => {
                let s = self.actors.soldier(id).unwrap();
                let target = self
                    .actors
                    .soldier(s.duty.partner as u32)
                    .filter(|e| !e.identity.gone && e.vitals.life == Life::Alive)
                    .map(|e| e.identity.id);
                let target = match target {
                    Some(id) => Some(id),
                    None => self.breach_enemy(id, house_id)?,
                };
                let position = target.and_then(|id| self.actors.soldier(id)).map_or_else(
                    || self.actors.structure(house_id).unwrap().position,
                    |e| e.motion.position,
                );
                let position = breach::room_target(c, n, position)?;
                self.actors.soldier_mut(id).unwrap().grenades.frags -= 1;
                out.push(Event::World(world_combat::Event::Stat("breach_frag_in")));
                self.breach_action(id, Action::ThrowIn { position, fuse }, 0.4)?;
                self.breach_speech(
                    id,
                    &["Frag out!", "Fire in the hole!", "Grenade in!"],
                    &mut out,
                );
            }
            Decision::FollowSquad => {
                self.end_breach(id);
                self.breach_route(
                    id,
                    self.actors.soldier(id).unwrap().orders.hold_position,
                    Goal::Slot,
                    1,
                )?;
            }
            Decision::Enter => self.enter_room(id, c, n, &mut out)?,
            _ => {}
        }
        Ok(out)
    }
}
