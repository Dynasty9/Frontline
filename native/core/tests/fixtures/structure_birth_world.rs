use frontline_core::actors::{Actor, Actors};
use frontline_core::structure::Structure;
use frontline_core::terrain::Terrain;
use frontline_core::vector::Vector3;
use frontline_core::world_geometry::WorldGeometry;

pub const KINDS: &[&str] = &[
    "low_wall",
    "tall_wall",
    "house_wall",
    "floor",
    "dock",
    "bridge",
    "roof",
    "rubble",
    "crates",
    "car",
    "wreck",
    "tree",
    "fob",
    "town",
    "barracks",
    "factory",
    "medic_tent",
    "research",
    "depot",
    "sandbags",
    "concrete_wall",
    "hesco",
    "barricade",
    "ammo_cache",
    "wire",
    "mines",
    "tank_trap",
    "trench",
    "camo_net",
    "watchtower",
    "mg_nest",
    "hmg_nest",
    "mortar_pit",
    "at_post",
    "bunker",
    "tunnel",
    "helipad",
];

fn block(out: &mut Vec<u8>, data: &[u8]) {
    out.extend_from_slice(&(data.len() as u32).to_le_bytes());
    out.extend_from_slice(data);
}

pub fn transcript() -> Vec<u8> {
    let mut bytes = vec![];
    for trial in 0..8 {
        let mut geometry = WorldGeometry::new(Terrain::blank(32).unwrap(), vec![], 16).unwrap();
        let mut actors = Actors::default();
        for (index, &kind) in KINDS.iter().enumerate() {
            let st = Structure {
                kind: kind.into(),
                variant: trial,
                built: trial % 3 != 0,
                door_closed: trial % 2 == 0,
                position: Vector3::new(
                    (index % 7) as f32 * 3.13 - 10.0,
                    0.17,
                    (index / 7) as f32 * 3.79 - 9.0,
                ),
                size: Vector3::new(7.3, 2.3, 5.7),
                yaw: trial as f64 * 0.317 - 1.3,
                ..Default::default()
            };
            let id = geometry.spawn_structure(&mut actors, st, None).unwrap();
            assert_eq!(id as usize, index + 1);
            block(&mut bytes, &actors.get(id).unwrap().checkpoint().unwrap());
            if index % 7 == 3 {
                geometry.tick_cover(37).unwrap();
                geometry = WorldGeometry::restore(&geometry.checkpoint()).unwrap();
                actors = Actors::restore(&actors.checkpoint().unwrap()).unwrap();
            }
        }
        block(&mut bytes, &geometry.checkpoint());
        block(&mut bytes, &actors.checkpoint().unwrap());
        for id in (1..=KINDS.len() as u32).step_by(3) {
            let Actor::Structure(mut st) = actors.remove(id).unwrap() else {
                unreachable!()
            };
            st.gone = true;
            geometry.retire_structure(&mut st, &actors).unwrap();
            block(&mut bytes, &st.checkpoint().unwrap());
        }
        geometry.tick_cover(67).unwrap();
        block(&mut bytes, &geometry.checkpoint());
        geometry = WorldGeometry::restore(&geometry.checkpoint()).unwrap();
        geometry.finish_tick();
        block(&mut bytes, &geometry.checkpoint());
    }
    bytes
}
