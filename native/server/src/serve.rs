//! Socket scheduling and render projection stay outside deterministic gameplay.
use crate::{
    content::Content,
    network::{self as net, Admission, Incoming, Network},
    observation::{
        events::{self, Events},
        Update, View,
    },
    replay::{Playback, Recorder},
    simulation::{Input, Simulation},
};
use frontline_core::{state_codec::Writer, vector::Vector3};
use serde_json::{json, Value};
use std::{
    collections::{BTreeMap, VecDeque},
    fs::File,
    io::{BufReader, BufWriter, Read, Write},
    net::SocketAddr,
    path::PathBuf,
    sync::Arc,
    time::{Duration, Instant},
};

pub struct Config {
    pub bind: SocketAddr,
    pub admissions: Vec<Admission>,
    pub admission_file: Option<PathBuf>,
    pub max_ticks: Option<u64>,
    pub ready: Option<PathBuf>,
    pub stop: Option<PathBuf>,
    pub speed: Option<PathBuf>,
    pub error: Option<PathBuf>,
    pub lease: Option<PathBuf>,
    pub profile: Option<crate::profiling::Profile>,
    pub seek: u64,
}
impl Config {
    pub fn decode(bytes: &[u8]) -> Result<Self, String> {
        if bytes.len() > 64 * 1024 {
            return Err("server configuration exceeds limit".into());
        }
        let d: Value = serde_json::from_slice(bytes).map_err(|e| e.to_string())?;
        let bind = d["bind"]
            .as_str()
            .ok_or("missing bind address")?
            .parse()
            .map_err(|_| "invalid bind address")?;
        let admissions = Admission::decode(&d["players"])?;
        let max_ticks = if d["ticks"].is_null() {
            None
        } else {
            Some(
                d["ticks"]
                    .as_u64()
                    .filter(|n| *n > 0 && *n <= crate::replay::MAX_REPLAY_TICKS)
                    .ok_or("invalid tick limit")?,
            )
        };
        let path = |key: &str| -> Result<Option<PathBuf>, String> {
            if d[key].is_null() {
                Ok(None)
            } else {
                d[key]
                    .as_str()
                    .filter(|s| !s.is_empty() && !s.contains('\0'))
                    .map(|s| Some(PathBuf::from(s)))
                    .ok_or_else(|| format!("invalid {key} path"))
            }
        };
        Ok(Self {
            bind,
            admissions,
            admission_file: path("admissions")?,
            max_ticks,
            ready: path("ready")?,
            stop: path("stop")?,
            speed: path("speed")?,
            error: path("error")?,
            lease: path("lease")?,
            profile: crate::profiling::Profile::decode(&d["profile"])?,
            seek: if d["seek"].is_null() {
                0
            } else {
                d["seek"]
                    .as_u64()
                    .filter(|n| *n <= crate::replay::MAX_REPLAY_TICKS)
                    .ok_or("invalid replay seek")?
            },
        })
    }
}
fn point(p: Vector3) -> Value {
    json!(p.to_array())
}
fn roads(s: &Simulation) -> Value {
    json!(s
        .state
        .rules
        .network
        .roads
        .iter()
        .map(|r| r
            .iter()
            .map(|p| p.iter().copied().map(point).collect::<Vec<_>>())
            .collect::<Vec<_>>())
        .collect::<Vec<_>>())
}
pub fn map(s: &Simulation) -> Result<Vec<u8>, String> {
    let water = &s.state.water;
    let presentation: Value = serde_json::from_slice(&s.presentation).map_err(|e| e.to_string())?;
    let coast = water
        .coast
        .map_or(json!({}), |c| json!({"x":c[0],"s":c[1]}));
    let data = json!({"side":water.side,"water":{"coast":coast,
        "rivers":water.rivers.iter().map(|r|json!({"pts":r.points.iter().copied().map(point).collect::<Vec<_>>(),"w":r.width})).collect::<Vec<_>>(),
        "ponds":water.ponds.iter().map(|p|json!({"c":point(p.center),"r":p.radius,"s":p.seed})).collect::<Vec<_>>(),
        "fords":water.fords.iter().copied().map(point).collect::<Vec<_>>(),
        "bridges":water.bridges.iter().map(|b|json!([point(b.a),point(b.b),b.half_width,if b.quay {"quay"} else {"bridge"}])).collect::<Vec<_>>()},
        "roads":roads(s),
        "town":s.state.field.town,"decor":presentation.get("decor").cloned().unwrap_or(json!([])),"mood":presentation.get("mood")});
    let terrain = &s.state.field.geometry.terrain;
    let mut w = Writer::new(b"FLVM\x02\0\0\0");
    w.bytes(&serde_json::to_vec(&data).map_err(|e| e.to_string())?);
    w.bytes(&terrain.layers[frontline_core::terrain::BASE]);
    w.u32((terrain.landform.samples().len() * 4) as u32);
    for &height in terrain.landform.samples() {
        w.f32(height);
    }
    w.bytes(&crate::compression::encode(&crate::terrain_view::heights(
        terrain,
    ))?);
    w.bytes(&crate::compression::encode(
        &terrain.layers[frontline_core::terrain::CRATER],
    )?);
    Ok(w.0)
}
fn chunks(data: &[u8]) -> Vec<Arc<Vec<u8>>> {
    data.chunks(48 * 1024)
        .enumerate()
        .map(|(i, part)| {
            let mut out = Vec::with_capacity(8 + part.len());
            out.extend_from_slice(&(data.len() as u32).to_le_bytes());
            out.extend_from_slice(&((i * 48 * 1024) as u32).to_le_bytes());
            out.extend_from_slice(part);
            Arc::new(out)
        })
        .collect()
}
fn reliable(n: &mut Network, slot: usize, kind: u8, data: Vec<u8>) -> Result<(), String> {
    if data.len() + 16 > net::MAX_PACKET {
        return Err("outgoing packet exceeds limit".into());
    }
    if n.reliable(slot, kind, Arc::new(data)).is_err() {
        n.close(slot);
    }
    Ok(())
}
fn json_packet(n: &mut Network, slot: usize, kind: u8, data: Value) -> Result<(), String> {
    let data = serde_json::to_vec(&data).map_err(|e| e.to_string())?;
    if data.len() <= 48 * 1024 {
        return reliable(n, slot, kind, data);
    }
    if data.len() > 16 * 1024 * 1024 {
        return Err("render document exceeds limit".into());
    }
    for (i, part) in data.chunks(48 * 1024).enumerate() {
        let mut packet = vec![kind];
        packet.extend_from_slice(&(data.len() as u32).to_le_bytes());
        packet.extend_from_slice(&((i * 48 * 1024) as u32).to_le_bytes());
        packet.extend_from_slice(part);
        reliable(n, slot, net::BLOB, packet)?;
    }
    Ok(())
}
pub fn publish(n: &mut Network, slots: &[usize], u: &Update, tick: u64) -> Result<(), String> {
    let mut packets = vec![];
    // Each spawn is bounded independently, so a large map cannot create an ENet mega-packet.
    for b in &u.births {
        let mut w = Writer::new(b"FLOB\x01\0\0\0");
        w.u32(b.id);
        w.byte(b.kind);
        w.bytes(&serde_json::to_vec(&b.props).map_err(|e| e.to_string())?);
        w.bytes(&b.state);
        packets.push((net::SPAWN, Arc::new(w.0)));
    }
    for (id, p) in &u.properties {
        packets.push((
            net::PROPS,
            Arc::new(serde_json::to_vec(&json!([id, p])).map_err(|e| e.to_string())?),
        ));
    }
    for ids in u.despawns.chunks(4096) {
        packets.push((
            net::DESPAWN,
            Arc::new(ids.iter().flat_map(|id| id.to_le_bytes()).collect()),
        ));
    }
    for &slot in slots {
        for (kind, data) in &packets {
            if n.reliable(slot, *kind, data.clone()).is_err() {
                n.close(slot);
                break;
            }
        }
        if n.peer(slot).is_some() {
            for data in &u.snapshots {
                if n.unreliable(slot, net::SNAPSHOT, tick, data).is_err() {
                    n.close(slot);
                    break;
                }
            }
        }
    }
    Ok(())
}
fn publish_events(
    n: &mut Network,
    slots: &BTreeMap<usize, i8>,
    events: &Events,
    tick: u64,
) -> Result<(), String> {
    for (&slot, &team) in slots {
        let Some(peer) = n.peer(slot).map(|a| a.peer) else {
            continue;
        };
        let visible = |mask: u8| team < 0 || mask & (1 << team) != 0;
        for (id, mask, props) in &events.properties {
            if visible(*mask) {
                json_packet(n, slot, net::PROPS, json!([id, props]))?;
            }
        }
        let mut batch = Vec::new();
        let mut bytes = 2;
        for e in &events.effects {
            if !visible(e.mask) {
                continue;
            }
            if e.reliable {
                json_packet(n, slot, net::FX, json!([e.data]))?;
                continue;
            }
            let encoded = serde_json::to_vec(&e.data).map_err(|e| e.to_string())?;
            if bytes + encoded.len() + 1 > 1100 && !batch.is_empty() {
                if n.unreliable(
                    slot,
                    net::FX,
                    tick,
                    &serde_json::to_vec(&batch).map_err(|e| e.to_string())?,
                )
                .is_err()
                {
                    n.close(slot);
                    break;
                }
                batch.clear();
                bytes = 2;
            }
            if encoded.len() + 2 > 1100 {
                json_packet(n, slot, net::FX, json!([e.data]))?;
            } else {
                bytes += encoded.len() + 1;
                batch.push(&e.data);
            }
        }
        if !batch.is_empty()
            && n.unreliable(
                slot,
                net::FX,
                tick,
                &serde_json::to_vec(&batch).map_err(|e| e.to_string())?,
            )
            .is_err()
        {
            n.close(slot);
        }
        for m in &events.messages {
            if events::admits(m.audience, peer, team) {
                json_packet(n, slot, net::MESSAGE, m.data.clone())?;
            }
        }
        for (from, side, data) in &events.deeds {
            if peer != *from && (team < 0 || team == *side) {
                json_packet(n, slot, net::DEED, data.clone())?;
            }
        }
    }
    Ok(())
}
enum Timeline {
    Live(Recorder<BufWriter<File>>),
    Replay {
        playback: Playback<BufReader<File>>,
        end: u64,
    },
}
impl Timeline {
    fn is_replay(&self) -> bool {
        matches!(self, Self::Replay { .. })
    }
    fn complete(&self) -> bool {
        matches!(self,Self::Replay{playback,..} if playback.verified())
    }
    fn status(&self, s: &Simulation) -> Value {
        match self {
            Self::Live(_) => Value::Null,
            Self::Replay { playback, end } => {
                json!({"position":(s.state.tick-playback.initial_tick) as f64/60.,
                "duration":(end-playback.initial_tick) as f64/60.,"verified":playback.verified(),
                "concluded":playback.verified() && s.state.victory.winner>=0})
            }
        }
    }
    fn step(
        &mut self,
        s: &mut Simulation,
        c: &Content,
        inputs: &[Input],
    ) -> Result<Option<crate::simulation::Frame>, String> {
        match self {
            Self::Live(recording) => recording.step(s, c, inputs).map(Some),
            Self::Replay { playback, end } => {
                let frame = playback.step(s, c)?;
                if s.state.tick > *end || (frame.is_none() && s.state.tick != *end) {
                    return Err("replay duration differs".into());
                }
                Ok(frame)
            }
        }
    }
}
fn lease_alive(path: &Option<PathBuf>, seen: &mut Instant, previous: &mut Vec<u8>) -> bool {
    let Some(path) = path else { return true };
    if std::fs::metadata(path).is_ok_and(|m| m.len() <= 1024) {
        if let Ok(value) = std::fs::read(path) {
            if !value.is_empty() && value != *previous {
                *previous = value;
                *seen = Instant::now();
            }
        }
    }
    seen.elapsed() <= Duration::from_secs(30)
}
#[test]
fn lease_requires_changing_heartbeat_and_expires_without_one() {
    let path = std::env::temp_dir().join(format!("frontline-lease-{}", std::process::id()));
    std::fs::write(&path, b"first").unwrap();
    let mut seen = Instant::now() - Duration::from_secs(31);
    let mut previous = Vec::new();
    assert!(lease_alive(&Some(path.clone()), &mut seen, &mut previous));
    seen = Instant::now() - Duration::from_secs(31);
    assert!(!lease_alive(&Some(path.clone()), &mut seen, &mut previous));
    std::fs::write(&path, b"second").unwrap();
    assert!(lease_alive(&Some(path.clone()), &mut seen, &mut previous));
    std::fs::remove_file(&path).unwrap();
    seen = Instant::now() - Duration::from_secs(31);
    assert!(!lease_alive(&Some(path), &mut seen, &mut previous));
    assert!(lease_alive(&None, &mut seen, &mut previous));
}
pub fn playback(source: File, content: &Content, config: Config) -> Result<(), String> {
    if config.admissions.iter().any(|a| a.team != -1) {
        return Err("replay clients must be observers".into());
    }
    let mut source = BufReader::new(source);
    let end = crate::replay::declared_tick(&mut source)?;
    let (mut playback, mut simulation) = Playback::new(source, content)?;
    if end < playback.initial_tick || end - playback.initial_tick > crate::replay::MAX_REPLAY_TICKS
    {
        return Err("invalid replay duration".into());
    }
    let target = playback.initial_tick.saturating_add(config.seek).min(end);
    let mut control_at = Instant::now() - Duration::from_millis(100);
    let mut lease_seen = Instant::now();
    let mut lease_value = Vec::new();
    // Seeking re-executes inputs; a visual snapshot must never substitute for simulation state.
    while simulation.state.tick < target {
        if control_at.elapsed() >= Duration::from_millis(100) {
            control_at = Instant::now();
            if config.stop.as_ref().is_some_and(|p| p.exists())
                || !lease_alive(&config.lease, &mut lease_seen, &mut lease_value)
            {
                return Ok(());
            }
        }
        if playback.step(&mut simulation, content)?.is_none() {
            return Err("replay ended before seek position".into());
        }
    }
    if target == end && playback.step(&mut simulation, content)?.is_some() {
        return Err("replay duration differs".into());
    }
    run_timeline(
        simulation,
        content,
        config,
        Timeline::Replay { playback, end },
    )
}
pub fn run(
    simulation: Simulation,
    content: &Content,
    config: Config,
    output: File,
) -> Result<(), String> {
    let recording = Recorder::new(BufWriter::new(output), &simulation, content)?;
    run_timeline(simulation, content, config, Timeline::Live(recording))
}
fn validate_admissions(simulation: &Simulation, players: &[Admission]) -> Result<(), String> {
    for a in players {
        if simulation
            .state
            .owners
            .players
            .iter()
            .any(|p| p.0 == a.peer && p.1 != a.team)
            || simulation
                .mission
                .as_ref()
                .is_some_and(|m| a.team >= 0 && a.team != m.side)
        {
            return Err("admission disagrees with battlefield ownership".into());
        }
    }
    Ok(())
}
fn run_timeline(
    mut simulation: Simulation,
    content: &Content,
    config: Config,
    mut timeline: Timeline,
) -> Result<(), String> {
    if !timeline.is_replay() {
        validate_admissions(&simulation, &config.admissions)?;
    }
    let mut admission_bytes = Vec::new();
    let absent = simulation
        .state
        .owners
        .players
        .iter()
        .filter(|p| p.0 > 0 && !config.admissions.iter().any(|a| a.peer == p.0))
        .map(|p| Input::Leave { peer: p.0 })
        .collect::<VecDeque<_>>();
    let mut network = Network::bind(config.bind, config.admissions)?;
    let mut profile = config.profile;
    simulation.profile = profile.as_ref().map(|_| Default::default());
    let public_map = chunks(&map(&simulation)?);
    let mut surface = crate::terrain_view::Surface::default();
    let mut road_state = simulation.state.rules.network.roads.clone();
    let presentation: Value =
        serde_json::from_slice(&simulation.presentation).map_err(|e| e.to_string())?;
    let ready = json!({"address":network.address()?.to_string(),"engine":crate::ENGINE_ID,"version":net::VERSION,
        "side":simulation.state.water.side,"mood":presentation.get("mood"),"replay":timeline.status(&simulation)});
    if let Some(path) = &config.ready {
        let mut f = File::options()
            .write(true)
            .create_new(true)
            .open(path)
            .map_err(|e| e.to_string())?;
        f.write_all(ready.to_string().as_bytes())
            .map_err(|e| e.to_string())?;
    }
    println!("SIMULATION_LISTENING {ready}");
    let mut slots = BTreeMap::<usize, i8>::new();
    let mut views = BTreeMap::<i8, View>::new();
    let mut pending = if timeline.is_replay() {
        VecDeque::new()
    } else {
        absent
    };
    let mut render_events = Vec::with_capacity(4);
    let mut start = false;
    let mut next = Instant::now();
    let created = next;
    let mut last_client = next;
    let mut last_winner = -1;
    let mut speed = 1.0;
    let mut control_at = Instant::now() - Duration::from_millis(100);
    let mut lease_seen = Instant::now();
    let mut lease_value = Vec::new();
    loop {
        if control_at.elapsed() >= Duration::from_millis(100) {
            control_at = Instant::now();
            if !lease_alive(&config.lease, &mut lease_seen, &mut lease_value) {
                break;
            }
            if let Some(path) = config.admission_file.as_ref().filter(|p| p.exists()) {
                let mut bytes = Vec::new();
                File::open(path)
                    .map_err(|e| e.to_string())?
                    .take(64 * 1024 + 1)
                    .read_to_end(&mut bytes)
                    .map_err(|e| e.to_string())?;
                if bytes.len() > 64 * 1024 {
                    return Err("admission update exceeds limit".into());
                }
                if bytes != admission_bytes {
                    let data: Value = serde_json::from_slice(&bytes).map_err(|e| e.to_string())?;
                    let players = Admission::decode(&data["players"])?;
                    if !timeline.is_replay() {
                        validate_admissions(&simulation, &players)?;
                        for &(peer, _) in &simulation.state.owners.players {
                            if peer > 0 && !players.iter().any(|a| a.peer == peer) {
                                pending.push_back(Input::Leave { peer });
                            }
                        }
                    }
                    network.replace_admissions(players)?;
                    let applied = path.with_extension("admitted");
                    let temporary = path.with_extension("admitted.tmp");
                    std::fs::write(&temporary, json!({"revision":data["revision"]}).to_string())
                        .map_err(|e| e.to_string())?;
                    std::fs::rename(temporary, applied).map_err(|e| e.to_string())?;
                    admission_bytes = bytes;
                }
            }
            if let Some(path) = config.speed.as_ref().filter(|p| p.exists()) {
                if std::fs::metadata(path).is_ok_and(|m| m.len() <= 1024) {
                    if let Ok(bytes) = std::fs::read(path) {
                        if let Ok(d) = serde_json::from_slice::<Value>(&bytes) {
                            if let Some(value) = d["speed"]
                                .as_f64()
                                .filter(|v| v.is_finite() && (0.0..=4.0).contains(v))
                            {
                                speed = value;
                                next = Instant::now();
                            }
                        }
                    }
                }
                let _ = std::fs::remove_file(path);
            }
        }
        for event in network.poll()? {
            match event {
                Incoming::Presence { slot, data } => {
                    if timeline.is_replay() {
                        continue;
                    }
                    let Some(a) = network.peer(slot) else {
                        continue;
                    };
                    let (peer, team) = (a.peer, a.team);
                    let mut bytes = peer.to_le_bytes().to_vec();
                    bytes.extend_from_slice(&data);
                    for (&target, &side) in &slots {
                        if target != slot
                            && (side < 0 || side == team)
                            && network
                                .unreliable(target, net::PRESENCE, simulation.state.tick, &bytes)
                                .is_err()
                        {
                            network.close(target);
                        }
                    }
                }
                Incoming::Mark { slot, data } => {
                    if timeline.is_replay() {
                        continue;
                    }
                    let Some(a) = network.peer(slot) else {
                        continue;
                    };
                    let (peer, team) = (a.peer, a.team);
                    let (kind, message) =
                        crate::co_command::project(&simulation, peer, team, &data);
                    for (&target, &side) in &slots {
                        if target != slot && (side < 0 || side == team) {
                            json_packet(&mut network, target, kind, message.clone())?;
                        }
                    }
                }
                Incoming::Report { slot } => {
                    if let Some(&team) = slots.get(&slot) {
                        let team = if simulation.state.victory.winner >= 0 {
                            -1
                        } else {
                            team
                        };
                        json_packet(
                            &mut network,
                            slot,
                            net::REPORT,
                            crate::observation::report(&simulation, content, team)?,
                        )?;
                    }
                }
                Incoming::Joined { slot, admission: a } => {
                    last_client = Instant::now();
                    let exists = simulation
                        .state
                        .owners
                        .players
                        .iter()
                        .any(|p| p.0 == a.peer)
                        && !pending
                            .iter()
                            .any(|i| matches!(i,Input::Leave{peer} if *peer==a.peer));
                    if !exists && !timeline.is_replay() {
                        let reclaim = a.reclaim.or_else(|| {
                            (simulation
                                .state
                                .owners
                                .away
                                .iter()
                                .any(|old| old.peer == a.peer)
                                || pending
                                    .iter()
                                    .any(|i| matches!(i,Input::Leave{peer} if *peer==a.peer)))
                            .then_some(a.peer)
                        });
                        pending.push_back(Input::Join {
                            peer: a.peer,
                            team: a.team,
                            name: a.name,
                            reclaim,
                        });
                    }
                    slots.insert(slot, a.team);
                    let mut view = View::new(a.team)?;
                    let baseline = view.update(&simulation, content);
                    // Late joiners get their own baseline without resetting the team's deltas.
                    views.entry(a.team).or_insert(view);
                    json_packet(
                        &mut network,
                        slot,
                        net::WELCOME,
                        json!({"peer":a.peer,"team":a.team,"entities":baseline.births.len(),"side":simulation.state.water.side,"tick":simulation.state.tick,"engine":crate::ENGINE_ID}),
                    )?;
                    for data in &public_map {
                        if network.reliable(slot, net::MAP, data.clone()).is_err() {
                            network.close(slot);
                            break;
                        }
                    }
                    for data in surface.tiles.values() {
                        if network.reliable(slot, net::SURFACE, data.clone()).is_err() {
                            network.close(slot);
                            break;
                        }
                    }
                    json_packet(&mut network, slot, net::ROADS, roads(&simulation))?;
                    publish(&mut network, &[slot], &baseline, simulation.state.tick)?;
                    reliable(&mut network, slot, net::BASELINE_END, vec![])?;
                    json_packet(
                        &mut network,
                        slot,
                        net::HUD,
                        crate::observation::hud(&simulation, content, a.team)?,
                    )?;
                    if timeline.is_replay() {
                        json_packet(
                            &mut network,
                            slot,
                            net::PLAYBACK,
                            timeline.status(&simulation),
                        )?;
                    }
                    if simulation.state.victory.winner >= 0 {
                        json_packet(
                            &mut network,
                            slot,
                            net::REPORT,
                            crate::observation::report(&simulation, content, -1)?,
                        )?;
                        json_packet(
                            &mut network,
                            slot,
                            net::OVER,
                            json!(simulation.state.victory.winner),
                        )?;
                    }
                }
                Incoming::Left { slot, peer } => {
                    slots.remove(&slot);
                    views.retain(|team, _| slots.values().any(|side| side == team));
                    if !timeline.is_replay() {
                        pending.push_back(Input::Leave { peer });
                    }
                }
                Incoming::Command(input) => {
                    if timeline.is_replay() {
                        continue;
                    }
                    if pending.len() < 1024 {
                        pending.push_back(input);
                    } else if let Input::Command { peer, .. } = input {
                        for slot in slots.keys().copied().collect::<Vec<_>>() {
                            if network.peer(slot).is_some_and(|a| a.peer == peer) {
                                network.close(slot);
                            }
                        }
                    }
                }
                Incoming::Loaded { slot } => {
                    if slots.contains_key(&slot) {
                        // Effects sent with the baseline would be discarded under the loading screen.
                        json_packet(
                            &mut network,
                            slot,
                            net::FX,
                            crate::observation::events::Events::persistent(&simulation),
                        )?;
                        start = true;
                        if let Some(p) = &mut profile {
                            p.start();
                        }
                    }
                }
            }
        }
        if !start {
            next = Instant::now();
        }
        for _ in 0..4 {
            if !start || speed == 0.0 || timeline.complete() || Instant::now() < next {
                break;
            }
            let mut bytes = 0;
            let tick_started = Instant::now();
            let mut count = 0;
            for input in pending.iter().take(crate::simulation::MAX_FRAME_INPUTS) {
                bytes += input.encode()?.len();
                if bytes > crate::simulation::MAX_FRAME_BYTES {
                    break;
                }
                count += 1;
            }
            let inputs: Vec<_> = pending.drain(..count).collect();
            let Some(frame) = timeline.step(&mut simulation, content, &inputs)? else {
                // Flush the final partial snapshot group before declaring verification.
                for (&team, view) in &mut views {
                    let recipients: Vec<_> = slots
                        .iter()
                        .filter_map(|(&slot, &side)| (side == team).then_some(slot))
                        .collect();
                    publish(
                        &mut network,
                        &recipients,
                        &view.update(&simulation, content),
                        simulation.state.tick,
                    )?;
                }
                for &slot in slots.keys() {
                    json_packet(
                        &mut network,
                        slot,
                        net::HUD,
                        crate::observation::hud(&simulation, content, -1)?,
                    )?;
                    json_packet(
                        &mut network,
                        slot,
                        net::REPORT,
                        crate::observation::report(&simulation, content, -1)?,
                    )?;
                    json_packet(
                        &mut network,
                        slot,
                        net::PLAYBACK,
                        timeline.status(&simulation),
                    )?;
                }
                for events in render_events.drain(..) {
                    publish_events(&mut network, &slots, &events, simulation.state.tick)?;
                }
                break;
            };
            let simulation_ms = tick_started.elapsed().as_secs_f64() * 1000.;
            let events = Events::collect(&simulation, &frame);
            for data in surface.update(&simulation.state.field.geometry.terrain, &events.blasts)? {
                for &slot in slots.keys() {
                    if network.reliable(slot, net::SURFACE, data.clone()).is_err() {
                        network.close(slot);
                    }
                }
            }
            if road_state != simulation.state.rules.network.roads {
                road_state.clone_from(&simulation.state.rules.network.roads);
                for &slot in slots.keys() {
                    json_packet(&mut network, slot, net::ROADS, roads(&simulation))?;
                }
            }
            render_events.push(events);
            next += Duration::from_secs_f64(frontline_core::match_state::FIXED_DELTA / speed);
            if simulation.state.tick % 4 == 0 {
                for (&team, view) in &mut views {
                    let recipients: Vec<_> = slots
                        .iter()
                        .filter_map(|(&slot, &side)| (side == team).then_some(slot))
                        .collect();
                    publish(
                        &mut network,
                        &recipients,
                        &view.update(&simulation, content),
                        simulation.state.tick,
                    )?;
                }
                for events in render_events.drain(..) {
                    publish_events(&mut network, &slots, &events, simulation.state.tick)?;
                }
            }
            if simulation.state.tick % 30 == 0 {
                if timeline.is_replay() {
                    for &slot in slots.keys() {
                        json_packet(
                            &mut network,
                            slot,
                            net::PLAYBACK,
                            timeline.status(&simulation),
                        )?;
                    }
                }
                for team in [-1, 0, 1]
                    .into_iter()
                    .filter(|team| slots.values().any(|t| t == team))
                {
                    let info = crate::observation::hud(&simulation, content, team)?;
                    for (&slot, &side) in &slots {
                        if side == team {
                            json_packet(&mut network, slot, net::HUD, info.clone())?;
                        }
                    }
                }
            }
            if simulation.state.victory.winner != last_winner {
                last_winner = simulation.state.victory.winner;
                for &slot in slots.keys() {
                    json_packet(
                        &mut network,
                        slot,
                        net::REPORT,
                        crate::observation::report(&simulation, content, -1)?,
                    )?;
                    json_packet(&mut network, slot, net::OVER, json!(last_winner))?;
                }
            }
            if let Some(p) = &mut profile {
                if p.record(tick_started, simulation_ms, &simulation)? {
                    profile = None;
                }
            }
            if config.max_ticks.is_some_and(|n| simulation.state.tick >= n) {
                break;
            }
        }
        if next.elapsed() > Duration::from_millis(250) {
            next = Instant::now();
        }
        if !slots.is_empty() {
            last_client = Instant::now();
        }
        if config.max_ticks.is_some_and(|n| simulation.state.tick >= n)
            || config.stop.as_ref().is_some_and(|p| p.exists())
            || (!start && created.elapsed() > Duration::from_secs(600))
            || (start && last_client.elapsed() > Duration::from_secs(600))
        {
            break;
        }
        std::thread::sleep(Duration::from_millis(1));
    }
    if let Timeline::Live(recording) = timeline {
        let mut output = recording.finish(&simulation)?;
        output.flush().map_err(|e| e.to_string())?;
        output.get_ref().sync_all().map_err(|e| e.to_string())?;
    }
    for _ in 0..50 {
        network.poll()?;
        std::thread::sleep(Duration::from_millis(2));
    }
    println!(
        "SIMULATION_STOPPED ticks={} winner={}",
        simulation.state.tick, simulation.state.victory.winner
    );
    Ok(())
}
