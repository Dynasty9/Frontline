use frontline_core::actors::{Actor, Actors};
use frontline_core::infantry::{Goal, Infantry};
use frontline_core::infantry_orders::PathFinish;
use frontline_core::navigation_scene::NavigationScene;
use frontline_core::random::SimulationRandom;
use frontline_core::terrain::{Terrain, BASE, WATER};
use frontline_core::vector::Vector3;
use frontline_core::vehicle::{Route, Vehicle};
use frontline_core::world_routes::Completion;

fn soldier(id: u32, x: f32) -> Infantry {
    let mut s = Infantry::default();
    s.identity.id = id;
    s.identity.unit = "rifleman".into();
    s.motion.position.x = x;
    s
}
fn navigation() -> (Terrain, NavigationScene) {
    let terrain = Terrain::blank(32).unwrap();
    let mut nav = NavigationScene::new(&terrain, &[], 16).unwrap();
    assert!(nav.finalize(1));
    (terrain, nav)
}

#[test]
fn direct_steps_cancel_old_work_and_ignore_stale_order_submissions() {
    let (terrain, mut nav) = navigation();
    let mut rng = SimulationRandom::new(137);
    let mut s = soldier(1, -10.0);
    let far = s.go_to(Vector3::X * 12.0, Goal::Slot, 0).unwrap();
    assert_eq!(
        nav.submit_infantry(
            &mut s,
            far,
            1.0,
            &mut rng,
            frontline_core::traversal::Ground::new(&terrain, &[])
        )
        .unwrap(),
        None
    );
    let near = s.go_to(Vector3::X * -8.0, Goal::Slot, 0).unwrap();
    let cursor = rng.state();
    assert_eq!(
        nav.submit_infantry(
            &mut s,
            near,
            2.0,
            &mut rng,
            frontline_core::traversal::Ground::new(&terrain, &[])
        )
        .unwrap(),
        Some(PathFinish::Following)
    );
    assert_eq!(
        nav.submit_infantry(
            &mut s,
            far,
            2.0,
            &mut rng,
            frontline_core::traversal::Ground::new(&terrain, &[])
        )
        .unwrap(),
        Some(PathFinish::Ignored)
    );
    assert_eq!(s.motion.path, [Vector3::X * -8.0]);
    assert_eq!(rng.state(), cursor);
    nav.planner.begin_batch();
    assert!(nav.planner.next_job().is_none());
}

#[test]
fn missing_and_stopped_units_do_not_consume_the_route_quota() {
    let (terrain, mut nav) = navigation();
    let mut rng = SimulationRandom::new(137);
    let mut entries = vec![];
    for id in 1..=3 {
        let mut s = soldier(id, -12.0);
        let order = s.go_to(Vector3::X * 12.0, Goal::Slot, 0).unwrap();
        assert_eq!(
            nav.submit_infantry(
                &mut s,
                order,
                0.0,
                &mut rng,
                frontline_core::traversal::Ground::new(&terrain, &[])
            )
            .unwrap(),
            None
        );
        if id == 2 {
            s.stop_moving().unwrap();
        }
        entries.push(Actor::Soldier(Box::new(s)));
    }
    let mut v = Vehicle {
        id: 4,
        position: Vector3::X * -12.0,
        hp: 100.0,
        ..Default::default()
    };
    let Route::Ground {
        destination,
        care,
        revision,
    } = v.request_path(Vector3::X * 12.0, 0.5).unwrap()
    else {
        panic!()
    };
    assert_eq!(
        nav.submit_vehicle(
            &mut v,
            destination,
            care,
            revision,
            frontline_core::traversal::Ground::new(&terrain, &[])
        )
        .unwrap(),
        None
    );
    entries.push(Actor::Vehicle(Box::new(v)));
    let mut actors = Actors::from_entries(10, entries).unwrap();
    actors.remove(1);
    assert_eq!(
        nav.process_paths(
            &mut actors,
            1,
            1.0,
            &mut rng,
            frontline_core::traversal::Ground::new(&terrain, &[])
        )
        .unwrap(),
        [Completion::Infantry {
            id: 3,
            finish: PathFinish::Following
        }]
    );
    assert!(actors.vehicle(4).unwrap().path_pending);
    assert!(actors.soldier(2).unwrap().motion.path.is_empty());
    assert_eq!(
        nav.process_paths(
            &mut actors,
            1,
            2.0,
            &mut rng,
            frontline_core::traversal::Ground::new(&terrain, &[])
        )
        .unwrap(),
        [Completion::Vehicle {
            id: 4,
            accepted: true
        }]
    );
    assert!(!actors.vehicle(4).unwrap().path_pending);
}

