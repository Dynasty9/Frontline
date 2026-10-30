//! Engine-independent simulation code. No scene objects, wall clock or global RNG.
/// Pinned scalar math and geometry rules; incompatible checkpoints must fail closed.
pub const NUMERIC_VERSION: u16 = 1;
pub mod collision;
pub mod cover;
pub mod drone;
pub mod formation;
pub mod guided;
pub mod hierarchy;
pub mod infantry_motion;
pub mod navigation_grid;
pub mod path_planner;
pub mod perception;
pub mod projectile;
pub mod random;
pub mod route_graph;
mod state_codec;
pub mod support;
pub mod targeting;
pub mod terrain;
pub mod terrain_cover;
pub mod terrain_scene;
pub mod vector;
pub mod visibility;
pub mod water;
