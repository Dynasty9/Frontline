use frontline_core::navigation_grid::NavigationGrid;
use godot::prelude::*;

#[derive(GodotClass)]
#[class(base=RefCounted, init)]
struct NavigationGridCore {
    base: Base<RefCounted>,
    core: Option<NavigationGrid>,
    cell_size: Vector2,
}

#[godot_api]
impl NavigationGridCore {
    #[func]
    fn cluster_costs(
        &self,
        map_side: i32,
        cluster_side: i32,
        solid: PackedByteArray,
        weight: PackedFloat32Array,
        origins: Array<Vector2i>,
        entrances: Array<PackedInt32Array>,
    ) -> Array<PackedFloat64Array> {
        if map_side <= 0
            || cluster_side <= 0
            || origins.len() != entrances.len()
            || origins.len() > 65_536
        {
            return Array::new();
        }
        let mut clusters = Vec::with_capacity(origins.len());
        for (origin, points) in origins.iter_shared().zip(entrances.iter_shared()) {
            if points.len() > 512 || points.len() % 2 != 0 {
                return Array::new();
            }
            clusters.push(frontline_core::navigation_grid::ClusterQuery {
                origin: cell(origin),
                entrances: points
                    .as_slice()
                    .chunks_exact(2)
                    .map(|p| [p[0], p[1]])
                    .collect(),
            });
        }
        let workers = std::thread::available_parallelism().map_or(1, usize::from);
        let Some(costs) = frontline_core::navigation_grid::cluster_costs(
            map_side as usize,
            cluster_side as usize,
            solid.as_slice(),
            weight.as_slice(),
            &clusters,
            workers,
        ) else {
            return Array::new();
        };
        costs
            .into_iter()
            .map(|row| PackedFloat64Array::from(row.as_slice()))
            .collect()
    }

    #[func]
    fn configure(&mut self, region: Rect2i, cell_size: Vector2) -> bool {
        if !cell_size.is_finite() || cell_size.x <= 0.0 || cell_size.y <= 0.0 {
            return false;
        }
        let Some(grid) = NavigationGrid::new(cell(region.position), region.size.x, region.size.y)
        else {
            return false;
        };
        self.core = Some(grid);
        self.cell_size = cell_size;
        true
    }

    #[func]
    fn load_cells(&mut self, solid: PackedByteArray, weight: PackedFloat32Array) -> bool {
        self.core
            .as_mut()
            .is_some_and(|grid| grid.load_cells(solid.as_slice(), weight.as_slice()))
    }

    #[func]
    fn is_in_boundsv(&self, point: Vector2i) -> bool {
        self.core
            .as_ref()
            .is_some_and(|grid| grid.contains(cell(point)))
    }

    #[func]
    fn is_point_solid(&self, point: Vector2i) -> bool {
        self.core
            .as_ref()
            .is_none_or(|grid| grid.is_solid(cell(point)))
    }

    #[func]
    fn set_point_solid(&mut self, point: Vector2i, solid: bool) -> bool {
        self.core
            .as_mut()
            .is_some_and(|grid| grid.set_solid(cell(point), solid))
    }

    #[func]
    fn fill_solid_region(&mut self, region: Rect2i, solid: bool) {
        if let Some(grid) = self.core.as_mut() {
            grid.fill_solid(cell(region.position), cell(region.size), solid);
        }
    }

    #[func]
    fn get_point_weight_scale(&self, point: Vector2i) -> f64 {
        self.core
            .as_ref()
            .and_then(|grid| grid.weight(cell(point)))
            .map_or(1.0, f64::from)
    }

    #[func]
    fn set_point_weight_scale(&mut self, point: Vector2i, weight: f64) -> bool {
        self.core
            .as_mut()
            .is_some_and(|grid| grid.set_weight(cell(point), weight as f32))
    }

    #[func]
    fn get_id_path(&mut self, from: Vector2i, to: Vector2i) -> Array<Vector2i> {
        let Some(grid) = self.core.as_mut() else {
            return Array::new();
        };
        grid.path(cell(from), cell(to))
            .into_iter()
            .map(|p| Vector2i::new(p[0], p[1]))
            .collect()
    }

    #[func]
    fn get_point_path(&mut self, from: Vector2i, to: Vector2i) -> PackedVector2Array {
        let Some(grid) = self.core.as_mut() else {
            return PackedVector2Array::new();
        };
        grid.path(cell(from), cell(to))
            .into_iter()
            .map(|p| Vector2::new(p[0] as f32, p[1] as f32) * self.cell_size)
            .collect()
    }

    #[func]
    fn path_cost(&mut self, from: Vector2i, to: Vector2i) -> f64 {
        self.core
            .as_mut()
            .map_or(-1.0, |grid| grid.path_cost(cell(from), cell(to)))
    }

    #[func]
    fn pair_costs(&mut self, cells: Array<Vector2i>) -> PackedFloat64Array {
        let Some(grid) = self.core.as_mut() else {
            return PackedFloat64Array::new();
        };
        if cells.len() > 1024 {
            return PackedFloat64Array::new();
        }
        let cells: Vec<_> = cells.iter_shared().map(cell).collect();
        grid.pair_costs(&cells).as_slice().into()
    }
}

fn cell(point: Vector2i) -> [i32; 2] {
    [point.x, point.y]
}
