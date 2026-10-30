//! Combat geometry comes from the soldier's state, never an animated model.
use crate::infantry_vitals::Life;
use crate::vector::Vector3;

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
#[repr(u8)]
pub enum Posture {
    #[default]
    Stand = 0,
    Crouch = 1,
    Prone = 2,
    LeanLeft = 3,
    LeanRight = 4,
}

impl TryFrom<u8> for Posture {
    type Error = &'static str;
    fn try_from(value: u8) -> Result<Self, Self::Error> {
        match value {
            0 => Ok(Self::Stand),
            1 => Ok(Self::Crouch),
            2 => Ok(Self::Prone),
            3 => Ok(Self::LeanLeft),
            4 => Ok(Self::LeanRight),
            _ => Err("invalid infantry posture"),
        }
    }
}

#[derive(Clone, Copy, Debug)]
pub struct InfantryPose {
    pub position: Vector3,
    pub posture: Posture,
    pub life: Life,
    pub at_cover: bool,
    pub cover_kind: u8,
    pub cover_height: f64,
    pub cover_normal: Vector3,
    pub lean_direction: Vector3,
    pub mounted: bool,
    pub gun_mount: bool,
    pub tower_mount: bool,
    pub peek_up: bool,
    pub blind: bool,
    pub moving: bool,
    pub move_mode: i32,
    pub ground: f64,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct ExposedPoints {
    points: [Vector3; 2],
    len: usize,
}

impl ExposedPoints {
    fn one(p: Vector3) -> Self {
        Self {
            points: [p, Vector3::ZERO],
            len: 1,
        }
    }
    fn two(a: Vector3, b: Vector3) -> Self {
        Self {
            points: [a, b],
            len: 2,
        }
    }
    pub fn as_slice(&self) -> &[Vector3] {
        &self.points[..self.len]
    }
}

impl InfantryPose {
    pub fn valid(self) -> bool {
        [self.position, self.cover_normal, self.lean_direction]
            .iter()
            .all(|p| p.is_finite() && p.abs().max_element() <= 1_000_000.0)
            && self.cover_kind <= 3
            && self.cover_height.is_finite()
            && self.cover_height.abs() <= 1_000_000.0
            && self.ground.is_finite()
            && self.ground.abs() <= 1_000_000.0
            && (!self.gun_mount || self.mounted)
            && (!self.tower_mount || self.gun_mount)
    }

    pub fn over_cover(self) -> bool {
        self.at_cover && self.cover_kind == 1 && self.cover_height > 0.0 && !self.mounted
    }

    pub fn eye(self) -> Vector3 {
        if self.posture == Posture::Stand && self.tower_mount {
            return self.position + Vector3::Y * 1.62;
        }
        if self.over_cover() && self.peek_up && !self.blind {
            return self.position
                + self.cover_normal * 0.12
                + Vector3::Y * (self.cover_height + 0.13) as f32;
        }
        let height = match self.posture {
            Posture::Crouch => {
                if self.gun_mount {
                    1.25
                } else {
                    0.95
                }
            }
            Posture::Prone => 0.32,
            Posture::LeanLeft | Posture::LeanRight => {
                return self.position + self.lean_direction * 0.75 + Vector3::Y * 1.45
            }
            _ if self.life == Life::Downed => 0.4,
            _ => 1.5,
        };
        self.position + Vector3::Y * height
    }

    pub fn scan_eye(self) -> Vector3 {
        if self.life == Life::Downed {
            return self.position + Vector3::Y * 0.4;
        }
        if self.over_cover() {
            return self.position
                + self.cover_normal * 0.12
                + Vector3::Y * (self.cover_height + 0.13) as f32;
        }
        if self.at_cover && self.cover_kind == 1 {
            return self.position
                + Vector3::Y
                    * if self.cover_height <= 0.0 && self.posture == Posture::Stand {
                        1.5
                    } else {
                        1.0
                    };
        }
        if self.at_cover && self.cover_kind == 2 {
            return self.position + self.lean_direction * 0.75 + Vector3::Y * 1.45;
        }
        self.eye()
    }

    pub fn exposed_points(self) -> ExposedPoints {
        if self.life == Life::Downed || self.life == Life::Dead {
            return ExposedPoints::one(self.position + Vector3::Y * 0.22);
        }
        if self.over_cover() {
            if self.peek_up && !self.blind {
                let up = self.position + self.cover_normal * 0.1;
                return ExposedPoints::two(
                    up + Vector3::Y * (self.cover_height + 0.1) as f32,
                    up + Vector3::Y * (self.cover_height + 0.26) as f32,
                );
            }
            if self.posture == Posture::Prone {
                return ExposedPoints::one(self.position + Vector3::Y * 0.22);
            }
            if self.cover_height >= 0.62 && self.cover_height < 1.12 {
                return ExposedPoints::two(
                    self.position + Vector3::Y * (self.cover_height - 0.34) as f32,
                    self.position + Vector3::Y * (self.cover_height - 0.16) as f32,
                );
            }
        }
        match self.posture {
            Posture::Crouch if self.gun_mount => ExposedPoints::two(
                self.position + Vector3::Y * 1.15,
                self.position + Vector3::Y * 1.35,
            ),
            Posture::Crouch => ExposedPoints::two(
                self.position + Vector3::Y * 0.8,
                self.position + Vector3::Y * 1.05,
            ),
            Posture::Prone => ExposedPoints::one(self.position + Vector3::Y * 0.25),
            Posture::LeanLeft | Posture::LeanRight => {
                ExposedPoints::one(self.position + self.lean_direction * 0.65 + Vector3::Y * 1.45)
            }
            _ => ExposedPoints::two(
                self.position + Vector3::Y * 1.3,
                self.position + Vector3::Y * 1.6,
            ),
        }
    }

    pub fn center(self) -> Vector3 {
        let height = match self.posture {
            Posture::Prone => 0.25,
            Posture::Crouch => 0.75,
            _ if !matches!(self.life, Life::Alive | Life::Surrender | Life::Captive) => 0.2,
            _ => 1.1,
        };
        self.position + Vector3::Y * height
    }

    pub fn hit_factor(self) -> f64 {
        let mut factor = match self.posture {
            Posture::Crouch => {
                if self.gun_mount {
                    0.5
                } else {
                    0.75
                }
            }
            Posture::Prone => 0.45,
            Posture::LeanLeft | Posture::LeanRight => 0.26,
            Posture::Stand if self.at_cover && self.cover_kind == 1 && !self.moving => 0.45,
            _ => 1.0,
        };
        if self.over_cover() && self.peek_up && !self.blind {
            factor = 0.3;
        }
        if self.life == Life::Downed {
            factor = 0.5;
        } else if self.moving {
            factor *= if self.move_mode >= 2 {
                0.5
            } else if self.move_mode == 1 {
                0.65
            } else {
                0.85
            };
        }
        if self.ground < -0.6 && self.life == Life::Alive {
            factor *= 0.55;
        }
        factor
    }

    pub fn cover_posture(self, up: bool) -> Posture {
        if self.cover_height < 0.62 {
            Posture::Prone
        } else if self.cover_height < 1.12 {
            if up || self.cover_height >= 0.8 {
                Posture::Crouch
            } else {
                Posture::Prone
            }
        } else if up {
            Posture::Stand
        } else {
            Posture::Crouch
        }
    }
}
