//! One tick entry point is used by the socket host and offline replay verification.
use crate::content::Content;
use frontline_core as sim;
use sim::match_commands::Command;
use sim::match_state::MatchState;
use sim::perception::PerceptionSearch;
use sim::state_codec::{Reader, Writer};
use std::collections::BTreeMap;

pub const MAX_INPUT: usize = 1_048_576;
pub const MAX_FRAME_INPUTS: usize = 256;
pub const MAX_FRAME_BYTES: usize = 4 * MAX_INPUT;
pub const MAX_STATE: usize = 512 * 1024 * 1024;

#[derive(Clone, Debug, PartialEq)]
pub enum Input {
    Join {
        peer: i32,
        team: i8,
        name: String,
        reclaim: Option<i32>,
    },
    Leave {
        peer: i32,
    },
    Command {
        peer: i32,
        command: Command,
    },
}
impl Input {
    pub fn encode(&self) -> Result<Vec<u8>, &'static str> {
        let mut w = Writer::new(b"FLMI\x01\0\0\0");
        match self {
            Self::Join {
                peer,
                team,
                name,
                reclaim,
            } => {
                if *peer <= 0
                    || !(-1..=1).contains(team)
                    || name.is_empty()
                    || name.len() > 256
                    || name.contains('\0')
                    || reclaim.is_some_and(|p| p <= 0)
                {
                    return Err("invalid player join");
                }
                w.byte(0);
                w.u32(*peer as u32);
                w.byte(*team as u8);
                w.bytes(name.as_bytes());
                w.u32(reclaim.unwrap_or(0) as u32);
            }
            Self::Leave { peer } => {
                if *peer <= 0 {
                    return Err("invalid departing player");
                }
                w.byte(1);
                w.u32(*peer as u32);
            }
            Self::Command { peer, command } => {
                if *peer <= 0 {
                    return Err("invalid command peer");
                }
                w.byte(2);
                w.u32(*peer as u32);
                w.bytes(&command.encode()?);
            }
        }
        if w.0.len() > MAX_INPUT {
            return Err("input exceeds limit");
        }
        Ok(w.0)
    }
    pub fn decode(bytes: &[u8]) -> Result<Self, &'static str> {
        if bytes.len() > MAX_INPUT {
            return Err("input exceeds limit");
        }
        let mut r = Reader::new(bytes, b"FLMI\x01\0\0\0")?;
        let tag = r.byte()?;
        let peer = i32::try_from(r.u32()?).map_err(|_| "invalid peer")?;
        let input = match tag {
            0 => {
                let team = r.byte()? as i8;
                let name =
                    String::from_utf8(r.bytes(256)?.to_vec()).map_err(|_| "invalid player name")?;
                let old = i32::try_from(r.u32()?).map_err(|_| "invalid returning peer")?;
                Self::Join {
                    peer,
                    team,
                    name,
                    reclaim: (old != 0).then_some(old),
                }
            }
            1 => Self::Leave { peer },
            2 => Self::Command {
                peer,
                command: Command::decode(r.bytes(MAX_INPUT)?)?,
            },
            _ => return Err("unknown match input"),
        };
        r.finish()?;
        if input.encode()? != bytes {
            return Err("noncanonical match input");
        }
        Ok(input)
    }
}

