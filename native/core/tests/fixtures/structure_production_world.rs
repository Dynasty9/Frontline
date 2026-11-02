#[allow(dead_code)]
#[path = "squad_movement_world.rs"]
mod movement;
#[allow(dead_code)]
#[path = "vehicle_loss_world.rs"]
mod shared;
use frontline_core::boat_navigation::BoatNavigation;
use frontline_core::command_ownership::{Away, Ownership};
use frontline_core::economy::Economy;
use frontline_core::infantry_spawn::Loadout;
use frontline_core::squad_birth::Definition;
use frontline_core::structure::Production;
use frontline_core::structure_production::{Event, Product, Profiles};
use frontline_core::vector::Vector3;
use frontline_core::vehicle_birth;
fn member() -> Loadout {
    Loadout {
        unit: "rifleman".into(),
        weapon: "rifle".into(),
        hp: 100.,
        magazine: 30,
        ammunition: 120,
        grenades: 2,
        smokes: 1,
        rockets: 0,
        mortar_rounds: 0,
        drones: 0,
        bearer: false,
    }
}
fn squad(m: &[Loadout]) -> Definition<'_> {
    Definition {
        kind: "rifle_squad",
        name: "Rifle Squad",
        members: m,
        armor_upgrade: false,
        grenade_upgrade: false,
    }
}
fn update(
    s: &mut shared::Scene,
    e: &mut Economy,
    o: &mut Ownership,
    b: &mut BoatNavigation,
    kind: &str,
    members: &[Loadout],
    dt: f64,
    cap: u32,
) -> Vec<Event> {
    let p = if s.world.actors.structure(30).unwrap().queue.is_empty() {
        None
    } else {
        Some(match kind {
            "rifle_squad" => Product::Squad(squad(members)),
            "armor" | "grenades" => Product::Research {
                key: kind,
                name: kind,
            },
            _ => Product::Vehicle {
                definition: vehicle_birth::Definition {
                    kind,
                    base: kind,
                    hp: 500.,
                    hull: Vector3::new(2., 2., 4.),
                    missiles: [3, 4],
                },
                name: "Carrier",
                cap: 3,
                air: matches!(kind, "lift_heli" | "uav"),
                supply: false,
                automatic: kind == "uav",
                passengers: (kind == "lift_heli" || kind == "boat").then(|| squad(members)),
            },
        })
    };
    s.context()
        .advance_production(
            30,
            dt,
            Profiles {
                product: p,
                base_cap: cap,
                cap_per_fob: 20,
                vehicle_cap: &|_| 3,
            },
            e,
            o,
            b,
        )
        .unwrap()
}
fn state(s: &shared::Scene, e: &Economy, o: &Ownership, b: &BoatNavigation) -> [Vec<u8>; 8] {
    let mut squads = vec![];
    for q in &s.world.squads {
        let bytes = q.checkpoint().unwrap();
        squads.extend_from_slice(&(bytes.len() as u32).to_le_bytes());
        squads.extend_from_slice(&bytes);
    }
    [
        s.world.actors.checkpoint().unwrap(),
        s.world.geometry.checkpoint(),
        s.world.battle.checkpoint(),
        e.checkpoint().unwrap(),
        o.checkpoint().unwrap(),
        b.checkpoint(),
        squads,
        [s.world.rng.state().to_le_bytes(), s.next.to_le_bytes()].concat(),
    ]
}
pub fn transcript() -> Vec<u8> {
    let mut out = vec![];
    for trial in 0..12 {
        for kind in [
            "rifle_squad",
            "tank",
            "boat",
            "lift_heli",
            "uav",
            "armor",
            "grenades",
        ] {
            let research = matches!(kind, "armor" | "grenades");
            let mut building = shared::shared::structure(
                30,
                if research {
                    "research"
                } else if kind == "boat" {
                    "dock"
                } else {
                    "factory"
                },
                0.,
            );
            building.yaw = trial as f64 * 0.317 - 1.3;
            building.queue = vec![Production {
                item: kind.into(),
                remaining: 0.3,
                total: 10.,
                owner: 7,
                cost: 90,
            }];
            building.tick_timer = 0.2;
            building.built = trial % 11 != 0;
            if trial % 2 == 0 {
                building.rally = Some(Vector3::new(9.3, 0., 10.7));
            }
            let mut s = shared::Scene::new(vec![shared::shared::actor(building)], 3917 + trial);
            let mut b =
                BoatNavigation::from_terrain(&s.world.geometry.terrain, &vec![0; 32 * 32]).unwrap();
            let mut e = Economy {
                upgrades: [
                    if trial % 3 == 0 {
                        vec!["armor".into(), "grenades".into()]
                    } else {
                        vec![]
                    },
                    vec![],
                ],
            };
            let mut o = Ownership {
                players: if trial % 3 == 0 {
                    vec![(7, 0)]
                } else if trial % 3 == 1 {
                    vec![(8, 0), (9, 1), (10, 0)]
                } else {
                    vec![]
                },
                away: vec![Away {
                    peer: 7,
                    ..Default::default()
                }],
            };
            let members = vec![member(); 4];
            let mut previous: [Vec<u8>; 8] = std::array::from_fn(|_| vec![]);
            for step in 0..4 {
                let dt = [0.1, 0.5, 1., 0.2][step];
                s.world.now += dt;
                let mut r = s.resume();
                let mut re = Economy::restore(&e.checkpoint().unwrap()).unwrap();
                let mut ro = Ownership::restore(&o.checkpoint().unwrap()).unwrap();
                let mut rb = BoatNavigation::restore(&b.checkpoint()).unwrap();
                let cap = if trial % 4 == 0 && step < 3 { 0 } else { 6 };
                let events = update(&mut s, &mut e, &mut o, &mut b, kind, &members, dt, cap);
                assert_eq!(
                    events,
                    update(&mut r, &mut re, &mut ro, &mut rb, kind, &members, dt, cap)
                );
                for w in [&mut s.world, &mut r.world] {
                    w.geometry
                        .navigation
                        .process_paths(&mut w.actors, 32, w.now, &mut w.rng)
                        .unwrap();
                }
                let bytes = state(&s, &e, &o, &b);
                assert_eq!(bytes, state(&r, &re, &ro, &rb));
                for (before, after) in previous.iter_mut().zip(bytes) {
                    movement::checkpoint_delta(&mut out, before, after);
                }
                let events = format!("{trial}/{step} {events:?}").into_bytes();
                out.extend_from_slice(&(events.len() as u32).to_le_bytes());
                out.extend_from_slice(&events);
                s = r;
            }
        }
    }
    out
}
