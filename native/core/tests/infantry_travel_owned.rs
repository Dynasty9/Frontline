use frontline_core::actors::{Actor, Actors};
use frontline_core::collision::CollisionWorld;
use frontline_core::drone::DroneFlight;
use frontline_core::drone_actor::Drone;
use frontline_core::infantry::{Goal, Infantry};
use frontline_core::infantry_action::{Action, Round};
use frontline_core::infantry_control::HiddenReason;
use frontline_core::infantry_controller::Task;
use frontline_core::infantry_cover::CoverWorld;
use frontline_core::infantry_pose::Posture;
use frontline_core::infantry_travel_owned::{Event, Transport};
use frontline_core::infantry_vitals::Life;
use frontline_core::path_planner::PathPlanner;
use frontline_core::random::SimulationRandom;
use frontline_core::spatial::{SpatialIndex, DOOR_CELL, STRUCTURE_CELL, UNIT_CELL};
use frontline_core::squad::Squad;
use frontline_core::structure::Structure;
use frontline_core::terrain::Terrain;
use frontline_core::vector::Vector3;
use frontline_core::vehicle::Vehicle;

fn soldier(id: u32, task: Task) -> Infantry {
    let mut s = Infantry::default();
    s.identity.id = id;
    s.identity.unit = "rifleman".into();
    s.identity.weapon = "rifle".into();
    s.identity.squad = 9;
    s.duty.kind = task;
    s
}
fn entry(s: Infantry) -> Actor {
    Actor::Soldier(Box::new(s))
}
struct Field {
    actors: Actors,
    terrain: Terrain,
    nav: PathPlanner,
    collision: CollisionWorld,
    units: SpatialIndex,
    structures: SpatialIndex,
    doors: SpatialIndex,
    squads: Vec<Squad>,
    rng: SimulationRandom,
    transport: Transport,
}
impl Field {
    fn new(entries: Vec<Actor>) -> Self {
        let actors = Actors::from_entries(100, entries).unwrap();
        let mut units = SpatialIndex::new(UNIT_CELL).unwrap();
        actors.rebuild_units(&mut units).unwrap();
        Self {
            actors,
            terrain: Terrain::blank(128).unwrap(),
            nav: PathPlanner::new(128).unwrap(),
            collision: CollisionWorld::default(),
            units,
            structures: SpatialIndex::new(STRUCTURE_CELL).unwrap(),
            doors: SpatialIndex::new(DOOR_CELL).unwrap(),
            squads: vec![Squad {
                id: 9,
                members: vec![1],
                ..Default::default()
            }],
            rng: SimulationRandom::new(71),
            transport: Transport {
                seats: 1,
                helicopter: false,
                boat: false,
            },
        }
    }
    fn step(&mut self, id: u32) -> Vec<Event> {
        let transport = self.transport;
        self.actors
            .advance_infantry_travel(
                id,
                0.1,
                10.0,
                Some(210),
                None,
                |_| transport,
                &mut self.squads,
                &mut CoverWorld {
                    terrain: &self.terrain,
                    nav: &self.nav,
                    collision: &mut self.collision,
                    units: &self.units,
                    structures: &self.structures,
                    heat: &[],
                    deck: &[],
                },
                &self.doors,
                &mut self.rng,
            )
            .unwrap()
    }
}

#[test]
fn retreat_waits_for_pending_routes_and_resets_cover_only_after_arrival() {
    for pending in [false, true] {
        let mut s = soldier(1, Task::Retreat);
        s.orders.pending_path = pending;
        s.motion.position.x = 3.0;
        s.cover.at_cover = true;
        s.cover.evaluate_at = 7.0;
        let mut f = Field::new(vec![entry(s)]);
        f.step(1);
        let s = f.actors.soldier(1).unwrap();
        assert_eq!(s.posture, Posture::Stand);
        assert_eq!(
            s.duty.kind,
            if pending { Task::Retreat } else { Task::Fight }
        );
        assert_eq!(s.activity, if pending { 2 } else { 0 });
        assert_eq!(s.cover.at_cover, pending);
        if !pending {
            assert_eq!(s.orders.hold_position, s.motion.position);
            assert_eq!(s.cover.evaluate_at, 0.0);
        }
    }
}

