use godot::classes::Node3D;
use godot::prelude::*;
use std::collections::HashMap;

struct Motion {
    node: Gd<Node3D>,
    position: Vector3,
    rotation: Vector3,
    target: Vector3,
    yaw: f64,
    batch: Option<(i32, i32)>,
}

#[derive(GodotClass)]
#[class(base=RefCounted, init)]
struct SoldierViewMotion {
    base: Base<RefCounted>,
    targets: HashMap<godot::obj::InstanceId, Motion>,
}

#[godot_api]
impl SoldierViewMotion {
    #[func]
    fn target(&mut self, node: Gd<Node3D>, target: Vector3, yaw: f64, reset: bool) {
        let id = node.instance_id();
        if !reset {
            if let Some(motion) = self.targets.get_mut(&id) {
                motion.target = target;
                motion.yaw = yaw;
                return;
            }
        }
        let batch = self.targets.get(&id).and_then(|motion| motion.batch);
        // Only the view loop and property corrections move client soldier roots.
        self.targets.insert(
            id,
            Motion {
                position: node.get_position(),
                rotation: node.get_rotation(),
                node,
                target,
                yaw,
                batch,
            },
        );
    }

    #[func]
    fn set_batch(&mut self, node: Gd<Node3D>, mesh: i32, pose: i32) -> bool {
        if let Some(motion) = self.targets.get_mut(&node.instance_id()) {
            let batch = (mesh >= 0 && (0..=255).contains(&pose)).then_some((mesh, pose));
            let changed = motion.batch != batch;
            motion.batch = batch;
            return changed;
        }
        false
    }

    #[func]
    fn batches(&self, planes: Array<Plane>, radii: PackedFloat32Array) -> Array<VarDictionary> {
        use crate::soldier_batch_buffer::SoldierBatchBuffer;
        const CELL: f32 = 64.0;
        let mut groups: HashMap<Vector3i, (Gd<SoldierBatchBuffer>, i32)> = HashMap::new();
        let mut visible = HashMap::new();
        for motion in self.targets.values() {
            let Some((mesh, pose)) = motion.batch else {
                continue;
            };
            if !motion.node.is_instance_valid() || mesh as usize >= radii.len() {
                continue;
            }
            let mut transform = motion.node.get_transform();
            let position = transform.origin;
            if !position.is_finite() {
                continue;
            }
            let cell = Vector2i::new(
                (position.x / CELL).floor() as i32,
                (position.z / CELL).floor() as i32,
            );
            if position.y.abs() < 60.0
                && !*visible.entry(cell).or_insert_with(|| {
                    let center = Vector3::new(
                        (cell.x as f32 + 0.5) * CELL,
                        0.0,
                        (cell.y as f32 + 0.5) * CELL,
                    );
                    let extent = Vector3::new(CELL * 1.5, 64.0, CELL * 1.5);
                    planes
                        .iter_shared()
                        .all(|plane| plane.distance_to(center) <= plane.normal.abs().dot(extent))
                })
            {
                continue;
            }
            let key = Vector3i::new(cell.x, cell.y, mesh);
            let (buffer, count) = groups
                .entry(key)
                .or_insert_with(|| (SoldierBatchBuffer::new_gd(), 0));
            transform.origin -= Vector3::new(cell.x as f32 * CELL, 0.0, cell.y as f32 * CELL);
            let turn = godot::global::angle_difference(motion.rotation.y as f64, motion.yaw);
            if buffer.bind_mut().append(
                transform,
                motion.target - position,
                turn,
                pose,
                radii[mesh as usize] as f64,
            ) {
                *count += 1;
            }
        }
        groups.into_iter().filter(|(_, (_, count))| *count > 0).map(|(key, (buffer, count))| {
            let buffer = buffer.bind();
            vdict! { "key" => key, "count" => count, "data" => &buffer.encode(count), "bounds" => buffer.bounds() }
        }).collect()
    }

    #[func]
    fn remove(&mut self, node: Gd<Node3D>) {
        self.targets.remove(&node.instance_id());
    }

    #[func]
    fn advance(&mut self, blend: f64) -> bool {
        let mut teleported = false;
        self.targets.retain(|_, motion| {
            if !motion.node.is_instance_valid() {
                return false;
            }
            teleported |= Self::smooth(motion, blend);
            true
        });
        teleported
    }

    fn smooth(motion: &mut Motion, blend: f64) -> bool {
        let position = motion.position;
        let rotation = motion.rotation;
        let target = motion.target;
        let offset = target - position;
        let moving = offset.y.abs() > 0.01 || offset.length() > 0.01;
        let teleported = offset.length() > 8.0;
        if moving {
            let next = if teleported {
                target
            } else {
                position.lerp(target, blend as f32)
            };
            if next != position {
                motion.node.set_position(next);
                motion.position = next;
            }
        }
        let mut next_rotation = rotation;
        next_rotation.y = godot::global::lerp_angle(rotation.y as f64, motion.yaw, blend) as f32;
        // Unchanged transforms still dirty every child model in the scene tree.
        if next_rotation != rotation {
            motion.node.set_rotation(next_rotation);
            motion.rotation = next_rotation;
        }
        teleported
    }
}
