use frontline_core::breach_selection::{self as entry, Building, Contact, Mate, Opening};
use frontline_core::path_planner::PathPlanner;
use frontline_core::vector::Vector3 as V;

fn house(id: u64) -> Building {
    Building {
        id,
        position: V::ZERO,
        size: V::new(8.0, 0.2, 6.0),
        yaw: 0.0,
        kind: 0,
        gone: false,
        wrecked: false,
    }
}
fn contact(id: u64) -> Contact {
    Contact {
        house: house(id),
        enemy_alive: true,
        openings: vec![Opening {
            id: id + 10,
            center: V::Z * 3.0,
            normal: V::Z,
            door: true,
        }],
    }
}

#[test]
fn house_queries_keep_strict_bounds_and_encounter_order() {
    assert_eq!(
        entry::house_at(V::ZERO, &[house(2), house(1)]).unwrap(),
        Some(2)
    );
    assert_eq!(entry::house_at(V::X * 4.0, &[house(1)]).unwrap(), None);
    let mut wall = house(4);
    wall.kind = 2;
    wall.position = V::Z * -3.0;
    let o = entry::openings(house(1), &[wall]).unwrap();
    assert_eq!(o[0].normal, -V::Z);
    wall.wrecked = true;
    assert!(entry::openings(house(1), &[wall]).unwrap().is_empty());
    assert!(entry::house_at(V::NAN, &[house(1)]).is_err());
    assert!(entry::house_at(V::ZERO, &[house(u64::MAX)]).is_err());
}

#[test]
fn a_better_placed_mate_prevents_claiming_another_contact_and_ties_keep_the_first_opening() {
    let nav = PathPlanner::new(64).unwrap();
    let mut first = contact(1);
    first.openings.push(first.openings[0]);
    let contacts = [first, contact(2)];
    let p = V::Z * 20.0;
    assert_eq!(
        entry::choose(p, V::ZERO, None, &contacts, &[], &nav).unwrap(),
        Some((0, 0))
    );
    assert_eq!(
        entry::choose(p, V::ZERO, Some(1), &contacts, &[], &nav).unwrap(),
        Some((1, 0))
    );
    let mut mate = Mate {
        position: V::Z * 3.0,
        other: true,
        alive: true,
        idle: true,
        frags: 1,
        mounted: false,
    };
    assert_eq!(
        entry::choose(p, V::ZERO, None, &contacts, &[mate], &nav).unwrap(),
        None
    );
    mate.mounted = true;
    assert_eq!(
        entry::choose(p, V::ZERO, None, &contacts, &[mate], &nav).unwrap(),
        Some((0, 0))
    );
}

#[test]
fn nearest_walkable_preserves_ring_order_and_keeps_unblocked_height() {
    let mut nav = PathPlanner::new(16).unwrap();
    assert_eq!(nav.nearest_walkable(V::Y), Some(V::Y));
    let mut cells = [3; 256];
    cells[7 * 16 + 7] = 0;
    cells[7 * 16 + 8] = 0;
    nav.load_cells(&cells, &cells, &[0; 256]);
    assert_eq!(nav.nearest_walkable(V::Y), Some(V::new(-0.5, 0.0, -0.5)));
    assert_eq!(nav.nearest_walkable(V::NAN), None);
}
