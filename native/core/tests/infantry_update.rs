use frontline_core::collision::CollisionWorld;
use frontline_core::infantry::{Goal, Identity, Infantry};
use frontline_core::infantry_controller::Task;
use frontline_core::infantry_motion::{Door, Neighbor};
use frontline_core::infantry_orders::Arrival;
use frontline_core::infantry_pose::Posture;
use frontline_core::infantry_update::{ActivityContext, Movement};
use frontline_core::infantry_vitals::Life;
use frontline_core::path_planner::PathPlanner;
use frontline_core::random::SimulationRandom;
use frontline_core::terrain::Terrain;
use frontline_core::vector::Vector3;

fn soldier() -> Infantry {
    Infantry {
        identity: Identity {
            id: 1,
            unit: "rifleman".into(),
            ..Default::default()
        },
        ..Default::default()
    }
}
fn movement() -> Movement {
    Movement {
        dt: 1.0 / 30.0,
        time: 100.0,
        speed: 3.4,
        danger: false,
        has_doors: false,
        door_still_closed: false,
        mount: None,
    }
}

#[test]
fn retained_routes_replan_and_apply_cover_or_prison_arrivals() {
    let nav = PathPlanner::new(32).unwrap();
    let terrain = Terrain::blank(32).unwrap();
    let mut collision = CollisionWorld::default();
    let mut rng = SimulationRandom::new(137);
    let mut s = soldier();
    s.orders.purpose = Goal::Cover;
    s.orders.move_mode = 2;
    s.motion.path = vec![Vector3::X * 5.0];
    s.motion.stuck_timer = 3.0;
    let out = s
        .move_route(
            movement(),
            &nav,
            &terrain,
            &mut collision,
            &mut rng,
            &[],
            &[],
        )
        .unwrap();
    assert!(out.moving);
    assert_eq!(out.route.unwrap().job.destination, Vector3::X * 5.0);
    assert!(s.orders.pending_path);
    assert_eq!(s.motion.stuck_timer, 0.0);
    s.accept_path(s.orders.path_revision, vec![Vector3::ZERO], 100.0, &mut rng)
        .unwrap();
    s.cover.normal = Vector3::X;
    let before = rng;
    let out = s
        .move_route(
            movement(),
            &nav,
            &terrain,
            &mut collision,
            &mut rng,
            &[],
            &[],
        )
        .unwrap();
    assert!(!out.moving);
    assert_eq!(out.arrival, Arrival::None);
    assert!(s.cover.at_cover);
    assert_eq!(s.orders.purpose, Goal::None);
    assert!(s.motion.path.is_empty());
    assert_ne!(rng, before);
    s.orders.purpose = Goal::Prison;
    s.motion.path = vec![Vector3::ZERO];
    let out = s
        .move_route(
            movement(),
            &nav,
            &terrain,
            &mut collision,
            &mut rng,
            &[],
            &[],
        )
        .unwrap();
    assert_eq!(out.arrival, Arrival::Prison);
}

#[test]
fn opened_door_reports_the_position_before_the_actor_steps_through_it() {
    let mut s = soldier();
    s.motion.path = vec![Vector3::Z * 8.0];
    s.motion.door = 10;
    s.motion.door_wait = 0.01;
    s.motion.door_kick = true;
    let nav = PathPlanner::new(32).unwrap();
    let terrain = Terrain::blank(32).unwrap();
    let mut collision = CollisionWorld::default();
    let mut rng = SimulationRandom::new(137);
    let out = s
        .move_route(
            Movement {
                has_doors: true,
                door_still_closed: true,
                ..movement()
            },
            &nav,
            &terrain,
            &mut collision,
            &mut rng,
            &[],
            &[],
        )
        .unwrap();
    let door = out.opened_door.unwrap();
    assert_eq!(door.id, 10);
    assert!(door.kicked);
    assert_eq!(door.by_position, Vector3::ZERO);
    assert!(s.motion.position.z > 0.0);
    assert_eq!(s.motion.door, 0);
}

#[test]
fn separation_and_stationary_updates_keep_carriers_and_prone_soldiers_in_place() {
    let mut s = soldier();
    let mut rng = SimulationRandom::new(137);
    let before = rng;
    let neighbor = [Neighbor {
        id: 2,
        position: Vector3::ZERO,
        life: Life::Alive,
    }];
    s.duty.kind = Task::Stretcher;
    s.compute_separation(&neighbor, &mut rng).unwrap();
    assert_eq!(rng, before);
    assert_eq!(s.fight.separation, Vector3::ZERO);
    s.duty.kind = Task::Fight;
    s.compute_separation(&neighbor, &mut rng).unwrap();
    assert_ne!(rng, before);
    let nav = PathPlanner::new(32).unwrap();
    let terrain = Terrain::blank(32).unwrap();
    s.posture = Posture::Prone;
    s.stand(0.1, 100.0, false, None, &nav, &terrain, &[])
        .unwrap();
    assert_eq!(s.motion.position, Vector3::ZERO);
    assert!(!s.fight.shuffling);
    s.posture = Posture::Stand;
    s.stand(0.1, 100.1, false, None, &nav, &terrain, &[])
        .unwrap();
    assert_ne!(s.motion.position, Vector3::ZERO);
    assert!(s.fight.shuffling);
}

