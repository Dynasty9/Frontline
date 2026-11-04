//! Canonical player inputs shared by live play and recordings.
use frontline_core::{
    match_commands::Command,
    state_codec::{Reader, Writer},
};

pub const MAX_INPUT: usize = 1_048_576;
pub const MAX_FRAME_INPUTS: usize = 256;
pub const MAX_FRAME_BYTES: usize = 4 * MAX_INPUT;

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
