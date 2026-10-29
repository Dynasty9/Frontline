use godot::prelude::*;

#[derive(GodotClass)]
#[class(base=RefCounted, init)]
pub struct RouteGraph {
    base: Base<RefCounted>,
    #[init(val = frontline_core::route_graph::RouteGraph::new())]
    core: frontline_core::route_graph::RouteGraph,
}

#[godot_api]
impl RouteGraph {
    #[func]
    fn add_point(&mut self, id: i64, position: Vector3, weight: f64) {
        self.core.add_point(id, crate::point(position), weight);
    }
    #[func]
    fn connect_points(&mut self, a: i64, b: i64) {
        self.core.connect_points(a, b);
    }
    #[func]
    fn remove_point(&mut self, id: i64) {
        self.core.remove_point(id);
    }
    #[func]
    fn has_point(&self, id: i64) -> bool {
        self.core.has_point(id)
    }
    #[func]
    fn get_point_count(&self) -> i64 {
        self.core.get_point_count()
    }
    #[func]
    fn get_point_position(&self, id: i64) -> Vector3 {
        let p = self.core.get_point_position(id);
        Vector3::new(p.x, p.y, p.z)
    }
    #[func]
    fn set_point_weight_scale(&mut self, id: i64, weight: f64) {
        self.core.set_point_weight_scale(id, weight);
    }
    #[func]
    fn get_id_path(&mut self, from: i64, to: i64) -> PackedInt64Array {
        self.core.get_id_path(from, to).into_iter().collect()
    }
}
