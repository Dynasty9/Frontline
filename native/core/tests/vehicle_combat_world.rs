#[allow(dead_code)]
#[path = "fixtures/vehicle_combat_world.rs"]
mod fixture;
use fixture::{infantry, profile, vehicle, Field};
use frontline_core::actors::Actor;
use frontline_core::infantry_action_owned::Event as Ordnance;
use frontline_core::infantry_fight_world::Event as Combat;
use frontline_core::infantry_vitals::Life;
use frontline_core::projectile::Kind;
use frontline_core::random::SimulationRandom;
use frontline_core::vector::Vector3;
use frontline_core::vehicle_artillery::ArtilleryProfile;
use frontline_core::vehicle_combat_world::Event;
use frontline_core::vehicle_service::{Service, SoldierSupply};
use frontline_core::world_combat;
#[test]
fn machine_gun_damage_and_burst_recovery_resume_together() {
    let mut v = vehicle(20, 0, 10.0);
    v.target = 1;
    let mut w = Field::new(v, infantry(Life::Alive));
    let mut resumed = w.resume();
    let out = w.fire(profile(false)).unwrap();
    assert_eq!(out, resumed.fire(profile(false)).unwrap());
    w.compare(&resumed);
    assert!(out.iter().any(|e| matches!(
        e,
        Event::Combat(Combat::World(world_combat::Event::Shot { shooter: 20, .. }))
    )));
    assert!(w.scene.world.actors.vehicle(20).unwrap().mg_timer >= 0.6);
    assert!(w.scene.world.battle.sides[0][frontline_core::battle_stats::SHOTS] > 0.0);
}
#[test]
fn cannon_impacts_apply_shared_destruction_and_cooldown() {
    let mut v = vehicle(20, 0, 10.0);
    v.target = 30;
    let mut st = fixture::shared::structure(30, "sandbags", 0.0);
    st.position.z = -10.0;
    st.hp = 1.0;
    st.team = 1;
    let mut w = Field::new(v, Actor::Structure(Box::new(st)));
    let mut resumed = w.resume();
    let out = w.fire(profile(true)).unwrap();
    assert_eq!(out, resumed.fire(profile(true)).unwrap());
    w.compare(&resumed);
    assert!(out
        .iter()
        .any(|e| matches!(e, Event::Cannon { vehicle: 20, .. })));
    assert!(w.scene.world.actors.structure(30).is_none());
    assert_eq!(w.scene.world.actors.vehicle(20).unwrap().cannon_timer, 5.5);
}
#[test]
fn missiles_resolve_defensive_smoke_before_the_launch_event() {
    let mut v = vehicle(20, 0, 12.0);
    v.target = 21;
    v.atgm_left = 2;
    let target = vehicle(21, 1, -12.0);
    let mut w = Field::new(v, Actor::Vehicle(Box::new(target)));
    let out = w.fire(profile(true)).unwrap();
    let smoke = out
        .iter()
        .position(|e| matches!(e, Event::Combat(Combat::Ordnance(Ordnance::Smoke { .. }))))
        .unwrap();
    let launch = out
        .iter()
        .position(|e| matches!(e, Event::Combat(Combat::Ordnance(Ordnance::Launch { .. }))))
        .unwrap();
    assert!(smoke < launch);
    assert_eq!(w.scene.world.actors.vehicle(20).unwrap().atgm_left, 1);
    assert_eq!(w.scene.world.actors.vehicle(21).unwrap().smoke_left, 1);
    assert!(w.scene.world.actors.vehicle(21).unwrap().path_pending);
}
#[test]
fn a_vehicle_does_not_shoot_a_wounded_target() {
    let mut v = vehicle(20, 0, 10.0);
    v.target = 1;
    let mut w = Field::new(v, infantry(Life::Downed));
    let before = w.resume();
    assert!(w.fire(profile(true)).unwrap().is_empty());
    w.compare(&before);
}
#[test]
fn artillery_orders_launch_attributed_shells_and_finish_the_salvo() {
    let mut v = vehicle(20, 0, 10.0);
    v.artillery_until = 0.0;
    v.fire_queue = vec![Vector3::Z * -10.0];
    let mut w = Field::new(v, infantry(Life::Alive));
    let p = ArtilleryProfile {
        shell: Kind::Arty,
        gun_height: 2.2,
        muzzle: 4.0,
        scatter: 3.0,
        salvo: 1,
        lay: 0.1,
        gap: 0.8,
        cooldown: 18.0,
        traverse: 1.0,
        traverse_accel: 2.0,
    };
    let a = w
        .scene
        .context()
        .advance_vehicle_artillery(20, 0.1, p, [40.0, 230.0], &[])
        .unwrap();
    assert!(
        a.contains(&Event::Combat(Combat::World(world_combat::Event::Stat(
            "arty_mission"
        ))))
    );
    let b = w
        .scene
        .context()
        .advance_vehicle_artillery(20, 0.2, p, [40.0, 230.0], &[])
        .unwrap();
    assert!(
        b.contains(&Event::Combat(Combat::World(world_combat::Event::Stat(
            "arty_round"
        ))))
    );
    assert_eq!(w.scene.world.actors.vehicle(20).unwrap().salvo, 0);
    assert!(w
        .scene
        .world
        .actors
        .iter()
        .any(|a| matches!(a,Actor::Projectile(p) if p.thrower==20 && p.team==0)));
}
#[test]
fn medical_service_credits_every_revival_in_the_world_ledger() {
    let mut revived = false;
    for seed in 0..16 {
        let v = vehicle(20, 1, 0.0);
        let mut w = Field::new(v, infantry(Life::Downed));
        w.scene.world.rng = SimulationRandom::new(seed);
        let out = w
            .scene
            .context()
            .advance_vehicle_service(
                20,
                0.1,
                Service::Medical,
                &|_| {
                    Ok(SoldierSupply {
                        loadout: None,
                        restored_weapon: Some(("rifle", 30)),
                    })
                },
                &|_| Ok([0, 0]),
            )
            .unwrap();
        if w.scene.world.actors.soldier(1).unwrap().vitals.life == Life::Alive {
            revived = true;
            assert_eq!(w.scene.world.battle.sides[1][23], 1.0);
            assert!(
                out.contains(&Event::Combat(Combat::World(world_combat::Event::Stat(
                    "veh_medevac_revive"
                ))))
            );
        }
    }
    assert!(revived);
}
#[test]
fn invalid_weapon_content_cannot_consume_the_burst_draw() {
    let mut v = vehicle(20, 0, 10.0);
    v.target = 1;
    let mut w = Field::new(v, infantry(Life::Alive));
    let before = w.resume();
    let mut p = profile(false);
    p.machine_gun.as_mut().unwrap().suppression = f64::NAN;
    assert!(w.fire(p).is_err());
    w.compare(&before);
}

