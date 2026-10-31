//! Infantry route progress, vaulting, doors and ground following without scene callbacks.
use crate::collision::CollisionWorld;
use crate::infantry_vitals::Life;
use crate::path_planner::PathPlanner;
use crate::random::SimulationRandom;
use crate::state_codec::{Reader, Writer};
use crate::terrain::Terrain;
use crate::vector::{normalized, turn_yaw, Vector3};
use std::f64::consts::TAU;

#[derive(Clone, Debug, PartialEq)]
pub struct InfantryMotion {
    pub position: Vector3,
    pub yaw: f64,
    pub path: Vec<Vector3>,
    pub path_index: usize,
    pub stuck_position: Vector3,
    pub stuck_timer: f64,
    pub slide_timer: f64,
    pub slide_cooldown: f64,
    pub vaulting: bool,
    pub last_direction: Vector3,
    pub barrier_until: f64,
    pub barrier: bool,
    pub ground_until: f64,
    pub ground: f64,
    pub door_wait: f64,
    pub door_until: f64,
    pub door: u64,
    pub door_kick: bool,
}

impl Default for InfantryMotion {
    fn default() -> Self {
        Self {
            position: Vector3::ZERO,
            yaw: 0.0,
            path: Vec::new(),
            path_index: 0,
            stuck_position: Vector3::ZERO,
            stuck_timer: 0.0,
            slide_timer: 0.0,
            slide_cooldown: 0.0,
            vaulting: false,
            last_direction: Vector3::ZERO,
            barrier_until: 0.0,
            barrier: false,
            ground_until: -1.0,
            ground: 0.0,
            door_wait: 0.0,
            door_until: 0.0,
            door: 0,
            door_kick: false,
        }
    }
}

#[derive(Clone, Copy, Debug)]
pub struct Door {
    pub id: u64,
    pub position: Vector3,
    pub yaw: f64,
}

#[derive(Clone, Copy, Debug)]
pub struct MoveInput {
    pub dt: f64,
    pub time: f64,
    pub speed: f64,
    pub base_y: f64,
    pub alive: bool,
    pub path_pending: bool,
    pub cover_goal: bool,
    pub move_mode: i32,
    pub suppression: f64,
    pub backwards: bool,
    pub danger: bool,
    pub has_doors: bool,
    pub door_still_closed: bool,
    pub mount: Option<(Vector3, f64)>,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
#[repr(u8)]
pub enum Progress {
    Idle = 0,
    Moving = 1,
    Arrived = 2,
    Repath = 3,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct MoveResult {
    pub progress: Progress,
    pub opened_door: u64,
    pub speech: Option<u8>,
    pub slid: bool,
}

#[derive(Clone, Copy, Debug)]
pub struct Neighbor {
    pub id: u64,
    pub position: Vector3,
    pub life: Life,
}

#[derive(Clone, Copy, Debug)]
pub struct StationaryInput {
    pub dt: f64,
    pub time: f64,
    pub base_y: f64,
    pub separation: Vector3,
    pub prone: bool,
    pub at_cover: bool,
    pub cover_position: Vector3,
    pub cover_normal: Vector3,
    pub cover_kind: u8,
    pub last_shot: f64,
    pub peek_up: bool,
    pub target_valid: bool,
    pub sector: Vector3,
    pub mount: Option<(Vector3, f64)>,
}

/// Neighbors retain the world's 0.85 m query order and current poses.
pub fn separation(
    id: u64,
    position: Vector3,
    active: bool,
    neighbors: &[Neighbor],
    rng: &mut SimulationRandom,
) -> Result<Vector3, &'static str> {
    if id == 0
        || id > i64::MAX as u64
        || !valid_point(position)
        || neighbors.len() > 100_000
        || neighbors
            .iter()
            .any(|n| n.id == 0 || n.id > i64::MAX as u64 || !valid_point(n.position))
    {
        return Err("invalid infantry neighbors");
    }
    let mut separation = Vector3::ZERO;
    if active {
        for other in neighbors {
            if other.id == id || matches!(other.life, Life::Hidden | Life::Dead) {
                continue;
            }
            let mut direction = flat(position - other.position);
            let mut length = f64::from(direction.length());
            if length < 0.01 {
                direction = Vector3::new(
                    rng.randf_range(-1.0, 1.0) as f32,
                    0.0,
                    rng.randf_range(-1.0, 1.0) as f32,
                );
                length = 0.5;
            }
            separation += normalized(direction) * (0.85 - length) as f32;
        }
    }
    Ok(separation)
}

fn flat(p: Vector3) -> Vector3 {
    Vector3::new(p.x, 0.0, p.z)
}
fn valid_point(p: Vector3) -> bool {
    p.is_finite() && p.abs().max_element() <= 1_000_000.0
}
fn yaw_of(p: Vector3) -> f64 {
    libm::atan2(-f64::from(p.x), -f64::from(p.z))
}
fn door_blocks(door: Door, p: Vector3, direction: Vector3) -> bool {
    let angle = (-door.yaw) as f32;
    let (s, c) = (libm::sinf(angle), libm::cosf(angle));
    let local = |p: Vector3| {
        Vector3::new(
            c * p.x + 0.0 * p.y + s * p.z,
            p.y,
            -s * p.x + 0.0 * p.y + c * p.z,
        )
    };
    let p = local(p - door.position);
    let direction = local(direction);
    let z = f64::from(p.z) - 0.08;
    f64::from(p.x.abs()) < 1.05
        && z.abs() < 0.9
        && f64::from(direction.z.abs()) > 0.3
        && z * f64::from(direction.z) < 0.0
}

impl InfantryMotion {
    pub fn valid(&self) -> bool {
        [self.position, self.stuck_position, self.last_direction]
            .into_iter()
            .all(valid_point)
            && [
                self.yaw,
                self.stuck_timer,
                self.slide_timer,
                self.slide_cooldown,
                self.barrier_until,
                self.ground_until,
                self.ground,
                self.door_wait,
                self.door_until,
            ]
            .iter()
            .all(|n| n.is_finite() && n.abs() <= 1e12)
            && self.path.len() <= 1_000_000
            && self.path_index <= self.path.len()
            && self.path.iter().copied().all(valid_point)
            && self.door <= i64::MAX as u64
    }

