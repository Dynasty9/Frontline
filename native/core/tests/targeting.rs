use frontline_core::collision::{BoxShape, CollisionWorld, Mat3};
use frontline_core::targeting::{scan, Contact, DroneContact, Observer, TargetKind};
use frontline_core::vector::Vector3;
use frontline_core::visibility::{Smoke, Visibility};

fn observer() -> Observer {
    Observer {
        position: Vector3::ZERO,
        eye: Vector3::Y,
        team: 0,
        current: 0,
        forced: 0,
        forced_structure: None,
        weapon_range: 50.0,
        rockets: false,
        armor_piercing: false,
        mount_forward: None,
        cache_obstruction: true,
    }
}
fn contact(id: u64, x: f32, kind: TargetKind) -> Contact {
    Contact {
        id,
        position: Vector3::X * x,
        kind,
        points: vec![Vector3::new(x, 1.0, 0.0)],
        excluded: vec![],
    }
}
fn infantry() -> TargetKind {
    TargetKind::Infantry {
        downed: false,
        machine_gunner: false,
    }
}

#[test]
fn acquisition_preserves_priority_ties_reporting_and_mount_arcs() {
    let mut geometry = CollisionWorld::default();
    let mut sight = Visibility::default();
    let contacts = vec![
        contact(2, 10.0, infantry()),
        contact(1, -10.0, infantry()),
        contact(3, 8.0, TargetKind::Vehicle { armor: 2 }),
    ];
    let result = scan(observer(), &contacts, &[], &mut geometry, &mut sight).unwrap();
    assert_eq!(result.target, 2);
    assert_eq!(result.visible, vec![2, 1, 3]);
    assert_eq!(result.reported, 3);
    let mut o = observer();
    o.current = 1;
    assert_eq!(
        scan(o, &contacts, &[], &mut geometry, &mut sight)
            .unwrap()
            .target,
        1
    );
    o.rockets = true;
    assert_eq!(
        scan(o, &contacts, &[], &mut geometry, &mut sight)
            .unwrap()
            .target,
        3
    );
    o.mount_forward = Some(-Vector3::X);
    let result = scan(o, &contacts, &[], &mut geometry, &mut sight).unwrap();
    assert_eq!(result.target, 1);
    assert_eq!(
        result.visible,
        vec![2, 1, 3],
        "flanking contacts are still reported"
    );
    let contacts = vec![
        contact(1, 10.0, infantry()),
        contact(
            2,
            12.0,
            TargetKind::Infantry {
                downed: false,
                machine_gunner: true,
            },
        ),
    ];
    assert_eq!(
        scan(observer(), &contacts, &[], &mut geometry, &mut sight)
            .unwrap()
            .target,
        2
    );
}

#[test]
fn drones_and_forced_orders_keep_existing_override_order_and_boundaries() {
    let mut geometry = CollisionWorld::default();
    let mut sight = Visibility::default();
    let contacts = vec![contact(1, 3.0, infantry())];
    let mut drones = vec![
        DroneContact {
            id: 9,
            position: Vector3::X * 29.0,
            team: 1,
            dead: false,
            diving: false,
        },
        DroneContact {
            id: 8,
            position: Vector3::Z * 37.0,
            team: 1,
            dead: false,
            diving: false,
        },
    ];
    let result = scan(observer(), &contacts, &drones, &mut geometry, &mut sight).unwrap();
    assert_eq!(result.target, 9);
    assert_eq!(result.visible, vec![1, 9, 8]);
    assert_eq!(
        result.reported, 1,
        "drones do not enter the squad's ground contact reports"
    );
    drones[1].diving = true;
    assert_eq!(
        scan(observer(), &contacts, &drones, &mut geometry, &mut sight)
            .unwrap()
            .target,
        8
    );
    drones[1].position = Vector3::Z * 38.0;
    assert_eq!(
        scan(observer(), &contacts, &drones, &mut geometry, &mut sight)
            .unwrap()
            .target,
        9
    );
    let mut o = observer();
    o.forced = 1;
    assert_eq!(
        scan(o, &contacts, &drones, &mut geometry, &mut sight)
            .unwrap()
            .target,
        1
    );
    o.forced = 7;
    o.forced_structure = Some(Vector3::X * 49.0);
    assert_eq!(
        scan(o, &contacts, &drones, &mut geometry, &mut sight)
            .unwrap()
            .target,
        7
    );
    o.forced_structure = Some(Vector3::X * 50.0);
    assert_eq!(
        scan(o, &contacts, &drones, &mut geometry, &mut sight)
            .unwrap()
            .target,
        9
    );
}

#[test]
fn blocked_contacts_exclusions_and_smoke_use_the_shared_numeric_world() {
    let mut geometry = CollisionWorld::default();
    let mut sight = Visibility::default();
    geometry.replace(
        4,
        &[BoxShape {
            body: 4,
            shape: 0,
            center: Vector3::new(5.0, 1.0, 0.0),
            basis: Mat3::IDENTITY,
            half: Vector3::new(0.5, 2.0, 2.0),
        }],
    );
    let mut contacts = vec![contact(1, 10.0, infantry())];
    assert_eq!(
        scan(observer(), &contacts, &[], &mut geometry, &mut sight)
            .unwrap()
            .target,
        0
    );
    assert_eq!(
        scan(observer(), &contacts, &[], &mut geometry, &mut sight)
            .unwrap()
            .reused,
        1
    );
    contacts[0].excluded.push(4);
    assert_eq!(
        scan(observer(), &contacts, &[], &mut geometry, &mut sight)
            .unwrap()
            .target,
        1
    );
    sight.set_projectile(
        5,
        Smoke {
            center: Vector3::new(5.0, 1.0, 0.0),
            radius: 2.0,
        },
    );
    assert_eq!(
        scan(observer(), &contacts, &[], &mut geometry, &mut sight)
            .unwrap()
            .target,
        0
    );
    contacts[0].points[0].x = f32::NAN;
    assert!(scan(observer(), &contacts, &[], &mut geometry, &mut sight).is_err());
}
