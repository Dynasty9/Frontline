#[allow(dead_code)]
#[path = "fixtures/vehicle_loss_world.rs"]
mod fixture;
use fixture::{shared, vehicle, Scene};
use frontline_core::actors::Actor;
use frontline_core::battle_stats::{DAMAGE, VEH_KILLS, VEH_LOST};
use frontline_core::infantry::Credit;
use frontline_core::infantry_vitals::Life;
use frontline_core::squad_movement;
use frontline_core::vector::Vector3;
use frontline_core::vehicle::LastBlast;
use frontline_core::vehicle_loss_world::Event;

#[test]
fn losses_credit_the_attacker_once_and_create_burning_wrecks() {
    let mut attacker = shared::soldier(1, -10.0, Life::Alive);
    attacker.identity.team = 1;
    attacker.identity.owner = 8;
    let mut s = Scene::new(
        vec![vehicle(20, "tank"), Actor::Soldier(Box::new(attacker))],
        137,
    );
    let events = s.damage(20, 61.0, 1).unwrap();
    assert!(matches!(events.as_slice(), [Event::UnderFire(_)]));
    assert_eq!(s.world.battle.sides[1][DAMAGE], 61.0);
    let events = s.damage(20, 50.0, 1).unwrap();
    assert_eq!(s.world.battle.sides[1][DAMAGE], 100.0);
    assert_eq!(s.world.battle.sides[1][VEH_KILLS], 1.0);
    assert_eq!(s.world.battle.sides[0][VEH_LOST], 1.0);
    assert!(s.world.actors.vehicle(20).is_none());
    let wreck = events
        .iter()
        .find_map(|e| {
            if let Event::Wreck { id, .. } = e {
                Some(*id)
            } else {
                None
            }
        })
        .unwrap();
    let st = s.world.actors.structure(wreck).unwrap();
    assert_eq!(
        (st.kind.as_str(), st.variant, st.wreck_kind.as_str()),
        ("wreck", 6, "tank")
    );
    assert!(st.burn > 0.0 && s.fires.burning().iter().any(|b| b.structure == wreck));
    let before = s.world.battle.checkpoint();
    assert!(s.damage(20, 999.0, 1).unwrap().is_empty());
    assert_eq!(before, s.world.battle.checkpoint());
}

#[test]
fn returning_crew_refund_the_fob_before_wreck_ignition() {
    let mut returned = 0;
    for seed in 0..16 {
        let mut fob = shared::structure(30, "fob", -9.0);
        fob.supply = 100.0;
        let mut s = Scene::new(vec![vehicle(20, "tank"), shared::actor(fob)], seed);
        let events = s.damage(20, 110.0, 0).unwrap();
        if let Some((index, survivors)) = events.iter().enumerate().find_map(|(i, e)| match e {
            Event::Bailout { survivors, .. } => Some((i, survivors)),
            _ => None,
        }) {
            returned += 1;
            let home = events
                .iter()
                .position(|e| matches!(e, Event::Squad(squad_movement::Event::CrewHome { .. })))
                .unwrap();
            let wreck = events
                .iter()
                .position(|e| matches!(e, Event::Wreck { .. }))
                .unwrap();
            let fire = events
                .iter()
                .position(|e| matches!(e, Event::Fire(_)))
                .unwrap();
            assert!(index < home && home < wreck && wreck < fire);
            assert_eq!(
                s.world.actors.structure(30).unwrap().supply,
                100.0 + (500.0 * 0.12 * survivors.len() as f64 / 3.0).trunc()
            );
            assert!(survivors
                .iter()
                .all(|id| s.world.actors.soldier(*id).is_none()));
            assert!(s.world.squads[0].members.is_empty());
            assert_eq!(s.world.battle.units[0].men, survivors.len() as u32);
        }
    }
    assert!(returned > 10);
}

#[test]
fn supply_losses_update_the_matching_town_or_destination_fob() {
    for source_town in [true, false] {
        let mut town = shared::structure(30, if source_town { "town" } else { "fob" }, -10.0);
        town.truck = 20;
        let mut v = vehicle(20, "supply");
        if let Actor::Vehicle(v) = &mut v {
            v.source_town = if source_town { 30 } else { 0 };
            v.destination_fob = 30;
            v.cargo = 71;
        }
        let mut s = Scene::new(vec![v, shared::actor(town)], 3);
        let events = s.damage(20, 101.0, 0).unwrap();
        assert!(events
            .iter()
            .any(|e| matches!(e, Event::TruckLost { cargo: 71, .. })));
        assert!(!events.iter().any(|e| matches!(e, Event::Bailout { .. })));
        let town = s.world.actors.structure(30).unwrap();
        assert_eq!(town.truck, 0);
        assert_eq!(town.truck_timer, if source_town { 20.0 } else { 28.0 });
        assert_eq!(town.supply_status, "Truck destroyed");
    }
}

