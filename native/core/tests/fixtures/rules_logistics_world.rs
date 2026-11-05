#[allow(dead_code)]
#[path = "squad_movement_world.rs"]
mod movement;
#[allow(dead_code)]
#[path = "vehicle_loss_world.rs"]
mod shared;
use frontline_core::command_ownership::Ownership;
use frontline_core::economy::Economy;
use frontline_core::infantry_spawn::Loadout;
use frontline_core::rules_logistics::{Event, TruckProfile};
use frontline_core::squad_birth::Definition;
use frontline_core::supply_network::SupplyNetwork;
use frontline_core::vector::Vector3;
use frontline_core::vehicle_birth;
fn update(
    s: &mut shared::Scene,
    ready: &mut [f64; 2],
    n: &SupplyNetwork,
    e: &Economy,
    o: &Ownership,
    trial: usize,
    dt: f64,
) -> Vec<Event> {
    let members = vec![
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
            bearer: false
        };
        6
    ];
    let defs = ["rifle_squad", "fighter_cell"].map(|kind| Definition {
        kind,
        name: "Reserves",
        members: &members,
        armor_upgrade: false,
        grenade_upgrade: false,
    });
    let mut events = s
        .context()
        .reinforce(ready, n, e, o, defs, trial % 11 == 0, trial % 13 == 0)
        .unwrap();
    if trial % 13 != 0 {
        events.extend(
            s.context()
                .dispatch_supply(
                    dt,
                    n,
                    TruckProfile {
                        vehicle: vehicle_birth::Definition {
                            kind: "truck",
                            base: "supply",
                            hp: 240.,
                            hull: Vector3::new(2., 2.5, 5.),
                            missiles: [0, 0],
                            tracked: false,
                        },
                        town_load: [50, 20],
                        town_stock: [100., 40.],
                        supply: [70, 60],
                    },
                )
                .unwrap(),
        );
    }
    events
}
fn state(
    s: &shared::Scene,
    ready: [f64; 2],
    n: &SupplyNetwork,
    e: &Economy,
    o: &Ownership,
) -> [Vec<u8>; 8] {
    let mut squads = vec![];
    for q in &s.world.squads {
        let b = q.checkpoint().unwrap();
        squads.extend_from_slice(&(b.len() as u32).to_le_bytes());
        squads.extend_from_slice(&b);
    }
    [
        s.world.actors.checkpoint().unwrap(),
        s.world.geometry.checkpoint(),
        s.world.battle.checkpoint(),
        n.checkpoint().unwrap(),
        e.checkpoint().unwrap(),
        o.checkpoint().unwrap(),
        squads,
        [
            ready[0].to_le_bytes(),
            ready[1].to_le_bytes(),
            s.world.rng.state().to_le_bytes(),
            s.next.to_le_bytes(),
        ]
        .concat(),
    ]
}
pub fn transcript() -> Vec<u8> {
    let mut out = vec![];
    for trial in 0..24 {
        let mut entries = vec![];
        for team in 0..2 {
            let mut d =
                shared::shared::structure(30 + team as u32, "depot", -12. + team as f32 * 24.);
            d.team = team;
            entries.push(shared::shared::actor(d));
            let mut f = shared::shared::structure(40 + team as u32, "fob", -4. + team as f32 * 8.);
            f.team = team;
            f.truck_timer = [0., 0.4, 4.][trial % 3];
            f.supply_parent = 30 + team as u32;
            f.road = vec![
                Vector3::new(-11. + team as f32 * 22., 0., -7.),
                Vector3::new(-4. + team as f32 * 8., 0., -7.),
            ];
            f.wrecked = trial % 4 == 0;
            if trial % 7 == 0 {
                f.supply_parent = 0;
            }
            entries.push(shared::shared::actor(f));
            let mut t =
                shared::shared::structure(50 + team as u32, "town", -10. + team as f32 * 20.);
            t.team = team;
            t.truck_timer = [0., 0.4, 4.][(trial + 1) % 3];
            t.supply_parent = 40 + team as u32;
            t.variant = trial as i32 % 4;
            t.supply = [0., 19.9, 20., 39.1, 49.9, 50., 100.7][trial % 7];
            t.road = vec![
                Vector3::new(-10. + team as f32 * 20., 0., 5.),
                Vector3::new(-4. + team as f32 * 8., 0., 5.),
            ];
            if trial % 9 == 0 {
                t.road.clear();
            }
            entries.push(shared::shared::actor(t));
        }
        let mut s = shared::Scene::new(entries, 3917 + trial as u64);
        let n = SupplyNetwork {
            depots: [30, 31],
            towns: vec![50, 51],
            ..Default::default()
        };
        let e = Economy {
            upgrades: [
                if trial % 2 == 0 {
                    vec!["armor".into(), "grenades".into()]
                } else {
                    vec![]
                },
                vec![],
            ],
        };
        let o = Ownership {
            players: if trial % 3 == 0 {
                vec![]
            } else {
                vec![(7, 0), (8, 1), (9, 0)]
            },
            ..Default::default()
        };
        let mut ready = [0.; 2];
        let mut previous: [Vec<u8>; 8] = std::array::from_fn(|_| vec![]);
        for step in 0..6 {
            let dt = [0.1, 0.1, 0.5, 0.5, 8., 1.][step];
            s.world.now = [119.99, 120., 120.5, 195., 196., 271.][step];
            let mut r = s.resume();
            let mut rr = ready;
            let rn = SupplyNetwork::restore(&n.checkpoint().unwrap()).unwrap();
            let re = Economy::restore(&e.checkpoint().unwrap()).unwrap();
            let ro = Ownership::restore(&o.checkpoint().unwrap()).unwrap();
            let events = update(&mut s, &mut ready, &n, &e, &o, trial, dt);
            assert_eq!(events, update(&mut r, &mut rr, &rn, &re, &ro, trial, dt));
            for w in [&mut s.world, &mut r.world] {
                w.geometry
                    .navigation
                    .process_paths(
                        &mut w.actors,
                        32,
                        w.now,
                        &mut w.rng,
                        frontline_core::traversal::Ground::new(
                            &w.geometry.terrain,
                            &w.geometry.deck,
                        ),
                    )
                    .unwrap();
            }
            let bytes = state(&s, ready, &n, &e, &o);
            assert_eq!(bytes, state(&r, rr, &rn, &re, &ro));
            for (before, after) in previous.iter_mut().zip(bytes) {
                movement::checkpoint_delta(&mut out, before, after);
            }
            let b = format!("{trial}/{step} {events:?}").into_bytes();
            out.extend_from_slice(&(b.len() as u32).to_le_bytes());
            out.extend_from_slice(&b);
            s = r;
        }
    }
    out
}
