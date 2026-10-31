use frontline_core::infantry_medicine::{self as medicine, EscortInput, Heal, Rescue, Treatment};
use frontline_core::path_planner::PathPlanner;
use frontline_core::vector::Vector3;

#[test]
fn rescue_repaths_claims_drags_and_treats_in_order() {
    let mut task = Treatment::default();
    let patient = Vector3::Z * 4.0;
    assert_eq!(
        task.rescue(false, Vector3::ZERO, patient, true, patient)
            .unwrap(),
        Rescue::Cancel
    );
    assert_eq!(
        task.rescue(true, Vector3::ZERO, patient, true, patient)
            .unwrap(),
        Rescue::Approach { repath: false }
    );
    assert_eq!(
        task.rescue(true, Vector3::ZERO, patient, false, patient)
            .unwrap(),
        Rescue::Approach { repath: true }
    );
    assert_eq!(
        task.rescue(true, Vector3::ZERO, patient, true, Vector3::ZERO)
            .unwrap(),
        Rescue::Approach { repath: true }
    );
    assert_eq!(
        task.rescue(true, patient, patient, true, patient).unwrap(),
        Rescue::Claim
    );
    assert_eq!(task.phase, 1);
    assert!(!task.finish_drag(true, 8.0).unwrap());
    assert_eq!(
        task.rescue(true, patient, patient, true, patient).unwrap(),
        Rescue::Drag
    );
    assert!(task.finish_drag(false, 8.0).unwrap());
    assert_eq!(
        task.rescue(true, patient, patient, false, patient).unwrap(),
        Rescue::Treat
    );
    assert_eq!(task.phase, 2);
    assert!(!task.treat(7.9).unwrap());
    assert!(task.treat(0.2).unwrap());
}

#[test]
fn ordinary_healing_preserves_range_duration_and_checkpoint_resume() {
    let mut task = Treatment::default();
    let position = Vector3::ZERO;
    assert_eq!(
        task.heal(true, position, Vector3::X * 1.5, false, 8.0)
            .unwrap(),
        Heal::Approach { repath: true }
    );
    assert_eq!(
        task.heal(true, position, Vector3::X * 1.5, true, 8.0)
            .unwrap(),
        Heal::Approach { repath: false }
    );
    assert_eq!(
        task.heal(true, position, Vector3::X, true, 8.0).unwrap(),
        Heal::Start
    );
    assert_eq!(
        task,
        Treatment {
            phase: 1,
            timer: 4.8
        }
    );
    assert_eq!(
        task.heal(false, position, Vector3::X, false, 8.0).unwrap(),
        Heal::Cancel
    );
    assert_eq!(
        task.heal(true, position, Vector3::X, false, 8.0).unwrap(),
        Heal::Treat
    );
    let mut resumed = Treatment::restore(&task.checkpoint()).unwrap();
    for _ in 0..150 {
        assert_eq!(task.treat(1.0 / 30.0), resumed.treat(1.0 / 30.0));
        assert_eq!(task, resumed);
    }
    assert_eq!(medicine::heal_time(2.0, false).unwrap(), 4.0);
    assert_eq!(medicine::heal_time(2.0, true).unwrap(), 4.0 * 0.67);
    assert!(medicine::heal_time(0.0, true).is_err());
}

#[test]
fn escorts_keep_their_side_and_walk_animation_when_ground_blocks_them() {
    let mut nav = PathPlanner::new(32).unwrap();
    let i = EscortInput {
        position: Vector3::new(0.0, 0.0, 5.0),
        yaw: 0.0,
        rescuer: Vector3::ZERO,
        threat: Vector3::Z,
        dt: 1.0 / 30.0,
        mount: None,
    };
    let moved = medicine::escort(i, &nav).unwrap();
    assert!(moved.backwards && moved.walking && moved.position.z < 5.0 && moved.position.x < 0.0);
    assert!(nav.load_cells(&[3; 1024], &[0; 1024], &[0; 1024]));
    let blocked = medicine::escort(i, &nav).unwrap();
    assert_eq!(blocked.position, i.position);
    assert!(blocked.backwards && blocked.walking);
    let drag =
        medicine::drag_pose(Vector3::new(2.0, 1.7, 3.0), 0.0, Vector3::Z, 0.1, None).unwrap();
    assert_eq!(drag.yaw, 0.0);
    assert_eq!(drag.patient, Vector3::new(2.0, 0.0, 1.95));
}

#[test]
fn casualty_shelter_uses_a_nearby_squad_order_only_when_it_is_away_from_fire() {
    let nav = PathPlanner::new(64).unwrap();
    let at = Vector3::ZERO;
    assert_eq!(
        medicine::safe_anchor(at, Vector3::Z, None, &nav).unwrap(),
        Vector3::Z * 11.0
    );
    assert_eq!(
        medicine::safe_anchor(at, Vector3::Z, Some(Vector3::Z * 20.0), &nav).unwrap(),
        Vector3::Z * 20.0
    );
    for order in [Vector3::Z * 22.0, -Vector3::Z, Vector3::X * 10.0] {
        assert_eq!(
            medicine::safe_anchor(at, Vector3::Z, Some(order), &nav).unwrap(),
            Vector3::Z * 11.0
        );
    }
}

#[test]
fn bad_medical_state_is_rejected_without_advancing_treatment() {
    let mut task = Treatment {
        phase: 2,
        timer: 0.5,
    };
    let before = task;
    assert!(task.treat(f64::NAN).is_err());
    assert_eq!(task, before);
    assert!(task.finish_drag(false, -1.0).is_err());
    assert_eq!(task, before);
    let mut bytes = task.checkpoint();
    bytes.push(0);
    assert!(Treatment::restore(&bytes).is_err());
    bytes.pop();
    bytes[8] = 3;
    assert!(Treatment::restore(&bytes).is_err());
}
