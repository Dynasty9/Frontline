use frontline_core as sim;
use frontline_server::{
    content::Content,
    replay::{declared_tick, verify, Playback, Recorder},
    simulation::{Input, Simulation},
};
use sim::match_commands::{Action, Command};
use sim::match_state::MatchState;
use sim::vector::Vector3;

fn battle(content: &Content) -> Simulation {
    let terrain = sim::terrain::Terrain::blank(64).unwrap();
    let deck = vec![0; 64 * 64];
    let boats = sim::boat_navigation::BoatNavigation::from_terrain(&terrain, &deck).unwrap();
    let geometry = sim::world_geometry::WorldGeometry::new(terrain, deck, 16).unwrap();
    let water = sim::water::Water {
        side: 64,
        coast: None,
        rivers: vec![],
        ponds: vec![],
        fords: vec![],
        bridges: vec![],
    };
    let mut state = MatchState::empty(geometry, water, boats, 137, false).unwrap();
    state.scenario = true;
    content.with_profiles(&[], |p, _| {
        for team in 0..2 {
            let x = if team == 0 { -20. } else { 20. };
            let id = state
                .field
                .geometry
                .spawn_structure(
                    &mut state.field.actors,
                    sim::structure::Structure {
                        kind: "depot".into(),
                        team,
                        position: Vector3::new(x, 0., 0.),
                        built: true,
                        ..Default::default()
                    },
                    None,
                )
                .unwrap();
            state.rules.network.depots[team as usize] = id;
            state
                .field
                .with_context(&p.shared, Default::default(), |w| {
                    w.spawn_squad(
                        sim::squad_birth::Spawn {
                            team,
                            owner: if team == 0 { 7 } else { 9 },
                            position: Vector3::new(x * 0.3, 0., 0.),
                            destination: None,
                        },
                        content
                            .squad(if team == 0 {
                                "rifle_squad"
                            } else {
                                "fighter_cell"
                            })
                            .unwrap(),
                    )
                })
                .unwrap();
        }
    });
    Simulation::new(state, 7, content).unwrap()
}
fn inputs(tick: u64) -> Vec<Input> {
    match tick {
        0 => vec![
            Input::Join {
                peer: 7,
                team: 0,
                name: "Commander Ada".into(),
                reclaim: None,
            },
            Input::Join {
                peer: 9,
                team: 1,
                name: "Commander Lin".into(),
                reclaim: None,
            },
        ],
        1 => vec![Input::Command {
            peer: 7,
            command: Command {
                squads: vec![1],
                vehicles: vec![],
                action: Action::Move {
                    position: Vector3::new(3., 0., -3.),
                    face: Vector3::X,
                    mode: 0,
                },
            },
        }],
        30 => vec![Input::Command {
            peer: 7,
            command: Command {
                squads: vec![1],
                vehicles: vec![],
                action: Action::Throw {
                    position: Vector3::new(6., 0., 0.),
                    smoke: false,
                },
            },
        }],
        70 => vec![Input::Leave { peer: 7 }],
        80 => vec![Input::Join {
            peer: 11,
            team: 0,
            name: "Commander Ada".into(),
            reclaim: Some(7),
        }],
        100 => vec![Input::Command {
            peer: 11,
            command: Command {
                squads: vec![],
                vehicles: vec![],
                action: Action::Chat {
                    text: "Regroup".into(),
                    team_only: true,
                },
            },
        }],
        _ => vec![],
    }
}

#[test]
fn recorded_combat_and_rejoins_rerun_to_the_same_state_and_events() {
    let c = Content::bundled().unwrap();
    let mut live = battle(&c);
    let mut resumed = Simulation::restore(&live.checkpoint().unwrap(), &c).unwrap();
    let mut recording = Recorder::new(Vec::new(), &live, &c).unwrap();
    for tick in 0..180 {
        let commands = inputs(tick);
        for input in &commands {
            assert_eq!(*input, Input::decode(&input.encode().unwrap()).unwrap());
        }
        assert_eq!(
            recording.step(&mut live, &c, &commands).unwrap(),
            resumed.step(&c, &commands).unwrap(),
            "tick {tick}"
        );
        if tick == 90 {
            resumed = Simulation::restore(&resumed.checkpoint().unwrap(), &c).unwrap();
        }
    }
    let bytes = recording.finish(&live).unwrap();
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
    let mut live = battle(&c);
    let mut recording = Recorder::new(Vec::new(), &live, &c).unwrap();
    let frames: Vec<_> = (0..100)
        .map(|t| recording.step(&mut live, &c, &inputs(t)).unwrap())
        .collect();
    let bytes = recording.finish(&live).unwrap();
    let mut source = std::io::Cursor::new(bytes.clone());
    assert_eq!(declared_tick(&mut source).unwrap(), 100);
    let (mut stream, mut state) = Playback::new(source, &c).unwrap();
    for frame in frames {
        assert!(!stream.verified());
        assert_eq!(stream.step(&mut state, &c).unwrap(), Some(frame));
    }
    assert!(!stream.verified());
    assert_eq!(stream.step(&mut state, &c).unwrap(), None);
    assert!(stream.verified());
    assert_eq!(state.checkpoint().unwrap(), live.checkpoint().unwrap());
    assert_eq!(stream.step(&mut state, &c).unwrap(), None);
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
    let mut s = battle(&c);
    let mut rec = Recorder::new(Vec::new(), &s, &c).unwrap();
    rec.step(&mut s, &c, &inputs(0)).unwrap();
    let bytes = rec.finish(&s).unwrap();
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
fn independent_verifier_process_reruns_a_recording_and_rejects_a_bad_conclusion() {
    let c = Content::bundled().unwrap();
    let mut s = battle(&c);
    let mut rec = Recorder::new(Vec::new(), &s, &c).unwrap();
    for tick in 0..125 {
        rec.step(&mut s, &c, &inputs(tick)).unwrap();
    }
    let mut bytes = rec.finish(&s).unwrap();
    let path = std::env::temp_dir().join(format!(
        "frontline-replay-{}-{}.flr",
        std::process::id(),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    let mut file = std::fs::OpenOptions::new()
        .write(true)
        .create_new(true)
        .open(&path)
        .unwrap();
    std::io::Write::write_all(&mut file, &bytes).unwrap();
    drop(file);
    let output = std::process::Command::new(env!("CARGO_BIN_EXE_frontline-server"))
        .arg("verify")
        .arg(&path)
        .output()
        .unwrap();
    assert!(
        output.status.success(),
        "{}",
        String::from_utf8_lossy(&output.stderr)
    );
    assert!(String::from_utf8_lossy(&output.stdout).contains("REPLAY_VERIFIED tick=125 frames=125"));
    let last = bytes.len() - 1;
    bytes[last] ^= 1;
    std::fs::write(&path, bytes).unwrap();
    let bad = std::process::Command::new(env!("CARGO_BIN_EXE_frontline-server"))
        .arg("verify")
        .arg(&path)
        .output()
        .unwrap();
    std::fs::remove_file(path).unwrap();
    assert!(!bad.status.success());
    assert!(!String::from_utf8_lossy(&bad.stdout).contains("REPLAY_VERIFIED"));
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
    let mut rec = Recorder::new(Vec::new(), &s, &c).unwrap();
    rec.step(&mut s, &c, &[]).unwrap();
    assert_eq!(s.state.victory.winner, 0);
    let mut bytes = rec.finish(&s).unwrap();
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
