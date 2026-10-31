//! Support vehicles update nearby retained actors; effects carry only speech and battle counters.
use crate::actors::{Actor, Actors};
use crate::infantry::Infantry;
use crate::infantry_supply::Loadout;
use crate::infantry_vitals::Life;
use crate::random::SimulationRandom;
use crate::spatial::SpatialIndex;
use crate::vector::Vector3;
use crate::vehicle::Vehicle;
use std::collections::HashMap;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Service {
    Repair,
    Ammo,
    Medical,
}
#[derive(Clone, Copy, Debug)]
pub struct SoldierSupply<'a> {
    pub loadout: Option<Loadout>,
    pub restored_weapon: Option<(&'a str, i32)>,
}
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ServiceEffect {
    Repaired { vehicle: u32, track: bool },
    Reload { soldier: u32, speech: u8 },
    Revived { soldier: u32, speech: u8 },
}

impl Actors {
    pub fn service_vehicle<'a>(
        &mut self,
        vehicle: u32,
        dt: f64,
        service: Service,
        units: &SpatialIndex,
        rng: &mut SimulationRandom,
        soldier_stock: impl Fn(&Infantry) -> Result<SoldierSupply<'a>, &'static str>,
        vehicle_stock: impl Fn(&Vehicle) -> Result<[i32; 2], &'static str>,
    ) -> Result<Vec<ServiceEffect>, &'static str> {
        if !dt.is_finite() || !(0.0..=10.0).contains(&dt) {
            return Err("invalid vehicle service step");
        }
        let v = self.vehicle(vehicle).ok_or("missing service vehicle")?;
        let timer = v.service_timer - dt;
        if !timer.is_finite() || timer.abs() > 1e12 {
            return Err("vehicle service clock exceeds limit");
        }
        if timer > 0.0 || v.speed > 1.0 {
            self.vehicle_mut(vehicle).unwrap().service_timer = timer;
            return Ok(Vec::new());
        }
        let (position, team) = (v.position, v.team);
        let mut random = rng.clone();
        // Only the once-per-second recipients are staged, so bad content cannot leave a partial refill.
        let mut updates: HashMap<u32, Actor> = HashMap::new();
        let mut effects = Vec::new();
        if service != Service::Repair {
            let ids = self.units_near(
                units,
                position,
                if service == Service::Medical {
                    11.0
                } else {
                    13.0
                },
                -1,
            )?;
            for id in ids {
                let Some(Actor::Soldier(s)) = updates.get(&id).or_else(|| self.get(id)) else {
                    continue;
                };
                if s.identity.team != team {
                    continue;
                }
                if service == Service::Ammo {
                    if s.vitals.life != Life::Alive {
                        continue;
                    }
                    let stock = soldier_stock(s)?;
                    let Actor::Soldier(s) = updates
                        .entry(id)
                        .or_insert_with(|| self.get(id).unwrap().clone())
                    else {
                        unreachable!();
                    };
                    if let Some(speech) = s.resupply(1.0, stock.loadout, &mut random)? {
                        effects.push(ServiceEffect::Reload {
                            soldier: id,
                            speech,
                        });
                    }
                } else if s.vitals.life == Life::Downed
                    && s.links.dragged_by == 0
                    && s.links.carried_by.is_empty()
                    && f64::from(random.randf()) < 0.22
                {
                    let stock = soldier_stock(s)?;
                    let Actor::Soldier(s) = updates
                        .entry(id)
                        .or_insert_with(|| self.get(id).unwrap().clone())
                    else {
                        unreachable!();
                    };
                    let speech = s.revive(false, stock.restored_weapon, &mut random)?;
                    effects.push(ServiceEffect::Revived {
                        soldier: id,
                        speech,
                    });
                } else if s.vitals.life == Life::Alive && s.vitals.hp < s.vitals.max_hp {
                    let Actor::Soldier(s) = updates
                        .entry(id)
                        .or_insert_with(|| self.get(id).unwrap().clone())
                    else {
                        unreachable!();
                    };
                    s.vitals.hp = s.vitals.max_hp.min(s.vitals.hp + 5.0);
                }
            }
        }
        if service != Service::Medical {
            // Vehicles keep registration order; the infantry query above follows the unit buckets.
            for actor in self.iter() {
                let Actor::Vehicle(v) = actor else {
                    continue;
                };
                let delta = v.position - position;
                if v.id == vehicle
                    || v.team != team
                    || Vector3::new(delta.x, 0.0, delta.z).length() > 13.0
                {
                    continue;
                }
                if service == Service::Repair && !v.needs_repair() {
                    continue;
                }
                let mut next = v.clone();
                if service == Service::Repair {
                    let track = next.repair(1.4)?;
                    effects.push(ServiceEffect::Repaired {
                        vehicle: v.id,
                        track,
                    });
                } else {
                    let [atgm, sam] = vehicle_stock(v)?;
                    next.rearm(atgm, sam)?;
                }
                updates.insert(v.id, Actor::Vehicle(next));
            }
        }
        for (id, actor) in updates {
            match actor {
                Actor::Soldier(s) => *self.soldier_mut(id).unwrap() = *s,
                Actor::Vehicle(v) => *self.vehicle_mut(id).unwrap() = *v,
                _ => unreachable!(),
            }
        }
        self.vehicle_mut(vehicle).unwrap().service_timer = 1.0;
        *rng = random;
        Ok(effects)
    }
}
