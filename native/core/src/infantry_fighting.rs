//! The firing sequence keeps cover changes ahead of stance, sight and barrel alignment.
use crate::actors::Actors;
use crate::collision::CollisionWorld;
use crate::cover::{rotation, transform, AnchorKind};
use crate::infantry::{Goal, Infantry};
use crate::infantry_aim::AimResult;
use crate::infantry_fire::{CoverReply, MountedGun};
use crate::infantry_orders::RouteOrder;
use crate::infantry_pose::Posture;
use crate::infantry_vitals::Life;
use crate::infantry_weapon::{CoverInput, CoverResult, StanceInput, Weapon};
use crate::path_planner::PathPlanner;
use crate::random::SimulationRandom;
use crate::spatial::{SpatialIndex, UNIT_CELL};
use crate::squad::Squad;
use crate::vector::{normalized, turn_yaw, Vector3};
use crate::visibility::Visibility;

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
#[repr(u8)]
pub enum Mode {
    #[default]
    Normal,
    Escort,
    Crew,
}

#[derive(Clone, Copy, Debug)]
pub struct WeaponInput {
    pub dt: f64,
    pub now: f64,
    pub moving: bool,
    pub mode: Mode,
    pub weapon: Option<Weapon>,
    pub gun: Option<MountedGun>,
}
impl WeaponInput {
    fn valid(self) -> bool {
        self.dt.is_finite()
            && (0.0..=10.0).contains(&self.dt)
            && self.now.is_finite()
            && self.now.abs() <= 1e12 - 100.0
            && self.weapon.is_none_or(Weapon::valid)
            && self.gun.is_none_or(MountedGun::valid)
    }
}

#[derive(Clone, Copy, Debug)]
pub struct WeaponStep {
    id: u32,
    input: WeaponInput,
    pinned: bool,
    danger: bool,
    target_valid: bool,
    covering: bool,
    cycled: bool,
    pub cycle: CoverResult,
    pub reply: CoverReply,
}

#[derive(Clone, Copy, Debug)]
pub struct WeaponReady {
    pub aim: AimResult,
    pub covering: bool,
    pub cycle: CoverResult,
    pub reply: CoverReply,
    pub route: Option<RouteOrder>,
}

fn flat(p: Vector3) -> Vector3 {
    Vector3::new(p.x, 0.0, p.z)
}
fn immediate_yaw(yaw: f64, direction: Vector3) -> f64 {
    if f64::from(direction.length_squared()) > 0.0001 {
        f64::from(libm::atan2(-f64::from(direction.x), -f64::from(direction.z)) as f32)
    } else {
        yaw
    }
}

