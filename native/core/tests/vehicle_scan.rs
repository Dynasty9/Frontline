use frontline_core::actors::{Actor, Actors};
use frontline_core::collision::{BoxShape, CollisionWorld, Mat3};
use frontline_core::infantry::Infantry;
use frontline_core::infantry_pose::Posture;
use frontline_core::infantry_vitals::Life;
use frontline_core::spatial::{SpatialIndex, STRUCTURE_CELL, UNIT_CELL};
use frontline_core::structure::Structure;
use frontline_core::vector::Vector3;
use frontline_core::vehicle::Vehicle;
use frontline_core::vehicle_scan::{Scan, ScanProfile};
use frontline_core::visibility::{Smoke, Visibility};

fn profile() -> ScanProfile {
    ScanProfile {
        sight: 50.0,
        gun_height: 2.2,
        cannon: false,
        gunship: false,
        anti_air: false,
        penetrating_mg: false,
    }
}
fn soldier(id: u32, x: f32, z: f32) -> Infantry {
    let mut s = Infantry::default();
    s.identity.id = id;
    s.identity.team = 1;
    s.identity.unit = "rifleman".into();
    s.identity.weapon = "rifle".into();
    s.identity.squad = 10;
    s.motion.position = Vector3::new(x, 0.0, z);
    s
}
fn actors(v: Vehicle, soldiers: Vec<Infantry>, others: Vec<Actor>) -> Actors {
    let mut list = vec![Actor::Vehicle(Box::new(Vehicle {
        id: 1,
        team: 0,
        ..v
    }))];
    list.extend(soldiers.into_iter().map(|s| Actor::Soldier(Box::new(s))));
    list.extend(others);
    Actors::from_entries(100, list).unwrap()
}
fn scan(
    a: &mut Actors,
    p: ScanProfile,
    collision: &mut CollisionWorld,
    visibility: &mut Visibility,
) -> Scan {
    let mut units = SpatialIndex::new(UNIT_CELL).unwrap();
    let mut structures = SpatialIndex::new(STRUCTURE_CELL).unwrap();
    a.rebuild_units(&mut units).unwrap();
    for actor in a.iter() {
        if let Actor::Structure(s) = actor {
            structures.insert(s.id, s.position, s.radius).unwrap();
        }
    }
    a.scan_vehicle(
        1,
        p,
        &units,
        &structures,
        collision,
        visibility,
        |v| v.kind == "helicopter",
        |kind| matches!(kind, "depot" | "bunker" | "trench"),
    )
    .unwrap()
}
fn wall(c: &mut CollisionWorld, id: i64, center: Vector3, half: Vector3) {
    assert!(c.replace(
        id,
        &[BoxShape {
            body: id,
            shape: 0,
            center,
            half,
            basis: Mat3::IDENTITY
        }]
    ));
}

#[test]
fn tied_scores_keep_spatial_order_and_existing_targets_get_preference() {
    let mut a = actors(
        Vehicle::default(),
        vec![soldier(2, 1.0, -20.0), soldier(3, -1.0, -20.0)],
        vec![],
    );
    let mut c = CollisionWorld::default();
    let mut vis = Visibility::default();
    assert_eq!(scan(&mut a, profile(), &mut c, &mut vis).target, 3);
    let mut a = actors(
        Vehicle {
            target: 2,
            ..Default::default()
        },
        vec![soldier(2, 1.0, -20.0), soldier(3, -1.0, -20.0)],
        vec![],
    );
    assert_eq!(scan(&mut a, profile(), &mut c, &mut vis).target, 2);
}

#[test]
fn air_targets_require_sam_aa_or_penetrating_machine_guns() {
    for (sam, aa, mg, expected) in [
        (0, false, false, 2),
        (1, false, false, 3),
        (0, true, false, 3),
        (0, false, true, 2),
    ] {
        let mut a = actors(
            Vehicle {
                sam_left: sam,
                ..Default::default()
            },
            vec![soldier(2, 0.0, -20.0)],
            vec![Actor::Vehicle(Box::new(Vehicle {
                id: 3,
                team: 1,
                kind: "helicopter".into(),
                position: Vector3::new(0.0, 14.0, -21.0),
                ..Default::default()
            }))],
        );
        let mut c = CollisionWorld::default();
        let mut vis = Visibility::default();
        assert_eq!(
            scan(
                &mut a,
                ScanProfile {
                    anti_air: aa,
                    penetrating_mg: mg,
                    ..profile()
                },
                &mut c,
                &mut vis
            )
            .target,
            expected
        );
    }
}

#[test]
fn obstruction_proofs_are_reused_and_invalidated_when_the_wall_moves() {
    let mut a = actors(Vehicle::default(), vec![soldier(2, 0.0, -20.0)], vec![]);
    let mut c = CollisionWorld::default();
    let mut vis = Visibility::default();
    wall(
        &mut c,
        90,
        Vector3::new(0.0, 2.0, -10.0),
        Vector3::new(5.0, 4.0, 0.5),
    );
    assert_eq!(scan(&mut a, profile(), &mut c, &mut vis).target, 0);
    let rays = vis.rays;
    assert_eq!(
        scan(&mut a, profile(), &mut c, &mut vis).reused_obstructions,
        1
    );
    assert_eq!(vis.rays, rays);
    wall(
        &mut c,
        90,
        Vector3::new(20.0, 2.0, -10.0),
        Vector3::new(5.0, 4.0, 0.5),
    );
    assert_eq!(scan(&mut a, profile(), &mut c, &mut vis).target, 2);
}

