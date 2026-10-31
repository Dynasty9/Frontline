use crate::path_planner::PathPlannerCore;
use crate::simulation_random::SimulationRandomCore;
use frontline_core::infantry_duties::{
    self as duties, Build, Captor, Carry, Duty, Guard, Stretcher,
};
use frontline_core::infantry_travel::{self as travel, AfterBoarding, Boarding, Throw, Tunnel};
use godot::prelude::*;

#[derive(GodotClass)]
#[class(base=RefCounted, init)]
struct InfantryDutiesCore {
    base: Base<RefCounted>,
    core: Duty,
}

fn state(values: &PackedFloat64Array) -> Option<Duty> {
    if values.len() != 3 || !(0.0..=3.0).contains(&values[0]) || values[0].fract() != 0.0 {
        return None;
    }
    let state = Duty {
        phase: values[0] as u8,
        timer: values[1],
        build_sound: values[2],
    };
    state.valid().then_some(state)
}
fn mount(values: &PackedFloat64Array) -> Option<Option<(frontline_core::vector::Vector3, f64)>> {
    if values.is_empty() {
        return Some(None);
    }
    if values.len() != 4 {
        return None;
    }
    Some(Some((
        frontline_core::vector::Vector3::new(values[0] as f32, values[1] as f32, values[2] as f32),
        values[3],
    )))
}
fn vector(p: frontline_core::vector::Vector3) -> Vector3 {
    Vector3::new(p.x, p.y, p.z)
}
fn result(state: Duty, code: u8) -> PackedFloat64Array {
    [
        f64::from(state.phase),
        state.timer,
        state.build_sound,
        f64::from(code),
    ]
    .as_slice()
    .into()
}

#[godot_api]
impl InfantryDutiesCore {
    #[func]
    fn boarding(
        &self,
        valid: bool,
        position: Vector3,
        vehicle: Vector3,
        seats: i32,
        helicopter: bool,
        boat: bool,
        moving: bool,
    ) -> i32 {
        match travel::boarding(
            valid,
            crate::point(position),
            crate::point(vehicle),
            seats,
            helicopter,
            boat,
            moving,
        ) {
            Ok(Boarding::Cancel) => 0,
            Ok(Boarding::Enter) => 1,
            Ok(Boarding::Move) => 2,
            Err(_) => -1,
        }
    }

    #[func]
    fn after_boarding_move(
        &self,
        position: Vector3,
        vehicle: Vector3,
        goal: Vector3,
        boat: bool,
        moved: bool,
    ) -> i32 {
        match travel::after_boarding_move(
            crate::point(position),
            crate::point(vehicle),
            crate::point(goal),
            boat,
            moved,
        ) {
            Ok(AfterBoarding::Enter) => 2,
            Ok(AfterBoarding::Continue { repath }) => i32::from(repath),
            Err(_) => -1,
        }
    }

    #[func]
    fn tunnel_arrival(&self, position: Vector3, entrance: Vector3, moved: bool) -> i32 {
        match travel::tunnel_arrival(crate::point(position), crate::point(entrance), moved) {
            Ok(Tunnel::Move) => 0,
            Ok(Tunnel::Approach) => 1,
            Ok(Tunnel::Enter) => 2,
            Err(_) => -1,
        }
    }

    #[func]
    fn ordered_throw(
        &self,
        position: Vector3,
        target: Vector3,
        inventory: i32,
    ) -> PackedInt32Array {
        match travel::ordered_throw(crate::point(position), crate::point(target), inventory) {
            Ok(Throw::Move) => [0, inventory].as_slice().into(),
            Ok(Throw::Cancel) => [1, inventory].as_slice().into(),
            Ok(Throw::Release { remaining }) => [2, remaining].as_slice().into(),
            Err(_) => PackedInt32Array::new(),
        }
    }

    #[func]
    fn supply_arrival(
        &self,
        capacity: i32,
        magazine: i32,
        reserve: i32,
        loot: i32,
    ) -> PackedInt32Array {
        if loot < -1 {
            return PackedInt32Array::new();
        }
        let Ok(arrival) =
            travel::supply_arrival(capacity, magazine, reserve, (loot >= 0).then_some(loot))
        else {
            return PackedInt32Array::new();
        };
        [
            arrival.rounds,
            i32::from(arrival.announce),
            i32::from(arrival.return_to_hold),
        ]
        .as_slice()
        .into()
    }

    #[func]
    fn build(
        &self,
        done: bool,
        suppression: f64,
        moving: bool,
        position: Vector3,
        destination: Vector3,
        target: PackedVector3Array,
    ) -> i32 {
        if target.len() > 1 {
            return -1;
        }
        match duties::build(
            done,
            suppression,
            moving,
            crate::point(position),
            crate::point(destination),
            target.as_slice().first().copied().map(crate::point),
        ) {
            Ok(Build::Done) => 0,
            Ok(Build::Suppressed) => 1,
            Ok(Build::Move) => 2,
            Ok(Build::Approach) => 3,
            Ok(Build::Fight) => 4,
            Ok(Build::Work) => 5,
            Err(_) => -1,
        }
    }

