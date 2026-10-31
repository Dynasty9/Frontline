use crate::path_planner::PathPlannerCore;
use crate::simulation_random::SimulationRandomCore;
use frontline_core::infantry_action::ActionState;
use frontline_core::infantry_controller::{self as controller, Controller, Task};
use frontline_core::infantry_shock::InfantryShock;
use frontline_core::infantry_vitals::Life;
use godot::prelude::*;

#[derive(GodotClass)]
#[class(base=RefCounted, init)]
struct InfantryControllerCore {
    base: Base<RefCounted>,
    core: Controller,
}

fn read<T: FromGodot>(v: &Array<Variant>, n: usize) -> Option<T> {
    v.get(n)?.try_to().ok()
}
pub(crate) fn state(v: &Array<Variant>) -> Option<Controller> {
    if v.len() != 5 {
        return None;
    }
    let s = Controller {
        think_timer: read(v, 0)?,
        scan_number: u64::try_from(read::<i64>(v, 1)?).ok()?,
        activity_timer: read(v, 2)?,
        dive_timer: read(v, 3)?,
        dive_direction: crate::point(read(v, 4)?),
    };
    s.valid().then_some(s)
}
pub(crate) fn encode(s: Controller) -> Array<Variant> {
    varray![
        s.think_timer,
        s.scan_number as i64,
        s.activity_timer,
        s.dive_timer,
        Vector3::new(s.dive_direction.x, s.dive_direction.y, s.dive_direction.z)
    ]
}
fn task(value: i32) -> Option<Task> {
    u8::try_from(value).ok()?.try_into().ok()
}
fn life(value: i32) -> Option<Life> {
    u8::try_from(value).ok()?.try_into().ok()
}

#[godot_api]
impl InfantryControllerCore {
    #[func]
    fn advance(
        &mut self,
        values: Array<Variant>,
        dt: f64,
        timers: PackedFloat64Array,
        mut rng: Gd<SimulationRandomCore>,
    ) -> Array<Variant> {
        let Some(mut s) = state(&values) else {
            return Array::new();
        };
        if timers.len() != 3 {
            return Array::new();
        }
        let mut shock = InfantryShock {
            dazed_timer: timers[0],
            flinch_timer: timers[1],
            ..Default::default()
        };
        let mut action = ActionState {
            remaining: timers[2],
            ..Default::default()
        };
        let Ok(out) = s.advance(dt, &mut shock, &mut action, &mut rng.bind_mut().core) else {
            return Array::new();
        };
        self.core = s;
        varray![
            &encode(s),
            &PackedFloat64Array::from(
                [shock.dazed_timer, shock.flinch_timer, action.remaining].as_slice()
            ),
            out.stage as i32,
            out.flinch_ended
        ]
    }

    #[func]
    fn activity(&mut self, values: Array<Variant>, dt: f64) -> Array<Variant> {
        let Some(mut s) = state(&values) else {
            return Array::new();
        };
        let Ok(due) = s.activity_due(dt) else {
            return Array::new();
        };
        self.core = s;
        varray![&encode(s), due]
    }

    #[func]
    fn scan(&mut self, values: Array<Variant>, target_present: bool) -> Array<Variant> {
        let Some(mut s) = state(&values) else {
            return Array::new();
        };
        let Ok(due) = s.scan_due(target_present) else {
            return Array::new();
        };
        self.core = s;
        varray![&encode(s), due]
    }

    #[func]
    fn dive(
        &mut self,
        values: Array<Variant>,
        position: Vector3,
        base: f64,
        dt: f64,
        nav: Gd<PathPlannerCore>,
    ) -> Array<Variant> {
        let Some(mut s) = state(&values) else {
            return Array::new();
        };
        let nav = nav.bind();
        let Some(nav) = nav.core.as_ref() else {
            return Array::new();
        };
        let Ok(out) = s.dive(crate::point(position), base, dt, nav) else {
            return Array::new();
        };
        self.core = s;
        varray![
            &encode(s),
            Vector3::new(out.position.x, out.position.y, out.position.z),
            out.finished
        ]
    }

    #[func]
    fn continue_after_think(&self, living: i32, action: f64, dive: f64) -> i32 {
        let Some(life) = life(living) else {
            return -1;
        };
        controller::continue_after_think(life, action, dive).map_or(-1, i32::from)
    }

    #[func]
    fn orders(&self, living: i32, duty: i32, phase: i32, retreat: bool) -> i32 {
        let (Some(life), Some(task), Ok(phase)) = (life(living), task(duty), u8::try_from(phase))
        else {
            return -1;
        };
        i32::from(if retreat {
            task.can_retreat(life)
        } else {
            task.can_take_orders(life, phase)
        })
    }

    #[func]
    fn busy(&self, duty: i32, phase: i32, bearer: bool) -> i32 {
        let (Some(task), Ok(phase)) = (task(duty), u8::try_from(phase)) else {
            return -1;
        };
        i32::from(task.busy(phase, bearer))
    }

    #[func]
    fn checkpoint(&self) -> PackedByteArray {
        self.core.checkpoint().as_slice().into()
    }
    #[func]
    fn restore(&mut self, bytes: PackedByteArray) -> bool {
        let Ok(core) = Controller::restore(bytes.as_slice()) else {
            return false;
        };
        self.core = core;
        true
    }
}
