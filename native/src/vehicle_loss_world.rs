//! Reference fixture adapter; production destruction only uses retained Rust state.
use crate::actors::{birth_loadout, read_squads, write_squads, ActorStateCore};
use crate::battle_stats::BattleStatsCore;
use crate::deferred_effects::DeferredEffectsCore;
use crate::fires::FiresCore;
use crate::simulation_random::SimulationRandomCore;
use crate::spatial::SpatialIndexCore;
use crate::squad::SquadStateCore;
use crate::visibility::VisibilityCore;
use crate::world_geometry::WorldGeometryCore;
use frontline_core::actors::Actor;
use frontline_core::fires::{BuildingProfile, ManProfile};
use frontline_core::squad_movement;
use frontline_core::vehicle_loss::Crew;
use frontline_core::vehicle_loss_world::{Context, Event, Profile};
use godot::prelude::*;
use std::collections::BTreeMap;

fn read<T: FromGodot>(a: &Array<Variant>, i: usize) -> Option<T> {
    a.get(i)?.try_to().ok()
}
struct VehicleProfile {
    name: String,
    base: String,
    helicopter: bool,
    automatic: bool,
    count: Option<u32>,
    cost: f64,
    armor: bool,
    grenades: bool,
    weight: u8,
    hull: frontline_core::vector::Vector3,
}
impl VehicleProfile {
    fn view(&self) -> Profile<'_> {
        Profile {
            name: &self.name,
            weight: self.weight,
            hull: self.hull,
            crew: Crew {
                base: &self.base,
                helicopter: self.helicopter,
                automatic: self.automatic,
                count: self.count,
                cost: self.cost,
                armor_upgrade: self.armor,
                grenade_upgrade: self.grenades,
            },
        }
    }
}
struct Man {
    profile: ManProfile,
    movement: squad_movement::ManProfile,
    role: String,
}
#[derive(GodotClass)]
#[class(base=RefCounted, init)]
struct VehicleLossWorldCore {
    base: Base<RefCounted>,
}
#[godot_api]
impl VehicleLossWorldCore {
    #[func]
    fn damage(
        &self,
        mut actors: Gd<ActorStateCore>,
        mut geometry: Gd<WorldGeometryCore>,
        units: Gd<SpatialIndexCore>,
        nodes: Array<Gd<SquadStateCore>>,
        mut fires: Gd<FiresCore>,
        mut battle: Gd<BattleStatsCore>,
        mut deferred: Gd<DeferredEffectsCore>,
        mut visibility: Gd<VisibilityCore>,
        mut rng: Gd<SimulationRandomCore>,
        config: Array<Variant>,
        id: u32,
        amount: f64,
        source: u32,
    ) -> Array<Variant> {
        let parse = || -> Option<_> {
            if config.len() != 8 {
                return None;
            }
            let next = u64::try_from(read::<i64>(&config, 0)?).ok()?;
            let now: f64 = read(&config, 1)?;
            let town: Rect2 = read(&config, 2)?;
            let names: Array<Variant> = read(&config, 3)?;
            let loads: Array<Variant> = read(&config, 4)?;
            if names.len() != 2 || loads.len() != 2 {
                return None;
            }
            let names = [
                read::<PackedStringArray>(&names, 0)?,
                read::<PackedStringArray>(&names, 1)?,
            ]
            .map(|n| {
                n.as_slice()
                    .iter()
                    .map(ToString::to_string)
                    .collect::<Vec<_>>()
            });
            let loadouts = [
                birth_loadout(&read::<Array<Variant>>(&loads, 0)?)?,
                birth_loadout(&read::<Array<Variant>>(&loads, 1)?)?,
            ];
            let rows: Array<Variant> = read(&config, 5)?;
            if rows.len() > 100_000 {
                return None;
            }
            let mut vehicles = BTreeMap::new();
            for row in rows.iter_shared() {
                let r: Array<Variant> = row.try_to().ok()?;
                if r.len() != 11 {
                    return None;
                }
                let key: u32 = read(&r, 0)?;
                let count: i32 = read(&r, 5)?;
                if !(-1..=4096).contains(&count) {
                    return None;
                }
                let p = VehicleProfile {
                    name: read::<GString>(&r, 1)?.to_string(),
                    base: read::<GString>(&r, 2)?.to_string(),
                    helicopter: read(&r, 3)?,
                    automatic: read(&r, 4)?,
                    count: (count >= 0).then_some(count as u32),
                    cost: read(&r, 6)?,
                    armor: read(&r, 7)?,
                    grenades: read(&r, 8)?,
                    weight: read(&r, 9)?,
                    hull: crate::point(read(&r, 10)?),
                };
                if vehicles.insert(key, p).is_some() {
                    return None;
                }
            }
            let rows: Array<Variant> = read(&config, 6)?;
            if rows.len() > 4096 {
                return None;
            }
            let mut men = BTreeMap::new();
            for row in rows.iter_shared() {
                let r: Array<Variant> = row.try_to().ok()?;
                if r.len() != 6 {
                    return None;
                }
                let key = read::<GString>(&r, 0)?.to_string();
                let ammo: i32 = read(&r, 2)?;
                let value: f64 = read(&r, 3)?;
                let range: f64 = read(&r, 4)?;
                if ammo < -1
                    || !value.is_finite()
                    || !(0.0..=1e15).contains(&value)
                    || !range.is_finite()
                    || !(-1.0..=1e6).contains(&range)
                {
                    return None;
                }
                let bearer: bool = read(&r, 1)?;
                let p = Man {
                    profile: ManProfile {
                        bearer,
                        ammunition: (ammo >= 0).then_some(ammo),
                        value,
                    },
                    movement: squad_movement::ManProfile {
                        bearer,
                        weapon_range: (range >= 0.0).then_some(range),
                    },
                    role: read::<GString>(&r, 5)?.to_string(),
                };
                if men.insert(key, p).is_some() {
                    return None;
                }
            }
            let rows: Array<Variant> = read(&config, 7)?;
            if rows.len() > 4096 {
                return None;
            }
            let mut buildings = BTreeMap::new();
            for row in rows.iter_shared() {
                let r: Array<Variant> = row.try_to().ok()?;
                if r.len() != 3 {
                    return None;
                }
                let value: f64 = read(&r, 2)?;
                if !value.is_finite() || !(0.0..=1e15).contains(&value) {
                    return None;
                }
                buildings.insert(
                    read::<GString>(&r, 0)?.to_string(),
                    BuildingProfile {
                        player: read(&r, 1)?,
                        value,
                    },
                );
            }
            Some((next, now, town, names, loadouts, vehicles, men, buildings))
        };
        let Some((mut next, now, town, names, loadouts, vehicles, men, buildings)) = parse() else {
            return Array::new();
        };
        let mut actors = actors.bind_mut();
        let mut geometry = geometry.bind_mut();
        let units = units.bind();
        let mut fires = fires.bind_mut();
        let (Some(geometry), Some(units), Some(fires)) =
            (&mut geometry.core, &units.core, &mut fires.core)
        else {
            return Array::new();
        };
        let Some(mut squads) = read_squads(&nodes) else {
            return Array::new();
        };
        if !loadouts.iter().all(|l| men.contains_key(&l.unit))
            || actors.core.iter().any(|a| match a {
                Actor::Soldier(s) => !men.contains_key(&s.identity.unit),
                Actor::Vehicle(v) => !vehicles.contains_key(&v.id),
                _ => false,
            })
        {
            return Array::new();
        }
        let automatic: Vec<String> = actors
            .core
            .iter()
            .filter_map(|a| match a {
                Actor::Vehicle(v) if vehicles[&v.id].automatic => Some(v.kind.clone()),
                _ => None,
            })
            .collect();
        let mut battle = battle.bind_mut();
        let mut deferred = deferred.bind_mut();
        let mut visibility = visibility.bind_mut();
        let mut rng = rng.bind_mut();
        let result = Context {
            actors: &mut actors.core,
            geometry,
            units,
            squads: &mut squads,
            next_squad: &mut next,
            fires,
            battle: &mut battle.core,
            deferred: &mut deferred.core,
            visibility: &mut visibility.core,
            rng: &mut rng.core,
            now,
            town: [town.position.x, town.position.y, town.size.x, town.size.y],
            names: &names,
            crew_loadouts: &loadouts,
            crew_name: "Tank Crew",
            team_names: &["Coalition", "Rebels"],
            vehicle: &|v| vehicles[&v.id].view(),
            man: &|s, _| men[&s.identity.unit].profile,
            movement: &|s| men[&s.identity.unit].movement,
            building: &|st| {
                buildings.get(&st.kind).copied().unwrap_or(BuildingProfile {
                    player: false,
                    value: 0.0,
                })
            },
            role: &|s| men[&s.identity.unit].role.clone(),
            automatic: &|k| automatic.iter().any(|v| v == k),
            player_building: &|k| buildings.get(k).is_some_and(|p| p.player),
        }
        .damage(id, amount, source);
        let Ok(events) = result else {
            godot_error!("{}", result.unwrap_err());
            return Array::new();
        };
        let states: Array<Variant> = squads
            .iter()
            .map(|q| PackedByteArray::from(q.checkpoint().unwrap().as_slice()).to_variant())
            .collect();
        let original = nodes.len();
        write_squads(nodes, squads.into_iter().take(original).collect());
        let stats: PackedStringArray = events
            .iter()
            .filter_map(|e| match e {
                Event::Stat(s) | Event::Squad(squad_movement::Event::Stat(s)) => {
                    Some(GString::from(*s))
                }
                _ => None,
            })
            .collect();
        varray![next as i64, &states, &stats]
    }
}
