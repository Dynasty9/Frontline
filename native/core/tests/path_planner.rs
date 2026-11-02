use frontline_core::hierarchy::{build_all, Hierarchy};
use frontline_core::path_planner::{PathJob, PathPlanner};
use frontline_core::vector::Vector3;

fn job(id: u64) -> PathJob {
    PathJob {
        id,
        destination: Vector3::new(20.0, 0.0, 20.0),
        vehicle: false,
        tracked: false,
        team: -1,
        care: 0.0,
    }
}

#[test]
fn vehicle_recovery_keeps_the_three_cell_rim_used_by_navigation() {
    let nav = PathPlanner::new(64).unwrap();
    let edge = Vector3::new(7.354009, 0.0, -29.74264);
    assert_eq!(
        nav.nearest_walkable(edge, frontline_core::traversal::Ground::default()),
        Some(edge)
    );
    assert_eq!(
        nav.nearest_walkable_for(
            edge,
            true,
            false,
            frontline_core::traversal::Ground::default()
        ),
        Some(Vector3::new(6.5, 0.0, -28.5))
    );
    let open = Vector3::new(7.354009, 0.0, -28.74264);
    assert_eq!(
        nav.nearest_walkable_for(
            open,
            true,
            false,
            frontline_core::traversal::Ground::default()
        ),
        Some(open)
    );
}

#[test]
fn recovery_uses_live_water_and_reaches_shore_beyond_the_short_ring() {
    use frontline_core::terrain::{Terrain, BASE, SHALLOW};
    use frontline_core::traversal::Ground;
    let mut terrain = Terrain::blank(64).unwrap();
    terrain.heights.fill(-2.0);
    for z in 0..64 {
        for x in 8..56 {
            terrain.layers[BASE][z * 64 + x] = SHALLOW;
        }
    }
    // The water can change before the queued grid repair reaches this cell.
    let mut nav = PathPlanner::new(64).unwrap();
    let p = Vector3::new(0.5, 0.0, 0.5);
    let ground = Ground::new(&terrain, &[]);
    let shore = Vector3::new(24.5, 0.0, -23.5);
    assert_eq!(nav.nearest_walkable(p, ground), Some(shore));
    assert_eq!(
        nav.nearest_walkable_for(p, true, false, ground),
        Some(shore)
    );
    let mut deck = vec![0; 4096];
    deck[terrain.index(p)] = 1;
    assert_eq!(
        nav.nearest_walkable(p, Ground::new(&terrain, &deck)),
        Some(p)
    );
    nav.set_cell(terrain.index(p), 0, 3, 0);
    deck[terrain.index(p) - 1] = 1;
    assert_ne!(
        nav.nearest_walkable_for(p, true, false, Ground::new(&terrain, &deck)),
        Some(p)
    );
    assert_eq!(
        nav.nearest_walkable_for(p, true, true, Ground::new(&terrain, &deck)),
        Some(p)
    );
    assert_eq!(nav.nearest_walkable(p, Ground::new(&terrain, &[1])), None);
    assert_eq!(nav.nearest_walkable_for(p, false, true, ground), None);
}

#[test]
fn requests_replace_cancel_retry_and_resume_without_using_wall_time() {
    let mut planner = PathPlanner::new(64).unwrap();
    planner.request(job(1));
    planner.request(job(2));
    planner.cancel(1);
    let mut replacement = job(1);
    replacement.destination.x += 1.0;
    planner.request(replacement);
    planner.request(job(3));
    planner.begin_batch();
    // Replacing a cancelled request retains the old queue slot, as in the live game.
    assert_eq!(planner.next_job(), Some(replacement));
    planner.request(replacement);
    let checkpoint = planner.checkpoint();
    let mut resumed = PathPlanner::restore(&checkpoint).unwrap();
    assert_eq!(checkpoint, resumed.checkpoint());
    for expected in [Some(job(2)), Some(replacement), Some(job(3)), None] {
        assert_eq!(planner.next_job(), expected);
        assert_eq!(resumed.next_job(), expected);
    }
    for queue in [&mut planner, &mut resumed] {
        queue.request(job(4));
        assert_eq!(queue.next_job(), None);
        queue.begin_batch();
        assert_eq!(queue.next_job(), Some(job(4)));
        assert_eq!(queue.next_job(), None);
    }
    assert_eq!(planner.checkpoint(), resumed.checkpoint());
    assert!(!planner.request(job(0)));
    let mut invalid = job(4);
    invalid.care = f64::NAN;
    assert!(!planner.request(invalid));
    planner.request(job(5));
    let before = planner.checkpoint();
    assert!(!planner.restore_queue_order(&[6]));
    assert!(!planner.restore_queue_order(&[0, 5]));
    assert_eq!(before, planner.checkpoint());
    assert!(planner.restore_queue_order(&[6, 5, 5]));
    planner.begin_batch();
    assert_eq!(planner.next_job(), Some(job(5)));
    assert_eq!(planner.next_job(), None);
}

