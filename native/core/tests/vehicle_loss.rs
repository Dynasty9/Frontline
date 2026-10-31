use frontline_core::actors::{Actor, Actors};
use frontline_core::infantry::{Credit, Infantry};
use frontline_core::infantry_spawn::Loadout;
use frontline_core::infantry_vitals::Life;
use frontline_core::path_planner::PathPlanner;
use frontline_core::random::SimulationRandom;
use frontline_core::spatial::{SpatialIndex, UNIT_CELL};
use frontline_core::vector::Vector3;
use frontline_core::vehicle::{LastBlast, Vehicle};
use frontline_core::vehicle_loss::Crew;

fn loadout() -> Loadout {
    Loadout {
        unit: "crewman".into(),
        weapon: "smg".into(),
        hp: 90.0,
        magazine: 30,
        ammunition: 120,
        grenades: 0,
        smokes: 1,
        rockets: 0,
        mortar_rounds: 0,
        drones: 0,
        bearer: false,
    }
}
fn crew() -> Crew<'static> {
    Crew {
        base: "tank",
        helicopter: false,
        automatic: false,
        count: None,
        cost: 500.0,
        armor_upgrade: false,
        grenade_upgrade: false,
    }
}
fn vehicle() -> Vehicle {
    Vehicle {
        id: 20,
        kind: "tank".into(),
        team: 0,
        owner: 7,
        hp: -20.0,
        max_hp: 100.0,
        position: Vector3::new(1.3, 0.0, -2.7),
        yaw: 0.37,
        ..Default::default()
    }
}
fn actors() -> Actors {
    Actors::from_entries(100, vec![Actor::Vehicle(Box::new(vehicle()))]).unwrap()
}

#[test]
fn each_survivors_name_delay_and_injury_precede_the_next_survival_roll() {
    let names = ["Taylor", "Jones", "Perez"].map(String::from);
    for seed in 0..64 {
        let mut rng = SimulationRandom::new(seed);
        let mut expected = rng;
        let mut men = vec![];
        for _ in 0..3 {
            if expected.randf() > 0.6 {
                continue;
            }
            let name = names[expected.randi() as usize % names.len()].clone();
            let delay = f64::from(expected.randf()) * 0.3;
            let hp = 90.0 * f64::from(expected.randf_range(0.35, 0.85));
            men.push((name, delay, hp));
        }
        let mut a = actors();
        let mut next = 7;
        let out = a
            .bail_out_vehicle(
                20,
                20.0,
                crew(),
                &loadout(),
                &names,
                &mut next,
                &PathPlanner::new(64).unwrap(),
                &mut rng,
            )
            .unwrap();
        assert!(out.attempted);
        assert_eq!(rng, expected);
        assert_eq!(next, 7 + u64::from(!men.is_empty()));
        assert_eq!(a.entities().next_id(), 100 + men.len() as u64);
        if let Some(q) = out.squad {
            assert_eq!(q.id, 7);
            assert_eq!(q.order_position, vehicle().position);
            assert_eq!(
                q.cooldowns[0].1,
                (500.0 * 0.12 * men.len() as f64 / 3.0).trunc()
            );
            for (i, (name, delay, hp)) in men.iter().enumerate() {
                let s = a.soldier(q.members[i]).unwrap();
                assert_eq!(&s.identity.name, name);
                assert_eq!(s.controller.think_timer, *delay);
                assert_eq!(s.vitals.hp, *hp);
                assert_eq!(s.vitals.speech_cooldown, if i == 0 { 2.6 } else { 0.0 });
            }
        } else {
            assert!(men.is_empty());
        }
    }
}

#[test]
fn helicopters_robots_and_supply_vehicles_never_create_crews_or_draw_randomness() {
    for base in [
        "supply",
        "uav",
        "ugv",
        "attack_heli",
        "lift_heli",
        "boat",
        "tank",
    ] {
        let mut a = actors();
        let mut c = crew();
        c.base = base;
        c.automatic = base == "tank";
        let mut rng = SimulationRandom::new(7);
        let before = rng;
        let mut next = 3;
        let out = a
            .bail_out_vehicle(
                20,
                20.0,
                c,
                &loadout(),
                &["Jones".into()],
                &mut next,
                &PathPlanner::new(32).unwrap(),
                &mut rng,
            )
            .unwrap();
        assert!(!out.attempted);
        assert_eq!(rng, before);
        assert_eq!(next, 3);
        assert_eq!(a.entities().len(), 1);
    }
}