#[test]
fn sinking_evacuates_passengers_without_a_wreck_or_crew_and_preserves_blame() {
    let mut v = vehicle(20, "boat");
    if let Actor::Vehicle(v) = &mut v {
        v.passengers = vec![1, 2];
    }
    let men = [1, 2].map(|id| {
        let mut s = shared::soldier(id, 0.0, Life::Hidden);
        s.links.vehicle = 20;
        Actor::Soldier(Box::new(s))
    });
    let mut s = Scene::new(vec![v, men[0].clone(), men[1].clone()], 37);
    s.world.battle.blame = Some(Credit {
        owner: 8,
        team: 1,
        unit: "v9".into(),
        soldier: 0,
    });
    let events = s.damage(20, 101.0, 0).unwrap();
    assert_eq!(
        events
            .iter()
            .filter(|e| matches!(e, Event::Passenger { .. }))
            .count(),
        2
    );
    assert!(events.iter().any(|e| matches!(e, Event::Sunk { .. })));
    assert!(!events
        .iter()
        .any(|e| matches!(e, Event::Wreck { .. } | Event::Bailout { .. })));
    assert_eq!(s.world.battle.blame.as_ref().unwrap().unit, "v9");
    for id in [1, 2] {
        assert_ne!(
            s.world.actors.soldier(id).unwrap().vitals.life,
            Life::Hidden
        );
        assert_eq!(s.world.actors.soldier(id).unwrap().links.vehicle, 0);
    }
}

#[test]
fn sling_cargo_destruction_finishes_before_the_carriers_wreck() {
    let mut carrier = vehicle(20, "heli");
    let mut cargo = vehicle(21, "robot");
    if let Actor::Vehicle(v) = &mut carrier {
        v.position.y = 30.0;
        v.sling_cargo = 21;
    }
    if let Actor::Vehicle(v) = &mut cargo {
        v.position.y = 27.0;
        v.hp = 20.0;
        v.slung_by = 20;
    }
    let mut s = Scene::new(vec![carrier, cargo], 137);
    let v = s.world.actors.vehicle(21).unwrap();
    s.world
        .geometry
        .refresh_vehicle_collision(v, Vector3::new(3.0, 2.0, 5.0))
        .unwrap();
    let events = s.damage(20, 101.0, 0).unwrap();
    let cargo_dead = events
        .iter()
        .position(|e| matches!(e, Event::Despawn(21)))
        .unwrap();
    let carrier_dead = events
        .iter()
        .position(|e| matches!(e, Event::Despawn(20)))
        .unwrap();
    assert!(cargo_dead < carrier_dead);
    assert_eq!(s.fires.burning().len(), 2);
    assert_eq!(s.world.battle.sides[0][VEH_LOST], 2.0);
    assert_eq!(
        s.world.geometry.collision.shape(21, 0).unwrap().center.y,
        1.0
    );
    assert!(s.world.geometry.pending_removals().contains(&21));
    s.world.geometry.finish_tick();
    assert!(!s.world.geometry.collision.contains(21));
}

#[test]
fn resumed_destruction_reproduces_all_state_and_effects() {
    for seed in 0..24 {
        let mut v = vehicle(20, "tank");
        if let Actor::Vehicle(v) = &mut v {
            v.last_blast = Some(LastBlast {
                position: Vector3::new(-1.3, 0.0, 0.7),
                size: 2.7,
                time: 99.8,
            });
        }
        let mut a = Scene::new(vec![v], seed);
        let mut b = a.resume();
        assert_eq!(
            a.damage(20, 123.0, 0).unwrap(),
            b.damage(20, 123.0, 0).unwrap()
        );
        a.world.compare(&b.world);
        assert_eq!(a.fires.checkpoint(), b.fires.checkpoint());
        assert_eq!(a.next, b.next);
        assert_eq!(a.world.squads, b.world.squads);
    }
}

#[test]
fn invalid_damage_is_rejected_before_changing_any_state() {
    let mut s = Scene::new(vec![vehicle(20, "tank")], 1);
    let before = s.resume();
    for amount in [-1.0, f64::NAN, f64::INFINITY, 1e13] {
        assert!(s.damage(20, amount, 0).is_err());
    }
    s.world.compare(&before.world);
    assert_eq!(s.fires.checkpoint(), before.fires.checkpoint());
}
