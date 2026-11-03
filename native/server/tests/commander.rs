use frontline_core as sim;
use frontline_server::{
    commander::Commander,
    content::Content,
    replay::{verify, Recorder},
    simulation::Simulation,
};
use sim::{actors::Actor, match_state::MatchState, vector::Vector3};

fn battle(content: &Content) -> Simulation {
    battle_on(content, false)
}
fn golden(name: &str, simulation: &Simulation) {
    let mut hash = blake3::Hasher::new();
    hash.update(&simulation.state.checkpoint().unwrap());
    for commander in &simulation.commanders {
        hash.update(&commander.checkpoint().unwrap());
    }
    let actual = hash.finalize().to_hex().to_string();
    let path = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join(format!(
        "tests/numeric_v{}/{name}.txt",
        sim::NUMERIC_VERSION
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
fn battle_on(content: &Content, coast: bool) -> Simulation {
    let water = sim::water::Water {
        side: 256,
        coast: coast.then_some([32., 1.]),
        rivers: vec![],
        ponds: vec![],
        fords: vec![],
        bridges: vec![],
    };
    let loaded = water
        .load(sim::terrain::Terrain::blank(256).unwrap(), &[], false)
        .unwrap();
    let terrain = loaded.terrain;
    let deck = if loaded.deck.is_empty() {
        vec![0; 256 * 256]
    } else {
        loaded.deck
    };
    let boats = sim::boat_navigation::BoatNavigation::from_terrain(&terrain, &deck).unwrap();
    let geometry = sim::world_geometry::WorldGeometry::new(terrain, deck, 16).unwrap();
    let mut state = MatchState::empty(geometry, water, boats, 137, false).unwrap();
    state.scenario = true;
    state.field.now = 90.;
    state.tick = 5400;
    content.with_profiles(&[], |p, _| {
        for team in 0..2 {
            let z: f32 = if team == 0 { 65. } else { -65. };
            for (kind, position) in [
                ("depot", Vector3::new(0., 0., z.signum() * 112.)),
                ("fob", Vector3::new(0., 0., z)),
                ("fob", Vector3::new(-70., 0., z)),
                ("barracks", Vector3::new(24., 0., z)),
            ] {
                let id = state
                    .field
                    .geometry
                    .spawn_structure(
                        &mut state.field.actors,
                        sim::structure::Structure {
                            kind: kind.into(),
                            team,
                            position,
                            built: true,
                            supply: 900.,
                            completed_order: 1,
                            truck_timer: 99999.,
                            ..Default::default()
                        },
                        content.building(kind).map(|p| p.body),
                    )
                    .unwrap();
                if kind == "depot" {
                    state.rules.network.depots[team as usize] = id;
                }
            }
            if coast && team == 1 {
                continue;
            }
            for i in 0..6 {
                state
                    .field
                    .with_context(&p.shared, Default::default(), |w| {
                        w.spawn_squad(
                            sim::squad_birth::Spawn {
                                team,
                                owner: -1 - i32::from(team),
                                position: Vector3::new(
                                    -18. + i as f32 * 6.,
                                    0.,
                                    z - z.signum() * 14.,
                                ),
                                destination: None,
                            },
                            content
                                .squad(if i == 0 {
                                    if team == 0 {
                                        "engineer_team"
                                    } else {
                                        "digger_team"
                                    }
                                } else if team == 0 {
                                    "rifle_squad"
                                } else {
                                    "fighter_cell"
                                })
                                .unwrap(),
                        )
                    })
                    .unwrap();
            }
        }
        state
            .field
            .with_context(&p.shared, Default::default(), |w| {
                w.spawn_squad(
                    sim::squad_birth::Spawn {
                        team: 0,
                        owner: 7,
                        position: Vector3::new(-70., 0., 60.),
                        destination: None,
                    },
                    content.squad("rifle_squad").unwrap(),
                )
            })
            .unwrap();
    });
    let mut simulation = Simulation::new(state, 7, content).unwrap();
    simulation.enable_commander(0).unwrap();
    simulation.enable_commander(1).unwrap();
    simulation
}

#[test]
fn coastal_commanders_patrol_board_and_retain_their_raid_across_restore() {
    let content = Content::bundled().unwrap();
    let mut a = battle_on(&content, true);
    a.commanders.retain(|c| c.team == 0);
    let mut boats = vec![];
    for (kind, position) in [
        ("rhib", Vector3::new(100., -0.45, 65.)),
        ("patrol_ship", Vector3::new(110., -0.45, 25.)),
    ] {
        boats.push(
            a.state
                .field
                .geometry
                .spawn_vehicle(
                    &mut a.state.field.actors,
                    sim::vehicle_birth::Spawn {
                        team: 0,
                        owner: -1,
                        position,
                        yaw: 0.,
                    },
                    content.vehicle_birth(kind).unwrap(),
                )
                .unwrap(),
        );
    }
    // Keep a reserve for the boat while the ordinary military phase assigns garrisons.
    a.commanders[0].last_wave = 10000.;
    let mut b = Simulation::restore(&a.checkpoint().unwrap(), &content).unwrap();
    let mut patrol = false;
    let mut pickup = false;
    let mut boarding = false;
    let mut landed = false;
    for step in 0..9000 {
        let frame = a.step(&content, &[]).unwrap();
        assert_eq!(frame, b.step(&content, &[]).unwrap(), "step {step}");
        patrol |= a
            .state
            .field
            .actors
            .vehicle(boats[1])
            .is_some_and(|v| !v.path.is_empty());
        pickup |= a.commanders[0].roles.values().any(|r| r.kind == "raid");
        boarding |= a
            .state
            .field
            .actors
            .vehicle(boats[0])
            .is_some_and(|v| !v.passengers.is_empty());
        landed |= boarding
            && a.state
                .field
                .actors
                .vehicle(boats[0])
                .is_some_and(|v| v.passengers.is_empty() && v.assault_destination.is_some());
        if step == 450 {
            b = Simulation::restore(&b.checkpoint().unwrap(), &content).unwrap();
        }
        if patrol && pickup && boarding && landed {
            break;
        }
    }
    assert!(
        patrol && pickup && boarding && landed,
        "patrol={patrol} pickup={pickup} boarding={boarding} landed={landed} boat={:?} men={:?}",
        a.state.field.actors.vehicle(boats[0]).map(|v| (
            v.position,
            v.speed,
            v.path_index,
            v.path.len(),
            &v.brain_state,
            &v.passengers
        )),
        a.state
            .field
            .actors
            .iter()
            .filter_map(|a| match a {
                Actor::Soldier(s) if s.identity.squad == 6 => Some((
                    s.motion.position,
                    s.vitals.life,
                    s.duty.kind,
                    s.duty.entity,
                    s.motion.path.len(),
                    s.orders.clone()
                )),
                _ => None,
            })
            .collect::<Vec<_>>()
    );
    assert_eq!(a.checkpoint().unwrap(), b.checkpoint().unwrap());
    golden("naval_commander", &a);
}

#[test]
fn strategic_ai_builds_trains_attacks_and_replays_without_recording_its_decisions() {
    let content = Content::bundled().unwrap();
    let mut a = battle(&content);
    let initial = a.checkpoint().unwrap();
    let mut b = Simulation::restore(&initial, &content).unwrap();
    let mut recorder = Recorder::new(Vec::new(), &a, &content).unwrap();
    let mut commands = 0;
    let mut trained = false;
    let mut built = false;
    let mut attacked = false;
    let mut defended = false;
    for step in 0..900 {
        let frame = recorder.step(&mut a, &content, &[]).unwrap();
        assert_eq!(frame, b.step(&content, &[]).unwrap(), "step {step}");
        commands += frame.commands.len();
        trained|=a.state.field.battle.sides.iter().any(|s|s[14]>0.) && a.state.field.actors.iter().any(|actor|matches!(actor,Actor::Structure(s) if s.kind=="barracks" && !s.queue.is_empty()));
        built |= a
            .state
            .field
            .actors
            .iter()
            .any(|actor| matches!(actor,Actor::Structure(s) if s.kind=="medic_tent"));
        attacked |= a
            .commanders
            .iter()
            .any(|c| c.roles.values().any(|r| r.kind == "attack"));
        defended |= a
            .commanders
            .iter()
            .any(|c| c.roles.values().any(|r| r.kind == "garrison"));
        if step == 450 {
            b = Simulation::restore(&b.checkpoint().unwrap(), &content).unwrap();
        }
    }
    assert!(commands>0 && trained && built && attacked && defended,"commands={commands} trained={trained} built={built} attacked={attacked} defended={defended}");
    assert!(
        a.state
            .field
            .squads
            .iter()
            .filter(|q| q.owner == 7)
            .all(|q| q.order_number == 0),
        "AI must leave human-owned forces alone"
    );
    assert_eq!(a.checkpoint().unwrap(), b.checkpoint().unwrap());
    golden("commander", &a);
    let bytes = recorder.finish(&a).unwrap();
    let verified = verify(bytes.as_slice(), &content).unwrap();
    assert_eq!(verified.frames, 900);
    assert_eq!(
        a.checkpoint().unwrap(),
        verified.simulation.checkpoint().unwrap()
    );
}

#[test]
fn commander_checkpoint_rejects_corruption_and_preserves_phase_randomness_and_roles() {
    let mut c = Commander::new(1, 137, 90).unwrap();
    c.rng.randi();
    c.phase = 3;
    c.next_vehicle = "t72".into();
    let bytes = c.checkpoint().unwrap();
    assert_eq!(c, Commander::restore(&bytes).unwrap());
    assert!(Commander::restore(&bytes[..bytes.len() - 1]).is_err());
    let mut bad = bytes.clone();
    bad.push(0);
    assert!(Commander::restore(&bad).is_err());
    c.phase = 4;
    assert!(c.checkpoint().is_err());
    assert!(Commander::new(2, 1, 0).is_err());
}

#[test]
fn disconnected_players_get_a_replayable_stand_in_that_returns_control_on_rejoin() {
    use frontline_server::simulation::Input;
    let content = Content::bundled().unwrap();
    let mut a = battle(&content);
    a.commanders.retain(|c| c.team == 1);
    let mut recording = Recorder::new(Vec::new(), &a, &content).unwrap();
    recording
        .step(
            &mut a,
            &content,
            &[Input::Join {
                peer: 7,
                team: 0,
                name: "Ada".into(),
                reclaim: None,
            }],
        )
        .unwrap();
    recording
        .step(&mut a, &content, &[Input::Leave { peer: 7 }])
        .unwrap();
    assert!(a.commanders.iter().any(|c| c.team == 0 && !c.permanent));
    for _ in 0..300 {
        recording.step(&mut a, &content, &[]).unwrap();
    }
    recording
        .step(
            &mut a,
            &content,
            &[Input::Join {
                peer: 11,
                team: 0,
                name: "Ada".into(),
                reclaim: Some(7),
            }],
        )
        .unwrap();
    assert!(!a.commanders.iter().any(|c| c.team == 0));
    assert!(a.commanders.iter().any(|c| c.team == 1 && c.permanent));
    assert!(a
        .state
        .field
        .squads
        .iter()
        .filter(|q| q.team == 0)
        .all(|q| q.owner == 11));
    let bytes = recording.finish(&a).unwrap();
    let replay = verify(bytes.as_slice(), &content).unwrap();
    assert_eq!(
        a.checkpoint().unwrap(),
        replay.simulation.checkpoint().unwrap()
    );
}

#[test]
fn initial_navigation_is_built_before_admitting_long_distance_routes() {
    use frontline_server::simulation::Input;
    use sim::match_commands::{Action, Command};
    let content = Content::bundled().unwrap();
    let mut a = battle(&content);
    assert!(
        a.state.field.geometry.navigation.infantry.built
            && a.state.field.geometry.navigation.vehicles.built
            && a.state.field.geometry.navigation.tracked.built
    );
    let squad = a.state.field.squads.iter().find(|q| q.owner == 7).unwrap();
    let id = squad.id;
    let soldier = squad.members[0];
    let start = a
        .state
        .field
        .actors
        .soldier(soldier)
        .unwrap()
        .motion
        .position;
    a.step(
        &content,
        &[
            Input::Join {
                peer: 7,
                team: 0,
                name: "Ada".into(),
                reclaim: None,
            },
            Input::Command {
                peer: 7,
                command: Command {
                    squads: vec![id],
                    vehicles: vec![],
                    action: Action::Move {
                        position: Vector3::new(-60., 0., -40.),
                        face: Vector3::NEG_Z,
                        mode: 2,
                    },
                },
            },
        ],
    )
    .unwrap();
    for _ in 0..600 {
        a.step(&content, &[]).unwrap();
    }
    let man = a.state.field.actors.soldier(soldier).unwrap();
    assert!(
        man.motion.position.distance(start) > 20.,
        "route must cross multiple navigation clusters: {:?}",
        man.motion.position
    );
}
