use frontline_core::actors::{Actor, Actors};
use frontline_core::projectile::Kind;
use frontline_core::projectile_actor::Motion;
use frontline_core::random::SimulationRandom;
use frontline_core::vector::Vector3;
use frontline_core::vehicle::Vehicle;
use frontline_core::vehicle_artillery::{ArtilleryEvent, ArtilleryProfile};
use frontline_core::vehicle_launch::SmokeProfile;

fn profile() -> ArtilleryProfile {
    ArtilleryProfile {
        shell: Kind::Arty,
        gun_height: 2.2,
        muzzle: 6.5,
        scatter: 3.5,
        salvo: 3,
        lay: 0.0,
        gap: 0.2,
        cooldown: 22.0,
        traverse: 0.9,
        traverse_accel: 1.8,
    }
}
fn gun() -> Vehicle {
    Vehicle {
        id: 1,
        team: 0,
        ..Default::default()
    }
}
fn actors(next: u64) -> Actors {
    let mut v = gun();
    v.salvo_at = Some(Vector3::new(17.3, 0.0, -89.1));
    Actors::from_entries(
        next,
        vec![
            Actor::Vehicle(Box::new(v)),
            Actor::Vehicle(Box::new(Vehicle {
                id: 2,
                team: 1,
                position: Vector3::NEG_Z * 50.0,
                ..Default::default()
            })),
        ],
    )
    .unwrap()
}

#[test]
fn queued_orders_take_priority_and_automatic_search_waits_for_a_halted_ready_gun() {
    let mut v = gun();
    v.path_pending = true;
    assert!(!v.artillery_needs_target(10.0));
    assert_eq!(
        v.artillery_tick(10.0, 0.1, profile(), Some(Vector3::X))
            .unwrap(),
        ArtilleryEvent::None
    );
    v.path_pending = false;
    v.fire_queue = vec![Vector3::NEG_Z * 80.0, Vector3::X * 30.0];
    assert!(!v.artillery_needs_target(10.0));
    assert_eq!(
        v.artillery_tick(10.0, 0.1, profile(), Some(Vector3::Z))
            .unwrap(),
        ArtilleryEvent::Mission
    );
    assert_eq!(v.salvo_at, Some(Vector3::NEG_Z * 80.0));
    assert_eq!(v.fire_queue, [Vector3::X * 30.0]);
    assert_eq!(v.artillery_until, 32.0);
    assert_eq!(v.salvo, 3);
}

#[test]
fn a_salvo_waits_for_aim_then_finishes_each_round_after_launch() {
    let mut v = gun();
    let p = profile();
    assert_eq!(
        v.artillery_tick(10.0, 0.1, p, Some(Vector3::NEG_Z * 80.0))
            .unwrap(),
        ArtilleryEvent::Mission
    );
    for remaining in (1..=3).rev() {
        assert_eq!(
            v.artillery_tick(10.0, 0.2, p, None).unwrap(),
            ArtilleryEvent::Fire
        );
        assert_eq!(v.salvo, remaining);
        v.finish_artillery_round(p).unwrap();
        assert_eq!(v.salvo, remaining - 1);
        assert_eq!(v.salvo_timer, p.gap);
    }
    assert!(v.lay_yaw.is_none());
    assert!(v.finish_artillery_round(p).is_err());
    let mut v = gun();
    v.artillery_tick(10.0, 0.1, p, Some(Vector3::X * 80.0))
        .unwrap();
    assert_eq!(
        v.artillery_tick(10.1, 0.1, p, None).unwrap(),
        ArtilleryEvent::None
    );
    assert!(v.turret_yaw < 0.0 && v.salvo_timer < 0.0);
}

