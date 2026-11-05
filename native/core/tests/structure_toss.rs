use frontline_core::actors::Actors;
use frontline_core::random::SimulationRandom;
use frontline_core::structure::Structure;
use frontline_core::terrain::Terrain;
use frontline_core::vector::Vector3;
use frontline_core::world_geometry::WorldGeometry;

fn scene() -> (WorldGeometry, Actors, SimulationRandom) {
    let mut g = WorldGeometry::new(Terrain::blank(32).unwrap(), vec![], 16).unwrap();
    let mut actors = Actors::default();
    g.spawn_structure(
        &mut actors,
        Structure {
            kind: "car".into(),
            ..Default::default()
        },
        None,
    )
    .unwrap();
    (g, actors, SimulationRandom::new(71351))
}

#[test]
fn blast_moves_cover_navigation_and_collision_together() {
    let (mut g, mut actors, mut rng) = scene();
    let old = actors.structure(1).unwrap().position;
    let toss = g
        .toss_structure(&mut actors, 1, Vector3::new(-2.0, 0.0, 0.0), 3.0, &mut rng)
        .unwrap()
        .unwrap();
    let st = actors.structure(1).unwrap();
    assert_eq!(toss.origin, old);
    assert!(st.position.x > 3.0);
    assert_ne!(g.navigation.planner.kind_at(old, false), 3);
    assert_eq!(g.navigation.planner.kind_at(st.position, false), 3);
    assert!(g
        .collision
        .ray(
            Vector3::new(0.0, 0.5, -4.0),
            Vector3::new(0.0, 0.5, 4.0),
            &[]
        )
        .is_none());
    assert!(g
        .collision
        .ray(
            st.position + Vector3::new(0.0, 0.5, -4.0),
            st.position + Vector3::new(0.0, 0.5, 4.0),
            &[]
        )
        .is_some());
    assert!(!st.anchors.is_empty());
    assert_eq!(g.structures.membership(1).len(), st.hash_cells.len());
}

#[test]
fn weak_and_blocked_tosses_keep_geometry_and_preserve_random_order() {
    let (mut g, mut actors, mut rng) = scene();
    let state = g.checkpoint();
    let before = rng;
    assert!(g
        .toss_structure(&mut actors, 1, Vector3::ZERO, 0.0, &mut rng)
        .unwrap()
        .is_none());
    assert_ne!(
        rng, before,
        "Even a weak blast directly underneath chooses its direction first"
    );
    assert_eq!(g.checkpoint(), state);
    let before = rng;
    assert!(g
        .toss_structure(&mut actors, 1, Vector3::new(-20.0, 0.0, 0.0), 0.1, &mut rng)
        .unwrap()
        .is_none());
    assert_eq!(rng, before);
    g.spawn_structure(
        &mut actors,
        Structure {
            kind: "barracks".into(),
            position: Vector3::new(6.0, 0.0, 0.0),
            size: Vector3::new(10.0, 3.0, 10.0),
            ..Default::default()
        },
        None,
    )
    .unwrap();
    let state = g.checkpoint();
    assert!(g
        .toss_structure(&mut actors, 1, Vector3::new(-2.0, 0.0, 0.0), 3.0, &mut rng)
        .unwrap()
        .is_none());
    assert_eq!(rng, before);
    assert_eq!(g.checkpoint(), state);
}

#[test]
fn resumed_tosses_preserve_world_state_and_random_continuation() {
    let (mut g, mut actors, mut rng) = scene();
    for step in 0..12 {
        let mut restored = WorldGeometry::restore(&g.checkpoint()).unwrap();
        let mut restored_actors = Actors::restore(&actors.checkpoint().unwrap()).unwrap();
        let mut random = rng;
        let p = actors.structure(1).unwrap().position
            + Vector3::new(if step % 2 == 0 { -1.2 } else { 1.2 }, 0.0, 0.0);
        let a = g.toss_structure(&mut actors, 1, p, 2.7, &mut rng).unwrap();
        let b = restored
            .toss_structure(&mut restored_actors, 1, p, 2.7, &mut random)
            .unwrap();
        assert_eq!(a, b);
        assert_eq!(rng, random);
        assert_eq!(
            actors.checkpoint().unwrap(),
            restored_actors.checkpoint().unwrap()
        );
        assert_eq!(g.checkpoint(), restored.checkpoint());
        g.tick_cover(43).unwrap();
    }
}

#[test]
fn missing_untossable_and_invalid_inputs_do_not_touch_randomness_or_state() {
    let (mut g, mut actors, mut rng) = scene();
    g.spawn_structure(
        &mut actors,
        Structure {
            kind: "tree".into(),
            ..Default::default()
        },
        None,
    )
    .unwrap();
    let prior = (g.checkpoint(), actors.checkpoint().unwrap(), rng);
    for id in [2, 999] {
        assert!(g
            .toss_structure(&mut actors, id, Vector3::ZERO, 9.0, &mut rng)
            .unwrap()
            .is_none());
    }
    assert!(g
        .toss_structure(&mut actors, 1, Vector3::ZERO, f64::NAN, &mut rng)
        .is_err());
    assert!(g
        .toss_structure(&mut actors, 1, Vector3::splat(f32::INFINITY), 3.0, &mut rng)
        .is_err());
    assert_eq!(prior, (g.checkpoint(), actors.checkpoint().unwrap(), rng));
}
