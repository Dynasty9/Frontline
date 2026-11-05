#[allow(dead_code)]
#[path = "fixtures/vehicle_loss_world.rs"]
mod fixture;
use fixture::shared::{actor, soldier, structure};
use frontline_core::actors::Actor;
use frontline_core::infantry::Infantry;
use frontline_core::infantry_vitals::Life;
use frontline_core::structure::{Production, TownEconomy};
use frontline_core::structure_services::Supply;
use frontline_core::structure_world::{Event, Profiles, Victory};
use frontline_core::supply_network::SupplyNetwork;
use frontline_core::vector::Vector3;
use frontline_core::vehicle_damage::Armor;
fn profiles() -> Profiles<'static> {
    Profiles {
        fob_radius: 4.,
        town: [
            TownEconomy {
                stock: 180.,
                yield_per_minute: 24.,
                capture_pace: 1.,
            },
            TownEconomy {
                stock: 420.,
                yield_per_minute: 60.,
                capture_pace: 0.6,
            },
        ],
        supply: &|_: &Infantry| Supply {
            ammunition: None,
            frags: 0,
            loadout: None,
        },
    }
}
fn queue() -> Production {
    Production {
        item: "rifle_squad".into(),
        remaining: 3.,
        total: 10.,
        owner: 7,
        cost: 90,
    }
}
#[test]
fn victory_ignores_scenery_and_unfinished_fobs_after_restore_and_removal() {
    let mut enemy = structure(31, "fob", 8.);
    enemy.team = 1;
    let mut unfinished = enemy.clone();
    unfinished.id = 32;
    unfinished.built = false;
    let mut entries = vec![
        actor(structure(30, "fob", 0.)),
        actor(enemy),
        actor(unfinished),
    ];
    entries.extend((100..164).map(|id| actor(structure(id, "tree", (id % 8) as f32))));
    let scene = fixture::Scene::new(entries, 7);
    let mut resumed = scene.resume();
    let mut victory = Victory {
        winner: -1,
        mission: false,
    };
    assert_eq!(resumed.world.actors.simulated_structures().len(), 3);
    assert_eq!(resumed.context().check_victory(&mut victory), None);
    resumed.world.actors.remove(31).unwrap();
    assert_eq!(resumed.context().check_victory(&mut victory), Some(0));
}
#[test]
fn taking_the_last_fob_updates_ownership_credit_routes_and_victory_together() {
    let mut fob = structure(30, "fob", 0.);
    fob.name = "Delta".into();
    fob.capture_progress = 99.5;
    fob.capture_team = 1;
    fob.supply_parent = 31;
    fob.road = vec![Vector3::X];
    fob.truck = 40;
    fob.truck_timer = 2.;
    fob.queue = vec![queue()];
    let mut s = soldier(1, 1., Life::Alive);
    s.identity.team = 1;
    s.identity.owner = 8;
    let mut scene = fixture::Scene::new(vec![actor(fob), Actor::Soldier(Box::new(s))], 1);
    let mut victory = Victory {
        winner: -1,
        mission: false,
    };
    let mut network = SupplyNetwork::default();
    let out = scene
        .context()
        .advance_territory(30, 0.5, &profiles(), &mut network, &mut victory)
        .unwrap();
    let st = scene.world.actors.structure(30).unwrap();
    assert_eq!((st.team, st.owner), (1, -2));
    assert!(st.queue.is_empty());
    assert_eq!((st.supply_parent, st.truck, st.truck_timer), (0, 0, 6.));
    assert!(st.road.is_empty());
    assert_eq!(victory.winner, 1);
    assert!(out.contains(&Event::Winner(1)));
    assert_eq!(scene.world.battle.sides[1][20], 1.);
    assert_eq!(scene.world.battle.players[0].owner, 8);
    assert_eq!(
        scene.world.battle.events[0].text,
        "Rebels captured FOB Delta"
    );
}
#[test]
fn town_income_uses_the_previous_house_fraction_before_recounting() {
    let mut town = structure(30, "town", 0.);
    town.variant = 1;
    town.zone_center = Some(Vector3::ZERO);
    town.zone_radius = 6.;
    town.initial_houses = 4;
    town.intact = 0.1;
    town.supply = 10.;
    let mut scene = fixture::Scene::new(
        vec![
            actor(town),
            actor(structure(31, "roof", 2.)),
            actor(structure(32, "roof", 10.)),
        ],
        2,
    );
    let mut victory = Victory {
        winner: -1,
        mission: false,
    };
    let mut network = SupplyNetwork::default();
    scene
        .context()
        .advance_territory(30, 0.5, &profiles(), &mut network, &mut victory)
        .unwrap();
    let st = scene.world.actors.structure(30).unwrap();
    assert_eq!(st.supply, 10. + 0.5 * (0.35 + 0.65 * 0.1));
    assert_eq!(st.intact, 0.25);
    assert_eq!(st.house_timer, 10.);
    assert_eq!(victory.winner, -1);
}
#[test]
fn neutral_town_capture_keeps_its_stock_and_queue_without_ending_the_match() {
    let mut town = structure(30, "town", 0.);
    town.team = -1;
    town.name = "Crossroads".into();
    town.zone_center = Some(Vector3::ZERO);
    town.zone_radius = 6.;
    town.capture_progress = 99.9;
    town.capture_team = 1;
    town.supply = 27.;
    town.queue = vec![queue()];
    let mut s = soldier(1, 1., Life::Alive);
    s.identity.team = 1;
    s.identity.owner = 8;
    let mut scene = fixture::Scene::new(vec![actor(town), Actor::Soldier(Box::new(s))], 3);
    assert!(scene.world.actors.owned_structures().is_empty());
    let mut victory = Victory {
        winner: -1,
        mission: false,
    };
    let mut network = SupplyNetwork::default();
    let out = scene
        .context()
        .advance_territory(30, 0.5, &profiles(), &mut network, &mut victory)
        .unwrap();
    let st = scene.world.actors.structure(30).unwrap();
    assert_eq!(st.team, 1);
    assert_eq!(st.supply, 27.);
    assert_eq!(scene.world.actors.owned_structures(), [30]);
    assert_eq!(st.queue, vec![queue()]);
    assert_eq!(scene.world.battle.sides[1][21], 1.);
    assert_eq!(victory.winner, -1);
    assert!(out.iter().any(|e| matches!(
        e,
        Event::Captured {
            old_team: -1,
            supply: 27,
            ..
        }
    )));
}
#[test]
fn bearers_cannot_contest_a_fob_and_its_last_stand_capture_is_slower() {
    let fob = structure(30, "fob", 0.);
    let mut enemy = soldier(1, 1., Life::Alive);
    enemy.identity.team = 1;
    let mut bearer = soldier(2, 2., Life::Alive);
    bearer.identity.unit = "bearer".into();
    let mut scene = fixture::Scene::new(
        vec![
            actor(fob),
            Actor::Soldier(Box::new(enemy)),
            Actor::Soldier(Box::new(bearer)),
        ],
        4,
    );
    let mut victory = Victory {
        winner: -1,
        mission: false,
    };
    let mut network = SupplyNetwork::default();
    let mut ctx = scene.context();
    ctx.movement = &|s| frontline_core::squad_movement::ManProfile {
        bearer: s.identity.unit == "bearer",
        weapon_range: None,
    };
    let out = ctx
        .advance_territory(30, 0.5, &profiles(), &mut network, &mut victory)
        .unwrap();
    assert_eq!(
        scene.world.actors.structure(30).unwrap().capture_progress,
        0.75
    );
    assert!(matches!(
        &out[0],
        Event::Warning {
            last_stand: true,
            ..
        }
    ));
    assert_eq!(victory.winner, -1);
}
#[test]
fn mines_ignore_wounded_and_friendly_units_but_explode_against_a_living_enemy() {
    for life in [Life::Downed, Life::Alive] {
        let mine = structure(30, "mines", 0.);
        let friend = soldier(1, 0.5, Life::Alive);
        let mut enemy = soldier(2, 1., life);
        enemy.identity.team = 1;
        let mut scene = fixture::Scene::new(
            vec![
                actor(mine),
                Actor::Soldier(Box::new(friend)),
                Actor::Soldier(Box::new(enemy)),
            ],
            5,
        );
        let mut network = SupplyNetwork::default();
        let mut impacts = vec![];
        let out = scene
            .context()
            .advance_mine(30, 0.2, &mut network, &mut impacts, &|_| Armor {
                level: 0,
                helicopter: false,
                boat: false,
                supply: false,
                toss: 1.,
            })
            .unwrap();
        if life == Life::Downed {
            assert!(out.is_empty());
            assert!(scene.world.actors.structure(30).is_some());
        } else {
            assert!(!out.is_empty());
            assert!(scene.world.actors.structure(30).is_none());
        }
    }
}
#[test]
fn captures_resume_with_the_same_ledger_routes_and_victory_state() {
    let mut fob = structure(30, "fob", 0.);
    fob.capture_progress = 99.5;
    fob.capture_team = 1;
    let mut enemy = soldier(1, 1., Life::Alive);
    enemy.identity.team = 1;
    let mut scene = fixture::Scene::new(vec![actor(fob), Actor::Soldier(Box::new(enemy))], 6);
    let mut resumed = scene.resume();
    let mut a = SupplyNetwork::default();
    let mut b = a.clone();
    let mut va = Victory {
        winner: -1,
        mission: true,
    };
    let mut vb = va;
    assert_eq!(
        scene
            .context()
            .advance_territory(30, 0.5, &profiles(), &mut a, &mut va)
            .unwrap(),
        resumed
            .context()
            .advance_territory(30, 0.5, &profiles(), &mut b, &mut vb)
            .unwrap()
    );
    scene.world.compare(&resumed.world);
    assert_eq!(a, b);
    assert_eq!(va, vb);
    assert_eq!(va.winner, -1);
}
