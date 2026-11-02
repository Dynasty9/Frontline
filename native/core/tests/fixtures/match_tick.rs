#[path = "aircraft_world.rs"]
#[allow(dead_code)]
mod aircraft;
#[path = "boat_world.rs"]
#[allow(dead_code)]
mod boat;
#[path = "vehicle_world.rs"]
#[allow(dead_code)]
pub mod ground;
#[path = "infantry_world.rs"]
#[allow(dead_code)]
pub mod infantry;
#[path = "vehicle_loss_world.rs"]
#[allow(dead_code)]
pub mod shared;
use frontline_core::actors::Actor;
use frontline_core::boat_navigation::BoatNavigation;
use frontline_core::infantry_travel_owned::Transport;
use frontline_core::infantry_world::{Profiles as InfantryProfiles, Unit};
use frontline_core::match_state::{Battlefield, MatchState, Shared};
use frontline_core::match_tick::{Profiles, VehicleProfile};
use frontline_core::rules_logistics::TruckProfile;
use frontline_core::rules_world::{self, PrisonerProfile};
use frontline_core::squad_birth::Definition;
use frontline_core::squad_duties::Role;
use frontline_core::squad_world;
use frontline_core::structure::{Structure, TownEconomy};
use frontline_core::structure_production::Product;
use frontline_core::structure_services::Supply;
use frontline_core::structure_world::Victory;
use frontline_core::structures_tick;
use frontline_core::vector::Vector3;
use frontline_core::vehicle_birth;
use frontline_core::vehicle_service::SoldierSupply;
use frontline_core::water::Water;

