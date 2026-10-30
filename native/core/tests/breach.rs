use frontline_core::breach::{self, Breach, Decision, Input};
use frontline_core::random::SimulationRandom;
use frontline_core::vector::Vector3 as V;

fn state() -> Breach {
    Breach {
        started: 10.0,
        cook_started: -1.0,
        ..Default::default()
    }
}
fn input() -> Input {
    Input {
        time: 11.0,
        moving: false,
        distance: 0.2,
        enemy_inside: true,
        door_shut: false,
        frags: 1,
        team: 0,
        enemy_hard_cover: false,
        exploded: false,
        reordered: false,
    }
}

#[test]
fn closed_doors_block_cooking_and_entry_waits_for_the_explosion() {
    let mut s = state();
    let mut i = input();
    let mut rng = SimulationRandom::new(8);
    assert_eq!(s.advance(i, &mut rng).unwrap(), Decision::Stacked);
    i.time = s.wait_until;
    i.door_shut = true;
    let before = rng;
    assert_eq!(
        s.advance(i, &mut rng).unwrap(),
        Decision::ApproachDoor {
            cook: 0.0,
            distance: 0.8
        }
    );
    assert_eq!(rng, before);
    assert_eq!(s.advance(i, &mut rng).unwrap(), Decision::KickDoor);
    i.door_shut = false;
    assert_eq!(
        s.advance(i, &mut rng).unwrap(),
        Decision::Throw { fuse: 3.4 }
    );
    i.time = s.wait_until;
    assert_eq!(s.advance(i, &mut rng).unwrap(), Decision::Wait);
    assert_eq!(s.phase, 3);
    i.exploded = true;
    s.advance(i, &mut rng).unwrap();
    assert_eq!(s.phase, 4);
    assert_eq!(s.advance(i, &mut rng).unwrap(), Decision::Wait);
    i.time = s.wait_until;
    assert_eq!(s.advance(i, &mut rng).unwrap(), Decision::Enter);
    i.reordered = true;
    assert_eq!(s.advance(i, &mut rng).unwrap(), Decision::FollowSquad);
}

#[test]
fn empty_room_clearing_skips_the_frag_and_stalled_paths_have_a_deadline() {
    let mut s = state();
    let mut i = input();
    let mut rng = SimulationRandom::new(13);
    i.enemy_inside = false;
    assert_eq!(s.advance(i, &mut rng).unwrap(), Decision::Cancel);
    s.clear = true;
    assert_eq!(s.advance(i, &mut rng).unwrap(), Decision::Stacked);
    i.time = s.wait_until;
    let before = rng;
    assert_eq!(
        s.advance(i, &mut rng).unwrap(),
        Decision::ApproachDoor {
            cook: 0.0,
            distance: 1.25
        }
    );
    assert_eq!(rng, before);
    assert_eq!(s.advance(i, &mut rng).unwrap(), Decision::EnterWait);
    s = state();
    i = input();
    i.distance = 0.9;
    i.time = 30.0;
    assert_eq!(s.advance(i, &mut rng).unwrap(), Decision::RetryStack);
    i.time += 0.001;
    assert_eq!(s.advance(i, &mut rng).unwrap(), Decision::Cancel);
    assert!(!s.expired(55.0, true).unwrap());
    assert!(s.expired(55.001, true).unwrap());
    assert!(s.expired(10.0, false).unwrap());
}

#[test]
fn breach_checkpoints_resume_and_reject_invalid_state_without_consuming_randomness() {
    for phase in 0..=4 {
        let mut s = Breach { phase, ..state() };
        let mut rng = SimulationRandom::new(phase as u64 + 5);
        let bytes = s.checkpoint();
        let mut copy = Breach::restore(&bytes).unwrap();
        let mut r2 = rng;
        assert_eq!(s.advance(input(), &mut rng), copy.advance(input(), &mut r2));
        assert_eq!(s, copy);
        assert_eq!(rng, r2);
        for n in 0..bytes.len() {
            assert!(Breach::restore(&bytes[..n]).is_err());
        }
        let mut trailing = bytes.clone();
        trailing.push(0);
        assert!(Breach::restore(&trailing).is_err());
        for offset in [4, 6, 8, 33, 34] {
            let mut bad = bytes.clone();
            bad[offset] = 99;
            assert!(Breach::restore(&bad).is_err());
        }
        let before = s;
        let mut invalid = input();
        invalid.time = f64::NAN;
        assert!(s.advance(invalid, &mut rng).is_err());
        assert_eq!(s, before);
        assert_eq!(rng, r2);
    }
}

#[test]
fn grenades_land_inside_the_room_and_stacks_keep_the_nearer_side() {
    assert_eq!(
        breach::room_target(V::ZERO, V::Z, V::new(50.0, 0.0, -50.0)).unwrap(),
        V::new(1.4, 0.06, -3.6)
    );
    assert_eq!(
        breach::stack_spot(V::X, V::ZERO, V::Z, true).unwrap(),
        V::new(1.55, 0.0, 0.5)
    );
    assert_eq!(
        breach::stack_spot(-V::X, V::ZERO, V::Z, false).unwrap(),
        V::new(-1.25, 0.0, 0.5)
    );
    assert_eq!(breach::retreat(1.0, false, true).unwrap(), 1);
    assert_eq!(breach::retreat(0.9, true, false).unwrap(), 2);
    assert_eq!(breach::retreat(0.9, false, true).unwrap(), 0);
}
