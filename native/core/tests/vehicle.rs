use frontline_core::vector::Vector3;
use frontline_core::vehicle::*;

fn vehicle() -> Vehicle {
    Vehicle {
        id: 7,
        ..Default::default()
    }
}

#[test]
fn checkpoints_keep_transport_orders_and_reject_corrupt_or_nonfinite_state() {
    let mut v = vehicle();
    v.passengers = vec![4, 3];
    v.sling_cargo = 22;
    v.slung_by = 23;
    v.sling_target = 24;
    v.cooldowns = vec![("push_on".into(), 123.7)];
    v.resume = Some(Resume {
        destination: Some(Vector3::X),
        assault: true,
        assault_destination: Some(Vector3::Z),
    });
    v.flight = Some([0.17, -0.03, 0.72]);
    v.last_blast = Some(LastBlast {
        position: Vector3::NEG_Z,
        size: 2.1,
        time: 33.1,
    });
    v.fire_queue = vec![Vector3::new(170.3, 0.0, -21.9)];
    v.tries_time = Some(3.0);
    v.avoid_cap = Some(3.0);
    v.path = vec![Vector3::Y, Vector3::X];
    v.route = vec![Vector3::Z];
    let saved = v.checkpoint().unwrap();
    assert_eq!(Vehicle::restore(&saved).unwrap(), v);
    for n in 0..saved.len() {
        assert!(Vehicle::restore(&saved[..n]).is_err());
    }
    let mut bad = saved.clone();
    bad.push(0);
    assert!(Vehicle::restore(&bad).is_err());
    let mut bad = saved.clone();
    bad[6] = 0;
    assert!(Vehicle::restore(&bad).is_err());
    v.hp = f64::NAN;
    assert!(v.checkpoint().is_err());
}

#[test]
fn stop_and_replacement_reject_stale_path_completions() {
    let mut v = vehicle();
    let Route::Ground {
        revision: first, ..
    } = v.request_path(Vector3::X, 0.5).unwrap()
    else {
        panic!()
    };
    let Route::Ground {
        revision: second, ..
    } = v.request_path(Vector3::Z, 0.2).unwrap()
    else {
        panic!()
    };
    assert!(!v.complete_path(first, vec![Vector3::X]).unwrap());
    assert!(v.path_pending);
    assert!(v.complete_path(second, vec![Vector3::Z]).unwrap());
    assert!(!v.path_pending);
    v.order_stop("tank", false).unwrap();
    assert!(!v.complete_path(second, vec![Vector3::Z]).unwrap());
    assert!(v.path.is_empty());
    let saved = v.checkpoint().unwrap();
    assert!(v.request_path(Vector3::splat(f32::NAN), 0.5).is_err());
    assert_eq!(v.checkpoint().unwrap(), saved);
}

#[test]
fn crew_withdrawal_gates_ai_orders_but_accepts_players_and_its_own_move() {
    let mut v = vehicle();
    v.brain_state = "withdraw".into();
    v.owner = -1;
    assert_eq!(
        v.order_assault(Vector3::X, "tank", Vector3::X).unwrap(),
        Route::None
    );
    assert!(!v.assault);
    assert!(!v.path_pending);
    v.brain_order = true;
    assert!(matches!(
        v.order_move(Vector3::X, "tank", Vector3::X).unwrap(),
        Route::Ground { .. }
    ));
    assert_eq!(v.brain_state, "withdraw");
    assert!(!v.brain_overruled);
    v.brain_order = false;
    v.owner = 1;
    assert!(matches!(
        v.order_assault(Vector3::Z, "tank", Vector3::Z).unwrap(),
        Route::Ground { .. }
    ));
    assert!(v.brain_overruled);
    assert!(v.brain_state.is_empty());
    assert!(v.assault);
}

#[test]
fn aircraft_orders_preserve_flight_phase_and_clear_pickup_on_stop() {
    let mut v = vehicle();
    v.position = Vector3::Y * 4.0;
    v.lift_phase = 3;
    v.sling_target = 17;
    assert_eq!(
        v.order_move(Vector3::X, "lift_heli", Vector3::X * 2.0)
            .unwrap(),
        Route::None
    );
    assert_eq!(v.lift_phase, 2);
    assert_eq!(v.lift_destination, Some(Vector3::X * 2.0));
    v.order_stop("lift_heli", false).unwrap();
    assert_eq!(v.lift_phase, 7);
    assert_eq!(v.flight_hold, Some(v.position));
    assert_eq!(v.sling_target, 0);
    v.order_attack(8, Vector3::new(12.0, 30.0, -8.0), "attack_heli")
        .unwrap();
    assert_eq!(v.gunship_destination, Some(Vector3::new(12.0, 0.0, -8.0)));
    assert_eq!(v.forced_target, 8);
}

