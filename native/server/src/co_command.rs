//! Team-only screen presence and map marks do not advance or enter the simulation.
use crate::{observation, simulation::Simulation};
use serde_json::{json, Value};

pub fn presence(data: &[u8]) -> bool {
    if !(97..=700).contains(&data.len()) || data[0] > 31 || data[61] > 5 {
        return false;
    }
    let finite = |at| f32::from_le_bytes(data[at..at + 4].try_into().unwrap()).is_finite();
    if !(1..61).step_by(4).all(finite) {
        return false;
    }
    let name = u32::from_le_bytes(data[62..66].try_into().unwrap()) as usize;
    if name > 64 || 97 + name > data.len() || std::str::from_utf8(&data[66..66 + name]).is_err() {
        return false;
    }
    if !(66 + name..86 + name).step_by(4).all(finite) {
        return false;
    }
    let squads = data[94 + name] as usize;
    let vehicles_at = 95 + name + squads * 4;
    if squads > 40 || vehicles_at >= data.len() {
        return false;
    }
    let vehicles = data[vehicles_at] as usize;
    vehicles <= 40 && vehicles_at + vehicles * 4 + 2 == data.len()
}

pub fn mark(data: &[u8]) -> Result<Value, &'static str> {
    if data.len() > 8192 {
        return Err("map mark exceeds limit");
    }
    let d: Value = serde_json::from_slice(data).map_err(|_| "invalid map mark")?;
    let point = |p: &Value, n| {
        p.as_array().is_some_and(|a| {
            a.len() == n
                && a.iter().all(|v| {
                    v.as_f64()
                        .is_some_and(|v| v.is_finite() && v.abs() <= 100000.)
                })
        })
    };
    match d["t"].as_str() {
        Some("ping")
            if d["kind"].as_str().is_some_and(|k| {
                [
                    "look", "enemy", "attack", "defend", "danger", "help", "omw", "unit",
                ]
                .contains(&k)
            }) && point(&d["position"], 3)
                && d["entity"].as_u64().is_some_and(|id| id <= u32::MAX as u64) => {}
        Some("sketch")
            if d["points"]
                .as_array()
                .is_some_and(|a| (2..=64).contains(&a.len()) && a.iter().all(|p| point(p, 2))) => {}
        _ => return Err("invalid map mark"),
    }
    Ok(d)
}

pub fn project(s: &Simulation, peer: i32, team: i8, d: &Value) -> (u8, Value) {
    let half = s.state.water.side as f64 * 0.5;
    let bounded = |v: &Value| v.as_f64().unwrap().clamp(-half, half);
    if d["t"] == "ping" {
        let id = d["entity"].as_u64().unwrap() as u32;
        let id = if s
            .state
            .field
            .actors
            .get(id)
            .is_some_and(|a| observation::can_know(s, a, team))
        {
            id
        } else {
            0
        };
        (
            crate::network::PING,
            json!([
                peer,
                d["kind"],
                [bounded(&d["position"][0]), 0., bounded(&d["position"][2])],
                id
            ]),
        )
    } else {
        let points: Vec<_> = d["points"]
            .as_array()
            .unwrap()
            .iter()
            .map(|p| [bounded(&p[0]), bounded(&p[1])])
            .collect();
        (crate::network::SKETCH, json!([peer, points]))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn rejects_truncated_nonfinite_and_excessive_presentation() {
        let good = vec![0; 97];
        assert!(presence(&good));
        for n in 0..97 {
            assert!(!presence(&good[..n]));
        }
        for at in [1, 9, 13, 57, 66, 82] {
            let mut bad = good.clone();
            bad[at..at + 4].copy_from_slice(&f32::NAN.to_le_bytes());
            assert!(!presence(&bad));
        }
        let mut bad = good.clone();
        bad[94] = 41;
        assert!(!presence(&bad));
        let mut bad = good.clone();
        bad[62..66].copy_from_slice(&u32::MAX.to_le_bytes());
        assert!(!presence(&bad));
        let mut bad = good;
        bad.push(0);
        assert!(!presence(&bad));
        assert!(mark(br#"{"t":"ping","kind":"enemy","position":[0,0,0],"entity":0}"#).is_ok());
        assert!(mark(br#"{"t":"sketch","points":[[0,0],[1,2]]}"#).is_ok());
        for bad in [
            r#"{"t":"sketch","points":[[0,0]]}"#,
            r#"{"t":"ping","kind":"enemy","position":[0,0,0],"entity":-1}"#,
        ] {
            assert!(mark(bad.as_bytes()).is_err());
        }
    }
}
