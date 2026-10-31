#[allow(dead_code)]
#[path = "fixtures/vehicle_loss_world.rs"]
mod fixture;
use fixture::{shared, vehicle, Scene};
use frontline_core::actors::Actor;
use frontline_core::bullet::Weapon;
use frontline_core::bullet_world::{Gunfire, Shot};
use frontline_core::infantry_vitals::Life;
use frontline_core::squad::Squad;
use frontline_core::supply_network::SupplyNetwork;
use frontline_core::vector::Vector3;
use frontline_core::vehicle::Vehicle;
use frontline_core::vehicle_damage::Armor;
use frontline_core::vehicle_loss_world::Event as Loss;
use frontline_core::world_combat::Event;

fn armor(v: &Vehicle) -> Armor {
    Armor {
        level: if v.kind == "tank" { 2 } else { 0 },
        helicopter: false,
        boat: false,
        supply: false,
        toss: 1.0,
    }
}
fn shot() -> Shot<'static> {
    Shot {
        shooter: 1,
        target: 2,
        muzzle: Vector3::new(-10.0, 1.0, 0.0),
        aim: Vector3::new(10.0, 1.0, 0.0),
        weapon: Weapon {
            accuracy: 1.0,
            range: 80.0,
            damage: 30.0,
            anti_air: false,
            penetration: 0,
            drone_accuracy: 0.03,
            explosive_radius: None,
            airburst: false,
        },
        accuracy: 10.0,
        optics: false,
        piercing: false,
        suppression: 12.0,
        sound: "rifle",
    }
}
fn scene(seed: u64) -> Scene {
    let mut a = shared::soldier(1, -10.0, Life::Alive);
    a.identity.squad = 1;
    let mut b = shared::soldier(2, 10.0, Life::Alive);
    b.identity.team = 1;
    b.identity.owner = 8;
    b.identity.squad = 2;
    let mut s = Scene::new(
        vec![Actor::Soldier(Box::new(a)), Actor::Soldier(Box::new(b))],
        seed,
    );
    s.world.squads = (1..=2)
        .map(|id| Squad {
            id,
            team: (id - 1) as i8,
            owner: 6 + id as i32,
            members: vec![id],
            ..Default::default()
        })
        .collect();
    s
}
fn fire(s: &mut Scene, input: Shot<'_>, g: &mut Gunfire) -> Vec<Event> {
    s.context()
        .fire_bullet(
            input,
            g,
            &mut SupplyNetwork::default(),
            &mut vec![],
            &armor,
            &|_| 2.0,
        )
        .unwrap()
}

#[test]
fn direct_hit_records_damage_before_shot_and_reveals_once_per_cooldown() {
    let mut s = scene(137);
    let mut g = Gunfire::default();
    let events = fire(&mut s, shot(), &mut g);
    assert!(s.world.actors.soldier(2).unwrap().vitals.hp < 100.0);
    assert!(matches!(
        events.first(),
        Some(Event::InfantryHit { id: 2, .. })
    ));
    assert!(matches!(
        events.last(),
        Some(Event::Shot {
            hit: true,
            impact: 2,
            ..
        })
    ));
    assert_eq!(g.reveals()[&1], 101.5);
    // An unaimed shot cannot independently report the shooter through a victim's damage callback.
    let mut miss = shot();
    miss.target = 0;
    miss.aim.z = 30.0;
    s.world.now = 101.5;
    fire(&mut s, miss, &mut g);
    assert_eq!(g.reveals()[&1], 101.5);
    s.world.now += 0.01;
    fire(&mut s, miss, &mut g);
    assert_eq!(g.reveals()[&1], 103.01);
}

#[test]
fn heavy_ap_finishes_destruction_before_ricochet_without_shooter_credit() {
    let mut covered = false;
    for seed in 0..32 {
        let mut s = scene(seed);
        let mut entries = s.world.actors.iter().cloned().collect::<Vec<_>>();
        let mut v = vehicle(20, "tank");
        if let Actor::Vehicle(v) = &mut v {
            v.team = 1;
            v.owner = 8;
            v.hp = 2.0;
        }
        entries.push(v);
        s = Scene::new(entries, seed);
        let mut input = shot();
        input.target = 20;
        input.aim = Vector3::Y;
        input.piercing = true;
        let events = fire(&mut s, input, &mut Gunfire::default());
        let wreck = events
            .iter()
            .position(|e| matches!(e, Event::Vehicle(Loss::Wreck { .. })))
            .unwrap();
        assert_eq!(
            s.world.battle.sides[0][frontline_core::battle_stats::VEH_KILLS],
            0.0
        );
        if let Some(ricochet) = events
            .iter()
            .position(|e| matches!(e, Event::Ricochet { .. }))
        {
            assert!(wreck < ricochet);
            covered = true;
        }
    }
    assert!(covered);
}

