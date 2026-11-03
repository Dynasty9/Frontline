use frontline_server::{
    co_command,
    content::Content,
    initial,
    observation::{self, events::Events, View},
    protocol as net,
    render::{self, Output},
    replay::{self, Playback, Recorder},
    simulation::{Input, Simulation, MAX_FRAME_BYTES, MAX_FRAME_INPUTS},
    terrain_view::Surface,
};
use serde_json::{json, Value};
use std::{collections::VecDeque, io::Cursor, sync::Arc};

#[derive(Default)]
struct Packets {
    sequence: u64,
    bytes: usize,
    pending: VecDeque<(u8, Vec<u8>)>,
}
impl Packets {
    fn push(&mut self, channel: u8, kind: u8, sequence: u64, data: &[u8]) -> Result<(), String> {
        if data.len() + 16 > net::MAX_PACKET || self.bytes + data.len() + 21 > 384 * 1024 * 1024 {
            return Err("Worker render queue exceeds limit".into());
        }
        let packet = net::packet(kind, sequence, data);
        self.bytes += packet.len() + 5;
        self.pending.push_back((channel, packet));
        Ok(())
    }
    fn take(&mut self) -> Vec<u8> {
        let mut out = Vec::new();
        while let Some((_, data)) = self.pending.front() {
            if out.len() + data.len() + 5 > 1024 * 1024 {
                break;
            }
            let (channel, data) = self.pending.pop_front().unwrap();
            out.extend_from_slice(&(data.len() as u32).to_le_bytes());
            out.push(channel);
            out.extend_from_slice(&data);
        }
        self.bytes -= out.len();
        out
    }
}
impl Output for Packets {
    fn reliable(&mut self, kind: u8, data: Arc<Vec<u8>>) -> Result<(), String> {
        self.sequence += 1;
        self.push(0, kind, self.sequence, &data)
    }
    fn unreliable(&mut self, kind: u8, tick: u64, data: &[u8]) -> Result<(), String> {
        self.push(if kind == net::FX { 2 } else { 1 }, kind, tick, data)
    }
}

