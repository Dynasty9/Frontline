use frontline_core as sim;
use frontline_server::{
    content::{Content, SOURCE},
    simulation::Simulation,
};
use serde_json::json;

pub fn map(content: &Content) -> Simulation {
    let terrain = sim::terrain::Terrain::blank(64).unwrap();
    let deck = vec![0; 4096];
    let boats = sim::boat_navigation::BoatNavigation::from_terrain(&terrain, &deck).unwrap();
    let geometry = sim::world_geometry::WorldGeometry::new(terrain, deck, 16).unwrap();
    let water = sim::water::Water {
        side: 64,
        coast: None,
        rivers: vec![],
        ponds: vec![],
        bridges: vec![],
        fords: vec![],
    };
    let mut state = sim::match_state::MatchState::empty(geometry, water, boats, 137, true).unwrap();
    state.scenario = true;
    state.owners.players.push((7, 0));
    state.field.battle.joined(7, 0, "Commander").unwrap();
    content
        .with_profiles(&[], |p, _| {
            state
                .field
                .with_context(&p.shared, Default::default(), |w| {
                    w.spawn_squad(
                        sim::squad_birth::Spawn {
                            team: 0,
                            owner: 7,
                            position: sim::vector::Vector3::ZERO,
                            destination: None,
                        },
                        content.squad("rifle_squad").unwrap(),
                    )
                })
        })
        .unwrap();
    state
        .field
        .actors
        .rebuild_units(&mut state.field.units)
        .unwrap();
    Simulation::new(state, 7, content).unwrap()
}
pub fn encode(a: &Simulation, mut edit: impl FnMut(&mut serde_json::Value)) -> Vec<u8> {
    let mut meta = json!({"host":7,"players":[[7,0,"Commander"]],"ai":[],"mission":"","autoplay":false,"scenario":true,"wet":true,
        "town":[0,0,0,0],"landmarks":[{"kind":"woods","pos":[2,0,3]}],"upgrades":[[],[]],"support":[[],[]],"fob_names":[0,0],
        "presentation":{"decor":[["lamp",[1,0,2],0,{}]],"mood":"rain"}});
    edit(&mut meta);
    let f = &a.state.field;
    let mut w = sim::state_codec::Writer::new(b"FLIN\x02\0\0\0");
    w.bytes(SOURCE.as_bytes());
    w.bytes(&serde_json::to_vec(&meta).unwrap());
    w.u64(f.rng.seed());
    w.u64(f.rng.state());
    w.u64(f.next_squad);
    w.bytes(&frontline_server::compression::encode(&f.geometry.checkpoint()).unwrap());
    w.bytes(&f.actors.checkpoint().unwrap());
    w.bytes(&a.state.rules.network.checkpoint().unwrap());
    w.bytes(&f.battle.checkpoint());
    w.bytes(&a.state.water.checkpoint());
    w.u32(f.squads.len() as u32);
    for q in &f.squads {
        w.bytes(&q.checkpoint().unwrap());
    }
    w.0
}
