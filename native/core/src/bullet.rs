//! Bullet resolution is staged so damage can consume RNG before the next decision.
use crate::collision::{CollisionWorld, RayHit};
use crate::random::SimulationRandom;
use crate::vector::{normalized, Vector3};
use crate::visibility::Visibility;

const PASS: [[f64; 4]; 4] = [
    [0.5, 0.75, 0.9, 1.0],
    [0.0, 0.08, 0.3, 0.75],
    [0.0, 0.0, 0.0, 0.15],
    [0.0; 4],
];
const PASS_DAMAGE: [f64; 4] = [0.7, 0.55, 0.45, 0.0];

#[derive(Clone, Copy, Debug)]
pub struct Weapon {
    pub accuracy: f64,
    pub range: f64,
    pub damage: f64,
    pub anti_air: bool,
    pub penetration: u8,
    pub drone_accuracy: f64,
    pub explosive_radius: Option<f64>,
    pub airburst: bool,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum TargetKind {
    Infantry,
    Drone,
    AirVehicle,
    Other,
}

#[derive(Clone, Copy, Debug)]
pub struct Target {
    pub kind: TargetKind,
    pub hit_factor: f64,
    pub terrain_multiplier: f64,
    pub trench_protected: bool,
}

#[derive(Clone, Copy, Debug)]
pub struct ShotInput<'a> {
    pub muzzle: Vector3,
    pub aim: Vector3,
    pub target: Option<Target>,
    pub weapon: Weapon,
    pub accuracy_multiplier: f64,
    pub soldier_suppression: Option<f64>,
    pub optics: bool,
    pub excluded: &'a [i64],
}

#[derive(Clone, Copy, Debug)]
pub enum Body {
    Structure { material: u8 },
    Vehicle,
    Other,
}

#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct ObstacleEffect {
    pub penetrated: bool,
    pub penetration_damage: f64,
    pub through_end: Option<Vector3>,
    pub structure_damage: f64,
    pub vehicle_hit: bool,
    pub structure_surface: bool,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum TargetEffect {
    None,
    Damage(f64),
    DownDrone,
}

#[derive(Clone, Copy, Debug)]
pub struct TargetLocation {
    pub position: Vector3,
    pub center: Vector3,
    pub in_trench: bool,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Explosion {
    pub position: Vector3,
    pub damage: f64,
    pub radius: f64,
}

#[derive(Clone, Copy, Debug)]
pub struct ThroughContact {
    pub id: u64,
    pub team: i32,
    pub alive: bool,
    pub center: Vector3,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct ThroughHit {
    pub target: u64,
    pub damage: f64,
    pub direction: Vector3,
}

#[derive(Clone, Copy, Debug)]
pub struct Bullet {
    pub hit: bool,
    pub end: Vector3,
    pub direction: Vector3,
    pub impact: u8,
    pub ray: Option<RayHit>,
    muzzle: Vector3,
    distance: f64,
    weapon: Weapon,
    target: Option<TargetKind>,
    damage_multiplier: f64,
    stage: u8,
}

fn point(p: Vector3) -> bool {
    p.is_finite() && p.abs().max_element() <= 1_000_000.0
}
fn nonnegative(v: f64) -> bool {
    v.is_finite() && (0.0..=1_000_000.0).contains(&v)
}

fn line_distance(p: Vector3, a: Vector3, b: Vector3) -> f64 {
    let ab = b - a;
    let squared = f64::from(ab.length_squared());
    if squared < 0.0001 {
        return f64::from(p.distance(a));
    }
    let t = (f64::from((p - a).dot(ab)) / squared).clamp(0.0, 1.0);
    f64::from(p.distance(a + ab * t as f32))
}

/// Candidates retain the spatial query's order, including the first man missed.
pub fn through_hit(
    from: Vector3,
    end: Vector3,
    contacts: &[ThroughContact],
    shooter_team: i32,
    damage: f64,
    multiplier: f64,
    rng: &mut SimulationRandom,
) -> Result<Option<ThroughHit>, &'static str> {
    if !point(from)
        || !point(end)
        || !nonnegative(damage)
        || !nonnegative(multiplier)
        || contacts.len() > 100_000
        || contacts
            .iter()
            .any(|s| s.id == 0 || s.id > i64::MAX as u64 || !point(s.center))
    {
        return Err("invalid penetrating bullet input");
    }
    let direction = normalized(end - from);
    let far = from + direction * 3.0;
    for soldier in contacts {
        if soldier.team == shooter_team
            || !soldier.alive
            || line_distance(soldier.center, from, far) > 0.45
        {
            continue;
        }
        return Ok(if f64::from(rng.randf()) < 0.35 {
            Some(ThroughHit {
                target: soldier.id,
                damage: damage * multiplier * f64::from(rng.randf_range(0.8, 1.2)),
                direction,
            })
        } else {
            None
        });
    }
    Ok(None)
}

pub fn suppression(
    a: Vector3,
    b: Vector3,
    positions: &[Vector3],
    amount: f64,
) -> Result<Vec<f64>, &'static str> {
    if !point(a)
        || !point(b)
        || !nonnegative(amount)
        || positions.len() > 100_000
        || positions.iter().any(|p| !point(*p))
    {
        return Err("invalid bullet suppression input");
    }
    Ok(positions
        .iter()
        .map(|p| {
            let distance = line_distance(*p + Vector3::Y, a, b);
            if distance < 3.0 {
                amount * (1.0 - distance / 3.0)
            } else {
                -1.0
            }
        })
        .collect())
}

