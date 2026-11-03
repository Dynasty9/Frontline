//! ENet carries the same application packets for local and remote visual clients.
use crate::{client_command, simulation::Input};
use rusty_enet::{Event, Host, HostSettings, Packet, PeerID};
use serde_json::Value;
use std::{
    collections::VecDeque,
    net::{SocketAddr, UdpSocket},
    sync::Arc,
    time::{Duration, Instant},
};

pub const VERSION: u16 = 1;
pub const AUTH: u8 = 0;
pub const COMMAND: u8 = 1;
pub const LOADED: u8 = 2;
pub const ACK: u8 = 3;
pub const REQUEST_REPORT: u8 = 4;
pub const SNAPSHOT: u8 = 16;
pub const WELCOME: u8 = 17;
pub const SPAWN: u8 = 18;
pub const PROPS: u8 = 19;
pub const DESPAWN: u8 = 20;
pub const MAP: u8 = 21;
pub const BASELINE_END: u8 = 22;
pub const HUD: u8 = 23;
pub const FX: u8 = 24;
pub const MESSAGE: u8 = 25;
pub const OVER: u8 = 26;
pub const REPORT: u8 = 27;
pub const BLOB: u8 = 28;
pub const MAX_PACKET: usize = 64 * 1024 + 32;
const MAX_PENDING: usize = 128 * 1024 * 1024;
const WINDOW: usize = 512 * 1024;

pub fn packet(kind: u8, sequence: u64, data: &[u8]) -> Vec<u8> {
    let mut out = Vec::with_capacity(16 + data.len());
    out.extend_from_slice(b"FLNP");
    out.extend_from_slice(&VERSION.to_le_bytes());
    out.extend_from_slice(&[kind, 0]);
    out.extend_from_slice(&sequence.to_le_bytes());
    out.extend_from_slice(data);
    out
}
pub fn decode(data: &[u8]) -> Result<(u8, u64, &[u8]), &'static str> {
    if data.len() < 16
        || data.len() > MAX_PACKET
        || &data[..4] != b"FLNP"
        || u16::from_le_bytes(data[4..6].try_into().unwrap()) != VERSION
        || data[7] != 0
    {
        return Err("invalid network packet");
    }
    Ok((
        data[6],
        u64::from_le_bytes(data[8..16].try_into().unwrap()),
        &data[16..],
    ))
}

