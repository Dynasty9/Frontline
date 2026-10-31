use frontline_core::actors::{Actor, Actors};
use frontline_core::infantry::Infantry;
use frontline_core::infantry_control::HiddenReason;
use frontline_core::infantry_vitals::Life;
use frontline_core::path_planner::PathPlanner;
use frontline_core::spatial::{SpatialIndex, UNIT_CELL};
use frontline_core::vector::Vector3;
use frontline_core::vehicle::Vehicle;

fn passengers(v: Vehicle) -> Actors {
    let mut members = vec![Actor::Vehicle(Box::new(v))];
    for id in 2..=4 {
        let mut s = Infantry::default();
        s.identity.id = id;
        s.identity.unit = "rifleman".into();
        s.identity.weapon = "rifle".into();
        s.identity.squad = if id == 4 { 9 } else { 8 };
        s.vitals.life = Life::Hidden;
        s.control.hidden = HiddenReason::Vehicle;
        s.links.vehicle = 1;
        members.push(Actor::Soldier(Box::new(s)));
    }
    Actors::from_entries(5, members).unwrap()
}
fn carrier() -> Vehicle {
    Vehicle {
        id: 1,
        passengers: vec![2, 3, 4],
        ..Default::default()
    }
}

#[test]
fn exiting_updates_passengers_and_retains_the_last_squads_order() {
    let nav = PathPlanner::new(64).unwrap();
    let mut a = passengers(Vehicle {
        passengers: vec![2, 2, 3, 4],
        ..carrier()
    });
    let out = a.dismount(1, false, &nav).unwrap().unwrap();
    assert_eq!(out.squad, 9);
    assert!(!out.assault);
    assert_eq!(out.position, Vector3::NEG_Z * 8.0);
    assert!(a.vehicle(1).unwrap().passengers.is_empty());
    for id in 2..=4 {
        let s = a.soldier(id).unwrap();
        assert_eq!(s.vitals.life, Life::Alive);
        assert_eq!(s.links.vehicle, 0);
        assert_eq!(s.control.hidden, HiddenReason::Waiting);
        assert_eq!(
            s.motion.position,
            Vector3::new(-((id - 2) as f32 - 1.5) * 1.3, 0.0, 3.6)
        );
        assert_eq!(s.orders.hold_position, s.motion.position);
    }
    assert!(a.dismount(1, false, &nav).unwrap().is_none());
}

#[test]
fn removed_passengers_do_not_leave_gaps_and_assault_orders_survive() {
    let nav = PathPlanner::new(64).unwrap();
    let goal = Vector3::new(20.0, 0.0, 13.0);
    let mut a = passengers(Vehicle {
        assault: true,
        assault_destination: Some(goal),
        ..carrier()
    });
    a.remove(3);
    let out = a.dismount(1, false, &nav).unwrap().unwrap();
    assert!(out.assault);
    assert_eq!(out.position, goal);
    assert_eq!(
        a.soldier(4).unwrap().motion.position,
        Vector3::new(0.65, 0.0, 3.6)
    );
}

#[test]
fn boats_preserve_bounded_shore_search_and_exit_spacing() {
    let mut nav = PathPlanner::new(128).unwrap();
    let cells: Vec<u8> = (0..128 * 128)
        .map(|i| if i % 128 >= 84 { 0 } else { 3 })
        .collect();
    assert!(nav.load_cells(&cells, &vec![0; 128 * 128], &vec![0; 128 * 128]));
    let mut a = passengers(carrier());
    // Existing navigation falls back to the current cell when its nine-cell search finds no bank.
    assert!(a.dismount(1, true, &nav).unwrap().is_some());
    assert_eq!(nav.kind_at(a.soldier(2).unwrap().motion.position, false), 3);
    let mut a = passengers(Vehicle {
        position: Vector3::X * 12.0,
        assault_destination: Some(Vector3::X * 30.0),
        ..carrier()
    });
    let out = a.dismount(1, true, &nav).unwrap().unwrap();
    assert!(out.assault);
    for id in 2..=4 {
        assert!(a.soldier(id).unwrap().motion.position.x >= 20.0);
    }
}

#[test]
fn dismount_checks_preserve_arrival_damage_and_visible_enemy_gates() {
    let nav = PathPlanner::new(128).unwrap();
    let mut units = SpatialIndex::new(UNIT_CELL).unwrap();
    let mut a = passengers(Vehicle {
        dismount_timer: 0.1,
        ..carrier()
    });
    assert!(!a.dismount_due(1, 0.05, false, false, &nav, &units).unwrap());
    assert!(a.dismount_due(1, 0.05, false, false, &nav, &units).unwrap());
    let mut a = passengers(Vehicle {
        path: vec![Vector3::NEG_Z * 30.0],
        speed: 3.0,
        dismount_timer: 0.0,
        assault: true,
        ..carrier()
    });
    let foe = Vehicle {
        id: 0,
        team: 1,
        visible: 1,
        position: Vector3::NEG_Z * 40.0,
        ..Default::default()
    };
    a.spawn(Actor::Vehicle(Box::new(foe))).unwrap();
    a.rebuild_units(&mut units).unwrap();
    assert!(a.dismount_due(1, 0.1, false, false, &nav, &units).unwrap());
    let mut a = passengers(Vehicle {
        path: vec![Vector3::NEG_Z * 30.0],
        speed: 3.0,
        dismount_timer: 0.0,
        hp: 39.0,
        max_hp: 100.0,
        ..carrier()
    });
    assert!(a.dismount_due(1, 0.1, false, false, &nav, &units).unwrap());
}

#[test]
fn boat_arrival_clears_landing_once_and_lifts_keep_their_own_schedule() {
    let nav = PathPlanner::new(64).unwrap();
    let units = SpatialIndex::new(UNIT_CELL).unwrap();
    let mut a = passengers(Vehicle {
        landing: true,
        dismount_timer: 0.0,
        ..carrier()
    });
    let saved = a.checkpoint().unwrap();
    assert!(!a.dismount_due(1, 0.1, true, false, &nav, &units).unwrap());
    assert_eq!(a.checkpoint().unwrap(), saved);
    assert!(a.dismount_due(1, 0.1, false, true, &nav, &units).unwrap());
    assert!(!a.vehicle(1).unwrap().landing);
    assert!(!a.dismount_due(1, 1.0, false, true, &nav, &units).unwrap());
    let saved = a.checkpoint().unwrap();
    assert!(a
        .dismount_due(1, f64::NAN, false, true, &nav, &units)
        .is_err());
    assert_eq!(a.checkpoint().unwrap(), saved);
}
