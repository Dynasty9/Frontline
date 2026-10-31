#[path = "fixtures/squad_movement_world.rs"]
#[allow(dead_code)]
mod fixture;
use fixture::Scene;
use frontline_core::infantry::{Goal, Infantry};
use frontline_core::infantry_controller::Task;
use frontline_core::infantry_vitals::Life;
use frontline_core::squad::Report;
use frontline_core::squad_movement::Event;
use frontline_core::vector::Vector3;

#[test]
fn squad_orders_release_claims_and_keep_committed_breach_entries() {
    let mut s = Scene::new(137);
    s.squads[0].plan = 17;
    s.squads[0].ambush_plan = 19;
    s.squads[0].breach_by = 3;
    s.change(1, |m| {
        m.duty.kind = Task::Rescue;
        m.duty.entity = 2;
        m.orders.detached = true;
    });
    s.change(2, |m| {
        m.links.dragged_by = 1;
        m.links.rescue_claimed = 1;
    });
    s.change(3, |m| {
        m.duty.kind = Task::Breach;
        m.duty.phase = 0;
    });
    s.change(4, |m| {
        m.duty.kind = Task::Breach;
        m.duty.phase = 2;
    });
    let out = s
        .context()
        .order_move(7, Vector3::new(-25.0, 0.0, 10.0), Vector3::X, 2, true)
        .unwrap();
    assert!(out.contains(&Event::CancelAmbush(19)));
    assert_eq!(
        (
            s.squads[0].plan,
            s.squads[0].ambush_plan,
            s.squads[0].breach_by
        ),
        (0, 0, 0)
    );
    let patient = s.actors.soldier(2).unwrap();
    assert_eq!(
        (patient.links.dragged_by, patient.links.rescue_claimed),
        (0, 0)
    );
    assert!(!s.actors.soldier(1).unwrap().orders.detached);
    assert_eq!(s.actors.soldier(3).unwrap().duty.kind, Task::Fight);
    let breacher = s.actors.soldier(4).unwrap();
    assert_eq!(breacher.duty.kind, Task::Breach);
    assert!(breacher.entry.reordered);
}

#[test]
fn travel_slows_the_leader_and_releases_followers_into_final_cover() {
    let mut s = Scene::new(17);
    s.context()
        .order_move(7, Vector3::new(30.0, 0.0, 10.0), Vector3::ZERO, 2, true)
        .unwrap();
    assert!(s.squads[0].travel);
    s.change(6, |m| m.motion.position.x = -60.0);
    s.context().follow_tick(7).unwrap();
    assert_eq!(s.actors.soldier(1).unwrap().orders.move_mode, 0);
    assert_eq!(s.actors.soldier(6).unwrap().orders.move_mode, 2);
    let end = s.squads[0].final_slots.iter().find(|v| v.0 == 1).unwrap().1;
    s.change(1, |m| m.motion.position = end);
    s.context().follow_tick(7).unwrap();
    assert!(!s.squads[0].travel);
    for &(id, p) in &s.squads[0].final_slots {
        assert_eq!(s.actors.soldier(id).unwrap().orders.hold_position, p);
    }
}

#[test]
fn bounds_alternate_teams_and_recon_fire_respects_friendly_positions() {
    let mut s = Scene::new(37);
    s.squads[0].alert_time = 99.0;
    s.squads[0].heard.push(Report {
        position: Vector3::new(25.0, 0.0, 20.0),
        time: 95.0,
    });
    let out = s
        .context()
        .order_move(7, Vector3::new(45.0, 0.0, 10.0), Vector3::X, 0, true)
        .unwrap();
    assert!(out.contains(&Event::Stat("bounding")));
    assert_eq!(s.squads[0].technique, "bound");
    assert!(s.actors.soldier(1).unwrap().is_moving());
    assert!(!s.actors.soldier(2).unwrap().is_moving());
    let out = s.context().overwatch_tick(7).unwrap();
    assert!(out.contains(&Event::Stat("recon_by_fire")));
    assert_eq!(s.actors.soldier(4).unwrap().fight.covering_until, 102.6);
    s.now = 115.0;
    s.change(5, |m| m.motion.position = Vector3::new(25.0, 0.0, 20.0));
    s.actors.rebuild_units(&mut s.units).unwrap();
    assert!(!s
        .context()
        .overwatch_tick(7)
        .unwrap()
        .contains(&Event::Stat("recon_by_fire")));
    s.now = 123.0;
    s.context().overwatch_tick(7).unwrap();
    assert_eq!(s.squads[0].overwatch_team, 1);
    assert!(s.actors.soldier(2).unwrap().is_moving());
}

