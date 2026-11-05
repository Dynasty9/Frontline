use frontline_core::actors::{Actor, Actors};
use frontline_core::infantry::Infantry;
use frontline_core::infantry_action::Action;
use frontline_core::infantry_controller::Task;
use frontline_core::infantry_pose::Posture;
use frontline_core::path_planner::PathPlanner;
use frontline_core::projectile::Kind;
use frontline_core::projectile_actor::{ballistic, Motion, Projectile};
use frontline_core::random::SimulationRandom;
use frontline_core::spatial::{SpatialIndex, UNIT_CELL};
use frontline_core::vector::Vector3;

fn setup(task: Task, position: Vector3, fuse: f64) -> (Actors, SpatialIndex, PathPlanner) {
    let mut s = Infantry::default();
    s.identity.id = 1;
    s.identity.unit = "rifleman".into();
    s.identity.weapon = "rifle".into();
    s.duty.kind = task;
    s.duty.entity = 10;
    s.duty.timer = 10.0;
    s.posture = Posture::Crouch;
    s.activity = 8;
    let mut f = ballistic(Kind::Frag, position, Vector3::new(1.0, 2.0, 3.0));
    f.fuse = fuse;
    let actors = Actors::from_entries(
        100,
        vec![
            Actor::Soldier(Box::new(s)),
            Actor::Projectile(Projectile {
                id: 10,
                team: 1,
                thrower: 0,
                called_by: 0,
                held_by: 0,
                smothered_by: 0,
                handler: 1,
                thrown_back: 0,
                target_id: 0,
                motion: Motion::Ballistic(f),
            }),
        ],
    )
    .unwrap();
    let mut units = SpatialIndex::new(UNIT_CELL).unwrap();
    actors.rebuild_units(&mut units).unwrap();
    (actors, units, PathPlanner::new(32).unwrap())
}

#[test]
fn pickup_retains_the_action_and_changes_the_shared_projectile_atomically() {
    let (mut actors, units, nav) = setup(Task::GrenadePickup, Vector3::X * 0.89, 2.0);
    let mut rng = SimulationRandom::new(7);
    let before = rng;
    let out = actors
        .advance_infantry_grenade_task(1, 1.0 / 30.0, 10.0, None, &units, &nav, &mut rng)
        .unwrap();
    assert!(out.cancel_path && !out.dived);
    let s = actors.soldier(1).unwrap();
    assert_eq!(s.duty.kind, Task::Fight);
    assert_eq!(s.duty.entity, 10);
    assert_eq!(s.action.current, Action::Pickup { grenade: 10 });
    assert_eq!(s.action.remaining, 0.2);
    assert_eq!(s.activity, 21);
    assert_eq!(s.posture, Posture::Stand);
    let Some(Actor::Projectile(p)) = actors.get(10) else {
        panic!()
    };
    assert_eq!(p.held_by, 1);
    let Motion::Ballistic(f) = &p.motion else {
        panic!()
    };
    assert!(!f.flying);
    assert_eq!(f.velocity, Vector3::ZERO);
    assert_eq!(rng, before);
    let saved = actors.checkpoint().unwrap();
    assert_eq!(
        Actors::restore(&saved).unwrap().checkpoint().unwrap(),
        saved
    );
}

#[test]
fn close_kick_only_schedules_the_strike_without_moving_the_round_early() {
    let (mut actors, units, nav) = setup(Task::GrenadeKick, Vector3::X * 0.69, 1.0);
    let round = actors.get(10).unwrap().checkpoint().unwrap();
    let out = actors
        .advance_infantry_grenade_task(
            1,
            0.1,
            10.0,
            None,
            &units,
            &nav,
            &mut SimulationRandom::new(1),
        )
        .unwrap();
    assert!(out.cancel_path && !out.dived);
    let s = actors.soldier(1).unwrap();
    assert_eq!(
        s.action.current,
        Action::Kick {
            grenade: 10,
            velocity: Vector3::new(9.0, 3.0, 0.0)
        }
    );
    assert_eq!(s.action.remaining, 0.3);
    assert_eq!(s.activity, 33);
    assert_eq!(actors.get(10).unwrap().checkpoint().unwrap(), round);
}

