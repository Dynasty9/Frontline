use frontline_core::hierarchy::{build_all, Hierarchy};
use godot::prelude::*;

#[derive(GodotClass)]
#[class(base=RefCounted, init)]
pub(crate) struct HierarchyCore {
    base: Base<RefCounted>,
    pub(crate) core: Option<Hierarchy>,
}

#[godot_api]
impl HierarchyCore {
    #[func]
    fn checkpoint(&self) -> PackedByteArray {
        self.core
            .as_ref()
            .map_or_else(PackedByteArray::new, |core| {
                core.checkpoint().as_slice().into()
            })
    }

    #[func]
    fn restore(&mut self, bytes: PackedByteArray) -> bool {
        let Ok(core) = Hierarchy::restore(bytes.as_slice()) else {
            return false;
        };
        self.core = Some(core);
        true
    }

    #[func]
    fn configure(&mut self, side: i32, cluster: i32) -> bool {
        let Some(core) = Hierarchy::new(side as usize, cluster as usize) else {
            return false;
        };
        self.core = Some(core);
        true
    }

    #[func]
    fn load_cells(&mut self, solid: PackedByteArray, weight: PackedFloat32Array) -> bool {
        self.core
            .as_mut()
            .is_some_and(|core| core.load_cells(solid.as_slice(), weight.as_slice()))
    }

    #[func]
    fn set_cell(&mut self, cell: Vector2i, solid: bool, weight: f64) -> bool {
        self.core
            .as_mut()
            .is_some_and(|core| core.set_cell([cell.x, cell.y], solid, weight as f32))
    }

    #[func]
    fn build(&mut self) -> bool {
        let Some(core) = self.core.as_mut() else {
            return false;
        };
        let workers = std::thread::available_parallelism().map_or(1, usize::from);
        build_all(&mut [core], workers)
    }

    #[func]
    fn build_with(&mut self, mut other: Gd<HierarchyCore>) -> bool {
        if other.instance_id() == self.base().instance_id() {
            return false;
        }
        let mut other = other.bind_mut();
        let (Some(a), Some(b)) = (self.core.as_mut(), other.core.as_mut()) else {
            return false;
        };
        let workers = std::thread::available_parallelism().map_or(1, usize::from);
        build_all(&mut [a, b], workers)
    }

    #[func]
    fn terrain_revision(&self) -> i64 {
        self.core
            .as_ref()
            .map_or(0, |core| core.terrain_revision as i64)
    }

    #[func]
    fn danger_revision(&self, team: i32) -> i64 {
        self.core.as_ref().map_or(0, |core| {
            core.danger_revision
                .get(team as usize)
                .copied()
                .unwrap_or(0) as i64
        })
    }

    #[func]
    fn update(&mut self, budget: i32) -> bool {
        if !(0..=65536).contains(&budget) {
            return false;
        }
        self.core
            .as_mut()
            .is_some_and(|core| core.update(budget as usize))
    }

    #[func]
    fn set_danger(&mut self, team: i32, values: PackedFloat32Array) -> bool {
        self.core
            .as_mut()
            .is_some_and(|core| core.set_danger(team as usize, values.as_slice()))
    }

    #[func]
    fn route(&mut self, from: Vector2i, to: Vector2i, team: i32, care: f64) -> Array<Vector2i> {
        if !care.is_finite() {
            return Array::new();
        }
        let Some(core) = self.core.as_mut() else {
            return Array::new();
        };
        core.route([from.x, from.y], [to.x, to.y], team, care)
            .into_iter()
            .map(|p| Vector2i::new(p[0], p[1]))
            .collect()
    }

    #[func]
    fn local_path(&mut self, cluster: i32, from: Vector2i, to: Vector2i) -> Array<Vector2i> {
        let Some(core) = self.core.as_mut() else {
            return Array::new();
        };
        core.local_path(cluster as usize, [from.x, from.y], [to.x, to.y])
            .into_iter()
            .map(|p| Vector2i::new(p[0], p[1]))
            .collect()
    }

    #[func]
    fn revisions(&self) -> PackedInt64Array {
        self.core
            .as_ref()
            .map_or_else(PackedInt64Array::new, |core| {
                PackedInt64Array::from(&[
                    core.terrain_revision as i64,
                    core.danger_revision[0] as i64,
                    core.danger_revision[1] as i64,
                ])
            })
    }

    #[func]
    fn pending_clusters(&self) -> PackedInt32Array {
        self.core
            .as_ref()
            .map_or_else(PackedInt32Array::new, |core| {
                core.pending_clusters()
                    .into_iter()
                    .map(|i| i as i32)
                    .collect()
            })
    }

    #[func]
    fn cached_clusters(&self) -> PackedInt32Array {
        self.core
            .as_ref()
            .map_or_else(PackedInt32Array::new, |core| {
                core.cached_clusters()
                    .into_iter()
                    .map(|i| i as i32)
                    .collect()
            })
    }

    #[func]
    fn counts(&self) -> Vector2i {
        self.core.as_ref().map_or(Vector2i::ZERO, |core| {
            let [nodes, points] = core.counts();
            Vector2i::new(nodes as i32, points as i32)
        })
    }

    #[func]
    fn has_work(&self) -> bool {
        self.core.as_ref().is_some_and(Hierarchy::has_work)
    }
}
