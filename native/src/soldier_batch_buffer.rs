use godot::prelude::*;

#[derive(GodotClass)]
#[class(base=RefCounted, init)]
pub(crate) struct SoldierBatchBuffer {
    base: Base<RefCounted>,
    data: Vec<f32>,
    bounds: Option<Aabb>,
}

#[godot_api]
impl SoldierBatchBuffer {
    #[func]
    fn clear(&mut self) {
        self.data.clear();
        self.bounds = None;
    }

    #[func]
    pub(crate) fn append(
        &mut self,
        transform: Transform3D,
        offset: Vector3,
        turn: f64,
        pose: i32,
        radius: f64,
    ) -> bool {
        if !transform.is_finite()
            || !offset.is_finite()
            || !turn.is_finite()
            || !(0..=255).contains(&pose)
            || !radius.is_finite()
            || radius < 0.0
            || self.data.len() >= 100_000 * 20
        {
            return false;
        }
        let [x, y, z] = transform.basis.rows;
        let p = transform.origin;
        let scale = transform.basis.get_scale().abs();
        let radius = (radius * f64::from(scale.x.max(scale.y).max(scale.z))) as f32;
        let turn = turn as f32;
        if !radius.is_finite() || !turn.is_finite() || !(p + offset).is_finite() {
            return false;
        }
        // MultiMesh stores three transform rows, tint/pose, then shader motion data.
        self.data.extend_from_slice(&[
            x.x,
            x.y,
            x.z,
            p.x,
            y.x,
            y.y,
            y.z,
            p.y,
            z.x,
            z.y,
            z.z,
            p.z,
            1.0,
            1.0,
            1.0,
            pose as f32 / 255.0,
            offset.x,
            offset.y,
            offset.z,
            turn,
        ]);
        // The shader moves and turns the whole pose between snapshots.
        let swept = Aabb::new(p, Vector3::ZERO).expand(p + offset).grow(radius);
        self.bounds = Some(self.bounds.map_or(swept, |previous| previous.merge(swept)));
        true
    }

    #[func]
    pub(crate) fn encode(&self, capacity: i32) -> PackedFloat32Array {
        if !(0..=262_144).contains(&capacity) || capacity as usize * 20 < self.data.len() {
            return PackedFloat32Array::new();
        }
        let mut buffer = PackedFloat32Array::from(self.data.as_slice());
        buffer.resize(capacity as usize * 20);
        buffer
    }

    #[func]
    pub(crate) fn bounds(&self) -> Aabb {
        self.bounds.unwrap_or_default()
    }
}
