use frontline_core::actors::{Actor, Actors};
use frontline_core::infantry::Infantry;
use frontline_core::infantry_supply::Loadout;
use frontline_core::infantry_vitals::Life;
use frontline_core::infantry_weapon::Weapon;
use frontline_core::random::SimulationRandom;
use frontline_core::spatial::{SpatialIndex, UNIT_CELL};
use frontline_core::vector::Vector3;
use frontline_core::vehicle::Vehicle;
use frontline_core::vehicle_service::{Service, ServiceEffect, SoldierSupply};

fn stock(_: &Infantry) -> Result<SoldierSupply<'static>, &'static str> {
    Ok(SoldierSupply {
        loadout: Some(Loadout {
            ammunition: 120,
            special: [2, 1, 2, 1, 6],
            reload_weapon: Weapon {
                ammunition: 120,
                magazine: 30,
                reload_time: 2.0,
            },
        }),
        restored_weapon: Some(("rifle", 30)),
    })
}
fn missiles(_: &Vehicle) -> Result<[i32; 2], &'static str> {
    Ok([6, 4])
}
fn soldier(id: u32, team: i8, life: Life) -> Infantry {
    let mut s = Infantry::default();
    s.identity.id = id;
    s.identity.team = team;
    s.identity.unit = "rifleman".into();
    s.identity.weapon = "rifle".into();
    s.vitals.life = life;
    s.vitals.hp = 40.0;
    s.motion.position = Vector3::new(id as f32 - 3.0, 0.0, -1.0);
    s.fight.out_of_ammo_said = true;
    s.weapon.low_ammo_said = true;
    s
}
fn actors() -> (Actors, SpatialIndex) {
    let actors = Actors::from_entries(
        8,
        vec![
            Actor::Vehicle(Box::new(Vehicle {
                id: 1,
                team: 0,
                ..Default::default()
            })),
            Actor::Soldier(Box::new(soldier(2, 0, Life::Alive))),
            Actor::Soldier(Box::new(soldier(3, 0, Life::Alive))),
            Actor::Soldier(Box::new(soldier(4, 1, Life::Alive))),
            Actor::Soldier(Box::new(soldier(5, 0, Life::Downed))),
            Actor::Vehicle(Box::new(Vehicle {
                id: 6,
                team: 0,
                hp: 40.0,
                track_broken: true,
                track_fix: 5.0,
                ..Default::default()
            })),
            Actor::Vehicle(Box::new(Vehicle {
                id: 7,
                team: 1,
                hp: 40.0,
                ..Default::default()
            })),
        ],
    )
    .unwrap();
    let mut units = SpatialIndex::new(UNIT_CELL).unwrap();
    actors.rebuild_units(&mut units).unwrap();
    (actors, units)
}

#[test]
fn stopped_support_refills_friendly_live_infantry_then_missiles() {
    let (mut a, units) = actors();
    let mut rng = SimulationRandom::new(137);
    a.service_vehicle(1, 0.1, Service::Ammo, &units, &mut rng, stock, missiles)
        .unwrap();
    for id in [2, 3] {
        let s = a.soldier(id).unwrap();
        assert_eq!(s.weapon.reserve, 61);
        assert_eq!(s.weapon.reload_timer, 2.0);
        assert!(!s.fight.out_of_ammo_said && !s.weapon.low_ammo_said);
    }
    for id in [4, 5] {
        assert_eq!(a.soldier(id).unwrap().weapon.reserve, 0);
    }
    assert_eq!(a.vehicle(6).unwrap().atgm_left, 6);
    assert_eq!(a.vehicle(6).unwrap().sam_left, 4);
    assert_eq!(a.vehicle(7).unwrap().atgm_left, 0);
    assert_eq!(a.vehicle(1).unwrap().atgm_left, 0);
    assert_eq!(a.vehicle(1).unwrap().service_timer, 1.0);
}

#[test]
fn moving_or_waiting_support_preserves_cadence_without_random_draws() {
    let (a, units) = actors();
    let mut entries: Vec<_> = a.iter().cloned().collect();
    let Actor::Vehicle(v) = &mut entries[0] else {
        panic!()
    };
    v.speed = 2.0;
    let mut a = Actors::from_entries(8, entries).unwrap();
    let mut rng = SimulationRandom::new(137);
    let before = rng.state();
    assert!(a
        .service_vehicle(
            1,
            0.1,
            Service::Ammo,
            &units,
            &mut rng,
            |_| panic!("must not read stock"),
            |_| panic!("must not read stock")
        )
        .unwrap()
        .is_empty());
    assert_eq!(a.vehicle(1).unwrap().service_timer, -0.1);
    assert_eq!(rng.state(), before);
    let (mut a, units) = actors();
    a.service_vehicle(1, 0.1, Service::Repair, &units, &mut rng, stock, missiles)
        .unwrap();
    let hp = a.vehicle(6).unwrap().hp;
    a.service_vehicle(1, 0.1, Service::Repair, &units, &mut rng, stock, missiles)
        .unwrap();
    assert_eq!(a.vehicle(6).unwrap().hp, hp);
    assert_eq!(a.vehicle(1).unwrap().service_timer, 0.9);
}

