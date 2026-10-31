//! Ground driving retains the crew's steering, braking and recovery state between steps.
use crate::path_planner::PathPlanner;
use crate::random::SimulationRandom;
use crate::terrain::Terrain;
use crate::vector::{normalized, Vector3};
use crate::vehicle::{Route, Vehicle};
use std::f64::consts::{PI, TAU};

#[derive(Clone, Copy, Debug)]
pub struct GroundProfile {
    pub hull: Vector3,
    pub tracked: bool,
    pub weight: u8,
    pub supply: bool,
    pub tank: bool,
    pub cannon: bool,
    pub speed: f64,
    pub turn: f64,
    pub turn_accel: f64,
    pub handling: [f64; 4],
}
#[derive(Clone, Copy, Debug)]
pub struct Traffic {
    pub id: u32,
    pub position: Vector3,
    pub yaw: f64,
    pub speed: f64,
    pub hull: Vector3,
    pub air: bool,
}
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Drive {
    pub route: Route,
    pub unstuck: bool,
    pub shove: bool,
}
fn flat(p: Vector3) -> Vector3 {
    Vector3::new(p.x, 0.0, p.z)
}
fn wrap(v: f64) -> f64 {
    v - TAU * libm::floor((v + PI) / TAU)
}
fn sign(v: f64) -> f64 {
    if v == 0.0 {
        0.0
    } else {
        v.signum()
    }
}
fn yaw(p: Vector3) -> f64 {
    libm::atan2(-f64::from(p.x), -f64::from(p.z))
}
fn direction(yaw: f64) -> Vector3 {
    Vector3::new(-libm::sin(yaw) as f32, 0.0, -libm::cos(yaw) as f32)
}
fn toward(a: f64, b: f64, delta: f64) -> f64 {
    if (a - b).abs() <= delta {
        b
    } else {
        a + sign(b - a) * delta
    }
}
fn point(p: Vector3) -> bool {
    p.is_finite() && p.abs().max_element() <= 1_000_000.0
}

