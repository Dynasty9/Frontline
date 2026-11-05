use frontline_core::terrain::Terrain;
use frontline_core::vector::Vector3;
use frontline_core::vehicle::Vehicle;
use frontline_core::vehicle_air::{HomeLanding, LiftEvent, SlingTarget, SupplyPoint};
use frontline_core::vehicle_flight::FlightProfile;

fn profile() -> FlightProfile {
    FlightProfile {
        speed: 22.0,
        accel: 5.0,
        brake: 6.0,
        turn: 0.7,
        turn_accel: 0.95,
    }
}
fn helicopter() -> Vehicle {
    Vehicle {
        id: 1,
        flight: Some([0.0; 3]),
        position: Vector3::Y * 0.15,
        ..Default::default()
    }
}

#[test]
fn transport_climbs_cruises_lands_and_returns_after_unloading() {
    let terrain = Terrain::blank(128).unwrap();
    let home = HomeLanding {
        position: Vector3::new(-30.0, 0.0, 0.0),
        landing: Vector3::new(-30.3, 0.0, 0.7),
    };
    let mut v = helicopter();
    v.lift_destination = Some(Vector3::new(21.3, 0.0, -19.7));
    v.passengers = vec![3];
    let mut events = Vec::new();
    let mut phases = std::collections::BTreeSet::new();
    for _ in 0..6000 {
        let event = v
            .lift_guidance(1.0 / 30.0, profile(), &terrain, &[], 0.0, None, Some(home))
            .unwrap();
        phases.insert(v.lift_phase);
        if event == LiftEvent::Dismount {
            events.push(event);
            v.passengers.clear();
        }
    }
    assert_eq!(events, [LiftEvent::Dismount]);
    assert_eq!(phases.into_iter().collect::<Vec<_>>(), [0, 1, 2, 3, 4]);
    assert!(v.position.distance(home.landing + Vector3::Y * 0.15) < 0.01);
}

#[test]
fn sling_pickup_and_drop_wait_for_a_settled_hover() {
    let terrain = Terrain::blank(128).unwrap();
    let mut v = helicopter();
    v.lift_phase = 5;
    v.sling_target = 2;
    let target = SlingTarget {
        id: 2,
        position: Vector3::new(21.3, 0.0, -19.7),
        height: 2.2,
    };
    let mut hooked = false;
    for _ in 0..6000 {
        if v.lift_guidance(
            1.0 / 30.0,
            profile(),
            &terrain,
            &[],
            0.0,
            Some(target),
            None,
        )
        .unwrap()
            == LiftEvent::Hook(2)
        {
            hooked = true;
            break;
        }
    }
    assert!(hooked && v.sling_timer > 1.5);
    assert!((v.position.y - 9.2).abs() < 0.12);
    v.sling_target = 0;
    v.sling_cargo = 2;
    v.lift_phase = 1;
    v.lift_destination = Some(Vector3::new(-21.3, 0.0, 19.7));
    let mut released = false;
    for _ in 0..6000 {
        if v.lift_guidance(1.0 / 30.0, profile(), &terrain, &[], 2.2, None, None)
            .unwrap()
            == LiftEvent::Release
        {
            released = true;
            break;
        }
    }
    assert!(released && v.lift_destination.is_none() && v.lift_phase == 1);
    assert!((v.position.y - 9.35).abs() < 0.12);
}

#[test]
fn missing_pickups_and_nearby_home_preserve_order_semantics() {
    let terrain = Terrain::blank(128).unwrap();
    let mut v = helicopter();
    v.sling_target = 2;
    v.lift_phase = 6;
    assert_eq!(
        v.lift_guidance(0.1, profile(), &terrain, &[], 0.0, None, None)
            .unwrap(),
        LiftEvent::None
    );
    assert_eq!((v.sling_target, v.lift_phase), (0, 1));
    v.lift_phase = 4;
    v.lift_timer = 0.01;
    let destination = Vector3::new(3.0, 0.0, 1.0);
    v.lift_destination = Some(destination);
    v.lift_guidance(
        0.1,
        profile(),
        &terrain,
        &[],
        0.0,
        None,
        Some(HomeLanding {
            position: Vector3::ZERO,
            landing: Vector3::X,
        }),
    )
    .unwrap();
    assert_eq!(v.lift_destination, Some(destination));
}

#[test]
fn supply_destinations_preserve_need_ties_and_abort_on_capture() {
    let terrain = Terrain::blank(128).unwrap();
    let mut v = helicopter();
    let fobs = [
        SupplyPoint {
            id: 3,
            position: Vector3::X * 20.0,
            supply: 30.0,
        },
        SupplyPoint {
            id: 2,
            position: Vector3::X * -20.0,
            supply: 30.0,
        },
    ];
    v.supply_guidance(0.1, profile(), &terrain, &[], &fobs, None, Vector3::ZERO)
        .unwrap();
    assert_eq!((v.heli_destination, v.heli_phase), (3, 1));
    v.heli_phase = 2;
    v.supply_guidance(0.1, profile(), &terrain, &[], &fobs, None, Vector3::ZERO)
        .unwrap();
    assert_eq!(v.heli_phase, 5);
    v.heli_phase = 7;
    v.flight_hold = Some(Vector3::Y * 0.15);
    v.heli_timer = 0.01;
    assert_eq!(
        v.supply_guidance(0.1, profile(), &terrain, &[], &fobs, None, Vector3::ZERO)
            .unwrap(),
        None
    );
    assert_eq!(v.heli_phase, 4);
}

#[test]
fn supply_delivery_and_flight_resume_from_checkpoints() {
    let terrain = Terrain::blank(128).unwrap();
    let mut a = helicopter();
    let fob = SupplyPoint {
        id: 2,
        position: Vector3::new(21.3, 0.0, -19.7),
        supply: 0.0,
    };
    let mut b = a.clone();
    let mut delivered = 0;
    let mut phases = std::collections::BTreeSet::new();
    for step in 0..6000 {
        let event = a
            .supply_guidance(
                1.0 / 30.0,
                profile(),
                &terrain,
                &[],
                &[fob],
                Some(fob),
                Vector3::ZERO,
            )
            .unwrap();
        assert_eq!(
            event,
            b.supply_guidance(
                1.0 / 30.0,
                profile(),
                &terrain,
                &[],
                &[fob],
                Some(fob),
                Vector3::ZERO
            )
            .unwrap()
        );
        assert_eq!(a, b);
        if event.is_some() {
            delivered += 1;
        }
        phases.insert(a.heli_phase);
        if step % 19 == 0 {
            b = Vehicle::restore(&b.checkpoint().unwrap()).unwrap();
        }
    }
    assert!(delivered >= 2);
    assert_eq!(
        phases.into_iter().collect::<Vec<_>>(),
        (0..8).collect::<Vec<_>>()
    );
}

#[test]
fn invalid_flight_inputs_are_rejected_before_state_changes() {
    let terrain = Terrain::blank(128).unwrap();
    let mut v = helicopter();
    let saved = v.clone();
    assert!(v
        .lift_guidance(f64::NAN, profile(), &terrain, &[], 0.0, None, None)
        .is_err());
    assert!(v
        .supply_guidance(0.1, profile(), &terrain, &[], &[], None, Vector3::NAN)
        .is_err());
    assert_eq!(v, saved);
    v.lift_phase = 2;
    let saved = v.clone();
    assert!(v
        .lift_guidance(0.1, profile(), &terrain, &[], 0.0, None, None)
        .is_err());
    assert_eq!(v, saved);
}
