#[allow(dead_code)]
#[path = "fixtures/aircraft_world.rs"]
mod fixture;
use fixture::{air, armor, defense, heli, infantry, step, vehicle, Field};
use frontline_core::actors::{Actor, Actors};
use frontline_core::aircraft_world::Kind;
use frontline_core::infantry_control::HiddenReason;
use frontline_core::infantry_vitals::Life;
use frontline_core::vector::Vector3;
use frontline_core::vehicle_world::Event;

fn change(w: &mut Field, f: impl FnOnce(&mut Vec<Actor>)) {
    let mut entries: Vec<_> = w.scene.world.actors.iter().cloned().collect();
    f(&mut entries);
    w.scene.world.actors =
        Actors::from_entries(w.scene.world.actors.entities().next_id(), entries).unwrap();
}
#[test]
fn landing_unloads_passengers_before_the_wait_for_return_flight() {
    let mut v = heli();
    v.lift_phase = 3;
    v.lift_destination = Some(Vector3::ZERO);
    v.passengers = vec![1];
    let mut s = infantry(Life::Hidden);
    if let Actor::Soldier(s) = &mut s {
        s.identity.team = 0;
        s.links.vehicle = 20;
        s.control.hidden = HiddenReason::Vehicle;
    }
    let mut a = Field::new(v, s);
    let mut b = a.resume();
    let p = air(Kind::Lift { capacity: 2 });
    assert_eq!(
        step(&mut a, p, &mut [vec![], vec![]]),
        step(&mut b, p, &mut [vec![], vec![]])
    );
    a.compare(&b);
    assert_eq!(a.scene.world.actors.vehicle(20).unwrap().lift_phase, 4);
    let s = a.scene.world.actors.soldier(1).unwrap();
    assert_eq!(s.vitals.life, Life::Alive);
    assert_eq!(s.links.vehicle, 0);
}
#[test]
fn sling_pickup_and_release_update_both_actors_and_shared_collision() {
    for release in [false, true] {
        let mut v = heli();
        let mut cargo = vehicle(21, 0, 0.0);
        if release {
            v.position.y = 9.15;
            v.sling_cargo = 21;
            cargo.slung_by = 20;
            v.lift_phase = 3;
            v.lift_destination = Some(Vector3::ZERO);
            v.sling_timer = 1.3;
        } else {
            v.position.y = 9.0;
            v.sling_target = 21;
            v.lift_phase = 6;
            v.sling_timer = 1.6;
        }
        let mut a = Field::new(v, Actor::Vehicle(Box::new(cargo)));
        let mut b = a.resume();
        let p = air(Kind::Lift { capacity: 2 });
        let events = step(&mut a, p, &mut [vec![], vec![]]);
        assert_eq!(events, step(&mut b, p, &mut [vec![], vec![]]));
        a.compare(&b);
        assert!(
            events.contains(&Event::Sling {
                helicopter: 20,
                cargo: 21,
                released: release
            }),
            "{events:?}"
        );
        assert_eq!(
            a.scene.world.actors.vehicle(21).unwrap().slung_by,
            if release { 0 } else { 20 }
        );
    }
}
#[test]
fn deliveries_update_supply_and_income_once_across_a_resume() {
    let mut v = heli();
    v.heli_phase = 7;
    v.heli_timer = 0.05;
    v.heli_destination = 30;
    v.flight_hold = Some(v.position);
    let mut fob = fixture::fixture::shared::structure(30, "fob", 0.0);
    fob.team = 0;
    fob.supply = 42.0;
    let mut a = Field::new(v, Actor::Structure(Box::new(fob)));
    let mut b = a.resume();
    let p = air(Kind::Supply { load: 80 });
    let mut income = [vec![], vec![]];
    let mut resumed = income.clone();
    assert_eq!(step(&mut a, p, &mut income), step(&mut b, p, &mut resumed));
    a.compare(&b);
    assert_eq!(income, resumed);
    assert_eq!(income[0], [(100.0, 80)]);
    assert_eq!(a.scene.world.actors.structure(30).unwrap().supply, 122.0);
    step(&mut a, p, &mut income);
    assert_eq!(income[0].len(), 1);
}
#[test]
fn gunship_salvos_preserve_rocket_warning_order_and_resume() {
    let mut v = heli();
    v.position.y = 14.0;
    v.target = 21;
    v.aim_target = 21;
    v.rocket_timer = 0.0;
    let mut a = Field::new(v, Actor::Vehicle(Box::new(vehicle(21, 1, -30.0))));
    let mut b = a.resume();
    let p = air(Kind::Gunship { rockets: 4 });
    let events = step(&mut a, p, &mut [vec![], vec![]]);
    assert_eq!(events, step(&mut b, p, &mut [vec![], vec![]]));
    a.compare(&b);
    let rockets=a.scene.world.actors.iter().filter(|a|matches!(a,Actor::Projectile(p) if matches!(&p.motion,frontline_core::projectile_actor::Motion::Ballistic(f) if f.kind==frontline_core::projectile::Kind::Rocket))).count();
    assert_eq!(rockets, 4, "{events:?}");
    assert_eq!(a.scene.world.actors.vehicle(20).unwrap().rocket_timer, 9.0);
}
#[test]
fn uav_orbits_and_shared_fire_resume_together() {
    let mut v = heli();
    v.position.y = 20.0;
    v.uav_destination = Some(Vector3::ZERO);
    v.target = 1;
    let mut a = Field::new(v, infantry(Life::Alive));
    let p = air(Kind::Uav {
        altitude: 20.0,
        radius: 16.0,
    });
    for _ in 0..12 {
        a.scene.world.now += 0.1;
        let mut b = a.resume();
        assert_eq!(
            step(&mut a, p, &mut [vec![], vec![]]),
            step(&mut b, p, &mut [vec![], vec![]])
        );
        a.compare(&b);
    }
    assert!(a.scene.world.actors.vehicle(20).unwrap().position.x > 0.0);
}
#[test]
fn invalid_flight_input_does_not_advance_shared_state() {
    let mut a = Field::new(heli(), infantry(Life::Alive));
    let mut p = air(Kind::Lift { capacity: 2 });
    p.flight.speed = f64::NAN;
    let before = a.resume();
    assert!(a
        .scene
        .context()
        .advance_aircraft(
            20,
            0.1,
            p,
            &mut a.gunfire,
            &mut a.network,
            &mut a.impacts,
            &mut vec![],
            &mut 17,
            &mut [vec![], vec![]],
            &armor,
            &|_| 2.0,
            &defense
        )
        .is_err());
    a.compare(&before);
    change(&mut a, |actors| {
        if let Actor::Vehicle(v) = &mut actors[0] {
            v.flight = None;
        }
    });
    let before = a.resume();
    assert!(a
        .scene
        .context()
        .advance_aircraft(
            20,
            0.1,
            air(Kind::Lift { capacity: 2 }),
            &mut a.gunfire,
            &mut a.network,
            &mut a.impacts,
            &mut vec![],
            &mut 17,
            &mut [vec![], vec![]],
            &armor,
            &|_| 2.0,
            &defense
        )
        .is_err());
    a.compare(&before);
}
