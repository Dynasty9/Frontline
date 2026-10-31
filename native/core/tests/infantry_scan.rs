use frontline_core::actors::{Actor, Actors};
use frontline_core::collision::CollisionWorld;
use frontline_core::drone::DroneFlight;
use frontline_core::drone_actor::Drone;
use frontline_core::infantry::Infantry;
use frontline_core::infantry_controller::Task;
use frontline_core::infantry_pose::Posture;
use frontline_core::infantry_scan::ScanProfile;
use frontline_core::infantry_vitals::Life;
use frontline_core::perception::PerceptionSearch;
use frontline_core::structure::Structure;
use frontline_core::terrain::{Terrain, NETTED, WOODS};
use frontline_core::vector::Vector3;
use frontline_core::vehicle::Vehicle;
use frontline_core::visibility::Visibility;

fn soldier(id: u32, x: f32, z: f32) -> Infantry {
    let mut s = Infantry::default();
    s.identity.id = id;
    s.identity.team = if id == 1 { 0 } else { 1 };
    s.identity.unit = "rifleman".into();
    s.identity.weapon = "rifle".into();
    s.motion.position = Vector3::new(x, 0.0, z);
    s
}
fn entry(s: Infantry) -> Actor {
    Actor::Soldier(Box::new(s))
}
fn actors(others: Vec<Actor>) -> Actors {
    let mut entries = vec![entry(soldier(1, 0.0, 0.0))];
    entries.extend(others);
    let next = entries
        .iter()
        .map(|a| u64::from(a.identity().id))
        .max()
        .unwrap()
        + 1;
    Actors::from_entries(next, entries).unwrap()
}
fn profile() -> ScanProfile {
    ScanProfile {
        bearer: false,
        weapon_range: 50.0,
        armor_piercing: false,
    }
}
fn search(a: &Actors, terrain: &Terrain, now: f64) -> PerceptionSearch {
    let mut p = PerceptionSearch::default();
    p.rebuild_actors(a, terrain, now, |v| v.kind == "heli")
        .unwrap();
    p
}
fn scan(a: &mut Actors, p: &PerceptionSearch) -> frontline_core::targeting::Scan {
    a.scan_infantry(
        1,
        20.0,
        profile(),
        p,
        &mut CollisionWorld::default(),
        &mut Visibility::default(),
        |_| 2,
    )
    .unwrap()
}

fn perceive(
    a: &mut Actors,
    q: Option<&mut frontline_core::squad::Squad>,
    units: &frontline_core::spatial::SpatialIndex,
    rng: &mut frontline_core::random::SimulationRandom,
) -> Option<frontline_core::targeting::Scan> {
    let p = search(a, &Terrain::blank(128).unwrap(), 20.0);
    a.perceive_infantry(
        1,
        20.0,
        profile(),
        q,
        units,
        &p,
        &mut CollisionWorld::default(),
        &mut Visibility::default(),
        |_| 2,
        rng,
    )
    .unwrap()
}

#[test]
fn thoughts_skip_alternate_scans_only_while_the_target_still_exists() {
    use frontline_core::{
        random::SimulationRandom,
        spatial::{SpatialIndex, UNIT_CELL},
    };
    let mut a = actors(vec![entry(soldier(2, 0.0, -10.0))]);
    let mut units = SpatialIndex::new(UNIT_CELL).unwrap();
    a.rebuild_units(&mut units).unwrap();
    let mut rng = SimulationRandom::new(19);
    assert!(perceive(&mut a, None, &units, &mut rng).is_some());
    assert!(perceive(&mut a, None, &units, &mut rng).is_some());
    assert!(perceive(&mut a, None, &units, &mut rng).is_none());
    a = Actors::restore(&a.checkpoint().unwrap()).unwrap();
    assert!(perceive(&mut a, None, &units, &mut rng).is_some());
    a.remove(2);
    assert!(perceive(&mut a, None, &units, &mut rng).is_some());
    assert_eq!(a.soldier(1).unwrap().fight.target, 0);
    assert_eq!(a.soldier(1).unwrap().controller.scan_number, 5);
}

