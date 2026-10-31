use frontline_core::random::SimulationRandom;
use frontline_core::vector::Vector3;
use frontline_core::vehicle::Vehicle;
use frontline_core::vehicle_damage::{Armor, Blast};

fn armor(level: u8) -> Armor {
    Armor {
        level,
        helicopter: false,
        boat: false,
        supply: false,
        toss: 0.3,
    }
}
fn blast() -> Blast {
    Blast {
        position: Vector3::new(0.0, 0.0, -2.0),
        size: 2.0,
        anti_tank: 320.0,
        direction: Some(Vector3::Z),
        top: false,
        track: 0.3,
        radius: 5.0,
        damage: 100.0,
        vehicle_multiplier: 1.0,
    }
}

#[test]
fn bullets_preserve_armor_and_aircraft_multipliers() {
    let v = Vehicle::default();
    for (level, ap, expected) in [
        (0, false, 35.0),
        (0, true, 100.0),
        (1, false, 5.0),
        (1, true, 45.0),
        (2, false, 0.0),
        (2, true, 3.0),
    ] {
        assert_eq!(
            v.bullet_damage(armor(level), 100.0, ap, false).unwrap(),
            expected
        );
    }
    let mut v = v;
    v.position.y = 5.0;
    let a = Armor {
        helicopter: true,
        ..armor(1)
    };
    assert_eq!(v.bullet_damage(a, 100.0, false, true).unwrap(), 160.0);
    assert_eq!(v.bullet_damage(armor(1), 100.0, false, true).unwrap(), 5.0);
}

#[test]
fn front_rear_top_and_side_hits_preserve_damage_and_track_breaks() {
    for (direction, top, damage) in [
        (Vector3::NEG_Z, false, 432.0),
        (Vector3::X, false, 320.0),
        (Vector3::Z, true, 320.0),
    ] {
        let mut v = Vehicle::default();
        let mut rng = SimulationRandom::new(137);
        let hit = v
            .explosion_hit(
                31.7,
                armor(2),
                Blast {
                    direction: Some(direction),
                    top,
                    track: 1.0,
                    ..blast()
                },
                &mut rng,
            )
            .unwrap();
        assert_eq!(hit.damage, damage);
        assert!(hit.anti_tank && !hit.bounced && hit.track_broken && v.track_broken);
    }
    let mut bounced = 0;
    for seed in 0..100 {
        let mut v = Vehicle::default();
        let hit = v
            .explosion_hit(31.7, armor(2), blast(), &mut SimulationRandom::new(seed))
            .unwrap();
        if hit.bounced {
            bounced += 1;
            assert_eq!(hit.damage, 0.0);
            assert!(!hit.track_broken);
        } else {
            assert_eq!(hit.damage, 192.0);
        }
        assert!(v.knock_velocity.z > 0.0 && v.last_blast.is_some());
    }
    assert!(bounced > 0 && bounced < 100);
}

#[test]
fn aircraft_boats_and_convoys_do_not_lose_tracks() {
    for a in [
        Armor {
            helicopter: true,
            ..armor(1)
        },
        Armor {
            boat: true,
            ..armor(1)
        },
        Armor {
            supply: true,
            ..armor(1)
        },
    ] {
        let mut v = Vehicle::default();
        let mut rng = SimulationRandom::new(137);
        let saved = rng.state();
        let hit = v
            .explosion_hit(
                31.7,
                a,
                Blast {
                    track: 1.0,
                    ..blast()
                },
                &mut rng,
            )
            .unwrap();
        assert_eq!(hit.damage, 480.0);
        assert!(!hit.track_broken && !v.track_broken);
        assert_eq!(rng.state(), saved);
    }
    let mut v = Vehicle {
        position: Vector3::Y * 5.0,
        ..Default::default()
    };
    v.explosion_hit(
        31.7,
        Armor {
            helicopter: true,
            ..armor(1)
        },
        blast(),
        &mut SimulationRandom::new(137),
    )
    .unwrap();
    assert_eq!(v.knock_velocity, Vector3::ZERO);
}

#[test]
fn high_explosive_falloff_and_checkpointed_knockback_resume() {
    let mut a = Vehicle {
        id: 1,
        ..Default::default()
    };
    let mut random = SimulationRandom::new(137);
    let hit = a
        .explosion_hit(
            31.7,
            armor(2),
            Blast {
                anti_tank: 0.0,
                ..blast()
            },
            &mut random,
        )
        .unwrap();
    assert_eq!(hit.damage, 100.0 * (1.0 - 2.0 / 7.0) * 0.12);
    let mut b = Vehicle::restore(&a.checkpoint().unwrap()).unwrap();
    let mut resumed = random.clone();
    for step in 0..20 {
        assert_eq!(
            a.explosion_hit(32.0 + step as f64, armor(2), blast(), &mut random),
            b.explosion_hit(32.0 + step as f64, armor(2), blast(), &mut resumed)
        );
        assert_eq!(a, b);
        assert_eq!(random.state(), resumed.state());
    }
}

#[test]
fn vehicle_damage_alerts_and_death_are_single_transitions() {
    let mut v = Vehicle {
        hp: 100.0,
        max_hp: 100.0,
        ..Default::default()
    };
    let first = v.take_damage(60.0, 31.7, false).unwrap();
    assert!(first.applied && first.alert && !first.destroyed);
    assert_eq!(v.alert_time, 51.7);
    let second = v.take_damage(60.0, 32.0, false).unwrap();
    assert!(second.applied && !second.alert && second.destroyed);
    assert_eq!(v.hp, -20.0);
    assert!(!v.take_damage(60.0, 32.1, false).unwrap().applied);
    assert_eq!(v.hp, -20.0);
}

#[test]
fn invalid_damage_and_overflow_preserve_state_and_random_cursor() {
    let mut v = Vehicle {
        hp: 100.0,
        ..Default::default()
    };
    let mut rng = SimulationRandom::new(137);
    let saved = v.clone();
    let cursor = rng.state();
    assert!(v.take_damage(f64::NAN, 31.7, false).is_err());
    assert!(v.take_damage(60.0, 1e12, false).is_err());
    assert!(v
        .explosion_hit(
            31.7,
            armor(2),
            Blast {
                size: 1e12,
                ..blast()
            },
            &mut rng
        )
        .is_err());
    assert_eq!(v, saved);
    assert_eq!(rng.state(), cursor);
}
