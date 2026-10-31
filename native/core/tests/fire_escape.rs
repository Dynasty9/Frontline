use frontline_core::infantry::{Goal, Infantry};
use frontline_core::infantry_controller::Task;
use frontline_core::infantry_vitals::Life;
use frontline_core::path_planner::PathPlanner;
use frontline_core::random::SimulationRandom;
use frontline_core::vector::Vector3;

fn soldier() -> Infantry {
    let mut s = Infantry::default();
    s.identity.id = 1;
    s.identity.unit = "rifleman".into();
    s.cover.at_cover = true;
    s.cover.structure = 20;
    s.cover.anchor = 3;
    s.weapon.peek_up = true;
    s.weapon.blind = true;
    s
}

#[test]
fn fire_clears_shelter_and_routes_away_without_changing_the_task() {
    let mut s = soldier();
    let nav = PathPlanner::new(64).unwrap();
    let mut rng = SimulationRandom::new(823);
    s.duty.kind = Task::Heal;
    let out = s
        .flee_fire(Vector3::Z * 3.0, 10.0, &nav, &mut rng)
        .unwrap()
        .unwrap();
    assert_eq!(out.route.job.destination, -Vector3::Z * 7.0);
    assert_eq!(s.orders.purpose, Goal::Slot);
    assert_eq!(s.orders.move_mode, 2);
    assert_eq!(s.duty.kind, Task::Heal);
    assert!(!s.cover.at_cover && !s.weapon.peek_up && !s.weapon.blind);
    assert_eq!(s.cover.structure, 0);
    assert_eq!(s.cover.anchor, -1);
    assert_eq!(s.fight.flee_fire_at, 12.5);
    assert_eq!(s.cover.evaluate_at, 12.0);
    assert!(s
        .flee_fire(Vector3::ZERO, 12.499, &nav, &mut rng)
        .unwrap()
        .is_none());
    assert!(s
        .flee_fire(Vector3::ZERO, 12.5, &nav, &mut rng)
        .unwrap()
        .is_some());
}

#[test]
fn casualty_transport_and_committed_duties_do_not_draw_or_change_state() {
    let nav = PathPlanner::new(64).unwrap();
    for mode in 0..9 {
        let mut s = soldier();
        match mode {
            0 => s.vitals.life = Life::Downed,
            1 => s.vitals.life = Life::Dead,
            2 => s.vitals.life = Life::Surrender,
            3 => s.emplacement.structure = 20,
            4 => s.links.vehicle = 30,
            5 => s.duty.kind = Task::Smother,
            6 => s.duty.kind = Task::Stretcher,
            7 => s.duty.kind = Task::Tunnel,
            _ => s.activity = 15,
        }
        let before = s.checkpoint().unwrap();
        let mut rng = SimulationRandom::new(823);
        let cursor = rng.state();
        assert!(s
            .flee_fire(Vector3::ZERO, 10.0, &nav, &mut rng)
            .unwrap()
            .is_none());
        assert_eq!(s.checkpoint().unwrap(), before);
        assert_eq!(rng.state(), cursor);
    }
}

#[test]
fn random_direction_and_forced_shouting_keep_their_draw_order() {
    let nav = PathPlanner::new(64).unwrap();
    for distance in [0.0f32, 0.0999, 0.1, 0.1001, 3.0] {
        for seed in 0..64 {
            let mut s = soldier();
            s.vitals.speech_cooldown = 9.0;
            let mut rng = SimulationRandom::new(seed);
            let mut expected = rng;
            if f64::from(distance) <= 0.1 {
                expected.randf();
            }
            let speech = if expected.randf() < 0.4 {
                Some((expected.randi() % 4) as u8)
            } else {
                None
            };
            let out = s
                .flee_fire(Vector3::X * distance, 10.0, &nav, &mut rng)
                .unwrap()
                .unwrap();
            assert_eq!(out.speech, speech);
            assert_eq!(rng.state(), expected.state());
            assert_eq!(
                s.vitals.speech_cooldown,
                if speech.is_some() { 2.6 } else { 9.0 }
            );
            assert!((out.route.job.destination.length() - 7.0).abs() < 0.00001);
        }
    }
}

#[test]
fn rejected_routes_do_not_consume_randomness_or_partly_clear_cover() {
    let nav = PathPlanner::new(64).unwrap();
    for mode in 0..3 {
        let mut s = soldier();
        if mode == 0 {
            s.orders.path_revision = i64::MAX as u64;
        }
        if mode == 1 {
            s.motion.position = Vector3::X * 1_000_000.0;
        }
        let before = s.checkpoint().unwrap();
        let mut rng = SimulationRandom::new(823);
        let cursor = rng.state();
        assert!(s
            .flee_fire(
                Vector3::ZERO,
                if mode == 2 { f64::NAN } else { 10.0 },
                &nav,
                &mut rng
            )
            .is_err());
        assert_eq!(s.checkpoint().unwrap(), before);
        assert_eq!(rng.state(), cursor);
    }
}
