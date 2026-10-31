//! Urgent infantry reactions read shared rounds, handlers and casualties in registration order.
use crate::actors::{Actor, Actors};
use crate::collision::CollisionWorld;
use crate::drone_reaction;
use crate::grenade_reaction::{self, Grenade, Mate, Reaction, Shell};
use crate::infantry::Infantry;
use crate::infantry_action::Action;
use crate::infantry_casualty::Released;
use crate::infantry_commands::Release;
use crate::infantry_controller::Task;
use crate::infantry_vitals::Life;
use crate::path_planner::PathPlanner;
use crate::projectile::Kind;
use crate::projectile_actor::Motion;
use crate::random::SimulationRandom;
use crate::spatial::{SpatialIndex, UNIT_CELL};
use crate::squad::Squad;
use crate::vector::Vector3;

#[derive(Clone, Copy, Debug)]
pub enum Reflex {
    Grenade,
    BusyGrenade,
    Shell,
    BusyShell,
    Drone,
}

#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct Response {
    pub handled: bool,
    pub cancel_path: bool,
    // 1..5 are smother, pickup, kick, shelter and dive; 6 is shell, 7 is drone.
    pub leaf: u8,
    // Three variants each: grenade notice, smother, shell, then drone.
    pub speech: Vec<u8>,
    pub stats: Vec<&'static str>,
}

fn say(s: &mut Infantry, cue: u8, force: bool, out: &mut Response) {
    if force || s.vitals.speech_cooldown <= 0.0 {
        s.vitals.speech_cooldown = 2.6;
        out.speech.push(cue);
    }
}
fn face(s: &mut Infantry, direction: Vector3) {
    if f64::from(direction.length_squared()) > 0.0001 {
        s.motion.yaw =
            f64::from(libm::atan2(-f64::from(direction.x), -f64::from(direction.z)) as f32);
    }
}
fn dive(
    s: &mut Infantry,
    from: Vector3,
    rng: &mut SimulationRandom,
    out: &mut Response,
) -> Result<(), &'static str> {
    s.start_dive(from, rng)?;
    out.cancel_path = true;
    out.stats.push("dive");
    Ok(())
}

impl Infantry {
    pub(crate) fn start_dive(
        &mut self,
        from: Vector3,
        rng: &mut SimulationRandom,
    ) -> Result<(), &'static str> {
        let direction = crate::grenade_task::dive_direction(self.motion.position, from, rng)?;
        self.stop_moving()?;
        self.controller.dive_direction = direction;
        self.controller.dive_timer = 0.5;
        face(self, direction);
        self.activity = 15;
        self.cover.at_cover = false;
        self.weapon.peek_up = false;
        Ok(())
    }
}

impl Actors {
    fn grenade_contacts(&self) -> Vec<Grenade> {
        self.iter_kind(crate::entities::Kind::Projectile)
            .filter_map(|a| {
                let Actor::Projectile(p) = a else {
                    return None;
                };
                let Motion::Ballistic(f) = &p.motion else {
                    return None;
                };
                if f.kind != Kind::Frag {
                    return None;
                }
                let free = self.soldier(p.handler).is_none_or(|h| {
                    h.vitals.life != Life::Alive
                        || !(matches!(
                            h.duty.kind,
                            Task::Smother | Task::GrenadeKick | Task::GrenadePickup
                        ) || matches!(
                            h.action.current,
                            Action::Kick { .. } | Action::Pickup { .. } | Action::Rethrow { .. }
                        ))
                });
                Some(Grenade {
                    id: p.id.into(),
                    position: f.position,
                    fuse: f.fuse,
                    held: p.held_by != 0,
                    gone: false,
                    flying: f.flying,
                    free,
                    smothered: p.smothered_by != 0,
                    thrown_back: p.thrown_back,
                })
            })
            .collect()
    }

