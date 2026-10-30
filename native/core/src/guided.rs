use crate::collision::CollisionWorld;
use crate::vector::{normalized, slerp, Vector3};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
#[repr(u8)]
pub enum Kind {
    AntiTank,
    SurfaceToAir,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct GuidedFlight {
    pub kind: Kind,
    pub position: Vector3,
    pub velocity: Vector3,
    pub target: Vector3,
    pub life: f64,
    pub locked: bool,
    pub dead: bool,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Impact {
    pub position: Vector3,
    pub proximity: bool,
}

impl GuidedFlight {
    pub fn checks_smoke(&self, dt: f64) -> bool {
        self.kind == Kind::AntiTank && self.locked && (self.life + dt) % 0.25 < dt
    }

    pub fn advance(
        &mut self,
        dt: f64,
        target: Option<Vector3>,
        smoke: bool,
        collision: &mut CollisionWorld,
        excluded: &[i64],
    ) -> Option<Impact> {
        if self.dead {
            return None;
        }
        if target.is_some() && smoke && self.checks_smoke(dt) {
            self.locked = false;
        }
        self.life += dt;
        if self.locked {
            if let Some(target) = target {
                self.target = target;
            }
        }
        let anti_tank = self.kind == Kind::AntiTank;
        let mut aim = self.target;
        if anti_tank {
            let delta = self.target - self.position;
            let distance = Vector3::new(delta.x, 0.0, delta.z).length();
            if distance > 16.0 {
                aim.y += (f64::from(distance) * 0.18).min(9.0) as f32;
            }
        }
        let want = normalized(aim - self.position);
        let mut direction = normalized(self.velocity);
        let angle = direction.cross(want).length().atan2(direction.dot(want));
        if angle > 0.001 {
            let turn = if anti_tank { 2.2 } else { 4.2 };
            direction = slerp(
                direction,
                want,
                (turn * dt / f64::from(angle)).clamp(0.0, 1.0) as f32,
            );
        }
        let (acceleration, maximum) = if anti_tank {
            (20.0, 48.0)
        } else {
            (50.0, 95.0)
        };
        let speed = (f64::from(self.velocity.length()) + acceleration * dt).min(maximum);
        self.velocity = direction * speed as f32;
        let next = self.position + self.velocity * dt as f32;
        let impact = if anti_tank {
            if let Some(hit) = collision.ray(self.position, next, excluded) {
                Some(hit.position)
            } else if next.y <= 0.05 {
                Some(Vector3::new(next.x, 0.1, next.z))
            } else if self.life > 7.0 || self.position.distance(self.target) < 0.8 {
                Some(next)
            } else {
                None
            }
        } else {
            None
        };
        if let Some(position) = impact {
            self.dead = true;
            return Some(Impact {
                position,
                proximity: false,
            });
        }
        if !anti_tank {
            let proximity = target.is_some() && self.locked && next.distance(self.target) < 3.2;
            if proximity || self.life > 6.0 || next.y < 0.1 {
                self.dead = true;
                return Some(Impact {
                    position: if proximity { self.target } else { next },
                    proximity,
                });
            }
        }
        self.position = next;
        None
    }

    pub fn checkpoint(&self) -> Vec<u8> {
        let mut bytes = Vec::with_capacity(55);
        bytes.extend_from_slice(b"FLGF\x01\0\0\0");
        bytes.extend_from_slice(&[self.kind as u8, u8::from(self.locked), u8::from(self.dead)]);
        for point in [self.position, self.velocity, self.target] {
            for value in point.to_array() {
                bytes.extend_from_slice(&value.to_le_bytes());
            }
        }
        bytes.extend_from_slice(&self.life.to_le_bytes());
        bytes
    }

    pub fn restore(bytes: &[u8]) -> Result<Self, &'static str> {
        if bytes.len() != 55 || &bytes[..8] != b"FLGF\x01\0\0\0" {
            return Err("incompatible guided flight checkpoint");
        }
        if bytes[8..11].iter().any(|v| *v > 1) {
            return Err("invalid guided flight kind or flags");
        }
        let mut points = [Vector3::ZERO; 3];
        for (point, data) in points.iter_mut().zip(bytes[11..47].chunks_exact(12)) {
            let read = |i| f32::from_le_bytes(data[i..i + 4].try_into().unwrap());
            *point = Vector3::new(read(0), read(4), read(8));
            if !point.is_finite() {
                return Err("nonfinite guided flight vector");
            }
        }
        let life = f64::from_le_bytes(bytes[47..].try_into().unwrap());
        if !life.is_finite() {
            return Err("nonfinite guided flight timer");
        }
        Ok(Self {
            kind: if bytes[8] == 0 {
                Kind::AntiTank
            } else {
                Kind::SurfaceToAir
            },
            position: points[0],
            velocity: points[1],
            target: points[2],
            life,
            locked: bytes[9] != 0,
            dead: bytes[10] != 0,
        })
    }
}
