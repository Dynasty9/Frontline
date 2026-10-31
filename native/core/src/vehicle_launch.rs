//! Projectile creation precedes launch warnings and weapon-cycle completion.
use crate::actors::{Actor, Actors};
use crate::entities::MAX_ENTITIES;
use crate::guided::{GuidedFlight, Kind as GuidedKind};
use crate::projectile::Kind;
use crate::projectile_actor::{ballistic, ballistic_velocity, Motion, Projectile, Spawn};
use crate::random::SimulationRandom;
use crate::vector::{normalized, Vector3};

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Launch {
    pub id: u32,
    pub position: Vector3,
    pub velocity: Vector3,
}
#[derive(Clone, Copy, Debug)]
pub struct SmokeProfile {
    pub armor: u8,
    pub helicopter: bool,
    pub gun_height: f64,
}
fn point(p: Vector3) -> bool {
    p.is_finite() && p.abs().max_element() <= 1_000_000.0
}
fn flat(p: Vector3) -> Vector3 {
    Vector3::new(p.x, 0.0, p.z)
}
fn direction(yaw: f64) -> Vector3 {
    Vector3::new(-libm::sin(yaw) as f32, 0.0, -libm::cos(yaw) as f32)
}
impl Actors {
    pub fn launch_vehicle_rocket(
        &mut self,
        vehicle: u32,
        target: u32,
        index: u32,
        rng: &mut SimulationRandom,
    ) -> Result<Launch, &'static str> {
        if index > 10000 {
            return Err("invalid rocket index");
        }
        let v = self.vehicle(vehicle).ok_or("missing rocket carrier")?;
        let aim = self.actor_center(target).ok_or("missing rocket target")?;
        let forward = direction(v.yaw);
        let side = forward.cross(Vector3::Y);
        let position = v.position
            + Vector3::Y * 1.2
            + side * if index % 2 == 0 { 1.0 } else { -1.0 } * 1.1
            + forward;
        let mut random = rng.clone();
        let aim = aim
            + Vector3::new(
                random.randf_range(-2.5, 2.5),
                0.0,
                random.randf_range(-2.5, 2.5),
            );
        let velocity = normalized(aim - position) * 75.0;
        let projectile = Projectile::from_spawn(
            1,
            Spawn {
                flight: ballistic(Kind::Rocket, position, velocity),
                team: v.team,
                thrower: vehicle,
                called_by: 0,
            },
        )?;
        // The caller handles this rocket's warning before the next rocket consumes scatter draws.
        let id = self.spawn(Actor::Projectile(projectile))?;
        *rng = random;
        Ok(Launch {
            id,
            position,
            velocity,
        })
    }
    fn actor_center(&self, id: u32) -> Option<Vector3> {
        Some(match self.get(id)? {
            Actor::Soldier(s) => {
                crate::infantry_pose::center(s.motion.position, s.posture, s.vitals.life)
            }
            Actor::Vehicle(v) => v.position + Vector3::Y * 1.1,
            Actor::Structure(s) => s.position + Vector3::Y,
            Actor::Drone(d) => d.flight.position,
            Actor::Projectile(p) => p.motion.position() + Vector3::Y,
        })
    }
    pub fn launch_vehicle_missile(
        &mut self,
        vehicle: u32,
        target: u32,
        kind: GuidedKind,
        gunship: bool,
        gun_height: f64,
    ) -> Result<Launch, &'static str> {
        if !gun_height.is_finite() || !(0.0..=1000.0).contains(&gun_height) {
            return Err("invalid missile launch profile");
        }
        let v = self.vehicle(vehicle).ok_or("missing launcher")?;
        let aim = self.actor_center(target).ok_or("missing missile target")?;
        let forward = direction(v.yaw + v.turret_yaw);
        let mut turret = v.position + Vector3::Y * gun_height as f32;
        if gunship {
            turret += direction(v.yaw) * 2.3;
        }
        let position = turret + forward + Vector3::Y * 0.45;
        let at = kind == GuidedKind::AntiTank;
        let velocity =
            normalized(normalized(aim - position) + Vector3::Y * if at { 0.3 } else { 0.5 })
                * if at { 26.0 } else { 38.0 };
        let p = Projectile {
            id: 0,
            team: v.team,
            thrower: vehicle,
            called_by: 0,
            held_by: 0,
            smothered_by: 0,
            handler: 0,
            thrown_back: 0,
            target_id: target,
            motion: Motion::Guided(GuidedFlight {
                kind,
                position,
                velocity,
                target: aim,
                life: 0.0,
                locked: true,
                dead: false,
            }),
        };
        let id = self.spawn(Actor::Projectile(p))?;
        Ok(Launch {
            id,
            position,
            velocity,
        })
    }
    pub fn projectile_warning_target(&self, projectile: u32) -> Result<Option<u32>, &'static str> {
        let Some(Actor::Projectile(p)) = self.get(projectile) else {
            return Err("missing warning projectile");
        };
        let (position, velocity) = match &p.motion {
            Motion::Guided(f) if f.kind == GuidedKind::AntiTank => (f.position, f.velocity),
            Motion::Ballistic(f) if matches!(f.kind, Kind::Rocket | Kind::Recoilless) => {
                (f.position, f.velocity)
            }
            _ => return Ok(None),
        };
        if self.vehicle(p.target_id).is_some() {
            return Ok(Some(p.target_id));
        }
        let direction = normalized(velocity);
        let ahead = position + direction * 40.0;
        // The first vehicle in registration order sees the launch, even if another is closer.
        for actor in self.iter() {
            let Actor::Vehicle(v) = actor else {
                continue;
            };
            if v.team == p.team || v.gone || flat(v.position - ahead).length() > 45.0 {
                continue;
            }
            let delta = v.position - position;
            if delta.length() < 100.0 && f64::from(normalized(delta).dot(direction)) > 0.97 {
                return Ok(Some(v.id));
            }
        }
        Ok(None)
    }
    pub fn launch_vehicle_smoke(
        &mut self,
        vehicle: u32,
        now: f64,
        from: Vector3,
        p: SmokeProfile,
        rng: &mut SimulationRandom,
    ) -> Result<Vec<Launch>, &'static str> {
        if !now.is_finite()
            || now.abs() > 1e12
            || !point(from)
            || p.armor > 3
            || !p.gun_height.is_finite()
            || !(0.0..=1000.0).contains(&p.gun_height)
        {
            return Err("invalid smoke response");
        }
        let v = self.vehicle(vehicle).ok_or("missing smoke carrier")?;
        if v.gone
            || p.armor < 1
            || (p.helicopter && v.position.y > 3.0)
            || v.smoke_left <= 0
            || now < v.smoke_until
        {
            return Ok(Vec::new());
        }
        if now + 25.0 > 1e12
            || self.entities().next_id() + 3 > u32::MAX as u64
            || self.entities().len() > MAX_ENTITIES - 4
        {
            return Err("smoke response exceeds match limits");
        }
        let to = normalized(flat(from - v.position));
        let top = v.position + Vector3::Y * (p.gun_height + 0.3) as f32;
        let mut random = rng.clone();
        let mut projectiles = Vec::with_capacity(4);
        for i in 0..4 {
            let direction =
                crate::cover::transform(crate::cover::rotation((i as f64 - 1.5) * 0.32), to);
            let land = v.position + direction * random.randf_range(11.0, 16.0);
            let mut flight = ballistic(Kind::Smoke, top, ballistic_velocity(top, land));
            flight.fuse = 0.0;
            projectiles.push(Projectile::from_spawn(
                (self.entities().next_id() + i) as u32,
                Spawn {
                    flight,
                    team: v.team,
                    thrower: vehicle,
                    called_by: 0,
                },
            )?);
        }
        let v = self.vehicle_mut(vehicle).unwrap();
        v.smoke_until = now + 25.0;
        v.smoke_left -= 1;
        let mut launches = Vec::with_capacity(4);
        // All identities and trajectories are validated before changing shared state or randomness.
        for p in projectiles {
            let Motion::Ballistic(f) = &p.motion else {
                unreachable!()
            };
            let position = f.position;
            let velocity = f.velocity;
            let id = self.spawn(Actor::Projectile(p))?;
            launches.push(Launch {
                id,
                position,
                velocity,
            });
        }
        *rng = random;
        Ok(launches)
    }
}
