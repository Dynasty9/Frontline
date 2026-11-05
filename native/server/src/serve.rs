//! Socket scheduling and render projection stay outside deterministic gameplay.
use crate::network::{self as net, Admission, Incoming, Network};
use frontline_runtime::protocol;
use frontline_runtime::{
    content::Content,
    observation::{events::Events, Update, View},
    render::{publications, Publication},
    session::Session,
    simulation::{Input, Simulation},
};
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
                    .filter(|n| *n > 0 && *n <= frontline_runtime::replay::MAX_REPLAY_TICKS)
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
                    .filter(|n| *n <= frontline_runtime::replay::MAX_REPLAY_TICKS)
                    .ok_or("invalid replay seek")?
            },
        })
    }
}
use frontline_runtime::render::{chunks, map, roads};
fn reliable(n: &mut Network, slot: usize, kind: u8, data: Vec<u8>) -> Result<(), String> {
    if data.len() + 16 > protocol::MAX_PACKET {
        return Err("outgoing packet exceeds limit".into());
    }
    if n.reliable(slot, kind, Arc::new(data)).is_err() {
        n.close(slot);
    }
    Ok(())
}
struct SocketOutput<'a> {
    flush: bool,
    network: &'a mut Network,
    slots: &'a [usize],
}
impl frontline_runtime::render::Output for SocketOutput<'_> {
    fn reliable(&mut self, kind: u8, data: Arc<Vec<u8>>) -> Result<(), String> {
        if data.len() + 16 > protocol::MAX_PACKET {
            return Err("outgoing packet exceeds limit".into());
        }
        for &slot in self.slots {
            if self.network.reliable(slot, kind, data.clone()).is_err() {
                self.network.close(slot);
            }
        }
        Ok(())
    }
    fn unreliable(&mut self, kind: u8, tick: u64, data: &[u8]) -> Result<(), String> {
        for &slot in self.slots {
            if self.flush || self.network.peer(slot).is_some_and(Admission::recorder) {
                // Final state must precede OVER; archive deltas must never be dropped.
                if self
                    .network
                    .reliable(slot, kind, Arc::new(data.to_vec()))
                    .is_err()
                {
                    self.network.close(slot);
                }
            } else if self.network.peer(slot).is_some()
                && self.network.unreliable(slot, kind, tick, data).is_err()
            {
                self.network.close(slot);
            }
        }
        Ok(())
    }
}
fn json_packet(n: &mut Network, slot: usize, kind: u8, data: Value) -> Result<(), String> {
    frontline_runtime::render::json(
        &mut SocketOutput {
            network: n,
            slots: &[slot],
            flush: false,
        },
        kind,
        data,
    )
}
fn report(s: &Simulation, c: &Content, team: i8, broadcast: &str) -> Result<Value, String> {
    let mut result = frontline_runtime::observation::report(s, c, team)?;
    if !broadcast.is_empty() {
        result["replay"] = Value::String(broadcast.into());
    }
    Ok(result)
}
fn publish(
    n: &mut Network,
    slots: &[usize],
    u: &Update,
    tick: u64,
    flush: bool,
) -> Result<(), String> {
    frontline_runtime::render::update(
        &mut SocketOutput {
            network: n,
            slots,
            flush,
        },
        u,
        tick,
    )
}
fn publish_events(
    n: &mut Network,
    slots: &BTreeMap<usize, i8>,
    events: &Events,
    tick: u64,
    flush: bool,
) -> Result<(), String> {
    for (&slot, &team) in slots {
        let Some(peer) = n.peer(slot).map(|a| a.peer) else {
            continue;
        };
        frontline_runtime::render::events(
            &mut SocketOutput {
                network: n,
                slots: &[slot],
                flush,
            },
            peer,
            team,
            events,
            tick,
        )?;
    }
    Ok(())
}

