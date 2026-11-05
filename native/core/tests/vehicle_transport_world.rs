#[path = "fixtures/squad_movement_world.rs"]
#[allow(dead_code)]
mod fixture;
use fixture::Scene;
use frontline_core::actors::Actor;
use frontline_core::attack_plan::{AttackPlan, Event};
use frontline_core::infantry_control::HiddenReason;
use frontline_core::infantry_vitals::Life;
use frontline_core::vector::Vector3;
use frontline_core::vehicle::Vehicle;
use frontline_core::visibility::Visibility;

fn carrier(s: &mut Scene, assault: bool) -> u32 {
    let id = s
        .actors
        .spawn(Actor::Vehicle(Box::new(Vehicle {
            kind: "truck".into(),
            team: 0,
            passengers: (1..=6).collect(),
            position: Vector3::new(-28.7, 0.0, 2.3),
            yaw: 0.37,
            assault,
            assault_destination: Some(Vector3::new(30.7, 0.0, -4.3)),
            ..Default::default()
        })))
        .unwrap();
    for sid in 1..=6 {
        s.change(sid, |m| {
            m.vitals.life = Life::Hidden;
            m.links.vehicle = u64::from(id);
            m.control.hidden = HiddenReason::Vehicle;
        });
    }
    id
}
#[test]
fn dismounting_defends_and_clears_passenger_links_before_orders() {
    let mut s = Scene::new(19);
    let id = carrier(&mut s, false);
    let (plan, out) = s
        .context()
        .dismount_vehicle(id, false, 17, &Visibility::default())
        .unwrap();
    assert!(plan.is_none());
    assert_eq!(s.squads[0].order, "defend");
    assert!(out.contains(&Event::Stat("dismount")));
    assert!(out
        .iter()
        .any(|e| matches!(e,Event::Speech { soldier:1, text } if text == "Dismount! Go, go, go!")));
    assert!(s.actors.vehicle(id).unwrap().passengers.is_empty());
    for sid in 1..=6 {
        let m = s.actors.soldier(sid).unwrap();
        assert_eq!(m.links.vehicle, 0);
        assert_eq!(m.vitals.life, Life::Alive);
        assert_eq!(m.orders.leash, 7.0);
    }
    let before = s.actors.checkpoint().unwrap();
    let random = s.rng.state();
    assert!(s
        .context()
        .dismount_vehicle(id, false, 18, &Visibility::default())
        .unwrap()
        .1
        .is_empty());
    assert_eq!(before, s.actors.checkpoint().unwrap());
    assert_eq!(random, s.rng.state());
}
#[test]
fn assault_and_shore_landings_restore_full_attack_plans_after_leader_loss() {
    for boat in [false, true] {
        let mut a = Scene::new(41);
        let id = carrier(&mut a, !boat);
        a.change(1, |m| {
            m.vitals.life = Life::Downed;
            m.links.vehicle = 0;
        });
        let mut b = Scene::new(41);
        let id2 = carrier(&mut b, !boat);
        b.change(1, |m| {
            m.vitals.life = Life::Downed;
            m.links.vehicle = 0;
        });
        b.resume();
        assert_eq!(id, id2);
        let (pa, ea) = a
            .context()
            .dismount_vehicle(id, boat, 17, &Visibility::default())
            .unwrap();
        let (pb, eb) = b
            .context()
            .dismount_vehicle(id, boat, 17, &Visibility::default())
            .unwrap();
        assert_eq!(ea, eb);
        let mut pa = pa.unwrap();
        let mut pb = AttackPlan::restore(&pb.unwrap().checkpoint().unwrap()).unwrap();
        assert_eq!(a.squads[0].leader, 2);
        assert_eq!(a.squads[0].plan, 17);
        for step in 0..8 {
            a.now = 101.0 + step as f64;
            b.now = a.now;
            assert_eq!(
                pa.tick(&mut a.context()).unwrap(),
                pb.tick(&mut b.context()).unwrap()
            );
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
        }
    }
}
#[test]
fn invalid_transport_orders_leave_passengers_and_random_state_unchanged() {
    let mut s = Scene::new(79);
    let id = carrier(&mut s, true);
    let actors = s.actors.checkpoint().unwrap();
    let random = s.rng.state();
    assert!(s
        .context()
        .dismount_vehicle(id, false, 0, &Visibility::default())
        .is_err());
    assert_eq!(actors, s.actors.checkpoint().unwrap());
    assert_eq!(random, s.rng.state());
    s.squads.clear();
    assert!(s
        .context()
        .dismount_vehicle(id, false, 17, &Visibility::default())
        .is_err());
    assert_eq!(actors, s.actors.checkpoint().unwrap());
    assert_eq!(random, s.rng.state());
}
