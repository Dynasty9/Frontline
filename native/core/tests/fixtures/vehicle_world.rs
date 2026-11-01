#[allow(dead_code)]
#[path = "vehicle_combat_world.rs"]
mod combat;
#[allow(dead_code)]
#[path = "vehicle_movement_world.rs"]
mod movement;
#[allow(unused_imports)]
pub use combat::shared;
pub use combat::{armor, defense, infantry, profile, vehicle, Field};
use frontline_core::attack_plan::AttackPlan;
use frontline_core::infantry_vitals::Life;
use frontline_core::vector::Vector3;
use frontline_core::vehicle_scan::ScanProfile;
use frontline_core::vehicle_service::{Service, SoldierSupply};
use frontline_core::vehicle_world::{Event, Ground};

pub fn ground() -> Ground<'static> {
    Ground {
        movement: movement::ground(),
        scan: ScanProfile {
            sight: 60.0,
            gun_height: 2.2,
            cannon: true,
            gunship: false,
            anti_air: false,
            penetrating_mg: false,
        },
        crew: defense(&vehicle(20, 0, 0.0)).crew,
        weapons: profile(true),
        traverse: [1.0, 2.0],
        artillery: None,
        service: None,
        light: false,
    }
}
pub fn step(
    w: &mut Field,
    p: Ground<'_>,
    plans: &mut Vec<AttackPlan>,
    next: &mut u64,
) -> Result<Vec<Event>, &'static str> {
    w.scene.context().advance_ground_vehicle(
        20,
        0.1,
        p,
        &mut w.gunfire,
        &mut w.network,
        &mut w.impacts,
        plans,
        next,
        false,
        &[],
        &armor,
        &|_| 2.0,
        &defense,
        &|_| true,
        &|_| {
            Ok(SoldierSupply {
                loadout: None,
                restored_weapon: None,
            })
        },
        &|_| Ok([0, 0]),
    )
}

#[allow(dead_code)]
#[path = "squad_movement_world.rs"]
pub mod squad_fixture;
pub fn transcript() -> Vec<u8> {
    fn block(out: &mut Vec<u8>, data: &[u8]) {
        out.extend_from_slice(&(data.len() as u32).to_le_bytes());
        out.extend_from_slice(data);
    }
    let mut out = vec![];
    for trial in 0..4 {
        let mut v = vehicle(20, 0, 10.0);
        v.path = vec![Vector3::new(4.0, 0.0, -14.0)];
        v.speed = 3.0;
        v.target = 1;
        v.aim_target = 1;
        v.knock_velocity = Vector3::X;
        let mut p = ground();
        if trial == 1 {
            p.service = Some(Service::Repair);
        }
        if trial == 2 {
            v.fire_queue = vec![Vector3::Z * -10.0];
            p.artillery = Some((
                frontline_core::vehicle_artillery::ArtilleryProfile {
                    shell: frontline_core::projectile::Kind::Grad,
                    gun_height: 2.2,
                    muzzle: 4.0,
                    scatter: 3.0,
                    salvo: 2,
                    lay: 0.1,
                    gap: 0.2,
                    cooldown: 18.0,
                    traverse: 1.0,
                    traverse_accel: 2.0,
                },
                [5.0, 230.0],
            ));
        }
        if trial == 3 {
            v.slung_by = 999;
            v.position.y = 9.0;
        }
        let mut a = Field::new(v, infantry(Life::Alive));
        let mut plans = vec![];
        let mut next = 17;
        let mut previous = vec![vec![]; 12];
        for tick in 0..8 {
            a.scene.world.now += 0.1;
            let mut b = a.resume();
            let mut bp: Vec<_> = plans
                .iter()
                .map(|p: &AttackPlan| AttackPlan::restore(&p.checkpoint().unwrap()).unwrap())
                .collect();
            let mut bn = next;
            let events = step(&mut a, p, &mut plans, &mut next).unwrap();
            assert_eq!(events, step(&mut b, p, &mut bp, &mut bn).unwrap());
            a.compare(&b);
            assert_eq!(plans, bp);
            assert_eq!(next, bn);
            block(&mut out, format!("{trial}/{tick} {events:?}").as_bytes());
            let mut squads = vec![];
            for q in &a.scene.world.squads {
                block(&mut squads, &q.checkpoint().unwrap());
            }
            let mut plan_bytes = vec![];
            for p in &plans {
                block(&mut plan_bytes, &p.checkpoint().unwrap());
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
                plan_bytes,
                format!("{:?}", a.impacts).into_bytes(),
            ];
            for (last, state) in previous.iter_mut().zip(states) {
                squad_fixture::checkpoint_delta(&mut out, last, state);
            }
            out.extend_from_slice(&a.scene.world.rng.state().to_le_bytes());
            out.extend_from_slice(&a.scene.next.to_le_bytes());
            out.extend_from_slice(&next.to_le_bytes());
        }
    }
    out
}
