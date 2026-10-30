use crate::collision::{BoxShape, CollisionWorld};
use crate::state_codec::{Reader, Writer};
use crate::vector::Vector3;
use std::collections::{BTreeMap, HashMap, VecDeque};

const CACHE_LIMIT: usize = 4096;
const SMOKE_LIMIT: usize = 100_000;

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Smoke {
    pub center: Vector3,
    pub radius: f64,
}

impl Smoke {
    fn valid(self) -> bool {
        valid_point(self.center) && self.radius.is_finite() && (0.0..=4096.0).contains(&self.radius)
    }
    fn blocks(self, from: Vector3, to: Vector3) -> bool {
        let ab = to - from;
        let squared = f64::from(ab.length_squared());
        let nearest = if squared < 0.0001 {
            from
        } else {
            let t = (f64::from((self.center - from).dot(ab)) / squared).clamp(0.0, 1.0);
            from + ab * t as f32
        };
        f64::from(self.center.distance(nearest)) < self.radius
    }
}

#[derive(Clone, Copy, Hash, PartialEq, Eq)]
struct Key {
    eye: [u32; 3],
    target: u64,
}

struct Obstruction {
    points: Vec<Vector3>,
    excluded: Vec<i64>,
    blockers: Vec<BoxShape>,
    stamp: u64,
}

#[derive(Debug, PartialEq, Eq)]
pub enum Sight {
    Hidden,
    Visible,
    ReusedObstruction,
}

#[derive(Default)]
pub struct Visibility {
    projectiles: BTreeMap<u64, Smoke>,
    fires: Vec<Smoke>,
    blocked: HashMap<Key, Obstruction>,
    recent: VecDeque<(Key, u64)>,
    stamp: u64,
    pub rays: u64,
}

impl Visibility {
    pub fn set_projectile(&mut self, id: u64, smoke: Smoke) -> bool {
        if id == 0 || id > i64::MAX as u64 || !smoke.valid() {
            return false;
        }
        if smoke.radius <= 0.8 {
            self.projectiles.remove(&id);
            return true;
        }
        if self.projectiles.len() >= SMOKE_LIMIT && !self.projectiles.contains_key(&id) {
            return false;
        }
        self.projectiles.insert(id, smoke);
        true
    }
    pub fn remove_projectile(&mut self, id: u64) {
        self.projectiles.remove(&id);
    }
    pub fn set_fires(&mut self, fires: &[Smoke]) -> bool {
        if fires.len() > SMOKE_LIMIT || fires.iter().any(|smoke| !smoke.valid()) {
            return false;
        }
        self.fires.clear();
        self.fires.extend_from_slice(fires);
        true
    }
    pub fn smoke_blocks(&self, from: Vector3, to: Vector3) -> bool {
        self.projectiles
            .values()
            .chain(&self.fires)
            .any(|smoke| smoke.blocks(from, to))
    }

    pub fn can_see(
        &mut self,
        collision: &mut CollisionWorld,
        eye: Vector3,
        target: u64,
        points: &[Vector3],
        excluded: &[i64],
        cache_obstruction: bool,
    ) -> Option<Sight> {
        if !valid_point(eye)
            || points.len() > 256
            || points.iter().any(|p| !valid_point(*p))
            || excluded.len() > 4096
            || excluded.iter().any(|id| *id < 0)
        {
            return None;
        }
        let key = Key {
            eye: eye
                .to_array()
                .map(|v| if v == 0.0 { 0 } else { v.to_bits() }),
            target,
        };
        if cache_obstruction
            && self.blocked.get(&key).is_some_and(|old| {
                old.points == points
                    && old.excluded == excluded
                    && old
                        .blockers
                        .iter()
                        .all(|shape| collision.shape(shape.body, shape.shape) == Some(*shape))
            })
        {
            self.touch(key);
            return Some(Sight::ReusedObstruction);
        }
        let mut blockers = Vec::new();
        let mut cacheable = cache_obstruction;
        for point in points {
            self.rays += 1;
            if let Some(hit) = collision.ray(eye, *point, excluded) {
                if cacheable
                    && !blockers
                        .iter()
                        .any(|s: &BoxShape| s.body == hit.body && s.shape == hit.shape)
                {
                    blockers.push(collision.shape(hit.body, hit.shape).unwrap());
                }
            } else {
                if !self.smoke_blocks(eye, *point) {
                    if cache_obstruction {
                        self.blocked.remove(&key);
                    }
                    return Some(Sight::Visible);
                }
                cacheable = false;
            }
        }
        if cache_obstruction {
            if cacheable && !blockers.is_empty() {
                if !self.blocked.contains_key(&key) && self.blocked.len() >= CACHE_LIMIT {
                    while let Some((old, stamp)) = self.recent.pop_front() {
                        if self
                            .blocked
                            .get(&old)
                            .is_some_and(|entry| entry.stamp == stamp)
                        {
                            self.blocked.remove(&old);
                            break;
                        }
                    }
                }
                self.blocked.insert(
                    key,
                    Obstruction {
                        points: points.to_vec(),
                        excluded: excluded.to_vec(),
                        blockers,
                        stamp: 0,
                    },
                );
                self.touch(key);
            } else {
                self.blocked.remove(&key);
            }
        }
        Some(Sight::Hidden)
    }

    fn touch(&mut self, key: Key) {
        self.stamp = self.stamp.wrapping_add(1);
        if self.stamp == 0 {
            self.blocked.clear();
            self.recent.clear();
            return;
        }
        self.blocked.get_mut(&key).unwrap().stamp = self.stamp;
        self.recent.push_back((key, self.stamp));
        if self.recent.len() >= CACHE_LIMIT * 2 {
            self.recent.retain(|(key, stamp)| {
                self.blocked
                    .get(key)
                    .is_some_and(|entry| entry.stamp == *stamp)
            });
        }
    }

    /// Geometry proofs only save queries; rebuilding them cannot change visibility.
    pub fn checkpoint(&self) -> Vec<u8> {
        let mut out = Writer::new(b"FLVS\x01\0\0\0");
        out.u32(self.projectiles.len() as u32);
        for (id, smoke) in &self.projectiles {
            out.u64(*id);
            out.point(smoke.center);
            out.f64(smoke.radius);
        }
        out.u32(self.fires.len() as u32);
        for smoke in &self.fires {
            out.point(smoke.center);
            out.f64(smoke.radius);
        }
        out.0
    }

    pub fn restore(bytes: &[u8]) -> Result<Self, &'static str> {
        let mut input = Reader::new(bytes, b"FLVS\x01\0\0\0")?;
        let mut visibility = Self::default();
        let count = input.u32()? as usize;
        if count > SMOKE_LIMIT {
            return Err("too many projectile smoke volumes");
        }
        let mut last_id = 0;
        for _ in 0..count {
            let id = input.u64()?;
            let smoke = Smoke {
                center: input.point()?,
                radius: input.f64()?,
            };
            if id <= last_id || smoke.radius <= 0.8 || !visibility.set_projectile(id, smoke) {
                return Err("invalid projectile smoke");
            }
            last_id = id;
        }
        let count = input.u32()? as usize;
        if count > SMOKE_LIMIT {
            return Err("too many fire smoke volumes");
        }
        for _ in 0..count {
            let smoke = Smoke {
                center: input.point()?,
                radius: input.f64()?,
            };
            if !smoke.valid() {
                return Err("invalid fire smoke");
            }
            visibility.fires.push(smoke);
        }
        input.finish()?;
        Ok(visibility)
    }
}

fn valid_point(point: Vector3) -> bool {
    point.is_finite() && point.abs().max_element() <= 1_000_000.0
}
