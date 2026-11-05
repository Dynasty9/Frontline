use frontline_core::random::SimulationRandom;
use frontline_core::vector::Vector3;
use frontline_core::vehicle::Vehicle;
use frontline_core::vehicle_weapon::{Fire, FireProfile, Target, TargetKind};

fn profile() -> FireProfile<'static> {
    FireProfile {
        base: "tank",
        cannon: true,
        armor: 2,
        machine_gun: "mg",
        burst: [3, 6],
        interval: 0.1,
        cannon_cooldown: 5.5,
        sam_cooldown: 8.0,
        sam_range: 160.0,
        atgm_cooldown: 12.0,
        atgm_range: 125.0,
    }
}
fn target(kind: TargetKind, distance: f32) -> Option<Target> {
    Some(Target {
        position: Vector3::NEG_Z * distance,
        kind,
    })
}
fn tank() -> Vehicle {
    Vehicle {
        id: 1,
        aim_time: 1.0,
        cannon_timer: 0.0,
        ..Default::default()
    }
}

#[test]
fn guided_weapons_take_priority_and_keep_exact_deadline_and_range_gates() {
    let mut v = tank();
    v.sam_left = 1;
    v.atgm_left = 2;
    let mut rng = SimulationRandom::new(137);
    let saved = rng.state();
    let air = target(
        TargetKind::Vehicle {
            air: true,
            armor: 1,
        },
        100.0,
    );
    assert_eq!(
        v.choose_weapon(31.7, profile(), air, &mut rng).unwrap(),
        Fire::Sam
    );
    v.finish_weapon(Fire::Sam, 31.7, profile(), &mut rng)
        .unwrap();
    assert_eq!((v.sam_left, v.sam_until), (0, 39.7));
    assert_eq!(
        v.choose_weapon(31.7, profile(), air, &mut rng).unwrap(),
        Fire::Cannon
    );
    let ground = target(
        TargetKind::Vehicle {
            air: false,
            armor: 2,
        },
        50.0,
    );
    assert_eq!(
        v.choose_weapon(31.7, profile(), ground, &mut rng).unwrap(),
        Fire::Atgm
    );
    v.atgm_until = 31.7;
    assert_eq!(
        v.choose_weapon(31.7, profile(), ground, &mut rng).unwrap(),
        Fire::Cannon
    );
    v.atgm_until = 0.0;
    assert_eq!(
        v.choose_weapon(
            31.7,
            profile(),
            target(TargetKind::Structure { fortified: true }, 22.0),
            &mut rng
        )
        .unwrap(),
        Fire::Cannon
    );
    assert_eq!(rng.state(), saved);
}

#[test]
fn tanks_wait_for_settled_aim_and_cannons_keep_their_infantry_priorities() {
    let mut rng = SimulationRandom::new(137);
    let mut v = tank();
    let troop = target(
        TargetKind::Soldier {
            nearby: 2,
            rockets: false,
            mounted: false,
        },
        40.0,
    );
    v.aim_time = 0.29;
    assert_eq!(
        v.choose_weapon(31.7, profile(), troop, &mut rng).unwrap(),
        Fire::MachineGun
    );
    v.aim_time = 0.3;
    let cursor = rng.state();
    for kind in [
        TargetKind::Soldier {
            nearby: 2,
            rockets: false,
            mounted: false,
        },
        TargetKind::Soldier {
            nearby: 1,
            rockets: true,
            mounted: false,
        },
        TargetKind::Soldier {
            nearby: 1,
            rockets: false,
            mounted: true,
        },
    ] {
        assert_eq!(
            v.choose_weapon(31.7, profile(), target(kind, 40.0), &mut rng)
                .unwrap(),
            Fire::Cannon
        );
    }
    assert_eq!(rng.state(), cursor);
    let mut cannon = 0;
    for seed in 0..100 {
        if v.choose_weapon(
            31.7,
            profile(),
            target(
                TargetKind::Soldier {
                    nearby: 1,
                    rockets: false,
                    mounted: false,
                },
                40.0,
            ),
            &mut SimulationRandom::new(seed),
        )
        .unwrap()
            == Fire::Cannon
        {
            cannon += 1;
        }
    }
    assert!(cannon > 0 && cannon < 100);
}

