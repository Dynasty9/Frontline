#[path = "squad_brain_world.rs"]
#[allow(dead_code)]
mod brain;
#[path = "squad_movement_world.rs"]
#[allow(dead_code)]
mod movement;
use brain::{contact, Scene};
use frontline_core::battle_stats::{BattleStats, Unit};
use frontline_core::infantry::Infantry;
use frontline_core::infantry_vitals::Life;
use frontline_core::random::SimulationRandom;
use frontline_core::squad::Squad;
use frontline_core::squad_brain::Event;
use frontline_core::squad_duties::Role;
use frontline_core::structure::Structure;
use frontline_core::vector::Vector3;

fn role(s: &Infantry) -> Role {
    Role {
        medic: s.identity.id == 6,
        engineer: s.identity.id == 5,
    }
}
fn field(trial: u64) -> (Scene, BattleStats) {
    let mut s = Scene::new(8317 + trial);
    let scenario = trial % 8;
    if scenario == 0 || scenario == 7 {
        contact(&mut s, 20.0);
    }
    for id in 1..=6 {
        s.change(id, |m| m.fight.smokes = i32::from(trial < 8));
    }
    match scenario {
        0 | 1 => s.change(1, |m| m.vitals.life = Life::Downed),
        2 => s.change(2, |m| m.vitals.hp = 30.0),
        3 | 4 => {
            s.geometry
                .spawn_structure(
                    &mut s.actors,
                    Structure {
                        kind: "hesco".into(),
                        position: Vector3::new(-15.0, 0.0, 12.0),
                        size: Vector3::new(8.0, 2.0, 1.0),
                        team: 0,
                        hp: 50.0,
                        max_hp: 100.0,
                        ..Default::default()
                    },
                    None,
                )
                .unwrap();
            if scenario == 4 {
                s.squads[0].order = "build".into();
            }
        }
        5 | 6 => {
            s.change(2, |m| {
                m.vitals.life = if scenario == 5 {
                    Life::Dead
                } else {
                    Life::Downed
                }
            });
            let mut q = Squad::new(8, 0, 1, "rifle_squad".into()).unwrap();
            for id in 3..=6 {
                s.squads[0].remove_member(id, &mut s.actors).unwrap();
                q.add_member(id, &mut s.actors).unwrap();
            }
            q.leader = 3;
            s.squads.push(q);
        }
        _ => {
            for id in 2..=6 {
                s.change(id, |m| m.vitals.life = Life::Dead);
            }
            s.change(1, |m| {
                m.vitals.suppression = 60.0;
                m.identity.weapon = "rifle".into();
            });
            let seed = (0..1000)
                .find(|&seed| f64::from(SimulationRandom::new(seed).randf()) < 0.035)
                .unwrap();
            s.rng = SimulationRandom::new(seed);
        }
    }
    s.squads[0].clear_call = Some((3, 100.5));
    if scenario == 2 {
        s.squads[0].order = "move".into();
        s.squads[0].then_defend = Some([Vector3::new(-20.0, 0.0, 4.0), Vector3::NEG_Z]);
    }
    let mut battle = BattleStats::default();
    for q in &s.squads {
        battle
            .register_unit(Unit {
                key: format!("s{}", q.id),
                name: q.callsign(),
                kind: "Rifle squad".into(),
                team: q.team,
                owner: q.owner,
                men: q.members.len() as u32,
                ..Default::default()
            })
            .unwrap();
    }
    s.geometry.tick_cover(100_000).unwrap();
    s.geometry.navigation.finalize(1);
    s.actors.rebuild_units(&mut s.units).unwrap();
    (s, battle)
}
fn step(s: &mut Scene, battle: &mut BattleStats) -> Vec<Event> {
    let mut out = s.context().squad_straggler_tick(7, battle).unwrap();
    out.extend(s.context().squad_then_defend_tick(7).unwrap());
    out.extend(s.context().squad_clear_call_tick(7).unwrap());
    out.extend(s.context().squad_rescue(7, &role).unwrap());
    out.extend(s.context().squad_surrender(7).unwrap());
    s.context().squad_medics(7, &role).unwrap();
    s.context().squad_engineers(7, &role).unwrap();
    s.geometry
        .navigation
        .process_paths(
            &mut s.actors,
            3,
            s.now,
            &mut s.rng,
            frontline_core::traversal::Ground::new(&s.geometry.terrain, &s.geometry.deck),
        )
        .unwrap();
    out
}
pub fn transcript() -> Vec<u8> {
    let mut out = vec![];
    let mut previous = vec![vec![]; 7];
    for trial in 0..16 {
        let (mut a, mut ab) = field(trial);
        let (mut b, mut bb) = field(trial);
        for tick in 0..8 {
            a.now = 100.0 + tick as f64 * 0.5;
            b.now = a.now;
            b.resume();
            bb = BattleStats::restore(&bb.checkpoint()).unwrap();
            let events = step(&mut a, &mut ab);
            assert_eq!(events, step(&mut b, &mut bb));
            assert_eq!(
                a.actors.checkpoint().unwrap(),
                b.actors.checkpoint().unwrap()
            );
            assert_eq!(a.squads, b.squads);
            assert_eq!(a.geometry.checkpoint(), b.geometry.checkpoint());
            assert_eq!(a.rng.state(), b.rng.state());
            assert_eq!(ab.checkpoint(), bb.checkpoint());
            let events = format!("{trial}/{tick} {events:?}").into_bytes();
            out.extend_from_slice(&(events.len() as u32).to_le_bytes());
            out.extend_from_slice(&events);
            let mut squads = vec![];
            for q in &a.squads {
                let bytes = q.checkpoint().unwrap();
                squads.extend_from_slice(&(bytes.len() as u32).to_le_bytes());
                squads.extend_from_slice(&bytes);
            }
            for (last, state) in previous.iter_mut().zip([
                a.actors.checkpoint().unwrap(),
                squads,
                a.geometry.navigation.planner.checkpoint(),
                a.geometry.navigation.infantry.checkpoint(),
                a.geometry.navigation.vehicles.checkpoint(),
                a.units.checkpoint(),
                ab.checkpoint(),
            ]) {
                movement::checkpoint_delta(&mut out, last, state);
            }
            out.extend_from_slice(&a.rng.state().to_le_bytes());
        }
    }
    out
}
