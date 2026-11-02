use crate::{structure::StructureStateCore, terrain::TerrainCore};
use frontline_core::navigation_scene::NavigationScene;
use godot::prelude::*;

#[derive(GodotClass)]
#[class(base=RefCounted, init)]
struct NavigationSceneCore {
    base: Base<RefCounted>,
    core: Option<NavigationScene>,
}
#[godot_api]
impl NavigationSceneCore {
    #[func]
    fn configure(
        &mut self,
        terrain: Gd<TerrainCore>,
        deck: PackedByteArray,
        cluster_side: i32,
    ) -> bool {
        let terrain = terrain.bind();
        let Some(terrain) = &terrain.core else {
            return false;
        };
        let Ok(core) = NavigationScene::new(terrain, deck.as_slice(), cluster_side as usize) else {
            return false;
        };
        self.core = Some(core);
        true
    }
    #[func]
    fn structure_changed(
        &mut self,
        mut structure: Gd<StructureStateCore>,
        terrain: Gd<TerrainCore>,
        deck: PackedByteArray,
        add: bool,
    ) -> bool {
        let mut structure = structure.bind_mut();
        let terrain = terrain.bind();
        let (Some(nav), Some(st), Some(terrain)) =
            (&mut self.core, &mut structure.core, &terrain.core)
        else {
            return false;
        };
        if add {
            nav.add_structure(st, terrain, deck.as_slice())
        } else {
            nav.remove_structure(st, terrain, deck.as_slice())
        }
        .is_ok()
    }
    #[func]
    fn terrain_changed(
        &mut self,
        index: i64,
        terrain: Gd<TerrainCore>,
        deck: PackedByteArray,
    ) -> bool {
        let terrain = terrain.bind();
        let (Some(nav), Some(terrain)) = (&mut self.core, &terrain.core) else {
            return false;
        };
        nav.terrain_changed(index as usize, terrain, deck.as_slice())
            .is_ok()
    }
    #[func]
    fn stamp_heat(
        &mut self,
        p: Vector3,
        radius: f64,
        delta: i32,
        terrain: Gd<TerrainCore>,
        deck: PackedByteArray,
    ) -> bool {
        let terrain = terrain.bind();
        let (Some(nav), Some(terrain)) = (&mut self.core, &terrain.core) else {
            return false;
        };
        let Ok(delta) = i8::try_from(delta) else {
            return false;
        };
        nav.stamp_heat(crate::point(p), radius, delta, terrain, deck.as_slice())
            .is_ok()
    }
    #[func]
    fn finalize(&mut self) -> bool {
        self.core.as_mut().is_some_and(|n| n.finalize(2))
    }
    #[func]
    fn update_hierarchy(&mut self, clusters: i32) -> bool {
        (0..=100_000).contains(&clusters)
            && self
                .core
                .as_mut()
                .is_some_and(|n| n.update_hierarchy(clusters as usize))
    }
    #[func]
    fn find_path(
        &mut self,
        from: Vector3,
        to: Vector3,
        vehicle: bool,
        team: i32,
        care: f64,
        tracked: bool,
        terrain: Gd<TerrainCore>,
        deck: PackedByteArray,
    ) -> PackedVector3Array {
        let Some(nav) = &mut self.core else {
            return PackedVector3Array::new();
        };
        let terrain = terrain.bind();
        let Some(terrain) = &terrain.core else {
            return PackedVector3Array::new();
        };
        let graph = if tracked {
            &mut nav.tracked
        } else if vehicle {
            &mut nav.vehicles
        } else {
            &mut nav.infantry
        };
        nav.planner
            .find_path(
                graph,
                crate::point(from),
                crate::point(to),
                vehicle,
                team,
                care,
                tracked,
                frontline_core::traversal::Ground::new(terrain, deck.as_slice()),
            )
            .into_iter()
            .map(|p| Vector3::new(p.x, p.y, p.z))
            .collect()
    }
    #[func]
    fn inspect(&self) -> Array<Variant> {
        let Some(nav) = &self.core else {
            return Array::new();
        };
        let planner: PackedByteArray = nav.planner.checkpoint().as_slice().into();
        let infantry: PackedByteArray = nav.infantry.checkpoint().as_slice().into();
        let vehicles: PackedByteArray = nav.vehicles.checkpoint().as_slice().into();
        let mut obstacles = Dictionary::<Variant, Variant>::new();
        for (&index, list) in nav.obstacles() {
            let values: Array<Variant> = list
                .iter()
                .map(|o| varray![o.id, o.infantry, o.vehicle].to_variant())
                .collect();
            obstacles.set(&index.to_variant(), &values.to_variant());
        }
        let tracked: PackedByteArray = nav.tracked.checkpoint().as_slice().into();
        varray![&planner, &infantry, &vehicles, &obstacles, &tracked]
    }
    #[func]
    fn checkpoint(&self) -> PackedByteArray {
        self.core
            .as_ref()
            .map_or_else(PackedByteArray::new, |n| n.checkpoint().as_slice().into())
    }
    #[func]
    fn restore(&mut self, bytes: PackedByteArray) -> bool {
        let Ok(nav) = NavigationScene::restore(bytes.as_slice()) else {
            return false;
        };
        self.core = Some(nav);
        true
    }
}
