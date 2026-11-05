use frontline_core as sim;
use frontline_runtime::{
    content::Content,
    simulation::{Input, Simulation},
};
use sim::match_commands::{Action, Command};
use sim::match_state::MatchState;
use sim::vector::Vector3;

pub fn battle(content: &Content) -> Simulation {
    let terrain = sim::terrain::Terrain::blank(64).unwrap();
    let deck = vec![0; 64 * 64];
    let boats = sim::boat_navigation::BoatNavigation::from_terrain(&terrain, &deck).unwrap();
    let geometry = sim::world_geometry::WorldGeometry::new(terrain, deck, 16).unwrap();
    let water = sim::water::Water {
        side: 64,
        coast: None,
        rivers: vec![],
        ponds: vec![],
        fords: vec![],
        bridges: vec![],
    };
    let mut state = MatchState::empty(geometry, water, boats, 137, false).unwrap();
    state.scenario = true;
    content.with_profiles(&[], |p, _| {
        for team in 0..2 {
            let x = if team == 0 { -20. } else { 20. };
            let id = state
                .field
                .geometry
                .spawn_structure(
                    &mut state.field.actors,
                    sim::structure::Structure {
                        kind: "depot".into(),
                        team,
                        position: Vector3::new(x, 0., 0.),
                        built: true,
                        ..Default::default()
                    },
                    None,
                )
                .unwrap();
            state.rules.network.depots[team as usize] = id;
            state
                .field
                .with_context(&p.shared, Default::default(), |w| {
                    w.spawn_squad(
                        sim::squad_birth::Spawn {
                            team,
                            owner: if team == 0 { 7 } else { 9 },
                            position: Vector3::new(x * 0.3, 0., 0.),
                            destination: None,
                        },
                        content
                            .squad(if team == 0 {
                                "rifle_squad"
                            } else {
                                "fighter_cell"
                            })
                            .unwrap(),
                    )
                })
                .unwrap();
        }
    });
    Simulation::new(state, 7, content).unwrap()
}

pub fn inputs(tick: u64) -> Vec<Input> {
    match tick {
        0 => vec![
            Input::Join {
                peer: 7,
                team: 0,
                name: "Commander Ada".into(),
                reclaim: None,
            },
            Input::Join {
                peer: 9,
                team: 1,
                name: "Commander Lin".into(),
                reclaim: None,
            },
        ],
        1 => vec![Input::Command {
            peer: 7,
            command: Command {
                squads: vec![1],
                vehicles: vec![],
                action: Action::Move {
                    position: Vector3::new(3., 0., -3.),
                    face: Vector3::X,
                    mode: 0,
                },
            },
        }],
        30 => vec![Input::Command {
            peer: 7,
            command: Command {
                squads: vec![1],
                vehicles: vec![],
                action: Action::Throw {
                    position: Vector3::new(6., 0., 0.),
                    smoke: false,
                },
            },
        }],
        70 => vec![Input::Leave { peer: 7 }],
        80 => vec![Input::Join {
            peer: 11,
            team: 0,
            name: "Commander Ada".into(),
            reclaim: Some(7),
        }],
        100 => vec![Input::Command {
            peer: 11,
            command: Command {
                squads: vec![],
                vehicles: vec![],
                action: Action::Chat {
                    text: "Regroup".into(),
                    team_only: true,
                },
            },
        }],
        _ => vec![],
    }
}
