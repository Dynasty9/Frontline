use crate::navigation_grid::{cluster_costs, ClusterQuery, NavigationGrid};
use crate::route_graph::RouteGraph;
use crate::state_codec::{Reader, Writer};
use crate::vector::Vector3;
use std::collections::{HashMap, VecDeque};

const UNKNOWN: f64 = -2.0;
const CACHE_CELLS: usize = 131_072;

#[derive(Default)]
struct Cluster {
    nodes: Vec<i64>,
    mids: Vec<i64>,
    basis: Vec<i64>,
    costs: Vec<f64>,
    version: u64,
    edge_version: [u64; 4],
    link_version: u64,
    danger: [f32; 2],
    danger_version: [u64; 2],
    mid_factor: [f64; 2],
}

struct Border {
    nodes: Vec<i64>,
    picks: Vec<i32>,
    version: [u64; 2],
    danger_version: [u64; 4],
}

pub struct Hierarchy {
    side: usize,
    cluster_side: usize,
    across: usize,
    solid: Vec<u8>,
    weight: Vec<f32>,
    clusters: Vec<Cluster>,
    borders: HashMap<(usize, usize), Border>,
    cells: HashMap<i64, [i32; 2]>,
    node_cluster: HashMap<i64, usize>,
    node_base: HashMap<i64, f64>,
    mids: HashMap<(i64, i64), i64>,
    graphs: [RouteGraph; 3],
    next_id: i64,
    dirty: VecDeque<usize>,
    queued: Vec<bool>,
    local: HashMap<usize, NavigationGrid>,
    recent: VecDeque<usize>,
    pub built: bool,
    pub terrain_revision: u64,
    pub danger_revision: [u64; 2],
}

impl Hierarchy {
    pub fn side(&self) -> usize {
        self.side
    }

    pub fn is_solid(&self, cell: [i32; 2]) -> bool {
        self.index(cell).is_none_or(|index| self.solid[index] != 0)
    }

    /// Local search caches cannot affect route choices; graph slots and pending repairs can.
    pub fn checkpoint(&self) -> Vec<u8> {
        let mut out = Writer::new(b"FLHP\x01\0\0\0");
        out.u32(self.side as u32);
        out.u32(self.cluster_side as u32);
        out.byte(u8::from(self.built));
        out.u64(self.next_id as u64);
        out.u64(self.terrain_revision);
        for value in self.danger_revision {
            out.u64(value);
        }
        out.bytes(&self.solid);
        let weights: Vec<u8> = self.weight.iter().flat_map(|v| v.to_le_bytes()).collect();
        out.bytes(&weights);
        for cluster in &self.clusters {
            out.u64(cluster.version);
            for value in cluster.edge_version {
                out.u64(value);
            }
            out.u64(cluster.link_version);
            for value in cluster.danger {
                out.f32(value);
            }
            for value in cluster.danger_version {
                out.u64(value);
            }
            for value in cluster.mid_factor {
                out.f64(value);
            }
            write_ids(&mut out, &cluster.nodes);
            write_ids(&mut out, &cluster.mids);
            write_ids(&mut out, &cluster.basis);
            out.u32(cluster.costs.len() as u32);
            for &value in &cluster.costs {
                out.f64(value);
            }
        }
        let mut cells: Vec<_> = self.cells.iter().collect();
        cells.sort_unstable_by_key(|(id, _)| **id);
        out.u32(cells.len() as u32);
        for (&id, cell) in cells {
            out.u64(id as u64);
            out.u32(cell[0] as u32);
            out.u32(cell[1] as u32);
        }
        let mut links: Vec<_> = self.mids.iter().collect();
        links.sort_unstable_by_key(|(pair, _)| **pair);
        out.u32(links.len() as u32);
        for (&(a, b), &mid) in links {
            out.u64(a as u64);
            out.u64(b as u64);
            out.u64(mid as u64);
            out.f64(self.node_base[&mid]);
        }
        let mut borders: Vec<_> = self.borders.iter().collect();
        borders.sort_unstable_by_key(|(pair, _)| **pair);
        out.u32(borders.len() as u32);
        for (&(a, b), border) in borders {
            out.u32(a as u32);
            out.u32(b as u32);
            write_ids(&mut out, &border.nodes);
            out.u32(border.picks.len() as u32);
            for &pick in &border.picks {
                out.u32(pick as u32);
            }
            for value in border.version {
                out.u64(value);
            }
            for value in border.danger_version {
                out.u64(value);
            }
        }
        for graph in &self.graphs {
            out.bytes(&graph.checkpoint());
        }
        out.u32(self.dirty.len() as u32);
        for &cluster in &self.dirty {
            out.u32(cluster as u32);
        }
        out.0
    }

