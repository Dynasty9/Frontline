use frontline_core::terrain::Terrain;
use frontline_core::vector::Vector3;
use frontline_core::vehicle::Vehicle;
use frontline_core::vehicle_flight::FlightProfile;

fn profile() -> FlightProfile {
    FlightProfile {
        speed: 23.0,
        accel: 6.0,
        brake: 6.0,
        turn: 2.3,
        turn_accel: 4.0,
    }
}
fn gunship() -> Vehicle {
    Vehicle {
        id: 1,
        position: Vector3::Y * 14.0,
        flight: Some([0.0; 3]),
        rocket_timer: 0.0,
        ..Default::default()
    }
}

#[test]
fn scanning_and_rocket_deadlines_advance_before_target_decisions() {
    let mut v = gunship();
    assert!(v.gunship_begin(0.1).unwrap());
    assert_eq!(v.scan_timer, 0.4);
    assert_eq!(v.rocket_timer, -0.1);
    assert!(!v.gunship_begin(0.1).unwrap());
    let before = v.clone();
    assert!(v.gunship_begin(f64::NAN).is_err());
    assert_eq!(v, before);
}
#[test]
fn rocket_salvos_require_aim_range_worth_ammunition_and_a_finished_cooldown() {
    let mut v = gunship();
    let target = Some(Vector3::NEG_Z * 70.0);
    assert!(!v.gunship_rockets_due(target, false, 4).unwrap());
    assert!(!v.gunship_rockets_due(target, true, 0).unwrap());
    assert!(!v
        .gunship_rockets_due(Some(Vector3::X * 70.0), true, 4)
        .unwrap());
    assert!(!v
        .gunship_rockets_due(Some(Vector3::NEG_Z * 100.0), true, 4)
        .unwrap());
    assert!(v.gunship_rockets_due(target, true, 4).unwrap());
    assert_eq!(v.rocket_timer, 9.0);
    assert!(!v.gunship_rockets_due(target, true, 4).unwrap());
    v.gunship_begin(9.0).unwrap();
    assert!(v.gunship_rockets_due(target, true, 4).unwrap());
}
#[test]
fn guidance_resumes_orbits_and_damaged_aircraft_descend() {
    let terrain = Terrain::blank(256).unwrap();
    let mut a = gunship();
    a.hp = 20.0;
    a.max_hp = 100.0;
    for _ in 0..120 {
        a.gunship_guidance(
            1.0 / 30.0,
            Some(Vector3::NEG_Z * 70.0),
            profile(),
            &terrain,
            &[],
        )
        .unwrap();
    }
    assert!(a.position.y < 11.0);
    let mut b = Vehicle::restore(&a.checkpoint().unwrap()).unwrap();
    for _ in 0..120 {
        a.gunship_guidance(
            1.0 / 30.0,
            Some(Vector3::NEG_Z * 70.0),
            profile(),
            &terrain,
            &[],
        )
        .unwrap();
        b.gunship_guidance(
            1.0 / 30.0,
            Some(Vector3::NEG_Z * 70.0),
            profile(),
            &terrain,
            &[],
        )
        .unwrap();
    }
    assert_eq!(a, b);
    let saved = a.clone();
    assert!(a
        .gunship_guidance(0.1, Some(Vector3::NAN), profile(), &terrain, &[])
        .is_err());
    assert_eq!(a, saved);
}
