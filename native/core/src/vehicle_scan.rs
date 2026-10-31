//! Vehicle crews choose contacts from owned actors, collision and smoke in spatial order.
use crate::actors::{Actor, Actors};
use crate::collision::CollisionWorld;
use crate::infantry_pose::InfantryPose;
use crate::infantry_vitals::Life;
use crate::spatial::{SpatialIndex, STRUCTURE_CELL, UNIT_CELL};
use crate::vector::Vector3;
use crate::vehicle::Vehicle;
use crate::visibility::{Sight, Visibility};

#[derive(Clone, Copy, Debug)]
pub struct ScanProfile {
    pub sight: f64,
    pub gun_height: f64,
    pub cannon: bool,
    pub gunship: bool,
    pub anti_air: bool,
    pub penetrating_mg: bool,
}
impl ScanProfile {
    pub fn valid(self) -> bool {
        self.sight.is_finite()
            && (0.0..=4096.0).contains(&self.sight)
            && self.gun_height.is_finite()
            && (0.0..=1000.0).contains(&self.gun_height)
    }
}
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Scan {
    pub target: u32,
    pub reports: Vec<u32>,
    pub reused_obstructions: u32,
}
fn flat(p: Vector3) -> Vector3 {
    Vector3::new(p.x, 0.0, p.z)
}
impl Vehicle {
    pub fn turret_position(&self, height: f64, gunship: bool) -> Vector3 {
        let turret = self.position + Vector3::Y * height as f32;
        if gunship {
            turret
                + Vector3::new(
                    -libm::sin(self.yaw) as f32,
                    0.0,
                    -libm::cos(self.yaw) as f32,
                ) * 2.3
        } else {
            turret
        }
    }
}
impl Actors {
    pub fn infantry_pose(&self, id: u32) -> Option<InfantryPose> {
        let s = self.soldier(id)?;
        let mount = self.structure(s.emplacement.structure as u32);
        let gun = mount.is_some_and(|m| matches!(m.kind.as_str(), "mg_nest" | "hmg_nest"));
        Some(InfantryPose {
            position: s.motion.position,
            posture: s.posture,
            life: s.vitals.life,
            at_cover: s.cover.at_cover,
            cover_kind: s.cover.kind,
            cover_height: s.cover.height,
            cover_normal: s.cover.normal,
            lean_direction: s.cover.lean_direction,
            mounted: mount.is_some(),
            gun_mount: gun,
            tower_mount: gun && mount.is_some_and(|m| m.variant == 1),
            peek_up: s.weapon.peek_up,
            blind: s.weapon.blind,
            moving: s.is_moving(),
            move_mode: s.orders.move_mode.into(),
            ground: s.motion.ground,
        })
    }
    pub fn scan_vehicle(
        &mut self,
        id: u32,
        p: ScanProfile,
        units: &SpatialIndex,
        structures: &SpatialIndex,
        collision: &mut CollisionWorld,
        visibility: &mut Visibility,
        helicopter: impl Fn(&Vehicle) -> bool,
        player_building: impl Fn(&str) -> bool,
    ) -> Result<Scan, &'static str> {
        if !p.valid() || units.cell_size() != UNIT_CELL || structures.cell_size() != STRUCTURE_CELL
        {
            return Err("invalid vehicle scan profile or grid");
        }
        let v = self.vehicle(id).ok_or("missing scanning vehicle")?;
        let eye = v.turret_position(p.gun_height, p.gunship);
        let candidates = self.units_near(units, v.position, 72.0_f64.max(p.sight + 20.0), -1)?;
        let mut result = Scan {
            target: 0,
            reports: Vec::new(),
            reused_obstructions: 0,
        };
        let mut best_score = -1e9;
        for candidate in candidates {
            let (position, team, priority) = match self.get(candidate) {
                Some(Actor::Soldier(s)) if s.vitals.life == Life::Alive => (
                    s.motion.position,
                    s.identity.team,
                    if s.arsenal.rockets > 0 { 75.0 } else { 50.0 },
                ),
                Some(Actor::Vehicle(other)) => {
                    let priority = if helicopter(other) && other.position.y > 3.0 {
                        if p.anti_air || v.sam_left > 0 {
                            160.0
                        } else if p.penetrating_mg {
                            20.0
                        } else {
                            continue;
                        }
                    } else if p.cannon {
                        110.0
                    } else if p.gunship {
                        70.0
                    } else {
                        40.0
                    };
                    (other.position, other.team, priority)
                }
                _ => continue,
            };
            if team < 0 || team == v.team {
                continue;
            }
            let mut score = priority - f64::from(flat(position - v.position).length());
            if candidate == v.target {
                score += 8.0;
            }
            if score <= best_score {
                continue;
            }
            let sight = if let Some(other) = self.vehicle(candidate) {
                visibility.can_see(
                    collision,
                    eye,
                    candidate.into(),
                    &other.exposed_points(),
                    &[id.into(), candidate.into()],
                    true,
                )
            } else {
                let pose = self.infantry_pose(candidate).unwrap();
                visibility.can_see(
                    collision,
                    eye,
                    candidate.into(),
                    pose.exposed_points().as_slice(),
                    &[id.into()],
                    true,
                )
            }
            .ok_or("invalid vehicle sight geometry")?;
            match sight {
                Sight::Visible => {
                    best_score = score;
                    result.target = candidate;
                }
                Sight::ReusedObstruction => result.reused_obstructions += 1,
                Sight::Hidden => (),
            }
        }
        if result.target == 0 && p.cannon {
            for candidate in self.structures_near(structures, v.position, 55.0, false)? {
                let st = self.structure(candidate).unwrap();
                if st.team < 0
                    || st.team == v.team
                    || !player_building(&st.kind)
                    || matches!(
                        st.kind.as_str(),
                        "mines"
                            | "wire"
                            | "tank_trap"
                            | "trench"
                            | "camo_net"
                            | "hesco"
                            | "barricade"
                    )
                    || v.team < 0
                    || (st.visible >> v.team) & 1 == 0
                {
                    continue;
                }
                // Buildings use their own first-hit test, including the firing hull, without smoke.
                if collision
                    .ray(eye, st.position + Vector3::Y, &[])
                    .is_none_or(|hit| hit.body == i64::from(candidate))
                {
                    result.target = candidate;
                    break;
                }
            }
        }
        if let Some(forced) = self.get(v.forced_target) {
            let position = match forced {
                Actor::Soldier(s) => s.motion.position,
                Actor::Vehicle(v) => v.position,
                Actor::Structure(s) => s.position,
                Actor::Projectile(p) => p.motion.position(),
                Actor::Drone(d) => d.flight.position,
            };
            if flat(position - v.position).length() < 75.0 {
                result.target = v.forced_target;
            }
        }
        for observer in self.units_near(units, v.position, 30.0, -1)? {
            if let Some(s) = self.soldier(observer) {
                if s.identity.team != v.team
                    && s.identity.team >= 0
                    && s.identity.squad != 0
                    && s.vitals.life == Life::Alive
                {
                    result.reports.push(s.identity.squad);
                }
            }
        }
        self.vehicle_mut(id).unwrap().target = result.target;
        Ok(result)
    }
}
