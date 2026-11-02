#[allow(dead_code)]
#[path = "fixtures/vehicle_loss_world.rs"]
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
use frontline_core::support_calls::{Event as SupportEvent, Salvo};
use frontline_core::vector::Vector3;
use frontline_core::vehicle_birth;
fn run(s: &mut fixture::Scene, r: &mut Rules, v: &mut Victory, dt: f64) -> Vec<Event> {
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
            true,
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
#[test]
fn rule_clocks_preserve_the_original_cadence_without_catchup_bursts() {
    let mut s = fixture::Scene::new(vec![], 1);
    let mut r = Rules::default();
    let mut v = Victory {
        winner: -1,
        mission: true,
    };
    assert_eq!(
        run(&mut s, &mut r, &mut v, 0.1),
        vec![Event::Visibility(vec![])]
    );
    assert_eq!((r.visibility_timer, r.second_timer), (0.4, 1.));
    assert!(run(&mut s, &mut r, &mut v, 0.1).is_empty());
    let events = run(&mut s, &mut r, &mut v, 2.);
    assert_eq!(events, vec![Event::Visibility(vec![])]);
    assert_eq!((r.visibility_timer, r.second_timer), (0.4, 1.));
}
#[test]
fn arriving_support_is_created_before_visibility_and_periodic_victory() {
    let mut s = fixture::Scene::new(vec![], 1);
    let mut r = Rules::default();
    let mut v = Victory {
        winner: -1,
        mission: false,
    };
    r.support.queue.push(Salvo {
        at: 100.,
        kind: Kind::Grad,
        team: 0,
        position: Vector3::ZERO,
        radius: 20.,
        back: Vector3::Z * 300.,
        called_by: 7,
    });
    let out = run(&mut s, &mut r, &mut v, 0.1);
    assert!(matches!(
        out.as_slice(),
        [
            Event::Support(SupportEvent::Born { id: 1000, .. }),
            Event::Visibility(_),
            Event::Winner(1)
        ]
    ));
    assert_eq!(v.winner, 1);
    assert!(r.support.queue.is_empty());
}
#[test]
fn rescue_updates_shared_membership_and_routes_before_the_next_rules_tick() {
    let p = soldier(1, 0., Life::Surrender);
    let friend = soldier(2, 1., Life::Alive);
    let mut s = fixture::Scene::new(
        vec![
            Actor::Soldier(Box::new(p)),
            Actor::Soldier(Box::new(friend)),
        ],
        1,
    );
    let mut r = Rules::default();
    let mut v = Victory {
        winner: -1,
        mission: true,
    };
    let events = run(&mut s, &mut r, &mut v, 0.1);
    assert!(events
        .iter()
        .any(|e| matches!(e, Event::Freed { id: 1, .. })));
    let p = s.world.actors.soldier(1).unwrap();
    assert_eq!(p.vitals.life, Life::Alive);
    assert_eq!(p.weapon.magazine, 30);
    assert!(s.world.squads.iter().any(|q| q.members.contains(&1)));
}
#[test]
fn hidden_prisoners_reveal_intelligence_after_their_strict_deadline() {
    let mut p = soldier(1, 0., Life::Hidden);
    p.control.hidden = HiddenReason::Held;
    p.links.intel_left = 2;
    p.links.intel_timer = 100.;
    let mut s = fixture::Scene::new(vec![Actor::Soldier(Box::new(p))], 1);
    let mut r = Rules::default();
    let mut v = Victory {
        winner: -1,
        mission: true,
    };
    assert!(!run(&mut s, &mut r, &mut v, 0.1)
        .iter()
        .any(|e| matches!(e, Event::Intelligence(_))));
    s.world.now = 101.;
    let out = run(&mut s, &mut r, &mut v, 1.);
    assert!(out
        .iter()
        .any(|e| matches!(e,Event::Intelligence(i) if i.team==1)));
    assert_eq!(s.world.actors.soldier(1).unwrap().links.intel_left, 1);
    assert_eq!(r.prisoners.given(1).len(), 1);
}
#[test]
fn the_complete_rules_state_resumes_with_identical_actor_and_random_continuation() {
    let mut p = soldier(1, 0., Life::Hidden);
    p.control.hidden = HiddenReason::Held;
    p.links.intel_left = 3;
    p.links.intel_timer = 99.;
    let mut s = fixture::Scene::new(
        vec![Actor::Soldier(Box::new(p)), actor(structure(30, "fob", 8.))],
        91,
    );
    let mut r = Rules::default();
    let mut v = Victory {
        winner: -1,
        mission: true,
    };
    r.income[0] = vec![(90., 70)];
    r.fob_names_used = [12, 4];
    for dt in [0.1, 0.5, 1., 7., 0.2] {
        s.world.now += dt;
        let mut resumed = s.resume();
        let mut rr = Rules::restore(&r.checkpoint().unwrap()).unwrap();
        let mut vv = v;
        assert_eq!(
            run(&mut s, &mut r, &mut v, dt),
            run(&mut resumed, &mut rr, &mut vv, dt)
        );
        assert_eq!(r, rr);
        assert_eq!(v, vv);
        s.world.compare(&resumed.world);
    }
}
#[test]
fn income_keeps_the_two_minute_boundary_and_rejects_invalid_checkpoint_clocks() {
    let mut r = Rules::default();
    r.income[0] = vec![(1., 10), (2., 20), (121., 30)];
    assert_eq!(r.income_per_minute(0, 121.).unwrap(), 30);
    assert_eq!(r.income_per_minute(0, 121.01).unwrap(), 25);
    assert_eq!(r.income[0], vec![(2., 20), (121., 30)]);
    let mut bytes = r.checkpoint().unwrap();
    bytes.push(0);
    assert!(Rules::restore(&bytes).is_err());
    r.visibility_timer = f64::NAN;
    assert!(r.checkpoint().is_err());
}

#[test]
fn assigning_a_guard_reports_the_captor_event_once() {
    let p = soldier(1, 0., Life::Surrender);
    let mut guard = soldier(2, 1., Life::Alive);
    guard.identity.team = 1;
    let mut prison = structure(30, "fob", 5.);
    prison.team = 1;
    let mut s = fixture::Scene::new(
        vec![
            Actor::Soldier(Box::new(p)),
            Actor::Soldier(Box::new(guard)),
            actor(prison),
        ],
        1,
    );
    let mut r = Rules::default();
    let mut v = Victory {
        winner: -1,
        mission: true,
    };
    assert!(run(&mut s, &mut r, &mut v, 0.1).contains(&Event::Captor(2)));
    assert_eq!(s.world.actors.soldier(1).unwrap().links.captor, 2);
    s.world.now += 1.;
    assert!(!run(&mut s, &mut r, &mut v, 1.)
        .iter()
        .any(|e| matches!(e, Event::Captor(_))));
}
