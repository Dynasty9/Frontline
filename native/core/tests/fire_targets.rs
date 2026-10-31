use frontline_core::actors::{Actor, Actors};
use frontline_core::fire_targets::{fpv, mortar};
use frontline_core::infantry::Infantry;
use frontline_core::spatial::{SpatialIndex, UNIT_CELL};
use frontline_core::structure::Structure;
use frontline_core::vector::Vector3;
use frontline_core::vehicle::Vehicle;

fn soldier(id: u32, x: f32, team: i8) -> Infantry {
    let mut s = Infantry::default();
    s.identity.id = id;
    s.identity.unit = "rifleman".into();
    s.identity.team = team;
    s.identity.visible = 1;
    s.motion.position.x = x;
    s
}
fn field(soldiers: Vec<Infantry>, others: Vec<Actor>) -> (Actors, SpatialIndex) {
    let entries = soldiers
        .into_iter()
        .map(|s| Actor::Soldier(Box::new(s)))
        .chain(others)
        .collect();
    let actors = Actors::from_entries(100, entries).unwrap();
    let mut units = SpatialIndex::new(UNIT_CELL).unwrap();
    actors.rebuild_units(&mut units).unwrap();
    (actors, units)
}
fn drone(actors: &Actors, units: &SpatialIndex) -> Option<u32> {
    fpv(
        actors,
        units,
        0,
        Vector3::ZERO,
        400.0,
        |v| if v.kind == "tank" { 2 } else { 0 },
        |s| s.identity.unit == "bearer",
    )
    .unwrap()
}

#[test]
fn mortar_protects_friendly_men_and_keeps_the_strict_eight_metre_boundary() {
    for (friendly_x, expected) in [(57.99, None), (58.0, Some(Vector3::X * 50.0))] {
        let (actors, units) = field(
            vec![
                soldier(1, 50.0, 1),
                soldier(2, 51.0, 1),
                soldier(3, friendly_x, 0),
            ],
            vec![],
        );
        assert_eq!(
            mortar(&actors, &units, &[], 0, Vector3::ZERO, 30.0, 130.0).unwrap(),
            expected
        );
    }
}

#[test]
fn mortar_keeps_contact_cover_and_neutral_neighbor_scoring() {
    let s = soldier(1, 50.0, 1);
    let (actors, units) = field(vec![s.clone()], vec![]);
    assert_eq!(
        mortar(&actors, &units, &[], 0, Vector3::ZERO, 30.0, 130.0).unwrap(),
        None
    );
    let (actors, units) = field(vec![s.clone(), soldier(2, 50.0, -1)], vec![]);
    assert_eq!(
        mortar(&actors, &units, &[], 0, Vector3::ZERO, 30.0, 130.0).unwrap(),
        Some(Vector3::X * 50.0)
    );
    let mut s = s;
    s.cover.at_cover = true;
    let (actors, units) = field(vec![s.clone()], vec![]);
    assert!(mortar(&actors, &units, &[], 0, Vector3::ZERO, 30.0, 130.0)
        .unwrap()
        .is_some());
    s.identity.visible = 0;
    let (actors, units) = field(vec![s], vec![]);
    assert!(mortar(&actors, &units, &[], 0, Vector3::ZERO, 30.0, 130.0)
        .unwrap()
        .is_none());
}

#[test]
fn mortar_uses_current_ownership_order_and_remembered_emplacements() {
    let structures = [10, 11]
        .into_iter()
        .map(|id| {
            Actor::Structure(Box::new(Structure {
                id,
                kind: "bunker".into(),
                team: 1,
                built: true,
                seen: 1,
                position: Vector3::X * if id == 10 { 50.0 } else { -50.0 },
                ..Default::default()
            }))
        })
        .collect();
    let (actors, units) = field(vec![], structures);
    assert_eq!(
        mortar(
            &actors,
            &units,
            &[99, 11, 10],
            0,
            Vector3::ZERO,
            30.0,
            130.0
        )
        .unwrap(),
        Some(Vector3::X * -50.0)
    );
    assert_eq!(
        mortar(&actors, &units, &[10, 11], 0, Vector3::ZERO, 30.0, 130.0).unwrap(),
        Some(Vector3::X * 50.0)
    );
}

#[test]
fn fpv_prefers_armour_and_requires_sighting_at_exactly_150_metres() {
    let vehicle = |id, kind: &str, x, visible| {
        Actor::Vehicle(Box::new(Vehicle {
            id,
            kind: kind.into(),
            team: 1,
            hp: 100.0,
            position: Vector3::X * x,
            visible,
            ..Default::default()
        }))
    };
    let (actors, units) = field(
        vec![],
        vec![vehicle(1, "truck", 149.0, 0), vehicle(2, "tank", 150.0, 0)],
    );
    assert_eq!(drone(&actors, &units), Some(1));
    let (actors, units) = field(
        vec![],
        vec![vehicle(1, "truck", 149.0, 0), vehicle(2, "tank", 150.0, 1)],
    );
    assert_eq!(drone(&actors, &units), Some(2));
}

#[test]
fn fpv_preserves_vehicle_first_ties_and_stale_unit_membership() {
    let (actors, units) = field(
        (1..=10).map(|id| soldier(id, 320.0, 1)).collect(),
        vec![Actor::Vehicle(Box::new(Vehicle {
            id: 20,
            kind: "truck".into(),
            team: 1,
            hp: 100.0,
            visible: 1,
            position: Vector3::X * 240.0,
            ..Default::default()
        }))],
    );
    assert_eq!(drone(&actors, &units), Some(20));
    let (actors, mut units) = field(vec![soldier(1, 50.0, 1), soldier(2, 51.0, 1)], vec![]);
    units.remove(2);
    units.insert(2, Vector3::X * 100.0, 0.0).unwrap();
    assert_eq!(drone(&actors, &units), None);
    actors.rebuild_units(&mut units).unwrap();
    assert_eq!(drone(&actors, &units), Some(1));
}

#[test]
fn invalid_team_ranges_and_grids_fail_without_queries() {
    let (actors, units) = field(vec![], vec![]);
    assert!(mortar(&actors, &units, &[], -1, Vector3::ZERO, 30.0, 130.0).is_err());
    assert!(mortar(&actors, &units, &[], 0, Vector3::ZERO, 131.0, 130.0).is_err());
    assert!(fpv(&actors, &units, 0, Vector3::NAN, 30.0, |_| 0, |_| false).is_err());
    assert!(fpv(
        &actors,
        &SpatialIndex::new(16.0).unwrap(),
        0,
        Vector3::ZERO,
        30.0,
        |_| 0,
        |_| false
    )
    .is_err());
}
