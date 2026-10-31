//! Barrel geometry and cannon impacts use the same sockets as the rendered models.
use crate::actors::{Actor, Actors};
use crate::collision::{CollisionWorld, Mat3};
use crate::cover::{rotation, transform};
use crate::projectile_actor::Explosion;
use crate::random::SimulationRandom;
use crate::terrain::{Terrain, TRENCH};
use crate::vector::{normalized, Vector3};
use crate::vehicle::Vehicle;

#[derive(Clone, Copy, Debug)]
pub struct Socket {
    pub point: Vector3,
    pub pivot: Option<Vector3>,
}
#[derive(Clone, Copy, Debug)]
pub struct Muzzle {
    pub socket: Option<Socket>,
    pub helicopter: bool,
    pub gunship: bool,
    pub gun_height: f64,
}
#[derive(Clone, Copy, Debug)]
pub struct CannonProfile {
    pub muzzle: Muzzle,
    pub damage: f64,
    pub radius: f64,
    pub anti_tank: f64,
    pub size: f64,
}
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct CannonShot {
    pub from: Vector3,
    pub blast: Explosion,
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
fn multiply(a: Mat3, b: Mat3) -> Mat3 {
    Mat3::from_cols(
        transform(a, b.x_axis),
        transform(a, b.y_axis),
        transform(a, b.z_axis),
    )
}
impl Vehicle {
    pub fn weapon_muzzle(&self, p: Muzzle, main_gun: bool) -> Result<Vector3, &'static str> {
        if !p.gun_height.is_finite()
            || !(0.0..=1000.0).contains(&p.gun_height)
            || p.socket
                .is_some_and(|s| !point(s.point) || s.pivot.is_some_and(|v| !point(v)))
        {
            return Err("invalid weapon socket");
        }
        let result = if let Some(s) = p.socket {
            let local = s.pivot.map_or(s.point, |pivot| {
                pivot + transform(rotation(self.turret_yaw), s.point - pivot)
            });
            let mut pose = rotation(self.yaw);
            if p.helicopter {
                let (cp, sp) = (
                    libm::cosf(self.flight_pitch as f32),
                    libm::sinf(self.flight_pitch as f32),
                );
                let (cr, sr) = (
                    libm::cosf(self.flight_roll as f32),
                    libm::sinf(self.flight_roll as f32),
                );
                let pitch = Mat3::from_cols(
                    Vector3::X,
                    Vector3::new(0.0, cp, sp),
                    Vector3::new(0.0, -sp, cp),
                );
                let roll = Mat3::from_cols(
                    Vector3::new(cr, sr, 0.0),
                    Vector3::new(-sr, cr, 0.0),
                    Vector3::Z,
                );
                // Preserve Godot's yaw * (pitch * roll) and float32 row-dot rounding.
                pose = multiply(pose, multiply(pitch, roll));
            }
            self.position + transform(pose, local)
        } else {
            let mut turret = self.position + Vector3::Y * p.gun_height as f32;
            if p.gunship {
                turret += direction(self.yaw) * 2.3;
            }
            turret + direction(self.yaw + self.turret_yaw) * if main_gun { 4.2 } else { 1.0 }
        };
        if !point(result) {
            return Err("weapon muzzle exceeds world bounds");
        }
        Ok(result)
    }
}
impl Actors {
    pub fn fire_vehicle_cannon(
        &mut self,
        vehicle: u32,
        target: u32,
        now: f64,
        p: CannonProfile,
        terrain: &Terrain,
        collision: &mut CollisionWorld,
        rng: &mut SimulationRandom,
    ) -> Result<CannonShot, &'static str> {
        if !now.is_finite()
            || now.abs() > 1e12
            || [p.damage, p.radius, p.anti_tank, p.size]
                .into_iter()
                .any(|n| !n.is_finite() || !(0.0..=1e6).contains(&n))
        {
            return Err("invalid cannon profile");
        }
        let v = self.vehicle(vehicle).ok_or("missing cannon vehicle")?;
        let from = v.weapon_muzzle(p.muzzle, true)?;
        let mut aim = self.actor_center(target).ok_or("missing cannon target")?;
        if let Some(Actor::Soldier(s)) = self.get(target) {
            let at = s.motion.position;
            if terrain.layers[TRENCH][terrain.index(at)] > 0
                && terrain.layers[TRENCH][terrain.index(v.position)] == 0
                && !terrain.scene.trench_enfiladed(at, from)
            {
                let to = normalized(flat(at - from));
                let mut distance = 0.3;
                while distance < 3.0
                    && terrain.layers[TRENCH][terrain.index(at - to * distance as f32)] > 0
                {
                    distance += 0.2;
                }
                aim = Vector3::new(at.x, 0.35, at.z) - to * (distance + 0.35) as f32;
            }
        }
        let distance = from.distance(aim);
        let mut random = rng.clone();
        aim += Vector3::new(
            random.randf_range(-1.0, 1.0),
            random.randf_range(-0.4, 0.4),
            random.randf_range(-1.0, 1.0),
        ) * distance
            * 0.012;
        let dir = normalized(aim - from);
        let end = aim + dir * 3.0;
        if !point(aim) || !point(end) {
            return Err("cannon trajectory exceeds world bounds");
        }
        let mut position = collision
            .ray(from, end, &[i64::from(vehicle)])
            .map_or(aim, |hit| hit.position);
        position.y = position.y.max(0.1);
        let blast = Explosion {
            position,
            damage: p.damage,
            radius: p.radius,
            fling: 10.0,
            antitank: p.anti_tank,
            direction: Some(dir),
            top: false,
            track: 0.3,
            source: vehicle,
            team: v.team,
            called_by: 0,
            size: p.size,
            structure_multiplier: 2.5,
        };
        // The world applies the blast after the muzzle event and firing timestamp.
        self.vehicle_mut(vehicle).unwrap().last_fire = now;
        *rng = random;
        Ok(CannonShot { from, blast })
    }
}
