//! Flight resolves shared holders and targets, then applies impacts in emission order.
use crate::actors::Actor;
use crate::entities::Kind as ActorKind;
use crate::infantry_controller::Task;
use crate::infantry_vitals::Life;
use crate::projectile::{Holder, Kind};
use crate::projectile_actor::{Event as Flight, Motion, Projectile, Smotherer, Step};
use crate::squad::Report;
use crate::supply_network::SupplyNetwork;
use crate::vector::Vector3;
use crate::vehicle::Vehicle;
use crate::vehicle_damage::Armor;
use crate::vehicle_loss_world::Context;
use crate::visibility::Smoke;
use crate::world_combat;

#[derive(Clone, Debug, PartialEq)]
pub enum Event {
    Combat(world_combat::Event),
    Spawn(u32),
    Smothered {
        soldier: u32,
        team: i8,
        position: Vector3,
        name: String,
    },
    Sound {
        name: &'static str,
        volume: f64,
        position: Vector3,
    },
}

impl Context<'_> {
    pub fn advance_projectile_world(
        &mut self,
        id: u32,
        dt: f64,
        marks: &mut [Vec<[f32; 4]>; 2],
        network: &mut SupplyNetwork,
        impacts: &mut Vec<Report>,
        armor: &dyn Fn(&Vehicle) -> Armor,
    ) -> Result<Vec<Event>, &'static str> {
        if !crate::infantry_fight_world::valid_step(dt, self.now, None) {
            return Err("invalid projectile world time");
        }
        let Some(Actor::Projectile(p)) = self.actors.get(id) else {
            return Err("missing advancing projectile");
        };
        let holder = if p.held_by == 0 {
            Holder::Free
        } else if let Some(s) = self
            .actors
            .soldier(p.held_by)
            .filter(|s| s.vitals.life == Life::Alive)
        {
            let forward = Vector3::new(
                -libm::sin(s.motion.yaw) as f32,
                0.0,
                -libm::cos(s.motion.yaw) as f32,
            );
            Holder::Alive(s.motion.position + Vector3::new(0.0, 1.3, 0.0) + forward * 0.3)
        } else {
            Holder::Dropped
        };
        let target = self.actors.actor_center(p.target_id);
        let smoke = matches!(&p.motion, Motion::Guided(f) if f.checks_smoke(dt))
            && target
                .zip(self.actors.get(p.thrower))
                .is_some_and(|(target, source)| {
                    self.visibility
                        .smoke_blocks(source.position() + Vector3::Y * 1.5, target)
                });
        let smotherer = self.actors.soldier(p.smothered_by).map(|s| Smotherer {
            id: s.identity.id,
            position: s.motion.position,
            yaw: s.motion.yaw,
            alive: s.vitals.life == Life::Alive,
            covering: s.duty.kind == Task::Smother,
        });
        let mut candidates = vec![];
        if let Motion::Support(f) = &p.motion {
            if f.needs_candidates(dt) {
                for sid in self.actors.units_near(self.units, f.target, 38.0, -1)? {
                    if let Some(s) = self.actors.soldier(sid).filter(|s| {
                        s.vitals.life == Life::Alive && (p.team < 0 || s.identity.team != p.team)
                    }) {
                        candidates.push(s.motion.position);
                    }
                }
                // The gunship gives vehicles twice the weight, in vehicle registration order.
                for actor in self.actors.iter_kind(ActorKind::Vehicle) {
                    let Actor::Vehicle(v) = actor else {
                        unreachable!()
                    };
                    let d = v.position - f.target;
                    if (p.team < 0 || v.team != p.team)
                        && Vector3::new(d.x, 0.0, d.z).length() <= 40.0
                    {
                        candidates.extend([v.position; 2]);
                    }
                }
            }
        }
        // Only vehicles have exclusion bodies; infantry and structures inherit an empty list.
        let excluded = if matches!(
            &p.motion,
            Motion::Guided(_)
                | Motion::Ballistic(crate::projectile::Flight {
                    kind: Kind::Rocket | Kind::Recoilless,
                    ..
                })
        ) && self.actors.vehicle(p.thrower).is_some()
            && self.geometry.collision.contains(i64::from(p.thrower))
        {
            vec![i64::from(p.thrower)]
        } else {
            vec![]
        };
        let Some(Actor::Projectile(p)) = self.actors.get_mut(id) else {
            unreachable!()
        };
        let events = p.advance(
            Step {
                dt,
                time: self.now,
                map_half: self.geometry.terrain.n as f64 * 0.5,
                holder,
                target,
                smoke,
                smotherer,
                candidates: &candidates,
                excluded: &excluded,
            },
            &mut self.geometry.collision,
            self.rng,
        )?;
        if let Motion::Ballistic(f) = &p.motion {
            if f.kind == Kind::Smoke
                && !self.visibility.set_projectile(
                    u64::from(id),
                    Smoke {
                        center: f.position,
                        radius: f.smoke_radius,
                    },
                )
            {
                return Err("projectile smoke limit exceeded");
            }
        }
        let mut out = vec![];
        for event in events {
            match event {
                Flight::Explosion(blast) => out.extend(
                    self.explode(blast.into(), network, impacts, armor)?
                        .into_iter()
                        .map(Event::Combat),
                ),
                Flight::Spawn(spawn) => {
                    let id = self
                        .actors
                        .spawn(Actor::Projectile(Projectile::from_spawn(1, spawn)?))?;
                    out.push(Event::Spawn(id));
                }
                Flight::DamageSmotherer { soldier, source } => out.push(Event::Combat(
                    self.hit_infantry(soldier, 900.0, source, Vector3::Y, "explosion")?,
                )),
                Flight::SmotherNotice(id) => {
                    if let Some(s) = self.actors.soldier(id) {
                        out.push(Event::Smothered {
                            soldier: id,
                            team: s.identity.team,
                            position: s.motion.position,
                            name: s.identity.name.clone(),
                        });
                    }
                }
                Flight::Photograph {
                    team,
                    position,
                    radius,
                    linger,
                } => {
                    if team >= 0 {
                        marks[team as usize].push([
                            position.x,
                            position.z,
                            radius as f32,
                            (self.now + linger) as f32,
                        ]);
                        out.push(Event::Combat(world_combat::Event::Stat("recon_photo")));
                    }
                }
                Flight::Sound {
                    name,
                    volume,
                    position,
                } => out.push(Event::Sound {
                    name,
                    volume,
                    position,
                }),
                Flight::Stat(key) => out.push(Event::Combat(world_combat::Event::Stat(key))),
                Flight::Despawn => {
                    self.actors.remove(id);
                    self.visibility.remove_projectile(u64::from(id));
                    out.push(Event::Combat(world_combat::Event::Despawn(id)));
                }
            }
        }
        Ok(out)
    }

    pub fn advance_drone_world(
        &mut self,
        id: u32,
        dt: f64,
        network: &mut SupplyNetwork,
        impacts: &mut Vec<Report>,
        armor: &dyn Fn(&Vehicle) -> Armor,
    ) -> Result<Vec<Event>, &'static str> {
        if !crate::infantry_fight_world::valid_step(dt, self.now, None) {
            return Err("invalid drone world time");
        }
        let Some(blast) = self.actors.step_drone(
            id,
            dt,
            &mut self.geometry.collision,
            self.geometry.terrain.n as f32 * 0.5,
        )?
        else {
            return Ok(vec![]);
        };
        let mut out = vec![Event::Combat(world_combat::Event::Stat("drone_boom"))];
        out.extend(
            self.explode(blast.into(), network, impacts, armor)?
                .into_iter()
                .map(Event::Combat),
        );
        self.actors.remove(id);
        out.push(Event::Combat(world_combat::Event::Despawn(id)));
        Ok(out)
    }
}
