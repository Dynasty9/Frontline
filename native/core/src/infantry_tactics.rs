//! Infantry applies cover and movement decisions to its own retained state.
use crate::cover_search::{self, Scene, SearchResult};
use crate::infantry::{Goal, Infantry};
use crate::infantry_orders::RouteOrder;
use crate::infantry_pose::Posture;
use crate::random::SimulationRandom;
use crate::vector::{normalized, Vector3};

pub struct Shelter<'a> {
    pub gone: bool,
    pub burn: f64,
    pub anchors: &'a [Vector3],
}

#[derive(Clone, Copy)]
pub struct CoverRequest<'a> {
    pub time: f64,
    pub anchor: Vector3,
    pub radius: f64,
    pub threats: &'a [Vector3],
    pub grouped: bool,
    pub unarmed: bool,
    pub weapon_range: f64,
    pub danger: bool,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct CoverOrder {
    pub search: SearchResult,
    pub route: Option<RouteOrder>,
}

fn point(p: Vector3) -> bool {
    p.is_finite() && p.abs().max_element() <= 1_000_000.0
}
fn flat(p: Vector3) -> Vector3 {
    Vector3::new(p.x, 0.0, p.z)
}
fn threats_valid(threats: &[Vector3]) -> bool {
    threats.len() <= 4096 && threats.iter().copied().all(point)
}
fn time(t: f64) -> bool {
    t.is_finite() && t.abs() <= 1e12 - 10.0
}

