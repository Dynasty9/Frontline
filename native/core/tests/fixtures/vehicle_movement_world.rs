#[allow(dead_code)]
#[path = "vehicle_combat_world.rs"]
mod combat;
pub use combat::{infantry, shared, vehicle, Field};
use frontline_core::actors::Actor;
use frontline_core::infantry_vitals::Life;
use frontline_core::squad::Squad;
use frontline_core::vector::Vector3;
use frontline_core::vehicle_brain::CrewProfile;
use frontline_core::vehicle_motion::GroundProfile;
use frontline_core::vehicle_movement_world::Event;
use frontline_core::vehicle_scan::ScanProfile;
pub fn ground() -> GroundProfile {
    GroundProfile {
        hull: Vector3::new(3.0, 2.0, 5.0),
        tracked: true,
        weight: 2,
        supply: false,
        tank: true,
        cannon: true,
        speed: 8.0,
        turn: 1.0,
        turn_accel: 2.0,
        handling: [2.0, 4.0, 3.0, 0.5],
    }
}

pub fn transcript() -> Vec<u8> {
    fn block(out: &mut Vec<u8>, bytes: &[u8]) {
        out.extend_from_slice(&(bytes.len() as u32).to_le_bytes());
        out.extend_from_slice(bytes);
    }
    fn step(field: &mut Field, trial: usize) -> Vec<Event> {
        let mut out = vec![];
        if trial == 0 {
            field
                .scene
                .context()
                .scan_vehicle_world(
                    20,
                    ScanProfile {
                        sight: 60.0,
                        gun_height: 2.2,
                        cannon: true,
                        gunship: false,
                        anti_air: false,
                        penetrating_mg: false,
                    },
                )
                .unwrap();
        } else if trial == 1 {
            out.extend(
                field
                    .scene
                    .context()
                    .think_vehicle_world(
                        20,
                        CrewProfile {
                            base: "tank",
                            helicopter: false,
                            automatic: false,
                            artillery: false,
                            tracked: true,
                            armor: 2,
                        },
                        false,
                        &|_| true,
                    )
                    .unwrap(),
            );
        } else {
            out.extend(
                field
                    .scene
                    .context()
                    .smash_vehicle_world(20, false, 2)
                    .unwrap(),
            );
        }
        out.extend(
            field
                .scene
                .context()
                .drive_vehicle_world(20, 0.1, ground())
                .unwrap(),
        );
        out
    }
    let mut out = vec![];
    for trial in 0..3 {
        let mut v = vehicle(20, 0, 2.0);
        v.path = vec![Vector3::Z * -10.0];
        v.speed = 3.0;
        let target = if trial == 0 {
            let mut s = infantry(Life::Alive);
            if let Actor::Soldier(s) = &mut s {
                s.motion.position = Vector3::new(0.4, 0.0, 0.0);
                s.identity.squad = 2;
            }
            s
        } else {
            let mut st = shared::structure(
                30,
                if trial == 1 { "fob" } else { "tree" },
                if trial == 1 { 14.0 } else { 0.0 },
            );
            if trial == 1 {
                v.hp = 20.0;
                v.max_hp = 100.0;
                v.position.x = -14.0;
                st.team = 0;
            } else {
                st.team = -1;
                st.smashable = true;
            }
            Actor::Structure(Box::new(st))
        };
        let mut field = Field::new(v, target);
        if trial == 0 {
            field.scene.world.squads.push(Squad {
                id: 2,
                team: 1,
                owner: 8,
                members: vec![1],
                ..Default::default()
            });
        }
        for _ in 0..8 {
            field.scene.world.now += 0.1;
            let mut resumed = field.resume();
            let events = step(&mut field, trial);
            assert_eq!(events, step(&mut resumed, trial));
            field.compare(&resumed);
            block(&mut out, format!("{events:?}").as_bytes());
            block(&mut out, &field.scene.world.actors.checkpoint().unwrap());
            for q in &field.scene.world.squads {
                block(&mut out, &q.checkpoint().unwrap());
            }
            block(&mut out, &field.scene.world.geometry.checkpoint());
            block(&mut out, &field.scene.world.units.checkpoint());
            block(&mut out, &field.scene.world.battle.checkpoint());
            block(&mut out, &field.scene.world.deferred.checkpoint());
            block(&mut out, &field.scene.world.visibility.checkpoint());
            block(&mut out, &field.scene.fires.checkpoint());
            out.extend_from_slice(&field.scene.world.rng.state().to_le_bytes());
            out.extend_from_slice(&field.scene.next.to_le_bytes());
        }
    }
    out
}
