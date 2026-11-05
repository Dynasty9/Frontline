//! Engineers finish shared geometry and supply changes before advancing their work clock.
use crate::actors::Actor;
use crate::battle_stats;
use crate::bullet_world::Gunfire;
use crate::infantry::{Goal, Infantry};
use crate::infantry_controller::Task;
use crate::infantry_duties::{self, Build, Duty};
use crate::infantry_fight_world::{valid_step, Event, Profile};
use crate::infantry_fighting::Mode;
use crate::infantry_fire::MountedGun;
use crate::infantry_pose::Posture;
use crate::infantry_travel_owned::Event as Movement;
use crate::infantry_vitals::Life;
use crate::squad::Report;
use crate::supply_network::SupplyNetwork;
use crate::vector::Vector3;
use crate::vehicle::Vehicle;
use crate::vehicle_damage::Armor;
use crate::world::WorldContext;
use crate::world_combat;

#[derive(Clone, Debug, PartialEq)]
pub enum Construction {
    Completed { id: u32, kind: String },
    FobRestored { id: u32 },
    TrackRepaired { id: u32 },
    Sound { position: Vector3 },
}

impl WorldContext<'_> {
    fn finish_build_order(&mut self, id: u32, target: u32, out: &mut Vec<Event>) {
        let s = self.actors.soldier_mut(id).unwrap();
        s.duty.kind = Task::Fight;
        let Some(q) = self.squads.iter_mut().find(|q| q.id == s.identity.squad) else {
            return;
        };
        if q.build_target != target {
            return;
        }
        q.build_target = 0;
        q.order = "hold".into();
        if q.members.iter().any(|id| {
            self.actors
                .soldier(*id)
                .is_some_and(|m| m.vitals.life == Life::Alive && m.duty.kind == Task::Build)
        }) {
            return;
        }
        if let Some(m) = q
            .members
            .first()
            .and_then(|id| self.actors.soldier_mut(*id))
        {
            // The line is picked even when this soldier's speech cooldown suppresses it.
            let text = ["Done here.", "Construction complete.", "That should hold."]
                [self.rng.randi() as usize % 3];
            if m.vitals.speech_cooldown <= 0.0 {
                m.vitals.speech_cooldown = 2.6;
                out.push(Event::Speech {
                    id: m.identity.id,
                    text: text.into(),
                });
            }
        }
    }

    pub fn advance_build<'a>(
        &mut self,
        id: u32,
        dt: f64,
        rate: f64,
        build_time: Option<f64>,
        gun: Option<MountedGun>,
        profile: &dyn Fn(&Infantry) -> Option<Profile<'a>>,
        gunfire: &mut Gunfire,
        network: &mut SupplyNetwork,
        impacts: &mut Vec<Report>,
        armor: &dyn Fn(&Vehicle) -> Armor,
        vehicle_hit: &dyn Fn(&Vehicle) -> f64,
    ) -> Result<Vec<Event>, &'static str> {
        let s = self.actors.soldier(id).ok_or("missing building infantry")?;
        if !valid_step(dt, self.now, gun)
            || !rate.is_finite()
            || !(0.0..=100_000.0).contains(&rate)
            || build_time.is_some_and(|t| !t.is_finite() || !(0.001..=1e9).contains(&t))
            || profile(s).is_some_and(|p| !p.valid())
            || s.vitals.life != Life::Alive
            || s.duty.kind != Task::Build
        {
            return Err("invalid construction step");
        }
        let target = s.duty.entity as u32;
        let work = self.actors.get(target);
        let done = match work {
            Some(Actor::Structure(st)) => !st.needs_work(),
            Some(Actor::Vehicle(v)) => !v.needs_repair(),
            None => true,
            _ => false,
        };
        let enemy = self
            .actors
            .infantry_target_valid(s.fight.target as u32)
            .then(|| self.actors.get(s.fight.target as u32).unwrap().position());
        let decision = infantry_duties::build(
            done,
            s.vitals.suppression,
            s.is_moving(),
            s.motion.position,
            s.duty.position,
            enemy,
        )?;
        let mut out = vec![];
        match decision {
            Build::Done => {
                self.finish_build_order(id, if work.is_some() { target } else { 0 }, &mut out)
            }
            Build::Suppressed | Build::Fight => {
                if decision == Build::Suppressed {
                    let s = self.actors.soldier_mut(id).unwrap();
                    s.posture = Posture::Crouch;
                    s.activity = 0;
                }
                out.extend(self.advance_infantry_weapon(
                    id,
                    dt,
                    false,
                    Mode::Normal,
                    gun,
                    profile,
                    gunfire,
                    network,
                    impacts,
                    armor,
                    vehicle_hit,
                )?);
                if decision == Build::Fight {
                    self.actors
                        .choose_infantry_activity(id, false, self.now, self.squads);
                }
            }
            Build::Move => {
                let speed = self.actors.infantry_speed(id, self.now, self.squads);
                let (_, events) = self.move_infantry_world(id, dt, speed, gun)?;
                out.extend(
                    events
                        .into_iter()
                        .map(|event| Event::Movement { id, event }),
                );
                self.actors
                    .choose_infantry_activity(id, true, self.now, self.squads);
            }
            Build::Approach => {
                let s = self.actors.soldier_mut(id).unwrap();
                let route = s.go_to(s.duty.position, Goal::Task, 1)?;
                self.apply_infantry_movement(id, Movement::Route(route))?;
            }
            Build::Work => {
                if self.actors.structure(target).is_some_and(|st| {
                    st.kind == "fob"
                        && !st.built
                        && st.progress + rate * dt / build_time.unwrap_or(10.0) >= 1.0
                }) && network.completed == u32::MAX
                {
                    return Err("FOB completion order exhausted");
                }
                let position = work.unwrap().position();
                let mount = self.actors.mount_turn(s, gun)?;
                let s = self.actors.soldier_mut(id).unwrap();
                s.motion.yaw = infantry_duties::build_pose(
                    s.motion.position,
                    s.motion.yaw,
                    position,
                    dt,
                    mount,
                )?;
                s.activity = 7;
                s.posture = Posture::Crouch;
                match self.actors.get_mut(target).unwrap() {
                    Actor::Structure(st) => {
                        let result = st.add_work(rate * dt, build_time)?;
                        let team = st.team;
                        if result.completed {
                            self.geometry.complete_structure(target, self.actors)?;
                            let st = self.actors.structure(target).unwrap();
                            let (owner, kind, name) = (st.owner, st.kind.clone(), st.name.clone());
                            self.battle.add(owner, team, 17, 1.0)?;
                            if kind == "fob" {
                                self.battle.event(battle_stats::Event {
                                    time: self.now,
                                    team,
                                    kind: "fob".into(),
                                    text: format!("FOB {name} established"),
                                })?;
                                network.register_start(target, self.actors)?;
                                out.push(Event::World(world_combat::Event::Stat("fob_built")));
                                out.extend(
                                    network
                                        .rebuild(team as u8, self.actors, self.geometry)?
                                        .into_iter()
                                        .map(|id| Event::World(world_combat::Event::Despawn(id))),
                                );
                            } else if kind == "medic_tent" {
                                let Some(Actor::Structure(st)) = self.actors.get_mut(target) else {
                                    unreachable!()
                                };
                                st.bearer_timer = 0.0;
                            }
                            out.push(Event::Construction(Construction::Completed {
                                id: target,
                                kind,
                            }));
                        } else if result.repaired_fob {
                            out.push(Event::Construction(Construction::FobRestored {
                                id: target,
                            }));
                            out.extend(
                                network
                                    .rebuild(team as u8, self.actors, self.geometry)?
                                    .into_iter()
                                    .map(|id| Event::World(world_combat::Event::Despawn(id))),
                            );
                        }
                    }
                    Actor::Vehicle(v) => {
                        if v.repair(rate * dt)? {
                            out.push(Event::Construction(Construction::TrackRepaired {
                                id: target,
                            }));
                        }
                    }
                    _ => {}
                }
                let s = self.actors.soldier_mut(id).unwrap();
                let mut timer = Duty {
                    build_sound: s.fight.build_sound_timer,
                    ..Default::default()
                };
                let sound = timer.finish_build(dt, self.rng)?;
                s.fight.build_sound_timer = timer.build_sound;
                if sound {
                    out.push(Event::Construction(Construction::Sound {
                        position: s.motion.position,
                    }));
                }
            }
        }
        Ok(out)
    }
}