#[derive(Debug, PartialEq)]
pub struct Frame {
    pub tick: u64,
    pub commands: Vec<sim::match_commands::Event>,
    pub events: Vec<sim::match_tick::Event>,
}
pub struct Simulation {
    pub state: MatchState,
    pub host_peer: i32,
    pub names: BTreeMap<i32, String>,
    pub commanders: Vec<crate::commander::Commander>,
    pub landmarks: Vec<crate::mission::Landmark>,
    pub mission: Option<crate::mission::Mission>,
    pub presentation: Vec<u8>,
    pub aircraft_models: BTreeMap<u32, String>,
    pub profile: Option<crate::profiling::TickProfile>,
    search: PerceptionSearch,
}
impl Simulation {
    pub fn new(state: MatchState, host_peer: i32, content: &Content) -> Result<Self, &'static str> {
        Self::from_state(state, host_peer, content, None)
    }
    fn from_state(
        mut state: MatchState,
        host_peer: i32,
        content: &Content,
        mission: Option<crate::mission::Mission>,
    ) -> Result<Self, &'static str> {
        if host_peer <= 0 {
            return Err("invalid host identity");
        }
        if state.victory.mission != mission.is_some() {
            return Err("inconsistent mission program");
        }
        content.validate_state(&state)?;
        let nav = &mut state.field.geometry.navigation;
        if (!nav.infantry.built || !nav.vehicles.built || !nav.tracked.built) && !nav.finalize(2) {
            return Err("initial navigation build failed");
        }
        let names = state
            .owners
            .players
            .iter()
            .map(|&(peer, _)| {
                let name = state
                    .field
                    .battle
                    .commander_names
                    .iter()
                    .find(|p| p.0 == peer)
                    .map_or_else(|| format!("Player {peer}"), |p| p.1.clone());
                (peer, name)
            })
            .collect();
        Ok(Self {
            state,
            host_peer,
            names,
            commanders: vec![],
            landmarks: vec![],
            mission,
            presentation: b"{}".to_vec(),
            aircraft_models: BTreeMap::new(),
            profile: None,
            search: PerceptionSearch::default(),
        })
    }
    pub fn enable_commander(&mut self, team: i8) -> Result<(), &'static str> {
        if self.mission.is_some() {
            return Err("missions direct their own forces");
        }
        if self.commanders.iter().any(|c| c.team == team) {
            return Err("duplicate commander");
        }
        self.commanders.push(crate::commander::Commander::new(
            team,
            self.state.field.rng.seed(),
            self.state.tick,
        )?);
        self.commanders.sort_by_key(|c| c.team);
        Ok(())
    }
    pub fn enable_mission(
        &mut self,
        key: &str,
        autoplay: bool,
        content: &Content,
    ) -> Result<Vec<sim::match_commands::Event>, &'static str> {
        if self.mission.is_some() || !self.commanders.is_empty() {
            return Err("match already has a director");
        }
        let mut mission =
            crate::mission::Mission::new(crate::mission::Kind::parse(key)?, &self.state, autoplay);
        if self
            .state
            .owners
            .players
            .iter()
            .any(|p| p.1 >= 0 && p.1 != mission.side)
        {
            return Err("mission player is on the opposing side");
        }
        let events = content.with_profiles(&[], |p, commands| {
            mission.setup(
                &mut self.state,
                content,
                &p.shared,
                commands,
                self.host_peer,
                &self.landmarks,
            )
        })?;
        self.mission = Some(mission);
        Ok(events)
    }
    pub fn checkpoint(&self) -> Result<Vec<u8>, &'static str> {
        if self.presentation.len() > 16 * 1024 * 1024 {
            return Err("map presentation exceeds limit");
        }
        let presentation: serde_json::Value =
            serde_json::from_slice(&self.presentation).map_err(|_| "invalid map presentation")?;
        if !presentation.is_object()
            || serde_json::to_vec(&presentation).unwrap() != self.presentation
        {
            return Err("noncanonical map presentation");
        }
        if let Some(m) = &self.mission {
            let winner = match m.over {
                0 => -1,
                1 => m.side,
                2 => 1 - m.side,
                _ => return Err("invalid mission conclusion"),
            };
            if winner != self.state.victory.winner
                || m.owners
                    .iter()
                    .any(|p| *p > 0 && self.state.owners.team_of(*p) != m.side)
            {
                return Err("inconsistent mission ownership or winner");
            }
        }
        if self.state.victory.mission != self.mission.is_some()
            || self.mission.is_some() && !self.commanders.is_empty()
        {
            return Err("inconsistent mission director");
        }
        if self.landmarks.len() > 4096
            || self.landmarks.iter().any(|p| {
                p.kind.is_empty()
                    || p.kind.len() > 64
                    || p.kind.contains('\0')
                    || !p.position.is_finite()
                    || p.position.abs().max_element() > 1_000_000.
            })
        {
            return Err("invalid map landmarks");
        }
        if self.names.len() > 32
            || self
                .names
                .iter()
                .any(|(p, n)| *p <= 0 || n.is_empty() || n.len() > 256 || n.contains('\0'))
        {
            return Err("invalid player registry");
        }
        let mut w = Writer::new(b"FLSS\x02\0\0\0");
        w.bytes(crate::ENGINE_ID.as_bytes());
        w.u32(self.host_peer as u32);
        w.u32(self.names.len() as u32);
        for (&peer, name) in &self.names {
            w.u32(peer as u32);
            w.bytes(name.as_bytes());
        }
        if self.commanders.len() > 2 || self.commanders.windows(2).any(|c| c[0].team >= c[1].team) {
            return Err("invalid commander registry");
        }
        w.byte(self.commanders.len() as u8);
        for c in &self.commanders {
            w.bytes(&c.checkpoint()?);
        }
        w.u32(self.landmarks.len() as u32);
        for p in &self.landmarks {
            w.bytes(p.kind.as_bytes());
            w.point(p.position);
        }
        w.byte(self.mission.is_some().into());
        if let Some(mission) = &self.mission {
            w.bytes(&mission.checkpoint()?);
        }
        w.bytes(&self.presentation);
        w.u32(self.aircraft_models.len() as u32);
        for (&id, model) in &self.aircraft_models {
            if model.len() > 128
                || model.contains('\0')
                || !matches!(self.state.field.actors.get(id), Some(sim::actors::Actor::Projectile(p)) if matches!(p.motion, sim::projectile_actor::Motion::Support(_)))
            {
                return Err("invalid support aircraft appearance");
            }
            w.u32(id);
            w.bytes(model.as_bytes());
        }
        w.bytes(&crate::compression::encode(&self.state.checkpoint()?)?);
        if w.0.len() > MAX_STATE {
            return Err("simulation checkpoint exceeds limit");
        }
        Ok(w.0)
    }
    pub fn restore(bytes: &[u8], content: &Content) -> Result<Self, &'static str> {
        if bytes.len() > MAX_STATE {
            return Err("simulation checkpoint exceeds limit");
        }
        let mut r = Reader::new(bytes, b"FLSS\x02\0\0\0")?;
        if r.bytes(64)? != crate::ENGINE_ID.as_bytes() {
            return Err("incompatible simulation build");
        }
        let host = i32::try_from(r.u32()?).map_err(|_| "invalid host")?;
        let count = r.u32()?;
        if count > 32 {
            return Err("player registry exceeds limit");
        }
        let mut names = BTreeMap::new();
        for _ in 0..count {
            let peer = i32::try_from(r.u32()?).map_err(|_| "invalid player")?;
            let name =
                String::from_utf8(r.bytes(256)?.to_vec()).map_err(|_| "invalid player name")?;
            if names.insert(peer, name).is_some() {
                return Err("duplicate player identity");
            }
        }
        let count = r.byte()?;
        if count > 2 {
            return Err("commander registry exceeds limit");
        }
        let mut commanders = Vec::with_capacity(count as usize);
        for _ in 0..count {
            commanders.push(crate::commander::Commander::restore(r.bytes(MAX_STATE)?)?);
        }
        if commanders.iter().any(|c| {
            !c.next_vehicle.is_empty() && content.definitions["vehicles"][&c.next_vehicle].is_null()
        }) {
            return Err("commander references unknown vehicle");
        }
        let count = r.u32()?;
        if count > 4096 {
            return Err("too many map landmarks");
        }
        let mut landmarks = Vec::with_capacity(count as usize);
        for _ in 0..count {
            landmarks.push(crate::mission::Landmark {
                kind: String::from_utf8(r.bytes(64)?.to_vec())
                    .map_err(|_| "invalid landmark kind")?,
                position: r.point()?,
            });
        }
        let mission = if r.boolean()? {
            Some(crate::mission::Mission::restore(
                r.bytes(16 * 1024 * 1024)?,
            )?)
        } else {
            None
        };
        let presentation = r.bytes(16 * 1024 * 1024)?.to_vec();
        let count = r.u32()?;
        if count > sim::entities::MAX_ENTITIES as u32 {
            return Err("too many aircraft appearances");
        }
        let mut aircraft_models = BTreeMap::new();
        for _ in 0..count {
            let id = r.u32()?;
            let model = String::from_utf8(r.bytes(128)?.to_vec())
                .map_err(|_| "invalid aircraft appearance")?;
            if aircraft_models.insert(id, model).is_some() {
                return Err("duplicate aircraft appearance");
            }
        }
        let state = MatchState::restore(&crate::compression::decode(
            r.bytes(MAX_STATE)?,
            sim::match_state::MAX_CHECKPOINT,
        )?)?;
        r.finish()?;
        if names
            .keys()
            .any(|p| !state.owners.players.iter().any(|q| q.0 == *p))
            || names.len() != state.owners.players.len()
        {
            return Err("inconsistent player registry");
        }
        let mut result = Self::from_state(state, host, content, mission)?;
        result.names = names;
        result.commanders = commanders;
        result.landmarks = landmarks;
        result.presentation = presentation;
        result.aircraft_models = aircraft_models;
        if result.checkpoint()? != bytes {
            return Err("noncanonical simulation checkpoint");
        }
        Ok(result)
    }
    pub fn step(&mut self, content: &Content, inputs: &[Input]) -> Result<Frame, &'static str> {
        if let Some(timing) = &mut self.profile {
            timing.begin();
        }
        if inputs.len() > MAX_FRAME_INPUTS {
            return Err("too many frame inputs");
        }
        let mut bytes = 0;
        for input in inputs {
            bytes += input.encode()?.len();
            if bytes > MAX_FRAME_BYTES {
                return Err("frame input bytes exceed limit");
            }
        }
        let mut present: BTreeMap<i32, i8> = self.state.owners.players.iter().copied().collect();
        for input in inputs {
            match input {
                Input::Join {
                    peer,
                    team,
                    reclaim,
                    ..
                } => {
                    if present.contains_key(peer)
                        || present.len() >= 32
                        || self
                            .mission
                            .as_ref()
                            .is_some_and(|m| *team >= 0 && *team != m.side)
                        || reclaim.is_some_and(|old| present.contains_key(&old))
                    {
                        return Err("invalid player admission");
                    }
                    present.insert(*peer, *team);
                }
                Input::Leave { peer } => {
                    present.remove(peer);
                }
                Input::Command { peer, .. } if !present.contains_key(peer) => {
                    return Err("command from disconnected player")
                }
                _ => {}
            }
        }
        let targets: Vec<_> = self
            .commanders
            .iter()
            .map(|c| (c.team, c.attack_target))
            .collect();
        content.with_profiles(&targets, |p, commands| {
            let mut out = Frame {
                tick: self.state.tick + 1,
                commands: vec![],
                events: vec![],
            };
            for input in inputs {
                match input {
                    Input::Join {
                        peer,
                        team,
                        name,
                        reclaim,
                    } => {
                        if self.names.contains_key(peer) || self.names.len() >= 32 {
                            return Err("duplicate or excess connected player");
                        }
                        self.state.owners.connect(*peer, *team)?;
                        let f = &mut self.state.field;
                        f.battle.joined(*peer, *team, name)?;
                        self.names.insert(*peer, name.clone());
                        let mut returned = false;
                        if let Some(old) = reclaim {
                            let stand_down = self
                                .commanders
                                .iter()
                                .any(|c| c.team == *team && !c.permanent)
                                || self.mission.as_ref().is_some_and(|m| {
                                    m.side == *team && m.owners.contains(&(-1 - i32::from(*team)))
                                });
                            let (got_back, changed) = self.state.owners.reclaim(
                                *peer,
                                *old,
                                name,
                                &mut f.squads,
                                &mut f.actors,
                                &mut f.battle,
                                stand_down,
                                p.shared.automatic,
                            )?;
                            returned = got_back > 0;
                            out.commands
                                .push(sim::match_commands::Event::Ownership(changed));
                            if stand_down {
                                self.commanders.retain(|c| c.team != *team);
                            }
                        }
                        if let Some(mission) = &mut self.mission {
                            out.commands.push(sim::match_commands::Event::Ownership(
                                mission.joined(&mut self.state, *peer, returned)?,
                            ));
                        }
                    }
                    Input::Leave { peer } => {
                        let f = &mut self.state.field;
                        if let Some((team, heir, changed)) =
                            self.state
                                .owners
                                .depart(*peer, &mut f.squads, &mut f.actors)?
                        {
                            out.commands
                                .push(sim::match_commands::Event::Ownership(changed));
                            if let Some(mission) = &mut self.mission {
                                mission.owner_changed(*peer, heir);
                            }
                            if team >= 0
                                && heir < 0
                                && !self.state.victory.mission
                                && !self.commanders.iter().any(|c| c.team == team)
                            {
                                let mut commander = crate::commander::Commander::new(
                                    team,
                                    f.rng.seed(),
                                    self.state.tick,
                                )?;
                                commander.permanent = false;
                                self.commanders.push(commander);
                                self.commanders.sort_by_key(|c| c.team);
                            }
                        }
                        self.names.remove(peer);
                    }
                    Input::Command { peer, command } => {
                        let name = self
                            .names
                            .get(peer)
                            .ok_or("command from disconnected player")?;
                        out.commands.extend(self.state.execute(
                            *peer,
                            name,
                            self.host_peer,
                            command,
                            &p.shared,
                            commands,
                        )?);
                    }
                }
            }
            if let Some(timing) = &mut self.profile {
                timing.mark("commands");
            }
            out.events.extend(self.state.advance_battlefield_profiled(
                p,
                &mut self.search,
                |phase| {
                    if let Some(timing) = &mut self.profile {
                        timing.mark(phase);
                    }
                },
            )?);
            for commander in &mut self.commanders {
                out.commands.extend(commander.advance(
                    &mut self.state,
                    content,
                    &self.landmarks,
                    &p.shared,
                    commands,
                    self.host_peer,
                )?);
            }
            if let Some(mission) = &mut self.mission {
                let winner = self.state.victory.winner;
                out.commands.extend(mission.advance(
                    &mut self.state,
                    content,
                    &p.shared,
                    commands,
                    self.host_peer,
                )?);
                if winner < 0 && self.state.victory.winner >= 0 {
                    out.events.push(sim::match_tick::Event::Rules(
                        sim::rules_world::Event::Winner(self.state.victory.winner),
                    ));
                }
            }
            if let Some(timing) = &mut self.profile {
                timing.mark("commanders_and_missions");
            }
            out.events.extend(self.state.finish_battlefield(p)?);
            let births = out
                .commands
                .iter()
                .filter_map(|e| match e {
                    sim::match_commands::Event::Support(e) => Some(e),
                    _ => None,
                })
                .chain(out.events.iter().filter_map(|e| match e {
                    sim::match_tick::Event::Rules(sim::rules_world::Event::Support(e)) => Some(e),
                    _ => None,
                }));
            for e in births {
                if let sim::support_calls::Event::Born { id, model } = e {
                    if !model.is_empty() {
                        self.aircraft_models.insert(*id, model.clone());
                    }
                }
            }
            self.aircraft_models
                .retain(|id, _| self.state.field.actors.get(*id).is_some());
            if let Some(timing) = &mut self.profile {
                timing.mark("deferred_effects");
            }
            Ok(out)
        })
    }
}