#[test]
fn smoke_is_rechecked_and_reports_do_not_require_line_of_sight() {
    let mut a = actors(
        Vehicle::default(),
        vec![soldier(2, 0.0, -20.0), soldier(3, 1.0, -21.0)],
        vec![],
    );
    let mut c = CollisionWorld::default();
    let mut vis = Visibility::default();
    assert!(vis.set_fires(&[Smoke {
        center: Vector3::new(0.0, 1.0, -10.0),
        radius: 5.0
    }]));
    let result = scan(&mut a, profile(), &mut c, &mut vis);
    assert_eq!(result.target, 0);
    assert_eq!(result.reports, vec![10, 10]);
    assert!(vis.set_fires(&[]));
    assert_eq!(scan(&mut a, profile(), &mut c, &mut vis).target, 2);
}

#[test]
fn pose_resolves_the_mount_from_owned_actors_and_ignores_a_removed_mount() {
    let mut s = soldier(2, 0.0, -20.0);
    s.emplacement.structure = 3;
    s.posture = Posture::Crouch;
    let mut a = actors(
        Vehicle::default(),
        vec![s],
        vec![Actor::Structure(Box::new(Structure {
            id: 3,
            kind: "hmg_nest".into(),
            variant: 1,
            ..Default::default()
        }))],
    );
    let pose = a.infantry_pose(2).unwrap();
    assert!(pose.gun_mount && pose.tower_mount);
    assert_eq!(pose.exposed_points().as_slice()[0].y, 1.15);
    assert!(a.remove(3).is_some());
    assert!(!a.infantry_pose(2).unwrap().mounted);
}

#[test]
fn cannon_building_fallback_needs_team_visibility_and_its_first_hit_can_be_the_building() {
    for (visible, kind, expected) in [(0, "bunker", 0), (1, "trench", 0), (1, "bunker", 2)] {
        let mut a = actors(
            Vehicle::default(),
            vec![],
            vec![Actor::Structure(Box::new(Structure {
                id: 2,
                team: 1,
                kind: kind.into(),
                visible,
                position: Vector3::NEG_Z * 20.0,
                ..Default::default()
            }))],
        );
        let mut c = CollisionWorld::default();
        let mut vis = Visibility::default();
        wall(
            &mut c,
            2,
            Vector3::new(0.0, 1.0, -20.0),
            Vector3::new(3.0, 2.0, 3.0),
        );
        assert!(vis.set_fires(&[Smoke {
            center: Vector3::new(0.0, 1.0, -10.0),
            radius: 5.0
        }]));
        assert_eq!(
            scan(
                &mut a,
                ScanProfile {
                    cannon: true,
                    ..profile()
                },
                &mut c,
                &mut vis
            )
            .target,
            expected
        );
    }
}

#[test]
fn forced_targets_preserve_the_strict_range_and_override_life_and_visibility() {
    for (distance, expected) in [(74.99, 2), (75.0, 0)] {
        let mut s = soldier(2, 0.0, -distance);
        s.vitals.life = Life::Dead;
        let mut a = actors(
            Vehicle {
                forced_target: 2,
                ..Default::default()
            },
            vec![s],
            vec![],
        );
        let mut c = CollisionWorld::default();
        let mut vis = Visibility::default();
        wall(
            &mut c,
            90,
            Vector3::new(0.0, 1.0, -10.0),
            Vector3::splat(5.0),
        );
        assert_eq!(scan(&mut a, profile(), &mut c, &mut vis).target, expected);
        a.remove(2);
        assert_eq!(scan(&mut a, profile(), &mut c, &mut vis).target, 0);
    }
}

#[test]
fn invalid_profile_does_not_change_the_target_or_visibility_cache() {
    let mut a = actors(
        Vehicle {
            target: 2,
            ..Default::default()
        },
        vec![soldier(2, 0.0, -20.0)],
        vec![],
    );
    let before = a.checkpoint().unwrap();
    let mut units = SpatialIndex::new(UNIT_CELL).unwrap();
    a.rebuild_units(&mut units).unwrap();
    let structures = SpatialIndex::new(STRUCTURE_CELL).unwrap();
    let mut c = CollisionWorld::default();
    let mut vis = Visibility::default();
    assert!(a
        .scan_vehicle(
            1,
            ScanProfile {
                sight: f64::NAN,
                ..profile()
            },
            &units,
            &structures,
            &mut c,
            &mut vis,
            |_| false,
            |_| false
        )
        .is_err());
    assert_eq!(a.checkpoint().unwrap(), before);
    assert_eq!(vis.rays, 0);
}
