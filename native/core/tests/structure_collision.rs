use frontline_core::actors::Actors;
use frontline_core::structure::{Part, Structure};
use frontline_core::terrain::Terrain;
use frontline_core::vector::Vector3;
use frontline_core::world_geometry::WorldGeometry;

fn wall() -> Structure {
    Structure {
        id: 1,
        kind: "house_wall".into(),
        built: true,
        parts: vec![Part {
            position: Vector3::Y,
            size: Vector3::new(4.0, 2.0, 0.5),
            yaw: 0.0,
            infantry: 3,
            vehicle: 3,
            cover: true,
            collision: true,
            door: true,
        }],
        ..Default::default()
    }
}
fn geometry() -> WorldGeometry {
    WorldGeometry::new(Terrain::blank(32).unwrap(), vec![], 16).unwrap()
}
fn hit(g: &mut WorldGeometry) -> bool {
    g.collision
        .ray(
            Vector3::new(0.0, 1.0, -5.0),
            Vector3::new(0.0, 1.0, 5.0),
            &[],
        )
        .is_some()
}

#[test]
fn construction_and_door_removal_change_collision_without_scene_objects() {
    let mut g = geometry();
    let mut st = wall();
    st.built = false;
    g.refresh_structure_collision(&st).unwrap();
    assert!(!hit(&mut g));
    assert!(!g.collision.contains(1));
    st.built = true;
    g.refresh_structure_collision(&st).unwrap();
    assert!(hit(&mut g));
    st.parts.clear();
    g.refresh_structure_collision(&st).unwrap();
    assert!(!hit(&mut g));
    assert!(
        g.collision.contains(1),
        "Removing the final door leaves the body's empty shape list"
    );
}

#[test]
fn movement_and_part_rotations_preserve_shape_order_and_ignore_visual_tilt() {
    let mut g = geometry();
    let mut st = wall();
    let mut visual = st.parts[0];
    visual.collision = false;
    st.parts.insert(0, visual);
    let mut second = st.parts[1];
    second.position = Vector3::new(5.0, 1.0, 0.0);
    second.yaw = 0.7;
    st.parts.push(second);
    g.refresh_structure_collision(&st).unwrap();
    assert_eq!(g.collision.shape(1, 0).unwrap().center, Vector3::Y);
    assert_eq!(g.collision.shape(1, 1).unwrap().center, second.position);
    let prior = g.collision.checkpoint();
    st.tilt = [1.1, -2.3];
    g.refresh_structure_collision(&st).unwrap();
    assert_eq!(prior, g.collision.checkpoint());
    st.position.x = 10.0;
    st.yaw = 0.3;
    g.refresh_structure_collision(&st).unwrap();
    assert!(!hit(&mut g));
    assert!(g
        .collision
        .ray(
            Vector3::new(10.0, 1.0, -5.0),
            Vector3::new(10.0, 1.0, 5.0),
            &[]
        )
        .is_some());
}

#[test]
fn invalid_shapes_do_not_remove_previous_shelter() {
    let mut g = geometry();
    let mut st = wall();
    g.refresh_structure_collision(&st).unwrap();
    let prior = g.collision.checkpoint();
    st.parts[0].size.x = 0.0;
    assert!(g.refresh_structure_collision(&st).is_err());
    assert_eq!(prior, g.collision.checkpoint());
    st.parts[0].size.x = 1e6;
    assert!(g.refresh_structure_collision(&st).is_err());
    assert_eq!(prior, g.collision.checkpoint());
}

#[test]
fn destroyed_body_cannot_be_refreshed_before_its_deferred_removal() {
    let mut g = geometry();
    let mut st = wall();
    g.refresh_structure_collision(&st).unwrap();
    st.gone = true;
    g.retire_structure(&mut st, &Actors::default()).unwrap();
    let mut resumed = WorldGeometry::restore(&g.checkpoint()).unwrap();
    for state in [&mut g, &mut resumed] {
        st.gone = false;
        assert!(state.refresh_structure_collision(&st).is_err());
        assert!(hit(state));
        state.finish_tick();
        assert!(!hit(state));
    }
    assert_eq!(g.checkpoint(), resumed.checkpoint());
}
