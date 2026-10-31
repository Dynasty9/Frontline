//! Infantry aim selection and its short-lived line-of-sight cache.
use crate::collision::CollisionWorld;
use crate::random::SimulationRandom;
use crate::state_codec::{Reader, Writer};
use crate::vector::Vector3;
use crate::visibility::{Sight, Visibility};

#[derive(Clone, Copy, Debug)]
pub enum TargetKind {
    Infantry { over_cover: bool, cover_height: f64 },
    Drone,
    Structure,
    Other,
}

#[derive(Clone, Copy, Debug)]
pub struct Target<'a> {
    pub id: u64,
    pub kind: TargetKind,
    pub position: Vector3,
    pub center: Vector3,
    pub points: &'a [Vector3],
    pub excluded: &'a [i64],
}

#[derive(Clone, Copy, Debug)]
pub struct AimInput<'a> {
    pub time: f64,
    pub position: Vector3,
    pub eye: Vector3,
    pub target: Option<Target<'a>>,
    pub blind: bool,
    pub cache_obstruction: bool,
    pub cover_fire: Option<Vector3>,
    pub last_known: Option<Vector3>,
    pub weapon_range: f64,
}

#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct InfantryAim {
    pub sight_target: u64,
    pub sight_until: f64,
    pub visible: bool,
}

#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct AimResult {
    pub point: Option<Vector3>,
    pub target: u64,
    pub reused_obstruction: bool,
}

fn point(p: Vector3) -> bool {
    p.is_finite() && p.abs().max_element() <= 1_000_000.0
}

impl Target<'_> {
    fn valid(self) -> bool {
        self.id > 0
            && self.id <= i64::MAX as u64
            && point(self.position)
            && point(self.center)
            && self.points.len() <= 256
            && self.points.iter().all(|p| point(*p))
            && self.excluded.len() <= 4096
            && self.excluded.iter().all(|id| *id >= 0)
            && match self.kind {
                TargetKind::Infantry { cover_height, .. } => {
                    !self.points.is_empty()
                        && cover_height.is_finite()
                        && cover_height.abs() <= 1_000_000.0
                }
                _ => true,
            }
    }

    pub fn aim_point(self, rng: &mut SimulationRandom) -> Result<Vector3, &'static str> {
        if !self.valid() {
            return Err("invalid infantry aim target");
        }
        Ok(match self.kind {
            TargetKind::Infantry {
                over_cover,
                cover_height,
            } => {
                if over_cover && f64::from(rng.randf()) < 0.35 {
                    self.position + Vector3::new(0.0, (cover_height - 0.12).min(1.0) as f32, 0.0)
                } else {
                    self.points[rng.randi() as usize % self.points.len()]
                }
            }
            TargetKind::Drone => self.position,
            _ => self.center,
        })
    }
}

impl InfantryAim {
    pub fn valid(self) -> bool {
        self.sight_target <= i64::MAX as u64
            && self.sight_until.is_finite()
            && self.sight_until.abs() <= 1e12
    }

    pub fn choose(
        &mut self,
        input: AimInput<'_>,
        collision: &mut CollisionWorld,
        visibility: &mut Visibility,
        rng: &mut SimulationRandom,
    ) -> Result<AimResult, &'static str> {
        if !self.valid()
            || !input.time.is_finite()
            || input.time.abs() > 1e12 - 1.0
            || !point(input.position)
            || !point(input.eye)
            || !input.weapon_range.is_finite()
            || !(0.0..=1_000_000.0).contains(&input.weapon_range)
            || input.cover_fire.is_some_and(|p| !point(p))
            || input.last_known.is_some_and(|p| !point(p))
            || input.target.is_some_and(|t| !t.valid())
        {
            return Err("invalid infantry aim input");
        }
        let mut result = AimResult::default();
        if let Some(target) = input.target {
            if input.blind {
                result.target = target.id;
                result.point = Some(
                    target.position
                        + Vector3::new(
                            rng.randf_range(-1.5, 1.5),
                            rng.randf_range(0.5, 1.8),
                            rng.randf_range(-1.5, 1.5),
                        ),
                );
                return Ok(result);
            }
            if target.id != self.sight_target || input.time > self.sight_until {
                self.sight_target = target.id;
                self.sight_until = input.time + 0.3;
                self.visible = match target.kind {
                    TargetKind::Structure => collision
                        .ray(input.eye, target.position + Vector3::Y, &[])
                        .is_none_or(|hit| hit.body == target.id as i64),
                    TargetKind::Drone => {
                        collision.ray(input.eye, target.position, &[]).is_none()
                            && !visibility.smoke_blocks(input.eye, target.position)
                    }
                    _ => {
                        let sight = visibility
                            .can_see(
                                collision,
                                input.eye,
                                target.id,
                                target.points,
                                target.excluded,
                                input.cache_obstruction,
                            )
                            .ok_or("invalid infantry sight query")?;
                        result.reused_obstruction = sight == Sight::ReusedObstruction;
                        sight == Sight::Visible
                    }
                };
            }
            if self.visible {
                result.target = target.id;
                result.point = Some(target.aim_point(rng)?);
                return Ok(result);
            }
        }
        if let Some(cover) = input.cover_fire.filter(|p| {
            let delta = *p - input.position;
            f64::from(Vector3::new(delta.x, 0.0, delta.z).length()) < input.weapon_range * 1.1
        }) {
            result.point = Some(
                cover
                    + Vector3::new(
                        rng.randf_range(-2.5, 2.5),
                        rng.randf_range(0.6, 1.4),
                        rng.randf_range(-2.5, 2.5),
                    ),
            );
        } else if let Some(known) = input.last_known {
            result.point = Some(
                known + Vector3::new(rng.randf_range(-1.5, 1.5), 1.0, rng.randf_range(-1.5, 1.5)),
            );
        }
        Ok(result)
    }

    pub fn checkpoint(self) -> Vec<u8> {
        let mut out = Writer::new(b"FLIA\x01\0\0\0");
        out.u64(self.sight_target);
        out.f64(self.sight_until);
        out.byte(u8::from(self.visible));
        out.0
    }

    pub fn restore(bytes: &[u8]) -> Result<Self, &'static str> {
        let mut input = Reader::new(bytes, b"FLIA\x01\0\0\0")?;
        let state = Self {
            sight_target: input.u64()?,
            sight_until: input.f64()?,
            visible: input.boolean()?,
        };
        input.finish()?;
        if !state.valid() {
            return Err("invalid infantry aim checkpoint");
        }
        Ok(state)
    }
}
