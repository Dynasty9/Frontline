use crate::state_codec::{Reader, Writer};
use crate::vector::Vector3;
use std::collections::HashMap;

#[derive(Clone)]
struct Point {
    id: i64,
    position: Vector3,
    weight: f64,
    edges: Vec<(usize, f64)>,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn component_labels_match_depth_first_search_after_slot_reuse_and_restore() {
        for variant in 0..12 {
            let mut graph = road_grid(12, variant);
            for id in (0..144).step_by(7) {
                graph.remove_point(id);
            }
            for id in 20_000..20_020 {
                graph.add_point(id, Vector3::ZERO, 1.0);
                if id % 4 != 0 {
                    graph.connect_points(id - 1, id);
                }
            }
            for graph in [&graph, &RouteGraph::restore(&graph.checkpoint()).unwrap()] {
                let checkpoint = graph.checkpoint();
                assert_eq!(graph.components(), graph.depth_first_components());
                assert_eq!(graph.checkpoint(), checkpoint);
            }
        }
    }

    fn road_grid(side: i64, variant: i64) -> RouteGraph {
        let mut graph = RouteGraph::new();
        for id in 0..side * side {
            graph.add_point(
                id,
                Vector3::new((id % side * 10) as f32, 0.0, (id / side * 10) as f32),
                if (id + variant) % 17 == 0 { 4.0 } else { 1.0 },
            );
        }
        let mut mid = side * side;
        for a in 0..side * side {
            for b in [a + 1, a + side] {
                if b >= side * side
                    || (b == a + 1 && b % side == 0)
                    || (a * 3 + b + variant) % 11 == 0
                {
                    continue;
                }
                let weight = [0.05, 0.3, 1.0, 6.0][((a + b + variant) % 4) as usize];
                graph.add_point(
                    mid,
                    (graph.get_point_position(a) + graph.get_point_position(b)) * 0.5,
                    weight,
                );
                graph.connect_points(a, mid);
                graph.connect_points(mid, b);
                mid += 1;
            }
        }
        graph.add_point(10_000, Vector3::new(-10.0, 0.0, -10.0), 1.0);
        graph
    }

    // Independent uncontracted Dijkstra checks the admissible bound, including
    // road detours, danger costs and degree-two entrances skipped by the live search.
    fn shortest_cost(graph: &RouteGraph, from: i64, to: i64) -> f64 {
        let mut costs = vec![f64::INFINITY; graph.points.len()];
        let mut done = vec![false; costs.len()];
        costs[graph.ids[&from]] = 0.0;
        loop {
            let next = (0..costs.len())
                .filter(|&i| !done[i])
                .min_by(|&a, &b| costs[a].total_cmp(&costs[b]));
            let Some(next) = next else {
                return f64::INFINITY;
            };
            if next == graph.ids[&to] || !costs[next].is_finite() {
                return costs[next];
            }
            done[next] = true;
            for &(other, length) in &graph.points[next].as_ref().unwrap().edges {
                costs[other] = costs[other]
                    .min(costs[next] + length * graph.points[other].as_ref().unwrap().weight);
            }
        }
    }

    #[test]
    fn midpoint_heuristic_preserves_shortest_cost_and_checkpoint() {
        for variant in 0..8 {
            let mut graph = road_grid(8, variant);
            let checkpoint = graph.checkpoint();
            for from in [0, 7, 25, 63] {
                for to in [1, 28, 56, 10_000] {
                    let expected = shortest_cost(&graph, from, to);
                    let path = graph.get_midpoint_path(from, to);
                    if !expected.is_finite() {
                        assert!(path.is_empty());
                        continue;
                    }
                    assert_eq!(path.first(), Some(&from));
                    assert_eq!(path.last(), Some(&to));
                    let cost: f64 = path
                        .windows(2)
                        .map(|pair| {
                            let a = graph.ids[&pair[0]];
                            let b = graph.ids[&pair[1]];
                            graph.points[a]
                                .as_ref()
                                .unwrap()
                                .edges
                                .iter()
                                .find(|e| e.0 == b)
                                .unwrap()
                                .1
                                * graph.points[b].as_ref().unwrap().weight
                        })
                        .sum();
                    assert!(
                        (cost - expected).abs() < 1e-9,
                        "{variant}: {from}->{to}: {cost} != {expected}"
                    );
                }
            }
            assert_eq!(graph.checkpoint(), checkpoint);
        }
    }

