use frontline_server::simulation::Simulation;

pub fn golden(name: &str, simulation: &Simulation) {
    // Source fingerprints differ as code evolves; compare the actual deterministic state.
    let mut hash = blake3::Hasher::new();
    hash.update(&simulation.state.checkpoint().unwrap());
    for commander in &simulation.commanders {
        hash.update(&commander.checkpoint().unwrap());
    }
    if let Some(mission) = &simulation.mission {
        hash.update(&mission.checkpoint().unwrap());
    }
    let actual = hash.finalize().to_hex().to_string();
    let path = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join(format!(
        "tests/numeric_v{}/{name}.txt",
        frontline_core::NUMERIC_VERSION
    ));
    if std::env::var_os("FL_WRITE_NUMERIC_GOLDENS").is_some() {
        assert!(
            std::env::var_os("CI").is_none(),
            "CI must never rewrite goldens"
        );
        std::fs::create_dir_all(path.parent().unwrap()).unwrap();
        std::fs::write(&path, &actual).unwrap();
    }
    assert_eq!(actual, std::fs::read_to_string(path).unwrap(), "{name}");
}
