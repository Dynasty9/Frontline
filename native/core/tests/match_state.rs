#[allow(dead_code)]
#[path = "fixtures/match_commands.rs"]
mod fixture;
use frontline_core::boat_navigation::BoatNavigation;
use frontline_core::match_state::{Battlefield, MatchState};
use frontline_core::structure_world::Victory;
use frontline_core::terrain::Terrain;
use frontline_core::water::Water;
use frontline_core::world_geometry::WorldGeometry;

fn empty(side: usize) -> MatchState {
    let terrain = Terrain::blank(side).unwrap();
    let deck = vec![0; side * side];
    let boats = BoatNavigation::from_terrain(&terrain, &deck).unwrap();
    MatchState::empty(
        WorldGeometry::new(terrain, deck, 16).unwrap(),
        Water {
            side,
            coast: None,
            rivers: vec![],
            ponds: vec![],
            fords: vec![],
            bridges: vec![],
        },
        boats,
        137,
        true,
    )
    .unwrap()
}
#[test]
fn checkpoint_retains_connected_commands_and_random_continuation() {
    use frontline_core::match_commands::{Action, Command};
    use frontline_core::vector::Vector3;
    let mut s = fixture::scene();
    s.execute(
        7,
        &fixture::command(Action::Assault {
            position: Vector3::ZERO,
            face: Vector3::NEG_Z,
        }),
    )
    .unwrap();
    s.execute(
        7,
        &Command {
            squads: vec![],
            vehicles: vec![],
            action: Action::Support {
                kind: "mortars".into(),
                position: Vector3::ZERO,
                direction: Vector3::NEG_Z,
            },
        },
    )
    .unwrap();
    let f = s.world.world;
    let mut a = MatchState {
        field: Battlefield {
            actors: f.actors,
            geometry: f.geometry,
            units: f.units,
            next_squad: f
                .squads
                .iter()
                .map(|q| u64::from(q.id) + 1)
                .max()
                .unwrap_or(1),
            squads: f.squads,
            fires: s.world.fires,
            battle: f.battle,
            deferred: f.deferred,
            visibility: f.visibility,
            rng: f.rng,
            now: f.now,
            town: [0.; 4],
        },
        tick: 6000,
        rules: s.rules,
        owners: s.owners,
        water: s.water,
        boats: s.boats,
        attacks: s.plans,
        ambushes: s.ambushes,
        next_attack: s.next_plan,
        next_ambush: 1,
        gunfire: Default::default(),
        impacts: vec![],
        chat: [9., 13.],
        victory: Victory {
            winner: -1,
            mission: true,
        },
        scenario: true,
    };
    let bytes = a.checkpoint().unwrap();
    let mut b = MatchState::restore(&bytes).unwrap();
    assert_eq!(b.checkpoint().unwrap(), bytes);
    assert!(!b.rules.support.queue.is_empty());
    assert!(!b.attacks.is_empty());
    for _ in 0..32 {
        assert_eq!(a.field.rng.randi(), b.field.rng.randi());
    }
    assert_eq!(a.checkpoint().unwrap(), b.checkpoint().unwrap());
}
#[test]
fn rejects_incompatible_truncated_or_trailing_checkpoints() {
    let state = empty(16);
    let bytes = state.checkpoint().unwrap();
    // Sample boundaries across large terrain blocks, and every byte in the scalar header.
    for end in (0..140)
        .chain((140..bytes.len()).step_by(997))
        .chain([bytes.len() - 1])
    {
        assert!(MatchState::restore(&bytes[..end]).is_err(), "{end}");
    }
    for at in [4, 5, 6, 7] {
        let mut bad = bytes.clone();
        bad[at] = 9;
        assert!(MatchState::restore(&bad).is_err());
    }
    let mut bad = bytes.clone();
    bad.push(0);
    assert!(MatchState::restore(&bad).is_err());
    let mut bad = bytes;
    bad[16..24].copy_from_slice(&f64::NAN.to_le_bytes());
    assert!(MatchState::restore(&bad).is_err());
}
#[test]
fn rejects_inconsistent_dimensions_and_identity_counters() {
    let mut s = empty(16);
    s.water.side = 32;
    assert!(s.checkpoint().is_err());
    s.water.side = 16;
    s.next_attack = 0;
    assert!(s.checkpoint().is_err());
    s.next_attack = 1;
    s.field.squads = fixture::scene().world.world.squads;
    assert!(s.checkpoint().is_err());
    s.field.next_squad = 8;
    assert!(s.checkpoint().is_ok());
    s.field.squads.push(s.field.squads[0].clone());
    assert!(s.checkpoint().is_err());
}
