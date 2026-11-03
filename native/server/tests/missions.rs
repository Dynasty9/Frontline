#[path = "fixtures/missions.rs"]
mod fixture;
#[path = "fixtures/numeric.rs"]
mod numeric;
use frontline_server::{
    content::Content,
    mission::Mission,
    replay::{verify, Recorder},
    simulation::{Input, Simulation},
};

#[test]
#[ignore = "manual full mission from an authored initial state, with independent replay verification"]
fn natural_mission_reaches_and_verifies_its_conclusion() {
    use std::{
        fs::File,
        io::{BufReader, BufWriter, Read, Write},
    };
    let initial = std::env::var("FL_PLAYTHROUGH_INITIAL").expect("authored mission initial path");
    let output = std::env::var("FL_PLAYTHROUGH_RECORDING").expect("new recording path");
    let mut bytes = vec![];
    File::open(initial)
        .unwrap()
        .take(frontline_server::simulation::MAX_STATE as u64 + 1)
        .read_to_end(&mut bytes)
        .unwrap();
    let content = Content::bundled().unwrap();
    let mut simulation = frontline_server::initial::load(&bytes, &content).unwrap();
    let mission = simulation
        .mission
        .as_ref()
        .expect("initial state must enable a mission");
    assert!(
        mission.autopilot,
        "The playthrough must use the real mission autopilot"
    );
    let key = mission.kind.key().to_owned();
    let file = File::options()
        .write(true)
        .create_new(true)
        .open(&output)
        .unwrap();
    let mut recording = Recorder::new(BufWriter::new(file), &simulation, &content).unwrap();
    for _ in 0..108_000 {
        if simulation.state.victory.winner >= 0 {
            break;
        }
        recording.step(&mut simulation, &content, &[]).unwrap();
        if simulation.state.tick % 3600 == 0 {
            let objectives: Vec<_> = simulation
                .mission
                .as_ref()
                .unwrap()
                .objectives
                .iter()
                .map(|o| (&o.id, o.state))
                .collect();
            println!(
                "MISSION_PROGRESS mission={key} seconds={} objectives={objectives:?}",
                simulation.state.tick / 60
            );
        }
    }
    recording.finish(&simulation).unwrap().flush().unwrap();
    let verified = verify(BufReader::new(File::open(output).unwrap()), &content).unwrap();
    assert_eq!(
        verified.simulation.checkpoint().unwrap(),
        simulation.checkpoint().unwrap()
    );
    println!(
        "MISSION_VERIFIED mission={key} tick={} winner={} state={}",
        simulation.state.tick,
        simulation.state.victory.winner,
        blake3::Hash::from(verified.state_hash)
    );
    if simulation.state.victory.winner < 0 {
        for objective in &simulation.mission.as_ref().unwrap().objectives {
            println!("UNFINISHED_OBJECTIVE {objective:?}");
        }
        for actor in simulation.state.field.actors.iter() {
            if let frontline_core::actors::Actor::Vehicle(v) = actor {
                println!(
                    "REMAINING_VEHICLE id={} kind={} hp={} position={:?} target={} ammo={} destination={:?} passengers={:?}",
                    v.id, v.kind, v.hp, v.position, v.target, v.atgm_left, v.path_destination, v.passengers
                );
            }
        }
    }
    assert!(
        simulation.state.victory.winner >= 0,
        "Mission did not conclude within 30 simulated minutes; recording retained"
    );
}

