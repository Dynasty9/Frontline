#[path = "fixtures/squad_brain_world.rs"]
#[allow(dead_code)]
mod fixture;
use fixture::{contact, profile, Scene};
use frontline_core::infantry_vitals::Life;
use frontline_core::squad::Report;
use frontline_core::squad_brain::Event;
use frontline_core::structure::Structure;
use frontline_core::vector::Vector3;
#[test]
fn nerve_loss_routes_before_withdrawal_and_rallies_after_recovery() {
    let mut s = Scene::new(13);
    contact(&mut s, 25.0);
    s.squads[0].morale = 5.0;
    let (_, out) = s.context().squad_think(7, &profile()).unwrap();
    assert!(out.contains(&Event::Stat("squad_rout")));
    assert_eq!(s.squads[0].drill, "rout");
    assert!(!out.contains(&Event::Stat("break_contact")));
    s.now += 20.0;
    s.squads[0].morale = 46.0;
    let (_, out) = s.context().squad_think(7, &profile()).unwrap();
    assert!(out.contains(&Event::Stat("squad_rally")));
    assert_eq!(s.squads[0].order, "defend");
    assert!(s.squads[0].drill.is_empty());
}
#[test]
fn incoming_shells_move_exposed_squads_but_not_dug_in_squads() {
    for dug in [false, true] {
        let mut s = Scene::new(19);
        s.squads[0].morale = 70.0;
        let c = s.squads[0].centroid(s.now, &s.actors);
        s.squads[0].impacts = vec![
            Report {
                position: c,
                time: 99.0,
            },
            Report {
                position: c + Vector3::Z,
                time: 98.0,
            },
            Report {
                position: c,
                time: 60.0,
            },
        ];
        for id in 1..=6 {
            s.change(id, |m| m.motion.ground = if dug { -0.7 } else { 0.0 });
        }
        let (_, out) = s.context().squad_think(7, &profile()).unwrap();
        assert_eq!(out.contains(&Event::Stat("displace")), !dug);
        assert_eq!(s.squads[0].impacts.len(), 2);
    }
}
#[test]
fn contact_reaction_ignores_wounded_reports_and_assaults_a_close_ambush() {
    for wounded in [false, true] {
        let mut s = Scene::new(31);
        contact(&mut s, 18.0);
        s.squads[0].morale = 70.0;
        s.squads[0].order = "move".into();
        s.squads[0].order_position = Vector3::new(40.0, 0.0, 8.0);
        if wounded {
            let id = s.squads[0].known[0].id;
            s.change(id, |m| m.vitals.life = Life::Downed);
        }
        let (_, out) = s.context().squad_think(7, &profile()).unwrap();
        assert_eq!(out.contains(&Event::Stat("near_ambush_assault")), !wounded);
        if wounded {
            assert!(s.squads[0].drill.is_empty());
            assert_eq!(s.squads[0].order, "move");
        }
    }
}
#[test]
fn ammunition_transfer_uses_each_weapons_capacity_and_reloads_only_when_due() {
    let mut s = Scene::new(43);
    for id in 1..=6 {
        s.change(id, |m| {
            m.weapon.magazine = 30;
            m.weapon.reserve = 170;
        });
    }
    s.change(1, |m| {
        m.weapon.magazine = 0;
        m.weapon.reserve = 0;
        m.fight.out_of_ammo_said = true;
    });
    let out = s.context().squad_share_ammo(7, &profile()).unwrap();
    assert!(out.contains(&Event::Stat("ammo_shared")));
    let m = s.actors.soldier(1).unwrap();
    assert_eq!(m.weapon.reserve, 30);
    assert_eq!(m.weapon.reload_timer, 2.0);
    assert!(!m.fight.out_of_ammo_said);
    assert_eq!(s.actors.soldier(2).unwrap().weapon.reserve, 140);
    let rng = s.rng.state();
    assert!(s
        .context()
        .squad_share_ammo(7, &profile())
        .unwrap()
        .is_empty());
    assert_eq!(rng, s.rng.state());
}
#[test]
fn morale_keeps_cover_leadership_and_invalid_steps_do_not_mutate() {
    let mut s = Scene::new(47);
    contact(&mut s, 20.0);
    s.squads[0].morale = 50.0;
    for id in 1..=6 {
        s.change(id, |m| {
            m.vitals.suppression = 100.0;
            m.motion.ground = -0.7;
        });
    }
    s.context().squad_morale_tick(7, 0.5, &profile()).unwrap();
    assert_eq!(s.squads[0].morale, 50.0 - (1.4 * 0.5 + 0.15) * 0.5);
    let before = s.squads[0].checkpoint().unwrap();
    assert!(s
        .context()
        .squad_morale_tick(7, f64::NAN, &profile())
        .is_err());
    assert_eq!(before, s.squads[0].checkpoint().unwrap());
}
#[test]
fn busy_riflemen_do_not_mark_a_house_as_cleared() {
    let mut s = Scene::new(53);
    s.squads[0].order = "defend".into();
    s.squads[0].morale = 70.0;
    s.squads[0].order_position = Vector3::ZERO;
    s.squads[0].alert_time = 100.0;
    let house = s
        .geometry
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
    for id in 1..=6 {
        s.change(id, |m| m.orders.detached = true);
    }
    let (handled, _) = s.context().squad_think(7, &profile()).unwrap();
    assert!(!handled);
    assert!(!s.squads[0].cleared.iter().any(|v| v.0 == house));
    s.change(2, |m| m.orders.detached = false);
    s.now += 2.0;
    let (handled, out) = s.context().squad_think(7, &profile()).unwrap();
    assert!(handled);
    assert!(out.contains(&Event::Stat("clear_house")));
    assert_eq!(s.squads[0].breach_by, 2);
    assert!(s.actors.soldier(2).unwrap().entry.clear);
}
#[test]
fn saved_squad_decisions_continue_with_identical_routes_and_randomness() {
    let mut a = Scene::new(59);
    let mut b = Scene::new(59);
    for s in [&mut a, &mut b] {
        contact(s, 60.0);
        s.squads[0].morale = 25.0;
    }
    for step in 0..16 {
        a.now = 100.0 + step as f64 * 2.1;
        b.now = a.now;
        b.resume();
        assert_eq!(
            a.context().squad_think(7, &profile()).unwrap(),
            b.context().squad_think(7, &profile()).unwrap()
        );
        assert_eq!(
            a.actors.checkpoint().unwrap(),
            b.actors.checkpoint().unwrap()
        );
        assert_eq!(a.squads, b.squads);
        assert_eq!(a.geometry.checkpoint(), b.geometry.checkpoint());
        assert_eq!(a.rng.state(), b.rng.state());
    }
}
