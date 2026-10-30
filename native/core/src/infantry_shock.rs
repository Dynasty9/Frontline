//! Blast knockback and disorientation, independent of animated bodies.
use crate::infantry_vitals::Life;
use crate::path_planner::PathPlanner;
use crate::random::SimulationRandom;
use crate::state_codec::{Reader, Writer};
use crate::vector::{normalized, turn_yaw, Vector3};

#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct InfantryShock {
    pub flinging: bool,
    pub velocity: Vector3,
    pub dazed_timer: f64,
    pub flinch_timer: f64,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Landing {
    pub position: Vector3,
    pub landed: bool,
    pub dazed: bool,
    pub speak: bool,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Stagger {
    pub position: Vector3,
    pub yaw: f64,
    pub task_timer: f64,
    pub direction: Vector3,
}

fn point(p: Vector3) -> bool {
    p.is_finite() && p.abs().max_element() <= 1_000_000.0
}
fn scalar(v: f64) -> bool {
    v.is_finite() && v.abs() <= 1e12
}
fn step(dt: f64) -> bool {
    dt.is_finite() && (0.0..=10.0).contains(&dt)
}
fn random_direction(rng: &mut SimulationRandom) -> Vector3 {
    let angle = f64::from(rng.randf()) * std::f64::consts::TAU;
    Vector3::new(-libm::sin(angle) as f32, 0.0, -libm::cos(angle) as f32)
}

impl InfantryShock {
    pub fn valid(self) -> bool {
        point(self.velocity) && scalar(self.dazed_timer) && scalar(self.flinch_timer)
    }

    pub fn fling(
        &mut self,
        position: Vector3,
        center: Vector3,
        power: f64,
        life: Life,
        carried: bool,
        rng: &mut SimulationRandom,
    ) -> Result<bool, &'static str> {
        if !self.valid()
            || !point(position)
            || !point(center)
            || !power.is_finite()
            || power.abs() > 100_000.0
        {
            return Err("invalid infantry fling");
        }
        if life == Life::Hidden || power <= 0.8 || carried || self.flinging {
            return Ok(false);
        }
        let delta = position - center;
        let delta = Vector3::new(delta.x, 0.0, delta.z);
        let direction = if f64::from(delta.length()) > 0.05 {
            normalized(delta)
        } else {
            random_direction(rng)
        };
        self.velocity = direction * power as f32 + Vector3::Y * (2.5 + power * 0.45) as f32;
        self.flinging = true;
        Ok(true)
    }

    pub fn fling_step(
        &mut self,
        position: Vector3,
        life: Life,
        dt: f64,
        nav: &PathPlanner,
        rng: &mut SimulationRandom,
    ) -> Result<Landing, &'static str> {
        if !self.valid() || !point(position) || !step(dt) {
            return Err("invalid infantry fling step");
        }
        let mut next = position + self.velocity * dt as f32;
        if nav.kind_at(next, false) == 3 && next.y < 1.5 {
            self.velocity.x = (-f64::from(self.velocity.x) * 0.2) as f32;
            self.velocity.z = (-f64::from(self.velocity.z) * 0.2) as f32;
            next = position + Vector3::new(0.0, (f64::from(self.velocity.y) * dt) as f32, 0.0);
        }
        self.velocity.y = (f64::from(self.velocity.y) - 20.0 * dt) as f32;
        let landed = next.y <= 0.0 && self.velocity.y < 0.0;
        let dazed = landed && life == Life::Alive;
        let mut speak = false;
        if landed {
            next.y = 0.0;
            self.flinging = false;
            if dazed {
                self.dazed_timer = f64::from(rng.randf_range(2.5, 5.0));
                speak = rng.randf() < 0.5;
            }
        }
        Ok(Landing {
            position: next,
            landed,
            dazed,
            speak,
        })
    }

    pub fn flinch(
        &mut self,
        suppression: &mut f64,
        life: Life,
        distance: f64,
        radius: f64,
        busy: bool,
    ) -> Result<bool, &'static str> {
        if !self.valid()
            || !scalar(*suppression)
            || !scalar(distance)
            || distance < 0.0
            || !scalar(radius)
            || radius <= 0.0
        {
            return Err("invalid infantry flinch");
        }
        if life != Life::Alive || self.flinging || self.dazed_timer > 0.0 {
            return Ok(false);
        }
        *suppression = (*suppression + 45.0 * (1.0 - distance / radius)).min(100.0);
        if distance < radius * 0.75 && !busy {
            self.flinch_timer = 0.5;
            return Ok(true);
        }
        Ok(false)
    }

    pub fn stagger(
        &mut self,
        mut state: Stagger,
        dt: f64,
        mount: Option<(Vector3, f64)>,
        nav: &PathPlanner,
        rng: &mut SimulationRandom,
    ) -> Result<Stagger, &'static str> {
        if !self.valid()
            || !point(state.position)
            || !point(state.direction)
            || !scalar(state.yaw)
            || !scalar(state.task_timer)
            || !step(dt)
            || mount.is_some_and(|(p, rate)| !point(p) || !scalar(rate) || rate < 0.0)
        {
            return Err("invalid dazed infantry step");
        }
        self.dazed_timer -= dt;
        state.task_timer -= dt;
        if state.task_timer <= 0.0 {
            state.task_timer = f64::from(rng.randf_range(0.6, 1.3));
            state.direction = random_direction(rng);
        }
        let next = state.position + state.direction * 0.8 * dt as f32;
        if nav.kind_at(next, false) != 3 {
            state.position = next;
        }
        state.yaw = turn_yaw(state.yaw, state.direction, state.position, dt, 2.0, mount);
        Ok(state)
    }

    pub fn checkpoint(self) -> Vec<u8> {
        let mut out = Writer::new(b"FLIS\x01\0\0\0");
        out.byte(u8::from(self.flinging));
        out.point(self.velocity);
        out.f64(self.dazed_timer);
        out.f64(self.flinch_timer);
        out.0
    }

    pub fn restore(bytes: &[u8]) -> Result<Self, &'static str> {
        let mut input = Reader::new(bytes, b"FLIS\x01\0\0\0")?;
        let value = Self {
            flinging: input.boolean()?,
            velocity: input.point()?,
            dazed_timer: input.f64()?,
            flinch_timer: input.f64()?,
        };
        input.finish()?;
        if !value.valid() {
            return Err("invalid infantry shock checkpoint");
        }
        Ok(value)
    }
}
