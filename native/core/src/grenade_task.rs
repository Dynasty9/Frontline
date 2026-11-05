//! Closing on a grenade to smother, kick or pick it up.
use crate::path_planner::PathPlanner;
use crate::random::SimulationRandom;
use crate::vector::{normalized, turn_yaw, Vector3};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Task {
    Smother,
    Kick,
    Pickup,
}

#[derive(Clone, Copy, Debug)]
pub struct Grenade {
    pub position: Vector3,
    pub fuse: f64,
    pub gone: bool,
    pub held: bool,
    pub held_by_self: bool,
}

#[derive(Clone, Copy, Debug)]
pub struct Input {
    pub task: Task,
    pub position: Vector3,
    pub yaw: f64,
    pub time: f64,
    pub started: f64,
    pub dt: f64,
    pub grenade: Option<Grenade>,
    pub mount: Option<(Vector3, f64)>,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
#[repr(u8)]
pub enum Action {
    Cancel,
    DiveAway,
    Smother,
    DiveOnto,
    Kick,
    Pickup,
    Run,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Step {
    pub position: Vector3,
    pub yaw: f64,
    pub action: Action,
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
fn direction(yaw: f64) -> Vector3 {
    Vector3::new(-libm::sin(yaw) as f32, 0.0, -libm::cos(yaw) as f32)
}

pub fn advance(input: Input, nav: &PathPlanner) -> Result<Step, &'static str> {
    if !point(input.position)
        || !scalar(input.yaw)
        || !scalar(input.time)
        || !scalar(input.started)
        || !input.dt.is_finite()
        || !(0.0..=10.0).contains(&input.dt)
        || input
            .grenade
            .is_some_and(|g| !point(g.position) || !scalar(g.fuse) || (g.held_by_self && !g.held))
        || input
            .mount
            .is_some_and(|(p, rate)| !point(p) || !scalar(rate) || rate < 0.0)
    {
        return Err("invalid grenade task step");
    }
    let mut result = Step {
        position: input.position,
        yaw: input.yaw,
        action: Action::Cancel,
    };
    let Some(g) = input.grenade.filter(|g| !g.gone) else {
        return Ok(result);
    };
    match input.task {
        Task::Smother => {
            if g.held && !g.held_by_self {
                return Ok(result);
            }
            let spot = Vector3::new(g.position.x, input.position.y, g.position.z)
                - direction(input.yaw) * 0.75;
            let delta = flat(spot - input.position);
            if f64::from(delta.length()) > 0.06 && input.time - input.started < 1.0 {
                let length = delta.length();
                let limit = (6.5 * input.dt) as f32;
                let motion = if length > limit {
                    normalized(delta) * limit
                } else {
                    delta
                };
                result.position += motion;
                result.action = Action::DiveOnto;
            } else {
                result.action = Action::Smother;
            }
        }
        Task::Kick | Task::Pickup => {
            if input.task == Task::Pickup && g.held && !g.held_by_self {
                return Ok(result);
            }
            if (input.task == Task::Kick && g.held)
                || g.fuse < if input.task == Task::Kick { 0.35 } else { 0.7 }
            {
                result.action = Action::DiveAway;
                return Ok(result);
            }
            let delta = flat(g.position - input.position);
            let distance = f64::from(delta.length());
            if distance < if input.task == Task::Kick { 0.7 } else { 0.9 } {
                result.action = if input.task == Task::Kick {
                    Action::Kick
                } else {
                    Action::Pickup
                };
                return Ok(result);
            }
            let speed = if input.task == Task::Kick { 5.5 } else { 5.0 };
            let next = input.position + normalized(delta) * distance.min(speed * input.dt) as f32;
            if nav.kind_at(next, false) != 3 {
                result.position = next;
            }
            result.yaw = turn_yaw(
                input.yaw,
                delta,
                result.position,
                input.dt,
                14.0,
                input.mount,
            );
            result.action = Action::Run;
        }
    }
    Ok(result)
}

pub fn dive_direction(
    position: Vector3,
    from: Vector3,
    rng: &mut SimulationRandom,
) -> Result<Vector3, &'static str> {
    if !point(position) || !point(from) {
        return Err("invalid dive origin");
    }
    let delta = flat(position - from);
    Ok(if f64::from(delta.length()) > 0.1 {
        normalized(delta)
    } else {
        direction(f64::from(rng.randf()) * std::f64::consts::TAU)
    })
}

pub fn covers_grenade(position: Vector3, yaw: f64, grenade: Vector3) -> Result<bool, &'static str> {
    if !point(position) || !scalar(yaw) || !point(grenade) {
        return Err("invalid grenade cover pose");
    }
    Ok(f64::from(flat(position + direction(yaw) * 0.75 - grenade).length()) <= 0.9)
}
