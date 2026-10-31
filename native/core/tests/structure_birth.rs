use frontline_core::actors::Actors;
use frontline_core::structure::Structure;
use frontline_core::structure_birth::BuildingProfile;
use frontline_core::terrain::Terrain;
use frontline_core::vector::Vector3;
use frontline_core::world_geometry::WorldGeometry;

#[path = "fixtures/structure_birth_world.rs"]
mod world;

#[test]
fn all_structures_spawn_register_and_retire_with_identical_resumes() {
    assert_eq!(world::transcript(), world::transcript());
}

#[test]
fn default_sizes_health_cache_stock_and_explicit_damage_are_preserved() {
    for (kind, size, hp) in [
        ("depot", Vector3::new(17.0, 3.0, 11.0), 99999.0),
        ("wreck", Vector3::new(3.4, 2.0, 6.2), 5000.0),
        ("crates", Vector3::new(2.5, 1.2, 1.25), 200.0),
        ("tree", Vector3::new(0.6, 5.0, 0.6), 400.0),
        ("town", Vector3::new(3.6, 2.0, 2.4), 300.0),
    ] {
        let mut st = Structure {
            id: 1,
            kind: kind.into(),
            variant: 1,
            ..Default::default()
        };
        st.initialize(None, 32.0).unwrap();
        assert_eq!(st.size, size);
        assert_eq!(st.hp, hp);
    }
    let mut cache = Structure {
        id: 1,
        kind: "ammo_cache".into(),
        built: false,
        ..Default::default()
    };
    cache
        .initialize(
            Some(BuildingProfile {
                size: [3.0, 2.5],
                hp: 450.0,
            }),
            32.0,
        )
        .unwrap();
    assert_eq!(cache.supply, 160.0);
    assert_eq!(cache.hp, 45.0);
    cache.hp = 32.0;
    cache.supply = 17.0;
    cache
        .initialize(
            Some(BuildingProfile {
                size: [3.0, 2.5],
                hp: 450.0,
            }),
            32.0,
        )
        .unwrap();
    assert_eq!(cache.hp, 32.0);
    assert_eq!(cache.supply, 17.0);
}

#[test]
fn invalid_creation_does_not_consume_identity_or_edit_the_world() {
    let mut geometry = WorldGeometry::new(Terrain::blank(32).unwrap(), vec![], 16).unwrap();
    let mut actors = Actors::default();
    let old = geometry.checkpoint();
    let st = Structure {
        kind: "house_wall".into(),
        variant: 2,
        ..Default::default()
    };
    assert!(geometry.spawn_structure(&mut actors, st, None).is_err());
    assert_eq!(actors.entities().next_id(), 1);
    assert!(actors.entities().is_empty());
    assert_eq!(geometry.checkpoint(), old);
    let mut st = Structure {
        id: 1,
        kind: "car".into(),
        ..Default::default()
    };
    let old = st.clone();
    assert!(st
        .initialize(
            Some(BuildingProfile {
                size: [f32::NAN, 1.0],
                hp: 10.0
            }),
            32.0
        )
        .is_err());
    assert_eq!(st, old);
}

#[test]
fn registration_rejects_reused_geometry_before_changing_navigation() {
    let mut geometry = WorldGeometry::new(Terrain::blank(32).unwrap(), vec![], 16).unwrap();
    let mut actors = Actors::default();
    let id = geometry
        .spawn_structure(
            &mut actors,
            Structure {
                kind: "car".into(),
                ..Default::default()
            },
            None,
        )
        .unwrap();
    let mut st = actors.structure(id).unwrap().clone();
    let old = geometry.checkpoint();
    assert!(geometry.register_structure(&mut st, &actors).is_err());
    assert_eq!(geometry.checkpoint(), old);
}
