use frontline_core::infantry_pose::{InfantryPose, Posture};
use frontline_core::infantry_vitals::Life;
use frontline_core::vector::Vector3 as V;

fn pose() -> InfantryPose {
    InfantryPose {
        position: V::ZERO,
        posture: Posture::Stand,
        life: Life::Alive,
        at_cover: false,
        cover_kind: 0,
        cover_height: 0.0,
        cover_normal: V::X,
        lean_direction: V::Z,
        mounted: false,
        gun_mount: false,
        tower_mount: false,
        peek_up: false,
        blind: false,
        moving: false,
        move_mode: 0,
        ground: 0.0,
    }
}

#[test]
fn cover_height_boundaries_preserve_firing_stance_and_exposure() {
    let mut p = InfantryPose {
        at_cover: true,
        cover_kind: 1,
        ..pose()
    };
    for (height, down, up) in [
        (0.61, Posture::Prone, Posture::Prone),
        (0.62, Posture::Prone, Posture::Crouch),
        (0.8, Posture::Crouch, Posture::Crouch),
        (1.12, Posture::Crouch, Posture::Stand),
    ] {
        p.cover_height = height;
        assert_eq!(p.cover_posture(false), down);
        assert_eq!(p.cover_posture(true), up);
        p.peek_up = true;
        assert_eq!(p.eye(), p.scan_eye());
        assert_eq!(p.hit_factor(), 0.3);
        assert_eq!(p.exposed_points().as_slice().len(), 2);
        p.blind = true;
        assert_eq!(p.eye(), V::Y * 1.5);
        assert_eq!(p.hit_factor(), 0.45);
        p.blind = false;
    }
}

#[test]
fn wounds_movement_trenches_and_mounts_keep_geometry_precedence() {
    let mut p = InfantryPose {
        life: Life::Downed,
        posture: Posture::Prone,
        moving: true,
        ground: -1.0,
        ..pose()
    };
    assert_eq!(p.eye(), V::Y * 0.32);
    assert_eq!(p.scan_eye(), V::Y * 0.4);
    assert_eq!(p.center(), V::Y * 0.25);
    assert_eq!(p.hit_factor(), 0.5);
    assert_eq!(p.exposed_points().as_slice(), &[V::Y * 0.22]);
    p.life = Life::Alive;
    p.move_mode = 2;
    assert_eq!(p.hit_factor(), 0.45 * 0.5 * 0.55);
    p.posture = Posture::Stand;
    p.tower_mount = true;
    p.gun_mount = true;
    p.mounted = true;
    assert!(p.valid());
    assert_eq!(p.eye(), V::Y * 1.62);
    p.posture = Posture::Crouch;
    assert_eq!(p.eye(), V::Y * 1.25);
    assert_eq!(p.exposed_points().as_slice(), &[V::Y * 1.15, V::Y * 1.35]);
    p.posture = Posture::LeanRight;
    assert_eq!(p.eye(), V::Z * 0.75 + V::Y * 1.45);
    assert_eq!(p.exposed_points().as_slice(), &[V::Z * 0.65 + V::Y * 1.45]);
}

#[test]
fn malformed_pose_data_is_rejected() {
    assert!(pose().valid());
    assert!(!InfantryPose {
        position: V::INFINITY,
        ..pose()
    }
    .valid());
    assert!(!InfantryPose {
        cover_height: f64::NAN,
        ..pose()
    }
    .valid());
    assert!(!InfantryPose {
        tower_mount: true,
        ..pose()
    }
    .valid());
    assert!(!InfantryPose {
        cover_kind: 4,
        ..pose()
    }
    .valid());
    assert!(Posture::try_from(5).is_err());
}
