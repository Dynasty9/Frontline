#[path = "../../runtime/tests/fixtures/initial.rs"]
mod fixture;
use frontline_browser::session::Session;
use frontline_runtime::{
    content::Content,
    initial, protocol as net,
    replay::{verify, Recorder},
};

fn drain(s: &mut Session) -> Vec<(u8, u8, u64, Vec<u8>)> {
    let mut out = vec![];
    loop {
        let bytes = s.take_packets();
        if bytes.is_empty() {
            break;
        }
        let mut offset = 0;
        while offset < bytes.len() {
            let length = u32::from_le_bytes(bytes[offset..offset + 4].try_into().unwrap()) as usize;
            let channel = bytes[offset + 4];
            let (kind, seq, payload) =
                net::decode(&bytes[offset + 5..offset + 5 + length]).unwrap();
            out.push((channel, kind, seq, payload.to_vec()));
            offset += length + 5;
        }
        assert_eq!(offset, bytes.len());
    }
    out
}
#[test]
fn worker_commands_and_observations_preserve_native_ticks_and_recording() {
    let content = Content::bundled().unwrap();
    let initial = fixture::encode(&fixture::map(&content), |_| {});
    let native = initial::load(&initial, &content).unwrap();
    let mut worker = Session::new(initial.clone(), false).unwrap();
    assert_eq!(worker.metadata()["team"], 0);
    worker.step(4).unwrap();
    assert_eq!(
        worker.simulation().state.tick,
        0,
        "Loading cannot advance the match"
    );
    worker.open().unwrap();
    let baseline = drain(&mut worker);
    assert!(baseline.iter().any(|p| p.1 == net::MAP));
    assert!(baseline.iter().any(|p| p.1 == net::SPAWN));
    assert!(baseline.iter().any(|p| p.1 == net::BASELINE_END));
    assert!(!baseline.iter().any(|p| p.1 == net::FX));
    assert!(worker.open().is_err());
    worker.receive(&net::packet(net::LOADED, 0, &[])).unwrap();
    assert!(
        drain(&mut worker).iter().any(|p| p.1 == net::FX),
        "Persistent effects must arrive after loading"
    );
    let command = br#"{"t":"chat","text":"Worker command","team_only":true}"#;
    let input = frontline_runtime::simulation::Input::Command {
        peer: 7,
        command: frontline_runtime::client_command::decode(command).unwrap(),
    };
    worker
        .receive(&net::packet(net::COMMAND, 0, command))
        .unwrap();
    let mut recording = Recorder::new(Vec::new(), native, &content).unwrap();
    for tick in 0..120 {
        worker.step(1).unwrap();
        recording
            .step(
                &content,
                if tick == 0 {
                    std::slice::from_ref(&input)
                } else {
                    &[]
                },
            )
            .unwrap();
    }
    let updates = drain(&mut worker);
    assert!(updates.iter().any(|p| p.0 == 1 && p.1 == net::SNAPSHOT));
    assert!(updates
        .iter()
        .any(|p| p.1 == net::MESSAGE && String::from_utf8_lossy(&p.3).contains("Worker command")));
    assert!(worker.step(5).is_err());
    assert!(worker.receive(b"bad packet").is_err());
    assert_eq!(
        worker.simulation().checkpoint().unwrap(),
        recording.simulation().checkpoint().unwrap()
    );
    let bytes = worker.finish().unwrap();
    let (expected, native) = recording.finish().unwrap();
    assert_eq!(bytes, expected);
    if let Ok(path) = std::env::var("FL_BROWSER_CONTRACT") {
        std::fs::write(format!("{path}.initial"), initial).unwrap();
        std::fs::write(path, &bytes).unwrap();
    }
    assert_eq!(
        verify(bytes.as_slice(), &content)
            .unwrap()
            .simulation
            .checkpoint()
            .unwrap(),
        native.checkpoint().unwrap()
    );
    let mut replay = Session::new(bytes, true).unwrap();
    replay.seek(120).unwrap();
    assert_eq!(replay.metadata()["replay"]["verified"], true);
    assert_eq!(
        replay.simulation().checkpoint().unwrap(),
        native.checkpoint().unwrap()
    );
    replay.open().unwrap();
    assert!(replay.seek(0).is_err());
    assert!(replay
        .receive(&net::packet(net::COMMAND, 0, command))
        .is_err());
    let packets = drain(&mut replay);
    assert!(packets.iter().any(|p| p.1 == net::PLAYBACK));
}

#[test]
fn winning_tick_flushes_observations_before_result_between_regular_updates() {
    let content = Content::bundled().unwrap();
    let initial = fixture::encode(&fixture::map(&content), |_| {});
    let mut worker = Session::new(initial, false).unwrap();
    worker.open().unwrap();
    drain(&mut worker);
    worker.receive(&net::packet(net::LOADED, 0, &[])).unwrap();
    drain(&mut worker);
    let mut winning_tick = None;
    for _ in 0..660 {
        worker.step(1).unwrap();
        let packets = drain(&mut worker);
        if let Some(over) = packets.iter().position(|p| p.1 == net::OVER) {
            assert!(packets[..over].iter().any(|p| p.1 == net::SNAPSHOT));
            assert!(packets[..over].iter().any(|p| p.1 == net::HUD));
            assert!(packets[..over].iter().any(|p| p.1 == net::REPORT));
            winning_tick = Some(worker.simulation().state.tick);
            break;
        }
    }
    assert_eq!(winning_tick, Some(601));
    let bytes = worker.finish().unwrap();
    let verified = verify(bytes.as_slice(), &content).unwrap();
    assert_eq!(verified.simulation.state.victory.winner, 1);
    assert_eq!(verified.frames, 601);
}