    pub fn step(
        &mut self,
        input: MoveInput,
        nav: &PathPlanner,
        terrain: &Terrain,
        collision: &mut CollisionWorld,
        rng: &mut SimulationRandom,
        decks: &[u8],
        doors: &[Door],
    ) -> Result<MoveResult, &'static str> {
        if !self.valid()
            || nav.side() != terrain.n
            || !input.dt.is_finite()
            || !(0.0..=10.0).contains(&input.dt)
            || [input.time, input.speed, input.base_y, input.suppression]
                .iter()
                .any(|v| !v.is_finite() || v.abs() > 1e12)
            || input.speed < 0.0
            || input.mount.is_some_and(|(p, rate)| {
                !valid_point(p) || !rate.is_finite() || !(0.0..=TAU).contains(&rate)
            })
            || !decks.is_empty() && decks.len() != terrain.n * terrain.n
            || doors.len() > 4096
            || doors.iter().any(|d| {
                d.id == 0
                    || d.id > i64::MAX as u64
                    || !valid_point(d.position)
                    || !d.yaw.is_finite()
                    || d.yaw.abs() > 1_000_000.0
            })
        {
            return Err("invalid infantry movement");
        }
        let mut result = MoveResult {
            progress: Progress::Moving,
            opened_door: 0,
            speech: None,
            slid: false,
        };
        if input.path_pending {
            return Ok(result);
        }
        if self.path_index >= self.path.len() {
            result.progress = Progress::Idle;
            return Ok(result);
        }
        self.stuck_timer += input.dt;
        if self.stuck_timer > 3.0 {
            if f64::from(flat(self.position - self.stuck_position).length()) < 0.8
                && self.slide_timer <= 0.0
            {
                result.progress = Progress::Repath;
                return Ok(result);
            }
            self.stuck_timer = 0.0;
            self.stuck_position = self.position;
        }
        let mut to = flat(self.path[self.path_index] - self.position);
        let mut distance = f64::from(to.length());
        if distance < 0.3 {
            self.path_index += 1;
            if self.path_index >= self.path.len() {
                result.progress = Progress::Arrived;
                return Ok(result);
            }
            to = flat(self.path[self.path_index] - self.position);
            distance = f64::from(to.length());
            if distance < 0.001 {
                return Ok(result);
            }
        }
        let direction = Vector3::new(
            to.x / distance as f32,
            to.y / distance as f32,
            to.z / distance as f32,
        );
        let kind = nav.kind_at(self.position, false);
        self.vaulting = false;
        if kind == 1 && input.alive {
            if input.time > self.barrier_until {
                self.barrier_until = input.time + 0.2;
                let from = self.position + Vector3::new(0.0, 0.45, 0.0);
                self.barrier = collision.ray(from, from + direction * 0.9, &[]).is_some();
            }
            self.vaulting = self.barrier;
        }
        let mut multiplier = if kind == 2 {
            0.3
        } else if self.vaulting {
            0.7
        } else {
            1.0
        };
        if self.slide_timer > 0.0 {
            self.slide_timer -= input.dt;
            multiplier = 1.3;
        }
        multiplier *= terrain.speed(self.position, false, false);
        let step = distance.min(input.speed * multiplier * input.dt);
        if self.door_wait > 0.0 || input.has_doors && input.time > self.door_until {
            if self.door_wait > 0.0 {
                self.door_wait -= input.dt;
                self.stuck_timer = 0.0;
                if self.door_wait > 0.0 {
                    return Ok(result);
                }
                if input.door_still_closed {
                    result.opened_door = self.door;
                }
                self.door = 0;
            } else {
                self.door_until = input.time + 0.12;
                if input.alive {
                    if let Some(door) = doors
                        .iter()
                        .find(|d| door_blocks(**d, self.position, direction))
                    {
                        self.door = door.id;
                        self.door_kick = input.danger;
                        self.door_wait = if self.door_kick { 0.5 } else { 0.8 };
                        self.yaw = f64::from(yaw_of(direction) as f32);
                        if self.door_kick && f64::from(rng.randf()) < 0.4 {
                            result.speech = Some((rng.randi() % 3) as u8);
                        }
                        return Ok(result);
                    }
                }
            }
        }
        self.last_direction = direction;
        self.position += direction * step as f32;
        let mut target_y = input.base_y + if self.vaulting { 0.5 } else { 0.0 };
        if input.base_y == 0.0 {
            target_y += self.cached_ground(input.time, terrain, decks);
        }
        self.position.y = (f64::from(self.position.y)
            + (target_y - f64::from(self.position.y)) * (1.0 - libm::exp(-input.dt * 12.0)))
            as f32;
        if !input.backwards {
            self.yaw = turn_yaw(
                self.yaw,
                direction,
                self.position,
                input.dt,
                10.0,
                input.mount,
            );
        }
        if input.cover_goal
            && input.move_mode >= 1
            && self.path_index == self.path.len() - 1
            && self.slide_timer <= 0.0
            && input.time > self.slide_cooldown
        {
            let remaining =
                f64::from(flat(self.path[self.path.len() - 1] - self.position).length());
            if remaining < 2.4 && remaining > 1.2 && input.suppression > 10.0 {
                self.slide_timer = 0.45;
                self.slide_cooldown = input.time + 4.0;
                result.slid = true;
            }
        }
        Ok(result)
    }

