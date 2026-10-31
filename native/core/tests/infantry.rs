use frontline_core::infantry::*;
use frontline_core::infantry_action::{Action, Round, Throw};
use frontline_core::infantry_control::HiddenReason;
use frontline_core::infantry_controller::{Stage, Task};
use frontline_core::infantry_idle::{Line, CHAT};
use frontline_core::infantry_pose::Posture;
use frontline_core::random::SimulationRandom;
use frontline_core::vector::Vector3;

fn soldier() -> Infantry {
    let mut s = Infantry {
        identity: Identity {
            id: 17,
            team: 1,
            owner: -2,
            gone: true,
            visible: 2,
            seen: 3,
            unit: "rifleman".into(),
            name: "André 🪖".into(),
            squad: 4,
            weapon: "ak".into(),
            mounted_weapon: "m2".into(),
            hit_by: Some(Credit {
                owner: 42,
                team: 0,
                unit: "tank".into(),
                soldier: 31,
            }),
        },
        orders: Orders {
            pending_path: true,
            path_revision: 782,
            goal: Vector3::new(7.1, 2.2, -8.3),
            purpose: Goal::Crawl,
            move_mode: 2,
            base_y: -0.75,
            backwards: true,
            hold_position: Vector3::X,
            hold_face: Vector3::Z,
            leash: 12.3,
            detached: true,
        },
        cover: FightingPosition {
            kind: 3,
            position: Vector3::Y,
            at_cover: true,
            lean_direction: Vector3::X,
            threat: Vector3::Z,
            evaluate_at: 103.1,
            normal: Vector3::NEG_X,
            height: 1.3,
            material: 2,
            structure: 23,
            anchor: 6,
            shifting: true,
        },
        duty: Duty {
            kind: Task::Stretcher,
            entity: 73,
            partner: 74,
            phase: 3,
            timer: -0.01,
            position: Vector3::ONE,
            second_position: Vector3::NEG_Y,
            front: true,
            throw_kind: Round::Smoke,
        },
        links: Links {
            vehicle: 101,
            dragged_by: 102,
            rescue_claimed: 103,
            carried_by: vec![105, 104],
            stretcher_claimed: true,
            captor: 106,
            hidden_in: 107,
            tent_dead: true,
            home: 108,
            prison_destination: 109,
            intel_left: 3,
            intel_timer: 2.75,
        },
        entry: HouseEntry {
            clear: true,
            no_frag: true,
            selected: Some(BreachChoice {
                house: 201,
                enemy: 202,
                opening: Opening {
                    id: 203,
                    center: Vector3::X,
                    normal: Vector3::Z,
                    door: true,
                },
            }),
            house: 204,
            opening: Some(Opening {
                id: 0,
                center: Vector3::Y,
                normal: Vector3::NEG_Z,
                door: false,
            }),
            next_check: 111.1,
            cooking_started: 110.2,
            grenade: 205,
            wait_until: 113.4,
            reordered: true,
        },
        emplacement: Emplacement {
            structure: 301,
            target: 302,
            scan_timer: -0.02,
            mortar_aim: Some(Vector3::new(-1.2, 3.4, -5.6)),
            mortar_round: Round::Smoke,
            mortar_delay: 7.2,
        },
        fight: Fight {
            target: 401,
            forced_target: 402,
            visible_targets: vec![405, 404, 403],
            covering_until: 123.4,
            covering_position: Vector3::ONE,
            fire_team: 1,
            out_of_ammo_said: true,
            controlled_drone: 406,
            sector: Vector3::X,
            separation: Vector3::Z,
            shuffling: true,
            noticed_grenade: 407,
            flee_fire_at: 109.2,
            build_sound_timer: -0.03,
            loot: 107,
            smokes: -1,
        },
        posture: Posture::LeanRight,
        activity: 36,
        flags: 255,
        doing: 52,
        doing_entity: 501,
        hit_direction: Vector3::new(0.1, -0.2, 0.3),
        hit_kind: "blast".into(),
        ..Default::default()
    };
    s.vitals.hp = 42.7;
    s.vitals.suppression = 69.3;
    s.motion.position = Vector3::new(1.2, -3.4, 5.6);
    s.motion.path = vec![Vector3::X, Vector3::Y, Vector3::NEG_Z];
    s.motion.path_index = 1;
    s.motion.door = 21;
    s.weapon.magazine = 17;
    s.weapon.reload_timer = 0.42;
    s.arsenal.rockets = 3;
    s.arsenal.drone_ready = 203.1;
    s.grenades.frags = 2;
    s.grenades.cooldown = 201.2;
    s.supply.scavenge_at = 131.2;
    s.supply.search_at = 132.3;
    s.control.hidden = HiddenReason::TunnelTravel;
    s.control.hidden_timer = 2.4;
    s.control.previous_position = Vector3::new(1.1, -3.3, 5.5);
    s.idle.calm = 16.8;
    s.idle.activity = CHAT;
    s.idle.partner = 31;
    s.idle.until = 100.2;
    s.idle.next = 123.7;
    s.idle.laugh_until = 103.6;
    s.idle.lines.push_back(Line {
        at: 112.3,
        text: "Ready, André?".into(),
    });
    s.controller.think_timer = 0.12;
    s.controller.scan_number = 37;
    s.controller.activity_timer = 0.17;
    s.controller.dive_direction = Vector3::NEG_X;
    s.shock.flinging = true;
    s.shock.velocity = Vector3::new(0.2, 3.5, -4.1);
    s.aim.sight_target = 602;
    s.aim.sight_until = 114.3;
    s.aim.visible = true;
    s.grenade_memory.seen = vec![71, 73, 72];
    s.drone_memory.heard = vec![81, 83, 82];
    s.action.current = Action::Cook;
    s.action.remaining = 0.1;
    s.action.queued_throw = Some(Throw {
        position: Vector3::X,
        round: Round::Frag,
        fuse: 1.7,
    });
    s
}

