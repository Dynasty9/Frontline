use frontline_core::drone::DroneFlight;
use godot::prelude::*;

#[derive(GodotClass)]
#[class(base=RefCounted, init)]
struct DroneFlightCore {
    base: Base<RefCounted>,
    core: Option<DroneFlight>,
}

#[godot_api]
impl DroneFlightCore {
    #[func]
    fn reset(&mut self, position: Vector3, yaw: f64) -> bool {
        if !position.is_finite() || !(yaw as f32).is_finite() {
            return false;
        }
        self.core = Some(DroneFlight::new(crate::point(position), yaw as f32));
        true
    }

    #[func]
    fn lose_control(&mut self) {
        if let Some(core) = self.core.as_mut() {
            core.lose_control();
        }
    }

    #[func]
    fn destroy(&mut self) {
        if let Some(core) = self.core.as_mut() {
            core.dead = true;
        }
    }

    #[func]
    fn checkpoint(&self) -> PackedByteArray {
        self.core.map_or_else(PackedByteArray::new, |core| {
            core.checkpoint().as_slice().into()
        })
    }

    #[func]
    fn restore(&mut self, bytes: PackedByteArray) -> bool {
        let Ok(core) = DroneFlight::restore(bytes.as_slice()) else {
            return false;
        };
        self.core = Some(core);
        true
    }

    #[func]
    fn advance(
        &mut self,
        dt: f64,
        target_valid: bool,
        target: Vector3,
        mut collision: Gd<crate::collision_index::CollisionIndexCore>,
        map_half: f64,
    ) -> PackedFloat64Array {
        if !dt.is_finite()
            || dt < 0.0
            || !target.is_finite()
            || !(map_half as f32).is_finite()
            || map_half <= 0.0
        {
            return PackedFloat64Array::new();
        }
        let Some(core) = self.core.as_mut() else {
            return PackedFloat64Array::new();
        };
        let detonate = core.advance(
            dt,
            target_valid.then(|| crate::point(target)),
            &mut collision.bind_mut().core,
            map_half as f32,
        );
        let p = core.position;
        let v = core.velocity;
        let t = core.target;
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
            core.phase as u8 as f64,
            f64::from(u8::from(core.diving)),
            core.yaw as f64,
            f64::from(u8::from(core.dead)),
            f64::from(u8::from(detonate)),
        ])
    }
}
