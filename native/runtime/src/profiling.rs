//! Optional measurements never enter authoritative state or replay.
use std::{collections::BTreeMap, time::Instant};

pub struct TickProfile {
    at: Instant,
    infantry_at: Option<Instant>,
    pub phases: BTreeMap<&'static str, f64>,
}
impl Default for TickProfile {
    fn default() -> Self {
        Self {
            at: Instant::now(),
            infantry_at: None,
            phases: BTreeMap::new(),
        }
    }
}
impl TickProfile {
    pub fn begin(&mut self) {
        self.phases.clear();
        self.infantry_at = None;
        self.at = Instant::now();
    }
    pub fn mark(&mut self, phase: &'static str) {
        let now = Instant::now();
        if phase == "infantry_begin" {
            self.infantry_at = Some(now);
            self.at = now;
            return;
        }
        let start = if phase == "infantry" {
            self.infantry_at.take().unwrap_or(self.at)
        } else {
            self.at
        };
        *self.phases.entry(phase).or_default() += now.duration_since(start).as_secs_f64() * 1000.;
        self.at = now;
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::time::Duration;
    #[test]
    fn repeated_infantry_phases_accumulate_inside_the_whole_pass() {
        let mut timing = TickProfile::default();
        timing.begin();
        timing.mark("infantry_begin");
        timing.at -= Duration::from_millis(1);
        timing.infantry_at = Some(timing.at);
        timing.mark("infantry_status");
        let first = timing.phases["infantry_status"];
        timing.mark("infantry_status");
        assert!(timing.phases["infantry_status"] >= first);
        timing.mark("infantry_finish");
        timing.mark("infantry");
        assert!(
            timing.phases["infantry"]
                >= timing.phases["infantry_status"] + timing.phases["infantry_finish"]
        );
        assert!(!timing.phases.contains_key("infantry_begin"));
        timing.begin();
        assert!(timing.phases.is_empty() && timing.infantry_at.is_none());
    }
}
