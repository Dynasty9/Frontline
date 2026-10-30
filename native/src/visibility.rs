use crate::collision_index::CollisionIndexCore;
use frontline_core::vector::Vector3 as Point;
use frontline_core::visibility::{Sight, Smoke, Visibility};
use godot::prelude::*;

#[derive(GodotClass)]
#[class(base=RefCounted, init)]
struct VisibilityCore {
    base: Base<RefCounted>,
    core: Visibility,
    points: Vec<Point>,
}

#[godot_api]
impl VisibilityCore {
    #[func]
    fn set_projectile(&mut self, id: i64, center: Vector3, radius: f64) -> bool {
        self.core.set_projectile(
            id as u64,
            Smoke {
                center: crate::point(center),
                radius,
            },
        )
    }
    #[func]
    fn remove_projectile(&mut self, id: i64) {
        self.core.remove_projectile(id as u64);
    }
    #[func]
    fn set_fires(&mut self, rows: PackedFloat64Array) -> bool {
        if rows.len() % 4 != 0 || rows.len() > 400_000 {
            return false;
        }
        let fires: Vec<_> = rows
            .as_slice()
            .chunks_exact(4)
            .map(|r| Smoke {
                center: Point::new(r[0] as f32, r[1] as f32, r[2] as f32),
                radius: r[3],
            })
            .collect();
        self.core.set_fires(&fires)
    }
    #[func]
    fn smoke_blocks(&self, from: Vector3, to: Vector3) -> bool {
        self.core.smoke_blocks(crate::point(from), crate::point(to))
    }
    #[func]
    fn can_see(
        &mut self,
        mut collision: Gd<CollisionIndexCore>,
        eye: Vector3,
        target: i64,
        points: PackedVector3Array,
        excluded: PackedInt64Array,
        cache: bool,
    ) -> i32 {
        if target < 0 || points.len() > 256 || excluded.len() > 4096 {
            return -1;
        }
        self.points.clear();
        self.points
            .extend(points.as_slice().iter().map(|p| crate::point(*p)));
        match self.core.can_see(
            &mut collision.bind_mut().core,
            crate::point(eye),
            target as u64,
            &self.points,
            excluded.as_slice(),
            cache,
        ) {
            Some(Sight::Hidden) => 0,
            Some(Sight::Visible) => 1,
            Some(Sight::ReusedObstruction) => 2,
            None => -1,
        }
    }
    #[func]
    fn rays(&self) -> i64 {
        self.core.rays as i64
    }
    #[func]
    fn checkpoint(&self) -> PackedByteArray {
        self.core.checkpoint().as_slice().into()
    }
    #[func]
    fn restore(&mut self, bytes: PackedByteArray) -> bool {
        let Ok(core) = Visibility::restore(bytes.as_slice()) else {
            return false;
        };
        self.core = core;
        true
    }
}
