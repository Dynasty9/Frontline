use frontline_core::collision::{BoxShape, CollisionWorld, Mat3};
use frontline_core::cover::{self, Anchor, AnchorKind};
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
    fn evaluate_cover(
        &mut self,
        position: Vector3,
        normal: Vector3,
        height: f64,
        kind: i64,
        ground: f64,
        threats: PackedVector3Array,
        prone: bool,
    ) -> PackedFloat64Array {
        let kind = match kind {
            1 => AnchorKind::Over,
            2 => AnchorKind::EdgeLeft,
            3 => AnchorKind::EdgeRight,
            4 => AnchorKind::Shelter,
            5 => AnchorKind::Stack,
            _ => {
                godot_error!("Invalid cover anchor kind");
                return PackedFloat64Array::new();
            }
        };
        if threats.len() > 4096 {
            godot_error!("Too many cover threats");
            return PackedFloat64Array::new();
        }
        let threats: Vec<_> = threats
            .as_slice()
            .iter()
            .copied()
            .map(crate::point)
            .collect();
        let anchor = Anchor {
            position: crate::point(position),
            normal: crate::point(normal),
            height,
            kind,
        };
        match cover::evaluate(&mut self.core, anchor, ground, &threats, prone) {
            Ok(Some(value)) => PackedFloat64Array::from(&[
                value.kind as u8 as f64,
                value.protection,
                f64::from(value.fire),
                value.lean.x as f64,
                value.lean.y as f64,
                value.lean.z as f64,
                value.threat_direction.x as f64,
                value.threat_direction.y as f64,
                value.threat_direction.z as f64,
            ]),
            Ok(None) => PackedFloat64Array::new(),
            Err(message) => {
                godot_error!("{message}");
                PackedFloat64Array::new()
            }
        }
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
