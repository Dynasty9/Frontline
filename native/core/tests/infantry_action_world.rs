#[allow(dead_code)]
#[path = "fixtures/vehicle_loss_world.rs"]
mod fixture;
use fixture::{shared, Scene};
use frontline_core::actors::Actor;
use frontline_core::battle_stats::{DAMAGE, DOWNS, KILLS};
use frontline_core::infantry_action::{Action, Round, Throw};
use frontline_core::infantry_action_owned::{Defense, Event as Ordnance};
use frontline_core::infantry_fight_world::Event;
use frontline_core::infantry_vitals::Life;
use frontline_core::vector::Vector3;
use frontline_core::vehicle_brain::CrewProfile;
use frontline_core::vehicle_launch::SmokeProfile;

fn scene(action: Action, health: f64) -> Scene {
    let mut s = shared::soldier(1, 0.0, Life::Alive);
    s.action.current = action;
    s.action.queued_throw = Some(Throw {
        position: Vector3::X * 10.0,
        round: Round::Frag,
        fuse: 1.8,
    });
    let mut victim = shared::soldier(2, 1.0, Life::Alive);
    victim.identity.team = 1;
    victim.identity.owner = 8;
    victim.vitals.hp = health;
    let mut door = shared::structure(10, "house_wall", 4.0);
    door.door_closed = true;
    door.parts[0].door = true;
    let mut w = Scene::new(
        vec![
            Actor::Soldier(Box::new(s)),
            Actor::Soldier(Box::new(victim)),
            Actor::Structure(Box::new(door)),
        ],
        7371,
    );
    w.world
        .geometry
        .doors
        .insert(10, Vector3::X * 4.0, 2.0)
        .unwrap();
    w
}
fn step(s: &mut Scene, warhead: f64) -> Result<Vec<Event>, &'static str> {
    s.context()
        .advance_infantry_action(1, warhead, &|_| Defense {
            smoke: SmokeProfile {
                armor: 2,
                helicopter: false,
                gun_height: 2.2,
            },
            crew: CrewProfile {
                base: "tank",
                helicopter: false,
                automatic: false,
                artillery: false,
                tracked: true,
                armor: 2,
            },
        })
}

#[test]
fn a_door_kick_changes_shared_visibility_and_door_queries_immediately() {
    let mut w = scene(
        Action::DoorKick {
            door: 10,
            position: Vector3::X * 4.0,
        },
        100.0,
    );
    let from = Vector3::new(4.0, 1.0, -2.0);
    let to = Vector3::new(4.0, 1.0, 2.0);
    assert_eq!(
        w.world.geometry.collision.ray(from, to, &[]).unwrap().body,
        10
    );
    let out = step(&mut w, 1.0).unwrap();
    assert!(!w.world.actors.structure(10).unwrap().door_closed);
    assert!(w.world.actors.structure(10).unwrap().parts.is_empty());
    assert!(w
        .world
        .geometry
        .doors
        .cells()
        .all(|(_, ids)| !ids.contains(&10)));
    assert!(out.contains(&Event::Ordnance(Ordnance::Door(10))));
    assert!(w.world.geometry.collision.ray(from, to, &[]).is_none());
    let geometry = w.world.geometry.checkpoint();
    assert_eq!(geometry, w.resume().world.geometry.checkpoint());
}
#[test]
fn melee_injuries_update_damage_and_casualty_credit_before_returning() {
    for health in [1.0, 100.0] {
        let mut w = scene(Action::Melee { target: 2 }, health);
        let out = step(&mut w, 1.0).unwrap();
        assert!(w.world.battle.sides[0][DAMAGE] > 0.0);
        assert!(out
            .iter()
            .any(|e| matches!(e, Event::Ordnance(Ordnance::Melee { target: 2, .. }))));
        if health == 1.0 {
            assert_eq!(
                w.world.battle.sides[0][DOWNS] + w.world.battle.sides[0][KILLS],
                1.0
            );
            assert_ne!(w.world.actors.soldier(2).unwrap().vitals.life, Life::Alive);
        }
    }
}
#[test]
fn cooked_grenades_preserve_the_throw_delay_and_forced_speech() {
    let mut w = scene(Action::Cook, 100.0);
    let out = step(&mut w, 1.0).unwrap();
    assert!(matches!(
        w.world.actors.soldier(1).unwrap().action.current,
        Action::Throw(_)
    ));
    assert_eq!(w.world.actors.soldier(1).unwrap().action.remaining, 0.6);
    assert_eq!(w.world.actors.entities().len(), 3);
    assert!(matches!(out.as_slice(), [Event::Speech { id: 1, .. }]));
}
#[test]
fn actions_resume_geometry_credit_and_randomness_exactly() {
    for action in [
        Action::Cook,
        Action::Melee { target: 2 },
        Action::DoorKick {
            door: 10,
            position: Vector3::X * 4.0,
        },
        Action::Mortar {
            position: Vector3::X * 12.0,
            round: Round::Smoke,
        },
        Action::LaunchDrone { target: 2 },
    ] {
        let mut a = scene(action, 1.0);
        let mut b = a.resume();
        assert_eq!(step(&mut a, 1.0).unwrap(), step(&mut b, 1.0).unwrap());
        a.world.compare(&b.world);
    }
}
#[test]
fn invalid_warheads_leave_pending_actions_and_the_world_unchanged() {
    let mut w = scene(Action::Melee { target: 2 }, 1.0);
    let before = w.resume();
    assert!(step(&mut w, f64::NAN).is_err());
    w.world.compare(&before.world);
}