#[test]
fn disappearing_grenades_clear_only_the_fields_the_current_duty_owns() {
    for task in [Task::Smother, Task::GrenadeKick, Task::GrenadePickup] {
        let (mut actors, units, nav) = setup(task, Vector3::X, 2.0);
        actors.remove(10);
        let out = actors
            .advance_infantry_grenade_task(
                1,
                0.1,
                10.0,
                None,
                &units,
                &nav,
                &mut SimulationRandom::new(1),
            )
            .unwrap();
        assert!(!out.cancel_path && !out.dived);
        let s = actors.soldier(1).unwrap();
        assert_eq!(s.duty.kind, Task::Fight);
        assert_eq!(s.duty.entity, if task == Task::Smother { 0 } else { 10 });
        assert_eq!(s.activity, if task == Task::Smother { 0 } else { 8 });
        assert_eq!(
            s.posture,
            if task == Task::Smother {
                Posture::Prone
            } else {
                Posture::Crouch
            }
        );
    }
}

#[test]
fn short_fuses_trigger_a_dive_at_the_existing_strict_thresholds() {
    for (task, threshold) in [(Task::GrenadeKick, 0.35), (Task::GrenadePickup, 0.7)] {
        for delta in [-0.001, 0.0] {
            let (mut actors, units, nav) = setup(task, Vector3::X * 2.0, threshold + delta);
            let out = actors
                .advance_infantry_grenade_task(
                    1,
                    0.1,
                    10.0,
                    None,
                    &units,
                    &nav,
                    &mut SimulationRandom::new(1),
                )
                .unwrap();
            assert_eq!(out.dived, delta < 0.0);
            let s = actors.soldier(1).unwrap();
            if out.dived {
                assert_eq!(s.controller.dive_direction, Vector3::NEG_X);
                assert_eq!(s.controller.dive_timer, 0.5);
            } else {
                assert_eq!(s.duty.kind, task);
                assert_eq!(s.activity, 2);
            }
        }
    }
}

#[test]
fn smothering_moves_towards_the_chest_position_then_stays_over_the_round() {
    let (mut actors, units, nav) = setup(Task::Smother, Vector3::new(0.0, 0.0, -1.0), 1.5);
    let mut rng = SimulationRandom::new(1);
    actors
        .advance_infantry_grenade_task(1, 0.01, 10.0, None, &units, &nav, &mut rng)
        .unwrap();
    let s = actors.soldier(1).unwrap();
    assert_eq!(s.posture, Posture::Prone);
    assert_eq!(s.activity, 15);
    assert!(s.motion.position.z < 0.0);
    let before = s.motion.position;
    actors
        .advance_infantry_grenade_task(1, 0.1, 11.0, None, &units, &nav, &mut rng)
        .unwrap();
    let s = actors.soldier(1).unwrap();
    assert_eq!(s.activity, 34);
    assert_eq!(s.motion.position, before);
}

#[test]
fn rejected_pickup_keeps_the_round_flying_and_preserves_randomness() {
    let (actors, units, nav) = setup(Task::GrenadePickup, Vector3::X * 0.2, 2.0);
    let mut entries: Vec<_> = actors.iter().cloned().collect();
    let Actor::Soldier(s) = &mut entries[0] else {
        panic!()
    };
    s.orders.path_revision = i64::MAX as u64;
    let mut actors = Actors::from_entries(100, entries).unwrap();
    let saved = actors.checkpoint().unwrap();
    let mut rng = SimulationRandom::new(71);
    let before = rng;
    assert!(actors
        .advance_infantry_grenade_task(1, 0.1, 10.0, None, &units, &nav, &mut rng)
        .is_err());
    assert_eq!(actors.checkpoint().unwrap(), saved);
    assert_eq!(rng, before);
}
