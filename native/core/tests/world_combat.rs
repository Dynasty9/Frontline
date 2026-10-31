#[allow(dead_code)]
#[path = "fixtures/vehicle_loss_world.rs"]
mod fixture;
use fixture::{shared, vehicle, Scene};
use frontline_core::actors::Actor;
use frontline_core::battle_stats::{BLD_KILLS, BLD_LOST};
use frontline_core::infantry::Credit;
use frontline_core::infantry_vitals::Life;
use frontline_core::structure_damage::Event as StructureEvent;
use frontline_core::supply_network::SupplyNetwork;
use frontline_core::vector::Vector3;
use frontline_core::vehicle::Vehicle;
use frontline_core::vehicle_damage::Armor;
use frontline_core::vehicle_loss_world::Event as Loss;
use frontline_core::world_combat::{Event, Explosion};

fn armor(v: &Vehicle) -> Armor {
    Armor {
        level: 0,
        helicopter: v.kind == "heli",
        boat: v.kind == "boat",
        supply: v.kind == "supply",
        toss: 1.3,
    }
}

#[test]
fn fatal_blasts_finish_vehicle_wrecks_before_structure_damage() {
    let mut s = Scene::new(vec![vehicle(20, "robot")], 137);
    let mut network = SupplyNetwork::default();
    let events = s
        .context()
        .explode(
            Explosion {
                damage: Some(1000.0),
                ..Default::default()
            },
            &mut network,
            &mut vec![],
            &armor,
        )
        .unwrap();
    let (born, wreck) = events
        .iter()
        .enumerate()
        .find_map(|(i, e)| match e {
            Event::Vehicle(Loss::Wreck { id, .. }) => Some((i, *id)),
            _ => None,
        })
        .unwrap();
    let hit = events
        .iter()
        .position(|e| matches!(e, Event::Structure { id, .. } if *id == wreck))
        .unwrap();
    assert!(born < hit);
    let damaged_wreck = s.world.actors.structure(wreck).unwrap();
    assert!(damaged_wreck.hp < damaged_wreck.max_hp);
    assert!(s.world.geometry.pending_removals().contains(&20));
    assert!(!s.world.geometry.pending_removals().contains(&wreck));
}

#[test]
fn lost_fob_credit_and_town_routes_change_before_the_next_hit() {
    let mut depot = shared::structure(10, "depot", -12.0);
    depot.smashable = false;
    let mut fob = shared::structure(11, "fob", -3.0);
    fob.smashable = false;
    fob.name = "Oak".into();
    let mut town = shared::structure(12, "town", 8.0);
    town.smashable = false;
    let mut s = Scene::new(
        vec![
            shared::actor(depot),
            shared::actor(fob),
            shared::actor(town),
        ],
        137,
    );
    let mut network = SupplyNetwork {
        depots: [10, 0],
        towns: vec![12],
        ..Default::default()
    };
    network
        .rebuild(0, &mut s.world.actors, &mut s.world.geometry)
        .unwrap();
    s.world
        .battle
        .set_blame(Some(Credit {
            owner: 8,
            team: 1,
            unit: String::new(),
            soldier: 0,
        }))
        .unwrap();
    let events = s
        .context()
        .damage_structure(11, 150.0, 0, &mut network)
        .unwrap();
    assert!(events.iter().any(|e| matches!(e, Event::Structure { damage, .. } if damage.events.contains(&StructureEvent::FobWrecked))));
    assert!(s.world.actors.structure(11).unwrap().wrecked);
    assert_eq!(
        s.world.actors.structure(12).unwrap().supply_status,
        "No FOB"
    );
    assert!(s.world.actors.structure(12).unwrap().road.is_empty());
    assert_eq!(s.world.battle.sides[0][BLD_LOST], 1.0);
    assert_eq!(s.world.battle.sides[1][BLD_KILLS], 1.0);
    let saved = s.world.battle.checkpoint();
    assert!(s
        .context()
        .damage_structure(11, 150.0, 0, &mut network)
        .unwrap()
        .is_empty());
    assert_eq!(s.world.battle.checkpoint(), saved);
}

#[test]
fn door_opening_updates_collision_even_when_the_wall_dies_in_the_same_hit() {
    let mut wall = shared::structure(10, "house_wall", 0.0);
    wall.door_closed = true;
    wall.parts[0].door = true;
    let mut s = Scene::new(vec![shared::actor(wall)], 137);
    s.world
        .geometry
        .doors
        .insert_door(10, Vector3::ZERO)
        .unwrap();
    assert!(s
        .world
        .geometry
        .collision
        .ray(
            Vector3::new(-2.0, 1.0, -2.0),
            Vector3::new(2.0, 1.0, 2.0),
            &[]
        )
        .is_some());
    let events = s
        .context()
        .damage_structure(10, 150.0, 0, &mut SupplyNetwork::default())
        .unwrap();
    assert!(events
        .iter()
        .any(|e| matches!(e, Event::Stat("door_kicked"))));
    assert!(s.world.geometry.doors.membership(10).is_empty());
    assert!(s
        .world
        .geometry
        .collision
        .ray(
            Vector3::new(-2.0, 1.0, -2.0),
            Vector3::new(2.0, 1.0, 2.0),
            &[]
        )
        .is_none());
}

