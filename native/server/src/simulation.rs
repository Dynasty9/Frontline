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
    search: PerceptionSearch,
}
impl Simulation {
    pub fn new(
        mut state: MatchState,
        host_peer: i32,
        content: &Content,
    ) -> Result<Self, &'static str> {
        if host_peer <= 0 {
            return Err("invalid host identity");
        }
        if state.victory.mission {
            return Err("mission program required");
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
            search: PerceptionSearch::default(),
        })
    }
    pub fn enable_commander(&mut self, team: i8) -> Result<(), &'static str> {
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
    pub fn checkpoint(&self) -> Result<Vec<u8>, &'static str> {
        if self.names.len() > 32
            || self
                .names
                .iter()
                .any(|(p, n)| *p <= 0 || n.is_empty() || n.len() > 256 || n.contains('\0'))
        {
            return Err("invalid player registry");
        }
        let mut w = Writer::new(b"FLSS\x01\0\0\0");
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
        w.bytes(&self.state.checkpoint()?);
        if w.0.len() > MAX_STATE {
            return Err("simulation checkpoint exceeds limit");
        }
        Ok(w.0)
    }
    pub fn restore(bytes: &[u8], content: &Content) -> Result<Self, &'static str> {
        if bytes.len() > MAX_STATE {
            return Err("simulation checkpoint exceeds limit");
        }
        let mut r = Reader::new(bytes, b"FLSS\x01\0\0\0")?;
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
        let state = MatchState::restore(r.bytes(MAX_STATE)?)?;
        r.finish()?;
        if names
            .keys()
            .any(|p| !state.owners.players.iter().any(|q| q.0 == *p))
            || names.len() != state.owners.players.len()
        {
            return Err("inconsistent player registry");
        }
        let mut result = Self::new(state, host, content)?;
        result.names = names;
        result.commanders = commanders;
        if result.checkpoint()? != bytes {
            return Err("noncanonical simulation checkpoint");
        }
        Ok(result)
    }
    pub fn step(&mut self, content: &Content, inputs: &[Input]) -> Result<Frame, &'static str> {
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
                        if let Some(old) = reclaim {
                            let stand_down = self
                                .commanders
                                .iter()
                                .any(|c| c.team == *team && !c.permanent);
                            let (_, changed) = self.state.owners.reclaim(
                                *peer,
                                *old,
                                name,
                                &mut f.squads,
                                &mut f.actors,
                                &mut f.battle,
                                stand_down,
                                p.shared.automatic,
                            )?;
                            out.commands
                                .push(sim::match_commands::Event::Ownership(changed));
                            if stand_down {
                                self.commanders.retain(|c| c.team != *team);
                            }
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
            out.events
                .extend(self.state.advance_battlefield(p, &mut self.search)?);
            for commander in &mut self.commanders {
                out.commands.extend(commander.advance(
                    &mut self.state,
                    content,
                    &p.shared,
                    commands,
                    self.host_peer,
                )?);
            }
            out.events.extend(self.state.finish_battlefield(p)?);
            Ok(out)
        })
    }
}
