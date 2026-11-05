//! A fired round completes damage and its random draws before suppression and reports.
use crate::actors::Actor;
use crate::bullet::{
    self, Body, Bullet, ShotInput, Target, TargetEffect, TargetKind, TargetLocation,
};
use crate::infantry_effects::Damage;
use crate::infantry_vitals::Life;
use crate::squad::{Contact, Report};
use crate::state_codec::{Reader, Writer};
use crate::supply_network::SupplyNetwork;
use crate::vector::{normalized, Vector3};
use crate::vehicle::Vehicle;
use crate::vehicle_damage::Armor;
use crate::world::WorldContext;
use crate::world_combat::{Event, Explosion};
use std::collections::BTreeMap;

#[derive(Clone, Debug, Default, PartialEq)]
pub struct Gunfire {
    reveal: BTreeMap<u32, f64>,
}
impl Gunfire {
    pub fn reveals(&self) -> &BTreeMap<u32, f64> {
        &self.reveal
    }
    pub fn checkpoint(&self) -> Vec<u8> {
        let mut w = Writer::new(b"FLGF\x01\0\0\0");
        w.u32(self.reveal.len() as u32);
        for (id, time) in &self.reveal {
            w.u32(*id);
            w.f64(*time);
        }
        w.0
    }
    pub fn restore(bytes: &[u8]) -> Result<Self, &'static str> {
        let mut r = Reader::new(bytes, b"FLGF\x01\0\0\0")?;
        let count = r.u32()?;
        if count > 100_000 {
            return Err("too many gunfire reveals");
        }
        let mut state = Self::default();
        let mut last = 0;
        for _ in 0..count {
            let id = r.u32()?;
            let time = r.f64()?;
            if id <= last || !time.is_finite() || !(0.0..=1e12).contains(&time) {
                return Err("invalid gunfire reveal");
            }
            state.reveal.insert(id, time);
            last = id;
        }
        r.finish()?;
        Ok(state)
    }
}

#[derive(Clone, Copy, Debug)]
pub struct Shot<'a> {
    pub shooter: u32,
    pub target: u32,
    pub muzzle: Vector3,
    pub aim: Vector3,
    pub weapon: bullet::Weapon,
    pub accuracy: f64,
    pub optics: bool,
    pub piercing: bool,
    pub suppression: f64,
    pub sound: &'a str,
}

