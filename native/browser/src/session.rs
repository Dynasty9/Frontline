use frontline_runtime::{
    co_command,
    content::Content,
    initial,
    observation::{self, events::Events, View},
    protocol as net,
    render::Publication,
    render::{self, Output},
    session::Session as MatchSession,
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
    timeline: MatchSession<Cursor<Vec<u8>>, Vec<u8>>,
    content: Content,
    view: View,
    peer: i32,
    team: i8,
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
        let timeline = if replay {
            MatchSession::play(Cursor::new(bytes), &content)?
        } else {
            MatchSession::record(Vec::new(), initial::load(&bytes, &content)?, &content)?
        };
        let simulation = timeline.simulation();
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
            timeline,
            content,
            view: View::new(team)?,
            peer,
            team,
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
        let presentation: Value = serde_json::from_slice(&self.timeline.simulation().presentation)
            .expect("validated simulation presentation");
        json!({"engine":frontline_runtime::ENGINE_ID,"peer":self.peer,"team":self.team,
            "side":self.timeline.simulation().state.water.side,"mood":presentation.get("mood"),"replay":self.status()})
    }
    pub fn simulation(&self) -> &Simulation {
        self.timeline.simulation()
    }
    fn status(&self) -> Value {
        self.timeline.status()
    }
    fn hud(&mut self) -> Result<(), String> {
        render::json(
            &mut self.packets,
            net::HUD,
            observation::hud(self.timeline.simulation(), &self.content, self.team)?,
        )?;
        if self.timeline.is_replay() {
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
        let update = self.view.update(self.timeline.simulation(), &self.content);
        render::json(
            &mut self.packets,
            net::WELCOME,
            json!({"engine":frontline_runtime::ENGINE_ID,
            "peer":self.peer,"team":self.team,"entities":update.births.len(),
            "side":self.timeline.simulation().state.water.side,"tick":self.timeline.simulation().state.tick}),
        )?;
        for data in render::chunks(&render::map(self.timeline.simulation())?) {
            self.packets.reliable(net::MAP, data)?;
        }
        render::update(
            &mut self.packets,
            &update,
            self.timeline.simulation().state.tick,
        )?;
        self.packets.reliable(net::BASELINE_END, Arc::new(vec![]))?;
        self.hud()?;
        if self.timeline.simulation().state.victory.winner >= 0 {
            self.report()?;
            render::json(
                &mut self.packets,
                net::OVER,
                json!(self.timeline.simulation().state.victory.winner),
            )?;
        }
        Ok(())
    }
    fn report(&mut self) -> Result<(), String> {
        render::json(
            &mut self.packets,
            net::REPORT,
            observation::report(self.timeline.simulation(), &self.content, self.team)?,
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
                    Events::persistent(self.timeline.simulation()),
                )?;
                self.loaded = true;
            }
            net::ACK if payload.is_empty() => {}
            net::COMMAND if !self.timeline.is_replay() && !self.finished => {
                let input = Input::Command {
                    peer: self.peer,
                    command: frontline_runtime::client_command::decode(payload)?,
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
            net::MARK if self.team >= 0 && !self.timeline.is_replay() => {
                let mark = co_command::mark(payload)?;
                let (kind, data) =
                    co_command::project(self.timeline.simulation(), self.peer, self.team, &mark);
                render::json(&mut self.packets, kind, data)?;
            }
            _ => return Err("Invalid worker command".into()),
        }
        Ok(())
    }
    fn project(&mut self) -> Result<(), String> {
        render::update(
            &mut self.packets,
            &self.view.update(self.timeline.simulation(), &self.content),
            self.timeline.simulation().state.tick,
        )?;
        Ok(())
    }
    fn effects(&mut self) -> Result<(), String> {
        for events in self.effects.drain(..) {
            render::events(
                &mut self.packets,
                self.peer,
                self.team,
                &events,
                self.timeline.simulation().state.tick,
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
            let winner = self.timeline.simulation().state.victory.winner;
            let frame = self.timeline.step(&self.content, &self.inputs)?;
            self.inputs.clear();
            self.input_bytes = 0;
            self.finished = frame.is_none();
            if let Some(frame) = frame {
                let events = Events::collect(self.timeline.simulation(), &frame);
                for data in self.surface.update(
                    &self.timeline.simulation().state.field.geometry.terrain,
                    &events.blasts,
                )? {
                    self.packets.reliable(net::SURFACE, data)?;
                }
                if self.roads != self.timeline.simulation().state.rules.network.roads {
                    self.roads
                        .clone_from(&self.timeline.simulation().state.rules.network.roads);
                    render::json(
                        &mut self.packets,
                        net::ROADS,
                        render::roads(self.timeline.simulation()),
                    )?;
                }
                self.effects.push(events);
            }
            let concluded = self.timeline.simulation().state.victory.winner != winner;
            for publication in render::publications(
                self.timeline.simulation().state.tick,
                concluded,
                self.finished,
            ) {
                match publication {
                    Publication::Snapshot => self.project()?,
                    Publication::Effects => self.effects()?,
                    Publication::Hud => self.hud()?,
                    Publication::Report => self.report()?,
                    Publication::Over => render::json(
                        &mut self.packets,
                        net::OVER,
                        json!(self.timeline.simulation().state.victory.winner),
                    )?,
                }
            }
            if self.finished {
                break;
            }
        }
        Ok(())
    }
    pub fn seek(&mut self, offset: u32) -> Result<(), String> {
        if self.opened {
            return Err("Seeking requires a fresh observer".into());
        }
        let target = self.timeline.seek_target(u64::from(offset))?;
        while self.timeline.simulation().state.tick < target {
            if self.timeline.step(&self.content, &[])?.is_none() {
                return Err("Replay ended before its declared duration".into());
            }
        }
        if self.timeline.at_end() && self.timeline.step(&self.content, &[])?.is_some() {
            return Err("Replay duration differs".into());
        }
        self.finished = self.timeline.complete();
        Ok(())
    }
    pub fn take_packets(&mut self) -> Vec<u8> {
        self.packets.take()
    }
    pub fn finish(self) -> Result<Vec<u8>, String> {
        self.timeline.finish()?.ok_or("No live recording".into())
    }
}
