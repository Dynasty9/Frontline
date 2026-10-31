use frontline_core::actors::{Actor, Actors};
use frontline_core::infantry::Infantry;
use frontline_core::infantry_controller::Task;
use frontline_core::infantry_logistics::SupplySource;
use frontline_core::infantry_vitals::Life;
use frontline_core::infantry_weapon::Weapon;
use frontline_core::path_planner::PathPlanner;
use frontline_core::random::SimulationRandom;
use frontline_core::spatial::{SpatialIndex, STRUCTURE_CELL, UNIT_CELL};
use frontline_core::structure::Structure;
use frontline_core::vector::Vector3;

fn soldier(id: u32, position: Vector3) -> Infantry {
    let mut s = Infantry::default();
    s.identity.id = id;
    s.identity.unit = "rifleman".into();
    s.identity.weapon = "rifle".into();
    s.motion.position = position;
    s.weapon.low_ammo_said = true;
    s.fight.out_of_ammo_said = true;
    s
}
fn body(id: u32, position: Vector3, loot: i32) -> Actor {
    let mut s = soldier(id, position);
    s.vitals.life = Life::Dead;
    s.fight.loot = loot;
    Actor::Soldier(Box::new(s))
}
fn scene(entries: Vec<Actor>) -> (Actors, SpatialIndex, SpatialIndex) {
    let a = Actors::from_entries(100, entries).unwrap();
    let mut units = SpatialIndex::new(UNIT_CELL).unwrap();
    a.rebuild_units(&mut units).unwrap();
    let mut structures = SpatialIndex::new(STRUCTURE_CELL).unwrap();
    for e in a.iter() {
        if let Actor::Structure(st) = e {
            structures.insert(st.id, st.position, st.radius).unwrap();
        }
    }
    (a, units, structures)
}
fn stock() -> Option<(i32, Weapon)> {
    Some((
        120,
        Weapon {
            ammunition: 120,
            magazine: 30,
            reload_time: 2.0,
        },
    ))
}
fn depot(id: u32, kind: &str, x: f32) -> Actor {
    Actor::Structure(Box::new(Structure {
        id,
        kind: kind.into(),
        position: Vector3::X * x,
        team: 0,
        built: true,
        radius: 2.0,
        ..Default::default()
    }))
}

#[test]
fn scavenging_uses_bucket_order_and_updates_both_stocks_before_reload() {
    let s = soldier(1, Vector3::new(0.1, 0.0, 0.1));
    let (mut a, units, _) = scene(vec![
        Actor::Soldier(Box::new(s)),
        body(2, Vector3::new(0.2, 0.0, 0.1), 100),
        body(3, Vector3::NEG_X * 2.0, 30),
    ]);
    let result = a
        .scavenge_infantry(1, 10.0, stock(), &units, &mut SimulationRandom::new(137))
        .unwrap()
        .unwrap();
    assert_eq!((result.body, result.rounds), (3, 30));
    assert_eq!(a.soldier(3).unwrap().fight.loot, 0);
    assert_eq!(a.soldier(2).unwrap().fight.loot, 100);
    let s = a.soldier(1).unwrap();
    assert_eq!(s.weapon.reserve, 30);
    assert_eq!(s.weapon.reload_timer, 2.0);
    assert!(!s.weapon.low_ammo_said && !s.fight.out_of_ammo_said);
    assert_eq!(s.supply.scavenge_at, 11.5);
}

#[test]
fn muted_scavenging_speech_preserves_the_random_cursor_and_checkpoint_resume() {
    for seed in 0..128 {
        let (mut loud, units, _) = scene(vec![
            Actor::Soldier(Box::new(soldier(1, Vector3::ZERO))),
            body(2, Vector3::X, 100),
        ]);
        let mut s = soldier(1, Vector3::ZERO);
        s.vitals.speech_cooldown = 8.0;
        let (mut muted, _, _) = scene(vec![Actor::Soldier(Box::new(s)), body(2, Vector3::X, 100)]);
        let mut a = SimulationRandom::new(seed);
        let mut b = a;
        loud.scavenge_infantry(1, 10.0, stock(), &units, &mut a)
            .unwrap();
        let result = muted
            .scavenge_infantry(1, 10.0, stock(), &units, &mut b)
            .unwrap()
            .unwrap();
        assert!(result.speech.is_none() && result.reload_speech.is_none());
        assert_eq!(a, b);
        let saved = muted.checkpoint().unwrap();
        let mut restored = Actors::restore(&saved).unwrap();
        let mut random = b;
        assert_eq!(
            muted
                .scavenge_infantry(1, 10.1, stock(), &units, &mut b)
                .unwrap(),
            restored
                .scavenge_infantry(1, 10.1, stock(), &units, &mut random)
                .unwrap()
        );
        assert_eq!(muted.checkpoint().unwrap(), restored.checkpoint().unwrap());
        assert_eq!(b, random);
    }
}

