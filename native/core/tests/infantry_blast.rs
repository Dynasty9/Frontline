use frontline_core::actors::{Actor, Actors};
use frontline_core::blast::Blast;
use frontline_core::collision::{BoxShape, CollisionWorld, Mat3};
use frontline_core::infantry::{Credit, Infantry};
use frontline_core::infantry_controller::Task;
use frontline_core::infantry_pose::Posture;
use frontline_core::infantry_vitals::Life;
use frontline_core::random::SimulationRandom;
use frontline_core::spatial::{SpatialIndex, UNIT_CELL};
use frontline_core::squad::Squad;
use frontline_core::structure::Structure;
use frontline_core::terrain::{Terrain, CRATER, TRENCH};
use frontline_core::vector::Vector3;

fn soldier(id: u32, position: Vector3) -> Infantry {
    let mut s = Infantry::default();
    s.identity.id = id;
    s.identity.squad = 9;
    s.identity.unit = "rifleman".into();
    s.identity.weapon = "rifle".into();
    s.motion.position = position;
    s
}
fn actors(soldiers: Vec<Infantry>) -> (Actors, SpatialIndex) {
    let a = Actors::from_entries(
        100,
        soldiers
            .into_iter()
            .map(|s| Actor::Soldier(Box::new(s)))
            .collect(),
    )
    .unwrap();
    let mut units = SpatialIndex::new(UNIT_CELL).unwrap();
    a.rebuild_units(&mut units).unwrap();
    (a, units)
}
fn blast(damage: f64, fling: f64) -> Blast {
    Blast {
        position: Vector3::ZERO,
        damage,
        radius: 5.0,
        fling,
        in_trench: false,
    }
}

#[test]
fn an_earlier_carrier_can_release_a_patient_before_their_fling() {
    let mut carrier = soldier(1, Vector3::new(0.2, 0.0, 0.0));
    carrier.duty.kind = Task::Stretcher;
    carrier.duty.entity = 2;
    let mut patient = soldier(2, Vector3::new(0.3, 0.0, 0.0));
    patient.vitals.life = Life::Downed;
    patient.links.carried_by = vec![1];
    let (mut a, units) = actors(vec![carrier, patient]);
    let out = a
        .blast_infantry(
            blast(0.0, 8.0),
            0,
            10.0,
            None,
            &Terrain::blank(32).unwrap(),
            &units,
            &mut CollisionWorld::default(),
            &mut [],
            |_| (None, false),
            &mut SimulationRandom::new(7),
        )
        .unwrap();
    assert_eq!(
        out.iter().map(|v| (v.soldier, v.flung)).collect::<Vec<_>>(),
        [(1, true), (2, true)]
    );
    assert!(a.soldier(2).unwrap().links.carried_by.is_empty());
    assert_eq!(a.soldier(1).unwrap().duty.kind, Task::Fight);
    assert_eq!(a.soldier(1).unwrap().vitals.suppression, 0.0);
}

#[test]
fn damage_runs_before_fling_and_squad_claims_are_released() {
    for damage in [0.0, 1000.0] {
        let mut s = soldier(1, Vector3::new(0.2, 0.0, 0.0));
        s.duty.kind = Task::Breach;
        s.orders.pending_path = true;
        let (mut a, units) = actors(vec![s]);
        let mut q = [Squad {
            id: 9,
            members: vec![1],
            breach_by: 1,
            ..Default::default()
        }];
        let out = a
            .blast_infantry(
                blast(damage, 8.0),
                0,
                10.0,
                None,
                &Terrain::blank(32).unwrap(),
                &units,
                &mut CollisionWorld::default(),
                &mut q,
                |_| (Some(120), false),
                &mut SimulationRandom::new(7),
            )
            .unwrap();
        assert!(out[0].flung);
        assert_eq!(q[0].breach_by, 0);
        assert_eq!(a.soldier(1).unwrap().activity, 17);
        assert!(!a.soldier(1).unwrap().orders.pending_path);
        assert_eq!(
            a.soldier(1).unwrap().vitals.life,
            if damage == 0.0 {
                Life::Alive
            } else {
                Life::Dead
            }
        );
    }
}

