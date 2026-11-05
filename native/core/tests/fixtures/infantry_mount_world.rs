#[allow(dead_code)]
#[path = "vehicle_loss_world.rs"]
pub mod shared;
use frontline_core::actors::Actor;
use frontline_core::bullet_world::Gunfire;
use frontline_core::infantry_action_owned::Defense;
use frontline_core::infantry_controller::Task;
use frontline_core::infantry_fight_world::Event;
use frontline_core::infantry_fire::MountedGun;
use frontline_core::infantry_vitals::Life;
use frontline_core::supply_network::SupplyNetwork;
use frontline_core::vector::Vector3;
use frontline_core::vehicle_brain::CrewProfile;
use frontline_core::vehicle_damage::Armor;
use frontline_core::vehicle_launch::SmokeProfile;
pub use shared::Scene;

pub fn scene(kind: &str, phase: u8, team: i8, smoke: bool) -> Scene {
    let mut s = shared::shared::soldier(1, 0.0, Life::Alive);
    s.identity.team = team;
    s.duty.kind = Task::Man;
    s.duty.entity = 10;
    s.duty.phase = phase;
    s.duty.timer = 0.05;
    s.emplacement.structure = 10;
    let mut st = shared::shared::structure(10, kind, 0.0);
    st.team = team;
    st.parts.clear();
    st.fire_queue = vec![(Vector3::NEG_Z * 12.0, false), (Vector3::X * 14.0, true)];
    let mut v = shared::vehicle(20, "tank");
    if let Actor::Vehicle(v) = &mut v {
        v.position = Vector3::NEG_Z * 12.0;
        v.team = 1 - team;
        v.visible = 3;
        v.smoke_left = if smoke { 2 } else { 0 };
    }
    let mut world = Scene::new(
        vec![
            Actor::Soldier(Box::new(s)),
            Actor::Structure(Box::new(st)),
            v,
        ],
        7717,
    );
    world.world.geometry.collision.remove(10);
    world
}
pub fn step(s: &mut Scene, dt: f64) -> Result<Vec<Event>, &'static str> {
    s.context().advance_mount(
        1,
        dt,
        Some(MountedGun {
            bore: 0.15,
            muzzle: 1.0,
            grip_z: 0.25,
            nest_height: 0.8,
            trench_height: 0.6,
        }),
        &[10],
        &|_| None,
        &|_| Defense {
            smoke: SmokeProfile {
                armor: 2,
                helicopter: false,
                gun_height: 2.2,
            },
            crew: CrewProfile {
                base: "tank",
                helicopter: false,
                automatic: false,
                artillery: false,
                tracked: true,
                armor: 2,
            },
        },
        &mut Gunfire::default(),
        &mut SupplyNetwork::default(),
        &mut vec![],
        &|_| Armor {
            level: 2,
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
    for trial in 0..20 {
        let mut s = scene(
            ["watchtower", "mg_nest", "hmg_nest", "mortar_pit", "at_post"][trial % 5],
            (trial % 3) as u8,
            (trial % 2) as i8,
            trial % 3 == 0,
        );
        for _ in 0..5 {
            s = s.resume();
            s.world.now += 0.5;
            let events = step(&mut s, 0.5).unwrap();
            block(&mut out, format!("{events:?}").as_bytes());
            block(&mut out, &s.world.actors.checkpoint().unwrap());
            block(&mut out, &s.world.geometry.checkpoint());
            for q in &s.world.squads {
                block(&mut out, &q.checkpoint().unwrap());
            }
            out.extend_from_slice(&s.world.rng.state().to_le_bytes());
        }
    }
    out
}
