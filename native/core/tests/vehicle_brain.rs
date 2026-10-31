use frontline_core::path_planner::PathPlanner;
use frontline_core::random::SimulationRandom;
use frontline_core::vector::Vector3;
use frontline_core::vehicle::{Route, Vehicle};
use frontline_core::vehicle_brain::*;

fn profile() -> CrewProfile<'static> {
    CrewProfile {
        base: "tank",
        helicopter: false,
        automatic: false,
        artillery: false,
        tracked: true,
        armor: 3,
    }
}
fn vehicle() -> Vehicle {
    Vehicle {
        id: 1,
        team: 0,
        owner: -1,
        max_hp: 1000.0,
        hp: 1000.0,
        path: vec![Vector3::NEG_Z * 50.0],
        ..Default::default()
    }
}
fn scene() -> Perception<'static> {
    Perception {
        threats: &[],
        ahead: &[],
        support: &[],
        fob: None,
        mission: false,
    }
}
fn antitank(id: u32, at: Vector3) -> Contact {
    Contact {
        id,
        position: at,
        team: 1,
        visible: true,
        gone: false,
        kind: UnitKind::Soldier {
            alive: true,
            rockets: 1,
            antitank: false,
            riding: false,
        },
    }
}

#[test]
fn withdrawal_prioritizes_damage_but_respects_player_and_mission_limits() {
    let nav = PathPlanner::new(512).unwrap();
    let mut v = vehicle();
    v.hp = 350.0;
    v.assault = true;
    let mut s = scene();
    s.fob = Some((9, Vector3::X * 80.0));
    let out = v.crew_think(3.0, profile(), s, &nav).unwrap();
    assert_eq!(out.event, Some(CrewEvent::Withdraw(9)));
    assert_eq!(v.brain_state, "withdraw");
    assert!(!v.assault && v.path_pending && !v.brain_order);
    assert_eq!(v.path_destination, Some(Vector3::X * 68.0));
    assert!(matches!(out.route, Route::Ground { care: 0.5, .. }));
    for overruled in [false, true] {
        let mut v = vehicle();
        v.hp = 300.0;
        v.brain_overruled = overruled;
        s.mission = !overruled;
        s.fob = Some((9, Vector3::X * 200.0));
        assert_eq!(v.crew_think(3.0, profile(), s, &nav).unwrap().event, None);
        assert_eq!(v.brain_state, "");
    }
}

#[test]
fn crew_repairs_at_the_fob_and_turns_towards_the_nearest_visible_threat() {
    let nav = PathPlanner::new(128).unwrap();
    let mut v = vehicle();
    v.hp = 799.0;
    v.brain_state = "withdraw".into();
    let units = [
        antitank(8, Vector3::X * 30.0),
        antitank(9, Vector3::NEG_Z * 20.0),
    ];
    let s = Perception {
        threats: &units,
        fob: Some((10, Vector3::X * 10.0)),
        ..scene()
    };
    let out = v.crew_think(3.0, profile(), s, &nav).unwrap();
    assert_eq!(out.event, Some(CrewEvent::PatchedUp));
    assert!(v.hp > 800.0);
    assert_eq!(v.brain_state, "");
    assert_eq!(v.face_yaw, Some(0.0));
}

#[test]
fn waiting_for_infantry_has_a_deadline_and_player_orders_do_not_wait() {
    let nav = PathPlanner::new(128).unwrap();
    let threats = [antitank(8, Vector3::NEG_Z * 30.0)];
    let s = Perception {
        ahead: &threats,
        threats: &threats,
        ..scene()
    };
    let mut v = vehicle();
    v.assault = true;
    assert_eq!(
        v.crew_think(10.0, profile(), s, &nav).unwrap().event,
        Some(CrewEvent::WaitInfantry)
    );
    assert!(v.brain_hold);
    v.crew_think(55.0, profile(), s, &nav).unwrap();
    assert!(v.brain_hold);
    v.crew_think(55.1, profile(), s, &nav).unwrap();
    assert!(!v.brain_hold);
    assert_eq!(v.cooldowns, vec![("push_on".into(), 115.1)]);
    v.crew_think(115.0, profile(), s, &nav).unwrap();
    assert!(!v.brain_hold);
    v.crew_think(115.1, profile(), s, &nav).unwrap();
    assert!(v.brain_hold);
    v.owner = 3;
    v.crew_think(116.0, profile(), s, &nav).unwrap();
    assert!(!v.brain_hold);
    v.owner = -1;
    v.brain_state = "wait".into();
    let saved = v.clone();
    assert!(v.crew_think(1e12, profile(), s, &nav).is_err());
    assert_eq!(v, saved);
}

