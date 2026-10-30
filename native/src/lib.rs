use godot::prelude::*;

mod collision_index;
mod cover_geometry;
mod drone_flight;
mod formation_ground;
mod guided_flight;
mod hierarchy;
mod infantry_motion;
mod infantry_weapon;
mod navigation_grid;
mod path_planner;
mod projectile_flight;
mod route_graph;
mod simulation_random;
mod support_flight;
mod terrain;
mod visibility;
mod water_raster;

struct FrontlineSimulation;
#[gdextension]
unsafe impl ExtensionLibrary for FrontlineSimulation {}

fn point(p: Vector3) -> frontline_core::vector::Vector3 {
    frontline_core::vector::Vector3::new(p.x, p.y, p.z)
}

#[derive(GodotClass)]
#[class(base=RefCounted, init)]
struct PerceptionSearch {
    base: Base<RefCounted>,
    core: frontline_core::perception::PerceptionSearch,
}

#[godot_api]
impl PerceptionSearch {
    #[func]
    fn rebuild(&mut self, meta: PackedInt32Array, values: PackedFloat64Array) -> bool {
        self.core.rebuild(meta.as_slice(), values.as_slice())
    }

    #[func]
    fn nearest(&self, x: f64, z: f64, team: i32, sight: f64) -> PackedInt32Array {
        self.core.nearest(x, z, team, sight).into_iter().collect()
    }
}
