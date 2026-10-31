use crate::simulation_random::SimulationRandomCore;
use frontline_core::deferred_effects::{DeferredEffects, Rubble};
use frontline_core::projectile_actor::Event;
use godot::prelude::*;

#[derive(GodotClass)]
#[class(base=RefCounted, init)]
pub(crate) struct DeferredEffectsCore {
    base: Base<RefCounted>,
    pub(crate) core: DeferredEffects,
}
#[godot_api]
impl DeferredEffectsCore {
    #[func]
    fn defer_rubble(&mut self, position: Vector3, yaw: f64, size: Vector3) -> bool {
        self.core
            .defer_rubble(Rubble {
                position: crate::point(position),
                yaw,
                size: crate::point(size),
            })
            .is_ok()
    }
    #[func]
    fn take_rubble(&mut self) -> Array<Variant> {
        self.core
            .take_rubble()
            .into_iter()
            .map(|r| {
                varray![
                    Vector3::new(r.position.x, r.position.y, r.position.z),
                    r.yaw,
                    Vector3::new(r.size.x, r.size.y, r.size.z)
                ]
                .to_variant()
            })
            .collect()
    }
    #[func]
    fn cook_off(
        &mut self,
        now: f64,
        position: Vector3,
        supply: f64,
        mut rng: Gd<SimulationRandomCore>,
    ) -> i32 {
        self.core
            .cook_off(
                now,
                crate::point(position),
                supply,
                &mut rng.bind_mut().core,
            )
            .map_or(-1, |n| n as i32)
    }
    #[func]
    fn advance_to(&mut self, now: f64) -> Array<Variant> {
        match self.core.advance_to(now) {
            Ok(events) => varray![&crate::projectile_actor::events(
                events.into_iter().map(Event::Explosion).collect()
            )],
            Err(_) => Array::new(),
        }
    }
    #[func]
    fn pending(&self) -> Array<Variant> {
        self.core
            .pending()
            .map(|(time, sequence, e)| {
                varray![
                    time,
                    sequence as i64,
                    &crate::projectile_actor::events(vec![Event::Explosion(e)])
                ]
                .to_variant()
            })
            .collect()
    }
    #[func]
    fn checkpoint(&self) -> PackedByteArray {
        self.core.checkpoint().as_slice().into()
    }
    #[func]
    fn restore(&mut self, bytes: PackedByteArray) -> bool {
        let Ok(q) = DeferredEffects::restore(bytes.as_slice()) else {
            return false;
        };
        self.core = q;
        true
    }
}
