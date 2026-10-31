use crate::collision_index::CollisionIndexCore;
use crate::simulation_random::SimulationRandomCore;
use crate::visibility::VisibilityCore;
use frontline_core::infantry_arsenal::{
    InfantryArsenal, MeleeContact, MortarDecision, MortarTarget, RocketContact, RocketInput,
};
use frontline_core::infantry_vitals::Life;
use godot::prelude::*;

#[derive(GodotClass)]
#[class(base=RefCounted, init)]
struct InfantryArsenalCore {
    base: Base<RefCounted>,
    core: InfantryArsenal,
}

pub(crate) fn state(v: &Array<Variant>) -> Option<InfantryArsenal> {
    if v.len() != 7 {
        return None;
    }
    let s = InfantryArsenal {
        rockets: v.get(0)?.try_to().ok()?,
        rocket_ready: v.get(1)?.try_to().ok()?,
        drones: v.get(2)?.try_to().ok()?,
        drone_ready: v.get(3)?.try_to().ok()?,
        mortar_rounds: v.get(4)?.try_to().ok()?,
        mortar_ready: v.get(5)?.try_to().ok()?,
        melee_ready: v.get(6)?.try_to().ok()?,
    };
    s.valid().then_some(s)
}
pub(crate) fn encode(s: InfantryArsenal) -> Array<Variant> {
    varray![
        s.rockets,
        s.rocket_ready,
        s.drones,
        s.drone_ready,
        s.mortar_rounds,
        s.mortar_ready,
        s.melee_ready
    ]
}
fn rocket_contact(v: &Array<Variant>) -> Option<RocketContact> {
    if v.len() != 6 {
        return None;
    }
    let excluded: PackedInt64Array = v.get(5)?.try_to().ok()?;
    if excluded.len() > 4096 {
        return None;
    }
    Some(RocketContact {
        id: u64::try_from(v.get(0)?.try_to::<i64>().ok()?).ok()?,
        position: crate::point(v.get(1)?.try_to().ok()?),
        center: crate::point(v.get(2)?.try_to().ok()?),
        gone: v.get(3)?.try_to().ok()?,
        age: v.get(4)?.try_to().ok()?,
        excluded: excluded.as_slice().to_vec(),
    })
}
fn rocket_contacts(rows: &Array<Variant>) -> Option<Vec<RocketContact>> {
    if rows.len() > 100_000 {
        return None;
    }
    rows.iter_shared()
        .map(|v| rocket_contact(&v.try_to().ok()?))
        .collect()
}

#[godot_api]
impl InfantryArsenalCore {
    #[func]
    fn rocket(
        &mut self,
        values: Array<Variant>,
        context: Array<Variant>,
        visible: Array<Variant>,
        reported: Array<Variant>,
        forced: Array<Variant>,
        mut collision: Gd<CollisionIndexCore>,
        visibility: Gd<VisibilityCore>,
    ) -> Array<Variant> {
        self.rocket_checked(
            &values,
            &context,
            &visible,
            &reported,
            &forced,
            &mut collision,
            &visibility,
        )
        .unwrap_or_default()
    }

    #[func]
    fn melee(
        &mut self,
        values: Array<Variant>,
        now: f64,
        team: i32,
        armed: bool,
        nearby: Array<Variant>,
    ) -> Array<Variant> {
        let Some(mut state) = state(&values) else {
            return Array::new();
        };
        if nearby.len() > 100_000 {
            return Array::new();
        }
        let nearby = nearby
            .iter_shared()
            .map(|v| {
                let v: Array<Variant> = v.try_to().ok()?;
                if v.len() != 4 {
                    return None;
                }
                Some(MeleeContact {
                    id: u64::try_from(v.get(0)?.try_to::<i64>().ok()?).ok()?,
                    team: v.get(1)?.try_to().ok()?,
                    life: Life::try_from(u8::try_from(v.get(2)?.try_to::<i32>().ok()?).ok()?)
                        .ok()?,
                    flinging: v.get(3)?.try_to().ok()?,
                })
            })
            .collect::<Option<Vec<_>>>();
        let Some(nearby) = nearby else {
            return Array::new();
        };
        let Ok(target) = state.melee(now, team, armed, &nearby) else {
            return Array::new();
        };
        self.core = state;
        varray![&encode(state), target.unwrap_or(0) as i64]
    }

    #[func]
    fn drone(
        &mut self,
        values: Array<Variant>,
        now: f64,
        controlling: bool,
        target: i64,
        mut random: Gd<SimulationRandomCore>,
    ) -> Array<Variant> {
        let Some(mut state) = state(&values) else {
            return Array::new();
        };
        let Ok(target) = u64::try_from(target) else {
            return Array::new();
        };
        let Ok(result) = state.drone(
            now,
            controlling,
            (target != 0).then_some(target),
            &mut random.bind_mut().core,
        ) else {
            return Array::new();
        };
        self.core = state;
        varray![&encode(state), result.unwrap_or(0) as i64]
    }

    #[func]
    fn mortar(
        &mut self,
        values: Array<Variant>,
        now: f64,
        position: Vector3,
        moving: bool,
        squad: bool,
        queued: bool,
        target: Variant,
    ) -> Array<Variant> {
        let Some(mut state) = state(&values) else {
            return Array::new();
        };
        let p = if target.is_nil() {
            None
        } else {
            let Ok(p) = target.try_to::<Vector3>() else {
                return Array::new();
            };
            Some(crate::point(p))
        };
        let target = if queued {
            let Some(p) = p else {
                return Array::new();
            };
            MortarTarget::Queued(p)
        } else {
            MortarTarget::Automatic(p)
        };
        let Ok(result) = state.mortar(now, crate::point(position), moving, squad, target) else {
            return Array::new();
        };
        self.core = state;
        varray![
            &encode(state),
            match result {
                MortarDecision::Wait => 0,
                MortarDecision::CancelQueue => 1,
                MortarDecision::Fire(_) => 2,
            }
        ]
    }

    #[func]
    fn checkpoint(&self) -> PackedByteArray {
        self.core.checkpoint().as_slice().into()
    }

    #[func]
    fn restore(&mut self, bytes: PackedByteArray) -> bool {
        let Ok(state) = InfantryArsenal::restore(bytes.as_slice()) else {
            return false;
        };
        self.core = state;
        true
    }
}

impl InfantryArsenalCore {
    #[allow(clippy::too_many_arguments)]
    fn rocket_checked(
        &mut self,
        values: &Array<Variant>,
        context: &Array<Variant>,
        visible: &Array<Variant>,
        reported: &Array<Variant>,
        forced: &Array<Variant>,
        collision: &mut Gd<CollisionIndexCore>,
        visibility: &Gd<VisibilityCore>,
    ) -> Option<Array<Variant>> {
        let mut state = state(values)?;
        if context.len() != 4 {
            return None;
        }
        let visible = rocket_contacts(visible)?;
        let reported = rocket_contacts(reported)?;
        let forced = if forced.is_empty() {
            None
        } else {
            Some(rocket_contact(forced)?)
        };
        let result = state
            .rocket(
                RocketInput {
                    time: context.get(0)?.try_to().ok()?,
                    position: crate::point(context.get(1)?.try_to().ok()?),
                    eye: crate::point(context.get(2)?.try_to().ok()?),
                    ambush: context.get(3)?.try_to().ok()?,
                    visible: &visible,
                    reported: &reported,
                    forced,
                },
                &mut collision.bind_mut().core,
                &visibility.bind().core,
            )
            .ok()?;
        self.core = state;
        Some(varray![&encode(state), result.unwrap_or(0) as i64])
    }
}
