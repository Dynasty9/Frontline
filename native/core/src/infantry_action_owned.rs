//! Completed infantry actions apply shared actor effects before the next soldier advances.
use crate::actors::{Actor, Actors};
use crate::drone::DroneFlight;
use crate::drone_actor::Drone;
use crate::entities::MAX_ENTITIES;
use crate::infantry::Infantry;
use crate::infantry_action::{Action, Related, Round};
use crate::infantry_controller::Task;
use crate::infantry_effects::{Damage, InfantryHit};
use crate::infantry_vitals::Life;
use crate::path_planner::PathPlanner;
use crate::projectile::Kind;
use crate::projectile_actor::{ballistic, ballistic_velocity, Projectile, Spawn};
use crate::random::SimulationRandom;
use crate::spatial::{SpatialIndex, UNIT_CELL};
use crate::squad::Squad;
use crate::vector::{normalized, Vector3};
use crate::vehicle::{Route, Vehicle};
use crate::vehicle_brain::{CrewEvent, CrewProfile};
use crate::vehicle_launch::SmokeProfile;

#[derive(Clone, Copy, Debug)]
pub struct Defense<'a> {
    pub smoke: SmokeProfile,
    pub crew: CrewProfile<'a>,
}
#[derive(Clone, Debug, PartialEq)]
pub enum Event {
    Spawn(u32),
    Launch {
        position: Vector3,
        direction: Vector3,
    },
    Mortar(Vector3),
    Door(u32),
    Melee {
        target: u32,
        position: Vector3,
        hit: InfantryHit,
    },
    Smoke {
        vehicle: u32,
        route: Route,
        manual: bool,
    },
}
#[derive(Clone, Debug, Default, PartialEq)]
pub struct Completed {
    pub events: Vec<Event>,
    pub stats: Vec<&'static str>,
    // The three throw calls, then the throwback call.
    pub speech: Option<u8>,
    pub cancel_path: bool,
}
fn flat(p: Vector3) -> Vector3 {
    Vector3::new(p.x, 0.0, p.z)
}
fn direction(yaw: f64) -> Vector3 {
    Vector3::new(-libm::sin(yaw) as f32, 0.0, -libm::cos(yaw) as f32)
}

