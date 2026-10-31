use frontline_core::collision::{BoxShape, CollisionWorld, Mat3};
use frontline_core::cover::{Anchor, AnchorKind};
use frontline_core::cover_search::{Scene, Structure};
use frontline_core::infantry::{Goal, Identity, Infantry};
use frontline_core::infantry_pose::Posture;
use frontline_core::infantry_tactics::{CoverRequest, Shelter};
use frontline_core::path_planner::PathPlanner;
use frontline_core::random::SimulationRandom;
use frontline_core::terrain::Terrain;
use frontline_core::vector::Vector3;

fn soldier() -> Infantry {
    Infantry {
        identity: Identity {
            id: 1,
            unit: "rifleman".into(),
            ..Default::default()
        },
        ..Default::default()
    }
}

#[test]
fn cover_review_keeps_valid_positions_and_releases_moved_burning_or_missing_shelter() {
    let mut s = soldier();
    s.cover.kind = 1;
    s.cover.at_cover = true;
    s.cover.structure = 10;
    s.cover.anchor = 0;
    s.cover.threat = Vector3::Z;
    s.cover.evaluate_at = 10.0;
    let threats = [Vector3::Z * 20.0];
    assert!(!s
        .reevaluate_cover(
            10.1,
            Some(Shelter {
                gone: false,
                burn: 0.3,
                anchors: &[Vector3::ZERO]
            }),
            &threats
        )
        .unwrap());
    assert_eq!(s.cover.evaluate_at, 12.6);
    assert!(s
        .reevaluate_cover(
            11.0,
            Some(Shelter {
                gone: false,
                burn: 0.3001,
                anchors: &[Vector3::ZERO]
            }),
            &threats
        )
        .unwrap());
    assert_eq!(s.cover.structure, 0);
    for anchors in [&[][..], &[Vector3::X][..]] {
        s.cover.structure = 10;
        assert!(s
            .reevaluate_cover(
                11.0,
                Some(Shelter {
                    gone: false,
                    burn: 0.0,
                    anchors
                }),
                &threats
            )
            .unwrap());
        assert_eq!(s.cover.structure, 0);
    }
    s.cover.structure = 10;
    assert!(s.reevaluate_cover(11.0, None, &threats).unwrap());
    s.orders.purpose = Goal::Cover;
    s.orders.pending_path = true;
    assert!(!s.reevaluate_cover(100.0, None, &threats).unwrap());
}

#[test]
fn renewed_threats_break_concealment_and_quiet_sectors_keep_their_deadline() {
    let mut s = soldier();
    s.cover.at_cover = true;
    s.cover.kind = 3;
    s.cover.threat = Vector3::Z;
    s.cover.evaluate_at = 10.0;
    let forward = [Vector3::Z * 20.0];
    assert!(!s.reevaluate_cover(10.0, None, &[Vector3::NEG_Z]).unwrap());
    assert!(s.reevaluate_cover(10.01, None, &[Vector3::NEG_Z]).unwrap());
    s.vitals.suppression = 46.0;
    s.fight.visible_targets = vec![13];
    assert!(s.reevaluate_cover(10.01, None, &forward).unwrap());
    s.vitals.suppression = 45.0;
    assert!(!s.reevaluate_cover(10.01, None, &forward).unwrap());
    assert_eq!(s.cover.evaluate_at, 12.51);
}

#[test]
fn speed_and_crawl_require_an_active_cover_route_and_preserve_fatigue_thresholds() {
    let mut s = soldier();
    s.orders.purpose = Goal::Cover;
    s.orders.goal = Vector3::X * 2.5;
    s.vitals.suppression = 70.0;
    assert!(!s.crawling(true));
    s.motion.path.push(s.orders.goal);
    assert!(s.crawling(false));
    assert_eq!(s.movement_speed(false), 0.95);
    s.vitals.suppression = 69.9;
    s.cover.shifting = true;
    s.cover.height = 1.119;
    assert!(s.crawling(true));
    assert!(!s.crawling(false));
    s.cover.height = 1.12;
    assert!(!s.crawling(true));
    s.identity.unit = "mg_gunner".into();
    s.posture = Posture::Crouch;
    s.vitals.stamina = 0.1;
    assert_eq!(s.movement_speed(true), 3.4 * 0.9 * 0.8 * 0.75);
    s.vitals.stamina = 0.35;
    assert_eq!(s.movement_speed(true), 3.4 * 0.9 * 0.8);
}

