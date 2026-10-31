use frontline_core::actors::{Actor, Actors};
use frontline_core::infantry::Infantry;
use frontline_core::infantry_action::{Action, Round, Throw};
use frontline_core::infantry_action_owned::{Completed, Defense, Event};
use frontline_core::infantry_controller::Task;
use frontline_core::infantry_vitals::Life;
use frontline_core::path_planner::PathPlanner;
use frontline_core::projectile::Kind;
use frontline_core::projectile_actor::{ballistic, Motion, Projectile};
use frontline_core::random::SimulationRandom;
use frontline_core::spatial::{SpatialIndex, UNIT_CELL};
use frontline_core::squad::{Contact, Report, Squad};
use frontline_core::structure::{Part, Structure};
use frontline_core::vector::Vector3;
use frontline_core::vehicle::Vehicle;
use frontline_core::vehicle_brain::CrewProfile;
use frontline_core::vehicle_launch::SmokeProfile;
fn soldier(id: u32, x: f32, team: i8) -> Infantry {
    let mut s = Infantry::default();
    s.identity.id = id;
    s.identity.team = team;
    s.identity.unit = "rifleman".into();
    s.identity.weapon = "rifle".into();
    s.motion.position.x = x;
    s.identity.squad = 9 + u32::from(team == 1);
    s
}
fn actor(s: Infantry) -> Actor {
    Actor::Soldier(Box::new(s))
}
fn grenade(held: u32) -> Projectile {
    let mut f = ballistic(Kind::Frag, Vector3::X * 0.7, Vector3::ZERO);
    f.fuse = 0.8;
    Projectile {
        id: 30,
        team: 1,
        thrower: 7,
        called_by: 0,
        held_by: held,
        smothered_by: 0,
        handler: 1,
        thrown_back: 0,
        target_id: 0,
        motion: Motion::Ballistic(f),
    }
}
fn defense(_: &Vehicle) -> Defense<'static> {
    Defense {
        smoke: SmokeProfile {
            armor: 3,
            helicopter: false,
            gun_height: 2.2,
        },
        crew: CrewProfile {
            base: "tank",
            helicopter: false,
            automatic: false,
            artillery: false,
            tracked: true,
            armor: 3,
        },
    }
}
struct Field {
    actors: Actors,
    nav: PathPlanner,
    units: SpatialIndex,
    squads: Vec<Squad>,
    rng: SimulationRandom,
}
impl Field {
    fn new(entries: Vec<Actor>) -> Self {
        let actors = Actors::from_entries(100, entries).unwrap();
        let mut units = SpatialIndex::new(UNIT_CELL).unwrap();
        actors.rebuild_units(&mut units).unwrap();
        Self {
            actors,
            nav: PathPlanner::new(128).unwrap(),
            units,
            squads: vec![
                Squad {
                    id: 9,
                    members: vec![1],
                    ..Default::default()
                },
                Squad {
                    id: 10,
                    members: vec![7],
                    team: 1,
                    ..Default::default()
                },
            ],
            rng: SimulationRandom::new(83),
        }
    }
    fn complete(&mut self) -> Result<Completed, &'static str> {
        self.actors.complete_infantry_action(
            1,
            10.0,
            1.5,
            &mut self.squads,
            &self.units,
            &self.nav,
            |_| (Some(210), false),
            defense,
            &mut self.rng,
        )
    }
    fn expire(&mut self) {
        let entries = self
            .actors
            .iter()
            .cloned()
            .map(|mut a| {
                if let Actor::Soldier(s) = &mut a {
                    if s.identity.id == 1 {
                        s.action.remaining = 0.0;
                    }
                }
                a
            })
            .collect();
        self.actors = Actors::from_entries(self.actors.entities().next_id(), entries).unwrap();
    }
}
#[test]
fn cooking_starts_the_queued_throw_without_creating_a_projectile_early() {
    let mut s = soldier(1, 0.0, 0);
    s.action.current = Action::Cook;
    s.action.queued_throw = Some(Throw {
        position: Vector3::Z * 20.0,
        round: Round::Frag,
        fuse: 1.8,
    });
    let mut f = Field::new(vec![actor(s)]);
    let out = f.complete().unwrap();
    assert!(out.events.is_empty());
    assert!(out.cancel_path);
    assert!(out.speech.is_some_and(|c| c < 3));
    assert!(matches!(
        f.actors.soldier(1).unwrap().action.current,
        Action::Throw(_)
    ));
    assert_eq!(f.actors.entities().next_id(), 100);
    f.expire();
    let out = f.complete().unwrap();
    assert_eq!(out.events, [Event::Spawn(100)]);
    let Some(Actor::Projectile(p)) = f.actors.get(100) else {
        panic!()
    };
    let Motion::Ballistic(round) = p.motion else {
        panic!()
    };
    assert_eq!(round.fuse, 1.8);
    assert_eq!(p.thrower, 1);
}
#[test]
fn unfinished_actions_only_update_the_pose() {
    let mut s = soldier(1, 0.0, 0);
    s.action.current = Action::Mortar {
        position: Vector3::X * 50.0,
        round: Round::Smoke,
    };
    s.action.remaining = 0.1;
    let mut f = Field::new(vec![actor(s)]);
    let cursor = f.rng.state();
    let out = f.complete().unwrap();
    assert_eq!(out, Completed::default());
    assert_eq!(f.actors.entities().next_id(), 100);
    assert_eq!(f.rng.state(), cursor);
    assert_eq!(
        f.actors.soldier(1).unwrap().posture,
        frontline_core::infantry_pose::Posture::Crouch
    );
}
#[test]
fn pickup_targets_the_original_thrower_then_rethrow_changes_shared_ownership() {
    let mut s = soldier(1, 0.0, 0);
    s.action.current = Action::Pickup { grenade: 30 };
    let mut f = Field::new(vec![
        actor(s),
        actor(soldier(7, 20.0, 1)),
        Actor::Projectile(grenade(1)),
    ]);
    let out = f.complete().unwrap();
    assert!(out.cancel_path);
    assert_eq!(
        f.actors.soldier(1).unwrap().action.current,
        Action::Rethrow {
            grenade: 30,
            position: Vector3::X * 20.0
        }
    );
    let saved = f.actors.checkpoint().unwrap();
    f.actors = Actors::restore(&saved).unwrap();
    f.expire();
    let out = f.complete().unwrap();
    assert_eq!(out.stats, ["throwback"]);
    assert_eq!(out.speech, Some(3));
    let Some(Actor::Projectile(p)) = f.actors.get(30) else {
        panic!()
    };
    assert_eq!((p.held_by, p.team, p.thrower, p.thrown_back), (0, 0, 1, 1));
    let Motion::Ballistic(round) = p.motion else {
        panic!()
    };
    assert!(round.flying);
    assert_eq!(round.fuse, 0.8);
}
#[test]
fn pickup_uses_shared_last_known_position_when_the_thrower_is_missing() {
    let mut s = soldier(1, 0.0, 0);
    s.action.current = Action::Pickup { grenade: 30 };
    let mut p = grenade(1);
    p.thrower = 99;
    let mut f = Field::new(vec![
        actor(s),
        actor(soldier(7, 20.0, 1)),
        Actor::Projectile(p),
    ]);
    f.squads[0].known.push(Contact {
        id: 7,
        report: Report {
            position: Vector3::Z * 12.0,
            time: 5.0,
        },
    });
    f.complete().unwrap();
    assert_eq!(
        f.actors.soldier(1).unwrap().action.current,
        Action::Rethrow {
            grenade: 30,
            position: Vector3::Z * 12.0
        }
    );
}
#[test]
fn kicked_rounds_keep_their_thrower_but_moved_or_held_rounds_are_not_struck() {
    for mode in 0..3 {
        let mut s = soldier(1, 0.0, 0);
        s.action.current = Action::Kick {
            grenade: 30,
            velocity: Vector3::new(8.0, 3.0, 0.0),
        };
        let mut p = grenade(if mode == 2 { 7 } else { 0 });
        if mode == 1 {
            let Motion::Ballistic(f) = &mut p.motion else {
                panic!()
            };
            f.position.x = 1.401;
        }
        let mut f = Field::new(vec![actor(s), Actor::Projectile(p)]);
        let out = f.complete().unwrap();
        let Some(Actor::Projectile(p)) = f.actors.get(30) else {
            panic!()
        };
        assert_eq!(p.thrown_back, u32::from(mode == 0));
        assert_eq!(p.thrower, 7);
        assert_eq!(out.stats.contains(&"kicked"), mode == 0);
        assert_eq!(f.actors.soldier(1).unwrap().vitals.hit_dirt_timer, 1.6);
    }
}
#[test]
fn rocket_smoke_and_evasion_consume_randomness_before_the_launch_event() {
    let mut s = soldier(1, 0.0, 0);
    s.action.current = Action::Launch { target: 10 };
    let v = Vehicle {
        id: 10,
        kind: "tank".into(),
        team: 1,
        hp: 100.0,
        position: Vector3::X * 35.0,
        smoke_left: 2,
        ..Default::default()
    };
    let mut f = Field::new(vec![actor(s), Actor::Vehicle(Box::new(v))]);
    let mut expected = f.rng;
    for _ in 0..8 {
        expected.randf();
    }
    let out = f.complete().unwrap();
    assert_eq!(f.actors.entities().next_id(), 105);
    assert_eq!(f.rng.state(), expected.state());
    assert!(matches!(out.events.first(), Some(Event::Spawn(100))));
    assert!(matches!(out.events.last(), Some(Event::Launch { .. })));
    assert!(matches!(out.events[5], Event::Smoke { vehicle: 10, .. }));
    assert_eq!(out.stats, ["veh_smoke", "veh_evade"]);
    assert_eq!(f.actors.vehicle(10).unwrap().smoke_left, 1);
    assert_eq!(f.actors.vehicle(10).unwrap().brain_state, "evade");
}
#[test]
fn drone_launch_links_the_operator_target_and_upgrade_to_the_spawned_actor() {
    let mut s = soldier(1, 0.0, 0);
    s.action.current = Action::LaunchDrone { target: 7 };
    let mut f = Field::new(vec![actor(s), actor(soldier(7, 30.0, 1))]);
    let out = f.complete().unwrap();
    assert_eq!(out.events, [Event::Spawn(100)]);
    let Some(Actor::Drone(d)) = f.actors.get(100) else {
        panic!()
    };
    assert_eq!((d.operator, d.target, d.warhead), (1, 7, 1.5));
    let s = f.actors.soldier(1).unwrap();
    assert_eq!(s.fight.controlled_drone, 100);
    assert_eq!(s.duty.kind, Task::Pilot);
}
#[test]
fn door_kicks_remove_the_leaf_and_warn_each_nearby_enemy_in_spatial_order() {
    let mut s = soldier(1, 0.0, 0);
    s.action.current = Action::DoorKick {
        door: 20,
        position: Vector3::X * 10.0,
    };
    let part = Part {
        position: Vector3::ZERO,
        size: Vector3::ONE,
        yaw: 0.0,
        infantry: 3,
        vehicle: 3,
        cover: true,
        collision: true,
        door: true,
    };
    let st = Structure {
        id: 20,
        kind: "house_wall".into(),
        position: Vector3::X * 10.0,
        door_closed: true,
        parts: vec![
            part,
            Part {
                door: false,
                ..part
            },
        ],
        ..Default::default()
    };
    let mut f = Field::new(vec![
        actor(s),
        actor(soldier(7, 13.0, 1)),
        actor(soldier(8, 14.0, 1)),
        Actor::Structure(Box::new(st)),
    ]);
    let out = f.complete().unwrap();
    assert_eq!(out.stats, ["door_kicked"]);
    assert_eq!(out.events, [Event::Door(20)]);
    assert_eq!(f.squads[1].heard.len(), 2);
    assert_eq!(f.squads[1].heard[0].position, Vector3::ZERO);
    let st = f.actors.structure(20).unwrap();
    assert!(!st.door_closed);
    assert_eq!(st.parts.len(), 1);
    assert!(!st.parts[0].door);
}
#[test]
fn melee_updates_shared_casualty_state_suppression_and_squad_knowledge() {
    let mut s = soldier(1, 0.0, 0);
    s.action.current = Action::Melee { target: 7 };
    let mut enemy = soldier(7, 1.5, 1);
    enemy.vitals.hp = 1.0;
    let mut f = Field::new(vec![actor(s), actor(enemy)]);
    f.squads[1].morale = 75.0;
    let out = f.complete().unwrap();
    assert!(matches!(&out.events[..], [Event::Melee { target: 7, .. }]));
    assert_ne!(f.actors.soldier(7).unwrap().vitals.life, Life::Alive);
    assert!(f.actors.soldier(7).unwrap().vitals.suppression >= 40.0);
    assert!(f.squads[1].morale < 75.0);
    assert_eq!(f.squads[1].known[0].id, 1);
}
#[test]
fn rejected_grenade_mutations_keep_both_action_and_round_unchanged() {
    let mut s = soldier(1, 0.0, 0);
    s.action.current = Action::Kick {
        grenade: 30,
        velocity: Vector3::X,
    };
    let mut p = grenade(0);
    p.thrown_back = 1_000_000;
    let mut f = Field::new(vec![actor(s), Actor::Projectile(p)]);
    let saved = f.actors.checkpoint().unwrap();
    let cursor = f.rng.state();
    assert!(f.complete().is_err());
    assert_eq!(f.actors.checkpoint().unwrap(), saved);
    assert_eq!(f.rng.state(), cursor);
}