#[test]
fn repeated_shots_resume_all_shared_state_and_effects_exactly() {
    let mut a = scene(7137);
    let mut ga = Gunfire::default();
    let mut network_a = SupplyNetwork::default();
    let mut impacts_a = vec![];
    for tick in 0..12 {
        let mut b = a.resume();
        let mut gb = Gunfire::restore(&ga.checkpoint()).unwrap();
        let mut network_b = SupplyNetwork::restore(&network_a.checkpoint().unwrap()).unwrap();
        let mut impacts_b = impacts_a.clone();
        let mut input = shot();
        input.accuracy = 0.6;
        input.weapon.explosive_radius = Some(2.2);
        input.aim.z = tick as f32 * 0.17;
        let ea = a
            .context()
            .fire_bullet(
                input,
                &mut ga,
                &mut network_a,
                &mut impacts_a,
                &armor,
                &|_| 2.0,
            )
            .unwrap();
        let eb = b
            .context()
            .fire_bullet(
                input,
                &mut gb,
                &mut network_b,
                &mut impacts_b,
                &armor,
                &|_| 2.0,
            )
            .unwrap();
        assert_eq!(ea, eb);
        a.world.compare(&b.world);
        assert_eq!(a.fires.checkpoint(), b.fires.checkpoint());
        assert_eq!(ga, gb);
        assert_eq!(network_a, network_b);
        assert_eq!(impacts_a, impacts_b);
        a.world.now += 0.2;
    }
}

#[test]
fn invalid_shot_and_checkpoint_leave_state_and_random_cursor_unchanged() {
    let mut s = scene(137);
    let mut g = Gunfire::default();
    let before = s.resume();
    for input in [
        Shot {
            suppression: f64::NAN,
            ..shot()
        },
        Shot {
            shooter: 0,
            ..shot()
        },
        Shot {
            target: 999,
            ..shot()
        },
    ] {
        assert!(s
            .context()
            .fire_bullet(
                input,
                &mut g,
                &mut SupplyNetwork::default(),
                &mut vec![],
                &armor,
                &|_| 2.0
            )
            .is_err());
        s.world.compare(&before.world);
        assert!(g.reveals().is_empty());
    }
    fire(&mut s, shot(), &mut g);
    let bytes = g.checkpoint();
    for n in 0..bytes.len() {
        assert!(Gunfire::restore(&bytes[..n]).is_err());
    }
    let mut bad = bytes.clone();
    bad.push(0);
    assert!(Gunfire::restore(&bad).is_err());
    let mut bad = bytes;
    bad[12..16].copy_from_slice(&0_u32.to_le_bytes());
    assert!(Gunfire::restore(&bad).is_err());
}

#[test]
fn drone_hits_remove_live_targets_once_and_ignore_already_destroyed_ones() {
    use frontline_core::drone::DroneFlight;
    use frontline_core::drone_actor::Drone;
    for dead in [false, true] {
        let a = shared::soldier(1, -10.0, Life::Alive);
        let mut flight = DroneFlight::new(Vector3::new(10.0, 1.0, 0.0), 0.0);
        flight.dead = dead;
        let drone = Drone {
            id: 2,
            team: 1,
            operator: 0,
            target: 0,
            operator_at_spawn: 0,
            target_at_spawn: 0,
            warhead: 1.0,
            flight,
        };
        let mut s = Scene::new(vec![Actor::Soldier(Box::new(a)), Actor::Drone(drone)], 137);
        let mut input = shot();
        input.weapon.drone_accuracy = 2.0;
        let events = fire(&mut s, input, &mut Gunfire::default());
        assert_eq!(s.world.actors.get(2).is_none(), !dead);
        assert_eq!(
            events
                .iter()
                .filter(|e| matches!(e, Event::DroneDown { .. }))
                .count(),
            usize::from(!dead)
        );
        assert!(matches!(
            events.last(),
            Some(Event::Shot {
                hit: true,
                impact: 3,
                ..
            })
        ));
    }
}
