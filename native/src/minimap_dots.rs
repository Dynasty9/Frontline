use godot::prelude::*;

#[derive(GodotClass)]
#[class(base=RefCounted, init)]
struct MinimapDots {
    base: Base<RefCounted>,
    buffer: Vec<f32>,
}

#[godot_api]
impl MinimapDots {
    #[func]
    fn encode(
        &mut self,
        points: PackedVector3Array,
        colors: PackedColorArray,
        capacity: i32,
    ) -> PackedFloat32Array {
        if points.len() != colors.len()
            || points.len() > 100_000
            || capacity < 0
            || capacity > 262_144
            || (capacity as usize) < points.len() * 2
            || points
                .as_slice()
                .iter()
                .any(|p| !p.is_finite() || !(0.0..=64.0).contains(&p.z))
            || colors
                .as_slice()
                .iter()
                .any(|c| [c.r, c.g, c.b, c.a].iter().any(|v| !v.is_finite()))
        {
            return PackedFloat32Array::new();
        }
        self.buffer.clear();
        for (p, c) in points.as_slice().iter().zip(colors.as_slice()) {
            // Preserve the border/fill and soldier order when translucent dots overlap.
            for (radius, color) in [
                (p.z + 0.9, Color::from_rgba(0.0, 0.0, 0.0, 0.65)),
                (p.z, *c),
            ] {
                self.buffer.extend_from_slice(&[
                    radius, 0.0, 0.0, p.x, 0.0, radius, 0.0, p.y, color.r, color.g, color.b,
                    color.a,
                ]);
            }
        }
        self.buffer.resize(capacity as usize * 12, 0.0);
        PackedFloat32Array::from(self.buffer.as_slice())
    }
}
