//! Guns retain fire missions and laying clocks; each round is spawned before its salvo advances.
use crate::actors::{Actor, Actors};
use crate::projectile::{Flight, Kind};
use crate::projectile_actor::{ballistic, Projectile, Spawn};
use crate::random::SimulationRandom;
use crate::vector::Vector3;
use crate::vehicle::Vehicle;
use std::f64::consts::{PI, TAU};

#[derive(Clone, Copy, Debug)]
pub struct ArtilleryProfile {
    pub shell: Kind,
    pub gun_height: f64,
    pub muzzle: f64,
    pub scatter: f64,
    pub salvo: i32,
    pub lay: f64,
    pub gap: f64,
    pub cooldown: f64,
    pub traverse: f64,
    pub traverse_accel: f64,
}
impl ArtilleryProfile {
    pub fn valid(self) -> bool {
        matches!(self.shell, Kind::Arty | Kind::Grad)
            && (1..=10000).contains(&self.salvo)
            && [
                self.gun_height,
                self.muzzle,
                self.scatter,
                self.lay,
                self.gap,
                self.cooldown,
                self.traverse,
                self.traverse_accel,
            ]
            .into_iter()
            .all(|n| n.is_finite() && (0.0..=1000.0).contains(&n))
    }
}
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ArtilleryEvent {
    None,
    Mission,
    Fire,
}
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct ShellLaunch {
    pub id: u32,
    pub forward: Vector3,
    pub flight: Flight,
}
fn point(p: Vector3) -> bool {
    p.is_finite() && p.abs().max_element() <= 1_000_000.0
}
fn scalar(n: f64) -> bool {
    n.is_finite() && n.abs() <= 1e12
}
fn flat(p: Vector3) -> Vector3 {
    Vector3::new(p.x, 0.0, p.z)
}

impl Vehicle {
    pub fn artillery_needs_target(&self, now: f64) -> bool {
        self.salvo == 0
            && !self.path_pending
            && self.path_index as usize >= self.path.len()
            && now >= self.artillery_until
            && self.fire_queue.is_empty()
    }
    pub fn artillery_tick(
        &mut self,
        now: f64,
        dt: f64,
        p: ArtilleryProfile,
        auto_target: Option<Vector3>,
    ) -> Result<ArtilleryEvent, &'static str> {
        if !scalar(now)
            || !dt.is_finite()
            || !(0.0..=3600.0).contains(&dt)
            || !p.valid()
            || !scalar(now + p.cooldown)
            || !scalar(now + 2.0)
            || !scalar(self.salvo_timer - dt)
            || auto_target.is_some_and(|v| !point(v))
            || (self.salvo > 0 && self.salvo_at.is_none())
        {
            return Err("invalid artillery step");
        }
        if self.salvo > 0 {
            let delta = flat(self.salvo_at.unwrap() - self.position);
            let wanted = libm::atan2(-f64::from(delta.x), -f64::from(delta.z)) - self.yaw;
            self.slew_turret(wanted, dt, false, false, p.traverse, p.traverse_accel)?;
            self.lay_yaw = Some(wanted);
            self.salvo_timer -= dt;
            let error = wanted - self.turret_yaw;
            let error = error - TAU * libm::floor((error + PI) / TAU);
            return Ok(if self.salvo_timer <= 0.0 && error.abs() < 0.06 {
                ArtilleryEvent::Fire
            } else {
                ArtilleryEvent::None
            });
        }
        if self.path_pending
            || (self.path_index as usize) < self.path.len()
            || now < self.artillery_until
        {
            return Ok(ArtilleryEvent::None);
        }
        let target = if self.fire_queue.is_empty() {
            auto_target
        } else {
            Some(self.fire_queue.remove(0))
        };
        let Some(target) = target else {
            self.artillery_until = now + 2.0;
            return Ok(ArtilleryEvent::None);
        };
        self.salvo_at = Some(target);
        self.salvo = p.salvo;
        self.salvo_timer = p.lay;
        self.artillery_until = now + p.cooldown;
        Ok(ArtilleryEvent::Mission)
    }
    pub fn finish_artillery_round(&mut self, p: ArtilleryProfile) -> Result<(), &'static str> {
        if !p.valid() || self.salvo <= 0 {
            return Err("no active artillery salvo");
        }
        self.salvo -= 1;
        self.salvo_timer = p.gap;
        if self.salvo == 0 {
            self.lay_yaw = None;
        }
        Ok(())
    }
}
impl Actors {
    pub fn artillery_needs_target(&self, vehicle: u32, now: f64) -> Result<bool, &'static str> {
        if !scalar(now) {
            return Err("invalid artillery time");
        }
        Ok(self
            .vehicle(vehicle)
            .ok_or("missing artillery vehicle")?
            .artillery_needs_target(now))
    }
    pub fn artillery_tick(
        &mut self,
        vehicle: u32,
        now: f64,
        dt: f64,
        p: ArtilleryProfile,
        target: Option<Vector3>,
    ) -> Result<ArtilleryEvent, &'static str> {
        self.vehicle_mut(vehicle)
            .ok_or("missing artillery vehicle")?
            .artillery_tick(now, dt, p, target)
    }
    pub fn finish_artillery_round(
        &mut self,
        vehicle: u32,
        p: ArtilleryProfile,
    ) -> Result<(), &'static str> {
        self.vehicle_mut(vehicle)
            .ok_or("missing artillery vehicle")?
            .finish_artillery_round(p)
    }
    pub fn launch_vehicle_shell(
        &mut self,
        vehicle: u32,
        now: f64,
        p: ArtilleryProfile,
        rng: &mut SimulationRandom,
    ) -> Result<ShellLaunch, &'static str> {
        if !scalar(now) || !p.valid() {
            return Err("invalid shell launch");
        }
        let v = self.vehicle(vehicle).ok_or("missing artillery vehicle")?;
        let target = v.salvo_at.ok_or("missing fire mission")?;
        let yaw = v.yaw + v.turret_yaw;
        let forward = Vector3::new(-libm::sin(yaw) as f32, 0.0, -libm::cos(yaw) as f32);
        let from =
            v.position + Vector3::Y * (p.gun_height + 1.2) as f32 + forward * p.muzzle as f32;
        let distance = f64::from(flat(target - from).length());
        let scatter = p.scatter + distance * 0.025;
        let mut random = rng.clone();
        let angle = f64::from(random.randf()) * TAU;
        let radius = libm::sqrt(f64::from(random.randf())) * scatter;
        let target = Vector3::new(
            (f64::from(target.x) + libm::cos(angle) * radius) as f32,
            0.05,
            (f64::from(target.z) + libm::sin(angle) * radius) as f32,
        );
        let mut flight = ballistic(p.shell, from, Vector3::ZERO);
        flight.origin = from;
        flight.target = target;
        flight.shell_duration = 2.6 + distance / 45.0;
        let projectile = Projectile::from_spawn(
            1,
            Spawn {
                flight,
                team: v.team,
                thrower: vehicle,
                called_by: 0,
            },
        )?;
        let id = self.spawn(Actor::Projectile(projectile))?;
        self.vehicle_mut(vehicle).unwrap().last_fire = now;
        *rng = random;
        Ok(ShellLaunch {
            id,
            forward,
            flight,
        })
    }
}
