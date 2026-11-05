#[allow(dead_code)]
#[path = "fixtures/vehicle_loss_world.rs"]
mod fixture;
use fixture::shared::{actor, soldier, structure};
use frontline_core::actors::Actor;
use frontline_core::infantry::Infantry;
use frontline_core::infantry_controller::Task;
use frontline_core::infantry_spawn::Loadout;
use frontline_core::infantry_supply;
use frontline_core::infantry_vitals::Life;
use frontline_core::infantry_weapon::Weapon;
use frontline_core::squad_movement::ManProfile;
use frontline_core::structure_services::{Event, Profiles, Supply};
fn bearer() -> Loadout {
    Loadout {
        unit: "bearer".into(),
        weapon: String::new(),
        hp: 90.,
        magazine: 0,
        ammunition: 0,
        grenades: 0,
        smokes: 0,
        rockets: 0,
        mortar_rounds: 0,
        drones: 0,
        bearer: true,
    }
}
fn supply(_: &Infantry) -> Supply {
    Supply {
        ammunition: Some(120),
        frags: 2,
        loadout: Some(infantry_supply::Loadout {
            ammunition: 120,
            special: [2, 1, 0, 0, 0],
            reload_weapon: Weapon {
                ammunition: 120,
                magazine: 30,
                reload_time: 2.5,
            },
        }),
    }
}
fn tick(scene: &mut fixture::Scene, id: u32, dt: f64) -> Result<Vec<Event>, &'static str> {
    let bearer = bearer();
    let mut context = scene.context();
    context.movement = &|s| ManProfile {
        bearer: s.identity.unit == "bearer",
        weapon_range: Some(85.),
    };
    context.advance_structure_service(
        id,
        dt,
        &Profiles {
            supply: &supply,
            bearer: &bearer,
            armor_upgrade: false,
            grenade_upgrade: false,
            gun: None,
        },
    )
}
#[test]
fn tents_keep_surrendered_bearers_but_replace_dead_or_enemy_bearers() {
    let mut tent = structure(30, "medic_tent", 0.);
    tent.bearers = vec![1, 2, 3];
    tent.bearer_timer = 1.;
    let mut men = vec![];
    for (id, life, team) in [
        (1, Life::Surrender, 0),
        (2, Life::Dead, 0),
        (3, Life::Alive, 1),
    ] {
        let mut s = soldier(id, id as f32, life);
        s.identity.unit = "bearer".into();
        s.identity.team = team;
        men.push(Actor::Soldier(Box::new(s)));
    }
    men.push(actor(tent));
    let mut scene = fixture::Scene::new(men, 17);
    let events = tick(&mut scene, 30, 0.1).unwrap();
    let st = scene.world.actors.structure(30).unwrap();
    assert_eq!(st.bearers, vec![1, 1000]);
    assert_eq!(st.bearer_timer, 25.);
    let s = scene.world.actors.soldier(1000).unwrap();
    assert_eq!(s.links.home, 30);
    assert_eq!(s.identity.owner, -1);
    assert_eq!(s.vitals.life, Life::Alive);
    assert!(events.contains(&Event::Born {
        tent: 30,
        soldier: 1000
    }));
}
#[test]
fn stretcher_partners_claim_one_old_wounded_patient_and_keep_recent_casualties_waiting() {
    let mut tent = structure(30, "medic_tent", 0.);
    tent.bearers = vec![1, 2];
    let mut men = vec![actor(tent)];
    for id in 1..=5 {
        let mut s = soldier(
            id,
            if id == 5 { 25. } else { id as f32 },
            if id < 3 {
                Life::Alive
            } else if id == 3 {
                Life::Dead
            } else {
                Life::Downed
            },
        );
        if id < 3 {
            s.identity.unit = "bearer".into();
        }
        if id == 4 {
            s.vitals.downed_at = 99.;
        }
        men.push(Actor::Soldier(Box::new(s)));
    }
    let mut scene = fixture::Scene::new(men, 31);
    let events = tick(&mut scene, 30, 0.1).unwrap();
    assert_eq!(
        events
            .iter()
            .filter(|e| **e == Event::Stat("stretcher_job"))
            .count(),
        2
    );
    for (id, partner, front) in [(1, 2, true), (2, 1, false)] {
        let s = scene.world.actors.soldier(id).unwrap();
        assert_eq!(s.duty.kind, Task::Stretcher);
        assert_eq!(s.duty.entity, 5);
        assert_eq!(s.duty.partner, partner);
        assert_eq!(s.duty.front, front);
        assert!(s.is_moving());
    }
    assert!(
        scene
            .world
            .actors
            .soldier(5)
            .unwrap()
            .links
            .stretcher_claimed
    );
    assert!(
        !scene
            .world
            .actors
            .soldier(4)
            .unwrap()
            .links
            .stretcher_claimed
    );
}
#[test]
fn preferred_gun_crew_beats_a_closer_rifleman_and_stale_gunners_are_replaced() {
    let mut st = structure(30, "mortar_pit", 0.);
    st.gunner = 99;
    let a = soldier(1, 1., Life::Alive);
    let mut b = soldier(2, 4., Life::Alive);
    b.identity.unit = "mortar_gunner".into();
    let mut scene = fixture::Scene::new(
        vec![
            actor(st),
            Actor::Soldier(Box::new(a)),
            Actor::Soldier(Box::new(b)),
        ],
        51,
    );
    assert!(tick(&mut scene, 30, 0.1)
        .unwrap()
        .contains(&Event::Stat("manned")));
    assert_eq!(scene.world.actors.structure(30).unwrap().gunner, 2);
    let s = scene.world.actors.soldier(2).unwrap();
    assert_eq!(s.duty.kind, Task::Man);
    assert_eq!(s.emplacement.structure, 30);
    assert!(s.is_moving());
    assert_eq!(
        scene.world.actors.soldier(1).unwrap().duty.kind,
        Task::Fight
    );
}
#[test]
fn cache_finishes_nearby_refills_before_emptying_and_retires_shared_geometry() {
    let mut st = structure(30, "ammo_cache", 0.);
    st.supply = 0.5;
    let men = (1..=3).map(|id| {
        let mut s = soldier(id, id as f32, Life::Alive);
        s.weapon.magazine = 0;
        s.weapon.reserve = 0;
        Actor::Soldier(Box::new(s))
    });
    let mut entries = vec![actor(st)];
    entries.extend(men);
    let mut scene = fixture::Scene::new(entries, 81);
    let events = tick(&mut scene, 30, 0.1).unwrap();
    assert_eq!(
        events
            .iter()
            .filter(|e| **e == Event::Stat("cache_draw"))
            .count(),
        3
    );
    for id in 1..=3 {
        assert_eq!(scene.world.actors.soldier(id).unwrap().weapon.reserve, 31);
    }
    assert!(scene.world.actors.get(30).is_none());
    assert!(scene.world.geometry.pending_removals().contains(&30));
    assert!(events.contains(&Event::Stat("cache_empty")));
    assert_eq!(events.last(), Some(&Event::Despawn(30)));
}
#[test]
fn service_clocks_and_resume_preserve_actor_routes_and_randomness() {
    let mut st = structure(30, "medic_tent", 0.);
    st.tick_timer = 0.7;
    st.bearer_timer = 1.;
    let mut scene = fixture::Scene::new(vec![actor(st)], 97);
    let before = scene.world.actors.checkpoint().unwrap();
    let rng = scene.world.rng;
    assert!(tick(&mut scene, 30, f64::NAN).is_err());
    assert_eq!(before, scene.world.actors.checkpoint().unwrap());
    assert!(tick(&mut scene, 30, 0.1).unwrap().is_empty());
    assert_eq!(scene.world.rng, rng);
    let mut resumed = scene.resume();
    assert_eq!(
        tick(&mut scene, 30, 1.).unwrap(),
        tick(&mut resumed, 30, 1.).unwrap()
    );
    scene.world.compare(&resumed.world);
}
