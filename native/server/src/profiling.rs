//! Optional wall-clock measurements never enter authoritative state or replay.
use crate::simulation::Simulation;
use serde_json::{json, Value};
use std::{
    collections::BTreeMap,
    fs::File,
    io::Write,
    path::PathBuf,
    time::{Duration, Instant},
};

pub struct TickProfile {
    at: Instant,
    pub phases: BTreeMap<&'static str, f64>,
}
impl Default for TickProfile {
    fn default() -> Self {
        Self {
            at: Instant::now(),
            phases: BTreeMap::new(),
        }
    }
}
impl TickProfile {
    pub fn begin(&mut self) {
        self.phases.clear();
        self.at = Instant::now();
    }
    pub fn mark(&mut self, phase: &'static str) {
        let now = Instant::now();
        self.phases
            .insert(phase, now.duration_since(self.at).as_secs_f64() * 1000.);
        self.at = now;
    }
}

pub struct Profile {
    path: PathBuf,
    warmup: Duration,
    duration: Duration,
    began: Option<Instant>,
    ticks: Vec<f64>,
    simulation: Vec<f64>,
    phases: BTreeMap<&'static str, Vec<f64>>,
    paths: [u64; 5],
}
impl Profile {
    pub fn decode(d: &Value) -> Result<Option<Self>, String> {
        if d.is_null() {
            return Ok(None);
        }
        let seconds = |key: &str, minimum: f64| {
            d[key]
                .as_f64()
                .filter(|v| v.is_finite() && (minimum..=3600.).contains(v))
                .map(Duration::from_secs_f64)
                .ok_or_else(|| format!("invalid profile {key}"))
        };
        Ok(Some(Self {
            path: d["path"]
                .as_str()
                .filter(|s| !s.is_empty() && !s.contains('\0'))
                .ok_or("invalid profile path")?
                .into(),
            warmup: seconds("warmup", 0.)?,
            duration: seconds("duration", 1.)?,
            began: None,
            ticks: vec![],
            simulation: vec![],
            phases: BTreeMap::new(),
            paths: [0; 5],
        }))
    }
    pub fn start(&mut self) {
        self.began.get_or_insert_with(Instant::now);
    }
    pub fn record(
        &mut self,
        tick: Instant,
        simulation_ms: f64,
        state: &Simulation,
    ) -> Result<bool, String> {
        let Some(began) = self.began else {
            return Ok(false);
        };
        let elapsed = tick.saturating_duration_since(began);
        if elapsed < self.warmup {
            return Ok(false);
        }
        if elapsed < self.warmup + self.duration {
            self.ticks.push(tick.elapsed().as_secs_f64() * 1000.);
            self.simulation.push(simulation_ms);
            if let Some(timing) = &state.profile {
                for (&name, &ms) in &timing.phases {
                    self.phases.entry(name).or_default().push(ms);
                }
            }
            if let Some(p) = &state.state.field.geometry.navigation.planner.profile {
                for (total, value) in self.paths.iter_mut().zip([
                    p.queries,
                    p.cache_hits,
                    p.failed,
                    p.routes,
                    p.expanded,
                ]) {
                    *total += value;
                }
                for (name, ms) in [
                    ("path_route", p.route_ms),
                    ("path_refine", p.refine_ms),
                    ("path_smooth", p.smooth_ms),
                ] {
                    self.phases.entry(name).or_default().push(ms);
                }
            }
            return Ok(false);
        }
        let projection: Vec<_> = self
            .ticks
            .iter()
            .zip(&self.simulation)
            .map(|(a, b)| a - b)
            .collect();
        let alive = state.state.field.actors.iter().filter(|a| matches!(a,
            frontline_core::actors::Actor::Soldier(s) if s.vitals.life == frontline_core::infantry_vitals::Life::Alive)).count();
        let shots: f64 = state
            .state
            .field
            .battle
            .sides
            .iter()
            .map(|s| s[frontline_core::battle_stats::SHOTS])
            .sum();
        let report = json!({"runtime":"rust", "tick_hz":60, "engine":crate::ENGINE_ID,
            "tick":state.state.tick, "entities":state.state.field.actors.entities().len(),
            "soldiers_alive":alive,"shots_since_start":shots,"duration_seconds":self.duration.as_secs_f64(),
            "ticks":samples(&self.ticks),"simulation":samples(&self.simulation),"projection":samples(&projection),
            "phases":self.phases.iter().map(|(name, times)|(*name,samples(times))).collect::<BTreeMap<_,_>>()});
        let mut report = report;
        report["path_searches"] = json!({"queries":self.paths[0],"cache_hits":self.paths[1],"failed":self.paths[2],"routes":self.paths[3],"expanded":self.paths[4]});
        let mut file = File::options()
            .write(true)
            .create_new(true)
            .open(&self.path)
            .map_err(|e| e.to_string())?;
        file.write_all(
            serde_json::to_string_pretty(&report)
                .map_err(|e| e.to_string())?
                .as_bytes(),
        )
        .map_err(|e| e.to_string())?;
        Ok(true)
    }
}

fn samples(values: &[f64]) -> Value {
    if values.is_empty() {
        return json!({"count":0});
    }
    let mut sorted = values.to_vec();
    sorted.sort_by(f64::total_cmp);
    let percentile = |p: f64| sorted[((sorted.len() as f64 * p).ceil() as usize).saturating_sub(1)];
    json!({"count":sorted.len(), "mean_ms":sorted.iter().sum::<f64>()/sorted.len() as f64,
        "p50_ms":percentile(0.5),"p95_ms":percentile(0.95),"p99_ms":percentile(0.99),
        "max_ms":sorted.last().unwrap(),"over_16_67_ms":sorted.iter().filter(|&&v|v>1000./60.).count()})
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn bounded_profile_and_tail_measurements() {
        assert!(Profile::decode(&json!({"path":"x", "warmup":-1,"duration":10})).is_err());
        assert!(Profile::decode(&json!({"path":"x", "warmup":0,"duration":3601})).is_err());
        assert!(
            Profile::decode(&json!({"path":"x", "warmup":0,"duration":10}))
                .unwrap()
                .is_some()
        );
        assert_eq!(samples(&[])["count"], 0);
        let s = samples(&[20., 1., 2., 3.]);
        assert_eq!(s["p50_ms"], 2.);
        assert_eq!(s["p99_ms"], 20.);
        assert_eq!(s["over_16_67_ms"], 1);
    }
}