#[test]
fn mission_callbacks_reach_every_scripted_reinforcement_and_conclusion() {
    let content = Content::bundled().unwrap();
    for (key, chain) in [
        ("bridgehead", vec!["village", "bridge", "hold"]),
        ("beachhead", vec!["land", "aa", "harbour", "hold"]),
        ("skyhook", vec!["deliver", "column"]),
        ("ambush", vec!["position", "depart", "convoy", "exfil"]),
        ("kingpin", vec!["checkpoint", "hvt", "exfil"]),
    ] {
        let mut a = fixture::map(&content);
        a.enable_mission(key, false, &content).unwrap();
        a.mission.as_mut().unwrap().autopilot = false;
        let mut commands = vec![];
        for id in chain {
            // Objective conditions have separate tests; exercise the actual callback graph here.
            let m = a.mission.as_mut().unwrap();
            let o = m
                .objectives
                .iter_mut()
                .find(|o| o.id == id)
                .unwrap_or_else(|| panic!("{key}: missing {id}"));
            o.goal = frontline_server::mission::Goal::Timer;
            o.seconds = 0.;
            o.state = 1;
            for _ in 0..31 {
                commands.extend(
                    a.step(&content, &[])
                        .unwrap_or_else(|e| panic!("{key}/{id}: {e}"))
                        .commands,
                );
            }
            if key == "beachhead" && id == "aa" {
                let helicopter = a
                    .state
                    .field
                    .actors
                    .iter()
                    .find_map(|a| match a {
                        frontline_core::actors::Actor::Vehicle(v) if v.kind == "ghosthawk" => {
                            Some(v)
                        }
                        _ => None,
                    })
                    .unwrap();
                assert_eq!(
                    helicopter.passengers.len(),
                    content.members["rifle_squad"].len()
                );
            }
            if a.mission.as_ref().unwrap().over == 0 {
                // Run due reinforcements before the next objective in the chain.
                a.state.tick += if key == "skyhook" { 8460 } else { 5100 };
                a.state.field.now = a.state.tick as f64 / 60.;
                commands.extend(
                    a.step(&content, &[])
                        .unwrap_or_else(|e| panic!("{key}/{id}: {e}"))
                        .commands,
                );
            }
        }
        assert_eq!(a.mission.as_ref().unwrap().over, 1, "{key}");
        assert_eq!(
            a.state.victory.winner,
            a.mission.as_ref().unwrap().side,
            "{key}"
        );
        assert!(!commands.is_empty());
        let saved = a.checkpoint().unwrap();
        assert_eq!(
            saved,
            Simulation::restore(&saved, &content)
                .unwrap()
                .checkpoint()
                .unwrap()
        );
    }
}

#[test]
fn checkpointed_final_objective_and_deadline_recompute_the_winner() {
    let c = Content::bundled().unwrap();
    for win in [true, false] {
        let mut a = fixture::map(&c);
        a.enable_mission("kingpin", false, &c).unwrap();
        let mission = a.mission.as_mut().unwrap();
        if win {
            for o in &mut mission.objectives {
                o.state = 2;
            }
            let exfil = mission
                .objectives
                .iter_mut()
                .find(|o| o.id == "exfil")
                .unwrap();
            exfil.state = 1;
            exfil.done = 31;
        } else {
            mission.deadline = 0.01;
        }
        let mut recorder = Recorder::new(Vec::new(), &a, &c).unwrap();
        recorder.step(&mut a, &c, &[]).unwrap();
        assert_eq!(a.mission.as_ref().unwrap().over, if win { 1 } else { 2 });
        assert_eq!(a.state.victory.winner, if win { 0 } else { 1 });
        let bytes = recorder.finish(&a).unwrap();
        let result = verify(bytes.as_slice(), &c).unwrap();
        assert_eq!(
            result.simulation.state.victory.winner,
            a.state.victory.winner
        );
        assert_eq!(
            result.simulation.checkpoint().unwrap(),
            a.checkpoint().unwrap()
        );
    }
}

