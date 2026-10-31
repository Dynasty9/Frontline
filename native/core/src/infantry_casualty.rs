//! Casualty transitions retain the actor and return shared links for the world to release.
use crate::infantry::Infantry;
use crate::infantry_action::Action;
use crate::infantry_control::{Hidden, HiddenReason};
use crate::infantry_controller::Task;
use crate::infantry_pose::Posture;
use crate::infantry_vitals::{DamageResult, Life};
use crate::path_planner::PathPlanner;
use crate::random::SimulationRandom;
use crate::vector::{normalized, Vector3};

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct Released {
    pub patient: u32,
    pub stretcher: u32,
    pub squad: u32,
    pub drone: u32,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct DeathPose {
    pub impulse: Vector3,
    pub kind: u8,
}

fn point(p: Vector3) -> bool {
    p.is_finite() && p.abs().max_element() <= 1_000_000.0
}

impl Infantry {
    pub fn release_all(&mut self) -> Result<Released, &'static str> {
        if !self.valid() {
            return Err("invalid infantry release");
        }
        Ok(self.release_links())
    }

    fn release_links(&mut self) -> Released {
        let out = Released {
            patient: if self.duty.kind == Task::Rescue {
                self.duty.entity as u32
            } else {
                0
            },
            stretcher: if self.duty.kind == Task::Stretcher {
                self.duty.entity as u32
            } else {
                0
            },
            squad: if self.duty.kind == Task::Breach {
                self.identity.squad
            } else {
                0
            },
            drone: self.fight.controlled_drone as u32,
        };
        if self.emplacement.structure != 0 {
            self.emplacement.structure = 0;
            self.identity.mounted_weapon.clear();
            self.orders.base_y = 0.0;
        }
        self.fight.controlled_drone = 0;
        self.action.queued_throw = None;
        self.duty.kind = Task::Fight;
        self.duty.entity = 0;
        self.duty.partner = 0;
        self.orders.backwards = false;
        self.action.remaining = 0.0;
        self.action.current = Action::None;
        out
    }

    pub fn go_down(&mut self, time: f64) -> Result<Released, &'static str> {
        if !self.valid() {
            return Err("invalid infantry downing");
        }
        let mut next = self.vitals;
        next.go_down(time)?;
        self.stop_moving()?;
        self.vitals = next;
        self.hit_kind.clear();
        self.activity = 0;
        self.posture = Posture::Prone;
        self.weapon.peek_up = false;
        self.weapon.blind = false;
        let released = self.release_links();
        self.links.stretcher_claimed = false;
        self.links.rescue_claimed = 0;
        Ok(released)
    }

    pub fn die(
        &mut self,
        time: f64,
        weapon_ammunition: Option<i32>,
    ) -> Result<Option<Released>, &'static str> {
        if !self.valid()
            || !time.is_finite()
            || time.abs() > 1e12
            || weapon_ammunition.is_some_and(|n| !(0..=1_000_000).contains(&n))
        {
            return Err("invalid retained infantry death");
        }
        if self.vitals.life == Life::Dead {
            return Ok(None);
        }
        let loot = if weapon_ammunition.is_some_and(|ammo| ammo < 9000) {
            30.max(self.weapon.magazine + self.weapon.reserve)
        } else {
            0
        };
        if loot > 1_000_000 {
            return Err("infantry loot exceeds limit");
        }
        let mut next = self.vitals;
        next.die(time)?;
        self.stop_moving()?;
        self.vitals = next;
        self.activity = 0;
        self.fight.loot = loot;
        self.weapon.magazine = 0;
        self.weapon.reserve = 0;
        self.links.dragged_by = 0;
        self.links.rescue_claimed = 0;
        Ok(Some(self.release_links()))
    }

    pub fn revive(
        &mut self,
        full: bool,
        restored_weapon: Option<(&str, i32)>,
        rng: &mut SimulationRandom,
    ) -> Result<u8, &'static str> {
        if !self.valid()
            || restored_weapon.is_some_and(|(key, mag)| {
                key.is_empty() || key.len() > 128 || !(0..=1_000_000).contains(&mag)
            })
        {
            return Err("invalid retained infantry revival");
        }
        let mut next = self.vitals;
        next.revive(full)?;
        self.vitals = next;
        self.activity = 0;
        self.posture = Posture::Crouch;
        self.links.dragged_by = 0;
        self.links.rescue_claimed = 0;
        self.links.carried_by.clear();
        self.links.stretcher_claimed = false;
        self.cover.at_cover = false;
        self.cover.evaluate_at = 0.0;
        self.motion.position.y = self.motion.position.y.max(0.0);
        if self.identity.weapon.is_empty() {
            if let Some((key, magazine)) = restored_weapon {
                self.identity.weapon = key.into();
                self.weapon.magazine = magazine;
                self.weapon.reserve = 0;
            }
        }
        self.vitals.speech_cooldown = 2.6;
        Ok((rng.randi() % 4) as u8)
    }

    pub fn receive_damage(
        &mut self,
        amount: f64,
        direction: Vector3,
        kind: &str,
        bearer: bool,
        rng: &mut SimulationRandom,
    ) -> Result<DamageResult, &'static str> {
        if !self.valid() || !point(direction) || kind.len() > 128 {
            return Err("invalid retained infantry damage");
        }
        let result = self
            .vitals
            .damage(amount, kind == "explosion", bearer, rng)?;
        if result != DamageResult::Ignored {
            self.hit_direction = direction;
            self.hit_kind = kind.into();
        }
        Ok(result)
    }

    pub fn fling_from(
        &mut self,
        center: Vector3,
        power: f64,
        rng: &mut SimulationRandom,
    ) -> Result<Option<Released>, &'static str> {
        if !self.valid() {
            return Err("invalid retained infantry fling");
        }
        let mut shock = self.shock;
        let mut random = *rng;
        if !shock.fling(
            self.motion.position,
            center,
            power,
            self.vitals.life,
            !self.links.carried_by.is_empty(),
            &mut random,
        )? {
            return Ok(None);
        }
        self.stop_moving()?;
        self.shock = shock;
        *rng = random;
        self.activity = 17;
        self.links.dragged_by = 0;
        Ok(Some(if self.vitals.life == Life::Alive {
            self.release_links()
        } else {
            Released::default()
        }))
    }

    pub fn death_pose(&self) -> DeathPose {
        let flat = Vector3::new(self.hit_direction.x, 0.0, self.hit_direction.z);
        let direction = if f64::from(flat.length()) > 0.05 {
            normalized(flat)
        } else {
            let angle = self.motion.yaw + std::f64::consts::PI;
            Vector3::new(-libm::sin(angle) as f32, 0.0, -libm::cos(angle) as f32)
        };
        if self.shock.flinging {
            DeathPose {
                kind: 1,
                impulse: self.shock.velocity,
            }
        } else if self.hit_kind == "explosion" {
            DeathPose {
                kind: 1,
                impulse: direction * 4.0 + Vector3::Y * 2.5,
            }
        } else if matches!(self.hit_kind.as_str(), "bullet" | "melee") {
            DeathPose {
                kind: 0,
                impulse: direction * 2.6 + Vector3::Y * 0.4,
            }
        } else {
            DeathPose {
                kind: 2,
                impulse: Vector3::ZERO,
            }
        }
    }

    pub fn corpse_tick(
        &mut self,
        ground: f64,
        time: f64,
        carrier_alive: bool,
    ) -> Result<bool, &'static str> {
        if !self.valid() {
            return Err("invalid retained corpse");
        }
        let out = self.vitals.corpse_step(
            self.motion.position.y,
            ground,
            time,
            !self.links.carried_by.is_empty(),
            carrier_alive,
            self.links.stretcher_claimed,
        )?;
        self.motion.position.y = out.height;
        self.activity = if out.carried { 13 } else { 0 };
        if out.clear_carriers {
            self.links.carried_by.clear();
        }
        Ok(out.despawn)
    }

    pub fn hide_in(
        &mut self,
        reason: HiddenReason,
        duration: f64,
        shelter: Option<(u32, Vector3)>,
    ) -> Result<(), &'static str> {
        if !self.valid()
            || !duration.is_finite()
            || duration.abs() > 1e12
            || shelter.is_some_and(|(id, p)| id == 0 || !point(p))
        {
            return Err("invalid infantry shelter");
        }
        self.stop_moving()?;
        self.vitals.life = Life::Hidden;
        self.control.hidden = reason;
        self.control.hidden_timer = duration;
        self.links.hidden_in = shelter.map_or(0, |s| u64::from(s.0));
        self.links.carried_by.clear();
        self.links.dragged_by = 0;
        if let Some((_, p)) = shelter {
            self.motion.position = p;
        }
        Ok(())
    }

    pub fn unhide(&mut self, position: Vector3, nav: &PathPlanner) -> Result<(), &'static str> {
        if !self.valid() || !point(position) {
            return Err("invalid infantry exit");
        }
        let position = nav
            .nearest_walkable(position)
            .ok_or("invalid exit position")?;
        self.vitals.life = Life::Alive;
        self.control.hidden = HiddenReason::Waiting;
        self.links.hidden_in = 0;
        self.motion.position = position;
        self.motion.position.y = 0.0;
        self.activity = 0;
        self.cover.at_cover = false;
        self.cover.evaluate_at = 0.0;
        self.orders.hold_position = self.motion.position;
        Ok(())
    }

    pub fn hidden_tick(
        &mut self,
        dt: f64,
        vehicle: Option<Vector3>,
    ) -> Result<Hidden, &'static str> {
        if !self.valid() {
            return Err("invalid retained hidden infantry");
        }
        let out = self.control.hidden_step(dt, vehicle)?;
        if let Hidden::FollowVehicle(p) = out {
            self.motion.position = p;
        }
        Ok(out)
    }
}
