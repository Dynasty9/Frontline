use frontline_core::path_planner::PathPlanner;
use frontline_core::random::SimulationRandom;
use frontline_core::terrain::Terrain;
use frontline_core::vector::Vector3;
use frontline_core::vehicle::{Route, Vehicle};
use frontline_core::vehicle_motion::*;

fn profile(tracked: bool) -> GroundProfile {
    GroundProfile {
        hull: Vector3::new(3.0, 2.0, 6.0),
        tracked,
        weight: 2,
        supply: false,
        tank: tracked,
        cannon: true,
        speed: 9.0,
        turn: 0.6,
        turn_accel: 0.9,
        handling: [1.2, 4.0, 2.2, 0.32],
    }
}
fn vehicle(to: Vector3) -> Vehicle {
    Vehicle {
        id: 1,
        path: vec![to],
        ..Default::default()
    }
}

#[test]
fn supply_trucks_reverse_into_nearby_deliveries_without_a_lane_offset() {
    let nav = PathPlanner::new(32).unwrap();
    let terrain = Terrain::blank(32).unwrap();
    let mut p = profile(false);
    p.supply = true;
    let mut truck = Vehicle {
        route: vec![Vector3::Z * 10.],
        ..Default::default()
    };
    truck
        .follow_truck_route(0.1, p, &nav, &terrain, &[], &[])
        .unwrap();
    assert!(truck.reverse && truck.speed < 0. && truck.position.z > 0.);
    assert_eq!(truck.position.x, 0.);
    assert_eq!(truck.yaw_rate, 0.);
}

#[test]
fn wheeled_hulls_need_forward_speed_to_turn_and_tracked_hulls_pivot() {
    let nav = PathPlanner::new(128).unwrap();
    let terrain = Terrain::blank(128).unwrap();
    let mut rng = SimulationRandom::new(3);
    let mut wheels = vehicle(Vector3::X * 40.0);
    let mut tracks = wheels.clone();
    wheels
        .drive_ground(
            1.0 / 30.0,
            profile(false),
            None,
            &nav,
            &terrain,
            &[],
            &mut rng,
            &[],
        )
        .unwrap();
    tracks
        .drive_ground(
            1.0 / 30.0,
            profile(true),
            None,
            &nav,
            &terrain,
            &[],
            &mut rng,
            &[],
        )
        .unwrap();
    assert_eq!(wheels.yaw, 0.0);
    assert_eq!(wheels.yaw_rate, 0.0);
    assert!(wheels.speed > 0.0);
    assert!(tracks.yaw < 0.0);
    assert!(tracks.yaw_rate < 0.0);
    wheels
        .drive_ground(
            1.0 / 30.0,
            profile(false),
            None,
            &nav,
            &terrain,
            &[],
            &mut rng,
            &[],
        )
        .unwrap();
    assert!(wheels.yaw < 0.0);
}

#[test]
fn checkpoint_resumes_ground_steering_and_final_braking() {
    let nav = PathPlanner::new(128).unwrap();
    let terrain = Terrain::blank(128).unwrap();
    let mut rng = SimulationRandom::new(137);
    let mut a = vehicle(Vector3::new(7.0, 0.0, -25.0));
    for _ in 0..100 {
        a.drive_ground(
            1.0 / 30.0,
            profile(false),
            None,
            &nav,
            &terrain,
            &[],
            &mut rng,
            &[],
        )
        .unwrap();
    }
    let mut b = Vehicle::restore(&a.checkpoint().unwrap()).unwrap();
    let mut brng = rng.clone();
    for _ in 0..900 {
        let left = a
            .drive_ground(
                1.0 / 30.0,
                profile(false),
                None,
                &nav,
                &terrain,
                &[],
                &mut rng,
                &[],
            )
            .unwrap();
        let right = b
            .drive_ground(
                1.0 / 30.0,
                profile(false),
                None,
                &nav,
                &terrain,
                &[],
                &mut brng,
                &[],
            )
            .unwrap();
        assert_eq!(left, right);
        assert_eq!(a, b);
        assert_eq!(rng.state(), brng.state());
    }
    assert_eq!(a.path_index, 1);
    assert!(a.speed.abs() < 0.4);
    assert!(a.position.distance(Vector3::new(7.0, 0.0, -25.0)) < 2.0);
}

#[test]
fn obstructed_vehicles_back_out_then_issue_a_new_route() {
    let mut nav = PathPlanner::new(128).unwrap();
    let terrain = Terrain::blank(128).unwrap();
    assert!(nav.load_cells(
        &vec![3; 128 * 128],
        &vec![3; 128 * 128],
        &vec![0; 128 * 128]
    ));
    let mut rng = SimulationRandom::new(137);
    let before = rng.state();
    let mut v = vehicle(Vector3::NEG_Z * 30.0);
    let mut unstuck = 0;
    let mut replanned = 0;
    for _ in 0..200 {
        let out = v
            .drive_ground(
                1.0 / 30.0,
                profile(true),
                None,
                &nav,
                &terrain,
                &[],
                &mut rng,
                &[],
            )
            .unwrap();
        unstuck += usize::from(out.unstuck);
        if let Route::Ground {
            destination,
            care,
            revision,
        } = out.route
        {
            assert_eq!(destination, Vector3::NEG_Z * 30.0);
            assert_eq!(care, 0.0);
            assert_eq!(revision, 1);
            replanned += 1;
        }
    }
    assert_eq!(unstuck, 1);
    assert_eq!(replanned, 1);
    assert!(v.path_pending);
    assert_eq!(v.position, Vector3::ZERO);
    assert_ne!(rng.state(), before);
}

