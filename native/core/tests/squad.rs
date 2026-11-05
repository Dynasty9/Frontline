use frontline_core::actors::{Actor, Actors};
use frontline_core::infantry::{Infantry, Opening};
use frontline_core::infantry_controller::Task;
use frontline_core::infantry_vitals::Life;
use frontline_core::random::SimulationRandom;
use frontline_core::squad::*;
use frontline_core::vector::Vector3;

fn actor(id: u32, life: Life, position: Vector3) -> Actor {
    let mut s = Infantry::default();
    s.identity.id = id;
    s.identity.unit = "rifleman".into();
    s.identity.squad = 7;
    s.vitals.life = life;
    s.motion.position = position;
    Actor::Soldier(Box::new(s))
}
fn sample() -> Squad {
    let contact = Contact {
        id: 21,
        report: Report {
            position: Vector3::new(1.3, 2.7, -0.3),
            time: 9.7,
        },
    };
    Squad {
        id: 7,
        team: 1,
        owner: -2,
        kind: "r_rifles".into(),
        members: vec![5, 3, 4],
        known: vec![contact],
        heard: vec![contact.report],
        combat_at: 12.3,
        combat: true,
        centroid_at: 11.7,
        center: Vector3::X,
        briefing_at: 10.9,
        briefing: vec![Vector3::ONE],
        buildings_at: 17.3,
        buildings: vec![(21, 31)],
        order: "assault".into(),
        order_position: Vector3::Y,
        order_number: 333,
        shown_order: "contact".into(),
        facing: Vector3::Z,
        cover_fire_until: 123.1,
        cover_fire_position: Vector3::NEG_X,
        think_timer: -0.1,
        smoked: vec![(6, 12.3)],
        build_target: 41,
        tunnel_exit: Some(Vector3::NEG_Z),
        fire_queue: vec![(Vector3::X, false), (Vector3::Z, true)],
        bound_team: 1,
        bound_time: 123.2,
        contact_time: 123.3,
        alert_time: 123.4,
        leader: 5,
        travel: true,
        travel_mode: 2,
        final_slots: vec![(5, Vector3::ONE), (3, Vector3::NEG_X)],
        plan: 47,
        breach_by: 4,
        morale: 57.5,
        drill: "withdraw".into(),
        drill_time: 123.5,
        drill_position: Vector3::NEG_Y,
        halt_destination: Vector3::new(5.1, 1.5, -2.3),
        halt_face: Vector3::X,
        halt_mode: 1,
        move_mode: 2,
        known_at_order: vec![contact],
        impacts: vec![contact.report],
        last_casualty: 123.6,
        displace_cooldown: 123.7,
        previous_order: Some(SavedOrder {
            order: "defend".into(),
            position: Vector3::Y,
            facing: Vector3::Z,
            mode: 2,
        }),
        ammo_timer: 123.8,
        cooldowns: vec![
            ("crew".into(), 123.9),
            ("crew_n".into(), 333.0),
            ("refund".into(), 50.0),
        ],
        ambush: true,
        ambush_time: 124.0,
        offsets: vec![(5, [1.2, -3.4]), (3, [-5.6, 7.8])],
        technique: "bound".into(),
        overwatch_team: 1,
        overwatch_time: 124.1,
        recon_fire_time: 124.2,
        then_defend: Some([Vector3::Y, Vector3::NEG_Z]),
        cleared: vec![(31, 124.3)],
        clear_house: Some(ClearHouse {
            house: 31,
            soldier: 5,
            buddy: 3,
            opening: Opening {
                id: 30,
                center: Vector3::X,
                normal: Vector3::Z,
                door: true,
            },
        }),
        clear_call: Some((5, 124.4)),
        ambush_plan: 49,
        halt_then: Some([Vector3::X, Vector3::NEG_Y]),
    }
}

