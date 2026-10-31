use frontline_core::actors::{Actor, Actors};
use frontline_core::collision::CollisionWorld;
use frontline_core::drone::{DroneFlight, Phase};
use frontline_core::drone_actor::Drone;
use frontline_core::infantry::Infantry;
use frontline_core::infantry_controller::Task;
use frontline_core::infantry_vitals::Life;
use frontline_core::projectile::Kind;
use frontline_core::projectile_actor::{ballistic, Projectile, Spawn};
use frontline_core::random::SimulationRandom;
use frontline_core::vector::Vector3;

fn soldier(id: u32) -> Infantry {
    let mut s = Infantry::default();
    s.identity.id = id;
    s.identity.unit = "rifleman".into();
    s.identity.weapon = "rifle".into();
    s.motion.position = Vector3::new(10.0, 0.0, 3.0);
    s
}
fn drone(id: u32) -> Drone {
    Drone {
        id,
        team: 1,
        operator: 1,
        target: 2,
        operator_at_spawn: 1,
        target_at_spawn: 2,
        warhead: 1.5,
        flight: DroneFlight::new(Vector3::new(0.0, 7.0, 0.0), 0.3),
    }
}
fn scene(task: Task) -> Actors {
    let mut carrier = soldier(1);
    carrier.duty.kind = task;
    carrier.duty.entity = 2;
    carrier.fight.controlled_drone = 3;
    carrier.identity.squad = 4;
    let mut patient = soldier(2);
    patient.links.dragged_by = 1;
    patient.links.rescue_claimed = 1;
    patient.links.carried_by = vec![1, 4];
    Actors::from_entries(
        9,
        vec![
            Actor::Soldier(Box::new(carrier)),
            Actor::Soldier(Box::new(patient)),
            Actor::Drone(drone(3)),
        ],
    )
    .unwrap()
}

#[test]
fn releases_update_patients_and_drones_without_borrowing_scene_objects() {
    for task in [Task::Rescue, Task::Stretcher, Task::Breach] {
        for operation in 0..4 {
            let mut world = scene(task);
            let mut rng = SimulationRandom::new(137);
            let released = match operation {
                0 => world.release_all(1).unwrap(),
                1 => world.go_down(1, 17.5).unwrap(),
                2 => world.die(1, 17.5, Some(120)).unwrap().unwrap(),
                _ => world
                    .fling_from(1, Vector3::ZERO, 7.0, &mut rng)
                    .unwrap()
                    .unwrap(),
            };
            let patient = world.soldier(2).unwrap();
            assert_eq!(
                patient.links.dragged_by,
                if task == Task::Rescue { 0 } else { 1 }
            );
            assert_eq!(
                patient.links.rescue_claimed,
                if task == Task::Rescue { 0 } else { 1 }
            );
            assert_eq!(
                patient.links.carried_by,
                if task == Task::Stretcher {
                    vec![4]
                } else {
                    vec![1, 4]
                }
            );
            assert_eq!(released.squad, if task == Task::Breach { 4 } else { 0 });
            let Some(Actor::Drone(d)) = world.get(3) else {
                panic!()
            };
            assert_eq!(d.operator, 0);
            assert_eq!(d.operator_at_spawn, 1);
            assert_eq!(d.flight.phase, Phase::Uncontrolled);
            let before = world.checkpoint().unwrap();
            assert_eq!(
                Actors::restore(&before).unwrap().checkpoint().unwrap(),
                before
            );
        }
    }
}

#[test]
fn releasing_old_rescue_claim_does_not_remove_the_new_carrier() {
    let mut s = soldier(1);
    s.duty.kind = Task::Rescue;
    s.duty.entity = 2;
    let mut patient = soldier(2);
    patient.links.dragged_by = 17;
    patient.links.rescue_claimed = 18;
    let mut actors = Actors::from_entries(
        20,
        vec![
            Actor::Soldier(Box::new(s)),
            Actor::Soldier(Box::new(patient)),
        ],
    )
    .unwrap();
    actors.release_all(1).unwrap();
    assert_eq!(actors.soldier(2).unwrap().links.dragged_by, 17);
    assert_eq!(actors.soldier(2).unwrap().links.rescue_claimed, 18);
}

#[test]
fn allocation_checkpoint_and_compaction_retain_actor_order() {
    let mut actors = Actors::default();
    let mut live = Vec::new();
    for n in 0..5000 {
        let id = actors
            .spawn(Actor::Soldier(Box::new(soldier(999))))
            .unwrap();
        live.push(id);
        if n % 3 != 0 {
            actors.remove(live.remove(live.len() - 2));
        }
    }
    let mut restored = Actors::restore(&actors.checkpoint().unwrap()).unwrap();
    assert_eq!(
        restored.iter().map(|a| a.identity().id).collect::<Vec<_>>(),
        live
    );
    assert_eq!(
        restored
            .spawn(Actor::Soldier(Box::new(soldier(0))))
            .unwrap(),
        5001
    );
    let p = Projectile::from_spawn(
        1,
        Spawn {
            flight: ballistic(Kind::Frag, Vector3::Y, Vector3::ZERO),
            team: 0,
            thrower: 5001,
            called_by: 17,
        },
    )
    .unwrap();
    assert_eq!(restored.spawn(Actor::Projectile(p)).unwrap(), 5002);
    let bytes = restored.checkpoint().unwrap();
    assert_eq!(
        Actors::restore(&bytes).unwrap().checkpoint().unwrap(),
        bytes
    );
}

