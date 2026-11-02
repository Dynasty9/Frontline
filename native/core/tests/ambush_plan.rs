#[path = "fixtures/squad_brain_world.rs"]
#[allow(dead_code)]
mod fixture;
use fixture::{contact, Scene};
use frontline_core::ambush_plan::{AmbushPlan, Phase};
use frontline_core::infantry_vitals::Life;
use frontline_core::squad_brain::Event;
use frontline_core::vector::Vector3;
fn start(s: &mut Scene) -> AmbushPlan {
    AmbushPlan::make(
        &mut s.context(),
        19,
        7,
        Vector3::ZERO,
        Vector3::Z,
        Vector3::NEG_X,
    )
    .unwrap()
    .0
}
#[test]
fn road_ambush_occupies_waits_springs_and_withdraws() {
    for team in 0..=1 {
        let mut s = Scene::new(31);
        s.squads[0].team = team;
        for id in 1..=6 {
            s.change(id, |m| {
                m.identity.team = team;
                m.fight.smokes = 1;
            });
        }
        let mut p = start(&mut s);
        s.now += 1.;
        s.squads[0].centroid_at = -1.;
        for id in 1..=6 {
            s.change(id, |m| m.motion.position = p.rally);
        }
        assert!(p
            .tick(&mut s.context(), &|_| false)
            .unwrap()
            .contains(&Event::Stat("ambush_laid")));
        assert_eq!(p.phase, Phase::Wait);
        assert!(s.squads[0].ambush);
        contact(&mut s, 54.0);
        let enemy = s
            .actors
            .iter()
            .find_map(|a| {
                if let frontline_core::actors::Actor::Soldier(m) = a {
                    (m.identity.squad == 0).then_some(m.identity.id)
                } else {
                    None
                }
            })
            .unwrap();
        s.change(enemy, |m| {
            m.identity.team = 1 - team;
            m.motion.position = Vector3::ZERO;
        });
        s.actors.rebuild_units(&mut s.units).unwrap();
        s.now += 1.;
        p.tick(&mut s.context(), &|_| false).unwrap();
        assert_eq!(p.phase, Phase::Wait);
        s.now += 4.1;
        assert!(p
            .tick(&mut s.context(), &|_| false)
            .unwrap()
            .contains(&Event::Stat("ambush_sprung")));
        assert_eq!(p.caught, 1);
        s.now += 29.;
        assert!(p
            .tick(&mut s.context(), &|_| false)
            .unwrap()
            .contains(&Event::Stat("ambush_withdraw")));
        assert!(p.done);
        assert_eq!(s.squads[0].ambush_plan, 0);
        assert_eq!(
            s.squads[0].order,
            if team == 0 { "withdraw" } else { "move" }
        );
    }
}
#[test]
fn contact_on_approach_abandons_the_ambush() {
    let mut s = Scene::new(5);
    let mut p = start(&mut s);
    contact(&mut s, 20.0);
    assert_eq!(
        p.tick(&mut s.context(), &|_| false).unwrap(),
        vec![Event::Stat("ambush_abandoned")]
    );
    assert!(p.done);
    assert_eq!(s.squads[0].ambush_plan, 0);
}
#[test]
fn waiting_ignores_wounded_enemies_and_times_out() {
    let mut s = Scene::new(7);
    let mut p = start(&mut s);
    p.phase = Phase::Wait;
    contact(&mut s, 29.0);
    for id in 1..=6 {
        s.change(id, |m| m.motion.position = Vector3::NEG_X * 30.0);
    }
    let ids: Vec<_> = s
        .actors
        .iter()
        .filter_map(|a| match a {
            frontline_core::actors::Actor::Soldier(m) if m.identity.squad == 0 => {
                Some(m.identity.id)
            }
            _ => None,
        })
        .collect();
    for id in ids {
        s.change(id, |m| {
            m.vitals.life = Life::Downed;
            m.motion.position = Vector3::ZERO;
        });
    }
    s.actors.rebuild_units(&mut s.units).unwrap();
    s.now += 261.;
    assert_eq!(
        p.tick(&mut s.context(), &|_| false).unwrap(),
        vec![Event::Stat("ambush_abandoned")]
    );
}
#[test]
fn checkpoint_rejects_invalid_data_and_restores_every_phase() {
    let mut s = Scene::new(9);
    let mut p = start(&mut s);
    for phase in [Phase::Move, Phase::Wait, Phase::Spring] {
        p.phase = phase;
        p.caught = 3;
        p.quiet_time = 101.25;
        let bytes = p.checkpoint().unwrap();
        assert_eq!(p, AmbushPlan::restore(&bytes).unwrap());
        for end in 0..bytes.len() {
            assert!(AmbushPlan::restore(&bytes[..end]).is_err());
        }
        let mut extra = bytes;
        extra.push(0);
        assert!(AmbushPlan::restore(&extra).is_err());
    }
    p.gun_end = 0.;
    assert!(p.checkpoint().is_err());
    let random = s.rng.state();
    assert!(AmbushPlan::make(
        &mut s.context(),
        0,
        7,
        Vector3::ZERO,
        Vector3::Z,
        Vector3::X
    )
    .is_err());
    assert_eq!(random, s.rng.state());
}

#[test]
fn aircraft_above_the_road_are_ignored_but_landed_aircraft_spring_the_ambush() {
    let mut s = Scene::new(43);
    let mut p = start(&mut s);
    p.phase = Phase::Wait;
    let id = s
        .actors
        .spawn(frontline_core::actors::Actor::Vehicle(Box::new(
            frontline_core::vehicle::Vehicle {
                kind: "helicopter".into(),
                team: 1,
                position: Vector3::Y * 20.,
                ..Default::default()
            },
        )))
        .unwrap();
    s.actors.rebuild_units(&mut s.units).unwrap();
    p.tick(&mut s.context(), &|kind| kind == "helicopter")
        .unwrap();
    assert_eq!(p.phase, Phase::Wait);
    let mut entries: Vec<_> = s.actors.iter().cloned().collect();
    for a in &mut entries {
        if let frontline_core::actors::Actor::Vehicle(v) = a {
            if v.id == id {
                v.position.y = 0.;
            }
        }
    }
    s.actors = frontline_core::actors::Actors::from_entries(s.actors.entities().next_id(), entries)
        .unwrap();
    p.tick(&mut s.context(), &|kind| kind == "helicopter")
        .unwrap();
    assert_eq!(p.phase, Phase::Spring);
    assert_eq!(p.caught, 1);
}
