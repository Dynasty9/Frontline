use frontline_core::actors::{Actor, Actors};
use frontline_core::cover::{Anchor, AnchorKind};
use frontline_core::infantry::Credit;
use frontline_core::structure::*;
use frontline_core::vector::Vector3;

fn building(kind: &str) -> Structure {
    Structure {
        id: 7,
        kind: kind.into(),
        team: 0,
        ..Default::default()
    }
}
fn economy() -> TownEconomy {
    TownEconomy {
        stock: 180.0,
        yield_per_minute: 24.0,
        capture_pace: 1.0,
    }
}
fn sample() -> Structure {
    Structure {
        id: 17,
        team: 1,
        owner: -2,
        gone: true,
        visible: 3,
        seen: 2,
        hit_by: Some(Credit {
            owner: 3,
            team: 0,
            unit: "rifleman".into(),
            soldier: 91,
        }),
        kind: "town".into(),
        position: Vector3::new(3.1, 1.2, -5.7),
        yaw: 0.731,
        size: Vector3::new(5.7, 2.2, 9.1),
        variant: 1,
        built: false,
        progress: 0.75,
        hp: 37.7,
        max_hp: 199.5,
        name: "Village — 北".into(),
        radius: 5.1,
        footprint: [2.85, 4.55],
        parts: vec![Part {
            position: Vector3::Y,
            size: Vector3::ONE,
            yaw: 0.23,
            infantry: 3,
            vehicle: 2,
            cover: true,
            collision: false,
            door: true,
        }],
        cover_points: vec![Vector3::X],
        anchors: vec![Anchor {
            position: Vector3::Z,
            normal: Vector3::X,
            height: 1.2,
            kind: AnchorKind::Stack,
        }],
        nav_cells: vec![12, 9, 12],
        hash_cells: vec![[3, -4], [-7, 1]],
        smashable: false,
        indestructible: true,
        supply: 77.7,
        wrecked: true,
        capture_progress: 42.1,
        capture_team: 0,
        completed_order: 21,
        supply_parent: 22,
        road: vec![Vector3::NEG_X, Vector3::Z],
        truck: 23,
        truck_timer: 3.2,
        supply_status: "contested".into(),
        alert_time: 18.1,
        zone_center: Some(Vector3::NEG_Z),
        zone_radius: 120.5,
        initial_houses: 9,
        intact: 0.71,
        house_timer: 4.2,
        queue: vec![Production {
            item: "r_rifles".into(),
            remaining: 12.3,
            total: 45.0,
            owner: 3,
            cost: 111,
        }],
        queue_fraction: 0.42,
        rally: Some(Vector3::NEG_Y),
        production_status: "cap".into(),
        gunner: 24,
        manned: true,
        inside: vec![25, 26],
        bearers: vec![27, 28],
        bearer_timer: 4.6,
        tick_timer: -0.01,
        tilt: [0.12, -0.34],
        wreck_kind: "tank".into(),
        door_closed: true,
        burn: 0.71,
        burnt: true,
        fire_kind: "roof".into(),
        fuel: 33.1,
        fuel_max: 44.0,
        fire_queue: vec![(Vector3::X, false), (Vector3::Z, true)],
        hit_from: Some(Vector3::NEG_X),
    }
}