#[test]
fn recovery_fatigue_and_observation_updates_use_actor_state_and_preserve_priority() {
    let mut s = soldier();
    s.vitals.suppression = 90.0;
    s.cover.at_cover = true;
    s.cover.kind = 1;
    s.cover.material = 3;
    s.vitals.last_suppression = 99.9;
    s.recover(1.0, 100.0).unwrap();
    assert_eq!(s.vitals.suppression, 74.0);
    s.orders.pending_path = true;
    s.orders.move_mode = 2;
    s.duty.kind = Task::Rescue;
    s.fatigue(1.0).unwrap();
    assert!((s.vitals.stamina - 0.93).abs() < 1e-12);
    s.posture = Posture::Prone;
    s.activity = 0;
    s.motion.position = Vector3::X;
    assert_eq!(s.finish_tick(0.1, 100.0, Some(210), true).unwrap(), 3);
    assert_eq!(s.posture, Posture::Stand);
    assert_eq!(s.activity, 2);
    assert_eq!(s.flags, 1 | 2 | 8 | 64);
    s.duty.entity = 17;
    s.update_activity(ActivityContext {
        task_target_exists: true,
        ..Default::default()
    });
    assert_eq!((s.doing, s.doing_entity), (10, 17));
    s.duty.kind = Task::Fight;
    s.update_activity(ActivityContext::default());
    assert_eq!(s.doing, 5);
    s.vitals.life = Life::Downed;
    s.activity = 23;
    s.links.dragged_by = 99;
    s.update_activity(ActivityContext::default());
    assert_eq!((s.doing, s.doing_entity), (26, 0));
    s.vitals.life = Life::Alive;
    s.duty.kind = Task::Man;
    s.emplacement.structure = 30;
    s.activity = 4;
    s.update_activity(ActivityContext {
        mounted_exists: true,
        ..Default::default()
    });
    assert_eq!((s.doing, s.doing_entity), (6, 30));
}

#[test]
fn retained_movement_continues_identically_after_a_checkpoint_each_tick() {
    let nav = PathPlanner::new(32).unwrap();
    let terrain = Terrain::blank(32).unwrap();
    let mut collision = CollisionWorld::default();
    let mut continuous = soldier();
    continuous.orders.purpose = Goal::Cover;
    continuous.orders.move_mode = 1;
    continuous.vitals.suppression = 30.0;
    continuous.motion.path = vec![Vector3::new(1.1, 0.0, 3.7), Vector3::new(3.9, 0.0, 7.1)];
    continuous.cover.normal = Vector3::new(0.3, 0.0, -0.9);
    let mut restored = continuous.clone();
    let mut randoms = [SimulationRandom::new(137); 2];
    for tick in 0..300 {
        let i = Movement {
            time: 100.0 + tick as f64 / 30.0,
            ..movement()
        };
        let mut outputs = Vec::new();
        for (s, rng) in [&mut continuous, &mut restored]
            .into_iter()
            .zip(randoms.iter_mut())
        {
            s.recover(i.dt, i.time).unwrap();
            s.fatigue(i.dt).unwrap();
            let out = s
                .move_route(i, &nav, &terrain, &mut collision, rng, &[], &[])
                .unwrap();
            if !out.moving {
                s.stand(i.dt, i.time, false, None, &nav, &terrain, &[])
                    .unwrap();
            }
            s.finish_tick(i.dt, i.time, Some(210), false).unwrap();
            s.update_activity(ActivityContext::default());
            outputs.push(out);
        }
        assert_eq!(outputs[0], outputs[1]);
        assert_eq!(continuous, restored);
        assert_eq!(randoms[0], randoms[1]);
        restored = Infantry::restore(&restored.checkpoint().unwrap()).unwrap();
    }
}

#[test]
fn invalid_input_does_not_mutate_the_actor_or_consume_draws() {
    let nav = PathPlanner::new(32).unwrap();
    let terrain = Terrain::blank(32).unwrap();
    let mut collision = CollisionWorld::default();
    let mut s = soldier();
    s.motion.path = vec![Vector3::X * 5.0];
    let mut rng = SimulationRandom::new(137);
    let before = s.clone();
    let draws = rng;
    for i in [
        Movement {
            dt: f64::NAN,
            ..movement()
        },
        Movement {
            speed: -1.0,
            ..movement()
        },
        Movement {
            mount: Some((Vector3::ZERO, -1.0)),
            ..movement()
        },
    ] {
        assert!(s
            .move_route(i, &nav, &terrain, &mut collision, &mut rng, &[], &[])
            .is_err());
        assert_eq!(s, before);
        assert_eq!(rng, draws);
    }
    let invalid = [Door {
        id: u32::MAX as u64 + 1,
        position: Vector3::ZERO,
        yaw: 0.0,
    }];
    assert!(s
        .move_route(
            movement(),
            &nav,
            &terrain,
            &mut collision,
            &mut rng,
            &[],
            &invalid
        )
        .is_err());
    assert!(s.finish_tick(0.1, 100.0, Some(-1), false).is_err());
    assert_eq!(s, before);
    assert_eq!(rng, draws);
}
