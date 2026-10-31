use frontline_core::actors::{Actor, Actors};
use frontline_core::battle_stats::{BattleStats, CAPTURED, VALUE_KILLED, VALUE_LOST};
use frontline_core::collision::CollisionWorld;
use frontline_core::infantry::{Goal, Infantry};
use frontline_core::infantry_control::HiddenReason;
use frontline_core::infantry_controller::Task;
use frontline_core::infantry_cover::CoverWorld;
use frontline_core::infantry_prison_owned::{Event, Profile};
use frontline_core::infantry_travel_owned::Event as Movement;
use frontline_core::infantry_vitals::Life;
use frontline_core::path_planner::PathPlanner;
use frontline_core::random::SimulationRandom;
use frontline_core::spatial::{SpatialIndex, DOOR_CELL, STRUCTURE_CELL, UNIT_CELL};
use frontline_core::structure::Structure;
use frontline_core::vector::Vector3;

struct Field {
    a: Actors,
    battle: BattleStats,
    terrain: frontline_core::terrain::Terrain,
    nav: PathPlanner,
    rng: SimulationRandom,
}
impl Field {
    fn new(team: i8) -> Self {
        let mut c = Infantry::default();
        c.identity.id = 1;
        c.identity.unit = "rifleman".into();
        c.identity.team = team;
        c.duty.kind = Task::Captor;
        c.duty.entity = 2;
        c.orders.hold_position = Vector3::X * -12.0;
        let mut p = Infantry::default();
        p.identity.id = 2;
        p.identity.unit = "rifleman".into();
        p.identity.team = 1 - team;
        p.vitals.life = Life::Surrender;
        p.links.captor = 1;
        p.motion.position = Vector3::X;
        Self {
            a: Actors::from_entries(
                100,
                vec![Actor::Soldier(Box::new(c)), Actor::Soldier(Box::new(p))],
            )
            .unwrap(),
            battle: BattleStats::default(),
            terrain: frontline_core::terrain::Terrain::blank(128).unwrap(),
            nav: PathPlanner::new(128).unwrap(),
            rng: SimulationRandom::new(1729),
        }
    }
    fn base(&mut self, id: u32, kind: &str, x: f32, built: bool, team: i8) {
        let mut actors: Vec<_> = self.a.iter().cloned().collect();
        actors.push(Actor::Structure(Box::new(Structure {
            id,
            kind: kind.into(),
            position: Vector3::X * x,
            built,
            team,
            ..Default::default()
        })));
        self.a = Actors::from_entries(100, actors).unwrap();
    }
    fn edit(&mut self, id: u32, change: impl FnOnce(&mut Infantry)) {
        let mut actors: Vec<_> = self.a.iter().cloned().collect();
        let s = actors
            .iter_mut()
            .find_map(|a| match a {
                Actor::Soldier(s) if s.identity.id == id => Some(s.as_mut()),
                _ => None,
            })
            .unwrap();
        change(s);
        self.a = Actors::from_entries(100, actors).unwrap();
    }
    fn step(&mut self, fallback: u32) -> Result<Vec<Event>, &'static str> {
        let mut units = SpatialIndex::new(UNIT_CELL).unwrap();
        self.a.rebuild_units(&mut units).unwrap();
        self.a.advance_infantry_captor(
            1,
            0.1,
            10.0,
            Profile {
                value: 25.0,
                fallback_depot: fallback,
                gun: None,
            },
            &mut self.battle,
            &mut [],
            &mut CoverWorld {
                terrain: &self.terrain,
                nav: &self.nav,
                units: &units,
                structures: &SpatialIndex::new(STRUCTURE_CELL).unwrap(),
                collision: &mut CollisionWorld::default(),
                heat: &[],
                deck: &[],
            },
            &SpatialIndex::new(DOOR_CELL).unwrap(),
            &mut self.rng,
        )
    }
}

#[test]
fn capture_prefers_rebel_tunnels_and_credits_exactly_once() {
    let mut f = Field::new(1);
    f.base(11, "fob", 6.0, true, 1);
    f.base(12, "tunnel", 31.0, true, 1);
    f.base(13, "tunnel", 2.0, false, 1);
    f.base(14, "tunnel", 1.0, true, 0);
    let mut expected = f.rng;
    let cue = (expected.randi() % 3) as u8;
    let out = f.step(0).unwrap();
    assert!(out.contains(&Event::Taken {
        prisoner: 2,
        captor: 1,
        destination: 12
    }));
    assert!(out.contains(&Event::Speech { captor: 1, cue }));
    let p = f.a.soldier(2).unwrap();
    assert_eq!(p.vitals.life, Life::Captive);
    assert_eq!(p.links.prison_destination, 12);
    assert_eq!(p.orders.purpose, Goal::Prison);
    assert_eq!(f.battle.sides[0][CAPTURED], 1.0);
    assert_eq!(f.battle.sides[0][VALUE_LOST], 25.0);
    assert_eq!(f.battle.sides[1][VALUE_KILLED], 25.0);
    assert_eq!(f.rng.state(), expected.state());
    let ledger = f.battle.clone();
    f.step(0).unwrap();
    assert_eq!(f.battle, ledger);
    expected.randf(); // An idle guard still consumes the zero-chance shot draw.
    assert_eq!(f.rng.state(), expected.state());
}