#[test]
fn ordered_throws_keep_the_default_fuse_ammunition_and_forced_speech() {
    for round in [Round::Frag, Round::Smoke] {
        let mut s = soldier(1, Task::Throw);
        s.duty.throw_kind = round;
        s.duty.position = Vector3::X * 25.0;
        s.grenades.frags = 2;
        s.fight.smokes = 3;
        s.vitals.speech_cooldown = 9.0;
        let mut f = Field::new(vec![entry(s)]);
        let events = f.step(1);
        let s = f.actors.soldier(1).unwrap();
        let Action::Throw(t) = s.action.current else {
            panic!()
        };
        assert_eq!(t.round, round);
        assert_eq!(t.fuse, 3.4);
        assert_eq!(s.action.remaining, 0.6);
        assert_eq!(s.duty.kind, Task::Fight);
        assert_eq!(s.vitals.speech_cooldown, 2.6);
        assert_eq!(s.grenades.frags, if round == Round::Frag { 1 } else { 2 });
        assert_eq!(s.fight.smokes, if round == Round::Smoke { 2 } else { 3 });
        assert!(events.contains(&Event::ThrowSpeech(round)));
        assert_eq!(
            events.contains(&Event::Stat("smoke")),
            round == Round::Smoke
        );
    }
}

#[test]
fn boarding_claims_the_last_seat_before_another_soldier_can_enter() {
    let mut a = soldier(1, Task::Board);
    a.duty.entity = 10;
    let mut b = soldier(2, Task::Board);
    b.duty.entity = 10;
    let mut f = Field::new(vec![
        entry(a),
        entry(b),
        Actor::Vehicle(Box::new(Vehicle {
            id: 10,
            ..Default::default()
        })),
    ]);
    let events = f.step(1);
    assert!(events.contains(&Event::CancelPath));
    assert!(events.contains(&Event::Stat("boarded")));
    assert!(f.step(2).is_empty());
    assert_eq!(f.actors.soldier(1).unwrap().vitals.life, Life::Hidden);
    assert_eq!(f.actors.soldier(1).unwrap().links.vehicle, 10);
    assert_eq!(f.actors.soldier(2).unwrap().vitals.life, Life::Alive);
    assert_eq!(f.actors.soldier(2).unwrap().duty.kind, Task::Fight);
    assert_eq!(f.actors.vehicle(10).unwrap().passengers, [1]);
}

#[test]
fn stopped_boat_passengers_can_be_hauled_aboard_but_airborne_helicopters_refuse() {
    for helicopter in [false, true] {
        let mut s = soldier(1, Task::Board);
        s.duty.entity = 10;
        let mut f = Field::new(vec![
            entry(s),
            Actor::Vehicle(Box::new(Vehicle {
                id: 10,
                position: Vector3::new(17.0, if helicopter { 1.001 } else { 0.0 }, 0.0),
                ..Default::default()
            })),
        ]);
        f.transport.helicopter = helicopter;
        f.transport.boat = !helicopter;
        f.step(1);
        assert_eq!(
            f.actors.soldier(1).unwrap().vitals.life,
            if helicopter {
                Life::Alive
            } else {
                Life::Hidden
            }
        );
    }
}

#[test]
fn tunnel_arrivals_hide_at_the_entrance_and_retain_occupancy_through_checkpoints() {
    let mut s = soldier(1, Task::Tunnel);
    s.duty.entity = 10;
    let mut f = Field::new(vec![
        entry(s),
        Actor::Structure(Box::new(Structure {
            id: 10,
            kind: "tunnel".into(),
            position: Vector3::X * 2.0,
            built: true,
            ..Default::default()
        })),
    ]);
    assert!(f.step(1).contains(&Event::Stat("tunnel_in")));
    f.actors = Actors::restore(&f.actors.checkpoint().unwrap()).unwrap();
    let s = f.actors.soldier(1).unwrap();
    assert_eq!(s.control.hidden, HiddenReason::TunnelWait);
    assert_eq!(s.links.hidden_in, 10);
    assert_eq!(s.motion.position.x, 2.0);
    assert_eq!(f.actors.structure(10).unwrap().inside, [1]);
}

