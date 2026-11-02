#[allow(dead_code)]
#[path = "squad_movement_world.rs"]
mod movement;
#[allow(dead_code)]
#[path = "vehicle_loss_world.rs"]
mod shared;
use frontline_core::actors::Actor;
use frontline_core::infantry::Infantry;
use frontline_core::infantry_controller::Task;
use frontline_core::infantry_fire::MountedGun;
use frontline_core::infantry_spawn::Loadout;
use frontline_core::infantry_supply;
use frontline_core::infantry_vitals::Life;
use frontline_core::infantry_weapon::Weapon;
use frontline_core::squad_movement::ManProfile;
use frontline_core::structure_services::{Event, Profiles, Supply};
fn stock(_: &Infantry) -> Supply {
    Supply {
        ammunition: Some(120),
        frags: 2,
        loadout: Some(infantry_supply::Loadout {
            ammunition: 120,
            special: [2, 1, 2, 1, 4],
            reload_weapon: Weapon {
                ammunition: 120,
                magazine: 30,
                reload_time: 2.5,
            },
        }),
    }
}
fn update(
    scene: &mut shared::Scene,
    trial: usize,
    step: usize,
    gun: Option<MountedGun>,
) -> Vec<Event> {
    let mut ctx = scene.context();
    ctx.movement = &|s| ManProfile {
        bearer: s.identity.unit == "bearer",
        weapon_range: Some(85.),
    };
    ctx.advance_structure_service(
        30,
        [0.1, 0.5, 1.0][step % 3],
        &Profiles {
            supply: &stock,
            bearer: &Loadout {
                unit: "bearer".into(),
                weapon: String::new(),
                hp: 90.,
                magazine: 0,
                ammunition: 0,
                grenades: 0,
                smokes: 0,
                rockets: 0,
                mortar_rounds: 0,
                drones: 0,
                bearer: true,
            },
            armor_upgrade: trial % 3 == 0,
            grenade_upgrade: trial % 4 == 0,
            gun,
        },
    )
    .unwrap()
}
fn block(out: &mut Vec<u8>, data: &[u8]) {
    out.extend_from_slice(&(data.len() as u32).to_le_bytes());
    out.extend_from_slice(data);
}
fn state(s: &shared::Scene) -> [Vec<u8>; 3] {
    [
        s.world.actors.checkpoint().unwrap(),
        s.world.geometry.checkpoint(),
        s.world.rng.state().to_le_bytes().to_vec(),
    ]
}
pub fn transcript() -> Vec<u8> {
    let mut out = vec![];
    for trial in 0..16 {
        for kind in [
            "medic_tent",
            "watchtower",
            "mg_nest",
            "hmg_nest",
            "mortar_pit",
            "at_post",
            "ammo_cache",
        ] {
            let mut st = shared::shared::structure(30, kind, 0.);
            st.yaw = trial as f64 * 0.317 - 1.3;
            st.variant = (trial % 2) as i32;
            st.supply = [0., 0.5, 1.3, 20.][trial % 4];
            st.bearer_timer = 0.;
            st.tick_timer = if trial % 3 == 0 { 0.7 } else { 0. };
            st.built = trial % 11 != 0;
            if trial % 4 != 0 {
                st.bearers = vec![1, 2];
            }
            if kind == "watchtower" && trial % 2 == 0 {
                st.gunner = 7;
            }
            let mut entries = vec![shared::shared::actor(st)];
            for id in 1..=9 {
                let mut s = shared::shared::soldier(
                    id,
                    id as f32 * 0.71 - 3.,
                    if id < 8 {
                        Life::Alive
                    } else if id == 8 {
                        Life::Downed
                    } else {
                        Life::Dead
                    },
                );
                s.identity.unit = match id {
                    1 | 2 => "bearer",
                    3 => "mg_gunner",
                    4 => "mortar_gunner",
                    5 => "at_soldier",
                    _ => "rifleman",
                }
                .into();
                if id == 1 && trial % 5 == 0 {
                    s.vitals.life = Life::Surrender;
                }
                if id == 2 && trial % 5 == 0 {
                    s.vitals.life = Life::Dead;
                }
                if id <= 2 && trial % 7 == 0 {
                    s.identity.team = 1;
                }
                if id == 7 && kind == "watchtower" && trial % 2 == 0 {
                    s.duty.kind = Task::Man;
                    s.duty.entity = 30;
                    s.duty.phase = 2;
                    s.emplacement.structure = 30;
                }
                s.vitals.downed_at = if trial % 3 == 0 { 99. } else { 91. };
                s.vitals.dead_at = if trial % 4 == 0 { -150. } else { 90. };
                s.weapon.magazine = if id % 3 == 0 { 0 } else { 5 };
                s.weapon.reserve = if trial % 2 == 0 { 47 } else { 0 };
                s.grenades.frags = (trial % 4) as i32;
                entries.push(Actor::Soldier(Box::new(s)));
            }
            let gun = matches!(kind, "mg_nest" | "hmg_nest").then_some(MountedGun {
                bore: 0.1,
                muzzle: 1.2,
                grip_z: 0.3,
                nest_height: 0.7,
                trench_height: 0.5,
            });
            let mut scene = shared::Scene::new(entries, trial as u64 + 117);
            let mut previous: [Vec<u8>; 3] = std::array::from_fn(|_| vec![]);
            for step in 0..8 {
                if scene.world.actors.get(30).is_none() {
                    break;
                }
                scene.world.now += [0.1, 0.5, 1.][step % 3];
                let mut resumed = scene.resume();
                let events = update(&mut scene, trial, step, gun);
                assert_eq!(events, update(&mut resumed, trial, step, gun));
                for w in [&mut scene.world, &mut resumed.world] {
                    w.geometry
                        .navigation
                        .process_paths(&mut w.actors, 32, w.now, &mut w.rng)
                        .unwrap();
                }
                let bytes = state(&scene);
                assert_eq!(bytes, state(&resumed));
                for (before, after) in previous.iter_mut().zip(bytes) {
                    movement::checkpoint_delta(&mut out, before, after);
                }
                out.extend_from_slice(&(events.len() as u32).to_le_bytes());
                for e in events {
                    match e {
                        Event::Born { tent, soldier } => {
                            out.push(0);
                            out.extend_from_slice(&tent.to_le_bytes());
                            out.extend_from_slice(&soldier.to_le_bytes());
                        }
                        Event::Reload { soldier, variant } => {
                            out.push(1);
                            out.extend_from_slice(&soldier.to_le_bytes());
                            out.push(variant);
                        }
                        Event::CacheEmpty { id, team, position } => {
                            out.push(2);
                            out.extend_from_slice(&id.to_le_bytes());
                            out.push(team as u8);
                            for v in position.to_array() {
                                out.extend_from_slice(&v.to_le_bytes());
                            }
                        }
                        Event::Despawn(id) => {
                            out.push(3);
                            out.extend_from_slice(&id.to_le_bytes());
                        }
                        Event::Stat(key) => {
                            out.push(4);
                            block(&mut out, key.as_bytes());
                        }
                    }
                }
                scene = resumed;
            }
        }
    }
    out
}