#[test]
fn thought_reports_update_the_shared_squad_but_do_not_report_visible_drones() {
    use frontline_core::{
        random::SimulationRandom,
        spatial::{SpatialIndex, UNIT_CELL},
        squad::Squad,
    };
    let mut s = soldier(1, 0.0, 0.0);
    s.identity.squad = 9;
    let drone = Drone {
        id: 4,
        team: 1,
        flight: DroneFlight::new(Vector3::new(5.0, 1.0, 0.0), 0.0),
        operator: 0,
        target: 0,
        operator_at_spawn: 0,
        target_at_spawn: 0,
        warhead: 1.0,
    };
    let mut a = Actors::from_entries(
        10,
        vec![entry(s), entry(soldier(2, 0.0, -10.0)), Actor::Drone(drone)],
    )
    .unwrap();
    let mut units = SpatialIndex::new(UNIT_CELL).unwrap();
    a.rebuild_units(&mut units).unwrap();
    let mut q = Squad {
        id: 9,
        members: vec![1],
        ..Default::default()
    };
    let out = perceive(&mut a, Some(&mut q), &units, &mut SimulationRandom::new(1)).unwrap();
    assert!(out.visible.contains(&4));
    assert_eq!(q.known.len(), 1);
    assert_eq!(q.known[0].id, 2);
    assert_eq!(q.known[0].report.time, 20.0);
    assert_eq!(q.combat_at, 20.0);
    assert!(q.combat);
}

#[test]
fn separation_still_runs_on_skipped_scans_and_uses_current_positions_in_old_buckets() {
    use frontline_core::{
        random::SimulationRandom,
        spatial::{SpatialIndex, UNIT_CELL},
    };
    let mut a = actors(vec![
        entry(soldier(2, 0.0, 0.0)),
        entry(soldier(3, 0.3, 0.0)),
    ]);
    let mut units = SpatialIndex::new(UNIT_CELL).unwrap();
    a.rebuild_units(&mut units).unwrap();
    let mut rng = SimulationRandom::new(19);
    perceive(&mut a, None, &units, &mut rng);
    perceive(&mut a, None, &units, &mut rng);
    let before = rng.state();
    assert!(perceive(&mut a, None, &units, &mut rng).is_none());
    assert_ne!(rng.state(), before);
    assert_ne!(a.soldier(1).unwrap().fight.separation, Vector3::ZERO);
    let entries = a
        .iter()
        .cloned()
        .map(|mut actor| {
            if let Actor::Soldier(s) = &mut actor {
                if s.identity.id != 1 {
                    s.motion.position.x = 40.0;
                }
            }
            actor
        })
        .collect();
    a = Actors::from_entries(4, entries).unwrap();
    let before = rng.state();
    perceive(&mut a, None, &units, &mut rng);
    assert_eq!(rng.state(), before);
    assert_eq!(a.soldier(1).unwrap().fight.separation, Vector3::ZERO);
}

#[test]
fn inactive_separation_clears_without_consuming_randomness() {
    use frontline_core::{
        random::SimulationRandom,
        spatial::{SpatialIndex, UNIT_CELL},
    };
    for mode in 0..4 {
        let mut s = soldier(1, 0.0, 0.0);
        s.fight.separation = Vector3::X;
        match mode {
            0 => s.links.dragged_by = 2,
            1 => s.duty.kind = Task::Stretcher,
            2 => s.duty.kind = Task::Captor,
            _ => s.vitals.life = Life::Downed,
        }
        let mut a = Actors::from_entries(3, vec![entry(s), entry(soldier(2, 0.0, 0.0))]).unwrap();
        let mut units = SpatialIndex::new(UNIT_CELL).unwrap();
        a.rebuild_units(&mut units).unwrap();
        let mut rng = SimulationRandom::new(19);
        let before = rng.state();
        perceive(&mut a, None, &units, &mut rng);
        assert_eq!(rng.state(), before);
        assert_eq!(a.soldier(1).unwrap().fight.separation, Vector3::ZERO);
    }
}

