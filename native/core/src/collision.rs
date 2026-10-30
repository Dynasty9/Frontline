//! Segment queries against the battlefield's box colliders, independent of physics frames.
pub use glam::Mat3;
use glam::Vec3;
use std::collections::HashMap;

const CELL: f32 = 32.0;

#[derive(Clone, Copy)]
pub struct BoxShape {
    pub body: i64,
    pub shape: i32,
    pub center: Vec3,
    pub basis: Mat3,
    pub half: Vec3,
}

struct IndexedBox {
    shape: BoxShape,
    inverse: Mat3,
    cells: Vec<(i32, i32)>,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct RayHit {
    pub body: i64,
    pub shape: i32,
    pub fraction: f32,
    pub position: Vec3,
    pub normal: Vec3,
}

#[derive(Default)]
pub struct CollisionWorld {
    boxes: Vec<Option<IndexedBox>>,
    bodies: HashMap<i64, Vec<usize>>,
    cells: HashMap<(i32, i32), Vec<usize>>,
    free: Vec<usize>,
    visited: Vec<u64>,
    generation: u64,
}

impl CollisionWorld {
    pub fn remove(&mut self, body: i64) {
        if let Some(indices) = self.bodies.remove(&body) {
            for index in indices {
                if let Some(shape) = self.boxes[index].take() {
                    for cell in shape.cells {
                        let empty = if let Some(indices) = self.cells.get_mut(&cell) {
                            indices.retain(|i| *i != index);
                            indices.is_empty()
                        } else {
                            false
                        };
                        if empty {
                            self.cells.remove(&cell);
                        }
                    }
                    self.free.push(index);
                }
            }
        }
    }

    pub fn replace(&mut self, body: i64, shapes: &[BoxShape]) -> bool {
        // Bound registration before mutating the live world.
        if body < 0
            || shapes.iter().any(|s| {
                s.body != body
                    || s.shape < 0
                    || !s.center.is_finite()
                    || !s.basis.is_finite()
                    || !s.half.is_finite()
                    || s.half.min_element() <= 0.0
                    || !s.basis.determinant().is_finite()
                    || s.basis.determinant().abs() < 1e-8
                    || !s.basis.inverse().is_finite()
                    || (s.basis.abs() * s.half).max_element() > 4096.0
                    || s.center.abs().max_element() > 1_000_000.0
            })
        {
            return false;
        }
        self.remove(body);
        let mut body_indices = Vec::with_capacity(shapes.len());
        for &shape in shapes {
            let extent = shape.basis.abs() * shape.half;
            let low = shape.center - extent;
            let high = shape.center + extent;
            let mut cells = Vec::new();
            for x in cell(low.x)..=cell(high.x) {
                for z in cell(low.z)..=cell(high.z) {
                    cells.push((x, z));
                }
            }
            let entry = Some(IndexedBox {
                shape,
                inverse: shape.basis.inverse(),
                cells,
            });
            let index = if let Some(index) = self.free.pop() {
                self.boxes[index] = entry;
                self.visited[index] = 0;
                index
            } else {
                self.boxes.push(entry);
                self.visited.push(0);
                self.boxes.len() - 1
            };
            for &cell in &self.boxes[index].as_ref().unwrap().cells {
                self.cells.entry(cell).or_default().push(index);
            }
            body_indices.push(index);
        }
        self.bodies.insert(body, body_indices);
        true
    }

