use frontline_core::actors::Actor;
use frontline_core::fires::{Event, Fires};
use frontline_core::infantry_vitals::Life;
use frontline_core::vector::Vector3;
#[path = "fixtures/fires_world.rs"]
mod fires_world;
use fires_world::*;

#[test]
fn burning_wall_removal_opens_a_later_victims_escape_in_the_same_tick() {
    let tree = structure(10, "tree", 0.0);
    let mut wall = structure(11, "medic_tent", 10.0);
    wall.hp = 0.01;
    let mut w = Battle::new(vec![
        Actor::Soldier(Box::new(soldier(1, 3.0, Life::Alive))),
        actor(tree),
        actor(wall),
    ]);
    let mut fires = Fires::new(32, false).unwrap();
    let mut events = vec![];
    for id in [10, 11] {
        assert!(fires
            .ignite(id, 1.0, &mut w.context(), &mut events)
            .unwrap());
    }
    w.now = 0.25;
    let events = fires.tick(0.25, &mut w.context()).unwrap();
    assert!(matches!(events[0], Event::BurnedDown { structure: 11, .. }));
    assert!(w.actors.structure(11).is_none());
    assert_eq!(w.geometry.pending_removals(), [11]);
    let s = w.actors.soldier(1).unwrap();
    assert_eq!(s.orders.goal, Vector3::X * 10.0);
    assert_eq!(s.motion.path, [Vector3::X * 10.0]);
    assert!(!s.orders.pending_path && s.vitals.hp < 100.0);
    assert_eq!(fires.burning().len(), 1);
}

#[test]
fn charred_trees_stand_but_no_longer_stamp_heat_or_reignite() {
    let mut tree = structure(10, "tree", 0.0);
    tree.fire_kind = "tree".into();
    tree.burn = 0.9;
    tree.fuel = 0.01;
    tree.fuel_max = 80.0;
    let mut w = Battle::new(vec![actor(tree)]);
    let mut fires = Fires::new(32, false).unwrap();
    fires
        .track_ignition(10, &mut w.context(), &mut vec![])
        .unwrap();
    assert!(fires.hot_at(Vector3::ZERO));
    let events = fires.tick(0.25, &mut w.context()).unwrap();
    assert!(events.iter().any(|e| matches!(
        e,
        Event::Charred {
            structure: 10,
            variant: 16
        }
    )));
    assert!(w.actors.structure(10).unwrap().burnt);
    assert!(fires.burning().is_empty());
    assert!(!fires.hot_at(Vector3::ZERO));
    assert!(w.geometry.pending_removals().is_empty());
    assert!(!fires
        .ignite(10, 1.0, &mut w.context(), &mut vec![])
        .unwrap());
}

#[test]
fn replay_resume_keeps_spread_casualties_heat_smoke_and_geometry_identical() {
    let mut entries = vec![];
    for (i, kind) in [
        "tree",
        "medic_tent",
        "crates",
        "watchtower",
        "car",
        "barracks",
    ]
    .into_iter()
    .enumerate()
    {
        entries.push(actor(structure(10 + i as u32, kind, i as f32 * 1.7 - 4.0)));
    }
    for (i, life) in [Life::Alive, Life::Downed, Life::Hidden, Life::Surrender]
        .into_iter()
        .enumerate()
    {
        entries.push(Actor::Soldier(Box::new(soldier(
            1 + i as u32,
            i as f32 - 1.0,
            life,
        ))));
    }
    let mut a = Battle::new(entries);
    let mut fires = Fires::new(32, false).unwrap();
    fires
        .ignite(10, 0.8, &mut a.context(), &mut vec![])
        .unwrap();
    fires
        .start_patch(
            Vector3::new(3.0, 5.0, 1.0),
            2.7,
            20.0,
            0,
            &mut a.geometry,
            &mut vec![],
        )
        .unwrap();
    fires.tick(0.1, &mut a.context()).unwrap();
    let mut b = a.resume();
    let mut resumed = Fires::restore(&fires.checkpoint()).unwrap();
    let mut saw_casualty = false;
    for tick in 0..160 {
        a.now = tick as f64 * 0.27;
        b.now = a.now;
        let expected = fires.tick(0.27, &mut a.context()).unwrap();
        assert_eq!(expected, resumed.tick(0.27, &mut b.context()).unwrap());
        saw_casualty |= expected.iter().any(|e| matches!(e, Event::Scorched { hit, .. } if matches!(hit.result, frontline_core::infantry_vitals::DamageResult::Down | frontline_core::infantry_vitals::DamageResult::Die)));
        assert_eq!(fires.checkpoint(), resumed.checkpoint());
        a.compare(&b);
        a.geometry.finish_tick();
        b.geometry.finish_tick();
        if tick % 11 == 0 {
            b = b.resume();
            resumed = Fires::restore(&resumed.checkpoint()).unwrap();
        }
    }
    assert!(saw_casualty);
    assert_eq!(a.actors.soldier(3).unwrap().vitals.life, Life::Hidden);
}

#[test]
fn grass_smoke_expires_with_its_heat_and_rain_prevents_blast_grass_ignition() {
    let mut w = Battle::new(vec![]);
    let mut fires = Fires::new(32, false).unwrap();
    fires
        .start_patch(
            Vector3::new(0.0, 4.0, 0.0),
            2.0,
            0.3,
            0,
            &mut w.geometry,
            &mut vec![],
        )
        .unwrap();
    assert!(fires.hot_at(Vector3::ZERO));
    fires.tick(0.25, &mut w.context()).unwrap();
    assert_eq!(fires.smokes().len(), 1);
    assert_eq!(fires.patches()[0].position.y, 0.0);
    fires.tick(0.25, &mut w.context()).unwrap();
    assert!(fires.smokes().is_empty() && fires.patches().is_empty());
    assert!(fires.hot().iter().all(|&heat| heat == 0));
    fires.wet = true;
    for _ in 0..100 {
        assert!(fires
            .blast(Vector3::ZERO, 3.0, 10.0, &mut w.context())
            .unwrap()
            .is_empty());
    }
    assert!(fires.patches().is_empty());
}

#[test]
fn rejected_fire_inputs_preserve_state_and_random_draws() {
    let mut w = Battle::new(vec![actor(structure(10, "tree", 0.0))]);
    let mut fires = Fires::new(32, false).unwrap();
    let state = fires.checkpoint();
    let prior = w.resume();
    assert!(fires
        .ignite(10, f64::NAN, &mut w.context(), &mut vec![])
        .is_err());
    assert!(fires.tick(-0.1, &mut w.context()).is_err());
    assert!(fires
        .blast(Vector3::ZERO, 3.0, 0.0, &mut w.context())
        .is_err());
    assert!(fires
        .start_patch(Vector3::NAN, 2.0, 20.0, 0, &mut w.geometry, &mut vec![])
        .is_err());
    assert_eq!(state, fires.checkpoint());
    w.compare(&prior);
    for end in 0..state.len() {
        assert!(Fires::restore(&state[..end]).is_err());
    }
    let mut bad = state;
    bad.push(0);
    assert!(Fires::restore(&bad).is_err());
}
