use frontline_runtime::{
    content::Content,
    initial,
    replay::{verify, Recorder},
};
use serde_json::json;

#[path = "fixtures/initial.rs"]
mod fixture;
use fixture::{encode, map};

#[test]
fn authored_initial_state_preserves_units_randomness_ledger_and_replay() {
    let c = Content::bundled().unwrap();
    let original = map(&c);
    let bytes = encode(&original, |_| {});
    let a = initial::load(&bytes, &c).unwrap();
    assert_eq!(
        original.state.checkpoint().unwrap(),
        a.state.checkpoint().unwrap()
    );
    assert_eq!(a.landmarks[0].kind, "woods");
    assert_eq!(a.names[&7], "Commander");
    assert_eq!(
        serde_json::from_slice::<serde_json::Value>(&a.presentation).unwrap()["mood"],
        "rain"
    );
    let mut recorder = Recorder::new(Vec::new(), a, &c).unwrap();
    for _ in 0..60 {
        recorder.step(&c, &[]).unwrap();
    }
    let saved = recorder.simulation().checkpoint().unwrap();
    let (bytes, _a) = recorder.finish().unwrap();
    assert_eq!(
        saved,
        verify(bytes.as_slice(), &c)
            .unwrap()
            .simulation
            .checkpoint()
            .unwrap()
    );
}

#[test]
fn malformed_initial_state_cannot_silently_drop_rules_or_change_content() {
    let c = Content::bundled().unwrap();
    let a = map(&c);
    let bytes = encode(&a, |_| {});
    let mut wrong = bytes.clone();
    wrong[12] ^= 1;
    assert!(initial::load(&wrong, &c).is_err());
    assert!(initial::load(&bytes[..bytes.len() - 1], &c).is_err());
    let mut extra = bytes.clone();
    extra.push(0);
    assert!(initial::load(&extra, &c).is_err());
    for (key, value) in [
        ("players", json!([[7, 0, "First"], [7, 1, "Other"]])),
        ("upgrades", json!([["imaginary"], []])),
        ("support", json!([[["imaginary", 0]], []])),
        ("ai", json!([2])),
        ("mission", json!("imaginary")),
        ("presentation", json!([])),
    ] {
        assert!(
            initial::load(&encode(&a, |m| m[key] = value.clone()), &c).is_err(),
            "{key}"
        );
    }
}
