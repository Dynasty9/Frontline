use frontline_core::collision::{BoxShape, CollisionWorld, Mat3};
use frontline_core::grenade_reaction::{
    self as grenade, Grenade, GrenadeMemory, Mate, Reaction, Shell, Soldier,
};
use frontline_core::infantry_pose::Posture;
use frontline_core::infantry_vitals::Life;
use frontline_core::random::SimulationRandom;
use frontline_core::vector::Vector3 as V;

fn soldier() -> Soldier {
    Soldier {
        id: 1,
        position: V::ZERO,
        center: V::Y,
        yaw: 0.0,
        team: 0,
        suppression: 0.0,
        posture: Posture::Stand,
        squad: true,
        mounted: false,
        riding: false,
        armed: true,
    }
}
fn round() -> Grenade {
    Grenade {
        id: 2,
        position: V::X * 1.5,
        fuse: 2.0,
        held: false,
        gone: false,
        flying: false,
        free: true,
        smothered: false,
        thrown_back: 0,
    }
}

#[test]
fn mortar_warning_history_can_exceed_the_grenade_eviction_threshold() {
    let mut memory = GrenadeMemory {
        seen: (100..165).collect(),
    };
    assert_eq!(
        GrenadeMemory::restore(&memory.checkpoint()).unwrap(),
        memory
    );
    let before = memory.clone();
    let remembered = Grenade { id: 100, ..round() };
    let distant = Grenade {
        position: V::X * 20.0,
        ..round()
    };
    assert_eq!(
        memory
            .notice(V::ZERO, &[remembered, distant], true)
            .unwrap(),
        None
    );
    assert_eq!(memory, before);
    assert_eq!(memory.notice(V::ZERO, &[round()], true).unwrap(), Some(2));
    assert_eq!(memory.seen, vec![2]);
    let mut duplicate = before;
    duplicate.seen.push(100);
    assert!(!duplicate.valid());
    assert!(GrenadeMemory::restore(&duplicate.checkpoint()).is_err());
    let mut excess = memory.checkpoint();
    excess[8..12].copy_from_slice(&((grenade::MAX_REMEMBERED_ROUNDS + 1) as u32).to_le_bytes());
    assert!(GrenadeMemory::restore(&excess).is_err());
}

#[test]
fn shell_warnings_keep_order_and_stop_after_the_first_dive() {
    let shells: Vec<_> = [20.0, 14.0, 8.0, 4.5, 4.49, 2.0]
        .into_iter()
        .enumerate()
        .map(|(i, x)| Shell {
            id: i as u64 + 1,
            target: V::new(x, 0.0, 0.0),
            flight_time: 1.6,
            age: 0.0,
        })
        .collect();
    let mut memory = GrenadeMemory::default();
    let notices = memory.incoming_shells(V::ZERO, &shells, false).unwrap();
    assert_eq!(memory.seen, vec![2, 3, 4, 5]);
    assert_eq!(
        notices.iter().map(|n| n.force_warning).collect::<Vec<_>>(),
        [false, false, true, true]
    );
    assert_eq!(
        notices.iter().map(|n| n.dive).collect::<Vec<_>>(),
        [false, false, false, true]
    );
    let mut busy = GrenadeMemory::default();
    assert!(busy
        .incoming_shells(V::ZERO, &shells, true)
        .unwrap()
        .iter()
        .all(|n| !n.dive));
    assert_eq!(busy.seen, vec![2, 3, 4, 5, 6]);
    assert!(busy
        .incoming_shells(V::ZERO, &shells, true)
        .unwrap()
        .is_empty());
    let before = busy.clone();
    let invalid = Shell {
        id: 10,
        target: V::NAN,
        ..shells[0]
    };
    assert!(busy.incoming_shells(V::ZERO, &[invalid], false).is_err());
    assert_eq!(busy, before);
    let mut full = GrenadeMemory {
        seen: (100..100 + grenade::MAX_REMEMBERED_ROUNDS as u64).collect(),
    };
    let before = full.checkpoint();
    assert!(full.incoming_shells(V::ZERO, &shells, true).is_err());
    assert_eq!(full.checkpoint(), before);
}