pub fn state(entries: Vec<Actor>) -> MatchState {
    let scene = shared::Scene::new(entries, 137);
    let f = scene.world;
    let boats = BoatNavigation::from_terrain(&f.geometry.terrain, &[0; 32 * 32]).unwrap();
    MatchState {
        field: Battlefield {
            actors: f.actors,
            geometry: f.geometry,
            units: f.units,
            squads: f.squads,
            next_squad: scene.next,
            fires: scene.fires,
            battle: f.battle,
            deferred: f.deferred,
            visibility: f.visibility,
            rng: f.rng,
            now: f.now,
            town: [0.; 4],
        },
        tick: 6000,
        rules: Default::default(),
        owners: Default::default(),
        water: Water {
            side: 32,
            coast: None,
            rivers: vec![],
            ponds: vec![],
            fords: vec![],
            bridges: vec![],
        },
        boats,
        attacks: vec![],
        ambushes: vec![],
        next_attack: 1,
        next_ambush: 1,
        gunfire: Default::default(),
        impacts: vec![],
        chat: [0.; 2],
        victory: Victory {
            winner: -1,
            mission: false,
        },
        scenario: true,
    }
}
pub fn with_profiles<T>(f: impl FnOnce(&Profiles<'_>) -> T) -> T {
    let mut source = shared::Scene::new(vec![], 0);
    let context = source.context();
    let unit = |_: &frontline_core::infantry::Infantry| Unit {
        bearer: false,
        healing: 1.,
        building: 1.,
        weapon: Some(("rifle", infantry::weapon())),
    };
    let names = ["Coalition", "Rebels"];
    let product = |s: &Structure| {
        s.queue.first().map(|q| {
            if q.item == "armor" {
                Product::Research {
                    key: "armor",
                    name: "Armor",
                }
            } else if q.item == "tank" {
                Product::Vehicle {
                    definition: vehicle_birth::Definition {
                        kind: "tank",
                        base: "tank",
                        hp: 500.,
                        hull: Vector3::new(3., 2., 5.),
                        missiles: [0, 0],
                        tracked: false,
                    },
                    name: "Tank",
                    cap: 3,
                    air: false,
                    supply: false,
                    automatic: false,
                    passengers: None,
                }
            } else {
                Product::Squad(Definition {
                    kind: "rifle_squad",
                    name: "Rifle Squad",
                    members: &context.crew_loadouts[0..1],
                    armor_upgrade: false,
                    grenade_upgrade: false,
                })
            }
        })
    };
    let mut bearer = context.crew_loadouts[0].clone();
    bearer.bearer = true;
    bearer.weapon.clear();
    bearer.magazine = 0;
    bearer.ammunition = 0;
    let p = Profiles {
        shared: Shared {
            names: context.names,
            crew_loadouts: context.crew_loadouts,
            crew_name: context.crew_name,
            team_names: &names,
            vehicle: context.vehicle,
            man: context.man,
            movement: context.movement,
            building: context.building,
            role: context.role,
            automatic: context.automatic,
            player_building: context.player_building,
        },
        infantry: InfantryProfiles {
            unit: &unit,
            weapon: &|s| infantry::profile(s),
            gun: &|_| None,
            build_time: &|_| Some(10.),
            defense: &|v| ground::defense(v),
            armor: &ground::armor,
            vehicle_hit: &|_| 2.,
            transport: &|_| Transport {
                seats: 4,
                helicopter: false,
                boat: false,
            },
        },
        buildings: structures_tick::Profiles {
            product: &product,
            base_cap: 600,
            cap_per_fob: 100,
            vehicle_cap: &|_| 3,
            supply: &|_| Supply {
                ammunition: Some(120),
                frags: 2,
                loadout: None,
            },
            bearers: [&bearer, &bearer],
            gun: &|_| None,
            armor: &ground::armor,
            fob_radius: 4.,
            towns: [TownEconomy {
                stock: 100.,
                yield_per_minute: 30.,
                capture_pace: 1.,
            }; 2],
        },
        squads: squad_world::Profiles {
            role: &|_| Role {
                medic: false,
                engineer: false,
            },
            armor: &|_| 1,
            weapon: &|_| Some(infantry::weapon()),
            air: &|s| s == "heli",
        },
        rules: rules_world::Profiles {
            reserves: ["rifle_squad", "fighter_cell"].map(|kind| Definition {
                kind,
                name: "Reserve",
                members: &context.crew_loadouts[0..1],
                armor_upgrade: false,
                grenade_upgrade: false,
            }),
            truck: TruckProfile {
                vehicle: vehicle_birth::Definition {
                    kind: "truck",
                    base: "supply",
                    hp: 240.,
                    hull: Vector3::new(2., 2., 5.),
                    missiles: [0, 0],
                    tracked: false,
                },
                town_load: [50, 20],
                town_stock: [100., 40.],
                supply: [70, 60],
            },
            vehicle: &|_| frontline_core::fog::VehicleProfile {
                sight: 65.,
                helicopter: false,
                automatic: false,
                cannon: true,
            },
            prisoner: &|_| PrisonerProfile {
                weapon: Some(("rifle", 30)),
                squad_name: "Section",
            },
            display: &|s| s.name.clone(),
            item_name: &str::to_owned,
            commanders: &[],
        },
        vehicle: &|v| match v.kind.as_str() {
            "heli" => VehicleProfile::Aircraft(aircraft::air(
                frontline_core::aircraft_world::Kind::Lift { capacity: 2 },
            )),
            "boat" => VehicleProfile::Boat(boat::profile()),
            "arty" => {
                let mut g = ground::ground();
                g.crew.artillery = true;
                g.artillery = Some((
                    frontline_core::vehicle_artillery::ArtilleryProfile {
                        shell: frontline_core::projectile::Kind::Arty,
                        gun_height: 2.2,
                        muzzle: 4.,
                        scatter: 0.,
                        salvo: 2,
                        lay: 0.1,
                        gap: 0.2,
                        cooldown: 18.,
                        traverse: 1.,
                        traverse_accel: 2.,
                    },
                    [5., 230.],
                ));
                VehicleProfile::Ground(g)
            }
            "truck" | "supply" => {
                let mut m = ground::ground().movement;
                m.supply = true;
                VehicleProfile::Truck {
                    movement: m,
                    load: 70,
                }
            }
            _ => VehicleProfile::Ground(ground::ground()),
        },
        soldier_stock: &|_| {
            Ok(SoldierSupply {
                loadout: None,
                restored_weapon: Some(("rifle", 30)),
            })
        },
        vehicle_stock: &|_| Ok([0, 0]),
        squad_names: ["Section", "Section"],
    };
    f(&p)
}

pub fn with_commands<T>(f: impl FnOnce(&frontline_core::match_commands::Profiles<'_>) -> T) -> T {
    f(&frontline_core::match_commands::Profiles {
        building: &|_| None,
        support: &|_| None,
        item: &|_, _| None,
        produces: &|_| &[],
        research: &[],
        vehicle: &|_| Default::default(),
        mount: &|_| None,
        engineer: &|_| false,
        mortar: &|_| false,
        structure_name: &|s| s.name.clone(),
        squad_name: &|s| s.kind.clone(),
        distances: &frontline_core::building_placement::Distances {
            build: 70.,
            fob_spacing: 45.,
            fob_expand: 130.,
        },
        fob_names: &[],
    })
}

#[path = "squad_orders.rs"]
#[allow(dead_code)]
mod differences;
pub fn transcript() -> Vec<u8> {
    use frontline_core::infantry_vitals::Life;
    use frontline_core::perception::PerceptionSearch;
    use frontline_core::structure::Production;
    let mut out = vec![];
    with_profiles(|p| {
        for trial in 0..4 {
            let mut enemy = shared::shared::soldier(2, 12., Life::Alive);
            enemy.identity.team = 1;
            let mut barracks = shared::shared::structure(30, "barracks", -9.);
            barracks.queue.push(Production {
                item: "rifle_squad".into(),
                remaining: 0.001,
                total: 10.,
                owner: 7,
                cost: 100,
            });
            let mut tank = ground::vehicle(20, 0, 6.);
            tank.target = 2;
            let mut s = state(vec![
                Actor::Soldier(Box::new(shared::shared::soldier(1, -8., Life::Alive))),
                Actor::Soldier(Box::new(enemy)),
                shared::shared::actor(barracks),
                Actor::Vehicle(Box::new(tank)),
            ]);
            s.field.rng = frontline_core::random::SimulationRandom::new(137 + trial);
            let mut restored = MatchState::restore(&s.checkpoint().unwrap()).unwrap();
            let mut search = PerceptionSearch::default();
            let mut previous = vec![];
            for _ in 0..32 {
                let mut events = s.advance_battlefield(p, &mut search).unwrap();
                let mut comparison = restored
                    .advance_battlefield(p, &mut PerceptionSearch::default())
                    .unwrap();
                events.extend(s.finish_battlefield(p).unwrap());
                comparison.extend(restored.finish_battlefield(p).unwrap());
                assert_eq!(events, comparison);
                let state = s.checkpoint().unwrap();
                assert_eq!(state, restored.checkpoint().unwrap());
                restored = MatchState::restore(&state).unwrap();
                differences::delta(&mut out, &mut previous, state);
                let data = format!("{events:?}");
                out.extend_from_slice(&(data.len() as u32).to_le_bytes());
                out.extend(data.as_bytes());
            }
        }
    });
    out
}