#[test]
fn missing_targets_retry_after_two_seconds_and_invalid_steps_do_not_change_state() {
    let mut v = gun();
    assert!(v.artillery_needs_target(10.0));
    assert_eq!(
        v.artillery_tick(10.0, 0.1, profile(), None).unwrap(),
        ArtilleryEvent::None
    );
    assert_eq!(v.artillery_until, 12.0);
    assert!(!v.artillery_needs_target(11.9));
    assert!(v.artillery_needs_target(12.0));
    let saved = v.clone();
    assert!(v.artillery_tick(12.0, f64::NAN, profile(), None).is_err());
    assert!(v
        .artillery_tick(12.0, 0.1, profile(), Some(Vector3::NAN))
        .is_err());
    assert_eq!(v, saved);
}

#[test]
fn shells_keep_origin_scatter_duration_identity_and_checkpoint_random_continuation() {
    let mut a = actors(3);
    let mut rng = SimulationRandom::new(137);
    let round = a
        .launch_vehicle_shell(1, 11.2, profile(), &mut rng)
        .unwrap();
    assert_eq!(round.id, 3);
    assert_eq!(round.flight.position, round.flight.origin);
    assert_eq!(round.flight.position, Vector3::new(0.0, 3.4, -6.5));
    assert_eq!(round.flight.target.y, 0.05);
    assert!(round.flight.shell_duration > 4.0);
    assert_eq!(a.vehicle(1).unwrap().last_fire, 11.2);
    let Some(Actor::Projectile(p)) = a.get(3) else {
        panic!()
    };
    assert_eq!((p.thrower, p.team), (1, 0));
    assert_eq!(p.motion, Motion::Ballistic(round.flight));
    let mut b = Actors::restore(&a.checkpoint().unwrap()).unwrap();
    let mut resumed = rng.clone();
    assert_eq!(
        a.launch_vehicle_shell(1, 12.2, profile(), &mut rng),
        b.launch_vehicle_shell(1, 12.2, profile(), &mut resumed)
    );
    assert_eq!(a.checkpoint().unwrap(), b.checkpoint().unwrap());
    assert_eq!(rng.state(), resumed.state());
}

#[test]
fn rejected_shells_and_rockets_preserve_ids_and_the_random_cursor() {
    let mut a = actors(u32::MAX as u64 + 1);
    let mut rng = SimulationRandom::new(137);
    let saved = a.checkpoint().unwrap();
    let cursor = rng.state();
    assert!(a
        .launch_vehicle_shell(1, 12.2, profile(), &mut rng)
        .is_err());
    assert!(a.launch_vehicle_rocket(1, 2, 0, &mut rng).is_err());
    assert_eq!(a.checkpoint().unwrap(), saved);
    assert_eq!(rng.state(), cursor);
}

#[test]
fn rocket_salvos_alternate_pods_and_allow_each_warning_to_consume_randomness() {
    let mut a = actors(3);
    let mut rng = SimulationRandom::new(137);
    let first = a.launch_vehicle_rocket(1, 2, 0, &mut rng).unwrap();
    assert_eq!(first.position, Vector3::new(1.1, 1.2, -1.0));
    assert_eq!(a.projectile_warning_target(first.id).unwrap(), Some(2));
    let smoke = a
        .launch_vehicle_smoke(
            2,
            12.0,
            first.position,
            SmokeProfile {
                armor: 2,
                helicopter: false,
                gun_height: 2.2,
            },
            &mut rng,
        )
        .unwrap();
    assert_eq!(smoke.len(), 4);
    let mut b = Actors::restore(&a.checkpoint().unwrap()).unwrap();
    let mut resumed = rng.clone();
    let next = a.launch_vehicle_rocket(1, 2, 1, &mut rng).unwrap();
    assert_eq!(next.id, 8);
    assert_eq!(next.position, Vector3::new(-1.1, 1.2, -1.0));
    assert_eq!(
        next,
        b.launch_vehicle_rocket(1, 2, 1, &mut resumed).unwrap()
    );
    assert_eq!(rng.state(), resumed.state());
    assert_eq!(a.checkpoint().unwrap(), b.checkpoint().unwrap());
}
