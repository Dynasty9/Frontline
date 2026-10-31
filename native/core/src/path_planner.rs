use crate::hierarchy::Hierarchy;
use crate::state_codec::{Reader, Writer};
use crate::vector::Vector3;
use std::collections::{HashMap, VecDeque};

const CACHE_LIMIT: usize = 128;
const JOB_LIMIT: usize = 131_072;

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct PathJob {
    pub id: u64,
    pub destination: Vector3,
    pub vehicle: bool,
    pub team: i32,
    pub care: f64,
}

#[derive(Clone, Debug, PartialEq, Eq)]
struct CacheKey {
    vehicle: bool,
    policy: i32,
    terrain_revision: u64,
    danger_revision: u64,
    cells: [i32; 4],
}

/// Shared infantry/vehicle corridors and deterministic request order.
/// Cached corridors affect later routes, so they are part of saved state.
pub struct PathPlanner {
    side: usize,
    kinds: [Vec<u8>; 2],
    heat: Vec<u8>,
    cache: VecDeque<(CacheKey, Vec<Vector3>)>,
    jobs: HashMap<u64, PathJob>,
    order: VecDeque<u64>,
    batch_left: usize,
    pub cache_hits: u64,
    pub queue_peak: usize,
}

impl PathPlanner {
    pub fn new(side: usize) -> Option<Self> {
        if side == 0 || side > 4096 {
            return None;
        }
        Some(Self {
            side,
            kinds: [vec![0; side * side], vec![0; side * side]],
            heat: vec![0; side * side],
            cache: VecDeque::new(),
            jobs: HashMap::new(),
            order: VecDeque::new(),
            batch_left: 0,
            cache_hits: 0,
            queue_peak: 0,
        })
    }

    pub fn load_cells(&mut self, infantry: &[u8], vehicle: &[u8], heat: &[u8]) -> bool {
        if [infantry, vehicle, heat]
            .iter()
            .any(|s| s.len() != self.side * self.side)
            || infantry.iter().chain(vehicle).any(|k| *k > 3)
        {
            return false;
        }
        self.kinds[0].copy_from_slice(infantry);
        self.kinds[1].copy_from_slice(vehicle);
        self.heat.copy_from_slice(heat);
        true
    }

    pub fn set_cell(&mut self, index: usize, infantry: u8, vehicle: u8, heat: u8) -> bool {
        if index >= self.heat.len() || infantry > 3 || vehicle > 3 {
            return false;
        }
        self.kinds[0][index] = infantry;
        self.kinds[1][index] = vehicle;
        self.heat[index] = heat;
        true
    }

    fn cell(&self, position: Vector3) -> [i32; 2] {
        let half = self.side as f64 * 0.5;
        [position.x, position.z].map(|v| {
            (f64::from(v) + half)
                .floor()
                .clamp(0.0, self.side as f64 - 1.0) as i32
        })
    }

    fn center(&self, cell: [i32; 2]) -> Vector3 {
        let half = self.side as f64 * 0.5;
        Vector3::new(
            (f64::from(cell[0]) - half + 0.5) as f32,
            0.0,
            (f64::from(cell[1]) - half + 0.5) as f32,
        )
    }

    fn index(&self, cell: [i32; 2]) -> usize {
        cell[1] as usize * self.side + cell[0] as usize
    }

    pub fn side(&self) -> usize {
        self.side
    }

    pub fn kind_at(&self, point: Vector3, vehicle: bool) -> u8 {
        self.kinds[usize::from(vehicle)][self.index(self.cell(point))]
    }

    pub fn nearest_walkable(&self, point: Vector3) -> Option<Vector3> {
        self.nearest_walkable_for(point, false)
    }

    pub fn nearest_walkable_for(&self, point: Vector3, vehicle: bool) -> Option<Vector3> {
        if !point.is_finite() {
            return None;
        }
        let cell = self.cell(point);
        let kinds = &self.kinds[usize::from(vehicle)];
        if kinds[self.index(cell)] != 3 {
            return Some(point);
        }
        let free = nearest_free(cell, |p| {
            p.into_iter().all(|v| v >= 0 && v < self.side as i32) && kinds[self.index(p)] != 3
        });
        Some(self.center(free))
    }

