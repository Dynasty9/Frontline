use frontline_core::actors::{Actor, Actors};
use frontline_core::collision::CollisionWorld;
use frontline_core::cover::{Anchor, AnchorKind};
use frontline_core::infantry::{Goal, Infantry};
use frontline_core::infantry_fighting::{Mode, WeaponInput};
use frontline_core::infantry_fire::MountedGun;
use frontline_core::infantry_pose::Posture;
use frontline_core::infantry_weapon::Weapon;
use frontline_core::path_planner::PathPlanner;
use frontline_core::random::SimulationRandom;
use frontline_core::spatial::{SpatialIndex, UNIT_CELL};
use frontline_core::squad::Squad;
use frontline_core::structure::Structure;
use frontline_core::vector::Vector3;
use frontline_core::visibility::Visibility;

fn soldier(id: u32) -> Infantry {
    let mut s = Infantry::default();
    s.identity.id = id;
    s.identity.squad = 9;
    s.identity.unit = "rifleman".into();
    s.identity.weapon = "rifle".into();
    s.weapon.magazine = 20;
    s.weapon.reserve = 100;
    s
}
fn actors(s: Infantry) -> Actors {
    let mut target = soldier(2);
    target.identity.team = 1;
    target.motion.position = Vector3::NEG_Z * 20.0;
    Actors::from_entries(
        100,
        vec![
            Actor::Soldier(Box::new(s)),
            Actor::Soldier(Box::new(target)),
        ],
    )
    .unwrap()
}
fn input(mode: Mode) -> WeaponInput {
    WeaponInput {
        dt: 0.1,
        now: 10.0,
        moving: false,
        mode,
        weapon: Some(Weapon {
            ammunition: 120,
            magazine: 30,
            reload_time: 2.0,
        }),
        gun: None,
    }
}
fn aim(
    a: &mut Actors,
    input: WeaponInput,
    squad: Option<&mut Squad>,
    rng: &mut SimulationRandom,
) -> bool {
    let step = a.begin_infantry_weapon(1, input, squad, rng).unwrap();
    a.aim_infantry_weapon(
        step,
        50.0,
        None,
        &mut CollisionWorld::default(),
        &mut Visibility::default(),
        rng,
    )
    .unwrap()
    .point
    .is_some()
}

#[test]
fn weapon_timers_finish_reload_before_selecting_a_stance() {
    let mut s = soldier(1);
    s.weapon.magazine = 0;
    s.weapon.reload_timer = 0.05;
    s.fight.target = 2;
    let mut a = actors(s);
    assert!(aim(
        &mut a,
        input(Mode::Normal),
        None,
        &mut SimulationRandom::new(137)
    ));
    let s = a.soldier(1).unwrap();
    assert_eq!((s.weapon.magazine, s.weapon.reserve), (30, 70));
    assert_eq!(s.weapon.fire_timer, -0.1);
}

#[test]
fn danger_updates_squad_knowledge_only_when_the_shared_query_is_needed() {
    let mut s = soldier(1);
    s.vitals.suppression = 6.0;
    let mut a = actors(s.clone());
    let mut q = Squad {
        id: 9,
        ..Default::default()
    };
    let mut rng = SimulationRandom::new(137);
    let before = q.checkpoint().unwrap();
    a.begin_infantry_weapon(1, input(Mode::Normal), Some(&mut q), &mut rng)
        .unwrap();
    assert_eq!(before, q.checkpoint().unwrap());
    s.vitals.suppression = 0.0;
    let mut a = actors(s);
    a.begin_infantry_weapon(1, input(Mode::Normal), Some(&mut q), &mut rng)
        .unwrap();
    assert_eq!(q.combat_at, 10.0);
}

#[test]
fn moving_and_escort_modes_keep_their_fire_and_hit_dirt_exceptions() {
    for mode in [Mode::Normal, Mode::Escort, Mode::Crew] {
        let mut s = soldier(1);
        s.fight.target = 2;
        s.vitals.suppression = 90.0;
        s.vitals.hit_dirt_timer = 2.0;
        let mut a = actors(s);
        assert_eq!(
            aim(&mut a, input(mode), None, &mut SimulationRandom::new(137)),
            mode == Mode::Escort
        );
        assert_eq!(
            a.soldier(1).unwrap().posture,
            if mode == Mode::Escort {
                Posture::Stand
            } else {
                Posture::Prone
            }
        );
    }
    let mut s = soldier(1);
    s.fight.target = 2;
    s.orders.move_mode = 1;
    let mut a = actors(s);
    assert!(!aim(
        &mut a,
        WeaponInput {
            moving: true,
            ..input(Mode::Normal)
        },
        None,
        &mut SimulationRandom::new(137)
    ));
}

