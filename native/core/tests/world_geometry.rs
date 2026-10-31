use frontline_core::actors::{Actor, Actors};
use frontline_core::collision::{BoxShape, Mat3};
use frontline_core::structure::{Part, Structure};
use frontline_core::terrain::{Terrain, NETTED, WOODS};
use frontline_core::vector::Vector3;
use frontline_core::world_geometry::WorldGeometry;

fn wall(id: u32, kind: &str) -> Structure {
    Structure {
        id,
        kind: kind.into(),
        built: true,
        size: Vector3::new(4.0, 2.0, 1.0),
        radius: 3.0,
        footprint: [2.0, 0.5],
        hash_cells: vec![[-1, -1], [-1, 0], [0, -1], [0, 0]],
        parts: vec![Part {
            position: Vector3::Y,
            size: Vector3::new(4.0, 2.0, 1.0),
            yaw: 0.0,
            infantry: 3,
            vehicle: 3,
            cover: true,
            collision: true,
            door: false,
        }],
        ..Default::default()
    }
}
fn install(g: &mut WorldGeometry, st: &mut Structure) {
    g.structures.insert(st.id, st.position, st.radius).unwrap();
    g.sync_structure(st, true).unwrap();
    g.navigation.add_structure(st, &g.terrain, &g.deck).unwrap();
    assert!(g.collision.replace(
        i64::from(st.id),
        &[BoxShape {
            body: i64::from(st.id),
            shape: 0,
            center: st.position + Vector3::Y,
            basis: Mat3::IDENTITY,
            half: st.size * 0.5
        }]
    ));
}

#[test]
fn destruction_opens_routes_and_doors_but_shields_the_rest_of_the_tick() {
    let mut g = WorldGeometry::new(Terrain::blank(32).unwrap(), vec![], 16).unwrap();
    let mut st = wall(1, "house_wall");
    st.door_closed = true;
    install(&mut g, &mut st);
    g.doors.insert_door(st.id, st.position).unwrap();
    assert!(g.navigation.finalize(1));
    let cell = g.terrain.index(Vector3::ZERO);
    assert_eq!(g.navigation.planner.cell_state(cell).unwrap()[0], 3);
    st.gone = true;
    g.retire_structure(&mut st, &Actors::default()).unwrap();
    assert!(st.hash_cells.is_empty() && st.nav_cells.is_empty());
    assert!(g.structures.cells().next().is_none() && g.doors.cells().next().is_none());
    assert_eq!(g.navigation.planner.cell_state(cell).unwrap()[0], 0);
    assert!(!g.terrain.pending(usize::MAX).is_empty());
    assert_eq!(g.pending_removals(), [1]);
    let mut resumed = WorldGeometry::restore(&g.checkpoint()).unwrap();
    for state in [&mut g, &mut resumed] {
        assert_eq!(
            state
                .collision
                .ray(
                    Vector3::new(0.0, 1.0, -5.0),
                    Vector3::new(0.0, 1.0, 5.0),
                    &[]
                )
                .unwrap()
                .body,
            1
        );
        state.finish_tick();
        assert!(state
            .collision
            .ray(
                Vector3::new(0.0, 1.0, -5.0),
                Vector3::new(0.0, 1.0, 5.0),
                &[]
            )
            .is_none());
        state.tick_cover(100).unwrap();
    }
    assert_eq!(g.checkpoint(), resumed.checkpoint());
}

#[test]
fn tree_loss_changes_ground_immediately_and_preserves_overlapping_trees() {
    let mut g = WorldGeometry::new(Terrain::blank(32).unwrap(), vec![], 16).unwrap();
    let mut st = wall(1, "tree");
    install(&mut g, &mut st);
    for _ in 0..2 {
        g.terrain.tree(Vector3::ZERO, 1);
    }
    let cell = g.terrain.index(Vector3::ZERO);
    st.gone = true;
    g.retire_structure(&mut st, &Actors::default()).unwrap();
    assert_eq!(g.terrain.layers[WOODS][cell], 1);
    assert!(g.terrain.pending(usize::MAX).is_empty());
    assert_eq!(g.terrain.version, 3);
}

#[test]
fn removing_a_net_keeps_ground_beneath_the_remaining_net_hidden() {
    let mut g = WorldGeometry::new(Terrain::blank(32).unwrap(), vec![], 16).unwrap();
    let mut removed = wall(1, "camo_net");
    removed.footprint = [3.0, 3.0];
    let mut remaining = wall(2, "camo_net");
    remaining.footprint = [1.0, 1.0];
    install(&mut g, &mut removed);
    install(&mut g, &mut remaining);
    g.terrain.layers[NETTED].fill(1);
    let actors = Actors::from_entries(3, vec![Actor::Structure(Box::new(remaining))]).unwrap();
    removed.gone = true;
    g.retire_structure(&mut removed, &actors).unwrap();
    assert_eq!(g.terrain.layers[NETTED][g.terrain.index(Vector3::ZERO)], 1);
    assert_eq!(
        g.terrain.layers[NETTED][g.terrain.index(Vector3::new(2.0, 0.0, 0.0))],
        0
    );
    assert!(g.terrain.pending(usize::MAX).is_empty());
}

#[test]
fn invalid_retirements_do_not_partly_clear_shared_geometry() {
    let mut g = WorldGeometry::new(Terrain::blank(32).unwrap(), vec![], 16).unwrap();
    let mut st = wall(1, "house_wall");
    install(&mut g, &mut st);
    let actors = Actors::from_entries(2, vec![Actor::Structure(Box::new(st.clone()))]).unwrap();
    let before = g.checkpoint();
    assert!(g.retire_structure(&mut st, &Actors::default()).is_err());
    st.gone = true;
    assert!(g.retire_structure(&mut st, &actors).is_err());
    st.nav_cells.push(32 * 32);
    assert!(g.retire_structure(&mut st, &Actors::default()).is_err());
    assert_eq!(before, g.checkpoint());
    for end in [0, 8, 12, before.len() - 1] {
        assert!(WorldGeometry::restore(&before[..end]).is_err());
    }
    let mut bad = before.clone();
    bad.push(0);
    assert!(WorldGeometry::restore(&bad).is_err());
    st.nav_cells.pop();
    g.retire_structure(&mut st, &Actors::default()).unwrap();
    let mut bad = g.checkpoint();
    let end = bad.len();
    bad[end - 4..].fill(0);
    assert!(WorldGeometry::restore(&bad).is_err());
}

#[test]
fn cover_geometry_preserves_low_parts_heavy_materials_and_trench_ends() {
    let mut st = wall(1, "low_wall");
    st.parts[0].position.y = 0.0;
    st.parts[0].size.y = 1.0;
    assert!(st.cover_geometry().parts.is_empty());
    st.parts[0].size.y = 1.2;
    assert_eq!(st.cover_geometry().parts[0].level, 1);
    st.kind = "sandbags".into();
    assert_eq!(st.cover_geometry().parts[0].level, 2);
    st.kind = "rubble".into();
    assert_eq!(st.cover_geometry().parts[0].level, 1);
    st.kind = "trench".into();
    assert_eq!(
        st.cover_geometry().trench,
        [Vector3::X * -2.0, Vector3::X * 2.0]
    );
    assert!(st.cover_geometry().dug);
    st.built = false;
    assert!(!st.cover_geometry().dug && st.cover_geometry().parts.is_empty());
}