    pub fn line_free(&self, from: Vector3, to: Vector3, vehicle: bool) -> bool {
        if !from.is_finite() || !to.is_finite() {
            return false;
        }
        let delta = to - from;
        let length = f64::from(delta.length());
        // External commands cannot turn a smoothing probe into an unbounded loop.
        if !length.is_finite() || length > self.side as f64 * 4.0 {
            return false;
        }
        let steps = (length / 0.5) as usize + 1;
        let mind_fire = !vehicle && self.heat[self.index(self.cell(from))] == 0;
        for step in 1..steps {
            let p = from + delta * (step as f64 / steps as f64) as f32;
            let index = self.index(self.cell(p));
            if self.kinds[usize::from(vehicle)][index] != 0 || (mind_fire && self.heat[index] > 0) {
                return false;
            }
        }
        true
    }

    pub fn direct_path(
        &self,
        graph: &Hierarchy,
        from: Vector3,
        job: PathJob,
    ) -> Option<Vec<Vector3>> {
        if !self.valid(graph, from, job.destination, job.care) {
            return None;
        }
        let a = self.cell(from);
        let b = self.cell(job.destination);
        if (job.care <= 0.0 || graph.cluster_of(a) == graph.cluster_of(b))
            && from.distance_squared(job.destination) <= 256.0
            && !graph.is_solid(a)
            && !graph.is_solid(b)
            && self.line_free(from, job.destination, job.vehicle)
        {
            Some(vec![flat(job.destination)])
        } else {
            None
        }
    }

    fn valid(&self, graph: &Hierarchy, from: Vector3, to: Vector3, care: f64) -> bool {
        graph.side() == self.side
            && from.is_finite()
            && to.is_finite()
            && care.is_finite()
            && from.abs().max_element() <= self.side as f32 * 2.0
            && to.abs().max_element() <= self.side as f32 * 2.0
    }

    pub fn find_path(
        &mut self,
        graph: &mut Hierarchy,
        from: Vector3,
        to: Vector3,
        vehicle: bool,
        team: i32,
        care: f64,
    ) -> Vec<Vector3> {
        if !self.valid(graph, from, to, care) {
            return Vec::new();
        }
        let mut a = self.cell(from);
        let mut b = self.cell(to);
        if graph.is_solid(a) {
            a = nearest_free(a, |p| !graph.is_solid(p));
        }
        let end_exact = !graph.is_solid(b);
        if !end_exact {
            b = nearest_free(b, |p| !graph.is_solid(p));
        }
        let end = self.center(b);
        let near_end = f64::from(flat(end - to).length()) < 1.7;
        if a == b {
            return vec![if end_exact || near_end { to } else { end }];
        }
        let policy = if care > 0.0 && (0..2).contains(&team) {
            team
        } else {
            -1
        };
        let key = CacheKey {
            vehicle,
            policy,
            terrain_revision: graph.terrain_revision,
            danger_revision: if policy < 0 {
                0
            } else {
                graph.danger_revision[policy as usize]
            },
            cells: [a[0] / 32, a[1] / 32, b[0] / 32, b[1] / 32],
        };
        if end_exact {
            if let Some((_, cached)) = self.cache.iter().find(|(k, _)| *k == key) {
                let last_from = if cached.len() == 1 {
                    from
                } else {
                    cached[cached.len() - 2]
                };
                let first_to = if cached.len() == 1 { to } else { cached[0] };
                if self.line_free(from, first_to, vehicle) && self.line_free(last_from, to, vehicle)
                {
                    let mut out = cached.clone();
                    *out.last_mut().unwrap() = flat(to);
                    self.cache_hits += 1;
                    return out;
                }
            }
        }
        let ids = if graph.built {
            refined_path(graph, a, b, team, care)
        } else if graph.cluster_of(a) == graph.cluster_of(b) {
            graph.local_path(graph.cluster_of(a), a, b)
        } else {
            Vec::new()
        };
        if ids.is_empty() {
            return Vec::new();
        }
        let mut points: Vec<_> = ids.iter().map(|c| self.center(*c)).collect();
        if ids.last() == Some(&b) {
            if end_exact {
                *points.last_mut().unwrap() = flat(to);
            } else if near_end {
                points.push(flat(to));
            }
        }
        let mut out = Vec::new();
        let mut i = 0;
        let last = points.len() - 1;
        while i < last {
            let mut j = last.min(i + 14);
            while j > i + 1 && !self.line_free(points[i], points[j], vehicle) {
                j -= 1;
            }
            out.push(points[j]);
            i = j;
        }
        if end_exact && !out.is_empty() && !graph.has_work() {
            if self.cache.len() >= CACHE_LIMIT {
                self.cache.pop_front();
            }
            if let Some((_, value)) = self.cache.iter_mut().find(|(k, _)| *k == key) {
                *value = out.clone();
            } else {
                self.cache.push_back((key, out.clone()));
            }
        }
        out
    }