#[test]
fn leader_loss_and_invalid_orders_preserve_replay_state() {
    let mut s = Scene::new(73);
    s.change(1, |m| m.vitals.life = Life::Downed);
    let out = s
        .context()
        .order_move(7, Vector3::new(5.0, 0.0, 5.0), Vector3::ZERO, 1, true)
        .unwrap();
    assert_eq!(s.squads[0].leader, 2);
    assert!(out.contains(&Event::Stat("leader_succession")));
    let before = s.actors.checkpoint().unwrap();
    let q = s.squads[0].checkpoint().unwrap();
    let rng = s.rng.state();
    assert!(s
        .context()
        .order_move(7, Vector3::NAN, Vector3::X, 1, true)
        .is_err());
    assert_eq!(before, s.actors.checkpoint().unwrap());
    assert_eq!(q, s.squads[0].checkpoint().unwrap());
    assert_eq!(rng, s.rng.state());
    s.change(2, |m: &mut Infantry| {
        m.motion.path.clear();
        m.orders.pending_path = false;
        m.orders.purpose = Goal::None;
    });
    s.resume();
    s.context().follow_tick(7).unwrap();
    assert!(!s.squads[0].travel);
}

#[test]
fn saved_formations_and_route_queues_repeat_the_same_continuation() {
    let mut uninterrupted = Scene::new(313);
    let mut resumed = Scene::new(313);
    for s in [&mut uninterrupted, &mut resumed] {
        s.squads[0].alert_time = 99.0;
        s.context()
            .order_move(7, Vector3::new(40.0, 0.0, 10.0), Vector3::ZERO, 0, true)
            .unwrap();
    }
    resumed.resume();
    for step in 0..16 {
        uninterrupted.now = 101.0 + step as f64 * 3.7;
        resumed.now = uninterrupted.now;
        assert_eq!(
            uninterrupted.context().overwatch_tick(7).unwrap(),
            resumed.context().overwatch_tick(7).unwrap()
        );
        for s in [&mut uninterrupted, &mut resumed] {
            s.geometry
                .navigation
                .process_paths(&mut s.actors, 2, s.now, &mut s.rng)
                .unwrap();
        }
        assert_eq!(
            uninterrupted.actors.checkpoint().unwrap(),
            resumed.actors.checkpoint().unwrap()
        );
        assert_eq!(uninterrupted.squads, resumed.squads);
        assert_eq!(
            uninterrupted.geometry.navigation.checkpoint(),
            resumed.geometry.navigation.checkpoint()
        );
        assert_eq!(uninterrupted.rng, resumed.rng);
    }
}

#[test]
fn crews_refund_once_and_leave_their_wounded_in_the_world() {
    use frontline_core::structure::Structure;
    let mut s = Scene::new(113);
    s.squads[0].kind = "crew".into();
    s.squads[0].cooldowns = vec![("refund".into(), 70.9)];
    let fob = s
        .geometry
        .spawn_structure(
            &mut s.actors,
            Structure {
                kind: "fob".into(),
                team: 0,
                position: Vector3::new(-28.0, 0.0, 0.0),
                supply: 10.25,
                ..Default::default()
            },
            None,
        )
        .unwrap();
    s.change(1, |m| m.vitals.life = Life::Downed);
    s.change(2, |m| m.vitals.life = Life::Dead);
    let out = s.context().crew_tick(7).unwrap();
    assert!(out.contains(&Event::CrewHome { squad: 7, fob }));
    assert_eq!(s.actors.structure(fob).unwrap().supply, 80.25);
    assert_eq!(s.squads[0].members, [1, 2]);
    assert!(s.actors.soldier(3).is_none());
    assert_eq!(s.actors.soldier(1).unwrap().identity.squad, 7);
    s.resume();
    s.now += 2.0;
    assert!(s.context().crew_tick(7).unwrap().is_empty());
    assert_eq!(s.actors.structure(fob).unwrap().supply, 80.25);
}

#[test]
fn crews_respect_manual_orders_cooldowns_and_contact_before_returning() {
    use frontline_core::structure::Structure;
    let mut s = Scene::new(117);
    s.squads[0].kind = "r_crew".into();
    s.squads[0].cooldowns = vec![("crew_n".into(), 1.0), ("refund".into(), 50.0)];
    let fob = s
        .geometry
        .spawn_structure(
            &mut s.actors,
            Structure {
                kind: "fob".into(),
                team: 0,
                position: Vector3::new(40.0, 0.0, 0.0),
                supply: 0.0,
                ..Default::default()
            },
            None,
        )
        .unwrap();
    assert!(s.context().crew_tick(7).unwrap().is_empty());
    assert_eq!(s.squads[0].order, "hold");
    s.squads[0].order_number = 1;
    s.now = 100.5;
    assert!(s.context().crew_tick(7).unwrap().is_empty());
    s.now = 101.0;
    s.context().crew_tick(7).unwrap();
    assert_eq!(s.squads[0].order, "move");
    assert_eq!(s.squads[0].move_mode, 2);
    for id in 1..=6 {
        s.change(id, |m| m.motion.position = Vector3::new(40.0, 0.0, 0.0));
    }
    s.squads[0].heard.push(Report {
        position: Vector3::ZERO,
        time: 101.0,
    });
    s.now = 102.0;
    assert!(!s
        .context()
        .crew_tick(7)
        .unwrap()
        .contains(&Event::Stat("crew_home")));
    assert_eq!(s.actors.structure(fob).unwrap().supply, 0.0);
    s.now = 108.0;
    assert!(s
        .context()
        .crew_tick(7)
        .unwrap()
        .contains(&Event::Stat("crew_home")));
}
