use frontline_core::actors::Actors;
use frontline_core::building_placement::{Definition, Distances};
use frontline_core::structure::Structure;
use frontline_core::structure_birth::BuildingProfile;
use frontline_core::supply_network::SupplyNetwork;
use frontline_core::terrain::{Terrain, BASE, WATER};
use frontline_core::vector::Vector3;
use frontline_core::water::Water;
use frontline_core::world_geometry::WorldGeometry;
pub fn transcript() -> Vec<u8> {
    let mut out = Vec::new();
    for trial in 0..12 {
        let mut a = Actors::default();
        let mut g =
            WorldGeometry::new(Terrain::blank(256).unwrap(), vec![0; 256 * 256], 16).unwrap();
        let mut w = Water {
            side: 256,
            coast: None,
            rivers: vec![],
            ponds: vec![],
            fords: vec![],
            bridges: vec![],
        };
        if trial % 2 == 0 {
            w.coast = Some([64., 0.]);
            for z in 0..256 {
                for x in 192..256 {
                    g.terrain.layers[BASE][z * 256 + x] = WATER;
                }
            }
        }
        for (kind, team, x, z) in [
            ("fob", 0, -40., 30.),
            ("fob", 1, 40., -30.),
            ("town", 0, -80., -60.),
            ("trench", 0, 0., 0.),
            ("camo_net", 0, 0., 30.),
            ("sandbags", 0, -20., 20.),
        ] {
            g.spawn_structure(
                &mut a,
                Structure {
                    kind: kind.into(),
                    team,
                    built: true,
                    position: Vector3::new(x, 0., z),
                    yaw: trial as f64 * 0.317 - 1.3,
                    size: Vector3::new(if kind == "trench" { 12. } else { 8. }, 3., 2.),
                    ..Default::default()
                },
                Some(BuildingProfile {
                    size: [8., 4.],
                    hp: 500.,
                }),
            )
            .unwrap();
        }
        let mut network = SupplyNetwork::default();
        network.roads[0].push(vec![
            Vector3::new(-90., 0., 20.),
            Vector3::new(90., 0., 20.),
        ]);
        let aa = Actors::restore(&a.checkpoint().unwrap()).unwrap();
        let gg = WorldGeometry::restore(&g.checkpoint()).unwrap();
        let ww = Water::restore(&w.checkpoint()).unwrap();
        let nn = SupplyNetwork::restore(&network.checkpoint().unwrap()).unwrap();
        for key in ["fob", "barracks", "trench", "camo_net", "dock", "mg_nest"] {
            for team in 0..2 {
                for index in 0..16 {
                    let at = if index == 0 {
                        Vector3::new(0., 0., 1.)
                    } else {
                        Vector3::new(
                            index as f32 * 15.137 - 120.,
                            0.,
                            (index % 4) as f32 * 29.713 - 45.,
                        )
                    };
                    let yaw = trial as f64 * 0.317 - 1.3;
                    let run = |a: &Actors, g: &WorldGeometry, w: &Water, n: &SupplyNetwork| {
                        let spot = g.trench_mount_spot(a, at, yaw).unwrap();
                        let error = g
                            .placement_error(
                                a,
                                n,
                                w,
                                team,
                                Some(&Definition {
                                    key,
                                    name: "Building",
                                    teams: 3,
                                    cost: 100,
                                    body: BuildingProfile {
                                        size: [8., 4.],
                                        hp: 500.,
                                    },
                                }),
                                at,
                                yaw,
                                &Distances {
                                    build: 70.,
                                    fob_spacing: 45.,
                                    fob_expand: 130.,
                                },
                                &|s| s.kind.clone(),
                            )
                            .unwrap();
                        let mut bytes = vec![u8::from(spot.is_some())];
                        if let Some(s) = spot {
                            for v in s.position.to_array() {
                                bytes.extend_from_slice(&v.to_le_bytes());
                            }
                            bytes.extend_from_slice(&s.yaw.to_le_bytes());
                            bytes.extend_from_slice(&s.variant.to_le_bytes());
                        }
                        bytes.extend_from_slice(&(error.len() as u32).to_le_bytes());
                        bytes.extend_from_slice(error.as_bytes());
                        bytes
                    };
                    let bytes = run(&a, &g, &w, &network);
                    assert_eq!(bytes, run(&aa, &gg, &ww, &nn));
                    out.extend_from_slice(&(bytes.len() as u32).to_le_bytes());
                    out.extend_from_slice(&bytes);
                }
            }
        }
    }
    out
}
