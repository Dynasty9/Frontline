#[allow(dead_code)]
#[path = "fixtures/vehicle_loss_world.rs"]
mod fixture;
use fixture::shared::{actor, soldier, structure};
use frontline_core::actors::Actor;
use frontline_core::boat_navigation::BoatNavigation;
use frontline_core::command_ownership::Ownership;
use frontline_core::infantry_spawn::Loadout;
use frontline_core::infantry_vitals::Life;
use frontline_core::rules_world::Rules;
use frontline_core::squad_birth::Definition;
use frontline_core::structure::{Production, TownEconomy};
use frontline_core::structure_production::{Event as ProductionEvent, Product};
use frontline_core::structure_services::Supply;
use frontline_core::structure_world::Victory;
use frontline_core::structures_tick::{Event, Profiles};
use frontline_core::vehicle_damage::Armor;
fn man(bearer: bool) -> Loadout {
    Loadout {
        unit: if bearer { "bearer" } else { "rifleman" }.into(),
        weapon: if bearer { "" } else { "rifle" }.into(),
        hp: 100.,
        magazine: if bearer { 0 } else { 30 },
        ammunition: if bearer { 0 } else { 120 },
        grenades: 0,
        smokes: 0,
        rockets: 0,
        mortar_rounds: 0,
        drones: 0,
        bearer,
    }
}
fn queue(key: &str) -> Production {
    Production {
        item: key.into(),
        remaining: 0.1,
        total: 10.,
        owner: 7,
        cost: 50,
    }
}
fn run(s: &mut fixture::Scene, r: &mut Rules, cap: u32) -> Vec<Event> {
    let mut boats =
        BoatNavigation::from_terrain(&s.world.geometry.terrain, &vec![0; 32 * 32]).unwrap();
    let mut owners = Ownership::default();
    let bearer = man(true);
    let fighters = [man(false)];
    let product = |st: &frontline_core::structure::Structure| {
        st.queue.first().map(|q| {
            if q.item == "armor" {
                Product::Research {
                    key: "armor",
                    name: "Armor",
                }
            } else {
                Product::Squad(Definition {
                    kind: "rifle_squad",
                    name: "Rifle Squad",
                    members: &fighters,
                    armor_upgrade: false,
                    grenade_upgrade: false,
                })
            }
        })
    };
    let mut c = s.context();
    c.movement = &|s| frontline_core::squad_movement::ManProfile {
        bearer: s.identity.unit == "bearer",
        weapon_range: Some(85.),
    };
    c.advance_structures(
        0.5,
        r,
        &mut owners,
        &mut boats,
        &mut Victory {
            winner: -1,
            mission: false,
        },
        &mut vec![],
        Profiles {
            product: &product,
            base_cap: cap,
            cap_per_fob: 0,
            vehicle_cap: &|_| 1,
            supply: &|_| Supply {
                ammunition: None,
                frags: 0,
                loadout: None,
            },
            bearers: [&bearer, &bearer],
            gun: &|_| None,
            armor: &|_| Armor {
                level: 0,
                helicopter: false,
                boat: false,
                supply: false,
                toss: 1.,
            },
            fob_radius: 4.,
            towns: [TownEconomy {
                stock: 100.,
                yield_per_minute: 30.,
                capture_pace: 1.,
            }; 2],
        },
    )
    .unwrap()
}
#[test]
fn earlier_production_consumes_capacity_before_the_next_building() {
    for reverse in [false, true] {
        let mut a = structure(30, "barracks", -8.);
        a.queue.push(queue("rifle_squad"));
        let mut b = structure(31, "barracks", 8.);
        b.queue = a.queue.clone();
        let mut entries = vec![actor(a), actor(b)];
        if reverse {
            entries.reverse();
        }
        let mut s = fixture::Scene::new(entries, 71);
        let out = run(&mut s, &mut Rules::default(), 1);
        assert!(s
            .world
            .actors
            .structure(if reverse { 31 } else { 30 })
            .unwrap()
            .queue
            .is_empty());
        assert_eq!(
            s.world
                .actors
                .structure(if reverse { 30 } else { 31 })
                .unwrap()
                .production_status,
            "cap"
        );
        assert_eq!(
            out.iter()
                .filter(|e| matches!(e, Event::Production(ProductionEvent::Squad(_))))
                .count(),
            1
        );
        assert_eq!(s.world.squads.len(), 1);
    }
}
#[test]
fn research_changes_recruits_and_tent_staff_in_the_same_building_pass() {
    let mut lab = structure(30, "research", -8.);
    lab.queue.push(queue("armor"));
    let mut barracks = structure(31, "barracks", 8.);
    barracks.queue.push(queue("rifle_squad"));
    let tent = structure(32, "medic_tent", 0.);
    let mut s = fixture::Scene::new(vec![actor(lab), actor(barracks), actor(tent)], 72);
    let mut r = Rules::default();
    run(&mut s, &mut r, 100);
    assert!(r.economy.has_upgrade(0, "armor"));
    assert_eq!(s.world.actors.soldier(1000).unwrap().vitals.max_hp, 120.);
    for id in &s.world.actors.structure(32).unwrap().bearers {
        assert_eq!(s.world.actors.soldier(*id).unwrap().vitals.max_hp, 120.);
    }
    assert!(!s.world.actors.structure(32).unwrap().bearers.is_empty());
}
#[test]
fn destroyed_buildings_are_skipped_and_decorations_keep_their_clocks() {
    let mine = structure(30, "mines", 0.);
    let mut barracks = structure(31, "barracks", 0.5);
    barracks.hp = 0.01;
    barracks.queue.push(queue("rifle_squad"));
    let mut enemy = soldier(1, 1., Life::Alive);
    enemy.identity.team = 1;
    let mut tree = structure(32, "tree", 12.);
    tree.team = -1;
    tree.tick_timer = 4.;
    let mut unfinished = structure(33, "barracks", -12.);
    unfinished.built = false;
    unfinished.tick_timer = 3.;
    let mut s = fixture::Scene::new(
        vec![
            actor(mine),
            actor(barracks),
            Actor::Soldier(Box::new(enemy)),
            actor(tree),
            actor(unfinished),
        ],
        73,
    );
    let out = run(&mut s, &mut Rules::default(), 100);
    assert!(s.world.actors.structure(31).is_none());
    assert!(!out.iter().any(|e| matches!(e, Event::Production(_))));
    assert_eq!(s.world.actors.structure(32).unwrap().tick_timer, 4.);
    assert_eq!(s.world.actors.structure(33).unwrap().tick_timer, 3.);
}
#[test]
fn mixed_building_passes_resume_with_identical_shared_state() {
    let mut a = structure(30, "barracks", -8.);
    a.queue.push(queue("rifle_squad"));
    let mut town = structure(31, "town", 8.);
    town.supply = 13.7;
    let tent = structure(32, "medic_tent", 0.);
    let mut s = fixture::Scene::new(vec![actor(a), actor(town), actor(tent)], 74);
    let mut r = Rules::default();
    for _ in 0..6 {
        let mut resumed = s.resume();
        let mut rr = Rules::restore(&r.checkpoint().unwrap()).unwrap();
        assert_eq!(run(&mut s, &mut r, 100), run(&mut resumed, &mut rr, 100));
        s.world.compare(&resumed.world);
        assert_eq!(r, rr);
        assert_eq!(s.next, resumed.next);
        assert_eq!(s.world.squads, resumed.world.squads);
    }
}
