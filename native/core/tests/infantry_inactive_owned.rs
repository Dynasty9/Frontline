use frontline_core::actors::{Actor, Actors};
use frontline_core::collision::CollisionWorld;
use frontline_core::infantry::Infantry;
use frontline_core::infantry_casualty::Inactive;
use frontline_core::infantry_cover::CoverWorld;
use frontline_core::infantry_pose::Posture;
use frontline_core::infantry_vitals::Life;
use frontline_core::path_planner::PathPlanner;
use frontline_core::random::SimulationRandom;
use frontline_core::spatial::{SpatialIndex, DOOR_CELL, STRUCTURE_CELL, UNIT_CELL};
use frontline_core::squad::Squad;
use frontline_core::terrain::Terrain;
use frontline_core::vector::Vector3;

fn soldier(life: Life) -> Infantry {
    let mut s = Infantry::default();
    s.identity.id = 1;
    s.identity.squad = 9;
    s.identity.unit = "rifleman".into();
    s.vitals.life = life;
    s
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
    fn new(s: Infantry, bearer_alive: bool) -> Self {
        let mut bearer = soldier(if bearer_alive {
            Life::Alive
        } else {
            Life::Dead
        });
        bearer.identity.id = 2;
        let actors = Actors::from_entries(
            100,
            vec![
                Actor::Soldier(Box::new(s)),
                Actor::Soldier(Box::new(bearer)),
            ],
        )
        .unwrap();
        let mut units = SpatialIndex::new(UNIT_CELL).unwrap();
        actors.rebuild_units(&mut units).unwrap();
        Self {
            actors,
            units,
            terrain: Terrain::blank(64).unwrap(),
            nav: PathPlanner::new(64).unwrap(),
            collision: CollisionWorld::default(),
            structures: SpatialIndex::new(STRUCTURE_CELL).unwrap(),
            doors: SpatialIndex::new(DOOR_CELL).unwrap(),
            squads: vec![Squad {
                id: 9,
                members: vec![1, 2],
                centroid_at: 3.0,
                ..Default::default()
            }],
            rng: SimulationRandom::new(1729),
        }
    }
    fn step(&mut self, now: f64) -> Result<Inactive, &'static str> {
        self.actors.advance_infantry_inactive(
            1,
            0.1,
            now,
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
fn corpses_keep_the_ground_cache_until_the_strict_deadline() {
    let mut s = soldier(Life::Dead);
    s.motion.position.y = 1.0;
    s.motion.ground = -0.4;
    s.motion.ground_until = 10.0;
    let mut f = Field::new(s, true);
    f.step(10.0).unwrap();
    assert_eq!(f.actors.soldier(1).unwrap().motion.position.y, 0.72);
    assert_eq!(f.actors.soldier(1).unwrap().motion.ground, -0.4);
    f.step(10.1).unwrap();
    let s = f.actors.soldier(1).unwrap();
    assert_eq!(s.motion.ground_until, 10.1 + 0.3);
    assert_eq!(s.motion.ground, 0.0);
    assert_eq!(s.motion.position.y, (f64::from(0.72f32) * 0.8) as f32);
}

#[test]
fn carried_bodies_keep_their_pose_and_skip_ground_and_cleanup() {
    let mut s = soldier(Life::Dead);
    s.links.carried_by = vec![2];
    s.motion.position.y = -0.55;
    let mut f = Field::new(s, true);
    let out = f.step(1000.0).unwrap();
    assert!(out.removed.is_none());
    let s = f.actors.soldier(1).unwrap();
    assert_eq!(s.activity, 13);
    assert_eq!(s.motion.position.y, -0.55);
    assert_eq!(s.motion.ground_until, -1.0);
}

#[test]
fn lost_carriers_are_cleared_before_cleanup_on_the_following_tick() {
    let mut s = soldier(Life::Dead);
    s.links.carried_by = vec![2, 99];
    let mut f = Field::new(s, false);
    assert!(f.step(1000.0).unwrap().removed.is_none());
    let s = f.actors.soldier(1).unwrap();
    assert!(s.links.carried_by.is_empty());
    assert_eq!(s.activity, 0);
    f.actors = Actors::restore(&f.actors.checkpoint().unwrap()).unwrap();
    let out = f.step(1000.1).unwrap();
    assert!(out.removed.unwrap().identity.gone);
    assert!(f.actors.soldier(1).is_none());
    assert_eq!(f.squads[0].members, [2]);
    assert_eq!(f.squads[0].centroid_at, 3.0);
}

#[test]
fn cleanup_respects_three_hundred_seconds_and_stretcher_claims() {
    for claimed in [false, true] {
        let mut s = soldier(Life::Dead);
        s.links.stretcher_claimed = claimed;
        let mut f = Field::new(s, true);
        assert!(f.step(300.0).unwrap().removed.is_none());
        assert_eq!(f.step(300.0001).unwrap().removed.is_none(), claimed);
    }
}

#[test]
fn only_captives_follow_routes_and_both_states_keep_their_hands_up() {
    for life in [Life::Surrender, Life::Captive] {
        let mut s = soldier(life);
        s.motion.path = vec![Vector3::X * 8.0];
        s.posture = Posture::Prone;
        let mut f = Field::new(s, true);
        let random = f.rng.state();
        f.step(10.0).unwrap();
        let s = f.actors.soldier(1).unwrap();
        assert_eq!(s.activity, 20);
        assert_eq!(s.posture, Posture::Stand);
        assert_eq!(
            s.motion.position.x,
            if life == Life::Captive { 0.17 } else { 0.0 }
        );
        assert_eq!(f.rng.state(), random);
    }
}

#[test]
fn invalid_context_leaves_a_corpse_in_its_squad() {
    let mut f = Field::new(soldier(Life::Dead), true);
    let before = f.actors.checkpoint().unwrap();
    assert!(f.step(f64::NAN).is_err());
    assert_eq!(f.actors.checkpoint().unwrap(), before);
    assert_eq!(f.squads[0].members, [1, 2]);
}