#[test]
fn corridors_resume_with_fire_and_terrain_edits_and_team_specific_danger() {
    let mut planner = PathPlanner::new(64).unwrap();
    let mut graph = Hierarchy::new(64, 16).unwrap();
    build_all(&mut [&mut graph], 1);
    let a = Vector3::new(-20.0, 0.0, -20.0);
    let b = Vector3::new(20.0, 0.0, 20.0);
    let initial = planner.find_path(
        &mut graph,
        a,
        b,
        false,
        -1,
        0.0,
        false,
        frontline_core::traversal::Ground::default(),
    );
    assert_eq!(initial.last(), Some(&b));
    assert!(initial.len() < 10);
    let checkpoint = planner.checkpoint();
    let mut resumed = PathPlanner::restore(&checkpoint).unwrap();
    let mut restored_graph = Hierarchy::restore(&graph.checkpoint()).unwrap();
    for tick in 0..40 {
        let mut danger = vec![0.0; 16];
        danger[tick % 16] = 1.0;
        for (p, g) in [
            (&mut planner, &mut graph),
            (&mut resumed, &mut restored_graph),
        ] {
            g.set_danger(tick % 2, &danger);
            let cell = [31, tick as i32];
            g.set_cell(cell, tick % 2 == 0, 1.0);
            p.set_cell(tick * 64 + 31, if tick % 2 == 0 { 3 } else { 0 }, 0, 0);
            g.update(1);
        }
        let target = b + Vector3::new((tick % 3) as f32, 0.0, 0.0);
        for team in [-1, 0, 1] {
            assert_eq!(
                planner.find_path(
                    &mut graph,
                    a,
                    target,
                    false,
                    team,
                    1.0,
                    false,
                    frontline_core::traversal::Ground::default()
                ),
                resumed.find_path(
                    &mut restored_graph,
                    a,
                    target,
                    false,
                    team,
                    1.0,
                    false,
                    frontline_core::traversal::Ground::default()
                )
            );
        }
        assert_eq!(planner.checkpoint(), resumed.checkpoint());
        assert_eq!(graph.checkpoint(), restored_graph.checkpoint());
    }
    let start = Vector3::new(-30.0, 0.0, -30.0);
    let end = start + Vector3::new(4.0, 0.0, 0.0);
    planner.set_cell(2 * 64 + 4, 0, 0, 1);
    assert!(!planner.line_free(
        start,
        end,
        false,
        false,
        frontline_core::traversal::Ground::default()
    ));
    assert!(planner.line_free(
        start,
        end,
        true,
        false,
        frontline_core::traversal::Ground::default()
    ));
    planner.set_cell(2 * 64 + 2, 0, 0, 1);
    assert!(
        planner.line_free(
            start,
            end,
            false,
            false,
            frontline_core::traversal::Ground::default()
        ),
        "A soldier already in a fire can escape it"
    );
    planner.set_cell(2 * 64 + 4, 1, 0, 1);
    assert!(
        !planner.line_free(
            start,
            end,
            false,
            false,
            frontline_core::traversal::Ground::default()
        ),
        "Smoothing cannot skip a vaultable wall"
    );
}

#[test]
fn planner_rejects_malformed_checkpoint_and_unbounded_geometry() {
    let mut planner = PathPlanner::new(16).unwrap();
    planner.request(job(1));
    planner.begin_batch();
    let bytes = planner.checkpoint();
    for end in 0..bytes.len() {
        assert!(PathPlanner::restore(&bytes[..end]).is_err());
    }
    for offset in [4, 8, 16] {
        let mut bad = bytes.clone();
        bad[offset] = 255;
        assert!(PathPlanner::restore(&bad).is_err());
    }
    let mut bad = bytes;
    bad.push(0);
    assert!(PathPlanner::restore(&bad).is_err());
    assert!(!planner.line_free(
        Vector3::ZERO,
        Vector3::splat(f32::MAX),
        false,
        false,
        frontline_core::traversal::Ground::default()
    ));
    assert!(!planner.line_free(
        Vector3::ZERO,
        Vector3::splat(f32::NAN),
        false,
        false,
        frontline_core::traversal::Ground::default()
    ));
    let mut graph = Hierarchy::new(32, 16).unwrap();
    assert!(planner
        .find_path(
            &mut graph,
            Vector3::ZERO,
            Vector3::ONE,
            false,
            0,
            1.0,
            false,
            frontline_core::traversal::Ground::default()
        )
        .is_empty());
}

#[test]
fn blocked_goals_require_exact_foot_clearance_and_cannot_cross_a_wall() {
    use frontline_core::navigation_scene::NavigationScene;
    use frontline_core::structure::{Part, Structure};
    use frontline_core::terrain::Terrain;
    use frontline_core::traversal::Ground;
    let terrain = Terrain::blank(32).unwrap();
    let mut nav = NavigationScene::new(&terrain, &[], 16).unwrap();
    let mut wall = Structure {
        id: 1,
        kind: "house_wall".into(),
        position: Vector3::new(0.6, 0., 0.),
        parts: vec![Part {
            position: Vector3::ZERO,
            size: Vector3::new(0.6, 2., 4.),
            yaw: 0.,
            infantry: 3,
            vehicle: 3,
            cover: true,
            collision: true,
            door: false,
        }],
        ..Default::default()
    };
    nav.add_structure(&mut wall, &terrain, &[]).unwrap();
    assert!(nav.finalize(1));
    let ground = Ground::new(&terrain, &[]);
    let a = Vector3::new(-0.5, 0., 0.5);
    let padding = Vector3::new(0.1, 0., 0.5);
    let inside = Vector3::new(0.6, 0., 0.5);
    assert_eq!(
        nav.planner
            .find_path(&mut nav.infantry, a, padding, false, -1, 0., false, ground)
            .last(),
        Some(&padding)
    );
    assert_ne!(
        nav.planner
            .find_path(&mut nav.infantry, a, inside, false, -1, 0., false, ground)
            .last(),
        Some(&inside)
    );
}