    pub fn request(&mut self, job: PathJob) -> bool {
        if job.id == 0
            || job.id > i64::MAX as u64
            || !job.destination.is_finite()
            || !job.care.is_finite()
        {
            return false;
        }
        if !self.jobs.contains_key(&job.id) {
            if self.order.len() >= JOB_LIMIT {
                return false;
            }
            self.order.push_back(job.id);
        }
        self.jobs.insert(job.id, job);
        self.queue_peak = self.queue_peak.max(self.jobs.len());
        true
    }

    pub fn cancel(&mut self, id: u64) {
        self.jobs.remove(&id);
    }
    pub fn restore_queue_order(&mut self, order: &[u64]) -> bool {
        if order.len() > JOB_LIMIT || order.iter().any(|id| *id == 0 || *id > i64::MAX as u64) {
            return false;
        }
        let pending: std::collections::HashSet<_> = order.iter().copied().collect();
        if self.jobs.keys().any(|id| !pending.contains(id)) {
            return false;
        }
        self.order = order.iter().copied().collect();
        self.batch_left = 0;
        true
    }
    pub fn begin_batch(&mut self) {
        self.batch_left = self.order.len();
    }
    pub fn next_job(&mut self) -> Option<PathJob> {
        while self.batch_left > 0 {
            self.batch_left -= 1;
            let id = self.order.pop_front()?;
            if let Some(job) = self.jobs.remove(&id) {
                return Some(job);
            }
        }
        None
    }

    pub fn checkpoint(&self) -> Vec<u8> {
        let mut out = Writer::new(b"FLPP\x01\0\0\0");
        out.u32(self.side as u32);
        for cells in &self.kinds {
            out.bytes(cells);
        }
        out.bytes(&self.heat);
        out.u32(self.cache.len() as u32);
        for (key, route) in &self.cache {
            out.byte(u8::from(key.vehicle));
            out.u32(key.policy as u32);
            out.u64(key.terrain_revision);
            out.u64(key.danger_revision);
            for cell in key.cells {
                out.u32(cell as u32);
            }
            out.u32(route.len() as u32);
            for point in route {
                out.point(*point);
            }
        }
        let mut jobs: Vec<_> = self.jobs.values().collect();
        jobs.sort_unstable_by_key(|job| job.id);
        out.u32(jobs.len() as u32);
        for job in jobs {
            out.u64(job.id);
            out.point(job.destination);
            out.byte(u8::from(job.vehicle));
            out.u32(job.team as u32);
            out.f64(job.care);
        }
        out.u32(self.order.len() as u32);
        for id in &self.order {
            out.u64(*id);
        }
        out.u32(self.batch_left as u32);
        out.0
    }

