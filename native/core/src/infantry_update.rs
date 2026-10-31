//! Actor updates reuse the retained components without copying state through an engine binding.
use crate::collision::CollisionWorld;
use crate::infantry::{Goal, Infantry};
use crate::infantry_control::{self, Status};
use crate::infantry_controller::Task;
use crate::infantry_motion::{self, Door, MoveInput, Neighbor, Progress, StationaryInput};
use crate::infantry_orders::{Arrival, RouteOrder};
use crate::infantry_pose::Posture;
use crate::infantry_vitals::{FatigueInput, Life, Protection};
use crate::path_planner::PathPlanner;
use crate::random::SimulationRandom;
use crate::terrain::Terrain;
use crate::vector::Vector3;

#[derive(Clone, Copy, Debug)]
pub struct Movement {
    pub dt: f64,
    pub time: f64,
    pub speed: f64,
    pub danger: bool,
    pub has_doors: bool,
    pub door_still_closed: bool,
    pub mount: Option<(Vector3, f64)>,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct OpenDoor {
    pub id: u64,
    pub kicked: bool,
    pub by_position: Vector3,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Moved {
    pub moving: bool,
    pub route: Option<RouteOrder>,
    pub arrival: Arrival,
    pub opened_door: Option<OpenDoor>,
    pub speech: Option<u8>,
    pub slid: bool,
}

#[derive(Clone, Copy, Debug, Default)]
pub struct ActivityContext {
    pub task_target_exists: bool,
    pub mounted_exists: bool,
    pub chat_partner_exists: bool,
    pub ambush_target: bool,
}

fn clock(dt: f64, now: f64) -> bool {
    dt.is_finite() && (0.0..=10.0).contains(&dt) && now.is_finite() && now.abs() <= 1e12 - 100.0
}

impl Infantry {
    #[allow(clippy::too_many_arguments)]
    pub fn move_route(
        &mut self,
        i: Movement,
        nav: &PathPlanner,
        terrain: &Terrain,
        collision: &mut CollisionWorld,
        rng: &mut SimulationRandom,
        decks: &[u8],
        doors: &[Door],
    ) -> Result<Moved, &'static str> {
        if !self.valid()
            || !clock(i.dt, i.time)
            || self.orders.path_revision == i64::MAX as u64
            || doors.iter().any(|d| d.id > u32::MAX as u64)
        {
            return Err("invalid retained infantry movement");
        }
        let before = self.motion.position;
        let result = self.motion.step(
            MoveInput {
                dt: i.dt,
                time: i.time,
                speed: i.speed,
                base_y: self.orders.base_y,
                alive: self.vitals.life == Life::Alive,
                path_pending: self.orders.pending_path,
                cover_goal: self.orders.purpose == Goal::Cover,
                move_mode: i32::from(self.orders.move_mode),
                suppression: self.vitals.suppression,
                backwards: self.orders.backwards,
                danger: i.danger,
                has_doors: i.has_doors,
                door_still_closed: i.door_still_closed,
                mount: i.mount,
            },
            nav,
            terrain,
            collision,
            rng,
            decks,
            doors,
        )?;
        let mut moved = Moved {
            moving: matches!(result.progress, Progress::Moving | Progress::Repath),
            route: None,
            arrival: Arrival::None,
            opened_door: None,
            speech: result.speech,
            slid: result.slid,
        };
        if result.opened_door != 0 {
            // Nearby enemies hear the position before he steps through the opened door.
            moved.opened_door = Some(OpenDoor {
                id: result.opened_door,
                kicked: self.motion.door_kick,
                by_position: before,
            });
        }
        if result.speech.is_some() {
            self.vitals.speech_cooldown = 2.6;
        }
        match result.progress {
            Progress::Repath => {
                let destination = *self
                    .motion
                    .path
                    .last()
                    .ok_or("missing infantry repath destination")?;
                moved.route =
                    Some(self.go_to(destination, self.orders.purpose, self.orders.move_mode)?);
            }
            Progress::Arrived => moved.arrival = self.arrived(i.time, rng)?,
            _ => {}
        }
        Ok(moved)
    }

    pub fn compute_separation(
        &mut self,
        neighbors: &[Neighbor],
        rng: &mut SimulationRandom,
    ) -> Result<(), &'static str> {
        if !self.valid() || neighbors.iter().any(|n| n.id > u32::MAX as u64) {
            return Err("invalid retained infantry neighbors");
        }
        self.fight.separation = infantry_motion::separation(
            u64::from(self.identity.id),
            self.motion.position,
            self.vitals.life == Life::Alive
                && self.links.dragged_by == 0
                && !matches!(self.duty.kind, Task::Stretcher | Task::Captor),
            neighbors,
            rng,
        )?;
        Ok(())
    }

