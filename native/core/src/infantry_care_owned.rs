//! A medic updates the shared casualty immediately; later soldiers see the released claim.
use crate::actors::Actors;
use crate::infantry::Goal;
use crate::infantry_controller::Task;
use crate::infantry_cover::{CoverIntent, CoverWorld};
use crate::infantry_fire::MountedGun;
use crate::infantry_medicine::{self as medicine, Heal, Rescue, Treatment};
use crate::infantry_pose::Posture;
use crate::infantry_travel_owned::Event;
use crate::infantry_vitals::Life;
use crate::random::SimulationRandom;
use crate::spatial::{SpatialIndex, DOOR_CELL, STRUCTURE_CELL, UNIT_CELL};
use crate::squad::Squad;
use crate::vector::{turn_yaw, Vector3};

#[derive(Clone, Copy, Debug)]
pub struct Profile<'a> {
    pub heal_rate: f64,
    pub medicine_upgrade: bool,
    pub weapon_range: f64,
    pub unarmed: bool,
    pub gun: Option<MountedGun>,
    pub restored_weapon: Option<(&'a str, i32)>,
}
#[derive(Clone, Debug, Default, PartialEq)]
pub struct Care {
    pub movement: Vec<Event>,
    pub drag_speech: Option<u8>,
    pub revived: Option<(u32, u8)>,
    pub rejoin: bool,
}
fn flat(p: Vector3) -> Vector3 {
    Vector3::new(p.x, 0.0, p.z)
}

impl Actors {
    fn end_infantry_rescue(&mut self, id: u32) {
        let who = self.soldier(id).unwrap().duty.entity as u32;
        if let Some(patient) = self.soldier_mut(who) {
            if patient.links.dragged_by == id.into() {
                patient.links.dragged_by = 0;
            }
            if patient.links.rescue_claimed == id.into() {
                patient.links.rescue_claimed = 0;
            }
        }
        let s = self.soldier_mut(id).unwrap();
        s.duty.kind = Task::Fight;
        s.duty.entity = 0;
        s.orders.backwards = false;
        s.cover.at_cover = false;
        s.cover.evaluate_at = 0.0;
    }

