//! Weighted octile grid search used by infantry, vehicles and boats.
//! Ordering and float precision preserve Godot 4.7 AStarGrid2D routes.
//! Heap/search behavior adapted from Godot; see ../GODOT-LICENSE.txt.

#[derive(Clone, Copy, Default)]
struct SearchCell {
    cost: f32,
    estimate: f32,
    parent: usize,
    heap: usize,
    opened: u64,
    closed: u64,
}

pub struct NavigationGrid {
    origin: [i32; 2],
    size: [usize; 2],
    solid: Vec<bool>,
    weight: Vec<f32>,
    search: Vec<SearchCell>,
    open: Vec<usize>,
    generation: u64,
}

pub struct ClusterQuery {
    pub origin: [i32; 2],
    pub entrances: Vec<[i32; 2]>,
}

/// Workers share only immutable numeric terrain. Results retain input order.
pub fn cluster_costs(
    map_side: usize,
    cluster_side: usize,
    solid: &[u8],
    weight: &[f32],
    clusters: &[ClusterQuery],
    workers: usize,
) -> Option<Vec<Vec<f64>>> {
    if map_side == 0
        || map_side > 4096
        || cluster_side == 0
        || cluster_side > 64
        || solid.len() != map_side * map_side
        || weight.len() != solid.len()
        || !weight.iter().all(|w| w.is_finite() && *w >= 0.0)
        || clusters.len() > 65_536
    {
        return None;
    }
    let mut output_cells = 0usize;
    for cluster in clusters {
        let [x, y] = cluster.origin;
        if x < 0
            || y < 0
            || x as usize + cluster_side > map_side
            || y as usize + cluster_side > map_side
            || cluster.entrances.len() > 256
        {
            return None;
        }
        output_cells += cluster.entrances.len() * cluster.entrances.len();
        if output_cells > 16_777_216 {
            return None;
        }
        if cluster.entrances.iter().any(|p| {
            p[0] < x
                || p[1] < y
                || p[0] >= x + cluster_side as i32
                || p[1] >= y + cluster_side as i32
        }) {
            return None;
        }
    }
    if clusters.is_empty() {
        return Some(Vec::new());
    }
    let count = workers.clamp(1, 8).min(clusters.len());
    std::thread::scope(|scope| {
        let mut handles = Vec::new();
        for chunk in clusters.chunks(clusters.len().div_ceil(count)) {
            handles.push(scope.spawn(move || {
                let mut results = Vec::with_capacity(chunk.len());
                for cluster in chunk {
                    let mut grid = NavigationGrid::new(
                        cluster.origin,
                        cluster_side as i32,
                        cluster_side as i32,
                    )
                    .unwrap();
                    for row in 0..cluster_side {
                        let from = (cluster.origin[1] as usize + row) * map_side
                            + cluster.origin[0] as usize;
                        for x in 0..cluster_side {
                            grid.solid[row * cluster_side + x] = solid[from + x] != 0;
                            grid.weight[row * cluster_side + x] = weight[from + x];
                        }
                    }
                    results.push(grid.pair_costs(&cluster.entrances));
                }
                results
            }));
        }
        let mut results = Vec::with_capacity(clusters.len());
        for handle in handles {
            results.extend(handle.join().ok()?);
        }
        Some(results)
    })
}

impl NavigationGrid {
    /// Only terrain state is saved; search scratch is reset before every query.
    pub fn checkpoint(&self) -> Vec<u8> {
        let mut bytes = Vec::with_capacity(24 + self.solid.len() * 5);
        bytes.extend_from_slice(&crate::state_codec::header(b"FLNG\x01\0\0\0"));
        for value in [
            self.origin[0],
            self.origin[1],
            self.size[0] as i32,
            self.size[1] as i32,
        ] {
            bytes.extend_from_slice(&value.to_le_bytes());
        }
        for (&solid, &weight) in self.solid.iter().zip(&self.weight) {
            bytes.push(u8::from(solid));
            bytes.extend_from_slice(&weight.to_le_bytes());
        }
        bytes
    }

