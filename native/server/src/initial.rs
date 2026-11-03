//! A trusted map-authoring process supplies initial data, never live gameplay decisions.
use crate::{
    content::Content,
    mission::Landmark,
    simulation::{Simulation, MAX_STATE},
};
use frontline_core as sim;
use serde_json::Value;
use sim::{
    actors::Actors, battle_stats::BattleStats, boat_navigation::BoatNavigation,
    match_state::MatchState, squad::Squad, state_codec::Reader, supply_network::SupplyNetwork,
    vector::Vector3, water::Water, world_geometry::WorldGeometry,
};

fn flag(meta: &Value, key: &str) -> Result<bool, &'static str> {
    meta[key].as_bool().ok_or("invalid initial flag")
}
fn text<'a>(meta: &'a Value, key: &str, limit: usize) -> Result<&'a str, &'static str> {
    let value = meta[key].as_str().ok_or("invalid initial text")?;
    if value.len() > limit || value.contains('\0') {
        return Err("initial text exceeds limit");
    }
    Ok(value)
}
fn count(r: &mut Reader<'_>, max: u32) -> Result<u32, &'static str> {
    let n = r.u32()?;
    if n > max {
        return Err("initial collection exceeds limit");
    }
    Ok(n)
}

pub fn load(bytes: &[u8], content: &Content) -> Result<Simulation, &'static str> {
    if bytes.len() > MAX_STATE {
        return Err("initial battlefield exceeds limit");
    }
    let mut r = Reader::new(bytes, b"FLIN\x02\0\0\0")?;
    if blake3::hash(r.bytes(4 * 1024 * 1024)?).as_bytes() != &content.digest {
        return Err("initial battlefield uses different game content");
    }
    let meta: Value = serde_json::from_slice(r.bytes(16 * 1024 * 1024)?)
        .map_err(|_| "invalid initial metadata")?;
    let seed = r.u64()?;
    let random = r.u64()?;
    let next_squad = r.u64()?;
    let geometry = WorldGeometry::restore(&crate::compression::decode(
        r.bytes(MAX_STATE)?,
        sim::match_state::MAX_CHECKPOINT,
    )?)?;
    let actors = Actors::restore(r.bytes(MAX_STATE)?)?;
    let network = SupplyNetwork::restore(r.bytes(MAX_STATE)?)?;
    let battle = BattleStats::restore(r.bytes(64 * 1024 * 1024)?)?;
    let water = Water::restore(r.bytes(MAX_STATE)?)?;
    let boats = BoatNavigation::from_terrain(&geometry.terrain, &geometry.deck)?;
    let mut state = MatchState::empty(geometry, water, boats, seed, flag(&meta, "wet")?)?;
    state.field.rng.set_state(random);
    state.field.next_squad = next_squad;
    state.field.actors = actors;
    state.field.actors.rebuild_units(&mut state.field.units)?;
    state.field.battle = battle;
    state.rules.network = network;
    state.field.town =
        serde_json::from_value(meta["town"].clone()).map_err(|_| "invalid initial town")?;
    state.rules.economy.upgrades =
        serde_json::from_value(meta["upgrades"].clone()).map_err(|_| "invalid initial upgrades")?;
    state.rules.support.ready =
        serde_json::from_value(meta["support"].clone()).map_err(|_| "invalid initial support")?;
    state.rules.fob_names_used = serde_json::from_value(meta["fob_names"].clone())
        .map_err(|_| "invalid initial FOB names")?;
    for keys in &state.rules.economy.upgrades {
        if keys
            .iter()
            .any(|key| content.definitions["upgrades"][key].is_null())
        {
            return Err("unknown initial upgrade");
        }
    }
    for calls in &state.rules.support.ready {
        if calls.iter().any(|(key, _)| content.support(key).is_none()) {
            return Err("unknown initial support");
        }
    }
    state.scenario = flag(&meta, "scenario")?;
    for _ in 0..count(&mut r, 100_000)? {
        state
            .field
            .squads
            .push(Squad::restore(r.bytes(16 * 1024 * 1024)?)?);
    }
    r.finish()?;
    if state
        .field
        .squads
        .iter()
        .any(|q| q.plan != 0 || q.ambush_plan != 0)
    {
        return Err("initial deployment references an active plan");
    }
    let host: i32 = meta["host"]
        .as_u64()
        .and_then(|p| p.try_into().ok())
        .ok_or("invalid initial host")?;
    let players = meta["players"]
        .as_array()
        .filter(|p| p.len() <= 32)
        .ok_or("invalid initial players")?;
    let mut names = std::collections::BTreeMap::new();
    for p in players {
        if p.as_array().is_none_or(|p| p.len() != 3) {
            return Err("invalid initial player");
        }
        let peer: i32 = p[0]
            .as_u64()
            .and_then(|p| p.try_into().ok())
            .ok_or("invalid initial peer")?;
        let team: i8 = p[1]
            .as_i64()
            .and_then(|p| p.try_into().ok())
            .ok_or("invalid initial side")?;
        let name = p[2]
            .as_str()
            .filter(|s| !s.is_empty() && s.len() <= 256 && !s.contains('\0'))
            .ok_or("invalid initial name")?;
        if names.insert(peer, name.to_owned()).is_some() {
            return Err("duplicate initial peer");
        }
        state.owners.players.push((peer, team));
    }
    if !state.owners.valid() {
        return Err("invalid initial ownership");
    }
    let mut result = Simulation::new(state, host, content)?;
    result.names = names;
    let landmarks = meta["landmarks"]
        .as_array()
        .filter(|p| p.len() <= 4096)
        .ok_or("invalid initial landmarks")?;
    for p in landmarks {
        let position: [f32; 3] =
            serde_json::from_value(p["pos"].clone()).map_err(|_| "invalid landmark position")?;
        result.landmarks.push(Landmark {
            kind: text(p, "kind", 64)?.into(),
            position: Vector3::from_array(position),
        });
    }
    let presentation = meta["presentation"]
        .as_object()
        .ok_or("invalid map presentation")?;
    result.presentation =
        serde_json::to_vec(presentation).map_err(|_| "invalid map presentation")?;
    let mission = text(&meta, "mission", 64)?;
    if !mission.is_empty() {
        result.enable_mission(mission, flag(&meta, "autoplay")?, content)?;
    } else {
        for team in meta["ai"]
            .as_array()
            .filter(|a| a.len() <= 2)
            .ok_or("invalid initial commanders")?
        {
            result.enable_commander(
                team.as_i64()
                    .and_then(|t| t.try_into().ok())
                    .ok_or("invalid AI side")?,
            )?;
        }
    }
    result.checkpoint()?;
    Ok(result)
}
