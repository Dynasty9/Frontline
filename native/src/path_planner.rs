use crate::hierarchy::HierarchyCore;
use crate::terrain::TerrainCore;
use frontline_core::path_planner::{PathJob, PathPlanner};
use frontline_core::traversal::Ground;
use frontline_core::traversal::{Footprint, Obstacle};
use frontline_core::vector::Vector3 as Point;
use godot::prelude::*;

#[derive(GodotClass)]
#[class(base=RefCounted, init)]
pub(crate) struct PathPlannerCore {
    base: Base<RefCounted>,
    pub(crate) core: Option<PathPlanner>,
}

fn point(p: Vector3) -> Point {
    Point::new(p.x, p.y, p.z)
}
fn vectors(points: Vec<Point>) -> PackedVector3Array {
    points
        .into_iter()
        .map(|p| Vector3::new(p.x, p.y, p.z))
        .collect()
}

#[godot_api]
impl PathPlannerCore {
    #[func]
    fn nearest_walkable(
        &self,
        from: Vector3,
        vehicle: bool,
        tracked: bool,
        terrain: Option<Gd<TerrainCore>>,
        deck: PackedByteArray,
    ) -> Vector3 {
        let terrain = terrain.as_ref().map(|t| t.bind());
        let ground = Ground {
            terrain: terrain.as_ref().and_then(|t| t.core.as_ref()),
            deck: deck.as_slice(),
        };
        self.core
            .as_ref()
            .and_then(|p| p.nearest_walkable_for(point(from), vehicle, tracked, ground))
            .map_or(Vector3::INF, |p| Vector3::new(p.x, p.y, p.z))
    }
    #[func]
    fn load_tracked(&mut self, cells: PackedByteArray) -> bool {
        self.core
            .as_mut()
            .is_some_and(|p| p.load_tracked(cells.as_slice()))
    }
    #[func]
    fn set_tracked(&mut self, index: i32, kind: i32) -> bool {
        (0..=3).contains(&kind)
            && self
                .core
                .as_mut()
                .is_some_and(|p| p.set_tracked(index as usize, kind as u8))
    }
    #[func]
    fn set_obstacles(&mut self, index: i32, rows: PackedInt64Array) -> bool {
        let Some(planner) = &mut self.core else {
            return false;
        };
        if index < 0 || index as usize >= planner.side() * planner.side() || rows.len() % 3 != 0 {
            return false;
        }
        let mut items = Vec::new();
        for row in rows.as_slice().chunks_exact(3) {
            if row[0] <= 0
                || row[0] > u32::MAX as i64
                || !(0..=3).contains(&row[1])
                || !(0..=3).contains(&row[2])
            {
                return false;
            }
            items.push(Obstacle {
                id: row[0] as u32,
                infantry: row[1] as u8,
                vehicle: row[2] as u8,
            });
        }
        planner.occupancy.set_cell(index as u32, items)
    }
    #[func]
    fn set_footprints(&mut self, id: i64, rows: PackedFloat64Array) -> bool {
        let Some(planner) = &mut self.core else {
            return false;
        };
        if id <= 0 || id > u32::MAX as i64 || rows.len() % 5 != 0 || rows.len() > 4096 * 5 {
            return false;
        }
        let parts = rows
            .as_slice()
            .chunks_exact(5)
            .map(|p| Footprint {
                center: [p[0] as f32, p[1] as f32].into(),
                half: [p[2] as f32, p[3] as f32].into(),
                yaw: p[4],
            })
            .collect();
        planner.occupancy.set_footprints(id as u32, parts)
    }
    #[func]
    fn remove_footprints(&mut self, id: i64) {
        if id > 0 && id <= u32::MAX as i64 {
            if let Some(planner) = &mut self.core {
                planner.occupancy.remove_footprints(id as u32);
            }
        }
    }
    #[func]
    fn configure(&mut self, side: i32) -> bool {
        let Some(core) = PathPlanner::new(side as usize) else {
            return false;
        };
        self.core = Some(core);
        true
    }
    #[func]
    fn load_cells(
        &mut self,
        infantry: PackedByteArray,
        vehicle: PackedByteArray,
        heat: PackedByteArray,
    ) -> bool {
        self.core
            .as_mut()
            .is_some_and(|p| p.load_cells(infantry.as_slice(), vehicle.as_slice(), heat.as_slice()))
    }
    #[func]
    fn set_cell(&mut self, index: i32, infantry: i32, vehicle: i32, heat: i32) -> bool {
        if !(0..=3).contains(&infantry) || !(0..=3).contains(&vehicle) || !(0..=255).contains(&heat)
        {
            return false;
        }
        self.core
            .as_mut()
            .is_some_and(|p| p.set_cell(index as usize, infantry as u8, vehicle as u8, heat as u8))
    }
    #[func]
    fn line_free(
        &self,
        from: Vector3,
        to: Vector3,
        vehicle: bool,
        tracked: bool,
        terrain: Option<Gd<TerrainCore>>,
        deck: PackedByteArray,
    ) -> bool {
        let terrain = terrain.as_ref().map(|t| t.bind());
        let ground = Ground {
            terrain: terrain.as_ref().and_then(|t| t.core.as_ref()),
            deck: deck.as_slice(),
        };
        self.core
            .as_ref()
            .is_some_and(|p| p.line_free(point(from), point(to), vehicle, tracked, ground))
    }
    #[func]
    fn step_clear(
        &self,
        from: Vector3,
        to: Vector3,
        vehicle: bool,
        tracked: bool,
        terrain: Option<Gd<TerrainCore>>,
        deck: PackedByteArray,
    ) -> bool {
        let terrain = terrain.as_ref().map(|t| t.bind());
        let ground = Ground {
            terrain: terrain.as_ref().and_then(|t| t.core.as_ref()),
            deck: deck.as_slice(),
        };
        self.core
            .as_ref()
            .is_some_and(|p| p.step_clear(point(from), point(to), vehicle, tracked, ground))
    }
    #[func]
    fn direct_path(
        &self,
        graph: Gd<HierarchyCore>,
        from: Vector3,
        to: Vector3,
        vehicle: bool,
        care: f64,
        tracked: bool,
        terrain: Option<Gd<TerrainCore>>,
        deck: PackedByteArray,
    ) -> PackedVector3Array {
        let graph = graph.bind();
        let (Some(planner), Some(graph)) = (&self.core, &graph.core) else {
            return PackedVector3Array::new();
        };
        let terrain = terrain.as_ref().map(|t| t.bind());
        let ground = Ground {
            terrain: terrain.as_ref().and_then(|t| t.core.as_ref()),
            deck: deck.as_slice(),
        };
        vectors(
            planner
                .direct_path(
                    graph,
                    point(from),
                    PathJob {
                        id: 1,
                        destination: point(to),
                        vehicle,
                        tracked,
                        team: -1,
                        care,
                    },
                    ground,
                )
                .unwrap_or_default(),
        )
    }
    #[func]
    fn find_path(
        &mut self,
        mut graph: Gd<HierarchyCore>,
        from: Vector3,
        to: Vector3,
        vehicle: bool,
        team: i32,
        care: f64,
        tracked: bool,
        terrain: Option<Gd<TerrainCore>>,
        deck: PackedByteArray,
    ) -> PackedVector3Array {
        let mut graph = graph.bind_mut();
        let (Some(planner), Some(graph)) = (&mut self.core, &mut graph.core) else {
            return PackedVector3Array::new();
        };
        let terrain = terrain.as_ref().map(|t| t.bind());
        let ground = Ground {
            terrain: terrain.as_ref().and_then(|t| t.core.as_ref()),
            deck: deck.as_slice(),
        };
        vectors(planner.find_path(
            graph,
            point(from),
            point(to),
            vehicle,
            team,
            care,
            tracked,
            ground,
        ))
    }
    #[func]
    fn request(
        &mut self,
        id: i64,
        to: Vector3,
        vehicle: bool,
        team: i32,
        care: f64,
        tracked: bool,
    ) -> bool {
        self.core.as_mut().is_some_and(|p| {
            p.request(PathJob {
                id: id as u64,
                destination: point(to),
                vehicle,
                tracked,
                team,
                care,
            })
        })
    }
    #[func]
    fn cancel(&mut self, id: i64) {
        if let Some(p) = &mut self.core {
            p.cancel(id as u64);
        }
    }
    #[func]
    fn begin_batch(&mut self) {
        if let Some(p) = &mut self.core {
            p.begin_batch();
        }
    }
    #[func]
    fn restore_queue_order(&mut self, order: PackedInt64Array) -> bool {
        let order: Vec<_> = order.as_slice().iter().map(|id| *id as u64).collect();
        self.core
            .as_mut()
            .is_some_and(|p| p.restore_queue_order(&order))
    }
    #[func]
    fn next_job(&mut self) -> Array<Variant> {
        let Some(job) = self.core.as_mut().and_then(PathPlanner::next_job) else {
            return Array::new();
        };
        let destination = Vector3::new(job.destination.x, job.destination.y, job.destination.z);
        Array::from(&[
            (job.id as i64).to_variant(),
            destination.to_variant(),
            job.vehicle.to_variant(),
            job.team.to_variant(),
            job.care.to_variant(),
            job.tracked.to_variant(),
        ])
    }
    #[func]
    fn cache_hits(&self) -> i64 {
        self.core.as_ref().map_or(0, |p| p.cache_hits as i64)
    }
    #[func]
    fn queue_peak(&self) -> i64 {
        self.core.as_ref().map_or(0, |p| p.queue_peak as i64)
    }
    #[func]
    fn checkpoint(&self) -> PackedByteArray {
        self.core
            .as_ref()
            .map_or_else(PackedByteArray::new, |p| p.checkpoint().as_slice().into())
    }
    #[func]
    fn restore(&mut self, bytes: PackedByteArray) -> bool {
        let Ok(core) = PathPlanner::restore(bytes.as_slice()) else {
            return false;
        };
        self.core = Some(core);
        true
    }
}
