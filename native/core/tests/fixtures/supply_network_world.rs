#[allow(dead_code)]
#[path = "fires_world.rs"]
mod shared;
use frontline_core::actors::{Actor, Actors};
use frontline_core::supply_network::SupplyNetwork;
use frontline_core::vector::Vector3;

pub fn scene() -> (shared::Battle, SupplyNetwork) {
    let mut depot = shared::structure(10, "depot", -12.0);
    depot.smashable = false;
    let mut first = shared::structure(11, "fob", -3.0);
    first.completed_order = 1;
    first.smashable = false;
    let mut second = shared::structure(12, "fob", 7.0);
    second.completed_order = 2;
    second.smashable = false;
    let mut town = shared::structure(13, "town", 12.0);
    town.position.z = 8.0;
    town.supply_status = "No FOB".into();
    town.smashable = false;
    let mut obstacle = shared::structure(14, "crates", -8.0);
    obstacle.team = -1;
    obstacle.smashable = true;
    obstacle.parts[0].vehicle = 0;
    obstacle.parts[0].infantry = 0;
    let w = shared::Battle::new(
        [depot, second, first, town, obstacle]
            .into_iter()
            .map(shared::actor)
            .collect(),
    );
    (
        w,
        SupplyNetwork {
            depots: [10, 0],
            towns: vec![13],
            completed: 2,
            ..Default::default()
        },
    )
}
pub fn change(
    w: &mut shared::Battle,
    id: u32,
    mut f: impl FnMut(&mut frontline_core::structure::Structure),
) {
    let mut entries: Vec<_> = w.actors.iter().cloned().collect();
    for a in &mut entries {
        if let Actor::Structure(st) = a {
            if st.id == id {
                f(st);
            }
        }
    }
    w.actors = Actors::from_entries(w.actors.entities().next_id(), entries).unwrap();
}

pub fn transcript() -> Vec<u8> {
    fn block(out: &mut Vec<u8>, bytes: &[u8]) {
        out.extend_from_slice(&(bytes.len() as u32).to_le_bytes());
        out.extend_from_slice(bytes);
    }
    let mut out = vec![];
    for trial in 0..8 {
        let (mut w, mut network) = scene();
        network.roads[2] = vec![vec![
            Vector3::new(-14.0, 0.0, -11.7),
            Vector3::new(13.3, 0.0, -11.7),
        ]];
        change(&mut w, 11, |st| st.completed_order = 1 + trial % 2);
        change(&mut w, 12, |st| st.completed_order = 2 - trial % 2);
        for step in 0..6 {
            match step {
                1 => change(&mut w, 12, |st| st.wrecked = true),
                2 => change(&mut w, 11, |st| st.wrecked = true),
                3 => change(&mut w, 11, |st| st.wrecked = false),
                4 => change(&mut w, 13, |st| st.team = 1),
                5 => change(&mut w, 13, |st| st.team = 0),
                _ => (),
            }
            let removed = network.rebuild(0, &mut w.actors, &mut w.geometry).unwrap();
            block(
                &mut out,
                &removed
                    .iter()
                    .flat_map(|id| id.to_le_bytes())
                    .collect::<Vec<_>>(),
            );
            block(&mut out, &w.actors.checkpoint().unwrap());
            block(&mut out, &w.geometry.checkpoint());
            block(&mut out, &network.checkpoint().unwrap());
            w.geometry.finish_tick();
            assert!(w.geometry.navigation.update_hierarchy(1));
            block(&mut out, &w.geometry.checkpoint());
            network = SupplyNetwork::restore(&network.checkpoint().unwrap()).unwrap();
            w = w.resume();
        }
    }
    out
}
