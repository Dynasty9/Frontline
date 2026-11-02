#[path = "fixtures/squad_movement_world.rs"]
#[allow(dead_code)]
mod fixture;
use fixture::Scene;
use frontline_core::actors::Actor;
use frontline_core::attack_plan::{AttackPlan, Event, Phase};
use frontline_core::infantry::{Goal, Infantry};
use frontline_core::infantry_controller::Task;
use frontline_core::infantry_vitals::Life;
use frontline_core::squad::{Contact, Report, Squad};
use frontline_core::squad_movement::{Call, Event as SquadEvent};
use frontline_core::vector::Vector3;
use frontline_core::visibility::Visibility;

fn attack(s: &mut Scene) -> AttackPlan {
    s.context()
        .order_assault(
            7,
            Vector3::new(30.0, 0.0, 6.0),
            Vector3::X,
            17,
            &Visibility::default(),
        )
        .unwrap()
        .0
        .unwrap()
}
fn defender(s: &mut Scene, n: u32) {
    for k in 0..n {
        let mut m = Infantry::default();
        m.identity.unit = "rifleman".into();
        m.identity.team = 1;
        m.motion.position = Vector3::new(30.0, 0.0, 6.0 + k as f32 * 0.1);
        let position = m.motion.position;
        let id = s.actors.spawn(Actor::Soldier(Box::new(m))).unwrap();
        s.squads[0].known.push(Contact {
            id,
            report: Report {
                position,
                time: s.now,
            },
        });
    }
    s.actors.rebuild_units(&mut s.units).unwrap();
}
fn arrived(s: &mut Scene) {
    for id in 1..=6 {
        s.change(id, |m| {
            m.orders.purpose = Goal::None;
            m.motion.path.clear();
            m.orders.pending_path = false;
        });
    }
}
#[test]
fn defense_routes_to_distant_positions_then_establishes_cover_and_leashes() {
    let mut s = Scene::new(137);
    let p = Vector3::new(30.0, 0.0, 10.0);
    s.context().order_defend(7, p, Vector3::X, false).unwrap();
    assert_eq!(s.squads[0].order, "move");
    assert_eq!(s.squads[0].then_defend, Some([p, Vector3::X]));
    s.squads[0].plan = 17;
    s.squads[0].ambush_plan = 19;
    let out = s.context().order_defend(7, p, Vector3::X, true).unwrap();
    assert_eq!(s.squads[0].order, "defend");
    assert!(s.squads[0].ambush);
    assert!(s.squads[0].then_defend.is_none());
    assert_eq!(s.squads[0].plan, 0);
    assert!(out.contains(&SquadEvent::CancelAmbush(19)));
    assert!(out.iter().any(|e| matches!(
        e,
        SquadEvent::Speech {
            call: Call::Defend,
            ..
        }
    )));
    for id in 1..=6 {
        assert_eq!(s.actors.soldier(id).unwrap().orders.leash, 7.0);
    }
}

