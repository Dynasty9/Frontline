#[path = "squad_movement_world.rs"]
#[allow(dead_code)]
mod movement;
use frontline_core::actors::Actor;
use frontline_core::infantry_action::Round;
use frontline_core::infantry_controller::Task;
use frontline_core::infantry_fire::MountedGun;
use frontline_core::infantry_vitals::Life;
use frontline_core::squad_movement::Event;
use frontline_core::structure::Structure;
use frontline_core::vector::Vector3;
use frontline_core::vehicle::Vehicle;
pub use movement::Scene;

pub fn gun() -> MountedGun {
    MountedGun {
        bore: 0.8,
        muzzle: 1.3,
        grip_z: 0.4,
        nest_height: 0.9,
        trench_height: 0.7,
    }
}
pub fn scene(trial: u32) -> Scene {
    let mut s = Scene::new(731 + u64::from(trial));
    assert_eq!(
        s.actors
            .spawn(Actor::Vehicle(Box::new(Vehicle {
                kind: "apc".into(),
                team: 0,
                position: Vector3::new(-10., 0., 3.),
                passengers: vec![1],
                ..Default::default()
            })))
            .unwrap(),
        8
    );
    let kind = [
        "tunnel",
        "bunker",
        "watchtower",
        "mortar_pit",
        "at_post",
        "mg_nest",
        "hmg_nest",
        "sandbags",
    ][trial as usize % 8];
    assert_eq!(
        s.geometry
            .spawn_structure(
                &mut s.actors,
                Structure {
                    kind: kind.into(),
                    team: 0,
                    position: Vector3::new(-15.7, 0., -10.3),
                    yaw: f64::from(trial) * 0.317 - 1.3,
                    built: true,
                    hp: 20.,
                    max_hp: 100.,
                    size: Vector3::new(3., 2., 3.),
                    ..Default::default()
                },
                None
            )
            .unwrap(),
        9
    );
    for id in 1..=6 {
        s.change(id, |m| {
            m.grenades.frags = if id == 2 { 0 } else { 2 };
            m.fight.smokes = if id == 2 { 0 } else { 1 };
            m.orders.detached = true;
        });
    }
    if trial % 3 == 0 {
        s.change(2, |m| m.vitals.life = Life::Downed);
    }
    if trial % 5 == 0 {
        s.change(3, |m| {
            m.duty.kind = Task::Rescue;
            m.duty.entity = 2;
        });
        s.change(2, |m| {
            m.links.dragged_by = 3;
            m.links.rescue_claimed = 3;
        });
    }
    s.geometry.tick_cover(100_000).unwrap();
    s.geometry.navigation.finalize(1);
    s
}
pub fn apply(s: &mut Scene, step: u32) -> Vec<Event> {
    let at = Vector3::new(27.3, 0., -7.1);
    match step % 8 {
        0 => s.context().order_attack(7, 9),
        1 => s.context().order_stop(7),
        2 => s.context().order_work(7, 9),
        3 => s.context().order_board(7, 8, 3),
        4 => s.context().order_enter(7, 9, Some(gun())),
        5 => s
            .context()
            .order_fire_mission(7, at, step % 2 == 1, &|m| m.identity.id == 4),
        6 => s.context().order_throw(7, at, Round::Frag),
        _ => s.context().order_throw(7, at, Round::Smoke),
    }
    .unwrap()
}
pub fn state(s: &Scene) -> [Vec<u8>; 5] {
    [
        s.actors.checkpoint().unwrap(),
        s.geometry.checkpoint(),
        s.units.checkpoint(),
        s.squads[0].checkpoint().unwrap(),
        s.rng.state().to_le_bytes().to_vec(),
    ]
}
pub fn delta(out: &mut Vec<u8>, previous: &mut Vec<u8>, next: Vec<u8>) {
    // Queue lengths shift later blocks; retain equal ends instead of recording that shift byte by byte.
    let prefix = previous
        .iter()
        .zip(&next)
        .take_while(|(a, b)| a == b)
        .count();
    let suffix = previous[prefix..]
        .iter()
        .rev()
        .zip(next[prefix..].iter().rev())
        .take_while(|(a, b)| a == b)
        .count();
    let middle = &next[prefix..next.len() - suffix];
    for n in [prefix, suffix, middle.len()] {
        out.extend_from_slice(&(n as u32).to_le_bytes());
    }
    out.extend_from_slice(middle);
    assert_eq!(
        [
            &previous[..prefix],
            middle,
            &previous[previous.len() - suffix..]
        ]
        .concat(),
        next
    );
    *previous = next;
}
pub fn transcript() -> Vec<u8> {
    let mut out = Vec::new();
    let mut previous: [Vec<u8>; 5] = Default::default();
    for trial in 0..24 {
        let mut s = scene(trial);
        let mut copy = scene(trial);
        for step in 0..16 {
            copy.resume();
            let events = apply(&mut s, step);
            assert_eq!(events, apply(&mut copy, step));
            let bytes = state(&s);
            assert_eq!(bytes, state(&copy));
            for (before, after) in previous.iter_mut().zip(bytes) {
                delta(&mut out, before, after);
            }
            let events = format!("{trial}/{step} {events:?}").into_bytes();
            out.extend_from_slice(&(events.len() as u32).to_le_bytes());
            out.extend(events);
        }
    }
    out
}
