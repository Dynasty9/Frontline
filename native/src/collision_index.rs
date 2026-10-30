use frontline_core::collision::{BoxShape, CollisionWorld, Mat3};
use godot::prelude::*;

#[derive(GodotClass)]
#[class(base=RefCounted, init)]
pub(crate) struct CollisionIndexCore {
    base: Base<RefCounted>,
    pub(crate) core: CollisionWorld,
}

#[godot_api]
impl CollisionIndexCore {
    #[func]
    fn checkpoint(&self) -> PackedByteArray {
        self.core.checkpoint().as_slice().into()
    }

    #[func]
    fn restore(&mut self, bytes: PackedByteArray) -> bool {
        let Ok(core) = CollisionWorld::restore(bytes.as_slice()) else {
            return false;
        };
        self.core = core;
        true
    }

    #[func]
    fn replace_body(&mut self, body: i64, rows: PackedFloat32Array) -> bool {
        let data = rows.as_slice();
        if data.len() % 16 != 0 || !data.iter().all(|v| v.is_finite()) {
            return false;
        }
        let mut shapes = Vec::with_capacity(data.len() / 16);
        for row in data.chunks_exact(16) {
            if row[15] < 0.0 || row[15] > 1_000_000.0 || row[15].fract() != 0.0 {
                return false;
            }
            let point = |i| frontline_core::vector::Vector3::new(row[i], row[i + 1], row[i + 2]);
            shapes.push(BoxShape {
                body,
                shape: row[15] as i32,
                center: point(0),
                basis: Mat3::from_cols(point(3), point(6), point(9)),
                half: point(12),
            });
        }
        self.core.replace(body, &shapes)
    }

    #[func]
    fn remove_body(&mut self, body: i64) {
        self.core.remove(body);
    }

    #[func]
    fn ray(
        &mut self,
        from: Vector3,
        to: Vector3,
        excluded: PackedInt64Array,
    ) -> PackedFloat64Array {
        let Some(hit) = self
            .core
            .ray(crate::point(from), crate::point(to), excluded.as_slice())
        else {
            return PackedFloat64Array::new();
        };
        PackedFloat64Array::from(&[
            hit.body as f64,
            hit.shape as f64,
            hit.position.x as f64,
            hit.position.y as f64,
            hit.position.z as f64,
            hit.normal.x as f64,
            hit.normal.y as f64,
            hit.normal.z as f64,
        ])
    }
}
