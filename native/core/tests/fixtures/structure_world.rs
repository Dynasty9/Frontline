#[allow(dead_code)]
#[path = "squad_movement_world.rs"]
mod movement;
#[allow(dead_code)]
#[path = "vehicle_loss_world.rs"]
mod shared;
use frontline_core::actors::Actor;
use frontline_core::infantry_vitals::Life;
use frontline_core::squad::Report;
use frontline_core::structure::TownEconomy;
use frontline_core::structure_services::Supply;
use frontline_core::structure_world::{Event, Profiles, Victory};
use frontline_core::supply_network::SupplyNetwork;
use frontline_core::vector::Vector3;
use frontline_core::vehicle_damage::Armor;

fn update(
    scene: &mut shared::Scene,
    network: &mut SupplyNetwork,
    victory: &mut Victory,
    impacts: &mut Vec<Report>,
    kind: &str,
    dt: f64,
) -> Vec<Event> {
    let mut ctx = scene.context();
    ctx.movement = &|s| frontline_core::squad_movement::ManProfile {
        bearer: s.identity.unit == "bearer",
        weapon_range: None,
    };
    if kind == "mines" {
        ctx.advance_mine(30, dt, network, impacts, &|_| Armor {
            level: 0,
            helicopter: false,
            boat: false,
            supply: false,
            toss: 1.,
        })
        .unwrap()
    } else {
        ctx.advance_territory(
            30,
            dt,
            &Profiles {
                fob_radius: 4.,
                town: [
                    TownEconomy {
                        stock: 180.,
                        yield_per_minute: 24.,
                        capture_pace: 1.,
                    },
                    TownEconomy {
                        stock: 420.,
                        yield_per_minute: 60.,
                        capture_pace: 0.6,
                    },
                ],
                supply: &|_| Supply {
                    ammunition: None,
                    frags: 0,
                    loadout: None,
                },
            },
            network,
            victory,
        )
        .unwrap()
    }
}
fn state(scene: &shared::Scene, network: &SupplyNetwork) -> [Vec<u8>; 8] {
    [
        scene.world.actors.checkpoint().unwrap(),
        scene.world.geometry.checkpoint(),
        scene.world.battle.checkpoint(),
        scene.world.deferred.checkpoint(),
        scene.world.visibility.checkpoint(),
        scene.fires.checkpoint(),
        network.checkpoint().unwrap(),
        scene.world.rng.state().to_le_bytes().to_vec(),
    ]
}
pub fn transcript() -> Vec<u8> {
    let mut out = vec![];
    for trial in 0..16 {
        for kind in ["fob", "town", "mines"] {
            let mut st = shared::shared::structure(30, kind, 0.);
            st.name = "Crossroads".into();
            st.variant = trial % 2;
            st.team = if kind == "town" && trial % 4 == 0 {
                -1
            } else {
                0
            };
            st.tick_timer = if trial % 3 == 0 { 0.7 } else { 0. };
            st.built = trial % 11 != 0;
            st.wrecked = trial % 9 == 0;
            st.supply = [0., 0.5, 27.3, 179.9][trial as usize % 4];
            st.capture_progress = if trial % 3 == 0 { 0. } else { 99.9 };
            st.capture_team = if trial % 3 == 0 { -1 } else { 1 };
            st.zone_center = Some(Vector3::new(0.7, 0., 0.4));
            st.zone_radius = 6.;
            st.initial_houses = if trial % 2 == 0 { 5 } else { -1 };
            st.intact = 0.1;
            let mut entries = vec![shared::shared::actor(st)];
            for (id, x) in [(31, -13.), (32, 13.), (33, -10.), (34, 10.)] {
                if id == 33 && trial % 2 != 0 {
                    continue;
                }
                let mut s = shared::shared::structure(id, if id < 33 { "depot" } else { "fob" }, x);
                s.team = if id % 2 == 0 { 1 } else { 0 };
                s.name = "Rear".into();
                s.position.z = if id < 33 { -12. } else { 12. };
                entries.push(shared::shared::actor(s));
            }
            if kind == "town" {
                entries.push(shared::shared::actor(shared::shared::structure(
                    35, "roof", 3.,
                )));
            }
            for id in 1..=6 {
                let mut s = shared::shared::soldier(
                    id,
                    id as f32 * 0.35 - 1.2,
                    if trial % 5 == 0 {
                        Life::Downed
                    } else {
                        Life::Alive
                    },
                );
                s.identity.team = if trial % 4 == 0 && id <= 3 { 0 } else { 1 };
                s.identity.unit = if id == 1 { "bearer" } else { "rifleman" }.into();
                s.identity.owner = 8;
                entries.push(Actor::Soldier(Box::new(s)));
            }
            let mut scene = shared::Scene::new(entries, 3917 + trial as u64);
            let mut network = SupplyNetwork {
                depots: [31, 32],
                towns: if kind == "town" { vec![30] } else { vec![] },
                ..Default::default()
            };
            let mut victory = Victory {
                winner: -1,
                mission: trial % 4 == 0,
            };
            let mut impacts = vec![];
            let mut previous = std::array::from_fn::<_, 8, _>(|_| vec![]);
            for step in 0..8 {
                if scene.world.actors.get(30).is_none() {
                    break;
                }
                let dt = [0.1, 0.5, 1.][step % 3];
                scene.world.now += dt;
                let mut resumed = scene.resume();
                let mut rn = SupplyNetwork::restore(&network.checkpoint().unwrap()).unwrap();
                let mut rv = victory;
                let mut ri = impacts.clone();
                let events = update(
                    &mut scene,
                    &mut network,
                    &mut victory,
                    &mut impacts,
                    kind,
                    dt,
                );
                assert_eq!(
                    events,
                    update(&mut resumed, &mut rn, &mut rv, &mut ri, kind, dt)
                );
                assert_eq!(victory, rv);
                assert_eq!(impacts, ri);
                let bytes = state(&scene, &network);
                assert_eq!(bytes, state(&resumed, &rn));
                for (before, after) in previous.iter_mut().zip(bytes) {
                    movement::checkpoint_delta(&mut out, before, after);
                }
                let e = format!("{trial}/{step} {events:?} {victory:?} {impacts:?}").into_bytes();
                out.extend_from_slice(&(e.len() as u32).to_le_bytes());
                out.extend_from_slice(&e);
                scene = resumed;
            }
        }
    }
    out
}
