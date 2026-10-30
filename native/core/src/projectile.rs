use crate::vector::Vector3;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
#[repr(u8)]
pub enum Kind {
    Frag = 0,
    Smoke = 1,
    Rocket = 2,
    Recoilless = 3,
    Mortar = 4,
    MortarSmoke = 5,
    Grad = 6,
    Arty = 7,
    Ac105 = 8,
    Ac40 = 9,
    Ac25 = 10,
    Bomb = 11,
}

impl Kind {
    pub fn parse(name: &str) -> Option<Self> {
        Some(match name {
            "frag" => Self::Frag,
            "smoke" => Self::Smoke,
            "rocket" => Self::Rocket,
            "recoilless" => Self::Recoilless,
            "mortar" => Self::Mortar,
            "mortar_smoke" => Self::MortarSmoke,
            "grad" => Self::Grad,
            "arty" => Self::Arty,
            "ac105" => Self::Ac105,
            "ac40" => Self::Ac40,
            "ac25" => Self::Ac25,
            "bomb" => Self::Bomb,
            _ => return None,
        })
    }
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Flight {
    pub kind: Kind,
    pub position: Vector3,
    pub velocity: Vector3,
    pub origin: Vector3,
    pub target: Vector3,
    pub fuse: f64,
    pub flying: bool,
    pub life: f64,
    pub smoke_time: f64,
    pub smoke_radius: f64,
    pub shell_duration: f64,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Hit {
    pub position: Vector3,
    pub normal: Vector3,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum Holder {
    Free,
    Alive(Vector3),
    Dropped,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum Outcome {
    Flying,
    Impact(Vector3),
    Expired,
}

impl Flight {
    /// Exact little-endian state; changing the layout requires a new version.
    pub fn checkpoint(&self) -> Vec<u8> {
        let mut bytes = Vec::with_capacity(98);
        bytes.extend_from_slice(b"FLPF");
        bytes.extend_from_slice(&1u32.to_le_bytes());
        bytes.extend_from_slice(&[self.kind as u8, u8::from(self.flying)]);
        for point in [self.position, self.velocity, self.origin, self.target] {
            for value in point.to_array() {
                bytes.extend_from_slice(&value.to_le_bytes());
            }
        }
        for value in [
            self.fuse,
            self.life,
            self.smoke_time,
            self.smoke_radius,
            self.shell_duration,
        ] {
            bytes.extend_from_slice(&value.to_le_bytes());
        }
        bytes
    }

    pub fn restore(bytes: &[u8]) -> Result<Self, &'static str> {
        if bytes.len() != 98 || &bytes[..8] != b"FLPF\x01\0\0\0" {
            return Err("incompatible projectile checkpoint");
        }
        let kinds = [
            Kind::Frag,
            Kind::Smoke,
            Kind::Rocket,
            Kind::Recoilless,
            Kind::Mortar,
            Kind::MortarSmoke,
            Kind::Grad,
            Kind::Arty,
            Kind::Ac105,
            Kind::Ac40,
            Kind::Ac25,
            Kind::Bomb,
        ];
        let kind = *kinds
            .get(bytes[8] as usize)
            .ok_or("unknown projectile kind")?;
        if bytes[9] > 1 {
            return Err("invalid flying flag");
        }
        let mut vectors = [Vector3::ZERO; 4];
        for (point, data) in vectors.iter_mut().zip(bytes[10..58].chunks_exact(12)) {
            let read = |i| f32::from_le_bytes(data[i..i + 4].try_into().unwrap());
            *point = Vector3::new(read(0), read(4), read(8));
            if !point.is_finite() {
                return Err("nonfinite projectile position or velocity");
            }
        }
        let mut scalars = [0.0; 5];
        for (value, data) in scalars.iter_mut().zip(bytes[58..].chunks_exact(8)) {
            *value = f64::from_le_bytes(data.try_into().unwrap());
            if !value.is_finite() {
                return Err("nonfinite projectile timer");
            }
        }
        Ok(Self {
            kind,
            position: vectors[0],
            velocity: vectors[1],
            origin: vectors[2],
            target: vectors[3],
            fuse: scalars[0],
            flying: bytes[9] != 0,
            life: scalars[1],
            smoke_time: scalars[2],
            smoke_radius: scalars[3],
            shell_duration: scalars[4],
        })
    }

    pub fn advance_in_world(
        &mut self,
        dt: f64,
        holder: Holder,
        world: &mut crate::collision::CollisionWorld,
        excluded: &[i64],
    ) -> Outcome {
        let sweeps = match self.kind {
            Kind::Frag | Kind::Smoke => holder == Holder::Free && self.flying,
            Kind::Rocket | Kind::Recoilless => true,
            _ => false,
        };
        let hit = if sweeps {
            world
                .ray(self.position, self.sweep_end(dt), excluded)
                .map(|hit| Hit {
                    position: hit.position,
                    normal: hit.normal,
                })
        } else {
            None
        };
        self.advance(dt, holder, hit)
    }

    pub fn sweep_end(&self, dt: f64) -> Vector3 {
        let mut velocity = self.velocity;
        if matches!(self.kind, Kind::Rocket | Kind::Recoilless) {
            velocity.y = (f64::from(velocity.y) - 1.5 * dt) as f32;
        }
        self.position + velocity * dt as f32
    }

    pub fn shell_position(&self, progress: f64) -> Vector3 {
        let mut position = self.origin + (self.target - self.origin) * progress as f32;
        if !matches!(self.kind, Kind::Ac105 | Kind::Ac40 | Kind::Ac25) {
            let delta = self.target - self.origin;
            let distance = Vector3::new(delta.x, 0.0, delta.z).length();
            let apex =
                10.0 + f64::from(distance) * if self.kind == Kind::Arty { 0.32 } else { 0.25 };
            position += Vector3::new(0.0, (apex * 4.0 * progress * (1.0 - progress)) as f32, 0.0);
        }
        position
    }

    pub fn advance(&mut self, dt: f64, holder: Holder, hit: Option<Hit>) -> Outcome {
        self.life += dt;
        match self.kind {
            Kind::Frag | Kind::Smoke => self.grenade(dt, holder, hit),
            Kind::Rocket | Kind::Recoilless => {
                self.velocity.y = (f64::from(self.velocity.y) - 1.5 * dt) as f32;
                let next = self.position + self.velocity * dt as f32;
                if let Some(hit) = hit {
                    return Outcome::Impact(hit.position);
                }
                if next.y <= 0.05 {
                    return Outcome::Impact(Vector3::new(next.x, 0.1, next.z));
                }
                if self.life > 2.5 {
                    return Outcome::Impact(next);
                }
                self.position = next;
                Outcome::Flying
            }
            Kind::Bomb => {
                self.velocity.y = (f64::from(self.velocity.y) - 9.8 * dt) as f32;
                let drag = (-1.25 * dt).exp();
                self.velocity.x = (f64::from(self.velocity.x) * drag) as f32;
                self.velocity.z = (f64::from(self.velocity.z) * drag) as f32;
                let next = self.position + self.velocity * dt as f32;
                if next.y <= 0.3 {
                    return Outcome::Impact(Vector3::new(next.x, 0.3, next.z));
                }
                self.position = next;
                Outcome::Flying
            }
            _ => {
                let progress = self.life / self.shell_duration.max(0.1);
                if progress >= 1.0 {
                    return Outcome::Impact(self.target);
                }
                self.position = self.shell_position(progress);
                Outcome::Flying
            }
        }
    }

    fn grenade(&mut self, dt: f64, holder: Holder, hit: Option<Hit>) -> Outcome {
        match holder {
            Holder::Alive(position) => self.position = position,
            Holder::Dropped => {
                self.flying = true;
                self.velocity = Vector3::ZERO;
            }
            Holder::Free if self.flying => {
                let mut next = self.position + self.velocity * dt as f32;
                self.velocity.y = (f64::from(self.velocity.y) - 18.0 * dt) as f32;
                if let Some(hit) = hit {
                    self.velocity =
                        (self.velocity - 2.0 * hit.normal * self.velocity.dot(hit.normal)) * 0.35;
                    next = hit.position + hit.normal * 0.06;
                }
                if next.y <= 0.06 {
                    next.y = 0.06;
                    if self.velocity.y < 0.0 {
                        self.velocity.y *= -0.25;
                        self.velocity.x *= 0.5;
                        self.velocity.z *= 0.5;
                    }
                    if self.velocity.y.abs() < 1.2
                        && Vector3::new(self.velocity.x, 0.0, self.velocity.z).length() < 0.7
                    {
                        self.flying = false;
                        self.velocity = Vector3::ZERO;
                    }
                }
                self.position = next;
            }
            Holder::Free => {}
        }
        if self.kind == Kind::Frag {
            self.fuse -= dt;
            if self.fuse <= 0.0 {
                return Outcome::Impact(self.position);
            }
        } else if !self.flying || self.life > 1.6 {
            self.smoke_time += dt;
            self.smoke_radius = if self.smoke_time < 22.0 {
                (self.smoke_time * 2.6).min(6.5)
            } else {
                (self.smoke_radius - dt * 1.5).max(0.0)
            };
            if self.smoke_time > 27.0 {
                return Outcome::Expired;
            }
        }
        Outcome::Flying
    }
}
