use frontline_core as sim;
use frontline_server::{
    content::Content,
    network::{self as net, Admission},
    replay,
    serve::{self, Config},
    simulation::Simulation,
};
use rusty_enet::{Event, Host, HostSettings, Packet};
use serde_json::json;
use std::{
    fs::{self, File},
    net::UdpSocket,
    path::PathBuf,
    sync::atomic::{AtomicU64, Ordering},
    thread,
    time::{Duration, Instant, SystemTime, UNIX_EPOCH},
};

fn map(c: &Content) -> Simulation {
    let terrain = sim::terrain::Terrain::blank(64).unwrap();
    let deck = vec![0; 4096];
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
    let mut state = sim::match_state::MatchState::empty(geometry, water, boats, 1, false).unwrap();
    state.scenario = true;
    for (peer, team) in [(7, 0), (9, 1)] {
        state.owners.players.push((peer, team));
        state.field.battle.joined(peer, team, "Commander").unwrap();
        c.with_profiles(&[], |p, _| {
            state
                .field
                .with_context(&p.shared, Default::default(), |w| {
                    w.spawn_squad(
                        sim::squad_birth::Spawn {
                            team,
                            owner: peer,
                            position: sim::vector::Vector3::new(
                                if team == 0 { -20. } else { 20. },
                                0.,
                                0.,
                            ),
                            destination: None,
                        },
                        c.squad(if team == 0 {
                            "rifle_squad"
                        } else {
                            "fighter_cell"
                        })
                        .unwrap(),
                    )
                })
        })
        .unwrap();
    }
    state
        .field
        .actors
        .rebuild_units(&mut state.field.units)
        .unwrap();
    Simulation::new(state, 7, c).unwrap()
}
struct Server {
    directory: PathBuf,
    ready: PathBuf,
    stop: PathBuf,
    replay: PathBuf,
    handle: Option<thread::JoinHandle<Result<(), String>>>,
}
impl Server {
    fn new() -> Self {
        static NEXT_DIRECTORY: AtomicU64 = AtomicU64::new(0);
        let directory = std::env::temp_dir().join(format!(
            "frontline-socket-{}-{}-{}",
            std::process::id(),
            SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_nanos(),
            NEXT_DIRECTORY.fetch_add(1, Ordering::Relaxed)
        ));
        fs::create_dir(&directory).unwrap();
        let ready = directory.join("ready.json");
        let stop = directory.join("stop");
        let replay = directory.join("match.flrp");
        let players = [(7, 0, '1'), (9, 1, '2'), (11, -1, '3'), (13, 0, '4')]
            .map(|(peer, team, digit)| Admission {
                peer,
                team,
                token: digit.to_string().repeat(48),
                name: format!("Commander {peer}"),
                reclaim: None,
            })
            .to_vec();
        let config = Config {
            bind: "127.0.0.1:0".parse().unwrap(),
            admissions: players,
            admission_file: Some(directory.join("admissions.json")),
            // Reconnect can wait for ENet retries on a busy desktop.
            max_ticks: Some(600),
            ready: Some(ready.clone()),
            stop: Some(stop.clone()),
            speed: None,
            error: None,
            lease: None,
            seek: 0,
            profile: frontline_server::profiling::Profile::decode(
                &json!({"path":directory.join("profile.json"),"warmup":0,"duration":1}),
            )
            .unwrap(),
        };
        let output = File::create(&replay).unwrap();
        let handle = thread::spawn(move || {
            let c = Content::bundled().unwrap();
            serve::run(map(&c), &c, config, output)
        });
        let deadline = Instant::now() + Duration::from_secs(10);
        while fs::read(&ready)
            .ok()
            .and_then(|b| serde_json::from_slice::<serde_json::Value>(&b).ok())
            .is_none()
        {
            assert!(Instant::now() < deadline, "server did not bind");
            thread::sleep(Duration::from_millis(2));
        }
        Self {
            directory,
            ready,
            stop,
            replay,
            handle: Some(handle),
        }
    }
    fn finish(&mut self) -> replay::Verification {
        fs::write(&self.stop, []).unwrap();
        self.handle.take().unwrap().join().unwrap().unwrap();
        replay::verify(
            File::open(&self.replay).unwrap(),
            &Content::bundled().unwrap(),
        )
        .unwrap()
    }
    fn playback(&mut self, seek: u64) {
        fs::remove_file(&self.ready).unwrap();
        fs::remove_file(&self.stop).unwrap();
        let config = Config::decode(
            &serde_json::to_vec(&json!({"bind":"127.0.0.1:0",
            "players":[{"peer":11,"team":-1,"name":"Observer","token":"3".repeat(48)}],
            "ready":self.ready,"stop":self.stop,"seek":seek}))
            .unwrap(),
        )
        .unwrap();
        let source = File::open(&self.replay).unwrap();
        self.handle = Some(thread::spawn(move || {
            serve::playback(source, &Content::bundled().unwrap(), config)
        }));
        let deadline = Instant::now() + Duration::from_secs(12);
        while fs::read(&self.ready)
            .ok()
            .and_then(|b| serde_json::from_slice::<serde_json::Value>(&b).ok())
            .is_none()
        {
            assert!(Instant::now() < deadline);
            thread::sleep(Duration::from_millis(2));
        }
    }
}
impl Drop for Server {
    fn drop(&mut self) {
        if let Some(handle) = self.handle.take() {
            let _ = fs::write(&self.stop, []);
            let _ = handle.join();
        }
        for file in [&self.ready, &self.stop, &self.replay] {
            let _ = fs::remove_file(file);
        }
        let _ = fs::remove_file(self.directory.join("profile.json"));
        let _ = fs::remove_file(self.directory.join("admissions.json"));
        let _ = fs::remove_file(self.directory.join("admissions.admitted"));
        let _ = fs::remove_dir(&self.directory);
    }
}
struct Client {
    host: Host<UdpSocket>,
    token: String,
    joined: bool,
    loaded: bool,
    closed: bool,
    spawns: usize,
    tick: u64,
    messages: Vec<serde_json::Value>,
    playback: serde_json::Value,
    presence: Vec<Vec<u8>>,
    marks: Vec<(u8, serde_json::Value)>,
}
impl Client {
    fn new(server: &Server, token: char) -> Self {
        let ready: serde_json::Value =
            serde_json::from_slice(&fs::read(&server.ready).unwrap()).unwrap();
        let mut host = Host::new(
            UdpSocket::bind("127.0.0.1:0").unwrap(),
            HostSettings {
                peer_limit: 1,
                channel_limit: 3,
                ..Default::default()
            },
        )
        .unwrap();
        host.connect(ready["address"].as_str().unwrap().parse().unwrap(), 3, 0)
            .unwrap();
        Self {
            host,
            token: token.to_string().repeat(48),
            joined: false,
            loaded: false,
            closed: false,
            spawns: 0,
            tick: 0,
            messages: vec![],
            playback: serde_json::Value::Null,
            presence: vec![],
            marks: vec![],
        }
    }
    fn poll(&mut self) {
        while let Some(event) = self.host.service().unwrap() {
            match event {
                Event::Connect { peer, .. } => peer
                    .send(
                        0,
                        &Packet::reliable(net::packet(
                            net::AUTH,
                            0,
                            json!({"token":self.token,"engine":frontline_server::ENGINE_ID})
                                .to_string()
                                .as_bytes(),
                        )),
                    )
                    .unwrap(),
                Event::Disconnect { .. } => self.closed = true,
                Event::Receive {
                    peer,
                    channel_id,
                    packet,
                } => {
                    let (kind, seq, data) = net::decode(packet.data()).unwrap();
                    match kind {
                        net::WELCOME => self.joined = true,
                        net::SPAWN => self.spawns += 1,
                        net::SNAPSHOT => self.tick = seq,
                        net::MESSAGE => self.messages.push(serde_json::from_slice(data).unwrap()),
                        net::PLAYBACK => self.playback = serde_json::from_slice(data).unwrap(),
                        net::PRESENCE => self.presence.push(data.to_vec()),
                        net::PING | net::SKETCH | net::DEED => self
                            .marks
                            .push((kind, serde_json::from_slice(data).unwrap())),
                        net::BASELINE_END => {
                            self.loaded = true;
                            peer.send(0, &Packet::reliable(net::packet(net::LOADED, 0, &[])))
                                .unwrap();
                        }
                        _ => {}
                    }
                    if channel_id == 0 {
                        peer.send(0, &Packet::reliable(net::packet(net::ACK, seq, &[])))
                            .unwrap();
                    }
                }
            }
        }
        self.host.flush();
    }
    fn command(&mut self, data: serde_json::Value) {
        self.host
            .peer_mut(rusty_enet::PeerID(0))
            .send(
                0,
                &Packet::reliable(net::packet(net::COMMAND, 0, data.to_string().as_bytes())),
            )
            .unwrap();
    }
    fn presentation(&mut self, kind: u8, data: &[u8]) {
        self.host
            .peer_mut(rusty_enet::PeerID(0))
            .send(
                if kind == net::SEND_PRESENCE { 1 } else { 0 },
                &if kind == net::SEND_PRESENCE {
                    Packet::unreliable(net::packet(kind, 0, data))
                } else {
                    Packet::reliable(net::packet(kind, 0, data))
                },
            )
            .unwrap();
        self.host.flush();
    }
}

