//! Armour and damage run before destruction effects; passengers may consume the next random draws.
use crate::random::SimulationRandom;
use crate::vector::{normalized, Vector3};
use crate::vehicle::{LastBlast, Vehicle};

#[derive(Clone, Copy, Debug)]
pub struct Armor {
    pub level: u8,
    pub helicopter: bool,
    pub boat: bool,
    pub supply: bool,
    pub toss: f64,
}
impl Armor {
    fn valid(self) -> bool {
        self.level <= 3 && self.toss.is_finite() && (0.0..=1000.0).contains(&self.toss)
    }
}
#[derive(Clone, Copy, Debug)]
pub struct Blast {
    pub position: Vector3,
    pub size: f64,
    pub anti_tank: f64,
    pub direction: Option<Vector3>,
    pub top: bool,
    pub track: f64,
    pub radius: f64,
    pub damage: f64,
    pub vehicle_multiplier: f64,
}
#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct BlastHit {
    pub damage: f64,
    pub anti_tank: bool,
    pub bounced: bool,
    pub track_broken: bool,
}
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct Damage {
    pub applied: bool,
    pub alert: bool,
    pub destroyed: bool,
}
fn point(p: Vector3) -> bool {
    p.is_finite() && p.abs().max_element() <= 1_000_000.0
}
fn scalar(v: f64) -> bool {
    v.is_finite() && v.abs() <= 1e12
}
fn flat(p: Vector3) -> Vector3 {
    Vector3::new(p.x, 0.0, p.z)
}
fn heading(yaw: f64) -> Vector3 {
    Vector3::new(-libm::sin(yaw) as f32, 0.0, -libm::cos(yaw) as f32)
}
impl Vehicle {
    pub fn bullet_damage(
        &self,
        armor: Armor,
        damage: f64,
        piercing: bool,
        anti_air: bool,
    ) -> Result<f64, &'static str> {
        if !armor.valid() || !scalar(damage) || damage < 0.0 {
            return Err("invalid vehicle bullet");
        }
        if armor.level >= 2 {
            return Ok(if piercing { 3.0 } else { 0.0 });
        }
        let multiplier = if anti_air && armor.helicopter && self.position.y > 3.0 {
            1.6
        } else if armor.level == 0 {
            if piercing {
                1.0
            } else {
                0.35
            }
        } else if piercing {
            0.45
        } else {
            0.05
        };
        let amount = damage * multiplier;
        if !scalar(amount) {
            return Err("vehicle bullet damage overflow");
        }
        Ok(amount)
    }
    // Heavy armour checks ricochet after applying AP damage, including any destruction effects.
    pub fn bullet_ricochet(
        &self,
        armor: Armor,
        position: Vector3,
        direction: Vector3,
        rng: &mut SimulationRandom,
    ) -> Result<Option<Vector3>, &'static str> {
        if !armor.valid() || !point(position) || !point(direction) {
            return Err("invalid ricochet");
        }
        if armor.level < 2 || rng.randf() >= 0.3 {
            return Ok(None);
        }
        let n = normalized(flat(position - self.position));
        Ok(Some(if n.length() > 0.1 {
            -(2.0 * n * n.dot(direction) - direction)
        } else {
            -direction
        }))
    }
    pub fn explosion_hit(
        &mut self,
        now: f64,
        armor: Armor,
        blast: Blast,
        rng: &mut SimulationRandom,
    ) -> Result<BlastHit, &'static str> {
        if !scalar(now)
            || !armor.valid()
            || !point(blast.position)
            || blast.direction.is_some_and(|d| !point(d))
            || [
                blast.size,
                blast.anti_tank,
                blast.track,
                blast.radius,
                blast.damage,
                blast.vehicle_multiplier,
            ]
            .iter()
            .any(|&v| !scalar(v) || v < 0.0)
        {
            return Err("invalid vehicle explosion");
        }
        let distance = f64::from(flat(self.position - blast.position).length());
        let mut random = rng.clone();
        let mut knock = self.knock_velocity;
        if !(armor.helicopter && self.position.y > 3.0) && blast.size >= 1.2 {
            let power = blast.size * (1.0 - distance / (4.0 + blast.size * 3.0)).clamp(0.0, 1.0);
            if power > 0.0 {
                let away = flat(self.position - blast.position);
                let away = if away.length() > 0.1 {
                    normalized(away)
                } else {
                    heading(f64::from(random.randf()) * std::f64::consts::TAU)
                };
                knock += away * power as f32 * armor.toss as f32;
            }
        }
        let mut hit = BlastHit::default();
        if blast.anti_tank > 0.0 && distance < 4.5 {
            hit.anti_tank = true;
            let direction = blast
                .direction
                .unwrap_or_else(|| normalized(flat(self.position - blast.position)));
            let facing = -f64::from(normalized(flat(direction)).dot(heading(self.yaw)));
            let mut multiplier = 1.0;
            if armor.level >= 2 && !blast.top {
                if facing > 0.7 {
                    multiplier = 0.6;
                    if random.randf() < 0.25 {
                        hit.bounced = true;
                    }
                } else if facing < -0.6 {
                    multiplier = 1.35;
                }
            } else if armor.level < 2 {
                multiplier = 1.5;
            }
            if !hit.bounced {
                hit.damage = blast.anti_tank * multiplier;
            }
            if !hit.bounced
                && !armor.supply
                && !armor.helicopter
                && !armor.boat
                && !self.track_broken
                && f64::from(random.randf())
                    < blast.track * if facing.abs() < 0.6 { 1.5 } else { 1.0 }
            {
                hit.track_broken = true;
            }
        } else {
            hit.damage = blast.damage
                * (1.0 - distance / (blast.radius + 2.0)).max(0.0)
                * if armor.level >= 2 { 0.12 } else { 0.8 }
                * blast.vehicle_multiplier;
        }
        if !point(knock) || !scalar(hit.damage) {
            return Err("vehicle explosion overflow");
        }
        self.last_blast = Some(LastBlast {
            position: blast.position,
            size: blast.size,
            time: now,
        });
        self.knock_velocity = knock;
        self.track_broken |= hit.track_broken;
        *rng = random;
        Ok(hit)
    }
    pub fn take_damage(
        &mut self,
        amount: f64,
        now: f64,
        automatic: bool,
    ) -> Result<Damage, &'static str> {
        if !scalar(amount) || amount < 0.0 || !scalar(now) {
            return Err("invalid vehicle damage");
        }
        if self.gone || self.hp <= 0.0 {
            return Ok(Damage::default());
        }
        let alert = now > self.alert_time && !automatic && amount > 50.0;
        if alert && !scalar(now + 20.0) {
            return Err("invalid vehicle alert deadline");
        }
        self.hp -= amount;
        if alert {
            self.alert_time = now + 20.0;
        }
        Ok(Damage {
            applied: true,
            alert,
            destroyed: self.hp <= 0.0,
        })
    }
}
