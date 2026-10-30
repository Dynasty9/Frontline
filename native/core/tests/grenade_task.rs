use frontline_core::grenade_task::{self as task, Action, Grenade, Input, Task};
use frontline_core::path_planner::PathPlanner;
use frontline_core::random::SimulationRandom;
use frontline_core::vector::Vector3 as V;

fn input(kind: Task) -> Input {
    Input {
        task: kind,
        position: V::ZERO,
        yaw: 0.0,
        time: 10.0,
        started: 10.0,
        dt: 0.1,
        grenade: Some(Grenade {
            position: V::X * 2.0,
            fuse: 2.0,
            gone: false,
            held: false,
            held_by_self: false,
        }),
        mount: None,
    }
}

#[test]
fn grenade_tasks_preserve_pickup_and_kick_deadlines_and_holder_rules() {
    let nav = PathPlanner::new(16).unwrap();
    for (kind, deadline) in [(Task::Kick, 0.35), (Task::Pickup, 0.7)] {
        let mut i = input(kind);
        i.grenade.as_mut().unwrap().fuse = deadline;
        assert_eq!(task::advance(i, &nav).unwrap().action, Action::Run);
        i.grenade.as_mut().unwrap().fuse -= 0.001;
        assert_eq!(task::advance(i, &nav).unwrap().action, Action::DiveAway);
        i.grenade.as_mut().unwrap().gone = true;
        assert_eq!(task::advance(i, &nav).unwrap().action, Action::Cancel);
    }
    let mut i = input(Task::Pickup);
    i.grenade.as_mut().unwrap().held = true;
    assert_eq!(task::advance(i, &nav).unwrap().action, Action::Cancel);
    i.grenade.as_mut().unwrap().held_by_self = true;
    assert_eq!(task::advance(i, &nav).unwrap().action, Action::Run);
    i.task = Task::Kick;
    assert_eq!(task::advance(i, &nav).unwrap().action, Action::DiveAway);
}

#[test]
fn smothering_stops_after_one_second_and_blocks_only_when_the_chest_covers_the_grenade() {
    let nav = PathPlanner::new(16).unwrap();
    let mut i = input(Task::Smother);
    let moving = task::advance(i, &nav).unwrap();
    assert_eq!(moving.action, Action::DiveOnto);
    assert!((moving.position.length() - 0.65).abs() < 1e-6);
    i.time += 1.0;
    assert_eq!(task::advance(i, &nav).unwrap().action, Action::Smother);
    assert!(task::covers_grenade(V::Z * 0.75, 0.0, V::ZERO).unwrap());
    assert!(!task::covers_grenade(V::Z * 2.0, 0.0, V::ZERO).unwrap());
}

#[test]
fn blocked_approaches_keep_facing_the_grenade_and_dives_only_draw_randomness_at_the_origin() {
    let mut nav = PathPlanner::new(16).unwrap();
    nav.load_cells(&[3; 256], &[0; 256], &[0; 256]);
    let result = task::advance(input(Task::Pickup), &nav).unwrap();
    assert_eq!(result.position, V::ZERO);
    assert!(result.yaw < 0.0);
    assert_eq!(result.action, Action::Run);
    let mut rng = SimulationRandom::new(13);
    let before = rng;
    assert_eq!(task::dive_direction(V::X, V::ZERO, &mut rng).unwrap(), V::X);
    assert_eq!(rng, before);
    let mut expected = rng;
    expected.randf();
    let direction = task::dive_direction(V::ZERO, V::ZERO, &mut rng).unwrap();
    assert!((direction.length() - 1.0).abs() < 1e-6);
    assert_eq!(rng, expected);
    assert!(task::dive_direction(V::NAN, V::ZERO, &mut rng).is_err());
    assert_eq!(rng, expected);
}
