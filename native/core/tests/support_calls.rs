use frontline_core::actors::{Actor, Actors};
use frontline_core::battle_stats::BattleStats;
use frontline_core::projectile::Kind;
use frontline_core::projectile_actor::Motion;
use frontline_core::random::SimulationRandom;
use frontline_core::structure::Structure;
use frontline_core::support::Gunset;
use frontline_core::support_calls::{Definition, Event, Salvo, Sortie, SupportCalls};
use frontline_core::vector::Vector3;
fn definition(sortie: Sortie) -> Definition<'static> {
    Definition {
        key: "test",
        name: "Test Aircraft Strike",
        model: "test_model",
        team: 0,
        cost: 100,
        from: 300.,
        cooldown: 90.,
        radius: 20.,
        sortie,
        quiet: false,
        leg: 420.,
        altitude: 60.,
        speed: 90.,
        sight: 85.,
        stay: 60.,
        bombs: 4,
        guns: Gunset::Ac130,
        muzzles: [Vector3::X, Vector3::Y, Vector3::Z],
    }
}
fn actors(stock: f64) -> Actors {
    Actors::from_entries(
        100,
        vec![Actor::Structure(Box::new(Structure {
            id: 1,
            kind: "fob".into(),
            team: 0,
            built: true,
            supply: stock,
            ..Default::default()
        }))],
    )
    .unwrap()
}
#[test]
fn paid_support_checks_opening_cost_and_cooldown_before_creating_an_aircraft() {
    let mut a = actors(250.);
    let mut b = BattleStats::default();
    let mut r = SimulationRandom::new(71);
    let mut s = SupportCalls::default();
    let p = definition(Sortie::Jet);
    for (now, ok) in [
        (299.9, false),
        (300., true),
        (301., false),
        (390., true),
        (480., false),
    ] {
        let before = r;
        let (accepted, events) = s
            .call(
                &mut a,
                &mut b,
                &mut r,
                now,
                7,
                0,
                Vector3::ZERO,
                Vector3::ZERO,
                &p,
                1024,
            )
            .unwrap();
        assert_eq!(accepted, ok);
        if !ok {
            assert!(matches!(events.as_slice(), [Event::Warn { peer: 7, .. }]));
            assert_eq!(r, before);
        }
    }
    assert_eq!(a.structure(1).unwrap().supply, 50.);
    assert_eq!(a.entities().next_id(), 102);
    assert_eq!(b.sides[0][14], 200.);
    assert_eq!(b.sides[0][19], 2.);
    assert_eq!(s.ready[0], vec![("test".into(), 480.)]);
}
#[test]
fn simultaneous_salvos_keep_reverse_rng_order_and_future_round_order() {
    let mut s = SupportCalls::default();
    for (at, by) in [(4., 7), (9., 8), (4., 9), (8., 10)] {
        s.queue.push(Salvo {
            at,
            kind: Kind::Grad,
            team: 0,
            position: Vector3::ZERO,
            radius: 20.,
            back: Vector3::Z * 300.,
            called_by: by,
        });
    }
    let mut a = Actors::default();
    let mut r = SimulationRandom::new(13);
    let out = s.advance(&mut a, &mut r, 4.).unwrap();
    assert_eq!(out.len(), 2);
    let callers: Vec<_> = a
        .iter()
        .map(|a| {
            if let Actor::Projectile(p) = a {
                p.called_by
            } else {
                0
            }
        })
        .collect();
    assert_eq!(callers, vec![9, 7]);
    assert_eq!(
        s.queue.iter().map(|q| q.called_by).collect::<Vec<_>>(),
        vec![8, 10]
    );
    let state = r;
    assert!(s.advance(&mut a, &mut r, 7.99).unwrap().is_empty());
    assert_eq!(r, state);
}
#[test]
fn checkpoint_continuation_keeps_all_sorties_and_delayed_random_draws_exact() {
    for kind in [
        Sortie::Recon,
        Sortie::Watch,
        Sortie::Jet,
        Sortie::GunRun,
        Sortie::Orbit,
        Sortie::Artillery,
        Sortie::Barrage,
        Sortie::Mortars,
        Sortie::Smoke,
    ] {
        let mut a = actors(1000.);
        let mut b = BattleStats::default();
        let mut rng = SimulationRandom::new(15);
        let mut s = SupportCalls::default();
        let p = definition(kind);
        assert!(
            s.call(
                &mut a,
                &mut b,
                &mut rng,
                300.,
                7,
                0,
                Vector3::new(7., 4., 9.),
                Vector3::new(1., 0., 2.),
                &p,
                2048
            )
            .unwrap()
            .0
        );
        let mut r = SupportCalls::restore(&s.checkpoint().unwrap()).unwrap();
        let mut ar = Actors::restore(&a.checkpoint().unwrap()).unwrap();
        let mut rr = rng;
        for now in [300., 301., 301.5, 302., 304., 310., 320.] {
            assert_eq!(
                s.advance(&mut a, &mut rng, now).unwrap(),
                r.advance(&mut ar, &mut rr, now).unwrap()
            );
            assert_eq!(s, r);
            assert_eq!(a.checkpoint().unwrap(), ar.checkpoint().unwrap());
            assert_eq!(rng, rr);
        }
        assert!(s.queue.is_empty());
    }
}
#[test]
fn quiet_recon_has_no_enemy_warning_and_demo_aircraft_belong_to_neither_team() {
    let mut a = actors(1000.);
    let mut b = BattleStats::default();
    let mut rng = SimulationRandom::new(1);
    let mut s = SupportCalls::default();
    let mut p = definition(Sortie::Recon);
    p.quiet = true;
    let (_, events) = s
        .call(
            &mut a,
            &mut b,
            &mut rng,
            300.,
            7,
            0,
            Vector3::ZERO,
            Vector3::ZERO,
            &p,
            1024,
        )
        .unwrap();
    assert_eq!(
        events
            .iter()
            .filter(|e| matches!(e, Event::Message { .. }))
            .count(),
        1
    );
    let Actor::Projectile(first) = a.get(100).unwrap() else {
        panic!()
    };
    assert_eq!(first.called_by, 0);
    let Motion::Support(f) = &first.motion else {
        panic!()
    };
    assert_eq!(f.position, Vector3::new(0., 60., 420.));
    assert_eq!(f.sight, 85.);
    let events = s
        .demo(
            &mut a,
            &mut rng,
            300.,
            Vector3::ZERO,
            Vector3::ZERO,
            &p,
            1024,
        )
        .unwrap();
    assert!(events.iter().any(|e| matches!(
        e,
        Event::Message {
            team: -1,
            alert: false,
            ..
        }
    )));
    let Actor::Projectile(second) = a.get(101).unwrap() else {
        panic!()
    };
    assert_eq!(second.team, -1);
    let Motion::Support(f) = &second.motion else {
        panic!()
    };
    assert_eq!(f.position, Vector3::new(-420., 60., 0.));
    assert_eq!(a.structure(1).unwrap().supply, 900.);
}
#[test]
fn malformed_requests_and_checkpoints_do_not_spend_or_spawn() {
    let mut a = actors(1000.);
    let before = a.checkpoint().unwrap();
    let mut b = BattleStats::default();
    let mut rng = SimulationRandom::new(1);
    let random = rng;
    let mut s = SupportCalls::default();
    let mut p = definition(Sortie::Jet);
    p.altitude = f64::NAN;
    assert!(s
        .call(
            &mut a,
            &mut b,
            &mut rng,
            300.,
            7,
            0,
            Vector3::ZERO,
            Vector3::ZERO,
            &p,
            1024
        )
        .is_err());
    assert_eq!(a.checkpoint().unwrap(), before);
    assert_eq!(rng, random);
    assert_eq!(b, BattleStats::default());
    assert_eq!(s, SupportCalls::default());
    let mut bytes = s.checkpoint().unwrap();
    bytes.push(0);
    assert!(SupportCalls::restore(&bytes).is_err());
    s.ready[0] = vec![("same".into(), 300.), ("same".into(), 301.)];
    assert!(s.checkpoint().is_err());
}
#[test]
fn opposing_teams_cannot_charge_supply_and_ai_rejections_do_not_send_private_warnings() {
    let mut a = actors(0.);
    let mut b = BattleStats::default();
    let mut rng = SimulationRandom::new(1);
    let mut s = SupportCalls::default();
    let p = definition(Sortie::Jet);
    for (peer, team, now) in [(8, 1, 300.), (-1, 0, 299.), (-1, 0, 300.)] {
        assert_eq!(
            s.call(
                &mut a,
                &mut b,
                &mut rng,
                now,
                peer,
                team,
                Vector3::ZERO,
                Vector3::ZERO,
                &p,
                1024
            )
            .unwrap(),
            (false, vec![])
        );
    }
    assert_eq!(s, SupportCalls::default());
    assert_eq!(b, BattleStats::default());
    assert_eq!(a.entities().next_id(), 100);
}

#[test]
fn credit_overflow_is_rejected_before_supply_or_cooldown_changes() {
    let mut a = actors(1000.);
    let before = a.checkpoint().unwrap();
    let mut b = BattleStats::default();
    b.sides[0][14] = 1e15;
    let before_b = b.clone();
    let mut rng = SimulationRandom::new(1);
    let before_r = rng;
    let mut s = SupportCalls::default();
    let p = definition(Sortie::Orbit);
    assert!(s
        .call(
            &mut a,
            &mut b,
            &mut rng,
            300.,
            7,
            0,
            Vector3::ZERO,
            Vector3::ZERO,
            &p,
            1024
        )
        .is_err());
    assert_eq!(a.checkpoint().unwrap(), before);
    assert_eq!(b, before_b);
    assert_eq!(rng, before_r);
    assert_eq!(s, SupportCalls::default());
}
