#[allow(dead_code)]
#[path = "fixtures/vehicle_movement_world.rs"]
mod fixture;
use fixture::{ground, infantry, vehicle, Field};
use frontline_core::actors::Actor;
use frontline_core::infantry_vitals::Life;
use frontline_core::squad::Squad;
use frontline_core::vector::Vector3;
use frontline_core::vehicle_brain::{CrewEvent, CrewProfile};
use frontline_core::vehicle_movement_world::Event;
use frontline_core::vehicle_scan::ScanProfile;

#[test]
fn scanning_updates_opposing_squad_knowledge_and_resumes() {
    let mut target = infantry(Life::Alive);
    if let Actor::Soldier(s) = &mut target {
        s.identity.squad = 2;
    }
    let mut w = Field::new(vehicle(20, 0, 10.0), target);
    w.scene.world.squads.push(Squad {
        id: 2,
        team: 1,
        owner: 8,
        members: vec![1],
        ..Default::default()
    });
    let mut resumed = w.resume();
    let p = ScanProfile {
        sight: 60.0,
        gun_height: 2.2,
        cannon: true,
        gunship: false,
        anti_air: false,
        penetrating_mg: false,
    };
    let scan = w.scene.context().scan_vehicle_world(20, p).unwrap();
    assert_eq!(
        scan,
        resumed.scene.context().scan_vehicle_world(20, p).unwrap()
    );
    w.compare(&resumed);
    assert_eq!(scan.target, 1);
    assert_eq!(w.scene.world.squads[0].known[0].id, 20);
}
#[test]
fn withdrawing_submits_the_route_before_the_next_vehicle_acts() {
    let mut v = vehicle(20, 0, 0.0);
    v.position.x = -14.0;
    v.hp = 20.0;
    v.max_hp = 100.0;
    let mut fob = fixture::shared::structure(30, "fob", 14.0);
    fob.team = 0;
    fob.built = true;
    let mut w = Field::new(v, Actor::Structure(Box::new(fob)));
    let p = CrewProfile {
        base: "tank",
        helicopter: false,
        automatic: false,
        artillery: false,
        tracked: true,
        armor: 2,
    };
    let mut resumed = w.resume();
    let out = w
        .scene
        .context()
        .think_vehicle_world(20, p, false, &|_| true)
        .unwrap();
    assert_eq!(
        out,
        resumed
            .scene
            .context()
            .think_vehicle_world(20, p, false, &|_| true)
            .unwrap()
    );
    w.compare(&resumed);
    assert!(out.contains(&Event::Crew {
        vehicle: 20,
        event: CrewEvent::Withdraw(30)
    }));
    let v = w.scene.world.actors.vehicle(20).unwrap();
    assert!(!v.path.is_empty() || v.path_pending);
}
#[test]
fn a_driver_pushes_shared_soldiers_and_moves_its_collision() {
    let mut v = vehicle(20, 0, 2.0);
    v.path = vec![Vector3::Z * -10.0];
    v.speed = 3.0;
    let mut target = infantry(Life::Alive);
    if let Actor::Soldier(s) = &mut target {
        s.motion.position = Vector3::new(0.4, 0.0, 0.0);
    }
    let mut w = Field::new(v, target);
    let before = w.scene.world.geometry.collision.checkpoint();
    let mut resumed = w.resume();
    let out = w
        .scene
        .context()
        .drive_vehicle_world(20, 0.1, ground())
        .unwrap();
    assert_eq!(
        out,
        resumed
            .scene
            .context()
            .drive_vehicle_world(20, 0.1, ground())
            .unwrap()
    );
    w.compare(&resumed);
    assert!(w.scene.world.actors.soldier(1).unwrap().motion.position.x > 0.4);
    assert_ne!(before, w.scene.world.geometry.collision.checkpoint());
}
#[test]
fn smashing_retires_navigation_immediately_and_collision_at_tick_end() {
    let mut tree = fixture::shared::structure(30, "tree", 0.0);
    tree.team = -1;
    tree.smashable = true;
    let mut w = Field::new(vehicle(20, 0, 0.0), Actor::Structure(Box::new(tree)));
    let mut resumed = w.resume();
    let out = w.scene.context().smash_vehicle_world(20, false, 2).unwrap();
    assert_eq!(
        out,
        resumed
            .scene
            .context()
            .smash_vehicle_world(20, false, 2)
            .unwrap()
    );
    w.compare(&resumed);
    assert!(out.iter().any(|e| matches!(
        e,
        Event::Smashed {
            tree_yaw: Some(_),
            ..
        }
    )));
    assert!(w.scene.world.actors.structure(30).is_none());
    assert!(w.scene.world.geometry.collision.contains(30));
    w.scene.world.geometry.finish_tick();
    assert!(!w.scene.world.geometry.collision.contains(30));
}
#[test]
fn bad_driving_time_leaves_shared_state_unchanged() {
    let mut w = Field::new(vehicle(20, 0, 0.0), infantry(Life::Alive));
    let before = w.resume();
    assert!(w
        .scene
        .context()
        .drive_vehicle_world(20, f64::NAN, ground())
        .is_err());
    w.compare(&before);
}