#[test]
fn notice_preserves_projectile_order_flight_distance_and_memory_eviction() {
    let mut memory = GrenadeMemory::default();
    let distant = Grenade {
        id: 3,
        position: V::X * 7.6,
        ..round()
    };
    let airborne = Grenade {
        id: 4,
        position: V::X * 5.0,
        flying: true,
        fuse: 2.3,
        ..round()
    };
    assert_eq!(
        memory
            .notice(V::ZERO, &[distant, airborne, round()], true)
            .unwrap(),
        Some(2)
    );
    assert_eq!(memory.notice(V::ZERO, &[round()], true).unwrap(), None);
    memory.seen = (3..=27).collect();
    assert_eq!(memory.notice(V::ZERO, &[round()], true).unwrap(), Some(2));
    assert_eq!(memory.seen, vec![2]);
    let gone = Grenade {
        id: 29,
        gone: true,
        ..round()
    };
    assert_eq!(memory.notice(V::ZERO, &[gone], true).unwrap(), None);
    assert_eq!(memory.notice(V::ZERO, &[gone], false).unwrap(), Some(29));
    assert_eq!(
        GrenadeMemory::restore(&memory.checkpoint()).unwrap(),
        memory
    );
    let mut bytes = memory.checkpoint();
    bytes.push(0);
    assert!(GrenadeMemory::restore(&bytes).is_err());
    memory.seen.push(29);
    assert!(GrenadeMemory::restore(&memory.checkpoint()).is_err());
}

#[test]
fn crowded_grenade_reactions_keep_smother_throw_kick_and_dive_priority() {
    let mut collision = CollisionWorld::default();
    let mates: Vec<Mate> = (3..=6)
        .map(|id| Mate {
            id,
            position: V::X * 2.0,
            center: V::new(2.0, 0.3, 0.0),
            team: 0,
            life: Life::Downed,
            helpless: true,
        })
        .collect();
    let mut outcomes = [false; 4];
    for seed in 0..512 {
        let mut rng = SimulationRandom::new(seed);
        let reaction =
            grenade::react(soldier(), round(), &mates, &mut collision, &mut rng).unwrap();
        outcomes[match reaction {
            Reaction::Smother => 0,
            Reaction::ThrowBack => 1,
            Reaction::Kick => 2,
            Reaction::Dive => 3,
            Reaction::Shelter(_) => panic!("no wall"),
        }] = true;
    }
    assert_eq!(outcomes, [true; 4]);
    let mut rng = SimulationRandom::new(12);
    let before = rng;
    let s = Soldier {
        squad: false,
        armed: false,
        posture: Posture::Prone,
        ..soldier()
    };
    assert_eq!(
        grenade::react(s, round(), &mates, &mut collision, &mut rng).unwrap(),
        Reaction::Dive
    );
    assert_eq!(
        rng, before,
        "ineligible reactions must not draw random numbers"
    );
}

#[test]
fn sheltered_soldier_returns_the_blocking_body_but_close_grenades_force_a_dive() {
    let mut collision = CollisionWorld::default();
    collision.replace(
        77,
        &[BoxShape {
            body: 77,
            shape: 0,
            center: V::new(1.0, 1.0, 0.0),
            basis: Mat3::IDENTITY,
            half: V::new(0.1, 1.0, 1.0),
        }],
    );
    let s = Soldier {
        squad: false,
        armed: false,
        posture: Posture::Prone,
        ..soldier()
    };
    let mut rng = SimulationRandom::new(12);
    assert_eq!(
        grenade::react(s, round(), &[], &mut collision, &mut rng).unwrap(),
        Reaction::Shelter(77)
    );
    let near = Grenade {
        position: V::X * 1.1,
        ..round()
    };
    assert_eq!(
        grenade::react(s, near, &[], &mut collision, &mut rng).unwrap(),
        Reaction::Dive
    );
}

#[test]
fn kicks_turn_away_from_mates_and_cooking_requires_a_short_throw() {
    let mut rng = SimulationRandom::new(21);
    let before = rng;
    assert_eq!(grenade::cook_time(0, 20.01, true, &mut rng).unwrap(), 0.0);
    assert_eq!(rng, before);
    let direct = grenade::kick_velocity(soldier(), round(), &[], None).unwrap();
    assert_eq!(direct, V::new(9.0, 3.0, 0.0));
    let mate = Mate {
        id: 3,
        position: V::new(1.5, 0.0, 2.0),
        center: V::new(1.5, 1.0, 2.0),
        team: 0,
        life: Life::Alive,
        helpless: false,
    };
    let away = grenade::kick_velocity(soldier(), round(), &[mate], None).unwrap();
    assert!(away.z < 0.0 && away.x > 0.0);
    assert_eq!(away.y, 3.0);
    let mut memory = GrenadeMemory::default();
    assert!(memory.notice(V::NAN, &[round()], true).is_err());
    assert!(memory.seen.is_empty());
    assert!(grenade::cook_time(0, f64::NAN, false, &mut rng).is_err());
    assert_eq!(rng, before);
}
