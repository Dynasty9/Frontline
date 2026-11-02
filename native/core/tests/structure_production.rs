#[allow(dead_code)]
#[path = "fixtures/vehicle_loss_world.rs"]
mod fixture;
use fixture::shared::{actor, soldier, structure};
use frontline_core::actors::Actor;
use frontline_core::boat_navigation::BoatNavigation;
use frontline_core::command_ownership::{Away, Ownership};
use frontline_core::economy::{self, Economy};
use frontline_core::infantry_spawn::Loadout;
use frontline_core::infantry_vitals::Life;
use frontline_core::squad_birth::Definition;
use frontline_core::structure::Production;
use frontline_core::structure_production::{Event, Product, Profiles};
use frontline_core::vector::Vector3;
fn member() -> Loadout {
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
        bearer: false,
    }
}
fn squad(m: &[Loadout]) -> Definition<'_> {
    Definition {
        kind: "rifle_squad",
        name: "Rifle Squad",
        members: m,
        armor_upgrade: false,
        grenade_upgrade: false,
    }
}
fn scene(kind: &str, item: &str) -> fixture::Scene {
    let mut s = structure(30, kind, 0.);
    s.queue.push(Production {
        item: item.into(),
        remaining: 0.1,
        total: 10.,
        owner: 7,
        cost: 90,
    });
    fixture::Scene::new(vec![actor(s)], 771)
}
fn boats(scene: &fixture::Scene) -> BoatNavigation {
    BoatNavigation::from_terrain(&scene.world.geometry.terrain, &vec![0; 32 * 32]).unwrap()
}
fn run(
    scene: &mut fixture::Scene,
    p: Product<'_>,
    economy: &mut Economy,
    owners: &mut Ownership,
    cap: u32,
) -> Vec<Event> {
    let mut water = boats(scene);
    scene
        .context()
        .advance_production(
            30,
            0.5,
            Profiles {
                product: Some(p),
                base_cap: cap,
                cap_per_fob: 20,
                vehicle_cap: &|_| 3,
            },
            economy,
            owners,
            &mut water,
        )
        .unwrap()
}
#[test]
fn a_completed_squad_uses_current_upgrades_and_the_absent_commanders_heir() {
    let mut s = scene("barracks", "rifle_squad");
    let m = vec![member(); 3];
    let mut e = Economy {
        upgrades: [vec!["armor".into(), "grenades".into()], vec![]],
    };
    let mut o = Ownership {
        players: vec![(8, 0), (9, 1), (10, 0)],
        away: vec![Away {
            peer: 7,
            ..Default::default()
        }],
    };
    let out = run(&mut s, Product::Squad(squad(&m)), &mut e, &mut o, 6);
    assert!(out.contains(&Event::Squad(7)));
    assert!(matches!(out.last(), Some(Event::Ready { .. })));
    assert!(s.world.actors.structure(30).unwrap().queue.is_empty());
    assert_eq!(s.world.squads[0].owner, 10);
    assert_eq!(o.away[0].squads, vec![7]);
    assert_eq!(s.world.battle.players[0].owner, 10);
    assert_eq!(s.world.battle.sides[0][15], 1.);
    for &id in &s.world.squads[0].members {
        let m = s.world.actors.soldier(id).unwrap();
        assert_eq!(m.vitals.hp, 120.);
        assert_eq!(m.grenades.frags, 3);
        assert!(m.is_moving());
    }
}
#[test]
fn capacity_stalls_the_order_without_resetting_its_clock_and_warns_once() {
    let mut s = scene("barracks", "rifle_squad");
    let m = vec![member(); 7];
    let mut e = Economy::default();
    let mut o = Ownership::default();
    assert_eq!(
        run(&mut s, Product::Squad(squad(&m)), &mut e, &mut o, 6),
        vec![Event::CapWarning { peer: 7, team: 0 }]
    );
    assert!(run(&mut s, Product::Squad(squad(&m)), &mut e, &mut o, 6).is_empty());
    assert_eq!(
        s.world.actors.structure(30).unwrap().queue[0].remaining,
        0.1
    );
    run(&mut s, Product::Squad(squad(&m)), &mut e, &mut o, 7);
    assert_eq!(s.world.squads[0].members.len(), 7);
    assert!(s
        .world
        .actors
        .structure(30)
        .unwrap()
        .production_status
        .is_empty());
}
#[test]
fn research_ignores_capacity_and_applies_to_existing_wounded_but_not_enemy_soldiers() {
    let mut s = scene("research", "armor");
    for (id, team) in [(1, 0), (2, 1)] {
        let mut man = soldier(id, 1., Life::Downed);
        man.identity.team = team;
        s.world.actors.spawn(Actor::Soldier(Box::new(man))).unwrap();
    }
    let mut e = Economy::default();
    let mut o = Ownership::default();
    assert_eq!(
        run(
            &mut s,
            Product::Research {
                key: "armor",
                name: "Body armor"
            },
            &mut e,
            &mut o,
            0
        ),
        vec![Event::Research {
            team: 0,
            name: "Body armor".into()
        }]
    );
    assert!(e.has_upgrade(0, "armor"));
    let men: Vec<_> = s
        .world
        .actors
        .iter()
        .filter_map(|a| {
            if let Actor::Soldier(s) = a {
                Some(s)
            } else {
                None
            }
        })
        .collect();
    assert_eq!(men[0].vitals.hp, 120.);
    assert_eq!(men[1].vitals.hp, 100.);
    assert_eq!(s.world.battle.sides[0][18], 1.);
}
#[test]
fn vehicles_keep_their_passenger_squads_when_held_for_a_returning_commander() {
    for base in ["tank", "boat", "lift_heli", "uav", "supply"] {
        let mut s = scene(if base == "boat" { "dock" } else { "factory" }, "carrier");
        let m = vec![member(); 2];
        let mut e = Economy::default();
        let mut o = Ownership {
            players: vec![],
            away: vec![Away {
                peer: 7,
                ..Default::default()
            }],
        };
        let air = base == "lift_heli" || base == "uav";
        let out = run(
            &mut s,
            Product::Vehicle {
                definition: frontline_core::vehicle_birth::Definition {
                    kind: "carrier",
                    base,
                    hp: 500.,
                    hull: Vector3::new(2., 2., 4.),
                    missiles: [3, 4],
                },
                name: "Carrier",
                cap: 2,
                air,
                supply: false,
                automatic: false,
                passengers: Some(squad(&m)),
            },
            &mut e,
            &mut o,
            6,
        );
        let id = out
            .iter()
            .find_map(|e| {
                if let Event::Vehicle(id) = e {
                    Some(*id)
                } else {
                    None
                }
            })
            .unwrap();
        let v = s.world.actors.vehicle(id).unwrap();
        assert_eq!(v.owner, -1);
        assert_eq!(v.passengers.len(), 2);
        assert_eq!(v.heli_home, if air { 30 } else { 0 });
        assert_eq!(o.away[0].vehicles, vec![id]);
        assert_eq!(o.away[0].squads, vec![7]);
        for &id in &v.passengers {
            assert_eq!(
                s.world.actors.soldier(id).unwrap().vitals.life,
                Life::Hidden
            );
        }
        assert_eq!(s.world.battle.sides[0][16], 1.);
    }
}
#[test]
fn invalid_product_rejects_before_consuming_the_queue_or_randomness() {
    let mut s = scene("barracks", "rifle_squad");
    let before = s.resume();
    let mut m = vec![member()];
    m[0].hp = f64::NAN;
    let mut water = boats(&s);
    let mut e = Economy::default();
    let mut o = Ownership::default();
    assert!(s
        .context()
        .advance_production(
            30,
            0.5,
            Profiles {
                product: Some(Product::Squad(squad(&m))),
                base_cap: 6,
                cap_per_fob: 20,
                vehicle_cap: &|_| 3
            },
            &mut e,
            &mut o,
            &mut water
        )
        .is_err());
    s.world.compare(&before.world);
    assert_eq!(s.next, before.next);
}
#[test]
fn restored_production_preserves_research_owners_recruits_and_routes() {
    let mut s = scene("barracks", "rifle_squad");
    let mut r = s.resume();
    let m = vec![member(); 4];
    let mut e = Economy {
        upgrades: [vec!["grenades".into()], vec![]],
    };
    let mut er = Economy::restore(&e.checkpoint().unwrap()).unwrap();
    let mut o = Ownership {
        players: vec![(8, 0)],
        away: vec![Away {
            peer: 7,
            ..Default::default()
        }],
    };
    let mut or = Ownership::restore(&o.checkpoint().unwrap()).unwrap();
    assert_eq!(
        run(&mut s, Product::Squad(squad(&m)), &mut e, &mut o, 6),
        run(&mut r, Product::Squad(squad(&m)), &mut er, &mut or, 6)
    );
    s.world.compare(&r.world);
    assert_eq!(o, or);
    assert_eq!(e, er);
}
#[test]
fn supply_prefers_one_affordable_fob_then_splits_integer_stock_and_refunds_nearest() {
    let entries = [(30, 0., 10.9), (31, 2., 30.2), (32, 4., 40.8)]
        .into_iter()
        .map(|(id, x, stock)| {
            let mut f = structure(id, "fob", x);
            f.supply = stock;
            actor(f)
        })
        .collect();
    let mut s = fixture::Scene::new(entries, 1);
    assert!(economy::spend(&mut s.world.actors, 0, Vector3::ZERO, 25).unwrap());
    assert_eq!(
        s.world.actors.structure(31).unwrap().supply,
        5.199999999999999
    );
    assert!(economy::spend(&mut s.world.actors, 0, Vector3::ZERO, 50).unwrap());
    assert!((s.world.actors.structure(30).unwrap().supply - 0.9).abs() < 1e-12);
    assert!((s.world.actors.structure(32).unwrap().supply - 5.8).abs() < 1e-12);
    let before = s.world.actors.checkpoint().unwrap();
    assert!(!economy::spend(&mut s.world.actors, 0, Vector3::ZERO, 99).unwrap());
    assert_eq!(before, s.world.actors.checkpoint().unwrap());
    assert_eq!(
        economy::refund(&mut s.world.actors, 0, Vector3::new(4., 0., 0.), 10).unwrap(),
        Some(32)
    );
    assert!(economy::spend(&mut s.world.actors, 0, Vector3::ZERO, -1).is_err());
}
#[test]
fn capacity_counts_wounded_and_tunnelled_men_but_excludes_bearers_and_passengers() {
    use frontline_core::infantry_control::HiddenReason;
    let mut entries = vec![];
    for (i, (life, hidden, unit)) in [
        (Life::Alive, HiddenReason::Waiting, "rifleman"),
        (Life::Downed, HiddenReason::Waiting, "rifleman"),
        (Life::Hidden, HiddenReason::TunnelWait, "rifleman"),
        (Life::Hidden, HiddenReason::Tent, "rifleman"),
        (Life::Hidden, HiddenReason::Vehicle, "rifleman"),
        (Life::Alive, HiddenReason::Waiting, "bearer"),
        (Life::Dead, HiddenReason::Waiting, "rifleman"),
    ]
    .into_iter()
    .enumerate()
    {
        let mut s = soldier(i as u32 + 1, 0., life);
        s.control.hidden = hidden;
        s.identity.unit = unit.into();
        entries.push(Actor::Soldier(Box::new(s)));
    }
    entries.push(fixture::vehicle(20, "tank"));
    entries.push(actor(structure(30, "fob", -8.)));
    let mut wreck = structure(31, "fob", 8.);
    wreck.wrecked = true;
    entries.push(actor(wreck));
    let s = fixture::Scene::new(entries, 1);
    assert_eq!(
        economy::used(&s.world.actors, 0, &|s| s.identity.unit == "bearer", &|_| 3),
        7
    );
    assert_eq!(economy::capacity(&s.world.actors, 0, 6, 20), 26);
}
#[test]
fn ownership_and_research_checkpoints_reject_duplicate_and_trailing_data() {
    let mut o = Ownership {
        players: vec![(7, 0), (8, 0)],
        away: vec![],
    };
    assert_eq!(o.acting_owner(9, 0), 8);
    assert_eq!(o.acting_owner(7, 0), 7);
    assert_eq!(o.acting_owner(9, 1), -2);
    let mut bytes = o.checkpoint().unwrap();
    bytes.push(0);
    assert!(Ownership::restore(&bytes).is_err());
    o.players.push((7, 1));
    assert!(o.checkpoint().is_err());
    let mut e = Economy::default();
    e.upgrades[0] = vec!["armor".into(), "armor".into()];
    assert!(e.checkpoint().is_err());
    let mut bytes = Economy::default().checkpoint().unwrap();
    bytes.push(0);
    assert!(Economy::restore(&bytes).is_err());
}
