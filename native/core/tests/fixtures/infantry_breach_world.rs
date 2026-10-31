#[allow(dead_code)]
#[path = "vehicle_loss_world.rs"]
pub mod shared;
use frontline_core::actors::Actor;
use frontline_core::bullet_world::Gunfire;
use frontline_core::infantry::Opening;
use frontline_core::infantry_controller::Task;
use frontline_core::infantry_fight_world::Event;
use frontline_core::infantry_vitals::Life;
use frontline_core::squad::Squad;
use frontline_core::structure::Structure;
use frontline_core::supply_network::SupplyNetwork;
use frontline_core::vector::Vector3;
use frontline_core::vehicle_damage::Armor;
pub use shared::Scene;

pub fn scene(phase: u8, closed: bool, clear: bool) -> Scene {
    let mut entries = vec![];
    for id in 1..=4 {
        let mut s =
            shared::shared::soldier(id, if id == 1 { 0.0 } else { id as f32 - 2.0 }, Life::Alive);
        s.identity.squad = if id == 2 { 2 } else { 1 };
        if id == 2 {
            s.identity.team = 1;
            s.identity.owner = 8;
        }
        if id == 1 {
            s.duty.kind = Task::Breach;
            s.duty.entity = 11;
            s.duty.partner = 2;
            s.duty.phase = phase;
            s.duty.timer = 99.0;
            s.duty.position = s.motion.position;
            s.duty.second_position = s.motion.position;
            s.entry.house = 10;
            s.entry.clear = clear;
            s.entry.wait_until = 99.0;
            s.entry.opening = Some(Opening {
                id: 11,
                center: Vector3::Z * 4.0,
                normal: Vector3::Z,
                door: true,
            });
            s.grenades.frags = 1;
        }
        entries.push(Actor::Soldier(Box::new(s)));
    }
    entries.push(Actor::Structure(Box::new(Structure {
        id: 10,
        kind: "floor".into(),
        size: Vector3::new(8.0, 0.1, 8.0),
        ..Default::default()
    })));
    entries.push(Actor::Structure(Box::new(Structure {
        id: 11,
        kind: "house_wall".into(),
        variant: 2,
        position: Vector3::Z * 4.0,
        size: Vector3::new(8.0, 2.3, 0.3),
        door_closed: closed,
        ..Default::default()
    })));
    let mut s = Scene::new(entries, 137);
    s.world.squads = vec![Squad {
        id: 1,
        team: 0,
        owner: 7,
        members: vec![1, 3, 4],
        breach_by: 1,
        ..Default::default()
    }];
    s
}
pub fn step(s: &mut Scene) -> Result<Vec<Event>, &'static str> {
    s.context().advance_breach(
        1,
        0.1,
        None,
        &|_| None,
        &mut Gunfire::default(),
        &mut SupplyNetwork::default(),
        &mut vec![],
        &|_| Armor {
            level: 0,
            helicopter: false,
            boat: false,
            supply: false,
            toss: 1.0,
        },
        &|_| 2.0,
    )
}
pub fn transcript() -> Vec<u8> {
    fn block(out: &mut Vec<u8>, bytes: &[u8]) {
        out.extend_from_slice(&(bytes.len() as u32).to_le_bytes());
        out.extend_from_slice(bytes);
    }
    let mut out = vec![];
    for trial in 0..20 {
        let mut s = scene((trial % 5) as u8, trial % 2 == 0, trial % 3 == 0);
        s.world.rng = frontline_core::random::SimulationRandom::new(4817 + trial);
        for _ in 0..6 {
            if s.world.actors.soldier(1).unwrap().duty.kind != Task::Breach {
                break;
            }
            s = s.resume();
            s.world.now += 0.3;
            let events = step(&mut s).unwrap();
            block(&mut out, format!("{events:?}").as_bytes());
            block(&mut out, &s.world.actors.checkpoint().unwrap());
            block(&mut out, &s.world.geometry.checkpoint());
            for q in &s.world.squads {
                block(&mut out, &q.checkpoint().unwrap());
            }
            out.extend_from_slice(&s.world.rng.state().to_le_bytes());
            if s.world.actors.soldier(1).unwrap().action.remaining > 0.0 {
                break;
            }
        }
    }
    out
}
