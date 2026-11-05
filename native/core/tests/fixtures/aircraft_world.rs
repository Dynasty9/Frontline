#[allow(dead_code)]
#[path = "vehicle_world.rs"]
pub mod fixture;
pub use fixture::{armor, defense, infantry, profile, vehicle, Field};
use frontline_core::actors::Actor;
use frontline_core::aircraft_world::{Kind, Profile};
use frontline_core::infantry_vitals::Life;
use frontline_core::vector::Vector3;
use frontline_core::vehicle_flight::FlightProfile;
use frontline_core::vehicle_scan::ScanProfile;
use frontline_core::vehicle_world::Event;

pub fn air(kind: Kind) -> Profile<'static> {
    let mut weapons = profile(false);
    weapons.cycle.base = match kind {
        Kind::Gunship { .. } => "attack_heli",
        Kind::Uav { .. } => "uav",
        _ => "lift_heli",
    };
    Profile {
        kind,
        flight: FlightProfile {
            speed: 22.0,
            accel: 5.0,
            brake: 6.0,
            turn: 0.7,
            turn_accel: 0.95,
        },
        scan: ScanProfile {
            sight: 100.0,
            gun_height: 2.2,
            cannon: false,
            gunship: matches!(kind, Kind::Gunship { .. }),
            anti_air: false,
            penetrating_mg: false,
        },
        weapons,
        traverse: [1.0, 2.0],
    }
}
pub fn heli() -> frontline_core::vehicle::Vehicle {
    let mut v = vehicle(20, 0, 0.0);
    v.kind = "heli".into();
    v.position.y = 0.15;
    v.flight = Some([0.0; 3]);
    v.scan_timer = 10.0;
    v
}
pub fn step(w: &mut Field, p: Profile<'_>, income: &mut [Vec<(f64, i32)>; 2]) -> Vec<Event> {
    w.scene
        .context()
        .advance_aircraft(
            20,
            0.1,
            p,
            &mut w.gunfire,
            &mut w.network,
            &mut w.impacts,
            &mut vec![],
            &mut 17,
            income,
            &armor,
            &|_| 2.0,
            &defense,
        )
        .unwrap()
}

pub fn transcript() -> Vec<u8> {
    fn block(out: &mut Vec<u8>, data: &[u8]) {
        out.extend_from_slice(&(data.len() as u32).to_le_bytes());
        out.extend_from_slice(data);
    }
    let mut out = vec![];
    for trial in 0..6 {
        let mut v = heli();
        let mut target = infantry(Life::Alive);
        let kind = match trial {
            0 => {
                v.position.y = 20.0;
                v.uav_destination = Some(Vector3::ZERO);
                Kind::Uav {
                    altitude: 20.0,
                    radius: 16.0,
                }
            }
            1 => {
                v.position.y = 14.0;
                v.target = 21;
                v.aim_target = 21;
                v.rocket_timer = 0.0;
                target = Actor::Vehicle(Box::new(vehicle(21, 1, -30.0)));
                Kind::Gunship { rockets: 4 }
            }
            2 => {
                v.lift_phase = 3;
                v.lift_destination = Some(Vector3::ZERO);
                v.passengers = vec![1];
                if let Actor::Soldier(s) = &mut target {
                    s.identity.team = 0;
                    s.vitals.life = Life::Hidden;
                    s.links.vehicle = 20;
                    s.control.hidden = frontline_core::infantry_control::HiddenReason::Vehicle;
                }
                Kind::Lift { capacity: 2 }
            }
            3 => {
                v.heli_phase = 7;
                v.heli_timer = 0.05;
                v.heli_destination = 30;
                v.flight_hold = Some(v.position);
                let mut fob = fixture::shared::structure(30, "fob", 0.0);
                fob.team = 0;
                fob.supply = 42.0;
                target = Actor::Structure(Box::new(fob));
                Kind::Supply { load: 80 }
            }
            4 => {
                v.position.y = 9.0;
                v.sling_target = 21;
                v.lift_phase = 6;
                v.sling_timer = 1.6;
                target = Actor::Vehicle(Box::new(vehicle(21, 0, 0.0)));
                Kind::Lift { capacity: 2 }
            }
            _ => {
                v.position.y = 9.15;
                v.sling_cargo = 21;
                v.lift_phase = 3;
                v.lift_destination = Some(Vector3::ZERO);
                v.sling_timer = 1.3;
                let mut cargo = vehicle(21, 0, 0.0);
                cargo.slung_by = 20;
                target = Actor::Vehicle(Box::new(cargo));
                Kind::Lift { capacity: 2 }
            }
        };
        let mut a = Field::new(v, target);
        let mut income = [vec![], vec![]];
        let mut previous = vec![vec![]; 11];
        let p = air(kind);
        for tick in 0..8 {
            a.scene.world.now += 0.1;
            let mut b = a.resume();
            let mut bi = income.clone();
            let events = step(&mut a, p, &mut income);
            assert_eq!(events, step(&mut b, p, &mut bi));
            a.compare(&b);
            assert_eq!(income, bi);
            block(
                &mut out,
                format!("{trial}/{tick} {events:?} {income:?}").as_bytes(),
            );
            let mut squads = vec![];
            for q in &a.scene.world.squads {
                block(&mut squads, &q.checkpoint().unwrap());
            }
            let states = [
                a.scene.world.actors.checkpoint().unwrap(),
                a.scene.world.geometry.checkpoint(),
                a.scene.world.units.checkpoint(),
                a.scene.world.battle.checkpoint(),
                a.scene.world.deferred.checkpoint(),
                a.scene.world.visibility.checkpoint(),
                a.scene.fires.checkpoint(),
                a.gunfire.checkpoint(),
                a.network.checkpoint().unwrap(),
                squads,
                format!("{:?}", a.impacts).into_bytes(),
            ];
            for (last, state) in previous.iter_mut().zip(states) {
                fixture::squad_fixture::checkpoint_delta(&mut out, last, state);
            }
            out.extend_from_slice(&a.scene.world.rng.state().to_le_bytes());
            out.extend_from_slice(&a.scene.next.to_le_bytes());
        }
    }
    out
}
