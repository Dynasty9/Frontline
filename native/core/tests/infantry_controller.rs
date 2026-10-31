use frontline_core::infantry_action::ActionState;
use frontline_core::infantry_controller::{self as controller, Controller, Stage, Task};
use frontline_core::infantry_shock::InfantryShock;
use frontline_core::infantry_vitals::Life;
use frontline_core::path_planner::PathPlanner;
use frontline_core::random::SimulationRandom;
use frontline_core::vector::Vector3;

#[test]
fn interruptions_short_circuit_before_lower_priority_clocks_or_random_draws() {
    let mut c = Controller {
        think_timer: 0.1,
        dive_timer: 0.2,
        ..Default::default()
    };
    let mut shock = InfantryShock {
        dazed_timer: 0.2,
        flinch_timer: 0.2,
        ..Default::default()
    };
    let mut action = ActionState {
        remaining: 0.2,
        ..Default::default()
    };
    let mut rng = SimulationRandom::new(137);
    let before = rng;
    assert_eq!(
        c.advance(0.1, &mut shock, &mut action, &mut rng)
            .unwrap()
            .stage,
        Stage::Dazed
    );
    assert_eq!(
        (
            c.think_timer,
            c.dive_timer,
            shock.flinch_timer,
            action.remaining
        ),
        (0.1, 0.2, 0.2, 0.2)
    );
    shock.dazed_timer = 0.0;
    assert_eq!(
        c.advance(0.1, &mut shock, &mut action, &mut rng)
            .unwrap()
            .stage,
        Stage::Dive
    );
    c.dive_timer = 0.0;
    assert_eq!(
        c.advance(0.2, &mut shock, &mut action, &mut rng)
            .unwrap()
            .stage,
        Stage::Action
    );
    assert_eq!(action.remaining, 0.0);
    assert_eq!(
        c.advance(0.1, &mut shock, &mut action, &mut rng)
            .unwrap()
            .stage,
        Stage::Flinch
    );
    assert_eq!(c.think_timer, 0.1);
    assert_eq!(rng, before);
    let out = c.advance(0.1, &mut shock, &mut action, &mut rng).unwrap();
    assert_eq!(out.stage, Stage::Think);
    assert!(out.flinch_ended);
    assert!((0.24..=0.34).contains(&c.think_timer));
    assert_ne!(rng, before);
}

#[test]
fn scan_and_activity_deadlines_preserve_the_existing_cadence() {
    let mut c = Controller::default();
    assert!(c.activity_due(0.0).unwrap());
    assert_eq!(c.activity_timer, 0.25);
    assert!(!c.activity_due(0.1).unwrap());
    assert!(c.activity_due(0.15).unwrap());
    assert!(!c.scan_due(true).unwrap());
    assert!(c.scan_due(true).unwrap());
    assert!(c.scan_due(false).unwrap());
    assert_eq!(c.scan_number, 3);
    for life in [
        Life::Downed,
        Life::Dead,
        Life::Hidden,
        Life::Captive,
        Life::Surrender,
    ] {
        assert!(!controller::continue_after_think(life, 0.0, 0.0).unwrap());
    }
    assert!(controller::continue_after_think(Life::Alive, 0.0, 0.0).unwrap());
    assert!(!controller::continue_after_think(Life::Alive, 0.1, 0.0).unwrap());
    assert!(!controller::continue_after_think(Life::Alive, 0.0, 0.1).unwrap());
}

#[test]
fn dives_preserve_blocked_motion_and_finish_on_the_expiry_tick() {
    let mut nav = PathPlanner::new(16).unwrap();
    nav.load_cells(&vec![3; 256], &vec![3; 256], &vec![0; 256]);
    let mut c = Controller {
        dive_timer: 0.1,
        dive_direction: Vector3::X,
        ..Default::default()
    };
    let out = c.dive(Vector3::Y, 0.0, 0.1, &nav).unwrap();
    assert_eq!(out.position, Vector3::new(0.0, 0.7, 0.0));
    assert!(out.finished);
    nav.load_cells(&vec![0; 256], &vec![0; 256], &vec![0; 256]);
    c.dive_timer = 0.1;
    let out = c.dive(Vector3::ZERO, 0.2, 0.1, &nav).unwrap();
    assert_eq!(out.position, Vector3::new(0.55, 0.2, 0.0));
    assert!(out.finished);
}

#[test]
fn busy_and_order_gates_distinguish_rescue_from_retreat() {
    for task in [Task::Stretcher, Task::Captor, Task::Limp, Task::Tunnel] {
        assert!(task.busy(0, false));
        assert!(!task.can_take_orders(Life::Alive, 0));
        assert!(!task.can_retreat(Life::Alive));
    }
    assert!(Task::Rescue.can_take_orders(Life::Alive, 0));
    assert!(!Task::Rescue.can_take_orders(Life::Alive, 1));
    assert!(Task::Rescue.can_retreat(Life::Alive));
    assert!(Task::Retreat.can_take_orders(Life::Alive, 0));
    assert!(Task::Retreat.busy(0, false));
    assert!(Task::Fight.busy(0, true));
    assert!(!Task::Build.busy(0, false));
    for task in 0..20 {
        assert!(!Task::try_from(task)
            .unwrap()
            .can_take_orders(Life::Hidden, 0));
    }
}

#[test]
fn controller_checkpoint_and_invalid_input_preserve_state_and_rng() {
    let mut c = Controller {
        think_timer: 0.1,
        scan_number: 37,
        activity_timer: 0.2,
        dive_timer: 0.0,
        dive_direction: Vector3::X,
    };
    let saved = c.checkpoint();
    let mut restored = Controller::restore(&saved).unwrap();
    let mut rng = SimulationRandom::new(713);
    let mut rr = rng;
    for _ in 0..60 {
        assert_eq!(
            c.advance(
                1.0 / 30.0,
                &mut InfantryShock::default(),
                &mut ActionState::default(),
                &mut rng
            ),
            restored.advance(
                1.0 / 30.0,
                &mut InfantryShock::default(),
                &mut ActionState::default(),
                &mut rr
            )
        );
        assert_eq!(c.checkpoint(), restored.checkpoint());
        assert_eq!(rng, rr);
    }
    let before = c;
    let mut shock = InfantryShock::default();
    let mut action = ActionState::default();
    assert!(c
        .advance(f64::NAN, &mut shock, &mut action, &mut rng)
        .is_err());
    assert_eq!(c, before);
    assert_eq!(rng, rr);
    assert_eq!(shock, InfantryShock::default());
    assert_eq!(action, ActionState::default());
    for n in 0..saved.len() {
        assert!(Controller::restore(&saved[..n]).is_err());
    }
    let mut bad = saved.clone();
    bad[6] = 0;
    assert!(Controller::restore(&bad).is_err());
    let mut bad = saved.clone();
    bad.push(0);
    assert!(Controller::restore(&bad).is_err());
    let mut exhausted = Controller {
        scan_number: i64::MAX as u64,
        ..Default::default()
    };
    assert!(exhausted.scan_due(true).is_err());
    assert_eq!(exhausted.scan_number, i64::MAX as u64);
}
