use frontline_core::actors::{Actor, Actors};
use frontline_core::collision::{BoxShape, CollisionWorld, Mat3};
use frontline_core::drone::DroneFlight;
use frontline_core::drone_actor::Drone;
use frontline_core::infantry::Infantry;
use frontline_core::infantry_controller::Task;
use frontline_core::infantry_reflex::Reflex;
use frontline_core::infantry_vitals::Life;
use frontline_core::path_planner::PathPlanner;
use frontline_core::projectile::Kind;
use frontline_core::projectile_actor::{ballistic, Motion, Projectile};
use frontline_core::random::SimulationRandom;
use frontline_core::spatial::{SpatialIndex, UNIT_CELL};
use frontline_core::squad::Squad;
use frontline_core::structure::Structure;
use frontline_core::vector::Vector3;

fn soldier(id: u32) -> Infantry {
    let mut s = Infantry::default();
    s.identity.id = id;
    s.identity.unit = "rifleman".into();
    s.identity.squad = 9;
    s
}
fn round(id: u32, kind: Kind, x: f32, fuse: f64) -> Actor {
    let mut flight = ballistic(kind, Vector3::X * x, Vector3::ZERO);
    flight.fuse = fuse;
    flight.target = Vector3::X * x;
    flight.life = 2.0;
    Actor::Projectile(Projectile {
        id,
        team: 1,
        thrower: 0,
        called_by: 0,
        held_by: 0,
        smothered_by: 0,
        handler: 0,
        thrown_back: 0,
        target_id: 0,
        motion: Motion::Ballistic(flight),
    })
}
fn field(entries: Vec<Actor>) -> (Actors, SpatialIndex, PathPlanner, CollisionWorld) {
    let actors = Actors::from_entries(100, entries).unwrap();
    let mut units = SpatialIndex::new(UNIT_CELL).unwrap();
    actors.rebuild_units(&mut units).unwrap();
    (
        actors,
        units,
        PathPlanner::new(32).unwrap(),
        CollisionWorld::default(),
    )
}

#[test]
fn grenade_memory_and_busy_dives_preserve_the_order_of_random_draws() {
    let mut s = soldier(1);
    s.fight.noticed_grenade = 99;
    s.cover.at_cover = true;
    s.weapon.peek_up = true;
    s.weapon.blind = true;
    let (mut actors, units, nav, mut collision) = field(vec![
        Actor::Soldier(Box::new(s)),
        round(10, Kind::Frag, 0.0, 1.2),
    ]);
    let mut rng = SimulationRandom::new(83);
    let mut expected = rng;
    let cue = (expected.randi() % 3) as u8;
    let direction =
        frontline_core::grenade_task::dive_direction(Vector3::ZERO, Vector3::ZERO, &mut expected)
            .unwrap();
    let result = actors
        .react_infantry(
            1,
            Reflex::BusyGrenade,
            10.0,
            true,
            None,
            &units,
            &nav,
            &mut collision,
            &mut rng,
        )
        .unwrap();
    assert!(result.handled && result.cancel_path);
    assert_eq!(result.speech, [cue]);
    assert_eq!(rng, expected);
    let s = actors.soldier(1).unwrap();
    assert_eq!(s.controller.dive_direction, direction);
    assert_eq!(s.fight.noticed_grenade, 99);
    assert!(!s.cover.at_cover && !s.weapon.peek_up && s.weapon.blind);
    let saved = actors.checkpoint().unwrap();
    actors = Actors::restore(&saved).unwrap();
    assert!(
        !actors
            .react_infantry(
                1,
                Reflex::BusyGrenade,
                10.1,
                true,
                None,
                &units,
                &nav,
                &mut collision,
                &mut rng
            )
            .unwrap()
            .handled
    );
    assert_eq!(actors.checkpoint().unwrap(), saved);
    assert_eq!(rng, expected);
}

