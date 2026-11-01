#[allow(dead_code)]
#[path = "fixtures/vehicle_world.rs"]
mod fixture;
use fixture::{ground, infantry, step, vehicle, Field};
use frontline_core::actors::Actor;
use frontline_core::infantry_vitals::Life;
use frontline_core::vector::Vector3;
use frontline_core::vehicle_service::Service;
use frontline_core::vehicle_world::Event;
#[test]
fn a_complete_ground_update_resumes_movement_scanning_and_combat() {
    let mut v = vehicle(20, 0, 10.0);
    v.path = vec![Vector3::new(5.0, 0.0, -14.0)];
    v.speed = 3.0;
    v.knock_velocity = Vector3::X;
    let mut a = Field::new(v, infantry(Life::Alive));
    let mut plans = vec![];
    let mut next = 17;
    for _ in 0..16 {
        a.scene.world.now += 0.1;
        let mut b = a.resume();
        let mut bp = plans.clone();
        let mut bn = next;
        assert_eq!(
            step(&mut a, ground(), &mut plans, &mut next).unwrap(),
            step(&mut b, ground(), &mut bp, &mut bn).unwrap()
        );
        a.compare(&b);
        assert_eq!(plans, bp);
        assert_eq!(next, bn);
    }
    let v = a.scene.world.actors.vehicle(20).unwrap();
    assert!(v.position.z < 10.0);
    assert_eq!(v.knock_velocity, Vector3::ZERO);
    assert!(v.scan_timer > 0.0);
    assert!(v.smash_timer > 0.0);
}
#[test]
fn invalid_weapon_content_is_rejected_before_timers_or_movement_change() {
    let mut a = Field::new(vehicle(20, 0, 10.0), infantry(Life::Alive));
    let before = a.resume();
    let mut p = ground();
    p.weapons.muzzle.gun_height = f64::NAN;
    assert!(step(&mut a, p, &mut vec![], &mut 17).is_err());
    a.compare(&before);
    let mut p = ground();
    p.weapons.machine_gun.as_mut().unwrap().suppression = -1.0;
    assert!(step(&mut a, p, &mut vec![], &mut 17).is_err());
    a.compare(&before);
}
#[test]
fn slung_cargo_waits_without_advancing_weapon_clocks_and_drops_if_orphaned() {
    let mut v = vehicle(20, 0, 0.0);
    v.slung_by = 21;
    v.position.y = 2.0;
    let mut carrier = vehicle(21, 0, 0.0);
    carrier.sling_cargo = 20;
    let mut a = Field::new(v, Actor::Vehicle(Box::new(carrier)));
    let before = a.resume();
    assert!(step(&mut a, ground(), &mut vec![], &mut 17)
        .unwrap()
        .is_empty());
    a.compare(&before);
    let mut entries: Vec<_> = a.scene.world.actors.iter().cloned().collect();
    if let Actor::Vehicle(v) = &mut entries[1] {
        v.sling_cargo = 0;
    }
    a.scene.world.actors = frontline_core::actors::Actors::from_entries(
        a.scene.world.actors.entities().next_id(),
        entries,
    )
    .unwrap();
    let out = step(&mut a, ground(), &mut vec![], &mut 17).unwrap();
    assert!(out.iter().any(|e| matches!(
        e,
        Event::Loss(frontline_core::vehicle_loss_world::Event::SlingDropped { id: 20, .. })
    )));
    assert_eq!(a.scene.world.actors.vehicle(20).unwrap().slung_by, 0);
}
#[test]
fn a_vehicle_destroyed_by_its_own_blast_stops_before_service() {
    let mut v = vehicle(20, 0, 2.0);
    v.hp = 0.01;
    v.target = 21;
    v.aim_target = 21;
    v.scan_timer = 10.0;
    let mut target = vehicle(21, 1, -2.0);
    target.hp = 100.0;
    let mut a = Field::new(v, Actor::Vehicle(Box::new(target)));
    let mut p = ground();
    p.service = Some(Service::Repair);
    p.weapons.cannon.as_mut().unwrap().radius = 20.0;
    p.weapons.cannon.as_mut().unwrap().damage = 10000.0;
    let out = step(&mut a, p, &mut vec![], &mut 17).unwrap();
    assert!(a.scene.world.actors.vehicle(20).is_none(), "{out:?}");
    assert!(!out.iter().any(|e| matches!(
        e,
        Event::Combat(frontline_core::vehicle_combat_world::Event::Service(_))
    )));
}
