//! Reference fixture adapter; production destruction only uses retained Rust state.
use crate::actors::{birth_loadout, read_squads, write_squads, ActorStateCore};
use crate::battle_stats::BattleStatsCore;
use crate::deferred_effects::DeferredEffectsCore;
use crate::fires::FiresCore;
use crate::simulation_random::SimulationRandomCore;
use crate::spatial::SpatialIndexCore;
use crate::squad::SquadStateCore;
use crate::supply_network::SupplyNetworkCore;
use crate::visibility::VisibilityCore;
use crate::world_geometry::WorldGeometryCore;
use frontline_core::actors::Actor;
use frontline_core::bullet::Weapon;
use frontline_core::bullet_world::{Gunfire, Shot};
use frontline_core::fires::{BuildingProfile, ManProfile};
use frontline_core::infantry_fight_world::{self as fighting, Profile as FightingProfile};
use frontline_core::infantry_fire::FireProfile;
use frontline_core::infantry_wounded_world::{self as wounded, Input as WoundedInput};
use frontline_core::squad::Report;
use frontline_core::squad_movement;
use frontline_core::vehicle_damage::Armor;
use frontline_core::vehicle_loss::Crew;
use frontline_core::vehicle_loss_world::{Context, Event, Profile};
use frontline_core::world_combat::{self, Explosion};
use godot::prelude::*;
use std::collections::BTreeMap;

