//! Validated full-match checkpoints; tick advancement lives in the parent module.
use super::*;
use sim::state_codec::{Reader, Writer};

pub const MAX_STATE: usize = 512 * 1024 * 1024;

impl Simulation {
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
}
