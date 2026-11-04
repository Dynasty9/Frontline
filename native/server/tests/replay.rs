#[path = "../../runtime/tests/fixtures/replay.rs"]
mod fixture;
use fixture::{battle, inputs};
use frontline_runtime::{content::Content, replay::Recorder};

#[test]
fn independent_verifier_process_reruns_a_recording_and_rejects_a_bad_conclusion() {
    let c = Content::bundled().unwrap();
    let mut s = battle(&c);
    let mut rec = Recorder::new(Vec::new(), &s, &c).unwrap();
    for tick in 0..125 {
        rec.step(&mut s, &c, &inputs(tick)).unwrap();
    }
    let mut bytes = rec.finish(&s).unwrap();
    let path = std::env::temp_dir().join(format!(
        "frontline-replay-{}-{}.flr",
        std::process::id(),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    let mut file = std::fs::OpenOptions::new()
        .write(true)
        .create_new(true)
        .open(&path)
        .unwrap();
    std::io::Write::write_all(&mut file, &bytes).unwrap();
    drop(file);
    let output = std::process::Command::new(env!("CARGO_BIN_EXE_frontline-server"))
        .arg("verify")
        .arg(&path)
        .output()
        .unwrap();
    assert!(
        output.status.success(),
        "{}",
        String::from_utf8_lossy(&output.stderr)
    );
    assert!(String::from_utf8_lossy(&output.stdout).contains("REPLAY_VERIFIED tick=125 frames=125"));
    let last = bytes.len() - 1;
    bytes[last] ^= 1;
    std::fs::write(&path, bytes).unwrap();
    let bad = std::process::Command::new(env!("CARGO_BIN_EXE_frontline-server"))
        .arg("verify")
        .arg(&path)
        .output()
        .unwrap();
    std::fs::remove_file(path).unwrap();
    assert!(!bad.status.success());
    assert!(!String::from_utf8_lossy(&bad.stdout).contains("REPLAY_VERIFIED"));
}