#[test]
fn heavy_overkill_and_explicit_crew_counts_survive_checkpoint_continuation() {
    for count in [0, 1, 5] {
        let mut a = actors();
        let mut b = Actors::restore(&a.checkpoint().unwrap()).unwrap();
        let mut c = crew();
        c.count = Some(count);
        c.armor_upgrade = true;
        let mut rng = SimulationRandom::new(77);
        let mut copy = rng;
        let mut next = 3;
        let mut resumed = next;
        for overkill in [35.0, 35.00001, 999.0] {
            let first = a
                .bail_out_vehicle(
                    20,
                    overkill,
                    c,
                    &loadout(),
                    &["Jones".into()],
                    &mut next,
                    &PathPlanner::new(32).unwrap(),
                    &mut rng,
                )
                .unwrap();
            let second = b
                .bail_out_vehicle(
                    20,
                    overkill,
                    c,
                    &loadout(),
                    &["Jones".into()],
                    &mut resumed,
                    &PathPlanner::new(32).unwrap(),
                    &mut copy,
                )
                .unwrap();
            assert_eq!(first, second);
            assert_eq!(a.checkpoint().unwrap(), b.checkpoint().unwrap());
            assert_eq!(rng, copy);
        }
    }
}

#[test]
fn failed_bailouts_keep_all_actor_and_random_cursors() {
    let mut a = actors();
    let mut next = u32::MAX as u64 + 1;
    let mut rng = SimulationRandom::new(7);
    let before = a.checkpoint().unwrap();
    let random = rng;
    assert!(a
        .bail_out_vehicle(
            20,
            20.0,
            crew(),
            &loadout(),
            &["Jones".into()],
            &mut next,
            &PathPlanner::new(32).unwrap(),
            &mut rng
        )
        .is_err());
    assert_eq!(a.checkpoint().unwrap(), before);
    assert_eq!(rng, random);
    assert_eq!(next, u32::MAX as u64 + 1);
    next = 7;
    let mut no_crew = crew();
    no_crew.count = Some(0);
    assert!(a
        .bail_out_vehicle(
            20,
            20.0,
            no_crew,
            &loadout(),
            &[],
            &mut next,
            &PathPlanner::new(32).unwrap(),
            &mut rng
        )
        .is_err());
    assert_eq!(a.checkpoint().unwrap(), before);
    assert_eq!(rng, random);
    assert_eq!(next, 7);
}

fn loaded() -> Actors {
    let mut v = vehicle();
    v.passengers = vec![1, 999, 2, 3];
    v.hit_by = Some(Credit {
        owner: 8,
        team: 1,
        unit: "v9".into(),
        soldier: 0,
    });
    let mut entries = vec![Actor::Vehicle(Box::new(v))];
    for id in 1..=4 {
        let mut s = Infantry::default();
        s.identity.id = id;
        s.identity.unit = "rifleman".into();
        s.vitals.life = if id == 3 {
            Life::Dead
        } else if id == 4 {
            Life::Alive
        } else {
            Life::Hidden
        };
        s.links.vehicle = if id < 4 { 20 } else { 0 };
        s.motion.position = Vector3::new(id as f32, 0.0, 0.0);
        entries.push(Actor::Soldier(Box::new(s)));
    }
    Actors::from_entries(100, entries).unwrap()
}