#[test]
fn invalid_thought_context_does_not_advance_the_scan_clock_or_random_stream() {
    use frontline_core::{
        random::SimulationRandom,
        spatial::{SpatialIndex, UNIT_CELL},
        squad::Squad,
    };
    let mut a = actors(vec![entry(soldier(2, 0.0, 0.0))]);
    let units = SpatialIndex::new(UNIT_CELL).unwrap();
    let p = search(&a, &Terrain::blank(128).unwrap(), 20.0);
    let mut rng = SimulationRandom::new(19);
    let before = a.checkpoint().unwrap();
    let cursor = rng.state();
    let mut q = Squad {
        id: 9,
        ..Default::default()
    };
    assert!(a
        .perceive_infantry(
            1,
            20.0,
            profile(),
            Some(&mut q),
            &units,
            &p,
            &mut CollisionWorld::default(),
            &mut Visibility::default(),
            |_| 2,
            &mut rng
        )
        .is_err());
    assert_eq!(a.checkpoint().unwrap(), before);
    assert_eq!(rng.state(), cursor);
}

#[test]
fn nearest_seven_keep_id_ties_and_update_retained_contacts() {
    let mut a = actors(
        (2..12)
            .rev()
            .map(|id| entry(soldier(id, 0.0, -20.0)))
            .collect(),
    );
    let p = search(&a, &Terrain::blank(256).unwrap(), 20.0);
    let r = scan(&mut a, &p);
    assert_eq!(r.target, 2);
    assert_eq!(r.visible, vec![2, 3, 4, 5, 6, 7, 8]);
    assert_eq!(r.reported, 7);
    assert_eq!(a.soldier(1).unwrap().fight.visible_targets, r.visible);
}

#[test]
fn snapshot_preserves_concealment_recent_casualties_and_netted_aircraft() {
    let mut terrain = Terrain::blank(256).unwrap();
    let mut quiet = soldier(2, 0.0, -30.0);
    quiet.cover.at_cover = true;
    let mut firing = soldier(3, 1.0, -30.0);
    firing.cover.at_cover = true;
    firing.weapon.last_shot = 19.0;
    let mut wounded = soldier(4, 2.0, -20.0);
    wounded.vitals.life = Life::Downed;
    wounded.weapon.last_shot = 19.0;
    let mut silent = soldier(5, 3.0, -20.0);
    silent.vitals.life = Life::Downed;
    for s in [&quiet, &firing] {
        let i = terrain.index(s.motion.position);
        terrain.layers[WOODS][i] = 1;
    }
    let mut entries = vec![entry(quiet), entry(firing), entry(wounded), entry(silent)];
    for id in 6..8 {
        let v = Vehicle {
            id,
            kind: if id == 6 { "tank" } else { "heli" }.into(),
            team: 1,
            position: Vector3::new((id - 6) as f32, if id == 7 { 14.0 } else { 0.0 }, -60.0),
            ..Default::default()
        };
        let i = terrain.index(v.position);
        terrain.layers[NETTED][i] = 1;
        entries.push(Actor::Vehicle(Box::new(v)));
    }
    let a = actors(entries);
    let p = search(&a, &terrain, 20.0);
    assert_eq!(p.nearest_owned(0.0, 0.0, 0, 56.0), vec![4, 3, 7]);
}

#[test]
fn removed_and_newly_silent_targets_are_filtered_without_refilling_the_seven() {
    let mut a = actors(
        (2..11)
            .map(|id| entry(soldier(id, id as f32, 0.0)))
            .collect(),
    );
    let p = search(&a, &Terrain::blank(256).unwrap(), 20.0);
    a.remove(2);
    a.remove(3);
    let r = scan(&mut a, &p);
    assert_eq!(r.visible, vec![4, 5, 6, 7, 8]);
    let mut casualty = soldier(4, 4.0, 0.0);
    casualty.vitals.life = Life::Downed;
    casualty.weapon.last_shot = 18.0;
    let mut b = actors(vec![entry(casualty)]);
    let p = search(&b, &Terrain::blank(256).unwrap(), 20.0);
    let result = b
        .scan_infantry(
            1,
            20.001,
            profile(),
            &p,
            &mut CollisionWorld::default(),
            &mut Visibility::default(),
            |_| 0,
        )
        .unwrap();
    assert!(result.visible.is_empty());
}