#[test]
fn pilots_turn_toward_the_shared_drone_then_release_a_missing_controller() {
    let mut s = soldier(1, Task::Pilot);
    s.fight.controlled_drone = 10;
    let mut f = Field::new(vec![
        entry(s),
        Actor::Drone(Drone {
            id: 10,
            team: 0,
            operator: 1,
            operator_at_spawn: 1,
            target: 0,
            target_at_spawn: 0,
            warhead: 1.0,
            flight: DroneFlight::new(Vector3::X * 10.0, 0.0),
        }),
    ]);
    f.step(1);
    assert_ne!(f.actors.soldier(1).unwrap().motion.yaw, 0.0);
    f.actors.remove(10);
    f.step(1);
    let s = f.actors.soldier(1).unwrap();
    assert_eq!(s.duty.kind, Task::Fight);
    assert_eq!(s.fight.controlled_drone, 0);
    assert_eq!(s.posture, Posture::Crouch);
    assert_eq!(s.activity, 24);
}

#[test]
fn arriving_soldiers_share_finite_body_ammunition() {
    let mut a = soldier(1, Task::Resupply);
    a.duty.entity = 3;
    a.weapon.reserve = 200;
    let mut b = soldier(2, Task::Resupply);
    b.duty.entity = 3;
    b.weapon.reserve = 200;
    let mut body = soldier(3, Task::Fight);
    body.vitals.life = Life::Dead;
    body.fight.loot = 15;
    let mut f = Field::new(vec![entry(a), entry(b), entry(body)]);
    assert!(f.step(1).contains(&Event::GotAmmo));
    f.step(2);
    assert_eq!(f.actors.soldier(1).unwrap().weapon.reserve, 210);
    assert_eq!(f.actors.soldier(2).unwrap().weapon.reserve, 205);
    assert_eq!(f.actors.soldier(3).unwrap().fight.loot, 0);
}

#[test]
fn kicked_movement_doors_warn_shared_squads_before_the_next_actor() {
    let mut s = soldier(1, Task::Retreat);
    s.motion.path = vec![Vector3::X * 10.0];
    s.orders.purpose = Goal::Task;
    s.motion.door = 10;
    s.motion.door_wait = 0.05;
    s.motion.door_kick = true;
    let mut enemy = soldier(2, Task::Fight);
    enemy.identity.team = 1;
    enemy.identity.squad = 11;
    let mut f = Field::new(vec![
        entry(s),
        entry(enemy),
        Actor::Structure(Box::new(Structure {
            id: 10,
            kind: "house_wall".into(),
            door_closed: true,
            ..Default::default()
        })),
    ]);
    f.squads.push(Squad {
        id: 11,
        team: 1,
        members: vec![2],
        ..Default::default()
    });
    f.doors.insert_door(10, Vector3::ZERO).unwrap();
    let events = f.step(1);
    assert!(events.contains(&Event::Door {
        id: 10,
        kicked: true
    }));
    assert!(!f.actors.structure(10).unwrap().door_closed);
    assert_eq!(f.squads[1].heard[0].position, Vector3::ZERO);
}

#[test]
fn invalid_transport_capacity_does_not_change_a_passenger_or_randomness() {
    let mut s = soldier(1, Task::Board);
    s.duty.entity = 10;
    let mut f = Field::new(vec![
        entry(s),
        Actor::Vehicle(Box::new(Vehicle {
            id: 10,
            ..Default::default()
        })),
    ]);
    let before = f.actors.checkpoint().unwrap();
    let rng = f.rng.state();
    let result = f.actors.advance_infantry_travel(
        1,
        0.1,
        10.0,
        Some(210),
        None,
        |_| Transport {
            seats: 1001,
            helicopter: false,
            boat: false,
        },
        &mut f.squads,
        &mut CoverWorld {
            terrain: &f.terrain,
            nav: &f.nav,
            collision: &mut f.collision,
            units: &f.units,
            structures: &f.structures,
            heat: &[],
            deck: &[],
        },
        &f.doors,
        &mut f.rng,
    );
    assert!(result.is_err());
    assert_eq!(f.actors.checkpoint().unwrap(), before);
    assert_eq!(f.rng.state(), rng);
}
