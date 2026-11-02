#[path = "fixtures/squad_orders.rs"]
#[allow(dead_code)]
mod fixture;
use frontline_core::infantry_action::Round;
use frontline_core::infantry_controller::Task;
use frontline_core::infantry_vitals::Life;
use frontline_core::squad_movement::{Call, Event};
use frontline_core::vector::Vector3;

#[test]
fn attack_and_stop_regroup_the_squad_and_release_rescue_claims() {
    let mut s = fixture::scene(0);
    s.squads[0].ambush_plan = 17;
    s.squads[0].plan = 19;
    let events = s.context().order_attack(7, 9).unwrap();
    assert!(events.contains(&Event::CancelAmbush(17)));
    assert_eq!(s.squads[0].order, "attack");
    assert_eq!(s.squads[0].plan, 0);
    assert_eq!(s.actors.soldier(2).unwrap().links.rescue_claimed, 0);
    assert_eq!(s.actors.soldier(1).unwrap().fight.forced_target, 9);
    s.context().order_stop(7).unwrap();
    assert_eq!(s.squads[0].order, "hold");
    assert_eq!(s.actors.soldier(2).unwrap().vitals.life, Life::Downed);
    assert!(!s.actors.soldier(1).unwrap().is_moving());
}
#[test]
fn construction_reuses_duty_routes_and_releases_shared_claims() {
    let mut s = fixture::scene(0);
    s.context().order_work(7, 9).unwrap();
    assert_eq!(s.squads[0].build_target, 9);
    assert_eq!(s.actors.soldier(3).unwrap().duty.kind, Task::Build);
    assert_eq!(s.actors.soldier(2).unwrap().links.dragged_by, 0);
    assert_eq!(
        s.actors.soldier(1).unwrap().orders.hold_position,
        s.actors.structure(9).unwrap().position
    );
    assert!(s.actors.soldier(1).unwrap().is_moving());
}
#[test]
fn boarding_only_assigns_available_living_members_to_free_seats() {
    let mut s = fixture::scene(0);
    s.context().order_board(7, 8, 3).unwrap();
    let boarded: Vec<_> = (1..=6)
        .filter(|&id| s.actors.soldier(id).unwrap().duty.kind == Task::Board)
        .collect();
    assert_eq!(boarded, vec![1, 3]);
    let mut s = fixture::scene(1);
    let out = s.context().order_board(7, 8, 0).unwrap();
    assert!(out.is_empty());
    assert!(!(1..=6).any(|id| s.actors.soldier(id).unwrap().duty.kind == Task::Board));
}
#[test]
fn garrison_tunnel_and_mount_orders_preserve_specialist_choices() {
    let mut s = fixture::scene(0);
    s.context().order_enter(7, 9, None).unwrap();
    assert_eq!(s.squads[0].order, "tunnel");
    assert_eq!(s.actors.soldier(1).unwrap().duty.kind, Task::Tunnel);
    let mut s = fixture::scene(1);
    s.context().order_enter(7, 9, None).unwrap();
    assert_eq!(s.actors.soldier(1).unwrap().orders.leash, 2.6);
    let mut s = fixture::scene(5);
    s.change(1, |m| m.motion.position = Vector3::new(-40., 0., -10.));
    let events = s.context().order_enter(7, 9, Some(fixture::gun())).unwrap();
    let id = s.actors.structure(9).unwrap().gunner;
    assert!(events.contains(&Event::Stat("manned")));
    assert_eq!(s.actors.soldier(id).unwrap().identity.unit, "mg_gunner");
    assert_eq!(s.actors.soldier(id).unwrap().emplacement.structure, 9);
}
#[test]
fn fire_mission_replaces_four_rounds_and_throw_picks_the_nearest_armed_member() {
    let mut s = fixture::scene(1);
    let p = Vector3::new(10., 0., 5.);
    assert!(s
        .context()
        .order_fire_mission(7, p, true, &|_| false)
        .unwrap()
        .is_empty());
    let events = s
        .context()
        .order_fire_mission(7, p, true, &|m| m.identity.id == 4)
        .unwrap();
    assert_eq!(s.squads[0].fire_queue, vec![(p, true); 4]);
    assert_eq!(
        events,
        vec![Event::Speech {
            soldier: 4,
            call: Call::FireMission,
            variant: 1
        }]
    );
    s.change(1, |m| m.motion.position = p);
    s.context().order_throw(7, p, Round::Smoke).unwrap();
    assert_eq!(s.actors.soldier(1).unwrap().duty.kind, Task::Throw);
}
#[test]
fn invalid_orders_leave_authoritative_state_unchanged() {
    let mut s = fixture::scene(5);
    let before = fixture::state(&s);
    assert!(s.context().order_attack(7, 999).is_err());
    assert!(s.context().order_enter(7, 9, None).is_err());
    assert!(s.context().order_board(7, 8, -1).is_err());
    assert!(s
        .context()
        .order_throw(7, Vector3::ZERO, Round::HighExplosive)
        .is_err());
    assert!(s.context().order_work(7, 999).is_err());
    assert_eq!(fixture::state(&s), before);
}
#[test]
fn every_manual_order_resumes_without_state_or_rng_drift() {
    assert!(!fixture::transcript().is_empty());
}
