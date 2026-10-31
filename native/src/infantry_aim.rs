use crate::collision_index::CollisionIndexCore;
use crate::simulation_random::SimulationRandomCore;
use crate::visibility::VisibilityCore;
use frontline_core::infantry_aim::{AimInput, InfantryAim, Target, TargetKind};
use godot::prelude::*;

#[derive(GodotClass)]
#[class(base=RefCounted, init)]
struct InfantryAimCore {
    base: Base<RefCounted>,
    core: InfantryAim,
}

fn read<T: FromGodot>(values: &Array<Variant>, i: usize) -> Option<T> {
    values.get(i)?.try_to::<T>().ok()
}

fn optional_point(
    values: &Array<Variant>,
    i: usize,
) -> Option<Option<frontline_core::vector::Vector3>> {
    let value = values.get(i)?;
    if value.is_nil() {
        Some(None)
    } else {
        Some(Some(crate::point(value.try_to::<Vector3>().ok()?)))
    }
}

fn read_target<'a>(
    target: &Array<Variant>,
    points: &'a [frontline_core::vector::Vector3],
    excluded: &'a [i64],
) -> Option<Target<'a>> {
    if target.len() != 6 || points.len() > 256 || excluded.len() > 4096 {
        return None;
    }
    Some(Target {
        id: u64::try_from(read::<i64>(target, 0)?).ok()?,
        kind: match read::<i32>(target, 1)? {
            0 => TargetKind::Other,
            1 => TargetKind::Infantry {
                over_cover: read(target, 2)?,
                cover_height: read(target, 3)?,
            },
            2 => TargetKind::Drone,
            3 => TargetKind::Structure,
            _ => return None,
        },
        position: crate::point(read(target, 4)?),
        center: crate::point(read(target, 5)?),
        points,
        excluded,
    })
}

#[godot_api]
impl InfantryAimCore {
    #[func]
    fn aim_point(
        &self,
        target: Array<Variant>,
        points: PackedVector3Array,
        mut rng: Gd<SimulationRandomCore>,
    ) -> Variant {
        if points.len() > 256 {
            return Variant::nil();
        }
        let points: Vec<_> = points.as_slice().iter().map(|p| crate::point(*p)).collect();
        let Some(target) = read_target(&target, &points, &[]) else {
            return Variant::nil();
        };
        let Ok(point) = target.aim_point(&mut rng.bind_mut().core) else {
            return Variant::nil();
        };
        Vector3::new(point.x, point.y, point.z).to_variant()
    }

    #[func]
    fn checkpoint(&self) -> PackedByteArray {
        self.core.checkpoint().as_slice().into()
    }

    #[func]
    fn restore(&mut self, bytes: PackedByteArray) -> bool {
        let Ok(core) = InfantryAim::restore(bytes.as_slice()) else {
            return false;
        };
        self.core = core;
        true
    }

    #[func]
    fn choose(
        &mut self,
        mut collision: Gd<CollisionIndexCore>,
        mut visibility: Gd<VisibilityCore>,
        mut rng: Gd<SimulationRandomCore>,
        state: Array<Variant>,
        inputs: Array<Variant>,
        target: Array<Variant>,
        points: PackedVector3Array,
        excluded: PackedInt64Array,
    ) -> Array<Variant> {
        self.choose_checked(
            &mut collision,
            &mut visibility,
            &mut rng,
            &state,
            &inputs,
            &target,
            &points,
            &excluded,
        )
        .unwrap_or_default()
    }
}

impl InfantryAimCore {
    #[allow(clippy::too_many_arguments)]
    fn choose_checked(
        &mut self,
        collision: &mut Gd<CollisionIndexCore>,
        visibility: &mut Gd<VisibilityCore>,
        rng: &mut Gd<SimulationRandomCore>,
        state: &Array<Variant>,
        inputs: &Array<Variant>,
        target: &Array<Variant>,
        points: &PackedVector3Array,
        excluded: &PackedInt64Array,
    ) -> Option<Array<Variant>> {
        if state.len() != 3
            || inputs.len() != 8
            || (!target.is_empty() && target.len() != 6)
            || points.len() > 256
            || excluded.len() > 4096
        {
            return None;
        }
        let mut core = InfantryAim {
            sight_target: u64::try_from(read::<i64>(state, 0)?).ok()?,
            sight_until: read(state, 1)?,
            visible: read(state, 2)?,
        };
        let points: Vec<_> = points.as_slice().iter().map(|p| crate::point(*p)).collect();
        let target = if target.is_empty() {
            None
        } else {
            Some(read_target(target, &points, excluded.as_slice())?)
        };
        let input = AimInput {
            time: read(inputs, 0)?,
            position: crate::point(read(inputs, 1)?),
            eye: crate::point(read(inputs, 2)?),
            target,
            blind: read(inputs, 3)?,
            cache_obstruction: read(inputs, 4)?,
            cover_fire: optional_point(inputs, 5)?,
            last_known: optional_point(inputs, 6)?,
            weapon_range: read(inputs, 7)?,
        };
        let result = core
            .choose(
                input,
                &mut collision.bind_mut().core,
                &mut visibility.bind_mut().core,
                &mut rng.bind_mut().core,
            )
            .ok()?;
        self.core = core;
        Some(varray![
            &result
                .point
                .map_or_else(Variant::nil, |p| Vector3::new(p.x, p.y, p.z).to_variant()),
            result.target as i64,
            core.sight_target as i64,
            core.sight_until,
            core.visible,
            result.reused_obstruction,
        ])
    }
}
