use frontline_server::{content::Content, initial, replay, simulation::MAX_STATE};
use std::{
    fs::File,
    io::{BufReader, Read, Write},
    path::PathBuf,
};

const USAGE: &str = "usage: frontline-server verify RECORDING | prepare INITIAL CHECKPOINT | run INITIAL RECORDING TICKS";

fn read_initial(path: PathBuf) -> Result<Vec<u8>, String> {
    let file = File::open(path).map_err(|e| e.to_string())?;
    if file.metadata().map_err(|e| e.to_string())?.len() > MAX_STATE as u64 {
        return Err("initial battlefield exceeds limit".into());
    }
    let mut data = Vec::new();
    file.take(MAX_STATE as u64 + 1)
        .read_to_end(&mut data)
        .map_err(|e| e.to_string())?;
    Ok(data)
}

fn run() -> Result<(), String> {
    let mut args = std::env::args_os().skip(1);
    let command = args.next().ok_or(USAGE)?;
    match command.to_str() {
        Some("verify") => {
            let path = PathBuf::from(args.next().ok_or("missing replay path")?);
            if args.next().is_some() {
                return Err("unexpected verifier argument".into());
            }
            let content = Content::bundled()?;
            let file = File::open(path).map_err(|e| e.to_string())?;
            let verified = replay::verify(BufReader::new(file), &content)?;
            let state = &verified.simulation.state;
            println!(
                "REPLAY_VERIFIED tick={} frames={} winner={} concluded={} initial={} state={} engine={}",
                state.tick,
                verified.frames,
                state.victory.winner,
                state.victory.winner >= 0,
                blake3::Hash::from(verified.initial_hash),
                blake3::Hash::from(verified.state_hash),
                frontline_server::ENGINE_ID
            );
            Ok(())
        }
        Some("prepare" | "run") => {
            let path = PathBuf::from(args.next().ok_or("missing initial battlefield")?);
            let output = PathBuf::from(args.next().ok_or("missing output path")?);
            let ticks: u64 = if command == "run" {
                args.next()
                    .and_then(|s| s.to_str().and_then(|s| s.parse().ok()))
                    .filter(|n| (1..=5_184_000).contains(n))
                    .ok_or("invalid tick count")?
            } else {
                0
            };
            if args.next().is_some() {
                return Err("unexpected server argument".into());
            }
            let content = Content::bundled()?;
            let mut simulation = initial::load(&read_initial(path)?, &content)?;
            // Never replace an existing recording when a launch command is retried.
            let mut file = File::options()
                .write(true)
                .create_new(true)
                .open(output)
                .map_err(|e| e.to_string())?;
            if ticks == 0 {
                file.write_all(&simulation.checkpoint()?)
                    .map_err(|e| e.to_string())?;
                println!(
                    "SIMULATION_PREPARED entities={} squads={} mission={} engine={}",
                    simulation.state.field.actors.entities().len(),
                    simulation.state.field.squads.len(),
                    simulation.mission.as_ref().map_or("", |m| m.kind.key()),
                    frontline_server::ENGINE_ID
                );
            } else {
                let mut recording = replay::Recorder::new(file, &simulation, &content)?;
                for _ in 0..ticks {
                    recording.step(&mut simulation, &content, &[])?;
                }
                file = recording.finish(&simulation)?;
                println!(
                    "SIMULATION_RUN ticks={} winner={}",
                    simulation.state.tick, simulation.state.victory.winner
                );
            }
            file.sync_all().map_err(|e| e.to_string())?;
            Ok(())
        }
        _ => Err(USAGE.into()),
    }
}
fn main() {
    if let Err(error) = run() {
        eprintln!("frontline-server: {error}");
        std::process::exit(1);
    }
}
