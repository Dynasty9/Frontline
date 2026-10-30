use frontline_core::cover::{self, Part};
use godot::prelude::*;

#[derive(GodotClass)]
#[class(base=RefCounted, init)]
struct CoverGeometry {
    base: Base<RefCounted>,
}

fn parts(values: &Array<Variant>) -> Option<Vec<Part>> {
    if values.len() > 4096 {
        return None;
    }
    values
        .iter_shared()
        .map(|value| {
            let part = value.try_to::<VarDictionary>().ok()?;
            Some(Part {
                position: crate::point(part.get("p")?.try_to::<Vector3>().ok()?),
                size: crate::point(part.get("s")?.try_to::<Vector3>().ok()?),
                yaw: part.get("r")?.try_to::<f64>().ok()?,
                cover: part.get("cover")?.try_to::<bool>().ok()?,
                collision: part.get("col")?.try_to::<bool>().ok()?,
                blocks_navigation: part.get("nav")?.try_to::<i32>().ok()? != 0,
            })
        })
        .collect()
}

#[godot_api]
impl CoverGeometry {
    #[func]
    fn generate(
        &self,
        kind: GString,
        variant: i32,
        position: Vector3,
        yaw: f64,
        size: Vector3,
        geometry: Array<Variant>,
        map_half: f64,
    ) -> Array<Variant> {
        let Some(parts) = parts(&geometry) else {
            godot_error!("Invalid cover parts");
            return Array::new();
        };
        let Ok(anchors) = cover::generate(
            &kind.to_string(),
            variant,
            crate::point(position),
            yaw,
            crate::point(size),
            &parts,
            map_half,
        ) else {
            godot_error!("Invalid cover structure");
            return Array::new();
        };
        let point = |p: frontline_core::vector::Vector3| Vector3::new(p.x, p.y, p.z);
        let positions: PackedVector3Array = anchors.iter().map(|a| point(a.position)).collect();
        let normals: PackedVector3Array = anchors.iter().map(|a| point(a.normal)).collect();
        let heights: PackedFloat32Array = anchors.iter().map(|a| a.height as f32).collect();
        let kinds: PackedByteArray = anchors.iter().map(|a| a.kind as u8).collect();
        varray![&positions, &normals, &heights, &kinds]
    }
}
