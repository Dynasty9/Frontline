#[allow(dead_code)]
#[path = "fixtures/vehicle_loss_world.rs"]
mod fixture;
use frontline_core::infantry_spawn::Loadout;
use frontline_core::infantry_vitals::Life;
use frontline_core::squad_birth::{Definition, Spawn};
use frontline_core::vector::Vector3;
fn member() -> Loadout {
    Loadout {
        unit: "rifleman".into(),
        weapon: "rifle".into(),
        hp: 100.,
        magazine: 30,
        ammunition: 120,
        grenades: 2,
        smokes: 1,
        rockets: 0,
        mortar_rounds: 0,
        drones: 0,
        bearer: false,
    }
}
fn definition(members: &[Loadout]) -> Definition<'_> {
    Definition {
        kind: "rifle_squad",
        name: "Rifle Squad",
        members,
        armor_upgrade: true,
        grenade_upgrade: true,
    }
}
fn spawn() -> Spawn {
    Spawn {
        team: 0,
        owner: 7,
        position: Vector3::new(1.3, 0., -2.7),
        destination: None,
    }
}
#[test]
fn recruitment_registers_members_and_upgrades_before_rally_orders() {
    let mut scene = fixture::Scene::new(vec![], 711);
    let members = vec![member(); 7];
    let (id, events) = scene
        .context()
        .spawn_squad(spawn(), definition(&members))
        .unwrap();
    assert_eq!(id, 7);
    assert_eq!(scene.next, 8);
    assert!(events.is_empty());
    let q = &scene.world.squads[0];
    assert_eq!(q.members.len(), 7);
    assert_eq!(q.order_position, spawn().position);
    assert_eq!(scene.world.battle.units[0].men, 7);
    assert_eq!(scene.world.battle.units[0].alive, 0);
    for (i, &id) in q.members.iter().enumerate() {
        let s = scene.world.actors.soldier(id).unwrap();
        assert_eq!(s.identity.squad, 7);
        assert_eq!(s.vitals.hp, 120.);
        assert_eq!(s.grenades.frags, 3);
        assert_eq!(s.motion.position.z, -2.7 + ((i / 3) as f64 * 1.4) as f32);
        assert!(matches!(s.identity.name.as_str(), "Jones" | "Perez"));
    }
    let (id, events) = scene
        .context()
        .spawn_squad(
            Spawn {
                destination: Some(Vector3::new(12., 0., 8.)),
                ..spawn()
            },
            definition(&members),
        )
        .unwrap();
    assert_eq!(id, 8);
    assert!(!events.is_empty());
    assert_eq!(scene.world.squads[1].order, "move");
    assert!(scene.world.squads[1].members.iter().all(|&id| scene
        .world
        .actors
        .soldier(id)
        .unwrap()
        .is_moving()));
}
#[test]
fn transport_recruitment_links_and_hides_every_passenger() {
    let mut scene = fixture::Scene::new(vec![fixture::vehicle(20, "tank")], 19);
    let members = vec![member(); 4];
    let id = scene
        .context()
        .embark_new_squad(20, definition(&members))
        .unwrap();
    let q = &scene.world.squads[0];
    assert_eq!(id, q.id);
    assert_eq!(
        scene.world.actors.vehicle(20).unwrap().passengers,
        q.members
    );
    for &id in &q.members {
        let s = scene.world.actors.soldier(id).unwrap();
        assert_eq!(s.links.vehicle, 20);
        assert_eq!(s.vitals.life, Life::Hidden);
        assert_eq!(s.control.hidden_timer, 9999.);
        assert!(!s.is_moving());
    }
}
#[test]
fn rejected_recruitment_does_not_consume_ids_randomness_or_ledger_entries() {
    let mut scene = fixture::Scene::new(vec![], 31);
    let mut members = vec![member(); 3];
    members[2].hp = f64::NAN;
    let before = scene.world.actors.checkpoint().unwrap();
    let rng = scene.world.rng;
    assert!(scene
        .context()
        .spawn_squad(spawn(), definition(&members))
        .is_err());
    members[2] = member();
    for bad in [
        Spawn {
            team: -1,
            ..spawn()
        },
        Spawn {
            destination: Some(Vector3::NAN),
            ..spawn()
        },
        Spawn {
            owner: -3,
            ..spawn()
        },
    ] {
        assert!(scene
            .context()
            .spawn_squad(bad, definition(&members))
            .is_err());
    }
    assert!(scene
        .context()
        .embark_new_squad(99, definition(&members))
        .is_err());
    assert_eq!(scene.world.actors.checkpoint().unwrap(), before);
    assert_eq!(scene.world.rng, rng);
    assert_eq!(scene.next, 7);
    assert!(scene.world.squads.is_empty());
    assert!(scene.world.battle.units.is_empty());
}
#[test]
fn checkpoint_resume_preserves_recruitment_random_order_and_paths() {
    let mut scene = fixture::Scene::new(vec![], 912);
    let members = vec![member(); 6];
    scene
        .context()
        .spawn_squad(spawn(), definition(&members))
        .unwrap();
    let mut resumed = scene.resume();
    let next = Spawn {
        team: 1,
        owner: -2,
        destination: Some(Vector3::new(11., 0., -10.)),
        ..spawn()
    };
    let a = scene
        .context()
        .spawn_squad(next, definition(&members))
        .unwrap();
    let b = resumed
        .context()
        .spawn_squad(next, definition(&members))
        .unwrap();
    assert_eq!(a, b);
    assert_eq!(
        scene.world.actors.checkpoint().unwrap(),
        resumed.world.actors.checkpoint().unwrap()
    );
    assert_eq!(scene.world.squads, resumed.world.squads);
    assert_eq!(
        scene.world.geometry.checkpoint(),
        resumed.world.geometry.checkpoint()
    );
    assert_eq!(scene.world.rng, resumed.world.rng);
    assert_eq!(scene.world.battle, resumed.world.battle);
}
