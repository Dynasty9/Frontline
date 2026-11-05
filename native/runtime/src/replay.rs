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

/// Owns the live state until its recording closes. Observations cannot bypass recorded inputs.
/// ```compile_fail
/// fn edit<W: std::io::Write>(recording: &mut frontline_runtime::replay::Recorder<W>) {
///     recording.simulation().state.field.rng.randi();
/// }
/// ```
pub struct Recorder<W: Write> {
    simulation: Simulation,
    output: W,
    last_tick: u64,
    failed: bool,
    frames: u64,
    chain: blake3::Hasher,
}
impl<W: Write> Recorder<W> {
    pub fn new(mut output: W, simulation: Simulation, content: &Content) -> Result<Self, String> {
        let mut h = Writer::new(b"FLRH\x01\0\0\0");
        h.bytes(crate::ENGINE_ID.as_bytes());
        h.bytes(&content.digest());
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
            failed: false,
            simulation,
            frames: 0,
            chain,
        })
    }
    pub fn step(&mut self, content: &Content, inputs: &[Input]) -> Result<Frame, String> {
        if self.failed {
            return Err("recording previously failed".into());
        }
        self.failed = true;
        let result = self.step_inner(content, inputs);
        self.failed = result.is_err();
        result
    }
    fn step_inner(&mut self, content: &Content, inputs: &[Input]) -> Result<Frame, String> {
        let simulation = &mut self.simulation;
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
    pub(crate) fn enable_profiling(&mut self, enabled: bool) {
        self.simulation.profile = enabled.then(Default::default);
    }
    pub fn simulation(&self) -> &Simulation {
        &self.simulation
    }
    pub fn finish(mut self) -> Result<(W, Simulation), String> {
        if self.failed {
            return Err("recording previously failed".into());
        }
        let simulation = &self.simulation;
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
        Ok((self.output, self.simulation))
    }
}
pub struct Verification {
    pub simulation: Simulation,
    pub frames: u64,
    pub state_hash: [u8; 32],
    pub initial_hash: [u8; 32],
}

/// The verifier and visual player consume exactly the same bounded input stream.
pub struct Playback<R: Read> {
    simulation: Simulation,
    source: R,
    chain: blake3::Hasher,
    frames: u64,
    initial_tick: u64,
    last_tick: u64,
    failed: bool,
    initial_hash: [u8; 32],
    state_hash: Option<[u8; 32]>,
}
impl<R: Read> Playback<R> {
    pub fn new(mut source: R, content: &Content) -> Result<Self, String> {
        let header = read_block(&mut source, HEADER_LIMIT)?;
        let mut h = Reader::new(&header, b"FLRH\x01\0\0\0")?;
        if h.bytes(64)? != crate::ENGINE_ID.as_bytes() {
            return Err("incompatible replay simulation build".into());
        }
        if digest(&mut h)? != content.digest() {
            return Err("incompatible replay content".into());
        }
        let initial = h.bytes(MAX_STATE)?;
        let initial_hash = *blake3::hash(initial).as_bytes();
        let simulation = Simulation::restore(initial, content)?;
        h.finish()?;
        let mut chain = blake3::Hasher::new();
        chain.update(&header);
        let tick = simulation.state.tick;
        Ok(Self {
            source,
            chain,
            frames: 0,
            initial_tick: tick,
            last_tick: tick,
            failed: false,
            initial_hash,
            state_hash: None,
            simulation,
        })
    }
    pub(crate) fn enable_profiling(&mut self, enabled: bool) {
        self.simulation.profile = enabled.then(Default::default);
    }
    pub fn simulation(&self) -> &Simulation {
        &self.simulation
    }
    pub fn initial_tick(&self) -> u64 {
        self.initial_tick
    }
    pub fn verified(&self) -> bool {
        self.state_hash.is_some()
    }
    pub fn step(&mut self, content: &Content) -> Result<Option<Frame>, String> {
        if self.failed {
            return Err("playback previously failed".into());
        }
        self.failed = true;
        let result = self.step_inner(content);
        self.failed = result.is_err();
        result
    }
    fn step_inner(&mut self, content: &Content) -> Result<Option<Frame>, String> {
        if self.verified() {
            return Ok(None);
        }
        let simulation = &mut self.simulation;
        let bytes = read_block(&mut self.source, FRAME_LIMIT)?;
        let mut r = Reader::new(&bytes, b"FLRF\x01\0\0\0")?;
        let tag = r.byte()?;
        let tick = r.u64()?;
        match tag {
            0 => {
                if tick != self.last_tick + 1 || self.frames >= MAX_REPLAY_TICKS {
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
                let frame = simulation
                    .step(content, &inputs)
                    .map_err(|e| format!("tick {tick}: {e}"))?;
                self.chain.update(&bytes);
                self.frames += 1;
                self.last_tick = tick;
                Ok(Some(frame))
            }
            1 => {
                if tick != self.last_tick {
                    return Err("replay conclusion tick differs".into());
                }
                let expected = digest(&mut r)?;
                let winner = r.byte()? as i8;
                let transcript = digest(&mut r)?;
                r.finish()?;
                if transcript != *self.chain.finalize().as_bytes() {
                    return Err("replay input digest differs".into());
                }
                let actual = hash(simulation)?;
                if actual != expected || winner != simulation.state.victory.winner {
                    return Err("replay conclusion differs".into());
                }
                let mut extra = [0];
                if self.source.read(&mut extra).map_err(|e| e.to_string())? != 0 {
                    return Err("trailing replay data".into());
                }
                self.state_hash = Some(actual);
                Ok(None)
            }
            _ => Err("unknown replay record".into()),
        }
    }
}

/// A footer supplies a timeline length, never a verification result.
pub fn declared_tick(source: &mut (impl Read + std::io::Seek)) -> Result<u64, String> {
    // The fixed conclusion block includes two length-prefixed 32-byte digests.
    const FOOTER_BYTES: i64 = 4 + 8 + 1 + 8 + 36 + 1 + 36;
    source
        .seek(std::io::SeekFrom::End(-FOOTER_BYTES))
        .map_err(|e| format!("incomplete replay: {e}"))?;
    let bytes = read_block(source, FOOTER_BYTES as usize - 4)?;
    let mut r = Reader::new(&bytes, b"FLRF\x01\0\0\0")?;
    if r.byte()? != 1 {
        return Err("missing replay conclusion".into());
    }
    let tick = r.u64()?;
    digest(&mut r)?;
    if !(-1..=1).contains(&(r.byte()? as i8)) {
        return Err("invalid replay winner".into());
    }
    digest(&mut r)?;
    r.finish()?;
    source.rewind().map_err(|e| e.to_string())?;
    Ok(tick)
}

pub fn verify(source: impl Read, content: &Content) -> Result<Verification, String> {
    let mut playback = Playback::new(source, content)?;
    while playback.step(content)?.is_some() {}
    Ok(Verification {
        simulation: playback.simulation,
        frames: playback.frames,
        state_hash: playback.state_hash.ok_or("missing replay conclusion")?,
        initial_hash: playback.initial_hash,
    })
}