    #[test]
    fn midpoint_heuristic_explores_less_of_a_large_road_graph() {
        for minimum in [0.05, 0.7, 1.0] {
            let mut graph = road_grid(32, 0);
            for point in graph.points.iter_mut().flatten() {
                point.weight = point.weight.max(minimum);
            }
            graph.minimum_weight = minimum;
            let from = 32 * 16;
            let to = from + 31;
            assert!(!graph.get_id_path(from, to).is_empty());
            let original = graph.last_expanded;
            assert!(!graph.get_midpoint_path(from, to).is_empty());
            assert!(
                graph.last_expanded <= original,
                "minimum {minimum}: {} > {original}",
                graph.last_expanded
            );
        }
    }
}

mod search;
pub(crate) use search::RouteQuery;
use search::Search;

/// HPA's two-edge cost nodes need not become separate A* search states.
/// Keep their directional costs and include them when reconstructing the path.
#[derive(Default)]
pub struct RouteGraph {
    ids: HashMap<i64, usize>,
    points: Vec<Option<Point>>,
    free: Vec<usize>,
    search: Search,
    minimum_weight: f64,
    pub last_expanded: u64,
}

impl RouteGraph {
    #[cfg(test)]
    pub(crate) fn depth_first_components(&self) -> Vec<usize> {
        let mut groups = vec![usize::MAX; self.points.len()];
        let mut pending = Vec::new();
        for root in 0..self.points.len() {
            if self.points[root].is_none() || groups[root] != usize::MAX {
                continue;
            }
            groups[root] = root;
            pending.push(root);
            while let Some(index) = pending.pop() {
                for &(next, _) in &self.points[index].as_ref().unwrap().edges {
                    if groups[next] == usize::MAX {
                        groups[next] = root;
                        pending.push(next);
                    }
                }
            }
        }
        groups
    }

    /// Slot reuse and neighbor order break equal-cost ties, so both are authoritative.
    pub fn checkpoint(&self) -> Vec<u8> {
        let mut out = Writer::new(b"FLRG\x01\0\0\0");
        out.f64(self.minimum_weight);
        out.u32(self.points.len() as u32);
        for point in &self.points {
            out.byte(u8::from(point.is_some()));
            if let Some(point) = point {
                out.u64(point.id as u64);
                out.point(point.position);
                out.f64(point.weight);
                out.u32(point.edges.len() as u32);
                for &(next, _) in &point.edges {
                    out.u32(next as u32);
                }
            }
        }
        out.u32(self.free.len() as u32);
        for &slot in &self.free {
            out.u32(slot as u32);
        }
        out.0
    }

