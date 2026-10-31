use frontline_core::actors::{Actor, Actors};
use frontline_core::collision::{BoxShape, CollisionWorld, Mat3};
use frontline_core::infantry::Infantry;
use frontline_core::random::SimulationRandom;
use frontline_core::terrain::{Terrain, TRENCH};
use frontline_core::terrain_cover::CoverStructure;
use frontline_core::vector::Vector3;
use frontline_core::vehicle::Vehicle;
use frontline_core::vehicle_cannon::{CannonProfile, Muzzle, Socket};

fn profile() -> CannonProfile {
    CannonProfile {
        muzzle: Muzzle {
            socket: None,
            helicopter: false,
            gunship: false,
            gun_height: 2.2,
        },
        damage: 160.0,
        radius: 5.5,
        anti_tank: 320.0,
        size: 1.4,
    }
}
fn actors(infantry: bool) -> Actors {
    let target = if infantry {
        let mut s = Infantry::default();
        s.identity.id = 2;
        s.identity.unit = "rifleman".into();
        s.identity.weapon = "rifle".into();
        s.motion.position = Vector3::new(0.0, -1.0, -30.0);
        Actor::Soldier(Box::new(s))
    } else {
        Actor::Vehicle(Box::new(Vehicle {
            id: 2,
            position: Vector3::NEG_Z * 50.0,
            ..Default::default()
        }))
    };
    Actors::from_entries(
        3,
        vec![
            Actor::Vehicle(Box::new(Vehicle {
                id: 1,
                team: 0,
                ..Default::default()
            })),
            target,
        ],
    )
    .unwrap()
}

#[test]
fn muzzle_fallbacks_and_rotating_sockets_preserve_barrel_offsets() {
    let v = Vehicle {
        id: 1,
        ..Default::default()
    };
    let mut p = profile().muzzle;
    assert_eq!(
        v.weapon_muzzle(p, true).unwrap(),
        Vector3::new(0.0, 2.2, -4.2)
    );
    assert_eq!(
        v.weapon_muzzle(p, false).unwrap(),
        Vector3::new(0.0, 2.2, -1.0)
    );
    p.gunship = true;
    p.gun_height = 0.8;
    assert_eq!(
        v.weapon_muzzle(p, false).unwrap(),
        Vector3::new(0.0, 0.8, -3.3)
    );
    p.socket = Some(Socket {
        point: Vector3::new(0.0, 2.0, -4.0),
        pivot: Some(Vector3::Y * 2.0),
    });
    let v = Vehicle {
        turret_yaw: std::f64::consts::FRAC_PI_2,
        ..v
    };
    assert!(
        v.weapon_muzzle(p, true)
            .unwrap()
            .distance(Vector3::new(-4.0, 2.0, 0.0))
            < 0.00001
    );
}

#[test]
fn aircraft_socket_geometry_includes_pitch_and_roll() {
    let v = Vehicle {
        id: 1,
        flight_pitch: std::f64::consts::FRAC_PI_2,
        ..Default::default()
    };
    let p = Muzzle {
        socket: Some(Socket {
            point: Vector3::NEG_Z * 4.0,
            pivot: None,
        }),
        helicopter: true,
        ..profile().muzzle
    };
    assert!(v.weapon_muzzle(p, true).unwrap().distance(Vector3::Y * 4.0) < 0.00001);
    let v = Vehicle {
        flight_pitch: 0.0,
        flight_roll: std::f64::consts::FRAC_PI_2,
        ..v
    };
    let p = Muzzle {
        socket: Some(Socket {
            point: Vector3::X * 2.0,
            pivot: None,
        }),
        ..p
    };
    assert!(
        v.weapon_muzzle(p, false)
            .unwrap()
            .distance(Vector3::Y * 2.0)
            < 0.00001
    );
}

