//! A soldier leaves burning cover before the next fire victim is processed.
use crate::infantry::{Goal, Infantry};
use crate::infantry_controller::Task;
use crate::infantry_orders::RouteOrder;
use crate::infantry_vitals::Life;
use crate::path_planner::PathPlanner;
use crate::random::SimulationRandom;
use crate::vector::{normalized, Vector3};

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Escape {
    pub route: RouteOrder,
    pub speech: Option<u8>,
}

impl Infantry {
    pub fn flee_fire(
        &mut self,
        from: Vector3,
        now: f64,
        nav: &PathPlanner,
        rng: &mut SimulationRandom,
        ground: crate::traversal::Ground<'_>,
    ) -> Result<Option<Escape>, &'static str> {
        if !ground.valid_for(nav.side()) {
            return Err("invalid navigation ground");
        }

        if !self.valid()
            || !from.is_finite()
            || from.abs().max_element() > 1_000_000.0
            || !now.is_finite()
            || now.abs() > 1e12 - 100.0
        {
            return Err("invalid fire escape context");
        }
        if self.vitals.life != Life::Alive
            || self.emplacement.structure != 0
            || self.links.vehicle != 0
            || matches!(
                self.duty.kind,
                Task::Smother | Task::Stretcher | Task::Tunnel
            )
            || self.activity == 15
            || now < self.fight.flee_fire_at
        {
            return Ok(None);
        }
        if self.orders.path_revision == i64::MAX as u64 {
            return Err("fire escape path revision exhausted");
        }
        let mut next = self.clone();
        let mut random = *rng;
        let away = self.motion.position - from;
        let away = Vector3::new(away.x, 0.0, away.z);
        let away = if f64::from(away.length()) > 0.1 {
            normalized(away)
        } else {
            let yaw = f64::from(random.randf()) * std::f64::consts::TAU;
            Vector3::new(-libm::sin(yaw) as f32, 0.0, -libm::cos(yaw) as f32)
        };
        let destination = nav
            .nearest_walkable(self.motion.position + away * 7.0, ground)
            .unwrap();
        next.fight.flee_fire_at = now + 2.5;
        next.cover.at_cover = false;
        next.weapon.peek_up = false;
        next.clear_cover();
        next.cover.evaluate_at = now + 2.0;
        let route = next.go_to(destination, Goal::Slot, 2)?;
        let speech = if random.randf() < 0.4 {
            next.vitals.speech_cooldown = 2.6;
            Some((random.randi() % 4) as u8)
        } else {
            None
        };
        *self = next;
        *rng = random;
        Ok(Some(Escape { route, speech }))
    }
}
