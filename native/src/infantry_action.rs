use frontline_core::infantry_action::{
    Action, ActionState, Context, Gesture, Related, Round, Throw,
};
use godot::prelude::*;

#[derive(GodotClass)]
#[class(base=RefCounted, init)]
struct InfantryActionCore {
    base: Base<RefCounted>,
    core: ActionState,
}

fn read<T: FromGodot>(row: &Array<Variant>, index: usize) -> Option<T> {
    row.get(index)?.try_to::<T>().ok()
}

fn round(row: &Array<Variant>) -> Option<Round> {
    match read::<i32>(row, 2)? {
        0 => Some(Round::Frag),
        1 => Some(Round::Smoke),
        2 => Some(Round::HighExplosive),
        _ => None,
    }
}
fn throw(row: &Array<Variant>) -> Option<Throw> {
    if row.len() != 5 {
        return None;
    }
    let t = Throw {
        position: crate::point(read(row, 1)?),
        round: round(row)?,
        fuse: read(row, 3)?,
    };
    t.valid().then_some(t)
}
pub(crate) fn state(values: &Array<Variant>) -> Option<ActionState> {
    if values.len() != 4 {
        return None;
    }
    let kind: i32 = read(values, 0)?;
    let payload: Array<Variant> = read(values, 2)?;
    let queued: Array<Variant> = read(values, 3)?;
    if payload.len() != 5 {
        return None;
    }
    let entity = u64::try_from(read::<i64>(&payload, 0)?).ok()?;
    let position = crate::point(read(&payload, 1)?);
    let current = match kind {
        0 => Action::None,
        1 => Action::Throw(throw(&payload)?),
        2 => Action::Rethrow {
            grenade: entity,
            position,
        },
        3 => Action::ThrowIn {
            position,
            fuse: read(&payload, 3)?,
        },
        4 => Action::Kick {
            grenade: entity,
            velocity: crate::point(read(&payload, 4)?),
        },
        5 => Action::DoorKick {
            door: entity,
            position,
        },
        6 => Action::Cook,
        7 => Action::Melee { target: entity },
        8 => Action::Pickup { grenade: entity },
        9 => Action::Launch { target: entity },
        10 => Action::LaunchDrone { target: entity },
        11 => Action::Mortar {
            position,
            round: round(&payload)?,
        },
        _ => return None,
    };
    let state = ActionState {
        current,
        remaining: read(values, 1)?,
        queued_throw: if queued.is_empty() {
            None
        } else {
            Some(throw(&queued)?)
        },
    };
    state.valid().then_some(state)
}
fn context(actor: i64, position: Vector3, related: &Array<Variant>) -> Option<Context> {
    let related = if related.is_empty() {
        None
    } else {
        if related.len() != 4 {
            return None;
        }
        Some(Related {
            id: u64::try_from(read::<i64>(related, 0)?).ok()?,
            position: crate::point(read(related, 1)?),
            gone: read(related, 2)?,
            holder: u64::try_from(read::<i64>(related, 3)?).ok()?,
        })
    };
    Some(Context {
        actor: u64::try_from(actor).ok()?,
        position: crate::point(position),
        related,
    })
}

#[godot_api]
impl InfantryActionCore {
    #[func]
    fn start_pose(
        &mut self,
        values: Array<Variant>,
        actor: i64,
        position: Vector3,
        related: Array<Variant>,
    ) -> Array<Variant> {
        let Some(state) = state(&values) else {
            return Array::new();
        };
        let Some(context) = context(actor, position, &related) else {
            return Array::new();
        };
        let Ok(yaw) = state.current.begin_yaw(context) else {
            return Array::new();
        };
        self.core = state;
        let gesture = match state.current.gesture() {
            None => 0,
            Some(Gesture::Throw) => 1,
            Some(Gesture::Kick) => 2,
            Some(Gesture::Cook) => 3,
            Some(Gesture::Melee) => 4,
            Some(Gesture::Pickup) => 5,
            Some(Gesture::Launch) => 6,
        };
        varray![gesture, &yaw.map_or_else(Variant::nil, |y| y.to_variant())]
    }

    #[func]
    fn pose(
        &mut self,
        values: Array<Variant>,
        actor: i64,
        position: Vector3,
        related: Array<Variant>,
    ) -> Array<Variant> {
        let Some(state) = state(&values) else {
            return Array::new();
        };
        let Some(context) = context(actor, position, &related) else {
            return Array::new();
        };
        let Ok(pose) = state.current.pose(context) else {
            return Array::new();
        };
        self.core = state;
        varray![
            pose.posture.map_or(-1, |p| p as i32),
            &pose.yaw.map_or_else(Variant::nil, |y| y.to_variant())
        ]
    }

    #[func]
    fn finish(
        &mut self,
        values: Array<Variant>,
        actor: i64,
        position: Vector3,
        related: Array<Variant>,
    ) -> PackedInt32Array {
        let Some(mut state) = state(&values) else {
            return PackedInt32Array::new();
        };
        let Some(context) = context(actor, position, &related) else {
            return PackedInt32Array::new();
        };
        let Ok(result) = state.finish(context) else {
            return PackedInt32Array::new();
        };
        self.core = state;
        [
            i32::from(result.effect != Action::None),
            i32::from(result.begin_throw),
            i32::from(result.duck_after),
        ]
        .as_slice()
        .into()
    }

    #[func]
    fn checkpoint(&self) -> PackedByteArray {
        self.core.checkpoint().as_slice().into()
    }

    #[func]
    fn restore(&mut self, bytes: PackedByteArray) -> bool {
        let Ok(core) = ActionState::restore(bytes.as_slice()) else {
            return false;
        };
        self.core = core;
        true
    }
}