    pub fn restore(bytes: &[u8]) -> Result<Self, &'static str> {
        if bytes.len() < 24 || bytes[..8] != crate::state_codec::header(b"FLNG\x01\0\0\0") {
            return Err("incompatible navigation checkpoint");
        }
        let read = |i| i32::from_le_bytes(bytes[i..i + 4].try_into().unwrap());
        let width = read(16);
        let height = read(20);
        if width <= 0
            || height <= 0
            || (width as u64) * (height as u64) > 4_194_304
            || bytes.len() != 24 + width as usize * height as usize * 5
        {
            return Err("invalid navigation dimensions or length");
        }
        for cell in bytes[24..].chunks_exact(5) {
            let weight = f32::from_le_bytes(cell[1..].try_into().unwrap());
            if cell[0] > 1 || !weight.is_finite() || weight < 0.0 {
                return Err("invalid navigation cell");
            }
        }
        let mut grid =
            Self::new([read(8), read(12)], width, height).ok_or("invalid navigation origin")?;
        for (i, cell) in bytes[24..].chunks_exact(5).enumerate() {
            grid.solid[i] = cell[0] == 1;
            grid.weight[i] = f32::from_le_bytes(cell[1..].try_into().unwrap());
        }
        Ok(grid)
    }

    pub fn new(origin: [i32; 2], width: i32, height: i32) -> Option<Self> {
        if width <= 0
            || height <= 0
            || origin[0].checked_add(width).is_none()
            || origin[1].checked_add(height).is_none()
        {
            return None;
        }
        let count = (width as usize).checked_mul(height as usize)?;
        // Boat cells are 2 m; this covers maps up to 4 km without an unbounded allocation.
        if count > 4_194_304 {
            return None;
        }
        Some(Self {
            origin,
            size: [width as usize, height as usize],
            solid: vec![false; count],
            weight: vec![1.0; count],
            search: vec![SearchCell::default(); count],
            open: Vec::new(),
            generation: 0,
        })
    }

    fn index(&self, cell: [i32; 2]) -> Option<usize> {
        let x = i64::from(cell[0]) - i64::from(self.origin[0]);
        let y = i64::from(cell[1]) - i64::from(self.origin[1]);
        if x < 0 || y < 0 || x >= self.size[0] as i64 || y >= self.size[1] as i64 {
            return None;
        }
        Some(y as usize * self.size[0] + x as usize)
    }

    fn cell(&self, index: usize) -> [i32; 2] {
        [
            self.origin[0] + (index % self.size[0]) as i32,
            self.origin[1] + (index / self.size[0]) as i32,
        ]
    }

    pub fn contains(&self, cell: [i32; 2]) -> bool {
        self.index(cell).is_some()
    }
    pub fn is_solid(&self, cell: [i32; 2]) -> bool {
        self.index(cell).is_none_or(|i| self.solid[i])
    }
    pub fn weight(&self, cell: [i32; 2]) -> Option<f32> {
        self.index(cell).map(|i| self.weight[i])
    }
    pub fn set_solid(&mut self, cell: [i32; 2], solid: bool) -> bool {
        let Some(i) = self.index(cell) else {
            return false;
        };
        self.solid[i] = solid;
        true
    }
    pub fn set_weight(&mut self, cell: [i32; 2], weight: f32) -> bool {
        let Some(i) = self.index(cell) else {
            return false;
        };
        if !weight.is_finite() || weight < 0.0 {
            return false;
        }
        self.weight[i] = weight;
        true
    }
    pub fn fill_solid(&mut self, origin: [i32; 2], size: [i32; 2], solid: bool) {
        let x0 = i64::from(origin[0]).max(i64::from(self.origin[0]));
        let y0 = i64::from(origin[1]).max(i64::from(self.origin[1]));
        let x1 = (i64::from(origin[0]) + i64::from(size[0]))
            .min(i64::from(self.origin[0]) + self.size[0] as i64);
        let y1 = (i64::from(origin[1]) + i64::from(size[1]))
            .min(i64::from(self.origin[1]) + self.size[1] as i64);
        for y in y0..y1 {
            for x in x0..x1 {
                self.set_solid([x as i32, y as i32], solid);
            }
        }
    }

    /// Loads one cluster in a single call. Validate everything before changing the grid.
    pub fn load_cells(&mut self, solid: &[u8], weight: &[f32]) -> bool {
        if solid.len() != self.solid.len()
            || weight.len() != solid.len()
            || !weight.iter().all(|w| w.is_finite() && *w >= 0.0)
        {
            return false;
        }
        for (out, &value) in self.solid.iter_mut().zip(solid) {
            *out = value != 0;
        }
        self.weight.copy_from_slice(weight);
        true
    }

    fn worse(&self, a: usize, b: usize) -> bool {
        let a = self.search[a];
        let b = self.search[b];
        a.estimate > b.estimate || (a.estimate == b.estimate && a.cost < b.cost)
    }
    fn put(&mut self, slot: usize, point: usize) {
        self.open[slot] = point;
        self.search[point].heap = slot;
    }
    fn push(&mut self, mut hole: usize, point: usize) {
        while hole > 0 {
            let parent = (hole - 1) / 2;
            if !self.worse(self.open[parent], point) {
                break;
            }
            self.put(hole, self.open[parent]);
            hole = parent;
        }
        self.put(hole, point);
    }
    fn pop(&mut self) {
        let point = self.open.pop().unwrap();
        let len = self.open.len();
        if len == 0 {
            return;
        }
        let mut hole = 0;
        let mut child = 2;
        while child < len {
            if self.worse(self.open[child], self.open[child - 1]) {
                child -= 1;
            }
            self.put(hole, self.open[child]);
            hole = child;
            child = 2 * (child + 1);
        }
        if child == len {
            self.put(hole, self.open[child - 1]);
            hole = child - 1;
        }
        self.push(hole, point);
    }

    fn neighbors(&self, p: usize) -> [Option<usize>; 8] {
        let w = self.size[0];
        let x = p % w;
        let y = p / w;
        let clear = |i: Option<usize>| i.filter(|&i| !self.solid[i]);
        let top = clear((y > 0).then(|| p - w));
        let right = clear((x + 1 < w).then_some(p + 1));
        let bottom = clear((y + 1 < self.size[1]).then_some(p + w));
        let left = clear((x > 0).then(|| p - 1));
        [
            top,
            right,
            bottom,
            left,
            clear((top.is_some() && left.is_some()).then(|| p - w - 1)),
            clear((top.is_some() && right.is_some()).then(|| p - w + 1)),
            clear((bottom.is_some() && right.is_some()).then(|| p + w + 1)),
            clear((bottom.is_some() && left.is_some()).then(|| p + w - 1)),
        ]
    }

    pub fn path(&mut self, from: [i32; 2], to: [i32; 2]) -> Vec<[i32; 2]> {
        let (Some(start), Some(end)) = (self.index(from), self.index(to)) else {
            return Vec::new();
        };
        if self.solid[start] || self.solid[end] {
            return Vec::new();
        }
        if start == end {
            return vec![from];
        }
        self.generation = self.generation.wrapping_add(1);
        if self.generation == 0 {
            self.search.fill(SearchCell::default());
            self.generation = 1;
        }
        let generation = self.generation;
        self.open.clear();
        self.search[start] = SearchCell {
            estimate: octile(from, to),
            opened: generation,
            ..SearchCell::default()
        };
        self.open.push(start);
        while let Some(&p) = self.open.first() {
            if p == end {
                let mut out = vec![to];
                let mut current = end;
                while current != start {
                    current = self.search[current].parent;
                    out.push(self.cell(current));
                }
                out.reverse();
                return out;
            }
            self.pop();
            self.search[p].closed = generation;
            for next in self.neighbors(p).into_iter().flatten() {
                if self.search[next].closed == generation {
                    continue;
                }
                let cell = self.cell(next);
                let cost = self.search[p].cost + octile(self.cell(p), cell) * self.weight[next];
                if self.search[next].opened != generation {
                    self.search[next].opened = generation;
                    self.search[next].heap = self.open.len();
                    self.open.push(next);
                } else if cost >= self.search[next].cost {
                    continue;
                }
                self.search[next].parent = p;
                self.search[next].cost = cost;
                self.search[next].estimate = cost + octile(cell, to);
                self.push(self.search[next].heap, next);
            }
        }
        Vec::new()
    }

    pub fn path_cost(&mut self, from: [i32; 2], to: [i32; 2]) -> f64 {
        if from == to {
            return 0.0;
        }
        let path = self.path(from, to);
        if path.is_empty() {
            return -1.0;
        }
        path.windows(2)
            .map(|pair| {
                let diagonal = pair[0][0] != pair[1][0] && pair[0][1] != pair[1][1];
                // HNav has always used this rounded diagonal cost for its abstract links.
                (if diagonal { 1.4142 } else { 1.0 }) * f64::from(self.weight(pair[1]).unwrap())
            })
            .sum()
    }

    pub fn pair_costs(&mut self, cells: &[[i32; 2]]) -> Vec<f64> {
        let n = cells.len();
        let mut costs = vec![-2.0; n * n];
        for i in 0..n {
            for j in i + 1..n {
                costs[i * n + j] = self.path_cost(cells[i], cells[j]);
            }
        }
        costs
    }
}

fn octile(a: [i32; 2], b: [i32; 2]) -> f32 {
    let x = (i64::from(a[0]) - i64::from(b[0])).unsigned_abs() as f32;
    let y = (i64::from(a[1]) - i64::from(b[1])).unsigned_abs() as f32;
    let f = (std::f64::consts::SQRT_2 - 1.0) as f32;
    f * x.min(y) + x.max(y)
}
