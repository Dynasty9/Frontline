//! Route orders operate on the retained actor; the world delivers planner completions by revision.
use crate::infantry::{Goal, Infantry};
use crate::infantry_controller::Task;
use crate::infantry_vitals::Life;
use crate::path_planner::PathJob;
use crate::random::SimulationRandom;
use crate::vector::Vector3;

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct RouteOrder {
    pub revision: u64,
    pub job: PathJob,
}

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub enum Arrival {
    #[default]
    None,
    Prison,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum PathFinish {
    Ignored,
    Following,
    Arrived(Arrival),
    Unreachable,
}

fn point(p: Vector3) -> bool {
    p.is_finite() && p.abs().max_element() <= 1_000_000.0
}
fn time(t: f64) -> bool {
    t.is_finite() && t.abs() <= 1e12 - 10.0
}
fn flat(p: Vector3) -> Vector3 {
    Vector3::new(p.x, 0.0, p.z)
}

impl Infantry {
    pub fn is_moving(&self) -> bool {
        self.orders.pending_path || self.motion.path_index < self.motion.path.len()
    }

    pub fn go_to(
        &mut self,
        destination: Vector3,
        purpose: Goal,
        mode: u8,
    ) -> Result<RouteOrder, &'static str> {
        if !self.valid()
            || !point(destination)
            || mode > 2
            || self.orders.path_revision == i64::MAX as u64
        {
            return Err("invalid infantry route order");
        }
        let care = if matches!(self.duty.kind, Task::Retreat | Task::Limp) {
            1.6
        } else if purpose == Goal::Slot {
            if mode == 0 {
                0.8
            } else {
                0.35
            }
        } else {
            0.0
        };
        self.orders.path_revision += 1;
        self.orders.pending_path = true;
        self.motion.path.clear();
        self.motion.path_index = 0;
        self.motion.stuck_position = self.motion.position;
        self.motion.stuck_timer = 0.0;
        self.orders.goal = destination;
        self.orders.purpose = purpose;
        self.orders.move_mode = mode;
        Ok(RouteOrder {
            revision: self.orders.path_revision,
            job: PathJob {
                id: u64::from(self.identity.id),
                destination,
                vehicle: false,
                team: i32::from(self.identity.team),
                care,
            },
        })
    }

    pub fn stop_moving(&mut self) -> Result<(), &'static str> {
        if !self.valid() || self.orders.path_revision == i64::MAX as u64 {
            return Err("invalid infantry stop order");
        }
        self.stop_route();
        Ok(())
    }

    fn stop_route(&mut self) {
        self.orders.path_revision += 1;
        self.orders.pending_path = false;
        self.motion.path.clear();
        self.motion.path_index = 0;
        self.orders.purpose = Goal::None;
    }

    pub fn accept_path(
        &mut self,
        revision: u64,
        path: Vec<Vector3>,
        now: f64,
        rng: &mut SimulationRandom,
    ) -> Result<PathFinish, &'static str> {
        if !self.valid()
            || !time(now)
            || revision > i64::MAX as u64
            || path.len() > 1_000_000
            || !path.iter().copied().all(point)
        {
            return Err("invalid infantry path completion");
        }
        if revision != self.orders.path_revision {
            return Ok(PathFinish::Ignored);
        }
        if matches!(self.vitals.life, Life::Dead | Life::Hidden) {
            self.orders.pending_path = false;
            return Ok(PathFinish::Ignored);
        }
        let arrived = path.is_empty()
            && f64::from(flat(self.motion.position - self.orders.goal).length_squared())
                < 1.7 * 1.7;
        if path.is_empty() && !arrived && self.orders.path_revision == i64::MAX as u64 {
            return Err("infantry path revision exhausted");
        }
        self.orders.pending_path = false;
        self.motion.path = path;
        self.motion.path_index = 0;
        if !self.motion.path.is_empty() {
            return Ok(PathFinish::Following);
        }
        if arrived {
            return Ok(PathFinish::Arrived(self.arrival(now, rng)));
        }
        if self.orders.purpose == Goal::Cover {
            self.clear_cover();
            self.cover.at_cover = false;
            self.cover.evaluate_at = now + 1.0;
        }
        self.stop_route();
        Ok(PathFinish::Unreachable)
    }

    pub fn arrived(
        &mut self,
        now: f64,
        rng: &mut SimulationRandom,
    ) -> Result<Arrival, &'static str> {
        if !self.valid() || !time(now) {
            return Err("invalid infantry arrival");
        }
        Ok(self.arrival(now, rng))
    }

    fn arrival(&mut self, now: f64, rng: &mut SimulationRandom) -> Arrival {
        let purpose = self.orders.purpose;
        self.orders.purpose = Goal::None;
        self.motion.path.clear();
        self.motion.path_index = 0;
        self.motion.slide_timer = 0.0;
        match purpose {
            Goal::Slot => {
                self.cover.at_cover = false;
                self.cover.evaluate_at = 0.0;
            }
            Goal::Cover => {
                self.cover.at_cover = true;
                self.cover.shifting = false;
                self.weapon.peek_timer = f64::from(rng.randf_range(0.3, 1.0));
                if self.cover.normal != Vector3::ZERO
                    && now - self.weapon.last_shot > 0.5
                    && f64::from(self.cover.normal.length_squared()) > 0.0001
                {
                    self.motion.yaw = f64::from(libm::atan2(
                        -f64::from(self.cover.normal.x),
                        -f64::from(self.cover.normal.z),
                    ) as f32);
                }
            }
            Goal::Prison => return Arrival::Prison,
            _ => {}
        }
        Arrival::None
    }

    pub fn clear_cover(&mut self) {
        self.cover.normal = Vector3::ZERO;
        self.cover.height = 0.0;
        self.cover.material = -1;
        self.cover.structure = 0;
        self.cover.anchor = -1;
        self.weapon.blind = false;
        self.cover.shifting = false;
    }
}
