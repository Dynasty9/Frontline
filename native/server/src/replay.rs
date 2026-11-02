//! Record admitted inputs, then verify by independently advancing the same simulation.
use crate::{
    content::Content,
    simulation::{
        Frame, Input, Simulation, MAX_FRAME_BYTES, MAX_FRAME_INPUTS, MAX_INPUT, MAX_STATE,
    },
};
use frontline_core::state_codec::{Reader, Writer};
use std::io::{Read, Write};

const HEADER_LIMIT: usize = MAX_STATE + 256;
const FRAME_LIMIT: usize = MAX_FRAME_BYTES + MAX_FRAME_INPUTS * 4 + 128;
pub const MAX_REPLAY_TICKS: u64 = 24 * 60 * 60 * 60;
fn write_block(w: &mut impl Write, b: &[u8]) -> Result<(), String> {
    let size = u32::try_from(b.len()).map_err(|_| "replay block exceeds limit")?;
    w.write_all(&size.to_le_bytes())
        .and_then(|_| w.write_all(b))
        .map_err(|e| e.to_string())
}
fn read_block(r: &mut impl Read, limit: usize) -> Result<Vec<u8>, String> {
    let mut size = [0; 4];
    r.read_exact(&mut size)
        .map_err(|e| format!("incomplete replay: {e}"))?;
    let size = u32::from_le_bytes(size) as usize;
    if size > limit {
        return Err("replay block exceeds limit".into());
    }
    let mut bytes = vec![0; size];
    r.read_exact(&mut bytes)
        .map_err(|e| format!("incomplete replay: {e}"))?;
    Ok(bytes)
}
fn hash(s: &Simulation) -> Result<[u8; 32], String> {
    Ok(*blake3::hash(&s.checkpoint()?).as_bytes())
}
fn digest(r: &mut Reader<'_>) -> Result<[u8; 32], String> {
    r.bytes(32)?
        .try_into()
        .map_err(|_| "invalid replay digest".into())
}

pub struct Recorder<W: Write> {
    output: W,
    last_tick: u64,
    frames: u64,
    chain: blake3::Hasher,
}
impl<W: Write> Recorder<W> {
    pub fn new(mut output: W, simulation: &Simulation, content: &Content) -> Result<Self, String> {
        let mut h = Writer::new(b"FLRH\x01\0\0\0");
        h.bytes(crate::ENGINE_ID.as_bytes());
        h.bytes(&content.digest);
        h.bytes(&simulation.checkpoint()?);
        if h.0.len() > HEADER_LIMIT {
            return Err("replay header exceeds limit".into());
        }
        write_block(&mut output, &h.0)?;
        let mut chain = blake3::Hasher::new();
        chain.update(&h.0);
        Ok(Self {
            output,
            last_tick: simulation.state.tick,
            frames: 0,
            chain,
        })
    }
    pub fn step(
        &mut self,
        simulation: &mut Simulation,
        content: &Content,
        inputs: &[Input],
    ) -> Result<Frame, String> {
        if simulation.state.tick != self.last_tick || self.frames >= MAX_REPLAY_TICKS {
            return Err("recording tick is out of sequence".into());
        }
        let frame = simulation.step(content, inputs)?;
        let mut w = Writer::new(b"FLRF\x01\0\0\0");
        w.byte(0);
        w.u64(frame.tick);
        w.u32(inputs.len() as u32);
        for input in inputs {
            w.bytes(&input.encode()?);
        }
        // A full map checkpoint belongs at the start/end, not in a running tick.
        write_block(&mut self.output, &w.0)?;
        self.chain.update(&w.0);
        self.last_tick = frame.tick;
        self.frames += 1;
        Ok(frame)
    }
    pub fn finish(mut self, simulation: &Simulation) -> Result<W, String> {
        if simulation.state.tick != self.last_tick {
            return Err("unrecorded simulation tick".into());
        }
        let mut w = Writer::new(b"FLRF\x01\0\0\0");
        w.byte(1);
        w.u64(self.last_tick);
        w.bytes(&hash(simulation)?);
        w.byte(simulation.state.victory.winner as u8);
        w.bytes(self.chain.finalize().as_bytes());
        write_block(&mut self.output, &w.0)?;
        self.output.flush().map_err(|e| e.to_string())?;
        Ok(self.output)
    }
}
pub struct Verification {
    pub simulation: Simulation,
    pub frames: u64,
    pub state_hash: [u8; 32],
    pub initial_hash: [u8; 32],
}

pub fn verify(mut source: impl Read, content: &Content) -> Result<Verification, String> {
    let header = read_block(&mut source, HEADER_LIMIT)?;
    let mut h = Reader::new(&header, b"FLRH\x01\0\0\0")?;
    if h.bytes(64)? != crate::ENGINE_ID.as_bytes() {
        return Err("incompatible replay simulation build".into());
    }
    if digest(&mut h)? != content.digest {
        return Err("incompatible replay content".into());
    }
    let initial = h.bytes(MAX_STATE)?;
    let initial_hash = *blake3::hash(initial).as_bytes();
    let mut simulation = Simulation::restore(initial, content)?;
    h.finish()?;
    let mut chain = blake3::Hasher::new();
    chain.update(&header);
    drop(header);
    let mut frames = 0;
    loop {
        let bytes = read_block(&mut source, FRAME_LIMIT)?;
        let mut r = Reader::new(&bytes, b"FLRF\x01\0\0\0")?;
        let tag = r.byte()?;
        let tick = r.u64()?;
        match tag {
            0 => {
                if tick != simulation.state.tick + 1 || frames >= MAX_REPLAY_TICKS {
                    return Err("replay tick is out of sequence".into());
                }
                let count = r.u32()? as usize;
                if count > MAX_FRAME_INPUTS {
                    return Err("replay input count exceeds limit".into());
                }
                let mut inputs = Vec::with_capacity(count);
                let mut total = 0;
                for _ in 0..count {
                    let data = r.bytes(MAX_INPUT)?;
                    total += data.len();
                    if total > MAX_FRAME_BYTES {
                        return Err("replay input bytes exceed limit".into());
                    }
                    inputs.push(Input::decode(data)?);
                }
                r.finish()?;
                simulation
                    .step(content, &inputs)
                    .map_err(|e| format!("tick {tick}: {e}"))?;
                chain.update(&bytes);
                frames += 1;
            }
            1 => {
                if tick != simulation.state.tick {
                    return Err("replay conclusion tick differs".into());
                }
                let expected = digest(&mut r)?;
                let winner = r.byte()? as i8;
                let transcript = digest(&mut r)?;
                r.finish()?;
                if transcript != *chain.finalize().as_bytes() {
                    return Err("replay input digest differs".into());
                }
                let actual = hash(&simulation)?;
                if actual != expected || winner != simulation.state.victory.winner {
                    return Err("replay conclusion differs".into());
                }
                let mut extra = [0];
                if source.read(&mut extra).map_err(|e| e.to_string())? != 0 {
                    return Err("trailing replay data".into());
                }
                return Ok(Verification {
                    simulation,
                    frames,
                    state_hash: actual,
                    initial_hash,
                });
            }
            _ => return Err("unknown replay record".into()),
        }
    }
}
