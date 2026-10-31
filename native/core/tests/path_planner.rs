use frontline_core::hierarchy::{build_all, Hierarchy};
use frontline_core::path_planner::{PathJob, PathPlanner};
use frontline_core::vector::Vector3;

fn job(id: u64) -> PathJob {
    PathJob {
        id,
        destination: Vector3::new(20.0, 0.0, 20.0),
        vehicle: false,
        team: -1,
        care: 0.0,
    }
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
    let initial = planner.find_path(&mut graph, a, b, false, -1, 0.0);
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
                planner.find_path(&mut graph, a, target, false, team, 1.0),
                resumed.find_path(&mut restored_graph, a, target, false, team, 1.0)
            );
        }
        assert_eq!(planner.checkpoint(), resumed.checkpoint());
        assert_eq!(graph.checkpoint(), restored_graph.checkpoint());
    }
    let start = Vector3::new(-30.0, 0.0, -30.0);
    let end = start + Vector3::new(4.0, 0.0, 0.0);
    planner.set_cell(2 * 64 + 4, 0, 0, 1);
    assert!(!planner.line_free(start, end, false));
    assert!(planner.line_free(start, end, true));
    planner.set_cell(2 * 64 + 2, 0, 0, 1);
    assert!(
        planner.line_free(start, end, false),
        "A soldier already in a fire can escape it"
    );
    planner.set_cell(2 * 64 + 4, 1, 0, 1);
    assert!(
        !planner.line_free(start, end, false),
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
    assert!(!planner.line_free(Vector3::ZERO, Vector3::splat(f32::MAX), false));
    assert!(!planner.line_free(Vector3::ZERO, Vector3::splat(f32::NAN), false));
    let mut graph = Hierarchy::new(32, 16).unwrap();
    assert!(planner
        .find_path(&mut graph, Vector3::ZERO, Vector3::ONE, false, 0, 1.0)
        .is_empty());
}