#[test]
fn cover_reload_asks_the_next_squadmate_before_stance_is_applied() {
    let mut s = soldier(1);
    s.fight.target = 2;
    s.fight.visible_targets = vec![2];
    s.cover.at_cover = true;
    s.cover.kind = 1;
    s.cover.height = 1.3;
    s.weapon.peek_up = true;
    s.weapon.magazine = 3;
    s.weapon.peek_from = 5.0;
    s.vitals.suppression = 35.0;
    s.weapon.up_suppression = 0.0;
    let mut mate = soldier(3);
    mate.cover.at_cover = true;
    mate.weapon.peek_timer = 4.0;
    let mut a = actors(s);
    assert_eq!(a.spawn(Actor::Soldier(Box::new(mate))).unwrap(), 100);
    let mut q = Squad {
        id: 9,
        members: vec![1, 100],
        ..Default::default()
    };
    let mut rng = SimulationRandom::new(137);
    let step = a
        .begin_infantry_weapon(1, input(Mode::Normal), Some(&mut q), &mut rng)
        .unwrap();
    assert!(step.cycle.drew_fire && step.cycle.call_cover);
    assert_eq!(step.reply.soldier, 100);
    assert_eq!(a.soldier(100).unwrap().weapon.peek_timer, 0.2);
    assert_eq!(a.soldier(1).unwrap().weapon.reload_timer, 2.0);
    assert!(a
        .aim_infantry_weapon(
            step,
            50.0,
            Some(&q),
            &mut CollisionWorld::default(),
            &mut Visibility::default(),
            &mut rng
        )
        .unwrap()
        .point
        .is_none());
    assert_eq!(a.soldier(1).unwrap().posture, Posture::Crouch);
}

#[test]
fn mounted_gunners_turn_while_waiting_for_the_next_round_and_obey_the_arc() {
    let gun = MountedGun {
        bore: 0.07,
        muzzle: 0.78,
        grip_z: 0.21,
        nest_height: 0.38,
        trench_height: 0.3,
    };
    for yaw in [0.0, std::f64::consts::PI] {
        let st = Structure {
            id: 8,
            kind: "mg_nest".into(),
            yaw,
            ..Default::default()
        };
        let mut s = soldier(1);
        s.motion.position = st.mg_mount_position(gun);
        s.motion.yaw = 0.1;
        s.emplacement.structure = 8;
        s.weapon.fire_timer = 2.0;
        s.fight.target = 2;
        let mut target = soldier(2);
        target.motion.position = Vector3::NEG_Z * 20.0;
        let mut a = Actors::from_entries(
            100,
            vec![
                Actor::Soldier(Box::new(s)),
                Actor::Soldier(Box::new(target)),
                Actor::Structure(Box::new(st)),
            ],
        )
        .unwrap();
        assert!(!aim(
            &mut a,
            WeaponInput {
                gun: Some(gun),
                ..input(Mode::Crew)
            },
            None,
            &mut SimulationRandom::new(137)
        ));
        if yaw == 0.0 {
            assert!(a.soldier(1).unwrap().motion.yaw < 0.1);
        } else {
            assert_eq!(a.soldier(1).unwrap().motion.yaw, 0.1);
        }
    }
}

#[test]
fn invalid_content_preserves_actors_squad_and_randomness() {
    let s = soldier(1);
    let mut a = actors(s);
    let mut q = Squad {
        id: 9,
        ..Default::default()
    };
    let mut rng = SimulationRandom::new(137);
    let before = (a.checkpoint().unwrap(), q.checkpoint().unwrap(), rng);
    let p = WeaponInput {
        dt: f64::NAN,
        ..input(Mode::Normal)
    };
    assert!(a
        .begin_infantry_weapon(1, p, Some(&mut q), &mut rng)
        .is_err());
    assert_eq!(
        (a.checkpoint().unwrap(), q.checkpoint().unwrap(), rng),
        before
    );
}

#[test]
fn a_cover_route_under_heavy_fire_keeps_the_last_metres_prone() {
    let mut s = soldier(1);
    s.orders.purpose = Goal::Cover;
    s.orders.goal = Vector3::X;
    s.motion.path = vec![Vector3::X];
    s.vitals.suppression = 70.0;
    s.fight.target = 2;
    let mut a = actors(s);
    assert!(!aim(
        &mut a,
        WeaponInput {
            moving: true,
            ..input(Mode::Normal)
        },
        None,
        &mut SimulationRandom::new(137)
    ));
    assert_eq!(a.soldier(1).unwrap().posture, Posture::Prone);
}