#[test]
fn machine_guns_preserve_heavy_armor_structure_and_range_limits() {
    let mut v = tank();
    let mut rng = SimulationRandom::new(137);
    let p = FireProfile {
        cannon: false,
        ..profile()
    };
    assert_eq!(
        v.choose_weapon(
            31.7,
            p,
            target(
                TargetKind::Vehicle {
                    air: false,
                    armor: 2
                },
                30.0
            ),
            &mut rng
        )
        .unwrap(),
        Fire::None
    );
    assert_eq!(
        v.choose_weapon(
            31.7,
            FireProfile {
                machine_gun: "chaingun",
                ..p
            },
            target(
                TargetKind::Vehicle {
                    air: false,
                    armor: 2
                },
                30.0
            ),
            &mut rng
        )
        .unwrap(),
        Fire::MachineGun
    );
    assert_eq!(
        v.choose_weapon(
            31.7,
            p,
            target(TargetKind::Structure { fortified: false }, 30.0),
            &mut rng
        )
        .unwrap(),
        Fire::None
    );
    let p = FireProfile {
        base: "attack_heli",
        ..p
    };
    assert_eq!(
        v.choose_weapon(
            31.7,
            p,
            target(TargetKind::Structure { fortified: false }, 90.0),
            &mut rng
        )
        .unwrap(),
        Fire::MachineGun
    );
    assert_eq!(
        v.choose_weapon(31.7, p, target(TargetKind::Other, 105.0), &mut rng)
            .unwrap(),
        Fire::None
    );
}

#[test]
fn burst_recovery_draw_occurs_after_shared_bullet_effects() {
    let mut v = tank();
    let p = FireProfile {
        cannon: false,
        burst: [1, 1],
        ..profile()
    };
    let mut rng = SimulationRandom::new(137);
    let mut reference = rng.clone();
    assert_eq!(
        v.choose_weapon(31.7, p, target(TargetKind::Other, 30.0), &mut rng)
            .unwrap(),
        Fire::MachineGun
    );
    reference.randi_range(1, 1);
    for _ in 0..4 {
        rng.randf();
        reference.randf();
    }
    v.finish_weapon(Fire::MachineGun, 31.7, p, &mut rng)
        .unwrap();
    assert_eq!(v.mg_timer, f64::from(reference.randf_range(0.6, 1.3)));
    assert_eq!(rng.state(), reference.state());
    assert_eq!(v.last_fire, 31.7);
}

#[test]
fn completed_weapon_cycles_resume_from_checkpointed_ammo_and_bursts() {
    let mut a = tank();
    let mut random = SimulationRandom::new(137);
    let mut b = Vehicle::restore(&a.checkpoint().unwrap()).unwrap();
    let mut resumed = random.clone();
    for step in 0..100 {
        a.mg_timer = 0.0;
        b.mg_timer = 0.0;
        let p = FireProfile {
            cannon: false,
            ..profile()
        };
        let t = target(TargetKind::Other, 30.0);
        let fire = a.choose_weapon(step as f64, p, t, &mut random).unwrap();
        assert_eq!(
            fire,
            b.choose_weapon(step as f64, p, t, &mut resumed).unwrap()
        );
        a.finish_weapon(fire, step as f64, p, &mut random).unwrap();
        b.finish_weapon(fire, step as f64, p, &mut resumed).unwrap();
        assert_eq!(a, b);
        assert_eq!(random.state(), resumed.state());
        if step % 7 == 0 {
            b = Vehicle::restore(&b.checkpoint().unwrap()).unwrap();
        }
    }
}

#[test]
fn invalid_weapon_requests_leave_vehicle_and_randomness_unchanged() {
    let mut v = tank();
    let mut rng = SimulationRandom::new(137);
    let saved = v.clone();
    let cursor = rng.state();
    assert!(v
        .choose_weapon(f64::NAN, profile(), None, &mut rng)
        .is_err());
    assert!(v
        .choose_weapon(
            31.7,
            FireProfile {
                burst: [6, 3],
                ..profile()
            },
            target(TargetKind::Other, 30.0),
            &mut rng
        )
        .is_err());
    assert!(v
        .finish_weapon(Fire::Sam, 31.7, profile(), &mut rng)
        .is_err());
    assert_eq!(v, saved);
    assert_eq!(rng.state(), cursor);
}
