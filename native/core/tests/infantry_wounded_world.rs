#[allow(dead_code)]
#[path = "fixtures/vehicle_loss_world.rs"]
mod fixture;
use fixture::{shared, Scene};
use frontline_core::actors::Actor;
use frontline_core::bullet_world::Gunfire;
use frontline_core::infantry::Credit;
use frontline_core::infantry_controller::Task;
use frontline_core::infantry_pose::Posture;
use frontline_core::infantry_vitals::Life;
use frontline_core::infantry_wounded_world::{Event, Input};
use frontline_core::squad::Squad;
use frontline_core::supply_network::SupplyNetwork;
use frontline_core::vehicle_damage::Armor;
use frontline_core::world_combat;

fn input() -> Input {
    Input {
        dt: 0.1,
        medicine: false,
        optics: false,
        gun: None,
    }
}
fn scene(bleed: f64, carried: bool) -> Scene {
    let mut s = shared::soldier(1, 0.0, Life::Downed);
    s.vitals.hp = 0.0;
    s.vitals.bleed = bleed;
    s.vitals.bleed_max = 50.0;
    s.vitals.downed_at = 90.0;
    s.posture = Posture::Prone;
    s.identity.squad = 1;
    s.weapon.magazine = 7;
    s.weapon.reserve = 23;
    if carried {
        s.links.carried_by = vec![3];
    }
    let mut enemy = shared::soldier(2, 7.0, Life::Alive);
    enemy.identity.team = 1;
    enemy.identity.owner = 8;
    let mut medic = shared::soldier(3, -1.0, Life::Alive);
    medic.duty.kind = Task::Rescue;
    medic.duty.entity = 1;
    let mut w = Scene::new(
        vec![
            Actor::Soldier(Box::new(s)),
            Actor::Soldier(Box::new(enemy)),
            Actor::Soldier(Box::new(medic)),
        ],
        137,
    );
    w.world.squads = vec![Squad {
        id: 1,
        team: 0,
        owner: 7,
        members: vec![1, 3],
        morale: 75.0,
        ..Default::default()
    }];
    w
}
fn step(s: &mut Scene, input: Input, gunfire: &mut Gunfire) -> Result<Vec<Event>, &'static str> {
    s.context().advance_wounded(
        1,
        input,
        gunfire,
        &mut SupplyNetwork::default(),
        &mut vec![],
        &|_| Armor {
            level: 0,
            helicopter: false,
            boat: false,
            supply: false,
            toss: 1.0,
        },
        &|_| 2.0,
    )
}

#[test]
fn bleeding_out_records_loss_and_finishes_death_without_firing() {
    let mut w = scene(0.05, false);
    let events = step(&mut w, input(), &mut Gunfire::default()).unwrap();
    let s = w.world.actors.soldier(1).unwrap();
    assert_eq!(s.vitals.life, Life::Dead);
    assert_eq!(s.fight.loot, 30);
    assert_eq!(s.weapon.magazine + s.weapon.reserve, 0);
    assert_eq!(
        w.world.battle.sides[0][frontline_core::battle_stats::LOST],
        1.0
    );
    assert!(events.contains(&Event::Died(1)));
    assert!(!events
        .iter()
        .any(|e| matches!(e, Event::World(world_combat::Event::Shot { .. }))));
    assert!(w.world.squads[0].morale < 75.0);
}

#[test]
fn a_carried_patient_bleeds_slower_cries_but_does_not_fire_or_crawl() {
    let mut w = scene(40.0, true);
    let events = step(
        &mut w,
        Input {
            medicine: true,
            ..input()
        },
        &mut Gunfire::default(),
    )
    .unwrap();
    let s = w.world.actors.soldier(1).unwrap();
    assert_eq!(s.vitals.bleed, 40.0 - 0.1 * (0.35 * 0.67));
    assert_eq!(s.activity, 13);
    assert_eq!(s.vitals.pistol_timer, 0.0);
    assert_eq!(s.vitals.crawl_timer, 0.0);
    assert_eq!(s.vitals.speech_cooldown, 2.6);
    assert!(matches!(events.as_slice(), [Event::Cry { id: 1, .. }]));
}

#[test]
fn pistol_fire_and_crawl_continuation_resume_with_the_shared_world() {
    let mut w = scene(40.0, false);
    let mut gunfire = Gunfire::default();
    let mut fired = false;
    let mut injured = false;
    for tick in 0..80 {
        let mut resumed = w.resume();
        let mut resumed_gunfire = Gunfire::restore(&gunfire.checkpoint()).unwrap();
        let a = step(&mut w, input(), &mut gunfire).unwrap();
        let b = step(&mut resumed, input(), &mut resumed_gunfire).unwrap();
        if tick == 0 {
            assert_eq!(
                w.world.actors.soldier(1).unwrap().motion.yaw,
                f64::from(-std::f32::consts::FRAC_PI_2)
            );
        }
        assert_eq!(a, b);
        w.world.compare(&resumed.world);
        assert_eq!(gunfire, resumed_gunfire);
        fired |= a.iter().any(|e| {
            matches!(
                e,
                Event::World(world_combat::Event::Shot { shooter: 1, .. })
            )
        });
        injured |= w.world.actors.soldier(2).unwrap().vitals.hp < 100.0;
        w.world.now += 0.1;
    }
    assert!(fired && injured);
}

#[test]
fn bleed_out_retains_the_original_attackers_kill_credit() {
    let mut w = scene(0.05, false);
    let entries = w
        .world
        .actors
        .iter()
        .cloned()
        .map(|mut a| {
            if let Actor::Soldier(s) = &mut a {
                if s.identity.id == 1 {
                    s.identity.hit_by = Some(Credit {
                        owner: 8,
                        team: 1,
                        unit: String::new(),
                        soldier: 2,
                    });
                }
            }
            a
        })
        .collect();
    w.world.actors = frontline_core::actors::Actors::from_entries(1000, entries).unwrap();
    step(&mut w, input(), &mut Gunfire::default()).unwrap();
    assert_eq!(
        w.world.battle.sides[1][frontline_core::battle_stats::KILLS],
        1.0
    );
}

#[test]
fn invalid_delta_leaves_wounded_state_and_random_cursor_unchanged() {
    let mut w = scene(40.0, false);
    let before = w.resume();
    assert!(step(
        &mut w,
        Input {
            dt: f64::NAN,
            ..input()
        },
        &mut Gunfire::default()
    )
    .is_err());
    w.world.compare(&before.world);
}
