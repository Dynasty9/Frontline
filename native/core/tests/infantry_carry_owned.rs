use frontline_core::actors::{Actor, Actors};
use frontline_core::collision::CollisionWorld;
use frontline_core::infantry::Infantry;
use frontline_core::infantry_carry_owned::{Event, Speech};
use frontline_core::infantry_control::HiddenReason;
use frontline_core::infantry_controller::Task;
use frontline_core::infantry_cover::CoverWorld;
use frontline_core::infantry_travel_owned::Event as Movement;
use frontline_core::infantry_vitals::Life;
use frontline_core::path_planner::PathPlanner;
use frontline_core::random::SimulationRandom;
use frontline_core::spatial::{SpatialIndex, DOOR_CELL, STRUCTURE_CELL, UNIT_CELL};
use frontline_core::squad::Squad;
use frontline_core::structure::Structure;
use frontline_core::terrain::Terrain;
use frontline_core::vector::Vector3;

fn bearer(id: u32) -> Infantry {
    let mut s = Infantry::default();
    s.identity.id = id;
    s.identity.unit = "bearer".into();
    s.identity.squad = 9;
    s.duty.kind = Task::Stretcher;
    s.duty.entity = 3;
    s.duty.partner = if id == 1 { 2 } else { 1 };
    s.duty.front = id == 1;
    s.links.home = 10;
    s
}
fn patient() -> Infantry {
    let mut p = bearer(3);
    p.duty.kind = Task::Fight;
    p.duty.entity = 0;
    p.duty.partner = 0;
    p.vitals.life = Life::Downed;
    p.links.carried_by = vec![1, 2];
    p.links.stretcher_claimed = true;
    p
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
}
impl Field {
    fn new(a: Infantry, b: Infantry, p: Infantry) -> Self {
        let actors = Actors::from_entries(
            100,
            vec![
                Actor::Soldier(Box::new(a)),
                Actor::Soldier(Box::new(b)),
                Actor::Soldier(Box::new(p)),
                Actor::Structure(Box::new(Structure {
                    id: 10,
                    kind: "medic_tent".into(),
                    position: Vector3::X * 15.0,
                    ..Default::default()
                })),
            ],
        )
        .unwrap();
        let mut units = SpatialIndex::new(UNIT_CELL).unwrap();
        actors.rebuild_units(&mut units).unwrap();
        Self {
            actors,
            units,
            terrain: Terrain::blank(128).unwrap(),
            nav: PathPlanner::new(128).unwrap(),
            collision: CollisionWorld::default(),
            structures: SpatialIndex::new(STRUCTURE_CELL).unwrap(),
            doors: SpatialIndex::new(DOOR_CELL).unwrap(),
            squads: vec![Squad {
                id: 9,
                members: vec![1, 2, 3],
                ..Default::default()
            }],
            rng: SimulationRandom::new(1729),
        }
    }
    fn step(&mut self, id: u32, dt: f64) -> Result<Vec<Event>, &'static str> {
        self.actors.advance_infantry_stretcher(
            id,
            dt,
            10.0,
            None,
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
    }
}

#[test]
fn the_lead_lifts_and_changes_the_follower_before_his_turn() {
    let mut a = bearer(1);
    a.duty.phase = 1;
    let mut b = bearer(2);
    b.duty.phase = 1;
    let mut p = patient();
    p.links.carried_by.clear();
    let mut f = Field::new(a, b, p);
    let random = f.rng.state();
    let out = f.step(1, 0.1).unwrap();
    assert!(matches!(out[0], Event::Movement(1, Movement::Route(_))));
    assert_eq!(out[1], Event::Speech(1, Speech::Lift));
    assert_eq!(f.actors.soldier(1).unwrap().duty.phase, 2);
    assert_eq!(f.actors.soldier(2).unwrap().duty.phase, 3);
    assert_eq!(f.actors.soldier(3).unwrap().links.carried_by, [1, 2]);
    f.actors = Actors::restore(&f.actors.checkpoint().unwrap()).unwrap();
    assert!(f.step(2, 0.1).unwrap().is_empty());
    assert_eq!(f.actors.soldier(2).unwrap().activity, 10);
    assert_eq!(f.actors.soldier(2).unwrap().duty.phase, 3);
    assert_eq!(f.rng.state(), random);
}

#[test]
fn bearers_wait_for_a_late_partner_until_the_eight_second_deadline() {
    for timer in [-7.999, -8.0] {
        let mut a = bearer(1);
        a.duty.phase = 1;
        a.duty.timer = timer;
        let mut f = Field::new(a, bearer(2), patient());
        let out = f.step(1, 0.0).unwrap();
        assert_eq!(out.is_empty(), timer > -8.0);
        assert_eq!(
            f.actors.soldier(1).unwrap().duty.phase,
            if timer > -8.0 { 1 } else { 2 }
        );
    }
}