#[test]
fn evacuation_skips_missing_and_nonhidden_passengers_and_preserves_blame_scope() {
    let surrounding = Credit {
        owner: 11,
        team: 1,
        unit: "s5".into(),
        soldier: 9,
    };
    for boat in [false, true] {
        let mut a = loaded();
        let saved = a.checkpoint().unwrap();
        let mut rng = SimulationRandom::new(7);
        let random = rng;
        assert!(a
            .evacuate_destroyed_vehicle(
                20,
                boat,
                10.0,
                Some(&surrounding),
                &PathPlanner::new(128).unwrap(),
                &SpatialIndex::new(2.0).unwrap(),
                &mut [],
                |_| (Some(120), false),
                &mut rng
            )
            .is_err());
        assert_eq!(a.checkpoint().unwrap(), saved);
        assert_eq!(rng, random);
        let mut units = SpatialIndex::new(UNIT_CELL).unwrap();
        a.rebuild_units(&mut units).unwrap();
        let out = a
            .evacuate_destroyed_vehicle(
                20,
                boat,
                10.0,
                Some(&surrounding),
                &PathPlanner::new(128).unwrap(),
                &units,
                &mut [],
                |_| (Some(120), false),
                &mut SimulationRandom::new(7),
            )
            .unwrap();
        assert_eq!(out.iter().map(|h| h.soldier).collect::<Vec<_>>(), [1, 2]);
        assert!(a.vehicle(20).unwrap().passengers.is_empty());
        for id in [1, 2] {
            let s = a.soldier(id).unwrap();
            assert_eq!(s.links.vehicle, 0);
            assert_ne!(s.vitals.life, Life::Hidden);
            assert_eq!(
                s.identity.hit_by.as_ref().unwrap().owner,
                if boat { 11 } else { 8 }
            );
        }
        assert_eq!(a.soldier(3).unwrap().links.vehicle, 20);
        assert_eq!(a.soldier(4).unwrap().vitals.suppression > 0.0, !boat);
    }
}

#[test]
fn distant_shore_kills_swimmers_without_a_survival_damage_draw() {
    let mut a = loaded();
    let mut vehicle = a.remove(20).unwrap();
    let Actor::Vehicle(v) = &mut vehicle else {
        unreachable!()
    };
    v.position.x = 300.0;
    let mut entries: Vec<_> = a.iter().cloned().collect();
    entries.push(vehicle);
    let mut a = Actors::from_entries(100, entries).unwrap();
    let mut nav = PathPlanner::new(256).unwrap();
    let blocked = vec![3; 256 * 256];
    assert!(nav.load_cells(&blocked, &blocked, &vec![0; blocked.len()]));
    assert!(
        (nav.nearest_walkable(a.vehicle(20).unwrap().position)
            .unwrap()
            - a.vehicle(20).unwrap().position)
            .length()
            >= 60.0
    );
    let units = SpatialIndex::new(UNIT_CELL).unwrap();
    let mut rng = SimulationRandom::new(7);
    let mut expected = rng;
    for _ in 0..6 {
        expected.randf();
    }
    let out = a
        .evacuate_destroyed_vehicle(
            20,
            true,
            10.0,
            None,
            &nav,
            &units,
            &mut [],
            |_| (Some(120), false),
            &mut rng,
        )
        .unwrap();
    assert_eq!(out.len(), 2);
    assert_eq!(rng, expected);
    for id in [1, 2] {
        assert_eq!(a.soldier(id).unwrap().vitals.life, Life::Dead);
    }
}

#[test]
fn stale_blasts_only_draw_resting_tilt_and_wrecks_stay_inside_the_map() {
    let mut v = vehicle();
    v.last_blast = Some(LastBlast {
        position: Vector3::ZERO,
        size: 5.0,
        time: 10.0,
    });
    let nav = PathPlanner::new(64).unwrap();
    let mut rng = SimulationRandom::new(7);
    let mut expected = rng;
    let tilt = [
        expected.randf_range(-0.03, 0.03),
        expected.randf_range(-0.04, 0.04),
    ];
    let p = v.wreck_plan(0, 10.60001, &nav, &mut rng).unwrap();
    assert_eq!(p.tilt, tilt);
    assert_eq!(p.velocity, Vector3::ZERO);
    assert_eq!(rng, expected);
    v.position = Vector3::new(27.9, 3.0, 0.0);
    v.last_blast.as_mut().unwrap().position = Vector3::new(26.0, 0.0, 0.0);
    let p = v.wreck_plan(0, 10.0, &nav, &mut rng).unwrap();
    assert_eq!(p.position, Vector3::new(27.9, 0.0, 0.0));
    assert!(p.velocity.length() > 0.3);
}
