#[allow(dead_code)]
#[path = "vehicle_world.rs"]
pub mod fixture;
pub use fixture::{vehicle, Field};
use frontline_core::actors::Actor;
use frontline_core::vector::Vector3;
use frontline_core::vehicle_motion::GroundProfile;
use frontline_core::vehicle_world::Event;

pub fn profile() -> GroundProfile {
    let mut p = fixture::ground().movement;
    p.supply = true;
    p.tracked = false;
    p.tank = false;
    p.speed = 12.0;
    p
}
pub fn field(trial: usize) -> Field {
    let mut v = vehicle(20, 0, 0.0);
    v.kind = "supply".into();
    v.destination_fob = 30;
    v.cargo = 75;
    v.route = vec![Vector3::Z * 15.0, Vector3::NEG_Z * 15.0];
    v.route_index = 1;
    let mut fob = fixture::shared::structure(30, "fob", 8.0);
    fob.team = 0;
    fob.supply = 50.0;
    fob.truck = 20;
    match trial {
        0 | 3 => {
            v.route_index = 2;
            if trial == 3 {
                fob.team = 1;
            }
        }
        1 | 4 => {
            v.route_index = 2;
            v.returning = true;
            if trial == 4 {
                v.source_town = 30;
                fob.kind = "town".into();
            }
        }
        2 => {
            v.blocked_timer = 4.95;
        }
        _ => {}
    }
    let mut w = Field::new(v, Actor::Structure(Box::new(fob)));
    if trial == 2 {
        let blocker = w
            .scene
            .world
            .actors
            .spawn(Actor::Vehicle(Box::new(vehicle(0, 1, -4.0))))
            .unwrap();
        let v = w.scene.world.actors.vehicle(blocker).unwrap();
        w.scene
            .world
            .geometry
            .refresh_vehicle_collision(v, Vector3::new(3.0, 2.0, 5.0))
            .unwrap();
        w.scene
            .world
            .actors
            .rebuild_units(&mut w.scene.world.units)
            .unwrap();
    }
    w
}
pub fn step(
    w: &mut Field,
    p: GroundProfile,
    income: &mut [Vec<(f64, i32)>; 2],
) -> Result<Vec<Event>, &'static str> {
    w.scene
        .context()
        .advance_supply_truck(20, 0.1, p, 100, income)
}
pub fn transcript() -> Vec<u8> {
    fn block(out: &mut Vec<u8>, bytes: &[u8]) {
        out.extend_from_slice(&(bytes.len() as u32).to_le_bytes());
        out.extend_from_slice(bytes);
    }
    let mut out = vec![];
    for trial in 0..6 {
        let mut a = field(trial);
        let mut income = [vec![], vec![]];
        let mut previous = vec![vec![]; 11];
        for tick in 0..8 {
            if a.scene.world.actors.vehicle(20).is_none() {
                break;
            }
            a.scene.world.now += 0.1;
            let mut b = a.resume();
            let mut bi = income.clone();
            let events = step(&mut a, profile(), &mut income).unwrap();
            assert_eq!(events, step(&mut b, profile(), &mut bi).unwrap());
            a.compare(&b);
            assert_eq!(income, bi);
            block(
                &mut out,
                format!("{trial}/{tick} {events:?} {income:?}").as_bytes(),
            );
            let mut squads = vec![];
            for q in &a.scene.world.squads {
                block(&mut squads, &q.checkpoint().unwrap());
            }
            let states = [
                a.scene.world.actors.checkpoint().unwrap(),
                a.scene.world.geometry.checkpoint(),
                a.scene.world.units.checkpoint(),
                a.scene.world.battle.checkpoint(),
                a.scene.world.deferred.checkpoint(),
                a.scene.world.visibility.checkpoint(),
                a.scene.fires.checkpoint(),
                a.gunfire.checkpoint(),
                a.network.checkpoint().unwrap(),
                squads,
                format!("{:?}", a.impacts).into_bytes(),
            ];
            for (last, state) in previous.iter_mut().zip(states) {
                fixture::squad_fixture::checkpoint_delta(&mut out, last, state);
            }
            out.extend_from_slice(&a.scene.world.rng.state().to_le_bytes());
            out.extend_from_slice(&a.scene.next.to_le_bytes());
        }
    }
    out
}
