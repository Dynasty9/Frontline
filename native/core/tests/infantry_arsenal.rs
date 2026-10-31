use frontline_core::collision::{BoxShape, CollisionWorld, Mat3};
use frontline_core::infantry_arsenal::{
    InfantryArsenal, MeleeContact, MortarDecision, MortarTarget, RocketContact, RocketInput,
};
use frontline_core::infantry_vitals::Life;
use frontline_core::random::SimulationRandom;
use frontline_core::vector::Vector3;
use frontline_core::visibility::{Smoke, Visibility};

fn contact(id: u64, distance: f32) -> RocketContact {
    RocketContact {
        id,
        position: Vector3::new(distance, 0.0, 0.0),
        center: Vector3::new(distance, 1.6, 0.0),
        gone: false,
        age: 0.0,
        excluded: vec![],
    }
}
fn arsenal() -> InfantryArsenal {
    InfantryArsenal {
        rockets: 10,
        drones: 10,
        mortar_rounds: 10,
        ..Default::default()
    }
}

#[test]
fn rockets_keep_visible_reported_and_forced_priority() {
    let mut collision = CollisionWorld::default();
    let visibility = Visibility::default();
    let visible = [contact(1, 75.0), contact(2, 74.99), contact(3, 20.0)];
    let mut reported = [contact(4, 70.0), contact(5, 69.99), contact(6, 50.0)];
    reported[1].age = 6.0;
    let mut i = RocketInput {
        time: 10.0,
        position: Vector3::ZERO,
        eye: Vector3::new(0.0, 1.6, 0.0),
        ambush: false,
        visible: &visible,
        reported: &reported,
        forced: Some(contact(7, 59.99)),
    };
    let mut state = arsenal();
    assert_eq!(
        state.rocket(i, &mut collision, &visibility).unwrap(),
        Some(2)
    );
    assert_eq!((state.rockets, state.rocket_ready), (9, 14.5));
    i = RocketInput {
        time: 14.5,
        position: Vector3::ZERO,
        eye: Vector3::new(0.0, 1.6, 0.0),
        ambush: false,
        visible: &[],
        reported: &reported,
        forced: Some(contact(7, 59.99)),
    };
    assert_eq!(
        state.rocket(i, &mut collision, &visibility).unwrap(),
        Some(6)
    );
    let mut hidden = contact(8, 20.0);
    hidden.gone = true;
    for (forced, expected) in [(contact(9, 60.0), None), (contact(9, 59.99), Some(9))] {
        let i = RocketInput {
            time: 30.0,
            position: Vector3::ZERO,
            eye: Vector3::ZERO,
            ambush: false,
            visible: &[],
            reported: &[hidden.clone()],
            forced: Some(forced),
        };
        assert_eq!(
            arsenal().rocket(i, &mut collision, &visibility).unwrap(),
            expected
        );
    }
}

#[test]
fn reported_rockets_respect_cover_smoke_exclusions_and_ambush() {
    let mut collision = CollisionWorld::default();
    collision.replace(
        10,
        &[BoxShape {
            body: 10,
            shape: 0,
            center: Vector3::new(5.0, 1.6, 0.0),
            basis: Mat3::IDENTITY,
            half: Vector3::ONE,
        }],
    );
    let mut visibility = Visibility::default();
    for case in 0..4 {
        let mut c = contact(2, 10.0);
        if case > 0 {
            c.excluded = vec![10];
        }
        if case == 2 {
            assert!(visibility.set_projectile(
                20,
                Smoke {
                    center: Vector3::new(3.0, 1.6, 0.0),
                    radius: 1.0
                }
            ));
        }
        if case == 3 {
            visibility.remove_projectile(20);
        }
        let i = RocketInput {
            time: 10.0,
            position: Vector3::ZERO,
            eye: Vector3::new(0.0, 1.6, 0.0),
            ambush: case == 3,
            visible: &[],
            reported: &[c],
            forced: None,
        };
        let mut state = arsenal();
        assert_eq!(
            state.rocket(i, &mut collision, &visibility).unwrap(),
            if case == 1 { Some(2) } else { None }
        );
        assert_eq!(state.rockets, if case == 1 { 9 } else { 10 });
    }
}