impl Actors {
    fn rethrow_target(&self, id: u32, p: &Projectile, now: f64, squads: &[Squad]) -> Vector3 {
        let s = self.soldier(id).unwrap();
        if let Some(src) = self.get(p.thrower) {
            let team = match src {
                Actor::Soldier(s) => s.identity.team,
                Actor::Vehicle(v) => v.team,
                Actor::Structure(s) => s.team,
                Actor::Projectile(p) => p.team,
                Actor::Drone(d) => d.team,
            };
            if team != s.identity.team {
                return src.position();
            }
        }
        if let Some(contact) = squads
            .iter()
            .find(|q| q.id == s.identity.squad)
            .and_then(|q| q.last_known_near(self, s.motion.position, 30.0, 10.0, now))
        {
            return contact.report.position;
        }
        s.motion.position + direction(s.motion.yaw) * 18.0
    }
    fn warn_infantry_rocket<'a>(
        &mut self,
        id: u32,
        now: f64,
        nav: &PathPlanner,
        profile: impl Fn(&Vehicle) -> Defense<'a>,
        rng: &mut SimulationRandom,
        out: &mut Completed,
    ) -> Result<(), &'static str> {
        let Some(target) = self.projectile_warning_target(id)? else {
            return Ok(());
        };
        let from = self.get(id).unwrap().position();
        let defense = profile(self.vehicle(target).unwrap());
        let smoke = self.launch_vehicle_smoke(target, now, from, defense.smoke, rng)?;
        if smoke.is_empty() {
            return Ok(());
        }
        out.events
            .extend(smoke.into_iter().map(|p| Event::Spawn(p.id)));
        let response =
            self.vehicle_mut(target)
                .unwrap()
                .crew_threat(now, from, defense.crew, nav, rng)?;
        out.stats.push("veh_smoke");
        if response.event == Some(CrewEvent::Evade) {
            out.stats.push("veh_evade");
        }
        out.events.push(Event::Smoke {
            vehicle: target,
            route: response.route,
            manual: !defense.crew.automatic,
        });
        Ok(())
    }
    pub fn complete_infantry_action<'a>(
        &mut self,
        id: u32,
        now: f64,
        warhead: f64,
        squads: &mut [Squad],
        units: &SpatialIndex,
        nav: &PathPlanner,
        ammunition: impl Fn(&Infantry) -> (Option<i32>, bool),
        defense: impl Fn(&Vehicle) -> Defense<'a>,
        rng: &mut SimulationRandom,
    ) -> Result<Completed, &'static str> {
        if !now.is_finite()
            || !(0.0..=1e12 - 100.0).contains(&now)
            || !warhead.is_finite()
            || !(0.0..=1000.0).contains(&warhead)
            || units.cell_size() != UNIT_CELL
        {
            return Err("invalid infantry action context");
        }
        let s = self.soldier(id).ok_or("missing acting infantry")?;
        let related = self
            .get(crate::infantry_execution::action_id(s.action.current) as u32)
            .map(|a| Related {
                id: a.identity().id.into(),
                position: a.position(),
                gone: false,
                holder: if let Actor::Projectile(p) = a {
                    p.held_by.into()
                } else {
                    0
                },
            });
        let mut next = s.clone();
        let mut random = *rng;
        let step = next.action_tick(related, &mut random)?;
        let effect = step.effect;
        let mut out = Completed {
            cancel_path: step.cancel_path,
            speech: step.speech,
            ..Default::default()
        };
        // Reserve enough identities for the round and an immediate four-round smoke response.
        let births = match effect {
            Action::Launch { .. } => 5,
            Action::Throw(_)
            | Action::ThrowIn { .. }
            | Action::Mortar { .. }
            | Action::LaunchDrone { .. } => 1,
            _ => 0,
        };
        if births > 0
            && (self.entities().next_id() + births - 1 > u32::MAX as u64
                || self.entities().len() > MAX_ENTITIES - births as usize)
        {
            return Err("infantry action exceeds match limits");
        }
        let position = next.motion.position;
        let facing = direction(next.motion.yaw);
        let team = next.identity.team;
        let mut spawn = None;
        match effect {
            Action::Throw(t) => {
                let from = position + Vector3::Y * 1.7 + facing * 0.3;
                let mut f = ballistic(
                    if t.round == Round::Smoke {
                        Kind::Smoke
                    } else {
                        Kind::Frag
                    },
                    from,
                    ballistic_velocity(from, t.position),
                );
                f.fuse = if t.round == Round::Smoke { 1.0 } else { t.fuse };
                spawn = Some(Actor::Projectile(Projectile::from_spawn(
                    1,
                    Spawn {
                        flight: f,
                        team,
                        thrower: id,
                        called_by: 0,
                    },
                )?));
            }
            Action::ThrowIn {
                position: target,
                fuse,
            } => {
                let from = position + Vector3::Y * 1.45 + facing * 0.35;
                let t = (f64::from(flat(target - from).length()) / 11.0).clamp(0.3, 0.75);
                let velocity =
                    (target - from) / t as f32 + Vector3::new(0.0, (9.0 * t) as f32, 0.0);
                let mut f = ballistic(Kind::Frag, from, velocity);
                f.fuse = fuse;
                spawn = Some(Actor::Projectile(Projectile::from_spawn(
                    1,
                    Spawn {
                        flight: f,
                        team,
                        thrower: id,
                        called_by: 0,
                    },
                )?));
            }
            Action::Launch { target } => {
                let mut pose = self.infantry_pose(id).unwrap();
                pose.position = position;
                pose.posture = next.posture;
                let from = pose.eye() + facing * 0.7 + Vector3::Y * 0.1;
                let mut aim = self
                    .actor_center(target as u32)
                    .ok_or("missing rocket target")?;
                let distance = f64::from(from.distance(aim));
                if let Some(v) = self.vehicle(target as u32) {
                    aim += v.velocity * (distance / 60.0) as f32;
                }
                aim += Vector3::new(
                    random.randf_range(-1.0, 1.0),
                    random.randf_range(-0.5, 0.5),
                    random.randf_range(-1.0, 1.0),
                ) * distance as f32
                    * 0.025;
                let heading = normalized(aim - from);
                spawn = Some(Actor::Projectile(Projectile::from_spawn(
                    1,
                    Spawn {
                        flight: ballistic(Kind::Rocket, from, heading * 60.0),
                        team,
                        thrower: id,
                        called_by: 0,
                    },
                )?));
                out.events.push(Event::Launch {
                    position: from,
                    direction: heading,
                });
            }
            Action::Mortar {
                position: target,
                round,
            } => {
                let from = position + Vector3::Y;
                let distance = f64::from(flat(target - from).length());
                let scatter = 1.2 + distance * 0.03;
                let angle = f64::from(random.randf()) * std::f64::consts::TAU;
                let radius = libm::sqrt(f64::from(random.randf())) * scatter;
                let target = Vector3::new(
                    (f64::from(target.x) + libm::cos(angle) * radius) as f32,
                    0.05,
                    (f64::from(target.z) + libm::sin(angle) * radius) as f32,
                );
                let mut f = ballistic(
                    if round == Round::Smoke {
                        Kind::MortarSmoke
                    } else {
                        Kind::Mortar
                    },
                    from,
                    Vector3::ZERO,
                );
                f.origin = from;
                f.target = target;
                f.shell_duration = 2.4 + distance / 40.0;
                spawn = Some(Actor::Projectile(Projectile::from_spawn(
                    1,
                    Spawn {
                        flight: f,
                        team,
                        thrower: id,
                        called_by: 0,
                    },
                )?));
                out.events.push(Event::Mortar(from));
                out.stats.push("mortar_round");
            }
            Action::LaunchDrone { target } => {
                let from = position + Vector3::Y + facing * 0.8;
                let drone = Drone {
                    id: 1,
                    team,
                    operator: id,
                    target: target as u32,
                    operator_at_spawn: id,
                    target_at_spawn: target as u32,
                    warhead,
                    flight: DroneFlight::new(from, 0.0),
                };
                if !drone.valid() {
                    return Err("invalid launched drone");
                }
                spawn = Some(Actor::Drone(drone));
            }
            _ => {}
        }
        let mut changed_round = None;
        match effect {
            Action::Kick { grenade, velocity } => {
                if let Some(Actor::Projectile(p)) = self.get(grenade as u32) {
                    let mut p = p.clone();
                    p.kick(velocity)?;
                    changed_round = Some(p);
                    out.stats.push("kicked");
                }
            }
            Action::Pickup { grenade } => {
                if let Some(Actor::Projectile(p)) = self.get(grenade as u32) {
                    let target = self.rethrow_target(id, p, now, squads);
                    let related = Related {
                        id: grenade,
                        position: p.motion.position(),
                        gone: false,
                        holder: id.into(),
                    };
                    next.begin_action(
                        Action::Rethrow {
                            grenade,
                            position: target,
                        },
                        0.3,
                        Some(related),
                    )?;
                    out.cancel_path = true;
                }
            }
            Action::Rethrow {
                grenade,
                position: target,
            } => {
                if let Some(Actor::Projectile(p)) = self.get(grenade as u32) {
                    let mut p = p.clone();
                    p.release_throw(id, team, position, target)?;
                    changed_round = Some(p);
                    out.stats.push("throwback");
                }
            }
            _ => {}
        }
        *self.soldier_mut(id).unwrap() = next;
        if let Some(p) = changed_round {
            let id = p.id;
            *self.get_mut(id).unwrap() = Actor::Projectile(p);
        }
        if let Some(actor) = spawn {
            let spawned = self.spawn(actor)?;
            let later = std::mem::take(&mut out.events);
            out.events.push(Event::Spawn(spawned));
            if matches!(effect, Action::ThrowIn { .. }) {
                self.soldier_mut(id).unwrap().entry.grenade = spawned.into();
            }
            if matches!(effect, Action::LaunchDrone { .. }) {
                let s = self.soldier_mut(id).unwrap();
                s.fight.controlled_drone = spawned.into();
                s.duty.kind = Task::Pilot;
            }
            if matches!(effect, Action::Launch { .. }) {
                self.warn_infantry_rocket(spawned, now, nav, defense, &mut random, &mut out)?;
            }
            out.events.extend(later);
        }
        match effect {
            Action::DoorKick { door, .. } => {
                let opened = match self.get_mut(door as u32) {
                    Some(Actor::Structure(st)) => st.open_door(),
                    _ => false,
                };
                if opened {
                    let door_position = self.structure(door as u32).unwrap().position;
                    for who in self.units_near(units, door_position, 16.0, -1)? {
                        if let Some(other) = self.soldier(who).filter(|s| {
                            s.identity.team != team
                                && s.identity.team >= 0
                                && s.vitals.life == Life::Alive
                        }) {
                            if let Some(q) =
                                squads.iter_mut().find(|q| q.id == other.identity.squad)
                            {
                                q.report_position(position, now)?;
                            }
                        }
                    }
                    out.events.push(Event::Door(door as u32));
                    out.stats.push("door_kicked");
                }
            }
            Action::Melee { target } => {
                if let Some(victim) = self.soldier(target as u32).filter(|s| {
                    s.vitals.life == Life::Alive
                        && f64::from(flat(s.motion.position - position).length()) <= 2.4
                }) {
                    let target_position = victim.motion.position;
                    let (stock, bearer) = ammunition(victim);
                    let amount = f64::from(random.randf_range(45.0, 75.0));
                    let hit = self.damage_infantry(
                        target as u32,
                        Damage {
                            amount,
                            source: id,
                            direction: normalized(target_position - position),
                            kind: "melee",
                            now,
                            ammunition: stock,
                            bearer,
                            blame: None,
                        },
                        squads,
                        &mut random,
                    )?;
                    let s = self.soldier_mut(target as u32).unwrap();
                    s.vitals.suppression = (s.vitals.suppression + 40.0).min(100.0);
                    out.events.push(Event::Melee {
                        target: target as u32,
                        position: target_position + Vector3::Y * 1.2,
                        hit,
                    });
                }
            }
            _ => {}
        }
        *rng = random;
        Ok(out)
    }
}
