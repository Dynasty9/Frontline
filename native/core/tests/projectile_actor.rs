use frontline_core::collision::CollisionWorld;
use frontline_core::guided::{GuidedFlight, Kind as GuidedKind};
use frontline_core::projectile::{Holder, Kind};
use frontline_core::projectile_actor::{
    ballistic, Event, Motion, Projectile, Smotherer, Spawn, Step,
};
use frontline_core::random::SimulationRandom;
use frontline_core::support::{Gunset, Kind as SupportKind, SupportFlight};
use frontline_core::vector::Vector3;

fn actor(kind: Kind) -> Projectile {
    Projectile::from_spawn(
        17,
        Spawn {
            flight: ballistic(kind, Vector3::new(0.0, 0.06, 0.0), Vector3::ZERO),
            team: 0,
            thrower: 7,
            called_by: 42,
        },
    )
    .unwrap()
}
fn input() -> Step<'static> {
    Step {
        dt: 0.1,
        time: 100.0,
        map_half: 512.0,
        holder: Holder::Free,
        target: None,
        smoke: false,
        smotherer: None,
        candidates: &[],
        excluded: &[],
    }
}
fn advance(s: &mut Projectile, i: Step<'_>, rng: &mut SimulationRandom) -> Vec<Event> {
    s.advance(i, &mut CollisionWorld::default(), rng).unwrap()
}

#[test]
fn pickup_kick_and_rethrow_preserve_fuse_handler_and_original_support_credit() {
    let mut s = actor(Kind::Frag);
    s.handler = 8;
    s.smothered_by = 9;
    s.pick_up(8).unwrap();
    assert_eq!(s.held_by, 8);
    let Motion::Ballistic(f) = &s.motion else {
        panic!()
    };
    assert!(!f.flying);
    assert_eq!(f.fuse, 3.4);
    s.kick(Vector3::new(5.0, 2.0, 1.0)).unwrap();
    assert_eq!(s.held_by, 8);
    assert_eq!(s.handler, 8);
    assert_eq!(s.smothered_by, 0);
    s.release_throw(8, 1, Vector3::X, Vector3::Z * 14.0)
        .unwrap();
    assert_eq!(
        (s.held_by, s.thrower, s.team, s.thrown_back, s.called_by),
        (0, 8, 1, 2, 42)
    );
    let Motion::Ballistic(f) = &s.motion else {
        panic!()
    };
    assert_eq!(f.position, Vector3::new(1.0, 1.7, 0.0));
    assert!(f.flying && f.velocity.z > 0.0);
    assert_eq!(f.fuse, 3.4);
}

#[test]
fn a_dead_holder_drops_the_grenade_before_its_fuse_expires() {
    let mut s = actor(Kind::Frag);
    s.pick_up(8).unwrap();
    let Motion::Ballistic(f) = &mut s.motion else {
        panic!()
    };
    f.fuse = 0.05;
    let out = advance(
        &mut s,
        Step {
            holder: Holder::Dropped,
            ..input()
        },
        &mut SimulationRandom::new(1),
    );
    assert_eq!(s.held_by, 0);
    assert!(
        matches!(out.as_slice(), [Event::Explosion(e), Event::Despawn] if e.damage == 150.0 && e.source == 7 && e.called_by == 42)
    );
    let Motion::Ballistic(f) = &s.motion else {
        panic!()
    };
    assert!(f.flying);
    assert_eq!(f.velocity, Vector3::ZERO);
}

#[test]
fn smothering_orders_the_direct_injury_small_blast_notice_and_removal() {
    let mut s = actor(Kind::Frag);
    s.smothered_by = 9;
    let Motion::Ballistic(f) = &mut s.motion else {
        panic!()
    };
    f.fuse = 0.0;
    let out = advance(
        &mut s,
        Step {
            smotherer: Some(Smotherer {
                id: 9,
                position: Vector3::new(0.0, 0.0, 0.75),
                yaw: 0.0,
                alive: true,
                covering: true,
            }),
            ..input()
        },
        &mut SimulationRandom::new(1),
    );
    assert!(
        matches!(out.as_slice(), [Event::DamageSmotherer { soldier: 9, source: 7 }, Event::Explosion(e), Event::SmotherNotice(9), Event::Stat("smother_saved"), Event::Despawn] if e.damage == 32.0 && e.called_by == 0 && e.radius == 2.6 && e.fling == 0.0)
    );
}

