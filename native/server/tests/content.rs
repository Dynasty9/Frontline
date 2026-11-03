use frontline_core as sim;
use frontline_server::content::Content;
use sim::actors::Actor;
use sim::infantry::Infantry;
use sim::match_state::MatchState;
use sim::perception::PerceptionSearch;
use sim::vector::Vector3;

fn empty() -> MatchState {
    let terrain = sim::terrain::Terrain::blank(64).unwrap();
    let deck = vec![0; 64 * 64];
    let boats = sim::boat_navigation::BoatNavigation::from_terrain(&terrain, &deck).unwrap();
    let geometry = sim::world_geometry::WorldGeometry::new(terrain, deck, 16).unwrap();
    let water = sim::water::Water {
        side: 64,
        coast: None,
        rivers: vec![],
        ponds: vec![],
        fords: vec![],
        bridges: vec![],
    };
    let mut state = MatchState::empty(geometry, water, boats, 137, false).unwrap();
    state.scenario = true;
    state
}

#[test]
fn baked_content_resolves_every_unit_squad_building_and_support() {
    let c = Content::bundled().unwrap();
    assert_eq!(
        c.loadouts.len(),
        c.definitions["units"].as_object().unwrap().len()
    );
    for key in c.definitions["weapons"].as_object().unwrap().keys() {
        assert!(c.weapon(key).is_some(), "{key}");
    }
    for key in c.definitions["buildings"].as_object().unwrap().keys() {
        assert!(c.building(key).unwrap().valid(), "{key}");
    }
    for key in c.definitions["support"].as_object().unwrap().keys() {
        assert!(c.support(key).unwrap().valid(), "{key}");
    }
    for key in c.definitions["squads"].as_object().unwrap().keys() {
        assert!(!c.squad(key).unwrap().members.is_empty(), "{key}");
    }
    assert!(
        c.building("missing").is_none()
            && c.vehicle_birth("missing").is_none()
            && c.support("missing").is_none()
    );
}

#[test]
fn each_production_vehicle_advances_without_a_godot_callback_and_resumes_exactly() {
    let c = Content::bundled().unwrap();
    c.with_profiles(&[], |p, _| {
        for (key, d) in c.definitions["vehicles"].as_object().unwrap() {
            let mut a = empty();
            a.field
                .geometry
                .spawn_vehicle(
                    &mut a.field.actors,
                    sim::vehicle_birth::Spawn {
                        team: d["team"].as_i64().unwrap().max(0) as i8,
                        owner: 0,
                        position: Vector3::ZERO,
                        yaw: 0.,
                    },
                    c.vehicle_birth(key).unwrap(),
                )
                .unwrap();
            let mut b = MatchState::restore(&a.checkpoint().unwrap()).unwrap();
            let mut ac = PerceptionSearch::default();
            let mut bc = PerceptionSearch::default();
            for _ in 0..3 {
                assert_eq!(
                    a.advance_battlefield(p, &mut ac)
                        .unwrap_or_else(|e| panic!("{key}: {e}")),
                    b.advance_battlefield(p, &mut bc).unwrap(),
                    "{key}"
                );
                assert_eq!(
                    a.finish_battlefield(p).unwrap(),
                    b.finish_battlefield(p).unwrap(),
                    "{key}"
                );
            }
            assert_eq!(a.checkpoint().unwrap(), b.checkpoint().unwrap(), "{key}");
        }
    });
}

#[test]
fn every_unit_uses_the_production_weapon_and_supply_definitions() {
    let c = Content::bundled().unwrap();
    c.with_profiles(&[], |p, _| {
        for (key, loadout) in &c.loadouts {
            let mut a = empty();
            let s = Infantry::from_spawn(
                1,
                sim::infantry_spawn::Spawn {
                    team: 0,
                    owner: 0,
                    position: Vector3::ZERO,
                    yaw: 0.,
                    name: "Test".into(),
                    squad: 0,
                    life: sim::infantry_vitals::Life::Alive,
                    posture: sim::infantry_pose::Posture::Stand,
                    armor_upgrade: false,
                    grenade_upgrade: false,
                },
                loadout,
                &mut a.field.rng,
            )
            .unwrap();
            let expected = c.weapon(&loadout.weapon).map(|w| w.fire.weapon.ammunition);
            assert_eq!((p.buildings.supply)(&s).ammunition, expected, "{key}");
            a.field.actors.spawn(Actor::Soldier(Box::new(s))).unwrap();
            a.advance_battlefield(p, &mut PerceptionSearch::default())
                .unwrap_or_else(|e| panic!("{key}: {e}"));
            a.finish_battlefield(p).unwrap();
            MatchState::restore(&a.checkpoint().unwrap()).unwrap();
        }
    });
}

#[test]
fn passenger_capacity_matches_explicit_seats_or_the_carried_squad() {
    let c = Content::bundled().unwrap();
    assert_eq!(
        c.seats("ghosthawk"),
        c.members["rifle_squad"].len().max(4) as u32
    );
    assert_eq!(c.seats("rhib"), 6);
    assert_eq!(c.seats("tank"), 0);
    c.with_profiles(&[], |p, commands| {
        for kind in c.definitions["vehicles"].as_object().unwrap().keys() {
            let v = sim::vehicle::Vehicle {
                kind: kind.clone(),
                ..Default::default()
            };
            assert_eq!((p.infantry.transport)(&v).seats, c.seats(kind));
            assert_eq!((commands.vehicle)(&v).seats, c.seats(kind) as i32);
        }
    });
}