#[test]
fn mounted_gunners_report_flanks_but_aim_within_the_arc_and_towers_extend_sight() {
    for (kind, z, expected, visible) in [
        ("mg_nest", -20.0, 3, vec![2, 3]),
        ("watchtower", -70.0, 2, vec![2, 3]),
    ] {
        let mut s = soldier(1, 0.0, 0.0);
        s.emplacement.structure = 9;
        s.duty.kind = Task::Man;
        s.duty.phase = 2;
        s.posture = Posture::Crouch;
        let mut a = Actors::from_entries(
            100,
            vec![
                entry(s),
                entry(soldier(2, 10.0, 0.0)),
                entry(soldier(3, 0.0, z)),
                Actor::Structure(Box::new(Structure {
                    id: 9,
                    kind: kind.into(),
                    ..Default::default()
                })),
            ],
        )
        .unwrap();
        let p = search(&a, &Terrain::blank(256).unwrap(), 20.0);
        let r = scan(&mut a, &p);
        assert_eq!(r.target, expected);
        assert_eq!(r.visible, visible);
    }
}

#[test]
fn drones_follow_registration_order_and_forced_buildings_keep_the_legacy_range_override() {
    let mut a = actors(vec![entry(soldier(2, 0.0, -10.0))]);
    let mut ids = vec![];
    for x in [1.0, 2.0] {
        ids.push(
            a.spawn(Actor::Drone(Drone {
                id: 0,
                team: 1,
                operator: 0,
                target: 0,
                operator_at_spawn: 0,
                target_at_spawn: 0,
                warhead: 1.0,
                flight: DroneFlight::new(Vector3::new(x, 5.0, -20.0), 0.0),
            }))
            .unwrap(),
        );
    }
    let p = search(&a, &Terrain::blank(256).unwrap(), 20.0);
    let r = scan(&mut a, &p);
    assert_eq!(r.target, u64::from(ids[1]));
    assert_eq!(r.reported, 1);
    assert_eq!(r.visible.len(), 3);
    let mut s = soldier(1, 0.0, 0.0);
    s.fight.forced_target = 9;
    let mut a = Actors::from_entries(
        100,
        vec![
            entry(s),
            Actor::Structure(Box::new(Structure {
                id: 9,
                team: 1,
                kind: "bunker".into(),
                visible: 0,
                position: Vector3::NEG_Z * 49.0,
                ..Default::default()
            })),
        ],
    )
    .unwrap();
    let p = search(&a, &Terrain::blank(256).unwrap(), 20.0);
    let r = scan(&mut a, &p);
    assert_eq!(r.target, 9);
    assert!(r.visible.is_empty());
}

#[test]
fn bearers_clear_contacts_without_casting_and_invalid_inputs_are_atomic() {
    let mut s = soldier(1, 0.0, 0.0);
    s.fight.target = 2;
    s.fight.visible_targets = vec![2];
    let mut a = Actors::from_entries(100, vec![entry(s), entry(soldier(2, 0.0, -10.0))]).unwrap();
    let p = search(&a, &Terrain::blank(256).unwrap(), 20.0);
    let before = a.checkpoint().unwrap();
    let mut vis = Visibility::default();
    let mut c = CollisionWorld::default();
    assert!(a
        .scan_infantry(1, f64::NAN, profile(), &p, &mut c, &mut vis, |_| 0)
        .is_err());
    assert_eq!(a.checkpoint().unwrap(), before);
    let r = a
        .scan_infantry(
            1,
            20.0,
            ScanProfile {
                bearer: true,
                ..profile()
            },
            &p,
            &mut c,
            &mut vis,
            |_| 0,
        )
        .unwrap();
    assert_eq!(r.target, 0);
    assert!(a.soldier(1).unwrap().fight.visible_targets.is_empty());
    assert_eq!(vis.rays, 0);
}

#[test]
fn owned_contacts_keep_unsigned_entity_ids_and_checkpoint_continuation() {
    let mut a = actors(vec![entry(soldier(u32::MAX - 1, 0.0, -10.0))]);
    let terrain = Terrain::blank(256).unwrap();
    let p = search(&a, &terrain, 20.0);
    assert_eq!(scan(&mut a, &p).target, u64::from(u32::MAX - 1));
    let mut restored = Actors::restore(&a.checkpoint().unwrap()).unwrap();
    let q = search(&restored, &terrain, 20.0);
    assert_eq!(scan(&mut a, &p), scan(&mut restored, &q));
}
