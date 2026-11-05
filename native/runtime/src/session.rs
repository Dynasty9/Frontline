//! A running match owns its state and input history; adapters can only observe it.
use crate::{
    content::Content,
    replay::{self, Playback, Recorder},
    simulation::{Frame, Input, Simulation},
};
use serde_json::{json, Value};
use std::io::{Read, Seek, Write};

pub struct Session<R: Read, W: Write> {
    timeline: Timeline<R, W>,
}

enum Timeline<R: Read, W: Write> {
    Live(Recorder<W>),
    Replay { playback: Playback<R>, end: u64 },
}
impl<R: Read, W: Write> Session<R, W> {
    pub fn record(output: W, simulation: Simulation, content: &Content) -> Result<Self, String> {
        Ok(Self {
            timeline: Timeline::Live(Recorder::new(output, simulation, content)?),
        })
    }
    pub fn play(mut source: R, content: &Content) -> Result<Self, String>
    where
        R: Seek,
    {
        let end = replay::declared_tick(&mut source)?;
        source.rewind().map_err(|e| e.to_string())?;
        let playback = Playback::new(source, content)?;
        if end < playback.initial_tick() || end - playback.initial_tick() > replay::MAX_REPLAY_TICKS
        {
            return Err("invalid replay duration".into());
        }
        Ok(Self {
            timeline: Timeline::Replay { playback, end },
        })
    }
    pub fn simulation(&self) -> &Simulation {
        match &self.timeline {
            Timeline::Live(recording) => recording.simulation(),
            Timeline::Replay { playback, .. } => playback.simulation(),
        }
    }
    pub fn enable_profiling(&mut self, enabled: bool) {
        match &mut self.timeline {
            Timeline::Live(recording) => recording.enable_profiling(enabled),
            Timeline::Replay { playback, .. } => playback.enable_profiling(enabled),
        }
    }
    pub fn is_replay(&self) -> bool {
        matches!(&self.timeline, Timeline::Replay { .. })
    }
    pub fn complete(&self) -> bool {
        matches!(&self.timeline, Timeline::Replay { playback, .. } if playback.verified())
    }
    pub fn status(&self) -> Value {
        match &self.timeline {
            Timeline::Live(_) => Value::Null,
            Timeline::Replay { playback, end } => json!({
                "position": (playback.simulation().state.tick - playback.initial_tick()) as f64 / 60.,
                "duration": (end - playback.initial_tick()) as f64 / 60.,
                "verified": playback.verified(),
                "concluded": playback.verified() && playback.simulation().state.victory.winner >= 0,
            }),
        }
    }
    pub fn step(&mut self, content: &Content, inputs: &[Input]) -> Result<Option<Frame>, String> {
        match &mut self.timeline {
            Timeline::Live(recording) => recording.step(content, inputs).map(Some),
            Timeline::Replay { playback, end } => {
                if !inputs.is_empty() {
                    return Err("replay cannot admit live commands".into());
                }
                let frame = playback.step(content)?;
                let tick = playback.simulation().state.tick;
                if tick > *end || (frame.is_none() && tick != *end) {
                    return Err("replay duration differs".into());
                }
                Ok(frame)
            }
        }
    }
    pub fn seek_target(&self, offset: u64) -> Result<u64, String> {
        match &self.timeline {
            Timeline::Replay { playback, end } => {
                let target = playback.initial_tick().saturating_add(offset).min(*end);
                if target < playback.simulation().state.tick {
                    return Err("backward seeking requires a fresh replay".into());
                }
                Ok(target)
            }
            Timeline::Live(_) => Err("only recordings can seek".into()),
        }
    }
    pub fn at_end(&self) -> bool {
        matches!(&self.timeline, Timeline::Replay { playback, end } if playback.simulation().state.tick == *end)
    }
    pub fn finish(self) -> Result<Option<W>, String> {
        match self.timeline {
            Timeline::Live(recording) => recording.finish().map(|(output, _)| Some(output)),
            Timeline::Replay { .. } => Ok(None),
        }
    }
}
