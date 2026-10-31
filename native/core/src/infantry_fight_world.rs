//! Movement and cover changes finish before aiming; bullet effects finish before burst recovery.
use crate::bullet;
use crate::bullet_world::{Gunfire, Shot};
use crate::infantry::Infantry;
use crate::infantry_controller::Task;
use crate::infantry_cover::CoverWorld;
use crate::infantry_fighting::{Mode, WeaponInput};
use crate::infantry_fire::{FireProfile, MountedGun};
use crate::infantry_idle_owned;
use crate::infantry_medicine::{self, EscortInput};
use crate::infantry_travel_owned::Event as Movement;
use crate::infantry_vitals::Life;
use crate::squad::Report;
use crate::supply_network::SupplyNetwork;
use crate::vehicle::Vehicle;
use crate::vehicle_damage::Armor;
use crate::vehicle_loss_world::Context;
use crate::world_combat::{self, Explosion};

#[derive(Clone, Copy, Debug)]
pub struct Profile<'a> {
    pub fire: FireProfile,
    pub bullet: bullet::Weapon,
    pub interval: f64,
    pub suppression: f64,
    pub sound: &'a str,
    pub optics: bool,
    pub piercing: bool,
}
impl Profile<'_> {
    pub fn valid(self) -> bool {
        self.fire.weapon.valid()
            && (1..=1_000_000).contains(&self.fire.burst_min)
            && (self.fire.burst_min..=1_000_000).contains(&self.fire.burst_max)
            && self.bullet.valid()
            && self.interval.is_finite()
            && (0.0..=3600.0).contains(&self.interval)
            && self.suppression.is_finite()
            && (0.0..=1_000_000.0).contains(&self.suppression)
            && self.sound.len() <= 128
            && !self.sound.contains('\0')
            && self.bullet.explosive_radius.is_none_or(|radius| {
                Explosion {
                    damage: Some(self.bullet.damage * 1.6),
                    radius,
                    structure_multiplier: 1.5,
                    vehicle_multiplier: 0.1,
                    ..Default::default()
                }
                .valid()
            })
    }
}
#[derive(Clone, Debug, PartialEq)]
pub enum Event {
    World(world_combat::Event),
    Speech { id: u32, text: String },
    Movement { id: u32, event: Movement },
}
fn reload(id: u32, cue: Option<u8>, out: &mut Vec<Event>) {
    if let Some(cue) = cue {
        out.push(Event::Speech {
            id,
            text: ["Reloading!", "Changing mag!", "Cover me, reloading!"][cue as usize].into(),
        });
    }
}
pub(crate) fn valid_step(dt: f64, now: f64, gun: Option<MountedGun>) -> bool {
    dt.is_finite()
        && (0.0..=10.0).contains(&dt)
        && now.is_finite()
        && (0.0..=1e12 - 100.0).contains(&now)
        && gun.is_none_or(MountedGun::valid)
}

