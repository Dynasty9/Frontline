//! Passenger exits update both actor kinds before the squad receives its next order.
use crate::actors::{Actor, Actors};
use crate::attack_plan::{AttackPlan, Event};
use crate::infantry_vitals::Life;
use crate::path_planner::PathPlanner;
use crate::spatial::SpatialIndex;
use crate::squad_movement::Context;
use crate::vector::{normalized, Vector3};
use crate::visibility::Visibility;
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
fn shore(
    position: Vector3,
    nav: &PathPlanner,
    ground: crate::traversal::Ground<'_>,
) -> Option<Vector3> {
    nav.nearest_walkable(position, ground)
        .filter(|p| flat(*p - position).length() < 15.0)
}
impl Context<'_> {
    /// Exiting a transport immediately restores the section's defense or deliberate attack.
    pub fn dismount_vehicle(
        &mut self,
        vehicle: u32,
        boat: bool,
        plan_id: u32,
        visibility: &Visibility,
    ) -> Result<(Option<AttackPlan>, Vec<Event>), &'static str> {
        if plan_id == 0 || !self.now.is_finite() || self.now.abs() > 1e12 - 100.0 {
            return Err("invalid transport squad context");
        }
        let team = self
            .actors
            .vehicle(vehicle)
            .ok_or("missing transport")?
            .team;
        // Validate the destination squad before any passenger leaves the vehicle.
        for &id in &self.actors.vehicle(vehicle).unwrap().passengers {
            if let Some(s) = self.actors.soldier(id) {
                if s.vitals.life == Life::Hidden && s.identity.squad != 0 {
                    self.index(s.identity.squad)?;
                }
            }
        }
        let Some(order) = self.actors.dismount(
            vehicle,
            boat,
            &self.geometry.navigation.planner,
            crate::traversal::Ground::new(&self.geometry.terrain, &self.geometry.deck),
        )?
        else {
            return Ok((None, vec![]));
        };
        let mut out = vec![Event::Stat("dismount")];
        if order.squad == 0 {
            return Ok((None, out));
        }
        let i = self.index(order.squad)?;
        let mut movement = vec![];
        let leader = self.leader(i, &mut movement);
        out.extend(movement.into_iter().map(Event::Squad));
        if leader != 0 {
            self.actors
                .soldier_mut(leader)
                .unwrap()
                .vitals
                .speech_cooldown = 2.6;
            out.push(Event::Speech {
                soldier: leader,
                text: if team == 0 {
                    "Dismount! Go, go, go!"
                } else {
                    "Out! Everybody out!"
                }
                .into(),
            });
        }
        let plan = if order.assault {
            let (plan, events) = self.order_assault(
                order.squad,
                order.position,
                order.forward,
                plan_id,
                visibility,
            )?;
            out.extend(events);
            plan
        } else {
            out.extend(
                self.order_defend(order.squad, order.position, order.forward, false)?
                    .into_iter()
                    .map(Event::Squad),
            );
            None
        };
        Ok((plan, out))
    }
}
impl Actors {
    pub fn dismount(
        &mut self,
        vehicle: u32,
        boat: bool,
        nav: &PathPlanner,
        ground: crate::traversal::Ground<'_>,
    ) -> Result<Option<Dismount>, &'static str> {
        if !ground.valid_for(nav.side()) {
            return Err("invalid navigation ground");
        }

        let v = self.vehicle(vehicle).ok_or("missing transport")?;
        if v.passengers.is_empty() {
            return Ok(None);
        }
        let forward = direction(v.yaw);
        let mut back = -forward;
        let bank = if boat {
            let Some(bank) = shore(v.position, nav, ground) else {
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
                nav.nearest_walkable(bank + side * offset * 1.3, ground)
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
            s.unhide(at, nav, ground)?;
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
        ground: crate::traversal::Ground<'_>,
    ) -> Result<bool, &'static str> {
        if !ground.valid_for(nav.side()) {
            return Err("invalid navigation ground");
        }

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
                && shore(v.position, nav, ground).is_some()
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
