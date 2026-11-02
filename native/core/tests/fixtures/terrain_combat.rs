use frontline_core::{
    collision::{BoxShape, CollisionWorld, Mat3, RayScene, Raycast},
    guided::{GuidedFlight, Kind as GuidedKind},
    projectile::{Flight, Holder, Kind, Outcome},
    random::SimulationRandom,
    support::{Kind as SupportKind, SupportFlight},
    terrain::Terrain,
    traversal::Ground,
    vector::Vector3,
    visibility::Visibility,
};

fn bytes(out: &mut Vec<u8>, data: &[u8]) {
    out.extend_from_slice(&(data.len() as u32).to_le_bytes());
    out.extend_from_slice(data);
}

pub fn transcript() -> Vec<u8> {
    let mut terrain = Terrain::blank(128).unwrap();
    let mut heights = Vec::new();
    for z in 0..33 {
        for x in 0..33 {
            heights.push((12. + 8. * libm::sin(x as f64 * 0.2) * libm::cos(z as f64 * 0.2)) as f32);
        }
    }
    assert!(terrain.set_landform(heights));
    for z in 0..256 {
        for x in 0..256 {
            let p = Vector3::new(
                (x as f32 + 0.5) * 0.5 - 64.,
                0.,
                (z as f32 + 0.5) * 0.5 - 64.,
            );
            terrain.heights[z * 256 + x] = terrain.landform.height(p) as f32;
        }
    }
    let mut boxes = CollisionWorld::default();
    for id in 1..12 {
        assert!(boxes.replace(
            id,
            &[BoxShape {
                body: id,
                shape: 0,
                center: Vector3::new(id as f32 * 5. - 30., 12., 0.),
                basis: Mat3::IDENTITY,
                half: Vector3::new(1., 8., 2.)
            }]
        ));
    }
    let mut rng = SimulationRandom::new(372018);
    let mut sight = Visibility::default();
    let mut out = Vec::new();
    for tick in 0..256 {
        let from = Vector3::new(
            rng.randf_range(-60., 60.),
            rng.randf_range(0., 35.),
            rng.randf_range(-20., 20.),
        );
        let to = Vector3::new(
            rng.randf_range(-60., 60.),
            rng.randf_range(0., 35.),
            rng.randf_range(-20., 20.),
        );
        if tick % 8 == 0 {
            let mut p = to;
            p.y = terrain.ground_y(p, false) as f32;
            terrain.crater(p, 3.);
        }
        let mut scene = RayScene {
            boxes: &mut boxes,
            ground: Ground::new(&terrain, &[]),
        };
        let hit = scene.ray(from, to, &[tick % 12]);
        out.push(u8::from(hit.is_some()));
        if let Some(hit) = hit {
            out.extend_from_slice(&hit.body.to_le_bytes());
            out.extend_from_slice(&hit.shape.to_le_bytes());
            for value in hit
                .position
                .to_array()
                .into_iter()
                .chain(hit.normal.to_array())
                .chain([hit.fraction])
            {
                out.extend_from_slice(&value.to_le_bytes());
            }
        }
        for _ in 0..2 {
            bytes(
                &mut out,
                format!("{:?}", sight.can_see(&mut scene, from, 1, &[to], &[], true)).as_bytes(),
            );
        }
    }
    for kind in [
        Kind::Frag,
        Kind::Smoke,
        Kind::Rocket,
        Kind::Recoilless,
        Kind::Mortar,
        Kind::MortarSmoke,
        Kind::Grad,
        Kind::Arty,
        Kind::Ac105,
        Kind::Ac40,
        Kind::Ac25,
        Kind::Bomb,
    ] {
        let origin = Vector3::new(-50., 18., 0.);
        let target = Vector3::new(50., 13., 0.);
        let mut f = Flight {
            kind,
            position: origin,
            velocity: Vector3::new(25., 2., 0.),
            origin,
            target,
            fuse: 3.4,
            flying: true,
            life: 0.,
            smoke_time: 0.,
            smoke_radius: 0.,
            shell_duration: 2.7,
        };
        for _ in 0..2000 {
            let outcome = f.advance_in_world(
                1. / 60.,
                Holder::Free,
                &mut RayScene {
                    boxes: &mut boxes,
                    ground: Ground::new(&terrain, &[]),
                },
                &[],
            );
            bytes(&mut out, &f.checkpoint());
            f = Flight::restore(&f.checkpoint()).unwrap();
            if outcome != Outcome::Flying {
                bytes(&mut out, format!("{outcome:?}").as_bytes());
                break;
            }
        }
    }
    for kind in [GuidedKind::AntiTank, GuidedKind::SurfaceToAir] {
        let mut f = GuidedFlight {
            kind,
            position: Vector3::new(-50., 18., 0.),
            velocity: Vector3::X * 20.,
            target: Vector3::new(50., 13., 0.),
            life: 0.,
            locked: true,
            dead: false,
        };
        for _ in 0..500 {
            let hit = f.advance(
                1. / 60.,
                None,
                false,
                &mut RayScene {
                    boxes: &mut boxes,
                    ground: Ground::new(&terrain, &[]),
                },
                &[],
            );
            bytes(&mut out, &f.checkpoint());
            if hit.is_some() {
                bytes(&mut out, format!("{hit:?}").as_bytes());
                break;
            }
        }
    }
    for kind in [SupportKind::Jet, SupportKind::GunRun, SupportKind::Orbit] {
        let mut f = SupportFlight::new(
            kind,
            Vector3::new(-100., 62., 0.),
            Vector3::X * 58.,
            Vector3::ZERO,
        );
        for tick in 0..2200 {
            let events = f.advance_in_world(
                1. / 60.,
                tick as f64 / 60.,
                0,
                64.,
                &[],
                &mut rng,
                &RayScene {
                    boxes: &mut boxes,
                    ground: Ground::new(&terrain, &[]),
                },
            );
            bytes(&mut out, &f.checkpoint());
            bytes(&mut out, format!("{events:?}").as_bytes());
            out.extend_from_slice(&rng.state().to_le_bytes());
            if f.dead {
                break;
            }
        }
    }
    out
}
