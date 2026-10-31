//! A retained soldier acquires contacts from the tick's perception snapshot.
use crate::actors::{Actor, Actors};
use crate::collision::CollisionWorld;
use crate::infantry_controller::Task;
use crate::infantry_motion::Neighbor;
use crate::infantry_vitals::Life;
use crate::perception::PerceptionSearch;
use crate::random::SimulationRandom;
use crate::spatial::{SpatialIndex, UNIT_CELL};
use crate::squad::{Contact as SquadContact, Report, Squad};
use crate::targeting::{self, Contact, DroneContact, Observer, Scan, TargetKind};
use crate::vehicle::Vehicle;
use crate::visibility::Visibility;

#[derive(Clone, Copy, Debug)]
pub struct ScanProfile {
    pub bearer: bool,
    pub weapon_range: f64,
    pub armor_piercing: bool,
}

impl ScanProfile {
    fn valid(self) -> bool {
        self.weapon_range.is_finite() && (0.0..=1e6).contains(&self.weapon_range)
    }
}

impl Actors {
    /// Each thought refreshes separation; a retained target permits every other sight scan.
    pub fn perceive_infantry(
        &mut self,
        id: u32,
        now: f64,
        profile: ScanProfile,
        mut squad: Option<&mut Squad>,
        units: &SpatialIndex,
        search: &PerceptionSearch,
        collision: &mut CollisionWorld,
        visibility: &mut Visibility,
        armor: impl Fn(&Vehicle) -> i32,
        rng: &mut SimulationRandom,
    ) -> Result<Option<Scan>, &'static str> {
        let s = self.soldier(id).ok_or("missing thinking soldier")?;
        if !now.is_finite()
            || now.abs() > 1e12
            || !profile.valid()
            || units.cell_size() != UNIT_CELL
            || squad.as_ref().is_some_and(|q| q.id != s.identity.squad)
        {
            return Err("invalid infantry perception context");
        }
        let mut clock = s.controller;
        let due = clock.scan_due(self.get(s.fight.target as u32).is_some())?;
        let active = s.vitals.life == Life::Alive
            && s.links.dragged_by == 0
            && !matches!(s.duty.kind, Task::Stretcher | Task::Captor);
        let neighbors: Vec<_> = if active {
            self.units_near(units, s.motion.position, 0.85, -1)?
                .into_iter()
                .filter_map(|id| self.soldier(id))
                .map(|s| Neighbor {
                    id: s.identity.id.into(),
                    position: s.motion.position,
                    life: s.vitals.life,
                })
                .collect()
        } else {
            Vec::new()
        };
        let scan = if due {
            let scan =
                self.scan_infantry(id, now, profile, search, collision, visibility, armor)?;
            if let Some(q) = squad.as_mut() {
                for &who in scan.visible.iter().take(scan.reported) {
                    if let Some(actor) = self.get(who as u32) {
                        q.report(SquadContact {
                            id: who as u32,
                            report: Report {
                                position: actor.position(),
                                time: now,
                            },
                        })?;
                    }
                }
            }
            Some(scan)
        } else {
            None
        };
        let s = self.soldier_mut(id).unwrap();
        s.compute_separation(&neighbors, rng)?;
        s.controller = clock;
        Ok(scan)
    }

    pub fn scan_infantry(
        &mut self,
        id: u32,
        now: f64,
        profile: ScanProfile,
        search: &PerceptionSearch,
        collision: &mut CollisionWorld,
        visibility: &mut Visibility,
        armor: impl Fn(&Vehicle) -> i32,
    ) -> Result<Scan, &'static str> {
        if !now.is_finite() || now.abs() > 1e12 || !profile.valid() {
            return Err("invalid infantry scan profile");
        }
        let s = self.soldier(id).ok_or("missing scanning soldier")?;
        if profile.bearer {
            let s = self.soldier_mut(id).unwrap();
            s.fight.visible_targets.clear();
            s.fight.target = 0;
            return Ok(Scan::default());
        }
        let mount = self.structure(s.emplacement.structure as u32);
        let range = if mount.is_some_and(|m| m.kind == "watchtower") && s.duty.phase == 2 {
            75.0
        } else {
            56.0
        };
        let mut contacts = Vec::with_capacity(7);
        for candidate in search.nearest_owned(
            s.motion.position.x.into(),
            s.motion.position.z.into(),
            s.identity.team,
            range,
        ) {
            let contact = match self.get(candidate) {
                Some(Actor::Soldier(other))
                    if matches!(other.vitals.life, Life::Alive | Life::Downed)
                        && !(other.vitals.life == Life::Downed
                            && now - other.weapon.last_shot > 2.0) =>
                {
                    Contact {
                        id: candidate.into(),
                        position: other.motion.position,
                        kind: TargetKind::Infantry {
                            downed: other.vitals.life == Life::Downed,
                            machine_gunner: matches!(
                                other.identity.unit.as_str(),
                                "mg_gunner" | "pkm"
                            ),
                        },
                        points: self
                            .infantry_pose(candidate)
                            .unwrap()
                            .exposed_points()
                            .as_slice()
                            .to_vec(),
                        excluded: Vec::new(),
                    }
                }
                Some(Actor::Vehicle(v)) => Contact {
                    id: candidate.into(),
                    position: v.position,
                    kind: TargetKind::Vehicle { armor: armor(v) },
                    points: v.exposed_points().to_vec(),
                    excluded: vec![candidate.into()],
                },
                _ => continue,
            };
            contacts.push(contact);
        }
        let drones: Vec<_> = self
            .iter_kind(crate::entities::Kind::Drone)
            .filter_map(|actor| match actor {
                Actor::Drone(d) => Some(DroneContact {
                    id: d.id.into(),
                    team: d.team.into(),
                    position: d.flight.position,
                    dead: d.flight.dead,
                    diving: d.flight.diving,
                }),
                _ => None,
            })
            .collect();
        let forced = self.get(s.fight.forced_target as u32);
        let observer = Observer {
            position: s.motion.position,
            eye: self.infantry_pose(id).unwrap().scan_eye(),
            team: s.identity.team.into(),
            current: s.fight.target,
            forced: if forced.is_some() {
                s.fight.forced_target
            } else {
                0
            },
            forced_structure: match forced {
                Some(Actor::Structure(st)) => Some(st.position),
                _ => None,
            },
            weapon_range: profile.weapon_range,
            rockets: s.arsenal.rockets > 0,
            armor_piercing: profile.armor_piercing,
            mount_forward: mount
                .filter(|m| {
                    s.duty.kind == Task::Man
                        && s.duty.phase == 2
                        && matches!(m.kind.as_str(), "mg_nest" | "hmg_nest")
                })
                .map(|m| m.front()),
            cache_obstruction: s.orders.pending_path || !s.is_moving(),
        };
        let result = targeting::scan(observer, &contacts, &drones, collision, visibility)?;
        let s = self.soldier_mut(id).unwrap();
        s.fight.target = result.target;
        s.fight.visible_targets.clone_from(&result.visible);
        Ok(result)
    }
}
