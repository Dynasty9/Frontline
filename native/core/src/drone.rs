use crate::collision::CollisionWorld;
use crate::vector::Vector3;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
#[repr(u8)]
pub enum Phase {
    Climb,
    Cruise,
    Dive,
    Uncontrolled,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct DroneFlight {
    pub position: Vector3,
    pub velocity: Vector3,
    pub target: Vector3,
    pub phase: Phase,
    pub diving: bool,
    pub dead: bool,
    pub life: f64,
    pub yaw: f32,
}

impl DroneFlight {
    pub fn new(position: Vector3, yaw: f32) -> Self {
        Self {
            position,
            velocity: Vector3::ZERO,
            target: position,
            phase: Phase::Climb,
            diving: false,
            dead: false,
            life: 0.0,
            yaw,
        }
    }

    pub fn lose_control(&mut self) {
        if self.phase != Phase::Uncontrolled {
            self.phase = Phase::Uncontrolled;
            self.diving = false;
        }
    }

    pub fn advance(
        &mut self,
        dt: f64,
        target: Option<Vector3>,
        collision: &mut CollisionWorld,
        map_half: f32,
    ) -> bool {
        if self.dead {
            return false;
        }
        self.life += dt;
        if let Some(target) = target {
            self.target = target;
        }
        let to = self.target - self.position;
        let horizontal = Vector3::new(to.x, 0.0, to.z);
        match self.phase {
            Phase::Climb => {
                let want = Vector3::Y * 6.0 + horizontal.normalize_or_zero() * 6.0;
                self.velocity = self.velocity.lerp(want, (1.0 - (-dt * 3.0).exp()) as f32);
                if self.position.y > 6.5 {
                    self.phase = Phase::Cruise;
                }
            }
            Phase::Cruise => {
                let mut want = horizontal.normalize_or_zero() * 21.0;
                want.y = ((7.5 - f64::from(self.position.y)) * 1.5) as f32;
                self.velocity = self.velocity.lerp(want, (1.0 - (-dt * 2.5).exp()) as f32);
                if horizontal.length() < 24.0 {
                    self.phase = Phase::Dive;
                    self.diving = true;
                }
            }
            Phase::Dive => {
                let want = to.normalize_or_zero() * 26.0;
                self.velocity = self.velocity.lerp(want, (1.0 - (-dt * 5.0).exp()) as f32);
                if to.length() < 1.4 {
                    self.dead = true;
                    return true;
                }
            }
            Phase::Uncontrolled => {
                self.velocity.y = (f64::from(self.velocity.y) - 6.0 * dt) as f32;
                self.velocity = self.velocity.lerp(self.velocity * 0.99, dt as f32);
            }
        }
        let next = self.position + self.velocity * dt as f32;
        if let Some(hit) = collision.ray(self.position, next, &[]) {
            self.position = hit.position;
            self.dead = true;
            return true;
        }
        self.position = next;
        let horizontal_velocity = Vector3::new(self.velocity.x, 0.0, self.velocity.z);
        if self.velocity.length() > 0.5 && horizontal_velocity.length() > 0.3 {
            self.yaw =
                f64::from(-horizontal_velocity.x).atan2(f64::from(-horizontal_velocity.z)) as f32;
        }
        if self.position.y < 0.25
            || self.life > 50.0
            || self.position.x.abs() >= map_half
            || self.position.z.abs() >= map_half
        {
            self.dead = true;
        }
        self.dead
    }

    pub fn checkpoint(&self) -> Vec<u8> {
        let mut bytes = Vec::with_capacity(59);
        bytes.extend_from_slice(b"FLDF\x01\0\0\0");
        bytes.extend_from_slice(&[self.phase as u8, u8::from(self.diving), u8::from(self.dead)]);
        for point in [self.position, self.velocity, self.target] {
            for value in point.to_array() {
                bytes.extend_from_slice(&value.to_le_bytes());
            }
        }
        bytes.extend_from_slice(&self.life.to_le_bytes());
        bytes.extend_from_slice(&self.yaw.to_le_bytes());
        bytes
    }

    pub fn restore(bytes: &[u8]) -> Result<Self, &'static str> {
        if bytes.len() != 59 || &bytes[..8] != b"FLDF\x01\0\0\0" {
            return Err("incompatible drone checkpoint");
        }
        if bytes[8] > 3 || bytes[9] > 1 || bytes[10] > 1 {
            return Err("invalid drone phase or flags");
        }
        let mut points = [Vector3::ZERO; 3];
        for (point, data) in points.iter_mut().zip(bytes[11..47].chunks_exact(12)) {
            let read = |i| f32::from_le_bytes(data[i..i + 4].try_into().unwrap());
            *point = Vector3::new(read(0), read(4), read(8));
            if !point.is_finite() {
                return Err("nonfinite drone vector");
            }
        }
        let life = f64::from_le_bytes(bytes[47..55].try_into().unwrap());
        let yaw = f32::from_le_bytes(bytes[55..].try_into().unwrap());
        if !life.is_finite() || !yaw.is_finite() {
            return Err("nonfinite drone timer or heading");
        }
        Ok(Self {
            position: points[0],
            velocity: points[1],
            target: points[2],
            phase: [
                Phase::Climb,
                Phase::Cruise,
                Phase::Dive,
                Phase::Uncontrolled,
            ][bytes[8] as usize],
            diving: bytes[9] != 0,
            dead: bytes[10] != 0,
            life,
            yaw,
        })
    }
}