    pub fn advance_infantry_care(
        &mut self,
        id: u32,
        dt: f64,
        now: f64,
        profile: Profile<'_>,
        squads: &mut [Squad],
        world: &mut CoverWorld<'_>,
        doors: &SpatialIndex,
        rng: &mut SimulationRandom,
    ) -> Result<Care, &'static str> {
        let duration = medicine::heal_time(profile.heal_rate, profile.medicine_upgrade)?;
        if !dt.is_finite()
            || !(0.0..=10.0).contains(&dt)
            || !now.is_finite()
            || now.abs() > 1e12 - 100.0
            || !profile.weapon_range.is_finite()
            || !(0.0..=1_000_000.0).contains(&profile.weapon_range)
            || profile.gun.is_some_and(|g| !g.valid())
            || profile.restored_weapon.is_some_and(|(k, n)| {
                k.is_empty() || k.len() > 128 || k.contains('\0') || !(0..=1_000_000).contains(&n)
            })
            || world.nav.side() != world.terrain.n
            || world.units.cell_size() != UNIT_CELL
            || world.structures.cell_size() != STRUCTURE_CELL
            || doors.cell_size() != DOOR_CELL
            || !world.deck.is_empty() && world.deck.len() != world.terrain.n * world.terrain.n
            || !world.heat.is_empty()
                && world.heat.len() != (world.terrain.n.div_ceil(4) + 1).pow(2)
        {
            return Err("invalid infantry medical context");
        }
        let s = self.soldier(id).ok_or("missing medic")?;
        let task = s.duty.kind;
        if !matches!(task, Task::Rescue | Task::Heal | Task::Limp) {
            return Err("infantry is not on a medical duty");
        }
        let mut out = Care::default();
        if task == Task::Limp {
            self.soldier_mut(id).unwrap().posture = Posture::Stand;
            let moving = self.move_infantry(
                id,
                dt,
                now,
                1.3,
                profile.gun,
                squads,
                world,
                doors,
                rng,
                &mut out.movement,
            )?;
            let s = self.soldier_mut(id).unwrap();
            s.activity = if moving { 22 } else { 0 };
            if !moving {
                s.duty.kind = Task::Fight;
                out.rejoin = true;
            }
            return Ok(out);
        }
        let target = s.duty.entity as u32;
        let patient = self.soldier(target);
        let valid = patient.is_some_and(|p| {
            if task == Task::Heal {
                p.vitals.life == Life::Alive && p.vitals.hp < p.vitals.max_hp
            } else {
                p.vitals.life == Life::Downed
                    && (p.links.dragged_by == 0 || p.links.dragged_by == id.into())
                    && p.links.carried_by.is_empty()
            }
        });
        if !valid {
            if task == Task::Rescue {
                self.end_infantry_rescue(id);
            } else {
                self.soldier_mut(id).unwrap().duty.kind = Task::Fight;
            }
            return Ok(out);
        }
        let patient_position = patient.unwrap().motion.position;
        let mut treatment = Treatment {
            phase: s.duty.phase,
            timer: s.duty.timer,
        };
        if task == Task::Heal {
            let decision = treatment.heal(
                true,
                s.motion.position,
                patient_position,
                s.is_moving(),
                duration,
            )?;
            let s = self.soldier_mut(id).unwrap();
            s.duty.phase = treatment.phase;
            s.duty.timer = treatment.timer;
            match decision {
                Heal::Cancel => unreachable!(),
                Heal::Approach { repath } => {
                    if repath {
                        out.movement.push(Event::Route(s.go_to(
                            patient_position,
                            Goal::Task,
                            0,
                        )?));
                    }
                    let speed = self.infantry_speed(id, now, squads);
                    self.move_infantry(
                        id,
                        dt,
                        now,
                        speed,
                        profile.gun,
                        squads,
                        world,
                        doors,
                        rng,
                        &mut out.movement,
                    )?;
                    self.choose_infantry_activity(id, true, now, squads);
                }
                Heal::Start => {
                    s.stop_moving()?;
                    out.movement.push(Event::CancelPath);
                }
                Heal::Treat => {
                    self.treat_infantry_pose(id, patient_position, dt, profile.gun)?;
                    let done = treatment.treat(dt)?;
                    self.soldier_mut(id).unwrap().duty.timer = treatment.timer;
                    if done {
                        let p = self.soldier_mut(target).unwrap();
                        p.vitals.hp = p.vitals.max_hp;
                        self.soldier_mut(id).unwrap().duty.kind = Task::Fight;
                    }
                }
            }
            return Ok(out);
        }
        let decision = treatment.rescue(
            true,
            s.motion.position,
            patient_position,
            s.is_moving(),
            s.orders.goal,
        )?;
        self.soldier_mut(id).unwrap().duty.phase = treatment.phase;
        match decision {
            Rescue::Cancel => unreachable!(),
            Rescue::Approach { repath } => {
                let s = self.soldier_mut(id).unwrap();
                s.posture = Posture::Stand;
                if repath {
                    out.movement
                        .push(Event::Route(s.go_to(patient_position, Goal::Task, 2)?));
                }
                self.move_infantry(
                    id,
                    dt,
                    now,
                    4.8,
                    profile.gun,
                    squads,
                    world,
                    doors,
                    rng,
                    &mut out.movement,
                )?;
                self.soldier_mut(id).unwrap().activity = 2;
            }
            Rescue::Claim => {
                self.soldier_mut(id).unwrap().posture = Posture::Stand;
                self.soldier_mut(target).unwrap().links.dragged_by = id.into();
                let s = self.soldier(id).unwrap();
                let squad = squads.iter().find(|q| q.id == s.identity.squad);
                let threats = self.infantry_threats(id, now, squad)?;
                let away = -s.threat_direction(&threats)?;
                let anchor = medicine::safe_anchor(
                    patient_position,
                    away,
                    squad
                        .filter(|q| !q.members.is_empty())
                        .map(|q| q.order_position),
                    world.nav,
                )?;
                let search = self.find_infantry_cover(
                    s,
                    CoverIntent {
                        now,
                        anchor,
                        radius: 8.0,
                        weapon_range: profile.weapon_range,
                        unarmed: profile.unarmed,
                    },
                    true,
                    &threats,
                    squad,
                    world,
                )?;
                let shelter = search.choice.map_or(anchor, |c| c.position);
                let s = self.soldier_mut(id).unwrap();
                s.duty.position = shelter;
                out.movement.push(Event::Stat("drag"));
                out.movement
                    .push(Event::Route(s.go_to(shelter, Goal::Task, 0)?));
                if s.motion.path.is_empty() {
                    treatment.finish_drag(false, duration)?;
                    s.duty.phase = treatment.phase;
                    s.duty.timer = treatment.timer;
                }
                s.vitals.speech_cooldown = 2.6;
                out.drag_speech = Some((rng.randi() % 4) as u8);
            }
            Rescue::Drag => {
                let s = self.soldier_mut(id).unwrap();
                s.orders.backwards = true;
                s.posture = Posture::Stand;
                let moving = self.move_infantry(
                    id,
                    dt,
                    now,
                    1.15,
                    profile.gun,
                    squads,
                    world,
                    doors,
                    rng,
                    &mut out.movement,
                )?;
                let s = self.soldier(id).unwrap();
                let pose = medicine::drag_pose(
                    s.motion.position,
                    s.motion.yaw,
                    s.motion.last_direction,
                    dt,
                    self.mount_turn(s, profile.gun)?,
                )?;
                let s = self.soldier_mut(id).unwrap();
                s.motion.yaw = pose.yaw;
                s.activity = 9;
                if !moving {
                    treatment.finish_drag(false, duration)?;
                    s.duty.phase = treatment.phase;
                    s.duty.timer = treatment.timer;
                    s.orders.backwards = false;
                }
                let p = self.soldier_mut(target).unwrap();
                p.motion.position = pose.patient;
                p.motion.yaw = pose.yaw;
            }
            Rescue::Treat => {
                self.soldier_mut(target).unwrap().links.dragged_by = 0;
                self.treat_infantry_pose(id, patient_position, dt, profile.gun)?;
                let done = treatment.treat(dt)?;
                self.soldier_mut(id).unwrap().duty.timer = treatment.timer;
                if done {
                    let cue = self.soldier_mut(target).unwrap().revive(
                        false,
                        profile.restored_weapon,
                        rng,
                    )?;
                    out.revived = Some((target, cue));
                    self.end_infantry_rescue(id);
                }
            }
        }
        Ok(out)
    }

    fn treat_infantry_pose(
        &mut self,
        id: u32,
        patient: Vector3,
        dt: f64,
        gun: Option<MountedGun>,
    ) -> Result<(), &'static str> {
        let s = self.soldier(id).unwrap();
        let yaw = turn_yaw(
            s.motion.yaw,
            flat(patient - s.motion.position),
            s.motion.position,
            dt,
            8.0,
            self.mount_turn(s, gun)?,
        );
        let s = self.soldier_mut(id).unwrap();
        s.activity = 8;
        s.posture = Posture::Crouch;
        s.motion.yaw = yaw;
        Ok(())
    }
}
