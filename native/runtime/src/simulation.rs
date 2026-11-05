//! One tick entry point is used by the socket host and offline replay verification.
use crate::content::Content;
use frontline_core as sim;
use sim::match_state::MatchState;
use sim::perception::PerceptionSearch;
use std::collections::BTreeMap;

mod codec;
mod input;
pub use codec::MAX_STATE;
pub use input::{Input, MAX_FRAME_BYTES, MAX_FRAME_INPUTS, MAX_INPUT};

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
    pub fn step(&mut self, content: &Content, inputs: &[Input]) -> Result<Frame, &'static str> {
        self.state.field.geometry.navigation.planner.profile =
            self.profile.as_ref().map(|_| Default::default());
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
                        } else if reclaim.is_none() && *team >= 0 {
                            let f = &mut self.state.field;
                            let home = sim::economy::fobs(&f.actors, *team, false)
                                .min_by_key(|s| s.completed_order)
                                .map(|s| s.position);
                            if let Some(home) = home {
                                let forward = if *team == 0 {
                                    sim::vector::Vector3::NEG_Z
                                } else {
                                    sim::vector::Vector3::Z
                                };
                                let side = sim::vector::Vector3::X * f.rng.randf_range(-12., 12.);
                                let kinds = if *team == 0 {
                                    ["rifle_squad", "engineer_team"]
                                } else {
                                    ["fighter_cell", "digger_team"]
                                };
                                for (i, kind) in kinds.iter().enumerate() {
                                    let (_, events) = f.with_context(
                                        &p.shared,
                                        sim::match_state::Upgrades::from(&self.state.rules.economy),
                                        |w| {
                                            w.spawn_squad(
                                                sim::squad_birth::Spawn {
                                                    team: *team,
                                                    owner: *peer,
                                                    position: home
                                                        + forward * if i == 0 { 11. } else { -10. }
                                                        + side,
                                                    destination: (i == 0)
                                                        .then_some(home + forward * 18. + side),
                                                },
                                                content.squad(kind).unwrap(),
                                            )
                                        },
                                    )?;
                                    out.commands.extend(
                                        events.into_iter().map(sim::match_commands::Event::Squad),
                                    );
                                }
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
