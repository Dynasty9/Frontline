//! Rotorcraft guidance retains momentum, hover braking and cyclic attitude.
use crate::terrain::Terrain;
use crate::vector::{normalized, Vector3};
use crate::vehicle::Vehicle;
use crate::vehicle_motion::slew;

#[derive(Clone, Copy, Debug)]
pub struct FlightProfile {
    pub speed: f64,
    pub accel: f64,
    pub brake: f64,
    pub turn: f64,
    pub turn_accel: f64,
}
fn point(p: Vector3) -> bool {
    p.is_finite() && p.abs().max_element() <= 1_000_000.0
}
fn flat(p: Vector3) -> Vector3 {
    Vector3::new(p.x, 0.0, p.z)
}
fn toward(a: f64, b: f64, delta: f64) -> f64 {
    if (a - b).abs() <= delta {
        b
    } else {
        a + (b - a).signum() * delta
    }
}
fn move_toward(a: Vector3, b: Vector3, delta: f64) -> Vector3 {
    let v = b - a;
    let len = v.length();
    let delta = delta as f32;
    if len <= delta || len < 0.00001 {
        b
    } else {
        a + Vector3::new(v.x / len, v.y / len, v.z / len) * delta
    }
}
fn ground(p: Vector3, terrain: &Terrain, deck: &[u8]) -> f64 {
    terrain
        .ground_y(p, !deck.is_empty() && deck[terrain.index(p)] != 0)
        .max(0.0)
}
impl FlightProfile {
    pub(crate) fn valid(self) -> bool {
        [
            self.speed,
            self.accel,
            self.brake,
            self.turn,
            self.turn_accel,
        ]
        .iter()
        .all(|v| v.is_finite() && (0.0..=1000.0).contains(v))
    }
}
impl Vehicle {
    fn integrate_flight(
        &mut self,
        goal: Vector3,
        dt: f64,
        face: Option<f64>,
        p: FlightProfile,
        terrain: &Terrain,
        deck: &[u8],
    ) {
        let loaded = self.sling_cargo != 0;
        let accel = p.accel * if loaded { 0.55 } else { 1.0 };
        let brake = p.brake * if loaded { 0.65 } else { 1.0 };
        let maximum = p.speed * if loaded { 0.65 } else { 1.0 };
        let to = flat(goal - self.position);
        let distance = f64::from(to.length());
        let approach = maximum.min(libm::sqrt(2.0 * brake * distance).min(distance * 1.5));
        let desired = normalized(to) * approach as f32;
        let before = flat(self.velocity);
        let slowing = desired.dot(before) < before.length_squared();
        let horizontal = move_toward(before, desired, (if slowing { brake } else { accel }) * dt);
        let acceleration = (horizontal - before) / dt as f32;
        let ahead = self.position + horizontal * 0.8;
        let altitude = f64::from(goal.y).max(ground(ahead, terrain, deck) + 0.15);
        let error = altitude - f64::from(self.position.y);
        let sign = if error == 0.0 { 0.0 } else { error.signum() };
        let wanted = sign * 6.0f64.min(libm::sqrt(6.0 * error.abs()).min(error.abs() * 1.5));
        let vertical = toward(f64::from(self.velocity.y), wanted, 4.0 * dt);
        self.velocity = Vector3::new(horizontal.x, vertical as f32, horizontal.z);
        self.position += self.velocity * dt as f32;
        let floor = ground(self.position, terrain, deck);
        if f64::from(self.position.y) < floor + 0.15 {
            self.position.y = (floor + 0.15) as f32;
            self.velocity.y = self.velocity.y.max(0.0);
        }
        self.speed = f64::from(horizontal.length());
        let heading = face.unwrap_or_else(|| {
            if distance > 1.0 {
                libm::atan2(-f64::from(to.x), -f64::from(to.z))
            } else {
                self.yaw
            }
        });
        let state = self.flight.as_mut().unwrap();
        let turn = slew(
            self.yaw,
            state[2],
            heading,
            p.turn * if loaded { 0.75 } else { 1.0 },
            p.turn_accel,
            dt,
            true,
        );
        state[2] = f64::from(turn[1]);
        self.yaw = f64::from(turn[0]);
        let forward = Vector3::new(
            -libm::sin(self.yaw) as f32,
            0.0,
            -libm::cos(self.yaw) as f32,
        );
        let right = forward.cross(Vector3::Y);
        let thrust = acceleration + horizontal * 0.055;
        let airborne = ((f64::from(self.position.y) - floor - 0.15) / 2.0).clamp(0.0, 1.0);
        let pitch =
            (-libm::atan2(f64::from(thrust.dot(forward)), 9.81)).clamp(-0.42, 0.42) * airborne;
        let roll = (-libm::atan2(f64::from(thrust.dot(right)), 9.81)).clamp(-0.48, 0.48) * airborne;
        let blend = 1.0 - libm::exp(-dt * 5.0);
        state[0] += (pitch - state[0]) * blend;
        state[1] += (roll - state[1]) * blend;
    }
    pub fn fly_to(
        &mut self,
        goal: Vector3,
        dt: f64,
        face: Option<f64>,
        profile: FlightProfile,
        terrain: &Terrain,
        deck: &[u8],
    ) -> Result<bool, &'static str> {
        if !point(goal)
            || !dt.is_finite()
            || !(0.0..=3600.0).contains(&dt)
            || !profile.valid()
            || self.flight.is_none()
            || face.is_some_and(|v| !v.is_finite() || v.abs() > 1e12)
            || (!deck.is_empty() && deck.len() != terrain.n * terrain.n)
        {
            return Err("invalid helicopter step");
        }
        let mut left = dt;
        while left > 0.00001 {
            let h = left.min(1.0 / 30.0);
            self.integrate_flight(goal, h, face, profile, terrain, deck);
            left -= h;
        }
        let state = self.flight.unwrap();
        self.flight_pitch = state[0];
        self.flight_roll = state[1];
        Ok(f64::from(flat(self.position - goal).length()) < 0.7
            && (f64::from(self.position.y) - f64::from(goal.y)).abs() < 0.12
            && f64::from(flat(self.velocity).length()) < 0.65
            && f64::from(self.velocity.y).abs() < 0.35)
    }
    pub fn fly_uav(
        &mut self,
        dt: f64,
        altitude: f64,
        radius: f64,
        profile: FlightProfile,
    ) -> Result<(), &'static str> {
        if !dt.is_finite()
            || !(0.0..=3600.0).contains(&dt)
            || !profile.valid()
            || !altitude.is_finite()
            || !(0.0..=1_000_000.0).contains(&altitude)
            || !radius.is_finite()
            || !(0.0..=1_000_000.0).contains(&radius)
        {
            return Err("invalid UAV step");
        }
        let center = self.uav_destination.unwrap_or(flat(self.position));
        let wanted = if f64::from(flat(center - self.position).length()) > radius * 1.6 {
            center
        } else {
            self.orbit += dt * profile.speed / radius.max(4.0);
            center
                + Vector3::new(
                    libm::cos(self.orbit) as f32,
                    0.0,
                    libm::sin(self.orbit) as f32,
                ) * radius as f32
        };
        let to = flat(wanted - self.position);
        self.velocity = move_toward(
            self.velocity,
            normalized(to) * profile.speed.min(f64::from(to.length()) * 1.5) as f32,
            6.0 * dt,
        );
        self.position += self.velocity * dt as f32;
        self.position.y = toward(f64::from(self.position.y), altitude, 4.0 * dt) as f32;
        if f64::from(self.velocity.length()) > 0.3 {
            let heading = libm::atan2(-f64::from(self.velocity.x), -f64::from(self.velocity.z));
            let next = slew(
                self.yaw,
                self.yaw_rate,
                heading,
                profile.turn,
                profile.turn_accel,
                dt,
                true,
            );
            self.yaw = f64::from(next[0]);
            self.yaw_rate = f64::from(next[1]);
        }
        Ok(())
    }
}
