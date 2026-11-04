//! Shared match runtime for native hosts, browser workers and replay verification.
//!
//! Load immutable definitions with [`content::Content`] and an authored battlefield
//! with [`initial::load`]. [`simulation::Simulation::step`] is the only gameplay tick;
//! [`replay::Recorder`] records its admitted inputs and [`replay::verify`] reruns them.
//! Adapters project observations through [`render::Output`] and frame them with
//! [`protocol`]. This crate owns no sockets, files, processes or Godot objects.
pub mod client_command;
pub mod co_command;
pub mod commander;
pub mod compression;
pub mod content;
pub mod initial;
pub mod mission;
pub mod observation;
pub mod profiling;
pub mod protocol;
pub mod render;
pub mod replay;
pub mod simulation;
pub mod terrain_view;

pub const ENGINE_ID: &str = env!("FRONTLINE_ENGINE_ID");
