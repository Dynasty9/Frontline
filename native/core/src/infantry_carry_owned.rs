//! Bearers share casualty and partner state throughout pickup, delivery and solo takeover.
use crate::actors::Actors;
use crate::infantry::Goal;
use crate::infantry_control::HiddenReason;
use crate::infantry_controller::Task;
use crate::infantry_cover::CoverWorld;
use crate::infantry_duties::{self as duties, Carry, Duty, Stretcher};
use crate::infantry_fire::MountedGun;
use crate::infantry_pose::Posture;
use crate::infantry_travel_owned::Event as Movement;
use crate::infantry_vitals::Life;
use crate::random::SimulationRandom;
use crate::spatial::{SpatialIndex, DOOR_CELL, UNIT_CELL};
use crate::squad::Squad;
use crate::vector::Vector3;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Speech {
    Lift,
    Solo,
    BearerDown,
}
#[derive(Clone, Copy, Debug, PartialEq)]
pub enum Event {
    Movement(u32, Movement),
    Speech(u32, Speech),
    IntoTent { soldier: u32, squad: u32 },
}

impl Actors {
    fn end_infantry_stretcher(
        &mut self,
        id: u32,
        delivered: bool,
        rng: &mut SimulationRandom,
        out: &mut Vec<Event>,
    ) -> Result<(), &'static str> {
        let s = self.soldier(id).unwrap();
        let patient = s.duty.entity as u32;
        let exit = self.structure(s.links.home as u32).map(|st| st.exit());
        if let Some(p) = self.soldier_mut(patient) {
            p.links.carried_by.retain(|&who| who != u64::from(id));
            if p.links.carried_by.is_empty() && !delivered {
                p.links.stretcher_claimed = false;
                p.motion.position.y = 0.0;
            }
        }
        let s = self.soldier_mut(id).unwrap();
        s.duty.kind = Task::Fight;
        s.duty.entity = 0;
        s.duty.partner = 0;
        s.orders.backwards = false;
        if let Some(exit) = exit {
            let destination =
                exit + Vector3::new(rng.randf_range(-2.0, 2.0), 0.0, rng.randf_range(-2.0, 2.0));
            out.push(Event::Movement(
                id,
                Movement::Route(s.go_to(destination, Goal::Slot, 0)?),
            ));
        }
        Ok(())
    }

    pub fn advance_infantry_stretcher(
        &mut self,
        id: u32,
        dt: f64,
        now: f64,
        gun: Option<MountedGun>,
        squads: &mut [Squad],
        world: &mut CoverWorld<'_>,
        doors: &SpatialIndex,
        rng: &mut SimulationRandom,
    ) -> Result<Vec<Event>, &'static str> {
        if !dt.is_finite()
            || !(0.0..=10.0).contains(&dt)
            || !now.is_finite()
            || now.abs() > 1e12 - 100.0
            || gun.is_some_and(|g| !g.valid())
            || world.nav.side() != world.terrain.n
            || world.units.cell_size() != UNIT_CELL
            || doors.cell_size() != DOOR_CELL
            || !world.deck.is_empty() && world.deck.len() != world.terrain.n * world.terrain.n
        {
            return Err("invalid stretcher context");
        }
        let s = self.soldier(id).ok_or("missing stretcher bearer")?;
        if s.duty.kind != Task::Stretcher {
            return Err("infantry is not carrying a stretcher");
        }
        let casualty = s.duty.entity as u32;
        let partner_id = s.duty.partner as u32;
        let partner = self.soldier(partner_id).filter(|p| {
            p.vitals.life == Life::Alive
                && p.duty.kind == Task::Stretcher
                && p.duty.entity == s.duty.entity
        });
        let home = self.structure(s.links.home as u32);
        let patient = self.soldier(casualty).filter(|p| {
            matches!(p.vitals.life, Life::Downed | Life::Dead) && p.links.dragged_by == 0
        });
        let mut out = Vec::new();
        let (Some(home), Some(patient)) = (home, patient) else {
            self.end_infantry_stretcher(id, false, rng, &mut out)?;
            return Ok(out);
        };
        let (home_id, home_position, exit) = (home.id, home.position, home.exit());
        let partner_ok = partner.is_some();
        let mut duty = Duty {
            phase: s.duty.phase,
            timer: s.duty.timer,
            build_sound: s.fight.build_sound_timer,
        };
        let decision = duty.stretcher(Stretcher {
            valid: true,
            position: s.motion.position,
            casualty: patient.motion.position,
            moving: s.is_moving(),
            partner_phase: partner.map(|p| p.duty.phase),
            front: s.duty.front,
            dt,
        })?;
        let s = self.soldier_mut(id).unwrap();
        s.posture = Posture::Stand;
        s.duty.phase = duty.phase;
        s.duty.timer = duty.timer;
        match decision {
            Carry::Cancel => unreachable!(),
            Carry::Ready => {}
            Carry::Wait => s.activity = 21,
            Carry::Approach => {
                let p = self.soldier(casualty).unwrap().motion.position;
                let route = self.soldier_mut(id).unwrap().go_to(p, Goal::Task, 1)?;
                out.push(Event::Movement(id, Movement::Route(route)));
            }
            Carry::Lift | Carry::TakeOver => {
                if decision == Carry::Lift {
                    s.activity = 21;
                }
                let p = self.soldier_mut(casualty).unwrap();
                p.links.carried_by = vec![id.into()];
                if decision == Carry::Lift && partner_ok {
                    p.links.carried_by.push(partner_id.into());
                    self.soldier_mut(partner_id).unwrap().duty.phase = 3;
                }
                let s = self.soldier_mut(id).unwrap();
                out.push(Event::Movement(
                    id,
                    Movement::Route(s.go_to(exit, Goal::Task, 0)?),
                ));
                if decision == Carry::Lift {
                    s.vitals.speech_cooldown = 2.6;
                    out.push(Event::Speech(
                        id,
                        if partner_ok {
                            Speech::Lift
                        } else {
                            Speech::Solo
                        },
                    ));
                }
            }
            Carry::Follow => {
                let partner = self.soldier(partner_id).unwrap();
                let yaw = partner.motion.yaw;
                let next = duties::follow_bearer(
                    self.soldier(id).unwrap().motion.position,
                    partner.motion.position,
                    yaw,
                    dt,
                )?;
                let s = self.soldier_mut(id).unwrap();
                s.motion.position = next;
                s.motion.yaw = yaw;
                s.activity = 10;
            }
            Carry::Move | Carry::Lead => {
                let mut movement = Vec::new();
                let solo = !partner_ok;
                let speed = if decision == Carry::Move {
                    4.4
                } else if solo {
                    0.95
                } else {
                    1.9
                };
                let moved = self.move_infantry(
                    id,
                    dt,
                    now,
                    speed,
                    gun,
                    squads,
                    world,
                    doors,
                    rng,
                    &mut movement,
                )?;
                out.extend(movement.into_iter().map(|e| Event::Movement(id, e)));
                if decision == Carry::Move {
                    self.soldier_mut(id).unwrap().activity = 2;
                    return Ok(out);
                }
                let s = self.soldier(id).unwrap();
                let pose = duties::carry_pose(
                    s.motion.position,
                    s.motion.yaw,
                    s.motion.last_direction,
                    dt,
                    solo,
                    self.mount_turn(s, gun)?,
                )?;
                let s = self.soldier_mut(id).unwrap();
                s.orders.backwards = solo;
                s.activity = if solo { 9 } else { 10 };
                s.motion.yaw = pose.yaw;
                let p = self.soldier_mut(casualty).unwrap();
                p.motion.position = pose.casualty;
                p.motion.yaw = pose.casualty_yaw;
                if solo && p.links.carried_by.len() > 1 {
                    p.links.carried_by = vec![id.into()];
                    self.soldier_mut(id).unwrap().vitals.speech_cooldown = 2.6;
                    out.push(Event::Speech(id, Speech::BearerDown));
                }
                if !moved {
                    self.end_infantry_stretcher(id, true, rng, &mut out)?;
                    if partner_ok {
                        self.end_infantry_stretcher(partner_id, true, rng, &mut out)?;
                    }
                    let p = self.soldier_mut(casualty).unwrap();
                    p.links.tent_dead = p.vitals.life == Life::Dead;
                    let qid = p.identity.squad;
                    out.push(Event::IntoTent {
                        soldier: casualty,
                        squad: qid,
                    });
                    if let Some(q) = squads.iter_mut().find(|q| q.id == qid) {
                        q.remove_member(casualty, self)?;
                    }
                    let p = self.soldier_mut(casualty).unwrap();
                    p.hide_in(
                        HiddenReason::Tent,
                        if p.links.tent_dead { 35.0 } else { 20.0 },
                        Some((home_id, home_position)),
                    )?;
                    out.push(Event::Movement(casualty, Movement::CancelPath));
                }
            }
        }
        Ok(out)
    }
}