impl Infantry {
    pub fn threat_direction(&self, threats: &[Vector3]) -> Result<Vector3, &'static str> {
        if !threats_valid(threats) || !point(self.motion.position) || !point(self.orders.hold_face)
        {
            return Err("invalid infantry threats");
        }
        Ok(self.direction_from(threats))
    }

    fn direction_from(&self, threats: &[Vector3]) -> Vector3 {
        let mut direction = Vector3::ZERO;
        for threat in threats {
            direction += normalized(flat(*threat - self.motion.position));
        }
        if f64::from(direction.length()) < 0.01 {
            self.orders.hold_face
        } else {
            normalized(direction)
        }
    }

    pub fn sector_direction(
        &self,
        threats: &[Vector3],
        centroid: Vector3,
        member_count: usize,
        last_member: bool,
    ) -> Result<Vector3, &'static str> {
        if !self.valid() || !threats_valid(threats) || !point(centroid) || member_count > 100_000 {
            return Err("invalid infantry sector");
        }
        let mut forward = self.direction_from(threats);
        if threats.is_empty() {
            let watch = flat(
                self.orders.hold_position + self.orders.hold_face * 40.0 - self.motion.position,
            );
            if f64::from(watch.length()) >= 0.01 {
                forward = normalized(watch);
            }
        }
        if member_count >= 6 && last_member && self.fight.visible_targets.is_empty() {
            return Ok(-forward);
        }
        let right = Vector3::new(-forward.z, 0.0, forward.x);
        let side = (f64::from((self.motion.position - centroid).dot(right)) / 5.0).clamp(-1.0, 1.0);
        Ok(normalized(forward + right * side as f32 * 0.85))
    }

    pub fn crawling(&self, danger: bool) -> bool {
        if self.orders.purpose != Goal::Cover || self.motion.path_index >= self.motion.path.len() {
            return false;
        }
        (self.cover.shifting && self.cover.height > 0.0 && self.cover.height < 1.12 && danger)
            || (self.vitals.suppression >= 70.0
                && f64::from(flat(self.orders.goal - self.motion.position).length()) < 2.6)
    }

    pub fn movement_speed(&self, danger: bool) -> f64 {
        if self.crawling(danger) {
            return 0.95;
        }
        let mut speed = [3.4, 4.6, 5.3][usize::from(self.orders.move_mode.min(2))];
        if matches!(self.identity.unit.as_str(), "mg_gunner" | "pkm") {
            speed *= 0.9;
        }
        if self.orders.move_mode == 0 && self.posture == Posture::Crouch {
            speed *= 0.8;
        }
        if self.vitals.stamina < 0.35 {
            speed *= 0.65 + self.vitals.stamina;
        }
        speed
    }

    pub fn reevaluate_cover(
        &mut self,
        now: f64,
        shelter: Option<Shelter<'_>>,
        threats: &[Vector3],
    ) -> Result<bool, &'static str> {
        if !self.valid()
            || !time(now)
            || !threats_valid(threats)
            || shelter.as_ref().is_some_and(|s| {
                !s.burn.is_finite()
                    || s.anchors.len() > 100_000
                    || !s.anchors.iter().copied().all(point)
            })
        {
            return Err("invalid infantry cover review");
        }
        if matches!(self.orders.purpose, Goal::Slot | Goal::Cover) && self.is_moving() {
            return Ok(false);
        }
        if !self.cover.at_cover {
            return Ok(now > self.cover.evaluate_at);
        }
        if self.cover.structure != 0 {
            let held = shelter.as_ref().is_some_and(|s| {
                let index = if self.cover.anchor < 0 {
                    s.anchors.len().checked_sub(1)
                } else {
                    Some(self.cover.anchor as usize)
                };
                !s.gone
                    && index
                        .and_then(|i| s.anchors.get(i))
                        .is_some_and(|p| f64::from(flat(*p - self.cover.position).length()) <= 0.3)
            });
            if !held || shelter.as_ref().is_some_and(|s| s.burn > 0.3) {
                self.cover.structure = 0;
                return Ok(true);
            }
        }
        if now > self.cover.evaluate_at {
            if f64::from(self.direction_from(threats).dot(self.cover.threat)) < 0.55
                || self.cover.kind == 0
                || (self.vitals.suppression > 45.0
                    && self.cover.kind == 3
                    && !self.fight.visible_targets.is_empty())
            {
                return Ok(true);
            }
            self.cover.evaluate_at = now + 2.5;
        }
        Ok(false)
    }

    pub fn seek_cover<A: AsRef<[crate::cover::Anchor]>>(
        &mut self,
        request: CoverRequest<'_>,
        scene: &mut Scene<'_, A>,
        rng: &mut SimulationRandom,
    ) -> Result<CoverOrder, &'static str> {
        if !self.valid()
            || !time(request.time)
            || self.orders.path_revision == i64::MAX as u64
            || scene.structures.iter().any(|s| s.id > u32::MAX as u64)
        {
            return Err("invalid retained infantry cover search");
        }
        let search = cover_search::find(
            cover_search::Input {
                id: u64::from(self.identity.id),
                team: i32::from(self.identity.team),
                position: self.motion.position,
                anchor: request.anchor,
                radius: request.radius,
                grouped: request.grouped && !self.orders.detached,
                prone: false,
                unarmed: request.unarmed,
                weapon_range: request.weapon_range,
                current_structure: self.cover.structure,
                current_anchor: self.cover.anchor,
            },
            request.threats,
            scene,
        )?;
        self.apply_cover_choice(request, search, rng)
    }

    pub(crate) fn apply_cover_choice(
        &mut self,
        request: CoverRequest<'_>,
        search: SearchResult,
        rng: &mut SimulationRandom,
    ) -> Result<CoverOrder, &'static str> {
        if !self.valid() || !time(request.time) || self.orders.path_revision == i64::MAX as u64 {
            return Err("invalid retained infantry cover choice");
        }
        self.cover.evaluate_at = request.time + f64::from(rng.randf_range(3.5, 6.0));
        self.weapon.peek_up = false;
        self.weapon.blind = false;
        let Some(choice) = search.choice else {
            self.cover.kind = 0;
            self.clear_cover();
            self.cover.threat = self.direction_from(request.threats);
            let route = if f64::from(flat(self.motion.position - request.anchor).length())
                > request.radius
            {
                Some(self.go_to(request.anchor, Goal::Slot, 0)?)
            } else {
                self.cover.at_cover = true;
                self.cover.position = self.motion.position;
                None
            };
            return Ok(CoverOrder { search, route });
        };
        self.cover.position = choice.position;
        self.cover.kind = choice.evaluation.kind as u8;
        self.cover.lean_direction = choice.evaluation.lean;
        self.cover.threat = choice.evaluation.threat_direction;
        self.cover.normal = choice.normal;
        self.cover.height = choice.height;
        self.cover.material = choice.material as i8;
        self.cover.structure = choice.structure;
        self.cover.anchor = choice.anchor;
        self.cover.shifting = false;
        let route = if f64::from(flat(self.motion.position - self.cover.position).length()) < 0.6 {
            self.cover.at_cover = true;
            None
        } else {
            self.cover.at_cover = false;
            let mode = if request.danger {
                if self.vitals.suppression > 35.0 {
                    2
                } else {
                    1
                }
            } else {
                0
            };
            Some(self.go_to(self.cover.position, Goal::Cover, mode)?)
        };
        Ok(CoverOrder { search, route })
    }
}