    pub fn restore(bytes: &[u8]) -> Result<Self, &'static str> {
        let mut input = Reader::new(bytes, b"FLHP\x01\0\0\0")?;
        let side = input.u32()? as usize;
        let cluster_side = input.u32()? as usize;
        if side == 0 || side > 4096 || !(2..=64).contains(&cluster_side) || side % cluster_side != 0
        {
            return Err("invalid hierarchy dimensions");
        }
        let built = input.boolean()?;
        let next_id = input.u64()?;
        if next_id == 0 || next_id > i64::MAX as u64 / 2 {
            return Err("invalid hierarchy ID cursor");
        }
        let revision = read_revision(&mut input)?;
        let danger_revision = [read_revision(&mut input)?, read_revision(&mut input)?];
        let solid = input.bytes(side * side)?;
        let weights = input.bytes(side * side * 4)?;
        if solid.len() != side * side
            || weights.len() != side * side * 4
            || solid.iter().any(|s| *s > 1)
        {
            return Err("invalid hierarchy terrain");
        }
        let mut nav = Self::new(side, cluster_side).ok_or("invalid hierarchy dimensions")?;
        nav.solid.copy_from_slice(solid);
        for (to, data) in nav.weight.iter_mut().zip(weights.chunks_exact(4)) {
            *to = f32::from_le_bytes(data.try_into().unwrap());
            if !to.is_finite() || *to < 0.0 {
                return Err("invalid hierarchy terrain cost");
            }
        }
        nav.built = built;
        nav.next_id = next_id as i64;
        nav.terrain_revision = revision;
        nav.danger_revision = danger_revision;
        let mut nodes = 0usize;
        for (index, cluster) in nav.clusters.iter_mut().enumerate() {
            cluster.version = read_revision(&mut input)?;
            for value in &mut cluster.edge_version {
                *value = read_revision(&mut input)?;
            }
            cluster.link_version = read_revision(&mut input)?;
            for value in &mut cluster.danger {
                *value = input.f32()?;
                if *value < 0.0 {
                    return Err("negative hierarchy danger");
                }
            }
            for value in &mut cluster.danger_version {
                *value = read_revision(&mut input)?;
            }
            for value in &mut cluster.mid_factor {
                *value = input.f64()?;
                if *value < 0.0 {
                    return Err("negative hierarchy danger factor");
                }
            }
            cluster.nodes = read_ids(&mut input, 256, next_id)?;
            cluster.mids = read_ids(&mut input, 32640, next_id)?;
            cluster.basis = read_ids(&mut input, 256, next_id)?;
            nodes += cluster.nodes.len() + cluster.mids.len();
            if nodes > 1_000_000 {
                return Err("too many hierarchy nodes");
            }
            for &id in cluster.nodes.iter().chain(&cluster.mids) {
                if nav.node_cluster.insert(id, index).is_some() {
                    return Err("duplicate hierarchy node");
                }
            }
            let count = input.u32()? as usize;
            if count != cluster.basis.len() * cluster.basis.len() {
                return Err("invalid hierarchy cost table");
            }
            for _ in 0..count {
                let value = input.f64()?;
                if value < 0.0 && value != -1.0 && value != UNKNOWN {
                    return Err("invalid hierarchy link cost");
                }
                cluster.costs.push(value);
            }
            if built && cluster.nodes.iter().any(|id| !cluster.basis.contains(id)) {
                return Err("hierarchy basis omits an entrance");
            }
        }
        let count = input.u32()? as usize;
        if count > nodes {
            return Err("too many hierarchy entrances");
        }
        for _ in 0..count {
            let id = input.u64()? as i64;
            let cell = [input.u32()? as i32, input.u32()? as i32];
            let Some(&cluster) = nav.node_cluster.get(&id) else {
                return Err("unknown hierarchy entrance");
            };
            if nav.index(cell).is_none()
                || nav.cluster_of(cell) != cluster
                || !nav.clusters[cluster].nodes.contains(&id)
                || nav.cells.insert(id, cell).is_some()
            {
                return Err("invalid hierarchy entrance cell");
            }
        }
        let count = input.u32()? as usize;
        if count != nodes - nav.cells.len() {
            return Err("invalid hierarchy link count");
        }
        for _ in 0..count {
            let a = input.u64()? as i64;
            let b = input.u64()? as i64;
            let mid = input.u64()? as i64;
            let base = input.f64()?;
            let Some(&cluster) = nav.node_cluster.get(&mid) else {
                return Err("unknown hierarchy link");
            };
            if a >= b
                || !nav.cells.contains_key(&a)
                || !nav.cells.contains_key(&b)
                || nav.node_cluster[&a] != cluster
                || nav.node_cluster[&b] != cluster
                || !nav.clusters[cluster].mids.contains(&mid)
                || !(0.05..=60.0).contains(&base)
                || nav.node_base.insert(mid, base).is_some()
                || nav.mids.insert((a, b), mid).is_some()
            {
                return Err("invalid hierarchy link");
            }
        }
        let count = input.u32()? as usize;
        let expected = if built {
            2 * nav.across * (nav.across - 1)
        } else {
            0
        };
        if count != expected {
            return Err("invalid hierarchy border count");
        }
        let mut border_nodes = std::collections::HashSet::new();
        for _ in 0..count {
            let a = input.u32()? as usize;
            let b = input.u32()? as usize;
            if a >= nav.clusters.len()
                || b >= nav.clusters.len()
                || !(b == a + nav.across || (b == a + 1 && a / nav.across == b / nav.across))
            {
                return Err("invalid hierarchy neighbors");
            }
            let nodes = read_ids(&mut input, 2 * cluster_side, next_id)?;
            if nodes.iter().any(|id| !border_nodes.insert(*id)) {
                return Err("shared hierarchy border entrance");
            }
            let count = input.u32()? as usize;
            if count * 2 != nodes.len() {
                return Err("invalid hierarchy border entrances");
            }
            let mut picks = Vec::new();
            let [x, z] = nav.corner(a);
            let c = cluster_side as i32;
            for index in 0..count {
                let pick = input.u32()? as i32;
                if pick < 0 || pick >= c || picks.contains(&pick) {
                    return Err("invalid hierarchy border pick");
                }
                let ca = if b == a + 1 {
                    [x + c - 1, z + pick]
                } else {
                    [x + pick, z + c - 1]
                };
                let cb = if b == a + 1 {
                    [x + c, z + pick]
                } else {
                    [x + pick, z + c]
                };
                if nav.cells.get(&nodes[index * 2]) != Some(&ca)
                    || nav.cells.get(&nodes[index * 2 + 1]) != Some(&cb)
                {
                    return Err("hierarchy border cell mismatch");
                }
                picks.push(pick);
            }
            let version = [read_revision(&mut input)?, read_revision(&mut input)?];
            let danger_version = [
                read_revision(&mut input)?,
                read_revision(&mut input)?,
                read_revision(&mut input)?,
                read_revision(&mut input)?,
            ];
            if nav
                .borders
                .insert(
                    (a, b),
                    Border {
                        nodes,
                        picks,
                        version,
                        danger_version,
                    },
                )
                .is_some()
            {
                return Err("duplicate hierarchy border");
            }
        }
        if border_nodes.len() != nav.cells.len() {
            return Err("hierarchy entrance has no border");
        }
        for graph in &mut nav.graphs {
            *graph = RouteGraph::restore(input.bytes(256 * 1024 * 1024)?)?;
        }
        for graph in &nav.graphs {
            if graph.get_point_count() as usize != nodes
                || nav.node_cluster.keys().any(|id| !graph.has_point(*id))
            {
                return Err("hierarchy graph membership mismatch");
            }
            for (&id, &cell) in &nav.cells {
                if graph.get_point_position(id) != position(cell) {
                    return Err("hierarchy graph entrance mismatch");
                }
            }
            for (&(a, b), &mid) in &nav.mids {
                if graph.get_point_position(mid)
                    != (position(nav.cells[&a]) + position(nav.cells[&b])) * 0.5
                {
                    return Err("hierarchy graph link mismatch");
                }
            }
        }
        let count = input.u32()? as usize;
        if count > nav.clusters.len() {
            return Err("too many pending hierarchy repairs");
        }
        for _ in 0..count {
            let cluster = input.u32()? as usize;
            if cluster >= nav.clusters.len() || nav.queued[cluster] {
                return Err("invalid pending hierarchy repair");
            }
            nav.queued[cluster] = true;
            nav.dirty.push_back(cluster);
        }
        input.finish()?;
        if !built && (nodes != 0 || count != 0) {
            return Err("unbuilt hierarchy has graph state");
        }
        Ok(nav)
    }
    pub fn new(side: usize, cluster_side: usize) -> Option<Self> {
        if side == 0 || side > 4096 || !(2..=64).contains(&cluster_side) || side % cluster_side != 0
        {
            return None;
        }
        let across = side / cluster_side;
        if across * across > 65_536 {
            return None;
        }
        Some(Self {
            side,
            cluster_side,
            across,
            solid: vec![0; side * side],
            weight: vec![1.0; side * side],
            clusters: (0..across * across).map(|_| Cluster::default()).collect(),
            borders: HashMap::new(),
            cells: HashMap::new(),
            node_cluster: HashMap::new(),
            node_base: HashMap::new(),
            mids: HashMap::new(),
            graphs: std::array::from_fn(|_| RouteGraph::new()),
            next_id: 1,
            dirty: VecDeque::new(),
            queued: vec![false; across * across],
            local: HashMap::new(),
            recent: VecDeque::new(),
            built: false,
            terrain_revision: 0,
            danger_revision: [0; 2],
        })
    }

    pub fn cluster_of(&self, cell: [i32; 2]) -> usize {
        let c = self.cluster_side as i32;
        (cell[1] / c).clamp(0, self.across as i32 - 1) as usize * self.across
            + (cell[0] / c).clamp(0, self.across as i32 - 1) as usize
    }

    fn corner(&self, cluster: usize) -> [i32; 2] {
        [
            (cluster % self.across * self.cluster_side) as i32,
            (cluster / self.across * self.cluster_side) as i32,
        ]
    }

    fn index(&self, cell: [i32; 2]) -> Option<usize> {
        (cell[0] >= 0 && cell[1] >= 0 && cell[0] < self.side as i32 && cell[1] < self.side as i32)
            .then(|| cell[1] as usize * self.side + cell[0] as usize)
    }

    pub fn set_cell(&mut self, cell: [i32; 2], solid: bool, weight: f32) -> bool {
        let Some(index) = self.index(cell) else {
            return false;
        };
        if !weight.is_finite() || weight < 0.0 {
            return false;
        }
        if self.solid[index] == u8::from(solid) && self.weight[index] == weight {
            return true;
        }
        let cluster = self.cluster_of(cell);
        self.solid[index] = u8::from(solid);
        self.weight[index] = weight;
        if let Some(grid) = self.local.get_mut(&cluster) {
            grid.set_solid(cell, solid);
            grid.set_weight(cell, weight);
        }
        if self.built {
            self.terrain_revision += 1;
            let state = &mut self.clusters[cluster];
            state.version += 1;
            let x = cell[0] as usize % self.cluster_side;
            let z = cell[1] as usize % self.cluster_side;
            if x == 0 {
                state.edge_version[0] += 1;
            } else if x == self.cluster_side - 1 {
                state.edge_version[1] += 1;
            }
            if z == 0 {
                state.edge_version[2] += 1;
            } else if z == self.cluster_side - 1 {
                state.edge_version[3] += 1;
            }
            if !self.queued[cluster] {
                self.queued[cluster] = true;
                self.dirty.push_back(cluster);
            }
        }
        true
    }

    pub fn load_cells(&mut self, solid: &[u8], weight: &[f32]) -> bool {
        if self.built
            || solid.len() != self.solid.len()
            || weight.len() != self.weight.len()
            || !weight.iter().all(|v| v.is_finite() && *v >= 0.0)
        {
            return false;
        }
        for (to, from) in self.solid.iter_mut().zip(solid) {
            *to = u8::from(*from != 0);
        }
        self.weight.copy_from_slice(weight);
        self.local.clear();
        self.recent.clear();
        true
    }

    fn local_grid(&mut self, cluster: usize) -> &mut NavigationGrid {
        if let Some(at) = self.recent.iter().position(|v| *v == cluster) {
            self.recent.remove(at);
        }
        if !self.local.contains_key(&cluster) {
            if self.local.len() >= CACHE_CELLS / (self.cluster_side * self.cluster_side) {
                if let Some(old) = self.recent.pop_front() {
                    self.local.remove(&old);
                }
            }
            let corner = self.corner(cluster);
            let mut grid =
                NavigationGrid::new(corner, self.cluster_side as i32, self.cluster_side as i32)
                    .unwrap();
            for z in 0..self.cluster_side {
                for x in 0..self.cluster_side {
                    let cell = [corner[0] + x as i32, corner[1] + z as i32];
                    let index = cell[1] as usize * self.side + cell[0] as usize;
                    grid.set_solid(cell, self.solid[index] != 0);
                    grid.set_weight(cell, self.weight[index]);
                }
            }
            self.local.insert(cluster, grid);
        }
        self.recent.push_back(cluster);
        self.local.get_mut(&cluster).unwrap()
    }

    pub fn local_path(&mut self, cluster: usize, from: [i32; 2], to: [i32; 2]) -> Vec<[i32; 2]> {
        if cluster >= self.clusters.len() {
            return Vec::new();
        }
        self.local_grid(cluster).path(from, to)
    }

    pub fn cached_clusters(&self) -> Vec<usize> {
        self.recent.iter().copied().collect()
    }
    pub fn pending_clusters(&self) -> Vec<usize> {
        self.dirty.iter().copied().collect()
    }
    pub fn has_work(&self) -> bool {
        !self.dirty.is_empty()
    }
    pub fn counts(&self) -> [usize; 2] {
        [self.cells.len(), self.graphs[0].get_point_count() as usize]
    }

    fn edge_versions(&self, a: usize, b: usize) -> [u64; 2] {
        if b == a + 1 {
            [
                self.clusters[a].edge_version[1],
                self.clusters[b].edge_version[0],
            ]
        } else {
            [
                self.clusters[a].edge_version[3],
                self.clusters[b].edge_version[2],
            ]
        }
    }
    fn danger_versions(&self, a: usize, b: usize) -> [u64; 4] {
        let x = self.clusters[a].danger_version;
        let y = self.clusters[b].danger_version;
        [x[0], x[1], y[0], y[1]]
    }

    fn border_picks(&self, a: usize, b: usize) -> Vec<i32> {
        let horizontal = b == a + 1;
        let [x, z] = self.corner(a);
        let c = self.cluster_side;
        let ia = if horizontal {
            z as usize * self.side + x as usize + c - 1
        } else {
            (z as usize + c - 1) * self.side + x as usize
        };
        let ib = ia + if horizontal { 1 } else { self.side };
        let step = if horizontal { self.side } else { 1 };
        let mut out = Vec::new();
        let mut run_start = None;
        for i in 0..=c {
            let open = i < c && self.solid[ia + i * step] == 0 && self.solid[ib + i * step] == 0;
            if open && run_start.is_none() {
                run_start = Some(i);
            } else if !open {
                if let Some(start) = run_start.take() {
                    let end = i - 1;
                    let mut picks = if end - start < 6 {
                        vec![((start + end) >> 1) as i32]
                    } else {
                        vec![(start + 2) as i32, (end - 2) as i32]
                    };
                    let mut cheap_start = None;
                    for j in start..=end + 1 {
                        let cheap = j <= end && f64::from(self.weight[ib + j * step]) < 0.95;
                        if cheap && cheap_start.is_none() {
                            cheap_start = Some(j);
                        } else if !cheap {
                            if let Some(first) = cheap_start.take() {
                                let middle = ((first + j - 1) >> 1) as i32;
                                if !picks.iter().any(|p| (p - middle).abs() < 3) {
                                    picks.push(middle);
                                }
                            }
                        }
                    }
                    out.extend(picks);
                }
            }
        }
        out
    }

    fn add_point(&mut self, id: i64, position: Vector3, cluster: usize, base: f64) {
        self.node_cluster.insert(id, cluster);
        self.graphs[0].add_point(id, position, base);
        for team in 0..2 {
            self.graphs[team + 1].add_point(
                id,
                position,
                base * (1.0 + f64::from(self.clusters[cluster].danger[team])),
            );
        }
    }
    fn connect(&mut self, a: i64, b: i64) {
        for graph in &mut self.graphs {
            graph.connect_points(a, b);
        }
    }
    fn remove_point(&mut self, id: i64) {
        self.node_cluster.remove(&id);
        self.node_base.remove(&id);
        for graph in &mut self.graphs {
            graph.remove_point(id);
        }
    }
    fn add_node(&mut self, cell: [i32; 2], cluster: usize) -> i64 {
        let id = self.next_id;
        self.next_id += 1;
        self.add_point(id, position(cell), cluster, 1.0);
        self.cells.insert(id, cell);
        self.clusters[cluster].nodes.push(id);
        id
    }

    fn make_border(&mut self, a: usize, b: usize, picks: Vec<i32>) {
        let horizontal = b == a + 1;
        let [x, z] = self.corner(a);
        let c = self.cluster_side as i32;
        let mut nodes = Vec::with_capacity(picks.len() * 2);
        for &p in &picks {
            let pa = if horizontal {
                [x + c - 1, z + p]
            } else {
                [x + p, z + c - 1]
            };
            let pb = if horizontal {
                [x + c, z + p]
            } else {
                [x + p, z + c]
            };
            let na = self.add_node(pa, a);
            let nb = self.add_node(pb, b);
            self.connect(na, nb);
            nodes.extend([na, nb]);
        }
        self.borders.insert(
            (a, b),
            Border {
                nodes,
                picks,
                version: self.edge_versions(a, b),
                danger_version: self.danger_versions(a, b),
            },
        );
    }

    fn clear_border(&mut self, a: usize, b: usize) {
        let Some(border) = self.borders.remove(&(a, b)) else {
            return;
        };
        for id in border.nodes {
            if let Some(&cluster) = self.node_cluster.get(&id) {
                for other in self.clusters[cluster].nodes.clone() {
                    if let Some(mid) = self.mids.remove(&key(id, other)) {
                        self.clusters[cluster].mids.retain(|m| *m != mid);
                        self.remove_point(mid);
                    }
                }
            }
            self.remove_point(id);
            self.cells.remove(&id);
            self.clusters[a].nodes.retain(|n| *n != id);
            self.clusters[b].nodes.retain(|n| *n != id);
        }
    }

    fn link(&mut self, a: i64, b: i64, cost: f64, cluster: usize, temporary: bool) -> Option<i64> {
        let pa = self.graphs[0].get_point_position(a);
        let pb = self.graphs[0].get_point_position(b);
        let length = f64::from(pa.distance(pb));
        if length < 0.5 {
            self.connect(a, b);
            return None;
        }
        let weight = (2.0 * cost / length - 1.0).clamp(0.05, 60.0);
        let id = self.next_id;
        self.next_id += 1;
        self.node_base.insert(id, weight);
        self.add_point(id, (pa + pb) * 0.5, cluster, weight);
        self.connect(a, id);
        self.connect(id, b);
        if !temporary {
            self.mids.insert(key(a, b), id);
            self.clusters[cluster].mids.push(id);
        }
        Some(id)
    }

    fn set_link(&mut self, a: i64, b: i64, cost: f64, cluster: usize) {
        let mid = self.mids.get(&key(a, b)).copied();
        if cost < 0.0 {
            if let Some(mid) = mid {
                self.mids.remove(&key(a, b));
                self.clusters[cluster].mids.retain(|m| *m != mid);
                self.remove_point(mid);
            }
            return;
        }
        let length = f64::from(position(self.cells[&a]).distance(position(self.cells[&b])));
        if length < 0.5 {
            self.connect(a, b);
            return;
        }
        let weight = (2.0 * cost / length - 1.0).clamp(0.05, 60.0);
        if let Some(mid) = mid {
            if self.node_base[&mid] != weight {
                self.node_base.insert(mid, weight);
                self.graphs[0].set_point_weight_scale(mid, weight);
                for team in 0..2 {
                    self.graphs[team + 1].set_point_weight_scale(
                        mid,
                        weight * self.clusters[cluster].mid_factor[team],
                    );
                }
            }
        } else {
            self.link(a, b, cost, cluster, false);
        }
    }

    fn fresh_danger(&mut self, cluster: usize) {
        for team in 0..2 {
            let factor = 1.0 + f64::from(self.clusters[cluster].danger[team]);
            if self.clusters[cluster].mid_factor[team] != factor {
                self.clusters[cluster].mid_factor[team] = factor;
                for &mid in &self.clusters[cluster].mids {
                    self.graphs[team + 1]
                        .set_point_weight_scale(mid, self.node_base[&mid] * factor);
                }
            }
        }
    }

    fn relink(&mut self, cluster: usize, before: &[i64]) {
        self.fresh_danger(cluster);
        let state = &mut self.clusters[cluster];
        let regrid = state.link_version != state.version;
        if !regrid && state.nodes == before {
            return;
        }
        let nodes = state.nodes.clone();
        let n = nodes.len();
        let mut at = vec![None; n];
        let mut bp = vec![None; n];
        let mut basis = state.basis.clone();
        let mut costs = std::mem::take(&mut state.costs);
        let mut fresh = regrid;
        if !regrid {
            for i in 0..n {
                at[i] = before.iter().position(|v| *v == nodes[i]);
                bp[i] = basis.iter().position(|v| *v == nodes[i]);
                fresh |= bp[i].is_none();
            }
        }
        if fresh {
            let mut next = vec![UNKNOWN; n * n];
            if !regrid {
                for i in 0..n {
                    for j in 0..n {
                        if let (Some(a), Some(b)) = (bp[i], bp[j]) {
                            next[i * n + j] = costs[a * basis.len() + b];
                        }
                    }
                }
            }
            for (i, v) in bp.iter_mut().enumerate() {
                *v = Some(i);
            }
            costs = next;
            basis = nodes.clone();
            state.basis = basis.clone();
        }
        for i in 0..n {
            let row = bp[i].unwrap() * basis.len();
            for j in i + 1..n {
                if matches!((at[i], at[j]), (Some(a), Some(b)) if b > a) {
                    continue;
                }
                let offset = row + bp[j].unwrap();
                let mut cost = costs[offset];
                if cost == UNKNOWN {
                    let ca = self.cells[&nodes[i]];
                    let cb = self.cells[&nodes[j]];
                    cost = self.local_grid(cluster).path_cost(ca, cb);
                    costs[offset] = cost;
                }
                if at[i].is_some()
                    && at[j].is_some()
                    && cost == costs[bp[j].unwrap() * basis.len() + bp[i].unwrap()]
                {
                    continue;
                }
                self.set_link(nodes[i], nodes[j], cost, cluster);
            }
        }
        self.clusters[cluster].costs = costs;
        self.clusters[cluster].link_version = self.clusters[cluster].version;
    }

    fn rebuild_cluster(&mut self, cluster: usize) {
        let x = cluster % self.across;
        let z = cluster / self.across;
        let mut neighbors = Vec::with_capacity(4);
        if x > 0 {
            neighbors.push(cluster - 1);
        }
        if x + 1 < self.across {
            neighbors.push(cluster + 1);
        }
        if z > 0 {
            neighbors.push(cluster - self.across);
        }
        if z + 1 < self.across {
            neighbors.push(cluster + self.across);
        }
        let before: Vec<_> = std::iter::once(cluster)
            .chain(neighbors.iter().copied())
            .map(|i| self.clusters[i].nodes.clone())
            .collect();
        for &neighbor in &neighbors {
            let a = cluster.min(neighbor);
            let b = cluster.max(neighbor);
            let key = (a, b);
            let versions = self.edge_versions(a, b);
            if self.borders[&key].version != versions {
                self.borders.get_mut(&key).unwrap().version = versions;
                let picks = self.border_picks(a, b);
                if self.borders[&key].picks != picks {
                    self.clear_border(a, b);
                    self.make_border(a, b, picks);
                    continue;
                }
            }
            let versions = self.danger_versions(a, b);
            if self.borders[&key].danger_version != versions {
                self.borders.get_mut(&key).unwrap().danger_version = versions;
                for id in &self.borders[&key].nodes {
                    let k = self.node_cluster[id];
                    for team in 0..2 {
                        self.graphs[team + 1].set_point_weight_scale(
                            *id,
                            1.0 + f64::from(self.clusters[k].danger[team]),
                        );
                    }
                }
            }
        }
        let mut own = Vec::new();
        for &neighbor in &neighbors {
            let border = &self.borders[&(cluster.min(neighbor), cluster.max(neighbor))].nodes;
            let offset = usize::from(cluster > neighbor);
            own.extend(border.iter().skip(offset).step_by(2).copied());
            let theirs = &mut self.clusters[neighbor].nodes;
            for id in border.iter().skip(1 - offset).step_by(2) {
                theirs.retain(|v| v != id);
            }
            theirs.extend(border.iter().skip(1 - offset).step_by(2).copied());
        }
        self.clusters[cluster].nodes = own;
        self.relink(cluster, &before[0]);
        for (index, neighbor) in neighbors.into_iter().enumerate() {
            self.relink(neighbor, &before[index + 1]);
        }
    }

    pub fn update(&mut self, budget: usize) -> bool {
        if !self.built {
            return build_all(&mut [self], 1);
        }
        for _ in 0..budget {
            let Some(cluster) = self.dirty.pop_front() else {
                break;
            };
            self.queued[cluster] = false;
            self.rebuild_cluster(cluster);
        }
        true
    }

    pub fn set_danger(&mut self, team: usize, values: &[f32]) -> bool {
        if team > 1
            || values.len() != self.clusters.len()
            || !values.iter().all(|v| v.is_finite() && *v >= 0.0)
        {
            return false;
        }
        for (cluster, &value) in self.clusters.iter_mut().zip(values) {
            let old = cluster.danger[team];
            cluster.danger[team] = value;
            if !self.built {
                continue;
            }
            if old != value {
                cluster.danger_version[team] += 1;
            }
            if (f64::from(old) - f64::from(value)).abs() < 0.05 {
                continue;
            }
            self.danger_revision[team] += 1;
            let factor = 1.0 + f64::from(value);
            for &id in &cluster.nodes {
                self.graphs[team + 1].set_point_weight_scale(id, factor);
            }
            for &id in &cluster.mids {
                self.graphs[team + 1].set_point_weight_scale(id, self.node_base[&id] * factor);
            }
            cluster.mid_factor[team] = factor;
        }
        true
    }

    pub fn route(&mut self, from: [i32; 2], to: [i32; 2], team: i32, care: f64) -> Vec<[i32; 2]> {
        if self.index(from).is_none()
            || self.index(to).is_none()
            || (!self.built && !build_all(&mut [self], 1))
        {
            return Vec::new();
        }
        let graph = if care > 0.0 && (0..2).contains(&team) {
            team as usize + 1
        } else {
            0
        };
        let a = self.cluster_of(from);
        let b = self.cluster_of(to);
        let start = self.next_id;
        let goal = start + 1;
        self.next_id += 2;
        self.add_point(start, position(from), a, 1.0);
        self.add_point(goal, position(to), b, 1.0);
        let mut temporary = Vec::new();
        for (cluster, cell, endpoint) in [(a, from, start), (b, to, goal)] {
            for id in self.clusters[cluster].nodes.clone() {
                let destination = self.cells[&id];
                let cost = self.local_grid(cluster).path_cost(cell, destination);
                if cost >= 0.0 {
                    if let Some(mid) = self.link(endpoint, id, cost, cluster, true) {
                        temporary.push(mid);
                    }
                }
            }
        }
        if a == b {
            let cost = self.local_grid(a).path_cost(from, to);
            if cost >= 0.0 {
                if let Some(mid) = self.link(start, goal, cost, a, true) {
                    temporary.push(mid);
                }
            }
        }
        let ids = self.graphs[graph].get_id_path(start, goal);
        let out = ids
            .into_iter()
            .filter_map(|id| {
                if id == start {
                    Some(from)
                } else if id == goal {
                    Some(to)
                } else {
                    self.cells.get(&id).copied()
                }
            })
            .collect();
        for id in temporary {
            self.remove_point(id);
        }
        self.remove_point(start);
        self.remove_point(goal);
        out
    }
}

