use frontline_core::grenade_attack::{Contact, GrenadeAttack, Input};
use frontline_core::infantry_pose::Posture;
use frontline_core::random::SimulationRandom;
use frontline_core::vector::Vector3 as V;

fn input() -> Input {
    Input {
        position: V::ZERO,
        time: 10.0,
        suppression: 0.0,
        squad: true,
        ambush: false,
        moving: false,
    }
}

#[test]
fn busy_pinned_ambushing_or_empty_handed_soldiers_do_not_start_a_grenade_check() {
    for case in 0..6 {
        let mut s = GrenadeAttack {
            frags: if case == 0 { 0 } else { 2 },
            cooldown: if case == 1 { 10.01 } else { 0.0 },
        };
        let mut i = input();
        i.suppression = if case == 2 { 70.01 } else { 0.0 };
        i.squad = case != 3;
        i.ambush = case == 4;
        i.moving = case == 5;
        let before = s;
        let mut rng = SimulationRandom::new(17);
        let r = rng;
        assert!(s.advance(i, &[contact(1)], &mut rng).unwrap().is_none());
        assert_eq!(s, before);
        assert_eq!(rng, r);
    }
}
fn contact(id: u64) -> Contact {
    Contact {
        id,
        position: V::X * 15.0,
        alive: true,
        age: 0.0,
        visible: false,
        posture: Posture::Stand,
        hard_cover: false,
        nearby_allies: 6,
    }
}

#[test]
fn grenades_choose_the_first_best_cluster_and_preserve_random_order() {
    let mut s = GrenadeAttack {
        frags: 2,
        cooldown: 0.0,
    };
    let mut rng = SimulationRandom::new(7);
    let mut expected = rng;
    expected.randf();
    let dx = expected.randf_range(-1.0, 1.0);
    let dz = expected.randf_range(-1.0, 1.0);
    let cooldown = expected.randf_range(12.0, 20.0);
    let t = s
        .advance(input(), &[contact(2), contact(1)], &mut rng)
        .unwrap()
        .unwrap();
    assert_eq!(t.target, 2);
    assert_eq!(t.position, V::X * 15.0 + V::new(dx, 0.0, dz) * 15.0 * 0.07);
    assert_eq!(s.frags, 1);
    assert_eq!(s.cooldown, 10.0 + f64::from(cooldown));
    assert_eq!(rng, expected);
    let saved = s;
    assert!(s
        .advance(input(), &[contact(2)], &mut rng)
        .unwrap()
        .is_none());
    assert_eq!(s, saved);
    assert_eq!(rng, expected);
}

#[test]
fn range_age_and_posture_limits_skip_random_draws_without_a_candidate() {
    let mut c = contact(1);
    let mut rng = SimulationRandom::new(8);
    let before = rng;
    for (distance, age, visible, posture) in [
        (8.99, 0.0, false, Posture::Stand),
        (27.01, 0.0, false, Posture::Stand),
        (15.0, 6.001, false, Posture::Prone),
        (15.0, 0.0, true, Posture::Stand),
    ] {
        c.position = V::X * distance;
        c.age = age;
        c.visible = visible;
        c.posture = posture;
        let mut s = GrenadeAttack {
            frags: 1,
            cooldown: 0.0,
        };
        assert!(s.advance(input(), &[c], &mut rng).unwrap().is_none());
        assert_eq!(s.cooldown, 12.5);
        assert_eq!(rng, before);
    }
    for distance in [9.0, 27.0] {
        c = contact(1);
        c.position = V::X * distance;
        c.age = 6.0;
        c.visible = true;
        c.posture = Posture::Crouch;
        let mut s = GrenadeAttack {
            frags: 1,
            cooldown: 0.0,
        };
        assert!(s.advance(input(), &[c], &mut rng).unwrap().is_some());
    }
}

#[test]
fn grenade_attack_checkpoints_resume_and_invalid_input_is_atomic() {
    let mut s = GrenadeAttack {
        frags: 2,
        cooldown: 4.0,
    };
    let bytes = s.checkpoint();
    let mut copy = GrenadeAttack::restore(&bytes).unwrap();
    let mut rng = SimulationRandom::new(15);
    let mut r2 = rng;
    let mut bad = contact(1);
    bad.position = V::NAN;
    assert!(s.advance(input(), &[bad], &mut rng).is_err());
    bad = contact(u64::MAX);
    assert!(s.advance(input(), &[bad], &mut rng).is_err());
    assert_eq!(s, copy);
    assert_eq!(rng, r2);
    assert_eq!(
        s.advance(input(), &[contact(1)], &mut rng),
        copy.advance(input(), &[contact(1)], &mut r2)
    );
    assert_eq!(s, copy);
    assert_eq!(rng, r2);
    for n in 0..bytes.len() {
        assert!(GrenadeAttack::restore(&bytes[..n]).is_err());
    }
    let mut trailing = bytes.clone();
    trailing.push(0);
    assert!(GrenadeAttack::restore(&trailing).is_err());
    for offset in [4, 6, 11, 19] {
        let mut bad = bytes.clone();
        bad[offset] = 255;
        assert!(GrenadeAttack::restore(&bad).is_err());
    }
}
