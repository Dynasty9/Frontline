use crate::{actors::ActorStateCore, structure::StructureStateCore};
use frontline_core::world_geometry::WorldGeometry;
use godot::prelude::*;

#[derive(GodotClass)]
#[class(base=RefCounted, init)]
pub(crate) struct WorldGeometryCore {
    base: Base<RefCounted>,
    pub(crate) core: Option<WorldGeometry>,
}
#[godot_api]
impl WorldGeometryCore {
    #[func]
    fn spawn_structure(
        &mut self,
        mut actors: Gd<ActorStateCore>,
        mut structure: Gd<StructureStateCore>,
        profile: PackedFloat64Array,
    ) -> i64 {
        let profile = match profile.as_slice() {
            [] => None,
            [x, z, hp] => Some(frontline_core::structure_birth::BuildingProfile {
                size: [*x as f32, *z as f32],
                hp: *hp,
            }),
            _ => return 0,
        };
        let mut st = structure.bind_mut();
        let (Some(g), Some(initial)) = (&mut self.core, &st.core) else {
            return 0;
        };
        let mut actors = actors.bind_mut();
        match g.spawn_structure(&mut actors.core, initial.clone(), profile) {
            Ok(id) => {
                st.core = actors.core.structure(id).cloned();
                i64::from(id)
            }
            Err(_) => 0,
        }
    }
    #[func]
    fn refresh_structure_collision(&mut self, structure: Gd<StructureStateCore>) -> bool {
        let st = structure.bind();
        let (Some(g), Some(st)) = (&mut self.core, &st.core) else {
            return false;
        };
        g.refresh_structure_collision(st).is_ok()
    }
    #[func]
    fn update_hierarchy(&mut self, clusters: i32) -> bool {
        clusters >= 0
            && self
                .core
                .as_mut()
                .is_some_and(|g| g.navigation.update_hierarchy(clusters as usize))
    }
    #[func]
    fn process_paths(
        &mut self,
        mut actors: Gd<ActorStateCore>,
        max_jobs: i32,
        now: f64,
        mut rng: Gd<crate::simulation_random::SimulationRandomCore>,
    ) -> bool {
        if max_jobs < 0 {
            return false;
        }
        self.core.as_mut().is_some_and(|g| {
            g.navigation
                .process_paths(
                    &mut actors.bind_mut().core,
                    max_jobs as usize,
                    now,
                    &mut rng.bind_mut().core,
                )
                .is_ok()
        })
    }
    #[func]
    fn restore(&mut self, bytes: PackedByteArray) -> bool {
        let Ok(core) = WorldGeometry::restore(bytes.as_slice()) else {
            return false;
        };
        self.core = Some(core);
        true
    }
    #[func]
    fn checkpoint(&self) -> PackedByteArray {
        self.core
            .as_ref()
            .map_or_else(PackedByteArray::new, |g| g.checkpoint().as_slice().into())
    }
    #[func]
    fn retire_structure(
        &mut self,
        mut structure: Gd<StructureStateCore>,
        actors: Gd<ActorStateCore>,
    ) -> bool {
        let mut structure = structure.bind_mut();
        let actors = actors.bind();
        let (Some(g), Some(st)) = (&mut self.core, &mut structure.core) else {
            return false;
        };
        g.retire_structure(st, &actors.core).is_ok()
    }
    #[func]
    fn sync_structure(&mut self, structure: Gd<StructureStateCore>, reindex: bool) -> bool {
        let structure = structure.bind();
        let (Some(g), Some(st)) = (&mut self.core, &structure.core) else {
            return false;
        };
        g.sync_structure(st, reindex).is_ok()
    }
    #[func]
    fn tick_cover(&mut self, budget: i32) -> bool {
        budget >= 0
            && self
                .core
                .as_mut()
                .is_some_and(|g| g.tick_cover(budget as usize).is_ok())
    }
    #[func]
    fn finish_tick(&mut self) {
        if let Some(g) = &mut self.core {
            g.finish_tick();
        }
    }
    #[func]
    fn inspect(&self) -> Array<PackedByteArray> {
        let Some(g) = &self.core else {
            return Array::new();
        };
        [
            g.terrain.checkpoint(),
            g.navigation.checkpoint(),
            g.collision.checkpoint(),
            g.structures.checkpoint(),
            g.doors.checkpoint(),
        ]
        .iter()
        .map(|b| PackedByteArray::from(b.as_slice()))
        .collect()
    }
    #[func]
    fn ray(&mut self, from: Vector3, to: Vector3) -> i64 {
        self.core
            .as_mut()
            .and_then(|g| g.collision.ray(crate::point(from), crate::point(to), &[]))
            .map_or(0, |hit| hit.body)
    }
}
