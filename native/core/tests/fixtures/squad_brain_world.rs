#[path = "squad_movement_world.rs"]
#[allow(dead_code)]
mod movement;
use frontline_core::actors::Actor;
use frontline_core::infantry::Infantry;
use frontline_core::infantry_vitals::Life;
use frontline_core::infantry_weapon::Weapon;
use frontline_core::squad::{Contact, Report, SavedOrder};
use frontline_core::squad_brain::{Event, Profile};
use frontline_core::structure::Structure;
use frontline_core::vector::Vector3;
pub use movement::Scene;

pub fn profile() -> Profile<'static> {
    Profile {
        plans: &[],
        impacts: &[],
        armor: &|_| 1,
        weapon: &|_| {
            Some(Weapon {
                ammunition: 200,
                magazine: 30,
                reload_time: 2.0,
            })
        },
    }
}
pub fn contact(s: &mut Scene, distance: f32) {
    let c = s.squads[0].centroid(s.now, &s.actors);
    let mut enemy = Infantry::default();
    enemy.identity.team = 1;
    enemy.identity.unit = "rifleman".into();
    enemy.motion.position = c + Vector3::X * distance;
    let position = enemy.motion.position;
    let id = s.actors.spawn(Actor::Soldier(Box::new(enemy))).unwrap();
    s.squads[0].known.push(Contact {
        id,
        report: Report {
            position,
            time: s.now,
        },
    });
    s.squads[0].combat_at = -1.0;
    s.actors.rebuild_units(&mut s.units).unwrap();
}
fn field(trial: u64) -> Scene {
    let mut s = Scene::new(137 + trial);
    contact(&mut s, if trial == 8 { 18.0 } else { 60.0 });
    s.squads[0].morale = 70.0;
    for id in 1..=6 {
        s.change(id, |m| {
            m.weapon.magazine = 30;
            m.weapon.reserve = 170;
            m.fight.smokes = 1;
            m.fight.target = 8;
        });
    }
    s.change(1, |m| {
        m.weapon.magazine = 0;
        m.weapon.reserve = 0;
    });
    let c = s.squads[0].centroid(s.now, &s.actors);
    let q = &mut s.squads[0];
    q.order_position = Vector3::new(30.0, 0.0, 8.0);
    q.ambush = trial % 3 == 0;
    match trial {
        0 | 1 => q.morale = 5.0,
        2 => {
            q.drill = "rout".into();
            q.morale = 46.0;
        }
        3 | 4 => {
            q.impacts = vec![
                Report {
                    position: c,
                    time: 99.0,
                },
                Report {
                    position: c + Vector3::Z,
                    time: 98.0,
                },
            ];
        }
        5 => q.morale = 25.0,
        6 => {
            q.drill = "withdraw".into();
            q.order = "withdraw".into();
            q.drill_time = 99.0;
        }
        7 | 8 => q.order = "move".into(),
        9 | 10 => {
            q.drill = "contact".into();
            q.drill_time = 50.0;
            q.halt_destination = Vector3::new(30.0, 0.0, -10.0);
            if trial == 9 {
                q.known.clear();
            }
        }
        11 => {
            q.drill = "displace".into();
            q.drill_time = 50.0;
            q.previous_order = Some(SavedOrder {
                order: "defend".into(),
                position: Vector3::new(-20.0, 0.0, 20.0),
                facing: Vector3::X,
                mode: 1,
            });
        }
        _ => {
            q.order = "defend".into();
            q.order_position = Vector3::ZERO;
            q.alert_time = 100.0;
            q.known.clear();
        }
    }
    if trial == 1 {
        s.geometry
            .spawn_structure(
                &mut s.actors,
                Structure {
                    kind: "fob".into(),
                    team: 0,
                    position: Vector3::new(-45.0, 0.0, -20.0),
                    ..Default::default()
                },
                None,
            )
            .unwrap();
    }
    if trial == 4 {
        for id in 1..=6 {
            s.change(id, |m| m.motion.ground = -0.7);
        }
    }
    if trial >= 12 {
        s.geometry
            .spawn_structure(
                &mut s.actors,
                Structure {
                    kind: "floor".into(),
                    size: Vector3::new(10.0, 0.1, 10.0),
                    ..Default::default()
                },
                None,
            )
            .unwrap();
        s.geometry
            .spawn_structure(
                &mut s.actors,
                Structure {
                    kind: "house_wall".into(),
                    variant: 2,
                    size: Vector3::new(2.0, 3.0, 0.2),
                    position: Vector3::new(0.0, 0.0, -5.0),
                    ..Default::default()
                },
                None,
            )
            .unwrap();
        if trial == 13 {
            s.change(3, |m| m.motion.position = Vector3::ZERO);
        }
        if trial == 14 {
            for id in 1..=6 {
                s.change(id, |m| m.orders.detached = true);
            }
        }
        if trial == 15 {
            s.change(1, |m| m.vitals.life = Life::Downed);
        }
    }
    s.geometry.tick_cover(100_000).unwrap();
    s.geometry.navigation.finalize(1);
    s.actors.rebuild_units(&mut s.units).unwrap();
    s
}
fn step(s: &mut Scene) -> Vec<Event> {
    s.context().squad_morale_tick(7, 0.5, &profile()).unwrap();
    let (_, mut out) = s.context().squad_think(7, &profile()).unwrap();
    out.extend(s.context().squad_ambush_tick(7).unwrap());
    out.extend(s.context().squad_share_ammo(7, &profile()).unwrap());
    s.geometry
        .navigation
        .process_paths(&mut s.actors, 3, s.now, &mut s.rng)
        .unwrap();
    out
}
pub fn transcript() -> Vec<u8> {
    let mut out = vec![];
    let mut previous = vec![vec![]; 6];
    for trial in 0..16 {
        let mut a = field(trial);
        let mut b = field(trial);
        for tick in 0..8 {
            a.now = 100.0 + tick as f64 * 8.1;
            b.now = a.now;
            b.resume();
            let events = step(&mut a);
            assert_eq!(events, step(&mut b));
            assert_eq!(
                a.actors.checkpoint().unwrap(),
                b.actors.checkpoint().unwrap()
            );
            assert_eq!(a.squads, b.squads);
            assert_eq!(a.geometry.checkpoint(), b.geometry.checkpoint());
            assert_eq!(a.rng.state(), b.rng.state());
            let event = format!("{trial}/{tick} {events:?}").into_bytes();
            out.extend_from_slice(&(event.len() as u32).to_le_bytes());
            out.extend_from_slice(&event);
            for (last, state) in previous.iter_mut().zip([
                a.actors.checkpoint().unwrap(),
                a.squads[0].checkpoint().unwrap(),
                a.geometry.navigation.planner.checkpoint(),
                a.geometry.navigation.infantry.checkpoint(),
                a.geometry.navigation.vehicles.checkpoint(),
                a.units.checkpoint(),
            ]) {
                movement::checkpoint_delta(&mut out, last, state);
            }
            out.extend_from_slice(&a.rng.state().to_le_bytes());
        }
    }
    out
}
