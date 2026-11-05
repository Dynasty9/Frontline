#[path = "squad_orders.rs"]
#[allow(dead_code)]
mod orders;
#[path = "vehicle_loss_world.rs"]
#[allow(dead_code)]
mod shared;
use frontline_core::actors::Actor;
use frontline_core::boat_navigation::BoatNavigation;
use frontline_core::vector::Vector3;
use frontline_core::vehicle_orders::Order;
pub use shared::Scene;

pub fn scene(kind: &str, busy: bool) -> (Scene, BoatNavigation) {
    let mut actor = shared::vehicle(20, kind);
    if let Actor::Vehicle(v) = &mut actor {
        v.position = Vector3::new(-10., if kind == "heli" { 5. } else { 0. }, -4.);
        if busy {
            v.owner = -1;
            v.brain_state = "withdraw".into();
        }
    }
    let mut enemy = shared::vehicle(21, "tank");
    if let Actor::Vehicle(v) = &mut enemy {
        v.team = 1;
        v.position = Vector3::new(52., 0., -4.);
    }
    (
        Scene::new(vec![actor, enemy], 37),
        BoatNavigation::new(16, &vec![0; 256], &vec![1.; 256]).unwrap(),
    )
}
fn state(s: &Scene, boats: &BoatNavigation) -> [Vec<u8>; 6] {
    [
        s.world.actors.checkpoint().unwrap(),
        s.world.geometry.checkpoint(),
        boats.checkpoint(),
        s.world.units.checkpoint(),
        s.world.battle.checkpoint(),
        s.world.rng.state().to_le_bytes().to_vec(),
    ]
}
pub fn transcript() -> Vec<u8> {
    let mut out = vec![];
    let mut previous: [Vec<u8>; 6] = Default::default();
    for trial in 0..10 {
        let (mut s, mut boats) = scene(
            ["tank", "boat", "heli", "supply", "robot"][trial % 5],
            trial >= 5,
        );
        for step in 0..16 {
            let mut copy = s.resume();
            let mut saved_boats = BoatNavigation::restore(&boats.checkpoint()).unwrap();
            let p = Vector3::new(3.7 + step as f32 * 0.1, 0., 7.3 - step as f32 * 0.2);
            let order = match step % 4 {
                0 => Order::Move(p),
                1 => Order::Assault(p),
                2 => Order::Attack(21),
                _ => Order::Stop,
            };
            s.context().order_vehicle(20, order, &mut boats).unwrap();
            copy.context()
                .order_vehicle(20, order, &mut saved_boats)
                .unwrap();
            s.world
                .geometry
                .navigation
                .process_paths(
                    &mut s.world.actors,
                    2,
                    s.world.now,
                    &mut s.world.rng,
                    frontline_core::traversal::Ground::new(
                        &s.world.geometry.terrain,
                        &s.world.geometry.deck,
                    ),
                )
                .unwrap();
            copy.world
                .geometry
                .navigation
                .process_paths(
                    &mut copy.world.actors,
                    2,
                    copy.world.now,
                    &mut copy.world.rng,
                    frontline_core::traversal::Ground::new(
                        &copy.world.geometry.terrain,
                        &copy.world.geometry.deck,
                    ),
                )
                .unwrap();
            let bytes = state(&s, &boats);
            assert_eq!(bytes, state(&copy, &saved_boats));
            for (before, after) in previous.iter_mut().zip(bytes) {
                orders::delta(&mut out, before, after);
            }
        }
    }
    out
}
