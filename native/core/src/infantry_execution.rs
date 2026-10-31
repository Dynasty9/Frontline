//! Retained action and interruption stages; the world applies returned combat effects.
use crate::infantry::Infantry;
use crate::infantry_action::{Action, Context, Gesture, Related};
use crate::infantry_controller::{Stage, Task};
use crate::infantry_pose::Posture;
use crate::infantry_shock::Stagger;
use crate::infantry_vitals::Life;
use crate::path_planner::PathPlanner;
use crate::random::SimulationRandom;
use crate::vector::Vector3;

#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct ActionEffect {
    pub effect: Action,
    pub cancel_path: bool,
    // 0..2 are the existing throw shouts; 3 is the throwback shout.
    pub speech: Option<u8>,
}

fn related_valid(r: Option<Related>) -> bool {
    r.is_none_or(|r| {
        r.id > 0
            && r.id <= u32::MAX as u64
            && r.holder <= u32::MAX as u64
            && r.position.is_finite()
            && r.position.abs().max_element() <= 1_000_000.0
    })
}

pub(crate) fn action_id(action: Action) -> u64 {
    match action {
        Action::Rethrow { grenade, .. }
        | Action::Kick { grenade, .. }
        | Action::Pickup { grenade } => grenade,
        Action::DoorKick { door, .. } => door,
        Action::Melee { target } | Action::Launch { target } | Action::LaunchDrone { target } => {
            target
        }
        _ => 0,
    }
}

fn activity(gesture: Gesture) -> u8 {
    match gesture {
        Gesture::Throw => 5,
        Gesture::Kick => 33,
        Gesture::Cook => 35,
        Gesture::Melee => 6,
        Gesture::Pickup => 21,
        Gesture::Launch => 24,
    }
}

impl Infantry {
    fn action_context(&self, related: Option<Related>) -> Context {
        Context {
            actor: u64::from(self.identity.id),
            position: self.motion.position,
            related,
        }
    }