    pub fn restore(bytes: &[u8]) -> Result<Self, &'static str> {
        let mut input = Reader::new(bytes, b"FLRG\x01\0\0\0")?;
        let minimum_weight = input.f64()?;
        if minimum_weight < 0.0 {
            return Err("negative route heuristic");
        }
        let count = input.u32()? as usize;
        if count > 1_000_000 || count > bytes.len() {
            return Err("too many route slots");
        }
        let mut graph = Self::new();
        graph.minimum_weight = minimum_weight;
        let mut edges = std::collections::HashSet::new();
        for index in 0..count {
            let point = if input.boolean()? {
                let id = input.u64()?;
                if id > i64::MAX as u64 || graph.ids.insert(id as i64, index).is_some() {
                    return Err("invalid or duplicate route ID");
                }
                let position = input.point()?;
                let weight = input.f64()?;
                if weight < minimum_weight {
                    return Err("invalid route weight");
                }
                let n = input.u32()? as usize;
                if n >= count || edges.len() + n > 8_000_000 {
                    return Err("too many route edges");
                }
                let mut neighbors = Vec::new();
                for _ in 0..n {
                    let next = input.u32()? as usize;
                    if next >= count || next == index || !edges.insert((index, next)) {
                        return Err("invalid or duplicate route edge");
                    }
                    neighbors.push((next, 0.0));
                }
                Some(Point {
                    id: id as i64,
                    position,
                    weight,
                    edges: neighbors,
                })
            } else {
                None
            };
            graph.points.push(point);
        }
        let free = input.u32()? as usize;
        if free != count - graph.ids.len() {
            return Err("invalid route free list size");
        }
        let mut seen = vec![false; count];
        for _ in 0..free {
            let slot = input.u32()? as usize;
            if slot >= count || graph.points[slot].is_some() || seen[slot] {
                return Err("invalid route free slot");
            }
            seen[slot] = true;
            graph.free.push(slot);
        }
        input.finish()?;
        for &(from, to) in &edges {
            if graph.points[to].is_none() || !edges.contains(&(to, from)) {
                return Err("asymmetric route edge");
            }
        }
        for index in 0..count {
            if let Some(point) = &graph.points[index] {
                let position = point.position;
                let distances: Vec<_> = point
                    .edges
                    .iter()
                    .map(|(next, _)| {
                        position.distance(graph.points[*next].as_ref().unwrap().position) as f64
                    })
                    .collect();
                if distances.iter().any(|d| !d.is_finite()) {
                    return Err("nonfinite route length");
                }
                for (edge, distance) in graph.points[index]
                    .as_mut()
                    .unwrap()
                    .edges
                    .iter_mut()
                    .zip(distances)
                {
                    edge.1 = distance;
                }
            }
        }
        graph.search.costs.resize(count, 0.0);
        graph.search.parents.resize(count, (0, None));
        graph.search.visited.resize(count, 0);
        Ok(graph)
    }

    pub fn new() -> Self {
        Self {
            minimum_weight: 1.0,
            ..Self::default()
        }
    }

    pub fn add_point(&mut self, id: i64, position: Vector3, weight: f64) {
        if id < 0 || !position.is_finite() || !weight.is_finite() || weight < 0.0 {
            return;
        }
        self.minimum_weight = self.minimum_weight.min(weight);
        if let Some(&index) = self.ids.get(&id) {
            let point = self.points[index].as_mut().unwrap();
            point.position = position;
            point.weight = weight;
            let neighbours: Vec<usize> = point.edges.iter().map(|e| e.0).collect();
            for neighbour in neighbours {
                let distance =
                    position.distance(self.points[neighbour].as_ref().unwrap().position) as f64;
                self.points[index]
                    .as_mut()
                    .unwrap()
                    .edges
                    .iter_mut()
                    .find(|e| e.0 == neighbour)
                    .unwrap()
                    .1 = distance;
                self.points[neighbour]
                    .as_mut()
                    .unwrap()
                    .edges
                    .iter_mut()
                    .find(|e| e.0 == index)
                    .unwrap()
                    .1 = distance;
            }
            return;
        }
        let point = Some(Point {
            id,
            position,
            weight,
            edges: Vec::new(),
        });
        let index = if let Some(index) = self.free.pop() {
            self.points[index] = point;
            self.search.visited[index] = 0;
            index
        } else {
            let index = self.points.len();
            self.points.push(point);
            self.search.costs.push(0.0);
            self.search.parents.push((index, None));
            self.search.visited.push(0);
            index
        };
        self.ids.insert(id, index);
    }

    pub fn connect_points(&mut self, a: i64, b: i64) {
        let (Some(&a), Some(&b)) = (self.ids.get(&a), self.ids.get(&b)) else {
            return;
        };
        if a == b
            || self.points[a]
                .as_ref()
                .unwrap()
                .edges
                .iter()
                .any(|e| e.0 == b)
        {
            return;
        }
        let distance = self.points[a]
            .as_ref()
            .unwrap()
            .position
            .distance(self.points[b].as_ref().unwrap().position) as f64;
        self.points[a].as_mut().unwrap().edges.push((b, distance));
        self.points[b].as_mut().unwrap().edges.push((a, distance));
    }

    pub fn remove_point(&mut self, id: i64) {
        let Some(index) = self.ids.remove(&id) else {
            return;
        };
        let point = self.points[index].take().unwrap();
        for (other, _) in point.edges {
            self.points[other]
                .as_mut()
                .unwrap()
                .edges
                .retain(|e| e.0 != index);
        }
        self.free.push(index);
    }

    pub fn has_point(&self, id: i64) -> bool {
        self.ids.contains_key(&id)
    }

    pub fn get_point_count(&self) -> i64 {
        self.ids.len() as i64
    }

    pub(crate) fn same_topology(&self, other: &Self) -> bool {
        self.points.len() == other.points.len()
            && self
                .points
                .iter()
                .zip(&other.points)
                .all(|(a, b)| match (a, b) {
                    (Some(a), Some(b)) => a.id == b.id && a.edges == b.edges,
                    (None, None) => true,
                    _ => false,
                })
    }

    pub(crate) fn components(&self) -> Vec<usize> {
        fn root(groups: &mut [usize], mut index: usize) -> usize {
            while groups[index] != index {
                groups[index] = groups[groups[index]];
                index = groups[index];
            }
            index
        }

        // Walk graph storage in order instead of chasing every weighted midpoint.
        let mut groups: Vec<usize> = (0..self.points.len()).collect();
        for (index, point) in self.points.iter().enumerate() {
            let Some(point) = point else { continue };
            for &(next, _) in &point.edges {
                if next > index {
                    let a = root(&mut groups, index);
                    let b = root(&mut groups, next);
                    groups[a.max(b)] = a.min(b);
                }
            }
        }
        for (index, point) in self.points.iter().enumerate() {
            groups[index] = if point.is_some() {
                root(&mut groups, index)
            } else {
                usize::MAX
            };
        }
        groups
    }

    pub(crate) fn component(&self, id: i64, groups: &[usize]) -> usize {
        groups[self.ids[&id]]
    }

    pub fn get_point_position(&self, id: i64) -> Vector3 {
        self.ids
            .get(&id)
            .and_then(|&i| self.points[i].as_ref())
            .map_or(Vector3::ZERO, |p| p.position)
    }

    pub(crate) fn get_point_weight_scale(&self, id: i64) -> f64 {
        self.ids
            .get(&id)
            .and_then(|&i| self.points[i].as_ref())
            .map_or(0.0, |p| p.weight)
    }

    pub(crate) fn connects_only(&self, id: i64, a: i64, b: i64) -> bool {
        let Some(point) = self.ids.get(&id).and_then(|&i| self.points[i].as_ref()) else {
            return false;
        };
        point.edges.len() == 2
            && point.edges.iter().all(|&(i, _)| {
                let other = self.points[i].as_ref().unwrap().id;
                other == a || other == b
            })
    }

    pub fn set_point_weight_scale(&mut self, id: i64, weight: f64) {
        if !weight.is_finite() || weight < 0.0 {
            return;
        }
        if let Some(&index) = self.ids.get(&id) {
            self.points[index].as_mut().unwrap().weight = weight;
            self.minimum_weight = self.minimum_weight.min(weight);
        }
    }

    pub fn get_id_path(&mut self, from: i64, to: i64) -> Vec<i64> {
        self.get_id_path_with_heuristic(from, to, self.minimum_weight)
    }

    /// Hierarchy graphs have unit-weight entrances and weighted half-edge midpoints.
    pub fn get_midpoint_path(&mut self, from: i64, to: i64) -> Vec<i64> {
        self.get_id_path_with_heuristic(from, to, (1.0 + self.minimum_weight) * 0.5)
    }

    fn get_id_path_with_heuristic(&mut self, from: i64, to: i64, minimum_cost: f64) -> Vec<i64> {
        self.last_expanded = 0;
        let (Some(&start), Some(&goal)) = (self.ids.get(&from), self.ids.get(&to)) else {
            return vec![];
        };
        self.search
            .begin(start, goal, minimum_cost, self.points.len());
        let path = self
            .search
            .poll(|i| self.points[i].as_ref().unwrap(), u64::MAX);
        self.last_expanded = self.search.expanded;
        path.unwrap()
            .into_iter()
            .map(|i| self.points[i].as_ref().unwrap().id)
            .collect()
    }
    pub(crate) fn query(
        &self,
        from: i64,
        to: i64,
        temporary: &[i64],
        spare: Option<RouteQuery>,
    ) -> RouteQuery {
        RouteQuery::new(self, from, to, temporary, spare)
    }
}
