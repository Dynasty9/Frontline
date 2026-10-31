//! An explosion finishes each victim and its world effects before considering the next.
use crate::actors::Actor;
use crate::blast::Blast;
use crate::entities::Kind;
use crate::fires;
use crate::infantry::Credit;
use crate::infantry_effects::BlastVictim;
use crate::squad::Report;
use crate::structure_damage::{Damage, Event as StructureEvent};
use crate::supply_network::SupplyNetwork;
use crate::vector::Vector3;
use crate::vehicle::Vehicle;
use crate::vehicle_damage::{Armor, BlastHit};
use crate::vehicle_loss_world::{self, Context};
use crate::world_geometry::Toss;

#[derive(Clone, Copy, Debug)]
pub struct Explosion {
    pub position: Vector3,
    // The old default is 120 for infantry/buildings and 100 for vehicles.
    pub damage: Option<f64>,
    pub radius: f64,
    pub fling: f64,
    pub size: f64,
    pub anti_tank: f64,
    pub track: f64,
    pub top: bool,
    pub direction: Option<Vector3>,
    pub structure_multiplier: f64,
    pub vehicle_multiplier: f64,
    pub source: u32,
    pub owner: i32,
    pub team: i8,
}
impl Default for Explosion {
    fn default() -> Self {
        Self {
            position: Vector3::ZERO,
            damage: None,
            radius: 5.0,
            fling: 8.0,
            size: 1.0,
            anti_tank: 0.0,
            track: 0.3,
            top: false,
            direction: None,
            structure_multiplier: 1.0,
            vehicle_multiplier: 1.0,
            source: 0,
            owner: 0,
            team: -1,
        }
    }
}
impl Explosion {
    pub fn valid(self) -> bool {
        let point = |p: Vector3| p.is_finite() && p.abs().max_element() <= 1_000_000.0;
        point(self.position)
            && self.direction.is_none_or(point)
            && self.owner >= -2
            && (-1..=1).contains(&self.team)
            && self.radius.is_finite()
            && (0.000001..=8192.0).contains(&self.radius)
            && self.size.is_finite()
            && (0.0..=1000.0).contains(&self.size)
            && self.damage.unwrap_or(120.0) * self.structure_multiplier * 6.0 <= 1e12
            && self.damage.unwrap_or(100.0) * self.vehicle_multiplier <= 1e12
            && [
                self.damage.unwrap_or(120.0),
                self.fling,
                self.anti_tank,
                self.track,
                self.structure_multiplier,
                self.vehicle_multiplier,
            ]
            .iter()
            .all(|v| v.is_finite() && (0.0..=1_000_000.0).contains(v))
    }
}
impl From<crate::projectile_actor::Explosion> for Explosion {
    fn from(e: crate::projectile_actor::Explosion) -> Self {
        Self {
            position: e.position,
            damage: Some(e.damage),
            radius: e.radius,
            fling: e.fling,
            size: e.size,
            anti_tank: e.antitank,
            track: e.track,
            top: e.top,
            direction: e.direction,
            structure_multiplier: e.structure_multiplier,
            vehicle_multiplier: 1.0,
            source: e.source,
            owner: e.called_by,
            team: e.team,
        }
    }
}
#[derive(Clone, Debug, PartialEq)]
pub enum Event {
    Infantry(BlastVictim),
    Vehicle(vehicle_loss_world::Event),
    VehicleBlast {
        id: u32,
        hit: BlastHit,
    },
    Structure {
        id: u32,
        damage: Damage,
    },
    Despawn(u32),
    Rubble(u32),
    DroneDown {
        id: u32,
        position: Vector3,
        team: i8,
    },
    Toss {
        id: u32,
        flight: Toss,
    },
    Fire(fires::Event),
    Explosion {
        position: Vector3,
        size: f64,
    },
    Stat(&'static str),
}
impl Context<'_> {
    pub(crate) fn fire_context(&mut self) -> (&mut fires::Fires, fires::Context<'_>) {
        (
            self.fires,
            fires::Context {
                actors: self.actors,
                geometry: self.geometry,
                units: self.units,
                squads: self.squads,
                battle: self.battle,
                deferred: self.deferred,
                visibility: self.visibility,
                rng: self.rng,
                now: self.now,
                town: self.town,
                man: self.man,
                building: self.building,
                role: self.role,
            },
        )
    }