    pub fn begin_action(
        &mut self,
        action: Action,
        duration: f64,
        related: Option<Related>,
    ) -> Result<(), &'static str> {
        if !self.valid() || !related_valid(related) || action_id(action) > u32::MAX as u64 {
            return Err("invalid retained infantry action");
        }
        let mut next = self.action;
        let gesture = next.begin(action, duration)?;
        let yaw = action.begin_yaw(self.action_context(related))?;
        self.stop_moving()?;
        self.action = next;
        if let Some(gesture) = gesture {
            self.activity = activity(gesture);
        }
        if let Some(yaw) = yaw {
            self.motion.yaw = yaw;
        }
        Ok(())
    }

    pub fn alive_stage(
        &mut self,
        dt: f64,
        rng: &mut SimulationRandom,
    ) -> Result<Stage, &'static str> {
        if !self.valid() || self.vitals.life != Life::Alive {
            return Err("invalid living infantry stage");
        }
        let mut controller = self.controller;
        let mut shock = self.shock;
        let mut action = self.action;
        let mut random = *rng;
        let advance = controller.advance(dt, &mut shock, &mut action, &mut random)?;
        self.fatigue(dt)?;
        self.controller = controller;
        self.shock = shock;
        self.action = action;
        *rng = random;
        if advance.flinch_ended {
            self.activity = 0;
        }
        if advance.stage == Stage::Flinch {
            self.activity = 19;
        }
        Ok(advance.stage)
    }

    pub fn action_tick(
        &mut self,
        related: Option<Related>,
        rng: &mut SimulationRandom,
    ) -> Result<ActionEffect, &'static str> {
        if !self.valid() || !related_valid(related) {
            return Err("invalid retained action update");
        }
        let context = self.action_context(related);
        let pose = self.action.current.pose(context)?;
        let mut next = self.action;
        let mut out = ActionEffect::default();
        let completion = if next.remaining <= 0.0 {
            Some(next.finish(context)?)
        } else {
            None
        };
        let mut next_activity = self.activity;
        let mut next_yaw = pose.yaw;
        if let Some(done) = completion {
            next_activity = 0;
            if done.begin_throw {
                next.begin(done.effect, 0.6)?;
                next_yaw = done.effect.begin_yaw(context)?;
                self.stop_moving()?;
                out.cancel_path = true;
                out.speech = Some((rng.randi() % 3) as u8);
                next_activity = 5;
            } else {
                out.effect = done.effect;
                if matches!(done.effect, Action::Rethrow { .. }) {
                    out.speech = Some(3);
                }
            }
            if done.duck_after {
                self.vitals.hit_dirt_timer = self.vitals.hit_dirt_timer.max(1.6);
            }
        }
        self.action = next;
        self.activity = next_activity;
        if let Some(posture) = pose.posture {
            self.posture = posture;
        }
        if let Some(yaw) = next_yaw {
            self.motion.yaw = yaw;
        }
        if out.speech.is_some() {
            self.vitals.speech_cooldown = 2.6;
        }
        Ok(out)
    }

    pub fn dive_tick(&mut self, dt: f64, now: f64, nav: &PathPlanner) -> Result<(), &'static str> {
        if !self.valid() || !now.is_finite() || now.abs() > 1e12 - 1.0 {
            return Err("invalid retained dive");
        }
        let mut controller = self.controller;
        let result = controller.dive(self.motion.position, self.orders.base_y, dt, nav)?;
        self.controller = controller;
        self.motion.position = result.position;
        self.activity = 15;
        if result.finished {
            self.posture = Posture::Prone;
            self.activity = 0;
            self.cover.at_cover = false;
            self.cover.evaluate_at = now + 0.8;
        }
        Ok(())
    }

    pub fn dazed_tick(
        &mut self,
        dt: f64,
        mount: Option<(Vector3, f64)>,
        nav: &PathPlanner,
        rng: &mut SimulationRandom,
    ) -> Result<(), &'static str> {
        if !self.valid() {
            return Err("invalid retained dazed infantry");
        }
        let next = self.shock.stagger(
            Stagger {
                position: self.motion.position,
                yaw: self.motion.yaw,
                task_timer: self.duty.timer,
                direction: self.controller.dive_direction,
            },
            dt,
            mount,
            nav,
            rng,
        )?;
        self.motion.position = next.position;
        self.motion.yaw = next.yaw;
        self.duty.timer = next.task_timer;
        self.controller.dive_direction = next.direction;
        self.activity = 18;
        self.posture = Posture::Stand;
        if self.shock.dazed_timer <= 0.0 {
            self.activity = 0;
            self.cover.at_cover = false;
            self.cover.evaluate_at = 0.0;
        }
        Ok(())
    }

    pub fn fling_tick(
        &mut self,
        dt: f64,
        nav: &PathPlanner,
        rng: &mut SimulationRandom,
    ) -> Result<(bool, Option<u8>), &'static str> {
        if !self.valid() {
            return Err("invalid retained airborne infantry");
        }
        let next = self
            .shock
            .fling_step(self.motion.position, self.vitals.life, dt, nav, rng)?;
        self.motion.position = next.position;
        self.activity = if next.landed { 0 } else { 17 };
        if next.dazed {
            self.posture = Posture::Stand;
            self.duty.timer = 0.0;
        }
        let speech = next.speak.then(|| (rng.randi() % 3) as u8);
        if speech.is_some() {
            self.vitals.speech_cooldown = 2.6;
        }
        Ok((next.dazed, speech))
    }

    pub fn flinch_from(&mut self, distance: f64, radius: f64) -> Result<(), &'static str> {
        if !self.valid() {
            return Err("invalid retained infantry flinch");
        }
        let busy = self.action.remaining > 0.0
            || self.controller.dive_timer > 0.0
            || self.duty.kind == Task::Stretcher
            || (self.duty.kind == Task::Rescue && self.duty.phase >= 1);
        if self.shock.flinch(
            &mut self.vitals.suppression,
            self.vitals.life,
            distance,
            radius,
            busy,
        )? {
            self.activity = 19;
        }
        Ok(())
    }
}
