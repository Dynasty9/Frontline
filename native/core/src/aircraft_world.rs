//! Pilots resolve shared targets, cargo, landing sites and deliveries without engine callbacks.
use crate::actors::Actor;
use crate::attack_plan::AttackPlan;
use crate::bullet_world::Gunfire;
use crate::entities::Kind as EntityKind;
use crate::infantry_action_owned::{Completed, Defense, Event as Ordnance};
use crate::infantry_vitals::Life;
use crate::squad::Report;
use crate::supply_network::SupplyNetwork;
use crate::vector::{normalized, Vector3};
use crate::vehicle::Vehicle;
use crate::vehicle_air::{HomeLanding, LiftEvent, SlingTarget, SupplyPoint};
use crate::vehicle_combat_world::{Event as Combat, Profile as Weapons};
use crate::vehicle_damage::Armor;
use crate::vehicle_flight::FlightProfile;
use crate::vehicle_loss_world::Context;
use crate::vehicle_movement_world::Event as Movement;
use crate::vehicle_scan::ScanProfile;
use crate::vehicle_sling::SlingSpec;
use crate::vehicle_world::Event;

#[derive(Clone, Copy, Debug)]
pub enum Kind {
    Lift { capacity: i8 },
    Supply { load: i32 },
    Gunship { rockets: u32 },
    Uav { altitude: f64, radius: f64 },
}
#[derive(Clone, Copy, Debug)]
pub struct Profile<'a> {
    pub kind: Kind,
    pub flight: FlightProfile,
    pub scan: ScanProfile,
    pub weapons: Weapons<'a>,
    pub traverse: [f64; 2],
}
impl Profile<'_> {
    fn valid(self) -> bool {
        self.flight.valid()
            && self.scan.valid()
            && self.weapons.valid()
            && self
                .traverse
                .into_iter()
                .all(|n| n.is_finite() && (0.0..=1000.0).contains(&n))
            && match self.kind {
                Kind::Lift { capacity } => (-1..=2).contains(&capacity),
                Kind::Supply { load } => (0..=1_000_000).contains(&load),
                Kind::Gunship { rockets } => rockets <= 10000,
                Kind::Uav { altitude, radius } => [altitude, radius]
                    .into_iter()
                    .all(|n| n.is_finite() && (0.0..=1_000_000.0).contains(&n)),
            }
    }
}
fn flat(p: Vector3) -> Vector3 {
    Vector3::new(p.x, 0.0, p.z)
}
fn stat(key: &'static str, out: &mut Vec<Event>) {
    out.push(Event::Movement(Movement::Stat(key)));
}
impl Context<'_> {
    pub fn landing_spot(&self, position: Vector3) -> Result<Vector3, &'static str> {
        if !position.is_finite() || position.abs().max_element() > 1e6 {
            return Err("invalid landing search");
        }
        let half = self.geometry.terrain.half() - 8.0;
        for ring in [0.0, 6.0, 11.0, 16.0] {
            let count = if ring == 0.0 { 1 } else { 8 };
            for i in 0..count {
                let angle = i as f64 * std::f64::consts::TAU / count as f64;
                let p = flat(position)
                    + Vector3::new(libm::cos(angle) as f32, 0.0, libm::sin(angle) as f32) * ring;
                if f64::from(p.x.abs()) >= half
                    || f64::from(p.z.abs()) >= half
                    || self.geometry.navigation.planner.kind_at(p, true) != 0
                {
                    continue;
                }
                let clear = self
                    .actors
                    .structures_near(&self.geometry.structures, p, 6.0, false)?
                    .into_iter()
                    .all(|id| {
                        let st = self.actors.structure(id).unwrap();
                        st.kind == "floor"
                            || f64::from(flat(st.position - p).length()) >= st.radius + 4.0
                    });
                if clear {
                    return Ok(p);
                }
            }
        }
        Ok(flat(position))
    }
    fn sling_spec(&self, cargo: u32, capacity: i8) -> Option<SlingSpec> {
        let v = self.actors.vehicle(cargo)?;
        let p = (self.vehicle)(v);
        Some(SlingSpec {
            lift: true,
            capacity,
            cargo_weight: p.weight,
            cargo_helicopter: p.crew.helicopter,
            cargo_boat: p.crew.base == "boat",
            cargo_automatic: p.crew.automatic,
        })
    }
    fn aircraft_collision(&mut self, id: u32) -> Result<(), &'static str> {
        let v = self
            .actors
            .vehicle(id)
            .ok_or("missing aircraft collision")?;
        self.geometry
            .refresh_vehicle_collision(v, (self.vehicle)(v).hull)
    }
    pub fn advance_aircraft<'a>(
        &mut self,
        id: u32,
        dt: f64,
        p: Profile<'_>,
        gunfire: &mut Gunfire,
        network: &mut SupplyNetwork,
        impacts: &mut Vec<Report>,
        plans: &mut Vec<AttackPlan>,
        next_plan: &mut u64,
        income: &mut [Vec<(f64, i32)>; 2],
        armor: &dyn Fn(&Vehicle) -> Armor,
        vehicle_hit: &dyn Fn(&Vehicle) -> f64,
        defense: &dyn Fn(&Vehicle) -> Defense<'a>,
    ) -> Result<Vec<Event>, &'static str> {
        if !p.valid()
            || !crate::infantry_fight_world::valid_step(dt, self.now, None)
            || dt > 10.0
            || income.iter().any(|side| side.len() >= 100_000)
        {
            return Err("invalid aircraft update");
        }
        let v = self.actors.vehicle(id).ok_or("missing aircraft")?;
        if !matches!(p.kind, Kind::Uav { .. }) && v.flight.is_none() {
            return Err("missing rotorcraft flight state");
        }
        if let Some(out) = self.begin_vehicle(id, dt)? {
            return Ok(out);
        }
        let mut out = vec![];
        if matches!(p.kind, Kind::Lift { .. }) {
            let cargo = self.actors.vehicle(id).unwrap().sling_cargo;
            let height = self
                .actors
                .vehicle(cargo)
                .map_or(0.0, |v| f64::from((self.vehicle)(v).hull.y));
            if self.actors.step_sling(id, dt, height)? {
                self.aircraft_collision(cargo)?;
            }
        }
        if !matches!(p.kind, Kind::Supply { .. }) {
            let scan = if matches!(p.kind, Kind::Gunship { .. }) {
                self.actors.vehicle_mut(id).unwrap().gunship_begin(dt)?
            } else {
                let v = self.actors.vehicle_mut(id).unwrap();
                v.scan_timer -= dt;
                let scan = v.scan_timer <= 0.0;
                if scan {
                    v.scan_timer = 0.5;
                }
                scan
            };
            if scan {
                self.scan_vehicle_world(id, p.scan)?;
            }
        }
        let v = self.actors.vehicle(id).unwrap();
        let target = self
            .actors
            .get(v.target)
            .filter(|a| self.actors.vehicle_target_valid(a.identity().id))
            .map(|a| a.position());
        match p.kind {
            Kind::Gunship { .. } => {
                self.actors.vehicle_mut(id).unwrap().gunship_guidance(
                    dt,
                    target,
                    p.flight,
                    &self.geometry.terrain,
                    &self.geometry.deck,
                )?;
                self.aircraft_collision(id)?;
            }
            Kind::Uav { altitude, radius } => {
                self.actors
                    .vehicle_mut(id)
                    .unwrap()
                    .fly_uav(dt, altitude, radius, p.flight)?;
                self.aircraft_collision(id)?;
            }
            _ => {}
        }
        let fire = match p.kind {
            Kind::Supply { .. } => false,
            Kind::Lift { .. } => {
                target.is_some() && self.actors.vehicle(id).unwrap().position.y > 3.0
            }
            Kind::Uav { .. } => target.is_some(),
            Kind::Gunship { .. } => true,
        };
        if fire {
            self.aim_vehicle(id, dt, matches!(p.kind, Kind::Gunship { .. }), p.traverse)?;
            out.extend(
                self.advance_vehicle_fire(
                    id,
                    p.weapons,
                    gunfire,
                    network,
                    impacts,
                    armor,
                    vehicle_hit,
                    defense,
                )?
                .into_iter()
                .map(Event::Combat),
            );
            if self.actors.vehicle(id).is_none() {
                return Ok(out);
            }
        }
        match p.kind {
            Kind::Gunship { rockets } => {
                let v = self.actors.vehicle(id).unwrap();
                let target_id = v.target;
                let target = self
                    .actors
                    .get(target_id)
                    .filter(|_| self.actors.vehicle_target_valid(target_id));
                let target_position = target.map(Actor::position);
                let worth = if v.rocket_timer > 0.0 || v.aim_error(target_position) >= 0.35 {
                    false
                } else {
                    match target {
                        Some(Actor::Vehicle(_) | Actor::Structure(_)) => true,
                        Some(Actor::Soldier(s)) => {
                            self.actors
                                .units_near(self.units, s.motion.position, 6.0, -1)?
                                .into_iter()
                                .filter(|&id| {
                                    self.actors.soldier(id).is_some_and(|o| {
                                        o.identity.team == s.identity.team
                                            && o.vitals.life == Life::Alive
                                    })
                                })
                                .take(3)
                                .count()
                                >= 3
                        }
                        _ => false,
                    }
                };
                if self.actors.vehicle_mut(id).unwrap().gunship_rockets_due(
                    target_position,
                    worth,
                    rockets as i32,
                )? {
                    for index in 0..rockets {
                        let shot = self
                            .actors
                            .launch_vehicle_rocket(id, target_id, index, self.rng)?;
                        let mut completed = Completed::default();
                        completed.events.push(Ordnance::Spawn(shot.id));
                        self.actors.warn_infantry_rocket(
                            shot.id,
                            self.now,
                            &self.geometry.navigation.planner,
                            defense,
                            self.rng,
                            &mut completed,
                        )?;
                        completed.events.push(Ordnance::Launch {
                            position: shot.position,
                            direction: normalized(shot.velocity),
                        });
                        let mut events = vec![];
                        self.apply_ordnance(completed, &mut events)?;
                        out.extend(events.into_iter().map(|e| Event::Combat(Combat::Combat(e))));
                    }
                    self.actors.vehicle_mut(id).unwrap().last_fire = self.now;
                }
            }
            Kind::Lift { capacity } => {
                let v = self.actors.vehicle(id).unwrap();
                let cargo_height = self
                    .actors
                    .vehicle(v.sling_cargo)
                    .map_or(0.0, |c| f64::from((self.vehicle)(c).hull.y));
                let target_spec = self.sling_spec(v.sling_target, capacity);
                let target = if let Some(spec) = target_spec {
                    if self.actors.can_sling(id, v.sling_target, spec)? {
                        let cargo = self.actors.vehicle(v.sling_target).unwrap();
                        Some(SlingTarget {
                            id: cargo.id,
                            position: cargo.position,
                            height: f64::from((self.vehicle)(cargo).hull.y),
                        })
                    } else {
                        None
                    }
                } else {
                    None
                };
                let home = if v.lift_phase == 4 && v.lift_timer <= dt {
                    self.actors
                        .structure(v.heli_home)
                        .filter(|h| h.team == v.team)
                        .map(|h| {
                            self.landing_spot(h.position).map(|landing| HomeLanding {
                                position: h.position,
                                landing,
                            })
                        })
                        .transpose()?
                } else {
                    None
                };
                match self.actors.vehicle_mut(id).unwrap().lift_guidance(
                    dt,
                    p.flight,
                    &self.geometry.terrain,
                    &self.geometry.deck,
                    cargo_height,
                    target,
                    home,
                )? {
                    LiftEvent::Dismount => out.extend(
                        self.dismount_vehicle_world(id, false, plans, next_plan)?
                            .into_iter()
                            .map(Event::Attack),
                    ),
                    LiftEvent::Hook(cargo) => {
                        if self.actors.hook_sling(
                            id,
                            cargo,
                            target_spec.ok_or("missing sling profile")?,
                        )? {
                            stat("sling_hooked", &mut out);
                            out.push(Event::Sling {
                                helicopter: id,
                                cargo,
                                released: false,
                            });
                        }
                    }
                    LiftEvent::Release => {
                        if let Some(cargo) = self
                            .actors
                            .release_sling(id, &self.geometry.navigation.planner)?
                        {
                            self.aircraft_collision(cargo)?;
                            stat("sling_delivered", &mut out);
                            out.push(Event::Sling {
                                helicopter: id,
                                cargo,
                                released: true,
                            });
                        }
                    }
                    LiftEvent::None => {}
                }
                self.aircraft_collision(id)?;
            }
            Kind::Supply { load } => {
                let v = self.actors.vehicle(id).unwrap();
                let team = v.team;
                let valid_fob = |s: &&crate::structure::Structure| s.team == team;
                let destination = self
                    .actors
                    .structure(v.heli_destination)
                    .filter(valid_fob)
                    .map(|s| SupplyPoint {
                        id: s.id,
                        position: s.position,
                        supply: s.supply,
                    });
                let home = if v.heli_phase == 5 {
                    if let Some(home) = self.actors.structure(v.heli_home).filter(valid_fob) {
                        home.position
                    } else {
                        let side = usize::try_from(team)
                            .ok()
                            .filter(|&n| n < 2)
                            .ok_or("supply helicopter has no team")?;
                        self.actors
                            .structure(network.depots[side])
                            .ok_or("missing helicopter supply depot")?
                            .position
                            + Vector3::Z * -12.0
                    }
                } else {
                    Vector3::ZERO
                };
                let fobs = if v.heli_phase == 0 && v.heli_timer <= dt {
                    self.actors
                        .iter_kind(EntityKind::Structure)
                        .filter_map(|a| match a {
                            Actor::Structure(s)
                                if s.kind == "fob" && s.team == team && s.built && !s.wrecked =>
                            {
                                Some(SupplyPoint {
                                    id: s.id,
                                    position: s.position,
                                    supply: s.supply,
                                })
                            }
                            _ => None,
                        })
                        .collect::<Vec<_>>()
                } else {
                    vec![]
                };
                let delivered = self.actors.vehicle_mut(id).unwrap().supply_guidance(
                    dt,
                    p.flight,
                    &self.geometry.terrain,
                    &self.geometry.deck,
                    &fobs,
                    destination,
                    home,
                )?;
                if let Some(id) = delivered {
                    let Some(Actor::Structure(fob)) = self.actors.get_mut(id) else {
                        return Err("missing supply destination");
                    };
                    fob.supply += f64::from(load);
                    if (0..=1).contains(&team) {
                        income[team as usize].push((self.now, load));
                    }
                    out.push(Event::Delivered {
                        team,
                        position: fob.position + Vector3::Y * 4.0,
                        amount: load,
                    });
                    stat("heli_delivered", &mut out);
                }
                self.aircraft_collision(id)?;
            }
            Kind::Uav { .. } => {}
        }
        if let Some(v) = self.actors.vehicle_mut(id) {
            v.update_flags(self.now, true, false)?;
        }
        Ok(out)
    }
}
