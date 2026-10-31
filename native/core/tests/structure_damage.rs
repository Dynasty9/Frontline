use frontline_core::actors::{Actor, Actors};
use frontline_core::deferred_effects::DeferredEffects;
use frontline_core::infantry::{Credit, Infantry};
use frontline_core::infantry_controller::Task;
use frontline_core::infantry_vitals::Life;
use frontline_core::path_planner::PathPlanner;
use frontline_core::random::SimulationRandom;
use frontline_core::structure::Structure;
use frontline_core::structure_damage::{Damage, Event};
use frontline_core::vector::Vector3;

fn actors(kind: &str) -> Actors {
    Actors::from_entries(
        100,
        vec![Actor::Structure(Box::new(Structure {
            id: 20,
            team: 0,
            kind: kind.into(),
            size: Vector3::new(6.0, 3.0, 4.0),
            ..Default::default()
        }))],
    )
    .unwrap()
}
fn hit(
    a: &mut Actors,
    amount: f64,
    time: f64,
    q: &mut DeferredEffects,
    rng: &mut SimulationRandom,
) -> Damage {
    a.damage_structure(
        20,
        amount,
        0,
        None,
        time,
        true,
        Some(55.0),
        &PathPlanner::new(32).unwrap(),
        q,
        rng,
    )
    .unwrap()
}

#[test]
fn wrecked_fobs_stay_registered_and_ignore_later_hits() {
    let mut a = actors("fob");
    let mut q = DeferredEffects::default();
    let mut rng = SimulationRandom::new(7);
    let out = hit(&mut a, 200.0, 10.0, &mut q, &mut rng);
    assert_eq!(
        out.events,
        [Event::UnderAttack, Event::BuildingLost, Event::FobWrecked]
    );
    assert!(out.removed.is_none());
    assert!(a.structure(20).unwrap().wrecked);
    let bytes = a.checkpoint().unwrap();
    assert!(!hit(&mut a, 200.0, 50.0, &mut q, &mut rng).applied);
    assert_eq!(a.checkpoint().unwrap(), bytes);
}

#[test]
fn doors_and_alerts_keep_their_thresholds_and_line_works_stay_quiet() {
    for kind in ["barracks", "concrete_wall"] {
        let mut a = Actors::from_entries(
            100,
            vec![Actor::Structure(Box::new(Structure {
                id: 20,
                kind: kind.into(),
                team: 0,
                hp: 1000.0,
                max_hp: 1000.0,
                door_closed: true,
                ..Default::default()
            }))],
        )
        .unwrap();
        let mut q = DeferredEffects::default();
        let mut rng = SimulationRandom::new(7);
        assert!(hit(&mut a, 5.0, 0.0, &mut q, &mut rng).events.is_empty());
        let first = hit(&mut a, 19.9, 10.0, &mut q, &mut rng);
        assert_eq!(
            first.events,
            if kind == "barracks" {
                vec![Event::UnderAttack]
            } else {
                vec![]
            }
        );
        assert_eq!(
            hit(&mut a, 20.0, 11.0, &mut q, &mut rng).events,
            [Event::Door]
        );
        assert!(!a.structure(20).unwrap().door_closed);
        assert!(hit(&mut a, 20.0, 35.0, &mut q, &mut rng).events.is_empty());
    }
}

#[test]
fn destroyed_tunnels_release_only_existing_occupants_in_stored_order() {
    let mut a = actors("tunnel");
    let mut men = vec![];
    for i in 0..2 {
        let mut s = Infantry::default();
        s.identity.unit = "rifleman".into();
        s.vitals.life = if i == 0 { Life::Hidden } else { Life::Alive };
        s.links.hidden_in = 20;
        men.push(a.spawn(Actor::Soldier(Box::new(s))).unwrap());
    }
    let mut st = a.remove(20).unwrap();
    let Actor::Structure(ref mut s) = st else {
        unreachable!()
    };
    s.inside = vec![men[1], 999, men[0]];
    let mut entries: Vec<_> = a.iter().cloned().collect();
    entries.push(st);
    let mut a = Actors::from_entries(200, entries).unwrap();
    let out = hit(
        &mut a,
        500.0,
        10.0,
        &mut DeferredEffects::default(),
        &mut SimulationRandom::new(7),
    );
    assert_eq!(
        &out.events[2..4],
        &[Event::Unhidden(men[1]), Event::Unhidden(men[0])]
    );
    assert!(out.removed.unwrap().inside.is_empty());
    for id in men {
        let s = a.soldier(id).unwrap();
        assert_eq!(s.vitals.life, Life::Alive);
        assert_eq!(s.links.hidden_in, 0);
        assert_eq!(s.motion.position.y, 0.0);
    }
}

