//! Grenade duties update the soldier and held projectile without a scene callback.
use crate::actors::{Actor, Actors};
use crate::grenade_reaction::{self, Mate};
use crate::grenade_task::{self, Action as Next, Grenade, Input, Task as Approach};
use crate::infantry_action::{Action, Related};
use crate::infantry_controller::Task;
use crate::infantry_fire::MountedGun;
use crate::infantry_pose::Posture;
use crate::path_planner::PathPlanner;
use crate::projectile_actor::Motion;
use crate::random::SimulationRandom;
use crate::spatial::{SpatialIndex, UNIT_CELL};

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct Advanced {
    pub cancel_path: bool,
    pub dived: bool,
}

impl Actors {
    pub fn advance_infantry_grenade_task(
        &mut self,
        id: u32,
        dt: f64,
        now: f64,
        gun: Option<MountedGun>,
        units: &SpatialIndex,
        nav: &PathPlanner,
        rng: &mut SimulationRandom,
    ) -> Result<Advanced, &'static str> {
        let s = self.soldier(id).ok_or("missing grenade handler")?;
        if units.cell_size() != UNIT_CELL || gun.is_some_and(|g| !g.valid()) {
            return Err("invalid grenade task context");
        }
        let task = match s.duty.kind {
            Task::Smother => Approach::Smother,
            Task::GrenadeKick => Approach::Kick,
            Task::GrenadePickup => Approach::Pickup,
            _ => return Err("infantry is not handling a grenade"),
        };
        let mut grenade = match self.get(s.duty.entity as u32) {
            Some(Actor::Projectile(p)) => Some(p.clone()),
            _ => None,
        };
        let contact = if let Some(p) = &grenade {
            let Motion::Ballistic(f) = p.motion else {
                return Err("grenade task requires a ballistic round");
            };
            Some(Grenade {
                position: f.position,
                fuse: f.fuse,
                gone: false,
                held: p.held_by != 0,
                held_by_self: p.held_by == id,
            })
        } else {
            None
        };
        let step = grenade_task::advance(
            Input {
                task,
                position: s.motion.position,
                yaw: s.motion.yaw,
                time: now,
                started: s.duty.timer,
                dt,
                grenade: contact,
                mount: self.mount_turn(s, gun)?,
            },
            nav,
        )?;
        let mut next = s.clone();
        let mut random = *rng;
        let mut out = Advanced::default();
        next.motion.position = step.position;
        next.motion.yaw = step.yaw;
        match step.action {
            Next::Cancel => {
                next.duty.kind = Task::Fight;
                if task == Approach::Smother {
                    next.duty.entity = 0;
                    next.posture = Posture::Prone;
                    next.activity = 0;
                }
            }
            Next::DiveAway => {
                next.duty.kind = Task::Fight;
                next.start_dive(contact.unwrap().position, &mut random)?;
                out.cancel_path = true;
                out.dived = true;
            }
            Next::Smother | Next::DiveOnto => {
                next.posture = Posture::Prone;
                next.activity = if step.action == Next::Smother { 34 } else { 15 };
            }
            Next::Kick => {
                let p = grenade.as_ref().unwrap();
                let g = contact.unwrap();
                next.posture = Posture::Stand;
                next.duty.kind = Task::Fight;
                let soldier = grenade_reaction::Soldier {
                    id: id.into(),
                    position: next.motion.position,
                    center: crate::infantry_pose::center(
                        next.motion.position,
                        next.posture,
                        next.vitals.life,
                    ),
                    yaw: next.motion.yaw,
                    team: next.identity.team.into(),
                    suppression: next.vitals.suppression,
                    posture: next.posture,
                    squad: next.identity.squad != 0,
                    mounted: next.emplacement.structure != 0,
                    riding: next.links.vehicle != 0,
                    armed: !next.identity.weapon.is_empty(),
                };
                let round = grenade_reaction::Grenade {
                    id: p.id.into(),
                    position: g.position,
                    fuse: g.fuse,
                    held: g.held,
                    gone: false,
                    flying: false,
                    free: true,
                    smothered: p.smothered_by != 0,
                    thrown_back: p.thrown_back,
                };
                let mates: Vec<_> = self
                    .units_near(units, g.position, 6.0, -1)?
                    .into_iter()
                    .filter_map(|id| self.soldier(id))
                    .map(|m| Mate {
                        id: m.identity.id.into(),
                        position: m.motion.position,
                        center: crate::infantry_pose::center(
                            m.motion.position,
                            m.posture,
                            m.vitals.life,
                        ),
                        team: m.identity.team.into(),
                        life: m.vitals.life,
                        helpless: false,
                    })
                    .collect();
                let thrower = self
                    .get(p.thrower)
                    .filter(|a| a.identity().id != id)
                    .and_then(|a| {
                        let team = match a {
                            Actor::Soldier(s) => s.identity.team,
                            Actor::Vehicle(v) => v.team,
                            Actor::Structure(s) => s.team,
                            Actor::Projectile(p) => p.team,
                            Actor::Drone(d) => d.team,
                        };
                        (team != next.identity.team).then(|| a.position())
                    });
                let velocity = grenade_reaction::kick_velocity(soldier, round, &mates, thrower)?;
                next.begin_action(
                    Action::Kick {
                        grenade: p.id.into(),
                        velocity,
                    },
                    0.3,
                    Some(Related {
                        id: p.id.into(),
                        position: g.position,
                        gone: false,
                        holder: p.held_by.into(),
                    }),
                )?;
                out.cancel_path = true;
            }
            Next::Pickup => {
                next.activity = 2;
                next.posture = Posture::Stand;
                let p = grenade.as_mut().unwrap();
                p.pick_up(id)?;
                next.duty.kind = Task::Fight;
                next.begin_action(
                    Action::Pickup {
                        grenade: p.id.into(),
                    },
                    0.2,
                    Some(Related {
                        id: p.id.into(),
                        position: p.motion.position(),
                        gone: false,
                        holder: id.into(),
                    }),
                )?;
                out.cancel_path = true;
            }
            Next::Run => {
                next.activity = 2;
                next.posture = Posture::Stand;
            }
        }
        if !next.valid() {
            return Err("invalid advanced grenade handler");
        }
        *self.soldier_mut(id).unwrap() = next;
        if step.action == Next::Pickup {
            let p = grenade.unwrap();
            let id = p.id;
            *self.get_mut(id).unwrap() = Actor::Projectile(p);
        }
        *rng = random;
        Ok(out)
    }
}
