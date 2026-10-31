#[allow(dead_code)]
#[path = "fixtures/supply_network_world.rs"]
mod fixture;
use fixture::{change, scene};
use frontline_core::supply_network::SupplyNetwork;
use frontline_core::vector::Vector3;

#[test]
fn completion_order_builds_the_supply_chain_and_clears_neutral_obstacles() {
    let (mut w, mut network) = scene();
    let removed = network.rebuild(0, &mut w.actors, &mut w.geometry).unwrap();
    assert_eq!(w.actors.structure(11).unwrap().supply_parent, 10);
    assert_eq!(w.actors.structure(12).unwrap().supply_parent, 11);
    assert_eq!(w.actors.structure(13).unwrap().supply_parent, 12);
    assert_eq!(w.actors.structure(13).unwrap().supply_status, "OK");
    assert_eq!(network.roads[0].len(), 3);
    assert_eq!(
        network.route_to(&w.actors, 12),
        [
            w.actors.structure(11).unwrap().road.clone(),
            w.actors.structure(12).unwrap().road.clone()
        ]
        .concat()
    );
    assert!(removed.contains(&14));
    assert!(w.actors.structure(14).is_none());
    assert!(w.geometry.pending_removals().contains(&14));
    assert!(w.geometry.collision.contains(14));
    w.geometry.finish_tick();
    assert!(!w.geometry.collision.contains(14));
}

#[test]
fn wrecked_fobs_keep_their_chain_but_towns_deliver_to_a_working_fob() {
    let (mut w, mut network) = scene();
    change(&mut w, 12, |st| st.wrecked = true);
    network.rebuild(0, &mut w.actors, &mut w.geometry).unwrap();
    assert_eq!(w.actors.structure(12).unwrap().supply_parent, 11);
    assert_eq!(w.actors.structure(13).unwrap().supply_parent, 11);
    change(&mut w, 11, |st| st.wrecked = true);
    network.rebuild(0, &mut w.actors, &mut w.geometry).unwrap();
    assert_eq!(w.actors.structure(13).unwrap().supply_parent, 0);
    assert_eq!(w.actors.structure(13).unwrap().supply_status, "No FOB");
    assert!(w.actors.structure(13).unwrap().road.is_empty());
    assert_eq!(network.roads[0].len(), 2);
}

#[test]
fn repainting_retains_existing_roads_and_checkpoint_continuations() {
    let (mut a, mut network) = scene();
    network.rebuild(0, &mut a.actors, &mut a.geometry).unwrap();
    let mut b = a.resume();
    let mut other = SupplyNetwork::restore(&network.checkpoint().unwrap()).unwrap();
    let version = a.geometry.terrain.version;
    for step in 0..4 {
        if step == 1 {
            change(&mut a, 13, |st| st.team = 1);
            change(&mut b, 13, |st| st.team = 1);
        }
        assert_eq!(
            network.rebuild(0, &mut a.actors, &mut a.geometry).unwrap(),
            other.rebuild(0, &mut b.actors, &mut b.geometry).unwrap()
        );
        a.compare(&b);
        assert_eq!(network, other);
        assert_eq!(a.geometry.terrain.version, version);
    }
}

#[test]
fn missing_depots_invalid_teams_and_route_cycles_do_not_loop() {
    let (mut w, mut network) = scene();
    let before = w.resume();
    let snapshot = network.clone();
    assert!(network
        .rebuild(1, &mut w.actors, &mut w.geometry)
        .unwrap()
        .is_empty());
    assert!(network.rebuild(2, &mut w.actors, &mut w.geometry).is_err());
    w.compare(&before);
    assert_eq!(network, snapshot);
    change(&mut w, 11, |st| st.supply_parent = 12);
    change(&mut w, 12, |st| st.supply_parent = 11);
    assert!(network.route_to(&w.actors, 11).is_empty());
    assert!(network.route_to(&w.actors, 999).is_empty());
}

#[test]
fn checkpoints_reject_corruption_and_completion_ids_do_not_wrap() {
    let (mut w, mut network) = scene();
    network.register_start(11, &mut w.actors).unwrap();
    assert_eq!(w.actors.structure(11).unwrap().completed_order, 3);
    let encoded = network.checkpoint().unwrap();
    assert_eq!(SupplyNetwork::restore(&encoded).unwrap(), network);
    for length in 0..encoded.len() {
        assert!(SupplyNetwork::restore(&encoded[..length]).is_err());
    }
    let mut trailing = encoded.clone();
    trailing.push(0);
    assert!(SupplyNetwork::restore(&trailing).is_err());
    let mut oversized = encoded.clone();
    oversized[20..24].copy_from_slice(&u32::MAX.to_le_bytes());
    assert!(SupplyNetwork::restore(&oversized).is_err());
    network.completed = u32::MAX;
    assert!(network.register_start(11, &mut w.actors).is_err());
    assert_eq!(w.actors.structure(11).unwrap().completed_order, 3);
    network.towns.push(13);
    assert!(network.checkpoint().is_err());
    network.towns.pop();
    network.roads[0].push(vec![Vector3::new(f32::NAN, 0.0, 0.0)]);
    assert!(network.checkpoint().is_err());
}
