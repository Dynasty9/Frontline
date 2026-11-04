use godot::classes::Node3D;
use godot::prelude::*;
use std::collections::HashMap;

struct Motion {
    node: Gd<Node3D>,
    position: Vector3,
    rotation: Vector3,
    target: Vector3,
    yaw: f64,
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
        // Only the view loop and property corrections move client soldier roots.
        self.targets.insert(
            id,
            Motion {
                position: node.get_position(),
                rotation: node.get_rotation(),
                node,
                target,
                yaw,
            },
        );
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
