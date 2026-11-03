pub mod client_command;
pub mod co_command;
pub mod commander;
pub mod compression;
pub mod content;
pub mod initial;
pub mod mission;
#[cfg(not(target_family = "wasm"))]
pub mod network;
pub mod observation;
pub mod profiling;
pub mod protocol;
pub mod render;
pub mod replay;
#[cfg(not(target_family = "wasm"))]
pub mod serve;
pub mod simulation;
pub mod terrain_view;

pub const ENGINE_ID: &str = env!("FRONTLINE_ENGINE_ID");