/// Prepare and assemble in the original order; only independent cell searches run in parallel.
pub fn build_all(navs: &mut [&mut Hierarchy], workers: usize) -> bool {
    if navs.iter().any(|nav| nav.built) {
        return false;
    }
    let mut shared: HashMap<Vec<u8>, Vec<f64>> = HashMap::new();
    for nav in navs.iter_mut() {
        for z in 0..nav.across {
            for x in 0..nav.across {
                let cluster = z * nav.across + x;
                if x + 1 < nav.across {
                    nav.make_border(cluster, cluster + 1, nav.border_picks(cluster, cluster + 1));
                }
                if z + 1 < nav.across {
                    nav.make_border(
                        cluster,
                        cluster + nav.across,
                        nav.border_picks(cluster, cluster + nav.across),
                    );
                }
            }
        }
        let mut queries = Vec::new();
        let mut keys = Vec::new();
        let mut slots = Vec::new();
        let mut first = HashMap::new();
        let mut alike = Vec::new();
        for cluster in 0..nav.clusters.len() {
            let nodes = nav.clusters[cluster].nodes.clone();
            nav.clusters[cluster].basis = nodes.clone();
            if nodes.len() < 2 {
                nav.clusters[cluster].costs = vec![UNKNOWN; nodes.len() * nodes.len()];
                continue;
            }
            let corner = nav.corner(cluster);
            let mut key =
                Vec::with_capacity(nav.cluster_side * nav.cluster_side * 5 + nodes.len() * 2 + 4);
            key.extend_from_slice(&(nav.cluster_side as u32).to_le_bytes());
            for z in 0..nav.cluster_side {
                let row = (corner[1] as usize + z) * nav.side + corner[0] as usize;
                key.extend_from_slice(&nav.solid[row..row + nav.cluster_side]);
            }
            for z in 0..nav.cluster_side {
                let row = (corner[1] as usize + z) * nav.side + corner[0] as usize;
                for &weight in &nav.weight[row..row + nav.cluster_side] {
                    key.extend_from_slice(&weight.to_le_bytes());
                }
            }
            let entrances: Vec<_> = nodes.iter().map(|id| nav.cells[id]).collect();
            for cell in &entrances {
                let relative =
                    (cell[1] - corner[1]) * nav.cluster_side as i32 + cell[0] - corner[0];
                key.extend_from_slice(&(relative as u16).to_le_bytes());
            }
            if let Some(costs) = shared.get(&key) {
                nav.clusters[cluster].costs = costs.clone();
            } else if let Some(&source) = first.get(&key) {
                alike.push((cluster, source));
            } else {
                first.insert(key.clone(), cluster);
                slots.push(cluster);
                keys.push(key);
                queries.push(ClusterQuery {
                    origin: corner,
                    entrances,
                });
            }
        }
        let Some(costs) = cluster_costs(
            nav.side,
            nav.cluster_side,
            &nav.solid,
            &nav.weight,
            &queries,
            workers,
        ) else {
            return false;
        };
        for ((cluster, key), costs) in slots.into_iter().zip(keys).zip(costs) {
            shared.insert(key, costs.clone());
            nav.clusters[cluster].costs = costs;
        }
        for (cluster, source) in alike {
            nav.clusters[cluster].costs = nav.clusters[source].costs.clone();
        }
        for cluster in 0..nav.clusters.len() {
            let nodes = nav.clusters[cluster].nodes.clone();
            for i in 0..nodes.len() {
                for j in i + 1..nodes.len() {
                    let cost = nav.clusters[cluster].costs[i * nodes.len() + j];
                    if cost >= 0.0 {
                        nav.link(nodes[i], nodes[j], cost, cluster, false);
                    }
                }
            }
            nav.clusters[cluster].link_version = nav.clusters[cluster].version;
            for team in 0..2 {
                nav.clusters[cluster].mid_factor[team] =
                    1.0 + f64::from(nav.clusters[cluster].danger[team]);
            }
        }
        nav.built = true;
        nav.dirty.clear();
        nav.queued.fill(false);
    }
    true
}

