//! Blast exposure uses gameplay geometry and applies each victim before the next.
use crate::infantry_pose::Posture;
use crate::infantry_vitals::Life;
use crate::vector::{normalized, Vector3};

const COVER_SHARE: [f64; 4] = [0.8, 0.45, 0.25, 0.2];

#[derive(Clone, Copy, Debug)]
pub struct Blast {
    pub position: Vector3,
    pub damage: f64,
    pub radius: f64,
    pub fling: f64,
    pub in_trench: bool,
}

#[derive(Clone, Copy, Debug)]
pub struct Infantry {
    pub center: Vector3,
    pub life: Life,
    pub posture: Posture,
    pub in_trench: bool,
    pub terrain_multiplier: f64,
}

#[derive(Clone, Copy, Debug, Default)]
pub struct Protection {
    pub blocked: bool,
    pub material: Option<u8>,
}

#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct Injury {
    pub damage: f64,
    pub direction: Vector3,
    pub fling: f64,
    pub distance: f64,
    pub flinch_radius: f64,
    pub sheltered: bool,
    pub blocked: bool,
    pub before_posture: f64,
}

fn point(p: Vector3) -> bool {
    p.is_finite() && p.abs().max_element() <= 1_000_000.0
}
fn scalar(v: f64) -> bool {
    v.is_finite() && (0.0..=1_000_000.0).contains(&v)
}

impl Blast {
    pub fn valid(self) -> bool {
        point(self.position) && scalar(self.damage) && scalar(self.radius) && scalar(self.fling)
    }

    pub fn infantry(
        self,
        victim: Infantry,
        protection: Protection,
    ) -> Result<Injury, &'static str> {
        if !self.valid()
            || !point(victim.center)
            || !scalar(victim.terrain_multiplier)
            || protection.material.is_some_and(|m| m > 3)
        {
            return Err("invalid infantry blast exposure");
        }
        let mut result = Injury::default();
        if victim.life == Life::Hidden {
            return Ok(result);
        }
        let distance = f64::from(self.position.distance(victim.center));
        result.distance = distance;
        if distance < self.radius {
            result.sheltered =
                victim.in_trench && !(self.in_trench && distance < self.radius * 0.6);
            result.blocked = protection.blocked || result.sheltered;
            let cover = protection
                .material
                .map_or(0.25, |m| COVER_SHARE[m as usize]);
            let falloff = libm::pow(1.0 - distance / self.radius, 1.2);
            let damage = self.damage
                * falloff
                * if result.blocked {
                    if result.sheltered {
                        0.25
                    } else {
                        cover
                    }
                } else {
                    1.0
                }
                * if result.sheltered { 0.5 } else { 1.0 }
                * victim.terrain_multiplier;
            result.before_posture = damage;
            let damage = damage
                * if victim.posture == Posture::Prone && victim.life == Life::Alive {
                    0.55
                } else {
                    1.0
                };
            if damage > 3.0 {
                result.damage = damage;
                result.direction = normalized(victim.center - self.position);
            }
            if !result.blocked && distance < self.radius * 0.8 && self.fling > 0.0 {
                result.fling = self.fling * (1.0 - distance / (self.radius * 0.8)) + 2.0;
            }
        }
        if distance < self.radius * 2.4 {
            result.flinch_radius = self.radius * 2.4;
        }
        Ok(result)
    }

    pub fn structure(
        self,
        position: Vector3,
        radius: f64,
        fragile: bool,
        multiplier: f64,
    ) -> Result<Option<f64>, &'static str> {
        if !self.valid() || !point(position) || !scalar(radius) || !scalar(multiplier) {
            return Err("invalid structure blast exposure");
        }
        let delta = position - self.position;
        let distance = f64::from(Vector3::new(delta.x, 0.0, delta.z).length()) - radius * 0.5;
        if distance >= self.radius {
            return Ok(None);
        }
        let falloff = if self.radius == 0.0 {
            1.0
        } else {
            (1.0 - distance / self.radius).clamp(0.2, 1.0)
        };
        Ok(Some(
            self.damage * falloff * if fragile { 6.0 } else { 1.0 } * multiplier,
        ))
    }
}
