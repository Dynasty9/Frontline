use crate::simulation_random::SimulationRandomCore;
use frontline_core::infantry_supply::{self as supply, Body, Cache, Depot, Search, SupplyTimers};
use godot::prelude::*;

#[derive(GodotClass)]
#[class(base=RefCounted, init)]
struct InfantrySupplyCore {
    base: Base<RefCounted>,
    core: SupplyTimers,
}

pub(crate) fn state(v: &PackedFloat64Array) -> Option<SupplyTimers> {
    if v.len() != 2 {
        return None;
    }
    let s = SupplyTimers {
        scavenge_at: v[0],
        search_at: v[1],
    };
    s.valid().then_some(s)
}
pub(crate) fn encode(s: SupplyTimers) -> PackedFloat64Array {
    [s.scavenge_at, s.search_at].as_slice().into()
}
fn bodies(rows: &Array<Variant>) -> Option<Vec<Body>> {
    if rows.len() > 100_000 {
        return None;
    }
    rows.iter_shared()
        .map(|v| {
            let v: Array<Variant> = v.try_to().ok()?;
            if v.len() != 4 {
                return None;
            }
            Some(Body {
                id: u64::try_from(v.get(0)?.try_to::<i64>().ok()?).ok()?,
                position: crate::point(v.get(1)?.try_to().ok()?),
                dead: v.get(2)?.try_to().ok()?,
                loot: v.get(3)?.try_to().ok()?,
            })
        })
        .collect()
}

#[godot_api]
impl InfantrySupplyCore {
    #[func]
    fn scavenge(
        &mut self,
        values: PackedFloat64Array,
        now: f64,
        total: i32,
        capacity: i32,
        nearby: Array<Variant>,
    ) -> Array<Variant> {
        let Some(mut state) = state(&values) else {
            return Array::new();
        };
        let Some(nearby) = bodies(&nearby) else {
            return Array::new();
        };
        if capacity < -1 {
            return Array::new();
        }
        let Ok(result) = state.scavenge(now, total, (capacity >= 0).then_some(capacity), &nearby)
        else {
            return Array::new();
        };
        self.core = state;
        varray![
            &encode(state),
            result.map_or(0, |t| t.body) as i64,
            result.map_or(0, |t| t.rounds)
        ]
    }

    #[func]
    fn search_bodies(
        &mut self,
        values: PackedFloat64Array,
        now: f64,
        position: Vector3,
        nearby: Array<Variant>,
    ) -> Array<Variant> {
        let Some(mut state) = state(&values) else {
            return Array::new();
        };
        let Some(nearby) = bodies(&nearby) else {
            return Array::new();
        };
        let Ok(result) = state.search_bodies(now, crate::point(position), &nearby) else {
            return Array::new();
        };
        self.core = state;
        varray![
            &encode(state),
            match result {
                Search::Wait => -1,
                Search::Depots => 0,
                Search::Body(id) => id as i64,
            }
        ]
    }

    #[func]
    fn choose_depot(
        &self,
        position: Vector3,
        team: i32,
        fob: Array<Variant>,
        caches: Array<Variant>,
        mut random: Gd<SimulationRandomCore>,
    ) -> Array<Variant> {
        self.depot_checked(position, team, &fob, &caches, &mut random)
            .unwrap_or_default()
    }

    #[func]
    fn refill_reserve(
        &self,
        capacity: i32,
        magazine: i32,
        reserve: i32,
        dt: f64,
    ) -> PackedInt64Array {
        let Ok((reserve, changed)) = supply::refill_reserve(capacity, magazine, reserve, dt) else {
            return PackedInt64Array::new();
        };
        [i64::from(reserve), i64::from(changed)].as_slice().into()
    }

    #[func]
    fn refill_special(
        &self,
        stock: PackedInt32Array,
        capacity: PackedInt32Array,
        dt: f64,
        mut random: Gd<SimulationRandomCore>,
    ) -> PackedInt32Array {
        let Ok(mut stock) = <[i32; 5]>::try_from(stock.as_slice()) else {
            return PackedInt32Array::new();
        };
        let Ok(capacity) = <[i32; 5]>::try_from(capacity.as_slice()) else {
            return PackedInt32Array::new();
        };
        if supply::refill_special(&mut stock, capacity, dt, &mut random.bind_mut().core).is_err() {
            return PackedInt32Array::new();
        }
        stock.as_slice().into()
    }

    #[func]
    fn checkpoint(&self) -> PackedByteArray {
        self.core.checkpoint().as_slice().into()
    }

    #[func]
    fn restore(&mut self, bytes: PackedByteArray) -> bool {
        let Ok(state) = SupplyTimers::restore(bytes.as_slice()) else {
            return false;
        };
        self.core = state;
        true
    }
}

impl InfantrySupplyCore {
    fn depot_checked(
        &self,
        position: Vector3,
        team: i32,
        fob: &Array<Variant>,
        caches: &Array<Variant>,
        random: &mut Gd<SimulationRandomCore>,
    ) -> Option<Array<Variant>> {
        if (!fob.is_empty() && fob.len() != 2) || caches.len() > 100_000 {
            return None;
        }
        let fob = if fob.is_empty() {
            None
        } else {
            Some(Depot {
                id: u64::try_from(fob.get(0)?.try_to::<i64>().ok()?).ok()?,
                position: crate::point(fob.get(1)?.try_to().ok()?),
            })
        };
        let caches = caches
            .iter_shared()
            .map(|v| {
                let v: Array<Variant> = v.try_to().ok()?;
                if v.len() != 6 {
                    return None;
                }
                Some(Cache {
                    depot: Depot {
                        id: u64::try_from(v.get(0)?.try_to::<i64>().ok()?).ok()?,
                        position: crate::point(v.get(1)?.try_to().ok()?),
                    },
                    team: v.get(2)?.try_to().ok()?,
                    built: v.get(3)?.try_to().ok()?,
                    gone: v.get(4)?.try_to().ok()?,
                    ammo_cache: v.get(5)?.try_to().ok()?,
                })
            })
            .collect::<Option<Vec<_>>>()?;
        let result = supply::choose_depot(
            crate::point(position),
            team,
            fob,
            &caches,
            &mut random.bind_mut().core,
        )
        .ok()?;
        Some(if let Some(d) = result {
            varray![
                d.depot as i64,
                d.cache,
                Vector3::new(d.position.x, d.position.y, d.position.z)
            ]
        } else {
            varray![0_i64, false, Vector3::ZERO]
        })
    }
}