#[test]
fn heavy_impacts_precede_casualties_and_restore_surrounding_blame() {
    let mut man = shared::soldier(1, 0.0, Life::Alive);
    man.identity.squad = 7;
    let mut s = Scene::new(vec![Actor::Soldier(Box::new(man))], 137);
    s.world.squads.push(frontline_core::squad::Squad {
        id: 7,
        members: vec![1],
        ..Default::default()
    });
    let previous = Some(Credit {
        owner: 8,
        team: 1,
        unit: String::new(),
        soldier: 0,
    });
    s.world.battle.set_blame(previous.clone()).unwrap();
    let mut impacts = vec![frontline_core::squad::Report {
        position: Vector3::ONE,
        time: 1.0,
    }];
    s.context()
        .explode(
            Explosion {
                top: true,
                damage: Some(2000.0),
                owner: 7,
                team: 0,
                ..Default::default()
            },
            &mut SupplyNetwork::default(),
            &mut impacts,
            &armor,
        )
        .unwrap();
    assert_eq!(impacts.len(), 1);
    assert_eq!(s.world.squads[0].impacts, impacts);
    assert_eq!(s.world.battle.blame, previous);
    assert_eq!(s.world.actors.soldier(1).unwrap().vitals.life, Life::Dead);
}

#[test]
fn connected_explosions_resume_without_changing_any_shared_state_or_event() {
    let mut a = Scene::new(
        vec![
            vehicle(20, "tank"),
            shared::actor(shared::structure(30, "car", 4.3)),
            Actor::Soldier(Box::new(shared::soldier(1, 2.0, Life::Alive))),
        ],
        137,
    );
    let mut b = a.resume();
    let (mut na, mut nb) = (SupplyNetwork::default(), SupplyNetwork::default());
    let (mut ia, mut ib) = (vec![], vec![]);
    for step in 0..5 {
        let blast = Explosion {
            position: Vector3::new(step as f32 * 0.3, 0.0, 0.7),
            damage: Some(130.0),
            size: 2.1,
            top: true,
            ..Default::default()
        };
        assert_eq!(
            a.context()
                .explode(blast, &mut na, &mut ia, &armor)
                .unwrap(),
            b.context()
                .explode(blast, &mut nb, &mut ib, &armor)
                .unwrap()
        );
        a.world.compare(&b.world);
        assert_eq!(a.world.squads, b.world.squads);
        assert_eq!(a.fires, b.fires);
        assert_eq!(a.next, b.next);
        assert_eq!(na, nb);
        assert_eq!(ia, ib);
        a.world.geometry.finish_tick();
        b.world.geometry.finish_tick();
        b = b.resume();
        nb = SupplyNetwork::restore(&nb.checkpoint().unwrap()).unwrap();
    }
}

#[test]
fn invalid_explosions_reject_before_changing_state_or_randomness() {
    let mut s = Scene::new(vec![vehicle(20, "tank")], 137);
    let before = s.resume();
    let mut n = SupplyNetwork::default();
    let mut impacts = vec![];
    assert!(!Explosion {
        damage: Some(1_000_000.0),
        structure_multiplier: 1_000_000.0,
        ..Default::default()
    }
    .valid());
    for radius in [0.0, f64::NAN, f64::INFINITY, 8193.0] {
        assert!(s
            .context()
            .explode(
                Explosion {
                    radius,
                    ..Default::default()
                },
                &mut n,
                &mut impacts,
                &armor
            )
            .is_err());
        s.world.compare(&before.world);
        assert_eq!(s.fires, before.fires);
        assert!(impacts.is_empty());
    }
}

#[test]
fn missing_throwers_use_the_commanders_credit_and_restore_outer_blame() {
    let mut s = Scene::new(vec![vehicle(20, "robot")], 137);
    let prior = Some(Credit {
        owner: 7,
        team: 0,
        unit: String::new(),
        soldier: 0,
    });
    s.world.battle.set_blame(prior.clone()).unwrap();
    s.context()
        .explode(
            Explosion {
                source: 999,
                owner: 8,
                team: 1,
                damage: Some(1000.0),
                ..Default::default()
            },
            &mut SupplyNetwork::default(),
            &mut vec![],
            &armor,
        )
        .unwrap();
    assert_eq!(
        s.world.battle.sides[1][frontline_core::battle_stats::VEH_KILLS],
        1.0
    );
    assert_eq!(s.world.battle.blame, prior);
}

#[test]
fn deferred_explosions_finish_before_all_new_rubble_is_registered() {
    let mut wall = shared::structure(10, "house_wall", 0.0);
    wall.size.x = 7.0;
    let mut s = Scene::new(vec![shared::actor(wall)], 137);
    s.world
        .deferred
        .cook_off(99.9, Vector3::ZERO, 160.0, &mut s.world.rng)
        .unwrap();
    let mut b = s.resume();
    let mut network = SupplyNetwork::default();
    let mut other = network.clone();
    let a = s
        .context()
        .flush_deferred(&mut network, &mut vec![], &armor)
        .unwrap();
    let resumed = b
        .context()
        .flush_deferred(&mut other, &mut vec![], &armor)
        .unwrap();
    assert_eq!(a, resumed);
    s.world.compare(&b.world);
    let blast = a
        .iter()
        .position(|e| matches!(e, Event::Explosion { .. }))
        .unwrap();
    let rubble = a
        .iter()
        .position(|e| matches!(e, Event::Rubble(_)))
        .unwrap();
    assert!(blast < rubble);
    assert!(s.world.actors.structure(10).is_none());
    assert!(s.world.deferred.pending().count() > 0);
    assert!(s
        .context()
        .flush_deferred(&mut network, &mut vec![], &armor)
        .unwrap()
        .is_empty());
}