#[test]
fn grenade_claims_and_task_cleanup_change_shared_state_in_the_existing_order() {
    let mut seen = std::collections::BTreeSet::new();
    for seed in 0..128 {
        let mut a = soldier(1);
        a.duty.kind = Task::Rescue;
        a.duty.entity = 2;
        a.duty.partner = 3;
        a.orders.backwards = true;
        let mut patient = soldier(2);
        patient.vitals.life = Life::Downed;
        patient.links.dragged_by = 1;
        patient.links.rescue_claimed = 1;
        let (mut actors, units, nav, mut collision) = field(vec![
            Actor::Soldier(Box::new(a)),
            Actor::Soldier(Box::new(patient)),
            Actor::Soldier(Box::new(soldier(3))),
            round(10, Kind::Frag, 1.0, 2.0),
        ]);
        let mut q = Squad {
            id: 9,
            ..Default::default()
        };
        let mut rng = SimulationRandom::new(seed);
        let out = actors
            .react_infantry(
                1,
                Reflex::Grenade,
                10.0,
                true,
                Some(&mut q),
                &units,
                &nav,
                &mut collision,
                &mut rng,
            )
            .unwrap();
        seen.insert(out.leaf);
        if [1, 2, 3].contains(&out.leaf) {
            let Some(Actor::Projectile(g)) = actors.get(10) else {
                panic!()
            };
            assert_eq!(g.handler, 1);
            assert_eq!(g.smothered_by, if out.leaf == 1 { 1 } else { 0 });
            let patient = actors.soldier(2).unwrap();
            assert_eq!(patient.links.dragged_by, if out.leaf == 2 { 1 } else { 0 });
            assert_eq!(patient.links.rescue_claimed, patient.links.dragged_by);
            let second = actors
                .react_infantry(
                    3,
                    Reflex::Grenade,
                    10.0,
                    true,
                    Some(&mut q),
                    &units,
                    &nav,
                    &mut collision,
                    &mut rng,
                )
                .unwrap();
            assert_eq!(second.leaf, 5);
            let Some(Actor::Projectile(g)) = actors.get(10) else {
                panic!()
            };
            assert_eq!(g.handler, 1);
        }
    }
    assert!(seen.is_superset(&[1, 2, 3, 5].into_iter().collect()));
}

#[test]
fn shelter_requires_an_owned_structure_not_just_a_collision_body() {
    for owned in [false, true] {
        let mut entries = vec![
            Actor::Soldier(Box::new(soldier(1))),
            round(10, Kind::Frag, 3.0, 1.0),
        ];
        if owned {
            entries.push(Actor::Structure(Box::new(Structure {
                id: 20,
                kind: "low_wall".into(),
                ..Default::default()
            })));
        }
        let (mut actors, units, nav, mut collision) = field(entries);
        assert!(collision.replace(
            20,
            &[BoxShape {
                body: 20,
                shape: 0,
                center: Vector3::new(1.5, 1.0, 0.0),
                half: Vector3::new(0.1, 2.0, 2.0),
                basis: Mat3::IDENTITY
            }]
        ));
        let out = actors
            .react_infantry(
                1,
                Reflex::Grenade,
                10.0,
                false,
                None,
                &units,
                &nav,
                &mut collision,
                &mut SimulationRandom::new(2),
            )
            .unwrap();
        assert_eq!(out.leaf, if owned { 4 } else { 5 });
        if owned {
            assert_eq!(actors.soldier(1).unwrap().vitals.hit_dirt_timer, 1.4);
        }
    }
}

