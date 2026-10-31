//! Infantry aims and asks squadmates for covering fire using retained actor state.
use crate::actors::{Actor, Actors};
use crate::collision::CollisionWorld;
use crate::cover::{rotation, transform};
use crate::infantry::Infantry;
use crate::infantry_aim::{AimInput, AimResult, Target, TargetKind};
use crate::infantry_controller::Task;
use crate::infantry_vitals::Life;
use crate::infantry_weapon::{ShotInput, ShotResult, Weapon};
use crate::random::SimulationRandom;
use crate::squad::{Contact, Squad};
use crate::structure::Structure;
use crate::vector::Vector3;
use crate::visibility::Visibility;

fn flat(p: Vector3) -> Vector3 {
    Vector3::new(p.x, 0.0, p.z)
}
fn clock(now: f64) -> bool {
    now.is_finite() && now.abs() <= 1e12 - 1.0
}

impl Squad {
    pub fn morale_state(&self) -> usize {
        let morale = if self.morale >= 0.0 {
            self.morale
        } else {
            75.0
        };
        if self.drill == "rout" || morale < 12.0 {
            3
        } else if morale < 33.0 {
            2
        } else if morale < 55.0 {
            1
        } else {
            0
        }
    }
    pub fn accuracy_multiplier(&self) -> f64 {
        [1.0, 0.85, 0.7, 0.45][self.morale_state()]
    }
    pub fn pin_at(&self) -> f64 {
        [60.0, 52.0, 44.0, 30.0][self.morale_state()]
    }
    pub fn last_known_near(
        &self,
        actors: &Actors,
        position: Vector3,
        radius: f64,
        age: f64,
        now: f64,
    ) -> Option<Contact> {
        let mut best = None;
        let mut distance = radius;
        for contact in &self.known {
            if now - contact.report.time > age {
                continue;
            }
            let Some(actor) = actors.get(contact.id) else {
                continue;
            };
            if matches!(actor,Actor::Soldier(s) if s.vitals.life!=Life::Alive) {
                continue;
            }
            let d = f64::from(flat(contact.report.position - position).length());
            if d < distance {
                distance = d;
                best = Some(*contact);
            }
        }
        best
    }
}

/// Fixed weapon geometry comes from the content catalog, never an animated model.
#[derive(Clone, Copy, Debug)]
pub struct MountedGun {
    pub bore: f64,
    pub muzzle: f64,
    pub grip_z: f32,
    pub nest_height: f64,
    pub trench_height: f64,
}
impl MountedGun {
    pub fn valid(self) -> bool {
        [
            self.bore,
            self.muzzle,
            f64::from(self.grip_z),
            self.nest_height,
            self.trench_height,
        ]
        .into_iter()
        .all(|v| v.is_finite() && (0.0..=100.0).contains(&v))
    }
}
impl Structure {
    fn mg_pivot(&self, gun: MountedGun) -> Vector3 {
        let heavy = self.kind == "hmg_nest";
        if self.variant == 1 {
            Vector3::new(
                0.0,
                gun.trench_height as f32,
                -(0.72 + if heavy { 0.55 } else { 0.5 }) as f32,
            )
        } else if heavy {
            Vector3::new(0.0, (0.45 + gun.nest_height) as f32, -1.1)
        } else {
            Vector3::new(0.0, (0.5 + gun.nest_height) as f32, -0.95)
        }
    }
    pub fn mg_mount_position(&self, gun: MountedGun) -> Vector3 {
        let local = self.mg_pivot(gun)
            + Vector3::new(
                0.0,
                0.0,
                (f64::from(gun.grip_z) + if self.variant == 1 { 0.34 } else { 0.5 }) as f32,
            );
        let mut position =
            self.position + transform(rotation(self.yaw), Vector3::new(local.x, 0.0, local.z));
        if self.variant == 1 {
            position.y = (-1.2 + 0.15) as f32;
        }
        position
    }
    pub fn mg_muzzle(&self, yaw: f64, gun: MountedGun) -> Vector3 {
        use std::f64::consts::{PI, TAU};
        let difference = yaw - self.yaw;
        let relative = (difference - TAU * ((difference + PI) / TAU).floor()).clamp(-1.2, 1.2);
        let pivot = self.position + transform(rotation(self.yaw), self.mg_pivot(gun));
        pivot
            + Vector3::new(0.0, gun.bore as f32, 0.0)
            + direction(self.yaw + relative) * gun.muzzle as f32
    }
}
fn direction(yaw: f64) -> Vector3 {
    Vector3::new(-libm::sin(yaw) as f32, 0.0, -libm::cos(yaw) as f32)
}