fn read<T: FromGodot>(a: &Array<Variant>, i: usize) -> Option<T> {
    a.get(i)?.try_to().ok()
}
fn vector(p: frontline_core::vector::Vector3) -> Vector3 {
    Vector3::new(p.x, p.y, p.z)
}
fn read_impacts(input: &Array<Variant>) -> Option<Vec<Report>> {
    if input.len() > 100_000 {
        return None;
    }
    let mut reports = vec![];
    for value in input.iter_shared() {
        let r: Array<Variant> = value.try_to().ok()?;
        if r.len() != 2 {
            return None;
        }
        let position = crate::point(read(&r, 0)?);
        let time: f64 = read(&r, 1)?;
        if !position.is_finite()
            || position.abs().max_element() > 1_000_000.0
            || !time.is_finite()
            || time.abs() > 1e12
        {
            return None;
        }
        reports.push(Report { position, time });
    }
    Some(reports)
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
    level: u8,
    toss: f64,
    hit: f64,
    gun_height: f64,
    artillery: bool,
    tracked: bool,
    seats: u32,
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
    healing: f64,
    building: f64,
    weapon: String,
}
#[derive(Clone, Copy)]
struct Building {
    profile: BuildingProfile,
    time: Option<f64>,
}
enum Operation {
    Service(Array<Variant>),
    Recruit(Array<Variant>),
    Damage(u32, f64, u32),
    Explosion(Explosion, Gd<SupplyNetworkCore>, Vec<Report>),
    Deferred(Gd<SupplyNetworkCore>, Vec<Report>),
    Bullet(Array<Variant>, Gd<SupplyNetworkCore>, Vec<Report>),
    Wounded(u32, WoundedInput, Gd<SupplyNetworkCore>, Vec<Report>),
    Combat(u8, Array<Variant>, Gd<SupplyNetworkCore>, Vec<Report>),
}
#[derive(GodotClass)]
#[class(base=RefCounted, init)]
struct VehicleLossWorldCore {
    base: Base<RefCounted>,
    gunfire: Gunfire,
}
#[godot_api]
impl VehicleLossWorldCore {
    #[func]
    fn advance_structure_service(
        &mut self,
        actors: Gd<ActorStateCore>,
        geometry: Gd<WorldGeometryCore>,
        units: Gd<SpatialIndexCore>,
        nodes: Array<Gd<SquadStateCore>>,
        fires: Gd<FiresCore>,
        battle: Gd<BattleStatsCore>,
        deferred: Gd<DeferredEffectsCore>,
        visibility: Gd<VisibilityCore>,
        rng: Gd<SimulationRandomCore>,
        config: Array<Variant>,
        input: Array<Variant>,
    ) -> Array<Variant> {
        self.run(
            actors,
            geometry,
            units,
            nodes,
            fires,
            battle,
            deferred,
            visibility,
            rng,
            config,
            Operation::Service(input),
        )
    }
    #[func]
    fn recruit(
        &mut self,
        actors: Gd<ActorStateCore>,
        geometry: Gd<WorldGeometryCore>,
        units: Gd<SpatialIndexCore>,
        nodes: Array<Gd<SquadStateCore>>,
        fires: Gd<FiresCore>,
        battle: Gd<BattleStatsCore>,
        deferred: Gd<DeferredEffectsCore>,
        visibility: Gd<VisibilityCore>,
        rng: Gd<SimulationRandomCore>,
        config: Array<Variant>,
        input: Array<Variant>,
    ) -> Array<Variant> {
        self.run(
            actors,
            geometry,
            units,
            nodes,
            fires,
            battle,
            deferred,
            visibility,
            rng,
            config,
            Operation::Recruit(input),
        )
    }
    #[func]
    fn damage(
        &mut self,
        actors: Gd<ActorStateCore>,
        geometry: Gd<WorldGeometryCore>,
        units: Gd<SpatialIndexCore>,
        nodes: Array<Gd<SquadStateCore>>,
        fires: Gd<FiresCore>,
        battle: Gd<BattleStatsCore>,
        deferred: Gd<DeferredEffectsCore>,
        visibility: Gd<VisibilityCore>,
        rng: Gd<SimulationRandomCore>,
        config: Array<Variant>,
        id: u32,
        amount: f64,
        source: u32,
    ) -> Array<Variant> {
        self.run(
            actors,
            geometry,
            units,
            nodes,
            fires,
            battle,
            deferred,
            visibility,
            rng,
            config,
            Operation::Damage(id, amount, source),
        )
    }
    #[func]
    fn explode(
        &mut self,
        actors: Gd<ActorStateCore>,
        geometry: Gd<WorldGeometryCore>,
        units: Gd<SpatialIndexCore>,
        nodes: Array<Gd<SquadStateCore>>,
        fires: Gd<FiresCore>,
        battle: Gd<BattleStatsCore>,
        deferred: Gd<DeferredEffectsCore>,
        visibility: Gd<VisibilityCore>,
        rng: Gd<SimulationRandomCore>,
        config: Array<Variant>,
        input: Array<Variant>,
        network: Gd<SupplyNetworkCore>,
        impacts: Array<Variant>,
    ) -> Array<Variant> {
        let parse = || -> Option<_> {
            if input.len() != 14 {
                return None;
            }
            let reports = read_impacts(&impacts)?;
            Some((
                Explosion {
                    position: crate::point(read(&input, 0)?),
                    damage: if input.get(1)?.is_nil() {
                        None
                    } else {
                        Some(read(&input, 1)?)
                    },
                    radius: read(&input, 2)?,
                    fling: read(&input, 3)?,
                    size: read(&input, 4)?,
                    anti_tank: read(&input, 5)?,
                    track: read(&input, 6)?,
                    top: read(&input, 7)?,
                    direction: if input.get(8)?.is_nil() {
                        None
                    } else {
                        Some(crate::point(read(&input, 8)?))
                    },
                    structure_multiplier: read(&input, 9)?,
                    vehicle_multiplier: read(&input, 10)?,
                    source: read(&input, 11)?,
                    owner: read(&input, 12)?,
                    team: read(&input, 13)?,
                },
                reports,
            ))
        };
        let Some((blast, reports)) = parse() else {
            return Array::new();
        };
        self.run(
            actors,
            geometry,
            units,
            nodes,
            fires,
            battle,
            deferred,
            visibility,
            rng,
            config,
            Operation::Explosion(blast, network, reports),
        )
    }
    #[func]
    fn flush_deferred(
        &mut self,
        actors: Gd<ActorStateCore>,
        geometry: Gd<WorldGeometryCore>,
        units: Gd<SpatialIndexCore>,
        nodes: Array<Gd<SquadStateCore>>,
        fires: Gd<FiresCore>,
        battle: Gd<BattleStatsCore>,
        deferred: Gd<DeferredEffectsCore>,
        visibility: Gd<VisibilityCore>,
        rng: Gd<SimulationRandomCore>,
        config: Array<Variant>,
        network: Gd<SupplyNetworkCore>,
        impacts: Array<Variant>,
    ) -> Array<Variant> {
        let Some(reports) = read_impacts(&impacts) else {
            return Array::new();
        };
        self.run(
            actors,
            geometry,
            units,
            nodes,
            fires,
            battle,
            deferred,
            visibility,
            rng,
            config,
            Operation::Deferred(network, reports),
        )
    }
    #[func]
    fn fire_bullet(
        &mut self,
        actors: Gd<ActorStateCore>,
        geometry: Gd<WorldGeometryCore>,
        units: Gd<SpatialIndexCore>,
        nodes: Array<Gd<SquadStateCore>>,
        fires: Gd<FiresCore>,
        battle: Gd<BattleStatsCore>,
        deferred: Gd<DeferredEffectsCore>,
        visibility: Gd<VisibilityCore>,
        rng: Gd<SimulationRandomCore>,
        config: Array<Variant>,
        input: Array<Variant>,
        network: Gd<SupplyNetworkCore>,
        impacts: Array<Variant>,
    ) -> Array<Variant> {
        let Some(reports) = read_impacts(&impacts) else {
            return Array::new();
        };
        self.run(
            actors,
            geometry,
            units,
            nodes,
            fires,
            battle,
            deferred,
            visibility,
            rng,
            config,
            Operation::Bullet(input, network, reports),
        )
    }
    #[func]
    fn gunfire_checkpoint(&self) -> PackedByteArray {
        PackedByteArray::from(self.gunfire.checkpoint().as_slice())
    }
    #[func]
    fn advance_wounded(
        &mut self,
        actors: Gd<ActorStateCore>,
        geometry: Gd<WorldGeometryCore>,
        units: Gd<SpatialIndexCore>,
        nodes: Array<Gd<SquadStateCore>>,
        fires: Gd<FiresCore>,
        battle: Gd<BattleStatsCore>,
        deferred: Gd<DeferredEffectsCore>,
        visibility: Gd<VisibilityCore>,
        rng: Gd<SimulationRandomCore>,
        config: Array<Variant>,
        input: Array<Variant>,
        network: Gd<SupplyNetworkCore>,
        impacts: Array<Variant>,
    ) -> Array<Variant> {
        let parse = || -> Option<_> {
            if input.len() != 4 {
                return None;
            }
            Some((
                read::<u32>(&input, 0)?,
                WoundedInput {
                    dt: read(&input, 1)?,
                    medicine: read(&input, 2)?,
                    optics: read(&input, 3)?,
                    gun: None,
                },
                read_impacts(&impacts)?,
            ))
        };
        let Some((id, input, reports)) = parse() else {
            return Array::new();
        };
        self.run(
            actors,
            geometry,
            units,
            nodes,
            fires,
            battle,
            deferred,
            visibility,
            rng,
            config,
            Operation::Wounded(id, input, network, reports),
        )
    }
    #[func]
    fn gunfire_restore(&mut self, bytes: PackedByteArray) -> bool {
        let Ok(state) = Gunfire::restore(bytes.as_slice()) else {
            return false;
        };
        self.gunfire = state;
        true
    }
    #[func]
    fn advance_fighting(
        &mut self,
        actors: Gd<ActorStateCore>,
        geometry: Gd<WorldGeometryCore>,
        units: Gd<SpatialIndexCore>,
        nodes: Array<Gd<SquadStateCore>>,
        fires: Gd<FiresCore>,
        battle: Gd<BattleStatsCore>,
        deferred: Gd<DeferredEffectsCore>,
        visibility: Gd<VisibilityCore>,
        rng: Gd<SimulationRandomCore>,
        config: Array<Variant>,
        input: Array<Variant>,
        network: Gd<SupplyNetworkCore>,
        impacts: Array<Variant>,
    ) -> Array<Variant> {
        let Some(reports) = read_impacts(&impacts) else {
            return Array::new();
        };
        self.run(
            actors,
            geometry,
            units,
            nodes,
            fires,
            battle,
            deferred,
            visibility,
            rng,
            config,
            Operation::Combat(0, input, network, reports),
        )
    }
    #[func]
    fn advance_breach(
        &mut self,
        actors: Gd<ActorStateCore>,
        geometry: Gd<WorldGeometryCore>,
        units: Gd<SpatialIndexCore>,
        nodes: Array<Gd<SquadStateCore>>,
        fires: Gd<FiresCore>,
        battle: Gd<BattleStatsCore>,
        deferred: Gd<DeferredEffectsCore>,
        visibility: Gd<VisibilityCore>,
        rng: Gd<SimulationRandomCore>,
        config: Array<Variant>,
        input: Array<Variant>,
        network: Gd<SupplyNetworkCore>,
        impacts: Array<Variant>,
    ) -> Array<Variant> {
        let Some(reports) = read_impacts(&impacts) else {
            return Array::new();
        };
        self.run(
            actors,
            geometry,
            units,
            nodes,
            fires,
            battle,
            deferred,
            visibility,
            rng,
            config,
            Operation::Combat(1, input, network, reports),
        )
    }
    #[func]
    fn advance_build(
        &mut self,
        actors: Gd<ActorStateCore>,
        geometry: Gd<WorldGeometryCore>,
        units: Gd<SpatialIndexCore>,
        nodes: Array<Gd<SquadStateCore>>,
        fires: Gd<FiresCore>,
        battle: Gd<BattleStatsCore>,
        deferred: Gd<DeferredEffectsCore>,
        visibility: Gd<VisibilityCore>,
        rng: Gd<SimulationRandomCore>,
        config: Array<Variant>,
        input: Array<Variant>,
        network: Gd<SupplyNetworkCore>,
        impacts: Array<Variant>,
    ) -> Array<Variant> {
        let Some(reports) = read_impacts(&impacts) else {
            return Array::new();
        };
        self.run(
            actors,
            geometry,
            units,
            nodes,
            fires,
            battle,
            deferred,
            visibility,
            rng,
            config,
            Operation::Combat(2, input, network, reports),
        )
    }
    #[func]
    fn advance_mount(
        &mut self,
        actors: Gd<ActorStateCore>,
        geometry: Gd<WorldGeometryCore>,
        units: Gd<SpatialIndexCore>,
        nodes: Array<Gd<SquadStateCore>>,
        fires: Gd<FiresCore>,
        battle: Gd<BattleStatsCore>,
        deferred: Gd<DeferredEffectsCore>,
        visibility: Gd<VisibilityCore>,
        rng: Gd<SimulationRandomCore>,
        config: Array<Variant>,
        input: Array<Variant>,
        network: Gd<SupplyNetworkCore>,
        impacts: Array<Variant>,
    ) -> Array<Variant> {
        let Some(reports) = read_impacts(&impacts) else {
            return Array::new();
        };
        self.run(
            actors,
            geometry,
            units,
            nodes,
            fires,
            battle,
            deferred,
            visibility,
            rng,
            config,
            Operation::Combat(3, input, network, reports),
        )
    }
    #[func]
    fn advance_action(
        &mut self,
        actors: Gd<ActorStateCore>,
        geometry: Gd<WorldGeometryCore>,
        units: Gd<SpatialIndexCore>,
        nodes: Array<Gd<SquadStateCore>>,
        fires: Gd<FiresCore>,
        battle: Gd<BattleStatsCore>,
        deferred: Gd<DeferredEffectsCore>,
        visibility: Gd<VisibilityCore>,
        rng: Gd<SimulationRandomCore>,
        config: Array<Variant>,
        input: Array<Variant>,
        network: Gd<SupplyNetworkCore>,
        impacts: Array<Variant>,
    ) -> Array<Variant> {
        let Some(reports) = read_impacts(&impacts) else {
            return Array::new();
        };
        self.run(
            actors,
            geometry,
            units,
            nodes,
            fires,
            battle,
            deferred,
            visibility,
            rng,
            config,
            Operation::Combat(4, input, network, reports),
        )
    }
    #[func]
    fn advance_infantry(
        &mut self,
        actors: Gd<ActorStateCore>,
        geometry: Gd<WorldGeometryCore>,
        units: Gd<SpatialIndexCore>,
        nodes: Array<Gd<SquadStateCore>>,
        fires: Gd<FiresCore>,
        battle: Gd<BattleStatsCore>,
        deferred: Gd<DeferredEffectsCore>,
        visibility: Gd<VisibilityCore>,
        rng: Gd<SimulationRandomCore>,
        config: Array<Variant>,
        input: Array<Variant>,
        network: Gd<SupplyNetworkCore>,
        impacts: Array<Variant>,
    ) -> Array<Variant> {
        let Some(reports) = read_impacts(&impacts) else {
            return Array::new();
        };
        self.run(
            actors,
            geometry,
            units,
            nodes,
            fires,
            battle,
            deferred,
            visibility,
            rng,
            config,
            Operation::Combat(5, input, network, reports),
        )
    }
    #[func]
    fn advance_actor(
        &mut self,
        actors: Gd<ActorStateCore>,
        geometry: Gd<WorldGeometryCore>,
        units: Gd<SpatialIndexCore>,
        nodes: Array<Gd<SquadStateCore>>,
        fires: Gd<FiresCore>,
        battle: Gd<BattleStatsCore>,
        deferred: Gd<DeferredEffectsCore>,
        visibility: Gd<VisibilityCore>,
        rng: Gd<SimulationRandomCore>,
        config: Array<Variant>,
        mode: u8,
        input: Array<Variant>,
        network: Gd<SupplyNetworkCore>,
        impacts: Array<Variant>,
    ) -> Array<Variant> {
        if mode > 12 {
            return Array::new();
        }
        let Some(reports) = read_impacts(&impacts) else {
            return Array::new();
        };
        self.run(
            actors,
            geometry,
            units,
            nodes,
            fires,
            battle,
            deferred,
            visibility,
            rng,
            config,
            Operation::Combat(6 + mode, input, network, reports),
        )
    }
    #[func]
    fn gunfire_reveals(&self) -> VarDictionary {
        let mut out = VarDictionary::new();
        for (id, time) in self.gunfire.reveals() {
            out.set(*id, *time);
        }
        out
    }
    fn run(
        &mut self,
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
        operation: Operation,
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
                if ![11, 13, 14, 17, 18].contains(&r.len()) {
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
                    level: if r.len() >= 13 { read(&r, 11)? } else { 0 },
                    toss: if r.len() >= 13 { read(&r, 12)? } else { 1.0 },
                    hit: if r.len() >= 14 { read(&r, 13)? } else { 2.0 },
                    gun_height: if r.len() >= 17 { read(&r, 14)? } else { 2.2 },
                    artillery: if r.len() >= 17 { read(&r, 15)? } else { false },
                    tracked: if r.len() >= 17 { read(&r, 16)? } else { false },
                    seats: if r.len() == 18 { read(&r, 17)? } else { 0 },
                };
                if p.seats > 4096
                    || !p.gun_height.is_finite()
                    || !(0.0..=1000.0).contains(&p.gun_height)
                    || vehicles.insert(key, p).is_some()
                {
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
                if r.len() != 6 && r.len() != 9 {
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
                    healing: if r.len() == 9 { read(&r, 6)? } else { 1.0 },
                    building: if r.len() == 9 { read(&r, 7)? } else { 1.0 },
                    weapon: if r.len() == 9 {
                        read::<GString>(&r, 8)?.to_string()
                    } else {
                        String::new()
                    },
                };
                if [p.healing, p.building]
                    .iter()
                    .any(|n| !n.is_finite() || !(0.0..=100_000.0).contains(n))
                    || p.weapon.len() > 128
                    || p.weapon.contains('\0')
                {
                    return None;
                }
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
                if r.len() != 3 && r.len() != 4 {
                    return None;
                }
                let value: f64 = read(&r, 2)?;
                if !value.is_finite() || !(0.0..=1e15).contains(&value) {
                    return None;
                }
                let time: Option<f64> = if r.len() == 4 && !r.at(3).is_nil() {
                    Some(read(&r, 3)?)
                } else {
                    None
                };
                if time.is_some_and(|t| !t.is_finite() || !(0.000001..=1e12).contains(&t)) {
                    return None;
                }
                buildings.insert(
                    read::<GString>(&r, 0)?.to_string(),
                    Building {
                        time,
                        profile: BuildingProfile {
                            player: read(&r, 1)?,
                            value,
                        },
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
        let mut context = Context {
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
                buildings
                    .get(&st.kind)
                    .map(|p| p.profile)
                    .unwrap_or(BuildingProfile {
                        player: false,
                        value: 0.0,
                    })
            },
            role: &|s| men[&s.identity.unit].role.clone(),
            automatic: &|k| automatic.iter().any(|v| v == k),
            player_building: &|k| buildings.get(k).is_some_and(|p| p.profile.player),
        };
        let mut reports = None;
        let mut cries: Option<Array<Variant>> = None;
        let mut chat_state: Option<PackedFloat64Array> = None;
        let mut construction: Option<Array<Variant>> = None;
        let mut construction_stats = PackedStringArray::new();
        let mut recruitment: Option<Array<Variant>> = None;
        let mut services: Option<Array<Variant>> = None;
        let armor = |v: &frontline_core::vehicle::Vehicle| {
            let p = &vehicles[&v.id];
            Armor {
                level: p.level,
                helicopter: p.helicopter,
                boat: p.base == "boat",
                supply: p.base == "supply",
                toss: p.toss,
            }
        };
        let result = match operation {
            Operation::Service(input) => {
                use frontline_core::structure_services::{Event as Service, Profiles, Supply};
                let parse = || -> Option<_> {
                    if input.len() != 8 {
                        return None;
                    }
                    let id: u32 = read(&input, 0)?;
                    let dt: f64 = read(&input, 1)?;
                    let stock = crate::actors::service_stock(read(&input, 2)?)?;
                    let rows: Array<Variant> = read(&input, 3)?;
                    if rows.len() > 100_000 {
                        return None;
                    }
                    let mut supply = BTreeMap::new();
                    for row in rows.iter_shared() {
                        let row: Array<Variant> = row.try_to().ok()?;
                        if row.len() != 3 {
                            return None;
                        }
                        let id: u32 = read(&row, 0)?;
                        let ammo: i32 = read(&row, 1)?;
                        if ammo < -1 {
                            return None;
                        }
                        let p = Supply {
                            ammunition: (ammo >= 0).then_some(ammo),
                            frags: read(&row, 2)?,
                            loadout: stock.get(&id)?.0,
                        };
                        if !p.valid() || supply.insert(id, p).is_some() {
                            return None;
                        }
                    }
                    if context.actors.iter().any(
                        |a| matches!(a,Actor::Soldier(s) if !supply.contains_key(&s.identity.id)),
                    ) {
                        return None;
                    }
                    let bearer = birth_loadout(&read(&input, 4)?)?;
                    if !men.contains_key(&bearer.unit) {
                        return None;
                    }
                    let armor: bool = read(&input, 5)?;
                    let grenades: bool = read(&input, 6)?;
                    let gun = crate::actors::mounted_gun(&read(&input, 7)?).ok()?;
                    Some((id, dt, supply, bearer, armor, grenades, gun))
                };
                let Some((id, dt, supply, bearer, armor, grenades, gun)) = parse() else {
                    return Array::new();
                };
                context
                    .advance_structure_service(
                        id,
                        dt,
                        &Profiles {
                            supply: &|s| supply[&s.identity.id],
                            bearer: &bearer,
                            armor_upgrade: armor,
                            grenade_upgrade: grenades,
                            gun,
                        },
                    )
                    .map(|events| {
                        services = Some(
                            events
                                .iter()
                                .map(|e| match e {
                                    Service::Born { tent, soldier } => {
                                        varray![0, *tent, *soldier].to_variant()
                                    }
                                    Service::Reload { soldier, variant } => {
                                        varray![1, *soldier, i32::from(*variant)].to_variant()
                                    }
                                    Service::CacheEmpty { id, team, position } => {
                                        varray![2, *id, i32::from(*team), vector(*position)]
                                            .to_variant()
                                    }
                                    Service::Despawn(id) => varray![3, *id].to_variant(),
                                    Service::Stat(key) => {
                                        varray![4, &GString::from(*key)].to_variant()
                                    }
                                })
                                .collect(),
                        );
                        events
                            .into_iter()
                            .filter_map(|e| match e {
                                Service::Stat(key) => Some(world_combat::Event::Stat(key)),
                                _ => None,
                            })
                            .collect()
                    })
            }
            Operation::Recruit(input) => {
                use frontline_core::squad_birth::{Definition, Spawn};
                let parse = || -> Option<_> {
                    if input.len() != 10 {
                        return None;
                    }
                    let kind = read::<GString>(&input, 0)?.to_string();
                    let name = read::<GString>(&input, 1)?.to_string();
                    let rows: Array<Variant> = read(&input, 2)?;
                    if rows.len() > 4096 {
                        return None;
                    }
                    let members = rows
                        .iter_shared()
                        .map(|r| birth_loadout(&r.try_to::<Array<Variant>>().ok()?))
                        .collect::<Option<Vec<_>>>()?;
                    if members.iter().any(|l| !men.contains_key(&l.unit)) {
                        return None;
                    }
                    let armor_upgrade: bool = read(&input, 3)?;
                    let grenade_upgrade: bool = read(&input, 4)?;
                    let spawn = Spawn {
                        team: read(&input, 5)?,
                        owner: read(&input, 6)?,
                        position: crate::point(read(&input, 7)?),
                        destination: if input.at(8).is_nil() {
                            None
                        } else {
                            Some(crate::point(read(&input, 8)?))
                        },
                    };
                    let transport: u32 = read(&input, 9)?;
                    Some((
                        kind,
                        name,
                        members,
                        armor_upgrade,
                        grenade_upgrade,
                        spawn,
                        transport,
                    ))
                };
                let Some((kind, name, members, armor_upgrade, grenade_upgrade, spawn, transport)) =
                    parse()
                else {
                    return Array::new();
                };
                let profile = Definition {
                    kind: &kind,
                    name: &name,
                    members: &members,
                    armor_upgrade,
                    grenade_upgrade,
                };
                let born = if transport == 0 {
                    context.spawn_squad(spawn, profile)
                } else {
                    context
                        .embark_new_squad(transport, profile)
                        .map(|id| (id, vec![]))
                };
                born.map(|(id, events)| {
                    let rows: Array<Variant> = events
                        .iter()
                        .cloned()
                        .map(crate::squad_movement::event)
                        .collect();
                    recruitment = Some(varray![id, &rows]);
                    events
                        .into_iter()
                        .map(|e| world_combat::Event::Vehicle(Event::Squad(e)))
                        .collect()
                })
            }
            Operation::Combat(mode, input, mut network, mut impacts) => {
                let parse = || -> Option<_> {
                    if input.len()
                        != match mode {
                            2 => 8,
                            3.. => 7,
                            _ => 6,
                        }
                    {
                        return None;
                    }
                    let id: u32 = read(&input, 0)?;
                    let dt: f64 = read(&input, 1)?;
                    let rows: Array<Variant> = read(&input, 2)?;
                    if rows.len() > 1024 {
                        return None;
                    }
                    let gun = crate::actors::mounted_gun(&read(&input, 3)?).ok()?;
                    let chat: PackedFloat64Array = read(&input, 4)?;
                    if chat.len() != 2 {
                        return None;
                    }
                    let optics: bool = read(&input, 5)?;
                    let mut profiles = BTreeMap::new();
                    for value in rows.iter_shared() {
                        let row: Array<Variant> = value.try_to().ok()?;
                        if row.len() != 3 {
                            return None;
                        }
                        let key: GString = read(&row, 0)?;
                        let values: PackedFloat64Array = read(&row, 1)?;
                        let sound: GString = read(&row, 2)?;
                        let v = values.as_slice();
                        if v.len() != 16
                            || v.iter().any(|v| !v.is_finite())
                            || [0, 1, 3, 4].into_iter().any(|i| {
                                v[i].fract() != 0.0 || !(0.0..=1_000_000.0).contains(&v[i])
                            })
                            || [8, 12, 15].into_iter().any(|i| v[i] != 0.0 && v[i] != 1.0)
                            || v[9].fract() != 0.0
                            || !(0.0..=3.0).contains(&v[9])
                        {
                            return None;
                        }
                        let fire = FireProfile {
                            weapon: frontline_core::infantry_weapon::Weapon {
                                ammunition: v[0] as i32,
                                magazine: v[1] as i32,
                                reload_time: v[2],
                            },
                            burst_min: v[3] as i32,
                            burst_max: v[4] as i32,
                        };
                        let bullet = Weapon {
                            accuracy: v[5],
                            range: v[6],
                            damage: v[7],
                            anti_air: v[8] != 0.0,
                            penetration: v[9] as u8,
                            drone_accuracy: v[10],
                            explosive_radius: (v[11] != -1.0).then_some(v[11]),
                            airburst: v[12] != 0.0,
                        };
                        let sound = sound.to_string();
                        if !(FightingProfile {
                            fire,
                            bullet,
                            interval: v[13],
                            suppression: v[14],
                            sound: &sound,
                            optics,
                            piercing: v[15] != 0.0,
                        })
                        .valid()
                        {
                            return None;
                        }
                        if profiles
                            .insert(
                                key.to_string(),
                                (fire, bullet, v[13], v[14], sound, v[15] != 0.0),
                            )
                            .is_some()
                        {
                            return None;
                        }
                    }
                    Some((id, dt, gun, [chat[0], chat[1]], optics, profiles))
                };
                let Some((id, dt, gun, mut chat, optics, profiles)) = parse() else {
                    return Array::new();
                };
                let profile = |s: &frontline_core::infantry::Infantry| {
                    let key = if s.identity.mounted_weapon.is_empty() {
                        &s.identity.weapon
                    } else {
                        &s.identity.mounted_weapon
                    };
                    profiles.get(key).map(|p| FightingProfile {
                        fire: p.0,
                        bullet: p.1,
                        interval: p.2,
                        suppression: p.3,
                        sound: &p.4,
                        optics,
                        piercing: p.5,
                    })
                };
                let defense = |v: &frontline_core::vehicle::Vehicle| {
                    let p = &vehicles[&v.id];
                    frontline_core::infantry_action_owned::Defense {
                        smoke: frontline_core::vehicle_launch::SmokeProfile {
                            armor: p.level,
                            helicopter: p.helicopter,
                            gun_height: p.gun_height,
                        },
                        crew: frontline_core::vehicle_brain::CrewProfile {
                            base: &p.base,
                            helicopter: p.helicopter,
                            automatic: p.automatic,
                            artillery: p.artillery,
                            tracked: p.tracked,
                            armor: p.level,
                        },
                    }
                };
                let mut vehicle_effects = Array::<Variant>::new();
                let mut cannon_effects = Array::<Variant>::new();
                let mut plan_state = None;
                let mut income_state = None;
                let result = if mode == 18 {
                    let parse = || -> Option<_> {
                        let a: Array<Variant> = read(&input, 6)?;
                        if a.len() != 4 {
                            return None;
                        }
                        Some((
                            crate::vehicle::ground_profile(&read(&a, 0)?)?,
                            read::<i32>(&a, 1)?,
                            crate::vehicle_world::incomes(&a, 2)?,
                        ))
                    };
                    let Some((profile, load, mut income)) = parse() else {
                        return Array::new();
                    };
                    context
                        .advance_supply_truck(id, dt, profile, load, &mut income)
                        .map(|events| {
                            income_state = Some(crate::vehicle_world::income_state(&income));
                            crate::vehicle_world::effects(events, &mut vehicle_effects)
                                .into_iter()
                                .filter_map(|e| {
                                    if let frontline_core::vehicle_combat_world::Event::Combat(e) =
                                        e
                                    {
                                        Some(e)
                                    } else {
                                        None
                                    }
                                })
                                .collect()
                        })
                } else if (13..=14).contains(&mode) {
                    use frontline_core::ordnance_world::Event as Ordnance;
                    let Some(data) = read::<Array<Variant>>(&input, 6) else {
                        return Array::new();
                    };
                    if data.len() != 2 {
                        return Array::new();
                    }
                    let (Some(a), Some(b)) = (
                        read::<PackedVector4Array>(&data, 0),
                        read::<PackedVector4Array>(&data, 1),
                    ) else {
                        return Array::new();
                    };
                    if a.len() > 100_000 || b.len() > 100_000 {
                        return Array::new();
                    }
                    let mut marks = [vec![], vec![]];
                    for (side, values) in [a, b].iter().enumerate() {
                        for p in values.as_slice() {
                            if !p.is_finite()
                                || p.x.abs() > 1_000_000.0
                                || p.y.abs() > 1_000_000.0
                                || !(0.0..=4096.0).contains(&p.z)
                                || p.w.abs() > 1e12
                            {
                                return Array::new();
                            }
                            marks[side].push([p.x, p.y, p.z, p.w]);
                        }
                    }
                    let result = if mode == 13 {
                        context.advance_projectile_world(
                            id,
                            dt,
                            &mut marks,
                            &mut network.bind_mut().core,
                            &mut impacts,
                            &armor,
                        )
                    } else {
                        context.advance_drone_world(
                            id,
                            dt,
                            &mut network.bind_mut().core,
                            &mut impacts,
                            &armor,
                        )
                    };
                    result.map(|events| {
                        let events = events
                            .into_iter()
                            .filter_map(|e| match e {
                                Ordnance::Combat(e) => Some(fighting::Event::World(e)),
                                Ordnance::Sound {
                                    name,
                                    volume,
                                    position,
                                } => {
                                    vehicle_effects.push(
                                        &varray!["far_sound", name, volume, vector(position)]
                                            .to_variant(),
                                    );
                                    None
                                }
                                Ordnance::Smothered { soldier, .. } => {
                                    vehicle_effects
                                        .push(&varray!["smother_notice", soldier].to_variant());
                                    None
                                }
                                Ordnance::Spawn(_) => None,
                            })
                            .collect();
                        let pack = |values: &[[f32; 4]]| {
                            values
                                .iter()
                                .map(|p| Vector4::new(p[0], p[1], p[2], p[3]))
                                .collect::<PackedVector4Array>()
                        };
                        vehicle_effects.push(
                            &varray!["marks", &pack(&marks[0]), &pack(&marks[1])].to_variant(),
                        );
                        events
                    })
                } else if (9..=12).contains(&mode) {
                    use frontline_core::vehicle_movement_world::Event as Motion;
                    let Some(data) = read::<Array<Variant>>(&input, 6) else {
                        return Array::new();
                    };
                    let result = match mode {
                        9 => {
                            let Some(p) = read::<PackedFloat64Array>(&data, 0) else {
                                return Array::new();
                            };
                            if data.len() != 1
                                || p.len() != 6
                                || p.as_slice()[2..].iter().any(|v| *v != 0.0 && *v != 1.0)
                            {
                                return Array::new();
                            }
                            context
                                .scan_vehicle_world(
                                    id,
                                    frontline_core::vehicle_scan::ScanProfile {
                                        sight: p[0],
                                        gun_height: p[1],
                                        cannon: p[2] != 0.0,
                                        gunship: p[3] != 0.0,
                                        anti_air: p[4] != 0.0,
                                        penetrating_mg: p[5] != 0.0,
                                    },
                                )
                                .map(|_| vec![])
                        }
                        10 => {
                            let (Some(mission), Some(cannons)) =
                                (read::<bool>(&data, 0), read::<PackedInt64Array>(&data, 1))
                            else {
                                return Array::new();
                            };
                            if data.len() != 2 || cannons.len() > 100_000 {
                                return Array::new();
                            }
                            let Some(cannons) = cannons
                                .as_slice()
                                .iter()
                                .map(|&id| u32::try_from(id).ok().filter(|id| *id != 0))
                                .collect::<Option<std::collections::BTreeSet<_>>>()
                            else {
                                return Array::new();
                            };
                            let Some(v) = context.actors.vehicle(id) else {
                                return Array::new();
                            };
                            context.think_vehicle_world(id, defense(v).crew, mission, &|v| {
                                cannons.contains(&v.id)
                            })
                        }
                        11 => {
                            let Some(profile) = crate::vehicle::ground_profile(&data) else {
                                return Array::new();
                            };
                            context.drive_vehicle_world(id, dt, profile)
                        }
                        12 => {
                            let (Some(light), Some(armor)) =
                                (read::<bool>(&data, 0), read::<u8>(&data, 1))
                            else {
                                return Array::new();
                            };
                            if data.len() != 2 {
                                return Array::new();
                            }
                            context.smash_vehicle_world(id, light, armor)
                        }
                        _ => return Array::new(),
                    };
                    result.map(|events| {
                        events
                            .into_iter()
                            .filter_map(|e| match e {
                                Motion::Stat(key) => {
                                    Some(fighting::Event::World(world_combat::Event::Stat(key)))
                                }
                                Motion::Loss(e) => {
                                    Some(fighting::Event::World(world_combat::Event::Vehicle(e)))
                                }
                                Motion::Track(id) => {
                                    vehicle_effects.push(&varray!["track", id].to_variant());
                                    None
                                }
                                Motion::Smashed { structure, .. } => {
                                    vehicle_effects
                                        .push(&varray!["smash", structure.id].to_variant());
                                    None
                                }
                                Motion::Crew { .. } => None,
                            })
                            .collect()
                    })
                } else if mode >= 6 {
                    use frontline_core::vehicle_combat_world::{
                        Event as VehicleEvent, MachineGun, Profile,
                    };
                    let Some(data) = read::<Array<Variant>>(&input, 6) else {
                        return Array::new();
                    };
                    let ground_data: Option<Array<Variant>> =
                        if mode >= 15 { read(&data, 1) } else { None };
                    let data = if mode >= 15 {
                        if data.len() != 2 {
                            return Array::new();
                        }
                        let Some(data) = read::<Array<Variant>>(&data, 0) else {
                            return Array::new();
                        };
                        data
                    } else {
                        data
                    };
                    let result = if mode == 6 || mode >= 15 {
                        let parse = || -> Option<_> {
                            if data.len() != 4 {
                                return None;
                            }
                            let cycle: Array<Variant> = read(&data, 0)?;
                            let base = read::<GString>(&cycle, 0)?.to_string();
                            let gun = read::<GString>(&cycle, 3)?.to_string();
                            let muzzle = crate::vehicle::muzzle_profile(&read(&data, 1)?)?;
                            let cannon_muzzle = crate::vehicle::muzzle_profile(&read(&data, 2)?)?;
                            let cannon: PackedFloat64Array = read(&data, 3)?;
                            if cannon.len() != 4 {
                                return None;
                            }
                            Some((
                                cycle,
                                base,
                                gun,
                                muzzle,
                                frontline_core::vehicle_cannon::CannonProfile {
                                    muzzle: cannon_muzzle,
                                    damage: cannon[0],
                                    radius: cannon[1],
                                    anti_tank: cannon[2],
                                    size: cannon[3],
                                },
                            ))
                        };
                        let Some((cycle, base, gun, muzzle, cannon)) = parse() else {
                            return Array::new();
                        };
                        let Some(cycle) = crate::vehicle::fire_profile(&cycle, &base, &gun) else {
                            return Array::new();
                        };
                        let weapons = Profile {
                            cycle,
                            muzzle,
                            cannon: cycle.cannon.then_some(cannon),
                            machine_gun: profiles.get(&gun).map(|p| MachineGun {
                                weapon: p.1,
                                sound: &p.4,
                                suppression: p.3,
                                optics,
                                piercing: p.5,
                            }),
                        };
                        if mode == 17 {
                            let Some(mut p) = ground_data
                                .as_ref()
                                .and_then(crate::vehicle_world::parse_boat)
                            else {
                                return Array::new();
                            };
                            let mut navigation = p.navigation.bind_mut();
                            let Some(nav) = navigation.core.as_mut() else {
                                return Array::new();
                            };
                            let water = p.water.bind();
                            let boat = frontline_core::boat_world::Profile {
                                movement: p.movement,
                                scan: p.scan,
                                weapons,
                                traverse: p.traverse,
                            };
                            context
                                .advance_boat(
                                    id,
                                    dt,
                                    boat,
                                    nav,
                                    water.core.as_ref(),
                                    &mut self.gunfire,
                                    &mut network.bind_mut().core,
                                    &mut impacts,
                                    &mut p.plans,
                                    &mut p.next,
                                    &armor,
                                    &|v| vehicles[&v.id].hit,
                                    &defense,
                                )
                                .map(|events| {
                                    let events =
                                        crate::vehicle_world::effects(events, &mut vehicle_effects);
                                    let plans: Array<Variant> = p
                                        .plans
                                        .iter()
                                        .map(|p| {
                                            PackedByteArray::from(
                                                p.checkpoint().unwrap().as_slice(),
                                            )
                                            .to_variant()
                                        })
                                        .collect();
                                    plan_state =
                                        Some(varray!["plans", &plans, p.next as i64].to_variant());
                                    events
                                })
                        } else if mode == 16 {
                            let Some(mut p) = ground_data
                                .as_ref()
                                .and_then(crate::vehicle_world::parse_air)
                            else {
                                return Array::new();
                            };
                            let aircraft = frontline_core::aircraft_world::Profile {
                                kind: p.kind,
                                flight: p.flight,
                                scan: p.scan,
                                weapons,
                                traverse: p.traverse,
                            };
                            let result = context.advance_aircraft(
                                id,
                                dt,
                                aircraft,
                                &mut self.gunfire,
                                &mut network.bind_mut().core,
                                &mut impacts,
                                &mut p.plans,
                                &mut p.next,
                                &mut p.income,
                                &armor,
                                &|v| vehicles[&v.id].hit,
                                &defense,
                            );
                            result.map(|events| {
                                let events =
                                    crate::vehicle_world::effects(events, &mut vehicle_effects);
                                let plans: Array<Variant> = p
                                    .plans
                                    .iter()
                                    .map(|p| {
                                        PackedByteArray::from(p.checkpoint().unwrap().as_slice())
                                            .to_variant()
                                    })
                                    .collect();
                                plan_state =
                                    Some(varray!["plans", &plans, p.next as i64].to_variant());
                                income_state = Some(crate::vehicle_world::income_state(&p.income));
                                events
                            })
                        } else if mode == 15 {
                            let Some(mut p) =
                                ground_data.as_ref().and_then(crate::vehicle_world::parse)
                            else {
                                return Array::new();
                            };
                            let Some(v) = context.actors.vehicle(id) else {
                                return Array::new();
                            };
                            let ground = frontline_core::vehicle_world::Ground {
                                movement: p.movement,
                                scan: p.scan,
                                crew: defense(v).crew,
                                weapons,
                                traverse: p.traverse,
                                artillery: p.artillery,
                                service: p.service,
                                light: p.light,
                            };
                            let result = context.advance_ground_vehicle(
                                id,
                                dt,
                                ground,
                                &mut self.gunfire,
                                &mut network.bind_mut().core,
                                &mut impacts,
                                &mut p.plans,
                                &mut p.next,
                                p.mission,
                                &p.owned,
                                &armor,
                                &|v| vehicles[&v.id].hit,
                                &defense,
                                &|v| p.cannons.contains(&v.id),
                                &|s| {
                                    p.stock
                                        .get(&s.identity.id)
                                        .map(|(loadout, key, magazine)| {
                                            frontline_core::vehicle_service::SoldierSupply {
                                                loadout: *loadout,
                                                restored_weapon: (!key.is_empty())
                                                    .then_some((key.as_str(), *magazine)),
                                            }
                                        })
                                        .ok_or("missing service stock")
                                },
                                &|v| {
                                    p.missiles
                                        .get(&v.id)
                                        .copied()
                                        .ok_or("missing missile stock")
                                },
                            );
                            result.map(|events| {
                                let events =
                                    crate::vehicle_world::effects(events, &mut vehicle_effects);
                                let plans: Array<Variant> = p
                                    .plans
                                    .iter()
                                    .map(|p| {
                                        PackedByteArray::from(p.checkpoint().unwrap().as_slice())
                                            .to_variant()
                                    })
                                    .collect();
                                plan_state =
                                    Some(varray!["plans", &plans, p.next as i64].to_variant());
                                events
                            })
                        } else {
                            context.advance_vehicle_fire(
                                id,
                                weapons,
                                &mut self.gunfire,
                                &mut network.bind_mut().core,
                                &mut impacts,
                                &armor,
                                &|v| vehicles[&v.id].hit,
                                &defense,
                            )
                        }
                    } else if mode == 7 {
                        let parse = || -> Option<_> {
                            if data.len() != 3 {
                                return None;
                            }
                            let profile = crate::actors::artillery_profile(&read(&data, 0)?)?;
                            let range: PackedFloat64Array = read(&data, 1)?;
                            let owned: PackedInt64Array = read(&data, 2)?;
                            if range.len() != 2 || owned.len() > 100_000 {
                                return None;
                            }
                            let owned = owned
                                .as_slice()
                                .iter()
                                .map(|&id| u32::try_from(id).ok())
                                .collect::<Option<Vec<_>>>()?;
                            Some((profile, [range[0], range[1]], owned))
                        };
                        let Some((profile, range, owned)) = parse() else {
                            return Array::new();
                        };
                        context.advance_vehicle_artillery(id, dt, profile, range, &owned)
                    } else {
                        use frontline_core::vehicle_service::{Service, SoldierSupply};
                        let parse = || -> Option<_> {
                            if data.len() != 3 {
                                return None;
                            }
                            let service = match read::<GString>(&data, 0)?.to_string().as_str() {
                                "repair" => Service::Repair,
                                "ammo" => Service::Ammo,
                                "medical" => Service::Medical,
                                _ => return None,
                            };
                            let stock = crate::actors::service_stock(read(&data, 1)?)?;
                            let rows: Array<Variant> = read(&data, 2)?;
                            if rows.len() > 100_000 {
                                return None;
                            }
                            let mut missiles = BTreeMap::new();
                            for row in rows.iter_shared() {
                                let r = row.try_to::<PackedInt64Array>().ok()?;
                                if r.len() != 3
                                    || !(0..=1_000_000).contains(&r[1])
                                    || !(0..=1_000_000).contains(&r[2])
                                {
                                    return None;
                                }
                                let id = u32::try_from(r[0]).ok()?;
                                if id == 0
                                    || missiles.insert(id, [r[1] as i32, r[2] as i32]).is_some()
                                {
                                    return None;
                                }
                            }
                            Some((service, stock, missiles))
                        };
                        let Some((service, stock, missiles)) = parse() else {
                            return Array::new();
                        };
                        context.advance_vehicle_service(
                            id,
                            dt,
                            service,
                            &|s| {
                                stock
                                    .get(&s.identity.id)
                                    .map(|(loadout, key, magazine)| SoldierSupply {
                                        loadout: *loadout,
                                        restored_weapon: (!key.is_empty())
                                            .then_some((key.as_str(), *magazine)),
                                    })
                                    .ok_or("missing service stock")
                            },
                            &|v| missiles.get(&v.id).copied().ok_or("missing missile stock"),
                        )
                    };
                    result.map(|events| {
                        events
                            .into_iter()
                            .filter_map(|e| match e {
                                VehicleEvent::Combat(e) => Some(e),
                                VehicleEvent::Cannon {
                                    vehicle,
                                    from,
                                    impact,
                                } => {
                                    cannon_effects.push(
                                        &varray!["cannon", vector(from), vector(impact), vehicle]
                                            .to_variant(),
                                    );
                                    None
                                }
                                VehicleEvent::Service(
                                    frontline_core::vehicle_service::ServiceEffect::Repaired {
                                        vehicle,
                                        track: true,
                                    },
                                ) => {
                                    vehicle_effects.push(&varray!["track", vehicle].to_variant());
                                    None
                                }
                                _ => None,
                            })
                            .collect()
                    })
                } else if mode == 5 {
                    use frontline_core::infantry_world::{
                        Event as InfantryEvent, Profiles, Tick, Unit,
                    };
                    let parse = || -> Option<_> {
                        let data: Array<Variant> = read(&input, 6)?;
                        if data.len() != 6 {
                            return None;
                        }
                        let owned: PackedInt64Array = read(&data, 0)?;
                        if owned.len() > 100_000 {
                            return None;
                        }
                        let owned = owned
                            .as_slice()
                            .iter()
                            .map(|&id| u32::try_from(id).ok().filter(|id| *id != 0))
                            .collect::<Option<Vec<_>>>()?;
                        let players: PackedInt32Array = read(&data, 1)?;
                        if players.len() > 200_000 || players.len() % 2 != 0 {
                            return None;
                        }
                        let mut seen = std::collections::HashSet::new();
                        let mut peers = vec![];
                        for p in players.as_slice().chunks_exact(2) {
                            if p[0] <= 0 || !(-1..=1).contains(&p[1]) || !seen.insert(p[0]) {
                                return None;
                            }
                            peers.push((p[0], p[1] as i8));
                        }
                        let depots: PackedInt64Array = read(&data, 2)?;
                        let upgrades: PackedByteArray = read(&data, 3)?;
                        let names: PackedStringArray = read(&data, 4)?;
                        if depots.len() != 2
                            || upgrades.len() != 6
                            || names.len() != 2
                            || upgrades.as_slice().iter().any(|&n| n > 1)
                        {
                            return None;
                        }
                        let depots = [
                            u32::try_from(depots[0]).ok()?,
                            u32::try_from(depots[1]).ok()?,
                        ];
                        let names = [names[0].to_string(), names[1].to_string()];
                        if names.iter().any(|s| s.len() > 128 || s.contains('\0')) {
                            return None;
                        }
                        let rows: Array<Variant> = read(&data, 5)?;
                        if rows.len() > 100_000 {
                            return None;
                        }
                        let mut guns = BTreeMap::new();
                        for value in rows.iter_shared() {
                            let row: Array<Variant> = value.try_to().ok()?;
                            if row.len() != 2 {
                                return None;
                            }
                            let id: u32 = read(&row, 0)?;
                            if id == 0
                                || guns
                                    .insert(id, crate::actors::mounted_gun(&read(&row, 1)?).ok()?)
                                    .is_some()
                            {
                                return None;
                            }
                        }
                        Some((owned, peers, depots, upgrades, names, guns))
                    };
                    let Some((owned, players, depots, upgrades, names, guns)) = parse() else {
                        return Array::new();
                    };
                    let mut search = frontline_core::perception::PerceptionSearch::default();
                    if search
                        .rebuild_actors(
                            context.actors,
                            &context.geometry.terrain,
                            context.now,
                            |v| vehicles[&v.id].helicopter,
                        )
                        .is_err()
                    {
                        return Array::new();
                    }
                    context
                        .advance_infantry(
                            id,
                            dt,
                            &Profiles {
                                unit: &|s| {
                                    let p = &men[&s.identity.unit];
                                    Unit {
                                        bearer: p.profile.bearer,
                                        healing: p.healing,
                                        building: p.building,
                                        weapon: profiles
                                            .get(&p.weapon)
                                            .map(|w| (p.weapon.as_str(), w.0.weapon)),
                                    }
                                },
                                weapon: &profile,
                                gun: &|st| guns.get(&st.id).copied().flatten(),
                                build_time: &|st| buildings.get(&st.kind).and_then(|p| p.time),
                                defense: &defense,
                                armor: &armor,
                                vehicle_hit: &|v| vehicles[&v.id].hit,
                                transport: &|v| {
                                    let p = &vehicles[&v.id];
                                    frontline_core::infantry_travel_owned::Transport {
                                        seats: p.seats,
                                        helicopter: p.helicopter,
                                        boat: p.base == "boat",
                                    }
                                },
                            },
                            &mut Tick {
                                search: &search,
                                gunfire: &mut self.gunfire,
                                network: &mut network.bind_mut().core,
                                impacts: &mut impacts,
                                chat: &mut chat,
                                owned: &owned,
                                players: &players,
                                depots,
                                medicine: [upgrades[0] != 0, upgrades[1] != 0],
                                optics: [upgrades[2] != 0, upgrades[3] != 0],
                                warheads: [upgrades[4] != 0, upgrades[5] != 0],
                                squad_names: [&names[0], &names[1]],
                            },
                        )
                        .map(|events| {
                            events
                                .into_iter()
                                .filter_map(|e| match e {
                                    InfantryEvent::Combat(e) => Some(e),
                                    InfantryEvent::Prison(
                                        frontline_core::infantry_prison_owned::Event::Taken {
                                            ..
                                        },
                                    ) => Some(fighting::Event::World(world_combat::Event::Stat(
                                        "prisoner_taken",
                                    ))),
                                    InfantryEvent::Prison(
                                        frontline_core::infantry_prison_owned::Event::Speech {
                                            captor,
                                            cue,
                                        },
                                    ) => Some(fighting::Event::Speech {
                                        id: captor,
                                        text: [
                                            "Move! Hands where I can see them!",
                                            "On your feet! Walk!",
                                            "Easy... keep those hands up.",
                                        ][cue as usize]
                                            .into(),
                                    }),
                                    _ => None,
                                })
                                .collect()
                        })
                } else if mode == 4 {
                    let Some(warhead) = read::<f64>(&input, 6) else {
                        return Array::new();
                    };
                    context.advance_infantry_action(id, warhead, &defense)
                } else if mode == 3 {
                    let Some(owned) = read::<PackedInt64Array>(&input, 6) else {
                        return Array::new();
                    };
                    let Some(owned) = owned
                        .as_slice()
                        .iter()
                        .map(|&id| u32::try_from(id).ok())
                        .collect::<Option<Vec<_>>>()
                    else {
                        return Array::new();
                    };
                    context.advance_mount(
                        id,
                        dt,
                        gun,
                        &owned,
                        &profile,
                        &defense,
                        &mut self.gunfire,
                        &mut network.bind_mut().core,
                        &mut impacts,
                        &armor,
                        &|v| vehicles[&v.id].hit,
                    )
                } else if mode == 2 {
                    let Some(rate) = read::<f64>(&input, 6) else {
                        return Array::new();
                    };
                    let time = input.at(7);
                    let build_time = if time.is_nil() {
                        None
                    } else {
                        let Ok(time) = time.try_to::<f64>() else {
                            return Array::new();
                        };
                        Some(time)
                    };
                    context.advance_build(
                        id,
                        dt,
                        rate,
                        build_time,
                        gun,
                        &profile,
                        &mut self.gunfire,
                        &mut network.bind_mut().core,
                        &mut impacts,
                        &armor,
                        &|v| vehicles[&v.id].hit,
                    )
                } else if mode == 1 {
                    context.advance_breach(
                        id,
                        dt,
                        gun,
                        &profile,
                        &mut self.gunfire,
                        &mut network.bind_mut().core,
                        &mut impacts,
                        &armor,
                        &|v| vehicles[&v.id].hit,
                    )
                } else {
                    context.advance_fighting(
                        id,
                        dt,
                        gun,
                        &mut chat,
                        &profile,
                        &mut self.gunfire,
                        &mut network.bind_mut().core,
                        &mut impacts,
                        &armor,
                        &|v| vehicles[&v.id].hit,
                    )
                };
                reports = Some(impacts);
                chat_state = Some(PackedFloat64Array::from(chat.as_slice()));
                result.map(|events| {
                    if mode >= 3 {
                        use frontline_core::infantry_action_owned::Event as Ordnance;
                        construction = Some(events.iter().filter_map(|e| match e {
                            fighting::Event::Ordnance(Ordnance::Mortar(p)) => Some(varray!["mortar", vector(*p)].to_variant()),
                            fighting::Event::Ordnance(Ordnance::Launch { position, direction }) => Some(varray!["launch", vector(*position), vector(*direction)].to_variant()),
                            fighting::Event::Ordnance(Ordnance::Door(id)) => context.actors.structure(*id).map(|st| varray!["door", vector(st.position + frontline_core::vector::Vector3::Y)].to_variant()),
                            fighting::Event::Ordnance(Ordnance::Melee { position, .. }) => Some(varray!["melee", vector(*position)].to_variant()),
                            fighting::Event::Movement { event: frontline_core::infantry_travel_owned::Event::Door { id, kicked: true }, .. } => context.actors.structure(*id).map(|st| varray!["door", vector(st.position + frontline_core::vector::Vector3::Y)].to_variant()),
                            fighting::Event::World(world_combat::Event::Structure { id, damage }) if damage.events.contains(&frontline_core::structure_damage::Event::Door) => damage.removed.as_deref().or_else(|| context.actors.structure(*id)).map(|st| varray!["door", vector(st.position + frontline_core::vector::Vector3::Y)].to_variant()),
                            _ => None,
                        }).collect());
                    }
                    if let Some(state) = plan_state { vehicle_effects.push(&state); }
                    if let Some(state) = income_state { vehicle_effects.push(&state); }
                    if let Some(events) = construction.as_mut() { events.extend_array(&cannon_effects); events.extend_array(&vehicle_effects); }
                    if mode == 2 || mode == 5 {
                        use frontline_core::infantry_build_world::Construction;
                        let work: Array<Variant> = events.iter().filter_map(|e| {
                            let fighting::Event::Construction(event) = e else { return None };
                            Some(match event {
                                Construction::Completed { id, kind } => {
                                    construction_stats.push("built");
                                    construction_stats.push(&GString::from(&format!("built_{kind}")));
                                    varray!["completed", *id, &GString::from(kind.as_str())].to_variant()
                                },
                                Construction::FobRestored { id } => varray!["restored", *id].to_variant(),
                                Construction::TrackRepaired { id } => varray!["track", *id].to_variant(),
                                Construction::Sound { position } => varray!["sound", vector(*position)].to_variant(),
                            })
                        }).collect();
                        if let Some(events) = construction.as_mut() {
                            events.extend_array(&work);
                        } else {
                            construction = Some(work);
                        }
                    }
                    cries = Some(
                        events
                            .iter()
                            .filter_map(|e| match e {
                                fighting::Event::Speech { id, text } => {
                                    Some(varray![*id, &GString::from(text.as_str())].to_variant())
                                }
                                fighting::Event::Movement { id, event: frontline_core::infantry_travel_owned::Event::BreachSpeech(cue) } => Some(
                                    varray![*id, ["Breaching!", "Door!", "Kicking it in!"][*cue as usize]].to_variant()
                                ),
                                fighting::Event::Movement { id, event: frontline_core::infantry_travel_owned::Event::ThrowSpeech(round) } => Some(
                                    varray![*id, if *round == frontline_core::infantry_action::Round::Smoke { "Smoke out!" } else { "Frag out!" }].to_variant()
                                ),
                                fighting::Event::Movement { id, event: frontline_core::infantry_travel_owned::Event::GotAmmo } => Some(varray![*id, "Got ammo."].to_variant()),
                                fighting::Event::World(world_combat::Event::InfantryHit {
                                    id,
                                    hit,
                                }) | fighting::Event::World(world_combat::Event::Vehicle(Event::Passenger { id, hit })) => hit.speech.map(|cue| {
                                    varray![
                                        *id,
                                        ["I'm hit!", "Argh!", "Took one!", "Hit! I'm hit!"]
                                            [cue as usize]
                                    ]
                                    .to_variant()
                                }),
                                fighting::Event::World(world_combat::Event::Infantry(victim)) => victim.hit.as_ref().and_then(|hit| hit.speech).map(|cue| {
                                    varray![victim.soldier, ["I'm hit!", "Argh!", "Took one!", "Hit! I'm hit!"][cue as usize]].to_variant()
                                }),
                                fighting::Event::World(world_combat::Event::Vehicle(Event::Bailout { vehicle, survivors, .. })) => survivors.first().map(|id| {
                                    varray![*id, if vehicle.team == 0 { "Bail out! Bail out!" } else { "Out! Get out, it's burning!" }].to_variant()
                                }),
                                fighting::Event::World(world_combat::Event::Speech(speech)) => {
                                    Some(
                                        varray![
                                            speech.soldier,
                                            [
                                                "I'm pinned!",
                                                "Can't move!",
                                                "Heads down!",
                                                "They've got us pinned!"
                                            ][speech.cue as usize]
                                        ]
                                        .to_variant(),
                                    )
                                }
                                _ => None,
                            })
                            .collect(),
                    );
                    events
                        .into_iter()
                        .filter_map(|e| match e {
                            fighting::Event::World(e) => Some(e),
                            fighting::Event::Movement {
                                event: frontline_core::infantry_travel_owned::Event::Stat(s),
                                ..
                            } => Some(world_combat::Event::Stat(s)),
                            _ => None,
                        })
                        .collect()
                })
            }
            Operation::Wounded(id, input, mut network, mut impacts) => {
                let result = context.advance_wounded(
                    id,
                    input,
                    &mut self.gunfire,
                    &mut network.bind_mut().core,
                    &mut impacts,
                    &armor,
                    &|v| vehicles[&v.id].hit,
                );
                reports = Some(impacts);
                result.map(|events| {
                    cries = Some(
                        events
                            .iter()
                            .filter_map(|e| match e {
                                wounded::Event::Cry { id, cue } => {
                                    Some(varray![*id, i32::from(*cue)].to_variant())
                                }
                                _ => None,
                            })
                            .collect(),
                    );
                    events
                        .into_iter()
                        .filter_map(|e| match e {
                            wounded::Event::World(e) => Some(e),
                            wounded::Event::Movement {
                                event: frontline_core::infantry_travel_owned::Event::Stat(s),
                                ..
                            } => Some(world_combat::Event::Stat(s)),
                            _ => None,
                        })
                        .collect()
                })
            }
            Operation::Bullet(input, mut network, mut impacts) => {
                let parse = || -> Option<_> {
                    if input.len() != 6 {
                        return None;
                    }
                    let shooter: u32 = read(&input, 0)?;
                    let target: u32 = read(&input, 1)?;
                    let muzzle = crate::point(read(&input, 2)?);
                    let aim = crate::point(read(&input, 3)?);
                    let values: PackedFloat64Array = read(&input, 4)?;
                    let sound = read::<GString>(&input, 5)?.to_string();
                    Some((shooter, target, muzzle, aim, values, sound))
                };
                let Some((shooter, target, muzzle, aim, values, sound)) = parse() else {
                    return Array::new();
                };
                let v = values.as_slice();
                if v.len() != 12
                    || v.iter().any(|v| !v.is_finite())
                    || ![3, 7, 9, 10].iter().all(|i| v[*i] == 0.0 || v[*i] == 1.0)
                    || v[4].fract() != 0.0
                    || !(0.0..=3.0).contains(&v[4])
                {
                    return Array::new();
                }
                let shot = Shot {
                    shooter,
                    target,
                    muzzle,
                    aim,
                    sound: &sound,
                    weapon: Weapon {
                        accuracy: v[0],
                        range: v[1],
                        damage: v[2],
                        anti_air: v[3] != 0.0,
                        penetration: v[4] as u8,
                        drone_accuracy: v[5],
                        explosive_radius: (v[6] != -1.0).then_some(v[6]),
                        airburst: v[7] != 0.0,
                    },
                    accuracy: v[8],
                    optics: v[9] != 0.0,
                    piercing: v[10] != 0.0,
                    suppression: v[11],
                };
                let result = context.fire_bullet(
                    shot,
                    &mut self.gunfire,
                    &mut network.bind_mut().core,
                    &mut impacts,
                    &armor,
                    &|v| vehicles[&v.id].hit,
                );
                reports = Some(impacts);
                result
            }
            Operation::Damage(id, amount, source) => {
                context.damage(id, amount, source).map(|events| {
                    events
                        .into_iter()
                        .map(world_combat::Event::Vehicle)
                        .collect()
                })
            }
            Operation::Explosion(blast, mut network, mut impacts) => {
                let result =
                    context.explode(blast, &mut network.bind_mut().core, &mut impacts, &armor);
                reports = Some(impacts);
                result
            }
            Operation::Deferred(mut network, mut impacts) => {
                let result =
                    context.flush_deferred(&mut network.bind_mut().core, &mut impacts, &armor);
                reports = Some(impacts);
                result
            }
        };
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
        let mut stats: PackedStringArray = events
            .iter()
            .filter_map(|e| match e {
                world_combat::Event::Stat(s)
                | world_combat::Event::Vehicle(
                    Event::Stat(s) | Event::Squad(squad_movement::Event::Stat(s)),
                ) => Some(GString::from(*s)),
                world_combat::Event::Structure { damage, .. }
                    if damage.events.iter().any(|e| {
                        matches!(e, frontline_core::structure_damage::Event::CacheCookOff(_))
                    }) =>
                {
                    Some(GString::from("cache_cook_off"))
                }
                _ => None,
            })
            .collect();
        stats.extend_array(&construction_stats);
        let mut out = varray![next as i64, &states, &stats];
        if let Some(reports) = reports {
            let rows: Array<Variant> = reports
                .into_iter()
                .map(|r| {
                    varray![
                        Vector3::new(r.position.x, r.position.y, r.position.z),
                        r.time
                    ]
                    .to_variant()
                })
                .collect();
            out.push(&rows.to_variant());
        }
        if cries.is_some()
            || events
                .iter()
                .any(|e| matches!(e, world_combat::Event::Shot { .. }))
        {
            let effects: Array<Variant> = events
                .iter()
                .filter_map(|e| match e {
                    world_combat::Event::Shot {
                        shooter,
                        muzzle,
                        end,
                        impact,
                        sound,
                        ..
                    } => Some(
                        varray![
                            "shot",
                            vector(*muzzle),
                            vector(*end),
                            i32::from(*impact),
                            &GString::from(sound.as_str()),
                            *shooter
                        ]
                        .to_variant(),
                    ),
                    world_combat::Event::Ricochet {
                        position,
                        direction,
                    } => Some(
                        varray!["ricochet", vector(*position), vector(*direction)].to_variant(),
                    ),
                    _ => None,
                })
                .collect();
            out.push(&effects.to_variant());
        }
        if let Some(cries) = cries {
            out.push(&cries.to_variant());
        }
        if let Some(chat) = chat_state {
            out.push(&chat.to_variant());
        }
        if let Some(construction) = construction {
            out.push(&construction.to_variant());
        }
        if let Some(recruitment) = recruitment {
            out.push(&recruitment.to_variant());
        }
        if let Some(services) = services {
            out.push(&services.to_variant());
        }
        out
    }
}
