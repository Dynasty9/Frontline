//! Run explicitly in release mode; wall-clock timing is never part of the simulation.
use frontline_core as sim;
use frontline_server::{content::Content, simulation::Simulation};
use sim::{match_state::MatchState, vector::Vector3};
use std::time::Instant;

#[test]
#[ignore = "manual simulation-only benchmark with other applications left running"]
fn five_hundred_soldiers_on_a_large_map() {
    let side: usize = std::env::var("FL_BENCH_SIDE")
        .unwrap_or_else(|_| "1024".into())
        .parse()
        .unwrap();
    assert!([1024, 2048, 3072].contains(&side));
    let content = Content::bundled().unwrap();
    let started = Instant::now();
    let terrain = sim::terrain::Terrain::blank(side).unwrap();
    let deck = vec![0; side * side];
    let boats = sim::boat_navigation::BoatNavigation::from_terrain(&terrain, &deck).unwrap();
    let geometry = sim::world_geometry::WorldGeometry::new(terrain, deck, 16).unwrap();
    let water = sim::water::Water {
        side,
        coast: None,
        rivers: vec![],
        ponds: vec![],
        fords: vec![],
        bridges: vec![],
    };
    let mut state = MatchState::empty(geometry, water, boats, 137, false).unwrap();
    state.scenario = true;
    content.with_profiles(&[], |p, commands| {
        for team in 0..2 {
            let sign = if team == 0 { -1. } else { 1. };
            let depot = state
                .field
                .geometry
                .spawn_structure(
                    &mut state.field.actors,
                    sim::structure::Structure {
                        kind: "depot".into(),
                        team,
                        position: Vector3::new(sign * 100., 0., 0.),
                        built: true,
                        ..Default::default()
                    },
                    None,
                )
                .unwrap();
            state.rules.network.depots[team as usize] = depot;
            let mut remaining = 250;
            let mut rank = 0;
            while remaining > 0 {
                let mut definition = content
                    .squad(if team == 0 {
                        "rifle_squad"
                    } else {
                        "fighter_cell"
                    })
                    .unwrap();
                definition.members = &definition.members[..remaining.min(definition.members.len())];
                remaining -= definition.members.len();
                let pos = Vector3::new(
                    sign * (12. + (rank % 5) as f32 * 5.),
                    0.,
                    (rank / 5) as f32 * 10. - 50.,
                );
                let (squad, _) = state
                    .field
                    .with_context(&p.shared, Default::default(), |w| {
                        w.spawn_squad(
                            sim::squad_birth::Spawn {
                                team,
                                owner: -1 - team as i32,
                                position: pos,
                                destination: None,
                            },
                            definition,
                        )
                    })
                    .unwrap();
                state
                    .execute(
                        -1 - team as i32,
                        "AI",
                        1,
                        &sim::match_commands::Command {
                            squads: vec![squad],
                            vehicles: vec![],
                            action: sim::match_commands::Action::Move {
                                position: pos + Vector3::X * -sign * 40.,
                                face: Vector3::X * -sign,
                                mode: 0,
                            },
                        },
                        &p.shared,
                        commands,
                    )
                    .unwrap();
                rank += 1;
            }
        }
    });
    let mut simulation = Simulation::new(state, 1, &content).unwrap();
    let initial: Vec<_> = simulation
        .state
        .field
        .actors
        .iter()
        .filter_map(|a| match a {
            sim::actors::Actor::Soldier(s) => Some((s.identity.id, s.motion.position)),
            _ => None,
        })
        .collect();
    let setup_ms = started.elapsed().as_secs_f64() * 1000.;
    let mut samples = Vec::with_capacity(600);
    let mut event_count = 0;
    for _ in 0..600 {
        let tick = Instant::now();
        let frame = simulation.step(&content, &[]).unwrap();
        samples.push(tick.elapsed().as_secs_f64() * 1000.);
        event_count += frame.events.len();
    }
    let mean = samples.iter().sum::<f64>() / samples.len() as f64;
    let over_budget = samples.iter().filter(|&&ms| ms > 1000. / 60.).count();
    samples.sort_by(f64::total_cmp);
    let alive = simulation.state.field.actors.iter().filter(|a| matches!(a, sim::actors::Actor::Soldier(s) if s.vitals.life == sim::infantry_vitals::Life::Alive)).count();
    let moved = initial
        .iter()
        .filter(|(id, pos)| {
            simulation
                .state
                .field
                .actors
                .soldier(*id)
                .is_some_and(|s| s.motion.position.distance(*pos) > 1.)
        })
        .count();
    let shots: f64 = simulation
        .state
        .field
        .battle
        .sides
        .iter()
        .map(|s| s[sim::battle_stats::SHOTS])
        .sum();
    println!("SIMULATION_SCALE side={side} initial_soldiers=500 alive={alive} moved={moved} shots={shots} ticks=600 setup_ms={setup_ms:.2} mean_ms={mean:.3} p50_ms={:.3} p95_ms={:.3} p99_ms={:.3} max_ms={:.3} over_16_67_ms={over_budget} events={event_count}", samples[299], samples[569], samples[593], samples[599]);
    assert!(moved > 100, "benchmark must exercise movement: {moved}");
    assert!(shots > 0., "benchmark must exercise combat");
}
