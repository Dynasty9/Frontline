#[allow(dead_code)]
#[path = "vehicle_loss_world.rs"]
mod shared;
use frontline_core::actors::Actor;
use frontline_core::bullet;
use frontline_core::bullet_world::Gunfire;
use frontline_core::infantry_controller::Task;
use frontline_core::infantry_fight_world::Profile;
use frontline_core::infantry_fire::FireProfile;
use frontline_core::infantry_vitals::Life;
use frontline_core::infantry_weapon::Weapon;
use frontline_core::squad::Squad;
use frontline_core::supply_network::SupplyNetwork;
use frontline_core::vector::Vector3;
use frontline_core::vehicle_damage::Armor;

fn block(out: &mut Vec<u8>, bytes: &[u8]) {
    out.extend_from_slice(&(bytes.len() as u32).to_le_bytes());
    out.extend_from_slice(bytes);
}
pub fn transcript() -> Vec<u8> {
    let mut out = vec![];
    for trial in 0..4 {
        let mut entries = vec![];
        for id in 1..=5 {
            let mut s = shared::shared::soldier(id, id as f32 * 2.3 - 2.3, Life::Alive);
            s.identity.team = if id <= 3 { 0 } else { 1 };
            s.identity.owner = 7 + s.identity.team as i32;
            s.identity.squad = 1 + s.identity.team as u32;
            s.weapon.magazine = 5;
            s.weapon.reserve = 30;
            s.weapon.last_shot = -10.0;
            if id == 1 {
                s.fight.target = if trial == 3 { 0 } else { 5 };
                if trial < 3 {
                    s.fight.visible_targets = vec![5];
                }
                if trial == 1 {
                    s.cover.at_cover = true;
                    s.cover.kind = 1;
                    s.cover.height = 0.8;
                    s.cover.normal = Vector3::X;
                    s.cover.position = s.motion.position;
                    s.weapon.peek_up = true;
                    s.weapon.peek_from = 98.0;
                    s.weapon.peek_timer = 0.2;
                    s.vitals.suppression = 42.0;
                } else if trial == 2 {
                    s.duty.kind = Task::Escort;
                    s.duty.entity = 3;
                    s.duty.partner = 2;
                } else if trial == 3 {
                    s.idle.calm = 12.0;
                }
            }
            if id == 2 && trial == 2 {
                s.duty.kind = Task::Rescue;
                s.duty.entity = 3;
            }
            entries.push(Actor::Soldier(Box::new(s)));
        }
        let mut s = shared::Scene::new(entries, 19417 + trial);
        s.world.squads = (0..2)
            .map(|team| Squad {
                id: 1 + team as u32,
                team,
                owner: 7 + team as i32,
                members: if team == 0 { vec![1, 2, 3] } else { vec![4, 5] },
                ..Default::default()
            })
            .collect();
        let mut gunfire = Gunfire::default();
        let mut network = SupplyNetwork::default();
        let mut impacts = vec![];
        let mut chat = [0.0; 2];
        for tick in 0..32 {
            s = s.resume();
            gunfire = Gunfire::restore(&gunfire.checkpoint()).unwrap();
            network = SupplyNetwork::restore(&network.checkpoint().unwrap()).unwrap();
            s.world.now += 0.25;
            let events = s
                .context()
                .advance_fighting(
                    1,
                    0.25,
                    None,
                    &mut chat,
                    &|_| {
                        Some(Profile {
                            fire: FireProfile {
                                weapon: Weapon {
                                    ammunition: 120,
                                    magazine: 30,
                                    reload_time: 2.2,
                                },
                                burst_min: 2,
                                burst_max: 4,
                            },
                            bullet: bullet::Weapon {
                                accuracy: 0.6,
                                range: 60.0,
                                damage: 30.0,
                                anti_air: false,
                                penetration: 0,
                                drone_accuracy: 0.03,
                                explosive_radius: None,
                                airburst: false,
                            },
                            interval: 0.12,
                            suppression: 11.0,
                            sound: "rifle",
                            optics: trial == 1,
                            piercing: false,
                        })
                    },
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
            for q in &s.world.squads {
                block(&mut out, &q.checkpoint().unwrap());
            }
            block(&mut out, &s.world.battle.checkpoint());
            block(&mut out, &s.world.visibility.checkpoint());
            block(&mut out, &gunfire.checkpoint());
            block(&mut out, &s.world.rng.state().to_le_bytes());
            for time in chat {
                out.extend_from_slice(&time.to_le_bytes());
            }
            if tick % 8 == 0 || tick == 31 {
                block(&mut out, &s.world.geometry.checkpoint());
                block(&mut out, &s.world.deferred.checkpoint());
                block(&mut out, &s.fires.checkpoint());
                block(&mut out, &network.checkpoint().unwrap());
            }
            s.world.geometry.finish_tick();
        }
    }
    out
}