#[derive(Clone, Copy, Debug)]
pub struct FireProfile {
    pub weapon: Weapon,
    pub burst_min: i32,
    pub burst_max: i32,
}
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct PreparedShot {
    pub shot: ShotResult,
    pub origin: Option<Vector3>,
}
impl Infantry {
    fn reload_speech(&mut self, speech: Option<u8>) -> Option<u8> {
        if speech.is_some() && self.vitals.speech_cooldown <= 0.0 {
            self.vitals.speech_cooldown = 2.6;
            speech
        } else {
            None
        }
    }
    /// Called after bullet effects; damage may have changed suppression and weapon.
    pub fn finish_fire(
        &mut self,
        weapon: Weapon,
        interval: f64,
        low_ammo: bool,
        cover_fire: bool,
        rng: &mut SimulationRandom,
    ) -> Result<Option<u8>, &'static str> {
        let speech = self.weapon.finish_shot(
            weapon,
            interval,
            self.vitals.suppression,
            low_ammo,
            cover_fire,
            rng,
        )?;
        Ok(self.reload_speech(speech))
    }
}

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct CoverReply {
    pub soldier: u32,
    pub speech: Option<u8>,
}

impl Actors {
    pub fn finish_infantry_shot(
        &mut self,
        id: u32,
        weapon: Weapon,
        interval: f64,
        low_ammo: bool,
        cover_fire: bool,
        rng: &mut SimulationRandom,
    ) -> Result<Option<u8>, &'static str> {
        self.soldier_mut(id)
            .ok_or("missing firing soldier")?
            .finish_fire(weapon, interval, low_ammo, cover_fire, rng)
    }
    pub fn infantry_bullet_origin(
        &self,
        id: u32,
        gun: Option<MountedGun>,
    ) -> Result<Vector3, &'static str> {
        if gun.is_some_and(|g| !g.valid()) {
            return Err("invalid mounted gun geometry");
        }
        let s = self.soldier(id).ok_or("missing firing soldier")?;
        let mut muzzle = self.infantry_pose(id).unwrap().eye() + direction(s.motion.yaw) * 0.55
            - Vector3::new(0.0, 0.08, 0.0);
        if let Some(st) = self
            .structure(s.emplacement.structure as u32)
            .filter(|st| !st.gone && matches!(st.kind.as_str(), "mg_nest" | "hmg_nest"))
        {
            let gun = gun.ok_or("missing mounted gun geometry")?;
            if f64::from(flat(s.motion.position - st.mg_mount_position(gun)).length()) < 0.8 {
                muzzle = st.mg_muzzle(s.motion.yaw, gun);
            }
        }
        if s.weapon.blind {
            muzzle = s.motion.position
                + s.cover.normal * 0.55
                + Vector3::new(0.0, (s.cover.height + 0.12) as f32, 0.0);
        }
        Ok(muzzle)
    }
    pub fn prepare_infantry_shot(
        &mut self,
        id: u32,
        now: f64,
        moving: bool,
        profile: FireProfile,
        gun: Option<MountedGun>,
        squad: Option<&Squad>,
        rng: &mut SimulationRandom,
    ) -> Result<PreparedShot, &'static str> {
        if !clock(now) {
            return Err("invalid infantry shot time");
        }
        let s = self.soldier(id).ok_or("missing firing soldier")?;
        if squad.is_some_and(|q| q.id != s.identity.squad) {
            return Err("infantry squad mismatch");
        }
        let origin = if s.weapon.magazine > 0 || profile.weapon.ammunition >= 9000 {
            Some(self.infantry_bullet_origin(id, gun)?)
        } else {
            None
        };
        let s = self.soldier_mut(id).unwrap();
        let mut shot = s.weapon.prepare_shot(
            ShotInput {
                weapon: profile.weapon,
                burst_min: profile.burst_min,
                burst_max: profile.burst_max,
                time: now,
                stamina: s.vitals.stamina,
                moving,
                gun_override: !s.identity.mounted_weapon.is_empty(),
                squad_accuracy: squad.map_or(1.0, Squad::accuracy_multiplier),
                ambush: squad.is_some_and(|q| q.ambush_time > now),
            },
            rng,
        )?;
        shot.reload_speech = s.reload_speech(shot.reload_speech);
        if shot.announce_low_ammo {
            s.vitals.speech_cooldown = 2.6;
        }
        if shot.fired {
            s.activity = 3;
        }
        Ok(PreparedShot { shot, origin })
    }
    pub fn infantry_target_valid(&self, id: u32) -> bool {
        match self.get(id) {
            Some(Actor::Soldier(s)) => matches!(s.vitals.life, Life::Alive | Life::Downed),
            Some(Actor::Drone(d)) => !d.flight.dead,
            Some(_) => true,
            None => false,
        }
    }
    pub fn aim_infantry(
        &mut self,
        id: u32,
        now: f64,
        weapon_range: f64,
        squad: Option<&Squad>,
        collision: &mut CollisionWorld,
        visibility: &mut Visibility,
        rng: &mut SimulationRandom,
    ) -> Result<AimResult, &'static str> {
        if !clock(now) || !weapon_range.is_finite() || !(0.0..=1e6).contains(&weapon_range) {
            return Err("invalid retained infantry aim");
        }
        let s = self.soldier(id).ok_or("missing aiming soldier")?;
        if squad.is_some_and(|q| q.id != s.identity.squad) {
            return Err("infantry squad mismatch");
        }
        let mut points = [Vector3::ZERO; 3];
        let mut excluded = [0i64; 1];
        let target = if self.infantry_target_valid(s.fight.target as u32) {
            let (position, center, kind, n, ex) = match self.get(s.fight.target as u32).unwrap() {
                Actor::Soldier(other) => {
                    let pose = self.infantry_pose(other.identity.id).unwrap();
                    let exposed = pose.exposed_points();
                    points[..exposed.as_slice().len()].copy_from_slice(exposed.as_slice());
                    (
                        other.motion.position,
                        pose.center(),
                        TargetKind::Infantry {
                            over_cover: pose.over_cover(),
                            cover_height: pose.cover_height,
                        },
                        exposed.as_slice().len(),
                        0,
                    )
                }
                Actor::Vehicle(v) => {
                    points = v.exposed_points();
                    excluded[0] = v.id.into();
                    (v.position, v.center(), TargetKind::Other, 3, 1)
                }
                Actor::Structure(st) => {
                    points[0] = st.position + Vector3::Y;
                    (st.position, points[0], TargetKind::Structure, 1, 0)
                }
                Actor::Drone(d) => {
                    points[0] = d.flight.position;
                    (
                        d.flight.position,
                        d.flight.position,
                        TargetKind::Drone,
                        1,
                        0,
                    )
                }
                Actor::Projectile(p) => {
                    let pos = p.motion.position();
                    points[0] = pos + Vector3::Y;
                    (pos, points[0], TargetKind::Other, 1, 0)
                }
            };
            Some(Target {
                id: s.fight.target,
                position,
                center,
                kind,
                points: &points[..n],
                excluded: &excluded[..ex],
            })
        } else {
            None
        };
        let cover_fire = if s.fight.covering_until > now {
            Some(s.fight.covering_position)
        } else {
            squad
                .filter(|q| q.cover_fire_until > now)
                .map(|q| q.cover_fire_position)
        };
        let last_known = if matches!(s.identity.unit.as_str(), "mg_gunner" | "pkm")
            || !s.identity.mounted_weapon.is_empty()
        {
            squad
                .and_then(|q| q.last_known_near(self, s.motion.position, weapon_range, 5.0, now))
                .map(|c| c.report.position)
        } else {
            None
        };
        let mut aim = s.aim;
        let mut random = *rng;
        let result = aim.choose(
            AimInput {
                time: now,
                position: s.motion.position,
                eye: self.infantry_pose(id).unwrap().eye(),
                target,
                blind: s.weapon.blind,
                cache_obstruction: s.orders.pending_path || !s.is_moving(),
                cover_fire,
                last_known,
                weapon_range,
            },
            collision,
            visibility,
            &mut random,
        )?;
        self.soldier_mut(id).unwrap().aim = aim;
        *rng = random;
        Ok(result)
    }

    pub fn buddy_up(&self, id: u32, now: f64, squad: Option<&Squad>) -> Result<bool, &'static str> {
        if !clock(now) {
            return Err("invalid covering-fire time");
        }
        let s = self.soldier(id).ok_or("missing soldier")?;
        let Some(q) = squad else {
            return Ok(false);
        };
        if q.id != s.identity.squad {
            return Err("infantry squad mismatch");
        }
        Ok(q.members
            .iter()
            .filter_map(|id| self.soldier(*id))
            .any(|mate| {
                mate.identity.id != id
                    && mate.vitals.life == Life::Alive
                    && flat(mate.motion.position - s.motion.position).length() <= 14.0
                    && (mate.cover.at_cover && mate.weapon.peek_up
                        || now - mate.weapon.last_shot < 0.6)
            }))
    }

    pub fn call_cover(
        &mut self,
        id: u32,
        squad: Option<&Squad>,
        rng: &mut SimulationRandom,
    ) -> Result<CoverReply, &'static str> {
        let s = self.soldier(id).ok_or("missing soldier")?;
        let Some(q) = squad else {
            return Ok(CoverReply::default());
        };
        if q.id != s.identity.squad {
            return Err("infantry squad mismatch");
        }
        if s.fight.visible_targets.is_empty() {
            return Ok(CoverReply::default());
        }
        let mate = q
            .members
            .iter()
            .filter_map(|id| self.soldier(*id))
            .find(|mate| {
                mate.identity.id != id
                    && mate.vitals.life == Life::Alive
                    && mate.cover.at_cover
                    && !mate.weapon.peek_up
                    && mate.weapon.reload_timer <= 0.0
                    && mate.duty.kind == Task::Fight
                    && flat(mate.motion.position - s.motion.position).length() <= 10.0
            })
            .map(|mate| mate.identity.id);
        let Some(id) = mate else {
            return Ok(CoverReply::default());
        };
        let mate = self.soldier_mut(id).unwrap();
        mate.weapon.peek_timer = mate.weapon.peek_timer.min(0.2);
        let mut speech = None;
        if f64::from(rng.randf()) < 0.45 {
            let choice = (rng.randi() % 3) as u8;
            if mate.vitals.speech_cooldown <= 0.0 {
                mate.vitals.speech_cooldown = 2.6;
                speech = Some(choice);
            }
        }
        Ok(CoverReply {
            soldier: id,
            speech,
        })
    }
}