#[test]
fn complete_squad_checkpoint_preserves_orders_plans_caches_and_tactics() {
    for squad in [
        sample(),
        Squad {
            id: 1,
            ..Default::default()
        },
    ] {
        let bytes = squad.checkpoint().unwrap();
        let restored = Squad::restore(&bytes).unwrap();
        assert_eq!(restored, squad);
        assert_eq!(restored.checkpoint().unwrap(), bytes);
    }
}
#[test]
fn squad_decode_rejects_truncation_unknown_versions_and_invalid_collections() {
    let mut s = sample();
    let bytes = s.checkpoint().unwrap();
    for end in 0..bytes.len() {
        assert!(Squad::restore(&bytes[..end]).is_err());
    }
    for index in [4, 6] {
        let mut bad = bytes.clone();
        bad[index] = 8;
        assert!(Squad::restore(&bad).is_err());
    }
    let mut trailing = bytes;
    trailing.push(0);
    assert!(Squad::restore(&trailing).is_err());
    s.members.push(s.members[0]);
    assert!(s.checkpoint().is_err());
    s.members.pop();
    s.known.push(s.known[0]);
    assert!(s.checkpoint().is_err());
    s.known.pop();
    s.cooldowns.push(s.cooldowns[0].clone());
    assert!(s.checkpoint().is_err());
    s.cooldowns.pop();
    s.morale = f64::NAN;
    assert!(s.checkpoint().is_err());
}
#[test]
fn centroid_keeps_its_tick_cache_and_includes_wounded_captives_and_surrendered() {
    let mut actors = Actors::from_entries(
        8,
        vec![
            actor(1, Life::Alive, Vector3::X),
            actor(2, Life::Downed, Vector3::X * 3.0),
            actor(3, Life::Surrender, Vector3::X * 5.0),
            actor(4, Life::Captive, Vector3::X * 7.0),
            actor(5, Life::Dead, Vector3::X * 100.0),
            actor(6, Life::Hidden, Vector3::X * 100.0),
        ],
    )
    .unwrap();
    let mut s = Squad {
        id: 7,
        members: vec![1, 2, 3, 4, 5, 6, 7],
        order_position: Vector3::Y,
        ..Default::default()
    };
    assert_eq!(s.centroid(1.0, &actors), Vector3::X * 4.0);
    actors.remove(1);
    assert_eq!(s.centroid(1.0, &actors), Vector3::X * 4.0);
    let mut s = Squad::restore(&s.checkpoint().unwrap()).unwrap();
    assert_eq!(s.centroid(1.0, &actors), Vector3::X * 4.0);
    assert_eq!(s.centroid(2.0, &actors), Vector3::X * 5.0);
    s.members.clear();
    assert_eq!(s.centroid(3.0, &actors), Vector3::Y);
}
#[test]
fn contact_updates_keep_order_and_refresh_only_the_matching_cache_deadlines() {
    let mut s = Squad {
        id: 1,
        briefing_at: 5.0,
        buildings_at: 5.0,
        ..Default::default()
    };
    s.report(Contact {
        id: 5,
        report: Report {
            position: Vector3::X,
            time: 6.0,
        },
    })
    .unwrap();
    s.report(Contact {
        id: 3,
        report: Report {
            position: Vector3::Z,
            time: 6.0,
        },
    })
    .unwrap();
    s.briefing_at = 6.0;
    s.buildings_at = 6.0;
    s.report(Contact {
        id: 5,
        report: Report {
            position: Vector3::Y,
            time: 6.1,
        },
    })
    .unwrap();
    assert_eq!((s.briefing_at, s.buildings_at), (6.0, 6.0));
    assert_eq!(s.known.iter().map(|k| k.id).collect::<Vec<_>>(), vec![5, 3]);
    assert!(s.in_combat(6.1));
    assert!(!s.in_combat(14.1));
    s.briefing = vec![Vector3::ONE];
    for n in 0..12 {
        s.report_position(Vector3::X * n as f32, 20.0 + n as f64)
            .unwrap();
    }
    assert_eq!(s.heard.len(), 8);
    assert_eq!(s.heard[0].time, 24.0);
    assert_eq!(s.briefing_at, 6.0);
    assert!(s.in_combat(36.9));
    assert!(!s.in_combat(37.0));
    let before = s.checkpoint().unwrap();
    assert!(s.report_position(Vector3::NAN, 0.0).is_err());
    assert_eq!(s.checkpoint().unwrap(), before);
}
#[test]
fn squad_leader_successor_skips_bearers_and_busy_men_without_extra_random_draws() {
    let mut busy = actor(3, Life::Alive, Vector3::ZERO);
    let Actor::Soldier(s) = &mut busy else {
        panic!()
    };
    s.duty.kind = Task::Rescue;
    let mut actors = Actors::from_entries(
        8,
        vec![
            actor(1, Life::Dead, Vector3::ZERO),
            actor(2, Life::Alive, Vector3::ZERO),
            busy,
            actor(4, Life::Alive, Vector3::ZERO),
        ],
    )
    .unwrap();
    let mut squad = Squad {
        id: 7,
        leader: 1,
        members: vec![1, 2, 3, 4],
        ..Default::default()
    };
    let mut rng = SimulationRandom::new(137);
    let mut reference = rng;
    let cue = (reference.randi() % 3) as u8;
    assert_eq!(
        squad.get_leader(&mut actors, |s| s.identity.id == 2, &mut rng),
        (4, Some(Speech { soldier: 4, cue }))
    );
    assert_eq!(actors.soldier(4).unwrap().vitals.speech_cooldown, 2.6);
    assert_eq!(rng.state(), reference.state());
    assert_eq!(
        squad.get_leader(&mut actors, |_| false, &mut rng),
        (4, None)
    );
    assert_eq!(rng.state(), reference.state());
}
#[test]
fn casualty_penalty_and_first_nearby_speaker_match_the_squad_rules() {
    let mut actors = Actors::from_entries(
        8,
        vec![
            actor(1, Life::Downed, Vector3::ZERO),
            actor(2, Life::Alive, Vector3::X * 31.0),
            actor(3, Life::Alive, Vector3::X * 5.0),
        ],
    )
    .unwrap();
    let mut q = Squad {
        id: 7,
        members: vec![1, 2, 3],
        morale: 78.0,
        ..Default::default()
    };
    let mut rng = SimulationRandom::new(137);
    assert_eq!(
        q.casualty(1, 17.3, &mut actors, &mut rng)
            .unwrap()
            .unwrap()
            .soldier,
        3
    );
    assert_eq!(q.morale, 65.0);
    assert_eq!(q.last_casualty, 17.3);
    actors.die(1, 19.3, Some(120)).unwrap();
    let before = rng.state();
    assert_eq!(q.casualty(1, 19.3, &mut actors, &mut rng).unwrap(), None);
    assert_eq!(q.morale, 49.0);
    assert_eq!(rng.state(), before);
}
#[test]
fn threat_ties_stay_in_report_order_and_stale_or_dead_contacts_are_ignored() {
    let actors = Actors::from_entries(
        8,
        vec![
            actor(1, Life::Alive, Vector3::ZERO),
            actor(2, Life::Alive, Vector3::ZERO),
            actor(3, Life::Dead, Vector3::ZERO),
        ],
    )
    .unwrap();
    let mut s = Squad {
        id: 7,
        members: vec![1, 2],
        ..Default::default()
    };
    for (id, p, t) in [
        (2, Vector3::X * 5.0, 10.0),
        (1, Vector3::Z * 5.0, 10.0),
        (3, Vector3::ZERO, 10.0),
        (4, Vector3::ZERO, 10.0),
    ] {
        s.report(Contact {
            id,
            report: Report {
                position: p,
                time: t,
            },
        })
        .unwrap();
    }
    s.report_position(Vector3::ZERO, 11.0).unwrap();
    assert_eq!(
        s.threat_points(Vector3::ZERO, 3, 12.0, &actors),
        vec![
            Vector3::new(5.0, 1.5, 0.0),
            Vector3::new(0.0, 1.5, 5.0),
            Vector3::Y * 1.5
        ]
    );
    let original = s.sector_threats(Vector3::ZERO, 12.0, &actors);
    s.report(Contact {
        id: 1,
        report: Report {
            position: Vector3::X,
            time: 12.1,
        },
    })
    .unwrap();
    assert_eq!(s.sector_threats(Vector3::ZERO, 12.1, &actors), original);
    assert_ne!(s.sector_threats(Vector3::ZERO, 12.25, &actors), original);
    assert!(s.threat_points(Vector3::ZERO, 3, 28.0, &actors).is_empty());
}