#[test]
fn melee_retains_order_life_and_weapon_gates() {
    let contacts = [
        MeleeContact {
            id: 1,
            team: 0,
            life: Life::Alive,
            flinging: false,
        },
        MeleeContact {
            id: 2,
            team: -1,
            life: Life::Alive,
            flinging: false,
        },
        MeleeContact {
            id: 3,
            team: 1,
            life: Life::Downed,
            flinging: false,
        },
        MeleeContact {
            id: 4,
            team: 1,
            life: Life::Alive,
            flinging: true,
        },
        MeleeContact {
            id: 5,
            team: 1,
            life: Life::Alive,
            flinging: false,
        },
        MeleeContact {
            id: 6,
            team: 1,
            life: Life::Alive,
            flinging: false,
        },
    ];
    let mut state = arsenal();
    assert_eq!(state.melee(10.0, 0, false, &contacts).unwrap(), None);
    assert_eq!(state.melee(10.0, 0, true, &contacts).unwrap(), Some(5));
    assert_eq!(state.melee_ready, 11.4);
    assert_eq!(state.melee(11.39, 0, true, &contacts).unwrap(), None);
    assert_eq!(state.melee(11.4, 0, true, &contacts).unwrap(), Some(5));
}

#[test]
fn drone_launch_preserves_probe_delay_inventory_and_random_draws() {
    let mut state = arsenal();
    let mut rng = SimulationRandom::new(691);
    let mut expected = rng;
    assert_eq!(state.drone(10.0, true, Some(1), &mut rng).unwrap(), None);
    assert_eq!(state.drone(10.0, false, None, &mut rng).unwrap(), None);
    assert_eq!(state.drone_ready, 13.0);
    assert_eq!(state.drone(12.99, false, Some(1), &mut rng).unwrap(), None);
    assert_eq!(rng, expected);
    assert_eq!(
        state.drone(13.0, false, Some(1), &mut rng).unwrap(),
        Some(1)
    );
    assert_eq!(
        state.drone_ready,
        13.0 + f64::from(expected.randf_range(18.0, 26.0))
    );
    assert_eq!(state.drones, 9);
    assert_eq!(rng, expected);
}

#[test]
fn mortar_preserves_queued_range_limits_and_automatic_probe_delay() {
    for (distance, allowed) in [(24.99, false), (25.0, true), (140.0, true), (140.01, false)] {
        let mut state = arsenal();
        let p = Vector3::new(distance, 300.0, 0.0);
        assert_eq!(
            state
                .mortar(10.0, Vector3::ZERO, false, true, MortarTarget::Queued(p))
                .unwrap(),
            if allowed {
                MortarDecision::Fire(p)
            } else {
                MortarDecision::CancelQueue
            }
        );
        assert_eq!(state.mortar_rounds, if allowed { 9 } else { 10 });
        assert_eq!(state.mortar_ready, if allowed { 13.5 } else { 0.0 });
    }
    let mut state = arsenal();
    assert_eq!(
        state
            .mortar(
                10.0,
                Vector3::ZERO,
                false,
                true,
                MortarTarget::Automatic(None)
            )
            .unwrap(),
        MortarDecision::Wait
    );
    assert_eq!(state.mortar_ready, 12.0);
    for (moving, squad, now) in [
        (true, true, 12.0),
        (false, false, 12.0),
        (false, true, 11.9),
    ] {
        assert_eq!(
            state
                .mortar(
                    now,
                    Vector3::ZERO,
                    moving,
                    squad,
                    MortarTarget::Automatic(Some(Vector3::X * 70.0))
                )
                .unwrap(),
            MortarDecision::Wait
        );
        assert_eq!(state.mortar_rounds, 10);
    }
}

#[test]
fn arsenal_checkpoints_and_invalid_input_are_atomic() {
    let mut state = arsenal();
    let original = state;
    let bytes = state.checkpoint();
    assert_eq!(InfantryArsenal::restore(&bytes).unwrap(), state);
    for length in 0..bytes.len() {
        assert!(InfantryArsenal::restore(&bytes[..length]).is_err());
    }
    let mut bad = bytes.clone();
    bad.push(0);
    assert!(InfantryArsenal::restore(&bad).is_err());
    assert!(InfantryArsenal::restore(
        &InfantryArsenal {
            rockets: -1,
            ..state
        }
        .checkpoint()
    )
    .is_err());
    let mut rng = SimulationRandom::new(3);
    let cursor = rng;
    assert!(state.drone(10.0, false, Some(0), &mut rng).is_err());
    assert!(state
        .mortar(
            10.0,
            Vector3::ZERO,
            false,
            true,
            MortarTarget::Queued(Vector3::splat(f32::NAN))
        )
        .is_err());
    assert!(state.melee(f64::NAN, 0, true, &[]).is_err());
    assert_eq!(state, original);
    assert_eq!(rng, cursor);
}
