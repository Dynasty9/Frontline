//! A crew finishes its shot and shared damage before the weapon consumes its recovery draw.
use crate::actors::{Actor, Actors};
use crate::bullet;
use crate::bullet_world::{Gunfire, Shot};
use crate::fire_targets;
use crate::guided::Kind as GuidedKind;
use crate::infantry::Infantry;
use crate::infantry_action_owned::{Completed, Defense, Event as Ordnance};
use crate::infantry_fight_world::Event as Combat;
use crate::infantry_vitals::Life;
use crate::projectile::Kind;
use crate::squad::Report;
use crate::supply_network::SupplyNetwork;
use crate::vector::{normalized, Vector3};
use crate::vehicle::Vehicle;
use crate::vehicle_artillery::{ArtilleryEvent, ArtilleryProfile};
use crate::vehicle_cannon::{CannonProfile, Muzzle};
use crate::vehicle_damage::Armor;
use crate::vehicle_loss_world::Context;
use crate::vehicle_service::{Service, ServiceEffect, SoldierSupply};
use crate::vehicle_weapon::{Fire, FireProfile, Target, TargetKind};
use crate::world_combat::{self, Explosion};

#[derive(Clone, Copy, Debug)]
pub struct MachineGun<'a> {
    pub weapon: bullet::Weapon,
    pub suppression: f64,
    pub sound: &'a str,
    pub optics: bool,
    pub piercing: bool,
}
#[derive(Clone, Copy, Debug)]
pub struct Profile<'a> {
    pub cycle: FireProfile<'a>,
    pub muzzle: Muzzle,
    pub cannon: Option<CannonProfile>,
    pub machine_gun: Option<MachineGun<'a>>,
}
impl Profile<'_> {
    pub(crate) fn valid(self) -> bool {
        !(!self.cycle.valid()
            || !self.muzzle.valid()
            || self.cycle.cannon != self.cannon.is_some()
            || !self.cycle.machine_gun.is_empty() != self.machine_gun.is_some()
            || self.machine_gun.is_some_and(|gun| {
                !gun.weapon.valid()
                    || !gun.suppression.is_finite()
                    || !(0.0..=1_000_000.0).contains(&gun.suppression)
                    || gun.sound.len() > 128
                    || gun.sound.contains('\0')
                    || gun.weapon.explosive_radius.is_some_and(|radius| {
                        !Explosion {
                            damage: Some(gun.weapon.damage * 1.6),
                            radius,
                            structure_multiplier: 1.5,
                            vehicle_multiplier: 0.1,
                            ..Default::default()
                        }
                        .valid()
                    })
            })
            || self.cannon.is_some_and(|gun| {
                !gun.muzzle.valid()
                    || !Explosion {
                        damage: Some(gun.damage),
                        radius: gun.radius,
                        anti_tank: gun.anti_tank,
                        size: gun.size,
                        structure_multiplier: 2.5,
                        ..Default::default()
                    }
                    .valid()
            }))
    }
}
#[derive(Clone, Debug, PartialEq)]
pub enum Event {
    Combat(Combat),
    Cannon {
        vehicle: u32,
        from: Vector3,
        impact: Vector3,
    },
    Recoil {
        vehicle: u32,
        direction: Vector3,
    },
    Service(ServiceEffect),
}
fn stat(key: &'static str, out: &mut Vec<Event>) {
    out.push(Event::Combat(Combat::World(world_combat::Event::Stat(key))));
}
impl Actors {
    pub fn vehicle_target_valid(&self, id: u32) -> bool {
        match self.get(id) {
            Some(Actor::Soldier(s)) => s.vitals.life == Life::Alive,
            Some(Actor::Drone(d)) => !d.flight.dead,
            Some(_) => true,
            None => false,
        }
    }
}
impl Context<'_> {
    pub fn advance_vehicle_fire<'a>(
        &mut self,
        id: u32,
        profile: Profile<'_>,
        gunfire: &mut Gunfire,
        network: &mut SupplyNetwork,
        impacts: &mut Vec<Report>,
        armor: &dyn Fn(&Vehicle) -> Armor,
        vehicle_hit: &dyn Fn(&Vehicle) -> f64,
        defense: &dyn Fn(&Vehicle) -> Defense<'a>,
    ) -> Result<Vec<Event>, &'static str> {
        let v = self.actors.vehicle(id).ok_or("missing firing vehicle")?;
        if !crate::infantry_fight_world::valid_step(0.0, self.now, None) || !profile.valid() {
            return Err("invalid vehicle weapon profile");
        }
        let target = v.target;
        if !self.actors.vehicle_target_valid(target) {
            return Ok(vec![]);
        }
        let muzzle = v.weapon_muzzle(profile.muzzle, false)?;
        if let Some(gun) = profile.cannon {
            v.weapon_muzzle(gun.muzzle, true)?;
        }
        let actor = self.actors.get(target).unwrap();
        let position = actor.position();
        let kind = match actor {
            Actor::Soldier(s) => {
                let mut nearby = 0;
                if profile.cycle.cannon
                    && v.cannon_timer <= 0.0
                    && v.aim_error(Some(position)) < 0.05
                    && (profile.cycle.base != "tank" || v.aim_time >= 0.3)
                {
                    for other in self.actors.units_near(self.units, position, 5.0, -1)? {
                        if self.actors.soldier(other).is_some_and(|other| {
                            other.identity.team == s.identity.team
                                && other.vitals.life == Life::Alive
                        }) {
                            nearby += 1;
                        }
                    }
                }
                TargetKind::Soldier {
                    nearby,
                    rockets: s.arsenal.rockets > 0,
                    mounted: s.emplacement.structure != 0,
                }
            }
            Actor::Vehicle(v) => {
                let p = armor(v);
                TargetKind::Vehicle {
                    air: p.helicopter && v.position.y > 3.0,
                    armor: p.level,
                }
            }
            Actor::Structure(st) => TargetKind::Structure {
                fortified: matches!(
                    st.kind.as_str(),
                    "bunker" | "mg_nest" | "hmg_nest" | "at_post" | "watchtower"
                ),
            },
            _ => TargetKind::Other,
        };
        let shot = self.actors.vehicle_mut(id).unwrap().choose_weapon(
            self.now,
            profile.cycle,
            Some(Target { position, kind }),
            self.rng,
        )?;
        let recovery_burst = self.actors.vehicle(id).unwrap().mg_burst;
        let mut out = vec![];
        match shot {
            Fire::None => return Ok(out),
            Fire::Sam | Fire::Atgm => {
                let launch = self.actors.launch_vehicle_missile(
                    id,
                    target,
                    if shot == Fire::Sam {
                        GuidedKind::SurfaceToAir
                    } else {
                        GuidedKind::AntiTank
                    },
                    profile.cycle.base == "attack_heli",
                    profile.muzzle.gun_height,
                )?;
                let mut completed = Completed::default();
                completed.events.push(Ordnance::Spawn(launch.id));
                self.actors.warn_infantry_rocket(
                    launch.id,
                    self.now,
                    &self.geometry.navigation.planner,
                    defense,
                    self.rng,
                    &mut completed,
                    crate::traversal::Ground::new(&self.geometry.terrain, &self.geometry.deck),
                )?;
                completed.events.push(Ordnance::Launch {
                    position: launch.position,
                    direction: normalized(launch.velocity),
                });
                completed.stats.push(if shot == Fire::Sam {
                    "veh_sam"
                } else {
                    "veh_atgm"
                });
                let mut combat = vec![];
                self.apply_ordnance(completed, &mut combat)?;
                out.extend(combat.into_iter().map(Event::Combat));
            }
            Fire::Cannon => {
                let cannon = self.actors.fire_vehicle_cannon(
                    id,
                    target,
                    self.now,
                    profile.cannon.unwrap(),
                    &self.geometry.terrain,
                    &mut self.geometry.collision,
                    self.rng,
                    &self.geometry.deck,
                )?;
                out.push(Event::Cannon {
                    vehicle: id,
                    from: cannon.from,
                    impact: cannon.blast.position,
                });
                stat("cannon", &mut out);
                out.extend(
                    self.explode(cannon.blast.into(), network, impacts, armor)?
                        .into_iter()
                        .map(|e| Event::Combat(Combat::World(e))),
                );
            }
            Fire::MachineGun => {
                let gun = profile.machine_gun.unwrap();
                let aim = self.actors.infantry_pose(target).map_or_else(
                    || self.actors.actor_center(target).unwrap(),
                    |s| s.exposed_points().as_slice()[0],
                );
                out.extend(
                    self.fire_bullet(
                        Shot {
                            shooter: id,
                            target,
                            muzzle,
                            aim,
                            weapon: gun.weapon,
                            accuracy: 1.0,
                            optics: gun.optics,
                            piercing: gun.piercing,
                            suppression: gun.suppression,
                            sound: gun.sound,
                        },
                        gunfire,
                        network,
                        impacts,
                        armor,
                        vehicle_hit,
                    )?
                    .into_iter()
                    .map(|e| Event::Combat(Combat::World(e))),
                );
            }
        }
        // A close cannon blast may destroy the firing vehicle itself.
        if let Some(v) = self.actors.vehicle_mut(id) {
            v.finish_weapon(shot, self.now, profile.cycle, self.rng)?;
        } else if shot == Fire::MachineGun && recovery_burst <= 0 {
            // Godot finishes the burst even when its explosive round destroys its own vehicle.
            self.rng.randf_range(0.6, 1.3);
        }
        Ok(out)
    }

    pub fn advance_vehicle_artillery(
        &mut self,
        id: u32,
        dt: f64,
        profile: ArtilleryProfile,
        range: [f64; 2],
        owned: &[u32],
    ) -> Result<Vec<Event>, &'static str> {
        if !crate::infantry_fight_world::valid_step(dt, self.now, None)
            || !profile.valid()
            || range
                .iter()
                .any(|v| !v.is_finite() || !(0.0..=1_000_000.0).contains(v))
            || range[0] > range[1]
        {
            return Err("invalid vehicle artillery profile");
        }
        let v = self.actors.vehicle(id).ok_or("missing artillery vehicle")?;
        let target = if v.artillery_needs_target(self.now) {
            fire_targets::mortar(
                self.actors,
                self.units,
                owned,
                v.team,
                v.position,
                range[0],
                range[1],
            )?
        } else {
            None
        };
        let mut out = vec![];
        match self
            .actors
            .artillery_tick(id, self.now, dt, profile, target)?
        {
            ArtilleryEvent::None => {}
            ArtilleryEvent::Mission => stat("arty_mission", &mut out),
            ArtilleryEvent::Fire => {
                let launch = self
                    .actors
                    .launch_vehicle_shell(id, self.now, profile, self.rng)?;
                out.push(Event::Combat(Combat::Ordnance(Ordnance::Spawn(launch.id))));
                if profile.shell == Kind::Grad {
                    out.push(Event::Combat(Combat::Ordnance(Ordnance::Launch {
                        position: launch.flight.position,
                        direction: normalized(launch.forward + Vector3::Y * 1.2),
                    })));
                } else {
                    out.push(Event::Combat(Combat::Ordnance(Ordnance::Mortar(
                        launch.flight.position,
                    ))));
                    out.push(Event::Recoil {
                        vehicle: id,
                        direction: -launch.forward,
                    });
                }
                stat("arty_round", &mut out);
                self.actors.finish_artillery_round(id, profile)?;
            }
        }
        Ok(out)
    }

    pub fn advance_vehicle_service<'a>(
        &mut self,
        id: u32,
        dt: f64,
        service: Service,
        soldier_stock: &dyn Fn(&Infantry) -> Result<SoldierSupply<'a>, &'static str>,
        vehicle_stock: &dyn Fn(&Vehicle) -> Result<[i32; 2], &'static str>,
    ) -> Result<Vec<Event>, &'static str> {
        let mut out = vec![];
        for event in self.actors.service_vehicle(
            id,
            dt,
            service,
            self.units,
            self.rng,
            soldier_stock,
            vehicle_stock,
        )? {
            let speech = match event {
                ServiceEffect::Repaired { .. } => {
                    stat("veh_repaired", &mut out);
                    None
                }
                ServiceEffect::Reload { soldier, speech } => Some((
                    soldier,
                    ["Reloading!", "Changing mag!", "Cover me, reloading!"][speech as usize],
                )),
                ServiceEffect::Revived { soldier, speech } => {
                    let s = self.actors.soldier(soldier).unwrap();
                    self.battle
                        .add(s.identity.owner, s.identity.team, 23, 1.0)?;
                    stat("revived", &mut out);
                    stat("veh_medevac_revive", &mut out);
                    Some((
                        soldier,
                        [
                            "Thanks, doc.",
                            "I'm good, I'm good!",
                            "Back in the fight.",
                            "Ugh... let's go.",
                        ][speech as usize],
                    ))
                }
            };
            if let Some((id, text)) = speech {
                out.push(Event::Combat(Combat::Speech {
                    id,
                    text: text.into(),
                }));
            }
            out.push(Event::Service(event));
        }
        Ok(out)
    }
}
