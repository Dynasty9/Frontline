use frontline_core::actors::{Actor, Actors};
use frontline_core::collision::CollisionWorld;
use frontline_core::infantry::Infantry;
use frontline_core::infantry_care_owned::{Care, Profile};
use frontline_core::infantry_controller::Task;
use frontline_core::infantry_cover::CoverWorld;
use frontline_core::infantry_pose::Posture;
use frontline_core::infantry_travel_owned::Event;
use frontline_core::infantry_vitals::Life;
use frontline_core::path_planner::PathPlanner;
use frontline_core::random::SimulationRandom;
use frontline_core::spatial::{SpatialIndex, DOOR_CELL, STRUCTURE_CELL, UNIT_CELL};
use frontline_core::squad::Squad;
use frontline_core::terrain::Terrain;
use frontline_core::vector::Vector3;

fn soldier(id: u32, task: Task) -> Infantry {
    let mut s = Infantry::default();
    s.identity.id = id;
    s.identity.unit = "rifleman".into();
    s.identity.weapon = "rifle".into();
    s.identity.squad = 9;
    s.duty.kind = task;
    s.duty.entity = 2;
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
    profile: Profile<'static>,
}
impl Field {
    fn new(soldiers: Vec<Infantry>) -> Self {
        let actors = Actors::from_entries(
            100,
            soldiers
                .into_iter()
                .map(|s| Actor::Soldier(Box::new(s)))
                .collect(),
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
            rng: SimulationRandom::new(71),
            profile: Profile {
                heal_rate: 1.0,
                medicine_upgrade: false,
                weapon_range: 100.0,
                unarmed: false,
                gun: None,
                restored_weapon: Some(("rifle", 30)),
            },
        }
    }
    fn step(&mut self, id: u32, dt: f64) -> Result<Care, &'static str> {
        self.actors.advance_infantry_care(
            id,
            dt,
            10.0,
            self.profile,
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
fn a_claim_is_visible_to_the_next_medic_without_another_snapshot() {
    let a = soldier(1, Task::Rescue);
    let mut p = soldier(2, Task::Fight);
    p.vitals.life = Life::Downed;
    p.links.rescue_claimed = 1;
    let b = soldier(3, Task::Rescue);
    let mut f = Field::new(vec![a, p, b]);
    let mut expected = f.rng;
    let cue = expected.randi() % 4;
    let first = f.step(1, 0.1).unwrap();
    assert_eq!(first.drag_speech, Some(cue as u8));
    assert!(first.movement.contains(&Event::Stat("drag")));
    assert_eq!(f.actors.soldier(2).unwrap().links.dragged_by, 1);
    assert_eq!(f.actors.soldier(1).unwrap().duty.phase, 2);
    assert_eq!(f.actors.soldier(1).unwrap().duty.timer, 8.0);
    assert_eq!(f.step(3, 0.1).unwrap(), Care::default());
    assert_eq!(f.actors.soldier(3).unwrap().duty.kind, Task::Fight);
    assert_eq!(f.actors.soldier(2).unwrap().links.dragged_by, 1);
    assert_eq!(f.actors.soldier(2).unwrap().links.rescue_claimed, 1);
    assert_eq!(f.rng.state(), expected.state());
}

#[test]
fn treatment_revives_once_and_restores_a_dropped_weapon() {
    let mut a = soldier(1, Task::Rescue);
    a.duty.phase = 2;
    a.duty.timer = 0.1;
    a.orders.backwards = true;
    a.cover.at_cover = true;
    let mut p = soldier(2, Task::Fight);
    p.vitals.life = Life::Downed;
    p.vitals.base_hp = 100.0;
    p.identity.weapon.clear();
    p.links.rescue_claimed = 1;
    p.links.dragged_by = 1;
    let b = soldier(3, Task::Rescue);
    let mut f = Field::new(vec![a, p, b]);
    let mut expected = f.rng;
    let cue = expected.randi() % 4;
    let out = f.step(1, 0.1).unwrap();
    assert_eq!(out.revived, Some((2, cue as u8)));
    let p = f.actors.soldier(2).unwrap();
    assert_eq!(p.vitals.life, Life::Alive);
    assert_eq!(p.vitals.hp, 68.0);
    assert_eq!(p.vitals.max_hp, 80.0);
    assert_eq!(p.vitals.times_downed, 1);
    assert_eq!(p.identity.weapon, "rifle");
    assert_eq!(p.weapon.magazine, 30);
    assert_eq!(p.links.dragged_by, 0);
    assert_eq!(p.links.rescue_claimed, 0);
    let a = f.actors.soldier(1).unwrap();
    assert_eq!(a.duty.kind, Task::Fight);
    assert_eq!(a.duty.entity, 0);
    assert!(!a.orders.backwards && !a.cover.at_cover);
    assert_eq!(f.step(3, 0.1).unwrap(), Care::default());
    assert_eq!(f.actors.soldier(2).unwrap().vitals.times_downed, 1);
    assert_eq!(f.rng.state(), expected.state());
}

#[test]
fn heal_starts_then_counts_down_and_later_healers_see_full_health() {
    for upgrade in [false, true] {
        let a = soldier(1, Task::Heal);
        let mut p = soldier(2, Task::Fight);
        p.vitals.hp = 10.0;
        let b = soldier(3, Task::Heal);
        let mut f = Field::new(vec![a, p, b]);
        f.profile.medicine_upgrade = upgrade;
        f.profile.heal_rate = 2.0;
        let before = f.rng.state();
        assert_eq!(f.step(1, 0.1).unwrap().movement, [Event::CancelPath]);
        let duration = 4.0 * if upgrade { 0.67 } else { 1.0 } * 0.6;
        assert_eq!(f.actors.soldier(1).unwrap().duty.timer, duration);
        f.actors = Actors::restore(&f.actors.checkpoint().unwrap()).unwrap();
        f.step(1, duration).unwrap();
        assert_eq!(f.actors.soldier(1).unwrap().duty.kind, Task::Fight);
        assert_eq!(
            f.actors.soldier(2).unwrap().vitals.hp,
            f.actors.soldier(2).unwrap().vitals.max_hp
        );
        assert_eq!(f.step(3, 0.1).unwrap(), Care::default());
        assert_eq!(f.actors.soldier(3).unwrap().duty.kind, Task::Fight);
        assert_eq!(f.rng.state(), before);
    }
}

#[test]
fn stopped_draggers_place_the_patient_before_starting_treatment() {
    let mut a = soldier(1, Task::Rescue);
    a.duty.phase = 1;
    a.motion.position = Vector3::new(2.0, 0.4, 1.0);
    a.motion.last_direction = Vector3::Z;
    let mut p = soldier(2, Task::Fight);
    p.vitals.life = Life::Downed;
    p.links.dragged_by = 1;
    let mut f = Field::new(vec![a, p]);
    f.step(1, 0.1).unwrap();
    let a = f.actors.soldier(1).unwrap();
    let p = f.actors.soldier(2).unwrap();
    assert_eq!(a.duty.phase, 2);
    assert_eq!(a.duty.timer, 8.0);
    assert!(!a.orders.backwards);
    assert_eq!(a.activity, 9);
    assert_eq!(p.motion.position, Vector3::new(2.0, 0.0, -0.049999952));
    assert_eq!(p.motion.yaw, a.motion.yaw);
    assert_eq!(p.links.dragged_by, 1);
}

#[test]
fn limp_finishes_only_when_movement_has_finished() {
    for pending in [false, true] {
        let mut s = soldier(1, Task::Limp);
        s.orders.pending_path = pending;
        let mut f = Field::new(vec![s]);
        let out = f.step(1, 0.1).unwrap();
        assert_eq!(out.rejoin, !pending);
        let s = f.actors.soldier(1).unwrap();
        assert_eq!(s.duty.kind, if pending { Task::Limp } else { Task::Fight });
        assert_eq!(s.activity, if pending { 22 } else { 0 });
        assert_eq!(s.posture, Posture::Stand);
    }
}

#[test]
fn invalid_context_does_not_change_a_patient_or_random_cursor() {
    let mut p = soldier(2, Task::Fight);
    p.vitals.life = Life::Downed;
    let mut f = Field::new(vec![soldier(1, Task::Rescue), p]);
    let before = f.actors.checkpoint().unwrap();
    let random = f.rng.state();
    assert!(f.step(1, f64::NAN).is_err());
    f.profile.heal_rate = 0.0;
    assert!(f.step(1, 0.1).is_err());
    assert_eq!(f.actors.checkpoint().unwrap(), before);
    assert_eq!(f.rng.state(), random);
}