#[derive(Clone)]
pub struct Admission {
    pub token: String,
    pub peer: i32,
    pub team: i8,
    pub name: String,
    pub reclaim: Option<i32>,
}
impl Admission {
    pub fn valid(&self) -> bool {
        self.token.len() == 48
            && self.token.bytes().all(|b| b.is_ascii_hexdigit())
            && Input::Join {
                peer: self.peer,
                team: self.team,
                name: self.name.clone(),
                reclaim: self.reclaim,
            }
            .encode()
            .is_ok()
    }
}
pub enum Incoming {
    Joined { slot: usize, admission: Admission },
    Left { slot: usize, peer: i32 },
    Command(Input),
    Loaded { slot: usize },
    Report { slot: usize },
}
struct Pending {
    kind: u8,
    data: Arc<Vec<u8>>,
}
struct Connection {
    admission: Option<usize>,
    born: Instant,
    last_ack: Instant,
    window_at: Instant,
    received: usize,
    commands: usize,
    loaded: bool,
    report_at: Option<Instant>,
    sent: u64,
    acked: u64,
    pending_bytes: usize,
    pending: VecDeque<Pending>,
    in_flight: VecDeque<(u64, usize)>,
}
impl Connection {
    fn new() -> Self {
        let now = Instant::now();
        Self {
            admission: None,
            born: now,
            last_ack: now,
            window_at: now,
            received: 0,
            commands: 0,
            loaded: false,
            report_at: None,
            sent: 0,
            acked: 0,
            pending_bytes: 0,
            pending: VecDeque::new(),
            in_flight: VecDeque::new(),
        }
    }
}
pub struct Network {
    host: Host<UdpSocket>,
    admissions: Vec<Admission>,
    connections: Vec<Option<Connection>>,
    closed: Vec<Incoming>,
}
impl Network {
    pub fn bind(address: SocketAddr, admissions: Vec<Admission>) -> Result<Self, String> {
        if admissions.is_empty()
            || admissions.len() > 32
            || admissions.iter().any(|a| !a.valid())
            || admissions.iter().enumerate().any(|(i, a)| {
                admissions[..i]
                    .iter()
                    .any(|b| a.peer == b.peer || a.token == b.token)
            })
        {
            return Err("invalid connection admissions".into());
        }
        let epoch = Instant::now();
        let socket = UdpSocket::bind(address).map_err(|e| e.to_string())?;
        let host = Host::new(
            socket,
            HostSettings {
                peer_limit: 32,
                channel_limit: 3,
                time: Box::new(move || epoch.elapsed()),
                ..Default::default()
            },
        )
        .map_err(|e| e.to_string())?;
        Ok(Self {
            host,
            admissions,
            connections: (0..32).map(|_| None).collect(),
            closed: vec![],
        })
    }
    pub fn address(&self) -> Result<SocketAddr, String> {
        self.host.socket().local_addr().map_err(|e| e.to_string())
    }
    pub fn peer(&self, slot: usize) -> Option<&Admission> {
        self.connections
            .get(slot)?
            .as_ref()?
            .admission
            .map(|i| &self.admissions[i])
    }
    pub fn close(&mut self, slot: usize) {
        if let Some(c) = self.connections.get_mut(slot).and_then(Option::take) {
            if let Some(i) = c.admission {
                self.closed.push(Incoming::Left {
                    slot,
                    peer: self.admissions[i].peer,
                });
            }
            self.host.peer_mut(PeerID(slot)).disconnect_now(1);
        }
    }
    pub fn reliable(
        &mut self,
        slot: usize,
        kind: u8,
        data: Arc<Vec<u8>>,
    ) -> Result<(), &'static str> {
        if data.len() + 16 > MAX_PACKET {
            return Err("outgoing packet exceeds limit");
        }
        let c = self
            .connections
            .get_mut(slot)
            .and_then(Option::as_mut)
            .ok_or("disconnected recipient")?;
        if c.admission.is_none() || c.pending_bytes + data.len() > MAX_PENDING {
            return Err("recipient queue exceeds limit");
        }
        c.pending_bytes += data.len();
        c.pending.push_back(Pending { kind, data });
        Ok(())
    }
    pub fn unreliable(
        &mut self,
        slot: usize,
        kind: u8,
        tick: u64,
        data: &[u8],
    ) -> Result<(), String> {
        if self.peer(slot).is_none() || data.len() > 1100 {
            return Err("invalid observation packet".into());
        }
        self.host
            .peer_mut(PeerID(slot))
            .send(
                if kind == FX { 2 } else { 1 },
                &Packet::unreliable(packet(kind, tick, data)),
            )
            .map_err(|e| e.to_string())
    }
    pub fn poll(&mut self) -> Result<Vec<Incoming>, String> {
        let mut incoming = std::mem::take(&mut self.closed);
        // A chatty peer cannot monopolize the fixed-tick loop.
        for _ in 0..512 {
            let serviced = match self.host.service() {
                Ok(event) => event,
                // UDP ICMP errors report a vanished recipient, not a failed listening socket.
                Err(e)
                    if matches!(
                        e.kind(),
                        std::io::ErrorKind::ConnectionReset | std::io::ErrorKind::ConnectionRefused
                    ) =>
                {
                    continue
                }
                Err(e) => return Err(e.to_string()),
            };
            let Some(event) = serviced else {
                break;
            };
            match event {
                Event::Connect { peer, .. } => {
                    let slot = peer.id().0;
                    peer.set_timeout(32, 10_000, 30_000);
                    self.connections[slot] = Some(Connection::new());
                }
                Event::Disconnect { peer, .. } => {
                    let slot = peer.id().0;
                    if let Some(c) = self.connections[slot].take() {
                        if let Some(i) = c.admission {
                            incoming.push(Incoming::Left {
                                slot,
                                peer: self.admissions[i].peer,
                            });
                        }
                    }
                }
                Event::Receive {
                    peer,
                    channel_id,
                    packet: received,
                } => {
                    let slot = peer.id().0;
                    if channel_id != 0
                        || self.receive(slot, received.data(), &mut incoming).is_err()
                    {
                        self.close(slot);
                    }
                }
            }
        }
        for slot in 0..self.connections.len() {
            let Some(c) = self.connections[slot].as_mut() else {
                continue;
            };
            if (c.admission.is_none() && c.born.elapsed() > Duration::from_secs(5))
                || (!c.in_flight.is_empty() && c.last_ack.elapsed() > Duration::from_secs(30))
            {
                self.close(slot);
                continue;
            }
            let mut bytes: usize = c.in_flight.iter().map(|p| p.1).sum();
            while bytes < WINDOW {
                let Some(p) = c.pending.pop_front() else {
                    break;
                };
                c.pending_bytes -= p.data.len();
                c.sent += 1;
                if c.in_flight.is_empty() {
                    c.last_ack = Instant::now();
                }
                let wire = packet(p.kind, c.sent, &p.data);
                if self
                    .host
                    .peer_mut(PeerID(slot))
                    .send(0, &Packet::reliable(wire.as_slice()))
                    .is_err()
                {
                    self.close(slot);
                    break;
                }
                c.in_flight.push_back((c.sent, wire.len()));
                bytes += wire.len();
            }
        }
        self.host.flush();
        incoming.append(&mut self.closed);
        Ok(incoming)
    }
    fn receive(
        &mut self,
        slot: usize,
        data: &[u8],
        out: &mut Vec<Incoming>,
    ) -> Result<(), &'static str> {
        let (kind, sequence, payload) = decode(data)?;
        let c = self.connections[slot]
            .as_mut()
            .ok_or("unknown connection")?;
        if c.window_at.elapsed() >= Duration::from_secs(1) {
            c.window_at = Instant::now();
            c.received = 0;
            c.commands = 0;
        }
        c.received += data.len();
        if c.received > 1024 * 1024 {
            return Err("connection byte budget exceeded");
        }
        if kind == AUTH {
            if c.admission.is_some() || sequence != 0 || payload.len() > 512 {
                return Err("invalid authorization");
            }
            let value: Value =
                serde_json::from_slice(payload).map_err(|_| "invalid authorization")?;
            let token = value["token"].as_str().ok_or("missing admission token")?;
            if value["engine"].as_str() != Some(crate::ENGINE_ID) {
                return Err("incompatible simulation build");
            }
            let index = self
                .admissions
                .iter()
                .position(|a| a.token == token)
                .ok_or("unknown admission")?;
            if self
                .connections
                .iter()
                .flatten()
                .any(|c| c.admission == Some(index))
            {
                return Err("identity already connected");
            }
            self.connections[slot].as_mut().unwrap().admission = Some(index);
            out.push(Incoming::Joined {
                slot,
                admission: self.admissions[index].clone(),
            });
            return Ok(());
        }
        let index = c.admission.ok_or("unauthorized command")?;
        match kind {
            REQUEST_REPORT if payload.is_empty() && sequence == 0 => {
                if c.report_at
                    .is_some_and(|at| at.elapsed() < Duration::from_secs(1))
                {
                    return Ok(());
                }
                c.report_at = Some(Instant::now());
                out.push(Incoming::Report { slot });
            }
            ACK if payload.is_empty() && sequence >= c.acked && sequence <= c.sent => {
                if sequence > c.acked {
                    c.last_ack = Instant::now();
                }
                c.acked = sequence;
                while c.in_flight.front().is_some_and(|p| p.0 <= sequence) {
                    c.in_flight.pop_front();
                }
            }
            LOADED if payload.is_empty() && sequence == 0 => {
                if !c.loaded {
                    c.loaded = true;
                    out.push(Incoming::Loaded { slot });
                }
            }
            COMMAND if sequence == 0 => {
                c.commands += 1;
                if c.commands > 64 {
                    return Err("command rate exceeded");
                }
                let command = client_command::decode(payload)?;
                out.push(Incoming::Command(Input::Command {
                    peer: self.admissions[index].peer,
                    command,
                }));
            }
            _ => return Err("unexpected client message"),
        }
        Ok(())
    }
}