impl Context<'_> {
    pub(crate) fn move_infantry_world(
        &mut self,
        id: u32,
        dt: f64,
        speed: f64,
        gun: Option<MountedGun>,
    ) -> Result<(bool, Vec<Movement>), &'static str> {
        let mut events = vec![];
        let moving = self.actors.move_infantry(
            id,
            dt,
            self.now,
            speed,
            gun,
            self.squads,
            &mut CoverWorld {
                terrain: &self.geometry.terrain,
                nav: &self.geometry.navigation.planner,
                collision: &mut self.geometry.collision,
                heat: self.fires.hot(),
                deck: &self.geometry.deck,
                units: self.units,
                structures: &self.geometry.structures,
            },
            &self.geometry.doors,
            self.rng,
            &mut events,
        )?;
        for event in &events {
            self.apply_infantry_movement(id, *event)?;
        }
        Ok((moving, events))
    }
    pub(crate) fn apply_infantry_movement(
        &mut self,
        id: u32,
        event: Movement,
    ) -> Result<(), &'static str> {
        match event {
            Movement::Route(route) => {
                self.geometry.navigation.submit_infantry(
                    self.actors.soldier_mut(id).unwrap(),
                    route,
                    self.now,
                    self.rng,
                )?;
            }
            Movement::CancelPath => self.geometry.navigation.planner.cancel(u64::from(id)),
            Movement::Door { id, .. } => {
                self.geometry.doors.remove(id);
                if let Some(st) = self.actors.structure(id) {
                    self.geometry.sync_structure(st, false)?;
                    self.geometry.refresh_structure_collision(st)?;
                }
            }
            _ => {}
        }
        Ok(())
    }

    pub fn advance_infantry_weapon<'a>(
        &mut self,
        id: u32,
        dt: f64,
        moving: bool,
        mode: Mode,
        gun: Option<MountedGun>,
        profile: &dyn Fn(&Infantry) -> Option<Profile<'a>>,
        gunfire: &mut Gunfire,
        network: &mut SupplyNetwork,
        impacts: &mut Vec<Report>,
        armor: &dyn Fn(&Vehicle) -> Armor,
        vehicle_hit: &dyn Fn(&Vehicle) -> f64,
    ) -> Result<Vec<Event>, &'static str> {
        let s = self.actors.soldier(id).ok_or("missing fighting infantry")?;
        let weapon = profile(s);
        if !valid_step(dt, self.now, gun) || weapon.is_some_and(|p| !p.valid()) {
            return Err("invalid infantry world weapon step");
        }
        let squad_id = s.identity.squad;
        let covering = s.fight.covering_until > self.now
            || self
                .squads
                .iter()
                .find(|q| q.id == squad_id)
                .is_some_and(|q| q.cover_fire_until > self.now);
        let step = self.actors.begin_infantry_weapon(
            id,
            WeaponInput {
                dt,
                now: self.now,
                moving,
                mode,
                weapon: weapon.map(|p| p.fire.weapon),
                gun,
            },
            self.squads.iter_mut().find(|q| q.id == squad_id),
            self.rng,
        )?;
        let mut out = vec![];
        if step.cycle.blind_fire {
            out.push(Event::World(world_combat::Event::Stat("blind_fire")));
        }
        reload(id, step.cycle.reload_speech, &mut out);
        if let Some(cue) = step.reply.speech {
            out.push(Event::Speech {
                id: step.reply.soldier,
                text: ["Covering!", "Got you covered!", "I'm up!"][cue as usize].into(),
            });
        }
        if step.cycle.shift_along {
            if let Some(route) = self.actors.shift_infantry_cover(
                id,
                self.squads.iter().find(|q| q.id == squad_id),
                &self.geometry.navigation.planner,
                self.units,
            )? {
                self.geometry.navigation.submit_infantry(
                    self.actors.soldier_mut(id).unwrap(),
                    route,
                    self.now,
                    self.rng,
                )?;
                out.push(Event::World(world_combat::Event::Stat("shift_along")));
            }
        }
        let aim = self.actors.aim_infantry_weapon(
            step,
            weapon.map_or(0.0, |p| p.bullet.range),
            self.squads.iter().find(|q| q.id == squad_id),
            &mut self.geometry.collision,
            self.visibility,
            self.rng,
        )?;
        if aim.reused_obstruction {
            out.push(Event::World(world_combat::Event::Stat(
                "perception_blocked_reused",
            )));
        }
        let (Some(point), Some(p)) = (aim.point, weapon) else {
            return Ok(out);
        };
        let prepared = self.actors.prepare_infantry_shot(
            id,
            self.now,
            moving,
            p.fire,
            gun,
            self.squads.iter().find(|q| q.id == squad_id),
            self.rng,
        )?;
        reload(id, prepared.shot.reload_speech, &mut out);
        if !prepared.shot.fired {
            return Ok(out);
        }
        if prepared.shot.announce_low_ammo {
            out.push(Event::World(world_combat::Event::Stat("low_ammo")));
            out.push(Event::Speech {
                id,
                text: "Low on ammo!".into(),
            });
        }
        out.extend(
            self.fire_bullet(
                Shot {
                    shooter: id,
                    target: aim.target as u32,
                    muzzle: prepared.origin.unwrap(),
                    aim: point,
                    weapon: p.bullet,
                    accuracy: prepared.shot.accuracy,
                    optics: p.optics,
                    piercing: p.piercing,
                    suppression: p.suppression,
                    sound: p.sound,
                },
                gunfire,
                network,
                impacts,
                armor,
                vehicle_hit,
            )?
            .into_iter()
            .map(Event::World),
        );
        // Damage can release a mounted weapon before the automatic reload starts.
        let mut reload_weapon = p.fire.weapon;
        reload_weapon.reload_time =
            profile(self.actors.soldier(id).unwrap()).map_or(2.0, |p| p.fire.weapon.reload_time);
        reload(
            id,
            self.actors.finish_infantry_shot(
                id,
                reload_weapon,
                p.interval,
                prepared.shot.low_ammo,
                covering,
                self.rng,
            )?,
            &mut out,
        );
        Ok(out)
    }

    pub fn advance_fighting<'a>(
        &mut self,
        id: u32,
        dt: f64,
        gun: Option<MountedGun>,
        last_chat: &mut [f64; 2],
        profile: &dyn Fn(&Infantry) -> Option<Profile<'a>>,
        gunfire: &mut Gunfire,
        network: &mut SupplyNetwork,
        impacts: &mut Vec<Report>,
        armor: &dyn Fn(&Vehicle) -> Armor,
        vehicle_hit: &dyn Fn(&Vehicle) -> f64,
    ) -> Result<Vec<Event>, &'static str> {
        let s = self.actors.soldier(id).ok_or("missing fighting infantry")?;
        if !valid_step(dt, self.now, gun)
            || profile(s).is_some_and(|p| !p.valid())
            || last_chat.iter().any(|t| !t.is_finite() || t.abs() > 1e12)
            || s.vitals.life != Life::Alive
            || !matches!(s.duty.kind, Task::Fight | Task::Escort)
        {
            return Err("invalid fighting infantry step");
        }
        let escort = s.duty.kind == Task::Escort;
        let mut out = vec![];
        let moving = if escort {
            let rescuer = self.actors.soldier(s.duty.partner as u32).filter(|r| {
                !r.identity.gone
                    && r.vitals.life == Life::Alive
                    && r.duty.kind == Task::Rescue
                    && r.duty.phase != 2
            });
            let patient = self
                .actors
                .soldier(s.duty.entity as u32)
                .filter(|w| !w.identity.gone);
            let (Some(rescuer), Some(_)) = (rescuer, patient) else {
                let s = self.actors.soldier_mut(id).unwrap();
                s.duty.kind = Task::Fight;
                s.orders.backwards = false;
                s.cover.at_cover = false;
                s.cover.evaluate_at = 0.0;
                return Ok(out);
            };
            let squad = self.squads.iter().find(|q| q.id == s.identity.squad);
            let threats = self.actors.infantry_threats(id, self.now, squad)?;
            let pose = infantry_medicine::escort(
                EscortInput {
                    position: s.motion.position,
                    yaw: s.motion.yaw,
                    rescuer: rescuer.motion.position,
                    threat: s.threat_direction(&threats)?,
                    dt,
                    mount: self.actors.mount_turn(s, gun)?,
                },
                &self.geometry.navigation.planner,
            )?;
            let s = self.actors.soldier_mut(id).unwrap();
            s.motion.position = pose.position;
            s.motion.yaw = pose.yaw;
            s.orders.backwards = pose.backwards;
            pose.walking
        } else {
            let speed = self.actors.infantry_speed(id, self.now, self.squads);
            let (moving, movement) = self.move_infantry_world(id, dt, speed, gun)?;
            for event in movement {
                out.push(Event::Movement { id, event });
            }
            if moving {
                self.actors.soldier_mut(id).unwrap().fight.shuffling = false;
            } else {
                let s = self.actors.soldier(id).unwrap();
                let target_valid = self.actors.infantry_target_valid(s.fight.target as u32);
                let mount = self.actors.mount_turn(s, gun)?;
                self.actors.soldier_mut(id).unwrap().stand(
                    dt,
                    self.now,
                    target_valid,
                    mount,
                    &self.geometry.navigation.planner,
                    &self.geometry.terrain,
                    &self.geometry.deck,
                )?;
            }
            moving
        };
        out.extend(self.advance_infantry_weapon(
            id,
            dt,
            moving && !escort,
            if escort { Mode::Escort } else { Mode::Normal },
            gun,
            profile,
            gunfire,
            network,
            impacts,
            armor,
            vehicle_hit,
        )?);
        if escort {
            let s = self.actors.soldier_mut(id).unwrap();
            s.activity = if self.now - s.weapon.last_shot < 0.35 {
                3
            } else if moving {
                1
            } else {
                0
            };
        } else {
            let shuffling = self.actors.soldier(id).unwrap().fight.shuffling;
            self.actors
                .choose_infantry_activity(id, moving || shuffling, self.now, self.squads);
            for event in self.actors.advance_infantry_idle(
                id,
                dt,
                self.now,
                moving,
                self.squads,
                last_chat,
                self.units,
                self.rng,
            )? {
                out.push(match event {
                    infantry_idle_owned::Event::Banter => {
                        Event::World(world_combat::Event::Stat("banter"))
                    }
                    infantry_idle_owned::Event::Speech(text) => Event::Speech { id, text },
                });
            }
        }
        Ok(out)
    }
}
