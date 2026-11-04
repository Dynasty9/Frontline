//! Render packets shared by socket hosts and browser workers.
use crate::{
    observation::{
        events::{self, Events},
        Update,
    },
    protocol as net,
    simulation::Simulation,
};
use frontline_core::{state_codec::Writer, vector::Vector3};
use serde_json::{json, Value};
use std::sync::Arc;

pub trait Output {
    fn reliable(&mut self, kind: u8, data: Arc<Vec<u8>>) -> Result<(), String>;
    fn unreliable(&mut self, kind: u8, tick: u64, data: &[u8]) -> Result<(), String>;
}

fn point(p: Vector3) -> Value {
    json!(p.to_array())
}
pub fn roads(s: &Simulation) -> Value {
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
pub fn chunks(data: &[u8]) -> Vec<Arc<Vec<u8>>> {
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

pub fn json(output: &mut impl Output, kind: u8, value: Value) -> Result<(), String> {
    let data = serde_json::to_vec(&value).map_err(|e| e.to_string())?;
    if data.len() <= 48 * 1024 {
        return output.reliable(kind, Arc::new(data));
    }
    if data.len() > 16 * 1024 * 1024 {
        return Err("render document exceeds limit".into());
    }
    for (i, part) in data.chunks(48 * 1024).enumerate() {
        let mut packet = vec![kind];
        packet.extend_from_slice(&(data.len() as u32).to_le_bytes());
        packet.extend_from_slice(&((i * 48 * 1024) as u32).to_le_bytes());
        packet.extend_from_slice(part);
        output.reliable(net::BLOB, Arc::new(packet))?;
    }
    Ok(())
}

pub fn update(output: &mut impl Output, u: &Update, tick: u64) -> Result<(), String> {
    for b in &u.births {
        let mut w = Writer::new(b"FLOB\x01\0\0\0");
        w.u32(b.id);
        w.byte(b.kind);
        w.bytes(&serde_json::to_vec(&b.props).map_err(|e| e.to_string())?);
        w.bytes(&b.state);
        output.reliable(net::SPAWN, Arc::new(w.0))?;
    }
    for (id, p) in &u.properties {
        output.reliable(
            net::PROPS,
            Arc::new(serde_json::to_vec(&json!([id, p])).map_err(|e| e.to_string())?),
        )?;
    }
    for ids in u.despawns.chunks(4096) {
        output.reliable(
            net::DESPAWN,
            Arc::new(ids.iter().flat_map(|id| id.to_le_bytes()).collect()),
        )?;
    }
    for data in &u.snapshots {
        output.unreliable(net::SNAPSHOT, tick, data)?;
    }
    Ok(())
}

pub fn events(
    output: &mut impl Output,
    peer: i32,
    team: i8,
    events: &Events,
    tick: u64,
) -> Result<(), String> {
    let visible = |mask: u8| team < 0 || mask & (1 << team) != 0;
    for (id, mask, props) in &events.properties {
        if visible(*mask) {
            json(output, net::PROPS, json!([id, props]))?;
        }
    }
    let mut batch = Vec::new();
    let mut bytes = 2;
    for e in &events.effects {
        if !visible(e.mask) {
            continue;
        }
        if e.reliable {
            json(output, net::FX, json!([e.data]))?;
            continue;
        }
        let encoded = serde_json::to_vec(&e.data).map_err(|e| e.to_string())?;
        if bytes + encoded.len() + 1 > 1100 && !batch.is_empty() {
            output.unreliable(
                net::FX,
                tick,
                &serde_json::to_vec(&batch).map_err(|e| e.to_string())?,
            )?;
            batch.clear();
            bytes = 2;
        }
        if encoded.len() + 2 > 1100 {
            json(output, net::FX, json!([e.data]))?;
        } else {
            bytes += encoded.len() + 1;
            batch.push(&e.data);
        }
    }
    if !batch.is_empty() {
        output.unreliable(
            net::FX,
            tick,
            &serde_json::to_vec(&batch).map_err(|e| e.to_string())?,
        )?;
    }
    for m in &events.messages {
        if events::admits(m.audience, peer, team) {
            json(output, net::MESSAGE, m.data.clone())?;
        }
    }
    for (from, side, data) in &events.deeds {
        if peer != *from && (team < 0 || team == *side) {
            json(output, net::DEED, data.clone())?;
        }
    }
    Ok(())
}
