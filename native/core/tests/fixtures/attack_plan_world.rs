#[path = "squad_movement_world.rs"]
#[allow(dead_code)]
mod movement;
use frontline_core::actors::Actor;
use frontline_core::attack_plan::{AttackPlan, Event, Phase};
use frontline_core::infantry::{Goal, Infantry};
use frontline_core::infantry_vitals::Life;
use frontline_core::squad::{Contact, Report, Squad};
use frontline_core::squad_movement::Event as SquadEvent;
use frontline_core::vector::Vector3;
use frontline_core::visibility::Visibility;

fn block(out: &mut Vec<u8>, bytes: &[u8]) {
    out.extend_from_slice(&(bytes.len() as u32).to_le_bytes());
    out.extend_from_slice(bytes);
}
fn events(out: &mut Vec<u8>, events: Vec<Event>) {
    for e in events {
        match e {
            Event::Squad(SquadEvent::Speech {
                soldier,
                call,
                variant,
            }) => {
                out.push(0);
                out.extend_from_slice(&soldier.to_le_bytes());
                out.extend_from_slice(&[call as u8, variant]);
            }
            Event::Squad(SquadEvent::CancelAmbush(id)) => {
                out.push(1);
                out.extend_from_slice(&id.to_le_bytes());
            }
            Event::Squad(SquadEvent::Stat(name)) | Event::Stat(name) => {
                out.push(2);
                block(out, name.as_bytes());
            }
            Event::Speech { soldier, text } => {
                out.push(3);
                out.extend_from_slice(&soldier.to_le_bytes());
                block(out, text.as_bytes());
            }
            Event::NeedsSupport {
                team,
                squad,
                position,
            } => {
                out.push(4);
                out.push(team as u8);
                out.extend_from_slice(&squad.to_le_bytes());
                for v in position.to_array() {
                    out.extend_from_slice(&v.to_le_bytes());
                }
            }
            e => panic!("unexpected attack event {e:?}"),
        }
    }
    out.push(255);
}
pub fn transcript() -> Vec<u8> {
    let mut out = vec![];
    let mut previous = [vec![], vec![], vec![]];
    let mut previous_actors = vec![];
    let mut previous_plan = vec![];
    let mut previous_squads = [vec![], vec![]];
    for trial in 0..4 {
        let mut s = movement::Scene::new(3141 + trial);
        for id in 1..=6 {
            s.change(id, |m| {
                m.grenades.frags = 2;
                m.fight.smokes = 1;
            });
        }
        let mut q = Squad::new(8, 0, 1, "rifle_squad".into()).unwrap();
        for k in 0..6 {
            let mut m = Infantry::default();
            m.identity.unit = "rifleman".into();
            m.motion.position = Vector3::new(-29.7, 0.0, 10.3 + k as f32);
            let id = s.actors.spawn(Actor::Soldier(Box::new(m))).unwrap();
            q.add_member(id, &mut s.actors).unwrap();
        }
        s.squads.push(q);
        for k in 0..8 {
            let mut m = Infantry::default();
            m.identity.unit = "rifleman".into();
            m.identity.team = 1;
            m.motion.position = Vector3::new(30.7, 0.0, 6.3 + k as f32 * 0.2);
            let position = m.motion.position;
            let id = s.actors.spawn(Actor::Soldier(Box::new(m))).unwrap();
            if trial % 3 == 0 {
                s.squads[0].known.push(Contact {
                    id,
                    report: Report {
                        position,
                        time: s.now,
                    },
                });
            }
        }
        s.actors.rebuild_units(&mut s.units).unwrap();
        let (plan, initial) = if trial % 4 == 0 {
            AttackPlan::make(
                &mut s.context(),
                17,
                &[7, 8],
                Vector3::new(30.7, 0.0, 6.3),
                Vector3::ZERO,
                &Visibility::default(),
            )
            .unwrap()
        } else {
            s.context()
                .order_assault(
                    7,
                    Vector3::new(30.7, 0.0, 6.3),
                    Vector3::ZERO,
                    17,
                    &Visibility::default(),
                )
                .unwrap()
        };
        let mut plan = plan.unwrap();
        events(&mut out, initial);
        for step in 0..32 {
            s.now = 100.0 + step as f64 * 3.7;
            if step == 3 && trial % 4 == 1 {
                let e = plan.join(&mut s.context(), 8).unwrap();
                events(&mut out, e);
            }
            if step == 4 && trial % 4 >= 2 {
                plan.phase = Phase::Assault;
                plan.phase_time = s.now;
                plan.rush_time = 0.0;
            }
            if step % 3 == 0 {
                for id in 1..=6 {
                    s.change(id, |m| {
                        if !m.orders.pending_path {
                            m.orders.purpose = Goal::None;
                            m.motion.path.clear();
                        }
                    });
                }
            }
            if trial % 4 == 2 && step >= 4 {
                for id in 1..=6 {
                    s.change(id, |m| {
                        m.vitals.suppression = if step < 26 { 80.0 } else { 20.0 }
                    });
                }
            }
            if trial % 4 == 3 && step >= 4 {
                for id in 1..=6 {
                    s.change(id, |m| {
                        if m.fight.fire_team == 1 {
                            m.motion.position =
                                Vector3::new(0.7 + ((step - 4) as f32 * 4.0).min(29.0), 0.0, 6.3);
                        }
                    });
                }
            }
            if step == 12 && trial % 7 == 0 {
                for id in 1..=6 {
                    s.change(id, |m| m.vitals.life = Life::Downed);
                }
            }
            s.actors.rebuild_units(&mut s.units).unwrap();
            events(&mut out, plan.tick(&mut s.context()).unwrap());
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
            movement::checkpoint_delta(&mut out, &mut previous_plan, plan.checkpoint().unwrap());
            movement::checkpoint_delta(
                &mut out,
                &mut previous_actors,
                s.actors.checkpoint().unwrap(),
            );
            for (q, previous) in s.squads.iter().zip(&mut previous_squads) {
                movement::checkpoint_delta(&mut out, previous, q.checkpoint().unwrap());
            }
            for (previous, next) in previous.iter_mut().zip([
                s.geometry.navigation.planner.checkpoint(),
                s.geometry.navigation.infantry.checkpoint(),
                s.geometry.navigation.vehicles.checkpoint(),
            ]) {
                movement::checkpoint_delta(&mut out, previous, next);
            }
            out.extend_from_slice(&s.rng.state().to_le_bytes());
            if step % 5 == 4 {
                s.resume();
                plan = AttackPlan::restore(&plan.checkpoint().unwrap()).unwrap();
            }
        }
    }
    out
}

