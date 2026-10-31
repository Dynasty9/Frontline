use crate::path_planner::PathPlannerCore;
use crate::simulation_random::SimulationRandomCore;
use frontline_core::breach::{self, Breach, Decision, Input};
use frontline_core::breach_selection::{self as selection, Building, Contact, Mate, Opening};
use godot::prelude::*;

#[derive(GodotClass)]
#[class(base=RefCounted, init)]
struct BreachCore {
    base: Base<RefCounted>,
    core: Breach,
}

fn boolean(v: f64) -> Option<bool> {
    match v {
        0.0 => Some(false),
        1.0 => Some(true),
        _ => None,
    }
}
fn integer(v: f64) -> Option<i32> {
    (v.is_finite() && v.fract() == 0.0 && v >= i32::MIN as f64 && v <= i32::MAX as f64)
        .then_some(v as i32)
}
fn state(v: &[f64]) -> Option<Breach> {
    if v.len() != 6 {
        return None;
    }
    let s = Breach {
        phase: u8::try_from(integer(v[0])?).ok()?,
        started: v[1],
        wait_until: v[2],
        cook_started: v[3],
        clear: boolean(v[4])?,
        no_frag: boolean(v[5])?,
    };
    s.valid().then_some(s)
}
fn input(v: &[f64]) -> Option<Input> {
    if v.len() != 11 {
        return None;
    }
    Some(Input {
        time: v[0],
        moving: boolean(v[1])?,
        distance: v[2],
        enemy_inside: boolean(v[3])?,
        door_shut: boolean(v[4])?,
        frags: integer(v[5])?,
        team: integer(v[6])?,
        enemy_hard_cover: boolean(v[7])?,
        exploded: boolean(v[8])?,
        reordered: boolean(v[9])?,
    })
}
fn observation(s: Breach) -> PackedFloat64Array {
    [
        s.phase as f64,
        s.started,
        s.wait_until,
        s.cook_started,
        s.clear.into(),
        s.no_frag.into(),
    ]
    .as_slice()
    .into()
}
fn vector(v: frontline_core::vector::Vector3) -> Variant {
    Vector3::new(v.x, v.y, v.z).to_variant()
}

fn id(v: Variant) -> Option<u64> {
    u64::try_from(v.try_to::<i64>().ok()?)
        .ok()
        .filter(|id| *id > 0)
}

fn building(v: &Array<Variant>) -> Option<Building> {
    if v.len() != 7 {
        return None;
    }
    let b = Building {
        id: id(v.get(0)?)?,
        position: crate::point(v.get(1)?.try_to().ok()?),
        size: crate::point(v.get(2)?.try_to().ok()?),
        yaw: v.get(3)?.try_to().ok()?,
        kind: u8::try_from(v.get(4)?.try_to::<i32>().ok()?).ok()?,
        gone: v.get(5)?.try_to().ok()?,
        wrecked: v.get(6)?.try_to().ok()?,
    };
    b.valid().then_some(b)
}

fn buildings(rows: &Array<Variant>) -> Option<Vec<Building>> {
    if rows.len() > 100_000 {
        return None;
    }
    rows.iter_shared()
        .map(|v| building(&v.try_to().ok()?))
        .collect()
}

fn opening(v: &Array<Variant>) -> Option<Opening> {
    if v.len() != 4 {
        return None;
    }
    let o = Opening {
        id: id(v.get(0)?)?,
        center: crate::point(v.get(1)?.try_to().ok()?),
        normal: crate::point(v.get(2)?.try_to().ok()?),
        door: v.get(3)?.try_to().ok()?,
    };
    o.valid().then_some(o)
}

fn contacts(rows: &Array<Variant>) -> Option<Vec<Contact>> {
    if rows.len() > 100_000 {
        return None;
    }
    let mut total = 0;
    rows.iter_shared()
        .map(|row| {
            let v: Array<Variant> = row.try_to().ok()?;
            if v.len() != 3 {
                return None;
            }
            let house = building(&v.get(0)?.try_to().ok()?)?;
            let o: Array<Variant> = v.get(2)?.try_to().ok()?;
            total += o.len();
            if total > 100_000 {
                return None;
            }
            Some(Contact {
                house,
                enemy_alive: v.get(1)?.try_to().ok()?,
                openings: o
                    .iter_shared()
                    .map(|o| opening(&o.try_to().ok()?))
                    .collect::<Option<Vec<_>>>()?,
            })
        })
        .collect()
}

fn mates(rows: &Array<Variant>) -> Option<Vec<Mate>> {
    if rows.len() > 100_000 {
        return None;
    }
    rows.iter_shared()
        .map(|row| {
            let v: Array<Variant> = row.try_to().ok()?;
            if v.len() != 6 {
                return None;
            }
            Some(Mate {
                position: crate::point(v.get(0)?.try_to().ok()?),
                other: v.get(1)?.try_to().ok()?,
                alive: v.get(2)?.try_to().ok()?,
                idle: v.get(3)?.try_to().ok()?,
                frags: v.get(4)?.try_to().ok()?,
                mounted: v.get(5)?.try_to().ok()?,
            })
        })
        .collect()
}