#[test]
fn terrain_shelter_and_wall_material_reduce_damage_and_stop_fling() {
    let mut amounts = vec![];
    for mode in 0..5 {
        let position = Vector3::new(2.0, 0.0, 0.0);
        let (mut a, units) = actors(vec![soldier(1, position)]);
        let mut terrain = Terrain::blank(32).unwrap();
        let cell = terrain.index(position);
        if mode == 1 {
            terrain.layers[CRATER][cell] = 1;
        }
        if mode == 2 {
            terrain.layers[TRENCH][cell] = 1;
        }
        let mut collision = CollisionWorld::default();
        if mode >= 3 {
            let id = a
                .spawn(Actor::Structure(Box::new(Structure {
                    kind: if mode == 3 { "medic_tent" } else { "fob" }.into(),
                    ..Default::default()
                })))
                .unwrap();
            collision.replace(
                id.into(),
                &[BoxShape {
                    body: id.into(),
                    shape: 0,
                    center: Vector3::new(1.0, 1.0, 0.0),
                    half: Vector3::new(0.1, 2.0, 2.0),
                    basis: Mat3::IDENTITY,
                }],
            );
        }
        let out = a
            .blast_infantry(
                blast(40.0, 8.0),
                0,
                10.0,
                None,
                &terrain,
                &units,
                &mut collision,
                &mut [],
                |_| (None, false),
                &mut SimulationRandom::new(7),
            )
            .unwrap();
        amounts.push(100.0 - a.soldier(1).unwrap().vitals.hp);
        assert_eq!(out[0].flung, mode < 2);
    }
    assert!((amounts[1] / amounts[0] - 0.6).abs() < 1e-12);
    assert_eq!(amounts[2], 0.0); // Sheltered damage below three does not injure him.
    assert!((amounts[3] / amounts[0] - 0.8).abs() < 1e-12);
    assert!((amounts[4] / amounts[0] - 0.2).abs() < 1e-12);
}

#[test]
fn hidden_men_are_ignored_and_near_misses_flinch_only_available_survivors() {
    let mut men = vec![];
    for id in 1..=6 {
        let mut s = soldier(id, Vector3::new(6.0, 0.0, 0.0));
        match id {
            2 => s.vitals.life = Life::Hidden,
            3 => s.vitals.life = Life::Dead,
            4 => s.shock.dazed_timer = 1.0,
            5 => s.duty.kind = Task::Stretcher,
            6 => s.shock.flinging = true,
            _ => (),
        }
        men.push(s);
    }
    let (mut a, units) = actors(men);
    let mut rng = SimulationRandom::new(7);
    let cursor = rng.state();
    let out = a
        .blast_infantry(
            blast(1000.0, 8.0),
            0,
            10.0,
            None,
            &Terrain::blank(32).unwrap(),
            &units,
            &mut CollisionWorld::default(),
            &mut [],
            |_| (None, false),
            &mut rng,
        )
        .unwrap();
    assert!(out.iter().all(|v| v.hit.is_none() && !v.flung));
    assert!(!out.iter().any(|v| v.soldier == 2));
    assert_eq!(a.soldier(1).unwrap().activity, 19);
    assert!(a.soldier(5).unwrap().vitals.suppression > 0.0);
    assert_eq!(a.soldier(5).unwrap().shock.flinch_timer, 0.0);
    for id in [2, 3, 4, 6] {
        assert_eq!(a.soldier(id).unwrap().vitals.suppression, 0.0);
    }
    assert_eq!(rng.state(), cursor);
}

#[test]
fn absent_throwers_preserve_credit_and_resumed_blasts_match_exactly() {
    let mut s = soldier(1, Vector3::new(0.0, 0.0, 0.0));
    s.posture = Posture::Prone;
    let (mut a, units) = actors(vec![s]);
    let mut resumed = Actors::restore(&a.checkpoint().unwrap()).unwrap();
    let mut rng = SimulationRandom::new(17);
    let mut other = rng;
    let credit = Credit {
        owner: 7,
        team: 1,
        unit: "s10".into(),
        soldier: 4,
    };
    for step in 0..8 {
        let run = |a: &mut Actors, rng: &mut SimulationRandom| {
            a.blast_infantry(
                blast(20.0, 0.0),
                99,
                10.0 + step as f64,
                Some(&credit),
                &Terrain::blank(32).unwrap(),
                &units,
                &mut CollisionWorld::default(),
                &mut [],
                |_| (Some(120), false),
                rng,
            )
            .unwrap()
        };
        assert_eq!(run(&mut a, &mut rng), run(&mut resumed, &mut other));
        assert_eq!(a.checkpoint().unwrap(), resumed.checkpoint().unwrap());
        assert_eq!(rng.state(), other.state());
        resumed = Actors::restore(&resumed.checkpoint().unwrap()).unwrap();
    }
    assert_eq!(a.soldier(1).unwrap().identity.hit_by, Some(credit));
}

#[test]
fn invalid_blast_geometry_does_not_touch_state_or_randomness() {
    let (mut a, units) = actors(vec![soldier(1, Vector3::ZERO)]);
    let before = a.checkpoint().unwrap();
    let mut rng = SimulationRandom::new(7);
    let cursor = rng.state();
    for damage in [f64::NAN, -1.0, f64::INFINITY] {
        assert!(a
            .blast_infantry(
                blast(damage, 8.0),
                0,
                10.0,
                None,
                &Terrain::blank(32).unwrap(),
                &units,
                &mut CollisionWorld::default(),
                &mut [],
                |_| (None, false),
                &mut rng
            )
            .is_err());
    }
    assert_eq!(a.checkpoint().unwrap(), before);
    assert_eq!(rng.state(), cursor);
}
