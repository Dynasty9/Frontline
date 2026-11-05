//! Shared battlefield access used by gameplay phases.
use crate::actors::Actors;
use crate::battle_stats::BattleStats;
use crate::deferred_effects::DeferredEffects;
use crate::fires::{self, Fires};
use crate::infantry::Infantry;
use crate::infantry_spawn::Loadout;
use crate::random::SimulationRandom;
use crate::spatial::SpatialIndex;
use crate::squad::Squad;
use crate::squad_movement;
use crate::structure::Structure;
use crate::vehicle::Vehicle;
use crate::vehicle_loss_world::Profile;
use crate::visibility::Visibility;
use crate::world_geometry::WorldGeometry;

pub struct WorldContext<'a> {
    pub actors: &'a mut Actors,
    pub geometry: &'a mut WorldGeometry,
    pub units: &'a SpatialIndex,
    pub squads: &'a mut Vec<Squad>,
    pub next_squad: &'a mut u64,
    pub fires: &'a mut Fires,
    pub battle: &'a mut BattleStats,
    pub deferred: &'a mut DeferredEffects,
    pub visibility: &'a mut Visibility,
    pub rng: &'a mut SimulationRandom,
    pub now: f64,
    pub town: [f32; 4],
    pub names: &'a [Vec<String>; 2],
    pub crew_loadouts: &'a [Loadout; 2],
    pub crew_name: &'a str,
    pub team_names: &'a [&'a str; 2],
    /// Definition values and retained upgrades; these never call the engine.
    pub vehicle: &'a dyn Fn(&Vehicle) -> Profile<'a>,
    pub man: &'a dyn Fn(&Infantry, &[Squad]) -> fires::ManProfile,
    pub movement: &'a dyn Fn(&Infantry) -> squad_movement::ManProfile,
    pub building: &'a dyn Fn(&Structure) -> fires::BuildingProfile,
    pub role: &'a dyn Fn(&Infantry) -> String,
    pub automatic: &'a dyn Fn(&str) -> bool,
    pub player_building: &'a dyn Fn(&str) -> bool,
}
