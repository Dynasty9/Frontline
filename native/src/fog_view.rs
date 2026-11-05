use std::collections::HashMap;

use godot::prelude::*;

use crate::terrain::TerrainCore;

const N: usize = 256;
const MARGIN: f64 = 128.0;

#[derive(Default)]
struct Horizon {
    generation: u64,
    pixels: Vec<usize>,
}

#[derive(GodotClass)]
#[class(base=RefCounted, init)]
struct FogSightMask {
    base: Base<RefCounted>,
    terrain_id: Option<godot::obj::InstanceId>,
    terrain_version: i64,
    generation: u64,
    cache: HashMap<[i32; 4], Horizon>,
    mask: Vec<u8>,
}

#[godot_api]
impl FogSightMask {
    #[func]
    fn raster(
        &mut self,
        terrain: Gd<TerrainCore>,
        observers: PackedVector4Array,
        version: i64,
    ) -> PackedByteArray {
        if observers.len() > 100_000
            || observers.as_slice().iter().any(|eye| {
                !eye.is_finite()
                    || eye.x.abs().max(eye.y.abs()).max(eye.z.abs()) > 1_000_000.0
                    || !(0.0..=4096.0).contains(&eye.w)
            })
        {
            return PackedByteArray::new();
        }
        let ground = terrain.bind();
        let Some(core) = &ground.core else {
            return PackedByteArray::new();
        };
        if self.terrain_id != Some(terrain.instance_id()) || self.terrain_version != version {
            self.cache.clear();
            self.terrain_id = Some(terrain.instance_id());
            self.terrain_version = version;
        }
        self.generation = self.generation.wrapping_add(1);
        self.mask.resize(N * N, 0);
        self.mask.fill(0);
        let k = N as f64 / (core.n as f64 + MARGIN * 2.0);
        let origin = core.half() + MARGIN;
        for eye in observers.as_slice() {
            let key = [
                (eye.x as f64 * k).round() as i32,
                (eye.z as f64 * k).round() as i32,
                (eye.y as f64).round() as i32,
                (eye.w as f64 * k).round() as i32,
            ];
            let horizon = self.cache.entry(key).or_insert_with(|| {
                let mut pixels = Vec::new();
                let mut seen = [false; N * N];
                let mut reveal = |x: i32, y: i32| {
                    if (0..N as i32).contains(&x) && (0..N as i32).contains(&y) {
                        let i = y as usize * N + x as usize;
                        if !seen[i] {
                            seen[i] = true;
                            pixels.push(i);
                        }
                    }
                };
                let center = Vector2::new(
                    ((eye.x as f64 + origin) * k) as f32,
                    ((eye.z as f64 + origin) * k) as f32,
                );
                let radius = (eye.w as f64 * k).ceil() as usize;
                reveal(center.x as i32, center.y as i32);
                let bearings = 32.max((std::f64::consts::TAU * radius as f64).ceil() as usize);
                // Keep the existing pixel horizon, but query terrain without crossing the script boundary.
                for bearing in 0..bearings {
                    let direction = Vector2::from_angle(
                        (bearing as f64 * std::f64::consts::TAU / bearings as f64) as f32,
                    );
                    let mut slope = f64::NEG_INFINITY;
                    for step in 1..=radius {
                        let p = center + direction * step as f32;
                        let (x, y) = (p.x as i32, p.y as i32);
                        if !(0..N as i32).contains(&x) || !(0..N as i32).contains(&y) {
                            break;
                        }
                        let target = frontline_core::vector::Vector3::new(
                            ((x as f64 + 0.5) / k - origin) as f32,
                            0.0,
                            ((y as f64 + 0.5) / k - origin) as f32,
                        );
                        let distance =
                            Vector2::new(target.x - eye.x, target.z - eye.z).length() as f64;
                        if distance > eye.w as f64 || distance < 0.1 {
                            continue;
                        }
                        let height = core.deform_at(target) - eye.y as f64;
                        if (height + 1.5) / distance >= slope {
                            reveal(x, y);
                        }
                        slope = slope.max(height / distance);
                    }
                }
                Horizon {
                    generation: 0,
                    pixels,
                }
            });
            horizon.generation = self.generation;
            for &pixel in &horizon.pixels {
                self.mask[pixel] = 255;
            }
        }
        self.cache
            .retain(|_, horizon| horizon.generation == self.generation);
        PackedByteArray::from(self.mask.as_slice())
    }
}
