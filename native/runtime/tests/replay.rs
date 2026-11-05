#[path = "fixtures/replay.rs"]
mod fixture;
use fixture::{battle, inputs};
use frontline_core as sim;
use frontline_runtime::{
    content::Content,
    replay::{declared_tick, verify, Playback, Recorder},
    simulation::{Input, Simulation},
};
use sim::match_commands::{Action, Command};
use sim::vector::Vector3;

#[test]
fn phase_measurements_do_not_change_commands_events_or_checkpoint() {
    let content = Content::bundled().unwrap();
    let mut measured = battle(&content);
    let mut plain = Simulation::restore(&measured.checkpoint().unwrap(), &content).unwrap();
    measured.profile = Some(Default::default());
    for _ in 0..120 {
        let a = measured.step(&content, &[]).unwrap();
        let b = plain.step(&content, &[]).unwrap();
        assert_eq!(a.commands, b.commands);
        assert_eq!(a.events, b.events);
    }
    assert_eq!(measured.checkpoint().unwrap(), plain.checkpoint().unwrap());
    let phases = &measured.profile.as_ref().unwrap().phases;
    assert!(phases.len() >= 12 && phases.contains_key("infantry"));
    for phase in ["terrain_cover", "navigation_hierarchy", "navigation_paths"] {
        assert!(phases.contains_key(phase));
    }
    assert!(phases.values().all(|ms| ms.is_finite() && *ms >= 0.));
}

#[test]
fn late_join_reinforcements_use_the_first_fob_and_reconnect_does_not_duplicate_them() {
    let content = Content::bundled().unwrap();
    let mut simulation = battle(&content);
    for (x, order) in [(18., 8), (-18., 2)] {
        let f = &mut simulation.state.field;
        f.geometry
            .spawn_structure(
                &mut f.actors,
                sim::structure::Structure {
                    kind: "fob".into(),
                    team: 0,
                    built: true,
                    completed_order: order,
                    position: Vector3::new(x, 0., 0.),
                    ..Default::default()
                },
                None,
            )
            .unwrap();
    }
    let count = simulation.state.field.squads.len();
    let mut recording = Recorder::new(Vec::new(), simulation, &content).unwrap();
    recording
        .step(
            &content,
            &[Input::Join {
                peer: 31,
                team: 0,
                name: "Late commander".into(),
                reclaim: None,
            }],
        )
        .unwrap();
    let squads = &recording.simulation().state.field.squads;
    assert_eq!(squads.len(), count + 2);
    let mine: Vec<_> = squads.iter().filter(|s| s.owner == 31).collect();
    assert_eq!(mine.len(), 2);
    assert!(mine.iter().all(|s| s.order_position.x < 0.));
    recording
        .step(&content, &[Input::Leave { peer: 31 }])
        .unwrap();
    recording
        .step(
            &content,
            &[Input::Join {
                peer: 41,
                team: 0,
                name: "Returned commander".into(),
                reclaim: Some(31),
            }],
        )
        .unwrap();
    assert_eq!(recording.simulation().state.field.squads.len(), count + 2);
    assert_eq!(
        recording
            .simulation()
            .state
            .field
            .squads
            .iter()
            .filter(|s| s.owner == 41)
            .count(),
        2
    );
    let (bytes, simulation) = recording.finish().unwrap();
    let verified = verify(std::io::Cursor::new(bytes), &content).unwrap();
    assert_eq!(
        verified.simulation.checkpoint().unwrap(),
        simulation.checkpoint().unwrap()
    );
}
#[test]
fn recorded_combat_and_rejoins_rerun_to_the_same_state_and_events() {
    let c = Content::bundled().unwrap();
    let live = battle(&c);
    let mut resumed = Simulation::restore(&live.checkpoint().unwrap(), &c).unwrap();
    let mut recording = Recorder::new(Vec::new(), live, &c).unwrap();
    for tick in 0..180 {
        let commands = inputs(tick);
        for input in &commands {
            assert_eq!(*input, Input::decode(&input.encode().unwrap()).unwrap());
        }
        assert_eq!(
            recording.step(&c, &commands).unwrap(),
            resumed.step(&c, &commands).unwrap(),
            "tick {tick}"
        );
        if tick == 90 {
            resumed = Simulation::restore(&resumed.checkpoint().unwrap(), &c).unwrap();
        }
    }
    let (bytes, live) = recording.finish().unwrap();
    let result = verify(bytes.as_slice(), &c).unwrap();
    assert_eq!(result.frames, 180);
    assert_eq!(
        result.simulation.checkpoint().unwrap(),
        live.checkpoint().unwrap()
    );
    assert!(!live.state.owners.players.iter().any(|p| p.0 == 7));
    assert!(live.state.owners.players.contains(&(11, 0)));
    assert!(live.state.field.squads.iter().any(|q| q.owner == 11));
    assert_eq!(live.state.tick, 180);
}

