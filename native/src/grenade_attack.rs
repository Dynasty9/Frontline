use crate::simulation_random::SimulationRandomCore;
use frontline_core::grenade_attack::{Contact, GrenadeAttack, Input};
use frontline_core::infantry_pose::Posture;
use godot::prelude::*;

#[derive(GodotClass)]
#[class(base=RefCounted, init)]
struct GrenadeAttackCore {
    base: Base<RefCounted>,
    core: GrenadeAttack,
}

fn contacts(rows: &Array<Variant>) -> Option<Vec<Contact>> {
    if rows.len() > 100_000 {
        return None;
    }
    rows.iter_shared()
        .map(|row| {
            let v: Array<Variant> = row.try_to().ok()?;
            if v.len() != 8 {
                return None;
            }
            Some(Contact {
                id: u64::try_from(v.get(0)?.try_to::<i64>().ok()?).ok()?,
                position: crate::point(v.get(1)?.try_to().ok()?),
                alive: v.get(2)?.try_to().ok()?,
                age: v.get(3)?.try_to().ok()?,
                visible: v.get(4)?.try_to().ok()?,
                posture: Posture::try_from(u8::try_from(v.get(5)?.try_to::<i32>().ok()?).ok()?)
                    .ok()?,
                hard_cover: v.get(6)?.try_to().ok()?,
                nearby_allies: u32::try_from(v.get(7)?.try_to::<i64>().ok()?).ok()?,
            })
        })
        .collect()
}

#[godot_api]
impl GrenadeAttackCore {
    #[func]
    fn advance(
        &mut self,
        frags: i32,
        cooldown: f64,
        context: PackedFloat64Array,
        candidates: Array<Variant>,
        mut random: Gd<SimulationRandomCore>,
    ) -> Array<Variant> {
        let v = context.as_slice();
        if v.len() != 8
            || v.iter().any(|x| !x.is_finite())
            || v[5..].iter().any(|x| *x != 0.0 && *x != 1.0)
        {
            return Array::new();
        }
        let Some(contacts) = contacts(&candidates) else {
            return Array::new();
        };
        let i = Input {
            position: frontline_core::vector::Vector3::new(v[0] as f32, v[1] as f32, v[2] as f32),
            time: v[3],
            suppression: v[4],
            squad: v[5] != 0.0,
            ambush: v[6] != 0.0,
            moving: v[7] != 0.0,
        };
        let mut state = GrenadeAttack { frags, cooldown };
        let Ok(result) = state.advance(i, &contacts, &mut random.bind_mut().core) else {
            return Array::new();
        };
        self.core = state;
        if let Some(t) = result {
            varray![
                state.frags,
                state.cooldown,
                t.target as i64,
                Vector3::new(t.position.x, t.position.y, t.position.z),
                t.distance
            ]
        } else {
            varray![state.frags, state.cooldown, 0_i64, Vector3::ZERO, 0.0]
        }
    }

    #[func]
    fn checkpoint(&self) -> PackedByteArray {
        self.core.checkpoint().as_slice().into()
    }

    #[func]
    fn restore(&mut self, bytes: PackedByteArray) -> bool {
        let Ok(s) = GrenadeAttack::restore(bytes.as_slice()) else {
            return false;
        };
        self.core = s;
        true
    }
}
