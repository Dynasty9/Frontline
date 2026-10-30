use frontline_core::random::SimulationRandom;
use frontline_core::support::{Event, Gunset, Kind, SupportFlight};
use frontline_core::vector::Vector3;

#[test]
fn pending_rounds_bursts_and_rng_resume_exactly() {
    for kind in [Kind::Jet, Kind::GunRun, Kind::Orbit] {
        for set in [
            Gunset::Ac130,
            Gunset::Blackfish,
            Gunset::Xian,
            Gunset::Greyhawk,
            Gunset::Unarmed,
        ] {
            let mut flight = SupportFlight::new(
                kind,
                Vector3::new(-420.0, 62.0, 0.0),
                Vector3::X * 58.0,
                Vector3::ZERO,
            );
            flight.gunset = set;
            flight.sight = 65.0;
            let mut rng = SimulationRandom::new(1234);
            let mut time = 42.0;
            let mut shots = 0;
            for _ in 0..1500 {
                time += 1.0 / 30.0;
                let mut restored = SupportFlight::restore(&flight.checkpoint()).unwrap();
                let mut restored_rng = rng;
                let candidates = [Vector3::new(5.0, 0.0, 3.0), Vector3::new(8.0, 0.0, 9.0)];
                let events = flight.advance(1.0 / 30.0, time, 0, 512.0, &candidates, &mut rng);
                assert_eq!(
                    events,
                    restored.advance(1.0 / 30.0, time, 0, 512.0, &candidates, &mut restored_rng)
                );
                assert_eq!(flight, restored);
                assert_eq!(rng, restored_rng);
                shots += events
                    .iter()
                    .filter(|e| {
                        matches!(
                            e,
                            Event::Bomb { .. } | Event::Impact(_) | Event::Shell { .. }
                        )
                    })
                    .count();
                if flight.dead {
                    break;
                }
            }
            assert!(flight.dead);
            assert_eq!(shots > 0, kind != Kind::Orbit || set != Gunset::Unarmed);
            let dead = flight.clone();
            let state = rng;
            assert!(flight
                .advance(1.0, time + 1.0, 0, 512.0, &[], &mut rng)
                .is_empty());
            assert_eq!(flight, dead);
            assert_eq!(rng, state);
        }
    }
}

#[test]
fn recon_marks_respect_map_edges_team_and_cadence() {
    let mut recon = SupportFlight::new(
        Kind::Jet,
        Vector3::new(-570.0, 60.0, 0.0),
        Vector3::X * 10.0,
        Vector3::ZERO,
    );
    recon.fuse = 0.0;
    recon.sight = 50.0;
    let mut rng = SimulationRandom::default();
    assert!(recon.advance(0.5, 0.5, 0, 512.0, &[], &mut rng).is_empty());
    assert_eq!(
        recon.advance(0.5, 1.0, 0, 512.0, &[], &mut rng),
        vec![Event::Photograph]
    );
    assert!(recon.advance(0.1, 1.1, 0, 512.0, &[], &mut rng).is_empty());
    assert!(recon.advance(0.5, 1.6, -1, 512.0, &[], &mut rng).is_empty());
}

#[test]
fn support_checkpoints_reject_malformed_state_without_allocating_unbounded_hits() {
    let state = SupportFlight::new(Kind::GunRun, Vector3::ZERO, Vector3::X, Vector3::ZERO);
    let bytes = state.checkpoint();
    for end in 0..bytes.len() {
        assert!(SupportFlight::restore(&bytes[..end]).is_err());
    }
    for (i, value) in [(4, 2), (8, 3), (9, 5), (10, 2), (103, 2)] {
        let mut bad = bytes.clone();
        bad[i] = value;
        assert!(SupportFlight::restore(&bad).is_err());
    }
    let mut bad = bytes.clone();
    bad[11..15].copy_from_slice(&f32::NAN.to_le_bytes());
    assert!(SupportFlight::restore(&bad).is_err());
    let mut bad = bytes.clone();
    bad[47..55].copy_from_slice(&f64::INFINITY.to_le_bytes());
    assert!(SupportFlight::restore(&bad).is_err());
    let mut bad = bytes.clone();
    bad[106..110].copy_from_slice(&u32::MAX.to_le_bytes());
    assert!(SupportFlight::restore(&bad).is_err());
    let mut bad = bytes;
    bad.push(0);
    assert!(SupportFlight::restore(&bad).is_err());
}