#[test]
fn visual_playback_advances_the_verifiers_stream_and_only_verifies_the_footer() {
    let c = Content::bundled().unwrap();
    let live = battle(&c);
    let mut recording = Recorder::new(Vec::new(), live, &c).unwrap();
    let frames: Vec<_> = (0..100)
        .map(|t| recording.step(&c, &inputs(t)).unwrap())
        .collect();
    let (bytes, live) = recording.finish().unwrap();
    let mut source = std::io::Cursor::new(bytes.clone());
    assert_eq!(declared_tick(&mut source).unwrap(), 100);
    let mut stream = Playback::new(source, &c).unwrap();
    for frame in frames {
        assert!(!stream.verified());
        assert_eq!(stream.step(&c).unwrap(), Some(frame));
    }
    assert!(!stream.verified());
    assert_eq!(stream.step(&c).unwrap(), None);
    assert!(stream.verified());
    assert_eq!(
        stream.simulation().checkpoint().unwrap(),
        live.checkpoint().unwrap()
    );
    assert_eq!(stream.step(&c).unwrap(), None);
    let mut bad = bytes.clone();
    *bad.last_mut().unwrap() ^= 1;
    let mut bad = std::io::Cursor::new(bad);
    assert_eq!(declared_tick(&mut bad).unwrap(), 100);
    assert!(
        verify(bad, &c).is_err(),
        "a readable timeline is not a verified replay"
    );
    assert!(declared_tick(&mut std::io::Cursor::new(&bytes[..bytes.len() - 1])).is_err());
}

#[test]
fn truncated_tampered_and_incompatible_replays_cannot_verify() {
    let c = Content::bundled().unwrap();
    let s = battle(&c);
    let mut rec = Recorder::new(Vec::new(), s, &c).unwrap();
    rec.step(&c, &inputs(0)).unwrap();
    let (bytes, _s) = rec.finish().unwrap();
    for length in [0, 4, 16, bytes.len() - 1] {
        assert!(verify(&bytes[..length], &c).is_err(), "truncation {length}");
    }
    let mut altered = bytes.clone();
    let i = altered
        .windows(13)
        .position(|s| s == b"Commander Ada")
        .unwrap();
    altered[i + 12] = b'u';
    assert!(verify(altered.as_slice(), &c).is_err());
    let mut altered = bytes.clone();
    let last = altered.len() - 1;
    altered[last] ^= 1;
    assert!(verify(altered.as_slice(), &c).is_err());
    let mut altered = bytes.clone();
    altered[16] ^= 1;
    assert!(verify(altered.as_slice(), &c)
        .err()
        .unwrap()
        .contains("incompatible"));
    let mut extra = bytes;
    extra.push(0);
    assert!(verify(extra.as_slice(), &c).is_err());
}

#[test]
fn invalid_admissions_are_rejected_before_any_gameplay_changes() {
    let c = Content::bundled().unwrap();
    let mut s = battle(&c);
    let before = s.checkpoint().unwrap();
    let mut commands = inputs(0);
    commands.push(commands[0].clone());
    assert!(s.step(&c, &commands).is_err());
    assert_eq!(before, s.checkpoint().unwrap());
    let command = Input::Command {
        peer: 7,
        command: Command {
            squads: vec![1],
            vehicles: vec![],
            action: Action::Stop,
        },
    };
    assert!(s.step(&c, &[command]).is_err());
    assert_eq!(before, s.checkpoint().unwrap());
    assert!(Input::decode(&[255; 32]).is_err());
}

#[test]
fn conclusion_is_recomputed_by_the_rules_and_cannot_be_changed_in_the_recording() {
    let c = Content::bundled().unwrap();
    let mut s = battle(&c);
    s.state
        .field
        .geometry
        .spawn_structure(
            &mut s.state.field.actors,
            sim::structure::Structure {
                kind: "fob".into(),
                team: 0,
                position: Vector3::new(-16., 0., 16.),
                built: true,
                ..Default::default()
            },
            Some(c.building("fob").unwrap().body),
        )
        .unwrap();
    s.state.tick = 600;
    s.state.field.now = 10.;
    assert_eq!(s.state.victory.winner, -1);
    let initial = *blake3::hash(&s.checkpoint().unwrap()).as_bytes();
    let mut rec = Recorder::new(Vec::new(), s, &c).unwrap();
    rec.step(&c, &[]).unwrap();
    assert_eq!(rec.simulation().state.victory.winner, 0);
    let (mut bytes, _s) = rec.finish().unwrap();
    let result = verify(bytes.as_slice(), &c).unwrap();
    assert_eq!(result.initial_hash, initial);
    assert_eq!(result.simulation.state.victory.winner, 0);
    let winner = bytes.len() - 37;
    assert_eq!(bytes[winner], 0);
    bytes[winner] = 1;
    assert!(verify(bytes.as_slice(), &c)
        .err()
        .unwrap()
        .contains("conclusion differs"));
}

