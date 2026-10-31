use crate::{path_planner::PathPlannerCore, simulation_random::SimulationRandomCore};
use frontline_core::infantry_shock::{InfantryShock, Stagger};
use frontline_core::infantry_vitals::Life;
use godot::prelude::*;

#[derive(GodotClass)]
#[class(base=RefCounted, init)]
struct InfantryShockCore {
    base: Base<RefCounted>,
    core: InfantryShock,
}

pub(crate) fn decode(v: &[f64]) -> Option<InfantryShock> {
    if v.len() != 6 || v.iter().any(|x| !x.is_finite()) || (v[0] != 0.0 && v[0] != 1.0) {
        return None;
    }
    let state = InfantryShock {
        flinging: v[0] != 0.0,
        velocity: frontline_core::vector::Vector3::new(v[1] as f32, v[2] as f32, v[3] as f32),
        dazed_timer: v[4],
        flinch_timer: v[5],
    };
    state.valid().then_some(state)
}
pub(crate) fn observation(s: InfantryShock) -> PackedFloat64Array {
    PackedFloat64Array::from(&[
        f64::from(s.flinging),
        f64::from(s.velocity.x),
        f64::from(s.velocity.y),
        f64::from(s.velocity.z),
        s.dazed_timer,
        s.flinch_timer,
    ])
}
fn life(v: i32) -> Option<Life> {
    Life::try_from(u8::try_from(v).ok()?).ok()
}
fn vector(v: frontline_core::vector::Vector3) -> Vector3 {
    Vector3::new(v.x, v.y, v.z)
}

#[godot_api]
impl InfantryShockCore {
    #[func]
    fn checkpoint(&self) -> PackedByteArray {
        self.core.checkpoint().as_slice().into()
    }

    #[func]
    fn restore(&mut self, bytes: PackedByteArray) -> bool {
        let Ok(state) = InfantryShock::restore(bytes.as_slice()) else {
            return false;
        };
        self.core = state;
        true
    }

    #[func]
    fn fling(
        &mut self,
        values: PackedFloat64Array,
        position: Vector3,
        center: Vector3,
        power: f64,
        life_id: i32,
        carried: bool,
        mut random: Gd<SimulationRandomCore>,
    ) -> Array<Variant> {
        let (Some(mut state), Some(life)) = (decode(values.as_slice()), life(life_id)) else {
            return Array::new();
        };
        let Ok(started) = state.fling(
            crate::point(position),
            crate::point(center),
            power,
            life,
            carried,
            &mut random.bind_mut().core,
        ) else {
            return Array::new();
        };
        self.core = state;
        varray![&observation(state), started]
    }

    #[func]
    fn fling_step(
        &mut self,
        values: PackedFloat64Array,
        position: Vector3,
        life_id: i32,
        dt: f64,
        planner: Gd<PathPlannerCore>,
        mut random: Gd<SimulationRandomCore>,
    ) -> Array<Variant> {
        let (Some(mut state), Some(life)) = (decode(values.as_slice()), life(life_id)) else {
            return Array::new();
        };
        let planner = planner.bind();
        let Some(nav) = planner.core.as_ref() else {
            return Array::new();
        };
        let Ok(result) = state.fling_step(
            crate::point(position),
            life,
            dt,
            nav,
            &mut random.bind_mut().core,
        ) else {
            return Array::new();
        };
        self.core = state;
        varray![
            &observation(state),
            vector(result.position),
            result.landed,
            result.dazed,
            result.speak
        ]
    }

    #[func]
    fn flinch(
        &mut self,
        values: PackedFloat64Array,
        mut suppression: f64,
        life_id: i32,
        distance: f64,
        radius: f64,
        busy: bool,
    ) -> Array<Variant> {
        let (Some(mut state), Some(life)) = (decode(values.as_slice()), life(life_id)) else {
            return Array::new();
        };
        let Ok(flinched) = state.flinch(&mut suppression, life, distance, radius, busy) else {
            return Array::new();
        };
        self.core = state;
        varray![&observation(state), suppression, flinched]
    }

    #[func]
    fn stagger(
        &mut self,
        values: PackedFloat64Array,
        context: PackedFloat64Array,
        planner: Gd<PathPlannerCore>,
        mut random: Gd<SimulationRandomCore>,
    ) -> Array<Variant> {
        let Some(mut state) = decode(values.as_slice()) else {
            return Array::new();
        };
        let v = context.as_slice();
        if v.len() != 13 || v.iter().any(|x| !x.is_finite()) || v[12] < -1.0 {
            return Array::new();
        }
        let p =
            |i| frontline_core::vector::Vector3::new(v[i] as f32, v[i + 1] as f32, v[i + 2] as f32);
        let input = Stagger {
            position: p(0),
            yaw: v[3],
            task_timer: v[4],
            direction: p(5),
        };
        let mount = if v[12] == -1.0 {
            None
        } else {
            Some((p(9), v[12]))
        };
        let planner = planner.bind();
        let Some(nav) = planner.core.as_ref() else {
            return Array::new();
        };
        let Ok(result) = state.stagger(input, v[8], mount, nav, &mut random.bind_mut().core) else {
            return Array::new();
        };
        self.core = state;
        varray![
            &observation(state),
            vector(result.position),
            result.yaw,
            result.task_timer,
            vector(result.direction)
        ]
    }
}
