//! Crews and drivers use shared contacts; movement changes cover before the next actor acts.
use crate::actors::Actor;
use crate::entities::Kind;
use crate::infantry_vitals::Life;
use crate::squad::{Contact as SquadContact, Report};
use crate::structure::Structure;
use crate::vector::Vector3;
use crate::vehicle::{Route, Vehicle};
use crate::vehicle_brain::{Contact, CrewEvent, CrewProfile, Perception, UnitKind};
use crate::vehicle_loss_world::Event as Loss;
use crate::vehicle_motion::{GroundProfile, Traffic};
use crate::vehicle_scan::{Scan, ScanProfile};
use crate::world::WorldContext;
use glam::Vec2;

#[derive(Clone, Debug, PartialEq)]
pub enum Event {
    Crew {
        vehicle: u32,
        event: CrewEvent,
    },
    Track(u32),
    Smashed {
        structure: Box<Structure>,
        tree_yaw: Option<f64>,
    },
    Loss(Loss),
    Stat(&'static str),
}
fn flat(v: Vector3) -> Vector3 {
    Vector3::new(v.x, 0.0, v.z)
}
fn direction(yaw: f64) -> Vector3 {
    Vector3::new(-libm::sin(yaw) as f32, 0.0, -libm::cos(yaw) as f32)
}
pub fn overlaps(position: Vector3, half: Vec2, yaw: f64, st: &Structure, inset: f32) -> bool {
    fn axes(yaw: f64) -> [Vec2; 2] {
        let c = libm::cos(yaw) as f32;
        let s = libm::sin(yaw) as f32;
        [Vec2::new(c, -s), Vec2::new(s, c)]
    }
    let a = axes(yaw);
    let b = axes(st.yaw);
    let half = half - Vec2::splat(inset);
    let other = Vec2::from_array(st.footprint) - Vec2::splat(inset);
    let d = Vec2::new(st.position.x - position.x, st.position.z - position.z);
    [a[0], a[1], b[0], b[1]].into_iter().all(|axis| {
        let p = f64::from(half.x) * f64::from(a[0].dot(axis)).abs()
            + f64::from(half.y) * f64::from(a[1].dot(axis)).abs();
        let q = f64::from(other.x) * f64::from(b[0].dot(axis)).abs()
            + f64::from(other.y) * f64::from(b[1].dot(axis)).abs();
        f64::from(d.dot(axis)).abs() <= p + q
    })
}
impl WorldContext<'_> {
    pub(crate) fn vehicle_traffic(&self) -> Vec<Traffic> {
        // Vehicles use registration order for traffic ties, independently of infantry buckets.
        self.actors
            .iter_kind(Kind::Vehicle)
            .filter_map(|a| {
                let Actor::Vehicle(v) = a else {
                    return None;
                };
                let p = (self.vehicle)(v);
                Some(Traffic {
                    id: v.id,
                    position: v.position,
                    yaw: v.yaw,
                    speed: v.speed,
                    hull: p.hull,
                    air: p.crew.helicopter && v.position.y > 3.0,
                })
            })
            .collect()
    }
    pub fn scan_vehicle_world(
        &mut self,
        id: u32,
        profile: ScanProfile,
    ) -> Result<Scan, &'static str> {
        if !crate::infantry_fight_world::valid_step(0.0, self.now, None) {
            return Err("invalid vehicle scan time");
        }
        let scan = self.actors.scan_vehicle(
            id,
            profile,
            self.units,
            &self.geometry.structures,
            &mut crate::collision::RayScene {
                boxes: &mut self.geometry.collision,
                ground: crate::traversal::Ground::new(&self.geometry.terrain, &self.geometry.deck),
            },
            self.visibility,
            |v| (self.vehicle)(v).crew.helicopter,
            self.player_building,
        )?;
        let position = self.actors.vehicle(id).unwrap().position;
        for &sid in &scan.reports {
            if let Some(q) = self.squads.iter_mut().find(|q| q.id == sid) {
                q.report(SquadContact {
                    id,
                    report: Report {
                        position,
                        time: self.now,
                    },
                })?;
            }
        }
        Ok(scan)
    }

    fn vehicle_route(&mut self, id: u32, route: Route) -> Result<(), &'static str> {
        if let Route::Ground {
            destination,
            care,
            revision,
        } = route
        {
            self.geometry.navigation.submit_vehicle(
                self.actors.vehicle_mut(id).unwrap(),
                destination,
                care,
                revision,
                crate::traversal::Ground::new(&self.geometry.terrain, &self.geometry.deck),
            )?;
        }
        Ok(())
    }

    fn crew_contacts(
        &self,
        team: i8,
        position: Vector3,
        radius: f64,
        cannon: &dyn Fn(&Vehicle) -> bool,
    ) -> Result<Vec<Contact>, &'static str> {
        Ok(self
            .actors
            .units_near(self.units, position, radius, -1)?
            .into_iter()
            .filter_map(|id| {
                let (position, other, visible, kind) = match self.actors.get(id)? {
                    Actor::Soldier(s) => (
                        s.motion.position,
                        s.identity.team,
                        s.identity.visible,
                        UnitKind::Soldier {
                            alive: s.vitals.life == Life::Alive,
                            rockets: s.arsenal.rockets,
                            antitank: matches!(s.identity.unit.as_str(), "at_soldier" | "rpg"),
                            riding: s.links.vehicle != 0,
                        },
                    ),
                    Actor::Vehicle(v) => (
                        v.position,
                        v.team,
                        v.visible,
                        UnitKind::Vehicle {
                            air: (self.vehicle)(v).crew.helicopter && v.position.y > 3.0,
                            cannon: cannon(v),
                            missiles: v.atgm_left,
                        },
                    ),
                    _ => return None,
                };
                Some(Contact {
                    id,
                    position,
                    team: other,
                    visible: team < 0 || visible & (1 << team) != 0,
                    gone: false,
                    kind,
                })
            })
            .collect())
    }

    pub fn think_vehicle_world(
        &mut self,
        id: u32,
        profile: CrewProfile<'_>,
        mission: bool,
        cannon: &dyn Fn(&Vehicle) -> bool,
    ) -> Result<Vec<Event>, &'static str> {
        if !crate::infantry_fight_world::valid_step(0.0, self.now, None) {
            return Err("invalid crew time");
        }
        let v = self.actors.vehicle(id).ok_or("missing thinking vehicle")?;
        if !profile.applies(v) {
            return Ok(vec![]);
        }
        let (team, position, forward) = (v.team, v.position, direction(v.yaw));
        let fob = self
            .actors
            .nearest_fob(team, position)
            .map(|st| (st.id, st.position));
        let threats = if profile.tracked && profile.armor >= 2 {
            self.crew_contacts(team, position, 120.0, cannon)?
        } else {
            vec![]
        };
        let waits = v.owner < 0
            && v.assault
            && (v.path_index as usize) < v.path.len()
            && self.now
                >= v.cooldowns
                    .iter()
                    .find(|v| v.0 == "push_on")
                    .map_or(-1.0, |v| v.1);
        let ahead = if waits {
            self.crew_contacts(team, position + forward * 30.0, 45.0, cannon)?
        } else {
            vec![]
        };
        let support = if waits {
            self.crew_contacts(team, position, 35.0, cannon)?
        } else {
            vec![]
        };
        let result = self.actors.vehicle_mut(id).unwrap().crew_think(
            self.now,
            profile,
            Perception {
                threats: &threats,
                ahead: &ahead,
                support: &support,
                fob,
                mission,
            },
            &self.geometry.navigation.planner,
            crate::traversal::Ground::new(&self.geometry.terrain, &self.geometry.deck),
        )?;
        self.vehicle_route(id, result.route)?;
        let mut out = vec![];
        if result.repaired_track {
            out.push(Event::Track(id));
        }
        if let Some(event) = result.event {
            out.push(Event::Stat(match event {
                CrewEvent::Withdraw(_) => "veh_withdraw",
                CrewEvent::PatchedUp => "veh_patched_up",
                CrewEvent::WaitInfantry => "veh_wait_infantry",
                CrewEvent::Evade => "veh_evade",
            }));
            out.push(Event::Crew { vehicle: id, event });
        }
        Ok(out)
    }

    pub fn drive_vehicle_world(
        &mut self,
        id: u32,
        dt: f64,
        profile: GroundProfile,
    ) -> Result<Vec<Event>, &'static str> {
        if !crate::infantry_fight_world::valid_step(dt, self.now, None) {
            return Err("invalid driving time");
        }
        let v = self.actors.vehicle(id).ok_or("missing driving vehicle")?;
        let target = self
            .actors
            .get(v.target)
            .filter(|_| self.actors.vehicle_target_valid(v.target))
            .map(|a| {
                let p = a.position();
                let trench = matches!(a, Actor::Soldier(_))
                    && self.geometry.terrain.layers[crate::terrain::TRENCH]
                        [self.geometry.terrain.index(p)]
                        > 0;
                (p, trench)
            });
        let traffic = self.vehicle_traffic();
        let result = self.actors.vehicle_mut(id).unwrap().drive_ground(
            dt,
            profile,
            target,
            &self.geometry.navigation.planner,
            &self.geometry.terrain,
            &traffic,
            self.rng,
            &self.geometry.deck,
        )?;
        self.vehicle_route(id, result.route)?;
        let v = self.actors.vehicle(id).unwrap();
        let position = v.position;
        let forward = direction(v.yaw);
        self.geometry.refresh_vehicle_collision(v, profile.hull)?;
        if result.shove {
            let side = forward.cross(Vector3::Y);
            for sid in self
                .actors
                .units_near(self.units, position + forward * 2.5, 2.6, -1)?
            {
                let Some(s) = self.actors.soldier_mut(sid) else {
                    continue;
                };
                if s.vitals.life == Life::Hidden || s.shock.flinging {
                    continue;
                }
                let push = flat(s.motion.position - position);
                let direction = if push.dot(side) > 0.0 { side } else { -side };
                let next = s.motion.position + direction * 3.0 * dt as f32;
                if self.geometry.navigation.planner.kind_at(next, false) != 3 {
                    s.motion.position = next;
                }
            }
        }
        Ok(if result.unstuck {
            vec![Event::Stat("veh_unstick")]
        } else {
            vec![]
        })
    }

    pub fn smash_vehicle_world(
        &mut self,
        id: u32,
        light: bool,
        armor: u8,
    ) -> Result<Vec<Event>, &'static str> {
        if armor > 16 {
            return Err("invalid smashing armor");
        }
        let v = self.actors.vehicle(id).ok_or("missing smashing vehicle")?;
        let profile = (self.vehicle)(v);
        if v.speed < 0.5 && profile.weight < 2 {
            return Ok(vec![]);
        }
        let (position, yaw, team) = (v.position, v.yaw, v.team);
        let half = Vec2::new(
            profile.hull.x * 0.5,
            (f64::from(profile.hull.z) * 0.5 + 0.3) as f32,
        );
        let mut out = vec![];
        for sid in self
            .actors
            .structures_near(&self.geometry.structures, position, 5.0, false)?
        {
            let Some(st) = self.actors.structure(sid) else {
                continue;
            };
            if !st.smashable
                || (st.team == team && (self.player_building)(&st.kind))
                || (light
                    && matches!(
                        st.kind.as_str(),
                        "tall_wall" | "house_wall" | "concrete_wall"
                    ))
                || !overlaps(position, half, yaw, st, 0.0)
            {
                continue;
            }
            let tree_yaw = (st.kind == "tree").then(|| {
                let p = flat(st.position - position);
                libm::atan2(-f64::from(p.x), -f64::from(p.z))
            });
            let Actor::Structure(mut st) = self.actors.remove(sid).unwrap() else {
                unreachable!();
            };
            st.gone = true;
            self.geometry.retire_structure(&mut st, self.actors)?;
            out.push(Event::Smashed {
                structure: st,
                tree_yaw,
            });
            out.push(Event::Stat("smash"));
            if light && armor == 0 && self.actors.vehicle(id).is_some() {
                out.extend(self.damage(id, 15.0, 0)?.into_iter().map(Event::Loss));
            }
        }
        Ok(out)
    }
}