    pub fn react_infantry(
        &mut self,
        id: u32,
        kind: Reflex,
        now: f64,
        armed: bool,
        mut squad: Option<&mut Squad>,
        units: &SpatialIndex,
        nav: &PathPlanner,
        collision: &mut CollisionWorld,
        rng: &mut SimulationRandom,
    ) -> Result<Response, &'static str> {
        let s = self.soldier(id).ok_or("missing reacting infantry")?;
        if !now.is_finite()
            || now.abs() > 1e12 - 100.0
            || units.cell_size() != UNIT_CELL
            || squad.as_ref().is_some_and(|q| q.id != s.identity.squad)
        {
            return Err("invalid infantry reaction context");
        }
        let mut next = s.clone();
        let mut random = *rng;
        let mut out = Response::default();
        let mut claimed = None;
        let mut release = None;
        match kind {
            Reflex::Grenade | Reflex::BusyGrenade => {
                let busy = matches!(kind, Reflex::BusyGrenade);
                let grenades = self.grenade_contacts();
                let noticed = next
                    .grenade_memory
                    .notice(s.motion.position, &grenades, !busy)?;
                if !busy {
                    next.fight.noticed_grenade = noticed.unwrap_or(0);
                }
                if let Some(gid) = noticed {
                    let g = *grenades.iter().find(|g| g.id == gid).unwrap();
                    say(&mut next, (random.randi() % 3) as u8, true, &mut out);
                    out.handled = true;
                    if busy {
                        dive(&mut next, g.position, &mut random, &mut out)?;
                        out.leaf = 5;
                    } else {
                        let mates: Vec<_> = self
                            .units_near(units, g.position, 4.5, -1)?
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
                                helpless: m.links.dragged_by != 0
                                    || matches!(
                                        m.duty.kind,
                                        Task::Rescue | Task::Heal | Task::Stretcher
                                    )
                                    || m.emplacement.structure != 0,
                            })
                            .collect();
                        let soldier = grenade_reaction::Soldier {
                            id: id.into(),
                            position: s.motion.position,
                            center: crate::infantry_pose::center(
                                s.motion.position,
                                s.posture,
                                s.vitals.life,
                            ),
                            yaw: s.motion.yaw,
                            team: s.identity.team.into(),
                            suppression: s.vitals.suppression,
                            posture: s.posture,
                            squad: squad.is_some(),
                            mounted: s.emplacement.structure != 0,
                            riding: s.links.vehicle != 0,
                            armed,
                        };
                        let reaction =
                            grenade_reaction::react(soldier, g, &mates, collision, &mut random)?;
                        match reaction {
                            Reaction::Smother | Reaction::Kick => {
                                let mount = self
                                    .structure(s.emplacement.structure as u32)
                                    .map(|m| m.position);
                                release = next.clear_duty(nav, mount);
                                next.duty.kind = if reaction == Reaction::Smother {
                                    Task::Smother
                                } else {
                                    Task::GrenadeKick
                                };
                                next.duty.entity = gid;
                                next.stop_moving()?;
                                out.cancel_path = true;
                                claimed = Some((gid as u32, reaction == Reaction::Smother));
                                if reaction == Reaction::Smother {
                                    next.duty.timer = now;
                                    next.cover.at_cover = false;
                                    next.weapon.peek_up = false;
                                    next.weapon.blind = false;
                                    let d = g.position - next.motion.position;
                                    face(&mut next, Vector3::new(d.x, 0.0, d.z));
                                    say(&mut next, (random.randi() % 3) as u8 + 3, true, &mut out);
                                    out.leaf = 1;
                                    out.stats.push("smother");
                                } else {
                                    out.leaf = 3;
                                    out.stats.push("grenade_kick");
                                }
                            }
                            Reaction::ThrowBack => {
                                next.duty.kind = Task::GrenadePickup;
                                next.duty.entity = gid;
                                next.stop_moving()?;
                                out.cancel_path = true;
                                out.leaf = 2;
                                out.stats.push("grenade_pickup");
                                claimed = Some((gid as u32, false));
                            }
                            Reaction::Shelter(body)
                                if u32::try_from(body)
                                    .ok()
                                    .and_then(|id| self.structure(id))
                                    .is_some() =>
                            {
                                next.vitals.hit_dirt_timer =
                                    next.vitals.hit_dirt_timer.max(g.fuse + 0.4);
                                next.stop_moving()?;
                                next.weapon.peek_up = false;
                                next.weapon.blind = false;
                                out.cancel_path = true;
                                out.leaf = 4;
                                out.stats.push("grenade_duck");
                            }
                            _ => {
                                dive(&mut next, g.position, &mut random, &mut out)?;
                                out.leaf = 5;
                            }
                        }
                    }
                }
            }
            Reflex::Shell | Reflex::BusyShell => {
                let rounds: Vec<_> = self
                    .iter_kind(crate::entities::Kind::Projectile)
                    .filter_map(|a| {
                        let Actor::Projectile(p) = a else {
                            return None;
                        };
                        let Motion::Ballistic(f) = &p.motion else {
                            return None;
                        };
                        (f.kind == Kind::Mortar).then_some(Shell {
                            id: p.id.into(),
                            target: f.target,
                            flight_time: f.shell_duration,
                            age: f.life,
                        })
                    })
                    .collect();
                let notices = next.grenade_memory.incoming_shells(
                    s.motion.position,
                    &rounds,
                    matches!(kind, Reflex::BusyShell),
                )?;
                for notice in notices {
                    say(
                        &mut next,
                        (random.randi() % 3) as u8 + 6,
                        notice.force_warning,
                        &mut out,
                    );
                    next.vitals.suppression = (next.vitals.suppression + 20.0).min(100.0);
                    if notice.dive {
                        dive(&mut next, notice.target, &mut random, &mut out)?;
                        out.handled = true;
                        out.leaf = 6;
                        break;
                    }
                    next.vitals.hit_dirt_timer = 2.5;
                }
            }
            Reflex::Drone => {
                let drones: Vec<_> = self
                    .iter_kind(crate::entities::Kind::Drone)
                    .filter_map(|a| {
                        let Actor::Drone(d) = a else {
                            return None;
                        };
                        Some(drone_reaction::Drone {
                            id: d.id.into(),
                            position: d.flight.position,
                            target: d.flight.target,
                            team: d.team.into(),
                            dead: d.flight.dead,
                            diving: d.flight.diving,
                        })
                    })
                    .collect();
                let reaction = next.drone_memory.react(
                    s.motion.position,
                    s.identity.team.into(),
                    &drones,
                    &mut random,
                )?;
                for warning in reaction.warnings {
                    say(&mut next, warning.variant + 9, true, &mut out);
                }
                if let Some(from) = reaction.dive_from {
                    dive(&mut next, from, &mut random, &mut out)?;
                }
                out.handled = next.controller.dive_timer > 0.0;
                if out.handled {
                    out.leaf = 7;
                }
            }
        }
        *self.soldier_mut(id).unwrap() = next;
        if let Some((grenade, smother)) = claimed {
            let Some(Actor::Projectile(g)) = self.get_mut(grenade) else {
                unreachable!();
            };
            g.handler = id;
            if smother {
                g.smothered_by = id;
            }
        }
        match release {
            Some(Release::Rescue(patient)) => self.release_links(
                id,
                Released {
                    patient,
                    ..Default::default()
                },
            ),
            Some(Release::Breach(squad_id)) => {
                if let Some(q) = squad
                    .as_mut()
                    .filter(|q| q.id == squad_id && q.breach_by == id)
                {
                    q.breach_by = 0;
                }
            }
            _ => {}
        }
        *rng = random;
        Ok(out)
    }
}
