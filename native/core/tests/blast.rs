use frontline_core::blast::{Blast, Infantry, Protection};
use frontline_core::infantry_pose::Posture;
use frontline_core::infantry_vitals::Life;
use frontline_core::vector::Vector3 as V;

fn blast() -> Blast {
    Blast {
        position: V::ZERO,
        damage: 100.0,
        radius: 5.0,
        fling: 8.0,
        in_trench: false,
    }
}
fn victim() -> Infantry {
    Infantry {
        center: V::ZERO,
        life: Life::Alive,
        posture: Posture::Stand,
        in_trench: false,
        terrain_multiplier: 1.0,
    }
}

#[test]
fn blast_shelter_and_posture_preserve_damage_and_fling_rules() {
    let direct = blast().infantry(victim(), Protection::default()).unwrap();
    assert_eq!(direct.damage, 100.0);
    assert_eq!(direct.fling, 10.0);
    assert_eq!(direct.flinch_radius, 12.0);
    let prone = blast()
        .infantry(
            Infantry {
                posture: Posture::Prone,
                ..victim()
            },
            Protection::default(),
        )
        .unwrap();
    assert_eq!(prone.damage, 100.0 * 0.55);
    let corpse = blast()
        .infantry(
            Infantry {
                posture: Posture::Prone,
                life: Life::Dead,
                ..victim()
            },
            Protection::default(),
        )
        .unwrap();
    assert_eq!(corpse.damage, 100.0);
    for (material, expected) in [(0, 80.0), (1, 45.0), (2, 25.0), (3, 20.0)] {
        let protected = blast()
            .infantry(
                victim(),
                Protection {
                    blocked: true,
                    material: Some(material),
                },
            )
            .unwrap();
        assert_eq!(protected.damage, expected);
        assert_eq!(protected.fling, 0.0);
    }
    let sheltered = blast()
        .infantry(
            Infantry {
                in_trench: true,
                ..victim()
            },
            Protection::default(),
        )
        .unwrap();
    assert_eq!(sheltered.damage, 12.5);
    assert!(sheltered.blocked && sheltered.sheltered);
    assert_eq!(sheltered.fling, 0.0);
    assert_eq!(
        Blast {
            in_trench: true,
            ..blast()
        }
        .infantry(
            Infantry {
                in_trench: true,
                ..victim()
            },
            Protection::default()
        )
        .unwrap(),
        direct
    );
}

#[test]
fn blast_radius_edges_hidden_soldiers_and_small_damage_skip_their_effects() {
    let edge = blast()
        .infantry(
            Infantry {
                center: V::X * 5.0,
                ..victim()
            },
            Protection::default(),
        )
        .unwrap();
    assert_eq!(edge.damage, 0.0);
    assert_eq!(edge.fling, 0.0);
    assert_eq!(edge.flinch_radius, 12.0);
    let edge = blast()
        .infantry(
            Infantry {
                center: V::X * 12.0,
                ..victim()
            },
            Protection::default(),
        )
        .unwrap();
    assert_eq!(edge.flinch_radius, 0.0);
    assert_eq!(
        blast()
            .infantry(
                Infantry {
                    life: Life::Hidden,
                    ..victim()
                },
                Protection::default()
            )
            .unwrap(),
        Default::default()
    );
    assert_eq!(
        Blast {
            damage: 3.0,
            ..blast()
        }
        .infantry(victim(), Protection::default())
        .unwrap()
        .damage,
        0.0
    );
    assert_eq!(
        Blast {
            radius: 0.0,
            ..blast()
        }
        .infantry(victim(), Protection::default())
        .unwrap()
        .damage,
        0.0
    );
}

#[test]
fn structures_use_their_radius_and_fragility_without_zero_radius_division() {
    assert_eq!(
        blast().structure(V::ZERO, 2.0, false, 1.0).unwrap(),
        Some(100.0)
    );
    assert_eq!(
        blast().structure(V::ZERO, 2.0, true, 1.5).unwrap(),
        Some(900.0)
    );
    assert_eq!(
        blast().structure(V::X * 6.0, 2.0, false, 1.0).unwrap(),
        None
    );
    assert_eq!(
        Blast {
            radius: 0.0,
            ..blast()
        }
        .structure(V::ZERO, 2.0, false, 1.0)
        .unwrap(),
        Some(100.0)
    );
    assert!(Blast {
        damage: f64::NAN,
        ..blast()
    }
    .infantry(victim(), Protection::default())
    .is_err());
    assert!(blast()
        .infantry(
            victim(),
            Protection {
                blocked: true,
                material: Some(4)
            }
        )
        .is_err());
    assert!(blast().structure(V::INFINITY, 2.0, true, 1.0).is_err());
}
