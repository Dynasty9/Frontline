use crate::path_planner::PathPlannerCore;
use frontline_core::infantry_medicine::{self as medicine, EscortInput, Heal, Rescue, Treatment};
use godot::prelude::*;

#[derive(GodotClass)]
#[class(base=RefCounted, init)]
struct InfantryMedicineCore {
    base: Base<RefCounted>,
    core: Treatment,
}

fn state(v: &PackedFloat64Array) -> Option<Treatment> {
    if v.len() != 2 || !(0.0..=2.0).contains(&v[0]) || v[0].fract() != 0.0 {
        return None;
    }
    let s = Treatment {
        phase: v[0] as u8,
        timer: v[1],
    };
    s.valid().then_some(s)
}
fn mount(v: &PackedFloat64Array) -> Option<Option<(frontline_core::vector::Vector3, f64)>> {
    if v.is_empty() {
        return Some(None);
    }
    if v.len() != 4 {
        return None;
    }
    Some(Some((
        frontline_core::vector::Vector3::new(v[0] as f32, v[1] as f32, v[2] as f32),
        v[3],
    )))
}

#[godot_api]
impl InfantryMedicineCore {
    #[func]
    fn rescue(
        &mut self,
        values: PackedFloat64Array,
        valid: bool,
        position: Vector3,
        patient: Vector3,
        moving: bool,
        goal: Vector3,
    ) -> PackedFloat64Array {
        let Some(mut state) = state(&values) else {
            return PackedFloat64Array::new();
        };
        let Ok(action) = state.rescue(
            valid,
            crate::point(position),
            crate::point(patient),
            moving,
            crate::point(goal),
        ) else {
            return PackedFloat64Array::new();
        };
        let (code, repath) = match action {
            Rescue::Cancel => (0.0, false),
            Rescue::Approach { repath } => (1.0, repath),
            Rescue::Claim => (2.0, false),
            Rescue::Drag => (3.0, false),
            Rescue::Treat => (4.0, false),
        };
        self.core = state;
        [f64::from(state.phase), state.timer, code, f64::from(repath)]
            .as_slice()
            .into()
    }

    #[func]
    fn heal(
        &mut self,
        values: PackedFloat64Array,
        valid: bool,
        position: Vector3,
        patient: Vector3,
        moving: bool,
        duration: f64,
    ) -> PackedFloat64Array {
        let Some(mut state) = state(&values) else {
            return PackedFloat64Array::new();
        };
        let Ok(action) = state.heal(
            valid,
            crate::point(position),
            crate::point(patient),
            moving,
            duration,
        ) else {
            return PackedFloat64Array::new();
        };
        let (code, repath) = match action {
            Heal::Cancel => (0.0, false),
            Heal::Approach { repath } => (1.0, repath),
            Heal::Start => (2.0, false),
            Heal::Treat => (3.0, false),
        };
        self.core = state;
        [f64::from(state.phase), state.timer, code, f64::from(repath)]
            .as_slice()
            .into()
    }

    #[func]
    fn finish_drag(
        &mut self,
        values: PackedFloat64Array,
        moving: bool,
        duration: f64,
    ) -> PackedFloat64Array {
        let Some(mut state) = state(&values) else {
            return PackedFloat64Array::new();
        };
        let Ok(started) = state.finish_drag(moving, duration) else {
            return PackedFloat64Array::new();
        };
        self.core = state;
        [f64::from(state.phase), state.timer, f64::from(started)]
            .as_slice()
            .into()
    }

    #[func]
    fn treat(&mut self, values: PackedFloat64Array, dt: f64) -> PackedFloat64Array {
        let Some(mut state) = state(&values) else {
            return PackedFloat64Array::new();
        };
        let Ok(done) = state.treat(dt) else {
            return PackedFloat64Array::new();
        };
        self.core = state;
        [f64::from(state.phase), state.timer, f64::from(done)]
            .as_slice()
            .into()
    }

    #[func]
    fn duration(&self, rate: f64, upgrade: bool) -> PackedFloat64Array {
        medicine::heal_time(rate, upgrade)
            .map(|v| [v].as_slice().into())
            .unwrap_or_default()
    }

    #[func]
    fn escort(
        &self,
        position: Vector3,
        yaw: f64,
        rescuer: Vector3,
        threat: Vector3,
        dt: f64,
        mounted: PackedFloat64Array,
        planner: Gd<PathPlannerCore>,
    ) -> Array<Variant> {
        let Some(mount) = mount(&mounted) else {
            return Array::new();
        };
        let planner = planner.bind();
        let Some(planner) = &planner.core else {
            return Array::new();
        };
        let Ok(pose) = medicine::escort(
            EscortInput {
                position: crate::point(position),
                yaw,
                rescuer: crate::point(rescuer),
                threat: crate::point(threat),
                dt,
                mount,
            },
            planner,
        ) else {
            return Array::new();
        };
        varray![
            Vector3::new(pose.position.x, pose.position.y, pose.position.z),
            pose.yaw,
            pose.backwards,
            pose.walking
        ]
    }

    #[func]
    fn drag_pose(
        &self,
        position: Vector3,
        yaw: f64,
        last_direction: Vector3,
        dt: f64,
        mounted: PackedFloat64Array,
    ) -> Array<Variant> {
        let Some(mount) = mount(&mounted) else {
            return Array::new();
        };
        let Ok(pose) = medicine::drag_pose(
            crate::point(position),
            yaw,
            crate::point(last_direction),
            dt,
            mount,
        ) else {
            return Array::new();
        };
        varray![
            pose.yaw,
            Vector3::new(pose.patient.x, pose.patient.y, pose.patient.z)
        ]
    }

    #[func]
    fn safe_anchor(
        &self,
        patient: Vector3,
        away: Vector3,
        orders: PackedVector3Array,
        planner: Gd<PathPlannerCore>,
    ) -> PackedVector3Array {
        if orders.len() > 1 {
            return PackedVector3Array::new();
        }
        let planner = planner.bind();
        let Some(planner) = &planner.core else {
            return PackedVector3Array::new();
        };
        let Ok(p) = medicine::safe_anchor(
            crate::point(patient),
            crate::point(away),
            orders.as_slice().first().copied().map(crate::point),
            planner,
        ) else {
            return PackedVector3Array::new();
        };
        [Vector3::new(p.x, p.y, p.z)].as_slice().into()
    }

    #[func]
    fn checkpoint(&self) -> PackedByteArray {
        self.core.checkpoint().as_slice().into()
    }

    #[func]
    fn restore(&mut self, bytes: PackedByteArray) -> bool {
        let Ok(state) = Treatment::restore(bytes.as_slice()) else {
            return false;
        };
        self.core = state;
        true
    }
}