#[test]
fn impact_profiles_keep_shell_damage_smoke_spawn_and_armour_direction() {
    let mut rng = SimulationRandom::new(137);
    for (kind, damage, antitank) in [
        (Kind::Mortar, 130.0, 80.0),
        (Kind::Grad, 150.0, 120.0),
        (Kind::Arty, 230.0, 220.0),
        (Kind::Ac105, 220.0, 300.0),
        (Kind::Ac40, 95.0, 140.0),
        (Kind::Ac25, 50.0, 70.0),
        (Kind::Rocket, 110.0, 380.0),
        (Kind::Recoilless, 110.0, 450.0),
        (Kind::Bomb, 220.0, 300.0),
    ] {
        let mut s = actor(kind);
        let Motion::Ballistic(f) = &mut s.motion else {
            panic!()
        };
        f.position = Vector3::ZERO;
        f.target = Vector3::X * 10.0;
        f.shell_duration = 0.1;
        let out = advance(&mut s, input(), &mut rng);
        assert!(
            matches!(out.as_slice(), [Event::Explosion(e), Event::Despawn] if e.damage == damage && e.antitank == antitank)
        );
    }
    let mut s = actor(Kind::MortarSmoke);
    let Motion::Ballistic(f) = &mut s.motion else {
        panic!()
    };
    f.shell_duration = 0.1;
    f.target = Vector3::X * 10.0;
    let out = advance(&mut s, input(), &mut rng);
    assert!(
        matches!(out.as_slice(), [Event::Spawn(p), Event::Despawn] if p.flight.kind == Kind::Smoke && p.flight.position == Vector3::new(10.0, 0.2, 0.0) && p.flight.fuse == 0.0 && p.thrower == 7 && p.called_by == 42)
    );
}

#[test]
fn guided_smoke_loss_precedes_impact_and_proximity_controls_antitank_power() {
    let mut s = actor(Kind::Rocket);
    s.target_id = 8;
    s.motion = Motion::Guided(GuidedFlight {
        kind: GuidedKind::AntiTank,
        position: Vector3::new(0.0, 0.01, 0.0),
        velocity: Vector3::NEG_Y,
        target: Vector3::X * 10.0,
        life: 0.24,
        locked: true,
        dead: false,
    });
    let out = advance(
        &mut s,
        Step {
            smoke: true,
            target: Some(Vector3::X * 10.0),
            ..input()
        },
        &mut SimulationRandom::new(1),
    );
    assert_eq!(s.target_id, 0);
    assert!(matches!(
        out.first(),
        Some(Event::Stat("atgm_lost_in_smoke"))
    ));
    assert!(matches!(out.last(), Some(Event::Despawn)));
    s.motion = Motion::Guided(GuidedFlight {
        kind: GuidedKind::SurfaceToAir,
        position: Vector3::Y * 20.0,
        velocity: Vector3::X * 30.0,
        target: Vector3::new(3.0, 20.0, 0.0),
        life: 0.0,
        locked: true,
        dead: false,
    });
    let out = advance(
        &mut s,
        Step {
            target: Some(Vector3::new(3.0, 20.0, 0.0)),
            ..input()
        },
        &mut SimulationRandom::new(1),
    );
    assert!(
        matches!(out.as_slice(), [Event::Explosion(e), Event::Despawn] if e.antitank == 620.0 && e.direction.is_none())
    );
}

#[test]
fn support_child_rounds_keep_their_aircraft_and_player_attribution() {
    let mut s = actor(Kind::Bomb);
    s.motion = Motion::Support(SupportFlight::new(
        SupportKind::Jet,
        Vector3::new(-10.0, 40.0, 0.0),
        Vector3::X * 100.0,
        Vector3::ZERO,
    ));
    let out = advance(&mut s, input(), &mut SimulationRandom::new(137));
    assert!(
        matches!(out.first(), Some(Event::Spawn(p)) if p.flight.kind == Kind::Bomb && p.thrower == 7 && p.called_by == 42)
    );
    let mut flight = SupportFlight::new(
        SupportKind::Orbit,
        Vector3::new(0.0, 88.0, 0.0),
        Vector3::ZERO,
        Vector3::ZERO,
    );
    flight.life = 3.0;
    flight.gunset = Gunset::Greyhawk;
    s.motion = Motion::Support(flight);
    let mut rng = SimulationRandom::new(137);
    let mut fired = false;
    for _ in 0..50 {
        let out = advance(&mut s, input(), &mut rng);
        fired |= out.iter().any(|event| matches!(event, Event::Spawn(p) if p.flight.kind == Kind::Ac40 && p.thrower == 17 && p.called_by == 42));
    }
    assert!(fired);
}