#[test]
fn cannon_hits_obstructions_but_excludes_the_firing_vehicle() {
    let mut a = actors(false);
    let terrain = Terrain::blank(128).unwrap();
    let mut collision = CollisionWorld::default();
    for (id, z) in [(1, -9.0), (99, -20.0)] {
        collision.replace(
            id,
            &[BoxShape {
                body: id,
                shape: 0,
                center: Vector3::new(0.0, 1.0, z),
                basis: Mat3::IDENTITY,
                half: Vector3::new(10.0, 10.0, 0.5),
            }],
        );
    }
    let shot = a
        .fire_vehicle_cannon(
            1,
            2,
            7.1,
            profile(),
            &terrain,
            &mut collision,
            &mut SimulationRandom::new(137),
        )
        .unwrap();
    assert!((shot.blast.position.z + 19.5).abs() < 0.0001);
    assert_eq!(shot.blast.source, 1);
    assert_eq!(shot.blast.team, 0);
    assert_eq!(shot.blast.structure_multiplier, 2.5);
    assert_eq!(a.vehicle(1).unwrap().last_fire, 7.1);
}

#[test]
fn trench_lips_intercept_flat_shots_unless_the_gun_looks_down_the_bay() {
    let mut terrain = Terrain::blank(128).unwrap();
    for z in 32..37 {
        for x in 62..67 {
            terrain.layers[TRENCH][z * 128 + x] = 1;
        }
    }
    let mut a = actors(true);
    let saved = a.checkpoint().unwrap();
    let mut collision = CollisionWorld::default();
    let lip = a
        .fire_vehicle_cannon(
            1,
            2,
            10.0,
            profile(),
            &terrain,
            &mut collision,
            &mut SimulationRandom::new(137),
        )
        .unwrap();
    assert!(lip.blast.position.z > -28.5);
    let at = Vector3::NEG_Z * 30.0;
    let shape = CoverStructure {
        position: at,
        radius: 5.0,
        kind: 0,
        rubble: false,
        dug: true,
        parts: vec![],
        footprint: [glam::Vec2::ZERO; 5],
        trench: [at - Vector3::Z * 4.0, at + Vector3::Z * 4.0],
    };
    assert!(terrain.scene.register(9, shape, vec![(-1, -2), (0, -2)]));
    assert!(terrain.scene.trench_enfiladed(at, Vector3::ZERO));
    let mut a = Actors::restore(&saved).unwrap();
    let down_bay = a
        .fire_vehicle_cannon(
            1,
            2,
            10.0,
            profile(),
            &terrain,
            &mut collision,
            &mut SimulationRandom::new(137),
        )
        .unwrap();
    assert!(down_bay.blast.position.z < -29.5);
}

#[test]
fn cannon_randomness_and_impact_resume_from_owned_actor_state() {
    let mut a = actors(false);
    let mut rng = SimulationRandom::new(137);
    let terrain = Terrain::blank(128).unwrap();
    let mut collision = CollisionWorld::default();
    a.fire_vehicle_cannon(1, 2, 10.0, profile(), &terrain, &mut collision, &mut rng)
        .unwrap();
    let mut b = Actors::restore(&a.checkpoint().unwrap()).unwrap();
    let mut resumed = rng.clone();
    assert_eq!(
        a.fire_vehicle_cannon(1, 2, 10.1, profile(), &terrain, &mut collision, &mut rng),
        b.fire_vehicle_cannon(
            1,
            2,
            10.1,
            profile(),
            &terrain,
            &mut collision,
            &mut resumed
        )
    );
    assert_eq!(a.checkpoint().unwrap(), b.checkpoint().unwrap());
    assert_eq!(rng.state(), resumed.state());
}

#[test]
fn invalid_cannon_requests_leave_state_and_randomness_unchanged() {
    let mut a = actors(false);
    let terrain = Terrain::blank(128).unwrap();
    let mut collision = CollisionWorld::default();
    let mut rng = SimulationRandom::new(137);
    let saved = a.checkpoint().unwrap();
    let cursor = rng.state();
    assert!(a
        .fire_vehicle_cannon(1, 99, 10.1, profile(), &terrain, &mut collision, &mut rng)
        .is_err());
    assert!(a
        .fire_vehicle_cannon(
            1,
            2,
            f64::NAN,
            profile(),
            &terrain,
            &mut collision,
            &mut rng
        )
        .is_err());
    let mut p = profile();
    p.muzzle.socket = Some(Socket {
        point: Vector3::NAN,
        pivot: None,
    });
    assert!(a
        .fire_vehicle_cannon(1, 2, 10.1, p, &terrain, &mut collision, &mut rng)
        .is_err());
    assert_eq!(a.checkpoint().unwrap(), saved);
    assert_eq!(rng.state(), cursor);
}
