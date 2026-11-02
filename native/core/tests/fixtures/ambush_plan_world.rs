#[path = "squad_brain_world.rs"]
#[allow(dead_code)]
mod brain;
#[path = "squad_movement_world.rs"]
#[allow(dead_code)]
mod movement;
use brain::{contact, Scene};
use frontline_core::ambush_plan::{AmbushPlan, Phase};
use frontline_core::infantry_vitals::Life;
use frontline_core::squad_brain::Event;
use frontline_core::vector::Vector3;
fn field(trial: u64) -> (Scene, AmbushPlan, Vec<Event>) {
    let mut s = Scene::new(7301 + trial);
    s.squads[0].team = (trial / 8) as i8;
    let team = s.squads[0].team;
    for id in 1..=6 {
        s.change(id, |m| {
            m.identity.team = team;
            m.fight.smokes = 1;
        });
    }
    let (p, out) = AmbushPlan::make(
        &mut s.context(),
        19,
        7,
        Vector3::ZERO,
        Vector3::Z,
        Vector3::NEG_X,
    )
    .unwrap();
    (s, p, out)
}
fn stage(s: &mut Scene, p: &mut AmbushPlan, trial: u64, tick: u32) {
    s.now = 100. + tick as f64 * 7.1;
    let case = trial % 8;
    if tick == 1 {
        if case == 1 {
            contact(s, 20.);
        } else if case == 7 {
            s.squads[0].drill = "rout".into();
        } else {
            for id in 1..=6 {
                s.change(id, |m| m.motion.position = p.rally);
            }
        }
    }
    if tick == 2 {
        for id in 1..=6 {
            s.change(id, |m| {
                m.motion.position = Vector3::new(-24., 0., id as f32 * 1.3)
            });
        }
        if [0, 3, 4, 5, 6].contains(&case) {
            contact(s, 24.);
            let id = s
                .actors
                .iter()
                .filter_map(|a| match a {
                    frontline_core::actors::Actor::Soldier(m) if m.identity.squad == 0 => {
                        Some(m.identity.id)
                    }
                    _ => None,
                })
                .last()
                .unwrap();
            let team = s.squads[0].team;
            s.change(id, |m| {
                m.identity.team = 1 - team;
                m.motion.position = Vector3::ZERO;
                if case == 4 {
                    m.vitals.life = Life::Downed;
                }
            });
            if case == 0 {
                let mut second = s.actors.soldier(id).unwrap().clone();
                second.identity.id = 0;
                second.motion.position.z = 3.;
                s.actors
                    .spawn(frontline_core::actors::Actor::Soldier(Box::new(second)))
                    .unwrap();
            }
        }
    }
    if tick >= 3 && case == 2 {
        s.now += 300.;
    }
    if tick == 3 && case == 4 {
        s.change(2, |m| m.vitals.suppression = 60.);
    }
    if tick == 3 && case == 5 {
        s.change(7, |m| m.motion.position = Vector3::new(-23., 0., 2.));
    }
    if tick == 4 && case == 6 {
        p.phase = Phase::Spring;
        p.fire_time = s.now;
        p.quiet_time = s.now;
    }
    if tick == 5 && case == 3 {
        s.change(7, |m| m.motion.position = Vector3::new(62., 0., 62.));
    }
    s.squads[0].centroid_at = -1.;
    s.actors.rebuild_units(&mut s.units).unwrap();
}
pub fn transcript() -> Vec<u8> {
    let mut out = vec![];
    let mut previous = vec![vec![]; 7];
    for trial in 0..16 {
        let (mut a, mut ap, initial) = field(trial);
        let (mut b, mut bp, other) = field(trial);
        assert_eq!(initial, other);
        out.extend_from_slice(format!("{initial:?}").as_bytes());
        for tick in 0..12 {
            stage(&mut a, &mut ap, trial, tick);
            stage(&mut b, &mut bp, trial, tick);
            b.resume();
            bp = AmbushPlan::restore(&bp.checkpoint().unwrap()).unwrap();
            let events = ap.tick(&mut a.context(), &|_| false).unwrap();
            assert_eq!(events, bp.tick(&mut b.context(), &|_| false).unwrap());
            a.geometry
                .navigation
                .process_paths(
                    &mut a.actors,
                    3,
                    a.now,
                    &mut a.rng,
                    frontline_core::traversal::Ground::new(&a.geometry.terrain, &a.geometry.deck),
                )
                .unwrap();
            b.geometry
                .navigation
                .process_paths(
                    &mut b.actors,
                    3,
                    b.now,
                    &mut b.rng,
                    frontline_core::traversal::Ground::new(&b.geometry.terrain, &b.geometry.deck),
                )
                .unwrap();
            assert_eq!(ap, bp);
            assert_eq!(
                a.actors.checkpoint().unwrap(),
                b.actors.checkpoint().unwrap()
            );
            assert_eq!(a.squads, b.squads);
            assert_eq!(a.geometry.checkpoint(), b.geometry.checkpoint());
            assert_eq!(a.rng.state(), b.rng.state());
            let e = format!("{trial}/{tick} {events:?}").into_bytes();
            out.extend_from_slice(&(e.len() as u32).to_le_bytes());
            out.extend_from_slice(&e);
            for (last, state) in previous.iter_mut().zip([
                a.actors.checkpoint().unwrap(),
                a.squads[0].checkpoint().unwrap(),
                a.geometry.navigation.planner.checkpoint(),
                a.geometry.navigation.infantry.checkpoint(),
                a.geometry.navigation.vehicles.checkpoint(),
                a.units.checkpoint(),
                ap.checkpoint().unwrap(),
            ]) {
                movement::checkpoint_delta(&mut out, last, state);
            }
            out.extend_from_slice(&a.rng.state().to_le_bytes());
        }
    }
    out
}
