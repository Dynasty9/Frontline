#[allow(dead_code)]
#[path = "squad_movement_world.rs"]
mod movement;
use frontline_core::actors::{Actor, Actors};
use frontline_core::drone::DroneFlight;
use frontline_core::drone_actor::Drone;
use frontline_core::fog::{self, Fog, VehicleProfile};
use frontline_core::infantry::Infantry;
use frontline_core::infantry_vitals::Life;
use frontline_core::navigation_scene::NavigationScene;
use frontline_core::projectile_actor::{Motion, Projectile};
use frontline_core::structure::Structure;
use frontline_core::support::{Kind, SupportFlight};
use frontline_core::terrain::{Terrain, NETTED};
use frontline_core::vector::Vector3;
use frontline_core::vehicle::Vehicle;
fn profile(v: &Vehicle) -> VehicleProfile {
    VehicleProfile {
        sight: if v.id % 2 == 0 { 91.7 } else { 50. },
        helicopter: v.id % 2 == 0,
        automatic: v.id % 3 == 0,
        cannon: v.id % 3 != 0,
    }
}
pub fn transcript() -> Vec<u8> {
    let mut out = vec![];
    let mut previous: [Vec<u8>; 3] = std::array::from_fn(|_| vec![]);
    for trial in 0..16 {
        let mut entries = vec![];
        let mut terrain = Terrain::blank(256).unwrap();
        for id in 1..=24 {
            let mut s = Infantry::default();
            s.identity.id = id;
            s.identity.team = ((id + trial) % 3) as i8 - 1;
            s.identity.unit = if id % 9 == 0 { "mg_gunner" } else { "rifleman" }.into();
            s.vitals.life = [
                Life::Alive,
                Life::Downed,
                Life::Dead,
                Life::Hidden,
                Life::Surrender,
                Life::Captive,
            ][(id + trial) as usize % 6];
            s.motion.position = Vector3::new(
                (id % 6) as f32 * 39.7 - 98.1,
                0.,
                (id / 6) as f32 * 51.3 - 87.7,
            );
            if id % 3 == 0 {
                let i = terrain.index(s.motion.position);
                terrain.layers[NETTED][i] = 1;
            }
            entries.push(Actor::Soldier(Box::new(s)));
        }
        for id in 30..34 {
            entries.push(Actor::Vehicle(Box::new(Vehicle {
                id,
                team: (id % 2) as i8,
                position: Vector3::new(
                    (id - 30) as f32 * 57.1 - 83.,
                    if trial % 2 == 0 { 3.0 } else { 3.01 },
                    53.1,
                ),
                ..Default::default()
            })));
        }
        for (i, kind) in [
            "watchtower",
            "fob",
            "town",
            "mg_nest",
            "mines",
            "concrete_wall",
        ]
        .into_iter()
        .enumerate()
        {
            entries.push(Actor::Structure(Box::new(Structure {
                id: 40 + i as u32,
                kind: kind.into(),
                team: (i % 2) as i8,
                built: trial % 3 != 0,
                manned: trial % 2 == 0,
                position: Vector3::new(i as f32 * 37.1 - 95., 0., -73.),
                zone_center: Some(Vector3::new(11., 0., 17.)),
                zone_radius: 37.3,
                seen: (trial % 4) as u8,
                ..Default::default()
            })));
        }
        for id in 50..52 {
            entries.push(Actor::Drone(Drone {
                id,
                team: (id % 2) as i8,
                operator: 0,
                target: 0,
                operator_at_spawn: 0,
                target_at_spawn: 0,
                warhead: 1.,
                flight: DroneFlight::new(Vector3::new((id - 50) as f32 * 120. - 60., 12., 87.), 0.),
            }));
        }
        let mut flight = SupportFlight::new(
            [Kind::Jet, Kind::GunRun, Kind::Orbit][trial as usize % 3],
            Vector3::new(if trial % 2 == 0 { 167.99 } else { 168. }, 50., -21.),
            Vector3::X,
            Vector3::new(-81., 0., 83.),
        );
        flight.life = [1.99, 2., 2.001, 26.][trial as usize % 4];
        flight.sight = if trial % 2 == 0 { 110.7 } else { 0. };
        entries.push(Actor::Projectile(Projectile {
            id: 60,
            team: 0,
            thrower: 0,
            called_by: 0,
            held_by: 0,
            smothered_by: 0,
            handler: 0,
            thrown_back: 0,
            target_id: 0,
            motion: Motion::Support(flight),
        }));
        let mut a = Actors::from_entries(1000, entries).unwrap();
        let mut nav = NavigationScene::new(&terrain, &[], 16).unwrap();
        assert!(nav.finalize(1));
        let mut f = Fog::default();
        for t in 0..2 {
            f.marks[t] = vec![
                [83., -76., 32.7, 100.],
                [-83., 79., 41.1, 100.5],
                [31.7, 21.3, 17.1, 99.9],
            ];
        }
        for now in [100., 100.2, 100.5, 104.] {
            let mut r = Actors::restore(&a.checkpoint().unwrap()).unwrap();
            let mut rf = Fog::restore(&f.checkpoint().unwrap()).unwrap();
            let mut rn = NavigationScene::restore(&nav.checkpoint()).unwrap();
            let changed = f.update(&mut a, &terrain, now, &profile).unwrap();
            assert_eq!(changed, rf.update(&mut r, &terrain, now, &profile).unwrap());
            assert_eq!(
                fog::update_danger(&a, &mut nav, &profile).unwrap(),
                fog::update_danger(&r, &mut rn, &profile).unwrap()
            );
            let bytes = [
                a.checkpoint().unwrap(),
                f.checkpoint().unwrap(),
                nav.checkpoint(),
            ];
            assert_eq!(
                bytes,
                [
                    r.checkpoint().unwrap(),
                    rf.checkpoint().unwrap(),
                    rn.checkpoint()
                ]
            );
            for (before, after) in previous.iter_mut().zip(bytes) {
                movement::checkpoint_delta(&mut out, before, after);
            }
            out.extend_from_slice(&(changed.len() as u32).to_le_bytes());
            for id in changed {
                out.extend_from_slice(&id.to_le_bytes());
            }
            a = r;
            f = rf;
            nav = rn;
        }
    }
    out
}