#[test]
fn destroyed_towers_release_the_gun_and_lower_the_gunner() {
    let mut gunner = Infantry::default();
    gunner.identity.id = 1;
    gunner.identity.unit = "rifleman".into();
    gunner.identity.mounted_weapon = "mg".into();
    gunner.emplacement.structure = 20;
    gunner.emplacement.target = 3;
    gunner.emplacement.mortar_aim = Some(Vector3::Z);
    gunner.orders.base_y = 4.0;
    gunner.motion.position.y = 4.0;
    gunner.duty.kind = Task::Man;
    gunner.duty.entity = 20;
    let mut a = Actors::from_entries(
        100,
        vec![
            Actor::Soldier(Box::new(gunner)),
            Actor::Structure(Box::new(Structure {
                id: 20,
                kind: "watchtower".into(),
                gunner: 1,
                ..Default::default()
            })),
        ],
    )
    .unwrap();
    let out = hit(
        &mut a,
        500.0,
        10.0,
        &mut DeferredEffects::default(),
        &mut SimulationRandom::new(7),
    );
    assert!(out.events.contains(&Event::ReleasedGunner(1)));
    let s = a.soldier(1).unwrap();
    assert_eq!(s.duty.kind, Task::Fight);
    assert_eq!(s.emplacement.structure, 0);
    assert_eq!(s.emplacement.target, 0);
    assert_eq!(s.emplacement.mortar_aim, None);
    assert_eq!(s.motion.position, Vector3::new(2.0, 0.0, 0.0));
}

#[test]
fn cache_cookoffs_and_rubble_survive_a_checkpoint_without_early_damage() {
    let mut q = DeferredEffects::default();
    let mut rng = SimulationRandom::new(7);
    let mut a = actors("ammo_cache");
    let out = hit(&mut a, 500.0, 10.0, &mut q, &mut rng);
    assert!(out.events.contains(&Event::CacheCookOff(5)));
    assert!(a.structure(20).is_none());
    assert!(q.advance_to(10.0).unwrap().is_empty());
    let mut restored = DeferredEffects::restore(&q.checkpoint()).unwrap();
    assert_eq!(
        q.advance_to(100.0).unwrap(),
        restored.advance_to(100.0).unwrap()
    );
    for quiet in [false, true] {
        let mut a = actors("house_wall");
        let out = a
            .destroy_structure(
                20,
                quiet,
                101.0,
                false,
                &PathPlanner::new(32).unwrap(),
                &mut q,
                &mut rng,
            )
            .unwrap();
        assert_eq!(out.events.contains(&Event::Rubble), !quiet);
        assert_eq!(q.take_rubble().len(), usize::from(!quiet));
    }
}

#[test]
fn holed_cars_draw_fuel_only_when_they_catch_and_keep_it_through_resume() {
    let mut ignited = 0;
    for seed in 0..64 {
        let mut a = actors("car");
        let mut rng = SimulationRandom::new(seed);
        let out = hit(
            &mut a,
            60.0,
            10.0,
            &mut DeferredEffects::default(),
            &mut rng,
        );
        let car = a.structure(20).unwrap();
        if out.events.contains(&Event::IgnitedCar) {
            ignited += 1;
            assert_eq!(car.burn, 0.3);
            assert!((44.0..=66.0).contains(&car.fuel));
            assert_eq!(car.fuel, car.fuel_max);
            assert_eq!(car.fire_kind, "car");
        }
        let restored = Actors::restore(&a.checkpoint().unwrap()).unwrap();
        assert_eq!(a.checkpoint().unwrap(), restored.checkpoint().unwrap());
    }
    assert!(ignited > 0 && ignited < 64);
}

#[test]
fn structure_credit_keeps_the_last_enemy_and_invalid_damage_is_rejected() {
    let mut a = actors("barracks");
    let credit = Credit {
        owner: 7,
        team: 1,
        unit: "v9".into(),
        soldier: 0,
    };
    let mut rng = SimulationRandom::new(7);
    let mut q = DeferredEffects::default();
    let nav = PathPlanner::new(32).unwrap();
    a.damage_structure(
        20,
        1.0,
        999,
        Some(&credit),
        1.0,
        true,
        None,
        &nav,
        &mut q,
        &mut rng,
    )
    .unwrap();
    assert_eq!(a.structure(20).unwrap().hit_by, Some(credit.clone()));
    a.damage_structure(20, 1.0, 20, None, 1.0, true, None, &nav, &mut q, &mut rng)
        .unwrap();
    assert_eq!(a.structure(20).unwrap().hit_by, Some(credit));
    let before = a.checkpoint().unwrap();
    let cursor = rng.state();
    assert!(a
        .damage_structure(
            20,
            f64::NAN,
            0,
            None,
            1.0,
            true,
            None,
            &nav,
            &mut q,
            &mut rng
        )
        .is_err());
    assert_eq!(a.checkpoint().unwrap(), before);
    assert_eq!(rng.state(), cursor);
}
