//! Retained action and interruption stages; the world applies returned combat effects.
use crate::infantry::{Goal, Infantry, Orders};
use crate::infantry_action::{Action, ActionState, Context, Gesture, Related};
use crate::infantry_controller::{Stage, Task};
use crate::infantry_pose::Posture;
use crate::infantry_shock::Stagger;
use crate::infantry_vitals::Life;
use crate::path_planner::PathPlanner;
use crate::random::SimulationRandom;
use crate::traversal::Ground;
use crate::vector::Vector3;

#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct ActionEffect {
    pub effect: Action,
    pub cancel_path: bool,
    // 0..2 are the existing throw shouts; 3 is the throwback shout.
    pub speech: Option<u8>,
}

// Actions stage only the fields they change, so validation cannot copy a soldier's route.
pub(crate) struct ActionUpdate {
    pub effect: ActionEffect,
    action: ActionState,
    orders: Orders,
    activity: u8,
    pub posture: Posture,
    pub yaw: f64,
    hit_dirt_timer: f64,
    speech_cooldown: f64,
    clear_path: bool,
}
impl ActionUpdate {
    fn new(s: &Infantry) -> Self {
        Self {
            effect: ActionEffect::default(),
            action: s.action,
            orders: s.orders,
            activity: s.activity,
            posture: s.posture,
            yaw: s.motion.yaw,
            hit_dirt_timer: s.vitals.hit_dirt_timer,
            speech_cooldown: s.vitals.speech_cooldown,
            clear_path: false,
        }
    }
    fn stop(&mut self) -> Result<(), &'static str> {
        if self.orders.path_revision == i64::MAX as u64 {
            return Err("invalid infantry stop order");
        }
        self.orders.path_revision += 1;
        self.orders.pending_path = false;
        self.orders.purpose = Goal::None;
        self.clear_path = true;
        Ok(())
    }
    pub fn begin(
        &mut self,
        action: Action,
        duration: f64,
        context: Context,
    ) -> Result<(), &'static str> {
        let gesture = self.action.begin(action, duration)?;
        let yaw = action.begin_yaw(context)?;
        self.stop()?;
        if let Some(gesture) = gesture {
            self.activity = activity(gesture);
        }
        if let Some(yaw) = yaw {
            self.yaw = yaw;
        }
        Ok(())
    }
    pub fn apply(self, s: &mut Infantry) {
        s.action = self.action;
        s.orders = self.orders;
        s.activity = self.activity;
        s.posture = self.posture;
        s.motion.yaw = self.yaw;
        s.vitals.hit_dirt_timer = self.hit_dirt_timer;
        s.vitals.speech_cooldown = self.speech_cooldown;
        if self.clear_path {
            s.motion.path.clear();
            s.motion.path_index = 0;
        }
    }
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
        let mut update = ActionUpdate::new(self);
        update.begin(action, duration, self.action_context(related))?;
        update.apply(self);
        Ok(())
    }

    pub fn alive_stage(
        &mut self,
        dt: f64,
        rng: &mut SimulationRandom,
    ) -> Result<Stage, &'static str> {
        if !self.valid() {
            return Err("invalid living infantry stage");
        }
        self.advance_alive_stage(dt, rng)
    }

    pub(crate) fn advance_alive_stage(
        &mut self,
        dt: f64,
        rng: &mut SimulationRandom,
    ) -> Result<Stage, &'static str> {
        if self.vitals.life != Life::Alive {
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
        if !self.valid() {
            return Err("invalid retained action update");
        }
        let update = self.plan_action(related, rng)?;
        let effect = update.effect;
        update.apply(self);
        Ok(effect)
    }

    pub(crate) fn plan_action(
        &self,
        related: Option<Related>,
        rng: &mut SimulationRandom,
    ) -> Result<ActionUpdate, &'static str> {
        if !related_valid(related) {
            return Err("invalid retained action update");
        }
        let context = self.action_context(related);
        let pose = self.action.current.pose(context)?;
        let mut update = ActionUpdate::new(self);
        let mut yaw = pose.yaw;
        if update.action.remaining <= 0.0 {
            let done = update.action.finish(context)?;
            update.activity = 0;
            if done.begin_throw {
                update.action.begin(done.effect, 0.6)?;
                yaw = done.effect.begin_yaw(context)?;
                update.stop()?;
                update.effect.cancel_path = true;
                update.effect.speech = Some((rng.randi() % 3) as u8);
                update.activity = 5;
            } else {
                update.effect.effect = done.effect;
                if matches!(done.effect, Action::Rethrow { .. }) {
                    update.effect.speech = Some(3);
                }
            }
            if done.duck_after {
                update.hit_dirt_timer = update.hit_dirt_timer.max(1.6);
            }
        }
        if let Some(posture) = pose.posture {
            update.posture = posture;
        }
        if let Some(yaw) = yaw {
            update.yaw = yaw;
        }
        if update.effect.speech.is_some() {
            update.speech_cooldown = 2.6;
        }
        Ok(update)
    }

    pub fn dive_tick(
        &mut self,
        dt: f64,
        now: f64,
        nav: &PathPlanner,
        ground: Ground<'_>,
    ) -> Result<(), &'static str> {
        if !self.valid() || !now.is_finite() || now.abs() > 1e12 - 1.0 {
            return Err("invalid retained dive");
        }
        let mut controller = self.controller;
        let result = controller.dive(self.motion.position, self.orders.base_y, dt, nav, ground)?;
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
        ground: Ground<'_>,
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
            ground,
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
        ground: Ground<'_>,
    ) -> Result<(bool, Option<u8>), &'static str> {
        if !self.valid() {
            return Err("invalid retained airborne infantry");
        }
        let next =
            self.shock
                .fling_step(self.motion.position, self.vitals.life, dt, nav, rng, ground)?;
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
