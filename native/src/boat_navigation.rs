use frontline_core::boat_navigation::BoatNavigation;
use godot::prelude::*;

#[derive(GodotClass)]
#[class(base=RefCounted, init)]
pub(crate) struct BoatNavigationCore {
    base: Base<RefCounted>,
    pub(crate) core: Option<BoatNavigation>,
}
fn vector(p: frontline_core::vector::Vector3) -> Vector3 {
    Vector3::new(p.x, p.y, p.z)
}

#[godot_api]
impl BoatNavigationCore {
    #[func]
    fn configure(
        &mut self,
        terrain: Gd<crate::terrain::TerrainCore>,
        decks: PackedByteArray,
    ) -> bool {
        let terrain = terrain.bind();
        let Some(terrain) = terrain.core.as_ref() else {
            return false;
        };
        let Ok(nav) = BoatNavigation::from_terrain(terrain, decks.as_slice()) else {
            return false;
        };
        self.core = Some(nav);
        true
    }
    #[func]
    fn open(&self, at: Vector3) -> bool {
        self.core.as_ref().is_some_and(|n| n.open(crate::point(at)))
    }
    #[func]
    fn body(&self, at: Vector3) -> i32 {
        self.core.as_ref().map_or(-1, |n| n.body(crate::point(at)))
    }
    #[func]
    fn line(&self, a: Vector3, b: Vector3, half_width: f64) -> bool {
        self.core
            .as_ref()
            .is_some_and(|n| n.line(crate::point(a), crate::point(b), half_width))
    }
    #[func]
    fn nearest(&self, at: Vector3, radius: f64, body: i32) -> PackedVector3Array {
        self.core
            .as_ref()
            .and_then(|n| n.nearest(crate::point(at), radius, body))
            .into_iter()
            .map(vector)
            .collect()
    }
    #[func]
    fn path(&mut self, a: Vector3, b: Vector3) -> PackedVector3Array {
        self.core
            .as_mut()
            .map_or_else(PackedVector3Array::new, |n| {
                n.path(crate::point(a), crate::point(b))
                    .into_iter()
                    .map(vector)
                    .collect()
            })
    }
    #[func]
    fn checkpoint(&self) -> PackedByteArray {
        self.core
            .as_ref()
            .map_or_else(PackedByteArray::new, |n| n.checkpoint().as_slice().into())
    }
    #[func]
    fn restore(&mut self, bytes: PackedByteArray) -> bool {
        let Ok(nav) = BoatNavigation::restore(bytes.as_slice()) else {
            return false;
        };
        self.core = Some(nav);
        true
    }
}