#[test]
fn bodies_precede_depots_with_strict_range_and_resupply_replaces_retreat_care() {
    let mut s = soldier(1, Vector3::ZERO);
    s.duty.kind = Task::Retreat;
    let (mut a, units, structures) = scene(vec![
        Actor::Soldier(Box::new(s)),
        body(2, Vector3::X * 25.0, 100),
        body(3, Vector3::X * 24.0, 100),
        depot(8, "fob", 1.0),
    ]);
    let mut rng = SimulationRandom::new(137);
    let random = rng;
    let order = a
        .seek_infantry_supply(1, 10.0, &units, &structures, &mut rng)
        .unwrap()
        .unwrap();
    assert_eq!((order.source, order.entity), (SupplySource::Body, 3));
    assert_eq!(order.route.job.care, 0.0);
    assert_eq!(a.soldier(1).unwrap().duty.kind, Task::Resupply);
    assert_eq!(rng, random);
    assert_eq!(a.soldier(1).unwrap().supply.search_at, 16.0);
}

#[test]
fn wrecked_fob_penalty_and_cache_distance_preserve_destination_priority() {
    for cache in [false, true] {
        let mut wreck = match depot(8, "fob", 10.0) {
            Actor::Structure(s) => s,
            _ => unreachable!(),
        };
        wreck.wrecked = true;
        let mut entries = vec![
            Actor::Soldier(Box::new(soldier(1, Vector3::ZERO))),
            Actor::Structure(wreck),
            depot(9, "fob", 60.0),
        ];
        if cache {
            entries.push(depot(10, "ammo_cache", 30.0));
        }
        let (mut a, units, structures) = scene(entries);
        let mut rng = SimulationRandom::new(137);
        let order = a
            .seek_infantry_supply(1, 10.0, &units, &structures, &mut rng)
            .unwrap()
            .unwrap();
        assert_eq!(
            (order.entity, order.source),
            if cache {
                (10, SupplySource::Cache)
            } else {
                (9, SupplySource::Fob)
            }
        );
        assert_eq!(a.soldier(1).unwrap().vitals.speech_cooldown, 2.6);
    }
}

#[test]
fn unavailable_stock_still_schedules_searches_but_rejected_routes_are_atomic() {
    let (mut a, units, structures) =
        scene(vec![Actor::Soldier(Box::new(soldier(1, Vector3::ZERO)))]);
    let mut rng = SimulationRandom::new(137);
    assert!(a
        .scavenge_infantry(1, 10.0, stock(), &units, &mut rng)
        .unwrap()
        .is_none());
    assert!(a
        .seek_infantry_supply(1, 10.0, &units, &structures, &mut rng)
        .unwrap()
        .is_none());
    assert_eq!(a.soldier(1).unwrap().supply.scavenge_at, 11.5);
    assert_eq!(a.soldier(1).unwrap().supply.search_at, 16.0);
    let mut s = soldier(1, Vector3::ZERO);
    s.orders.path_revision = i64::MAX as u64;
    s.duty.kind = Task::Retreat;
    let (mut a, units, structures) =
        scene(vec![Actor::Soldier(Box::new(s)), depot(8, "fob", 10.0)]);
    let before = a.checkpoint().unwrap();
    let random = rng;
    assert!(a
        .seek_infantry_supply(1, 10.0, &units, &structures, &mut rng)
        .is_err());
    assert_eq!(a.checkpoint().unwrap(), before);
    assert_eq!(rng, random);
}

#[test]
fn collecting_shared_ammunition_returns_to_hold_without_reloading_or_resetting_warnings() {
    let mut s = soldier(1, Vector3::ZERO);
    s.duty.kind = Task::Resupply;
    s.duty.entity = 2;
    s.orders.hold_position = Vector3::X * 20.0;
    s.activity = 2;
    let (mut a, _, _) = scene(vec![Actor::Soldier(Box::new(s)), body(2, Vector3::X, 50)]);
    let result = a
        .arrive_infantry_supply(1, 120, &PathPlanner::new(64).unwrap())
        .unwrap();
    assert!(result.spoke && result.returned && !result.missing);
    assert_eq!(result.rounds, 50);
    assert_eq!(result.route.unwrap().job.destination, Vector3::X * 20.0);
    let s = a.soldier(1).unwrap();
    assert_eq!(
        (s.weapon.reserve, s.weapon.reload_timer, s.activity),
        (50, 0.0, 0)
    );
    assert!(s.weapon.low_ammo_said && s.fight.out_of_ammo_said);
    assert_eq!(s.duty.kind, Task::Fight);
    assert_eq!(a.soldier(2).unwrap().fight.loot, 0);
}

#[test]
fn a_missing_depot_cancels_only_the_duty_and_failed_collection_keeps_both_stocks() {
    let nav = PathPlanner::new(64).unwrap();
    let mut s = soldier(1, Vector3::ZERO);
    s.duty.kind = Task::Resupply;
    s.duty.entity = 8;
    s.activity = 2;
    let (mut a, _, _) = scene(vec![Actor::Soldier(Box::new(s.clone()))]);
    assert!(a.arrive_infantry_supply(1, 120, &nav).unwrap().missing);
    assert_eq!(a.soldier(1).unwrap().duty.entity, 8);
    assert_eq!(a.soldier(1).unwrap().activity, 2);
    s.duty.entity = 2;
    s.orders.path_revision = i64::MAX as u64;
    let (mut a, _, _) = scene(vec![Actor::Soldier(Box::new(s)), body(2, Vector3::X, 50)]);
    let before = a.checkpoint().unwrap();
    assert!(a.arrive_infantry_supply(1, 120, &nav).is_err());
    assert_eq!(a.checkpoint().unwrap(), before);
}