#[test]
fn invalid_spawns_and_missing_actor_operations_preserve_state() {
    let mut actors = scene(Task::Fight);
    let before = actors.checkpoint().unwrap();
    let mut bad = soldier(0);
    bad.motion.position.x = f32::NAN;
    assert!(actors.spawn(Actor::Soldier(Box::new(bad))).is_err());
    assert!(actors.go_down(999, 0.0).is_err());
    assert!(actors.go_down(1, f64::NAN).is_err());
    assert!(actors.release_all(3).is_err());
    assert!(actors.remove(99).is_none());
    assert_eq!(actors.checkpoint().unwrap(), before);
    assert!(Actors::from_entries(1, vec![Actor::Soldier(Box::new(soldier(1)))]).is_err());
    assert!(Actors::from_entries(
        3,
        vec![Actor::Soldier(Box::new(soldier(1))), Actor::Drone(drone(1))]
    )
    .is_err());
}

#[test]
fn actor_checkpoints_reject_mismatched_id_kind_versions_and_truncation() {
    let bytes = scene(Task::Rescue).checkpoint().unwrap();
    for end in 0..bytes.len() {
        assert!(Actors::restore(&bytes[..end]).is_err());
    }
    for index in [4, 6, 16, 34, 55, 59] {
        let mut bad = bytes.clone();
        bad[index] ^= 0x40;
        assert!(Actors::restore(&bad).is_err(), "offset {index}");
    }
    let mut trailing = bytes;
    trailing.push(0);
    assert!(Actors::restore(&trailing).is_err());
}

#[test]
fn drone_reads_living_target_and_operator_from_owned_actors() {
    let mut actors = scene(Task::Fight);
    let mut collision = CollisionWorld::default();
    actors
        .step_drone(3, 1.0 / 30.0, &mut collision, 512.0)
        .unwrap();
    let Some(Actor::Drone(d)) = actors.get(3) else {
        panic!()
    };
    assert_eq!(d.flight.target, Vector3::new(10.0, 1.1, 3.0));
    actors.die(2, 0.0, None).unwrap();
    actors.remove(1);
    actors
        .step_drone(3, 1.0 / 30.0, &mut collision, 512.0)
        .unwrap();
    let Some(Actor::Drone(d)) = actors.get(3) else {
        panic!()
    };
    assert_eq!((d.operator, d.target), (0, 0));
    assert_eq!(d.flight.target, Vector3::new(10.0, 1.1, 3.0));
    assert_eq!(d.flight.phase, Phase::Uncontrolled);
    assert_eq!(actors.soldier(2).unwrap().vitals.life, Life::Dead);
}

#[test]
fn drone_resume_and_detonation_preserve_operator_credit_and_warhead() {
    for lose in [false, true] {
        let mut a = drone(3);
        let mut collision = CollisionWorld::default();
        for _ in 0..10 {
            a.advance(
                1.0 / 30.0,
                !lose,
                Some(Vector3::new(20.0, 0.25, 0.0)),
                &mut collision,
                512.0,
            )
            .unwrap();
        }
        let mut b = Drone::restore(&a.checkpoint().unwrap()).unwrap();
        let mut hit = false;
        for _ in 0..2000 {
            let ae = a
                .advance(1.0 / 30.0, !lose, None, &mut collision, 512.0)
                .unwrap();
            let be = b
                .advance(1.0 / 30.0, !lose, None, &mut collision, 512.0)
                .unwrap();
            assert_eq!(a, b);
            assert_eq!(ae, be);
            if let Some(explosion) = ae {
                assert_eq!(explosion.source, if lose { 0 } else { 1 });
                assert_eq!(explosion.damage, 225.0);
                assert_eq!(explosion.antitank, 510.0);
                assert!(a.detonate().is_none());
                assert!(!a.shot_down());
                hit = true;
                break;
            }
        }
        assert!(hit);
    }
    let mut d = drone(3);
    assert!(d.shot_down());
    assert!(d.detonate().is_none());
    assert_eq!(
        d.advance(0.1, false, None, &mut CollisionWorld::default(), 512.0)
            .unwrap(),
        None
    );
}

#[test]
fn drone_rejects_invalid_steps_and_checkpoint_metadata_atomically() {
    let mut d = drone(3);
    let before = d;
    assert!(d
        .advance(f64::NAN, false, None, &mut CollisionWorld::default(), 512.0)
        .is_err());
    assert_eq!(d, before);
    let bytes = d.checkpoint().unwrap();
    for end in 0..bytes.len() {
        assert!(Drone::restore(&bytes[..end]).is_err());
    }
    for index in [4, 6, 28] {
        let mut bad = bytes.clone();
        bad[index] = 7;
        assert!(Drone::restore(&bad).is_err());
    }
    d.flight.position = Vector3::new(1_000_000.0, 5.0, 0.0);
    d.flight.velocity = Vector3::X * 1_000_000.0;
    let before = d;
    assert!(d
        .advance(
            1.0,
            false,
            None,
            &mut CollisionWorld::default(),
            1_000_000.0
        )
        .is_err());
    assert_eq!(d, before);
}
