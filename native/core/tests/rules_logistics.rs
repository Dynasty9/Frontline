#[allow(dead_code)]
#[path = "fixtures/vehicle_loss_world.rs"]
mod fixture;
use fixture::shared::{actor, soldier, structure};
use frontline_core::actors::Actor;
use frontline_core::command_ownership::Ownership;
use frontline_core::economy::Economy;
use frontline_core::infantry_spawn::Loadout;
use frontline_core::infantry_vitals::Life;
use frontline_core::rules_logistics::{Event, TruckProfile};
use frontline_core::squad_birth::Definition;
use frontline_core::supply_network::SupplyNetwork;
use frontline_core::vector::Vector3;
use frontline_core::vehicle_birth;
fn truck() -> TruckProfile<'static> {
    TruckProfile {
        vehicle: vehicle_birth::Definition {
            kind: "truck",
            base: "supply",
            hp: 240.,
            hull: Vector3::new(2., 2.5, 5.),
            missiles: [0, 0],
            tracked: false,
        },
        town_load: [50, 20],
        town_stock: [100., 40.],
        supply: [70, 60],
    }
}
fn scene(stock: f64, road: bool) -> (fixture::Scene, SupplyNetwork) {
    let depot = structure(30, "depot", -12.);
    let mut fob = structure(31, "fob", 8.);
    fob.truck_timer = 0.;
    fob.supply_parent = 30;
    fob.road = vec![Vector3::new(-10., 0., -8.), Vector3::new(7., 0., -8.)];
    let mut town = structure(32, "town", -7.);
    town.truck_timer = 0.;
    town.supply_parent = 31;
    town.supply = stock;
    if road {
        town.road = vec![Vector3::new(-6., 0., 5.), Vector3::new(7., 0., 5.)];
    }
    let s = fixture::Scene::new(vec![actor(depot), actor(fob), actor(town)], 771);
    (
        s,
        SupplyNetwork {
            depots: [30, 0],
            towns: vec![32],
            ..Default::default()
        },
    )
}
fn definitions(m: &[Loadout]) -> [Definition<'_>; 2] {
    ["rifle_squad", "fighter_cell"].map(|kind| Definition {
        kind,
        name: "Reserves",
        members: m,
        armor_upgrade: false,
        grenade_upgrade: false,
    })
}
fn members() -> Vec<Loadout> {
    vec![
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
    ]
}
#[test]
fn town_stock_dispatches_before_the_fob_and_active_lorries_do_not_duplicate() {
    let (mut s, n) = scene(130.7, true);
    let out = s.context().dispatch_supply(0.5, &n, truck()).unwrap();
    assert_eq!(
        out,
        vec![
            Event::Truck { id: 1000, town: 32 },
            Event::Truck { id: 1001, town: 0 }
        ]
    );
    let v = s.world.actors.vehicle(1000).unwrap();
    assert_eq!(
        (
            v.cargo,
            v.destination_fob,
            v.source_town,
            v.route_index,
            v.owner
        ),
        (100, 31, 32, 1, -1)
    );
    assert_eq!(
        s.world.actors.structure(32).unwrap().supply,
        30.69999999999999
    );
    assert_eq!(s.world.actors.vehicle(1001).unwrap().cargo, 70);
    let state = s.world.actors.checkpoint().unwrap();
    assert!(s
        .context()
        .dispatch_supply(1., &n, truck())
        .unwrap()
        .is_empty());
    assert_eq!(s.world.actors.checkpoint().unwrap(), state);
}
#[test]
fn missing_routes_and_insufficient_stock_use_distinct_retry_clocks() {
    for (stock, road, wait) in [(49., true, 3.), (100., false, 8.)] {
        let (mut s, n) = scene(stock, road);
        s.context().dispatch_supply(0.5, &n, truck()).unwrap();
        assert_eq!(s.world.actors.structure(32).unwrap().truck_timer, wait);
        assert_eq!(s.world.actors.structure(32).unwrap().truck, 0);
        assert_eq!(s.world.actors.structure(32).unwrap().supply, stock);
    }
    let (mut s, n) = scene(39.2, true);
    let mut p = truck();
    p.town_stock[0] = 40.;
    s.context().dispatch_supply(0.5, &n, p).unwrap();
    assert_eq!(s.world.actors.vehicle(1000).unwrap().cargo, 39);
}
#[test]
fn destroyed_trucks_are_replaced_with_the_next_identity_after_a_resume() {
    let (mut s, n) = scene(130., true);
    s.context().dispatch_supply(0.5, &n, truck()).unwrap();
    s.world.actors.remove(1000);
    s.world.actors.remove(1001);
    s.world.geometry.collision.remove(1000);
    s.world.geometry.collision.remove(1001);
    let mut r = s.resume();
    assert_eq!(
        s.context().dispatch_supply(0.5, &n, truck()).unwrap(),
        r.context().dispatch_supply(0.5, &n, truck()).unwrap()
    );
    s.world.compare(&r.world);
    assert_eq!(s.world.actors.structure(31).unwrap().truck, 1002);
}
#[test]
fn reserves_use_the_first_commander_current_research_and_the_opening_and_cooldown_guards() {
    let (mut s, n) = scene(0., true);
    let m = members();
    let mut ready = [0.; 2];
    let e = Economy {
        upgrades: [vec!["armor".into(), "grenades".into()], vec![]],
    };
    let o = Ownership {
        players: vec![(8, 0), (9, 1), (10, 0)],
        ..Default::default()
    };
    for (now, scenario, mission) in [
        (119.99, false, false),
        (120., true, false),
        (120., false, true),
    ] {
        s.world.now = now;
        assert!(s
            .context()
            .reinforce(&mut ready, &n, &e, &o, definitions(&m), scenario, mission)
            .unwrap()
            .is_empty());
        assert_eq!(ready, [0.; 2]);
    }
    s.world.now = 120.;
    let mut r = s.resume();
    let mut rr = ready;
    let events = s
        .context()
        .reinforce(&mut ready, &n, &e, &o, definitions(&m), false, false)
        .unwrap();
    assert_eq!(
        events,
        r.context()
            .reinforce(&mut rr, &n, &e, &o, definitions(&m), false, false)
            .unwrap()
    );
    s.world.compare(&r.world);
    assert_eq!(ready, [195., 0.]);
    assert_eq!(ready, rr);
    assert_eq!(s.world.squads[0].owner, 8);
    for id in &s.world.squads[0].members {
        let m = s.world.actors.soldier(*id).unwrap();
        assert_eq!(m.vitals.hp, 120.);
        assert_eq!(m.grenades.frags, 3);
    }
    s.world.now = 195.;
    assert!(s
        .context()
        .reinforce(&mut ready, &n, &e, &o, definitions(&m), false, false)
        .unwrap()
        .is_empty());
}
#[test]
fn bearers_count_toward_reserve_strength_but_wounded_do_not() {
    for wounded in [false, true] {
        let (mut s, n) = scene(0., true);
        let m = members();
        let mut ready = [0.; 2];
        s.world.now = 120.;
        for i in 0..6 {
            let mut man = soldier(
                i + 1,
                1.,
                if wounded && i == 0 {
                    Life::Downed
                } else {
                    Life::Alive
                },
            );
            man.identity.unit = "bearer".into();
            s.world.actors.spawn(Actor::Soldier(Box::new(man))).unwrap();
        }
        let out = s
            .context()
            .reinforce(
                &mut ready,
                &n,
                &Economy::default(),
                &Ownership::default(),
                definitions(&m),
                false,
                false,
            )
            .unwrap();
        assert_eq!(!out.is_empty(), wounded);
        if wounded {
            assert_eq!(s.world.squads[0].owner, -1);
        }
    }
}
#[test]
fn malformed_rules_do_not_spend_stock_or_consume_identities_or_randomness() {
    let (mut s, n) = scene(100., true);
    let before = s.resume();
    let mut p = truck();
    p.town_load[1] = -1;
    assert!(s.context().dispatch_supply(0.5, &n, p).is_err());
    s.world.compare(&before.world);
    assert!(s.context().dispatch_supply(f64::NAN, &n, truck()).is_err());
    s.world.compare(&before.world);
    let mut ready = [f64::NAN, 0.];
    let m = members();
    assert!(s
        .context()
        .reinforce(
            &mut ready,
            &n,
            &Economy::default(),
            &Ownership::default(),
            definitions(&m),
            false,
            false
        )
        .is_err());
    s.world.compare(&before.world);
}