#[test]
fn attack_move_closes_to_trenches_but_stops_for_exposed_targets() {
    let nav = PathPlanner::new(128).unwrap();
    let terrain = Terrain::blank(128).unwrap();
    let mut rng = SimulationRandom::new(137);
    let mut a = vehicle(Vector3::NEG_Z * 55.0);
    a.assault = true;
    let mut b = a.clone();
    let target = Vector3::NEG_Z * 40.0;
    a.drive_ground(
        1.0 / 30.0,
        profile(true),
        Some((target, false)),
        &nav,
        &terrain,
        &[],
        &mut rng,
        &[],
    )
    .unwrap();
    b.drive_ground(
        1.0 / 30.0,
        profile(true),
        Some((target, true)),
        &nav,
        &terrain,
        &[],
        &mut rng,
        &[],
    )
    .unwrap();
    assert_eq!(a.position, Vector3::ZERO);
    assert!(b.position.z < 0.0);
}

#[test]
fn a_blocked_road_caps_approach_speed_and_invalid_inputs_do_not_advance() {
    let nav = PathPlanner::new(128).unwrap();
    let terrain = Terrain::blank(128).unwrap();
    let mut rng = SimulationRandom::new(137);
    let mut v = vehicle(Vector3::NEG_Z * 40.0);
    v.speed = 5.0;
    let traffic = [Traffic {
        id: 2,
        position: Vector3::NEG_Z * 8.0,
        yaw: 0.0,
        speed: 0.0,
        hull: Vector3::new(3.0, 2.0, 6.0),
        air: false,
    }];
    v.drive_ground(
        1.0 / 30.0,
        profile(false),
        None,
        &nav,
        &terrain,
        &traffic,
        &mut rng,
        &[],
    )
    .unwrap();
    assert_eq!(v.avoid_cap, Some(3.0));
    assert!(v.speed < 5.0);
    let saved = v.checkpoint().unwrap();
    let before = rng.state();
    assert!(v
        .drive_ground(
            f64::NAN,
            profile(false),
            None,
            &nav,
            &terrain,
            &traffic,
            &mut rng,
            &[]
        )
        .is_err());
    assert_eq!(v.checkpoint().unwrap(), saved);
    assert_eq!(rng.state(), before);
}

#[test]
fn exhausted_path_revisions_reject_recovery_before_moving() {
    let nav = PathPlanner::new(128).unwrap();
    let terrain = Terrain::blank(128).unwrap();
    let mut rng = SimulationRandom::new(137);
    let mut v = vehicle(Vector3::NEG_Z * 30.0);
    v.path_revision = i64::MAX as u64;
    v.unstick_timer = 0.01;
    let saved = v.clone();
    let random = rng.state();
    assert!(v
        .drive_ground(
            1.0 / 30.0,
            profile(true),
            None,
            &nav,
            &terrain,
            &[],
            &mut rng,
            &[]
        )
        .is_err());
    assert_eq!(v, saved);
    assert_eq!(rng.state(), random);
}

#[test]
fn long_vehicle_steps_and_supply_routes_cannot_skip_deep_water() {
    use frontline_core::navigation_scene::NavigationScene;
    use frontline_core::terrain::{BASE, WATER};
    let mut terrain = Terrain::blank(32).unwrap();
    for z in 0..32 {
        terrain.layers[BASE][z * 32 + 16] = WATER;
    }
    let nav = NavigationScene::new(&terrain, &[], 16).unwrap();
    for supply in [false, true] {
        let mut v = vehicle(Vector3::new(12., 0., 0.5));
        v.position = Vector3::new(-2., 0., 0.5);
        v.yaw = -std::f32::consts::FRAC_PI_2 as f64;
        v.speed = 9.;
        let mut p = profile(false);
        p.supply = supply;
        if supply {
            v.route = v.path.clone();
            v.follow_truck_route(1., p, &nav.planner, &terrain, &[], &[])
                .unwrap();
        } else {
            v.drive_ground(
                1.,
                p,
                None,
                &nav.planner,
                &terrain,
                &[],
                &mut SimulationRandom::new(1),
                &[],
            )
            .unwrap();
        }
        assert!(v.position.x < 0., "supply={supply}");
    }
}

#[test]
fn hull_movement_uses_its_slope_class_and_sets_geological_height() {
    use frontline_core::navigation_scene::NavigationScene;
    let mut terrain = Terrain::blank(64).unwrap();
    assert!(terrain.set_landform((0..289).map(|i| (i % 17) as f32 * 4. * 0.55).collect()));
    let nav = NavigationScene::new(&terrain, &[], 16).unwrap();
    for tracked in [false, true] {
        let mut v = vehicle(Vector3::new(12., 0., 0.5));
        v.position = Vector3::new(0., 17.6, 0.5);
        v.yaw = -std::f32::consts::FRAC_PI_2 as f64;
        v.speed = 5.;
        v.drive_ground(
            0.1,
            profile(tracked),
            None,
            &nav.planner,
            &terrain,
            &[],
            &mut SimulationRandom::new(1),
            &[],
        )
        .unwrap();
        if tracked {
            assert!(v.position.x > 0.1);
            assert_eq!(v.position.y, terrain.landform.height(v.position) as f32);
        } else {
            assert_eq!(v.position.x, 0.);
        }
    }
}