fn cover_world(edge: bool) -> (Actors, PathPlanner, SpatialIndex) {
    let mut s = soldier(1);
    s.cover.at_cover = true;
    s.cover.kind = if edge { 2 } else { 1 };
    s.cover.normal = Vector3::NEG_Z;
    s.cover.structure = 8;
    s.cover.anchor = 0;
    s.cover.height = 1.3;
    s.weapon.peek_up = true;
    s.weapon.peek_from = 5.0;
    s.vitals.suppression = 35.0;
    s.fight.target = 2;
    let mut target = soldier(2);
    target.motion.position = Vector3::NEG_Z * 25.0;
    let st = Structure {
        id: 8,
        kind: "low_wall".into(),
        anchors: vec![
            Anchor {
                position: Vector3::ZERO,
                normal: Vector3::NEG_Z,
                height: 1.3,
                kind: if edge {
                    AnchorKind::EdgeLeft
                } else {
                    AnchorKind::Over
                },
            },
            Anchor {
                position: Vector3::X * 2.0,
                normal: Vector3::NEG_Z,
                height: 0.4,
                kind: if edge {
                    AnchorKind::EdgeRight
                } else {
                    AnchorKind::Over
                },
            },
            Anchor {
                position: Vector3::NEG_X * 2.0,
                normal: Vector3::NEG_Z,
                height: 0.8,
                kind: if edge {
                    AnchorKind::EdgeLeft
                } else {
                    AnchorKind::Over
                },
            },
        ],
        ..Default::default()
    };
    let a = Actors::from_entries(
        100,
        vec![
            Actor::Soldier(Box::new(s)),
            Actor::Soldier(Box::new(target)),
            Actor::Structure(Box::new(st)),
        ],
    )
    .unwrap();
    let mut nav = PathPlanner::new(64).unwrap();
    assert!(nav.load_cells(&vec![0; 4096], &vec![0; 4096], &vec![0; 4096]));
    let mut units = SpatialIndex::new(UNIT_CELL).unwrap();
    a.rebuild_units(&mut units).unwrap();
    (a, nav, units)
}

#[test]
fn shifting_preserves_anchor_ties_and_applies_the_new_height_before_stance() {
    let (mut a, nav, units) = cover_world(false);
    let mut rng = SimulationRandom::new(137);
    let step = a
        .begin_infantry_weapon(1, input(Mode::Normal), None, &mut rng)
        .unwrap();
    assert!(step.cycle.shift_along);
    let route = a
        .shift_infantry_cover(1, None, &nav, &units)
        .unwrap()
        .unwrap();
    assert_eq!(route.job.destination, Vector3::X * 2.0);
    let s = a.soldier(1).unwrap();
    assert!(s.cover.shifting && !s.cover.at_cover && !s.weapon.peek_up && s.orders.pending_path);
    assert_eq!(s.cover.anchor, 1);
    assert_eq!(s.cover.height, 0.4);
    assert!(a
        .aim_infantry_weapon(
            step,
            50.0,
            None,
            &mut CollisionWorld::default(),
            &mut Visibility::default(),
            &mut rng
        )
        .unwrap()
        .point
        .is_none());
    assert_eq!(a.soldier(1).unwrap().posture, Posture::Prone);
}

#[test]
fn shifting_avoids_squad_claims_even_when_the_claimant_is_far_away() {
    let (mut a, nav, units) = cover_world(true);
    let mut mate = soldier(3);
    mate.motion.position = Vector3::X * 30.0;
    mate.cover.position = Vector3::X * 2.0;
    mate.orders.purpose = Goal::Cover;
    let member = a.spawn(Actor::Soldier(Box::new(mate))).unwrap();
    let q = Squad {
        id: 9,
        members: vec![1, member],
        ..Default::default()
    };
    let route = a
        .shift_infantry_cover(1, Some(&q), &nav, &units)
        .unwrap()
        .unwrap();
    assert_eq!(route.job.destination, Vector3::NEG_X * 2.0);
    assert_eq!(a.soldier(1).unwrap().cover.lean_direction, Vector3::NEG_X);
    assert_eq!(a.soldier(1).unwrap().cover.anchor, 2);
}

#[test]
fn blocked_or_occupied_anchors_leave_cover_and_routes_unchanged() {
    let (mut a, mut nav, mut units) = cover_world(false);
    let mut blocked = vec![0; 4096];
    for z in 26..39 {
        for x in 26..39 {
            blocked[z * 64 + x] = 3;
        }
    }
    assert!(nav.load_cells(&blocked, &blocked, &vec![0; 4096]));
    let before = a.checkpoint().unwrap();
    assert!(a
        .shift_infantry_cover(1, None, &nav, &units)
        .unwrap()
        .is_none());
    assert_eq!(a.checkpoint().unwrap(), before);
    assert!(nav.load_cells(&vec![0; 4096], &vec![0; 4096], &vec![0; 4096]));
    for x in [-2.0, 2.0] {
        let mut mate = soldier(3);
        mate.motion.position = Vector3::X * x;
        a.spawn(Actor::Soldier(Box::new(mate))).unwrap();
    }
    a.rebuild_units(&mut units).unwrap();
    let before = a.checkpoint().unwrap();
    assert!(a
        .shift_infantry_cover(1, None, &nav, &units)
        .unwrap()
        .is_none());
    assert_eq!(a.checkpoint().unwrap(), before);
}