impl Actors {
    pub fn ready_infantry_weapon(
        &mut self,
        id: u32,
        input: WeaponInput,
        range: f64,
        mut squad: Option<&mut Squad>,
        nav: &PathPlanner,
        units: &SpatialIndex,
        collision: &mut CollisionWorld,
        visibility: &mut Visibility,
        rng: &mut SimulationRandom,
    ) -> Result<WeaponReady, &'static str> {
        if !range.is_finite() || !(0.0..=1e6).contains(&range) || units.cell_size() != UNIT_CELL {
            return Err("invalid infantry firing context");
        }
        let step = self.begin_infantry_weapon(id, input, squad.as_deref_mut(), rng)?;
        let route = if step.cycle.shift_along {
            self.shift_infantry_cover(id, squad.as_deref(), nav, units)?
        } else {
            None
        };
        let aim =
            self.aim_infantry_weapon(step, range, squad.as_deref(), collision, visibility, rng)?;
        Ok(WeaponReady {
            aim,
            covering: step.covering,
            cycle: step.cycle,
            reply: step.reply,
            route,
        })
    }
    pub fn shift_infantry_cover(
        &mut self,
        id: u32,
        squad: Option<&Squad>,
        nav: &PathPlanner,
        units: &SpatialIndex,
    ) -> Result<Option<RouteOrder>, &'static str> {
        let s = self.soldier(id).ok_or("missing shifting soldier")?;
        if squad.is_some_and(|q| q.id != s.identity.squad) || units.cell_size() != UNIT_CELL {
            return Err("invalid infantry cover context");
        }
        let Some(st) = self
            .structure(s.cover.structure as u32)
            .filter(|st| !st.gone && s.cover.anchor >= 0)
        else {
            return Ok(None);
        };
        let edge = s.cover.kind == 2;
        let mut best = None;
        let mut distance = 9.0;
        for (i, anchor) in st.anchors.iter().enumerate() {
            if i == s.cover.anchor as usize
                || f64::from(anchor.normal.dot(s.cover.normal)) < 0.9
                || anchor.kind == AnchorKind::Stack
                || (anchor.kind == AnchorKind::Over) == edge
                || edge && anchor.kind == AnchorKind::Shelter
            {
                continue;
            }
            let d = f64::from(flat(anchor.position - s.motion.position).length());
            if d < 0.8 || d > if edge { 8.5 } else { 3.0 } {
                continue;
            }
            if nav.kind_at(anchor.position, false) == 3
                && nav
                    .nearest_walkable(anchor.position)
                    .is_none_or(|p| f64::from(flat(p - anchor.position).length()) >= 1.6)
            {
                continue;
            }
            if squad.is_some_and(|q| {
                q.members
                    .iter()
                    .filter_map(|id| self.soldier(*id))
                    .any(|other| {
                        other.identity.id != id
                            && other.vitals.life == Life::Alive
                            && flat(other.cover.position - anchor.position).length() < 1.0
                            && (other.cover.at_cover || other.orders.purpose == Goal::Cover)
                    })
            }) {
                continue;
            }
            if self
                .units_near(units, anchor.position, 1.3, -1)?
                .into_iter()
                .filter_map(|id| self.soldier(id))
                .any(|other| {
                    other.identity.id != id
                        && other.identity.team == s.identity.team
                        && other.vitals.life == Life::Alive
                        && (flat(other.cover.position - anchor.position).length() < 1.0
                            || f64::from(flat(other.motion.position - anchor.position).length())
                                < 0.8)
                })
            {
                continue;
            }
            if d < distance {
                distance = d;
                best = Some((i, *anchor));
            }
        }
        let Some((i, anchor)) = best else {
            return Ok(None);
        };
        let s = self.soldier_mut(id).unwrap();
        let route = s.go_to(anchor.position, Goal::Cover, 0)?;
        s.cover.anchor = i as i32;
        s.cover.position = anchor.position;
        s.cover.height = anchor.height;
        if edge {
            s.cover.lean_direction = s.cover.normal.cross(Vector3::Y)
                * if anchor.kind == AnchorKind::EdgeRight {
                    1.0
                } else {
                    -1.0
                };
        }
        s.cover.at_cover = false;
        s.weapon.peek_up = false;
        s.cover.shifting = true;
        Ok(Some(route))
    }
    pub(crate) fn mount_turn(
        &self,
        s: &Infantry,
        gun: Option<MountedGun>,
    ) -> Result<Option<(Vector3, f64)>, &'static str> {
        let Some(st) = self
            .structure(s.emplacement.structure as u32)
            .filter(|st| !st.gone)
        else {
            return Ok(None);
        };
        let (position, degrees): (Vector3, f64) = match st.kind.as_str() {
            "mg_nest" | "hmg_nest" => (
                st.mg_mount_position(gun.ok_or("missing mounted gun geometry")?),
                if st.kind == "mg_nest" { 55.0 } else { 35.0 },
            ),
            "mortar_pit" => (
                st.position + transform(rotation(st.yaw), Vector3::new(0.0, 0.0, 0.75)),
                12.0,
            ),
            "at_post" => (
                st.position + transform(rotation(st.yaw), Vector3::new(0.0, 0.0, -0.4)),
                20.0,
            ),
            _ => return Ok(None),
        };
        Ok(Some((position, degrees.to_radians())))
    }
    fn at_machine_gun(&self, s: &Infantry, gun: Option<MountedGun>) -> Result<bool, &'static str> {
        let Some(st) = self
            .structure(s.emplacement.structure as u32)
            .filter(|st| !st.gone && matches!(st.kind.as_str(), "mg_nest" | "hmg_nest"))
        else {
            return Ok(false);
        };
        let gun = gun.ok_or("missing mounted gun geometry")?;
        Ok(f64::from(flat(s.motion.position - st.mg_mount_position(gun)).length()) < 0.8)
    }
    fn stance_input(
        &self,
        step: WeaponStep,
        squad: Option<&Squad>,
    ) -> Result<StanceInput, &'static str> {
        let s = self.soldier(step.id).ok_or("missing fighting soldier")?;
        if squad.is_some_and(|q| q.id != s.identity.squad) {
            return Err("infantry squad mismatch");
        }
        let st = self.structure(s.emplacement.structure as u32);
        Ok(StanceInput {
            time: step.input.now,
            entity: s.identity.id.into(),
            mode: step.input.mode as u8,
            moving: step.input.moving,
            crawling: s.crawling(step.danger),
            near_cover: s.orders.purpose == Goal::Cover
                && flat(s.orders.goal - s.motion.position).length() < 4.0,
            move_mode: s.orders.move_mode,
            shifting: s.cover.shifting,
            at_cover: s.cover.at_cover,
            cover_kind: s.cover.kind,
            cover_height: s.cover.height,
            mounted: st.is_some(),
            bay: st.is_some_and(|st| st.variant == 1),
            danger: step.danger,
            pinned: step.pinned,
            suppression: s.vitals.suppression,
            hit_dirt_timer: s.vitals.hit_dirt_timer,
            sector: s.fight.sector != Vector3::ZERO,
            machine_gunner: matches!(s.identity.unit.as_str(), "mg_gunner" | "pkm"),
            target_valid: step.target_valid,
            covering: step.covering,
            crew_mount: self.at_machine_gun(s, step.input.gun)?,
            armed: step.input.weapon.is_some(),
            ambush: squad.is_some_and(|q| q.ambush),
            forced_target: self.get(s.fight.forced_target as u32).is_some(),
            yaw: s.motion.yaw,
            threat: s.cover.threat,
            lean_direction: s.cover.lean_direction,
        })
    }
    /// Apply a returned shift request before continuing: it can replace the cover position.
    pub fn begin_infantry_weapon(
        &mut self,
        id: u32,
        input: WeaponInput,
        mut squad: Option<&mut Squad>,
        rng: &mut SimulationRandom,
    ) -> Result<WeaponStep, &'static str> {
        if !input.valid() {
            return Err("invalid infantry firing step");
        }
        let s = self.soldier(id).ok_or("missing fighting soldier")?;
        if squad.as_ref().is_some_and(|q| q.id != s.identity.squad) {
            return Err("infantry squad mismatch");
        }
        self.mount_turn(s, input.gun)?;
        let mut weapon = s.weapon;
        weapon.advance_timers(
            input.dt,
            input.weapon.unwrap_or(Weapon {
                ammunition: 0,
                magazine: 30,
                reload_time: 2.0,
            }),
        )?;
        let mut step = WeaponStep {
            id,
            input,
            pinned: s.vitals.suppression >= squad.as_ref().map_or(60.0, |q| q.pin_at()),
            danger: s.vitals.suppression > 5.0
                || !s.fight.visible_targets.is_empty()
                || squad.as_mut().is_some_and(|q| q.in_combat(input.now)),
            target_valid: self.infantry_target_valid(s.fight.target as u32),
            covering: s.fight.covering_until > input.now
                || squad
                    .as_ref()
                    .is_some_and(|q| q.cover_fire_until > input.now),
            cycled: false,
            cycle: CoverResult::default(),
            reply: CoverReply::default(),
        };
        step.cycled = self.stance_input(step, squad.as_deref())?.cycles_cover();
        if step.cycled {
            step.cycle = weapon.cover_cycle(
                CoverInput {
                    dt: input.dt,
                    time: input.now,
                    team: s.identity.team.into(),
                    suppression: s.vitals.suppression,
                    last_suppression: s.vitals.last_suppression,
                    hit_dirt_timer: s.vitals.hit_dirt_timer,
                    ground: s.motion.ground,
                    cover_kind: s.cover.kind,
                    cover_height: s.cover.height,
                    cover_material: s.cover.material.into(),
                    want_fire: step.target_valid || step.covering,
                    pinned: step.pinned,
                    target_valid: step.target_valid,
                    buddy_up: self.buddy_up(id, input.now, squad.as_deref())?,
                    weapon: input.weapon,
                },
                rng,
            )?;
        }
        let s = self.soldier_mut(id).unwrap();
        s.weapon = weapon;
        if step.cycle.reload_speech.is_some() {
            if s.vitals.speech_cooldown <= 0.0 {
                s.vitals.speech_cooldown = 2.6;
            } else {
                step.cycle.reload_speech = None;
            }
        }
        if step.cycle.call_cover {
            step.reply = self.call_cover(id, squad.as_deref(), rng)?;
        }
        Ok(step)
    }

    pub fn aim_infantry_weapon(
        &mut self,
        step: WeaponStep,
        range: f64,
        squad: Option<&Squad>,
        collision: &mut CollisionWorld,
        visibility: &mut Visibility,
        rng: &mut SimulationRandom,
    ) -> Result<AimResult, &'static str> {
        if !range.is_finite() || !(0.0..=1e6).contains(&range) {
            return Err("invalid infantry weapon range");
        }
        let input = self.stance_input(step, squad)?;
        let mount = self.mount_turn(self.soldier(step.id).unwrap(), step.input.gun)?;
        let s = self.soldier_mut(step.id).unwrap();
        let stance = s.weapon.stance(input, step.cycled)?;
        if stance.face_threat == 1 {
            s.motion.yaw = turn_yaw(
                s.motion.yaw,
                s.cover.threat,
                s.motion.position,
                step.input.dt,
                3.0,
                mount,
            );
        } else if stance.face_threat == 2 {
            s.motion.yaw = immediate_yaw(s.motion.yaw, s.cover.threat);
        }
        s.posture = Posture::try_from(stance.posture)?;
        if !stance.can_aim {
            return Ok(AimResult::default());
        }
        let aim = self.aim_infantry(
            step.id,
            step.input.now,
            range,
            squad,
            collision,
            visibility,
            rng,
        )?;
        let Some(point) = aim.point else {
            return Ok(aim);
        };
        let blocked = AimResult { point: None, ..aim };
        let s = self.soldier(step.id).unwrap();
        let direction = normalized(flat(point - s.motion.position));
        if step.input.mode == Mode::Crew {
            if let Some(st) = self.structure(s.emplacement.structure as u32) {
                if f64::from(normalized(flat(direction)).dot(st.front())) <= libm::cos(1.2 + 0.1) {
                    return Ok(blocked);
                }
            }
        }
        let crew_mount = self.at_machine_gun(s, step.input.gun)?;
        let s = self.soldier_mut(step.id).unwrap();
        if step.input.mode != Mode::Escort
            && !matches!(s.posture, Posture::LeanLeft | Posture::LeanRight)
        {
            if s.weapon.blind
                && s.cover.normal != Vector3::ZERO
                && direction.dot(s.cover.normal) < 0.5
            {
                return Ok(blocked);
            }
            if crew_mount {
                s.motion.yaw = turn_yaw(
                    s.motion.yaw,
                    direction,
                    s.motion.position,
                    step.input.dt,
                    9.0,
                    mount,
                );
                use std::f64::consts::{PI, TAU};
                let difference =
                    libm::atan2(-f64::from(direction.x), -f64::from(direction.z)) - s.motion.yaw;
                let wrapped = difference - TAU * ((difference + PI) / TAU).floor();
                if wrapped.abs() > 0.035 {
                    return Ok(blocked);
                }
            } else {
                s.motion.yaw = immediate_yaw(s.motion.yaw, direction);
            }
        }
        if s.weapon.fire_timer > 0.0 {
            return Ok(blocked);
        }
        Ok(aim)
    }
}
