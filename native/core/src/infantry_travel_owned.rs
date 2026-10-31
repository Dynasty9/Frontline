//! Travel duties share movement, actor ownership and arrival effects.
use crate::actors::{Actor, Actors};
use crate::infantry::Goal;
use crate::infantry_action::{Action, Round, Throw};
use crate::infantry_control::{self, HiddenReason};
use crate::infantry_controller::Task;
use crate::infantry_cover::CoverWorld;
use crate::infantry_fire::MountedGun;
use crate::infantry_motion::Door;
use crate::infantry_orders::{Arrival, RouteOrder};
use crate::infantry_pose::Posture;
use crate::infantry_travel::{self, AfterBoarding, Boarding, Tunnel};
use crate::infantry_update::{Moved, Movement};
use crate::infantry_vitals::Life;
use crate::random::SimulationRandom;
use crate::spatial::{SpatialIndex, DOOR_CELL, UNIT_CELL};
use crate::squad::Squad;
use crate::vehicle::Vehicle;

#[derive(Clone, Copy, Debug)]
pub struct Transport {
    pub seats: u32,
    pub helicopter: bool,
    pub boat: bool,
}
#[derive(Clone, Copy, Debug, PartialEq)]
pub enum Event {
    Route(RouteOrder),
    CancelPath,
    Door { id: u32, kicked: bool },
    PrisonArrival,
    BreachSpeech(u8),
    ThrowSpeech(Round),
    GotAmmo,
    Stat(&'static str),
}

impl Actors {
    pub(crate) fn infantry_danger(&self, id: u32, now: f64, squads: &mut [Squad]) -> bool {
        let s = self.soldier(id).unwrap();
        s.vitals.suppression > 5.0
            || !s.fight.visible_targets.is_empty()
            || squads
                .iter_mut()
                .find(|q| q.id == s.identity.squad)
                .is_some_and(|q| q.in_combat(now))
    }
    fn crawling_danger(&self, id: u32, now: f64, squads: &mut [Squad]) -> bool {
        let s = self.soldier(id).unwrap();
        s.orders.purpose == Goal::Cover
            && s.motion.path_index < s.motion.path.len()
            && s.cover.shifting
            && s.cover.height > 0.0
            && s.cover.height < 1.12
            && self.infantry_danger(id, now, squads)
    }
    pub(crate) fn infantry_speed(&self, id: u32, now: f64, squads: &mut [Squad]) -> f64 {
        self.soldier(id)
            .unwrap()
            .movement_speed(self.crawling_danger(id, now, squads))
    }
    pub(crate) fn choose_infantry_activity(
        &mut self,
        id: u32,
        moving: bool,
        now: f64,
        squads: &mut [Squad],
    ) {
        let s = self.soldier(id).unwrap();
        let activity = if s.motion.door_wait > 0.0 {
            if s.motion.door_kick {
                33
            } else {
                0
            }
        } else if s.weapon.reload_timer > 0.0 {
            4
        } else if now - s.weapon.last_shot < 0.35 {
            3
        } else if moving {
            if s.crawling(self.crawling_danger(id, now, squads)) {
                11
            } else if s.motion.slide_timer > 0.0 {
                16
            } else if s.motion.vaulting {
                14
            } else if self.infantry_speed(id, now, squads) > 3.2 {
                2
            } else {
                1
            }
        } else if s.vitals.stamina < 0.3
            && s.posture == Posture::Stand
            && now - s.weapon.last_shot > 1.5
            && !self.infantry_target_valid(s.fight.target as u32)
        {
            36
        } else {
            0
        };
        self.soldier_mut(id).unwrap().activity = activity;
    }
    pub(crate) fn move_infantry(
        &mut self,
        id: u32,
        dt: f64,
        now: f64,
        speed: f64,
        gun: Option<MountedGun>,
        squads: &mut [Squad],
        world: &mut CoverWorld<'_>,
        doors: &SpatialIndex,
        rng: &mut SimulationRandom,
        events: &mut Vec<Event>,
    ) -> Result<bool, &'static str> {
        let s = self.soldier(id).ok_or("missing moving infantry")?;
        if s.orders.pending_path {
            return Ok(true);
        }
        if s.motion.path_index >= s.motion.path.len() {
            return Ok(false);
        }
        let mut candidates = Vec::new();
        if s.motion.door_wait <= 0.0 && now > s.motion.door_until {
            for who in doors.candidates(s.motion.position, 0.0)? {
                if let Some(st) = self.structure(who) {
                    candidates.push(Door {
                        id: who.into(),
                        position: st.position,
                        yaw: st.yaw,
                    });
                }
            }
        }
        let mount = self.mount_turn(s, gun)?;
        let input = Movement {
            dt,
            time: now,
            speed,
            danger: !candidates.is_empty() && self.infantry_danger(id, now, squads),
            has_doors: doors.cells().next().is_some(),
            door_still_closed: self
                .structure(s.motion.door as u32)
                .is_some_and(|st| st.door_closed),
            mount,
        };
        let Moved {
            moving,
            route,
            arrival,
            opened_door,
            speech,
            slid,
        } = self.soldier_mut(id).unwrap().move_route(
            input,
            world.nav,
            world.terrain,
            world.collision,
            rng,
            world.deck,
            &candidates,
        )?;
        if let Some(door) = opened_door {
            let opened = match self.get_mut(door.id as u32) {
                Some(Actor::Structure(st)) => st.open_door(),
                _ => false,
            };
            if opened {
                let team = self.soldier(id).unwrap().identity.team;
                if door.kicked {
                    let position = self.structure(door.id as u32).unwrap().position;
                    for who in self.units_near(world.units, position, 16.0, -1)? {
                        if let Some(other) = self.soldier(who).filter(|s| {
                            s.identity.team != team
                                && s.identity.team >= 0
                                && s.vitals.life == Life::Alive
                        }) {
                            if let Some(q) =
                                squads.iter_mut().find(|q| q.id == other.identity.squad)
                            {
                                q.report_position(door.by_position, now)?;
                            }
                        }
                    }
                }
                // The world refreshes terrain, collision and door membership before the next actor.
                events.push(Event::Door {
                    id: door.id as u32,
                    kicked: door.kicked,
                });
                events.push(Event::Stat(if door.kicked {
                    "door_kicked"
                } else {
                    "door_opened"
                }));
            }
        }
        if let Some(cue) = speech {
            events.push(Event::BreachSpeech(cue));
        }
        if slid {
            events.push(Event::Stat("slide"));
        }
        if let Some(route) = route {
            events.push(Event::Stat("repath"));
            events.push(Event::Route(route));
        }
        if arrival == Arrival::Prison {
            events.push(Event::PrisonArrival);
        }
        Ok(moving)
    }
    pub fn advance_infantry_travel(
        &mut self,
        id: u32,
        dt: f64,
        now: f64,
        ammunition: Option<i32>,
        gun: Option<MountedGun>,
        transport: impl Fn(&Vehicle) -> Transport,
        squads: &mut [Squad],
        world: &mut CoverWorld<'_>,
        doors: &SpatialIndex,
        rng: &mut SimulationRandom,
    ) -> Result<Vec<Event>, &'static str> {
        let s = self.soldier(id).ok_or("missing travelling infantry")?;
        if !dt.is_finite()
            || !(0.0..=10.0).contains(&dt)
            || !now.is_finite()
            || now.abs() > 1e12 - 100.0
            || world.nav.side() != world.terrain.n
            || world.units.cell_size() != UNIT_CELL
            || doors.cell_size() != DOOR_CELL
            || gun.is_some_and(|g| !g.valid())
            || !world.deck.is_empty() && world.deck.len() != world.terrain.n * world.terrain.n
            || ammunition.is_some_and(|n| !(0..=1_000_000).contains(&n))
        {
            return Err("invalid infantry travel context");
        }
        let task = s.duty.kind;
        if !matches!(
            task,
            Task::Retreat | Task::Throw | Task::Board | Task::Tunnel | Task::Pilot | Task::Resupply
        ) {
            return Err("infantry is not travelling");
        }
        let mut events = Vec::new();
        if task == Task::Pilot {
            let drone = self
                .get(s.fight.controlled_drone as u32)
                .and_then(|a| match a {
                    Actor::Drone(d) if !d.flight.dead => Some(d.flight.position),
                    _ => None,
                });
            let yaw = infantry_control::pilot_yaw(
                s.motion.position,
                s.motion.yaw,
                dt,
                drone,
                self.mount_turn(s, gun)?,
            )?;
            let s = self.soldier_mut(id).unwrap();
            s.posture = Posture::Crouch;
            s.activity = 24;
            if let Some(yaw) = yaw {
                s.motion.yaw = yaw;
            } else {
                s.fight.controlled_drone = 0;
                s.duty.kind = Task::Fight;
            }
            return Ok(events);
        }
        let target = s.duty.entity as u32;
        let vehicle = if task == Task::Board {
            self.vehicle(target).map(|v| (v, transport(v)))
        } else {
            None
        };
        if vehicle.is_some_and(|(_, p)| p.seats > 1000) {
            return Err("invalid transport capacity");
        }
        if task == Task::Resupply && ammunition.is_none() {
            return Err("missing supply ammunition");
        }
        if (task == Task::Board && vehicle.is_none())
            || (task == Task::Tunnel && self.structure(target).is_none_or(|st| !st.built))
            || (task == Task::Resupply && self.get(target).is_none())
        {
            self.soldier_mut(id).unwrap().duty.kind = Task::Fight;
            return Ok(events);
        }
        let vehicle = vehicle.map(|(v, profile)| {
            (
                v.position,
                profile,
                profile.seats as i32
                    - v.passengers
                        .iter()
                        .filter(|&&id| self.get(id).is_some())
                        .count() as i32,
            )
        });
        if let Some((position, profile, seats)) = vehicle {
            match infantry_travel::boarding(
                true,
                s.motion.position,
                position,
                seats,
                profile.helicopter,
                profile.boat,
                s.is_moving(),
            )? {
                Boarding::Cancel => {
                    self.soldier_mut(id).unwrap().duty.kind = Task::Fight;
                    return Ok(events);
                }
                Boarding::Enter => {
                    self.soldier_mut(id).unwrap().duty.kind = Task::Fight;
                    if self.board(target, id, profile.seats, profile.helicopter)? {
                        events.push(Event::CancelPath);
                        events.push(Event::Stat("boarded"));
                    }
                    return Ok(events);
                }
                Boarding::Move => {}
            }
        }
        if task == Task::Throw {
            let round = s.duty.throw_kind;
            let inventory = if round == Round::Smoke {
                s.fight.smokes
            } else {
                s.grenades.frags
            };
            match infantry_travel::ordered_throw(s.motion.position, s.duty.position, inventory)? {
                infantry_travel::Throw::Cancel => {
                    self.soldier_mut(id).unwrap().duty.kind = Task::Fight;
                    return Ok(events);
                }
                infantry_travel::Throw::Release { remaining } => {
                    let s = self.soldier_mut(id).unwrap();
                    if round == Round::Smoke {
                        s.fight.smokes = remaining;
                        events.push(Event::Stat("smoke"));
                    } else {
                        s.grenades.frags = remaining;
                    }
                    s.duty.kind = Task::Fight;
                    s.begin_action(
                        Action::Throw(Throw {
                            position: s.duty.position,
                            round,
                            fuse: 3.4,
                        }),
                        0.6,
                        None,
                    )?;
                    s.vitals.speech_cooldown = 2.6;
                    events.push(Event::CancelPath);
                    events.push(Event::ThrowSpeech(round));
                    return Ok(events);
                }
                infantry_travel::Throw::Move => {}
            }
        }
        let speed = if task == Task::Retreat {
            self.soldier_mut(id).unwrap().posture = Posture::Stand;
            5.3
        } else {
            self.infantry_speed(id, now, squads)
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
            &mut events,
        )?;
        match task {
            Task::Retreat => {
                let s = self.soldier_mut(id).unwrap();
                if moved {
                    s.activity = 2;
                } else {
                    s.duty.kind = Task::Fight;
                    s.activity = 0;
                    s.orders.hold_position = s.motion.position;
                    s.cover.at_cover = false;
                    s.cover.evaluate_at = 0.0;
                }
            }
            Task::Throw => {
                if !moved {
                    self.soldier_mut(id).unwrap().duty.kind = Task::Fight;
                }
                self.choose_infantry_activity(id, true, now, squads);
            }
            Task::Board => {
                let (position, profile, _) = vehicle.unwrap();
                let s = self.soldier(id).unwrap();
                match infantry_travel::after_boarding_move(
                    s.motion.position,
                    position,
                    s.orders.goal,
                    profile.boat,
                    moved,
                )? {
                    AfterBoarding::Enter => {
                        self.soldier_mut(id).unwrap().duty.kind = Task::Fight;
                        if self.board(target, id, profile.seats, profile.helicopter)? {
                            events.push(Event::CancelPath);
                            events.push(Event::Stat("boarded"));
                        }
                        return Ok(events);
                    }
                    AfterBoarding::Continue { repath } => {
                        if repath {
                            events.push(Event::Route(self.soldier_mut(id).unwrap().go_to(
                                position,
                                Goal::Task,
                                1,
                            )?));
                        }
                    }
                }
                self.choose_infantry_activity(id, true, now, squads);
            }
            Task::Tunnel => {
                let entrance = self.structure(target).unwrap().position;
                match infantry_travel::tunnel_arrival(
                    self.soldier(id).unwrap().motion.position,
                    entrance,
                    moved,
                )? {
                    Tunnel::Move => self.choose_infantry_activity(id, true, now, squads),
                    Tunnel::Approach => events.push(Event::Route(
                        self.soldier_mut(id)
                            .unwrap()
                            .go_to(entrance, Goal::Task, 1)?,
                    )),
                    Tunnel::Enter => {
                        if self.structure(target).unwrap().inside.len() == 100_000 {
                            return Err("tunnel occupant limit exceeded");
                        }
                        let s = self.soldier_mut(id).unwrap();
                        s.duty.kind = Task::Fight;
                        s.hide_in(HiddenReason::TunnelWait, 9999.0, Some((target, entrance)))?;
                        let Some(Actor::Structure(st)) = self.get_mut(target) else {
                            unreachable!()
                        };
                        st.inside.push(id);
                        events.push(Event::CancelPath);
                        events.push(Event::Stat("tunnel_in"));
                    }
                }
            }
            Task::Resupply => {
                if moved {
                    self.choose_infantry_activity(id, true, now, squads);
                } else {
                    let result = self.arrive_infantry_supply(id, ammunition.unwrap(), world.nav)?;
                    if result.spoke {
                        events.push(Event::GotAmmo);
                    }
                    if let Some(route) = result.route {
                        events.push(Event::Route(route));
                    }
                }
            }
            _ => unreachable!(),
        }
        Ok(events)
    }
}
