use frontline_core::infantry_motion::{separation, InfantryMotion, Neighbor, StationaryInput};
use frontline_core::infantry_vitals::Life;
use frontline_core::path_planner::PathPlanner;
use frontline_core::random::SimulationRandom;
use frontline_core::terrain::Terrain;
use frontline_core::vector::Vector3;

fn input() -> StationaryInput {
    StationaryInput {
        dt: 1.0 / 30.0,
        time: 2.0,
        base_y: 0.0,
        separation: Vector3::ZERO,
        prone: false,
        at_cover: false,
        cover_position: Vector3::ZERO,
        cover_normal: Vector3::ZERO,
        cover_kind: 0,
        last_shot: -99.0,
        peek_up: false,
        target_valid: false,
        sector: Vector3::ZERO,
        mount: None,
    }
}

#[test]
fn separation_preserves_neighbor_order_and_overlap_randomness() {
    let neighbors = [
        Neighbor {
            id: 1,
            position: Vector3::ZERO,
            life: Life::Alive,
        },
        Neighbor {
            id: 2,
            position: Vector3::ZERO,
            life: Life::Dead,
        },
        Neighbor {
            id: 3,
            position: Vector3::ZERO,
            life: Life::Hidden,
        },
        Neighbor {
            id: 4,
            position: Vector3::X * 0.5,
            life: Life::Downed,
        },
    ];
    let mut rng = SimulationRandom::new(991);
    let before = rng;
    assert_eq!(
        separation(1, Vector3::ZERO, false, &neighbors, &mut rng).unwrap(),
        Vector3::ZERO
    );
    assert_eq!(rng, before);
    assert_eq!(
        separation(1, Vector3::ZERO, true, &neighbors, &mut rng).unwrap(),
        -Vector3::X * 0.35
    );
    assert_eq!(rng, before);
    let overlapping = [Neighbor {
        id: 5,
        position: Vector3::ZERO,
        life: Life::Alive,
    }];
    let offset = separation(1, Vector3::ZERO, true, &overlapping, &mut rng).unwrap();
    assert!((offset.length() - 0.35).abs() < 0.000001);
    let mut expected = before;
    expected.randf_range(-1.0, 1.0);
    expected.randf_range(-1.0, 1.0);
    assert_eq!(rng, expected);
    let mut malformed = overlapping;
    malformed[0].position.x = f32::NAN;
    let before = rng;
    assert!(separation(1, Vector3::ZERO, true, &malformed, &mut rng).is_err());
    assert_eq!(rng, before);
}

#[test]
fn stationary_spacing_respects_prone_and_blocked_ground() {
    let mut nav = PathPlanner::new(32).unwrap();
    let terrain = Terrain::blank(32).unwrap();
    let mut state = InfantryMotion::default();
    let mut i = input();
    i.separation = Vector3::X * 10.0;
    assert!(state.stationary(i, &nav, &terrain, &[]).unwrap());
    assert!((state.position.x - 1.4 / 30.0).abs() < 0.000001);
    let position = state.position;
    i.prone = true;
    assert!(!state.stationary(i, &nav, &terrain, &[]).unwrap());
    assert_eq!(position, state.position);
    i.prone = false;
    assert!(nav.load_cells(&[3; 1024], &[0; 1024], &[0; 1024]));
    assert!(!state.stationary(i, &nav, &terrain, &[]).unwrap());
    assert_eq!(position, state.position);
}

#[test]
fn stationary_cover_alignment_and_ground_cache_resume_exactly() {
    let nav = PathPlanner::new(32).unwrap();
    let terrain = Terrain::blank(32).unwrap();
    let mut state = InfantryMotion {
        position: Vector3::new(0.4, 1.0, 0.0),
        ground: -0.8,
        ground_until: 2.0,
        ..Default::default()
    };
    let mut i = input();
    i.at_cover = true;
    i.cover_kind = 1;
    i.cover_normal = Vector3::X;
    state.stationary(i, &nav, &terrain, &[]).unwrap();
    assert_eq!(state.ground, -0.8);
    assert!(state.position.x < 0.4 && state.position.y < 1.0 && state.yaw < 0.0);
    let mut resumed = InfantryMotion::restore(&state.checkpoint()).unwrap();
    for tick in 1..40 {
        i.time = 2.0 + tick as f64 / 30.0;
        assert_eq!(
            state.stationary(i, &nav, &terrain, &[]),
            resumed.stationary(i, &nav, &terrain, &[])
        );
        assert_eq!(state, resumed);
    }
    assert_eq!(state.ground, 0.0);
    assert!(state.position.x <= 0.02);
    i.dt = f64::NAN;
    let before = state.clone();
    assert!(state.stationary(i, &nav, &terrain, &[]).is_err());
    assert_eq!(state, before);
}

#[test]
fn sector_and_cover_turning_keep_fire_and_mount_gates() {
    let nav = PathPlanner::new(32).unwrap();
    let terrain = Terrain::blank(32).unwrap();
    let mut i = input();
    i.sector = Vector3::X;
    let mut state = InfantryMotion::default();
    i.target_valid = true;
    state.stationary(i, &nav, &terrain, &[]).unwrap();
    assert_eq!(state.yaw, 0.0);
    i.target_valid = false;
    i.last_shot = i.time - 1.0;
    state.stationary(i, &nav, &terrain, &[]).unwrap();
    assert_eq!(state.yaw, 0.0);
    i.last_shot = -99.0;
    i.mount = Some((Vector3::ZERO, 0.2));
    state.stationary(i, &nav, &terrain, &[]).unwrap();
    assert_eq!(state.yaw, f64::from((-0.2 / 30.0) as f32));
    i.at_cover = true;
    i.cover_normal = Vector3::X;
    i.cover_kind = 2;
    let yaw = state.yaw;
    state.stationary(i, &nav, &terrain, &[]).unwrap();
    assert_eq!(state.yaw, yaw);
    i.cover_kind = 1;
    i.peek_up = true;
    i.target_valid = true;
    state.stationary(i, &nav, &terrain, &[]).unwrap();
    assert_eq!(state.yaw, yaw);
}
