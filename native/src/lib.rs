use godot::prelude::*;

mod actors;
mod blast;
mod breach;
mod bullet;
mod collision_index;
mod cover_geometry;
mod cover_search;
mod drone_flight;
mod drone_reaction;
mod entities;
mod formation_ground;
mod grenade_attack;
mod grenade_reaction;
mod guided_flight;
mod hierarchy;
mod infantry;
mod infantry_action;
mod infantry_aim;
mod infantry_arsenal;
mod infantry_control;
mod infantry_controller;
mod infantry_duties;
mod infantry_idle;
mod infantry_medicine;
mod infantry_motion;
mod infantry_mount;
mod infantry_pose;
mod infantry_shock;
mod infantry_supply;
mod infantry_vitals;
mod infantry_weapon;
mod navigation_grid;
mod path_planner;
mod projectile_actor;
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
