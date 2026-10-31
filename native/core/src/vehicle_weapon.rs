//! Vehicle weapons choose a shot before its shared damage effects consume randomness.
use crate::random::SimulationRandom;
use crate::vector::Vector3;
use crate::vehicle::Vehicle;

#[derive(Clone, Copy, Debug)]
pub struct FireProfile<'a> {
    pub base: &'a str,
    pub cannon: bool,
    pub armor: u8,
    pub machine_gun: &'a str,
    pub burst: [i32; 2],
    pub interval: f64,
    pub cannon_cooldown: f64,
    pub sam_cooldown: f64,
    pub sam_range: f64,
    pub atgm_cooldown: f64,
    pub atgm_range: f64,
}
impl FireProfile<'_> {
    fn valid(self) -> bool {
        self.base.len() <= 128
            && self.machine_gun.len() <= 128
            && self.armor <= 3
            && self.burst[0] >= 1
            && self.burst[1] >= self.burst[0]
            && self.burst[1] <= 10000
            && [
                self.interval,
                self.cannon_cooldown,
                self.sam_cooldown,
                self.sam_range,
                self.atgm_cooldown,
                self.atgm_range,
            ]
            .iter()
            .all(|v| v.is_finite() && (0.0..=1e6).contains(v))
    }
}
#[derive(Clone, Copy, Debug)]
pub enum TargetKind {
    Soldier {
        nearby: u32,
        rockets: bool,
        mounted: bool,
    },
    Vehicle {
        air: bool,
        armor: u8,
    },
    Structure {
        fortified: bool,
    },
    Other,
}
#[derive(Clone, Copy, Debug)]
pub struct Target {
    pub position: Vector3,
    pub kind: TargetKind,
}
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Fire {
    None,
    Sam,
    Atgm,
    Cannon,
    MachineGun,
}
fn scalar(v: f64) -> bool {
    v.is_finite() && v.abs() <= 1e12
}
impl Vehicle {
    pub fn choose_weapon(
        &mut self,
        now: f64,
        p: FireProfile,
        target: Option<Target>,
        rng: &mut SimulationRandom,
    ) -> Result<Fire, &'static str> {
        if !scalar(now)
            || !p.valid()
            || target.is_some_and(|t| {
                !t.position.is_finite() || t.position.abs().max_element() > 1_000_000.0
            })
            || !scalar(now + p.sam_cooldown)
            || !scalar(now + p.atgm_cooldown)
        {
            return Err("invalid vehicle firing input");
        }
        let Some(t) = target else {
            return Ok(Fire::None);
        };
        let error = self.aim_error(Some(t.position));
        let delta = t.position - self.position;
        let distance = f64::from(Vector3::new(delta.x, 0.0, delta.z).length());
        let air = matches!(t.kind, TargetKind::Vehicle { air: true, .. });
        if air {
            if self.sam_left > 0 && now > self.sam_until && distance < p.sam_range {
                return Ok(Fire::Sam);
            }
        } else if self.atgm_left > 0
            && now > self.atgm_until
            && error < 0.4
            && distance > 22.0
            && distance < p.atgm_range
            && matches!(
                t.kind,
                TargetKind::Vehicle { .. } | TargetKind::Structure { fortified: true }
            )
        {
            return Ok(Fire::Atgm);
        }
        if p.cannon
            && self.cannon_timer <= 0.0
            && error < 0.05
            && (p.base != "tank" || self.aim_time >= 0.3)
        {
            let worth = match t.kind {
                TargetKind::Vehicle { .. } | TargetKind::Structure { .. } => true,
                TargetKind::Soldier {
                    nearby,
                    rockets,
                    mounted,
                } => nearby >= 2 || rockets || mounted || rng.randf() < 0.25,
                TargetKind::Other => false,
            };
            if worth {
                return Ok(Fire::Cannon);
            }
        }
        let gunship = p.base == "attack_heli";
        let range = if gunship || p.base == "spaa" || air {
            105.0
        } else {
            70.0
        };
        let blocked = matches!(t.kind, TargetKind::Structure { .. }) && !gunship
            || matches!(t.kind, TargetKind::Vehicle { armor: 2.., .. })
                && p.armor >= 2
                && p.machine_gun != "chaingun";
        if !p.machine_gun.is_empty()
            && self.mg_timer <= 0.0
            && error < 0.15
            && distance < range
            && !blocked
        {
            if self.mg_burst <= 0 {
                self.mg_burst = rng.randi_range(p.burst[0], p.burst[1]);
            }
            self.mg_burst -= 1;
            return Ok(Fire::MachineGun);
        }
        Ok(Fire::None)
    }
    // Call after applying the shot, so bullet damage draws precede the burst recovery draw.
    pub fn finish_weapon(
        &mut self,
        shot: Fire,
        now: f64,
        p: FireProfile,
        rng: &mut SimulationRandom,
    ) -> Result<(), &'static str> {
        if !scalar(now)
            || !p.valid()
            || !scalar(now + p.sam_cooldown)
            || !scalar(now + p.atgm_cooldown)
            || (shot == Fire::Sam && self.sam_left <= 0)
            || (shot == Fire::Atgm && self.atgm_left <= 0)
        {
            return Err("invalid vehicle shot completion");
        }
        match shot {
            Fire::None => return Ok(()),
            Fire::Sam => {
                self.sam_left -= 1;
                self.sam_until = now + p.sam_cooldown;
            }
            Fire::Atgm => {
                self.atgm_left -= 1;
                self.atgm_until = now + p.atgm_cooldown;
            }
            Fire::Cannon => self.cannon_timer = p.cannon_cooldown,
            Fire::MachineGun => {
                self.mg_timer = if self.mg_burst > 0 {
                    p.interval
                } else {
                    f64::from(rng.randf_range(0.6, 1.3))
                }
            }
        }
        self.last_fire = now;
        Ok(())
    }
}
