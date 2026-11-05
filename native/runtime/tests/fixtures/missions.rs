use frontline_core as sim;
use frontline_runtime::{content::Content, mission::Landmark, simulation::Simulation};
use sim::{match_state::MatchState, vector::Vector3};

pub fn map(content: &Content) -> Simulation {
    let water = sim::water::Water {
        side: 1024,
        coast: Some([240., 1.]),
        rivers: vec![sim::water::River {
            points: vec![Vector3::new(0., 0., -500.), Vector3::new(0., 0., 500.)],
            width: 8.,
        }],
        ponds: vec![],
        fords: vec![Vector3::new(0., 0., 250.)],
        bridges: [-180., 180.]
            .into_iter()
            .map(|z| sim::water::Bridge {
                a: Vector3::new(-16., 0., z),
                b: Vector3::new(16., 0., z),
                half_width: 5.,
                quay: false,
            })
            .collect(),
    };
    let loaded = water
        .load(sim::terrain::Terrain::blank(1024).unwrap(), &[], false)
        .unwrap();
    let boats =
        sim::boat_navigation::BoatNavigation::from_terrain(&loaded.terrain, &loaded.deck).unwrap();
    let geometry =
        sim::world_geometry::WorldGeometry::new(loaded.terrain, loaded.deck, 16).unwrap();
    let mut state = MatchState::empty(geometry, water, boats, 137, false).unwrap();
    state.rules.network.roads[2] = vec![
        vec![
            Vector3::new(80., 0., -450.),
            Vector3::new(80., 0., 0.),
            Vector3::new(80., 0., 450.),
        ],
        vec![Vector3::new(80., 0., -180.), Vector3::new(170., 0., -180.)],
    ];
    for team in 0..2 {
        let z = if team == 0 { 400. } else { -400. };
        for (kind, p) in [
            ("depot", Vector3::new(-330., 0., z)),
            ("fob", Vector3::new(-300., 0., z)),
        ] {
            let id = state
                .field
                .geometry
                .spawn_structure(
                    &mut state.field.actors,
                    sim::structure::Structure {
                        kind: kind.into(),
                        team,
                        position: p,
                        built: true,
                        supply: 1000.,
                        completed_order: 1,
                        ..Default::default()
                    },
                    content.building(kind).map(|p| p.body),
                )
                .unwrap();
            if kind == "depot" {
                state.rules.network.depots[team as usize] = id;
            }
        }
    }
    let mut simulation = Simulation::new(state, 7, content).unwrap();
    simulation.landmarks = vec![
        Landmark {
            kind: "town".into(),
            position: Vector3::new(80., 0., -30.),
        },
        Landmark {
            kind: "harbour".into(),
            position: Vector3::new(220., 0., -120.),
        },
    ];
    for z in [-180., 180.] {
        for x in [-130., 130.] {
            simulation.landmarks.push(Landmark {
                kind: "village".into(),
                position: Vector3::new(x, 0., z),
            });
        }
    }
    simulation
}
