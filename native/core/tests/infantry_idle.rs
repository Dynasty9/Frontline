use frontline_core::infantry_idle::{self as idle, Calm, Decision, Idle, Line, Mate, CHAT};
use frontline_core::infantry_vitals::Life;
use frontline_core::random::SimulationRandom;
use frontline_core::vector::Vector3;

fn calm() -> Calm {
    Calm {
        moving: false,
        danger: false,
        sector: Vector3::ZERO,
        reload: 0.0,
        last_shot: 0.0,
        mounted: false,
        target: false,
    }
}

#[test]
fn calm_and_conversation_deadlines_preserve_strict_boundaries() {
    let mut s = Idle::default();
    assert_eq!(s.tick(1.0, 12.0, calm(), true), Ok(Decision::Wait));
    assert_eq!(s.calm, 0.0);
    s.calm = 11.0;
    s.next = 13.0;
    assert_eq!(s.tick(1.0, 13.0, calm(), true), Ok(Decision::Start));
    s.activity = CHAT;
    s.partner = 2;
    s.until = 13.0;
    assert_eq!(s.tick(0.0, 13.0, calm(), true), Ok(Decision::Chat));
    assert_eq!(s.tick(0.0, 13.01, calm(), true), Ok(Decision::End));
    assert_eq!(s.tick(0.0, 13.0, calm(), false), Ok(Decision::End));
    for c in [
        Calm {
            moving: true,
            ..calm()
        },
        Calm {
            danger: true,
            ..calm()
        },
        Calm {
            sector: Vector3::X,
            ..calm()
        },
        Calm {
            reload: 0.1,
            ..calm()
        },
        Calm {
            mounted: true,
            ..calm()
        },
        Calm {
            target: true,
            ..calm()
        },
    ] {
        s.calm = 50.0;
        assert_eq!(s.tick(0.1, 13.0, c, true), Ok(Decision::End));
        assert_eq!(s.calm, 0.0);
    }
}

#[test]
fn chat_partners_keep_spatial_encounter_order_and_exclude_busy_men() {
    let first = Mate {
        id: 2,
        team: 0,
        life: Life::Alive,
        chatting: false,
        calm: 5.0,
        free: true,
        moving: false,
    };
    let mut nearby = vec![
        Mate { id: 1, ..first },
        Mate {
            id: 9,
            calm: 4.99,
            ..first
        },
        first,
        Mate { id: 3, ..first },
    ];
    assert_eq!(idle::select_mate(1, 0, &nearby), Ok(Some(2)));
    nearby[2].moving = true;
    assert_eq!(idle::select_mate(1, 0, &nearby), Ok(Some(3)));
    nearby[3].life = Life::Hidden;
    assert_eq!(idle::select_mate(1, 0, &nearby), Ok(None));
}

#[test]
fn conversation_checkpoint_resumes_lines_and_intervening_random_draws() {
    for seed in 0..64 {
        let mut rng = SimulationRandom::new(seed);
        let mut a = Idle::default();
        let mut b = Idle::default();
        a.start_chat(
            &mut b,
            1,
            2,
            100.0,
            (seed % 2) as i32,
            "Mikhail",
            "James",
            &mut rng,
        )
        .unwrap();
        assert_eq!(
            (a.partner, b.partner, a.activity, b.activity),
            (2, 1, CHAT, CHAT)
        );
        assert!(a.until == 100.0 + (3.5 + 2.0 * 2.8) || a.until == 100.0 + (3.5 + 3.0 * 2.8));
        assert!(a
            .lines
            .iter()
            .chain(&b.lines)
            .all(|l| !l.text.contains("%s")));
        let mut c = Idle::restore(&a.checkpoint()).unwrap();
        let mut d = Idle::restore(&b.checkpoint()).unwrap();
        let mut replay_rng = rng;
        for i in 0..20 {
            let now = 100.0 + i as f64;
            for (live, saved) in [(&mut a, &mut c), (&mut b, &mut d)] {
                loop {
                    let line = live.next_line(now, &mut rng).unwrap();
                    assert_eq!(line, saved.next_line(now, &mut replay_rng).unwrap());
                    if line.is_none() {
                        break;
                    }
                    rng.randi();
                    replay_rng.randi();
                }
                assert_eq!(live.checkpoint(), saved.checkpoint());
            }
        }
        assert_eq!(rng, replay_rng);
        assert!(a.lines.is_empty() && b.lines.is_empty());
        assert_eq!(a.end(120.0, &mut rng), Ok(2));
        assert_eq!((a.activity, a.partner, a.laugh_until), (0, 0, 0.0));
    }
}

#[test]
fn silence_still_consumes_the_laugh_draw_and_clears_the_line() {
    let mut found = false;
    for seed in 0..20 {
        let mut s = Idle {
            lines: [Line {
                at: 1.0,
                text: "!laugh".into(),
            }]
            .into(),
            ..Default::default()
        };
        let mut rng = SimulationRandom::new(seed);
        let before = rng;
        if s.next_line(1.0, &mut rng).unwrap() == Some(None) {
            assert_ne!(rng, before);
            assert_eq!(s.laugh_until, 2.8);
            assert!(s.lines.is_empty());
            found = true;
        }
    }
    assert!(found);
}

#[test]
fn invalid_downtime_is_rejected_before_state_or_randomness_changes() {
    let mut a = Idle::default();
    let mut b = Idle::default();
    let mut rng = SimulationRandom::new(1);
    let before = rng;
    assert!(a.begin(f64::NAN, 0.0, &mut rng).is_err());
    assert!(a.solo(f64::INFINITY, 0, &mut rng).is_err());
    assert!(a
        .start_chat(&mut b, 1, 1, 0.0, 0, "a", "b", &mut rng)
        .is_err());
    assert!(a.next_line(f64::NAN, &mut rng).is_err());
    assert!(a.end(f64::NAN, &mut rng).is_err());
    assert_eq!(a, Idle::default());
    assert_eq!(b, Idle::default());
    assert_eq!(rng, before);
    a.start_chat(&mut b, 1, 2, 0.0, 0, "a", "b", &mut rng)
        .unwrap();
    let bytes = a.checkpoint();
    for n in 0..bytes.len() {
        assert!(Idle::restore(&bytes[..n]).is_err());
    }
    for (index, byte) in [(4, 2), (6, 0), (16, 27), (49, 129)] {
        let mut bad = bytes.clone();
        bad[index] = byte;
        assert!(Idle::restore(&bad).is_err());
    }
    let mut extra = bytes;
    extra.push(0);
    assert!(Idle::restore(&extra).is_err());
}

#[test]
fn conversation_facing_retains_distance_and_mounted_traverse_gates() {
    let p = Vector3::ZERO;
    assert_eq!(
        idle::chat_yaw(p, Vector3::X * 0.29, 0.3, 0.1, None),
        Ok(0.3)
    );
    assert_eq!(
        idle::chat_yaw(p, Vector3::X, 0.0, 0.1, Some((p, 0.2))),
        Ok(f64::from(-0.02f32))
    );
}
