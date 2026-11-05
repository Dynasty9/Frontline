//! Local sockets, remote sockets and replays use the same bounded command bytes.
use crate::match_commands::{Action, Command, Placement, UnitOrder};
use crate::state_codec::{Reader, Writer};
const SCHEMA: &[u8; 8] = b"FLMC\x01\0\0\0";
pub const MAX_COMMAND_BYTES: usize = 1_048_576;
fn string(r: &mut Reader<'_>, limit: usize) -> Result<String, &'static str> {
    String::from_utf8(r.bytes(limit)?.to_vec()).map_err(|_| "invalid command text")
}
fn ids(r: &mut Reader<'_>) -> Result<Vec<u32>, &'static str> {
    let n = r.u32()? as usize;
    if n > 100_000 {
        return Err("command selection limit exceeded");
    }
    (0..n).map(|_| r.u32()).collect()
}
impl Command {
    pub fn encode(&self) -> Result<Vec<u8>, &'static str> {
        if !self.valid() {
            return Err("invalid match command");
        }
        let mut w = Writer::new(SCHEMA);
        for ids in [&self.squads, &self.vehicles] {
            w.u32(ids.len() as u32);
            for &id in ids {
                w.u32(id);
            }
        }
        match &self.action {
            Action::Move {
                position,
                face,
                mode,
            } => {
                w.byte(0);
                w.point(*position);
                w.point(*face);
                w.byte(*mode);
            }
            Action::Assault { position, face } => {
                w.byte(1);
                w.point(*position);
                w.point(*face);
            }
            Action::Defend { position, face } => {
                w.byte(2);
                w.point(*position);
                w.point(*face);
            }
            Action::Dismount => w.byte(3),
            Action::Unit { soldier, order } => {
                w.byte(4);
                w.u32(*soldier);
                match order {
                    UnitOrder::Move {
                        position,
                        face,
                        mode,
                    } => {
                        w.byte(0);
                        w.point(*position);
                        w.point(*face);
                        w.byte(*mode);
                    }
                    UnitOrder::Attack(id) => {
                        w.byte(1);
                        w.u32(*id);
                    }
                    UnitOrder::Throw { position, smoke } => {
                        w.byte(2);
                        w.point(*position);
                        w.byte(u8::from(*smoke));
                    }
                    UnitOrder::Stop => w.byte(3),
                    UnitOrder::Retreat => w.byte(4),
                    UnitOrder::Man(id) => {
                        w.byte(5);
                        w.u32(*id);
                    }
                }
            }
            Action::Attack(id) => {
                w.byte(5);
                w.u32(*id);
            }
            Action::Stop => w.byte(6),
            Action::Retreat => w.byte(7),
            Action::Build {
                kind,
                position,
                yaw,
            } => {
                w.byte(8);
                w.bytes(kind.as_bytes());
                w.point(*position);
                w.f64(*yaw);
            }
            Action::BuildMany { kind, items } => {
                w.byte(9);
                w.bytes(kind.as_bytes());
                w.u32(items.len() as u32);
                for p in items {
                    w.point(p.position);
                    w.f64(p.yaw);
                    w.byte(u8::from(p.length.is_some()));
                    if let Some(n) = p.length {
                        w.f64(n);
                    }
                }
            }
            Action::FireMission {
                building,
                position,
                smoke,
            } => {
                w.byte(10);
                w.u32(*building);
                w.point(*position);
                w.byte(u8::from(*smoke));
            }
            Action::Work(id) => {
                w.byte(11);
                w.u32(*id);
            }
            Action::Enter(id) => {
                w.byte(12);
                w.u32(*id);
            }
            Action::Sling(id) => {
                w.byte(13);
                w.u32(*id);
            }
            Action::Board(id) => {
                w.byte(14);
                w.u32(*id);
            }
            Action::Throw { position, smoke } => {
                w.byte(15);
                w.point(*position);
                w.byte(u8::from(*smoke));
            }
            Action::Support {
                kind,
                position,
                direction,
            }
            | Action::DemoSupport {
                kind,
                position,
                direction,
            } => {
                w.byte(if matches!(self.action, Action::Support { .. }) {
                    16
                } else {
                    17
                });
                w.bytes(kind.as_bytes());
                w.point(*position);
                w.point(*direction);
            }
            Action::Produce {
                building,
                item,
                research,
            } => {
                w.byte(18);
                w.u32(*building);
                w.bytes(item.as_bytes());
                w.byte(u8::from(*research));
            }
            Action::Cancel(id) => {
                w.byte(19);
                w.u32(*id);
            }
            Action::Rally { building, position } => {
                w.byte(20);
                w.u32(*building);
                w.point(*position);
            }
            Action::TunnelExit { building, exit } => {
                w.byte(21);
                w.u32(*building);
                w.u32(*exit);
            }
            Action::Chat { text, team_only } => {
                w.byte(22);
                w.bytes(text.as_bytes());
                w.byte(u8::from(*team_only));
            }
        }
        if w.0.len() > MAX_COMMAND_BYTES {
            return Err("command packet limit exceeded");
        }
        Ok(w.0)
    }
    pub fn decode(bytes: &[u8]) -> Result<Self, &'static str> {
        if bytes.len() > MAX_COMMAND_BYTES {
            return Err("command packet limit exceeded");
        }
        let mut r = Reader::new(bytes, SCHEMA)?;
        let squads = ids(&mut r)?;
        let vehicles = ids(&mut r)?;
        let action = match r.byte()? {
            0 => Action::Move {
                position: r.point()?,
                face: r.point()?,
                mode: r.byte()?,
            },
            1 => Action::Assault {
                position: r.point()?,
                face: r.point()?,
            },
            2 => Action::Defend {
                position: r.point()?,
                face: r.point()?,
            },
            3 => Action::Dismount,
            4 => Action::Unit {
                soldier: r.u32()?,
                order: match r.byte()? {
                    0 => UnitOrder::Move {
                        position: r.point()?,
                        face: r.point()?,
                        mode: r.byte()?,
                    },
                    1 => UnitOrder::Attack(r.u32()?),
                    2 => UnitOrder::Throw {
                        position: r.point()?,
                        smoke: r.boolean()?,
                    },
                    3 => UnitOrder::Stop,
                    4 => UnitOrder::Retreat,
                    5 => UnitOrder::Man(r.u32()?),
                    _ => return Err("unknown individual order"),
                },
            },
            5 => Action::Attack(r.u32()?),
            6 => Action::Stop,
            7 => Action::Retreat,
            8 => Action::Build {
                kind: string(&mut r, 128)?,
                position: r.point()?,
                yaw: r.f64()?,
            },
            9 => {
                let kind = string(&mut r, 128)?;
                let n = r.u32()?;
                if n > 4096 {
                    return Err("construction segment limit exceeded");
                }
                let items = (0..n)
                    .map(|_| {
                        Ok(Placement {
                            position: r.point()?,
                            yaw: r.f64()?,
                            length: if r.boolean()? { Some(r.f64()?) } else { None },
                        })
                    })
                    .collect::<Result<_, &'static str>>()?;
                Action::BuildMany { kind, items }
            }
            10 => Action::FireMission {
                building: r.u32()?,
                position: r.point()?,
                smoke: r.boolean()?,
            },
            11 => Action::Work(r.u32()?),
            12 => Action::Enter(r.u32()?),
            13 => Action::Sling(r.u32()?),
            14 => Action::Board(r.u32()?),
            15 => Action::Throw {
                position: r.point()?,
                smoke: r.boolean()?,
            },
            tag @ (16 | 17) => {
                let kind = string(&mut r, 128)?;
                let position = r.point()?;
                let direction = r.point()?;
                if tag == 16 {
                    Action::Support {
                        kind,
                        position,
                        direction,
                    }
                } else {
                    Action::DemoSupport {
                        kind,
                        position,
                        direction,
                    }
                }
            }
            18 => Action::Produce {
                building: r.u32()?,
                item: string(&mut r, 128)?,
                research: r.boolean()?,
            },
            19 => Action::Cancel(r.u32()?),
            20 => Action::Rally {
                building: r.u32()?,
                position: r.point()?,
            },
            21 => Action::TunnelExit {
                building: r.u32()?,
                exit: r.u32()?,
            },
            22 => Action::Chat {
                text: string(&mut r, 8192)?,
                team_only: r.boolean()?,
            },
            _ => return Err("unknown match command"),
        };
        r.finish()?;
        let command = Self {
            squads,
            vehicles,
            action,
        };
        if !command.valid() {
            return Err("invalid match command");
        }
        Ok(command)
    }
}
