#[allow(dead_code)]
#[path = "vehicle_loss_world.rs"]
mod shared;
use frontline_core::actors::Actor;
use frontline_core::bullet::Weapon;
use frontline_core::bullet_world::{Gunfire, Shot};
use frontline_core::infantry_vitals::Life;
use frontline_core::squad::Squad;
use frontline_core::structure::Structure;
use frontline_core::supply_network::SupplyNetwork;
use frontline_core::vector::Vector3;
use frontline_core::vehicle::Vehicle;
use frontline_core::vehicle_damage::Armor;

fn armor(v: &Vehicle) -> Armor {
    Armor {
        level: if v.kind == "tank" { 2 } else { 0 },
        helicopter: false,
        boat: false,
        supply: false,
        toss: 1.0,
    }
}
fn block(out: &mut Vec<u8>, bytes: &[u8]) {
    out.extend_from_slice(&(bytes.len() as u32).to_le_bytes());
    out.extend_from_slice(bytes);
}
pub fn transcript() -> Vec<u8> {
    let mut out = vec![];
    for trial in 0..8 {
        let mut entries = vec![];
        for id in 1..=6 {
            let mut man = shared::shared::soldier(id, id as f32 * 2.1 - 7.0, Life::Alive);
            man.identity.team = (id % 2) as i8;
            man.identity.owner = 7 + man.identity.team as i32;
            man.identity.squad = 1 + man.identity.team as u32;
            man.motion.position.z = (id % 3) as f32 * 1.2;
            entries.push(Actor::Soldier(Box::new(man)));
        }
        let mut vehicle = shared::vehicle(20, if trial % 2 == 0 { "tank" } else { "robot" });
        if let Actor::Vehicle(v) = &mut vehicle {
            v.hp = 5.0;
            v.position = Vector3::new(3.0, 0.0, -2.0);
        }
        entries.push(vehicle);
        let mut s = shared::Scene::new(entries, 9173 + trial);
        s.world.squads = (0..2)
            .map(|team| Squad {
                id: 1 + team as u32,
                team,
                owner: 7 + team as i32,
                members: (1..=6).filter(|id| (id % 2) as i8 == team).collect(),
                ..Default::default()
            })
            .collect();
        let mut gunfire = Gunfire::default();
        let mut network = SupplyNetwork::default();
        let mut impacts = vec![];
        for (i, kind) in ["car", "crates", "ammo_cache", "low_wall"]
            .into_iter()
            .enumerate()
        {
            s.world
                .geometry
                .spawn_structure(
                    &mut s.world.actors,
                    Structure {
                        kind: kind.into(),
                        position: Vector3::new(i as f32 * 1.7 - 2.0, 0.0, 0.0),
                        variant: (trial % 3) as i32,
                        ..Default::default()
                    },
                    None,
                )
                .unwrap();
        }
        for tick in 0..8 {
            s = s.resume();
            gunfire = Gunfire::restore(&gunfire.checkpoint()).unwrap();
            network = SupplyNetwork::restore(&network.checkpoint().unwrap()).unwrap();
            let id = [2, 20, 4, 3, 0, 6, 20, 2][tick];
            let target = s.world.actors.get(id);
            let aim = target.map_or(Vector3::ZERO, |a| a.position() + Vector3::Y);
            let input = Shot {
                shooter: 1,
                target: if target.is_some() { id } else { 0 },
                muzzle: Vector3::new(-12.0, 1.1, if tick % 2 == 0 { 0.0 } else { -2.0 }),
                aim,
                weapon: Weapon {
                    accuracy: 0.6,
                    range: 80.0,
                    damage: 55.0,
                    anti_air: false,
                    penetration: 3,
                    drone_accuracy: 0.08,
                    explosive_radius: (trial % 2 == 0).then_some(2.2),
                    airburst: trial % 3 == 0,
                },
                accuracy: if tick % 3 == 0 { 10.0 } else { 0.7 },
                optics: trial % 2 == 0,
                piercing: true,
                suppression: 38.0,
                sound: "hmg",
            };
            let events = s
                .context()
                .fire_bullet(
                    input,
                    &mut gunfire,
                    &mut network,
                    &mut impacts,
                    &armor,
                    &|_| 2.0,
                )
                .unwrap();
            block(&mut out, format!("{events:?}").as_bytes());
            block(&mut out, &s.world.actors.checkpoint().unwrap());
            block(&mut out, &s.world.geometry.checkpoint());
            for q in &s.world.squads {
                block(&mut out, &q.checkpoint().unwrap());
            }
            block(&mut out, &s.world.battle.checkpoint());
            block(&mut out, &s.world.deferred.checkpoint());
            block(&mut out, &s.fires.checkpoint());
            block(&mut out, &s.world.visibility.checkpoint());
            block(&mut out, &gunfire.checkpoint());
            block(&mut out, &network.checkpoint().unwrap());
            block(&mut out, format!("{impacts:?}").as_bytes());
            block(&mut out, &s.world.rng.state().to_le_bytes());
            block(&mut out, &s.next.to_le_bytes());
            s.world.geometry.finish_tick();
            s.world.now += 0.17;
        }
    }
    out
}
