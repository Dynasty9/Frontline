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
    fn spawn_vehicle(
        &mut self,
        mut actors: Gd<ActorStateCore>,
        spawn: Array<Variant>,
        definition: Array<Variant>,
    ) -> i64 {
        use frontline_core::vehicle_birth::{Definition, Spawn};
        if spawn.len() != 4 || definition.len() != 6 {
            return 0;
        }
        let (
            Ok(team),
            Ok(owner),
            Ok(position),
            Ok(yaw),
            Ok(kind),
            Ok(base),
            Ok(hp),
            Ok(hull),
            Ok(atgm),
            Ok(sam),
        ) = (
            spawn.at(0).try_to::<i8>(),
            spawn.at(1).try_to::<i32>(),
            spawn.at(2).try_to::<Vector3>(),
            spawn.at(3).try_to::<f64>(),
            definition.at(0).try_to::<GString>(),
            definition.at(1).try_to::<GString>(),
            definition.at(2).try_to::<f64>(),
            definition.at(3).try_to::<Vector3>(),
            definition.at(4).try_to::<i32>(),
            definition.at(5).try_to::<i32>(),
        )
        else {
            return 0;
        };
        let Some(g) = &mut self.core else {
            return 0;
        };
        g.spawn_vehicle(
            &mut actors.bind_mut().core,
            Spawn {
                team,
                owner,
                position: crate::point(position),
                yaw,
            },
            Definition {
                kind: &kind.to_string(),
                base: &base.to_string(),
                hp,
                hull: crate::point(hull),
                missiles: [atgm, sam],
            },
        )
        .map_or(0, i64::from)
    }
    #[func]
    fn formation_slots(
        &self,
        actors: Gd<ActorStateCore>,
        center: Vector3,
        face: Vector3,
        count: i32,
        wide: bool,
    ) -> Array<Variant> {
        let Some(g) = &self.core else {
            return Array::new();
        };
        if count < 0 {
            return Array::new();
        }
        let actors = actors.bind();
        let Ok(slots) = g.formation_slots(
            &actors.core,
            crate::point(center),
            crate::point(face),
            count as usize,
            wide,
        ) else {
            return Array::new();
        };
        slots
            .into_iter()
            .map(|slot| {
                let mut info = Dictionary::<Variant, Variant>::new();
                if let Some((id, ai)) = slot.anchor {
                    let st = actors.core.structure(id).unwrap();
                    let a = st.anchors[ai];
                    let material = if a.kind == frontline_core::cover::AnchorKind::Stack {
                        st.cover_material().saturating_sub(1)
                    } else {
                        st.cover_material()
                    };
                    info.set("n", Vector3::new(a.normal.x, a.normal.y, a.normal.z));
                    info.set("h", a.height);
                    info.set("k", a.kind as i32);
                    info.set("mat", material as i32);
                    info.set("eid", id);
                }
                varray![
                    Vector3::new(slot.position.x, slot.position.y, slot.position.z),
                    slot.cover,
                    &info
                ]
                .to_variant()
            })
            .collect()
    }
    #[func]
    fn toss_structure(
        &mut self,
        mut actors: Gd<ActorStateCore>,
        id: u32,
        blast: Vector3,
        size: f64,
        mut rng: Gd<crate::simulation_random::SimulationRandomCore>,
    ) -> Array<Variant> {
        let Some(g) = &mut self.core else {
            return Array::new();
        };
        match g.toss_structure(
            &mut actors.bind_mut().core,
            id,
            crate::point(blast),
            size,
            &mut rng.bind_mut().core,
        ) {
            Ok(None) => varray![false],
            Ok(Some(t)) => varray![
                true,
                Vector3::new(t.origin.x, t.origin.y, t.origin.z),
                t.yaw,
                Vector3::new(t.velocity.x, t.velocity.y, t.velocity.z),
                Vector3::new(t.spin.x, t.spin.y, t.spin.z)
            ],
            Err(_) => Array::new(),
        }
    }
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
