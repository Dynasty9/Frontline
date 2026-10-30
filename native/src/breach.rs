use crate::simulation_random::SimulationRandomCore;
use frontline_core::breach::{self, Breach, Decision, Input};
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

#[godot_api]
impl BreachCore {
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
