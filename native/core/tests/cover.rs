use frontline_core::collision::{BoxShape, CollisionWorld, Mat3};
use frontline_core::cover::{evaluate, generate, Anchor, AnchorKind, CoverType, Part};
use frontline_core::vector::Vector3;

fn anchor(kind: AnchorKind, height: f64) -> Anchor {
    Anchor {
        position: Vector3::ZERO,
        normal: Vector3::Z,
        height,
        kind,
    }
}

fn wall(geometry: &mut CollisionWorld, z: f32, height: f32, half_width: f32) {
    assert!(geometry.replace(
        1,
        &[BoxShape {
            body: 1,
            shape: 0,
            center: Vector3::new(0.0, height * 0.5, z),
            basis: Mat3::IDENTITY,
            half: Vector3::new(half_width, height * 0.5, 0.2),
        }]
    ));
}

#[test]
fn cover_requires_a_near_barrier_facing_the_threat_and_keeps_all_threats_in_the_score() {
    let mut geometry = CollisionWorld::default();
    let threats = [
        Vector3::new(0.0, 1.4, 20.0),
        Vector3::new(0.0, 1.4, -20.0),
        Vector3::Y,
    ];
    let a = anchor(AnchorKind::Over, 1.0);
    assert_eq!(
        evaluate(&mut geometry, a, 0.0, &threats, false).unwrap(),
        None
    );
    wall(&mut geometry, 1.0, 1.0, 5.0);
    let result = evaluate(&mut geometry, a, 0.0, &threats, false)
        .unwrap()
        .unwrap();
    assert_eq!(result.kind, CoverType::Low);
    assert_eq!(result.protection, 1.0 / 3.0);
    assert_eq!(result.threat_direction, Vector3::Z);
    assert!(result.fire);
    assert_eq!(evaluate(&mut geometry, a, 0.0, &[], false).unwrap(), None);
    wall(&mut geometry, 5.0, 3.0, 5.0);
    assert_eq!(
        evaluate(&mut geometry, a, 0.0, &threats, false).unwrap(),
        None
    );
}

#[test]
fn edge_firing_shelter_prone_and_geometry_resume_preserve_cover() {
    let mut geometry = CollisionWorld::default();
    wall(&mut geometry, 1.0, 2.0, 0.3);
    let threats = [Vector3::new(0.0, 1.4, 20.0), Vector3::new(1.0, 1.4, 30.0)];
    for kind in [
        AnchorKind::EdgeLeft,
        AnchorKind::EdgeRight,
        AnchorKind::Shelter,
        AnchorKind::Stack,
    ] {
        let a = anchor(kind, 2.0);
        let result = evaluate(&mut geometry, a, 0.0, &threats, false)
            .unwrap()
            .unwrap();
        assert_eq!(result.protection, 1.0);
        let edge = matches!(kind, AnchorKind::EdgeLeft | AnchorKind::EdgeRight);
        assert_eq!(
            result.kind,
            if edge {
                CoverType::Lean
            } else {
                CoverType::Hide
            }
        );
        assert_eq!(result.fire, edge);
        let mut restored = CollisionWorld::restore(&geometry.checkpoint()).unwrap();
        assert_eq!(
            evaluate(&mut restored, a, 0.0, &threats, false).unwrap(),
            Some(result)
        );
    }
    wall(&mut geometry, 1.0, 0.5, 5.0);
    let a = anchor(AnchorKind::Over, 1.0);
    assert_eq!(
        evaluate(&mut geometry, a, 0.0, &threats, false).unwrap(),
        None
    );
    assert!(evaluate(&mut geometry, a, 0.0, &threats, true)
        .unwrap()
        .is_some());
    let a = anchor(AnchorKind::Over, 0.5);
    assert!(evaluate(&mut geometry, a, 0.0, &threats, false)
        .unwrap()
        .is_some());
}

#[test]
fn cover_rejects_invalid_input_without_changing_geometry() {
    let mut geometry = CollisionWorld::default();
    wall(&mut geometry, 1.0, 1.0, 4.0);
    let saved = geometry.checkpoint();
    let a = anchor(AnchorKind::Over, 1.0);
    assert!(evaluate(&mut geometry, a, 0.0, &[Vector3::NAN], false).is_err());
    assert!(evaluate(&mut geometry, a, f64::NAN, &[], false).is_err());
    assert!(evaluate(&mut geometry, a, 0.0, &vec![Vector3::Z; 4097], false).is_err());
    assert!(evaluate(&mut geometry, Anchor { height: -1.0, ..a }, 0.0, &[], false).is_err());
    assert_eq!(geometry.checkpoint(), saved);
}

#[test]
fn anchors_preserve_face_order_overflow_rows_map_edges_and_trench_steps() {
    let part = Part {
        position: Vector3::Y * 1.5,
        size: Vector3::new(8.0, 3.0, 0.6),
        yaw: 0.0,
        cover: true,
        collision: true,
        blocks_navigation: true,
    };
    let anchors = generate(
        "house_wall",
        0,
        Vector3::ZERO,
        0.0,
        Vector3::ONE,
        &[part],
        50.0,
    )
    .unwrap();
    assert_eq!(anchors.len(), 20);
    assert_eq!(anchors[0].kind, AnchorKind::EdgeRight);
    assert_eq!(anchors[1].kind, AnchorKind::EdgeLeft);
    assert!(anchors[2..6].iter().all(|a| a.kind == AnchorKind::Shelter));
    assert!(anchors[6..10].iter().all(|a| a.kind == AnchorKind::Stack));
    assert!(anchors[..10].iter().all(|a| a.normal == Vector3::Z));
    assert!(anchors[10..].iter().all(|a| a.normal == -Vector3::Z));
    assert_eq!(anchors[2].position.z - anchors[6].position.z, 1.5);
    let edge = generate(
        "house_wall",
        0,
        Vector3::new(49.0, 0.0, 0.0),
        0.0,
        Vector3::ONE,
        &[part],
        50.0,
    )
    .unwrap();
    assert!(!edge.is_empty() && edge.len() < anchors.len());
    assert!(edge.iter().all(|a| a.position.x.abs() < 48.0));
    assert!(
        generate("tree", 0, Vector3::ZERO, 0.0, Vector3::ONE, &[part], 50.0)
            .unwrap()
            .is_empty()
    );
    let trench = generate(
        "trench",
        0,
        Vector3::ZERO,
        0.0,
        Vector3::new(5.0, 1.0, 1.0),
        &[],
        50.0,
    )
    .unwrap();
    assert_eq!(trench.len(), 8);
    assert_eq!(trench[0].normal, -Vector3::Z);
    assert_eq!(trench[1].normal, Vector3::Z);
    assert_eq!(trench[0].position.z, -0.38);
    assert_eq!(trench[1].position.z, 0.38);
    assert!(generate("house_wall", 0, Vector3::NAN, 0.0, Vector3::ONE, &[], 50.0).is_err());
    assert!(generate(
        "house_wall",
        0,
        Vector3::ZERO,
        f64::MAX,
        Vector3::ONE,
        &[],
        50.0
    )
    .is_err());
}