#[godot_api]
impl BreachCore {
    #[func]
    fn house_at(&self, position: Vector3, houses: Array<Variant>) -> Variant {
        let Some(houses) = buildings(&houses) else {
            return Variant::nil();
        };
        selection::house_at(crate::point(position), &houses)
            .map(|id| (id.unwrap_or(0) as i64).to_variant())
            .unwrap_or_default()
    }

    #[func]
    fn openings(&self, house: Array<Variant>, walls: Array<Variant>) -> Variant {
        let (Some(house), Some(walls)) = (building(&house), buildings(&walls)) else {
            return Variant::nil();
        };
        let Ok(openings) = selection::openings(house, &walls) else {
            return Variant::nil();
        };
        let rows: Array<Variant> = openings
            .into_iter()
            .map(|o| {
                varray![o.id as i64, &vector(o.center), &vector(o.normal), o.door].to_variant()
            })
            .collect();
        rows.to_variant()
    }

    #[func]
    fn choose(
        &self,
        position: Vector3,
        hold: Vector3,
        own_house: i64,
        candidates: Array<Variant>,
        teammates: Array<Variant>,
        planner: Gd<PathPlannerCore>,
    ) -> PackedInt64Array {
        let (Some(contacts), Some(mates)) = (contacts(&candidates), mates(&teammates)) else {
            return PackedInt64Array::new();
        };
        if own_house < 0 {
            return PackedInt64Array::new();
        }
        let planner = planner.bind();
        let Some(nav) = planner.core.as_ref() else {
            return PackedInt64Array::new();
        };
        let Ok(choice) = selection::choose(
            crate::point(position),
            crate::point(hold),
            (own_house != 0).then_some(own_house as u64),
            &contacts,
            &mates,
            nav,
        ) else {
            return PackedInt64Array::new();
        };
        let indices = choice
            .map(|(c, o)| [c as i64, o as i64])
            .unwrap_or([-1, -1]);
        indices.as_slice().into()
    }

    #[func]
    fn advance(
        &mut self,
        values: PackedFloat64Array,
        context: PackedFloat64Array,
        mut random: Gd<SimulationRandomCore>,
    ) -> Array<Variant> {
        let (Some(mut s), Some(i)) = (state(values.as_slice()), input(context.as_slice())) else {
            return Array::new();
        };
        // The last flag validates the building before movement or weapons can run.
        let Some(valid) = boolean(context[10]) else {
            return Array::new();
        };
        if s.expired(i.time, valid) != Ok(false) {
            return Array::new();
        }
        let Ok(decision) = s.advance(i, &mut random.bind_mut().core) else {
            return Array::new();
        };
        self.core = s;
        let (action, amount, distance) = match decision {
            Decision::Wait => (0, 0.0, 0.0),
            Decision::Cancel => (1, 0.0, 0.0),
            Decision::RetryStack => (2, 0.0, 0.0),
            Decision::Stacked => (3, 0.0, 0.0),
            Decision::ApproachDoor { cook, distance } => (4, cook, f64::from(distance)),
            Decision::KickDoor => (5, 0.0, 0.0),
            Decision::EnterWait => (6, 0.0, 0.0),
            Decision::Throw { fuse } => (7, fuse, 0.0),
            Decision::FollowSquad => (8, 0.0, 0.0),
            Decision::Enter => (9, 0.0, 0.0),
        };
        varray![&observation(s), action, amount, distance]
    }

    #[func]
    fn expired(&self, values: PackedFloat64Array, time: f64, building_valid: bool) -> Variant {
        state(values.as_slice())
            .and_then(|s| s.expired(time, building_valid).ok())
            .map(|v| v.to_variant())
            .unwrap_or_default()
    }

    #[func]
    fn retreat(&self, distance: f64, moving: bool, grenade_present: bool) -> Variant {
        breach::retreat(distance, moving, grenade_present)
            .map(|v| i32::from(v).to_variant())
            .unwrap_or_default()
    }

    #[func]
    fn room_target(&self, center: Vector3, normal: Vector3, target: Vector3) -> Variant {
        breach::room_target(
            crate::point(center),
            crate::point(normal),
            crate::point(target),
        )
        .map(vector)
        .unwrap_or_default()
    }

    #[func]
    fn stack_spot(
        &self,
        position: Vector3,
        center: Vector3,
        normal: Vector3,
        door: bool,
    ) -> Variant {
        breach::stack_spot(
            crate::point(position),
            crate::point(center),
            crate::point(normal),
            door,
        )
        .map(vector)
        .unwrap_or_default()
    }

    #[func]
    fn checkpoint(&self) -> PackedByteArray {
        self.core.checkpoint().as_slice().into()
    }

    #[func]
    fn restore(&mut self, bytes: PackedByteArray) -> bool {
        let Ok(s) = Breach::restore(bytes.as_slice()) else {
            return false;
        };
        self.core = s;
        true
    }
}
