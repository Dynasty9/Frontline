use frontline_core::blast::{Blast, Infantry, Protection};
use frontline_core::infantry_pose::Posture;
use frontline_core::infantry_vitals::Life;
use godot::prelude::*;

#[derive(GodotClass)]
#[class(base=RefCounted, init)]
struct BlastCore {
    base: Base<RefCounted>,
    core: Option<Blast>,
}

#[godot_api]
impl BlastCore {
    #[func]
    fn configure(
        &mut self,
        position: Vector3,
        damage: f64,
        radius: f64,
        fling: f64,
        in_trench: bool,
    ) -> bool {
        let core = Blast {
            position: crate::point(position),
            damage,
            radius,
            fling,
            in_trench,
        };
        if !core.valid() {
            return false;
        }
        self.core = Some(core);
        true
    }

    #[func]
    fn infantry(
        &self,
        center: Vector3,
        life: i32,
        posture: i32,
        in_trench: bool,
        terrain_multiplier: f64,
        blocked: bool,
        material: i32,
    ) -> Array<Variant> {
        let (Some(core), Ok(life), Ok(posture)) =
            (self.core, u8::try_from(life), u8::try_from(posture))
        else {
            return Array::new();
        };
        let (Ok(life), Ok(posture)) = (Life::try_from(life), Posture::try_from(posture)) else {
            return Array::new();
        };
        if !(-1..=3).contains(&material) {
            return Array::new();
        }
        let Ok(result) = core.infantry(
            Infantry {
                center: crate::point(center),
                life,
                posture,
                in_trench,
                terrain_multiplier,
            },
            Protection {
                blocked,
                material: (material >= 0).then_some(material as u8),
            },
        ) else {
            return Array::new();
        };
        varray![
            result.damage,
            Vector3::new(result.direction.x, result.direction.y, result.direction.z),
            result.fling,
            result.distance,
            result.flinch_radius,
            result.blocked,
            result.sheltered,
            result.before_posture
        ]
    }

    #[func]
    fn structure(
        &self,
        position: Vector3,
        radius: f64,
        fragile: bool,
        multiplier: f64,
    ) -> Array<Variant> {
        let Some(core) = self.core else {
            return Array::new();
        };
        match core.structure(crate::point(position), radius, fragile, multiplier) {
            Ok(Some(damage)) => varray![damage],
            Ok(None) => varray![&Variant::nil()],
            Err(_) => Array::new(),
        }
    }
}
