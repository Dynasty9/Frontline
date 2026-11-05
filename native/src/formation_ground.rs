use godot::prelude::*;

#[derive(GodotClass)]
#[class(base=RefCounted, init)]
struct FormationGround {
    base: Base<RefCounted>,
    core: frontline_core::formation::FormationGround,
}

#[godot_api]
impl FormationGround {
    #[func]
    fn prepare(&mut self, positions: PackedVector3Array, scores: PackedFloat64Array) -> bool {
        let points = positions.as_slice().iter().map(|p| crate::point(*p));
        self.core.prepare(points, scores.as_slice())
    }

    #[func]
    fn add_taken(&mut self, point: Vector3) {
        self.core.add_taken(crate::point(point));
    }

    #[func]
    fn best(&self, point: Vector3) -> PackedFloat64Array {
        PackedFloat64Array::from(&self.core.best(crate::point(point)))
    }
}
