//! Gun crews use the same retained bullets, projectiles and warning responses as other troops.
use crate::actors::Actor;
use crate::bullet_world::Gunfire;
use crate::cover::{rotation, transform};
use crate::entities::{Kind as ActorKind, MAX_ENTITIES};
use crate::fire_targets;
use crate::guided::{GuidedFlight, Kind as GuidedKind};
use crate::infantry::Infantry;
use crate::infantry_action::Round;
use crate::infantry_action_owned::{Completed, Defense, Event as Ordnance};
use crate::infantry_controller::Task;
use crate::infantry_fight_world::{valid_step, Event, Profile};
use crate::infantry_fighting::Mode;
use crate::infantry_fire::MountedGun;
use crate::infantry_mount::{self, Contact, GunPose, Mount, Station};
use crate::infantry_pose::Posture;
use crate::infantry_vitals::Life;
use crate::projectile::Kind;
use crate::projectile_actor::{ballistic, Motion, Projectile, Spawn};
use crate::random::SimulationRandom;
use crate::squad::Report;
use crate::supply_network::SupplyNetwork;
use crate::vector::{normalized, turn_yaw, Vector3};
use crate::vehicle::{Route, Vehicle};
use crate::vehicle_damage::Armor;
use crate::vehicle_loss_world::Context;
use crate::visibility::Sight;
use crate::world_combat;

pub(crate) fn mortar_round(
    shooter: u32,
    team: i8,
    from: Vector3,
    target: Vector3,
    round: Round,
    rng: &mut SimulationRandom,
) -> Result<Projectile, &'static str> {
    let delta = target - from;
    let distance = f64::from(Vector3::new(delta.x, 0.0, delta.z).length());
    let scatter = 1.2 + distance * 0.03;
    let angle = f64::from(rng.randf()) * std::f64::consts::TAU;
    let radius = libm::sqrt(f64::from(rng.randf())) * scatter;
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
    Projectile::from_spawn(
        1,
        Spawn {
            flight: f,
            team,
            thrower: shooter,
            called_by: 0,
        },
    )
}

