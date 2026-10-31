//! Captors and prisoners share routes, destination ownership and capture credit.
use crate::actors::Actors;
use crate::battle_stats::BattleStats;
use crate::entities::Kind;
use crate::infantry::Goal;
use crate::infantry_commands::Command;
use crate::infantry_control::HiddenReason;
use crate::infantry_controller::Task;
use crate::infantry_cover::CoverWorld;
use crate::infantry_duties::{self as duties, Captor, Duty, Guard};
use crate::infantry_fire::MountedGun;
use crate::infantry_pose::Posture;
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
            let result =
                self.soldier_mut(id)
                    .unwrap()
                    .command(Command::ReturnToHold, world.nav, None)?;
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
    ) -> Result<Vec<Event>, &'static str> {
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
            let result = c.command(Command::ReturnToHold, nav, None)?;
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