#[test]
fn complete_projectile_checkpoints_continue_pending_support_bursts_and_random_draws() {
    let mut continuous = actor(Kind::Bomb);
    continuous.motion = Motion::Support(SupportFlight::new(
        SupportKind::Orbit,
        Vector3::Y * 88.0,
        Vector3::ZERO,
        Vector3::new(1.3, 0.0, -2.7),
    ));
    let mut restored = continuous.clone();
    let mut a = SimulationRandom::new(137);
    let mut b = a;
    for tick in 0..400 {
        let i = Step {
            dt: 1.0 / 30.0,
            time: 100.0 + tick as f64 / 30.0,
            ..input()
        };
        assert_eq!(
            advance(&mut continuous, i, &mut a),
            advance(&mut restored, i, &mut b)
        );
        assert_eq!(a, b);
        assert_eq!(continuous, restored);
        restored = Projectile::restore(&restored.checkpoint().unwrap()).unwrap();
    }
}

#[test]
fn malformed_checkpoints_and_commands_are_rejected_without_changing_state() {
    let mut s = actor(Kind::Frag);
    let before = s.clone();
    let mut rng = SimulationRandom::new(137);
    let random = rng;
    assert!(s.pick_up(0).is_err());
    assert!(s.kick(Vector3::splat(f32::NAN)).is_err());
    assert!(s.release_throw(1, 7, Vector3::ZERO, Vector3::X).is_err());
    assert!(s
        .advance(
            Step {
                dt: f64::NAN,
                ..input()
            },
            &mut CollisionWorld::default(),
            &mut rng
        )
        .is_err());
    assert!(s
        .advance(
            Step {
                holder: Holder::Dropped,
                ..input()
            },
            &mut CollisionWorld::default(),
            &mut rng
        )
        .is_err());
    assert_eq!(s, before);
    assert_eq!(rng, random);
    let saved = s.checkpoint().unwrap();
    for n in 0..saved.len() {
        assert!(Projectile::restore(&saved[..n]).is_err());
    }
    let mut bad = saved.clone();
    bad[6] = 0;
    assert!(Projectile::restore(&bad).is_err());
    let mut bad = saved.clone();
    bad[8..12].fill(0);
    assert!(Projectile::restore(&bad).is_err());
    let mut bad = saved.clone();
    bad.push(0);
    assert!(Projectile::restore(&bad).is_err());
}

#[test]
fn the_smothering_check_uses_the_grenade_position_at_detonation() {
    let mut s = actor(Kind::Frag);
    s.smothered_by = 9;
    let Motion::Ballistic(f) = &mut s.motion else {
        panic!()
    };
    f.velocity = Vector3::X * 100.0;
    f.fuse = 0.05;
    let out = advance(
        &mut s,
        Step {
            smotherer: Some(Smotherer {
                id: 9,
                position: Vector3::new(0.0, 0.0, 0.75),
                yaw: 0.0,
                alive: true,
                covering: true,
            }),
            ..input()
        },
        &mut SimulationRandom::new(137),
    );
    assert!(
        matches!(out.as_slice(), [Event::Explosion(e), Event::Despawn] if e.damage == 150.0 && e.position.x == 10.0)
    );
}

#[test]
fn updates_beyond_checkpoint_bounds_are_atomic() {
    let mut s = actor(Kind::Frag);
    let Motion::Ballistic(f) = &mut s.motion else {
        panic!()
    };
    f.position = Vector3::new(1_000_000.0, 20.0, 0.0);
    f.velocity = Vector3::X * 100.0;
    let before = s.clone();
    let mut rng = SimulationRandom::new(137);
    let random = rng;
    assert!(s
        .advance(input(), &mut CollisionWorld::default(), &mut rng)
        .is_err());
    assert_eq!(s, before);
    assert_eq!(rng, random);
}
