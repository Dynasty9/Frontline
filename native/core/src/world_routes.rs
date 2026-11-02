use crate::traversal::Ground;
// Queue completions update retained actors without engine callbacks or wall-clock budgets.
use crate::actors::{Actor, Actors};
use crate::infantry::Infantry;
use crate::infantry_orders::{PathFinish, RouteOrder};
use crate::navigation_scene::NavigationScene;
use crate::path_planner::PathJob;
use crate::random::SimulationRandom;
use crate::vehicle::Vehicle;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Completion {
    Infantry { id: u32, finish: PathFinish },
    Vehicle { id: u32, accepted: bool },
}
fn clock(now: f64) -> bool {
    now.is_finite() && now.abs() <= 1e12 - 100.0
}
impl NavigationScene {
    pub fn submit_infantry(
        &mut self,
        soldier: &mut Infantry,
        route: RouteOrder,
        now: f64,
        rng: &mut SimulationRandom,
        ground: Ground<'_>,
    ) -> Result<Option<PathFinish>, &'static str> {
        if !clock(now)
            || soldier.identity.id == 0
            || route.job.id != u64::from(soldier.identity.id)
            || route.job.vehicle
            || route.job.tracked
            || !ground.valid_for(self.planner.side())
            || !route.job.destination.is_finite()
            || !route.job.care.is_finite()
        {
            return Err("invalid infantry path request");
        }
        if route.revision != soldier.orders.path_revision || !soldier.orders.pending_path {
            return Ok(Some(PathFinish::Ignored));
        }
        if let Some(path) =
            self.planner
                .direct_path(&self.infantry, soldier.motion.position, route.job, ground)
        {
            self.planner.cancel(route.job.id);
            return soldier
                .accept_path(route.revision, path, now, rng)
                .map(Some);
        }
        if !self.planner.request(route.job) {
            return Err("path queue limit exceeded");
        }
        Ok(None)
    }
    pub fn submit_vehicle(
        &mut self,
        vehicle: &mut Vehicle,
        destination: crate::vector::Vector3,
        care: f64,
        revision: u64,
        ground: Ground<'_>,
    ) -> Result<Option<bool>, &'static str> {
        if !ground.valid_for(self.planner.side())
            || vehicle.id == 0
            || !destination.is_finite()
            || !care.is_finite()
        {
            return Err("invalid vehicle path request");
        }
        if revision != vehicle.path_revision || !vehicle.path_pending {
            return Ok(Some(false));
        }
        let tracked = vehicle.tracked;
        let job = PathJob {
            id: u64::from(vehicle.id),
            destination,
            vehicle: true,
            tracked,
            team: i32::from(vehicle.team),
            care,
        };
        if let Some(path) = self.planner.direct_path(
            if tracked {
                &self.tracked
            } else {
                &self.vehicles
            },
            vehicle.position,
            job,
            ground,
        ) {
            self.planner.cancel(job.id);
            return vehicle.complete_path(revision, path).map(Some);
        }
        if !self.planner.request(job) {
            return Err("path queue limit exceeded");
        }
        Ok(None)
    }
    pub fn process_paths(
        &mut self,
        actors: &mut Actors,
        max_jobs: usize,
        now: f64,
        rng: &mut SimulationRandom,
        ground: Ground<'_>,
    ) -> Result<Vec<Completion>, &'static str> {
        if !ground.valid_for(self.planner.side()) || max_jobs > 131_072 || !clock(now) {
            return Err("invalid path completion budget");
        }
        let mut finished = vec![];
        let mut count = 0;
        self.planner.begin_batch();
        while count < max_jobs {
            let Some(job) = self.planner.next_job() else {
                break;
            };
            let Ok(id) = u32::try_from(job.id) else {
                continue;
            };
            let (position, revision) = match actors.get(id) {
                Some(Actor::Soldier(s)) if !job.vehicle && s.orders.pending_path => {
                    (s.motion.position, s.orders.path_revision)
                }
                Some(Actor::Vehicle(v)) if job.vehicle && v.path_pending => {
                    (v.position, v.path_revision)
                }
                _ => continue,
            };
            let graph = if job.tracked {
                &mut self.tracked
            } else if job.vehicle {
                &mut self.vehicles
            } else {
                &mut self.infantry
            };
            let path = self.planner.find_path(
                graph,
                position,
                job.destination,
                job.vehicle,
                job.team,
                job.care,
                job.tracked,
                ground,
            );
            count += 1;
            if path.is_empty() && graph.has_work() {
                if !self.planner.request(job) {
                    return Err("pending path lost its queue slot");
                }
                continue;
            }
            // Solving and applying are synchronous; replacing an order replaces its queued job.
            let result = match actors.get_mut(id).unwrap() {
                Actor::Soldier(s) => Completion::Infantry {
                    id,
                    finish: s.accept_path(revision, path, now, rng)?,
                },
                Actor::Vehicle(v) => Completion::Vehicle {
                    id,
                    accepted: v.complete_path(revision, path)?,
                },
                _ => unreachable!(),
            };
            finished.push(result);
        }
        Ok(finished)
    }
}