#[test]
fn infantry_checkpoint_retains_pending_work_and_link_order() {
    let s = soldier();
    let bytes = s.checkpoint().unwrap();
    assert_eq!(&bytes[..6], b"FLIN\x01\0");
    assert_eq!(Infantry::restore(&bytes).unwrap(), s);
    assert_eq!(
        Infantry::restore(&bytes).unwrap().checkpoint().unwrap(),
        bytes
    );
    let empty = Infantry {
        identity: Identity {
            id: 1,
            unit: "rifleman".into(),
            ..Default::default()
        },
        ..Default::default()
    };
    assert_eq!(
        Infantry::restore(&empty.checkpoint().unwrap()).unwrap(),
        empty
    );
}

#[test]
fn restored_actor_continues_actions_and_think_draws_without_losing_hidden_state() {
    let mut s = soldier();
    let mut restored = Infantry::restore(&s.checkpoint().unwrap()).unwrap();
    let mut rng = SimulationRandom::new(7482);
    let mut replay_rng = rng;
    let mut thinks = 0;
    for _ in 0..120 {
        let a = s
            .controller
            .advance(1.0 / 30.0, &mut s.shock, &mut s.action, &mut rng)
            .unwrap();
        let b = restored
            .controller
            .advance(
                1.0 / 30.0,
                &mut restored.shock,
                &mut restored.action,
                &mut replay_rng,
            )
            .unwrap();
        assert_eq!(a, b);
        thinks += usize::from(a.stage == Stage::Think);
        assert_eq!(s, restored);
        assert_eq!(rng, replay_rng);
        restored = Infantry::restore(&restored.checkpoint().unwrap()).unwrap();
    }
    assert!(thinks > 5);
}

#[test]
fn infantry_rejects_truncated_incompatible_and_malformed_checkpoints() {
    let bytes = soldier().checkpoint().unwrap();
    let shock = soldier().shock.checkpoint();
    assert!(Infantry::restore(&shock).is_err());
    assert!(frontline_core::infantry_shock::InfantryShock::restore(&bytes).is_err());
    for n in 0..bytes.len() {
        assert!(Infantry::restore(&bytes[..n]).is_err(), "truncated at {n}");
    }
    for (at, value) in [
        (0, b'?'),
        (4, 2),
        (6, 0),
        (12, 2),
        (17, 2),
        (18, 4),
        (24, 0xff),
    ] {
        let mut bad = bytes.clone();
        bad[at] = value;
        assert!(Infantry::restore(&bad).is_err(), "malformed byte {at}");
    }
    let mut bad = bytes.clone();
    bad[20..24].copy_from_slice(&u32::MAX.to_le_bytes());
    assert!(Infantry::restore(&bad).is_err());
    let mut bad = bytes.clone();
    bad.extend_from_slice(&[0]);
    assert!(Infantry::restore(&bad).is_err());
    let mut bad = bytes;
    let inner = bad.windows(4).position(|w| w == b"FLIM").unwrap();
    bad[inner + 6] = 0;
    assert!(Infantry::restore(&bad).is_err());
}

#[test]
fn infantry_limits_apply_before_writing_and_to_embedded_component_links() {
    for alter in [
        |s: &mut Infantry| s.identity.id = 0,
        |s: &mut Infantry| s.identity.name = "x".repeat(1025),
        |s: &mut Infantry| s.identity.unit = "rifle\0man".into(),
        |s: &mut Infantry| s.motion.position.x = f32::NAN,
        |s: &mut Infantry| s.orders.base_y = f64::INFINITY,
        |s: &mut Infantry| s.links.carried_by.push(0),
        |s: &mut Infantry| s.duty.throw_kind = Round::HighExplosive,
        |s: &mut Infantry| s.emplacement.mortar_round = Round::Frag,
        |s: &mut Infantry| s.idle.partner = u32::MAX as u64 + 1,
        |s: &mut Infantry| s.aim.sight_target = u32::MAX as u64 + 1,
        |s: &mut Infantry| {
            s.action.current = Action::Launch {
                target: u32::MAX as u64 + 1,
            }
        },
        |s: &mut Infantry| s.grenade_memory.seen = vec![u32::MAX as u64 + 1],
    ] {
        let mut s = soldier();
        alter(&mut s);
        assert!(!s.valid());
        assert!(s.checkpoint().is_err());
    }
}

#[test]
fn actor_blocks_accept_the_component_limits_without_silently_dropping_memory() {
    let mut s = soldier();
    s.motion.path = vec![Vector3::new(1.2, 3.4, -5.6); 1_000_000];
    s.grenade_memory.seen = (1..=100_000).collect();
    s.fight.visible_targets = (1..=100_000).rev().collect();
    s.idle.lines = (0..128)
        .map(|i| Line {
            at: i as f64,
            text: "x".repeat(4096),
        })
        .collect();
    let saved = s.checkpoint().unwrap();
    assert_eq!(Infantry::restore(&saved).unwrap(), s);
    assert!(Infantry::restore(&saved[..saved.len() - 1]).is_err());
}
