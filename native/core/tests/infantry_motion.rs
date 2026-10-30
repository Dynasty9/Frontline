use frontline_core::collision::{BoxShape, CollisionWorld, Mat3};
use frontline_core::infantry_motion::{Door, InfantryMotion, MoveInput, Progress};
use frontline_core::path_planner::PathPlanner;
use frontline_core::random::SimulationRandom;
use frontline_core::terrain::Terrain;
use frontline_core::vector::Vector3;

fn input() -> MoveInput {
    MoveInput {
        dt: 1.0 / 30.0,
        time: 1.0,
        speed: 3.0,
        base_y: 0.0,
        alive: true,
        path_pending: false,
        cover_goal: false,
        move_mode: 0,
        suppression: 0.0,
        backwards: false,
        danger: false,
        has_doors: false,
        door_still_closed: false,
        mount: None,
    }
}

#[test]
fn route_progress_waiting_stuck_replanning_and_duplicate_points_preserve_priority() {
    let nav = PathPlanner::new(32).unwrap();
    let terrain = Terrain::blank(32).unwrap();
    let mut collision = CollisionWorld::default();
    let mut rng = SimulationRandom::new(7);
    let mut state = InfantryMotion {
        path: vec![Vector3::ZERO, Vector3::ZERO, Vector3::X * 10.0],
        ..Default::default()
    };
    let before = state.clone();
    let mut i = input();
    i.path_pending = true;
    assert_eq!(
        state
            .step(i, &nav, &terrain, &mut collision, &mut rng, &[], &[])
            .unwrap()
            .progress,
        Progress::Moving
    );
    assert_eq!(state, before);
    i.path_pending = false;
    state
        .step(i, &nav, &terrain, &mut collision, &mut rng, &[], &[])
        .unwrap();
    assert_eq!(state.position, Vector3::ZERO);
    assert_eq!(state.path_index, 1);
    state
        .step(i, &nav, &terrain, &mut collision, &mut rng, &[], &[])
        .unwrap();
    assert_eq!(state.path_index, 2);
    assert!(state.position.x > 0.0);
    state.stuck_position = state.position;
    state.stuck_timer = 3.0;
    assert_eq!(
        state
            .step(i, &nav, &terrain, &mut collision, &mut rng, &[], &[])
            .unwrap()
            .progress,
        Progress::Repath
    );
    state.stuck_timer = 0.0;
    state.position = Vector3::X * 9.8;
    assert_eq!(
        state
            .step(i, &nav, &terrain, &mut collision, &mut rng, &[], &[])
            .unwrap()
            .progress,
        Progress::Arrived
    );
    assert_eq!(
        state
            .step(i, &nav, &terrain, &mut collision, &mut rng, &[], &[])
            .unwrap()
            .progress,
        Progress::Idle
    );
}

#[test]
fn door_wait_kick_randomness_and_checkpoint_resume_keep_the_same_move() {
    let nav = PathPlanner::new(32).unwrap();
    let terrain = Terrain::blank(32).unwrap();
    let mut collision = CollisionWorld::default();
    let mut rng = SimulationRandom::new(7);
    let mut state = InfantryMotion {
        position: Vector3::new(0.0, 0.0, 0.6),
        path: vec![-Vector3::Z * 10.0],
        ..Default::default()
    };
    let door = Door {
        id: 9,
        position: Vector3::ZERO,
        yaw: 0.0,
    };
    let mut i = input();
    i.danger = true;
    i.has_doors = true;
    i.door_still_closed = true;
    let mut expected_rng = rng;
    let speech = if f64::from(expected_rng.randf()) < 0.4 {
        Some((expected_rng.randi() % 3) as u8)
    } else {
        None
    };
    let result = state
        .step(i, &nav, &terrain, &mut collision, &mut rng, &[], &[door])
        .unwrap();
    assert_eq!(result.speech, speech);
    assert_eq!(rng, expected_rng);
    assert_eq!(state.door, 9);
    assert_eq!(state.door_wait, 0.5);
    assert!(state.door_kick);
    assert_eq!(state.position.z, 0.6);
    let saved = state.checkpoint();
    let mut restored = InfantryMotion::restore(&saved).unwrap();
    let mut restored_rng = rng;
    assert_eq!(saved, restored.checkpoint());
    let mut opened = false;
    for tick in 0..30 {
        i.time += i.dt;
        let doors = if opened { &[][..] } else { &[door][..] };
        i.has_doors = !opened;
        i.door_still_closed = !opened;
        let a = state
            .step(i, &nav, &terrain, &mut collision, &mut rng, &[], doors)
            .unwrap();
        let b = restored
            .step(
                i,
                &nav,
                &terrain,
                &mut collision,
                &mut restored_rng,
                &[],
                doors,
            )
            .unwrap();
        assert_eq!(a, b);
        assert_eq!(state, restored);
        assert_eq!(rng, restored_rng);
        if a.opened_door != 0 {
            assert_eq!(a.opened_door, 9);
            assert!(tick >= 14);
            opened = true;
        }
    }
    assert!(opened && state.position.z < 0.0);
    for n in 0..saved.len() {
        assert!(InfantryMotion::restore(&saved[..n]).is_err());
    }
    let mut bad = saved;
    bad[4] = 2;
    assert!(InfantryMotion::restore(&bad).is_err());
}

#[test]
fn vaulting_slides_and_ground_caches_share_numeric_navigation_and_geometry() {
    let mut nav = PathPlanner::new(32).unwrap();
    let mut terrain = Terrain::blank(32).unwrap();
    let index = terrain.index(Vector3::ZERO);
    nav.set_cell(index, 1, 0, 0);
    let mut collision = CollisionWorld::default();
    collision.replace(
        2,
        &[BoxShape {
            body: 2,
            shape: 0,
            center: Vector3::new(0.6, 0.3, 0.0),
            basis: Mat3::IDENTITY,
            half: Vector3::new(0.1, 0.3, 2.0),
        }],
    );
    let mut rng = SimulationRandom::new(4);
    let mut state = InfantryMotion {
        path: vec![Vector3::X * 2.0],
        ..Default::default()
    };
    let mut i = input();
    i.cover_goal = true;
    i.move_mode = 1;
    i.suppression = 30.0;
    let a = state
        .step(i, &nav, &terrain, &mut collision, &mut rng, &[], &[])
        .unwrap();
    assert!(state.vaulting && a.slid);
    assert_eq!(state.slide_timer, 0.45);
    assert!(state.position.y > 0.0);
    terrain.heights.fill(-2.0);
    let cached = state.ground;
    i.time += 0.1;
    state
        .step(i, &nav, &terrain, &mut collision, &mut rng, &[], &[])
        .unwrap();
    assert_eq!(state.ground, cached);
    i.time += 0.3;
    state
        .step(i, &nav, &terrain, &mut collision, &mut rng, &[], &[])
        .unwrap();
    assert_eq!(state.ground, -2.0);
    i.time += 0.4;
    let decks = vec![1; 32 * 32];
    state
        .step(i, &nav, &terrain, &mut collision, &mut rng, &decks, &[])
        .unwrap();
    assert_eq!(state.ground, 0.06);
    let saved = state.clone();
    let saved_rng = rng;
    i.dt = f64::NAN;
    assert!(state
        .step(i, &nav, &terrain, &mut collision, &mut rng, &[], &[])
        .is_err());
    assert_eq!(state, saved);
    assert_eq!(rng, saved_rng);
}