type Timeline = Session<BufReader<File>, BufWriter<File>>;

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
    let mut timeline = Timeline::play(BufReader::new(source), content)?;
    let target = timeline.seek_target(config.seek)?;
    let mut control_at = Instant::now() - Duration::from_millis(100);
    let mut lease_seen = Instant::now();
    let mut lease_value = Vec::new();
    // Seeking re-executes inputs; a visual snapshot must never substitute for simulation state.
    while timeline.simulation().state.tick < target {
        if control_at.elapsed() >= Duration::from_millis(100) {
            control_at = Instant::now();
            if config.stop.as_ref().is_some_and(|p| p.exists())
                || !lease_alive(&config.lease, &mut lease_seen, &mut lease_value)
            {
                return Ok(());
            }
        }
        if timeline.step(content, &[])?.is_none() {
            return Err("replay ended before seek position".into());
        }
    }
    if timeline.at_end() && timeline.step(content, &[])?.is_some() {
        return Err("replay duration differs".into());
    }
    run_timeline(content, config, timeline)
}
pub fn run(
    simulation: Simulation,
    content: &Content,
    config: Config,
    output: File,
) -> Result<(), String> {
    let timeline = Timeline::record(BufWriter::new(output), simulation, content)?;
    run_timeline(content, config, timeline)
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
fn run_timeline(content: &Content, config: Config, mut timeline: Timeline) -> Result<(), String> {
    if !timeline.is_replay() {
        validate_admissions(timeline.simulation(), &config.admissions)?;
    }
    let mut admission_bytes = Vec::new();
    let absent = timeline
        .simulation()
        .state
        .owners
        .players
        .iter()
        .filter(|p| p.0 > 0 && !config.admissions.iter().any(|a| a.peer == p.0))
        .map(|p| Input::Leave { peer: p.0 })
        .collect::<VecDeque<_>>();
    let mut network = Network::bind(config.bind, config.admissions)?;
    let mut profile = config.profile;
    timeline.enable_profiling(profile.is_some());
    let public_map = chunks(&map(timeline.simulation())?);
    let mut surface = frontline_runtime::terrain_view::Surface::default();
    let mut road_state = timeline.simulation().state.rules.network.roads.clone();
    let presentation: Value =
        serde_json::from_slice(&timeline.simulation().presentation).map_err(|e| e.to_string())?;
    let ready = json!({"address":network.address()?.to_string(),"engine":frontline_runtime::ENGINE_ID,"version":protocol::VERSION,
        "side":timeline.simulation().state.water.side,"mood":presentation.get("mood"),"replay":timeline.status()});
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
    let mut broadcast = String::new();
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
                    let id = data["broadcast"].as_str().unwrap_or("");
                    if !id.is_empty()
                        && (id.len() != 24 || !id.bytes().all(|b| b.is_ascii_hexdigit()))
                    {
                        return Err("invalid public broadcast identifier".into());
                    }
                    broadcast = id.into();
                    let players = Admission::decode(&data["players"])?;
                    if !timeline.is_replay() {
                        validate_admissions(timeline.simulation(), &players)?;
                        for &(peer, _) in &timeline.simulation().state.owners.players {
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
                                .unreliable(
                                    target,
                                    protocol::PRESENCE,
                                    timeline.simulation().state.tick,
                                    &bytes,
                                )
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
                    let (kind, message) = frontline_runtime::co_command::project(
                        timeline.simulation(),
                        peer,
                        team,
                        &data,
                    );
                    for (&target, &side) in &slots {
                        if target != slot && (side < 0 || side == team) {
                            json_packet(&mut network, target, kind, message.clone())?;
                        }
                    }
                }
                Incoming::Report { slot } => {
                    if let Some(&team) = slots.get(&slot) {
                        let team = if timeline.simulation().state.victory.winner >= 0 {
                            -1
                        } else {
                            team
                        };
                        json_packet(
                            &mut network,
                            slot,
                            protocol::REPORT,
                            report(timeline.simulation(), content, team, &broadcast)?,
                        )?;
                    }
                }
                Incoming::Joined { slot, admission: a } => {
                    last_client = Instant::now();
                    let exists = timeline
                        .simulation()
                        .state
                        .owners
                        .players
                        .iter()
                        .any(|p| p.0 == a.peer)
                        && !pending
                            .iter()
                            .any(|i| matches!(i,Input::Leave{peer} if *peer==a.peer));
                    if !exists && !timeline.is_replay() && !a.recorder() {
                        let reclaim = a.reclaim.or_else(|| {
                            (timeline
                                .simulation()
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
                    let baseline = view.update(timeline.simulation(), content);
                    // Late joiners get their own baseline without resetting the team's deltas.
                    views.entry(a.team).or_insert(view);
                    json_packet(
                        &mut network,
                        slot,
                        protocol::WELCOME,
                        json!({"peer":a.peer,"team":a.team,"entities":baseline.births.len(),"side":timeline.simulation().state.water.side,"tick":timeline.simulation().state.tick,"engine":frontline_runtime::ENGINE_ID}),
                    )?;
                    for data in &public_map {
                        if network.reliable(slot, protocol::MAP, data.clone()).is_err() {
                            network.close(slot);
                            break;
                        }
                    }
                    for data in surface.tiles.values() {
                        if network
                            .reliable(slot, protocol::SURFACE, data.clone())
                            .is_err()
                        {
                            network.close(slot);
                            break;
                        }
                    }
                    json_packet(
                        &mut network,
                        slot,
                        protocol::ROADS,
                        roads(timeline.simulation()),
                    )?;
                    publish(
                        &mut network,
                        &[slot],
                        &baseline,
                        timeline.simulation().state.tick,
                        false,
                    )?;
                    reliable(&mut network, slot, protocol::BASELINE_END, vec![])?;
                    json_packet(
                        &mut network,
                        slot,
                        protocol::HUD,
                        frontline_runtime::observation::hud(
                            timeline.simulation(),
                            content,
                            a.team,
                        )?,
                    )?;
                    if timeline.is_replay() {
                        json_packet(&mut network, slot, protocol::PLAYBACK, timeline.status())?;
                    }
                    if timeline.simulation().state.victory.winner >= 0 {
                        json_packet(
                            &mut network,
                            slot,
                            protocol::REPORT,
                            report(timeline.simulation(), content, -1, &broadcast)?,
                        )?;
                        json_packet(
                            &mut network,
                            slot,
                            protocol::OVER,
                            json!(timeline.simulation().state.victory.winner),
                        )?;
                    }
                }
                Incoming::Left { slot, peer } => {
                    slots.remove(&slot);
                    views.retain(|team, _| slots.values().any(|side| side == team));
                    if !timeline.is_replay() && peer != net::RECORDER_PEER {
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
                            protocol::FX,
                            frontline_runtime::observation::events::Events::persistent(
                                timeline.simulation(),
                            ),
                        )?;
                        if network.peer(slot).is_some_and(|a| !a.recorder()) {
                            start = true;
                            if let Some(p) = &mut profile {
                                p.start();
                            }
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
            for input in pending
                .iter()
                .take(frontline_runtime::simulation::MAX_FRAME_INPUTS)
            {
                bytes += input.encode()?.len();
                if bytes > frontline_runtime::simulation::MAX_FRAME_BYTES {
                    break;
                }
                count += 1;
            }
            let inputs: Vec<_> = pending.drain(..count).collect();
            let winner = timeline.simulation().state.victory.winner;
            let frame = timeline.step(content, &inputs)?;
            let finished = frame.is_none();
            let simulation_ms = tick_started.elapsed().as_secs_f64() * 1000.;
            if let Some(frame) = frame {
                let events = Events::collect(timeline.simulation(), &frame);
                for data in surface.update(
                    &timeline.simulation().state.field.geometry.terrain,
                    &events.blasts,
                )? {
                    for &slot in slots.keys() {
                        if network
                            .reliable(slot, protocol::SURFACE, data.clone())
                            .is_err()
                        {
                            network.close(slot);
                        }
                    }
                }
                if road_state != timeline.simulation().state.rules.network.roads {
                    road_state.clone_from(&timeline.simulation().state.rules.network.roads);
                    for &slot in slots.keys() {
                        json_packet(
                            &mut network,
                            slot,
                            protocol::ROADS,
                            roads(timeline.simulation()),
                        )?;
                    }
                }
                render_events.push(events);
                next += Duration::from_secs_f64(frontline_core::match_state::FIXED_DELTA / speed);
            }
            let concluded = timeline.simulation().state.victory.winner != winner;
            for publication in publications(timeline.simulation().state.tick, concluded, finished) {
                match publication {
                    Publication::Snapshot => {
                        for (&team, view) in &mut views {
                            let recipients: Vec<_> = slots
                                .iter()
                                .filter_map(|(&slot, &side)| (side == team).then_some(slot))
                                .collect();
                            publish(
                                &mut network,
                                &recipients,
                                &view.update(timeline.simulation(), content),
                                timeline.simulation().state.tick,
                                concluded || finished,
                            )?;
                        }
                    }
                    Publication::Effects => {
                        for events in render_events.drain(..) {
                            publish_events(
                                &mut network,
                                &slots,
                                &events,
                                timeline.simulation().state.tick,
                                concluded || finished,
                            )?;
                        }
                    }
                    Publication::Hud => {
                        for team in [-1, 0, 1]
                            .into_iter()
                            .filter(|team| slots.values().any(|t| t == team))
                        {
                            let info = frontline_runtime::observation::hud(
                                timeline.simulation(),
                                content,
                                team,
                            )?;
                            for (&slot, &side) in &slots {
                                if side == team {
                                    json_packet(&mut network, slot, protocol::HUD, info.clone())?;
                                }
                            }
                        }
                        if timeline.is_replay() {
                            for &slot in slots.keys() {
                                json_packet(
                                    &mut network,
                                    slot,
                                    protocol::PLAYBACK,
                                    timeline.status(),
                                )?;
                            }
                        }
                    }
                    Publication::Report => {
                        for &slot in slots.keys() {
                            json_packet(
                                &mut network,
                                slot,
                                protocol::REPORT,
                                report(timeline.simulation(), content, -1, &broadcast)?,
                            )?;
                        }
                    }
                    Publication::Over => {
                        for &slot in slots.keys() {
                            json_packet(
                                &mut network,
                                slot,
                                protocol::OVER,
                                json!(timeline.simulation().state.victory.winner),
                            )?;
                        }
                    }
                }
            }
            if finished {
                break;
            }
            if let Some(p) = &mut profile {
                if p.record(tick_started, simulation_ms, timeline.simulation())? {
                    profile = None;
                }
            }
            if config
                .max_ticks
                .is_some_and(|n| timeline.simulation().state.tick >= n)
            {
                break;
            }
        }
        if next.elapsed() > Duration::from_millis(250) {
            next = Instant::now();
        }
        if !slots.is_empty() {
            last_client = Instant::now();
        }
        if config
            .max_ticks
            .is_some_and(|n| timeline.simulation().state.tick >= n)
            || config.stop.as_ref().is_some_and(|p| p.exists())
            || (!start && created.elapsed() > Duration::from_secs(600))
            || (start && last_client.elapsed() > Duration::from_secs(600))
        {
            break;
        }
        std::thread::sleep(Duration::from_millis(1));
    }
    let tick = timeline.simulation().state.tick;
    let winner = timeline.simulation().state.victory.winner;
    if let Some(mut output) = timeline.finish()? {
        output.flush().map_err(|e| e.to_string())?;
        output.get_ref().sync_all().map_err(|e| e.to_string())?;
    }
    for _ in 0..50 {
        network.poll()?;
        std::thread::sleep(Duration::from_millis(2));
    }
    println!("SIMULATION_STOPPED ticks={} winner={}", tick, winner);
    Ok(())
}