#[test]
fn repairs_restore_tracks_and_flags_preserve_weapon_and_aircraft_states() {
    let mut v = vehicle();
    v.max_hp = 900.0;
    v.hp = 200.0;
    v.track_broken = true;
    assert!(!v.repair(5.9).unwrap());
    assert!(v.repair(0.1).unwrap());
    assert!(!v.track_broken);
    assert_eq!(v.track_fix, 0.0);
    assert!(v.needs_repair());
    v.repair(40.0).unwrap();
    assert_eq!(v.hp, 900.0);
    assert!(!v.needs_repair());
    v.last_fire = 5.0;
    v.blocked_timer = 3.0;
    assert_eq!(v.update_flags(5.1, true, true).unwrap(), 2 | 4 | 8 | 16);
    assert_eq!(v.update_flags(10.0, false, true).unwrap(), 4);
    let saved = v.checkpoint().unwrap();
    assert!(v.repair(f64::INFINITY).is_err());
    assert_eq!(v.checkpoint().unwrap(), saved);
}

#[test]
fn turret_drives_cross_the_nose_and_reset_settled_aim_when_targets_change() {
    let mut v = vehicle();
    let limit = 110.0f64.to_radians();
    v.turret_yaw = limit;
    for _ in 0..360 {
        let before = v.turret_yaw;
        v.slew_turret(-limit, 1.0 / 30.0, false, true, 1.1, 1.7)
            .unwrap();
        assert!(v.turret_yaw <= before + 1e-7);
        assert!(v.turret_yaw.abs() <= limit + 1e-6);
    }
    assert!((v.turret_yaw + limit).abs() < 0.01);
    v.turret_yaw = 0.0;
    v.traverse = 0.0;
    for _ in 0..60 {
        v.turret_tick(Some((8, Vector3::NEG_Z)), 1.0 / 30.0, false, 1.1, 1.7)
            .unwrap();
    }
    assert!(v.aim_time > 1.9);
    v.turret_tick(Some((9, Vector3::X)), 1.0 / 30.0, false, 1.1, 1.7)
        .unwrap();
    assert_eq!(v.aim_time, 0.0);
    assert_eq!(v.aim_target, 9);
}

#[test]
fn shared_vehicle_links_and_queries_survive_checkpoint_and_boarding() {
    use frontline_core::actors::{Actor, Actors};
    use frontline_core::infantry::Infantry;
    use frontline_core::infantry_vitals::Life;
    use frontline_core::spatial::{SpatialIndex, UNIT_CELL};
    let mut s = Infantry::default();
    s.identity.id = 3;
    s.identity.unit = "rifleman".into();
    let mut v = vehicle();
    v.team = 1;
    v.passengers = vec![99];
    let mut actors = Actors::from_entries(
        100,
        vec![Actor::Vehicle(Box::new(v)), Actor::Soldier(Box::new(s))],
    )
    .unwrap();
    let mut index = SpatialIndex::new(UNIT_CELL).unwrap();
    actors.rebuild_units(&mut index).unwrap();
    assert_eq!(
        actors.units_near(&index, Vector3::ZERO, 10.0, -1).unwrap(),
        vec![3, 7]
    );
    assert!(actors.board(7, 3, 1, false).unwrap());
    assert_eq!(actors.soldier(3).unwrap().links.vehicle, 7);
    assert_eq!(actors.soldier(3).unwrap().vitals.life, Life::Hidden);
    assert_eq!(actors.vehicle(7).unwrap().passengers, vec![99, 3]);
    let saved = actors.checkpoint().unwrap();
    let mut restored = Actors::restore(&saved).unwrap();
    assert_eq!(restored.checkpoint().unwrap(), saved);
    assert!(!restored.board(7, 3, 1, false).unwrap());
    restored.rebuild_units(&mut index).unwrap();
    assert_eq!(
        restored
            .units_near(&index, Vector3::ZERO, 10.0, -1)
            .unwrap(),
        vec![7]
    );
}