#[test]
fn checkpoint_keeps_geometry_links_queues_and_private_timers() {
    for s in [sample(), building("fob")] {
        let encoded = s.checkpoint().unwrap();
        let decoded = Structure::restore(&encoded).unwrap();
        assert_eq!(decoded, s);
        assert_eq!(decoded.checkpoint().unwrap(), encoded);
        for length in 0..encoded.len() {
            assert!(Structure::restore(&encoded[..length]).is_err());
        }
        let mut trailing = encoded.clone();
        trailing.push(0);
        assert!(Structure::restore(&trailing).is_err());
        for version in [0u16, 2, u16::MAX] {
            let mut invalid = encoded.clone();
            invalid[6..8].copy_from_slice(&version.to_le_bytes());
            assert!(Structure::restore(&invalid).is_err());
        }
    }
}
#[test]
fn structures_join_the_ordered_actor_checkpoint_without_reusing_ids() {
    let mut actors =
        Actors::from_entries(18, vec![Actor::Structure(Box::new(building("fob")))]).unwrap();
    let id = actors
        .spawn(Actor::Structure(Box::new(building("tree"))))
        .unwrap();
    assert_eq!(id, 18);
    assert_eq!(actors.structure(id).unwrap().kind, "tree");
    actors.remove(7);
    let restored = Actors::restore(&actors.checkpoint().unwrap()).unwrap();
    assert_eq!(restored.entities().next_id(), 19);
    assert_eq!(restored.checkpoint().unwrap(), actors.checkpoint().unwrap());
    let mut dead = building("tree");
    dead.gone = true;
    let before = actors.checkpoint().unwrap();
    assert!(actors.spawn(Actor::Structure(Box::new(dead))).is_err());
    assert_eq!(actors.checkpoint().unwrap(), before);
}
#[test]
fn construction_extinguishing_and_fob_repair_preserve_thresholds() {
    let mut s = building("fob");
    s.built = false;
    s.progress = 0.0;
    s.hp = 1.0;
    let first = s.add_work(3.0, Some(10.0)).unwrap();
    assert!(first.worked && !first.completed);
    assert_eq!(s.hp, 30.0);
    assert!(s.add_work(7.0, Some(10.0)).unwrap().completed);
    assert!(s.built);
    assert_eq!(s.hp, 100.0);
    s.hp = 30.0;
    s.wrecked = true;
    s.burn = 0.5;
    s.fuel = 50.0;
    assert!(!s.add_work(1.0, None).unwrap().repaired_fob);
    assert!(s.add_work(3.0, None).unwrap().repaired_fob);
    assert_eq!(s.fuel, 34.0);
    assert!(!s.wrecked);
    s.hp = s.max_hp;
    assert!(!s.add_work(2.0, None).unwrap().worked);
    assert_eq!(s.fuel, 26.0);
    s.gone = true;
    let before = s.clone();
    assert_eq!(s.add_work(100.0, None).unwrap(), Work::default());
    assert_eq!(s, before);
}
#[test]
fn invalid_work_and_production_leave_state_unchanged() {
    let mut s = building("car");
    s.burn = 0.2;
    s.fuel = -1e12;
    let before = s.clone();
    for amount in [f64::NAN, -0.1, 1.0, 1e30] {
        assert!(s.add_work(amount, None).is_err());
        assert_eq!(s, before);
    }
    s.variant = 1_000_000;
    let before = s.clone();
    assert!(s.char_out().is_err());
    assert_eq!(s, before);
    s = building("barracks");
    s.queue.push(Production {
        item: "squad".into(),
        remaining: 1.0,
        total: 1e-300,
        owner: 1,
        cost: 5,
    });
    s.production_status = "cap".into();
    let before = s.clone();
    assert!(s.produce(0.1, true).is_err());
    assert_eq!(s, before);
    for dt in [f64::NAN, -0.1, 11.0] {
        assert!(s.begin_tick(dt, economy()).is_err());
        assert_eq!(s, before);
    }
}
#[test]
fn doors_and_charring_keep_non_door_parts_and_do_not_repeat() {
    let mut s = sample();
    s.gone = false;
    s.burnt = false;
    s.kind = "tree".into();
    let wall = Part {
        door: false,
        ..s.parts[0]
    };
    s.parts.push(wall);
    s.door_closed = true;
    assert!(s.open_door());
    assert_eq!(s.parts, vec![wall]);
    assert!(!s.open_door());
    assert!(s.char_out().unwrap());
    assert_eq!(s.variant, 17);
    assert!(!s.char_out().unwrap());
    s = building("car");
    assert_eq!(s.fire_kind(), "car");
    s.char_out().unwrap();
    assert_eq!(s.variant, 6);
    assert_eq!(s.fire_kind(), "");
    s = building("house_wall");
    assert!(s.door_blocks(Vector3::new(0.0, 0.0, 0.5), Vector3::NEG_Z));
    assert!(!s.door_blocks(Vector3::new(0.0, 0.0, 0.5), Vector3::Z));
    assert!(!s.door_blocks(Vector3::new(2.0, 0.0, 0.5), Vector3::NEG_Z));
}
#[test]
fn building_clock_preserves_neutral_towns_and_staggered_intervals() {
    for (kind, interval, tick) in [
        ("fob", 0.5, Tick::Fob),
        ("medic_tent", 1.0, Tick::Tent),
        ("watchtower", 0.7, Tick::Mount),
        ("mines", 0.2, Tick::Mine),
        ("ammo_cache", 0.5, Tick::Cache),
    ] {
        let mut s = building(kind);
        assert_eq!(s.begin_tick(0.03, economy()).unwrap(), tick);
        assert_eq!(s.tick_timer, interval);
        assert_eq!(s.begin_tick(0.03, economy()).unwrap(), Tick::None);
        s.team = -1;
        let before = s.clone();
        assert_eq!(s.begin_tick(0.03, economy()).unwrap(), Tick::None);
        assert_eq!(s, before);
    }
    let mut s = building("town");
    s.team = -1;
    assert_eq!(
        s.begin_tick(0.03, economy()).unwrap(),
        Tick::Town { count_houses: true }
    );
    assert_eq!(s.house_timer, 10.0);
    assert_eq!(s.supply, 0.0);
    s.team = 0;
    s.intact = 0.0;
    s.begin_tick(1.0, economy()).unwrap();
    assert_eq!(s.supply, 24.0 / 60.0 * 0.35);
    s.supply = 179.99;
    s.begin_tick(1.0, economy()).unwrap();
    assert_eq!(s.supply, 180.0);
    s = building("research");
    s.tick_timer = 1.0;
    assert_eq!(s.begin_tick(0.03, economy()).unwrap(), Tick::Production);
    assert_eq!(s.tick_timer, 0.97);
}
#[test]
fn fob_last_stand_and_contested_capture_match_existing_rules() {
    let mut s = building("fob");
    let first = s.fob_capture([0, 6], true).unwrap();
    assert!(first.warning && first.last_stand && first.resupply);
    assert_eq!(s.capture_progress, 2.0);
    s.capture_progress = 50.0;
    s.fob_capture([1, 6], true).unwrap();
    assert_eq!(s.capture_progress, 42.0);
    s.fob_capture([0, 0], false).unwrap();
    assert_eq!(s.capture_progress, 39.0);
    s.capture_progress = 99.0;
    let captured = s.fob_capture([0, 6], false).unwrap();
    assert_eq!(captured.captured_by, Some(1));
    assert!(!captured.resupply);
    assert_eq!(s.team, 0);
    assert_eq!(s.capture_team, -1);
    assert_eq!(s.capture_progress, 0.0);
    s.wrecked = true;
    assert!(!s.fob_capture([0, 0], false).unwrap().resupply);
}
#[test]
fn town_stock_damage_capture_and_alert_cooldowns_are_retained() {
    let mut s = building("town");
    s.team = -1;
    assert!(!s.count_houses(10).unwrap());
    assert_eq!(s.initial_houses, 10);
    assert!(s.count_houses(6).unwrap());
    assert_eq!(s.intact, 0.6);
    assert!(s.count_houses(20).unwrap());
    assert_eq!(s.intact, 1.0);
    assert!(!s.town_capture([2, 0], 1.0, economy()).unwrap().warning);
    assert!((s.capture_progress - 0.85).abs() < 1e-12);
    s.team = 0;
    s.capture_progress = 50.0;
    s.capture_team = 1;
    s.town_capture([2, 2], 2.0, economy()).unwrap();
    assert_eq!(s.capture_progress, 50.0);
    s.town_capture([2, 0], 3.0, economy()).unwrap();
    assert_eq!(s.capture_progress, 46.0);
    s.capture_team = -1;
    assert!(s.town_capture([0, 2], 5.0, economy()).unwrap().warning);
    assert_eq!(s.alert_time, 35.0);
    s.capture_team = -1;
    assert!(!s.town_capture([0, 2], 6.0, economy()).unwrap().warning);
    s.capture_progress = 99.9;
    let captured = s.town_capture([0, 2], 7.0, economy()).unwrap();
    assert_eq!(captured.captured_by, Some(1));
    assert!(!captured.resupply);
}
#[test]
fn production_pauses_at_cap_research_ignores_it_and_emits_one_item_per_tick() {
    let mut s = building("barracks");
    let item = Production {
        item: "rifles".into(),
        remaining: 0.1,
        total: 10.0,
        owner: 123,
        cost: 80,
    };
    s.queue = vec![item.clone(), item.clone()];
    assert!(s.produce(1.0, false).unwrap().cap_warning);
    assert!(!s.produce(1.0, false).unwrap().cap_warning);
    assert_eq!(s.queue[0], item);
    let produced = s.produce(1.0, true).unwrap();
    assert_eq!(produced.item.unwrap().owner, 123);
    assert_eq!(s.queue.len(), 1);
    assert_eq!(s.queue[0], item);
    assert!(s.production_status.is_empty());
    s.kind = "research".into();
    assert!(s.produce(1.0, false).unwrap().item.is_some());
    assert!(s.produce(1.0, false).unwrap().fraction_changed);
    assert_eq!(s.queue_fraction, 0.0);
}
