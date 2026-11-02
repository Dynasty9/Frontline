use frontline_core::{
    infantry_controller::Controller,
    infantry_shock::InfantryShock,
    infantry_vitals::Life,
    navigation_scene::NavigationScene,
    path_planner::PathJob,
    random::SimulationRandom,
    structure::{Part, Structure},
    terrain::{Terrain, BASE, SHALLOW},
    traversal::Ground,
    vector::{normalized, Vector3},
};

pub fn transcript() -> Vec<u8> {
    let mut out = Vec::new();
    for layout in 0..4 {
        let mut terrain = Terrain::blank(32).unwrap();
        let mut deck = vec![0; 1024];
        if layout == 1 || layout == 2 {
            let heights = (0..81)
                .map(|i| {
                    let x = i % 9;
                    if layout == 1 {
                        x as f32 * 4. * 0.55
                    } else if x >= 5 {
                        12.
                    } else {
                        0.
                    }
                })
                .collect();
            assert!(terrain.set_landform(heights));
            for z in 0..64 {
                for x in 0..64 {
                    let p = Vector3::new(
                        (x as f32 + 0.5) * 0.5 - 16.,
                        0.,
                        (z as f32 + 0.5) * 0.5 - 16.,
                    );
                    terrain.heights[z * 64 + x] = terrain.landform.height(p) as f32;
                }
            }
        }
        if layout == 3 {
            for z in 0..32 {
                for x in 14..18 {
                    terrain.layers[BASE][z * 32 + x] = SHALLOW;
                    deck[z * 32 + x] = u8::from((14..18).contains(&z));
                }
            }
            for z in 0..64 {
                for x in 28..36 {
                    terrain.heights[z * 64 + x] = -2.;
                }
            }
        }
        let mut nav = NavigationScene::new(&terrain, &deck, 16).unwrap();
        let mut wall = Structure {
            id: 1,
            kind: "house_wall".into(),
            built: true,
            position: Vector3::new(0.6, 0., -4.),
            parts: vec![Part {
                position: Vector3::ZERO,
                size: Vector3::new(0.6, 2., 5.),
                yaw: 0.37,
                infantry: 3,
                vehicle: 3,
                cover: true,
                collision: true,
                door: false,
            }],
            ..Default::default()
        };
        nav.add_structure(&mut wall, &terrain, &deck).unwrap();
        assert!(nav.finalize(1));
        let mut rng = SimulationRandom::new(41379);
        let mut previous = Vec::new();
        for query in 0..96 {
            if query == 48 {
                nav.remove_structure(&mut wall, &terrain, &deck).unwrap();
                nav.stamp_heat(Vector3::new(5., 0., 3.), 4.7, 1, &terrain, &deck)
                    .unwrap();
            }
            assert!(nav.update_hierarchy(query % 4));
            let mut from = Vector3::new(rng.randf_range(-13., 13.), 0., rng.randf_range(-13., 13.));
            let mut to = Vector3::new(rng.randf_range(-13., 13.), 0., rng.randf_range(-13., 13.));
            if query % 9 == 0 {
                from = Vector3::new(-0.5, 0., -4.3);
                to = Vector3::new([0.1, 0.6, 1.5][(query / 9) % 3], 0., -4.3);
            }
            let ground = Ground::new(&terrain, &deck);
            let vehicle = query % 3 != 0;
            let tracked = query % 3 == 2;
            let recovered = nav
                .planner
                .nearest_walkable_for(from, vehicle, tracked, ground)
                .unwrap();
            for value in recovered.to_array() {
                out.extend_from_slice(&value.to_le_bytes());
            }
            out.push(u8::from(
                nav.planner.step_clear(from, to, vehicle, tracked, ground),
            ));
            out.push(u8::from(
                nav.planner.line_free(from, to, vehicle, tracked, ground),
            ));
            let graph = if tracked {
                &mut nav.tracked
            } else if vehicle {
                &mut nav.vehicles
            } else {
                &mut nav.infantry
            };
            let route = nav.planner.find_path(
                graph,
                from,
                to,
                vehicle,
                (query % 2) as i32,
                1.,
                tracked,
                ground,
            );
            out.extend_from_slice(&(route.len() as u32).to_le_bytes());
            for p in route {
                super::point(&mut out, p);
            }
            let position = from + Vector3::Y * (ground.height(from) + 1.2) as f32;
            let mut controller = Controller {
                dive_timer: 0.8,
                dive_direction: normalized(to - from),
                ..Default::default()
            };
            let dive = controller
                .dive(position, 0.4, 0.1, &nav.planner, ground)
                .unwrap();
            super::point(&mut out, dive.position);
            super::block(&mut out, &controller.checkpoint());
            let mut shock = InfantryShock {
                flinging: true,
                velocity: normalized(to - from) * 9. - Vector3::Y * 4.,
                ..Default::default()
            };
            let landing = shock
                .fling_step(position, Life::Alive, 0.8, &nav.planner, &mut rng, ground)
                .unwrap();
            super::point(&mut out, landing.position);
            out.extend_from_slice(&[
                u8::from(landing.landed),
                u8::from(landing.dazed),
                u8::from(landing.speak),
            ]);
            super::block(&mut out, &shock.checkpoint());
            out.extend_from_slice(&rng.state().to_le_bytes());
            if query % 23 == 0 {
                assert!(nav.planner.request(PathJob {
                    id: query as u64 + 1,
                    destination: to,
                    vehicle,
                    tracked,
                    team: 0,
                    care: 1.
                }));
                let saved = nav.checkpoint();
                let restored = NavigationScene::restore(&saved).unwrap();
                assert_eq!(saved, restored.checkpoint());
                nav = restored;
                super::squad_orders::delta(&mut out, &mut previous, saved);
            }
        }
    }
    out
}