    pub fn restore(bytes: &[u8]) -> Result<Self, &'static str> {
        let mut input = Reader::new(bytes, b"FLPP\x01\0\0\0")?;
        let side = input.u32()? as usize;
        let mut planner = Self::new(side).ok_or("invalid planner dimensions")?;
        let infantry = input.bytes(side * side)?;
        let vehicle = input.bytes(side * side)?;
        let heat = input.bytes(side * side)?;
        if !planner.load_cells(infantry, vehicle, heat) {
            return Err("invalid planner terrain");
        }
        let count = input.u32()? as usize;
        if count > CACHE_LIMIT {
            return Err("too many cached corridors");
        }
        for _ in 0..count {
            let key = CacheKey {
                vehicle: input.boolean()?,
                policy: input.u32()? as i32,
                terrain_revision: input.u64()?,
                danger_revision: input.u64()?,
                cells: [
                    input.u32()? as i32,
                    input.u32()? as i32,
                    input.u32()? as i32,
                    input.u32()? as i32,
                ],
            };
            if !(-1..=1).contains(&key.policy)
                || key
                    .cells
                    .iter()
                    .any(|c| *c < 0 || *c as usize > (side - 1) / 32)
                || planner.cache.iter().any(|(k, _)| *k == key)
            {
                return Err("invalid corridor key");
            }
            let count = input.u32()? as usize;
            if count == 0 || count > side * side {
                return Err("invalid corridor length");
            }
            let mut route = Vec::new();
            for _ in 0..count {
                let point = input.point()?;
                if point.abs().max_element() > side as f32 * 2.0 {
                    return Err("invalid corridor point");
                }
                route.push(point);
            }
            planner.cache.push_back((key, route));
        }
        let count = input.u32()? as usize;
        if count > JOB_LIMIT {
            return Err("too many path jobs");
        }
        for _ in 0..count {
            let job = PathJob {
                id: input.u64()?,
                destination: input.point()?,
                vehicle: input.boolean()?,
                team: input.u32()? as i32,
                care: input.f64()?,
            };
            if job.id == 0 || job.id > i64::MAX as u64 || planner.jobs.insert(job.id, job).is_some()
            {
                return Err("invalid path job");
            }
        }
        let count = input.u32()? as usize;
        if count > JOB_LIMIT {
            return Err("too many path queue entries");
        }
        let mut pending = std::collections::HashSet::new();
        for _ in 0..count {
            let id = input.u64()?;
            if id == 0 || id > i64::MAX as u64 {
                return Err("invalid queued unit");
            }
            planner.order.push_back(id);
            pending.insert(id);
        }
        if planner.jobs.keys().any(|id| !pending.contains(id)) {
            return Err("unqueued path job");
        }
        planner.batch_left = input.u32()? as usize;
        if planner.batch_left > planner.order.len() {
            return Err("invalid path batch");
        }
        input.finish()?;
        Ok(planner)
    }
}

fn flat(mut point: Vector3) -> Vector3 {
    point.y = 0.0;
    point
}

fn nearest_free(cell: [i32; 2], is_free: impl Fn([i32; 2]) -> bool) -> [i32; 2] {
    for radius in 1..10 {
        for dx in -radius..=radius {
            for dz in [-radius, radius] {
                for point in [[cell[0] + dx, cell[1] + dz], [cell[0] + dz, cell[1] + dx]] {
                    if is_free(point) {
                        return point;
                    }
                }
            }
        }
    }
    cell
}

fn refined_path(
    graph: &mut Hierarchy,
    from: [i32; 2],
    to: [i32; 2],
    team: i32,
    care: f64,
) -> Vec<[i32; 2]> {
    if graph.cluster_of(from) == graph.cluster_of(to) {
        let direct = graph.local_path(graph.cluster_of(from), from, to);
        if !direct.is_empty() {
            return direct;
        }
    }
    let waypoints = graph.route(from, to, team, care);
    if waypoints.len() < 2 {
        return Vec::new();
    }
    let mut out = vec![waypoints[0]];
    for pair in waypoints.windows(2) {
        let [a, b] = [pair[0], pair[1]];
        if a == b {
            continue;
        }
        if (a[0] - b[0]).abs() <= 1 && (a[1] - b[1]).abs() <= 1 {
            if graph.is_solid(a) || graph.is_solid(b) {
                return Vec::new();
            }
            out.push(b);
        } else {
            let cluster = graph.cluster_of(a);
            if cluster != graph.cluster_of(b) {
                return Vec::new();
            }
            let segment = graph.local_path(cluster, a, b);
            if segment.is_empty() {
                return Vec::new();
            }
            out.extend_from_slice(&segment[1..]);
        }
    }
    out
}