    pub fn damage_structure(
        &mut self,
        id: u32,
        amount: f64,
        source: u32,
        network: &mut SupplyNetwork,
    ) -> Result<Vec<Event>, &'static str> {
        if !amount.is_finite()
            || !(0.0..=1e12).contains(&amount)
            || !self.now.is_finite()
            || !(0.0..=1e12 - 100.0).contains(&self.now)
        {
            return Err("invalid world structure damage");
        }
        let Some(st) = self
            .actors
            .structure(id)
            .filter(|st| !st.gone && !st.indestructible && !(st.kind == "fob" && st.wrecked))
        else {
            return Ok(vec![]);
        };
        let profile = (self.building)(st);
        let lost = st.hp <= amount;
        let team = st.team;
        if profile.player && team >= 0 {
            self.battle.record_hit(id, source, amount, self.actors)?;
            if lost {
                let text = format!("FOB {} wrecked", self.actors.structure(id).unwrap().name);
                self.battle
                    .building_destroyed(id, profile.value, self.now, &text, self.actors)?;
            }
        }
        let mut damage = self.actors.damage_structure(
            id,
            amount,
            source,
            self.battle.blame.as_ref(),
            self.now,
            profile.player,
            Some(55.0),
            &self.geometry.navigation.planner,
            self.deferred,
            self.rng,
        )?;
        let mut out = vec![];
        if damage.events.contains(&StructureEvent::Door) {
            self.geometry.doors.remove(id);
            if let Some(removed) = &mut damage.removed {
                // Opening a door changes the body's last collision state before retirement.
                removed.gone = false;
                let result = self.geometry.refresh_structure_collision(removed);
                removed.gone = true;
                result?;
            } else if let Some(st) = self.actors.structure(id) {
                self.geometry.sync_structure(st, false)?;
                self.geometry.refresh_structure_collision(st)?;
            }
            out.push(Event::Stat("door_kicked"));
        }
        for event in &damage.events {
            if let StructureEvent::Unhidden(id) | StructureEvent::ReleasedGunner(id) = event {
                self.geometry.navigation.planner.cancel(u64::from(*id));
            }
        }
        if let Some(removed) = &mut damage.removed {
            self.geometry.retire_structure(removed, self.actors)?;
        }
        if damage.events.contains(&StructureEvent::FobWrecked) && team >= 0 {
            out.extend(
                network
                    .rebuild(team as u8, self.actors, self.geometry)?
                    .into_iter()
                    .map(Event::Despawn),
            );
        }
        if damage.events.contains(&StructureEvent::IgnitedCar) {
            let (fires, mut context) = self.fire_context();
            let mut events = vec![];
            fires.track_ignition(id, &mut context, &mut events)?;
            out.extend(events.into_iter().map(Event::Fire));
        }
        out.push(Event::Structure { id, damage });
        Ok(out)
    }

    pub fn explode(
        &mut self,
        mut blast: Explosion,
        network: &mut SupplyNetwork,
        impacts: &mut Vec<Report>,
        armor: &dyn Fn(&Vehicle) -> Armor,
    ) -> Result<Vec<Event>, &'static str> {
        if !blast.valid()
            || !self.now.is_finite()
            || !(0.0..=1e12 - 100.0).contains(&self.now)
            || !network.valid()
            || impacts.len() >= 100_000
            || self.squads.iter().any(|q| q.impacts.len() >= 100_000)
        {
            return Err("invalid world explosion");
        }
        if self.actors.get(blast.source).is_none() {
            blast.source = 0;
        }
        let previous = if blast.source == 0 {
            self.battle.set_blame((blast.team >= 0).then_some(Credit {
                owner: blast.owner,
                team: blast.team,
                unit: String::new(),
                soldier: 0,
            }))?
        } else {
            None
        };
        let result = self.explode_inner(blast, network, impacts, armor);
        if blast.source == 0 {
            self.battle.set_blame(previous)?;
        }
        result
    }
    pub fn flush_deferred(
        &mut self,
        network: &mut SupplyNetwork,
        impacts: &mut Vec<Report>,
        armor: &dyn Fn(&Vehicle) -> Armor,
    ) -> Result<Vec<Event>, &'static str> {
        let due = self.deferred.advance_to(self.now)?;
        let mut out = vec![];
        for blast in due {
            out.extend(self.explode(blast.into(), network, impacts, armor)?);
        }
        for rubble in self.deferred.take_rubble() {
            let id = self.geometry.spawn_structure(
                self.actors,
                crate::structure::Structure {
                    kind: "rubble".into(),
                    position: rubble.position,
                    yaw: rubble.yaw,
                    size: rubble.size,
                    ..Default::default()
                },
                None,
            )?;
            out.push(Event::Rubble(id));
        }
        Ok(out)
    }
    fn explode_inner(
        &mut self,
        blast: Explosion,
        network: &mut SupplyNetwork,
        impacts: &mut Vec<Report>,
        armor: &dyn Fn(&Vehicle) -> Armor,
    ) -> Result<Vec<Event>, &'static str> {
        if blast.top && blast.radius >= 3.5 {
            let report = Report {
                position: blast.position,
                time: self.now,
            };
            impacts.push(report);
            let expired = impacts
                .iter()
                .take_while(|r| self.now - r.time > 40.0)
                .count();
            impacts.drain(..expired);
            for squad in &mut *self.squads {
                if squad.members.is_empty() {
                    continue;
                }
                let mut distance = squad.centroid(self.now, self.actors) - blast.position;
                distance.y = 0.0;
                if distance.length() < 45.0 {
                    squad.impacts.push(report);
                }
            }
        }
        let exposure = Blast {
            position: blast.position,
            damage: blast.damage.unwrap_or(120.0),
            radius: blast.radius,
            fling: blast.fling,
            in_trench: false,
        };
        let blame = self.battle.blame.clone();
        let victims = self.actors.blast_infantry_with(
            exposure,
            blast.source,
            self.now,
            blame.as_ref(),
            &self.geometry.terrain,
            self.units,
            &mut self.geometry.collision,
            self.squads,
            |s, squads| {
                let p = (self.man)(s, squads);
                (p.ammunition, p.bearer)
            },
            |actors, squads, id, hit| {
                Self::record_infantry_hit(
                    self.battle,
                    actors,
                    id,
                    hit,
                    (self.man)(actors.soldier(id).unwrap(), squads),
                    self.role,
                )
            },
            self.rng,
        )?;
        let mut out = vec![];
        for victim in victims {
            if victim.flung || victim.hit.as_ref().is_some_and(|h| h.released.is_some()) {
                self.geometry
                    .navigation
                    .planner
                    .cancel(u64::from(victim.soldier));
            }
            out.push(Event::Infantry(victim));
        }
        // Vehicle range queries retain registry order, unlike infantry's spatial buckets.
        let ids: Vec<_> = self
            .actors
            .iter_kind(Kind::Vehicle)
            .filter_map(|actor| {
                let Actor::Vehicle(v) = actor else {
                    unreachable!()
                };
                let delta = v.position - blast.position;
                (f64::from(Vector3::new(delta.x, 0.0, delta.z).length()) <= blast.radius + 4.0)
                    .then_some(v.id)
            })
            .collect();
        for id in ids {
            let Some(vehicle) = self.actors.vehicle_mut(id).filter(|v| !v.gone) else {
                continue;
            };
            let hit = vehicle.explosion_hit(
                self.now,
                armor(vehicle),
                crate::vehicle_damage::Blast {
                    position: blast.position,
                    size: blast.size,
                    anti_tank: blast.anti_tank,
                    direction: blast.direction,
                    top: blast.top,
                    track: blast.track,
                    radius: blast.radius,
                    damage: blast.damage.unwrap_or(100.0),
                    vehicle_multiplier: blast.vehicle_multiplier,
                },
                self.rng,
            )?;
            if hit.anti_tank {
                out.push(Event::Stat("at_hit"));
            }
            if hit.bounced {
                out.push(Event::Stat("at_bounce"));
            }
            if hit.track_broken {
                out.push(Event::Stat("track_broken"));
            }
            out.push(Event::VehicleBlast { id, hit });
            if hit.damage > 0.0 {
                out.extend(
                    self.damage(id, hit.damage, blast.source)?
                        .into_iter()
                        .map(Event::Vehicle),
                );
            }
        }
        for id in self.actors.structures_near(
            &self.geometry.structures,
            blast.position,
            blast.radius + 1.0,
            false,
        )? {
            let Some(st) = self.actors.structure(id).filter(|st| !st.gone) else {
                continue;
            };
            if let Some(amount) = exposure.structure(
                st.position,
                st.radius,
                matches!(st.kind.as_str(), "wire" | "mines"),
                blast.structure_multiplier,
            )? {
                let Some(Actor::Structure(st)) = self.actors.get_mut(id) else {
                    unreachable!()
                };
                st.hit_from = Some(blast.position);
                out.extend(self.damage_structure(id, amount, blast.source, network)?);
            }
        }
        let drones: Vec<_> = self
            .actors
            .iter_kind(Kind::Drone)
            .filter_map(|a| match a {
                Actor::Drone(d)
                    if !d.flight.dead
                        && f64::from(d.flight.position.distance(blast.position)) < blast.radius =>
                {
                    Some(d.id)
                }
                _ => None,
            })
            .collect();
        for id in drones {
            let Some(Actor::Drone(mut drone)) = self.actors.remove(id) else {
                unreachable!()
            };
            drone.shot_down();
            out.push(Event::Stat("drone_shot_down"));
            out.push(Event::DroneDown {
                id,
                position: drone.flight.position,
                team: drone.team,
            });
        }
        if blast.size >= 1.6 {
            for id in self.actors.structures_near(
                &self.geometry.structures,
                blast.position,
                blast.radius + 6.0,
                false,
            )? {
                if let Some(flight) = self.geometry.toss_structure(
                    self.actors,
                    id,
                    blast.position,
                    blast.size,
                    self.rng,
                )? {
                    out.push(Event::Toss { id, flight });
                }
            }
        }
        let (fires, mut context) = self.fire_context();
        out.extend(
            fires
                .blast(blast.position, blast.size, blast.radius, &mut context)?
                .into_iter()
                .map(Event::Fire),
        );
        out.push(Event::Explosion {
            position: blast.position,
            size: blast.size,
        });
        let (changed, _) = self.geometry.terrain.crater(blast.position, blast.size);
        for index in changed {
            self.geometry.navigation.terrain_changed(
                index as usize,
                &self.geometry.terrain,
                &self.geometry.deck,
            )?;
        }
        Ok(out)
    }
}
