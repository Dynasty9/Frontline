use frontline_core::projectile::{Flight, Hit, Holder, Kind, Outcome};
use frontline_core::vector::Vector3;

fn grenade() -> Flight {
    Flight {
        kind: Kind::Frag,
        position: Vector3::new(0.0, 1.5, 0.0),
        velocity: Vector3::new(3.0, 5.0, -1.0),
        origin: Vector3::ZERO,
        target: Vector3::new(30.0, 0.0, 0.0),
        fuse: 3.4,
        flying: true,
        life: 0.0,
        smoke_time: 0.0,
        smoke_radius: 0.0,
        shell_duration: 3.0,
    }
}

#[test]
fn held_grenade_keeps_its_fuse_and_drops_without_advancing_on_release_tick() {
    let mut flight = grenade();
    let held = Vector3::new(7.0, 1.3, 8.0);
    assert_eq!(
        flight.advance(0.1, Holder::Alive(held), None),
        Outcome::Flying
    );
    assert_eq!(flight.position, held);
    assert_eq!(flight.fuse, 3.3);
    flight.advance(0.1, Holder::Dropped, None);
    assert_eq!(flight.position, held);
    assert_eq!(flight.velocity, Vector3::ZERO);
    flight.advance(0.1, Holder::Free, None);
    assert_eq!(flight.position, held);
    assert_eq!(flight.velocity.y, -1.8);
}

#[test]
fn state_resume_reproduces_every_future_transition_and_outcome() {
    for kind in [
        Kind::Frag,
        Kind::Smoke,
        Kind::Rocket,
        Kind::Recoilless,
        Kind::Mortar,
        Kind::MortarSmoke,
        Kind::Grad,
        Kind::Arty,
        Kind::Ac105,
        Kind::Ac40,
        Kind::Ac25,
        Kind::Bomb,
    ] {
        let mut original = grenade();
        original.kind = kind;
        original.position.y = 20.0;
        for _ in 0..7 {
            original.advance(1.0 / 30.0, Holder::Free, None);
        }
        let mut restored = Flight::restore(&original.checkpoint()).unwrap();
        let mut ended = false;
        for tick in 0..1000 {
            let collision = (tick == 11).then_some(Hit {
                position: Vector3::new(0.0, 2.0, 0.0),
                normal: Vector3::X,
            });
            let a = original.advance(1.0 / 30.0, Holder::Free, collision);
            let b = restored.advance(1.0 / 30.0, Holder::Free, collision);
            assert_eq!(a, b);
            assert_eq!(original, restored);
            if a != Outcome::Flying {
                ended = true;
                break;
            }
        }
        assert!(ended, "{kind:?} did not finish");
    }
}

#[test]
fn checkpoint_rejects_truncation_versions_invalid_tags_and_nonfinite_state() {
    let saved = grenade().checkpoint();
    for length in 0..saved.len() {
        assert!(Flight::restore(&saved[..length]).is_err());
    }
    let mut trailing = saved.clone();
    trailing.push(0);
    assert!(Flight::restore(&trailing).is_err());
    for (offset, value) in [(4, 2), (8, 255), (9, 2)] {
        let mut bad = saved.clone();
        bad[offset] = value;
        assert!(Flight::restore(&bad).is_err());
    }
    let mut bad = saved;
    bad[10..14].copy_from_slice(&f32::NAN.to_le_bytes());
    assert!(Flight::restore(&bad).is_err());
}

#[test]
fn smoke_grows_lingers_fades_and_expires() {
    let mut smoke = grenade();
    smoke.kind = Kind::Smoke;
    smoke.flying = false;
    assert_eq!(smoke.advance(1.0, Holder::Free, None), Outcome::Flying);
    assert_eq!(smoke.smoke_radius, 2.6);
    for _ in 0..20 {
        smoke.advance(1.0, Holder::Free, None);
    }
    assert_eq!(smoke.smoke_radius, 6.5);
    smoke.advance(1.0, Holder::Free, None);
    assert_eq!(smoke.smoke_radius, 5.0);
    for _ in 0..5 {
        smoke.advance(1.0, Holder::Free, None);
    }
    assert_eq!(smoke.smoke_radius, 0.0);
    assert_eq!(smoke.advance(1.0, Holder::Free, None), Outcome::Expired);
}

#[test]
fn rocket_collision_precedes_timeout_and_ground_impact() {
    let mut rocket = grenade();
    rocket.kind = Kind::Rocket;
    rocket.life = 3.0;
    rocket.position.y = 0.0;
    let hit = Hit {
        position: Vector3::new(4.0, 1.0, 2.0),
        normal: Vector3::Y,
    };
    assert_eq!(
        rocket.advance(0.1, Holder::Free, Some(hit)),
        Outcome::Impact(hit.position)
    );
}

#[test]
fn collision_and_flight_advance_without_engine_callbacks() {
    use frontline_core::collision::{BoxShape, CollisionWorld, Mat3};
    let mut world = CollisionWorld::default();
    assert!(world.replace(91, &[BoxShape {
        body: 91, shape: 0, center: Vector3::new(2.0, 2.0, 0.0),
        basis: Mat3::IDENTITY, half: Vector3::new(0.1, 3.0, 3.0),
    }]));
    for kind in [Kind::Frag, Kind::Smoke, Kind::Rocket, Kind::Recoilless, Kind::Bomb, Kind::Arty] {
        for held in [Holder::Free, Holder::Alive(Vector3::new(5.0, 2.0, 0.0)), Holder::Dropped] {
            for excluded in [vec![], vec![91]] {
                let mut flight = grenade();
                flight.kind = kind;
                flight.position = Vector3::new(0.0, 2.0, 0.0);
                flight.velocity = Vector3::new(30.0, 0.0, 0.0);
                let mut reference = flight;
                let sweeps = match kind {
                    Kind::Frag | Kind::Smoke => held == Holder::Free,
                    Kind::Rocket | Kind::Recoilless => true,
                    _ => false,
                };
                let hit = if sweeps {
                    world.ray(flight.position, flight.sweep_end(0.1), &excluded)
                        .map(|hit| Hit { position: hit.position, normal: hit.normal })
                } else { None };
                let expected = reference.advance(0.1, held, hit);
                let actual = flight.advance_in_world(0.1, held, &mut world, &excluded);
                assert_eq!(actual, expected);
                assert_eq!(flight, reference);
                if kind == Kind::Rocket && excluded.is_empty() {
                    assert!(matches!(actual, Outcome::Impact(at) if (at.x - 1.9).abs() < 0.0001));
                }
            }
        }
    }
}