#[test]
fn planning_halt_stops_routes_without_releasing_a_rescuers_patient() {
    let mut s = Scene::new(103);
    s.change(3, |m| {
        m.duty.kind = Task::Rescue;
        m.duty.entity = 2;
        m.motion.path = vec![Vector3::new(-10.0, 0.0, 2.0)];
        m.orders.purpose = Goal::Task;
        m.orders.hold_position = Vector3::new(-15.0, 0.0, 3.0);
    });
    s.change(2, |m| {
        m.links.rescue_claimed = 3;
        m.links.dragged_by = 3;
    });
    let mut plan = attack(&mut s);
    plan.tick(&mut s.context()).unwrap();
    let rescuer = s.actors.soldier(3).unwrap();
    assert_eq!(rescuer.duty.kind, Task::Rescue);
    assert_eq!(rescuer.duty.entity, 2);
    assert!(rescuer.motion.path.is_empty());
    assert_eq!(rescuer.orders.hold_position, Vector3::new(-15.0, 0.0, 3.0));
    let patient = s.actors.soldier(2).unwrap();
    assert_eq!(
        (patient.links.rescue_claimed, patient.links.dragged_by),
        (3, 3)
    );
}
#[test]
fn small_squads_bound_but_do_not_ignore_a_deliberate_plan() {
    let mut s = Scene::new(17);
    for id in 4..=6 {
        s.change(id, |m| m.vitals.life = Life::Downed);
    }
    let (plan, out) = s
        .context()
        .order_assault(
            7,
            Vector3::new(30.0, 0.0, 6.0),
            Vector3::X,
            17,
            &Visibility::default(),
        )
        .unwrap();
    assert!(plan.is_none());
    assert_eq!(s.squads[0].bound_team, 1);
    assert!(out.iter().any(|e| matches!(
        e,
        Event::Squad(SquadEvent::Speech {
            call: Call::Assault,
            ..
        })
    )));
    s.now += 13.0;
    s.context().assault_bounds_tick(7).unwrap();
    assert_eq!(s.squads[0].bound_team, 0);
    s.squads[0].plan = 17;
    let before = s.squads[0].clone();
    let rng = s.rng.state();
    assert!(s.context().assault_bounds_tick(7).is_err());
    assert_eq!(s.squads[0], before);
    assert_eq!(s.rng.state(), rng);
}
#[test]
fn deliberate_attacks_keep_guns_in_support_and_shift_fire_before_consolidating() {
    let mut s = Scene::new(31);
    let mut p = attack(&mut s);
    assert_eq!(s.squads[0].plan, 17);
    assert_eq!(s.actors.soldier(1).unwrap().fight.fire_team, 0);
    assert_eq!(s.actors.soldier(4).unwrap().fight.fire_team, 0);
    assert_eq!(s.actors.soldier(2).unwrap().fight.fire_team, 1);
    assert_eq!(p.start_count, 3);
    p.tick(&mut s.context()).unwrap();
    s.now += 3.0;
    let out = p.tick(&mut s.context()).unwrap();
    assert!(out.contains(&Event::Stat("plan_move")));
    for id in 1..=6 {
        assert_eq!(s.actors.soldier(id).unwrap().orders.leash, 4.5);
    }
    arrived(&mut s);
    s.now += 1.0;
    p.tick(&mut s.context()).unwrap();
    assert_eq!(p.phase, Phase::Assault);
    assert!(p.support_set);
    for id in 1..=6 {
        s.change(id, |m| {
            if m.fight.fire_team == 1 {
                m.motion.position = Vector3::new(12.0, 0.0, 6.0);
            }
        });
    }
    s.now += 1.0;
    p.tick(&mut s.context()).unwrap();
    assert!(p.shifted);
    assert!(s.actors.soldier(1).unwrap().fight.covering_position.x > p.objective.x);
    for id in 1..=6 {
        s.change(id, |m| {
            if m.fight.fire_team == 1 {
                m.motion.position = Vector3::new(29.0, 0.0, 6.0);
            }
        });
    }
    s.now += 1.0;
    let out = p.tick(&mut s.context()).unwrap();
    assert!(p.done);
    assert!(out.contains(&Event::Stat("plan_won")));
    assert_eq!(s.squads[0].plan, 0);
    assert_eq!(s.squads[0].order, "defend");
}
#[test]
fn outnumbered_attacks_fix_the_enemy_and_reinforcements_restart_the_plan() {
    let mut s = Scene::new(13);
    defender(&mut s, 7);
    let mut p = attack(&mut s);
    p.tick(&mut s.context()).unwrap();
    s.now += 3.0;
    let out = p.tick(&mut s.context()).unwrap();
    assert_eq!(p.phase, Phase::Fix);
    assert!(out
        .iter()
        .any(|e| matches!(e, Event::NeedsSupport { squad: 7, .. })));
    let mut q = Squad::new(8, 0, 1, "rifle_squad".into()).unwrap();
    for k in 0..6 {
        let mut m = Infantry::default();
        m.identity.unit = "rifleman".into();
        m.motion.position = Vector3::new(-30.0, 0.0, k as f32 + 10.0);
        let id = s.actors.spawn(Actor::Soldier(Box::new(m))).unwrap();
        q.add_member(id, &mut s.actors).unwrap();
    }
    s.squads.push(q);
    let out = p.join(&mut s.context(), 8).unwrap();
    assert!(out.contains(&Event::Stat("plan_reinforced")));
    assert_eq!(s.squads[1].plan, 17);
    assert_eq!(p.start_count, 9);
    assert!(p.join(&mut s.context(), 8).unwrap().is_empty());
    s.now += 1.0;
    p.tick(&mut s.context()).unwrap();
    assert_eq!(p.phase, Phase::Plan);
    assert_eq!(p.phase_time, 0.0);
}
#[test]
fn rushes_use_smoke_then_grenades_and_pinned_assaults_fall_back() {
    let mut s = Scene::new(71);
    defender(&mut s, 1);
    for id in 1..=6 {
        s.change(id, |m| {
            m.fight.smokes = 1;
            m.grenades.frags = 2;
        });
    }
    let mut p = attack(&mut s);
    p.phase = Phase::Assault;
    p.tick(&mut s.context()).unwrap();
    assert!(p.smoked);
    assert!(s.actors.iter().any(|a| matches!(a, Actor::Soldier(m) if m.duty.kind == Task::Throw && m.duty.throw_kind == frontline_core::infantry_action::Round::Smoke)));
    for id in 1..=6 {
        s.change(id, |m| {
            if m.fight.fire_team == 1 {
                m.motion.position = Vector3::new(8.0, 0.0, 6.0);
            }
            m.duty.kind = Task::Fight;
        });
    }
    s.now += 4.0;
    p.tick(&mut s.context()).unwrap();
    assert!(s.actors.iter().any(|a| matches!(a, Actor::Soldier(m) if m.duty.kind == Task::Throw && m.duty.throw_kind == frontline_core::infantry_action::Round::Frag)));
    for id in 1..=6 {
        s.change(id, |m| {
            m.vitals.suppression = 80.0;
            m.duty.kind = Task::Fight;
        });
    }
    p.pinned_time = 10.0;
    s.now += 1.0;
    assert!(p
        .tick(&mut s.context())
        .unwrap()
        .contains(&Event::Stat("plan_fallback")));
    assert_eq!(p.phase, Phase::Fallback);
    for id in 1..=6 {
        s.change(id, |m| m.vitals.suppression = 20.0);
    }
    s.now += 21.0;
    p.tick(&mut s.context()).unwrap();
    assert_eq!(p.phase, Phase::Assault);
}
#[test]
fn saved_attack_continues_with_identical_orders_speech_routes_and_random_draws() {
    let mut a = Scene::new(211);
    let mut b = Scene::new(211);
    let mut pa = attack(&mut a);
    let mut pb = attack(&mut b);
    for step in 0..32 {
        a.now = 100.0 + step as f64 * 3.7;
        b.now = a.now;
        if step % 4 == 3 {
            arrived(&mut a);
            arrived(&mut b);
        }
        assert_eq!(
            pa.tick(&mut a.context()).unwrap(),
            pb.tick(&mut b.context()).unwrap()
        );
        for s in [&mut a, &mut b] {
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
        }
        assert_eq!(pa, pb);
        assert_eq!(
            a.actors.checkpoint().unwrap(),
            b.actors.checkpoint().unwrap()
        );
        assert_eq!(a.squads, b.squads);
        assert_eq!(a.rng, b.rng);
        assert_eq!(
            a.geometry.navigation.checkpoint(),
            b.geometry.navigation.checkpoint()
        );
        b.resume();
        pb = AttackPlan::restore(&pb.checkpoint().unwrap()).unwrap();
    }
}
#[test]
fn invalid_attack_checkpoints_and_orders_fail_before_mutating_the_battle() {
    let mut s = Scene::new(89);
    let mut p = attack(&mut s);
    let bytes = p.checkpoint().unwrap();
    for n in 0..bytes.len() {
        assert!(AttackPlan::restore(&bytes[..n]).is_err());
    }
    let mut extended = bytes.clone();
    extended.push(0);
    assert!(AttackPlan::restore(&extended).is_err());
    let actors = s.actors.checkpoint().unwrap();
    let q = s.squads.clone();
    let rng = s.rng.state();
    assert!(s
        .context()
        .order_defend(7, Vector3::NAN, Vector3::X, false)
        .is_err());
    assert!(s
        .context()
        .order_assault(7, Vector3::ZERO, Vector3::NAN, 18, &Visibility::default())
        .is_err());
    s.now = f64::NAN;
    assert!(p.tick(&mut s.context()).is_err());
    assert_eq!(p.checkpoint().unwrap(), bytes);
    assert_eq!(actors, s.actors.checkpoint().unwrap());
    assert_eq!(q, s.squads);
    assert_eq!(rng, s.rng.state());
}