#[test]
fn repairs_retry_once_per_batch_and_only_report_unreachable_when_finished() {
    let (mut terrain, mut nav) = navigation();
    let mut rng = SimulationRandom::new(137);
    let mut s = soldier(1, -12.0);
    let order = s.go_to(Vector3::X * 12.0, Goal::Cover, 0).unwrap();
    nav.submit_infantry(
        &mut s,
        order,
        0.0,
        &mut rng,
        frontline_core::traversal::Ground::new(&terrain, &[]),
    )
    .unwrap();
    let mut actors = Actors::from_entries(10, vec![Actor::Soldier(Box::new(s))]).unwrap();
    for z in 0..32 {
        let i = z * 32 + 16;
        terrain.layers[BASE][i] = WATER;
        nav.terrain_changed(i, &terrain, &[]).unwrap();
    }
    assert!(nav.infantry.has_work());
    for _ in 0..3 {
        assert!(nav
            .process_paths(
                &mut actors,
                100,
                2.0,
                &mut rng,
                frontline_core::traversal::Ground::new(&terrain, &[])
            )
            .unwrap()
            .is_empty());
        assert!(actors.soldier(1).unwrap().orders.pending_path);
    }
    let saved = nav.checkpoint();
    nav = NavigationScene::restore(&saved).unwrap();
    assert!(nav.update_hierarchy(100));
    assert_eq!(
        nav.process_paths(
            &mut actors,
            100,
            3.0,
            &mut rng,
            frontline_core::traversal::Ground::new(&terrain, &[])
        )
        .unwrap(),
        [Completion::Infantry {
            id: 1,
            finish: PathFinish::Unreachable
        }]
    );
    let s = actors.soldier(1).unwrap();
    assert_eq!(s.cover.evaluate_at, 4.0);
    assert!(!s.orders.pending_path);
    assert_eq!(s.orders.purpose, Goal::None);
}

#[test]
fn resumed_queues_preserve_replacement_order_actor_paths_and_randomness() {
    let (terrain, mut nav) = navigation();
    let mut rng = SimulationRandom::new(137);
    let mut entries = vec![];
    for id in 1..=24 {
        let mut s = soldier(id, -13.0);
        let order = s
            .go_to(
                Vector3::new(12.0, 0.0, id as f32 * 0.5 - 6.0),
                Goal::Slot,
                0,
            )
            .unwrap();
        nav.submit_infantry(
            &mut s,
            order,
            0.0,
            &mut rng,
            frontline_core::traversal::Ground::new(&terrain, &[]),
        )
        .unwrap();
        if id % 2 == 0 {
            let revised = s
                .go_to(Vector3::new(9.0, 0.0, 5.0), Goal::Cover, 2)
                .unwrap();
            nav.submit_infantry(
                &mut s,
                revised,
                0.0,
                &mut rng,
                frontline_core::traversal::Ground::new(&terrain, &[]),
            )
            .unwrap();
        }
        entries.push(Actor::Soldier(Box::new(s)));
    }
    let mut a = Actors::from_entries(30, entries).unwrap();
    let mut b = Actors::restore(&a.checkpoint().unwrap()).unwrap();
    let mut other = NavigationScene::restore(&nav.checkpoint()).unwrap();
    let mut rng2 = rng.clone();
    for budget in [0, 1, 3, 2, 8, 1, 20] {
        assert_eq!(
            nav.process_paths(
                &mut a,
                budget,
                3.0,
                &mut rng,
                frontline_core::traversal::Ground::new(&terrain, &[])
            )
            .unwrap(),
            other
                .process_paths(
                    &mut b,
                    budget,
                    3.0,
                    &mut rng2,
                    frontline_core::traversal::Ground::new(&terrain, &[])
                )
                .unwrap()
        );
        assert_eq!(nav.checkpoint(), other.checkpoint());
        assert_eq!(a.checkpoint().unwrap(), b.checkpoint().unwrap());
        assert_eq!(rng, rng2);
        other = NavigationScene::restore(&other.checkpoint()).unwrap();
    }
    assert!(a.iter().all(
        |a| matches!(a, Actor::Soldier(s) if !s.orders.pending_path && !s.motion.path.is_empty())
    ));
}

#[test]
fn invalid_budgets_and_requests_leave_queues_actors_and_randomness_unchanged() {
    let (terrain, mut nav) = navigation();
    let mut rng = SimulationRandom::new(137);
    let mut s = soldier(1, -12.0);
    let mut order = s.go_to(Vector3::X * 12.0, Goal::Slot, 0).unwrap();
    let queue = nav.checkpoint();
    let initial = s.clone();
    let cursor = rng.state();
    order.job.id = 2;
    assert!(nav
        .submit_infantry(
            &mut s,
            order,
            0.0,
            &mut rng,
            frontline_core::traversal::Ground::new(&terrain, &[])
        )
        .is_err());
    assert_eq!(s, initial);
    let mut actors = Actors::from_entries(10, vec![Actor::Soldier(Box::new(s))]).unwrap();
    assert!(nav
        .process_paths(
            &mut actors,
            131_073,
            0.0,
            &mut rng,
            frontline_core::traversal::Ground::new(&terrain, &[])
        )
        .is_err());
    assert!(nav
        .process_paths(
            &mut actors,
            1,
            f64::NAN,
            &mut rng,
            frontline_core::traversal::Ground::new(&terrain, &[])
        )
        .is_err());
    assert_eq!(nav.checkpoint(), queue);
    assert_eq!(rng.state(), cursor);
    let mut invalid = Vehicle::default();
    assert!(nav
        .submit_vehicle(
            &mut invalid,
            Vector3::ZERO,
            0.5,
            0,
            frontline_core::traversal::Ground::new(&terrain, &[])
        )
        .is_err());
}

