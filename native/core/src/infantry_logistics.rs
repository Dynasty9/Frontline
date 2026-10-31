//! Ammunition searches transfer shared stock and retain the resulting route and duty.
use crate::actors::{Actor, Actors};
use crate::infantry::Goal;
use crate::infantry_commands::Command;
use crate::infantry_controller::Task;
use crate::infantry_orders::RouteOrder;
use crate::infantry_supply::{self, Body, Cache, Depot, Search};
use crate::infantry_travel;
use crate::infantry_vitals::Life;
use crate::infantry_weapon::Weapon;
use crate::path_planner::PathPlanner;
use crate::random::SimulationRandom;
use crate::spatial::{SpatialIndex, STRUCTURE_CELL, UNIT_CELL};
use crate::vector::Vector3;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Scavenged {
    pub body: u32,
    pub rounds: i32,
    pub speech: Option<u8>,
    pub reload_speech: Option<u8>,
}
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum SupplySource {
    Body,
    Cache,
    Fob,
}
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct SupplyOrder {
    pub source: SupplySource,
    pub entity: u32,
    pub route: RouteOrder,
}

#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct SupplyCollected {
    pub missing: bool,
    pub spoke: bool,
    pub returned: bool,
    pub rounds: i32,
    pub route: Option<RouteOrder>,
}
fn flat(p: Vector3) -> Vector3 {
    Vector3::new(p.x, 0.0, p.z)
}
fn clock(now: f64) -> bool {
    now.is_finite() && now.abs() <= 1e12 - 10.0
}

