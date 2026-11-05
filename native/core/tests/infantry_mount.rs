use frontline_core::collision::{BoxShape, CollisionWorld, Mat3};
use frontline_core::infantry_mount::{self as crew, Contact, GunPose, Mount, Station};
use frontline_core::vector::Vector3;
use frontline_core::visibility::{Smoke, Visibility};

fn contact(id: u64, x: f32) -> Contact {
    Contact {
        id,
        team: 1,
        revealed: true,
        position: Vector3::X * x,
        points: vec![Vector3::new(x, 1.3, 0.0)],
        excluded: vec![],
    }
}

#[test]
fn approach_and_climb_keep_the_existing_tick_boundaries() {
    let mut mount = Mount::default();
    assert_eq!(mount.station(0.1, true, true), Ok(Station::Move));
    assert_eq!(mount, Mount::default());
    assert_eq!(mount.station(0.1, true, false), Ok(Station::StartClimb));
    assert_eq!((mount.phase, mount.timer), (1, 1.6));
    assert_eq!(
        mount.station(0.8, true, false),
        Ok(Station::Climb {
            height: 2.125,
            finished: false
        })
    );
    assert_eq!(
        mount.station(0.8, true, false),
        Ok(Station::Climb {
            height: 4.25,
            finished: true
        })
    );
    assert_eq!(mount.phase, 2);
    assert_eq!(mount.station(0.8, true, true), Ok(Station::Ready));
    assert_eq!(
        Mount::default().station(0.0, false, false),
        Ok(Station::Man)
    );
}

#[test]
fn scan_clock_clears_the_old_target_only_when_due() {
    let mut mount = Mount {
        scan_timer: 0.1,
        target: 45,
        ..Default::default()
    };
    assert!(!mount.scan_due(0.05).unwrap());
    assert_eq!(mount.target, 45);
    assert!(mount.scan_due(0.05).unwrap());
    assert_eq!((mount.scan_timer, mount.target), (0.7, 0));
}

#[test]
fn guns_traverse_before_testing_alignment_and_respect_the_mount_limit() {
    let pose = GunPose {
        position: Vector3::ZERO,
        yaw: 0.0,
        dt: 0.1,
        mount: Some((Vector3::ZERO, 0.2)),
    };
    let aim = crew::mortar_aim(pose, Vector3::X * 50.0).unwrap();
    assert_eq!(aim.yaw, f64::from(-0.02f32));
    assert!(!aim.aligned);
    let (aim, dir) = crew::antitank_aim(pose, Vector3::ZERO, Vector3::NEG_Z * 40.0).unwrap();
    assert!(aim.aligned);
    assert_eq!(dir, Vector3::NEG_Z);
    assert!(
        crew::mortar_aim(pose, Vector3::NEG_Z * 40.0)
            .unwrap()
            .aligned
    );
}

#[test]
fn scan_keeps_range_ties_fog_smoke_and_obstruction_cache_behavior() {
    let mut collision = CollisionWorld::default();
    let mut sight = Visibility::default();
    let mut contacts = vec![contact(1, 130.0), contact(2, -130.0), contact(3, 130.01)];
    assert_eq!(
        crew::scan(0, Vector3::ZERO, &contacts, &mut collision, &mut sight)
            .unwrap()
            .target,
        2
    );
    contacts[1].revealed = false;
    assert_eq!(
        crew::scan(0, Vector3::ZERO, &contacts, &mut collision, &mut sight)
            .unwrap()
            .target,
        1
    );
    contacts[0].team = 0;
    assert_eq!(
        crew::scan(0, Vector3::ZERO, &contacts, &mut collision, &mut sight)
            .unwrap()
            .target,
        0
    );
    let mut contacts = vec![contact(1, 10.0)];
    collision.replace(
        4,
        &[BoxShape {
            body: 4,
            shape: 0,
            center: Vector3::new(5.0, 1.0, 0.0),
            basis: Mat3::IDENTITY,
            half: Vector3::new(0.5, 2.0, 2.0),
        }],
    );
    assert_eq!(
        crew::scan(0, Vector3::ZERO, &contacts, &mut collision, &mut sight)
            .unwrap()
            .target,
        0
    );
    assert_eq!(
        crew::scan(0, Vector3::ZERO, &contacts, &mut collision, &mut sight)
            .unwrap()
            .reused,
        1
    );
    contacts[0].excluded.push(4);
    assert_eq!(
        crew::scan(0, Vector3::ZERO, &contacts, &mut collision, &mut sight)
            .unwrap()
            .target,
        1
    );
    sight.set_projectile(
        5,
        Smoke {
            center: Vector3::new(5.0, 1.3, 0.0),
            radius: 2.0,
        },
    );
    assert_eq!(
        crew::scan(0, Vector3::ZERO, &contacts, &mut collision, &mut sight)
            .unwrap()
            .target,
        0
    );
    sight.remove_projectile(5);
    assert_eq!(
        crew::scan(0, Vector3::ZERO, &contacts, &mut collision, &mut sight)
            .unwrap()
            .target,
        1
    );
}

#[test]
fn checkpoints_resume_and_invalid_input_does_not_change_state() {
    let mut mount = Mount {
        phase: 1,
        timer: 0.16,
        scan_timer: 0.2,
        target: 17,
    };
    let bytes = mount.checkpoint();
    let mut restored = Mount::restore(&bytes).unwrap();
    for _ in 0..30 {
        assert_eq!(
            mount.station(1.0 / 30.0, true, false),
            restored.station(1.0 / 30.0, true, false)
        );
        assert_eq!(mount.scan_due(1.0 / 30.0), restored.scan_due(1.0 / 30.0));
        assert_eq!(mount.checkpoint(), restored.checkpoint());
    }
    let before = mount;
    for dt in [f64::NAN, f64::INFINITY, -0.1, 10.1] {
        assert!(mount.station(dt, true, false).is_err());
        assert!(mount.scan_due(dt).is_err());
        assert_eq!(mount, before);
    }
    for n in 0..bytes.len() {
        assert!(Mount::restore(&bytes[..n]).is_err());
    }
    let mut extra = bytes.clone();
    extra.push(0);
    assert!(Mount::restore(&extra).is_err());
    for (index, value) in [(4, 2), (6, 0), (8, 3)] {
        let mut invalid = bytes.clone();
        invalid[index] = value;
        assert!(Mount::restore(&invalid).is_err());
    }
    let mut bad = contact(0, 10.0);
    assert!(crew::scan(
        0,
        Vector3::ZERO,
        &[bad.clone()],
        &mut CollisionWorld::default(),
        &mut Visibility::default()
    )
    .is_err());
    bad.id = 1;
    bad.position.x = f32::NAN;
    assert!(crew::scan(
        0,
        Vector3::ZERO,
        &[bad],
        &mut CollisionWorld::default(),
        &mut Visibility::default()
    )
    .is_err());
}
