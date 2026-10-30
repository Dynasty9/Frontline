use frontline_core::guided::{GuidedFlight, Kind};
use godot::prelude::*;

#[derive(GodotClass)]
#[class(base=RefCounted, init)]
struct GuidedFlightCore {
    base: Base<RefCounted>,
    core: Option<GuidedFlight>,
}

#[godot_api]
impl GuidedFlightCore {
    #[func]
    fn reset(
        &mut self,
        anti_tank: bool,
        position: Vector3,
        velocity: Vector3,
        target: Vector3,
        life: f64,
        locked: bool,
    ) -> bool {
        if !position.is_finite()
            || !velocity.is_finite()
            || !target.is_finite()
            || !life.is_finite()
        {
            return false;
        }
        self.core = Some(GuidedFlight {
            kind: if anti_tank {
                Kind::AntiTank
            } else {
                Kind::SurfaceToAir
            },
            position: crate::point(position),
            velocity: crate::point(velocity),
            target: crate::point(target),
            life,
            locked,
            dead: false,
        });
        true
    }

    #[func]
    fn checkpoint(&self) -> PackedByteArray {
        self.core.map_or_else(PackedByteArray::new, |core| {
            core.checkpoint().as_slice().into()
        })
    }

    #[func]
    fn restore(&mut self, bytes: PackedByteArray) -> bool {
        let Ok(core) = GuidedFlight::restore(bytes.as_slice()) else {
            return false;
        };
        self.core = Some(core);
        true
    }

    #[func]
    fn checks_smoke(&self, dt: f64) -> bool {
        self.core
            .as_ref()
            .is_some_and(|c| dt.is_finite() && dt >= 0.0 && c.checks_smoke(dt))
    }

    #[func]
    fn advance(
        &mut self,
        dt: f64,
        target_valid: bool,
        target: Vector3,
        smoke: bool,
        mut collision: Gd<crate::collision_index::CollisionIndexCore>,
        excluded: PackedInt64Array,
    ) -> PackedFloat64Array {
        if !dt.is_finite() || dt < 0.0 || !target.is_finite() {
            return PackedFloat64Array::new();
        }
        let Some(core) = self.core.as_mut() else {
            return PackedFloat64Array::new();
        };
        let impact = core.advance(
            dt,
            target_valid.then(|| crate::point(target)),
            smoke,
            &mut collision.bind_mut().core,
            excluded.as_slice(),
        );
        let p = core.position;
        let v = core.velocity;
        let t = core.target;
        let hit = impact.map_or(frontline_core::vector::Vector3::ZERO, |i| i.position);
        PackedFloat64Array::from(&[
            p.x as f64,
            p.y as f64,
            p.z as f64,
            v.x as f64,
            v.y as f64,
            v.z as f64,
            t.x as f64,
            t.y as f64,
            t.z as f64,
            core.life,
            f64::from(u8::from(core.locked)),
            f64::from(u8::from(impact.is_some())),
            hit.x as f64,
            hit.y as f64,
            hit.z as f64,
            f64::from(u8::from(impact.is_some_and(|i| i.proximity))),
        ])
    }
}