#[test]
fn delivery_releases_both_bearers_before_admitting_the_patient() {
    for dead in [false, true] {
        let mut a = bearer(1);
        a.duty.phase = 2;
        let mut b = bearer(2);
        b.duty.phase = 3;
        let mut p = patient();
        if dead {
            p.vitals.life = Life::Dead;
        }
        let mut f = Field::new(a, b, p);
        let exit = f.actors.structure(10).unwrap().exit();
        let mut random = f.rng;
        let destinations: Vec<_> = (0..2)
            .map(|_| {
                exit + Vector3::new(
                    random.randf_range(-2.0, 2.0),
                    0.0,
                    random.randf_range(-2.0, 2.0),
                )
            })
            .collect();
        let out = f.step(1, 0.1).unwrap();
        for i in 0..2 {
            let Event::Movement(id, Movement::Route(route)) = out[i] else {
                panic!("bearer must return first")
            };
            assert_eq!(id, (i + 1) as u32);
            assert_eq!(route.job.destination, destinations[i]);
            let s = f.actors.soldier(id).unwrap();
            assert_eq!(s.duty.kind, Task::Fight);
            assert_eq!(s.duty.entity, 0);
            assert_eq!(s.duty.partner, 0);
        }
        assert_eq!(
            out[2],
            Event::IntoTent {
                soldier: 3,
                squad: 9
            }
        );
        assert_eq!(out[3], Event::Movement(3, Movement::CancelPath));
        let p = f.actors.soldier(3).unwrap();
        assert_eq!(p.vitals.life, Life::Hidden);
        assert_eq!(p.links.tent_dead, dead);
        assert_eq!(p.control.hidden, HiddenReason::Tent);
        assert_eq!(p.control.hidden_timer, if dead { 35.0 } else { 20.0 });
        assert_eq!(p.links.hidden_in, 10);
        assert!(p.links.carried_by.is_empty() && p.links.stretcher_claimed);
        assert_eq!(p.identity.squad, 0);
        assert_eq!(f.squads[0].members, [1, 2]);
        assert_eq!(f.squads[0].centroid_at, -1.0);
        assert_eq!(f.rng.state(), random.state());
    }
}

#[test]
fn a_follower_takes_over_when_the_leader_is_lost() {
    let mut a = bearer(1);
    a.vitals.life = Life::Dead;
    let mut b = bearer(2);
    b.duty.phase = 3;
    let mut f = Field::new(a, b, patient());
    let random = f.rng.state();
    let out = f.step(2, 0.1).unwrap();
    assert_eq!(out.len(), 1);
    assert!(matches!(out[0], Event::Movement(2, Movement::Route(_))));
    assert_eq!(f.actors.soldier(3).unwrap().links.carried_by, [2]);
    assert_eq!(f.actors.soldier(2).unwrap().duty.phase, 2);
    assert_eq!(f.rng.state(), random);
}

#[test]
fn a_leader_switches_to_dragging_after_his_partner_dies() {
    let mut a = bearer(1);
    a.duty.phase = 2;
    a.orders.pending_path = true;
    let mut b = bearer(2);
    b.vitals.life = Life::Dead;
    let mut f = Field::new(a, b, patient());
    let random = f.rng.state();
    assert_eq!(
        f.step(1, 0.1).unwrap(),
        [Event::Speech(1, Speech::BearerDown)]
    );
    let a = f.actors.soldier(1).unwrap();
    assert_eq!(a.activity, 9);
    assert!(a.orders.backwards);
    assert_eq!(f.actors.soldier(3).unwrap().links.carried_by, [1]);
    assert_eq!(f.rng.state(), random);
}

#[test]
fn cancellation_releases_only_this_carrier_and_resets_the_last_claim() {
    let mut a = bearer(1);
    a.links.home = 0;
    let mut b = bearer(2);
    b.links.home = 0;
    let mut p = patient();
    p.motion.position.y = -0.55;
    let mut f = Field::new(a, b, p);
    let random = f.rng.state();
    assert!(f.step(1, 0.1).unwrap().is_empty());
    assert_eq!(f.actors.soldier(3).unwrap().links.carried_by, [2]);
    assert!(f.actors.soldier(3).unwrap().links.stretcher_claimed);
    assert!(f.step(2, 0.1).unwrap().is_empty());
    let p = f.actors.soldier(3).unwrap();
    assert!(p.links.carried_by.is_empty() && !p.links.stretcher_claimed);
    assert_eq!(p.motion.position.y, 0.0);
    assert_eq!(f.rng.state(), random);
}

#[test]
fn invalid_steps_leave_shared_carriers_and_random_state_unchanged() {
    let mut f = Field::new(bearer(1), bearer(2), patient());
    let before = f.actors.checkpoint().unwrap();
    let random = f.rng.state();
    assert!(f.step(1, f64::INFINITY).is_err());
    assert!(f.step(99, 0.1).is_err());
    assert_eq!(f.actors.checkpoint().unwrap(), before);
    assert_eq!(f.rng.state(), random);
}

#[test]
fn removal_from_a_previous_squad_preserves_the_new_squad_link() {
    let mut a = bearer(1);
    a.identity.squad = 10;
    let mut f = Field::new(a, bearer(2), patient());
    f.squads[0].remove_member(1, &mut f.actors).unwrap();
    assert_eq!(f.squads[0].members, [2, 3]);
    assert_eq!(f.actors.soldier(1).unwrap().identity.squad, 10);
}
