//! Application framing shared by socket and worker transports.
pub const VERSION: u16 = 3;
pub const AUTH: u8 = 0;
pub const COMMAND: u8 = 1;
pub const LOADED: u8 = 2;
pub const ACK: u8 = 3;
pub const REQUEST_REPORT: u8 = 4;
pub const SEND_PRESENCE: u8 = 5;
pub const MARK: u8 = 6;
pub const SNAPSHOT: u8 = 16;
pub const WELCOME: u8 = 17;
pub const SPAWN: u8 = 18;
pub const PROPS: u8 = 19;
pub const DESPAWN: u8 = 20;
pub const MAP: u8 = 21;
pub const BASELINE_END: u8 = 22;
pub const HUD: u8 = 23;
pub const FX: u8 = 24;
pub const MESSAGE: u8 = 25;
pub const OVER: u8 = 26;
pub const REPORT: u8 = 27;
pub const BLOB: u8 = 28;
pub const PLAYBACK: u8 = 29;
pub const SURFACE: u8 = 30;
pub const ROADS: u8 = 31;
pub const PRESENCE: u8 = 32;
pub const PING: u8 = 33;
pub const SKETCH: u8 = 34;
pub const DEED: u8 = 35;
pub const MAX_PACKET: usize = 64 * 1024 + 32;

pub fn packet(kind: u8, sequence: u64, data: &[u8]) -> Vec<u8> {
    let mut out = Vec::with_capacity(16 + data.len());
    out.extend_from_slice(b"FLNP");
    out.extend_from_slice(&VERSION.to_le_bytes());
    out.extend_from_slice(&[kind, 0]);
    out.extend_from_slice(&sequence.to_le_bytes());
    out.extend_from_slice(data);
    out
}
pub fn decode(data: &[u8]) -> Result<(u8, u64, &[u8]), &'static str> {
    if data.len() < 16
        || data.len() > MAX_PACKET
        || &data[..4] != b"FLNP"
        || u16::from_le_bytes(data[4..6].try_into().unwrap()) != VERSION
        || data[7] != 0
    {
        return Err("invalid network packet");
    }
    Ok((
        data[6],
        u64::from_le_bytes(data[8..16].try_into().unwrap()),
        &data[16..],
    ))
}
