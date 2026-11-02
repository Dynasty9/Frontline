use frontline_core::actors::Actors;
use frontline_core::terrain::Terrain;
use frontline_core::vector::Vector3;
use frontline_core::vehicle_birth::{Definition, Spawn};
use frontline_core::world_geometry::WorldGeometry;
pub fn transcript() -> Vec<u8> {
    fn block(out: &mut Vec<u8>, bytes: &[u8]) {
        out.extend_from_slice(&(bytes.len() as u32).to_le_bytes());
        out.extend_from_slice(bytes);
    }
    let mut out = vec![];
    for trial in 0..12 {
        let mut actors = Actors::default();
        let mut geometry = WorldGeometry::new(Terrain::blank(32).unwrap(), vec![], 16).unwrap();
        for (i, base) in [
            "tank",
            "ifv",
            "boat",
            "supply",
            "attack_heli",
            "lift_heli",
            "uav",
            "ugv",
        ]
        .into_iter()
        .enumerate()
        {
            let spawn = Spawn {
                team: trial % 3 - 1,
                owner: trial as i32 - 2,
                position: Vector3::new(
                    i as f32 * 2.13 - 9.,
                    trial as f32 * 0.2,
                    i as f32 * -1.71 + 7.,
                ),
                yaw: trial as f64 * 0.317 - 1.3,
            };
            let definition = Definition {
                kind: base,
                base,
                hp: 200. + i as f64 * 75.,
                hull: Vector3::new(2.3 + i as f32 * 0.2, 2.6, 6.),
                missiles: [i as i32, trial as i32],
            };
            let id = geometry
                .spawn_vehicle(&mut actors, spawn, definition)
                .unwrap();
            block(&mut out, &actors.get(id).unwrap().checkpoint().unwrap());
            if i % 3 == 0 {
                actors = Actors::restore(&actors.checkpoint().unwrap()).unwrap();
                geometry = WorldGeometry::restore(&geometry.checkpoint()).unwrap();
            }
        }
        block(&mut out, &actors.checkpoint().unwrap());
        block(&mut out, &geometry.checkpoint());
    }
    out
}
