use frontline_core::infantry_control::{self as control, Control, Hidden, HiddenReason, Status};
use frontline_core::infantry_pose::Posture;
use frontline_core::infantry_vitals::Life;
use godot::prelude::*;

#[derive(GodotClass)]
#[class(base=RefCounted, init)]
struct InfantryControlCore {
    base: Base<RefCounted>,
    core: Control,
}

fn read<T: FromGodot>(row: &Array<Variant>, index: usize) -> Option<T> {
    row.get(index)?.try_to::<T>().ok()
}
fn life(value: i32) -> Option<Life> {
    u8::try_from(value).ok()?.try_into().ok()
}
fn posture(value: i32) -> Option<Posture> {
    u8::try_from(value).ok()?.try_into().ok()
}

#[godot_api]
impl InfantryControlCore {
    #[func]
    fn hidden_step(
        &mut self,
        reason: i32,
        timer: f64,
        dt: f64,
        vehicle: PackedVector3Array,
    ) -> Array<Variant> {
        let Some(reason) = u8::try_from(reason)
            .ok()
            .and_then(|r| HiddenReason::try_from(r).ok())
        else {
            return Array::new();
        };
        if vehicle.len() > 1 {
            return Array::new();
        }
        let mut state = Control {
            hidden: reason,
            hidden_timer: timer,
            ..self.core
        };
        let Ok(result) =
            state.hidden_step(dt, vehicle.as_slice().first().copied().map(crate::point))
        else {
            return Array::new();
        };
        let (code, p) = match result {
            Hidden::Wait => (0, Vector3::ZERO),
            Hidden::FollowVehicle(p) => (1, Vector3::new(p.x, p.y, p.z)),
            Hidden::BailOut => (2, Vector3::ZERO),
            Hidden::LeaveTent => (3, Vector3::ZERO),
            Hidden::LeaveTunnel => (4, Vector3::ZERO),
            Hidden::PrisonerDone => (5, Vector3::ZERO),
        };
        self.core = state;
        varray![state.hidden_timer, code, p]
    }

    #[func]
    fn motion_posture(
        &mut self,
        previous: Vector3,
        position: Vector3,
        dt: f64,
        living: i32,
        stance: i32,
        activity: i32,
    ) -> PackedInt32Array {
        let (Some(life), Some(posture), Ok(activity)) =
            (life(living), posture(stance), u8::try_from(activity))
        else {
            return PackedInt32Array::new();
        };
        let mut state = Control {
            previous_position: crate::point(previous),
            ..self.core
        };
        let Ok(result) = state.motion_posture(dt, crate::point(position), life, posture, activity)
        else {
            return PackedInt32Array::new();
        };
        self.core = state;
        [
            result.posture as i32,
            i32::from(result.activity),
            i32::from(result.corrected),
        ]
        .as_slice()
        .into()
    }

    #[func]
    fn status(&self, values: Array<Variant>) -> i32 {
        self.status_checked(&values).unwrap_or(-1)
    }

    #[func]
    fn pilot(
        &self,
        position: Vector3,
        yaw: f64,
        dt: f64,
        drone: PackedVector3Array,
        mounted: PackedFloat64Array,
    ) -> Array<Variant> {
        if drone.len() > 1 {
            return Array::new();
        }
        let mount = match mounted.len() {
            0 => None,
            4 => Some((
                frontline_core::vector::Vector3::new(
                    mounted[0] as f32,
                    mounted[1] as f32,
                    mounted[2] as f32,
                ),
                mounted[3],
            )),
            _ => return Array::new(),
        };
        let Ok(yaw) = control::pilot_yaw(
            crate::point(position),
            yaw,
            dt,
            drone.as_slice().first().copied().map(crate::point),
            mount,
        ) else {
            return Array::new();
        };
        varray![yaw.is_some(), yaw.unwrap_or(0.0)]
    }

    #[func]
    fn checkpoint(&self) -> PackedByteArray {
        self.core.checkpoint().as_slice().into()
    }

    #[func]
    fn restore(&mut self, bytes: PackedByteArray) -> bool {
        let Ok(core) = Control::restore(bytes.as_slice()) else {
            return false;
        };
        self.core = core;
        true
    }
}

impl InfantryControlCore {
    fn status_checked(&self, v: &Array<Variant>) -> Option<i32> {
        if v.len() != 12 {
            return None;
        }
        let ammo: PackedInt32Array = read(v, 1)?;
        let ammunition = match ammo.len() {
            0 => None,
            2 => Some((ammo[0], ammo[1])),
            _ => return None,
        };
        control::flags(Status {
            suppression: read(v, 0)?,
            ammunition,
            time: read(v, 2)?,
            last_shot: read(v, 3)?,
            life: life(read(v, 4)?)?,
            leader: read(v, 5)?,
            at_cover: read(v, 6)?,
            cover_kind: u8::try_from(read::<i32>(v, 7)?).ok()?,
            peeking: read(v, 8)?,
            blind: read(v, 9)?,
            cover_height: read(v, 10)?,
            posture: posture(read(v, 11)?)?,
        })
        .ok()
        .map(i32::from)
    }
}