#[test]
fn infantry_support_must_be_alive_and_out_of_its_vehicle() {
    let nav = PathPlanner::new(128).unwrap();
    let threats = [antitank(8, Vector3::NEG_Z * 30.0)];
    for riding in [false, true] {
        let mut ally = antitank(9, Vector3::ZERO);
        ally.team = 0;
        ally.kind = UnitKind::Soldier {
            alive: true,
            riding,
            rockets: 0,
            antitank: false,
        };
        let support = [ally];
        let s = Perception {
            ahead: &threats,
            support: &support,
            ..scene()
        };
        let mut v = vehicle();
        v.assault = true;
        v.crew_think(10.0, profile(), s, &nav).unwrap();
        assert_eq!(v.brain_hold, riding);
    }
}

#[test]
fn missile_evasion_preserves_pending_attack_orders_across_checkpoints() {
    let nav = PathPlanner::new(128).unwrap();
    let mut rng = SimulationRandom::new(137);
    let mut v = vehicle();
    v.path_pending = true;
    v.path_destination = Some(Vector3::X * 40.0);
    v.assault = true;
    v.assault_destination = Some(Vector3::X * 42.0);
    let out = v
        .crew_threat(5.0, Vector3::NEG_Z * 30.0, profile(), &nav, &mut rng)
        .unwrap();
    assert_eq!(out.event, Some(CrewEvent::Evade));
    assert_eq!(v.resume.unwrap().destination, Some(Vector3::X * 40.0));
    let mut restored = Vehicle::restore(&v.checkpoint().unwrap()).unwrap();
    // Pending paths have no points, so the original crew resumes on its next decision.
    for a in [&mut v, &mut restored] {
        a.crew_think(5.5, profile(), scene(), &nav).unwrap();
        assert_eq!(a.brain_state, "");
        assert!(a.assault && a.resume.is_none());
        assert_eq!(a.path_destination, Some(Vector3::X * 42.0));
    }
    assert_eq!(v, restored);
}

#[test]
fn invalid_or_exhausted_evasion_does_not_lose_the_order_or_random_cursor() {
    let nav = PathPlanner::new(128).unwrap();
    let mut rng = SimulationRandom::new(137);
    let mut v = vehicle();
    v.path_revision = i64::MAX as u64;
    let saved = v.clone();
    let before = rng.state();
    assert!(v
        .crew_threat(5.0, Vector3::NEG_Z * 30.0, profile(), &nav, &mut rng)
        .is_err());
    assert_eq!(v, saved);
    assert_eq!(rng.state(), before);
    assert!(v.crew_think(f64::NAN, profile(), scene(), &nav).is_err());
    assert_eq!(v, saved);
}

#[test]
fn vehicle_recovery_uses_the_vehicle_grid_in_stable_nearest_order() {
    let mut nav = PathPlanner::new(32).unwrap();
    let infantry = vec![0; 32 * 32];
    let mut vehicles = vec![0; 32 * 32];
    vehicles[16 * 32 + 16] = 3;
    assert!(nav.load_cells(&infantry, &vehicles, &infantry));
    assert_eq!(nav.nearest_walkable(Vector3::ZERO), Some(Vector3::ZERO));
    assert_eq!(
        nav.nearest_walkable_for(Vector3::ZERO, true),
        Some(Vector3::new(-0.5, 0.0, -0.5))
    );
}