impl Context<'_> {
    pub(crate) fn apply_ordnance(
        &mut self,
        completed: Completed,
        out: &mut Vec<Event>,
    ) -> Result<(), &'static str> {
        for event in completed.events {
            if let Ordnance::Smoke {
                vehicle,
                route:
                    Route::Ground {
                        destination,
                        care,
                        revision,
                    },
                ..
            } = event
            {
                let v = self
                    .actors
                    .vehicle_mut(vehicle)
                    .ok_or("missing evasive vehicle")?;
                self.geometry
                    .navigation
                    .submit_vehicle(v, destination, care, revision)?;
            }
            out.push(Event::Ordnance(event));
        }
        out.extend(
            completed
                .stats
                .into_iter()
                .map(|s| Event::World(world_combat::Event::Stat(s))),
        );
        Ok(())
    }

    fn mount_mortar(
        &mut self,
        id: u32,
        st_id: u32,
        dt: f64,
        owned: &[u32],
        gun: Option<MountedGun>,
        out: &mut Vec<Event>,
    ) -> Result<(), &'static str> {
        let s = self.actors.soldier_mut(id).unwrap();
        s.posture = Posture::Crouch;
        s.activity = if self.now - s.weapon.last_shot < 0.7 {
            24
        } else {
            0
        };
        if self.now < s.arsenal.mortar_ready {
            return Ok(());
        }
        if s.emplacement.mortar_aim.is_none() {
            let Some(Actor::Structure(st)) = self.actors.get_mut(st_id) else {
                unreachable!()
            };
            let queued = if st.fire_queue.is_empty() {
                None
            } else {
                Some(st.fire_queue.remove(0))
            };
            let position = st.position;
            let s = self.actors.soldier_mut(id).unwrap();
            s.emplacement.mortar_round = if queued.is_some_and(|(_, smoke)| smoke) {
                Round::Smoke
            } else {
                Round::HighExplosive
            };
            s.emplacement.mortar_delay = if queued.is_some() { 2.2 } else { 5.0 };
            let target = match queued {
                Some((target, _)) => Some(target),
                None => fire_targets::mortar(
                    self.actors,
                    self.units,
                    owned,
                    self.actors.soldier(id).unwrap().identity.team,
                    position,
                    30.0,
                    160.0,
                )?,
            };
            let s = self.actors.soldier_mut(id).unwrap();
            s.emplacement.mortar_aim = target;
            if target.is_none() {
                s.arsenal.mortar_ready = self.now + 2.0;
                let s = self.actors.soldier(id).unwrap();
                let mount = self.actors.mount_turn(s, gun)?;
                let front = self.actors.structure(st_id).unwrap().front();
                let s = self.actors.soldier_mut(id).unwrap();
                s.motion.yaw = turn_yaw(s.motion.yaw, front, s.motion.position, dt, 3.0, mount);
                return Ok(());
            }
        }
        let s = self.actors.soldier(id).unwrap();
        let aim = infantry_mount::mortar_aim(
            GunPose {
                position: s.motion.position,
                yaw: s.motion.yaw,
                dt,
                mount: self.actors.mount_turn(s, gun)?,
            },
            s.emplacement.mortar_aim.unwrap(),
        )?;
        self.actors.soldier_mut(id).unwrap().motion.yaw = aim.yaw;
        if !aim.aligned {
            return Ok(());
        }
        if self.actors.entities().next_id() > u32::MAX as u64
            || self.actors.entities().len() >= MAX_ENTITIES
        {
            return Err("mounted mortar exceeds match limits");
        }
        let from = self.actors.structure(st_id).unwrap().position + Vector3::Y;
        let s = self.actors.soldier_mut(id).unwrap();
        s.arsenal.mortar_ready = self.now + s.emplacement.mortar_delay;
        s.weapon.last_shot = self.now;
        let round = mortar_round(
            id,
            s.identity.team,
            from,
            s.emplacement.mortar_aim.unwrap(),
            s.emplacement.mortar_round,
            self.rng,
        )?;
        let projectile = self.actors.spawn(Actor::Projectile(round))?;
        out.push(Event::Ordnance(Ordnance::Spawn(projectile)));
        out.push(Event::Ordnance(Ordnance::Mortar(from)));
        out.push(Event::World(world_combat::Event::Stat("mortar_round")));
        self.actors.soldier_mut(id).unwrap().emplacement.mortar_aim = None;
        Ok(())
    }

    fn mount_antitank<'a>(
        &mut self,
        id: u32,
        st_id: u32,
        dt: f64,
        gun: Option<MountedGun>,
        defense: &dyn Fn(&Vehicle) -> Defense<'a>,
        out: &mut Vec<Event>,
    ) -> Result<(), &'static str> {
        let st_position = self.actors.structure(st_id).unwrap().position;
        let eye = st_position + Vector3::Y * 1.3;
        let s = self.actors.soldier_mut(id).unwrap();
        s.posture = Posture::Crouch;
        s.activity = if self.now - s.weapon.last_shot < 1.0 {
            24
        } else {
            0
        };
        let team = s.identity.team;
        let mut clock = Mount {
            scan_timer: s.emplacement.scan_timer,
            target: s.emplacement.target,
            ..Default::default()
        };
        let scan = clock.scan_due(dt)?;
        s.emplacement.scan_timer = clock.scan_timer;
        s.emplacement.target = clock.target;
        if scan {
            let contacts: Vec<_> = self
                .actors
                .iter_kind(ActorKind::Vehicle)
                .filter_map(|a| {
                    let Actor::Vehicle(v) = a else { unreachable!() };
                    (v.team >= 0 && v.team != team && v.visible & (1 << team) != 0).then(|| {
                        Contact {
                            id: v.id.into(),
                            team: v.team.into(),
                            revealed: true,
                            position: v.position,
                            points: v.exposed_points().to_vec(),
                            excluded: vec![v.id.into()],
                        }
                    })
                })
                .collect();
            let found = infantry_mount::scan(
                team.into(),
                st_position,
                &contacts,
                &mut self.geometry.collision,
                self.visibility,
            )?;
            self.actors.soldier_mut(id).unwrap().emplacement.target = found.target;
            out.extend(
                (0..found.reused)
                    .map(|_| Event::World(world_combat::Event::Stat("perception_blocked_reused"))),
            );
        }
        let s = self.actors.soldier(id).unwrap();
        let target_id = s.emplacement.target as u32;
        let Some(target) = self.actors.get(target_id) else {
            return Ok(());
        };
        let (aim, direction) = infantry_mount::antitank_aim(
            GunPose {
                position: s.motion.position,
                yaw: s.motion.yaw,
                dt,
                mount: self.actors.mount_turn(s, gun)?,
            },
            st_position,
            target.position(),
        )?;
        let s = self.actors.soldier_mut(id).unwrap();
        s.motion.yaw = aim.yaw;
        if self.now < s.arsenal.rocket_ready || !aim.aligned {
            return Ok(());
        }
        let Some(v) = self.actors.vehicle(target_id) else {
            return Ok(());
        };
        match self.visibility.can_see(
            &mut self.geometry.collision,
            eye,
            u64::from(target_id),
            &v.exposed_points(),
            &[i64::from(target_id)],
            true,
        ) {
            Some(Sight::Visible) => {}
            Some(Sight::ReusedObstruction) => {
                out.push(Event::World(world_combat::Event::Stat(
                    "perception_blocked_reused",
                )));
                return Ok(());
            }
            _ => return Ok(()),
        }
        if self.actors.entities().next_id() + 4 > u32::MAX as u64
            || self.actors.entities().len() > MAX_ENTITIES - 5
        {
            return Err("mounted rocket exceeds match limits");
        }
        let from = eye + direction * 0.9;
        let mut target = self.actors.actor_center(target_id).unwrap();
        let distance = f64::from(from.distance(target));
        let guided = team == 0;
        let s = self.actors.soldier_mut(id).unwrap();
        s.arsenal.rocket_ready = self.now + 7.0;
        s.weapon.last_shot = self.now;
        let (round, heading) = if guided {
            let heading = normalized(normalized(target - from) + Vector3::Y * 0.3);
            (
                Projectile {
                    id: 0,
                    team,
                    thrower: id,
                    called_by: 0,
                    held_by: 0,
                    smothered_by: 0,
                    handler: 0,
                    thrown_back: 0,
                    target_id,
                    motion: Motion::Guided(GuidedFlight {
                        kind: GuidedKind::AntiTank,
                        position: from,
                        velocity: heading * 26.0,
                        target,
                        life: 0.0,
                        locked: true,
                        dead: false,
                    }),
                },
                heading,
            )
        } else {
            let v = self.actors.vehicle(target_id).unwrap();
            target += v.velocity * (distance / 90.0) as f32;
            target += Vector3::new(
                self.rng.randf_range(-1.0, 1.0),
                self.rng.randf_range(-0.3, 0.3),
                self.rng.randf_range(-1.0, 1.0),
            ) * distance as f32
                * 0.012;
            let heading = normalized(target - from);
            (
                Projectile::from_spawn(
                    1,
                    Spawn {
                        flight: ballistic(Kind::Recoilless, from, heading * 90.0),
                        team,
                        thrower: id,
                        called_by: 0,
                    },
                )?,
                heading,
            )
        };
        let projectile = self.actors.spawn(Actor::Projectile(round))?;
        out.push(Event::Ordnance(Ordnance::Spawn(projectile)));
        let mut warnings = Completed::default();
        self.actors.warn_infantry_rocket(
            projectile,
            self.now,
            &self.geometry.navigation.planner,
            defense,
            self.rng,
            &mut warnings,
        )?;
        self.apply_ordnance(warnings, out)?;
        out.push(Event::Ordnance(Ordnance::Launch {
            position: from,
            direction: heading,
        }));
        out.push(Event::World(world_combat::Event::Stat("at_launch")));
        let s = self.actors.soldier_mut(id).unwrap();
        if s.vitals.speech_cooldown <= 0.0 {
            s.vitals.speech_cooldown = 2.6;
            out.push(Event::Speech {
                id,
                text: if guided {
                    "Missile away!"
                } else {
                    "Recoilless, fire!"
                }
                .into(),
            });
        }
        Ok(())
    }

    pub fn advance_mount<'a>(
        &mut self,
        id: u32,
        dt: f64,
        gun: Option<MountedGun>,
        owned: &[u32],
        profile: &dyn Fn(&Infantry) -> Option<Profile<'a>>,
        defense: &dyn Fn(&Vehicle) -> Defense<'a>,
        gunfire: &mut Gunfire,
        network: &mut SupplyNetwork,
        impacts: &mut Vec<Report>,
        armor: &dyn Fn(&Vehicle) -> Armor,
        vehicle_hit: &dyn Fn(&Vehicle) -> f64,
    ) -> Result<Vec<Event>, &'static str> {
        let s = self.actors.soldier(id).ok_or("missing mounted infantry")?;
        if !valid_step(dt, self.now, gun)
            || s.duty.kind != Task::Man
            || s.vitals.life != Life::Alive
            || s.duty.phase > 2
            || profile(s).is_some_and(|p| !p.valid())
        {
            return Err("invalid mounted infantry step");
        }
        let st_id = s.duty.entity as u32;
        let Some(st) = self
            .actors
            .structure(st_id)
            .filter(|st| st.built && !st.gone)
        else {
            self.actors
                .release_infantry_mount(id, &self.geometry.navigation.planner)?;
            return Ok(vec![]);
        };
        let kind = st.kind.clone();
        let st_position = st.position;
        let position = match kind.as_str() {
            "watchtower" => st.position + Vector3::Y * 4.25,
            "mortar_pit" => st.position + transform(rotation(st.yaw), Vector3::new(0.0, 0.0, 0.75)),
            "at_post" => st.position + transform(rotation(st.yaw), Vector3::new(0.0, 0.0, -0.4)),
            "mg_nest" | "hmg_nest" => {
                st.mg_mount_position(gun.ok_or("missing mounted gun geometry")?)
            }
            _ => st.position + transform(rotation(st.yaw), Vector3::new(0.0, 0.0, -0.5)),
        };
        let weapon = match kind.as_str() {
            "mg_nest" => "mmg",
            "hmg_nest" => "m2",
            _ => "",
        };
        let mut clock = Mount {
            phase: s.duty.phase,
            timer: s.duty.timer,
            ..Default::default()
        };
        let station = clock.station(dt, kind == "watchtower", s.is_moving())?;
        let s = self.actors.soldier_mut(id).unwrap();
        s.duty.phase = clock.phase;
        s.duty.timer = clock.timer;
        let mut out = vec![];
        match station {
            Station::Move => {
                let speed = self.actors.infantry_speed(id, self.now, self.squads);
                let (_, events) = self.move_infantry_world(id, dt, speed, gun)?;
                out.extend(
                    events
                        .into_iter()
                        .map(|event| Event::Movement { id, event }),
                );
                self.actors
                    .choose_infantry_activity(id, true, self.now, self.squads);
                return Ok(out);
            }
            Station::StartClimb => {
                s.motion.position = Vector3::new(st_position.x, 0.0, st_position.z);
                return Ok(out);
            }
            Station::Climb { height, finished } => {
                s.activity = 25;
                s.motion.position.y = height;
                if !finished {
                    return Ok(out);
                }
                s.orders.base_y = 4.25;
            }
            Station::Man => {
                s.motion.position = position;
                s.identity.mounted_weapon = weapon.into();
                s.vitals.speech_cooldown = 2.6;
                out.push(Event::Speech {
                    id,
                    text: match kind.as_str() {
                        "mortar_pit" => "On the mortar!",
                        "at_post" => "AT post manned!",
                        _ => "Manning the gun!",
                    }
                    .into(),
                });
            }
            Station::Ready => {}
        }
        self.actors.soldier_mut(id).unwrap().motion.position = position;
        match kind.as_str() {
            "mortar_pit" => self.mount_mortar(id, st_id, dt, owned, gun, &mut out)?,
            "at_post" => self.mount_antitank(id, st_id, dt, gun, defense, &mut out)?,
            _ => {
                let s = self.actors.soldier(id).unwrap();
                let threats = self.actors.infantry_threats(
                    id,
                    self.now,
                    self.squads.iter().find(|q| q.id == s.identity.squad),
                )?;
                let s = self.actors.soldier_mut(id).unwrap();
                s.cover.at_cover = true;
                s.cover.kind = 1;
                s.cover.threat = s.threat_direction(&threats)?;
                out.extend(self.advance_infantry_weapon(
                    id,
                    dt,
                    false,
                    if matches!(kind.as_str(), "mg_nest" | "hmg_nest") {
                        Mode::Crew
                    } else {
                        Mode::Normal
                    },
                    gun,
                    profile,
                    gunfire,
                    network,
                    impacts,
                    armor,
                    vehicle_hit,
                )?);
                self.actors
                    .choose_infantry_activity(id, false, self.now, self.squads);
            }
        }
        Ok(out)
    }
}