impl Actors {
    /// Movement has stopped; collect shared stock before returning to the hold position.
    pub fn arrive_infantry_supply(
        &mut self,
        id: u32,
        capacity: i32,
        nav: &PathPlanner,
    ) -> Result<SupplyCollected, &'static str> {
        if !(0..=1_000_000).contains(&capacity) {
            return Err("invalid infantry supply capacity");
        }
        let s = self.soldier(id).ok_or("missing resupplying soldier")?;
        let target = s.duty.entity as u32;
        if self.get(target).is_none() {
            self.soldier_mut(id).unwrap().duty.kind = Task::Fight;
            return Ok(SupplyCollected {
                missing: true,
                ..Default::default()
            });
        }
        let body = self.soldier(target);
        let arrived = infantry_travel::supply_arrival(
            capacity,
            s.weapon.magazine,
            s.weapon.reserve,
            body.map(|b| b.fight.loot),
        )?;
        let loot = body.map(|b| b.fight.loot - arrived.rounds);
        if loot.is_some_and(|n| !(0..=1_000_000).contains(&n))
            || !(0..=1_000_000).contains(&(s.weapon.reserve + arrived.rounds))
        {
            return Err("infantry supply transfer exceeds stock limits");
        }
        let mut next = s.clone();
        next.activity = 0;
        next.weapon.reserve += arrived.rounds;
        let spoke = arrived.announce && next.vitals.speech_cooldown <= 0.0;
        if spoke {
            next.vitals.speech_cooldown = 2.6;
        }
        let route = if arrived.return_to_hold {
            next.command(Command::ReturnToHold, nav, None)?.route
        } else {
            None
        };
        if let Some(loot) = loot {
            if target == id {
                next.fight.loot = loot;
            } else {
                self.soldier_mut(target).unwrap().fight.loot = loot;
            }
        }
        *self.soldier_mut(id).unwrap() = next;
        Ok(SupplyCollected {
            missing: false,
            spoke,
            returned: arrived.return_to_hold,
            rounds: arrived.rounds,
            route,
        })
    }
    pub fn scavenge_infantry(
        &mut self,
        id: u32,
        now: f64,
        stock: Option<(i32, Weapon)>,
        units: &SpatialIndex,
        rng: &mut SimulationRandom,
    ) -> Result<Option<Scavenged>, &'static str> {
        if !clock(now)
            || units.cell_size() != UNIT_CELL
            || stock.is_some_and(|(capacity, w)| !(0..=1_000_000).contains(&capacity) || !w.valid())
        {
            return Err("invalid retained scavenging input");
        }
        let s = self.soldier(id).ok_or("missing scavenging soldier")?;
        let Some((capacity, weapon)) = stock else {
            return Ok(None);
        };
        let total = s.weapon.magazine + s.weapon.reserve;
        if now < s.supply.scavenge_at
            || capacity >= 9000
            || total >= (f64::from(capacity) * 0.65) as i32
        {
            return Ok(None);
        }
        let body = self
            .units_near(units, s.motion.position, 3.2, -1)?
            .into_iter()
            .filter_map(|id| self.soldier(id))
            .find(|body| body.vitals.life == Life::Dead && body.fight.loot > 0)
            .map(|body| Body {
                id: body.identity.id.into(),
                position: body.motion.position,
                dead: true,
                loot: body.fight.loot,
            });
        let mut timers = s.supply;
        let transfer = timers.scavenge(now, total, Some(capacity), body.as_slice())?;
        self.soldier_mut(id).unwrap().supply = timers;
        let Some(transfer) = transfer else {
            return Ok(None);
        };
        self.soldier_mut(transfer.body as u32).unwrap().fight.loot -= transfer.rounds;
        let s = self.soldier_mut(id).unwrap();
        s.weapon.reserve += transfer.rounds;
        s.fight.out_of_ammo_said = false;
        s.weapon.low_ammo_said = false;
        let mut speech = None;
        if f64::from(rng.randf()) < 0.6 {
            let choice = (rng.randi() % 3) as u8;
            if s.vitals.speech_cooldown <= 0.0 {
                s.vitals.speech_cooldown = 2.6;
                speech = Some(choice);
            }
        }
        let mut reload_speech = if s.weapon.magazine <= 0 {
            s.weapon.reload(weapon, rng)
        } else {
            None
        };
        if reload_speech.is_some() {
            if s.vitals.speech_cooldown <= 0.0 {
                s.vitals.speech_cooldown = 2.6;
            } else {
                reload_speech = None;
            }
        }
        Ok(Some(Scavenged {
            body: transfer.body as u32,
            rounds: transfer.rounds,
            speech,
            reload_speech,
        }))
    }

    pub fn seek_infantry_supply(
        &mut self,
        id: u32,
        now: f64,
        units: &SpatialIndex,
        structures: &SpatialIndex,
        rng: &mut SimulationRandom,
    ) -> Result<Option<SupplyOrder>, &'static str> {
        if !clock(now) || units.cell_size() != UNIT_CELL || structures.cell_size() != STRUCTURE_CELL
        {
            return Err("invalid retained resupply search");
        }
        let s = self.soldier(id).ok_or("missing resupplying soldier")?;
        if now < s.supply.search_at {
            return Ok(None);
        }
        let position = s.motion.position;
        let team = s.identity.team;
        let bodies: Vec<_> = self
            .units_near(units, position, 25.0, -1)?
            .into_iter()
            .filter_map(|id| self.soldier(id))
            .map(|body| Body {
                id: body.identity.id.into(),
                position: body.motion.position,
                dead: body.vitals.life == Life::Dead,
                loot: body.fight.loot,
            })
            .collect();
        let mut timers = s.supply;
        let search = timers.search_bodies(now, position, &bodies)?;
        let mut random = *rng;
        let destination = match search {
            Search::Wait => None,
            Search::Body(id) => Some((
                SupplySource::Body,
                id as u32,
                self.soldier(id as u32).unwrap().motion.position,
            )),
            Search::Depots => {
                let mut nearest = 1e9;
                let mut fob = None;
                for actor in self.iter_kind(crate::entities::Kind::Structure) {
                    if let Actor::Structure(st) = actor {
                        if st.kind != "fob" || st.team != team || !st.built {
                            continue;
                        }
                        let distance = f64::from(flat(st.position - position).length())
                            + if st.wrecked { 60.0 } else { 0.0 };
                        if distance < nearest {
                            nearest = distance;
                            fob = Some(Depot {
                                id: st.id.into(),
                                position: st.position,
                            });
                        }
                    }
                }
                let radius = fob.map_or(70.0, |f| {
                    f64::from(flat(f.position - position).length()).min(70.0)
                });
                let caches: Vec<_> = self
                    .structures_near(structures, position, radius, false)?
                    .into_iter()
                    .filter_map(|id| self.structure(id))
                    .map(|st| Cache {
                        depot: Depot {
                            id: st.id.into(),
                            position: st.position,
                        },
                        team: st.team.into(),
                        built: st.built,
                        gone: false,
                        ammo_cache: st.kind == "ammo_cache",
                    })
                    .collect();
                infantry_supply::choose_depot(position, team.into(), fob, &caches, &mut random)?
                    .map(|d| {
                        (
                            if d.cache {
                                SupplySource::Cache
                            } else {
                                SupplySource::Fob
                            },
                            d.depot as u32,
                            d.position,
                        )
                    })
            }
        };
        let Some((source, entity, position)) = destination else {
            self.soldier_mut(id).unwrap().supply = timers;
            return Ok(None);
        };
        let s = self.soldier_mut(id).unwrap();
        let previous_duty = s.duty;
        s.duty.kind = Task::Resupply;
        s.duty.entity = entity.into();
        let route = match s.go_to(position, Goal::Task, 1) {
            Ok(route) => route,
            Err(error) => {
                s.duty = previous_duty;
                return Err(error);
            }
        };
        s.supply = timers;
        if source != SupplySource::Body {
            s.vitals.speech_cooldown = 2.6;
        }
        *rng = random;
        Ok(Some(SupplyOrder {
            source,
            entity,
            route,
        }))
    }
}
