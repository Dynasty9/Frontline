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
enum Operation {
    Damage(u32, f64, u32),
    Explosion(Explosion, Gd<SupplyNetworkCore>, Vec<Report>),
    Deferred(Gd<SupplyNetworkCore>, Vec<Report>),
    Bullet(Array<Variant>, Gd<SupplyNetworkCore>, Vec<Report>),
    Wounded(u32, WoundedInput, Gd<SupplyNetworkCore>, Vec<Report>),
    Fighting(Array<Variant>, Gd<SupplyNetworkCore>, Vec<Report>),
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
            Operation::Fighting(input, network, reports),
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
                if ![11, 13, 14].contains(&r.len()) {
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
                    hit: if r.len() == 14 { read(&r, 13)? } else { 2.0 },
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
                buildings.get(&st.kind).copied().unwrap_or(BuildingProfile {
                    player: false,
                    value: 0.0,
                })
            },
            role: &|s| men[&s.identity.unit].role.clone(),
            automatic: &|k| automatic.iter().any(|v| v == k),
            player_building: &|k| buildings.get(k).is_some_and(|p| p.player),
        };
        let mut reports = None;
        let mut cries: Option<Array<Variant>> = None;
        let mut chat_state: Option<PackedFloat64Array> = None;
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
            Operation::Fighting(input, mut network, mut impacts) => {
                let parse = || -> Option<_> {
                    if input.len() != 6 {
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
                let result = context.advance_fighting(
                    id,
                    dt,
                    gun,
                    &mut chat,
                    &|s| {
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
                    },
                    &mut self.gunfire,
                    &mut network.bind_mut().core,
                    &mut impacts,
                    &armor,
                    &|v| vehicles[&v.id].hit,
                );
                reports = Some(impacts);
                chat_state = Some(PackedFloat64Array::from(chat.as_slice()));
                result.map(|events| {
                    cries = Some(
                        events
                            .iter()
                            .filter_map(|e| match e {
                                fighting::Event::Speech { id, text } => {
                                    Some(varray![*id, &GString::from(text.as_str())].to_variant())
                                }
                                fighting::Event::World(world_combat::Event::InfantryHit {
                                    id,
                                    hit,
                                }) => hit.speech.map(|cue| {
                                    varray![
                                        *id,
                                        ["I'm hit!", "Argh!", "Took one!", "Hit! I'm hit!"]
                                            [cue as usize]
                                    ]
                                    .to_variant()
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
        let stats: PackedStringArray = events
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
        out
    }
}