fn position(cell: [i32; 2]) -> Vector3 {
    Vector3::new(cell[0] as f32 + 0.5, 0.0, cell[1] as f32 + 0.5)
}

fn write_ids(out: &mut Writer, ids: &[i64]) {
    out.u32(ids.len() as u32);
    for &id in ids {
        out.u64(id as u64);
    }
}

fn read_ids(input: &mut Reader<'_>, limit: usize, next_id: u64) -> Result<Vec<i64>, &'static str> {
    let count = input.u32()? as usize;
    if count > limit {
        return Err("too many hierarchy IDs");
    }
    let mut out = Vec::new();
    let mut seen = std::collections::HashSet::new();
    for _ in 0..count {
        let id = input.u64()?;
        if id == 0 || id >= next_id || !seen.insert(id) {
            return Err("invalid or duplicate hierarchy ID");
        }
        out.push(id as i64);
    }
    Ok(out)
}
fn read_revision(input: &mut Reader<'_>) -> Result<u64, &'static str> {
    let value = input.u64()?;
    // Leave room for future edits, including checkpoints supplied by a verifier.
    if value > i64::MAX as u64 / 2 {
        return Err("hierarchy revision exceeds limit");
    }
    Ok(value)
}
fn key(a: i64, b: i64) -> (i64, i64) {
    (a.min(b), a.max(b))
}
