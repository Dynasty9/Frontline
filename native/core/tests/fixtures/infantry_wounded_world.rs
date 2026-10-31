#[allow(dead_code)]
#[path = "vehicle_loss_world.rs"]
mod shared;
use frontline_core::actors::Actor;
use frontline_core::bullet_world::Gunfire;
use frontline_core::infantry_controller::Task;
use frontline_core::infantry_pose::Posture;
use frontline_core::infantry_vitals::Life;
use frontline_core::infantry_wounded_world::Input;
use frontline_core::squad::Squad;
use frontline_core::structure::Structure;
use frontline_core::supply_network::SupplyNetwork;
use frontline_core::vector::Vector3;
use frontline_core::vehicle_damage::Armor;

fn block(out: &mut Vec<u8>, bytes: &[u8]) {
    out.extend_from_slice(&(bytes.len() as u32).to_le_bytes());
    out.extend_from_slice(bytes);
}
pub fn transcript() -> Vec<u8> {
    let mut out = vec![];
    for trial in 0..8 {
        let mut entries = vec![];
        for id in 1..=5 {
            let mut man = shared::shared::soldier(id, id as f32 * 2.3 - 2.3, Life::Alive);
            man.identity.team = if id == 1 || id == 3 { 0 } else { 1 };
            man.identity.owner = 7 + man.identity.team as i32;
            man.identity.squad = 1 + man.identity.team as u32;
            if id == 1 {
                man.vitals.life = Life::Downed;
                man.vitals.hp = 0.0;
                man.vitals.bleed_max = 50.0;
                man.vitals.bleed = if trial == 0 { 0.05 } else { 40.0 };
                man.vitals.downed_at = 99.0;
                man.posture = Posture::Prone;
                if trial == 1 || trial == 5 {
                    man.links.carried_by = vec![3];
                }
                if trial == 2 || trial == 6 {
                    man.links.dragged_by = 3;
                }
            }
            if id == 3 {
                man.duty.kind = if trial == 2 {
                    Task::Rescue
                } else {
                    Task::Fight
                };
                man.duty.entity = 1;
                if trial == 5 {
                    man.vitals.life = Life::Dead;
                    man.vitals.hp = 0.0;
                }
            }
            entries.push(Actor::Soldier(Box::new(man)));
        }
        let mut s = shared::Scene::new(entries, 43917 + trial);
        s.world.squads = (0..2)
            .map(|team| Squad {
                id: 1 + team as u32,
                team,
                owner: 7 + team as i32,
                members: if team == 0 { vec![1, 3] } else { vec![2, 4, 5] },
                ..Default::default()
            })
            .collect();
        for (kind, position) in [
            ("low_wall", Vector3::new(-3.0, 0.0, -2.0)),
            ("crates", Vector3::new(-2.0, 0.0, 3.0)),
        ] {
            s.world
                .geometry
                .spawn_structure(
                    &mut s.world.actors,
                    Structure {
                        kind: kind.into(),
                        position,
                        size: Vector3::new(4.0, 1.2, 0.6),
                        ..Default::default()
                    },
                    None,
                )
                .unwrap();
        }
        let mut gunfire = Gunfire::default();
        let mut network = SupplyNetwork::default();
        let mut impacts = vec![];
        for tick in 0..12 {
            if s.world.actors.soldier(1).unwrap().vitals.life != Life::Downed {
                break;
            }
            s = s.resume();
            gunfire = Gunfire::restore(&gunfire.checkpoint()).unwrap();
            network = SupplyNetwork::restore(&network.checkpoint().unwrap()).unwrap();
            let input = Input {
                dt: [0.1, 0.25, 0.5][tick % 3],
                medicine: trial % 3 == 0,
                optics: trial % 3 == 1,
                gun: None,
            };
            s.world.now += input.dt;
            let events = s
                .context()
                .advance_wounded(
                    1,
                    input,
                    &mut gunfire,
                    &mut network,
                    &mut impacts,
                    &|_| Armor {
                        level: 0,
                        helicopter: false,
                        boat: false,
                        supply: false,
                        toss: 1.0,
                    },
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
            block(&mut out, &s.world.visibility.checkpoint());
            block(&mut out, &s.world.deferred.checkpoint());
            block(&mut out, &s.fires.checkpoint());
            block(&mut out, &gunfire.checkpoint());
            block(&mut out, &network.checkpoint().unwrap());
            block(&mut out, &s.world.rng.state().to_le_bytes());
            s.world.geometry.finish_tick();
        }
    }
    out
}