pub struct Session {
    pub simulation: Simulation,
    content: Content,
    view: View,
    peer: i32,
    team: i8,
    recording: Option<Recorder<Vec<u8>>>,
    playback: Option<Playback<Cursor<Vec<u8>>>>,
    end: u64,
    packets: Packets,
    inputs: Vec<Input>,
    input_bytes: usize,
    effects: Vec<Events>,
    surface: Surface,
    roads: [Vec<Vec<frontline_core::vector::Vector3>>; 3],
    loaded: bool,
    opened: bool,
    finished: bool,
}
impl Session {
    pub fn new(bytes: Vec<u8>, replay: bool) -> Result<Self, String> {
        let content = Content::bundled()?;
        let (simulation, recording, playback, end) = if replay {
            let mut source = Cursor::new(bytes);
            let end = replay::declared_tick(&mut source)?;
            source.set_position(0);
            let (playback, simulation) = Playback::new(source, &content)?;
            if end < simulation.state.tick {
                return Err("Invalid replay duration".into());
            }
            (simulation, None, Some(playback), end)
        } else {
            let simulation = initial::load(&bytes, &content)?;
            let recording = Recorder::new(Vec::new(), &simulation, &content)?;
            (simulation, Some(recording), None, 0)
        };
        let peer = simulation.host_peer;
        let team = if replay {
            -1
        } else {
            simulation
                .state
                .owners
                .players
                .iter()
                .find(|p| p.0 == peer)
                .ok_or("Missing local player")?
                .1
        };
        let roads = simulation.state.rules.network.roads.clone();
        Ok(Self {
            simulation,
            content,
            view: View::new(team)?,
            peer,
            team,
            recording,
            playback,
            end,
            packets: Packets::default(),
            inputs: Vec::new(),
            input_bytes: 0,
            effects: Vec::new(),
            surface: Surface::default(),
            roads,
            loaded: false,
            opened: false,
            finished: false,
        })
    }
    pub fn metadata(&self) -> Value {
        let presentation: Value = serde_json::from_slice(&self.simulation.presentation)
            .expect("validated simulation presentation");
        json!({"engine":frontline_server::ENGINE_ID,"peer":self.peer,"team":self.team,
            "side":self.simulation.state.water.side,"mood":presentation.get("mood"),"replay":self.status()})
    }
    fn status(&self) -> Value {
        self.playback.as_ref().map_or(Value::Null, |p| {
            json!({
            "position":(self.simulation.state.tick-p.initial_tick) as f64/60.,
            "duration":(self.end-p.initial_tick) as f64/60.,"verified":p.verified(),
            "concluded":p.verified() && self.simulation.state.victory.winner >= 0})
        })
    }
    fn hud(&mut self) -> Result<(), String> {
        render::json(
            &mut self.packets,
            net::HUD,
            observation::hud(&self.simulation, &self.content, self.team)?,
        )?;
        if self.playback.is_some() {
            let status = self.status();
            render::json(&mut self.packets, net::PLAYBACK, status)?;
        }
        Ok(())
    }
    pub fn open(&mut self) -> Result<(), String> {
        if self.opened {
            return Err("Worker client is already connected".into());
        }
        self.opened = true;
        let update = self.view.update(&self.simulation, &self.content);
        render::json(
            &mut self.packets,
            net::WELCOME,
            json!({"engine":frontline_server::ENGINE_ID,
            "peer":self.peer,"team":self.team,"entities":update.births.len(),
            "side":self.simulation.state.water.side,"tick":self.simulation.state.tick}),
        )?;
        for data in render::chunks(&render::map(&self.simulation)?) {
            self.packets.reliable(net::MAP, data)?;
        }
        render::update(&mut self.packets, &update, self.simulation.state.tick)?;
        self.packets.reliable(net::BASELINE_END, Arc::new(vec![]))?;
        self.hud()?;
        if self.simulation.state.victory.winner >= 0 {
            self.report()?;
            render::json(
                &mut self.packets,
                net::OVER,
                json!(self.simulation.state.victory.winner),
            )?;
        }
        Ok(())
    }
    fn report(&mut self) -> Result<(), String> {
        render::json(
            &mut self.packets,
            net::REPORT,
            observation::report(&self.simulation, &self.content, self.team)?,
        )
    }
    pub fn receive(&mut self, data: &[u8]) -> Result<(), String> {
        let (kind, _, payload) = net::decode(data)?;
        match kind {
            net::LOADED if self.opened && payload.is_empty() => {
                // Loading discards transient visuals, so restore persistent effects afterwards.
                render::json(
                    &mut self.packets,
                    net::FX,
                    Events::persistent(&self.simulation),
                )?;
                self.loaded = true;
            }
            net::ACK if payload.is_empty() => {}
            net::COMMAND if self.playback.is_none() && !self.finished => {
                let input = Input::Command {
                    peer: self.peer,
                    command: frontline_server::client_command::decode(payload)?,
                };
                let bytes = input.encode()?.len();
                if self.inputs.len() >= MAX_FRAME_INPUTS
                    || self.input_bytes + bytes > MAX_FRAME_BYTES
                {
                    return Err("Worker command queue exceeds limit".into());
                }
                self.inputs.push(input);
                self.input_bytes += bytes;
            }
            net::REQUEST_REPORT if payload.is_empty() => self.report()?,
            net::SEND_PRESENCE if co_command::presence(payload) => {}
            net::MARK if self.team >= 0 && self.playback.is_none() => {
                let mark = co_command::mark(payload)?;
                let (kind, data) =
                    co_command::project(&self.simulation, self.peer, self.team, &mark);
                render::json(&mut self.packets, kind, data)?;
            }
            _ => return Err("Invalid worker command".into()),
        }
        Ok(())
    }
    fn project(&mut self) -> Result<(), String> {
        render::update(
            &mut self.packets,
            &self.view.update(&self.simulation, &self.content),
            self.simulation.state.tick,
        )?;
        for events in self.effects.drain(..) {
            render::events(
                &mut self.packets,
                self.peer,
                self.team,
                &events,
                self.simulation.state.tick,
            )?;
        }
        Ok(())
    }
    pub fn step(&mut self, count: u32) -> Result<(), String> {
        if count > 4 {
            return Err("Worker tick batch exceeds limit".into());
        }
        if !self.loaded || self.finished {
            return Ok(());
        }
        for _ in 0..count {
            let winner = self.simulation.state.victory.winner;
            let frame = if let Some(playback) = &mut self.playback {
                let frame = playback.step(&mut self.simulation, &self.content)?;
                if self.simulation.state.tick > self.end
                    || (frame.is_none() && self.simulation.state.tick != self.end)
                {
                    return Err("Replay duration differs".into());
                }
                frame
            } else {
                Some(self.recording.as_mut().ok_or("Recording is closed")?.step(
                    &mut self.simulation,
                    &self.content,
                    &self.inputs,
                )?)
            };
            self.inputs.clear();
            self.input_bytes = 0;
            let Some(frame) = frame else {
                self.finished = true;
                self.project()?;
                self.hud()?;
                self.report()?;
                break;
            };
            let events = Events::collect(&self.simulation, &frame);
            for data in self.surface.update(
                &self.simulation.state.field.geometry.terrain,
                &events.blasts,
            )? {
                self.packets.reliable(net::SURFACE, data)?;
            }
            if self.roads != self.simulation.state.rules.network.roads {
                self.roads
                    .clone_from(&self.simulation.state.rules.network.roads);
                render::json(
                    &mut self.packets,
                    net::ROADS,
                    render::roads(&self.simulation),
                )?;
            }
            self.effects.push(events);
            if self.simulation.state.tick % 4 == 0 {
                self.project()?;
            }
            if self.simulation.state.tick % 30 == 0 {
                self.hud()?;
            }
            if self.simulation.state.victory.winner != winner {
                self.report()?;
                render::json(
                    &mut self.packets,
                    net::OVER,
                    json!(self.simulation.state.victory.winner),
                )?;
            }
        }
        Ok(())
    }
    pub fn seek(&mut self, offset: u32) -> Result<(), String> {
        if self.opened {
            return Err("Seeking requires a fresh observer".into());
        }
        let playback = self.playback.as_mut().ok_or("Only recordings can seek")?;
        let target = (playback.initial_tick + u64::from(offset)).min(self.end);
        while self.simulation.state.tick < target {
            if playback
                .step(&mut self.simulation, &self.content)?
                .is_none()
            {
                return Err("Replay ended before its declared duration".into());
            }
        }
        if target == self.end
            && playback
                .step(&mut self.simulation, &self.content)?
                .is_some()
        {
            return Err("Replay duration differs".into());
        }
        self.finished = playback.verified();
        Ok(())
    }
    pub fn take_packets(&mut self) -> Vec<u8> {
        self.packets.take()
    }
    pub fn finish(&mut self) -> Result<Vec<u8>, String> {
        self.finished = true;
        self.recording
            .take()
            .ok_or("No live recording")?
            .finish(&self.simulation)
    }
}