fn location(context: &WorldContext<'_>, id: u32) -> Option<TargetLocation> {
    let actor = context.actors.get(id)?;
    let position = actor.position();
    Some(TargetLocation {
        position,
        center: match actor {
            Actor::Soldier(_) => context.actors.infantry_pose(id)?.center(),
            Actor::Vehicle(_) => position + Vector3::Y * 1.1,
            Actor::Drone(_) => position,
            _ => position + Vector3::Y,
        },
        in_trench: matches!(actor, Actor::Soldier(_))
            && context.geometry.terrain.layers[crate::terrain::TRENCH]
                [context.geometry.terrain.index(position)]
                > 0,
    })
}
fn surface(st: &crate::structure::Structure, p: Vector3) -> u8 {
    match st.kind.as_str() {
        "crates" | "watchtower" | "fence" | "dock" => 4,
        "tree" => {
            if p.y > 2.3 {
                7
            } else {
                4
            }
        }
        "low_wall" => {
            if st.variant % 3 == 1 {
                7
            } else {
                5
            }
        }
        "sandbags" | "mg_nest" | "hmg_nest" | "mortar_pit" | "at_post" | "trench" | "fob"
        | "tunnel" | "medic_tent" => 6,
        "car" | "wreck" | "tank_trap" | "wire" => 3,
        _ => 5,
    }
}
impl WorldContext<'_> {
    pub fn hit_infantry(
        &mut self,
        id: u32,
        amount: f64,
        source: u32,
        direction: Vector3,
        kind: &str,
    ) -> Result<Event, &'static str> {
        let s = self.actors.soldier(id).ok_or("missing hit soldier")?;
        let profile = (self.man)(s, self.squads);
        let hit = self.actors.damage_infantry(
            id,
            Damage {
                amount,
                source,
                direction,
                kind,
                now: self.now,
                ammunition: profile.ammunition,
                bearer: profile.bearer,
                blame: self.battle.blame.as_ref(),
            },
            self.squads,
            self.rng,
        )?;
        Self::record_infantry_hit(self.battle, self.actors, id, &hit, profile, self.role)?;
        if hit.released.is_some() {
            self.geometry.navigation.planner.cancel(u64::from(id));
        }
        Ok(Event::InfantryHit { id, hit })
    }

    pub fn fire_bullet(
        &mut self,
        shot: Shot<'_>,
        gunfire: &mut Gunfire,
        network: &mut SupplyNetwork,
        impacts: &mut Vec<Report>,
        armor: &dyn Fn(&Vehicle) -> Armor,
        vehicle_hit: &dyn Fn(&Vehicle) -> f64,
    ) -> Result<Vec<Event>, &'static str> {
        // Retained roads are validated on load; scanning the whole map per shot defeats batching.
        if !self.now.is_finite()
            || !(0.0..=1e12 - 100.0).contains(&self.now)
            || !shot.suppression.is_finite()
            || !(0.0..=1_000_000.0).contains(&shot.suppression)
            || shot.sound.len() > 128
            || shot.sound.contains('\0')
            || impacts.len() >= 100_000
            || self.squads.iter().any(|q| q.impacts.len() >= 100_000)
            || shot.weapon.explosive_radius.is_some_and(|radius| {
                !Explosion {
                    damage: Some(shot.weapon.damage * 1.6),
                    radius,
                    structure_multiplier: 1.5,
                    vehicle_multiplier: 0.1,
                    ..Default::default()
                }
                .valid()
            })
            || (gunfire.reveal.len() == 100_000 && !gunfire.reveal.contains_key(&shot.shooter))
        {
            return Err("invalid world bullet");
        }
        let shooter = self
            .actors
            .get(shot.shooter)
            .ok_or("missing bullet shooter")?;
        let shooter_position = shooter.position();
        let (owner, team) = match shooter {
            Actor::Soldier(s) => (s.identity.owner, s.identity.team),
            Actor::Vehicle(v) => (v.owner, v.team),
            Actor::Structure(st) => (st.owner, st.team),
            _ => return Err("invalid bullet shooter"),
        };
        let suppression = match shooter {
            Actor::Soldier(s) => Some(s.vitals.suppression),
            _ => None,
        };
        let excluded = [i64::from(shot.shooter)];
        let excluded = if matches!(shooter, Actor::Vehicle(_)) {
            &excluded[..]
        } else {
            &[]
        };
        let target = if shot.target == 0 {
            None
        } else {
            let actor = self
                .actors
                .get(shot.target)
                .ok_or("missing bullet target")?;
            let (kind, hit_factor) = match actor {
                Actor::Soldier(_) => (
                    TargetKind::Infantry,
                    self.actors.infantry_pose(shot.target).unwrap().hit_factor(),
                ),
                Actor::Drone(_) => (TargetKind::Drone, 0.3),
                Actor::Vehicle(v) => (
                    if armor(v).helicopter && v.position.y > 3.0 {
                        TargetKind::AirVehicle
                    } else {
                        TargetKind::Other
                    },
                    vehicle_hit(v),
                ),
                _ => (TargetKind::Other, 1.0),
            };
            Some(Target {
                kind,
                hit_factor,
                terrain_multiplier: if kind == TargetKind::Infantry {
                    self.geometry.terrain.hit(actor.position(), shot.muzzle)
                } else {
                    1.0
                },
                trench_protected: self.actors.soldier(shot.target).is_some_and(|s| {
                    s.motion.ground < -0.6
                        && !self
                            .geometry
                            .terrain
                            .scene
                            .trench_enfiladed(actor.position(), shot.muzzle)
                }),
            })
        };
        let original_location = location(self, shot.target);
        let mut bullet = Bullet::fire(
            ShotInput {
                muzzle: shot.muzzle,
                aim: shot.aim,
                target,
                weapon: shot.weapon,
                accuracy_multiplier: shot.accuracy,
                soldier_suppression: suppression,
                optics: shot.optics,
                excluded,
            },
            &mut crate::collision::RayScene {
                boxes: &mut self.geometry.collision,
                ground: crate::traversal::Ground::new(&self.geometry.terrain, &self.geometry.deck),
            },
            self.visibility,
            self.rng,
        )?;
        let id = bullet
            .ray
            .and_then(|r| u32::try_from(r.body).ok())
            .unwrap_or(0);
        let p = bullet.ray.map_or(Vector3::ZERO, |r| r.position);
        let body = match self.actors.get(id) {
            Some(Actor::Structure(st)) => Body::Structure {
                material: st.cover_material(),
            },
            Some(Actor::Vehicle(_)) => Body::Vehicle,
            _ => Body::Other,
        };
        let material = self.actors.structure(id).map(|st| surface(st, p));
        let effects = bullet.resolve_obstacle(body, self.rng)?;
        let mut out = vec![];
        if effects.penetrated {
            out.extend(self.damage_structure(
                id,
                effects.penetration_damage,
                shot.shooter,
                network,
            )?);
            out.push(Event::Stat("penetration"));
            if let Some(end) = effects.through_end {
                let far = p + normalized(end - p) * 3.0;
                let contacts = self
                    .actors
                    .units_near(self.units, (p + far) * 0.5, 2.0, -1)?
                    .into_iter()
                    .filter_map(|id| {
                        self.actors.soldier(id).map(|s| bullet::ThroughContact {
                            id: u64::from(id),
                            team: i32::from(s.identity.team),
                            alive: s.vitals.life == Life::Alive,
                            center: self.actors.infantry_pose(id).unwrap().center(),
                        })
                    })
                    .collect::<Vec<_>>();
                if let Some(hit) = bullet::through_hit(
                    p,
                    end,
                    &contacts,
                    i32::from(team),
                    shot.weapon.damage,
                    bullet.penetration_multiplier(),
                    self.rng,
                )? {
                    out.push(self.hit_infantry(
                        hit.target as u32,
                        hit.damage,
                        shot.shooter,
                        hit.direction,
                        "bullet",
                    )?);
                    out.push(Event::Stat("through_hit"));
                }
            }
        }
        if effects.vehicle_hit {
            let v = self.actors.vehicle(id).ok_or("missing bullet vehicle")?;
            let profile = armor(v);
            let amount = v.bullet_damage(
                profile,
                shot.weapon.damage,
                shot.piercing,
                shot.weapon.anti_air,
            )?;
            // The old body can ricochet after its destruction has created a wreck.
            let original = (profile.level >= 2).then(|| v.clone());
            if profile.level < 2 || shot.piercing {
                out.extend(
                    self.damage(
                        id,
                        amount,
                        if profile.level >= 2 { 0 } else { shot.shooter },
                    )?
                    .into_iter()
                    .map(Event::Vehicle),
                );
            }
            if let Some(v) = original {
                if let Some(direction) =
                    v.bullet_ricochet(profile, p, bullet.direction, self.rng)?
                {
                    out.push(Event::Ricochet {
                        position: p,
                        direction,
                    });
                    out.push(Event::Stat("ricochet"));
                }
            }
            bullet.set_surface(3)?;
        } else if effects.structure_surface {
            out.extend(self.damage_structure(
                id,
                effects.structure_damage,
                shot.shooter,
                network,
            )?);
            bullet.set_surface(material.unwrap())?;
        }
        match bullet.finish_target(self.rng)? {
            TargetEffect::Damage(damage) => out.push(self.hit_infantry(
                shot.target,
                damage,
                shot.shooter,
                bullet.direction,
                "bullet",
            )?),
            TargetEffect::DownDrone => {
                if matches!(self.actors.get(shot.target), Some(Actor::Drone(d)) if !d.flight.dead) {
                    let Some(Actor::Drone(mut d)) = self.actors.remove(shot.target) else {
                        unreachable!()
                    };
                    d.shot_down();
                    out.push(Event::DroneDown {
                        id: shot.target,
                        position: d.flight.position,
                        team: d.team,
                    });
                    out.push(Event::Stat("drone_shot_down"));
                }
            }
            TargetEffect::None => {}
        }
        self.battle.shot(owner, team, bullet.hit)?;
        let target_location = location(self, shot.target).or(original_location);
        if let Some(blast) = bullet.explosion(target_location, self.rng)? {
            out.extend(self.explode(
                Explosion {
                    position: blast.position,
                    damage: Some(blast.damage),
                    radius: blast.radius,
                    fling: 4.0,
                    size: 0.38,
                    structure_multiplier: 1.5,
                    vehicle_multiplier: 0.1,
                    source: shot.shooter,
                    team,
                    ..Default::default()
                },
                network,
                impacts,
                armor,
            )?);
        }
        out.extend(
            self.actors
                .suppress_bullet(
                    shot.muzzle,
                    bullet.end,
                    team,
                    shot.suppression,
                    if bullet.hit { shot.target } else { 0 },
                    self.now,
                    self.units,
                    self.squads,
                    self.rng,
                )?
                .into_iter()
                .map(Event::Speech),
        );
        if self.now > *gunfire.reveal.get(&shot.shooter).unwrap_or(&0.0) {
            gunfire.reveal.insert(shot.shooter, self.now + 1.5);
            let position = self
                .actors
                .get(shot.shooter)
                .map_or(shooter_position, Actor::position);
            for id in self.actors.units_near(self.units, position, 75.0, -1)? {
                let Some(s) = self.actors.soldier(id).filter(|s| {
                    s.identity.team != team && s.identity.team >= 0 && s.vitals.life == Life::Alive
                }) else {
                    continue;
                };
                if let Some(q) = self.squads.iter_mut().find(|q| q.id == s.identity.squad) {
                    q.report(Contact {
                        id: shot.shooter,
                        report: Report {
                            position,
                            time: self.now,
                        },
                    })?;
                }
            }
        }
        out.push(Event::Shot {
            shooter: shot.shooter,
            target: shot.target,
            muzzle: shot.muzzle,
            end: bullet.end,
            hit: bullet.hit,
            blocked: bullet.ray.is_some(),
            impact: bullet.impact,
            sound: shot.sound.into(),
        });
        Ok(out)
    }
}
