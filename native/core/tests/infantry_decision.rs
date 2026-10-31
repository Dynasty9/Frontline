use frontline_core::actors::{Actor, Actors};
use frontline_core::collision::CollisionWorld;
use frontline_core::infantry::Infantry;
use frontline_core::infantry_action::Action;
use frontline_core::infantry_controller::Task;
use frontline_core::infantry_cover::CoverWorld;
use frontline_core::infantry_decision::{Decision, Profile, Speech};
use frontline_core::infantry_vitals::Life;
use frontline_core::infantry_weapon::Weapon;
use frontline_core::path_planner::PathPlanner;
use frontline_core::projectile::Kind;
use frontline_core::projectile_actor::{ballistic, Motion, Projectile};
use frontline_core::random::SimulationRandom;
use frontline_core::spatial::{SpatialIndex, STRUCTURE_CELL, UNIT_CELL};
use frontline_core::squad::{Contact, Report, Squad};
use frontline_core::structure::Structure;
use frontline_core::terrain::Terrain;
use frontline_core::vector::Vector3;
use frontline_core::vehicle::Vehicle;
use frontline_core::visibility::Visibility;
fn soldier(id: u32, x: f32, team: i8) -> Infantry {
    let mut s = Infantry::default();
    s.identity.id = id;
    s.identity.team = team;
    s.identity.unit = "rifleman".into();
    s.identity.weapon = "rifle".into();
    s.identity.squad = 9;
    s.motion.position.x = x;
    s.weapon.magazine = 30;
    s.weapon.reserve = 180;
    s.cover.evaluate_at = 1000.0;
    s
}
fn actor(s: Infantry) -> Actor {
    Actor::Soldier(Box::new(s))
}
fn profile() -> Profile {
    Profile {
        stock: Some((
            210,
            Weapon {
                ammunition: 210,
                magazine: 30,
                reload_time: 2.2,
            },
        )),
        weapon_range: Some(60.0),
        weapon_ammunition: 210,
        bearer: false,
    }
}
fn squad() -> Squad {
    Squad {
        id: 9,
        members: vec![1],
        ..Default::default()
    }
}
struct Field {
    actors: Actors,
    units: SpatialIndex,
    structures: SpatialIndex,
    nav: PathPlanner,
    terrain: Terrain,
    collision: CollisionWorld,
    visibility: Visibility,
}
impl Field {
    fn new(entries: Vec<Actor>) -> Self {
        let actors = Actors::from_entries(100, entries).unwrap();
        let mut units = SpatialIndex::new(UNIT_CELL).unwrap();
        actors.rebuild_units(&mut units).unwrap();
        let mut structures = SpatialIndex::new(STRUCTURE_CELL).unwrap();
        for a in actors.iter() {
            if let Actor::Structure(st) = a {
                structures.insert(st.id, st.position, st.radius).unwrap();
            }
        }
        Self {
            actors,
            units,
            structures,
            nav: PathPlanner::new(128).unwrap(),
            terrain: Terrain::blank(128).unwrap(),
            collision: CollisionWorld::default(),
            visibility: Visibility::default(),
        }
    }
    fn think(
        &mut self,
        now: f64,
        p: Profile,
        q: &mut Squad,
        rng: &mut SimulationRandom,
    ) -> Result<Decision, &'static str> {
        self.actors.think_infantry(
            1,
            now,
            p,
            Some(q),
            &mut CoverWorld {
                terrain: &self.terrain,
                nav: &self.nav,
                collision: &mut self.collision,
                units: &self.units,
                structures: &self.structures,
                heat: &[],
                deck: &[],
            },
            &self.visibility,
            &[],
            |_| 3,
            |_| false,
            rng,
        )
    }
}
#[test]
fn grenade_danger_preempts_melee_looting_and_special_weapons() {
    let mut s = soldier(1, 0.0, 0);
    s.arsenal.rockets = 3;
    s.arsenal.drones = 2;
    s.weapon.magazine = 0;
    s.weapon.reserve = 0;
    let mut dead = soldier(3, 0.8, 0);
    dead.vitals.life = Life::Dead;
    dead.fight.loot = 60;
    let mut f = ballistic(Kind::Frag, Vector3::X, Vector3::ZERO);
    f.fuse = 1.0;
    let p = Projectile {
        id: 30,
        team: 1,
        thrower: 2,
        called_by: 0,
        held_by: 0,
        smothered_by: 0,
        handler: 0,
        thrown_back: 0,
        target_id: 0,
        motion: Motion::Ballistic(f),
    };
    let mut field = Field::new(vec![
        actor(s),
        actor(soldier(2, 1.5, 1)),
        actor(dead),
        Actor::Projectile(p),
    ]);
    let out = field
        .think(10.0, profile(), &mut squad(), &mut SimulationRandom::new(1))
        .unwrap();
    assert_ne!(out.reflex_leaf, 0);
    assert!(out.cancel_path);
    let s = field.actors.soldier(1).unwrap();
    assert_eq!(s.arsenal.rockets, 3);
    assert_eq!(s.arsenal.drones, 2);
    assert_eq!(s.arsenal.melee_ready, 0.0);
    assert_eq!(s.supply.scavenge_at, 0.0);
    assert_eq!(field.actors.soldier(3).unwrap().fight.loot, 60);
}
#[test]
fn busy_duties_do_not_make_fighting_or_supply_decisions() {
    for task in [
        Task::Retreat,
        Task::Stretcher,
        Task::Smother,
        Task::Captor,
        Task::Limp,
        Task::Tunnel,
    ] {
        let mut s = soldier(1, 0.0, 0);
        s.duty.kind = task;
        s.weapon.magazine = 0;
        s.weapon.reserve = 0;
        let mut field = Field::new(vec![actor(s), actor(soldier(2, 1.0, 1))]);
        let before = field.actors.checkpoint().unwrap();
        let mut rng = SimulationRandom::new(3);
        let initial = rng.state();
        let out = field
            .think(10.0, profile(), &mut squad(), &mut rng)
            .unwrap();
        assert_eq!(out, Decision::default());
        assert_eq!(field.actors.checkpoint().unwrap(), before);
        assert_eq!(rng.state(), initial);
    }
}
#[test]
fn melee_preempts_scavenging_and_reports_the_selected_action() {
    let mut s = soldier(1, 0.0, 0);
    s.weapon.magazine = 0;
    s.weapon.reserve = 0;
    let mut dead = soldier(3, 0.5, 0);
    dead.vitals.life = Life::Dead;
    dead.fight.loot = 60;
    let mut f = Field::new(vec![actor(s), actor(soldier(2, 1.5, 1)), actor(dead)]);
    let out = f
        .think(10.0, profile(), &mut squad(), &mut SimulationRandom::new(1))
        .unwrap();
    assert_eq!(out.stats, ["melee"]);
    assert!(out.cancel_path);
    assert_eq!(
        f.actors.soldier(1).unwrap().action.current,
        Action::Melee { target: 2 }
    );
    assert_eq!(f.actors.soldier(3).unwrap().fight.loot, 60);
}
#[test]
fn scavenging_prevents_an_empty_ammunition_warning_and_supply_retreat() {
    let mut s = soldier(1, 0.0, 0);
    s.weapon.magazine = 0;
    s.weapon.reserve = 0;
    let mut dead = soldier(2, 1.0, 0);
    dead.vitals.life = Life::Dead;
    dead.fight.loot = 60;
    let mut f = Field::new(vec![actor(s), actor(dead)]);
    let out = f
        .think(10.0, profile(), &mut squad(), &mut SimulationRandom::new(1))
        .unwrap();
    assert_eq!(out.stats, ["scavenge"]);
    assert!(!out.speech.contains(&Speech::OutOfAmmo));
    assert!(out.route.is_none());
    assert_eq!(f.actors.soldier(1).unwrap().weapon.reserve, 60);
    assert_eq!(f.actors.soldier(1).unwrap().weapon.reload_timer, 2.2);
    assert_eq!(f.actors.soldier(2).unwrap().fight.loot, 0);
}
fn breach_field() -> (Field, Squad) {
    let mut s = soldier(1, 0.0, 0);
    s.grenades.frags = 2;
    s.arsenal.rockets = 3;
    s.arsenal.drones = 2;
    let house = Structure {
        id: 20,
        kind: "floor".into(),
        position: Vector3::X * 15.0,
        size: Vector3::new(8.0, 0.1, 8.0),
        radius: 6.0,
        ..Default::default()
    };
    let wall = Structure {
        id: 21,
        kind: "house_wall".into(),
        position: Vector3::X * 11.0,
        size: Vector3::new(0.3, 3.0, 8.0),
        yaw: std::f64::consts::FRAC_PI_2,
        variant: 2,
        radius: 6.0,
        ..Default::default()
    };
    let mut q = squad();
    q.known.push(Contact {
        id: 7,
        report: Report {
            position: Vector3::X * 15.0,
            time: 10.0,
        },
    });
    (
        Field::new(vec![
            actor(s),
            actor(soldier(7, 15.0, 1)),
            Actor::Structure(Box::new(house)),
            Actor::Structure(Box::new(wall)),
        ]),
        q,
    )
}
#[test]
fn building_entry_preempts_special_weapons_and_retains_the_shared_claim() {
    let (mut f, mut q) = breach_field();
    let mut rng = SimulationRandom::new(3);
    let out = f.think(10.0, profile(), &mut q, &mut rng).unwrap();
    assert_eq!(out.stats, ["breach"]);
    assert!(out.route.is_some());
    assert_eq!(q.breach_by, 1);
    assert_eq!(q.buildings, [(7, 20)]);
    let s = f.actors.soldier(1).unwrap();
    assert_eq!(s.duty.kind, Task::Breach);
    assert_eq!(s.duty.entity, 21);
    assert_eq!(s.entry.house, 20);
    assert_eq!(s.arsenal.rockets, 3);
    assert_eq!(s.grenades.frags, 2);
    let saved = f.actors.checkpoint().unwrap();
    f.actors = Actors::restore(&saved).unwrap();
    q = Squad::restore(&q.checkpoint().unwrap()).unwrap();
    let out = f.think(10.5, profile(), &mut q, &mut rng).unwrap();
    assert!(!out.stats.contains(&"breach"));
    assert_eq!(q.breach_by, 1);
}
#[test]
fn mortar_then_rocket_then_drone_have_stable_priority() {
    for mode in 0..3 {
        let mut s = soldier(1, 0.0, 0);
        s.arsenal.mortar_rounds = if mode == 0 { 2 } else { 0 };
        s.arsenal.rockets = if mode <= 1 { 3 } else { 0 };
        s.arsenal.drones = 4;
        s.fight.visible_targets = vec![10];
        let vehicle = Vehicle {
            id: 10,
            kind: "tank".into(),
            team: 1,
            visible: 1,
            hp: 100.0,
            position: Vector3::X * 50.0,
            ..Default::default()
        };
        let mut f = Field::new(vec![actor(s), Actor::Vehicle(Box::new(vehicle))]);
        let mut q = squad();
        q.fire_queue.push((Vector3::X * 80.0, false));
        let out = f
            .think(10.0, profile(), &mut q, &mut SimulationRandom::new(3))
            .unwrap();
        assert!(out.cancel_path);
        let s = f.actors.soldier(1).unwrap();
        match mode {
            0 => assert!(matches!(s.action.current, Action::Mortar { .. })),
            1 => assert_eq!(s.action.current, Action::Launch { target: 10 }),
            _ => assert_eq!(s.action.current, Action::LaunchDrone { target: 10 }),
        }
        assert_eq!(s.arsenal.drones, if mode == 2 { 3 } else { 4 });
        assert_eq!(q.fire_queue.len(), usize::from(mode != 0));
    }
}
#[test]
fn grenade_cooking_retains_the_followup_throw_and_random_resume() {
    let mut cooked = false;
    let mut thrown = false;
    for seed in 0..64 {
        let mut s = soldier(1, 0.0, 0);
        s.grenades.frags = 2;
        s.entry.next_check = 1000.0;
        let mut enemy = soldier(7, 15.0, 1);
        enemy.cover.at_cover = true;
        enemy.cover.material = 2;
        let mut f = Field::new(vec![actor(s), actor(enemy)]);
        let mut q = squad();
        q.known.push(Contact {
            id: 7,
            report: Report {
                position: Vector3::X * 15.0,
                time: 10.0,
            },
        });
        let mut rng = SimulationRandom::new(seed);
        let out = f.think(10.0, profile(), &mut q, &mut rng).unwrap();
        let s = f.actors.soldier(1).unwrap();
        if out.stats.contains(&"frag_auto") {
            assert_eq!(s.grenades.frags, 1);
            assert!(out.cancel_path);
        }
        match s.action.current {
            Action::Cook => {
                cooked = true;
                assert!(s.action.queued_throw.is_some());
                assert!(out.stats.contains(&"frag_cooked"));
            }
            Action::Throw(_) => {
                thrown = true;
                assert!(s.action.queued_throw.is_none());
            }
            _ => {}
        }
        let mut resumed = Field::new(vec![]);
        resumed.actors = Actors::restore(&f.actors.checkpoint().unwrap()).unwrap();
        resumed.actors.rebuild_units(&mut resumed.units).unwrap();
        let mut q2 = Squad::restore(&q.checkpoint().unwrap()).unwrap();
        let mut rng2 = rng;
        for now in [10.1, 13.0, 20.0] {
            assert_eq!(
                f.think(now, profile(), &mut q, &mut rng).unwrap(),
                resumed.think(now, profile(), &mut q2, &mut rng2).unwrap()
            );
            assert_eq!(
                f.actors.checkpoint().unwrap(),
                resumed.actors.checkpoint().unwrap()
            );
            assert_eq!(q.checkpoint().unwrap(), q2.checkpoint().unwrap());
            assert_eq!(rng.state(), rng2.state());
        }
    }
    assert!(cooked && thrown);
}
#[test]
fn invalid_decision_context_is_rejected_before_any_shared_change() {
    let (mut f, mut q) = breach_field();
    let saved = f.actors.checkpoint().unwrap();
    let qs = q.checkpoint().unwrap();
    let mut rng = SimulationRandom::new(3);
    let state = rng.state();
    let mut p = profile();
    p.weapon_range = Some(f64::NAN);
    assert!(f.think(10.0, p, &mut q, &mut rng).is_err());
    assert!(f.think(f64::INFINITY, profile(), &mut q, &mut rng).is_err());
    f.nav = PathPlanner::new(32).unwrap();
    assert!(f.think(10.0, profile(), &mut q, &mut rng).is_err());
    assert_eq!(f.actors.checkpoint().unwrap(), saved);
    assert_eq!(q.checkpoint().unwrap(), qs);
    assert_eq!(rng.state(), state);
}