#[test]
fn repairs_update_other_friendly_vehicles_and_report_fixed_tracks() {
    let (mut a, units) = actors();
    let mut rng = SimulationRandom::new(137);
    let before = rng.state();
    let events = a
        .service_vehicle(1, 0.1, Service::Repair, &units, &mut rng, stock, missiles)
        .unwrap();
    assert_eq!(
        events,
        vec![ServiceEffect::Repaired {
            vehicle: 6,
            track: true
        }]
    );
    assert_eq!(a.vehicle(6).unwrap().hp, 43.5);
    assert!(!a.vehicle(6).unwrap().track_broken);
    assert_eq!(a.vehicle(7).unwrap().hp, 40.0);
    assert_eq!(rng.state(), before);
}

#[test]
fn medical_service_respects_carriers_and_restores_an_unarmed_casualty() {
    let (a, units) = actors();
    let mut entries: Vec<_> = a.iter().cloned().collect();
    let Actor::Soldier(s) = &mut entries[4] else {
        panic!()
    };
    s.identity.weapon.clear();
    let mut a = Actors::from_entries(8, entries).unwrap();
    let mut rng = SimulationRandom::new(137);
    let mut revived = false;
    for _ in 0..100 {
        let events = a
            .service_vehicle(1, 1.0, Service::Medical, &units, &mut rng, stock, missiles)
            .unwrap();
        if events
            .iter()
            .any(|e| matches!(e, ServiceEffect::Revived { soldier: 5, .. }))
        {
            revived = true;
            break;
        }
    }
    assert!(revived);
    let s = a.soldier(5).unwrap();
    assert_eq!(s.vitals.life, Life::Alive);
    assert_eq!(s.identity.weapon, "rifle");
    assert_eq!(s.weapon.magazine, 30);
    assert_eq!(a.soldier(4).unwrap().vitals.hp, 40.0);
    let (a, units) = actors();
    let mut entries: Vec<_> = a.iter().cloned().collect();
    let Actor::Soldier(s) = &mut entries[4] else {
        panic!()
    };
    s.links.carried_by = vec![2, 3];
    let mut a = Actors::from_entries(8, entries).unwrap();
    let before = rng.state();
    a.service_vehicle(1, 1.0, Service::Medical, &units, &mut rng, stock, missiles)
        .unwrap();
    assert_eq!(rng.state(), before);
    assert_eq!(a.soldier(5).unwrap().vitals.life, Life::Downed);
    assert_eq!(a.soldier(2).unwrap().vitals.hp, 45.0);
}

#[test]
fn missing_late_content_rolls_back_recipient_updates_and_randomness() {
    let (mut a, units) = actors();
    let mut rng = SimulationRandom::new(137);
    let state = a.checkpoint().unwrap();
    let before = rng.state();
    assert!(a
        .service_vehicle(1, 0.1, Service::Ammo, &units, &mut rng, stock, |_| Err(
            "missing missile load"
        ))
        .is_err());
    assert_eq!(a.checkpoint().unwrap(), state);
    assert_eq!(rng.state(), before);
    assert!(a
        .service_vehicle(
            1,
            f64::NAN,
            Service::Repair,
            &units,
            &mut rng,
            stock,
            missiles
        )
        .is_err());
    assert_eq!(a.checkpoint().unwrap(), state);
}

#[test]
fn checkpointed_support_preserves_recipient_order_speech_and_rng() {
    let (mut a, units) = actors();
    let mut rng = SimulationRandom::new(137);
    let mut b = Actors::restore(&a.checkpoint().unwrap()).unwrap();
    let mut other = rng.clone();
    for tick in 0..100 {
        let service = [Service::Repair, Service::Ammo, Service::Medical][tick % 3];
        assert_eq!(
            a.service_vehicle(1, 0.37, service, &units, &mut rng, stock, missiles)
                .unwrap(),
            b.service_vehicle(1, 0.37, service, &units, &mut other, stock, missiles)
                .unwrap()
        );
        assert_eq!(a.checkpoint().unwrap(), b.checkpoint().unwrap());
        assert_eq!(rng.state(), other.state());
        if tick % 11 == 0 {
            b = Actors::restore(&b.checkpoint().unwrap()).unwrap();
        }
    }
}
