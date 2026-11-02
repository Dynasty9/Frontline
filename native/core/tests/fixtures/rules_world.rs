#[allow(dead_code)]
#[path = "vehicle_loss_world.rs"]
mod fixture;
use fixture::shared::{actor, soldier, structure};
use frontline_core::actors::Actor;
use frontline_core::command_ownership::Ownership;
use frontline_core::fog::VehicleProfile;
use frontline_core::infantry_control::HiddenReason;
use frontline_core::infantry_spawn::Loadout;
use frontline_core::infantry_vitals::Life;
use frontline_core::projectile::Kind;
use frontline_core::rules_logistics::TruckProfile;
use frontline_core::rules_world::{Event, PrisonerProfile, Profiles, Rules};
use frontline_core::squad_birth::Definition;
use frontline_core::structure_world::Victory;
use frontline_core::support_calls::Salvo;
use frontline_core::vector::Vector3;
use frontline_core::vehicle_birth;
fn run(
    s: &mut fixture::Scene,
    r: &mut Rules,
    v: &mut Victory,
    dt: f64,
    scenario: bool,
) -> Vec<Event> {
    let members = vec![
        Loadout {
            unit: "rifleman".into(),
            weapon: "rifle".into(),
            hp: 100.,
            magazine: 30,
            ammunition: 120,
            grenades: 2,
            smokes: 1,
            rockets: 0,
            mortar_rounds: 0,
            drones: 0,
            bearer: false
        };
        6
    ];
    s.context()
        .advance_rules(
            dt,
            r,
            &Ownership::default(),
            v,
            scenario,
            Profiles {
                reserves: ["rifle_squad", "fighter_cell"].map(|kind| Definition {
                    kind,
                    name: "Reserves",
                    members: &members,
                    armor_upgrade: false,
                    grenade_upgrade: false,
                }),
                truck: TruckProfile {
                    vehicle: vehicle_birth::Definition {
                        kind: "truck",
                        base: "supply",
                        hp: 240.,
                        hull: Vector3::new(2., 2., 5.),
                        missiles: [0, 0],
                    },
                    town_load: [50, 20],
                    town_stock: [100., 40.],
                    supply: [70, 60],
                },
                vehicle: &|_| VehicleProfile {
                    sight: 65.,
                    helicopter: false,
                    automatic: false,
                    cannon: true,
                },
                prisoner: &|_| PrisonerProfile {
                    weapon: Some(("rifle", 30)),
                    squad_name: "Rifle Squad",
                },
                display: &|s| s.name.clone(),
                item_name: &str::to_owned,
                commanders: &[],
            },
        )
        .unwrap()
}

#[allow(dead_code)]
#[path = "squad_movement_world.rs"]
mod movement;
pub fn transcript() -> Vec<u8> {
    let mut out = vec![];
    for trial in 0..24 {
        let mut entries = vec![];
        for team in 0..2 {
            let mut d = structure(30 + team as u32, "depot", -12. + team as f32 * 24.);
            d.team = team;
            entries.push(actor(d));
            let mut f = structure(40 + team as u32, "fob", -4. + team as f32 * 8.);
            f.team = team;
            f.supply_parent = 30 + team as u32;
            f.supply = 100.;
            f.truck_timer = 0.;
            f.road = vec![
                Vector3::new(-11. + team as f32 * 22., 0., -6.),
                Vector3::new(-4. + team as f32 * 8., 0., -6.),
            ];
            entries.push(actor(f));
        }
        let mut t = structure(50, "town", -9.);
        t.supply = 100.;
        t.supply_parent = 40;
        t.truck_timer = 0.;
        t.road = vec![Vector3::new(-8., 0., 6.), Vector3::new(-4., 0., 6.)];
        entries.push(actor(t));
        let mut prisoner = soldier(
            1,
            0.,
            if trial % 3 == 0 {
                Life::Surrender
            } else {
                Life::Hidden
            },
        );
        prisoner.control.hidden = if trial % 3 == 1 {
            HiddenReason::Held
        } else if trial % 3 == 2 {
            HiddenReason::Interrogation
        } else {
            HiddenReason::Waiting
        };
        prisoner.links.intel_left = 3;
        prisoner.links.intel_timer = 120.;
        entries.push(Actor::Soldier(Box::new(prisoner)));
        entries.push(Actor::Soldier(Box::new(soldier(2, 1., Life::Alive))));
        let mut s = fixture::Scene::new(entries, 3917 + trial);
        let mut r = Rules::default();
        r.network.depots = [30, 31];
        r.network.towns = vec![50];
        r.visibility_timer = [0., 0.2, 0.4][trial as usize % 3];
        r.second_timer = [0., 0.1, 1.][trial as usize % 3];
        r.fog.add_mark(0, Vector3::ZERO, 15., 119., 1.4).unwrap();
        r.support.queue = vec![
            Salvo {
                at: 120.,
                kind: Kind::Arty,
                team: 0,
                position: Vector3::ZERO,
                radius: 22.,
                back: Vector3::Z * 380.,
                called_by: 7,
            },
            Salvo {
                at: 120.,
                kind: Kind::Grad,
                team: 1,
                position: Vector3::ZERO,
                radius: 20.,
                back: -Vector3::Z * 300.,
                called_by: 8,
            },
        ];
        let mut v = Victory {
            winner: -1,
            mission: trial % 5 == 0,
        };
        let mut previous: [Vec<u8>; 6] = std::array::from_fn(|_| vec![]);
        for step in 0..8 {
            s.world.now = [119.99, 120., 120.5, 121., 122., 129., 137., 138.][step];
            let dt = [0.1, 0.1, 0.5, 0.5, 1., 7., 8., 0.4][step];
            let mut resumed = s.resume();
            let mut rr = Rules::restore(&r.checkpoint().unwrap()).unwrap();
            let mut vv = v;
            let events = run(&mut s, &mut r, &mut v, dt, trial % 7 == 0);
            assert_eq!(
                events,
                run(&mut resumed, &mut rr, &mut vv, dt, trial % 7 == 0)
            );
            for w in [&mut s.world, &mut resumed.world] {
                w.geometry
                    .navigation
                    .process_paths(&mut w.actors, 32, w.now, &mut w.rng)
                    .unwrap();
            }
            let state = |s: &fixture::Scene, r: &Rules, v: Victory| {
                let mut squads = vec![];
                for q in &s.world.squads {
                    let b = q.checkpoint().unwrap();
                    squads.extend_from_slice(&(b.len() as u32).to_le_bytes());
                    squads.extend_from_slice(&b);
                }
                [
                    s.world.actors.checkpoint().unwrap(),
                    s.world.geometry.checkpoint(),
                    s.world.battle.checkpoint(),
                    r.checkpoint().unwrap(),
                    squads,
                    [
                        s.world.rng.state().to_le_bytes(),
                        s.next.to_le_bytes(),
                        (v.winner as i64).to_le_bytes(),
                    ]
                    .concat(),
                ]
            };
            let bytes = state(&s, &r, v);
            assert_eq!(bytes, state(&resumed, &rr, vv));
            for (before, after) in previous.iter_mut().zip(bytes) {
                movement::checkpoint_delta(&mut out, before, after);
            }
            let text = format!("{trial}/{step} {events:?}").into_bytes();
            out.extend_from_slice(&(text.len() as u32).to_le_bytes());
            out.extend_from_slice(&text);
            s = resumed;
        }
    }
    out
}
