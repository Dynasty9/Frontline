//! The visual client sends its existing order vocabulary; identity comes from the connection.
use frontline_core::{
    match_commands::{Action, Command, Placement, UnitOrder},
    vector::Vector3,
};
use serde_json::Value;

pub const MAX_BYTES: usize = 64 * 1024;

fn text<'a>(d: &'a Value, key: &str, default: &'a str) -> Result<&'a str, &'static str> {
    let s = match d.get(key) {
        Some(v) => v.as_str().ok_or("invalid command text")?,
        None => default,
    };
    if s.len() > 1024 || s.contains('\0') {
        return Err("command text exceeds limit");
    }
    Ok(s)
}
fn id(v: &Value) -> Result<u32, &'static str> {
    v.as_u64()
        .and_then(|v| v.try_into().ok())
        .ok_or("invalid command identity")
}
fn ids(d: &Value, key: &str) -> Result<Vec<u32>, &'static str> {
    match d.get(key) {
        None => Ok(vec![]),
        Some(v) => v
            .as_array()
            .filter(|v| v.len() <= 2048)
            .ok_or("command selection exceeds limit")?
            .iter()
            .map(id)
            .collect(),
    }
}
fn number(v: &Value) -> Result<f64, &'static str> {
    v.as_f64()
        .filter(|n| n.is_finite() && n.abs() <= 1_000_000.)
        .ok_or("invalid command number")
}
fn point(v: &Value) -> Result<Vector3, &'static str> {
    let p = v
        .as_array()
        .filter(|p| p.len() == 3)
        .ok_or("invalid command position")?;
    Ok(Vector3::new(
        number(&p[0])? as f32,
        number(&p[1])? as f32,
        number(&p[2])? as f32,
    ))
}
fn position(d: &Value, key: &str, optional: bool) -> Result<Vector3, &'static str> {
    match d.get(key) {
        None if optional => Ok(Vector3::ZERO),
        Some(v) => point(v),
        _ => Err("missing command position"),
    }
}
fn mode(d: &Value) -> Result<u8, &'static str> {
    d.get("mode").map_or(Ok(0), |v| {
        id(v).and_then(|v| {
            if v <= 2 {
                Ok(v as u8)
            } else {
                Err("invalid movement mode")
            }
        })
    })
}
fn smoke(d: &Value, default: &str) -> Result<bool, &'static str> {
    match text(d, "kind", default)? {
        "frag" | "he" => Ok(false),
        "smoke" => Ok(true),
        _ => Err("unknown ammunition kind"),
    }
}

pub fn decode(bytes: &[u8]) -> Result<Command, &'static str> {
    if bytes.len() > MAX_BYTES {
        return Err("command exceeds byte limit");
    }
    let d: Value = serde_json::from_slice(bytes).map_err(|_| "invalid command JSON")?;
    if !d.is_object()
        || d.get("peer").is_some()
        || d.get("owner").is_some()
        || d.get("reclaim").is_some()
    {
        return Err("command cannot choose its sender");
    }
    let action = match text(&d, "t", "")? {
        "move" => Action::Move {
            position: position(&d, "pos", false)?,
            face: position(&d, "face", true)?,
            mode: mode(&d)?,
        },
        "assault" => Action::Assault {
            position: position(&d, "pos", false)?,
            face: position(&d, "face", true)?,
        },
        "defend" => Action::Defend {
            position: position(&d, "pos", false)?,
            face: position(&d, "face", true)?,
        },
        "dismount" => Action::Dismount,
        "unit" => Action::Unit {
            soldier: id(&d["soldier"])?,
            order: match text(&d, "o", "move")? {
                "move" => UnitOrder::Move {
                    position: position(&d, "pos", false)?,
                    face: position(&d, "face", true)?,
                    mode: mode(&d)?,
                },
                "attack" => UnitOrder::Attack(id(&d["target"])?),
                "throw" => UnitOrder::Throw {
                    position: position(&d, "pos", false)?,
                    smoke: smoke(&d, "frag")?,
                },
                "stop" => UnitOrder::Stop,
                "retreat" => UnitOrder::Retreat,
                "man" => UnitOrder::Man(id(&d["target"])?),
                _ => return Err("unknown individual order"),
            },
        },
        "attack" => Action::Attack(id(&d["target"])?),
        "stop" => Action::Stop,
        "retreat" => Action::Retreat,
        "build" => Action::Build {
            kind: text(&d, "kind", "")?.into(),
            position: position(&d, "pos", false)?,
            yaw: d.get("yaw").map_or(Ok(0.), number)?,
        },
        "build_many" => {
            let items = d["items"]
                .as_array()
                .filter(|a| a.len() <= 4096)
                .ok_or("invalid placement list")?;
            let mut parsed = vec![];
            for row in items {
                let row = row
                    .as_array()
                    .filter(|a| (2..=3).contains(&a.len()))
                    .ok_or("invalid placement")?;
                parsed.push(Placement {
                    position: point(&row[0])?,
                    yaw: number(&row[1])?,
                    length: row.get(2).map(number).transpose()?,
                });
            }
            Action::BuildMany {
                kind: text(&d, "kind", "")?.into(),
                items: parsed,
            }
        }
        "fire_mission" => Action::FireMission {
            building: d.get("building").map_or(Ok(0), id)?,
            position: position(&d, "pos", false)?,
            smoke: smoke(&d, "he")?,
        },
        "work" => Action::Work(id(&d["target"])?),
        "enter" => Action::Enter(id(&d["target"])?),
        "sling" => Action::Sling(id(&d["target"])?),
        "board" => Action::Board(id(&d["target"])?),
        "throw" => Action::Throw {
            position: position(&d, "pos", false)?,
            smoke: smoke(&d, "frag")?,
        },
        "support" => Action::Support {
            kind: text(&d, "kind", "")?.into(),
            position: position(&d, "pos", false)?,
            direction: position(&d, "dir", true)?,
        },
        "demo_support" => Action::DemoSupport {
            kind: text(&d, "kind", "")?.into(),
            position: position(&d, "pos", false)?,
            direction: position(&d, "dir", true)?,
        },
        t @ ("train" | "research") => Action::Produce {
            building: id(&d["building"])?,
            item: text(&d, "item", "")?.into(),
            research: t == "research",
        },
        "cancel" => Action::Cancel(id(&d["building"])?),
        "rally" => Action::Rally {
            building: id(&d["building"])?,
            position: position(&d, "pos", false)?,
        },
        "tunnel_exit" => Action::TunnelExit {
            building: id(&d["building"])?,
            exit: id(&d["exit"])?,
        },
        "chat" => Action::Chat {
            text: text(&d, "text", "")?.trim().chars().take(200).collect(),
            team_only: d
                .get("team_only")
                .map_or(Ok(false), |v| v.as_bool().ok_or("invalid chat audience"))?,
        },
        _ => return Err("unknown client command"),
    };
    let command = Command {
        squads: ids(&d, "squads")?,
        vehicles: ids(&d, "vehicles")?,
        action,
    };
    if !command.valid() {
        return Err("invalid client command");
    }
    Ok(command)
}