pub fn slew(
    angle: f64,
    velocity: f64,
    wanted: f64,
    rate: f64,
    accel: f64,
    dt: f64,
    shortest_arc: bool,
) -> [f32; 2] {
    let error = if shortest_arc {
        wrap(wanted - angle)
    } else {
        wanted - angle
    };
    let demand =
        sign(error) * rate.min((libm::sqrt(2.0 * accel * error.abs()) - accel * dt).max(0.0));
    let mut velocity = toward(velocity, demand, accel * dt);
    let mut step = velocity * dt;
    if sign(step) == sign(error) && step.abs() >= error.abs() {
        step = error;
        velocity = 0.0;
    }
    [wrap(angle + step) as f32, velocity as f32]
}
impl GroundProfile {
    fn valid(self) -> bool {
        point(self.hull)
            && self.hull.min_element() > 0.0
            && self.weight <= 2
            && [self.speed, self.turn, self.turn_accel]
                .into_iter()
                .all(|v| v.is_finite() && (0.0..=1000.0).contains(&v))
            && self
                .handling
                .into_iter()
                .all(|v| v.is_finite() && (0.0..=1000.0).contains(&v))
    }
    fn wheelbase(self) -> f64 {
        (f64::from(self.hull.z) * 0.58).max(2.2)
    }
    fn steer(self) -> f64 {
        if self.weight == 0 {
            0.62
        } else {
            0.5
        }
    }
}
fn valid(dt: f64, p: GroundProfile, traffic: &[Traffic]) -> bool {
    dt.is_finite()
        && (0.0..=3600.0).contains(&dt)
        && p.valid()
        && traffic.len() <= 100_000
        && traffic.iter().all(|v| {
            v.id != 0
                && point(v.position)
                && point(v.hull)
                && v.hull.min_element() > 0.0
                && v.yaw.is_finite()
                && v.yaw.abs() <= 1e12
                && v.speed.is_finite()
                && v.speed.abs() <= 1e6
        })
}
impl Vehicle {
    fn lookahead(&self, points: &[Vector3], index: usize, look: f64) -> Vector3 {
        let origin = flat(self.position);
        let mut prev = origin;
        for &q in points.iter().skip(index) {
            let q = flat(q);
            let dq = f64::from(q.distance(origin));
            if dq >= look {
                let dp = f64::from(prev.distance(origin));
                let k = ((look - dp) / (dq - dp).max(0.001)).clamp(0.0, 1.0);
                return prev + (q - prev) * k as f32;
            }
            prev = q;
        }
        flat(*points.last().unwrap())
    }
    fn traffic_limit(
        &self,
        forward: Vector3,
        maximum: f64,
        p: GroundProfile,
        traffic: &[Traffic],
    ) -> f64 {
        let mut limit = maximum;
        let look = 6.0 + self.speed.abs() * 1.8;
        let center = self.position + forward * look as f32 * 0.5;
        let side = forward.cross(Vector3::Y);
        for v in traffic {
            if v.id == self.id
                || v.air
                || v.position.y > 1.0
                || f64::from(flat(v.position - center).length()) > look
            {
                continue;
            }
            if f64::from(direction(v.yaw).dot(forward)) < 0.3 || v.speed.abs() < 0.8 {
                continue;
            }
            let rel = flat(v.position - self.position);
            let ahead = f64::from(rel.dot(forward));
            if ahead <= 0.0
                || f64::from(rel.dot(side)).abs()
                    > (f64::from(p.hull.x) + f64::from(v.hull.x)) * 0.5 + 0.8
            {
                continue;
            }
            let gap = ahead - (f64::from(p.hull.z) + f64::from(v.hull.z)) * 0.5;
            limit = limit.min((v.speed.abs() * 0.9).max((gap - 2.5) * 0.9));
        }
        limit
    }
    fn avoid(
        &mut self,
        lookahead: Vector3,
        forward: Vector3,
        p: GroundProfile,
        nav: &PathPlanner,
        traffic: &[Traffic],
    ) -> Vector3 {
        self.avoid_cap = None;
        let side = forward.cross(Vector3::Y);
        let look = 8.0 + self.speed.abs() * 1.5;
        let center = self.position + forward * look as f32 * 0.5;
        let mut best = f64::INFINITY;
        let mut out = lookahead;
        for v in traffic {
            if v.id == self.id
                || v.air
                || v.position.y > 1.0
                || f64::from(flat(v.position - center).length()) > look
            {
                continue;
            }
            let rel = flat(v.position - self.position);
            let ahead = f64::from(rel.dot(forward));
            if ahead <= 0.5 || ahead > look || ahead > best {
                continue;
            }
            let standing = v.speed.abs() < 0.8;
            if !standing && f64::from(direction(v.yaw).dot(forward)) > 0.3 {
                continue;
            }
            let lat = f64::from(rel.dot(side));
            let clear = (f64::from(p.hull.x) + f64::from(v.hull.x)) * 0.5 + 1.0;
            if lat.abs() > clear {
                continue;
            }
            let mut go = 1.0;
            if standing {
                go = if lat.abs() > 0.3 { -sign(lat) } else { 1.0 };
                let past = self.position + forward * ahead as f32 + side * go as f32 * clear as f32;
                if nav.kind_at(past, true) == 3 {
                    go = -go;
                }
                self.avoid_cap = Some(3.0);
            }
            best = ahead;
            out = flat(self.position)
                + forward * ahead.max(4.0) as f32
                + side * (lat + go * clear) as f32;
        }
        out
    }
    fn move_ground(&mut self, velocity: Vector3, dt: f64, supply: bool, nav: &PathPlanner) {
        self.velocity = velocity;
        let next = self.position + velocity * dt as f32;
        if supply || nav.kind_at(next, true) != 3 {
            self.position = next;
            return;
        }
        let x = self.position + Vector3::new((f64::from(velocity.x) * dt) as f32, 0.0, 0.0);
        let z = self.position + Vector3::new(0.0, 0.0, (f64::from(velocity.z) * dt) as f32);
        if velocity.x.abs() > velocity.z.abs() && nav.kind_at(x, true) != 3 {
            self.position = x;
        } else if nav.kind_at(z, true) != 3 {
            self.position = z;
        } else if nav.kind_at(x, true) != 3 {
            self.position = x;
        }
        self.speed *= 0.6;
    }
    fn coast(&mut self, dt: f64, p: GroundProfile, nav: &PathPlanner) {
        self.speed = toward(self.speed, 0.0, p.handling[1] * dt);
        self.yaw_rate = toward(self.yaw_rate, 0.0, 2.0 * dt);
        self.move_ground(direction(self.yaw) * self.speed as f32, dt, p.supply, nav);
    }
    fn face(&mut self, dt: f64, p: GroundProfile) {
        let Some(wanted) = self.face_yaw else {
            return;
        };
        if self.track_broken
            || !p.tracked
            || self.speed.abs() > 0.5
            || wrap(wanted - self.yaw).abs() < 0.12
        {
            return;
        }
        let next = slew(
            self.yaw,
            self.yaw_rate,
            wanted,
            p.turn * 0.6,
            p.turn_accel,
            dt,
            true,
        );
        let step = wrap(f64::from(next[0]) - self.yaw);
        self.yaw_rate = f64::from(next[1]);
        self.yaw = f64::from((self.yaw + step) as f32);
        if !p.tank {
            self.turret_yaw -= step;
        }
    }
    fn follow_ground(
        &mut self,
        points: &[Vector3],
        mut index: usize,
        dt: f64,
        mut maximum: f64,
        reverse: bool,
        lane: f64,
        p: GroundProfile,
        nav: &PathPlanner,
        terrain: &Terrain,
        traffic: &[Traffic],
    ) -> usize {
        if index >= points.len() {
            self.coast(dt, p, nav);
            return index;
        }
        while index < points.len() - 1 {
            let at = flat(points[index]);
            let segment = flat(points[index + 1]) - at;
            if flat(self.position).distance(at) < 2.5
                || (f64::from(segment.length()) > 0.01
                    && (flat(self.position) - at).dot(segment) > 0.0)
            {
                index += 1;
            } else {
                break;
            }
        }
        let end = f64::from(flat(*points.last().unwrap() - self.position).length());
        if index >= points.len() - 1 && end < 1.8 {
            self.coast(dt, p, nav);
            return if self.speed.abs() < 0.4 {
                points.len()
            } else {
                index
            };
        }
        maximum *= terrain.speed(self.position, true, p.tracked);
        let base = (p.wheelbase() * 1.4).max(4.0);
        let look = (base + self.speed.abs() * 0.9).max(base).min(16.0);
        let mut at = self.lookahead(points, index, look);
        if lane != 0.0 {
            let road = self.lookahead(points, index, look + 2.5) - at;
            if f64::from(road.length()) > 0.1 {
                at += normalized(road).cross(Vector3::Y) * lane as f32;
            }
        }
        if !self.reverse {
            at = self.avoid(at, direction(self.yaw), p, nav, traffic);
        }
        let to = at - flat(self.position);
        let error = wrap(yaw(to) - self.yaw);
        if reverse {
            if !self.reverse && error.abs() > 2.1 && end < 30.0 {
                self.reverse = true;
            } else if self.reverse && (error.abs() < 1.2 || end > 40.0) {
                self.reverse = false;
            }
        } else {
            self.reverse = false;
        }
        let e = if self.reverse {
            wrap(error - PI)
        } else {
            error
        };
        let curvature =
            2.0 * (if e.abs() < PI * 0.5 {
                libm::sin(e)
            } else {
                sign(e)
            }) / f64::from(to.length()).max(1.0);
        let mut desired = maximum * if self.reverse { p.handling[3] } else { 1.0 };
        let far = self.lookahead(points, index, 18.0) - flat(self.position);
        let bend = wrap(yaw(far) - self.yaw - if self.reverse { PI } else { 0.0 }).abs();
        let ahead = curvature
            .abs()
            .max(2.0 * libm::sin(bend.min(PI * 0.5)) / 18.0);
        desired = desired.min(libm::sqrt(p.handling[2] / ahead.max(0.0005)));
        desired = desired.min(libm::sqrt(2.0 * p.handling[1] * (end - 1.5).max(0.0)) + 0.3);
        if p.tracked {
            let pivot = e.abs() > 0.9;
            if pivot {
                desired = desired.min(0.8);
            }
            let maximum =
                p.turn * (1.0 - 0.45 * (self.speed.abs() / maximum.max(0.1)).clamp(0.0, 1.0));
            let turn = (if pivot {
                sign(e) * p.turn * 0.75
            } else {
                curvature * self.speed.abs()
            })
            .clamp(-maximum, maximum);
            self.yaw_rate = toward(self.yaw_rate, turn, p.turn_accel * dt);
        } else {
            let cap = libm::tan(p.steer()) / p.wheelbase();
            if e.abs() > 1.0 {
                desired = desired.min(libm::sqrt(p.handling[2] / cap));
            }
            let turn = curvature.clamp(-cap, cap) * self.speed.abs();
            self.yaw_rate = toward(self.yaw_rate, turn, p.turn_accel * dt)
                .clamp(-cap * self.speed.abs(), cap * self.speed.abs());
        }
        if !self.reverse {
            desired = desired
                .min(self.avoid_cap.unwrap_or(f64::INFINITY))
                .min(self.traffic_limit(direction(self.yaw), desired, p, traffic));
        }
        let wanted = if self.reverse { -desired } else { desired };
        let rate = if wanted.abs() > self.speed.abs()
            && sign(wanted) == sign(self.speed + wanted * 0.001)
        {
            p.handling[0]
        } else {
            p.handling[1]
        };
        self.speed = toward(self.speed, wanted, rate * dt);
        self.yaw = f64::from((self.yaw + self.yaw_rate * dt) as f32);
        self.move_ground(direction(self.yaw) * self.speed as f32, dt, p.supply, nav);
        index
    }
    pub fn drive_ground(
        &mut self,
        dt: f64,
        p: GroundProfile,
        target: Option<(Vector3, bool)>,
        nav: &PathPlanner,
        terrain: &Terrain,
        traffic: &[Traffic],
        rng: &mut SimulationRandom,
    ) -> Result<Drive, &'static str> {
        if !valid(dt, p, traffic)
            || nav.side() as f64 * 0.5 != terrain.half()
            || target.is_some_and(|t| !point(t.0))
        {
            return Err("invalid vehicle ground step");
        }
        let mut out = Drive {
            route: Route::None,
            unstuck: false,
            shove: false,
        };
        let halt = if target.is_some_and(|t| t.1) && self.hp > self.max_hp * 0.45 {
            32.0
        } else if p.cannon {
            65.0
        } else {
            50.0
        };
        if self.track_broken
            || self.path_index as usize >= self.path.len()
            || self.brain_hold
            || (self.assault
                && target.is_some_and(|t| f64::from(flat(t.0 - self.position).length()) < halt))
        {
            self.coast(dt, p, nav);
            self.stuck_timer = 0.0;
            self.face(dt, p);
            return Ok(out);
        }
        if self.unstick_timer > 0.0
            && self.unstick_timer <= dt
            && self.path_revision >= i64::MAX as u64
        {
            return Err("vehicle path revision exhausted");
        }
        self.stuck_timer += dt;
        if self.unstick_timer > 0.0 {
            self.unstick_timer -= dt;
            self.speed = toward(self.speed, -2.6, 8.0 * dt);
            self.yaw_rate = toward(
                self.yaw_rate,
                self.unstick_direction * p.turn * 0.5,
                p.turn_accel * dt,
            );
            if !p.tracked {
                let limit = self.speed.abs() * libm::tan(p.steer()) / p.wheelbase();
                self.yaw_rate = self.yaw_rate.clamp(-limit, limit);
            }
            self.yaw = f64::from((self.yaw + self.yaw_rate * dt) as f32);
            self.velocity = direction(self.yaw) * self.speed as f32;
            let back = self.position + self.velocity * dt as f32;
            if nav.kind_at(back, true) != 3 {
                self.position = back;
            }
            if self.unstick_timer <= 0.0 {
                out.route = self.request_path(*self.path.last().unwrap(), 0.0)?;
                self.stuck_timer = 0.0;
                self.stuck_position = self.position;
            }
            return Ok(out);
        }
        if self.stuck_timer > 3.0 {
            if f64::from(flat(self.position - self.stuck_position).length()) < 1.2
                && wrap(self.yaw - self.stuck_yaw).abs() < 0.5
            {
                out.unstuck = true;
                self.unstick_timer = 1.6;
                self.unstick_direction = if rng.randf() < 0.5 { 1.0 } else { -1.0 };
            }
            self.stuck_timer = 0.0;
            self.stuck_position = self.position;
            self.stuck_yaw = self.yaw;
        }
        let points = std::mem::take(&mut self.path);
        self.path_index = self.follow_ground(
            &points,
            self.path_index as usize,
            dt,
            p.speed,
            true,
            0.0,
            p,
            nav,
            terrain,
            traffic,
        ) as u32;
        self.path = points;
        out.shove = true;
        Ok(out)
    }
    pub fn follow_truck_route(
        &mut self,
        dt: f64,
        p: GroundProfile,
        nav: &PathPlanner,
        terrain: &Terrain,
        traffic: &[Traffic],
    ) -> Result<(), &'static str> {
        if !valid(dt, p, traffic) || !p.supply || nav.side() as f64 * 0.5 != terrain.half() {
            return Err("invalid truck route step");
        }
        let points = std::mem::take(&mut self.route);
        self.route_index = self.follow_ground(
            &points,
            self.route_index as usize,
            dt,
            p.speed,
            false,
            1.6,
            p,
            nav,
            terrain,
            traffic,
        ) as u32;
        self.route = points;
        Ok(())
    }
}
