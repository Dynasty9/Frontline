use frontline_core::actors::{Actor, Actors};
use frontline_core::infantry::Infantry;
use frontline_core::infantry_vitals::Life;
use frontline_core::spatial::*;
use frontline_core::structure::Structure;
use frontline_core::vector::Vector3;

fn soldier(id: u32, position: Vector3, team: i8, life: Life) -> Actor {
    let mut s = Infantry::default();
    s.identity.id = id;
    s.identity.unit = "rifleman".into();
    s.identity.team = team;
    s.motion.position = position;
    s.vitals.life = life;
    Actor::Soldier(Box::new(s))
}
fn structure(id: u32, kind: &str, position: Vector3, radius: f64) -> Actor {
    Actor::Structure(Box::new(Structure {
        id,
        kind: kind.into(),
        position,
        radius,
        ..Default::default()
    }))
}
#[test]
fn query_order_uses_cells_then_registration_and_reinsertion_moves_to_the_end() {
    let mut index = SpatialIndex::new(UNIT_CELL).unwrap();
    for (id, p) in [
        (3, Vector3::X),
        (1, Vector3::NEG_X),
        (2, Vector3::new(1.0, 0.0, 1.0)),
        (4, Vector3::new(1.0, 0.0, -1.0)),
    ] {
        index.insert(id, p, 0.0).unwrap();
    }
    assert_eq!(
        index
            .candidates(Vector3::ZERO, 2.0)
            .unwrap()
            .collect::<Vec<_>>(),
        vec![1, 4, 3, 2]
    );
    index.insert(3, Vector3::X, 0.0).unwrap();
    assert_eq!(
        index
            .candidates(Vector3::ZERO, 2.0)
            .unwrap()
            .collect::<Vec<_>>(),
        vec![1, 4, 2, 3]
    );
    // A very wide query visits occupied cells; it does not enumerate billions of empty buckets.
    assert_eq!(
        index
            .candidates(Vector3::ZERO, 1_000_000.0)
            .unwrap()
            .collect::<Vec<_>>(),
        vec![1, 4, 2, 3]
    );
    assert!(index.remove(4));
    assert!(!index.remove(4));
    assert_eq!(
        index
            .candidates(Vector3::ZERO, 2.0)
            .unwrap()
            .collect::<Vec<_>>(),
        vec![1, 2, 3]
    );
}
#[test]
fn units_use_live_positions_but_keep_the_bucket_from_the_start_of_the_step() {
    let actors = Actors::from_entries(
        10,
        vec![
            soldier(1, Vector3::new(-12.1, 0.0, 0.0), 0, Life::Alive),
            soldier(2, Vector3::X, 1, Life::Dead),
            soldier(3, Vector3::ZERO, 1, Life::Hidden),
        ],
    )
    .unwrap();
    let mut index = SpatialIndex::new(UNIT_CELL).unwrap();
    actors.rebuild_units(&mut index).unwrap();
    assert_eq!(
        actors.units_near(&index, Vector3::ZERO, 30.0, -1).unwrap(),
        vec![1, 2]
    );
    assert_eq!(
        actors.units_near(&index, Vector3::ZERO, 30.0, 0).unwrap(),
        vec![2]
    );
    let moved = Actors::from_entries(
        10,
        vec![
            soldier(1, Vector3::new(12.1, 0.0, 0.0), 0, Life::Alive),
            soldier(2, Vector3::X, 1, Life::Dead),
        ],
    )
    .unwrap();
    let restored = SpatialIndex::restore(&index.checkpoint()).unwrap();
    assert!(moved
        .units_near(&restored, Vector3::new(12.1, 0.0, 0.0), 1.0, -1)
        .unwrap()
        .is_empty());
    assert_eq!(
        moved
            .units_near(&restored, Vector3::ZERO, 30.0, -1)
            .unwrap(),
        vec![1, 2]
    );
    moved.rebuild_units(&mut index).unwrap();
    assert_eq!(
        moved
            .units_near(&index, Vector3::new(12.1, 0.0, 0.0), 1.0, -1)
            .unwrap(),
        vec![1]
    );
    moved.rebuild_units(&mut index).unwrap();
    assert_eq!(
        index.checkpoint(),
        SpatialIndex::restore(&index.checkpoint())
            .unwrap()
            .checkpoint()
    );
}
#[test]
fn structure_queries_deduplicate_in_encounter_order_and_ignore_removed_actors() {
    let mut actors = Actors::from_entries(
        40,
        vec![
            structure(10, "tree", Vector3::X, 1.0),
            structure(20, "floor", Vector3::ZERO, 2.0),
            structure(30, "barracks", Vector3::NEG_X, 20.0),
        ],
    )
    .unwrap();
    let index = SpatialIndex::from_cells(
        STRUCTURE_CELL,
        vec![((0, 0), vec![10, 30, 20]), ((-1, -1), vec![30, 20])],
    )
    .unwrap();
    assert_eq!(
        actors
            .structures_near(&index, Vector3::ZERO, 32.0, false)
            .unwrap(),
        vec![30, 20, 10]
    );
    assert_eq!(
        actors
            .structures_near(&index, Vector3::ZERO, 32.0, true)
            .unwrap(),
        vec![20]
    );
    actors.remove(30);
    assert_eq!(
        actors
            .structures_near(&index, Vector3::ZERO, 32.0, false)
            .unwrap(),
        vec![20, 10]
    );
}
#[test]
fn door_membership_and_blocking_keep_the_first_registered_door() {
    let mut index = SpatialIndex::new(DOOR_CELL).unwrap();
    index.insert_door(3, Vector3::ZERO).unwrap();
    index.insert_door(1, Vector3::ZERO).unwrap();
    let actors = Actors::from_entries(
        4,
        vec![
            structure(1, "house_wall", Vector3::ZERO, 1.0),
            structure(3, "house_wall", Vector3::ZERO, 1.0),
        ],
    )
    .unwrap();
    assert_eq!(
        actors
            .door_in_way(&index, Vector3::new(0.0, 0.0, 0.5), Vector3::NEG_Z)
            .unwrap(),
        Some(3)
    );
    assert_eq!(
        actors
            .door_in_way(&index, Vector3::new(0.0, 0.0, 0.5), Vector3::Z)
            .unwrap(),
        None
    );
    index.remove(3);
    assert_eq!(
        actors
            .door_in_way(&index, Vector3::new(0.0, 0.0, 0.5), Vector3::NEG_Z)
            .unwrap(),
        Some(1)
    );
    let mut tiny = SpatialIndex::new(DOOR_CELL).unwrap();
    tiny.insert_door(7, Vector3::new(-f32::from_bits(1), 0.0, 0.0))
        .unwrap();
    assert!(tiny.cells().any(|(key, _)| key == (-2, -1)));
    assert!(!tiny.cells().any(|(key, _)| key.0 == 1));
}
#[test]
fn checkpoint_preserves_membership_order_and_rejects_corruption() {
    let mut index = SpatialIndex::new(STRUCTURE_CELL).unwrap();
    index
        .insert(17, Vector3::new(-7.3, 0.0, 13.7), 20.0)
        .unwrap();
    index.insert(3, Vector3::ZERO, 1.0).unwrap();
    let saved = index.checkpoint();
    let mut restored = SpatialIndex::restore(&saved).unwrap();
    assert_eq!(restored.checkpoint(), saved);
    for n in 0..saved.len() {
        assert!(SpatialIndex::restore(&saved[..n]).is_err());
    }
    let mut bad = saved.clone();
    bad.push(0);
    assert!(SpatialIndex::restore(&bad).is_err());
    let mut bad = saved.clone();
    bad[6..8].copy_from_slice(&0u16.to_le_bytes());
    assert!(SpatialIndex::restore(&bad).is_err());
    for (id, p, r) in [
        (0, Vector3::ZERO, 1.0),
        (3, Vector3::splat(f32::NAN), 1.0),
        (3, Vector3::ZERO, -1.0),
        (3, Vector3::ZERO, 1_000_000.0),
    ] {
        assert!(restored.insert(id, p, r).is_err());
        assert_eq!(restored.checkpoint(), saved);
    }
    for rows in [
        vec![((0, 0), vec![1, 1])],
        vec![((0, 0), vec![0])],
        vec![((0, 0), vec![])],
        vec![((0, 0), vec![1]), ((0, 0), vec![2])],
    ] {
        assert!(SpatialIndex::from_cells(12.0, rows).is_err());
    }
    index.remove(17);
    restored.remove(17);
    assert_eq!(restored.checkpoint(), index.checkpoint());
}