#[test]
fn all_five_missions_advance_scripted_events_and_resume_without_godot() {
    let content = Content::bundled().unwrap();
    for key in ["bridgehead", "beachhead", "skyhook", "ambush", "kingpin"] {
        let mut a = fixture::map(&content);
        a.enable_mission(key, true, &content)
            .unwrap_or_else(|e| panic!("{key}: {e}"));
        assert!(!a.mission.as_ref().unwrap().objectives.is_empty());
        // Exercise timers becoming due in insertion order before the next objective evaluation.
        a.state.field.now = 150.;
        a.state.tick = 9000;
        if key == "ambush" {
            a.mission
                .as_mut()
                .unwrap()
                .objectives
                .iter_mut()
                .find(|o| o.id == "depart")
                .unwrap()
                .progress = 99.5;
        }
        let initial = a.checkpoint().unwrap();
        let mut b = Simulation::restore(&initial, &content).unwrap();
        let mut recording = Recorder::new(Vec::new(), &a, &content).unwrap();
        let before = a.state.field.actors.entities().next_id();
        let mut messages = 0;
        for tick in 0..180 {
            let frame = recording
                .step(&mut a, &content, &[])
                .unwrap_or_else(|e| panic!("{key}/{tick}: {e}"));
            messages += frame.commands.len();
            assert_eq!(frame, b.step(&content, &[]).unwrap(), "{key}/{tick}");
            if tick == 90 {
                b = Simulation::restore(&b.checkpoint().unwrap(), &content).unwrap();
            }
        }
        if matches!(key, "skyhook" | "ambush") {
            assert!(
                a.state.field.actors.entities().next_id() > before,
                "{key} reinforcement did not spawn"
            );
        }
        assert!(messages > 0, "{key} autopilot did not give orders");
        assert_eq!(a.checkpoint().unwrap(), b.checkpoint().unwrap(), "{key}");
        numeric::golden(&format!("mission_{key}"), &a);
        let bytes = recording.finish(&a).unwrap();
        let replay = verify(bytes.as_slice(), &content).unwrap();
        assert_eq!(
            a.checkpoint().unwrap(),
            replay.simulation.checkpoint().unwrap(),
            "{key}"
        );
    }
}

#[test]
fn mission_join_departure_and_reclaim_keep_autopilot_and_force_ownership_consistent() {
    let c = Content::bundled().unwrap();
    let mut a = fixture::map(&c);
    a.enable_mission("bridgehead", false, &c).unwrap();
    let mut rec = Recorder::new(Vec::new(), &a, &c).unwrap();
    let join = |peer, reclaim| Input::Join {
        peer,
        team: 0,
        name: format!("Player {peer}"),
        reclaim,
    };
    rec.step(&mut a, &c, &[join(7, None)]).unwrap();
    assert!(!a.mission.as_ref().unwrap().autopilot);
    rec.step(&mut a, &c, &[join(8, None)]).unwrap();
    assert!(a.state.field.squads.iter().any(|q| q.owner == 8));
    rec.step(
        &mut a,
        &c,
        &[Input::Leave { peer: 7 }, Input::Leave { peer: 8 }],
    )
    .unwrap();
    assert!(a.mission.as_ref().unwrap().autopilot);
    assert!(a.commanders.is_empty());
    rec.step(&mut a, &c, &[join(11, Some(7))]).unwrap();
    assert_eq!(a.mission.as_ref().unwrap().owners, vec![11]);
    assert!(!a.mission.as_ref().unwrap().autopilot);
    assert!(a
        .state
        .field
        .squads
        .iter()
        .filter(|q| q.team == 0)
        .all(|q| q.owner == 11));
    let bytes = rec.finish(&a).unwrap();
    assert_eq!(
        a.checkpoint().unwrap(),
        verify(bytes.as_slice(), &c)
            .unwrap()
            .simulation
            .checkpoint()
            .unwrap()
    );
}

#[test]
fn mission_checkpoints_reject_cross_mission_callbacks_and_inconsistent_conclusions() {
    let c = Content::bundled().unwrap();
    let mut a = fixture::map(&c);
    a.enable_mission("bridgehead", true, &c).unwrap();
    let m = a.mission.as_mut().unwrap();
    let bytes = m.checkpoint().unwrap();
    assert!(Mission::restore(&bytes[..bytes.len() - 1]).is_err());
    let mut trailing = bytes.clone();
    trailing.push(0);
    assert!(Mission::restore(&trailing).is_err());
    m.objectives[0].done = 31;
    assert!(m.checkpoint().is_err());
    *m = Mission::restore(&bytes).unwrap();
    a.state.victory.winner = 0;
    assert!(a.checkpoint().is_err());
    a.state.victory.winner = -1;
    let before = a.checkpoint().unwrap();
    assert!(a
        .step(
            &c,
            &[Input::Join {
                peer: 9,
                team: 1,
                name: "Intruder".into(),
                reclaim: None
            }]
        )
        .is_err());
    assert_eq!(before, a.checkpoint().unwrap());
}
