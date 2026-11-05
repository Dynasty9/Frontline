use frontline_core::infantry::{Goal, Identity, Infantry};
use frontline_core::infantry_controller::Task;
use frontline_core::infantry_orders::{Arrival, PathFinish};
use frontline_core::infantry_vitals::Life;
use frontline_core::random::SimulationRandom;
use frontline_core::vector::Vector3;

fn soldier() -> Infantry {
    Infantry {
        identity: Identity {
            id: 17,
            unit: "rifleman".into(),
            ..Default::default()
        },
        ..Default::default()
    }
}

#[test]
fn route_revisions_reject_superseded_and_cancelled_completions() {
    let mut s = soldier();
    let mut rng = SimulationRandom::new(31);
    let before = rng;
    let first = s.go_to(Vector3::X * 10.0, Goal::Slot, 0).unwrap();
    assert_eq!(first.job.care, 0.8);
    assert!(s.is_moving());
    let second = s.go_to(Vector3::Z * 11.0, Goal::Slot, 1).unwrap();
    assert_eq!(second.job.care, 0.35);
    let pending = s.clone();
    assert_eq!(
        s.accept_path(first.revision, vec![Vector3::X], 1.0, &mut rng)
            .unwrap(),
        PathFinish::Ignored
    );
    assert_eq!(s, pending);
    s.stop_moving().unwrap();
    let stopped = s.clone();
    assert!(!s.is_moving());
    assert_eq!(
        s.accept_path(second.revision, vec![], 1.0, &mut rng)
            .unwrap(),
        PathFinish::Ignored
    );
    assert_eq!(s, stopped);
    assert_eq!(rng, before);
}

#[test]
fn unsafe_routes_release_cover_and_do_not_consume_arrival_randomness() {
    let mut s = soldier();
    s.cover.at_cover = true;
    s.cover.normal = Vector3::X;
    s.cover.height = 1.2;
    s.cover.material = 2;
    s.cover.structure = 42;
    s.cover.anchor = 3;
    s.cover.shifting = true;
    s.weapon.blind = true;
    let order = s.go_to(Vector3::Z * 10.0, Goal::Cover, 2).unwrap();
    let mut rng = SimulationRandom::new(17);
    let before = rng;
    assert_eq!(
        s.accept_path(order.revision, vec![], 123.4, &mut rng)
            .unwrap(),
        PathFinish::Unreachable
    );
    assert_eq!(s.cover.evaluate_at, 124.4);
    assert_eq!(s.cover.normal, Vector3::ZERO);
    assert_eq!(
        (s.cover.structure, s.cover.anchor, s.cover.material),
        (0, -1, -1)
    );
    assert!(!s.cover.at_cover);
    assert!(!s.is_moving());
    assert!(!s.weapon.blind);
    assert!(!s.cover.shifting);
    assert_eq!(s.orders.purpose, Goal::None);
    assert_eq!(s.orders.path_revision, order.revision + 1);
    assert_eq!(rng, before);
}

#[test]
fn cover_and_prison_arrivals_preserve_draws_facing_and_effect_admission() {
    let mut s = soldier();
    let mut rng = SimulationRandom::new(73);
    let mut expected = rng;
    s.cover.normal = Vector3::new(0.3, 0.0, 0.7);
    s.cover.shifting = true;
    s.motion.slide_timer = 0.5;
    let order = s.go_to(Vector3::X, Goal::Cover, 1).unwrap();
    assert_eq!(
        s.accept_path(order.revision, vec![], 100.0, &mut rng)
            .unwrap(),
        PathFinish::Arrived(Arrival::None)
    );
    assert!(s.cover.at_cover);
    assert!(!s.cover.shifting);
    assert_eq!(s.motion.slide_timer, 0.0);
    assert_eq!(
        s.weapon.peek_timer,
        f64::from(expected.randf_range(0.3, 1.0))
    );
    assert_ne!(s.motion.yaw, 0.0);
    assert_eq!(rng, expected);
    s.go_to(Vector3::ZERO, Goal::Prison, 0).unwrap();
    assert_eq!(s.arrived(100.0, &mut rng).unwrap(), Arrival::Prison);
    assert_eq!(rng, expected);
    s.orders.purpose = Goal::Cover;
    s.weapon.last_shot = 100.0;
    s.motion.yaw = 0.75;
    s.arrived(100.5, &mut rng).unwrap();
    assert_eq!(s.motion.yaw, 0.75);
}

#[test]
fn retained_path_completion_resumes_after_a_checkpoint_and_ignores_hidden_actors() {
    for life in [
        Life::Alive,
        Life::Downed,
        Life::Dead,
        Life::Hidden,
        Life::Surrender,
        Life::Captive,
    ] {
        let mut s = soldier();
        s.vitals.life = life;
        s.duty.kind = Task::Retreat;
        let request = s.go_to(Vector3::Z * 10.0, Goal::Task, 2).unwrap();
        assert_eq!(request.job.care, 1.6);
        let mut restored = Infantry::restore(&s.checkpoint().unwrap()).unwrap();
        let mut rng = SimulationRandom::new(31);
        let mut rr = rng;
        let path = vec![Vector3::X, Vector3::Z * 10.0];
        let a = s
            .accept_path(request.revision, path.clone(), 100.0, &mut rng)
            .unwrap();
        assert_eq!(
            a,
            restored
                .accept_path(request.revision, path, 100.0, &mut rr)
                .unwrap()
        );
        assert_eq!(s, restored);
        assert_eq!(rng, rr);
        assert_eq!(
            a == PathFinish::Ignored,
            matches!(life, Life::Dead | Life::Hidden)
        );
        assert!(!s.orders.pending_path);
    }
}

#[test]
fn malformed_orders_and_exhausted_revisions_leave_retained_state_unchanged() {
    let mut s = soldier();
    let mut rng = SimulationRandom::new(137);
    let before = s.clone();
    let random = rng;
    assert!(s.go_to(Vector3::NAN, Goal::Cover, 0).is_err());
    assert!(s.go_to(Vector3::ZERO, Goal::Cover, 3).is_err());
    assert!(s.accept_path(0, vec![Vector3::NAN], 0.0, &mut rng).is_err());
    assert!(s.arrived(f64::NAN, &mut rng).is_err());
    assert_eq!(s, before);
    s.orders.path_revision = i64::MAX as u64;
    s.orders.goal = Vector3::Z * 10.0;
    let before = s.clone();
    assert!(s.stop_moving().is_err());
    assert!(s.go_to(Vector3::X, Goal::Cover, 0).is_err());
    assert!(s
        .accept_path(i64::MAX as u64, vec![], 0.0, &mut rng)
        .is_err());
    assert_eq!(s, before);
    assert_eq!(rng, random);
}
