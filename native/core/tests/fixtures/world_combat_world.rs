#[allow(dead_code)]
#[path = "vehicle_loss_world.rs"]
mod shared;
use frontline_core::actors::Actor;
use frontline_core::infantry_vitals::Life;
use frontline_core::structure::Structure;
use frontline_core::supply_network::SupplyNetwork;
use frontline_core::vector::Vector3;
use frontline_core::vehicle::Vehicle;
use frontline_core::vehicle_damage::Armor;
use frontline_core::world_combat::Explosion;

fn armor(v: &Vehicle) -> Armor {
    Armor {
        level: if v.kind == "tank" { 2 } else { 0 },
        helicopter: v.kind == "heli",
        boat: v.kind == "boat",
        supply: v.kind == "supply",
        toss: 1.3,
    }
}
fn block(out: &mut Vec<u8>, bytes: &[u8]) {
    out.extend_from_slice(&(bytes.len() as u32).to_le_bytes());
    out.extend_from_slice(bytes);
}
pub fn transcript() -> Vec<u8> {
    let mut out = vec![];
    for trial in 0..12 {
        let mut transport =
            shared::vehicle(20, ["tank", "supply", "boat", "heli", "robot"][trial % 5]);
        if let Actor::Vehicle(v) = &mut transport {
            v.passengers = vec![1];
            v.position.x = 2.7;
        }
        let mut entries = vec![transport];
        for id in 1..=6 {
            let mut man = shared::shared::soldier(
                id,
                id as f32 * 1.3 - 2.7,
                if id == 1 { Life::Hidden } else { Life::Alive },
            );
            man.identity.team = (id % 2) as i8;
            man.identity.owner = 7 + man.identity.team as i32;
            man.vitals.times_downed = trial as u32 % 4;
            if id == 1 {
                man.links.vehicle = 20;
            }
            entries.push(Actor::Soldier(Box::new(man)));
        }
        let mut s = shared::Scene::new(entries, 7317 + trial as u64);
        let mut network = SupplyNetwork::default();
        let mut impacts = vec![];
        for (index, kind) in [
            "depot",
            "fob",
            "town",
            "car",
            "ammo_cache",
            "house_wall",
            "tree",
            "crates",
        ]
        .into_iter()
        .enumerate()
        {
            let position = match index {
                0 => Vector3::new(-12.0, 0.0, -10.0),
                1 => Vector3::new(-7.0, 0.0, 0.0),
                2 => Vector3::new(13.0, 0.0, 10.0),
                _ => Vector3::new(index as f32 - 3.7, 0.0, 1.3),
            };
            let id = s
                .world
                .geometry
                .spawn_structure(
                    &mut s.world.actors,
                    Structure {
                        kind: kind.into(),
                        position,
                        yaw: trial as f64 * 0.137,
                        team: if index < 3 { 0 } else { -1 },
                        owner: 7,
                        hp: 90.0,
                        max_hp: 300.0,
                        completed_order: index as u32,
                        supply: 120.0,
                        size: if kind == "house_wall" {
                            Vector3::new(7.3, 2.3, 1.0)
                        } else {
                            Vector3::ONE
                        },
                        door_closed: kind == "house_wall",
                        variant: if kind == "house_wall" { 2 } else { 0 },
                        ..Default::default()
                    },
                    None,
                )
                .unwrap();
            if index == 0 {
                network.depots[0] = id;
            }
            if index == 2 {
                network.towns.push(id);
            }
        }
        for step in 0..3 {
            s = s.resume();
            network = SupplyNetwork::restore(&network.checkpoint().unwrap()).unwrap();
            let events = if step < 2 {
                s.context()
                    .explode(
                        Explosion {
                            position: Vector3::new(0.7, 0.0, -0.3),
                            damage: Some(if step == 0 { 180.0 } else { 1200.0 }),
                            radius: 12.0,
                            size: 2.7,
                            top: trial % 2 == 0,
                            anti_tank: if trial % 3 == 0 { 120.0 } else { 0.0 },
                            source: if step == 0 { 5 } else { 0 },
                            owner: 8,
                            team: 1,
                            ..Default::default()
                        },
                        &mut network,
                        &mut impacts,
                        &armor,
                    )
                    .unwrap()
            } else {
                s.world.now += 1.6;
                s.context()
                    .flush_deferred(&mut network, &mut impacts, &armor)
                    .unwrap()
            };
            block(&mut out, format!("{events:?}").as_bytes());
            block(&mut out, &s.world.actors.checkpoint().unwrap());
            block(&mut out, &s.world.geometry.checkpoint());
            for q in &s.world.squads {
                block(&mut out, &q.checkpoint().unwrap());
            }
            block(&mut out, &s.fires.checkpoint());
            block(&mut out, &s.world.battle.checkpoint());
            block(&mut out, &s.world.deferred.checkpoint());
            block(&mut out, &s.world.visibility.checkpoint());
            block(&mut out, &network.checkpoint().unwrap());
            block(&mut out, format!("{impacts:?}").as_bytes());
            block(&mut out, &s.world.rng.state().to_le_bytes());
            block(&mut out, &s.next.to_le_bytes());
            s.world.geometry.finish_tick();
        }
    }
    out
}
