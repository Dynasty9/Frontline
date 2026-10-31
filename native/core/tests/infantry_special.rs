use frontline_core::actors::{Actor, Actors};
use frontline_core::collision::CollisionWorld;
use frontline_core::infantry::Infantry;
use frontline_core::infantry_action::{Action, Round};
use frontline_core::random::SimulationRandom;
use frontline_core::spatial::{SpatialIndex, UNIT_CELL};
use frontline_core::squad::{Contact, Report, Squad};
use frontline_core::terrain::Terrain;
use frontline_core::vector::Vector3;
use frontline_core::vehicle::Vehicle;
use frontline_core::visibility::Visibility;

fn soldier(id: u32, x: f32, team: i8) -> Infantry {
    let mut s = Infantry::default();
    s.identity.id = id;
    s.identity.unit = "rifleman".into();
    s.identity.team = team;
    s.identity.squad = 9;
    s.motion.position.x = x;
    s
}
fn field(soldiers: Vec<Infantry>, vehicles: Vec<Vehicle>) -> (Actors, SpatialIndex) {
    let entries = soldiers
        .into_iter()
        .map(|s| Actor::Soldier(Box::new(s)))
        .chain(vehicles.into_iter().map(|v| Actor::Vehicle(Box::new(v))))
        .collect();
    let actors = Actors::from_entries(100, entries).unwrap();
    let mut units = SpatialIndex::new(UNIT_CELL).unwrap();
    actors.rebuild_units(&mut units).unwrap();
    (actors, units)
}
fn vehicle(id: u32, x: f32) -> Vehicle {
    Vehicle {
        id,
        kind: "tank".into(),
        team: 1,
        hp: 100.0,
        visible: 1,
        position: Vector3::X * x,
        ..Default::default()
    }
}

#[test]
fn melee_skips_flinging_men_then_retains_the_first_enemy_and_cancels_the_route() {
    let mut a = soldier(1, 0.0, 0);
    a.motion.path = vec![Vector3::X * 20.0];
    a.orders.pending_path = true;
    let mut flung = soldier(2, 1.0, 1);
    flung.shock.flinging = true;
    let (mut actors, units) = field(
        vec![a, flung, soldier(3, 1.5, 1), soldier(4, 1.1, 1)],
        vec![],
    );
    assert!(
        actors
            .try_infantry_melee(1, 10.0, true, &units)
            .unwrap()
            .started
    );
    let a = actors.soldier(1).unwrap();
    assert_eq!(a.action.current, Action::Melee { target: 3 });
    assert_eq!(a.arsenal.melee_ready, 11.4);
    assert_eq!(a.orders.path_revision, 1);
    assert!(a.motion.path.is_empty());
    assert!(
        !actors
            .try_infantry_melee(1, 10.1, true, &units)
            .unwrap()
            .started
    );
}

#[test]
fn rocket_uses_visible_order_before_reports_without_touching_the_ground_cache() {
    let mut a = soldier(1, 0.0, 0);
    a.arsenal.rockets = 2;
    a.fight.visible_targets = vec![3, 2];
    let q = Squad {
        id: 9,
        known: vec![Contact {
            id: 2,
            report: Report {
                position: Vector3::ZERO,
                time: 10.0,
            },
        }],
        ..Default::default()
    };
    let (mut actors, _) = field(vec![a], vec![vehicle(2, 10.0), vehicle(3, 70.0)]);
    let result = actors
        .try_infantry_rocket(
            1,
            10.0,
            Some(&q),
            &Terrain::blank(32).unwrap(),
            &[],
            &mut CollisionWorld::default(),
            &Visibility::default(),
        )
        .unwrap();
    assert!(result.started);
    assert_eq!(result.speech, Some(0));
    let a = actors.soldier(1).unwrap();
    assert_eq!(a.action.current, Action::Launch { target: 3 });
    assert_eq!(a.motion.ground_until, -1.0);
    assert_eq!(a.arsenal.rockets, 1);
    assert_eq!(a.vitals.speech_cooldown, 2.6);
}

#[test]
fn reported_rocket_search_refreshes_ground_even_when_no_report_can_be_fired_on() {
    let mut a = soldier(1, 0.0, 0);
    a.arsenal.rockets = 2;
    let mut q = Squad {
        id: 9,
        known: vec![Contact {
            id: 2,
            report: Report {
                position: Vector3::ZERO,
                time: 4.0,
            },
        }],
        ..Default::default()
    };
    let (mut actors, _) = field(vec![a], vec![vehicle(2, 60.0)]);
    let terrain = Terrain::blank(32).unwrap();
    let mut collision = CollisionWorld::default();
    let visibility = Visibility::default();
    assert!(
        !actors
            .try_infantry_rocket(
                1,
                10.0,
                Some(&q),
                &terrain,
                &[],
                &mut collision,
                &visibility
            )
            .unwrap()
            .started
    );
    assert_eq!(actors.soldier(1).unwrap().motion.ground_until, 10.3);
    q.known[0].report.time = 4.01;
    assert!(
        actors
            .try_infantry_rocket(
                1,
                10.0,
                Some(&q),
                &terrain,
                &[],
                &mut collision,
                &visibility
            )
            .unwrap()
            .started
    );
    q.ambush = true;
    let before = actors.checkpoint().unwrap();
    assert!(
        !actors
            .try_infantry_rocket(
                1,
                20.0,
                Some(&q),
                &terrain,
                &[],
                &mut collision,
                &visibility
            )
            .unwrap()
            .started
    );
    assert_eq!(actors.checkpoint().unwrap(), before);
}

