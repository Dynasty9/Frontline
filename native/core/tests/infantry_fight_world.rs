#[allow(dead_code)]
#[path = "fixtures/vehicle_loss_world.rs"]
mod fixture;
use fixture::{shared, Scene};
use frontline_core::actors::Actor;
use frontline_core::bullet;
use frontline_core::bullet_world::Gunfire;
use frontline_core::infantry_controller::Task;
use frontline_core::infantry_fight_world::{Event, Profile};
use frontline_core::infantry_fire::FireProfile;
use frontline_core::infantry_vitals::Life;
use frontline_core::infantry_weapon::Weapon;
use frontline_core::supply_network::SupplyNetwork;
use frontline_core::vector::Vector3;
use frontline_core::vehicle_damage::Armor;
use frontline_core::world_combat;

fn profile() -> Profile<'static> {
    Profile {
        fire: FireProfile {
            weapon: Weapon {
                ammunition: 120,
                magazine: 30,
                reload_time: 2.0,
            },
            burst_min: 2,
            burst_max: 4,
        },
        bullet: bullet::Weapon {
            accuracy: 100.0,
            range: 85.0,
            damage: 12.0,
            anti_air: false,
            penetration: 0,
            drone_accuracy: 0.03,
            explosive_radius: None,
            airburst: false,
        },
        interval: 0.1,
        suppression: 8.0,
        sound: "rifle",
        optics: false,
        piercing: false,
    }
}
fn scene() -> Scene {
    let mut shooter = shared::soldier(1, 0.0, Life::Alive);
    shooter.fight.target = 2;
    shooter.fight.visible_targets = vec![2];
    shooter.weapon.magazine = 7;
    shooter.weapon.reserve = 60;
    let mut target = shared::soldier(2, 8.0, Life::Alive);
    target.identity.team = 1;
    target.identity.owner = 8;
    let rescuer = shared::soldier(3, -2.0, Life::Alive);
    Scene::new(
        vec![
            Actor::Soldier(Box::new(shooter)),
            Actor::Soldier(Box::new(target)),
            Actor::Soldier(Box::new(rescuer)),
        ],
        137,
    )
}
fn edit(s: &mut Scene, id: u32, change: impl FnOnce(&mut frontline_core::infantry::Infantry)) {
    let mut entries: Vec<_> = s.world.actors.iter().cloned().collect();
    let actor = entries.iter_mut().find(|a| a.identity().id == id).unwrap();
    let Actor::Soldier(man) = actor else {
        panic!("missing soldier")
    };
    change(man);
    s.world.actors =
        frontline_core::actors::Actors::from_entries(s.world.actors.entities().next_id(), entries)
            .unwrap();
}
fn step(
    s: &mut Scene,
    gunfire: &mut Gunfire,
    chat: &mut [f64; 2],
    p: Profile<'_>,
) -> Result<Vec<Event>, &'static str> {
    s.context().advance_fighting(
        1,
        0.1,
        None,
        chat,
        &|_| Some(p),
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
fn shots(events: &[Event]) -> usize {
    events
        .iter()
        .filter(|e| matches!(e, Event::World(world_combat::Event::Shot { .. })))
        .count()
}
#[test]
fn firing_updates_target_ammunition_reveal_and_cadence_together() {
    let mut s = scene();
    let mut gunfire = Gunfire::default();
    let events = step(&mut s, &mut gunfire, &mut [0.0; 2], profile()).unwrap();
    assert_eq!(shots(&events), 1);
    let shooter = s.world.actors.soldier(1).unwrap();
    assert_eq!(shooter.weapon.magazine, 6);
    assert_eq!(shooter.weapon.last_shot, 100.0);
    assert!(shooter.weapon.fire_timer > 0.0);
    assert_eq!(shooter.activity, 3);
    assert!(s.world.actors.soldier(2).unwrap().vitals.hp < 100.0);
    assert_ne!(gunfire.checkpoint(), Gunfire::default().checkpoint());
    edit(&mut s, 1, |s| s.weapon.fire_timer = 2.0);
    assert_eq!(
        shots(&step(&mut s, &mut gunfire, &mut [0.0; 2], profile()).unwrap()),
        0
    );
}
#[test]
fn empty_magazine_reloads_before_any_bullet_or_damage() {
    let mut s = scene();
    edit(&mut s, 1, |s| s.weapon.magazine = 0);
    let mut gunfire = Gunfire::default();
    assert_eq!(
        shots(&step(&mut s, &mut gunfire, &mut [0.0; 2], profile()).unwrap()),
        0
    );
    assert_eq!(s.world.actors.soldier(1).unwrap().weapon.reload_timer, 2.0);
    assert_eq!(s.world.actors.soldier(2).unwrap().vitals.hp, 100.0);
    assert_eq!(gunfire.checkpoint(), Gunfire::default().checkpoint());
}
#[test]
fn a_lost_rescuer_cancels_escort_before_weapon_or_random_updates() {
    let mut s = scene();
    edit(&mut s, 1, |shooter| {
        shooter.duty.kind = Task::Escort;
        shooter.duty.partner = 3;
        shooter.duty.entity = 2;
        shooter.orders.backwards = true;
        shooter.cover.at_cover = true;
        shooter.cover.evaluate_at = 110.0;
    });
    let random = s.world.rng.state();
    assert!(
        step(&mut s, &mut Gunfire::default(), &mut [0.0; 2], profile())
            .unwrap()
            .is_empty()
    );
    let shooter = s.world.actors.soldier(1).unwrap();
    assert_eq!(shooter.duty.kind, Task::Fight);
    assert!(!shooter.orders.backwards && !shooter.cover.at_cover);
    assert_eq!(shooter.cover.evaluate_at, 0.0);
    assert_eq!(shooter.weapon.magazine, 7);
    assert_eq!(s.world.rng.state(), random);
}
#[test]
fn escort_moves_and_fires_without_turning_away_from_the_threat() {
    let mut s = scene();
    edit(&mut s, 1, |shooter| {
        shooter.duty.kind = Task::Escort;
        shooter.duty.partner = 3;
        shooter.duty.entity = 2;
        shooter.orders.hold_face = Vector3::NEG_Z;
    });
    edit(&mut s, 3, |s| s.duty.kind = Task::Rescue);
    let events = step(&mut s, &mut Gunfire::default(), &mut [0.0; 2], profile()).unwrap();
    assert_eq!(shots(&events), 1);
    let shooter = s.world.actors.soldier(1).unwrap();
    assert_ne!(shooter.motion.position, Vector3::ZERO);
    assert_eq!(shooter.motion.yaw, 0.0);
    assert_eq!(shooter.activity, 3);
}
#[test]
fn resumed_fights_preserve_world_effects_and_randomness() {
    let mut s = scene();
    let mut gunfire = Gunfire::default();
    let mut chat = [0.0; 2];
    for tick in 0..80 {
        s.world.now = 100.0 + tick as f64 * 0.1;
        let mut resumed = s.resume();
        let mut resumed_chat = chat;
        let mut resumed_fire = Gunfire::restore(&gunfire.checkpoint()).unwrap();
        assert_eq!(
            step(&mut s, &mut gunfire, &mut chat, profile()).unwrap(),
            step(
                &mut resumed,
                &mut resumed_fire,
                &mut resumed_chat,
                profile()
            )
            .unwrap()
        );
        assert_eq!(
            s.world.actors.checkpoint().unwrap(),
            resumed.world.actors.checkpoint().unwrap()
        );
        assert_eq!(
            s.world.geometry.checkpoint(),
            resumed.world.geometry.checkpoint()
        );
        assert_eq!(
            s.world.battle.checkpoint(),
            resumed.world.battle.checkpoint()
        );
        assert_eq!(s.world.rng.state(), resumed.world.rng.state());
        assert_eq!(
            s.world.visibility.checkpoint(),
            resumed.world.visibility.checkpoint()
        );
        assert_eq!(gunfire.checkpoint(), resumed_fire.checkpoint());
        assert_eq!(chat, resumed_chat);
    }
}
#[test]
fn invalid_weapon_profile_is_rejected_before_movement_or_randomness() {
    let mut s = scene();
    let mut p = profile();
    p.bullet.damage = f64::NAN;
    let before = s.world.actors.checkpoint().unwrap();
    let random = s.world.rng.state();
    assert!(step(&mut s, &mut Gunfire::default(), &mut [0.0; 2], p).is_err());
    assert_eq!(s.world.actors.checkpoint().unwrap(), before);
    assert_eq!(s.world.rng.state(), random);
}
