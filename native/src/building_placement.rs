use crate::actors::ActorStateCore;
use crate::supply_network::SupplyNetworkCore;
use crate::water_raster::WaterRaster;
use crate::world_geometry::WorldGeometryCore;
use frontline_core::building_placement::{Definition, Distances, Spot};
use frontline_core::structure_birth::BuildingProfile;
use godot::prelude::*;
use std::collections::HashMap;
fn read<T: FromGodot>(a: &Array<Variant>, i: usize) -> Option<T> {
    a.get(i)?.try_to().ok()
}
#[derive(GodotClass)]
#[class(base=RefCounted,init)]
struct BuildingPlacementCore {
    base: Base<RefCounted>,
}
#[godot_api]
impl BuildingPlacementCore {
    #[func]
    fn query(
        &self,
        actors: Gd<ActorStateCore>,
        geometry: Gd<WorldGeometryCore>,
        network: Gd<SupplyNetworkCore>,
        water: Gd<WaterRaster>,
        request: Array<Variant>,
        definition: Array<Variant>,
        names: VarDictionary,
    ) -> Array<Variant> {
        let run = || -> Option<Array<Variant>> {
            if request.len() != 5 || !matches!(definition.len(), 0 | 6) || names.len() > 1_000_000 {
                return None;
            }
            let team: i8 = read(&request, 0)?;
            let position: Vector3 = read(&request, 1)?;
            let yaw: f64 = read(&request, 2)?;
            let distances: PackedFloat64Array = read(&request, 3)?;
            let snap: bool = read(&request, 4)?;
            if distances.len() != 3 {
                return None;
            }
            let distances = Distances {
                build: distances[0],
                fob_spacing: distances[1],
                fob_expand: distances[2],
            };
            let key = if definition.is_empty() {
                String::new()
            } else {
                read::<GString>(&definition, 0)?.to_string()
            };
            let name = if definition.is_empty() {
                String::new()
            } else {
                read::<GString>(&definition, 1)?.to_string()
            };
            let p = if definition.is_empty() {
                None
            } else {
                let size: Vector2 = read(&definition, 4)?;
                Some(Definition {
                    key: &key,
                    name: &name,
                    teams: read(&definition, 2)?,
                    cost: read(&definition, 3)?,
                    body: BuildingProfile {
                        size: [size.x, size.y],
                        hp: read(&definition, 5)?,
                    },
                })
            };
            let mut display = HashMap::new();
            for (id, value) in names.iter_shared() {
                display.insert(
                    id.try_to::<u32>().ok()?,
                    value.try_to::<GString>().ok()?.to_string(),
                );
            }
            let a = actors.bind();
            let g = geometry.bind();
            let n = network.bind();
            let w = water.bind();
            let g = g.core.as_ref()?;
            let w = w.core.as_ref()?;
            if a.core
                .iter_kind(frontline_core::entities::Kind::Structure)
                .any(|a| !display.contains_key(&a.identity().id))
            {
                return None;
            }
            let mut spot = Spot {
                position: crate::point(position),
                yaw,
                variant: 0,
            };
            if snap && matches!(key.as_str(), "mg_nest" | "hmg_nest") {
                if let Some(s) = g.trench_mount_spot(&a.core, spot.position, yaw).ok()? {
                    spot = s;
                }
            }
            let error = g
                .placement_error(
                    &a.core,
                    &n.core,
                    w,
                    team,
                    p.as_ref(),
                    spot.position,
                    spot.yaw,
                    &distances,
                    &|s| display[&s.id].clone(),
                )
                .ok()?;
            Some(varray![
                Vector3::new(spot.position.x, spot.position.y, spot.position.z),
                spot.yaw,
                spot.variant,
                &GString::from(&error)
            ])
        };
        run().unwrap_or_default()
    }
}
