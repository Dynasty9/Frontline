use frontline_server::{content::Content, replay};
use std::{fs::File, io::BufReader, path::PathBuf};

fn run() -> Result<(), String> {
    let mut args = std::env::args_os().skip(1);
    let command = args
        .next()
        .ok_or("usage: frontline-server verify RECORDING")?;
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
        _ => Err("usage: frontline-server verify RECORDING".into()),
    }
}
fn main() {
    if let Err(error) = run() {
        eprintln!("frontline-server: {error}");
        std::process::exit(1);
    }
}