    #[allow(clippy::too_many_arguments)]
    pub fn stand(
        &mut self,
        dt: f64,
        now: f64,
        target_valid: bool,
        mount: Option<(Vector3, f64)>,
        nav: &PathPlanner,
        terrain: &Terrain,
        decks: &[u8],
    ) -> Result<(), &'static str> {
        if !self.valid() || !clock(dt, now) {
            return Err("invalid retained stationary infantry");
        }
        self.fight.shuffling = self.motion.stationary(
            StationaryInput {
                dt,
                time: now,
                base_y: self.orders.base_y,
                separation: self.fight.separation,
                prone: self.posture == Posture::Prone,
                at_cover: self.cover.at_cover,
                cover_position: self.cover.position,
                cover_normal: self.cover.normal,
                cover_kind: self.cover.kind,
                last_shot: self.weapon.last_shot,
                peek_up: self.weapon.peek_up,
                target_valid,
                sector: self.fight.sector,
                mount,
            },
            nav,
            terrain,
            decks,
        )?;
        Ok(())
    }

    pub fn recover(&mut self, dt: f64, now: f64) -> Result<(), &'static str> {
        self.vitals.recover(
            dt,
            now,
            Protection {
                at_cover: self.cover.at_cover,
                cover_kind: self.cover.kind,
                material: (self.cover.material >= 0).then_some(self.cover.material as u8),
                peek_up: self.weapon.peek_up,
                ..Default::default()
            },
        )
    }

    pub fn fatigue(&mut self, dt: f64) -> Result<(), &'static str> {
        self.vitals.fatigue(
            dt,
            FatigueInput {
                moving_or_diving: self.is_moving() || self.controller.dive_timer > 0.0,
                move_mode: i32::from(self.orders.move_mode),
                crawling: self.activity == 11,
                heavy_task: matches!(
                    self.duty.kind,
                    Task::Rescue | Task::Stretcher | Task::Smother
                ),
                carrying: self.duty.kind == Task::Stretcher || matches!(self.activity, 9 | 10),
                standing: self.posture == Posture::Stand,
            },
        )
    }

    pub fn finish_tick(
        &mut self,
        dt: f64,
        now: f64,
        ammunition: Option<i32>,
        leader: bool,
    ) -> Result<u8, &'static str> {
        if !self.valid() || !clock(dt, now) {
            return Err("invalid infantry end of tick");
        }
        let mut control = self.control;
        let result = control.motion_posture(
            dt,
            self.motion.position,
            self.vitals.life,
            self.posture,
            self.activity,
        )?;
        let flags = infantry_control::flags(Status {
            suppression: self.vitals.suppression,
            ammunition: ammunition
                .map(|capacity| (capacity, self.weapon.magazine + self.weapon.reserve)),
            time: now,
            last_shot: self.weapon.last_shot,
            life: self.vitals.life,
            leader,
            at_cover: self.cover.at_cover,
            cover_kind: self.cover.kind,
            peeking: self.weapon.peek_up,
            blind: self.weapon.blind,
            cover_height: self.cover.height,
            posture: result.posture,
        })?;
        self.control = control;
        self.posture = result.posture;
        self.activity = result.activity;
        self.flags = flags;
        Ok(result.corrected)
    }

    pub fn update_activity(&mut self, context: ActivityContext) {
        // These codes are the existing soldier activity labels carried in observations.
        let mut entity = 0;
        let mut doing = match self.vitals.life {
            Life::Downed => {
                if self.activity == 23 {
                    26
                } else if self.links.dragged_by != 0 || !self.links.carried_by.is_empty() {
                    27
                } else if self.activity == 11 {
                    18
                } else {
                    17
                }
            }
            Life::Surrender => 19,
            Life::Captive => 20,
            Life::Hidden => 22,
            Life::Dead => 0,
            Life::Alive => {
                let mut d = match self.duty.kind {
                    Task::Heal => 9,
                    Task::Rescue => 10,
                    Task::Stretcher => 11,
                    Task::Build => 12,
                    Task::Man => 13,
                    Task::Retreat => 14,
                    Task::Resupply => 15,
                    Task::Escort | Task::Captor => 16,
                    Task::Limp => 21,
                    Task::Tunnel => 22,
                    Task::Pilot => 23,
                    Task::GrenadePickup => 31,
                    Task::Smother => 45,
                    Task::GrenadeKick => 46,
                    Task::Breach => {
                        if self.duty.phase <= 1 {
                            48
                        } else {
                            47
                        }
                    }
                    _ => 0,
                };
                if matches!(d, 9 | 10 | 16) && context.task_target_exists {
                    entity = self.duty.entity;
                } else if d == 13 {
                    entity = if context.mounted_exists {
                        self.emplacement.structure
                    } else if context.task_target_exists {
                        self.duty.entity
                    } else {
                        0
                    };
                }
                if d == 0 || d == 13 {
                    d = match self.activity {
                        3 => {
                            if d == 13 {
                                13
                            } else if matches!(self.posture, Posture::LeanLeft | Posture::LeanRight)
                            {
                                33
                            } else if self.weapon.blind {
                                43
                            } else if self.cover.at_cover
                                && self.cover.kind == 1
                                && self.cover.height > 0.0
                                && self.emplacement.structure == 0
                            {
                                42
                            } else {
                                3
                            }
                        }
                        4 => 6,
                        5 => 7,
                        6 => 24,
                        24 => 29,
                        14 | 25 => 30,
                        15 | 16 => 34,
                        17 | 18 => 28,
                        26 => {
                            entity = if context.chat_partner_exists {
                                self.idle.partner
                            } else {
                                0
                            };
                            35
                        }
                        27..=32 => 36 + self.activity - 27,
                        33 => 46,
                        35 => 49,
                        36 => 51,
                        _ => d,
                    };
                }
                d
            }
        };
        if self.vitals.life == Life::Alive && doing == 0 {
            doing = if self.vitals.hit_dirt_timer > 0.0 && self.activity != 15 {
                50
            } else if self.flags & 2 != 0 {
                5
            } else if self.flags & 8 != 0 {
                25
            } else if self.flags & 1 != 0 {
                4
            } else if self.orders.purpose == Goal::Cover && self.is_moving() && self.cover.shifting
            {
                44
            } else if context.ambush_target {
                52
            } else if self.activity == 2 {
                2
            } else if self.activity == 1 {
                1
            } else if self.cover.kind == 3 {
                32
            } else if self.cover.kind != 0 {
                8
            } else {
                0
            };
        }
        self.doing = doing;
        self.doing_entity = entity;
    }
}
