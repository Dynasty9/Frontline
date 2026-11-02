#[allow(dead_code)]
#[path = "vehicle_world.rs"]
pub mod fixture;
pub use fixture::{armor, defense, infantry, vehicle, Field};
use frontline_core::actors::Actor;
use frontline_core::attack_plan::AttackPlan;
use frontline_core::boat_navigation::{BoatNavigation, LEVEL};
use frontline_core::boat_world::Profile;
use frontline_core::infantry_vitals::Life;
use frontline_core::vector::Vector3;
use frontline_core::vehicle_boat::BoatProfile;
use frontline_core::vehicle_world::Event;

pub fn profile() -> Profile<'static> {
    let ground = fixture::ground();
    let mut weapons = ground.weapons;
    weapons.cycle.base = "boat";
    Profile {
        movement: BoatProfile {
            hull: Vector3::new(3.0, 2.0, 5.0),
            speed: 12.0,
            response: [2.5, 2.6, 0.45, 0.65, 0.6, 4.2, 0.85, 0.28, 0.45],
            cannon: true,
        },
        scan: ground.scan,
        weapons,
        traverse: ground.traverse,
    }
}
pub fn field(trial: usize) -> Field {
    let mut v = vehicle(20, 0, 8.0);
    v.kind = "boat".into();
    v.position.y = LEVEL;
    v.path = vec![Vector3::new(0.0, 0.0, -12.0)];
    v.speed = 3.0;
    v.target = 1;
    v.aim_target = 1;
    let mut s = infantry(Life::Alive);
    match trial {
        1 => {
            v.path.clear();
            v.landing = true;
            v.speed = 0.0;
            v.passengers = vec![1];
            if let Actor::Soldier(s) = &mut s {
                s.identity.team = 0;
                s.links.vehicle = 20;
                s.vitals.life = Life::Hidden;
                s.control.hidden = frontline_core::infantry_control::HiddenReason::Vehicle;
            }
        }
        2 => {
            v.stuck_timer = 4.1;
            v.stuck_position = v.position;
        }
        3 => {
            v.position.z = 0.01;
            v.speed = 8.0;
        }
        _ => {}
    }
    Field::new(v, s)
}
pub fn navigation(bank: bool) -> BoatNavigation {
    let solid = (0..256)
        .map(|i| u8::from(bank && i / 16 < 8))
        .collect::<Vec<_>>();
    BoatNavigation::new(16, &solid, &[1.0; 256]).unwrap()
}
pub fn step(
    w: &mut Field,
    nav: &mut BoatNavigation,
    p: Profile<'_>,
    plans: &mut Vec<AttackPlan>,
    next: &mut u64,
) -> Result<Vec<Event>, &'static str> {
    w.scene.context().advance_boat(
        20,
        0.1,
        p,
        nav,
        None,
        &mut w.gunfire,
        &mut w.network,
        &mut w.impacts,
        plans,
        next,
        &armor,
        &|_| 2.0,
        &defense,
    )
}
pub fn transcript() -> Vec<u8> {
    fn block(out: &mut Vec<u8>, bytes: &[u8]) {
        out.extend_from_slice(&(bytes.len() as u32).to_le_bytes());
        out.extend_from_slice(bytes);
    }
    let mut out = vec![];
    for trial in 0..4 {
        let mut a = field(trial);
        let mut nav = navigation(trial == 3);
        let mut plans = vec![];
        let mut next = 17;
        let mut previous = vec![vec![]; 13];
        for tick in 0..8 {
            a.scene.world.now += 0.1;
            let mut b = a.resume();
            let mut bn = BoatNavigation::restore(&nav.checkpoint()).unwrap();
            let mut bp: Vec<_> = plans
                .iter()
                .map(|p: &AttackPlan| AttackPlan::restore(&p.checkpoint().unwrap()).unwrap())
                .collect();
            let mut bnext = next;
            let events = step(&mut a, &mut nav, profile(), &mut plans, &mut next).unwrap();
            assert_eq!(
                events,
                step(&mut b, &mut bn, profile(), &mut bp, &mut bnext).unwrap()
            );
            a.compare(&b);
            assert_eq!(nav.checkpoint(), bn.checkpoint());
            assert_eq!(plans, bp);
            assert_eq!(next, bnext);
            block(&mut out, format!("{trial}/{tick} {events:?}").as_bytes());
            let mut squads = vec![];
            for q in &a.scene.world.squads {
                block(&mut squads, &q.checkpoint().unwrap());
            }
            let mut pp = vec![];
            for p in &plans {
                block(&mut pp, &p.checkpoint().unwrap());
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
                pp,
                nav.checkpoint(),
                format!("{:?}", a.impacts).into_bytes(),
            ];
            for (last, state) in previous.iter_mut().zip(states) {
                fixture::squad_fixture::checkpoint_delta(&mut out, last, state);
            }
            out.extend_from_slice(&a.scene.world.rng.state().to_le_bytes());
            out.extend_from_slice(&a.scene.next.to_le_bytes());
            out.extend_from_slice(&next.to_le_bytes());
        }
    }
    out
}
