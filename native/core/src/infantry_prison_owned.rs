//! Captors and prisoners share routes, destination ownership and capture credit.
use crate::actors::Actors;
use crate::battle_stats::BattleStats;
use crate::entities::Kind;
use crate::infantry::Goal;
use crate::infantry::Infantry;
use crate::infantry_commands::Command;
use crate::infantry_control::HiddenReason;
use crate::infantry_controller::Task;
use crate::infantry_cover::CoverWorld;
use crate::infantry_duties::{self as duties, Captor, Duty, Guard};
use crate::infantry_fire::MountedGun;
use crate::infantry_pose::Posture;
use crate::infantry_rejoin::Rejoined;
use crate::infantry_travel_owned::Event as Movement;
use crate::infantry_vitals::Life;
use crate::path_planner::PathPlanner;
use crate::random::SimulationRandom;
use crate::spatial::{SpatialIndex, DOOR_CELL, UNIT_CELL};
use crate::squad::Squad;
use crate::vector::Vector3;

#[derive(Clone, Copy, Debug)]
pub struct Profile {
    pub value: f64,
    pub fallback_depot: u32,
    pub gun: Option<MountedGun>,
}

#[derive(Clone, Copy, Debug)]
pub struct CustodyProfile<'a> {
    pub mission: bool,
    pub depots: [u32; 2],
    pub restored_weapon: Option<(&'a str, i32)>,
    pub squad_name: &'a str,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum IntelMode {
    March,
    Held,
    Interrogation,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum Custody {
    Unchanged,
    Freed(Rejoined),
    Assigned {
        captor: u32,
        route: crate::infantry_orders::RouteOrder,
    },
    LostGuard,
    Intelligence(IntelMode),
}
#[derive(Clone, Copy, Debug, PartialEq)]
pub enum Event {
    Movement(u32, Movement),
    Taken {
        prisoner: u32,
        captor: u32,
        destination: u32,
    },
    Speech {
        captor: u32,
        cue: u8,
    },
    Interrogation {
        prisoner: u32,
        destination: u32,
    },
    CapturedAlert(u32),
}
fn flat(p: Vector3) -> Vector3 {
    Vector3::new(p.x, 0.0, p.z)
}

impl Actors {
    pub fn advance_prisoner(
        &mut self,
        id: u32,
        now: f64,
        profile: CustodyProfile<'_>,
        players: &[(i32, i8)],
        squads: &mut Vec<Squad>,
        next_squad: &mut u64,
        battle: &mut BattleStats,
        units: &SpatialIndex,
        bearer: impl Fn(&Infantry) -> bool,
    ) -> Result<Custody, &'static str> {
        if !now.is_finite()
            || now.abs() > 1e12 - 100.0
            || units.cell_size() != UNIT_CELL
            || profile.restored_weapon.is_some_and(|(key, mag)| {
                key.is_empty()
                    || key.len() > 128
                    || key.contains('\0')
                    || !(0..=1_000_000).contains(&mag)
            })
        {
            return Err("invalid prisoner custody context");
        }
        let p = self.soldier(id).ok_or("missing prisoner")?;
        if !(0..=1).contains(&p.identity.team) {
            return Err("prisoner has no side");
        }
        let team = p.identity.team;
        let position = p.motion.position;
        let guarded = self.soldier(p.links.captor as u32).is_some_and(|c| {
            c.vitals.life == Life::Alive
                && c.duty.kind == Task::Captor
                && c.duty.entity == id.into()
        });
        match p.vitals.life {
            Life::Surrender if !guarded => {
                let rescued = self
                    .units_near(units, position, 6.0, -1)?
                    .into_iter()
                    .filter_map(|who| self.soldier(who))
                    .any(|s| {
                        s.identity.id != id
                            && s.identity.team == team
                            && s.vitals.life == Life::Alive
                            && !bearer(s)
                    });
                if rescued {
                    let previous = p.clone();
                    let p = self.soldier_mut(id).unwrap();
                    p.links.captor = 0;
                    p.vitals.life = Life::Alive;
                    p.activity = 0;
                    p.identity.weapon = profile
                        .restored_weapon
                        .map_or_else(String::new, |w| w.0.into());
                    if let Some((_, magazine)) = profile.restored_weapon {
                        p.weapon.magazine = magazine;
                        p.weapon.reserve = magazine;
                    }
                    p.vitals.speech_cooldown = 2.6;
                    let joined = self.rejoin_infantry(
                        id,
                        now,
                        players,
                        squads,
                        next_squad,
                        battle,
                        profile.squad_name,
                    );
                    match joined {
                        Ok(joined) => return Ok(Custody::Freed(joined)),
                        Err(error) => {
                            *self.soldier_mut(id).unwrap() = previous;
                            return Err(error);
                        }
                    }
                }
                let mut closest = None;
                let mut distance = 35.0;
                for who in self.units_near(units, position, 35.0, -1)? {
                    let Some(c) = self.soldier(who).filter(|c| {
                        c.identity.team != team
                            && c.identity.team >= 0
                            && c.vitals.life == Life::Alive
                            && c.duty.kind == Task::Fight
                            && !c.identity.weapon.is_empty()
                            && !bearer(c)
                    }) else {
                        continue;
                    };
                    let d = f64::from(flat(c.motion.position - position).length());
                    if d < distance {
                        distance = d;
                        closest = Some(who);
                    }
                }
                if profile.mission {
                    if let Some(who) = closest {
                        let c = self.soldier(who).unwrap();
                        let prison = self
                            .prison_destination(
                                c.identity.team,
                                position,
                                profile.depots[c.identity.team as usize],
                            )
                            .and_then(|destination| self.structure(destination));
                        if prison.is_none_or(|st| {
                            f64::from(flat(st.position - position).length()) > 200.0
                        }) {
                            closest = None;
                        }
                    }
                }
                if let Some(who) = closest {
                    let mut c = self.soldier(who).unwrap().clone();
                    c.duty.kind = Task::Captor;
                    c.duty.entity = id.into();
                    c.duty.partner = 0;
                    c.duty.phase = 0;
                    c.orders.backwards = false;
                    let route = c.go_to(position, Goal::Task, 1)?;
                    *self.soldier_mut(who).unwrap() = c;
                    self.soldier_mut(id).unwrap().links.captor = who.into();
                    Ok(Custody::Assigned { captor: who, route })
                } else {
                    self.soldier_mut(id).unwrap().links.captor = 0;
                    Ok(Custody::Unchanged)
                }
            }
            Life::Captive => {
                if !guarded {
                    let mut next = p.clone();
                    next.links.captor = 0;
                    next.vitals.life = Life::Surrender;
                    next.stop_moving()?;
                    *self.soldier_mut(id).unwrap() = next;
                    Ok(Custody::LostGuard)
                } else if p.links.intel_left > 0 && now > p.links.intel_timer {
                    let p = self.soldier_mut(id).unwrap();
                    p.links.intel_left -= 1;
                    p.links.intel_timer = now + 10.0;
                    Ok(Custody::Intelligence(IntelMode::March))
                } else {
                    Ok(Custody::Unchanged)
                }
            }
            Life::Hidden
                if matches!(
                    p.control.hidden,
                    HiddenReason::Held | HiddenReason::Interrogation
                ) && p.links.intel_left > 0
                    && now > p.links.intel_timer =>
            {
                let p = self.soldier_mut(id).unwrap();
                p.links.intel_left -= 1;
                p.links.intel_timer = now + 7.0;
                Ok(Custody::Intelligence(
                    if p.control.hidden == HiddenReason::Held {
                        IntelMode::Held
                    } else {
                        IntelMode::Interrogation
                    },
                ))
            }
            _ => Ok(Custody::Unchanged),
        }
    }

    fn prison_destination(&self, team: i8, position: Vector3, fallback: u32) -> Option<u32> {
        let mut best = None;
        let mut distance = 1e9;
        for actor in self.iter_kind(Kind::Structure) {
            let crate::actors::Actor::Structure(st) = actor else {
                unreachable!()
            };
            if st.team != team
                || !st.built
                || !(st.kind == "fob" || team == 1 && st.kind == "tunnel")
            {
                continue;
            }
            let d = f64::from(flat(st.position - position).length())
                - if st.kind == "tunnel" { 40.0 } else { 0.0 };
            if d < distance {
                distance = d;
                best = Some(st.id);
            }
        }
        best.or_else(|| self.structure(fallback).map(|st| st.id))
    }

    pub fn advance_infantry_captor(
        &mut self,
        id: u32,
        dt: f64,
        now: f64,
        profile: Profile,
        battle: &mut BattleStats,
        squads: &mut [Squad],
        world: &mut CoverWorld<'_>,
        doors: &SpatialIndex,
        rng: &mut SimulationRandom,
    ) -> Result<Vec<Event>, &'static str> {
        if !dt.is_finite()
            || !(0.0..=10.0).contains(&dt)
            || !now.is_finite()
            || now.abs() > 1e12 - 100.0
            || !profile.value.is_finite()
            || !(0.0..=1e12).contains(&profile.value)
            || profile.gun.is_some_and(|g| !g.valid())
            || world.nav.side() != world.terrain.n
            || world.units.cell_size() != UNIT_CELL
            || doors.cell_size() != DOOR_CELL
            || !world.deck.is_empty() && world.deck.len() != world.terrain.n * world.terrain.n
        {
            return Err("invalid captor context");
        }
        let s = self.soldier(id).ok_or("missing captor")?;
        if s.duty.kind != Task::Captor {
            return Err("infantry is not guarding a prisoner");
        }
        let prisoner = s.duty.entity as u32;
        let p = self.soldier(prisoner).filter(|p| {
            matches!(p.vitals.life, Life::Surrender | Life::Captive) && p.links.captor == id.into()
        });
        let mut out = Vec::new();
        let Some(p) = p else {
            let result = self.soldier_mut(id).unwrap().command(
                Command::ReturnToHold,
                world.nav,
                None,
                crate::traversal::Ground::new(world.terrain, world.deck),
            )?;
            if let Some(route) = result.route {
                out.push(Event::Movement(id, Movement::Route(route)));
            }
            return Ok(out);
        };
        let patient_position = p.motion.position;
        let mut duty = Duty {
            phase: s.duty.phase,
            timer: s.duty.timer,
            build_sound: s.fight.build_sound_timer,
        };
        let decision = duty.captor(true, s.motion.position, patient_position, s.is_moving())?;
        // A capture changes credit and two actors; reject invalid destinations before committing it.
        if decision == Captor::Claim {
            let destination = self
                .prison_destination(s.identity.team, patient_position, profile.fallback_depot)
                .ok_or("missing prison destination")?;
            let position = self.structure(destination).unwrap().position;
            let mut next = p.clone();
            next.vitals.life = Life::Captive;
            next.links.captor = id.into();
            next.links.prison_destination = destination.into();
            let route = next.go_to(position, Goal::Prison, 0)?;
            if s.identity.team == 0 {
                next.links.intel_left = 3;
                next.links.intel_timer = now + 6.0;
            }
            let mut ledger = battle.clone();
            ledger.prisoner(p, s, profile.value)?;
            *battle = ledger;
            *self.soldier_mut(prisoner).unwrap() = next;
            let s = self.soldier_mut(id).unwrap();
            s.posture = Posture::Stand;
            s.duty.phase = duty.phase;
            s.vitals.speech_cooldown = 2.6;
            out.push(Event::Taken {
                prisoner,
                captor: id,
                destination,
            });
            out.push(Event::Movement(prisoner, Movement::Route(route)));
            out.push(Event::Speech {
                captor: id,
                cue: (rng.randi() % 3) as u8,
            });
            return Ok(out);
        }
        let s = self.soldier_mut(id).unwrap();
        s.posture = Posture::Stand;
        s.duty.phase = duty.phase;
        match decision {
            Captor::Cancel | Captor::Claim => unreachable!(),
            Captor::Wait => {}
            Captor::Approach { repath } => {
                if repath {
                    out.push(Event::Movement(
                        id,
                        Movement::Route(s.go_to(patient_position, Goal::Task, 1)?),
                    ));
                }
                let mut movement = Vec::new();
                self.move_infantry(
                    id,
                    dt,
                    now,
                    4.0,
                    profile.gun,
                    squads,
                    world,
                    doors,
                    rng,
                    &mut movement,
                )?;
                out.extend(movement.into_iter().map(|e| Event::Movement(id, e)));
                self.soldier_mut(id).unwrap().activity = 2;
            }
            Captor::Guard => {
                let s = self.soldier(id).unwrap();
                let pose = duties::guard(
                    Guard {
                        position: s.motion.position,
                        yaw: s.motion.yaw,
                        prisoner: patient_position,
                        dt,
                        mount: self.mount_turn(s, profile.gun)?,
                    },
                    world.nav,
                    rng,
                    crate::traversal::Ground::new(world.terrain, world.deck),
                )?;
                let s = self.soldier_mut(id).unwrap();
                s.motion.position = pose.position;
                s.motion.yaw = pose.yaw;
                s.activity = if pose.walking { 1 } else { 0 };
            }
        }
        Ok(out)
    }

    pub fn arrive_infantry_prison(
        &mut self,
        id: u32,
        now: f64,
        nav: &PathPlanner,
        ground: crate::traversal::Ground<'_>,
    ) -> Result<Vec<Event>, &'static str> {
        if !ground.valid_for(nav.side()) {
            return Err("invalid navigation ground");
        }

        if !now.is_finite() || now.abs() > 1e12 - 100.0 {
            return Err("invalid prisoner arrival time");
        }
        let mut p = self.soldier(id).ok_or("missing arriving prisoner")?.clone();
        if p.orders.path_revision == i64::MAX as u64 {
            return Err("prisoner path revision exhausted");
        }
        let captor = p.links.captor as u32;
        let destination = self
            .structure(p.links.prison_destination as u32)
            .map(|st| (st.id, st.position, st.kind == "tunnel"));
        let mut out = Vec::new();
        let mut guard = self
            .soldier(captor)
            .filter(|c| c.duty.kind == Task::Captor)
            .cloned();
        p.links.captor = 0;
        if let Some(c) = &mut guard {
            let result = c.command(Command::ReturnToHold, nav, None, ground)?;
            if let Some(route) = result.route {
                out.push(Event::Movement(captor, Movement::Route(route)));
            }
        }
        let (reason, duration) = if destination.is_some_and(|d| d.2) {
            p.links.intel_left = 4;
            p.links.intel_timer = now + 4.0;
            (HiddenReason::Interrogation, 34.0)
        } else {
            (
                HiddenReason::Held,
                8.0 + f64::from(p.links.intel_left) * 10.0,
            )
        };
        p.hide_in(reason, duration, destination.map(|d| (d.0, d.1)))?;
        if let Some(c) = guard {
            *self.soldier_mut(captor).unwrap() = c;
        }
        *self.soldier_mut(id).unwrap() = p;
        out.push(Event::Movement(id, Movement::CancelPath));
        if let Some((destination, _, true)) = destination {
            out.push(Event::Interrogation {
                prisoner: id,
                destination,
            });
        }
        out.push(Event::CapturedAlert(id));
        Ok(out)
    }
}
