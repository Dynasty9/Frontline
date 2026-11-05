use frontline_core::actors::Actors;
use frontline_core::infantry_pose::Posture;
use frontline_core::infantry_spawn::{random_name, Loadout, Spawn};
use frontline_core::infantry_vitals::Life;
use frontline_core::random::SimulationRandom;
use frontline_core::squad::Squad;
use frontline_core::vector::Vector3;

fn loadout() -> Loadout {
    Loadout {
        unit: "crewman".into(),
        weapon: "smg".into(),
        hp: 90.0,
        magazine: 30,
        ammunition: 120,
        grenades: 0,
        smokes: 1,
        rockets: 0,
        mortar_rounds: 0,
        drones: 0,
        bearer: false,
    }
}
fn birth() -> Spawn {
    Spawn {
        team: 0,
        owner: 7,
        position: Vector3::new(2.0, 0.0, -3.0),
        yaw: 0.731,
        name: "Taylor".into(),
        squad: 0,
        life: Life::Alive,
        posture: Posture::Stand,
        armor_upgrade: false,
        grenade_upgrade: false,
    }
}

#[test]
fn births_apply_upgrades_and_keep_the_initial_cooldowns() {
    for armor in [false, true] {
        for grenades in [false, true] {
            for bearer in [false, true] {
                let mut a = Actors::default();
                let mut rng = SimulationRandom::new(59);
                let mut expected = rng;
                let delay = f64::from(expected.randf()) * 0.3;
                let mut b = birth();
                b.armor_upgrade = armor;
                b.grenade_upgrade = grenades;
                let mut l = loadout();
                l.bearer = bearer;
                let id = a.spawn_infantry(b, &l, &mut rng).unwrap();
                assert_eq!(id, 1);
                let s = a.soldier(id).unwrap();
                assert_eq!(s.vitals.hp, 90.0 * if armor { 1.2 } else { 1.0 });
                assert_eq!(s.vitals.hp, s.vitals.base_hp);
                assert_eq!(s.grenades.frags, i32::from(grenades && !bearer));
                assert_eq!((s.weapon.magazine, s.weapon.reserve), (30, 90));
                assert_eq!(s.controller.think_timer, delay);
                assert_eq!(s.arsenal.drone_ready, 4.0);
                assert_eq!(s.weapon.last_shot, -99.0);
                assert_eq!(s.vitals.last_suppression, -99.0);
                assert_eq!(s.motion.last_direction, Vector3::NEG_Z);
                assert_eq!(s.orders.hold_position, s.motion.position);
                assert_eq!(rng, expected);
            }
        }
    }
}

#[test]
fn missing_weapons_leave_empty_hands_and_special_ammunition_is_retained() {
    let mut l = loadout();
    l.weapon.clear();
    l.magazine = 0;
    l.ammunition = 0;
    l.rockets = 3;
    l.mortar_rounds = 8;
    l.drones = 2;
    let mut a = Actors::default();
    let id = a
        .spawn_infantry(birth(), &l, &mut SimulationRandom::new(7))
        .unwrap();
    let s = a.soldier(id).unwrap();
    assert_eq!((s.weapon.magazine, s.weapon.reserve), (0, 0));
    assert_eq!(
        (s.arsenal.rockets, s.arsenal.mortar_rounds, s.arsenal.drones),
        (3, 8, 2)
    );
}

#[test]
fn names_draw_before_the_ai_delay_and_checkpoint_resume_keeps_allocations() {
    let names: Vec<_> = ["Jones", "McDonald", "Perez"].map(String::from).into();
    let mut a = Actors::default();
    let mut rng = SimulationRandom::new(77);
    for i in 0..12 {
        let mut expected = rng;
        let expected_name = &names[expected.randi() as usize % names.len()];
        let delay = f64::from(expected.randf()) * 0.3;
        let mut b = birth();
        b.name = random_name(&names, &mut rng).unwrap();
        let id = a.spawn_infantry(b, &loadout(), &mut rng).unwrap();
        assert_eq!(id, i + 1);
        assert_eq!(&a.soldier(id).unwrap().identity.name, expected_name);
        assert_eq!(a.soldier(id).unwrap().controller.think_timer, delay);
        assert_eq!(rng, expected);
        if i == 5 {
            a = Actors::restore(&a.checkpoint().unwrap()).unwrap();
        }
    }
}

#[test]
fn squad_birth_and_recruitment_keep_cadence_member_order_and_cached_center() {
    let mut q = Squad::new(17, 1, -2, "r_crew".into()).unwrap();
    assert_eq!(q.think_timer, (17.0 * 0.309016994) % 0.5);
    let mut a = Actors::default();
    let mut rng = SimulationRandom::new(7);
    for i in 0..3 {
        let mut b = birth();
        b.position = Vector3::X * i as f32;
        let id = a.spawn_infantry(b, &loadout(), &mut rng).unwrap();
        assert!(q.add_member(id, &mut a).unwrap());
        assert!(!q.add_member(id, &mut a).unwrap());
        assert_eq!(a.soldier(id).unwrap().identity.squad, 17);
    }
    assert_eq!(q.members, [1, 2, 3]);
    assert_eq!(q.order_position, Vector3::X);
    assert_eq!(q.centroid_at, -1.0);
    let saved = q.checkpoint().unwrap();
    assert!(q.add_member(999, &mut a).is_err());
    assert_eq!(q.checkpoint().unwrap(), saved);
    assert_eq!(Squad::restore(&saved).unwrap(), q);
}

#[test]
fn malformed_or_exhausted_births_do_not_consume_ids_or_randomness() {
    for exhausted in [false, true] {
        for invalid in 0..4 {
            let mut a =
                Actors::from_entries(if exhausted { u32::MAX as u64 + 1 } else { 1 }, vec![])
                    .unwrap();
            let mut b = birth();
            let mut l = loadout();
            match invalid {
                0 => b.position.x = f32::NAN,
                1 => l.magazine = l.ammunition + 1,
                2 => b.name.push('\0'),
                _ => b.team = 8,
            }
            let mut rng = SimulationRandom::new(7);
            let saved = a.checkpoint().unwrap();
            let random = rng;
            assert!(a.spawn_infantry(b, &l, &mut rng).is_err());
            assert_eq!(a.checkpoint().unwrap(), saved);
            assert_eq!(rng, random);
        }
    }
    let mut a = Actors::from_entries(u32::MAX as u64 + 1, vec![]).unwrap();
    let mut rng = SimulationRandom::new(7);
    let random = rng;
    assert!(a.spawn_infantry(birth(), &loadout(), &mut rng).is_err());
    assert!(random_name(&[], &mut rng).is_err());
    assert_eq!(rng, random);
}
