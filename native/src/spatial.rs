use crate::actors::ActorStateCore;
use frontline_core::spatial::SpatialIndex;
use godot::prelude::*;

#[derive(GodotClass)]
#[class(base=RefCounted, init)]
pub(crate) struct SpatialIndexCore {
    base: Base<RefCounted>,
    pub(crate) core: Option<SpatialIndex>,
}
fn results(r: Result<Vec<u32>, &'static str>) -> Array<Variant> {
    r.map_or_else(
        |_| Array::new(),
        |ids| varray![&ids.into_iter().map(i64::from).collect::<PackedInt64Array>()],
    )
}
#[godot_api]
impl SpatialIndexCore {
    #[func]
    fn load_state(&mut self, cell_size: f64, rows: Array<Variant>) -> bool {
        if rows.len() > 1_000_000 {
            return false;
        }
        let mut cells = Vec::new();
        let mut count = 0;
        for row in rows.iter_shared() {
            let Ok(row) = row.try_to::<Array<Variant>>() else {
                return false;
            };
            if row.len() != 2 {
                return false;
            }
            let Some(key) = row.get(0).and_then(|v| v.try_to::<Vector2i>().ok()) else {
                return false;
            };
            let Some(ids) = row.get(1).and_then(|v| v.try_to::<PackedInt64Array>().ok()) else {
                return false;
            };
            count += ids.len();
            if count > 10_000_000 {
                return false;
            }
            let Some(ids) = ids
                .as_slice()
                .iter()
                .map(|&id| u32::try_from(id).ok())
                .collect::<Option<Vec<_>>>()
            else {
                return false;
            };
            cells.push(((key.x, key.y), ids));
        }
        let Ok(index) = SpatialIndex::from_cells(cell_size, cells) else {
            return false;
        };
        self.core = Some(index);
        true
    }
    #[func]
    fn cells(&self) -> Array<Variant> {
        self.core.as_ref().map_or_else(Array::new, |index| {
            index
                .cells()
                .map(|((x, z), ids)| {
                    varray![
                        Vector2i::new(x, z),
                        &ids.iter()
                            .copied()
                            .map(i64::from)
                            .collect::<PackedInt64Array>()
                    ]
                    .to_variant()
                })
                .collect()
        })
    }
    #[func]
    fn checkpoint(&self) -> PackedByteArray {
        self.core
            .as_ref()
            .map_or_else(PackedByteArray::new, |index| {
                index.checkpoint().as_slice().into()
            })
    }
    #[func]
    fn restore(&mut self, bytes: PackedByteArray) -> bool {
        let Ok(index) = SpatialIndex::restore(bytes.as_slice()) else {
            return false;
        };
        self.core = Some(index);
        true
    }
    #[func]
    fn insert(&mut self, id: u32, position: Vector3, radius: f64) -> bool {
        self.core
            .as_mut()
            .is_some_and(|index| index.insert(id, crate::point(position), radius).is_ok())
    }
    #[func]
    fn insert_door(&mut self, id: u32, position: Vector3) -> bool {
        self.core
            .as_mut()
            .is_some_and(|index| index.insert_door(id, crate::point(position)).is_ok())
    }
    #[func]
    fn remove(&mut self, id: u32) -> bool {
        self.core.as_mut().is_some_and(|index| index.remove(id))
    }
    #[func]
    fn rebuild_units(&mut self, actors: Gd<ActorStateCore>) -> bool {
        self.core
            .as_mut()
            .is_some_and(|index| actors.bind().core.rebuild_units(index).is_ok())
    }
    #[func]
    fn units_near(
        &self,
        actors: Gd<ActorStateCore>,
        position: Vector3,
        radius: f64,
        enemy_of: i8,
    ) -> Array<Variant> {
        results(
            self.core
                .as_ref()
                .ok_or("missing spatial index")
                .and_then(|index| {
                    actors
                        .bind()
                        .core
                        .units_near(index, crate::point(position), radius, enemy_of)
                }),
        )
    }
    #[func]
    fn structures_near(
        &self,
        actors: Gd<ActorStateCore>,
        position: Vector3,
        radius: f64,
        floors_only: bool,
    ) -> Array<Variant> {
        results(
            self.core
                .as_ref()
                .ok_or("missing spatial index")
                .and_then(|index| {
                    actors.bind().core.structures_near(
                        index,
                        crate::point(position),
                        radius,
                        floors_only,
                    )
                }),
        )
    }
    #[func]
    fn door_in_way(
        &self,
        actors: Gd<ActorStateCore>,
        position: Vector3,
        direction: Vector3,
    ) -> i64 {
        self.core
            .as_ref()
            .ok_or("missing spatial index")
            .and_then(|index| {
                actors.bind().core.door_in_way(
                    index,
                    crate::point(position),
                    crate::point(direction),
                )
            })
            .map_or(-1, |id| i64::from(id.unwrap_or(0)))
    }
}