#[test]
fn co_command_is_team_private_authenticated_bounded_and_absent_from_replay_inputs() {
    let mut server = Server::new();
    let mut clients = ['1', '2', '3', '4'].map(|token| Client::new(&server, token));
    let deadline = Instant::now() + Duration::from_secs(20);
    while clients.iter().any(|c| c.tick < 16) {
        for c in &mut clients {
            c.poll();
        }
        assert!(Instant::now() < deadline);
        thread::sleep(Duration::from_millis(1));
    }
    clients[0].presentation(net::SEND_PRESENCE, &[0; 97]);
    let ping =
        json!({"t":"ping","peer":9,"kind":"enemy","position":[999,0,-999],"entity":u32::MAX})
            .to_string();
    clients[0].presentation(net::MARK, ping.as_bytes());
    clients[0].presentation(net::MARK, br#"{"t":"sketch","points":[[0,0],[999,-999]]}"#);
    for _ in 0..6 {
        clients[0].presentation(net::MARK, ping.as_bytes());
    }
    while clients[2].marks.len() < 4
        || clients[3].marks.len() < 4
        || clients[2].presence.is_empty()
        || clients[3].presence.is_empty()
    {
        for c in &mut clients {
            c.poll();
        }
        assert!(Instant::now() < deadline);
        thread::sleep(Duration::from_millis(1));
    }
    assert!(clients[0].marks.is_empty() && clients[0].presence.is_empty());
    assert!(clients[1].marks.is_empty() && clients[1].presence.is_empty());
    for c in &clients[2..] {
        assert_eq!(c.marks.len(), 4);
        assert_eq!(
            i32::from_le_bytes(c.presence[0][..4].try_into().unwrap()),
            7
        );
        assert_eq!(
            c.marks[0],
            (net::PING, json!([7, "enemy", [32., 0., -32.], 0]))
        );
        assert_eq!(
            c.marks[1],
            (net::SKETCH, json!([7, [[0., 0.], [32., -32.]]]))
        );
    }
    let verified = server.finish();
    assert!(verified.frames >= 16);
    let bytes = fs::read(&server.replay).unwrap();
    assert!(!bytes
        .windows(b"\"sketch\"".len())
        .any(|b| b == b"\"sketch\""));
}
#[test]
fn replay_socket_ignores_live_commands_and_seek_reexecutes_the_same_inputs() {
    let mut server = Server::new();
    let mut live = Client::new(&server, '1');
    let deadline = Instant::now() + Duration::from_secs(20);
    while live.tick < 40 {
        live.poll();
        assert!(Instant::now() < deadline);
        thread::sleep(Duration::from_millis(1));
    }
    let verified = server.finish();
    drop(live);
    let bytes = fs::read(&server.replay).unwrap();
    for seek in [0, 20, verified.frames] {
        server.playback(seek);
        let mut viewer = Client::new(&server, '3');
        let mut sent = false;
        while viewer.playback["verified"] != true {
            viewer.poll();
            if viewer.loaded && !sent {
                viewer.command(json!({"t":"chat","text":"Must not enter replay"}));
                sent = true;
            }
            assert!(Instant::now() < deadline);
            thread::sleep(Duration::from_millis(1));
        }
        assert!(viewer.spawns > 0 && viewer.playback["position"] == viewer.playback["duration"]);
        assert!(!viewer
            .messages
            .iter()
            .any(|m| m.to_string().contains("Must not enter replay")));
        server.finish();
        assert_eq!(fs::read(&server.replay).unwrap(), bytes);
    }
}
#[test]
fn socket_clients_receive_private_views_and_record_admitted_commands() {
    let mut server = Server::new();
    let mut a = Client::new(&server, '1');
    let mut b = Client::new(&server, '2');
    let deadline = Instant::now() + Duration::from_secs(12);
    let mut sent = false;
    while a.tick < 40 || b.tick < 40 {
        a.poll();
        b.poll();
        if a.loaded && b.loaded && !sent {
            a.command(json!({"t":"chat","text":"Recorded socket command","team_only":true}));
            sent = true;
        }
        assert!(Instant::now() < deadline, "socket match stalled");
        thread::sleep(Duration::from_millis(1));
    }
    assert!(a.joined && b.joined && a.spawns > 0 && b.spawns > 0);
    assert!(a
        .messages
        .iter()
        .any(|m| m.to_string().contains("Recorded socket command")));
    assert!(!b
        .messages
        .iter()
        .any(|m| m.to_string().contains("Recorded socket command")));
    let verified = server.finish();
    assert!(verified.frames >= 40);
    assert_eq!(verified.simulation.state.owners.team_of(7), 0);
    assert_eq!(verified.simulation.state.owners.team_of(9), 1);
    let bytes = fs::read(&server.replay).unwrap();
    assert!(bytes
        .windows(b"Recorded socket command".len())
        .any(|b| b == b"Recorded socket command"));
}

#[test]
fn late_join_and_reconnect_receive_fresh_baselines_without_changing_ownership() {
    let mut server = Server::new();
    let mut a = Client::new(&server, '1');
    let mut b = Client::new(&server, '2');
    let deadline = Instant::now() + Duration::from_secs(12);
    while a.tick < 20 || b.tick < 20 {
        a.poll();
        b.poll();
        assert!(Instant::now() < deadline);
        thread::sleep(Duration::from_millis(1));
    }
    let first_baseline = a.spawns;
    a.host.peer_mut(rusty_enet::PeerID(0)).disconnect_now(0);
    a.host.flush();
    drop(a);
    while b.tick < 28 {
        b.poll();
        assert!(Instant::now() < deadline);
        thread::sleep(Duration::from_millis(1));
    }
    let mut returning = Client::new(&server, '1');
    let mut observer = Client::new(&server, '3');
    let mut ally = Client::new(&server, '4');
    while returning.tick < 76 || observer.tick < 76 || ally.tick < 76 {
        b.poll();
        returning.poll();
        observer.poll();
        ally.poll();
        assert!(Instant::now() < deadline);
        thread::sleep(Duration::from_millis(1));
    }
    assert!(
        returning.loaded
            && returning.spawns >= first_baseline
            && observer.spawns >= returning.spawns
            && ally.loaded
            && ally.spawns == returning.spawns
    );
    let profile: serde_json::Value =
        serde_json::from_slice(&fs::read(server.directory.join("profile.json")).unwrap()).unwrap();
    assert_eq!(profile["runtime"], "rust");
    assert_eq!(profile["tick_hz"], 60);
    assert!(profile["ticks"]["count"].as_u64().unwrap() > 0);
    let verified = server.finish();
    assert_eq!(verified.simulation.state.owners.team_of(7), 0);
    assert!(verified
        .simulation
        .state
        .field
        .actors
        .iter()
        .any(|a| matches!(a,sim::actors::Actor::Soldier(s) if s.identity.owner==7)));
}
#[test]
fn lobby_admission_changes_revoke_tickets_preserve_connections_and_record_reclaims() {
    let mut server = Server::new();
    let mut a = Client::new(&server, '1');
    let mut b = Client::new(&server, '2');
    let deadline = Instant::now() + Duration::from_secs(20);
    while a.tick < 16 || b.tick < 16 {
        a.poll();
        b.poll();
        assert!(Instant::now() < deadline);
        thread::sleep(Duration::from_millis(1));
    }
    let players = json!({"players":[
        {"peer":9,"team":1,"name":"Commander 9","token":"2".repeat(48)},
        {"peer":17,"team":0,"name":"Returned commander","token":"5".repeat(48),"reclaim":7}
    ]});
    let temporary = server.directory.join("admissions.tmp");
    fs::write(&temporary, serde_json::to_vec(&players).unwrap()).unwrap();
    fs::rename(temporary, server.directory.join("admissions.json")).unwrap();
    while !a.closed {
        a.poll();
        b.poll();
        assert!(
            Instant::now() < deadline,
            "revoked ticket remained connected"
        );
        thread::sleep(Duration::from_millis(1));
    }
    let mut revoked = Client::new(&server, '1');
    let mut returning = Client::new(&server, '5');
    while !revoked.closed || returning.tick < 64 {
        b.poll();
        revoked.poll();
        returning.poll();
        assert!(
            Instant::now() < deadline,
            "admitted returning player did not join"
        );
        thread::sleep(Duration::from_millis(1));
    }
    assert!(!revoked.joined && !b.closed && returning.loaded);
    b.command(json!({"t":"chat","text":"Kept my identity","team_only":true}));
    while !b
        .messages
        .iter()
        .any(|m| m.to_string().contains("Kept my identity"))
    {
        b.poll();
        returning.poll();
        assert!(Instant::now() < deadline);
        thread::sleep(Duration::from_millis(1));
    }
    let verified = server.finish();
    assert_eq!(verified.simulation.state.owners.team_of(17), 0);
    assert!(verified
        .simulation
        .state
        .field
        .actors
        .iter()
        .any(|a| matches!(a, sim::actors::Actor::Soldier(s) if s.identity.owner == 17)));
}

#[test]
fn unauthorized_connections_and_identity_spoofs_are_disconnected() {
    let mut server = Server::new();
    let mut bad = Client::new(&server, 'f');
    let mut a = Client::new(&server, '1');
    let deadline = Instant::now() + Duration::from_secs(10);
    let mut sent = false;
    while !bad.closed || !a.closed {
        bad.poll();
        a.poll();
        if a.loaded && !sent {
            a.command(json!({"t":"chat","text":"spoof","peer":9}));
            sent = true;
        }
        assert!(
            Instant::now() < deadline,
            "invalid peer was not disconnected"
        );
        thread::sleep(Duration::from_millis(1));
    }
    assert!(!bad.joined && bad.spawns == 0);
    server.finish();
}
#[test]
fn network_headers_and_configuration_are_bounded() {
    let p = net::packet(net::COMMAND, 0, b"{}");
    assert_eq!(net::decode(&p).unwrap(), (net::COMMAND, 0, &b"{}"[..]));
    for len in 0..16 {
        assert!(net::decode(&p[..len]).is_err());
    }
    let mut bad = p.clone();
    bad[4] = 255;
    assert!(net::decode(&bad).is_err());
    assert!(net::decode(&vec![0; net::MAX_PACKET + 1]).is_err());
    assert!(Config::decode(b"{}").is_err());
    assert!(Config::decode(&vec![0; 65537]).is_err());
    let player = json!({"peer":7,"team":0,"name":"Commander","token":"1".repeat(48)});
    assert!(Admission::decode(&json!([player.clone(), player])).is_err());
}
#[test]
#[ignore = "requires a Godot executable in FRONTLINE_GODOT"]
fn godot_connects_to_the_rust_socket_and_its_commands_replay() {
    let godot = std::env::var_os("FRONTLINE_GODOT").expect("set FRONTLINE_GODOT");
    let root = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../..");
    let mut server = Server::new();
    let output = std::process::Command::new(godot)
        .args([
            "--headless",
            "--max-fps",
            "120",
            "--quit-after",
            "2400",
            "--path",
        ])
        .arg(&root)
        .args(["res://tests/fixtures/rust-socket.tscn", "--"])
        .arg(format!("--socket-ready={}", server.ready.display()))
        .output()
        .unwrap();
    let text = format!(
        "{}{}",
        String::from_utf8_lossy(&output.stdout),
        String::from_utf8_lossy(&output.stderr)
    );
    assert!(
        output.status.success() && text.contains("RUST_SOCKET passed") && !text.contains("ERROR"),
        "{text}"
    );
    let verified = server.finish();
    assert!(verified.frames >= 32);
    let bytes = fs::read(&server.replay).unwrap();
    assert!(bytes
        .windows(b"Socket command from Godot".len())
        .any(|b| b == b"Socket command from Godot"));
}
