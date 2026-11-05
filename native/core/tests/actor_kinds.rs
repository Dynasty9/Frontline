use frontline_core::actors::{Actor, Actors};
use frontline_core::entities::Kind;
use frontline_core::infantry::Infantry;
use frontline_core::projectile_actor::{ballistic, Motion, Projectile};
use frontline_core::structure::Structure;
use frontline_core::vector::Vector3;

fn soldier(id: u32) -> Actor {
    let mut s = Infantry::default();
    s.identity.id = id;
    s.identity.unit = "rifleman".into();
    Actor::Soldier(Box::new(s))
}
fn projectile(id: u32) -> Actor {
    Actor::Projectile(Projectile {
        id,
        team: 0,
        thrower: 0,
        called_by: 0,
        held_by: 0,
        smothered_by: 0,
        handler: 0,
        thrown_back: 0,
        target_id: 0,
        motion: Motion::Ballistic(ballistic(
            frontline_core::projectile::Kind::Frag,
            Vector3::ZERO,
            Vector3::ZERO,
        )),
    })
}
fn consistent(actors: &Actors) {
    for kind in [
        Kind::Soldier,
        Kind::Structure,
        Kind::Vehicle,
        Kind::Projectile,
        Kind::Drone,
    ] {
        let expected: Vec<_> = actors
            .iter()
            .filter(|a| a.identity().kind == kind)
            .map(Actor::identity)
            .collect();
        let actual: Vec<_> = actors.iter_kind(kind).map(Actor::identity).collect();
        assert_eq!(actual, expected);
    }
}

#[test]
fn typed_actor_lists_follow_registration_order_through_spawns_removals_and_restores() {
    let mut actors = Actors::from_entries(
        20,
        vec![
            soldier(8),
            projectile(2),
            Actor::Structure(Box::new(Structure {
                id: 17,
                kind: "low_wall".into(),
                ..Default::default()
            })),
            soldier(3),
            projectile(13),
        ],
    )
    .unwrap();
    consistent(&actors);
    assert_eq!(
        actors
            .iter_kind(Kind::Soldier)
            .map(|a| a.identity().id)
            .collect::<Vec<_>>(),
        [8, 3]
    );
    for id in [8, 2, 99, 3] {
        actors.remove(id);
        consistent(&actors);
    }
    let first = actors.spawn(soldier(0)).unwrap();
    let round = actors.spawn(projectile(0)).unwrap();
    let second = actors.spawn(soldier(0)).unwrap();
    assert_eq!(
        actors
            .iter_kind(Kind::Soldier)
            .map(|a| a.identity().id)
            .collect::<Vec<_>>(),
        [first, second]
    );
    assert_eq!(
        actors
            .iter_kind(Kind::Projectile)
            .map(|a| a.identity().id)
            .collect::<Vec<_>>(),
        [13, round]
    );
    consistent(&actors);
    let bytes = actors.checkpoint().unwrap();
    actors = Actors::restore(&bytes).unwrap();
    consistent(&actors);
    assert_eq!(actors.checkpoint().unwrap(), bytes);
}

#[test]
fn projectile_churn_and_registry_compaction_do_not_leave_stale_typed_membership() {
    let mut actors = Actors::from_entries(2, vec![soldier(1)]).unwrap();
    for _ in 0..3 {
        let ids: Vec<_> = (0..1500)
            .map(|_| actors.spawn(projectile(0)).unwrap())
            .collect();
        for id in ids.into_iter().step_by(2) {
            actors.remove(id);
        }
        consistent(&actors);
        let ids: Vec<_> = actors
            .iter_kind(Kind::Projectile)
            .map(|a| a.identity().id)
            .collect();
        for id in ids {
            actors.remove(id);
        }
        consistent(&actors);
        assert!(actors.iter_kind(Kind::Projectile).next().is_none());
    }
    assert_eq!(actors.iter_kind(Kind::Soldier).count(), 1);
}