#[test]
fn drone_failure_waits_three_seconds_and_launch_uses_exact_random_continuation() {
    let mut a = soldier(1, 0.0, 0);
    a.arsenal.drones = 2;
    let (mut empty, units) = field(vec![a.clone()], vec![]);
    let mut rng = SimulationRandom::new(73);
    let before = rng;
    assert!(
        !empty
            .try_infantry_drone(1, 10.0, &units, |_| 2, |_| false, &mut rng)
            .unwrap()
            .started
    );
    assert_eq!(rng, before);
    assert_eq!(empty.soldier(1).unwrap().arsenal.drone_ready, 13.0);
    let (mut actors, units) = field(vec![a], vec![vehicle(2, 120.0)]);
    let result = actors
        .try_infantry_drone(1, 10.0, &units, |_| 2, |_| false, &mut rng)
        .unwrap();
    let mut expected = before;
    let deadline = 10.0 + f64::from(expected.randf_range(18.0, 26.0));
    assert!(result.started);
    assert_eq!(result.speech, Some(2));
    assert_eq!(rng, expected);
    assert_eq!(
        actors.soldier(1).unwrap().action.current,
        Action::LaunchDrone { target: 2 }
    );
    assert_eq!(actors.soldier(1).unwrap().arsenal.drone_ready, deadline);
    let mut a = soldier(1, 0.0, 0);
    a.arsenal.drones = 2;
    a.fight.controlled_drone = 99;
    let (mut actors, units) = field(vec![a], vec![vehicle(2, 120.0)]);
    let before = actors.checkpoint().unwrap();
    assert!(
        !actors
            .try_infantry_drone(1, 10.0, &units, |_| 2, |_| false, &mut rng)
            .unwrap()
            .started
    );
    assert_eq!(actors.checkpoint().unwrap(), before);
    assert_eq!(rng, expected);
}

#[test]
fn mortar_queue_range_and_smoke_preserve_inventory_and_muted_speech_draws() {
    let mut a = soldier(1, 0.0, 0);
    a.arsenal.mortar_rounds = 3;
    a.vitals.speech_cooldown = 9.0;
    let (mut actors, units) = field(vec![a], vec![]);
    let mut q = Squad {
        id: 9,
        fire_queue: vec![(Vector3::X * 24.99, false), (Vector3::X * 80.0, true)],
        ..Default::default()
    };
    let mut rng = SimulationRandom::new(0);
    let result = actors
        .try_infantry_mortar(1, 10.0, Some(&mut q), &units, &[], &mut rng)
        .unwrap();
    assert!(result.cleared_mission);
    assert_eq!(result.speech, Some(3));
    assert!(q.fire_queue.is_empty());
    assert_eq!(actors.soldier(1).unwrap().arsenal.mortar_rounds, 3);
    q.fire_queue.push((Vector3::X * 25.0, true));
    let mut expected = rng;
    if expected.randf() < 0.4 {
        expected.randi();
    }
    let result = actors
        .try_infantry_mortar(1, 10.0, Some(&mut q), &units, &[], &mut rng)
        .unwrap();
    assert!(result.started);
    assert_eq!(result.speech, None);
    assert_eq!(rng, expected);
    assert_eq!(
        actors.soldier(1).unwrap().action.current,
        Action::Mortar {
            position: Vector3::X * 25.0,
            round: Round::Smoke
        }
    );
    assert!(q.fire_queue.is_empty());
}

#[test]
fn rejected_action_keeps_shared_queue_ammunition_and_random_cursor() {
    let mut a = soldier(1, 0.0, 0);
    a.arsenal.mortar_rounds = 3;
    a.orders.path_revision = i64::MAX as u64;
    let (mut actors, units) = field(vec![a], vec![]);
    let mut q = Squad {
        id: 9,
        fire_queue: vec![(Vector3::X * 80.0, true)],
        ..Default::default()
    };
    let before = actors.checkpoint().unwrap();
    let before_queue = q.fire_queue.clone();
    let mut rng = SimulationRandom::new(73);
    let before_rng = rng;
    assert!(actors
        .try_infantry_mortar(1, 10.0, Some(&mut q), &units, &[], &mut rng)
        .is_err());
    assert_eq!(actors.checkpoint().unwrap(), before);
    assert_eq!(q.fire_queue, before_queue);
    assert_eq!(rng, before_rng);
}
