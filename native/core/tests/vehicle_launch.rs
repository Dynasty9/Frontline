use frontline_core::actors::{Actor, Actors};
use frontline_core::guided::Kind as GuidedKind;
use frontline_core::projectile::Kind;
use frontline_core::projectile_actor::{ballistic, Motion, Projectile, Spawn};
use frontline_core::random::SimulationRandom;
use frontline_core::vector::Vector3;
use frontline_core::vehicle::Vehicle;
use frontline_core::vehicle_launch::SmokeProfile;

fn actors(next: u64) -> Actors {
    Actors::from_entries(
        next,
        vec![
            Actor::Vehicle(Box::new(Vehicle {
                id: 1,
                team: 0,
                smoke_left: 2,
                ..Default::default()
            })),
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
fn profile() -> SmokeProfile {
    SmokeProfile {
        armor: 2,
        helicopter: false,
        gun_height: 2.2,
    }
}

#[test]
fn missiles_spawn_owned_guidance_and_leave_weapon_completion_to_the_dispatcher() {
    let mut a = actors(3);
    let last_fire = a.vehicle(1).unwrap().last_fire;
    for kind in [GuidedKind::AntiTank, GuidedKind::SurfaceToAir] {
        let launch = a.launch_vehicle_missile(1, 2, kind, false, 2.2).unwrap();
        let Some(Actor::Projectile(p)) = a.get(launch.id) else {
            panic!()
        };
        assert_eq!((p.thrower, p.target_id, p.team), (1, 2, 0));
        let Motion::Guided(f) = &p.motion else {
            panic!()
        };
        assert_eq!(f.target, Vector3::new(0.0, 1.1, -50.0));
        assert!(f.locked && !f.dead);
        assert_eq!(f.position, launch.position);
        assert_eq!(f.velocity, launch.velocity);
        assert!(
            (f.velocity.length()
                - if kind == GuidedKind::AntiTank {
                    26.0
                } else {
                    38.0
                })
            .abs()
                < 0.0001
        );
        assert_eq!(a.vehicle(1).unwrap().last_fire, last_fire);
    }
    let saved = a.checkpoint().unwrap();
    assert_eq!(
        Actors::restore(&saved).unwrap().checkpoint().unwrap(),
        saved
    );
}

#[test]
fn named_atgm_targets_are_warned_without_spatial_membership_but_sams_are_not() {
    let mut a = actors(3);
    let atgm = a
        .launch_vehicle_missile(1, 2, GuidedKind::AntiTank, false, 2.2)
        .unwrap();
    assert_eq!(a.projectile_warning_target(atgm.id).unwrap(), Some(2));
    let sam = a
        .launch_vehicle_missile(1, 2, GuidedKind::SurfaceToAir, false, 2.2)
        .unwrap();
    assert_eq!(a.projectile_warning_target(sam.id).unwrap(), None);
}

#[test]
fn unguided_launch_warnings_keep_registration_order_and_the_launch_cone() {
    let mut a = actors(3);
    let id = a
        .spawn(Actor::Vehicle(Box::new(Vehicle {
            id: 0,
            team: 1,
            position: Vector3::NEG_Z * 43.0,
            ..Default::default()
        })))
        .unwrap();
    let p = Projectile::from_spawn(
        1,
        Spawn {
            flight: ballistic(Kind::Rocket, Vector3::ZERO, Vector3::NEG_Z * 75.0),
            team: 0,
            thrower: 1,
            called_by: 0,
        },
    )
    .unwrap();
    let rocket = a.spawn(Actor::Projectile(p)).unwrap();
    assert_eq!(a.projectile_warning_target(rocket).unwrap(), Some(2));
    a.remove(2);
    assert_eq!(a.projectile_warning_target(rocket).unwrap(), Some(id));
}

#[test]
fn smoke_spawns_four_owned_grenades_and_preserves_cooldowns_and_random_continuation() {
    let mut a = actors(3);
    let mut rng = SimulationRandom::new(137);
    let launch = a
        .launch_vehicle_smoke(1, 31.7, Vector3::NEG_Z * 50.0, profile(), &mut rng)
        .unwrap();
    assert_eq!(
        launch.iter().map(|l| l.id).collect::<Vec<_>>(),
        [3, 4, 5, 6]
    );
    assert_eq!(
        (
            a.vehicle(1).unwrap().smoke_left,
            a.vehicle(1).unwrap().smoke_until
        ),
        (1, 56.7)
    );
    for l in launch {
        let Some(Actor::Projectile(p)) = a.get(l.id) else {
            panic!()
        };
        let Motion::Ballistic(f) = &p.motion else {
            panic!()
        };
        assert_eq!(f.kind, Kind::Smoke);
        assert_eq!(f.fuse, 0.0);
        assert_eq!(p.thrower, 1);
        assert_eq!(f.position, l.position);
        assert_eq!(f.velocity, l.velocity);
        assert!(f.velocity.z < 0.0 && f.velocity.y > 0.0);
    }
    let saved = a.checkpoint().unwrap();
    let cursor = rng.state();
    assert!(a
        .launch_vehicle_smoke(1, 32.0, Vector3::NEG_Z * 50.0, profile(), &mut rng)
        .unwrap()
        .is_empty());
    assert_eq!(a.checkpoint().unwrap(), saved);
    assert_eq!(rng.state(), cursor);
    let mut b = Actors::restore(&saved).unwrap();
    let mut resumed = rng.clone();
    assert_eq!(
        a.launch_vehicle_smoke(1, 56.7, Vector3::NEG_Z * 50.0, profile(), &mut rng),
        b.launch_vehicle_smoke(1, 56.7, Vector3::NEG_Z * 50.0, profile(), &mut resumed)
    );
    assert_eq!(a.checkpoint().unwrap(), b.checkpoint().unwrap());
    assert_eq!(rng.state(), resumed.state());
}

#[test]
fn rejected_launches_preserve_actor_ids_ammunition_and_randomness() {
    let mut a = actors(u32::MAX as u64 - 2);
    let mut rng = SimulationRandom::new(137);
    let saved = a.checkpoint().unwrap();
    let cursor = rng.state();
    assert!(a
        .launch_vehicle_smoke(1, 31.7, Vector3::NEG_Z * 50.0, profile(), &mut rng)
        .is_err());
    assert!(a
        .launch_vehicle_missile(1, 999, GuidedKind::AntiTank, false, 2.2)
        .is_err());
    assert_eq!(a.checkpoint().unwrap(), saved);
    assert_eq!(rng.state(), cursor);
    let mut a = actors(3);
    let saved = a.checkpoint().unwrap();
    assert!(a
        .launch_vehicle_smoke(1, 31.7, Vector3::NAN, profile(), &mut rng)
        .is_err());
    assert_eq!(a.checkpoint().unwrap(), saved);
    assert_eq!(rng.state(), cursor);
}