    #[func]
    fn build_pose(
        &self,
        position: Vector3,
        yaw: f64,
        work: Vector3,
        dt: f64,
        mounted: PackedFloat64Array,
    ) -> PackedFloat64Array {
        let Some(mount) = mount(&mounted) else {
            return PackedFloat64Array::new();
        };
        let Ok(yaw) =
            duties::build_pose(crate::point(position), yaw, crate::point(work), dt, mount)
        else {
            return PackedFloat64Array::new();
        };
        [yaw].as_slice().into()
    }

    #[func]
    fn finish_build(
        &mut self,
        values: PackedFloat64Array,
        dt: f64,
        mut rng: Gd<SimulationRandomCore>,
    ) -> PackedFloat64Array {
        let Some(mut state) = state(&values) else {
            return PackedFloat64Array::new();
        };
        let Ok(sound) = state.finish_build(dt, &mut rng.bind_mut().core) else {
            return PackedFloat64Array::new();
        };
        self.core = state;
        result(state, u8::from(sound))
    }

    #[func]
    fn stretcher(
        &mut self,
        values: PackedFloat64Array,
        valid: bool,
        position: Vector3,
        casualty: Vector3,
        moving: bool,
        partner_phase: i32,
        front: bool,
        dt: f64,
    ) -> PackedFloat64Array {
        let Some(mut state) = state(&values) else {
            return PackedFloat64Array::new();
        };
        if !(-1..=3).contains(&partner_phase) {
            return PackedFloat64Array::new();
        }
        let Ok(action) = state.stretcher(Stretcher {
            valid,
            position: crate::point(position),
            casualty: crate::point(casualty),
            moving,
            partner_phase: (partner_phase >= 0).then_some(partner_phase as u8),
            front,
            dt,
        }) else {
            return PackedFloat64Array::new();
        };
        let code = match action {
            Carry::Cancel => 0,
            Carry::Move => 1,
            Carry::Approach => 2,
            Carry::Ready => 3,
            Carry::Wait => 4,
            Carry::Lift => 5,
            Carry::Lead => 6,
            Carry::TakeOver => 7,
            Carry::Follow => 8,
        };
        self.core = state;
        result(state, code)
    }

    #[func]
    fn captor(
        &mut self,
        values: PackedFloat64Array,
        valid: bool,
        position: Vector3,
        prisoner: Vector3,
        moving: bool,
    ) -> PackedFloat64Array {
        let Some(mut state) = state(&values) else {
            return PackedFloat64Array::new();
        };
        let Ok(action) = state.captor(
            valid,
            crate::point(position),
            crate::point(prisoner),
            moving,
        ) else {
            return PackedFloat64Array::new();
        };
        let (code, repath) = match action {
            Captor::Cancel => (0, false),
            Captor::Approach { repath } => (1, repath),
            Captor::Claim => (2, false),
            Captor::Guard => (3, false),
            Captor::Wait => (4, false),
        };
        self.core = state;
        let mut out = result(state, code);
        out.push(f64::from(repath));
        out
    }

    #[func]
    fn carry_pose(
        &self,
        position: Vector3,
        yaw: f64,
        last_direction: Vector3,
        dt: f64,
        solo: bool,
        mounted: PackedFloat64Array,
    ) -> Array<Variant> {
        let Some(mount) = mount(&mounted) else {
            return Array::new();
        };
        let Ok(pose) = duties::carry_pose(
            crate::point(position),
            yaw,
            crate::point(last_direction),
            dt,
            solo,
            mount,
        ) else {
            return Array::new();
        };
        varray![pose.yaw, vector(pose.casualty), pose.casualty_yaw]
    }

    #[func]
    fn follow_bearer(
        &self,
        position: Vector3,
        partner: Vector3,
        yaw: f64,
        dt: f64,
    ) -> PackedVector3Array {
        let Ok(pose) =
            duties::follow_bearer(crate::point(position), crate::point(partner), yaw, dt)
        else {
            return PackedVector3Array::new();
        };
        [vector(pose)].as_slice().into()
    }

    #[func]
    fn guard(
        &self,
        position: Vector3,
        yaw: f64,
        prisoner: Vector3,
        dt: f64,
        mounted: PackedFloat64Array,
        planner: Gd<PathPlannerCore>,
        mut rng: Gd<SimulationRandomCore>,
    ) -> Array<Variant> {
        let Some(mount) = mount(&mounted) else {
            return Array::new();
        };
        let planner = planner.bind();
        let Some(planner) = &planner.core else {
            return Array::new();
        };
        let Ok(pose) = duties::guard(
            Guard {
                position: crate::point(position),
                yaw,
                prisoner: crate::point(prisoner),
                dt,
                mount,
            },
            planner,
            &mut rng.bind_mut().core,
        ) else {
            return Array::new();
        };
        varray![vector(pose.position), pose.yaw, pose.walking]
    }

    #[func]
    fn checkpoint(&self) -> PackedByteArray {
        self.core.checkpoint().as_slice().into()
    }

    #[func]
    fn restore(&mut self, bytes: PackedByteArray) -> bool {
        let Ok(state) = Duty::restore(bytes.as_slice()) else {
            return false;
        };
        self.core = state;
        true
    }
}