pub fn transport_transcript() -> Vec<u8> {
    use frontline_core::infantry_control::HiddenReason;
    use frontline_core::vehicle::Vehicle;
    let mut out = vec![];
    let mut previous = [vec![], vec![], vec![], vec![], vec![]];
    for trial in 0..4 {
        let mut s = movement::Scene::new(7121 + trial);
        let id = s
            .actors
            .spawn(Actor::Vehicle(Box::new(Vehicle {
                kind: "truck".into(),
                team: 0,
                passengers: (1..=6).collect(),
                position: Vector3::new(-28.7, 0.0, 2.3),
                yaw: trial as f64 * 0.37,
                assault: trial % 2 == 1,
                assault_destination: Some(Vector3::new(30.7, 0.0, -4.3)),
                ..Default::default()
            })))
            .unwrap();
        for sid in 1..=6 {
            s.change(sid, |m| {
                m.vitals.life = Life::Hidden;
                m.links.vehicle = u64::from(id);
                m.control.hidden = HiddenReason::Vehicle;
                if trial == 3 && sid == 1 {
                    m.vitals.life = Life::Downed;
                    m.links.vehicle = 0;
                }
            });
        }
        s.resume();
        let (mut plan, event) = s
            .context()
            .dismount_vehicle(id, trial >= 2, 17, &Visibility::default())
            .unwrap();
        events(&mut out, event);
        for step in 0..6 {
            s.now += 1.7;
            if step == 1 {
                let (again, event) = s
                    .context()
                    .dismount_vehicle(id, trial >= 2, 18, &Visibility::default())
                    .unwrap();
                assert!(again.is_none());
                assert!(event.is_empty());
            }
            if let Some(p) = &mut plan {
                events(&mut out, p.tick(&mut s.context()).unwrap());
                block(&mut out, &p.checkpoint().unwrap());
            } else {
                block(&mut out, &[]);
            }
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
            for (previous, next) in previous.iter_mut().zip([
                s.actors.checkpoint().unwrap(),
                s.squads[0].checkpoint().unwrap(),
                s.geometry.navigation.planner.checkpoint(),
                s.geometry.navigation.infantry.checkpoint(),
                s.geometry.navigation.vehicles.checkpoint(),
            ]) {
                movement::checkpoint_delta(&mut out, previous, next);
            }
            out.extend_from_slice(&s.rng.state().to_le_bytes());
            s.resume();
            if let Some(p) = &mut plan {
                *p = AttackPlan::restore(&p.checkpoint().unwrap()).unwrap();
            }
        }
    }
    out
}
