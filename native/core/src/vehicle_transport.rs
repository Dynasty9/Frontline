//! Passenger exits update both actor kinds before the squad receives its next order.
use crate::actors::{Actor, Actors};
use crate::infantry_vitals::Life;
use crate::path_planner::PathPlanner;
use crate::spatial::SpatialIndex;
use crate::vector::{normalized, Vector3};
use std::collections::HashSet;

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Dismount {
    pub squad: u32,
    pub position: Vector3,
    pub forward: Vector3,
    pub assault: bool,
}
fn flat(p: Vector3) -> Vector3 {
    Vector3::new(p.x, 0.0, p.z)
}
fn direction(yaw: f64) -> Vector3 {
    Vector3::new(-libm::sin(yaw) as f32, 0.0, -libm::cos(yaw) as f32)
}
fn shore(position: Vector3, nav: &PathPlanner) -> Option<Vector3> {
    nav.nearest_walkable(position)
        .filter(|p| flat(*p - position).length() < 15.0)
}
impl Actors {
    pub fn dismount(
        &mut self,
        vehicle: u32,
        boat: bool,
        nav: &PathPlanner,
    ) -> Result<Option<Dismount>, &'static str> {
        let v = self.vehicle(vehicle).ok_or("missing transport")?;
        if v.passengers.is_empty() {
            return Ok(None);
        }
        let forward = direction(v.yaw);
        let mut back = -forward;
        let bank = if boat {
            let Some(bank) = shore(v.position, nav) else {
                return Ok(None);
            };
            back = normalized(flat(bank - v.position));
            Some(bank)
        } else {
            None
        };
        let side = back.cross(Vector3::Y);
        let mut exits = Vec::new();
        let mut seen = HashSet::new();
        let mut squad = 0;
        for &id in &v.passengers {
            let Some(s) = self.soldier(id) else {
                continue;
            };
            if s.identity.gone || s.vitals.life != Life::Hidden || !seen.insert(id) {
                continue;
            }
            let offset = (exits.len() as f64 - 1.5) as f32;
            let at = if let Some(bank) = bank {
                nav.nearest_walkable(bank + side * offset * 1.3)
                    .ok_or("invalid shore exit")?
            } else {
                v.position + back * 3.6 + side * offset * 1.3
            };
            if !s.valid() || !at.is_finite() || at.abs().max_element() > 1_000_000.0 {
                return Err("invalid passenger exit");
            }
            exits.push((id, at));
            squad = s.identity.squad;
        }
        let assault = (v.assault || boat) && v.assault_destination.is_some();
        let order = Dismount {
            squad,
            forward,
            assault,
            position: if assault {
                v.assault_destination.unwrap()
            } else {
                v.position + forward * 8.0
            },
        };
        if !order.position.is_finite() || order.position.abs().max_element() > 1_000_000.0 {
            return Err("invalid dismount order");
        }
        for (id, at) in exits {
            let s = self.soldier_mut(id).unwrap();
            s.links.vehicle = 0;
            // The preflight above makes each exit infallible before changing shared state.
            s.unhide(at, nav)?;
        }
        self.vehicle_mut(vehicle).unwrap().passengers.clear();
        Ok(Some(order))
    }
    pub fn dismount_due(
        &mut self,
        vehicle: u32,
        dt: f64,
        lift: bool,
        boat: bool,
        nav: &PathPlanner,
        units: &SpatialIndex,
    ) -> Result<bool, &'static str> {
        if !dt.is_finite() || !(0.0..=3600.0).contains(&dt) {
            return Err("invalid dismount step");
        }
        let v = self.vehicle(vehicle).ok_or("missing transport")?;
        if v.passengers.is_empty() || lift {
            return Ok(false);
        }
        let timer = v.dismount_timer - dt;
        if timer > 0.0 {
            self.vehicle_mut(vehicle).unwrap().dismount_timer = timer;
            return Ok(false);
        }
        let due = if boat {
            v.landing
                && v.path_index as usize >= v.path.len()
                && v.speed.abs() < 0.8
                && shore(v.position, nav).is_some()
        } else {
            let mut close = false;
            if v.assault {
                for id in self.units_near(units, v.position, 70.0, -1)? {
                    let (team, visible, alive) = match self.get(id) {
                        Some(Actor::Soldier(s)) => (
                            s.identity.team,
                            s.identity.visible,
                            s.vitals.life == Life::Alive,
                        ),
                        Some(Actor::Vehicle(v)) => (v.team, v.visible, true),
                        _ => continue,
                    };
                    if team >= 0
                        && team != v.team
                        && (v.team < 0 || visible & (1 << v.team) != 0)
                        && alive
                    {
                        close = true;
                        break;
                    }
                }
            }
            (v.path_index as usize >= v.path.len() && v.speed < 0.6)
                || close
                || v.hp < v.max_hp * 0.4
        };
        let v = self.vehicle_mut(vehicle).unwrap();
        v.dismount_timer = 0.5;
        if boat && due {
            v.landing = false;
        }
        Ok(due)
    }
}