#[test]
fn sectors_watch_flanks_and_rear_until_the_rear_man_has_his_own_contact() {
    let mut s = soldier();
    assert_eq!(
        s.sector_direction(&[], Vector3::ZERO, 5, false).unwrap(),
        Vector3::NEG_Z
    );
    assert_eq!(
        s.sector_direction(&[], Vector3::ZERO, 6, true).unwrap(),
        Vector3::Z
    );
    s.fight.visible_targets.push(4);
    assert_eq!(
        s.sector_direction(&[], Vector3::ZERO, 6, true).unwrap(),
        Vector3::NEG_Z
    );
    s.motion.position = Vector3::X * 5.0;
    let sector = s
        .sector_direction(&[Vector3::new(5.0, 0.0, -20.0)], Vector3::ZERO, 6, false)
        .unwrap();
    assert!(sector.x > 0.6 && sector.z < -0.7);
    assert!((sector.length() - 1.0).abs() < 1e-6);
    assert_eq!(
        s.threat_direction(&[Vector3::X * 4.0, Vector3::X * 6.0])
            .unwrap(),
        s.orders.hold_face
    );
}

#[test]
fn cover_search_applies_the_choice_and_issues_the_retained_route_in_one_operation() {
    let terrain = Terrain::blank(64).unwrap();
    let nav = PathPlanner::new(64).unwrap();
    let mut collision = CollisionWorld::default();
    collision.replace(
        10,
        &[BoxShape {
            body: 10,
            shape: 0,
            center: Vector3::new(0.0, 0.6, 1.0),
            basis: Mat3::IDENTITY,
            half: Vector3::new(8.0, 0.6, 0.2),
        }],
    );
    let structures = [Structure {
        id: 10,
        built: true,
        burn: 0.0,
        material: 2,
        positions: vec![Anchor {
            position: Vector3::X * -2.0,
            normal: Vector3::Z,
            height: 1.2,
            kind: AnchorKind::Over,
        }],
    }];
    let mut scene = Scene {
        terrain: &terrain,
        navigation: &nav,
        collision: &mut collision,
        heat: &[],
        deck: &[],
        structures: &structures,
        squad_claims: &[],
        nearby_claims: &[],
    };
    let mut s = soldier();
    s.vitals.suppression = 36.0;
    let mut rng = SimulationRandom::new(73);
    let mut expected = rng;
    let request = CoverRequest {
        time: 100.0,
        anchor: Vector3::ZERO,
        radius: 9.0,
        threats: &[Vector3::new(0.0, 1.6, 20.0)],
        grouped: true,
        unarmed: false,
        weapon_range: 50.0,
        danger: true,
    };
    let result = s.seek_cover(request, &mut scene, &mut rng).unwrap();
    assert_eq!(s.cover.structure, 10);
    assert_eq!(s.cover.anchor, 0);
    assert!(!s.cover.at_cover);
    assert_eq!(result.route.unwrap().job.destination, s.cover.position);
    assert_eq!(s.orders.move_mode, 2);
    assert_eq!(s.orders.purpose, Goal::Cover);
    assert_eq!(
        s.cover.evaluate_at,
        100.0 + f64::from(expected.randf_range(3.5, 6.0))
    );
    assert_eq!(rng, expected);
    let original = s.clone();
    let random = rng;
    let bad = CoverRequest {
        radius: f64::NAN,
        ..request
    };
    assert!(s.seek_cover(bad, &mut scene, &mut rng).is_err());
    assert_eq!(s, original);
    assert_eq!(rng, random);
    scene.structures = &[];
    s.motion.position = Vector3::X * 15.0;
    let result = s.seek_cover(request, &mut scene, &mut rng).unwrap();
    assert!(result.search.choice.is_none());
    assert_eq!(result.route.unwrap().job.destination, request.anchor);
    assert_eq!(s.orders.purpose, Goal::Slot);
    assert_eq!(
        (s.cover.kind, s.cover.structure, s.cover.material),
        (0, 0, -1)
    );
}
