use frontline_core::collision::{BoxShape, CollisionWorld, Mat3};
use frontline_core::guided::{GuidedFlight, Kind};
use frontline_core::vector::{slerp, Vector3};

fn missile(kind: Kind) -> GuidedFlight {
    GuidedFlight {
        kind,
        position: Vector3::new(0.0, 3.0, 0.0),
        velocity: Vector3::X * 20.0,
        target: Vector3::new(90.0, 2.0, 15.0),
        life: 0.0,
        locked: true,
        dead: false,
    }
}

#[test]
fn restoring_guidance_preserves_tracking_smoke_and_final_impact() {
    let mut collision = CollisionWorld::default();
    for kind in [Kind::AntiTank, Kind::SurfaceToAir] {
        for lose_target in [false, true] {
            let mut a = missile(kind);
            for tick in 0..500 {
                let mut b = GuidedFlight::restore(&a.checkpoint()).unwrap();
                let target = (!lose_target || tick < 10).then_some(Vector3::new(
                    90.0,
                    2.0,
                    tick as f32 * 0.2,
                ));
                let smoke = tick > 12;
                let expected = a.advance(1.0 / 30.0, target, smoke, &mut collision, &[]);
                assert_eq!(
                    expected,
                    b.advance(1.0 / 30.0, target, smoke, &mut collision, &[])
                );
                assert_eq!(a, b);
                if expected.is_some() {
                    let dead = a;
                    assert!(a.advance(1.0, target, false, &mut collision, &[]).is_none());
                    assert_eq!(a, dead);
                    break;
                }
            }
            assert!(a.dead);
            if !lose_target {
                assert_eq!(a.locked, kind == Kind::SurfaceToAir);
            }
        }
    }
}

#[test]
fn impact_precedence_exclusions_and_sam_proximity_match_combat_rules() {
    let mut collision = CollisionWorld::default();
    assert!(collision.replace(
        7,
        &[BoxShape {
            body: 7,
            shape: 0,
            center: Vector3::new(2.0, 3.0, 0.0),
            basis: Mat3::IDENTITY,
            half: Vector3::new(0.1, 8.0, 5.0)
        }]
    ));
    let mut a = missile(Kind::AntiTank);
    a.life = 8.0;
    let hit = a.advance(0.1, None, false, &mut collision, &[]).unwrap();
    assert!((hit.position.x - 1.9).abs() < 0.0001);
    let mut b = missile(Kind::AntiTank);
    assert!(b.advance(0.1, None, false, &mut collision, &[7]).is_none());
    let mut sam = missile(Kind::SurfaceToAir);
    let target = Vector3::new(5.0, 3.0, 0.0);
    let hit = sam
        .advance(0.1, Some(target), false, &mut collision, &[])
        .unwrap();
    assert!(hit.proximity);
    assert_eq!(hit.position, target);
    let mut lost = missile(Kind::SurfaceToAir);
    lost.target = target;
    assert!(lost
        .advance(0.1, None, false, &mut collision, &[])
        .is_none());
}

#[test]
fn malformed_guidance_and_degenerate_steering_are_safe() {
    let bytes = missile(Kind::AntiTank).checkpoint();
    for end in 0..bytes.len() {
        assert!(GuidedFlight::restore(&bytes[..end]).is_err());
    }
    for i in [4, 8, 9, 10] {
        let mut bad = bytes.clone();
        bad[i] = 2;
        assert!(GuidedFlight::restore(&bad).is_err());
    }
    for i in (11..47).step_by(4) {
        let mut bad = bytes.clone();
        bad[i..i + 4].copy_from_slice(&f32::NAN.to_le_bytes());
        assert!(GuidedFlight::restore(&bad).is_err());
    }
    let mut bad = bytes.clone();
    bad[47..].copy_from_slice(&f64::INFINITY.to_le_bytes());
    assert!(GuidedFlight::restore(&bad).is_err());
    let mut bad = bytes;
    bad.push(0);
    assert!(GuidedFlight::restore(&bad).is_err());
    assert_eq!(slerp(Vector3::X, -Vector3::X, 0.5), Vector3::ZERO);
    assert_eq!(slerp(Vector3::ZERO, Vector3::X, 0.5), Vector3::X * 0.5);
}