    /// A man at a halt makes room, settles onto the ground and watches over his cover.
    pub fn stationary(
        &mut self,
        input: StationaryInput,
        nav: &PathPlanner,
        terrain: &Terrain,
        decks: &[u8],
    ) -> Result<bool, &'static str> {
        if !self.valid()
            || nav.side() != terrain.n
            || !input.dt.is_finite()
            || !(0.0..=10.0).contains(&input.dt)
            || [input.time, input.base_y, input.last_shot]
                .iter()
                .any(|v| !v.is_finite() || v.abs() > 1e12)
            || [
                input.separation,
                input.cover_position,
                input.cover_normal,
                input.sector,
            ]
            .into_iter()
            .any(|p| !valid_point(p))
            || input.cover_kind > 3
            || input.mount.is_some_and(|(p, rate)| {
                !valid_point(p) || !rate.is_finite() || !(0.0..=TAU).contains(&rate)
            })
            || !decks.is_empty() && decks.len() != terrain.n * terrain.n
        {
            return Err("invalid stationary infantry");
        }
        let mut shuffle = false;
        if f64::from(input.separation.length_squared()) >= 0.0001 && !input.prone {
            let mut velocity = input.separation * 2.5;
            if f64::from(velocity.length()) > 1.4 {
                velocity = normalized(velocity) * 1.4;
            }
            let next = self.position + velocity * input.dt as f32;
            if nav.kind_at(next, false) != 3 {
                self.position = next;
                shuffle = f64::from(velocity.length()) > 0.3;
            }
        }
        self.cached_ground(input.time, terrain, decks);
        let height = f64::from(self.position.y);
        self.position.y = (height
            + (input.base_y + self.ground - height) * (1.0 - libm::exp(-input.dt * 8.0)))
            as f32;
        if input.at_cover && input.cover_normal != Vector3::ZERO {
            let offset = flat(input.cover_position - self.position);
            let length = offset.length();
            if f64::from(length) > 0.02 && f64::from(length) < 0.9 {
                let limit = (input.dt * 1.4) as f32;
                self.position += if length > limit {
                    normalized(offset) * limit
                } else {
                    offset
                };
            }
            if input.time - input.last_shot > 1.0
                && !(input.peek_up && input.target_valid)
                && input.cover_kind != 2
            {
                self.yaw = turn_yaw(
                    self.yaw,
                    input.cover_normal,
                    self.position,
                    input.dt,
                    5.0,
                    input.mount,
                );
            }
        } else if input.sector != Vector3::ZERO
            && input.time - input.last_shot > 1.2
            && !(input.at_cover && input.cover_kind != 0)
            && !input.target_valid
        {
            self.yaw = turn_yaw(
                self.yaw,
                input.sector,
                self.position,
                input.dt,
                3.0,
                input.mount,
            );
        }
        Ok(shuffle)
    }

    pub(crate) fn cached_ground(&mut self, now: f64, terrain: &Terrain, decks: &[u8]) -> f64 {
        if now > self.ground_until {
            self.ground_until = now + 0.3;
            self.ground = terrain.ground_y(
                self.position,
                !decks.is_empty() && decks[terrain.index(self.position)] == 1,
            );
        }
        self.ground
    }

    pub fn checkpoint(&self) -> Vec<u8> {
        let mut out = Writer::new(b"FLIM\x01\0\0\0");
        out.point(self.position);
        out.f64(self.yaw);
        out.u32(self.path.len() as u32);
        for p in &self.path {
            out.point(*p);
        }
        out.u32(self.path_index as u32);
        out.point(self.stuck_position);
        for v in [self.stuck_timer, self.slide_timer, self.slide_cooldown] {
            out.f64(v);
        }
        out.byte(u8::from(self.vaulting));
        out.point(self.last_direction);
        out.f64(self.barrier_until);
        out.byte(u8::from(self.barrier));
        for v in [
            self.ground_until,
            self.ground,
            self.door_wait,
            self.door_until,
        ] {
            out.f64(v);
        }
        out.u64(self.door);
        out.byte(u8::from(self.door_kick));
        out.0
    }

    pub fn restore(bytes: &[u8]) -> Result<Self, &'static str> {
        let mut input = Reader::new(bytes, b"FLIM\x01\0\0\0")?;
        let position = input.point()?;
        let yaw = input.f64()?;
        let count = input.u32()? as usize;
        if count > 1_000_000 {
            return Err("too many infantry waypoints");
        }
        let mut path = Vec::new();
        for _ in 0..count {
            path.push(input.point()?);
        }
        let value = Self {
            position,
            yaw,
            path,
            path_index: input.u32()? as usize,
            stuck_position: input.point()?,
            stuck_timer: input.f64()?,
            slide_timer: input.f64()?,
            slide_cooldown: input.f64()?,
            vaulting: input.boolean()?,
            last_direction: input.point()?,
            barrier_until: input.f64()?,
            barrier: input.boolean()?,
            ground_until: input.f64()?,
            ground: input.f64()?,
            door_wait: input.f64()?,
            door_until: input.f64()?,
            door: input.u64()?,
            door_kick: input.boolean()?,
        };
        input.finish()?;
        if !value.valid() {
            return Err("invalid infantry motion checkpoint");
        }
        Ok(value)
    }
}
