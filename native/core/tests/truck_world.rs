#[allow(dead_code)]
#[path = "fixtures/truck_world.rs"]
mod fixture;
use fixture::{field, profile, step};
use frontline_core::battle_stats::DELIVERED;
use frontline_core::vehicle_world::Event;

#[test]
fn a_delivery_updates_stock_income_and_battle_credit_exactly_once() {
    let mut w = field(0);
    let mut income = [vec![], vec![]];
    step(&mut w, profile(), &mut income).unwrap();
    assert_eq!(w.scene.world.actors.structure(30).unwrap().supply, 125.0);
    assert_eq!(w.scene.world.battle.sides[0][DELIVERED], 75.0);
    assert_eq!(income[0], [(100.0, 75)]);
    let truck = w.scene.world.actors.vehicle(20).unwrap();
    assert!(truck.returning);
    assert_eq!(truck.cargo, 0);
    assert_eq!(truck.route_index, 1);
    step(&mut w, profile(), &mut income).unwrap();
    assert_eq!(income[0].len(), 1);
    fixture::transcript();
}
#[test]
fn homecoming_retires_the_truck_and_restarts_the_matching_supply_timer() {
    for trial in [1, 4] {
        let mut w = field(trial);
        step(&mut w, profile(), &mut [vec![], vec![]]).unwrap();
        assert!(w.scene.world.actors.vehicle(20).is_none());
        let source = w.scene.world.actors.structure(30).unwrap();
        assert_eq!(source.truck, 0);
        assert_eq!(source.truck_timer, 4.0);
        assert!(w.scene.world.geometry.pending_removals().contains(&20));
    }
}
#[test]
fn roadblocks_stop_delivery_and_notify_once_until_traffic_clears() {
    let mut w = field(2);
    let mut income = [vec![], vec![]];
    let events = step(&mut w, profile(), &mut income).unwrap();
    assert!(events
        .iter()
        .any(|e| matches!(e, Event::RoadBlocked { .. })));
    assert_eq!(
        w.scene.world.actors.structure(30).unwrap().supply_status,
        "Road blocked"
    );
    assert!(!step(&mut w, profile(), &mut income)
        .unwrap()
        .iter()
        .any(|e| matches!(e, Event::RoadBlocked { .. })));
    assert_eq!(w.scene.world.actors.vehicle(20).unwrap().speed, 0.0);
    w.scene.world.actors.remove(1000);
    step(&mut w, profile(), &mut income).unwrap();
    assert_eq!(w.scene.world.actors.vehicle(20).unwrap().blocked_timer, 0.0);
    assert!(income[0].is_empty());
}
#[test]
fn a_captured_destination_gets_no_supply_and_invalid_inputs_leave_state_alone() {
    let mut w = field(3);
    let mut income = [vec![], vec![]];
    step(&mut w, profile(), &mut income).unwrap();
    assert_eq!(w.scene.world.actors.structure(30).unwrap().supply, 50.0);
    assert!(income[0].is_empty());
    let before = w.resume();
    let mut p = profile();
    p.supply = false;
    assert!(step(&mut w, p, &mut income).is_err());
    w.compare(&before);
}
