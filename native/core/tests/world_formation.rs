use frontline_core::actors::Actors;
use frontline_core::structure::Structure;
use frontline_core::terrain::Terrain;
use frontline_core::vector::Vector3;
use frontline_core::world_geometry::WorldGeometry;

fn scene() -> WorldGeometry {
    WorldGeometry::new(Terrain::blank(32).unwrap(), vec![], 16).unwrap()
}

#[test]
fn open_ground_ties_and_spacing_keep_a_compact_group() {
    let g = scene();
    let actors = Actors::default();
    let slots = g
        .formation_slots(&actors, Vector3::ZERO, Vector3::ZERO, 12, false)
        .unwrap();
    assert_eq!(slots[0].position, Vector3::new(-0.5, 0.0, -0.5));
    for (i, s) in slots.iter().enumerate() {
        assert!(s.position.length() <= 5.5);
        assert_eq!(s.anchor, None);
        assert_eq!(s.cover, 0);
        for other in &slots[..i] {
            assert!(s.position.distance(other.position) >= 1.4);
        }
    }
}

#[test]
fn good_cover_does_not_split_a_formation_across_a_wall() {
    let mut g = scene();
    let mut actors = Actors::default();
    g.spawn_structure(
        &mut actors,
        Structure {
            kind: "hesco".into(),
            position: Vector3::new(0.0, 0.0, -2.0),
            size: Vector3::new(20.0, 1.37, 1.06),
            ..Default::default()
        },
        None,
    )
    .unwrap();
    g.tick_cover(100000).unwrap();
    let slots = g
        .formation_slots(&actors, Vector3::ZERO, Vector3::NEG_Z, 6, true)
        .unwrap();
    assert!(slots.iter().any(|s| s.anchor.is_some()));
    assert!(slots.iter().all(|s| s.position.z > -2.0));
}

#[test]
fn creation_and_repair_resumes_keep_formation_choices() {
    let mut g = scene();
    let mut actors = Actors::default();
    for (kind, x, z) in [
        ("sandbags", -4.0, -2.0),
        ("trench", 4.0, 1.0),
        ("crates", 0.0, -3.0),
    ] {
        g.spawn_structure(
            &mut actors,
            Structure {
                kind: kind.into(),
                position: Vector3::new(x, 0.0, z),
                size: Vector3::new(4.0, 1.0, 1.0),
                ..Default::default()
            },
            None,
        )
        .unwrap();
    }
    for budget in [0, 11, 37, 10000] {
        g.tick_cover(budget).unwrap();
        let restored = WorldGeometry::restore(&g.checkpoint()).unwrap();
        let restored_actors = Actors::restore(&actors.checkpoint().unwrap()).unwrap();
        for wide in [false, true] {
            assert_eq!(
                g.formation_slots(
                    &actors,
                    Vector3::ZERO,
                    Vector3::new(0.3, 0.0, -0.9),
                    8,
                    wide
                )
                .unwrap(),
                restored
                    .formation_slots(
                        &restored_actors,
                        Vector3::ZERO,
                        Vector3::new(0.3, 0.0, -0.9),
                        8,
                        wide
                    )
                    .unwrap()
            );
        }
    }
}

#[test]
fn empty_and_invalid_formations_do_not_change_shared_state() {
    let g = scene();
    let actors = Actors::default();
    let before = g.checkpoint();
    assert!(g
        .formation_slots(&actors, Vector3::ZERO, Vector3::NEG_Z, 0, false)
        .unwrap()
        .is_empty());
    assert!(g
        .formation_slots(&actors, Vector3::splat(f32::NAN), Vector3::NEG_Z, 6, false)
        .is_err());
    assert!(g
        .formation_slots(&actors, Vector3::ZERO, Vector3::NEG_Z, 4097, false)
        .is_err());
    assert_eq!(g.checkpoint(), before);
}
