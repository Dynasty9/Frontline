//! The coxswain steers through water, including current, sea room and backing off a bank.
use crate::boat_navigation::{BoatNavigation, LEVEL};
use crate::cover::{rotation, transform};
use crate::vector::{normalized, Vector3};
use crate::vehicle::Vehicle;
use crate::vehicle_motion::{valid_traffic, Traffic};
use crate::water::Water;
use std::f64::consts::{PI, TAU};

#[derive(Clone, Copy, Debug)]
pub struct BoatProfile {
    pub hull: Vector3,
    pub speed: f64,
    pub response: [f64; 9],
    pub cannon: bool,
}
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct BoatEvents {
    pub unstuck: bool,
    pub aground: bool,
    pub rejoined: bool,
    pub seaward: bool,
}
fn flat(p: Vector3) -> Vector3 {
    Vector3::new(p.x, 0.0, p.z)
}
fn point(p: Vector3) -> bool {
    p.is_finite() && p.abs().max_element() <= 1_000_000.0
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
fn same(a: Vector3, b: Vector3) -> bool {
    a.to_array()
        .into_iter()
        .zip(b.to_array())
        .all(|(a, b)| a == b || (a - b).abs() < (0.00001 * a.abs()).max(0.00001))
}
impl BoatProfile {
    fn valid(self) -> bool {
        point(self.hull)
            && self.hull.min_element() > 0.0
            && self.hull.max_element() <= 1000.0
            && self.speed.is_finite()
            && (0.001..=1000.0).contains(&self.speed)
            && self
                .response
                .into_iter()
                .all(|v| v.is_finite() && (0.001..=1000.0).contains(&v))
    }
    fn radius(self) -> f64 {
        f64::from(self.hull.z) * self.response[6]
    }
    fn drag(self, u: f64) -> f64 {
        let x = u / self.speed;
        self.response[0] * (0.8 * x * x.abs() + 0.2 * x) * if u < 0.0 { 2.5 } else { 1.0 }
    }
}
impl Vehicle {
    fn rudder_flow(&self, u: f64, p: BoatProfile) -> f64 {
        let wash = p.response[7]
            * p.speed
            * self.throttle.max(0.0)
            * (1.0 - u / (0.5 * p.speed)).clamp(0.0, 1.0);
        (if u >= 0.0 { u } else { u * 0.5 }) + wash
    }
    fn hull_tick(
        &mut self,
        dt: f64,
        throttle: f64,
        helm: f64,
        carried: bool,
        p: BoatProfile,
        nav: &BoatNavigation,
    ) {
        let k = p.response;
        self.throttle = toward(self.throttle, throttle.clamp(-1.0, 1.0), dt / k[3]);
        self.rudder = toward(self.rudder, helm.clamp(-1.0, 1.0), dt / k[4]);
        let mut u = self.speed;
        let thrust = k[0]
            * if self.throttle > 0.0 {
                self.throttle
            } else {
                self.throttle * k[8]
            };
        let turn = self.rudder * self.rudder_flow(u, p) / p.radius();
        let most = k[5] / u.abs().max(1.0);
        self.yaw_rate += (turn.clamp(-most, most) - self.yaw_rate) * (1.0 - libm::exp(-dt / k[2]));
        u += (thrust - p.drag(u) + self.yaw_rate * self.sway) * dt;
        self.sway = (self.sway - self.yaw_rate * u * dt) / (1.0 + k[1] * dt);
        self.speed = u;
        self.yaw = f64::from((self.yaw + self.yaw_rate * dt) as f32);
        let forward = direction(self.yaw);
        let mut through =
            forward * self.speed as f32 + Vector3::Y.cross(forward) * self.sway as f32;
        if carried
            && self.current != Vector3::ZERO
            && nav.open(self.position + (through + self.current) * dt as f32)
        {
            through += self.current;
        }
        self.velocity = through;
        let mut next = self.position + through * dt as f32;
        next.y = LEVEL;
        self.grounded = !nav.open(next);
        if self.grounded {
            self.speed *= 0.4;
            self.sway *= 0.4;
            self.yaw_rate *= 0.5;
        } else {
            self.position = next;
        }
    }
    fn con(&mut self, dt: f64, to: Vector3, want: f64, p: BoatProfile, nav: &BoatNavigation) {
        let astern = want < 0.0;
        let me = flat(self.position);
        let ground = flat(self.velocity);
        let mut course = self.yaw + if astern { PI } else { 0.0 };
        if ground.length() > 1.0 && (ground.dot(direction(self.yaw)) < 0.0) == astern {
            course = yaw(ground);
        }
        let error = wrap(yaw(to - me) - course);
        let turn = if error.abs() < PI * 0.5 {
            2.0 * libm::sin(error) * f64::from(ground.length()).max(1.0)
                / f64::from(me.distance(to)).max(1.0)
        } else {
            (if self.about != 0.0 && !astern {
                self.about
            } else {
                sign(error)
            }) * 10.0
        };
        let flow = self.rudder_flow(self.speed, p);
        let helm = if flow.abs() > 0.3 {
            (2.0 * turn - self.yaw_rate) * p.radius() / flow
        } else {
            self.rudder
        };
        let hold = p.drag(want) / p.response[0] * if astern { 1.0 / p.response[8] } else { 1.0 };
        self.hull_tick(
            dt,
            hold + (want - self.speed) * 3.0 / p.speed,
            helm,
            true,
            p,
            nav,
        );
    }
    fn lie_to(&mut self, dt: f64, p: BoatProfile, nav: &BoatNavigation) {
        let mut throttle = 0.0;
        if self.speed.abs() > 0.05 {
            throttle = -sign(self.speed) * (self.speed.abs() * 3.0 / p.speed + 0.15).min(1.0);
        } else if self.throttle == 0.0 {
            self.speed = 0.0;
        }
        self.hull_tick(dt, throttle, self.rudder, self.speed.abs() > 1.0, p, nav);
    }
    fn boat_look(&self, p: BoatProfile) -> f64 {
        (0.8 * f64::from(p.hull.z) + self.speed.abs() * (1.0 + p.response[2] + p.response[4]))
            .clamp(8.0, 45.0)
    }
    fn passage_speed(&self, points: &[Vector3], index: usize, p: BoatProfile) -> f64 {
        let me = flat(self.position);
        let stop = 0.4 * p.response[0];
        let to_end = f64::from(me.distance(flat(*points.last().unwrap())));
        let mut v = p.speed.min(
            libm::sqrt(2.0 * stop * (to_end - 2.0 - self.speed.abs() * p.response[3]).max(0.0))
                + 0.4,
        );
        let heading = self.yaw + if self.reverse { PI } else { 0.0 };
        let mut d = 16.0;
        let far = self.speed * self.speed / (2.0 * stop) + 16.0;
        while d < far * 1.5 && d <= 128.0 {
            let bend = wrap(yaw(self.lookahead(points, index, d) - me) - heading).abs();
            let kappa = if bend > PI * 0.5 {
                1.0 / p.radius()
            } else {
                2.0 * libm::sin(bend) / d
            };
            let v_bend = libm::sqrt(p.response[5] / kappa.max(0.0005));
            v = v.min(libm::sqrt(
                v_bend * v_bend + 2.0 * stop * (d - 16.0).max(0.0),
            ));
            d *= 2.0;
        }
        v
    }
    fn under_way(
        &mut self,
        dt: f64,
        cap: f64,
        p: BoatProfile,
        nav: &BoatNavigation,
        traffic: &[Traffic],
    ) -> usize {
        let points = std::mem::take(&mut self.path);
        let n = points.len();
        let mut i = self.path_index as usize;
        let me = flat(self.position);
        let reach = (f64::from(p.hull.z) * 0.2).max(2.5);
        while i < n - 1 {
            let at = flat(points[i]);
            let segment = flat(points[i + 1]) - at;
            if f64::from(me.distance(at)) < reach
                || (segment.length() > 0.01 && (me - at).dot(segment) > 0.0)
            {
                i += 1;
            } else {
                break;
            }
        }
        let to_end = f64::from(me.distance(flat(points[n - 1])));
        if i >= n - 1 && to_end < reach && flat(self.velocity).length() < 0.6 {
            self.path = points;
            return n;
        }
        let mut at = self.lookahead(&points, i, self.boat_look(p));
        if !nav.line(self.position, at, 0.0) {
            at = flat(points[i]);
        }
        let error = wrap(yaw(at - me) - self.yaw);
        if !self.reverse && error.abs() > 2.1 && to_end < 2.0 * p.radius() {
            self.reverse = true;
        } else if self.reverse && (error.abs() < 1.2 || to_end > 2.0 * p.radius() + 10.0) {
            self.reverse = false;
        }
        let forward = direction(self.yaw);
        let mut want = self.passage_speed(&points, i, p);
        if self.reverse {
            want = -want.min(p.speed * 0.3);
        } else {
            at = self.avoid(at, forward, p.hull, |at| nav.open(at), traffic);
            want = want
                .min(cap)
                .min(self.avoid_cap.unwrap_or(f64::INFINITY))
                .min(self.traffic_limit(forward, want, p.hull, traffic));
        }
        self.con(dt, at, want, p, nav);
        self.path = points;
        i
    }
    fn near_end(&self, p: BoatProfile) -> bool {
        let end = *self.path.last().unwrap();
        let tries = if self.tries_for.is_some_and(|v| same(end, v)) {
            self.tries.min(3)
        } else {
            0
        };
        f64::from(flat(end - self.position).length())
            < (f64::from(p.hull.z) * 0.6).max(10.0) * f64::from(1 + tries)
    }
    fn tried_for(&mut self, now: f64) {
        let end = *self.path.last().unwrap();
        if self.tries_for.is_none_or(|v| !same(end, v)) {
            self.tries = 1;
        } else if self.tries_time.is_none_or(|t| now - t > 6.0) {
            self.tries += 1;
        }
        self.tries_for = Some(end);
        self.tries_time = Some(now);
    }
    fn in_reach(rel: Vector3, forward: Vector3, radius: f64) -> bool {
        let f = f64::from(rel.dot(forward));
        let l = f64::from(rel.dot(forward.cross(Vector3::Y))).abs();
        f > 0.0 && f * f + l * l > 2.0 * radius * l
    }
    fn can_come_round(
        &self,
        side: f64,
        to: Vector3,
        most: f64,
        p: BoatProfile,
        nav: &BoatNavigation,
    ) -> bool {
        let radius = p.radius();
        let me = flat(self.position);
        let center = me + Vector3::Y.cross(direction(self.yaw)) * side as f32 * radius as f32;
        let half = f64::from(p.hull.x) * 0.5;
        let step = (4.0 / radius).min(0.3);
        let mut at = me;
        let mut angle = 0.0;
        while angle < most {
            let off = wrap(yaw(to - at) - (self.yaw + side * angle));
            if off.abs() < PI * 0.5 && (off.abs() <= step || sign(off) != side) {
                let run = to - at;
                let by = to - normalized(run) * run.length().min(p.hull.z);
                return nav.line(at, by, half) && nav.line(by, to, 0.0);
            }
            angle += step;
            let arm = transform(rotation(side * angle), me - center);
            at = center + arm;
            let out = normalized(arm) * half as f32;
            if !nav.open(at) || !nav.open(at + out) || !nav.open(at - out) {
                return false;
            }
        }
        false
    }
    fn boat_rejoin(&mut self, p: BoatProfile, nav: &BoatNavigation) -> bool {
        let n = self.path.len();
        let i = self.path_index as usize;
        let me = flat(self.position);
        if i >= n - 1
            || self.reverse
            || f64::from(me.distance(flat(self.path[i]))) < self.boat_look(p)
        {
            return false;
        }
        let forward = direction(self.yaw);
        let radius = p.radius();
        if Self::in_reach(flat(self.path[i]) - me, forward, radius) {
            return false;
        }
        let mut tries = 0;
        for j in (i + 1..=(n - 1).min(i + 24)).rev() {
            let rel = flat(self.path[j]) - me;
            if rel.length() > 150.0 || !Self::in_reach(rel, forward, radius) {
                continue;
            }
            if self.can_come_round(
                sign(wrap(yaw(rel) - self.yaw)),
                flat(self.path[j]),
                PI,
                p,
                nav,
            ) {
                self.path_index = j as u32;
                return true;
            }
            tries += 1;
            if tries >= 6 {
                return false;
            }
        }
        false
    }
    fn choose_about(&mut self, p: BoatProfile, nav: &BoatNavigation) -> bool {
        let error = wrap(
            yaw(
                self.lookahead(&self.path, self.path_index as usize, self.boat_look(p))
                    - flat(self.position),
            ) - self.yaw,
        );
        if error.abs() < PI * 0.5
            || self.reverse
            || (error.abs() > 2.1
                && f64::from(flat(*self.path.last().unwrap() - self.position).length())
                    < 2.0 * p.radius())
        {
            self.about = 0.0;
        } else if self.about == 0.0 {
            let course = self.lookahead(&self.path, self.path_index as usize, p.radius() * 3.0);
            let ce = wrap(yaw(course - flat(self.position)) - self.yaw);
            let side = if ce.abs() < 3.0 {
                sign(ce)
            } else {
                sign(error)
            };
            self.about = side;
            if !self.can_come_round(side, course, TAU, p, nav)
                && self.can_come_round(-side, course, TAU, p, nav)
            {
                self.about = -side;
                return true;
            }
        }
        false
    }
    fn go_astern(&mut self, nav: &mut BoatNavigation) {
        self.path = nav.path(self.position, *self.path.last().unwrap());
        self.path_index = 0;
        self.about = 0.0;
        self.astern = true;
        self.astern_timer = 12.0;
        self.astern_from = self.position;
        self.astern_stop = false;
        self.stuck_timer = 0.0;
        self.stuck_position = self.position;
    }
    fn back_off(&mut self, dt: f64, p: BoatProfile, nav: &mut BoatNavigation) {
        self.astern_timer -= dt;
        let radius = p.radius();
        let aim = if self.path.is_empty() {
            0.0
        } else {
            wrap(yaw(self.lookahead(&self.path, 0, radius * 2.0) - flat(self.position)) - self.yaw)
        };
        let backed = f64::from(flat(self.position - self.astern_from).length());
        if backed > radius * 1.5
            || (backed > (radius * 0.3).max(3.0) && aim.abs() < 0.7)
            || self.astern_timer <= 0.0
        {
            self.astern_stop = true;
        }
        let want = if self.astern_stop {
            0.0
        } else {
            -p.speed * 0.3
        };
        let flow = self.rudder_flow(self.speed, p);
        let helm = if flow.abs() > 0.3 {
            (aim * 2.0).clamp(-1.0, 1.0) * self.speed.abs() / flow
        } else {
            self.rudder
        };
        self.hull_tick(
            dt,
            p.drag(want) / p.response[0] * 2.0 + (want - self.speed) * 3.0 / p.speed,
            helm,
            true,
            p,
            nav,
        );
        if self.path.is_empty()
            || (self.astern_stop && self.speed.abs() < 0.3)
            || (self.grounded && self.speed < 0.0)
            || self.astern_timer < -8.0
        {
            self.astern = false;
            if !self.path.is_empty() {
                self.path = nav.path(self.position, *self.path.last().unwrap());
                self.path_index = 0;
            }
            self.stuck_timer = 0.0;
            self.stuck_position = self.position;
        }
    }
    pub fn boat_drive(
        &mut self,
        dt: f64,
        now: f64,
        p: BoatProfile,
        target: Option<Vector3>,
        nav: &mut BoatNavigation,
        water: Option<&Water>,
        traffic: &[Traffic],
    ) -> Result<BoatEvents, &'static str> {
        if !dt.is_finite()
            || !(0.0..=1.0).contains(&dt)
            || !now.is_finite()
            || now.abs() > 1e12
            || !p.valid()
            || target.is_some_and(|v| !point(v))
            || water.is_some_and(|w| !w.valid() || w.side as f64 * 0.5 != nav.half())
            || !valid_traffic(traffic)
            || self.tries >= 1_000_000
        {
            return Err("invalid boat drive");
        }
        let mut out = BoatEvents::default();
        self.position.y = LEVEL;
        self.current_timer -= dt;
        if self.current_timer <= 0.0 {
            self.current_timer = 0.5;
            self.current = water.map_or(Vector3::ZERO, |w| w.current(self.position));
        }
        if self.path_index as usize >= self.path.len() {
            self.astern = false;
            self.tries = 0;
            self.lie_to(dt, p, nav);
            return Ok(out);
        }
        if !self.passengers.is_empty() {
            self.landing = true;
        }
        if self.astern {
            self.back_off(dt, p, nav);
            return Ok(out);
        }
        let mut cap = f64::INFINITY;
        if self.assault {
            if let Some(t) = target.filter(|&t| {
                f64::from(flat(t - self.position).length()) < if p.cannon { 70.0 } else { 58.0 }
            }) {
                let bearing = wrap(yaw(flat(t - self.position)) - self.yaw);
                cap = if bearing.abs() < PI * 0.5 {
                    p.speed * 0.4
                } else {
                    0.0
                };
            }
        }
        self.stuck_timer = if cap == 0.0 {
            0.0
        } else {
            self.stuck_timer + dt
        };
        if self.stuck_timer > 4.0 {
            if flat(self.position - self.stuck_position).length() < 1.5 {
                if self.near_end(p) {
                    self.path_index = self.path.len() as u32;
                    return Ok(out);
                }
                out.unstuck = true;
                self.tried_for(now);
                self.go_astern(nav);
                return Ok(out);
            }
            self.stuck_timer = 0.0;
            self.stuck_position = self.position;
        }
        self.rejoin_timer -= dt;
        if self.rejoin_timer <= 0.0 {
            self.rejoin_timer = 1.0;
            out.rejoined = self.boat_rejoin(p, nav);
        }
        out.seaward = self.choose_about(p, nav);
        self.path_index = self.under_way(dt, cap, p, nav, traffic) as u32;
        if self.grounded && self.speed > 0.5 && (self.path_index as usize) < self.path.len() {
            if self.near_end(p) {
                self.path_index = self.path.len() as u32;
            } else {
                out.aground = true;
                self.tried_for(now);
                self.go_astern(nav);
            }
        }
        Ok(out)
    }
}