#[test]
fn shells_draw_muted_warnings_and_stop_at_the_first_close_dive() {
    let mut a = soldier(1);
    a.vitals.speech_cooldown = 7.0;
    let (mut actors, units, nav, mut collision) = field(vec![
        Actor::Soldier(Box::new(a)),
        round(10, Kind::Mortar, 8.0, 3.4),
        round(11, Kind::Mortar, 0.0, 3.4),
        round(12, Kind::Mortar, 1.0, 3.4),
    ]);
    let mut rng = SimulationRandom::new(81);
    let mut expected = rng;
    expected.randi();
    let spoken = (expected.randi() % 3) as u8 + 6;
    expected.randf();
    let out = actors
        .react_infantry(
            1,
            Reflex::Shell,
            10.0,
            true,
            None,
            &units,
            &nav,
            &mut collision,
            &mut rng,
        )
        .unwrap();
    assert!(out.handled);
    assert_eq!(out.speech, [spoken]);
    assert_eq!(rng, expected);
    let a = actors.soldier(1).unwrap();
    assert_eq!(a.grenade_memory.seen, [10, 11]);
    assert_eq!(a.vitals.suppression, 40.0);
    assert_eq!(a.vitals.hit_dirt_timer, 2.5);
}

#[test]
fn busy_shell_reactions_duck_without_cancelling_the_current_duty() {
    let mut a = soldier(1);
    a.duty.kind = Task::Stretcher;
    let (mut actors, units, nav, mut collision) = field(vec![
        Actor::Soldier(Box::new(a)),
        round(10, Kind::Mortar, 0.0, 3.4),
        round(11, Kind::Mortar, 4.0, 3.4),
    ]);
    let out = actors
        .react_infantry(
            1,
            Reflex::BusyShell,
            10.0,
            true,
            None,
            &units,
            &nav,
            &mut collision,
            &mut SimulationRandom::new(1),
        )
        .unwrap();
    assert!(!out.handled && !out.cancel_path);
    assert_eq!(out.speech.len(), 2);
    let a = actors.soldier(1).unwrap();
    assert_eq!(a.duty.kind, Task::Stretcher);
    assert_eq!(a.vitals.hit_dirt_timer, 2.5);
    assert_eq!(a.vitals.suppression, 40.0);
}

#[test]
fn drone_warnings_skip_friendly_dead_and_high_aircraft_without_random_draws() {
    let mut entries = vec![Actor::Soldier(Box::new(soldier(1)))];
    for id in 10..14 {
        let mut flight = DroneFlight::new(
            Vector3::new(2.0, if id == 12 { 46.0 } else { 0.0 }, 0.0),
            0.0,
        );
        flight.dead = id == 11;
        entries.push(Actor::Drone(Drone {
            id,
            team: if id == 10 { 0 } else { 1 },
            operator: 0,
            target: 0,
            operator_at_spawn: 0,
            target_at_spawn: 0,
            warhead: 1.0,
            flight,
        }));
    }
    let (mut actors, units, nav, mut collision) = field(entries);
    let mut rng = SimulationRandom::new(73);
    let mut expected = rng;
    let cue = (expected.randi() % 3) as u8 + 9;
    let out = actors
        .react_infantry(
            1,
            Reflex::Drone,
            10.0,
            true,
            None,
            &units,
            &nav,
            &mut collision,
            &mut rng,
        )
        .unwrap();
    assert!(!out.handled);
    assert_eq!(out.speech, [cue]);
    assert_eq!(actors.soldier(1).unwrap().drone_memory.heard, [13]);
    assert_eq!(rng, expected);
}

#[test]
fn a_failed_dive_cannot_spend_randomness_or_remember_the_round() {
    let mut a = soldier(1);
    a.orders.path_revision = i64::MAX as u64;
    let (mut actors, units, nav, mut collision) = field(vec![
        Actor::Soldier(Box::new(a)),
        round(10, Kind::Frag, 0.0, 1.0),
    ]);
    let saved = actors.checkpoint().unwrap();
    let mut rng = SimulationRandom::new(9);
    let random = rng;
    assert!(actors
        .react_infantry(
            1,
            Reflex::BusyGrenade,
            10.0,
            true,
            None,
            &units,
            &nav,
            &mut collision,
            &mut rng
        )
        .is_err());
    assert_eq!(actors.checkpoint().unwrap(), saved);
    assert_eq!(rng, random);
}