    pub fn ray(&mut self, from: Vec3, to: Vec3, excluded: &[i64]) -> Option<RayHit> {
        if !from.is_finite()
            || !to.is_finite()
            || from.abs().max_element() > 1_000_000.0
            || to.abs().max_element() > 1_000_000.0
            || from == to
        {
            return None;
        }
        self.generation = self.generation.wrapping_add(1);
        if self.generation == 0 {
            self.visited.fill(0);
            self.generation = 1;
        }
        let delta = to - from;
        let mut x = cell(from.x);
        let mut z = cell(from.z);
        let end = (cell(to.x), cell(to.z));
        let sx = if delta.x > 0.0 { 1 } else { -1 };
        let sz = if delta.z > 0.0 { 1 } else { -1 };
        let dx = if delta.x == 0.0 {
            f32::INFINITY
        } else {
            CELL / delta.x.abs()
        };
        let dz = if delta.z == 0.0 {
            f32::INFINITY
        } else {
            CELL / delta.z.abs()
        };
        let mut tx = if delta.x == 0.0 {
            f32::INFINITY
        } else {
            ((x + i32::from(sx > 0)) as f32 * CELL - from.x) / delta.x
        };
        let mut tz = if delta.z == 0.0 {
            f32::INFINITY
        } else {
            ((z + i32::from(sz > 0)) as f32 * CELL - from.z) / delta.z
        };
        let mut best: Option<RayHit> = None;
        loop {
            if let Some(indices) = self.cells.get(&(x, z)) {
                for &index in indices {
                    if self.visited[index] == self.generation {
                        continue;
                    }
                    self.visited[index] = self.generation;
                    let entry = self.boxes[index].as_ref().unwrap();
                    if excluded.contains(&entry.shape.body) {
                        continue;
                    }
                    if let Some(hit) = intersect(entry, from, delta) {
                        if best.is_none_or(|old| {
                            hit.fraction < old.fraction
                                || (hit.fraction == old.fraction
                                    && (hit.body, hit.shape) < (old.body, old.shape))
                        }) {
                            best = Some(hit);
                        }
                    }
                }
            }
            if (x, z) == end || best.is_some_and(|hit| hit.fraction < tx.min(tz)) {
                break;
            }
            // At a grid corner both axes cross; no wall-clock or worker ordering.
            let next = tx.min(tz);
            if next > 1.0 {
                break;
            }
            if tx <= next {
                x += sx;
                tx += dx;
            }
            if tz <= next {
                z += sz;
                tz += dz;
            }
        }
        best
    }
}

fn cell(value: f32) -> i32 {
    (value / CELL).floor() as i32
}

fn intersect(entry: &IndexedBox, from: Vec3, delta: Vec3) -> Option<RayHit> {
    let start = entry.inverse * (from - entry.shape.center);
    let direction = entry.inverse * delta;
    let half = entry.shape.half;
    // Match ray queries with hit_from_inside disabled.
    if start.abs().cmple(half).all() {
        return None;
    }
    let mut enter: f32 = 0.0;
    let mut leave: f32 = 1.0;
    let mut normal = Vec3::ZERO;
    for axis in 0..3 {
        if direction[axis].abs() < 1e-8 {
            if start[axis].abs() > half[axis] {
                return None;
            }
            continue;
        }
        let a = (-half[axis] - start[axis]) / direction[axis];
        let b = (half[axis] - start[axis]) / direction[axis];
        let near = a.min(b);
        leave = leave.min(a.max(b));
        if near > enter {
            enter = near;
            normal = Vec3::ZERO;
            normal[axis] = if a < b { -1.0 } else { 1.0 };
        }
        if enter > leave {
            return None;
        }
    }
    if normal == Vec3::ZERO {
        return None;
    }
    Some(RayHit {
        body: entry.shape.body,
        shape: entry.shape.shape,
        fraction: enter,
        position: from + delta * enter,
        normal: (entry.inverse.transpose() * normal).normalize(),
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::random::SimulationRandom;

    fn box_at(body: i64, center: Vec3) -> BoxShape {
        BoxShape {
            body,
            shape: 0,
            center,
            basis: Mat3::IDENTITY,
            half: Vec3::ONE,
        }
    }

    #[test]
    fn boxes_respect_exclusion_inside_origins_edits_and_stable_ties() {
        let mut world = CollisionWorld::default();
        for body in [2, 1] {
            assert!(world.replace(body, &[box_at(body, Vec3::new(5.0, 0.0, 0.0))]));
        }
        let hit = world.ray(Vec3::ZERO, Vec3::X * 10.0, &[]).unwrap();
        assert_eq!(
            (hit.body, hit.position, hit.normal),
            (1, Vec3::X * 4.0, -Vec3::X)
        );
        assert_eq!(world.ray(Vec3::ZERO, Vec3::X * 10.0, &[1]).unwrap().body, 2);
        assert!(world.ray(Vec3::X * 5.0, Vec3::X * 10.0, &[]).is_none());
        world.remove(1);
        world.replace(2, &[box_at(2, Vec3::new(-70.0, 0.0, 0.0))]);
        assert!(world.ray(Vec3::ZERO, Vec3::X * 10.0, &[]).is_none());
        assert_eq!(
            world
                .ray(Vec3::ZERO, Vec3::X * -100.0, &[])
                .unwrap()
                .position
                .x,
            -69.0
        );
        let mut invalid = box_at(2, Vec3::ZERO);
        invalid.half.x = -1.0;
        assert!(!world.replace(2, &[invalid]));
        assert!(world.ray(Vec3::ZERO, Vec3::X * -100.0, &[]).is_some());
        invalid.half = Vec3::splat(1e-20);
        invalid.basis = Mat3::from_diagonal(Vec3::splat(1e20));
        assert!(
            !world.replace(2, &[invalid]),
            "Overflowing inverse must not enter the index"
        );
        assert!(world.ray(Vec3::ZERO, Vec3::X * -100.0, &[]).is_some());
    }

    #[test]
    fn grid_traversal_matches_exhaustive_queries_with_rotated_scaled_boxes() {
        let mut world = CollisionWorld::default();
        let mut rng = SimulationRandom::new(581);
        for body in 0..300 {
            let shape = BoxShape {
                body,
                shape: 0,
                center: Vec3::new(
                    rng.randf_range(-160.0, 160.0),
                    rng.randf_range(-4.0, 8.0),
                    rng.randf_range(-160.0, 160.0),
                ),
                basis: Mat3::from_rotation_y(rng.randf_range(-3.0, 3.0))
                    * Mat3::from_diagonal(Vec3::new(1.0, 2.0, 0.5)),
                half: Vec3::new(
                    rng.randf_range(0.1, 12.0),
                    rng.randf_range(0.1, 3.0),
                    rng.randf_range(0.1, 12.0),
                ),
            };
            assert!(world.replace(body, &[shape]));
        }
        for _ in 0..3000 {
            let from = Vec3::new(
                rng.randf_range(-200.0, 200.0),
                rng.randf_range(-10.0, 15.0),
                rng.randf_range(-200.0, 200.0),
            );
            let to = Vec3::new(
                rng.randf_range(-200.0, 200.0),
                rng.randf_range(-10.0, 15.0),
                rng.randf_range(-200.0, 200.0),
            );
            let expected = world
                .boxes
                .iter()
                .flatten()
                .filter_map(|entry| intersect(entry, from, to - from))
                .min_by(|a, b| {
                    a.fraction
                        .total_cmp(&b.fraction)
                        .then_with(|| (a.body, a.shape).cmp(&(b.body, b.shape)))
                });
            assert_eq!(world.ray(from, to, &[]), expected);
        }
    }
}