#[test]
fn air_defense_launch_and_ammunition_resume_together() {
    let mut v = vehicle(20, 0, 12.0);
    v.target = 21;
    v.sam_left = 2;
    let mut target = vehicle(21, 1, -12.0);
    target.kind = "heli".into();
    target.position.y = 8.0;
    let mut w = Field::new(v, Actor::Vehicle(Box::new(target)));
    let mut resumed = w.resume();
    let out = w.fire(profile(true)).unwrap();
    assert_eq!(out, resumed.fire(profile(true)).unwrap());
    w.compare(&resumed);
    assert!(
        out.contains(&Event::Combat(Combat::World(world_combat::Event::Stat(
            "veh_sam"
        ))))
    );
    assert_eq!(w.scene.world.actors.vehicle(20).unwrap().sam_left, 1);
}

#[test]
fn explosive_machine_gun_finishes_its_random_draw_after_self_destruction() {
    let mut v = vehicle(20, 0, 0.0);
    v.target = 1;
    v.hp = 0.01;
    v.mg_burst = 1;
    let mut target = infantry(Life::Alive);
    if let Actor::Soldier(s) = &mut target {
        s.motion.position.z = -3.0;
    }
    let mut continuing = v.clone();
    continuing.mg_burst = 2;
    let mut control = Field::new(continuing, target.clone());
    let mut w = Field::new(v, target);
    let mut p = profile(false);
    let gun = p.machine_gun.as_mut().unwrap();
    gun.weapon.explosive_radius = Some(20.0);
    gun.weapon.damage = 1000.0;
    let mut resumed = w.resume();
    let out = w.fire(p).unwrap();
    assert_eq!(out, resumed.fire(p).unwrap());
    w.compare(&resumed);
    assert!(w.scene.world.actors.vehicle(20).is_none());
    assert_eq!(out, control.fire(p).unwrap());
    // Only the last round of a burst consumes a recovery draw after shared damage.
    control.scene.world.rng.randf_range(0.6, 1.3);
    w.compare(&control);
}