#[test]
fn tracked_requests_keep_their_class_through_queue_and_restore() {
    let mut terrain = Terrain::blank(64).unwrap();
    assert!(terrain.set_landform((0..289).map(|i| (i % 17) as f32 * 4. * 0.55).collect()));
    let mut nav = NavigationScene::new(&terrain, &[], 16).unwrap();
    assert!(nav.finalize(1));
    let mut entries = vec![];
    for (id, tracked) in [(1, true), (2, false)] {
        let mut v = Vehicle {
            id,
            tracked,
            position: Vector3::new(-16., 0., 0.),
            ..Default::default()
        };
        let Route::Ground {
            destination,
            care,
            revision,
        } = v.request_path(Vector3::new(16., 0., 0.), 0.).unwrap()
        else {
            panic!()
        };
        nav.submit_vehicle(
            &mut v,
            destination,
            care,
            revision,
            frontline_core::traversal::Ground::new(&terrain, &[]),
        )
        .unwrap();
        entries.push(Actor::Vehicle(Box::new(v)));
    }
    let mut actors = Actors::from_entries(3, entries).unwrap();
    let mut copy = NavigationScene::restore(&nav.checkpoint()).unwrap();
    let mut resumed = Actors::restore(&actors.checkpoint().unwrap()).unwrap();
    let mut rng = SimulationRandom::new(1);
    let mut other_rng = rng;
    let ground = frontline_core::traversal::Ground::new(&terrain, &[]);
    assert_eq!(
        nav.process_paths(&mut actors, 2, 1., &mut rng, ground)
            .unwrap(),
        copy.process_paths(&mut resumed, 2, 1., &mut other_rng, ground)
            .unwrap()
    );
    assert!(!actors.vehicle(1).unwrap().path.is_empty());
    assert!(actors.vehicle(2).unwrap().path.is_empty());
    assert_eq!(actors.checkpoint().unwrap(), resumed.checkpoint().unwrap());
    assert_eq!(nav.checkpoint(), copy.checkpoint());
}

#[test]
fn search_work_limit_defers_in_order_and_restores_without_profile_or_cache_timing() {
    let (terrain, mut nav) = navigation();
    let ground = frontline_core::traversal::Ground::new(&terrain, &[]);
    let mut rng = SimulationRandom::new(137);
    let mut entries = vec![];
    for id in 1..=3 {
        let mut s = soldier(id, -13.0);
        let order = s.go_to(Vector3::X * 13.0, Goal::Slot, 0).unwrap();
        assert_eq!(
            nav.submit_infantry(&mut s, order, 0., &mut rng, ground)
                .unwrap(),
            None
        );
        entries.push(Actor::Soldier(Box::new(s)));
    }
    let mut actors = Actors::from_entries(10, entries).unwrap();
    let queued = nav.checkpoint();
    let state = actors.checkpoint().unwrap();
    let cursor = rng.state();
    assert!(nav
        .process_paths_with_work_limit(&mut actors, 4, 0, 1., &mut rng, ground)
        .unwrap()
        .is_empty());
    assert!(
        nav.checkpoint() == queued,
        "A zero work budget must leave the queue unchanged"
    );
    assert_eq!(actors.checkpoint().unwrap(), state);
    assert_eq!(rng.state(), cursor);
    let first = nav
        .process_paths_with_work_limit(&mut actors, 4, 1, 1., &mut rng, ground)
        .unwrap();
    assert_eq!(
        first,
        [Completion::Infantry {
            id: 1,
            finish: PathFinish::Following
        }]
    );
    assert!(nav.infantry.last_expanded > 0);
    assert!(actors.soldier(2).unwrap().orders.pending_path);
    assert!(actors.soldier(3).unwrap().orders.pending_path);
    let mut restored = NavigationScene::restore(&nav.checkpoint()).unwrap();
    let mut restored_actors = Actors::restore(&actors.checkpoint().unwrap()).unwrap();
    let mut restored_rng = rng;
    restored.planner.profile = Some(Default::default());
    let next = nav
        .process_paths_with_work_limit(&mut actors, 4, 1, 2., &mut rng, ground)
        .unwrap();
    assert_eq!(
        next,
        [
            Completion::Infantry {
                id: 2,
                finish: PathFinish::Following
            },
            Completion::Infantry {
                id: 3,
                finish: PathFinish::Following
            },
        ]
    );
    assert_eq!(
        nav.infantry.last_expanded, 0,
        "Cached corridors must not reuse the preceding search's work count"
    );
    assert_eq!(
        next,
        restored
            .process_paths_with_work_limit(
                &mut restored_actors,
                4,
                1,
                2.,
                &mut restored_rng,
                ground
            )
            .unwrap()
    );
    assert_eq!(nav.checkpoint(), restored.checkpoint());
    assert_eq!(
        actors.checkpoint().unwrap(),
        restored_actors.checkpoint().unwrap()
    );
    assert_eq!(rng.state(), restored_rng.state());
}