#[test]
fn a_recording_cannot_continue_or_finish_after_an_output_failure() {
    use std::{
        cell::Cell,
        io::{self, Write},
        rc::Rc,
    };
    struct Output {
        fail: Rc<Cell<bool>>,
    }
    impl Write for Output {
        fn write(&mut self, data: &[u8]) -> io::Result<usize> {
            if self.fail.get() {
                Err(io::Error::other("disk full"))
            } else {
                Ok(data.len())
            }
        }
        fn flush(&mut self) -> io::Result<()> {
            Ok(())
        }
    }
    let content = Content::bundled().unwrap();
    let fail = Rc::new(Cell::new(false));
    let mut recording =
        Recorder::new(Output { fail: fail.clone() }, battle(&content), &content).unwrap();
    fail.set(true);
    assert!(recording.step(&content, &[]).is_err());
    fail.set(false);
    assert!(recording.step(&content, &[]).is_err());
    assert!(recording.finish().is_err());
}

#[test]
fn playback_cannot_skip_a_bad_record_and_later_claim_verification() {
    let content = Content::bundled().unwrap();
    let mut recording = Recorder::new(Vec::new(), battle(&content), &content).unwrap();
    recording.step(&content, &[]).unwrap();
    let (mut bytes, _) = recording.finish().unwrap();
    let header_len = 4 + u32::from_le_bytes(bytes[..4].try_into().unwrap()) as usize;
    let mut bad = sim::state_codec::Writer::new(b"FLRF\x01\0\0\0");
    bad.byte(99);
    bad.u64(0);
    let mut record = (bad.0.len() as u32).to_le_bytes().to_vec();
    record.extend(bad.0);
    bytes.splice(header_len..header_len, record);
    let mut playback = Playback::new(bytes.as_slice(), &content).unwrap();
    assert!(playback.step(&content).is_err());
    assert!(playback.step(&content).is_err());
    assert!(!playback.verified());
}

#[test]
fn recording_can_start_with_an_unfinished_route_and_verify_its_continuation() {
    use sim::{
        actors::{Actor, Actors},
        infantry::Goal,
        traversal::Ground,
    };
    let content = Content::bundled().unwrap();
    let mut simulation = battle(&content);
    let f = &mut simulation.state.field;
    let id = f
        .actors
        .iter()
        .find_map(|a| match a {
            Actor::Soldier(s) => Some(s.identity.id),
            _ => None,
        })
        .unwrap();
    let mut soldier = f.actors.soldier(id).unwrap().clone();
    let order = soldier
        .go_to(Vector3::new(28., 0., -25.), Goal::Slot, 0)
        .unwrap();
    let ground = Ground::new(&f.geometry.terrain, &f.geometry.deck);
    assert!(f
        .geometry
        .navigation
        .submit_infantry(&mut soldier, order, f.now, &mut f.rng, ground)
        .unwrap()
        .is_none());
    let entries = f
        .actors
        .iter()
        .map(|a| match a {
            Actor::Soldier(s) if s.identity.id == id => Actor::Soldier(Box::new(soldier.clone())),
            _ => a.clone(),
        })
        .collect();
    f.actors = Actors::from_entries(f.actors.entities().next_id(), entries).unwrap();
    assert!(f
        .geometry
        .navigation
        .process_paths_with_work_limit(&mut f.actors, 4, 1, f.now, &mut f.rng, ground)
        .unwrap()
        .is_empty());
    assert_eq!(f.geometry.navigation.infantry.last_expanded, 1);
    let initial = simulation.checkpoint().unwrap();
    assert_eq!(
        Simulation::restore(&initial, &content)
            .unwrap()
            .checkpoint()
            .unwrap(),
        initial
    );
    let mut recording = Recorder::new(Vec::new(), simulation, &content).unwrap();
    for _ in 0..60 {
        recording.step(&content, &[]).unwrap();
    }
    let (bytes, final_state) = recording.finish().unwrap();
    let verified = verify(bytes.as_slice(), &content).unwrap();
    assert_eq!(
        verified.simulation.checkpoint().unwrap(),
        final_state.checkpoint().unwrap()
    );
}
