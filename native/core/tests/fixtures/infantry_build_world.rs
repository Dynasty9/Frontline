#[allow(dead_code)]
#[path = "vehicle_loss_world.rs"]
pub mod shared;
use frontline_core::actors::Actor;
use frontline_core::bullet_world::Gunfire;
use frontline_core::infantry_controller::Task;
use frontline_core::infantry_fight_world::Event;
use frontline_core::infantry_vitals::Life;
use frontline_core::squad::Squad;
use frontline_core::supply_network::SupplyNetwork;
use frontline_core::vector::Vector3;
use frontline_core::vehicle_damage::Armor;
pub use shared::Scene;

pub fn scene(case: u8) -> Scene {
    let mut man = shared::shared::soldier(1, 0.0, Life::Alive);
    man.identity.squad = 1;
    man.duty.kind = Task::Build;
    man.duty.entity = if case == 7 { 0 } else { 10 };
    man.duty.position = if case == 8 {
        Vector3::X * 10.0
    } else {
        Vector3::ZERO
    };
    if case == 9 {
        man.vitals.suppression = 65.0;
    }
    let mut buddy = shared::shared::soldier(2, -3.0, Life::Alive);
    buddy.identity.squad = 1;
    if case == 5 {
        buddy.duty.kind = Task::Build;
        buddy.duty.entity = 10;
    }
    let mut entries = vec![
        Actor::Soldier(Box::new(man)),
        Actor::Soldier(Box::new(buddy)),
    ];
    if case == 2 {
        let mut v = shared::vehicle(10, "tank");
        if let Actor::Vehicle(v) = &mut v {
            v.track_broken = true;
            v.track_fix = 5.95;
            v.hp = 90.0;
        }
        entries.push(v);
    } else if case != 7 {
        let mut st = shared::shared::structure(
            10,
            match case {
                1 => "fob",
                3 => "medic_tent",
                4 => "camo_net",
                _ => "barracks",
            },
            2.0,
        );
        st.built = matches!(case, 1 | 5 | 6);
        st.progress = 0.995;
        st.hp = if case == 1 { 49.9 } else { 100.0 };
        st.wrecked = case == 1;
        st.bearer_timer = 12.0;
        entries.push(Actor::Structure(Box::new(st)));
    }
    let mut s = Scene::new(entries, 137);
    s.world.squads = vec![Squad {
        id: 1,
        team: 0,
        owner: 7,
        members: vec![1, 2],
        order: "build".into(),
        build_target: if case == 7 { 0 } else { 10 },
        ..Default::default()
    }];
    if let Some(st) = s.world.actors.structure(10) {
        s.world.geometry.refresh_structure_collision(st).unwrap();
    }
    s
}
pub fn step(s: &mut Scene, dt: f64) -> Result<Vec<Event>, &'static str> {
    s.context().advance_build(
        1,
        dt,
        1.0,
        Some(10.0),
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
    fn block(out: &mut Vec<u8>, data: &[u8]) {
        out.extend_from_slice(&(data.len() as u32).to_le_bytes());
        out.extend_from_slice(data);
    }
    let mut out = vec![];
    for case in 0..10 {
        let mut s = scene(case);
        for _ in 0..3 {
            if s.world.actors.soldier(1).unwrap().duty.kind != Task::Build {
                break;
            }
            s = s.resume();
            s.world.now += 0.1;
            let events = step(&mut s, 0.1).unwrap();
            block(&mut out, format!("{events:?}").as_bytes());
            block(&mut out, &s.world.actors.checkpoint().unwrap());
            block(&mut out, &s.world.geometry.checkpoint());
            block(&mut out, &s.world.battle.checkpoint());
            for q in &s.world.squads {
                block(&mut out, &q.checkpoint().unwrap());
            }
            out.extend_from_slice(&s.world.rng.state().to_le_bytes());
        }
    }
    out
}