#[test]
fn army_uses_first_equal_fob_and_starts_intelligence_clock() {
    let mut f = Field::new(0);
    f.base(14, "tunnel", 1.0, true, 0);
    f.base(12, "fob", 6.0, true, 0);
    f.base(11, "fob", -4.0, true, 0);
    f.step(0).unwrap();
    let p = f.a.soldier(2).unwrap();
    assert_eq!(p.links.prison_destination, 12);
    assert_eq!(p.links.intel_left, 3);
    assert_eq!(p.links.intel_timer, 16.0);
}

#[test]
fn fallback_is_used_only_without_an_eligible_prison() {
    let mut f = Field::new(0);
    let before = f.a.checkpoint().unwrap();
    let ledger = f.battle.clone();
    let cursor = f.rng.state();
    assert!(f.step(99).is_err());
    assert_eq!(before, f.a.checkpoint().unwrap());
    assert_eq!(ledger, f.battle);
    assert_eq!(cursor, f.rng.state());
    f.base(10, "hq", 30.0, true, 0);
    f.step(10).unwrap();
    assert_eq!(f.a.soldier(2).unwrap().links.prison_destination, 10);
}

#[test]
fn missing_or_reassigned_prisoner_returns_guard_to_hold() {
    for missing in [true, false] {
        let mut f = Field::new(0);
        if missing {
            f.a.remove(2);
        } else {
            f.edit(2, |p| p.links.captor = 99);
        }
        let out = f.step(0).unwrap();
        assert!(matches!(
            out.as_slice(),
            [Event::Movement(1, Movement::Route(_))]
        ));
        let c = f.a.soldier(1).unwrap();
        assert_eq!(c.duty.kind, Task::Fight);
        assert_eq!(c.duty.entity, 0);
        assert_eq!(c.orders.purpose, Goal::Slot);
    }
}

#[test]
fn captive_movement_delivers_to_tunnel_and_releases_guard_in_the_same_update() {
    let mut f = Field::new(1);
    f.base(10, "tunnel", 1.0, true, 1);
    f.step(0).unwrap();
    f.edit(2, |p| {
        p.orders.pending_path = false;
        p.motion.path = vec![Vector3::X];
    });
    let mut units = SpatialIndex::new(UNIT_CELL).unwrap();
    f.a.rebuild_units(&mut units).unwrap();
    let out =
        f.a.advance_infantry_inactive(
            2,
            0.1,
            11.0,
            None,
            &mut [],
            &mut CoverWorld {
                terrain: &f.terrain,
                nav: &f.nav,
                units: &units,
                structures: &SpatialIndex::new(STRUCTURE_CELL).unwrap(),
                collision: &mut CollisionWorld::default(),
                heat: &[],
                deck: &[],
            },
            &SpatialIndex::new(DOOR_CELL).unwrap(),
            &mut f.rng,
        )
        .unwrap();
    assert!(out.movement.is_empty());
    assert!(out.prison.contains(&Event::Interrogation {
        prisoner: 2,
        destination: 10
    }));
    assert_eq!(out.prison.last(), Some(&Event::CapturedAlert(2)));
    let p = f.a.soldier(2).unwrap();
    assert_eq!(p.vitals.life, Life::Hidden);
    assert_eq!(p.control.hidden, HiddenReason::Interrogation);
    assert_eq!(p.control.hidden_timer, 34.0);
    assert_eq!(p.links.intel_timer, 15.0);
    assert_eq!(p.links.intel_left, 4);
    assert_eq!(p.links.captor, 0);
    assert_eq!(f.a.soldier(1).unwrap().duty.kind, Task::Fight);
}

#[test]
fn destroyed_destination_holds_prisoner_in_place_without_retasking_reassigned_guard() {
    let mut f = Field::new(0);
    f.base(10, "fob", 15.0, true, 0);
    f.step(0).unwrap();
    f.a.remove(10);
    f.edit(1, |c| c.duty.kind = Task::Heal);
    let guard = f.a.soldier(1).unwrap().clone();
    f.a.arrive_infantry_prison(2, 11.0, &f.nav).unwrap();
    let p = f.a.soldier(2).unwrap();
    assert_eq!(p.control.hidden, HiddenReason::Held);
    assert_eq!(p.control.hidden_timer, 38.0);
    assert_eq!(p.links.hidden_in, 0);
    assert_eq!(p.motion.position, Vector3::X);
    assert_eq!(f.a.soldier(1).unwrap(), &guard);
}

#[test]
fn failed_arrival_does_not_release_guard_or_change_prisoner() {
    let mut f = Field::new(0);
    f.edit(1, |c| c.orders.path_revision = i64::MAX as u64);
    let before = f.a.checkpoint().unwrap();
    assert!(f.a.arrive_infantry_prison(2, 10.0, &f.nav).is_err());
    assert_eq!(before, f.a.checkpoint().unwrap());
}
