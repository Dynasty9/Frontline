#[path = "squad_orders.rs"]
#[allow(dead_code)]
mod shared;
use frontline_core::actors::Actor;
use frontline_core::infantry::Infantry;
use frontline_core::infantry_action::Round;
use frontline_core::squad_movement::Event;
use frontline_core::structure::Structure;
use frontline_core::unit_orders::Order;
use frontline_core::vector::Vector3;
pub use shared::{gun, state, Scene};

pub fn scene(trial: u32) -> Scene {
    let mut s = shared::scene(trial);
    let mut enemy = Infantry::default();
    enemy.identity.unit = "rifleman".into();
    enemy.identity.team = 1;
    enemy.motion.position = Vector3::new(40.7, 0., 10.1);
    assert_eq!(s.actors.spawn(Actor::Soldier(Box::new(enemy))).unwrap(), 10);
    if trial % 2 == 0 {
        s.geometry
            .spawn_structure(
                &mut s.actors,
                Structure {
                    kind: "fob".into(),
                    team: 0,
                    position: Vector3::new(-40., 0., 30.),
                    ..Default::default()
                },
                None,
            )
            .unwrap();
    }
    for id in 1..=6 {
        s.change(id, |m| m.orders.detached = false);
    }
    s.actors.rebuild_units(&mut s.units).unwrap();
    s.geometry.tick_cover(100_000).unwrap();
    s.geometry.navigation.finalize(1);
    s
}
pub fn apply(s: &mut Scene, step: u32) -> Vec<Event> {
    let at = Vector3::new(-14., 0., -9.);
    let order = match step % 8 {
        0 => Order::Move {
            position: at,
            face: Vector3::ZERO,
            mode: (step % 3) as u8,
        },
        1 => Order::Attack(10),
        2 => Order::Throw {
            position: Vector3::new(30., 0., 7.),
            round: Round::Frag,
        },
        3 => Order::Stop,
        4 => Order::Retreat,
        5 => Order::Man {
            target: 9,
            gun: Some(gun()),
        },
        6 => Order::Attack(2),
        _ => Order::Throw {
            position: at,
            round: Round::Smoke,
        },
    };
    let id = if step % 8 == 2 { 2 } else { 3 };
    s.context().unit_order(id, order, Some(40.)).unwrap()
}
pub fn transcript() -> Vec<u8> {
    let mut out = vec![];
    let mut previous: [Vec<u8>; 5] = Default::default();
    for trial in 0..16 {
        let mut s = scene(trial);
        let mut copy = scene(trial);
        for step in 0..16 {
            copy.resume();
            let events = apply(&mut s, step);
            assert_eq!(events, apply(&mut copy, step));
            let bytes = state(&s);
            assert_eq!(bytes, state(&copy));
            for (before, after) in previous.iter_mut().zip(bytes) {
                shared::delta(&mut out, before, after);
            }
            let events = format!("{trial}/{step} {events:?}").into_bytes();
            out.extend_from_slice(&(events.len() as u32).to_le_bytes());
            out.extend(events);
        }
    }
    out
}
