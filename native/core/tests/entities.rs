use frontline_core::entities::{Entities, Identity, Kind};

#[test]
fn retirement_never_reuses_an_identity_or_changes_survivor_order() {
    let mut entities = Entities::default();
    let mut expected = Vec::new();
    for i in 1..=20_000 {
        let kind = if i % 7 == 0 {
            Kind::Soldier
        } else {
            Kind::Projectile
        };
        assert_eq!(entities.spawn(kind), Ok(i));
        if kind == Kind::Soldier {
            expected.push(Identity { id: i, kind });
        } else {
            assert!(entities.remove(i));
            assert!(!entities.remove(i));
            assert_eq!(entities.get(i), None);
        }
        if i % 73 == 0 {
            assert_eq!(entities.iter().collect::<Vec<_>>(), expected);
            for &entry in &expected {
                assert_eq!(entities.get(entry.id), Some(entry));
            }
        }
    }
    assert_eq!(entities.next_id(), 20_001);
    assert_eq!(entities.len(), expected.len());
    assert!(!entities.is_empty());
}

#[test]
fn checkpoint_retains_registration_order_and_allocation_after_removals() {
    let entries = [
        Identity {
            id: 15,
            kind: Kind::Structure,
        },
        Identity {
            id: 2,
            kind: Kind::Vehicle,
        },
        Identity {
            id: 12,
            kind: Kind::Drone,
        },
    ];
    let mut original = Entities::from_entries(99, &entries).unwrap();
    original.remove(2);
    let bytes = original.checkpoint();
    let mut restored = Entities::restore(&bytes).unwrap();
    assert_eq!(restored.checkpoint(), bytes);
    assert_eq!(
        restored.iter().collect::<Vec<_>>(),
        [entries[0], entries[2]]
    );
    for i in 99..=200 {
        assert_eq!(original.spawn(Kind::Projectile), Ok(i));
        assert_eq!(restored.spawn(Kind::Projectile), Ok(i));
        original.remove(i - 1);
        restored.remove(i - 1);
        assert_eq!(original.checkpoint(), restored.checkpoint());
    }
}

#[test]
fn exhausted_ids_fail_without_mutating_the_registry() {
    let mut entities = Entities::from_entries(u64::from(u32::MAX), &[]).unwrap();
    assert_eq!(entities.spawn(Kind::Soldier), Ok(u32::MAX));
    assert!(entities.remove(u32::MAX));
    let bytes = entities.checkpoint();
    assert!(entities.spawn(Kind::Drone).is_err());
    assert_eq!(entities.checkpoint(), bytes);
    assert!(Entities::restore(&bytes)
        .unwrap()
        .spawn(Kind::Vehicle)
        .is_err());
    assert!(Entities::from_entries(0, &[]).is_err());
    assert!(Entities::from_entries(u64::from(u32::MAX) + 2, &[]).is_err());
}

#[test]
fn malformed_lifecycle_checkpoints_are_rejected() {
    let mut entities = Entities::default();
    entities.spawn(Kind::Soldier).unwrap();
    entities.spawn(Kind::Structure).unwrap();
    let bytes = entities.checkpoint();
    for length in 0..bytes.len() {
        assert!(
            Entities::restore(&bytes[..length]).is_err(),
            "length {length}"
        );
    }
    for (index, value) in [
        (0, b'X'),
        (4, 99),
        (6, 0),
        (16, 255),
        (20, 0),
        (25, 1),
        (24, 255),
    ] {
        let mut corrupt = bytes.clone();
        corrupt[index] = value;
        assert!(Entities::restore(&corrupt).is_err(), "byte {index}");
    }
    let mut trailing = bytes.clone();
    trailing.push(0);
    assert!(Entities::restore(&trailing).is_err());
    let mut stale_cursor = bytes;
    stale_cursor[8..16].copy_from_slice(&2u64.to_le_bytes());
    assert!(Entities::restore(&stale_cursor).is_err());
    let duplicate = [Identity {
        id: 1,
        kind: Kind::Soldier,
    }; 2];
    assert!(Entities::from_entries(3, &duplicate).is_err());
}
