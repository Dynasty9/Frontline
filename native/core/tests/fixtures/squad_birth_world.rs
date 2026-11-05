#[allow(dead_code)]
#[path = "vehicle_loss_world.rs"]
mod shared;
use frontline_core::infantry_spawn::Loadout;
use frontline_core::squad_birth::{Definition, Spawn};
use frontline_core::vector::Vector3;
fn block(out: &mut Vec<u8>, data: &[u8]) {
    out.extend_from_slice(&(data.len() as u32).to_le_bytes());
    out.extend_from_slice(data);
}
fn state(scene: &shared::Scene) -> Vec<u8> {
    let mut bytes = vec![];
    block(&mut bytes, &scene.world.actors.checkpoint().unwrap());
    block(&mut bytes, &scene.world.geometry.checkpoint());
    block(&mut bytes, &scene.world.battle.checkpoint());
    for q in &scene.world.squads {
        block(&mut bytes, &q.checkpoint().unwrap());
    }
    bytes.extend_from_slice(&scene.next.to_le_bytes());
    bytes.extend_from_slice(&scene.world.rng.state().to_le_bytes());
    bytes
}
pub fn transcript() -> Vec<u8> {
    let mut out = vec![];
    for trial in 0..32 {
        let mut vehicle = shared::vehicle(20, "tank");
        if let frontline_core::actors::Actor::Vehicle(v) = &mut vehicle {
            v.team = trial % 2;
            v.owner = trial as i32 - 2;
        }
        let mut scene = shared::Scene::new(vec![vehicle], trial as u64 + 157);
        let members: Vec<Loadout> = (0..3 + trial % 7)
            .map(|i| Loadout {
                unit: if i % 3 == 0 { "medic" } else { "rifleman" }.into(),
                weapon: "rifle".into(),
                hp: 90.,
                magazine: 30,
                ammunition: 120,
                grenades: 2,
                smokes: 1,
                rockets: 0,
                mortar_rounds: 0,
                drones: 0,
                bearer: false,
            })
            .collect();
        for step in 0..4 {
            let profile = || Definition {
                kind: "test_squad",
                name: "Test Squad",
                members: &members,
                armor_upgrade: trial % 3 == 0,
                grenade_upgrade: trial % 4 == 0,
            };
            let spawn = Spawn {
                team: trial % 2,
                owner: trial as i32 - 2,
                position: Vector3::new(-3.7, 0., 1.3),
                destination: if step == 1 {
                    Some(Vector3::new(11.7, 0., -9.3))
                } else if step == 3 {
                    Some(Vector3::new(-3.4, 0., 1.5))
                } else {
                    None
                },
            };
            let mut resumed = scene.resume();
            if step == 2 {
                assert_eq!(
                    scene.context().embark_new_squad(20, profile()).unwrap(),
                    resumed.context().embark_new_squad(20, profile()).unwrap()
                );
            } else {
                assert_eq!(
                    scene.context().spawn_squad(spawn, profile()).unwrap(),
                    resumed.context().spawn_squad(spawn, profile()).unwrap()
                );
            }
            let bytes = state(&scene);
            assert_eq!(bytes, state(&resumed));
            block(&mut out, &bytes);
            scene = resumed;
        }
    }
    out
}