impl Bullet {
    pub fn fire(
        input: ShotInput<'_>,
        collision: &mut CollisionWorld,
        visibility: &Visibility,
        rng: &mut SimulationRandom,
    ) -> Result<Self, &'static str> {
        let w = input.weapon;
        if !point(input.muzzle)
            || !point(input.aim)
            || !nonnegative(input.accuracy_multiplier)
            || input.soldier_suppression.is_some_and(|v| !nonnegative(v))
            || !nonnegative(w.accuracy)
            || !nonnegative(w.range)
            || w.range == 0.0
            || !nonnegative(w.damage)
            || w.penetration > 3
            || !nonnegative(w.drone_accuracy)
            || w.explosive_radius.is_some_and(|r| !nonnegative(r))
            || input.excluded.len() > 4096
            || input.excluded.iter().any(|id| *id < 0)
            || input
                .target
                .is_some_and(|t| !nonnegative(t.hit_factor) || !nonnegative(t.terrain_multiplier))
        {
            return Err("invalid bullet input");
        }
        let distance = f64::from(input.muzzle.distance(input.aim));
        let mut hit = false;
        if let Some(target) = input.target {
            let mut p = w.accuracy * input.accuracy_multiplier;
            p *= (1.25 - distance / w.range).clamp(0.1, 1.0);
            p *= target.hit_factor;
            if let Some(suppression) = input.soldier_suppression {
                p *= 1.0 - suppression * 0.0065;
            }
            if input.optics {
                p *= 1.15;
            }
            if target.kind == TargetKind::Infantry {
                p *= target.terrain_multiplier;
                if target.trench_protected {
                    p *= 0.45;
                }
            }
            if target.kind == TargetKind::AirVehicle && !w.anti_air {
                p *= 0.4;
            }
            if target.kind == TargetKind::Drone {
                p = w.drone_accuracy * (1.3 - distance / 40.0).clamp(0.3, 1.0);
            }
            hit = f64::from(rng.randf()) < p;
            if hit && visibility.smoke_blocks(input.muzzle, input.aim) {
                hit = false;
            }
        }
        let direction = normalized(input.aim - input.muzzle);
        let mut end = input.aim;
        if !hit {
            let side = normalized(direction.cross(Vector3::Y));
            let radius = f64::from(rng.randf_range(0.5, 2.0)) * (0.6 + distance / 60.0);
            end = input.aim
                + side * rng.randf_range(-1.0, 1.0) * radius as f32
                + Vector3::Y * rng.randf_range(-0.5, 0.9) * radius as f32 * 0.6;
            end = input.muzzle
                + normalized(end - input.muzzle) * (distance * 1.5 + 6.0).min(w.range * 1.4) as f32;
        }
        let ray = collision.ray(input.muzzle, end, input.excluded);
        Ok(Self {
            hit,
            end,
            direction,
            impact: 0,
            ray,
            muzzle: input.muzzle,
            distance,
            weapon: w,
            target: input.target.map(|t| t.kind),
            damage_multiplier: 1.0,
            stage: 0,
        })
    }

    /// Apply the returned penetration damage, stray hit, then surface effect in order.
    pub fn resolve_obstacle(
        &mut self,
        body: Body,
        rng: &mut SimulationRandom,
    ) -> Result<ObstacleEffect, &'static str> {
        if self.stage != 0 || matches!(body, Body::Structure { material } if material > 3) {
            return Err("invalid bullet obstacle stage");
        }
        self.stage = 1;
        let mut effects = ObstacleEffect::default();
        let Some(ray) = self.ray else {
            return Ok(effects);
        };
        let soft = matches!(self.target, Some(TargetKind::Infantry | TargetKind::Drone));
        let in_way = f64::from(self.muzzle.distance(ray.position)) < self.distance - 0.35;
        let mut through = false;
        if let Body::Structure { material } = body {
            if (soft || self.target.is_none())
                && (in_way || !self.hit)
                && f64::from(rng.randf())
                    < PASS[material as usize][self.weapon.penetration as usize]
            {
                through = true;
                effects.penetrated = true;
                self.damage_multiplier = PASS_DAMAGE[material as usize];
                effects.penetration_damage = self.weapon.damage * 0.05;
                if !self.hit {
                    effects.through_end = Some(self.end);
                }
            }
        }
        if self.hit && soft && in_way && !through {
            self.hit = false;
        }
        if !(through && self.hit) && (!self.hit || !soft) {
            self.end = ray.position;
            self.impact = 1;
            self.hit = false;
            match body {
                Body::Vehicle => effects.vehicle_hit = true,
                Body::Structure { .. } => {
                    effects.structure_damage = self.weapon.damage * 0.05;
                    effects.structure_surface = true;
                }
                Body::Other => {}
            }
        }
        Ok(effects)
    }

    pub fn set_surface(&mut self, impact: u8) -> Result<(), &'static str> {
        if self.stage != 1 {
            return Err("invalid bullet surface stage");
        }
        self.impact = impact;
        Ok(())
    }

    /// Structure and vehicle damage have already consumed their random draws.
    pub fn finish_target(
        &mut self,
        rng: &mut SimulationRandom,
    ) -> Result<TargetEffect, &'static str> {
        if self.stage != 1 {
            return Err("invalid bullet target stage");
        }
        self.stage = 2;
        if self.end.y < 0.0 {
            let t = f64::from(self.muzzle.y)
                / 0.001_f64.max(f64::from(self.muzzle.y) - f64::from(self.end.y));
            self.end = self.muzzle + (self.end - self.muzzle) * t as f32;
            if self.impact == 0 {
                self.impact = 1;
            }
        }
        if self.hit {
            match self.target {
                Some(TargetKind::Infantry) => {
                    let mut damage = self.weapon.damage
                        * f64::from(rng.randf_range(0.8, 1.2))
                        * self.damage_multiplier;
                    if f64::from(rng.randf()) < 0.08 {
                        damage *= 2.5;
                    }
                    self.impact = 2;
                    return Ok(TargetEffect::Damage(damage));
                }
                Some(TargetKind::Drone) => {
                    self.impact = 3;
                    return Ok(TargetEffect::DownDrone);
                }
                _ => {}
            }
        }
        Ok(TargetEffect::None)
    }

    /// Read the target's current center after damage has changed its life and pose.
    pub fn explosion(
        &mut self,
        location: Option<TargetLocation>,
        rng: &mut SimulationRandom,
    ) -> Result<Option<Explosion>, &'static str> {
        if self.stage != 2
            || self.target.is_some() != location.is_some()
            || location.is_some_and(|t| !point(t.position) || !point(t.center))
        {
            return Err("invalid bullet explosion stage");
        }
        self.stage = 3;
        let Some(radius) = self.weapon.explosive_radius else {
            return Ok(None);
        };
        if self.impact == 0 && !self.hit && self.end.y >= 0.2 {
            return Ok(None);
        }
        let mut position = if self.hit && self.target != Some(TargetKind::Drone) {
            location.unwrap().center
        } else {
            self.end
        };
        if let Some(target) = location {
            let delta = self.end - target.position;
            if self.weapon.airburst
                && self.target == Some(TargetKind::Infantry)
                && target.in_trench
                && Vector3::new(delta.x, 0.0, delta.z).length() < 3.0
            {
                position = Vector3::new(target.position.x, 1.4, target.position.z)
                    + Vector3::new(rng.randf_range(-0.8, 0.8), 0.0, rng.randf_range(-0.8, 0.8));
            }
        }
        Ok(Some(Explosion {
            position,
            damage: self.weapon.damage * 1.6,
            radius,
        }))
    }

    pub fn penetration_multiplier(self) -> f64 {
        self.damage_multiplier
    }

    pub fn damage(self) -> f64 {
        self.weapon.damage
    }

    pub fn muzzle(self) -> Vector3 {
        self.muzzle
    }
}
