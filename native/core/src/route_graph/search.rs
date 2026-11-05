//! A frontier owns only search state and the few query anchors, never the shared graph.
use super::{Point, RouteGraph};
use crate::state_codec::{Reader, Writer};
use std::cmp::Ordering;
use std::collections::{BTreeMap, BinaryHeap};
#[derive(Clone, Copy, PartialEq)]
struct Step {
    index: usize,
    cost: f64,
    estimate: f64,
}
impl Eq for Step {}
impl Ord for Step {
    fn cmp(&self, other: &Self) -> Ordering {
        other
            .estimate
            .total_cmp(&self.estimate)
            .then_with(|| self.cost.total_cmp(&other.cost))
            .then_with(|| other.index.cmp(&self.index))
    }
}
impl PartialOrd for Step {
    fn partial_cmp(&self, other: &Self) -> Option<Ordering> {
        Some(self.cmp(other))
    }
}

#[derive(Default)]
pub(super) struct Search {
    pub costs: Vec<f64>,
    pub parents: Vec<(usize, Option<usize>)>,
    pub visited: Vec<u64>,
    generation: u64,
    open: BinaryHeap<Step>,
    start: usize,
    goal: usize,
    minimum_cost: f64,
    pub expanded: u64,
}
impl Search {
    pub fn begin(&mut self, start: usize, goal: usize, minimum_cost: f64, size: usize) {
        self.costs.resize(size, 0.);
        self.parents.resize(size, (0, None));
        self.visited.resize(size, 0);
        self.generation = self.generation.wrapping_add(1);
        if self.generation == 0 {
            self.visited.fill(0);
            self.generation = 1;
        }
        self.start = start;
        self.goal = goal;
        self.minimum_cost = minimum_cost;
        self.open.clear();
        self.costs[start] = 0.;
        self.parents[start] = (start, None);
        self.visited[start] = self.generation;
        self.open.push(Step {
            index: start,
            cost: 0.,
            estimate: 0.,
        });
    }
    pub fn poll<'a>(
        &mut self,
        point: impl Fn(usize) -> &'a Point,
        budget: u64,
    ) -> Option<Vec<usize>> {
        self.expanded = 0;
        let destination = point(self.goal).position;
        while !self.open.is_empty() {
            if self.expanded == budget {
                return None;
            }
            let step = self.open.pop().unwrap();
            if step.cost != self.costs[step.index] {
                continue;
            }
            self.expanded += 1;
            if step.index == self.goal {
                let mut path = vec![self.goal];
                let mut index = self.goal;
                while index != self.start {
                    let (parent, via) = self.parents[index];
                    if let Some(via) = via {
                        path.push(via);
                    }
                    path.push(parent);
                    index = parent;
                }
                path.reverse();
                return Some(path);
            }
            for &(neighbour, distance) in &point(step.index).edges {
                let p = point(neighbour);
                let mut next = neighbour;
                let mut cost = step.cost + distance * p.weight;
                let mut via = None;
                if neighbour != self.goal && p.edges.len() == 2 {
                    let &(other, length) = p.edges.iter().find(|e| e.0 != step.index).unwrap();
                    next = other;
                    cost += length * point(other).weight;
                    via = Some(neighbour);
                }
                if self.visited[next] == self.generation && cost >= self.costs[next] {
                    continue;
                }
                self.visited[next] = self.generation;
                self.costs[next] = cost;
                self.parents[next] = (step.index, via);
                let estimate =
                    cost + point(next).position.distance(destination) as f64 * self.minimum_cost;
                self.open.push(Step {
                    index: next,
                    cost,
                    estimate,
                });
            }
        }
        Some(vec![])
    }
}

pub(crate) struct RouteQuery {
    anchors: BTreeMap<usize, Point>,
    search: Search,
}
impl RouteQuery {
    pub(super) fn new(
        graph: &RouteGraph,
        from: i64,
        to: i64,
        temporary: &[i64],
        spare: Option<Self>,
    ) -> Self {
        let Self {
            mut anchors,
            mut search,
        } = spare.unwrap_or_else(|| Self {
            anchors: BTreeMap::new(),
            search: Search::default(),
        });
        anchors.clear();
        for id in temporary.iter().chain([&from, &to]) {
            let index = graph.ids[id];
            let p = graph.points[index].as_ref().unwrap();
            anchors.insert(index, p.clone());
            for &(i, _) in &p.edges {
                anchors.insert(i, graph.points[i].as_ref().unwrap().clone());
            }
        }
        search.begin(
            graph.ids[&from],
            graph.ids[&to],
            (1. + graph.minimum_weight) * 0.5,
            graph.points.len(),
        );
        Self { anchors, search }
    }
    pub fn poll(&mut self, graph: &RouteGraph, budget: u64) -> Option<Vec<i64>> {
        let point = |i| {
            self.anchors
                .get(&i)
                .or_else(|| graph.points.get(i).and_then(Option::as_ref))
                .unwrap()
        };
        self.search
            .poll(point, budget)
            .map(|path| path.into_iter().map(|i| point(i).id).collect())
    }
    pub fn endpoints(&self) -> [(i64, crate::vector::Vector3); 2] {
        [self.search.start, self.search.goal].map(|i| {
            let p = &self.anchors[&i];
            (p.id, p.position)
        })
    }
    pub fn expanded(&self) -> u64 {
        self.search.expanded
    }
    pub fn write(&self, w: &mut Writer) {
        w.u32(self.anchors.len() as u32);
        for (&i, p) in &self.anchors {
            w.u32(i as u32);
            w.u64(p.id as u64);
            w.point(p.position);
            w.f64(p.weight);
            w.u32(p.edges.len() as u32);
            for &(next, distance) in &p.edges {
                w.u32(next as u32);
                w.f64(distance);
            }
        }
        let s = &self.search;
        w.u32(s.start as u32);
        w.u32(s.goal as u32);
        w.f64(s.minimum_cost);
        w.u32(s.visited.iter().filter(|&&g| g == s.generation).count() as u32);
        for (i, &g) in s.visited.iter().enumerate() {
            if g != s.generation {
                continue;
            }
            w.u32(i as u32);
            w.f64(s.costs[i]);
            w.u32(s.parents[i].0 as u32);
            w.u32(s.parents[i].1.map_or(u32::MAX, |v| v as u32));
        }
        let open = s.open.clone().into_sorted_vec();
        w.u32(open.len() as u32);
        for p in open {
            w.u32(p.index as u32);
            w.f64(p.cost);
            w.f64(p.estimate);
        }
    }
    pub fn read(r: &mut Reader<'_>, graph: &RouteGraph) -> Result<Self, &'static str> {
        let count = r.u32()? as usize;
        if count == 0 || count > 16384 {
            return Err("invalid route query overlay");
        }
        let mut anchors = BTreeMap::new();
        let mut size = graph.points.len();
        let mut total_edges = 0;
        for _ in 0..count {
            let i = r.u32()? as usize;
            let id = r.u64()?;
            let position = r.point()?;
            let weight = r.f64()?;
            let n = r.u32()? as usize;
            total_edges += n;
            if i >= 1_000_000
                || id > i64::MAX as u64
                || weight < 0.
                || n > 16384
                || total_edges > 131072
            {
                return Err("invalid route query point");
            }
            size = size.max(i + 1);
            let mut edges = vec![];
            for _ in 0..n {
                let next = r.u32()? as usize;
                let distance = r.f64()?;
                if distance < 0. || next == i || edges.iter().any(|e: &(usize, f64)| e.0 == next) {
                    return Err("invalid route query edge");
                }
                edges.push((next, distance));
            }
            if anchors
                .insert(
                    i,
                    Point {
                        id: id as i64,
                        position,
                        weight,
                        edges,
                    },
                )
                .is_some()
            {
                return Err("duplicate route query point");
            }
        }
        let point = |i| {
            anchors
                .get(&i)
                .or_else(|| graph.points.get(i).and_then(Option::as_ref))
        };
        for (&i, p) in &anchors {
            if let Some(base) = graph.points.get(i).and_then(Option::as_ref) {
                if p.id != base.id
                    || p.position != base.position
                    || p.weight != base.weight
                    || !p.edges.starts_with(&base.edges)
                {
                    return Err("route query changed a shared point");
                }
            } else if graph.ids.contains_key(&p.id) {
                return Err("route query duplicated a shared ID");
            }
            for &(other, distance) in &p.edges {
                let q = point(other).ok_or("missing route query neighbor")?;
                if !q.edges.iter().any(|e| e.0 == i)
                    || distance != p.position.distance(q.position) as f64
                {
                    return Err("inconsistent route query edge");
                }
            }
        }
        let start = r.u32()? as usize;
        let goal = r.u32()? as usize;
        let minimum = r.f64()?;
        if !anchors.contains_key(&start) || !anchors.contains_key(&goal) || minimum < 0. {
            return Err("invalid route query endpoints");
        }
        let mut search = Search::default();
        search.begin(start, goal, minimum, size);
        search.visited.fill(0);
        search.open.clear();
        let n = r.u32()? as usize;
        if n > size {
            return Err("too many route query states");
        }
        for _ in 0..n {
            let i = r.u32()? as usize;
            let cost = r.f64()?;
            let parent = r.u32()? as usize;
            let via = r.u32()?;
            let via = (via != u32::MAX).then_some(via as usize);
            if point(i).is_none()
                || i >= size
                || search.visited[i] != 0
                || cost < 0.
                || point(parent).is_none()
                || via.is_some_and(|v| point(v).is_none())
            {
                return Err("invalid route query state");
            }
            search.visited[i] = 1;
            search.costs[i] = cost;
            search.parents[i] = (parent, via);
        }
        if search.visited[start] != 1
            || search.costs[start] != 0.
            || search.parents[start] != (start, None)
        {
            return Err("invalid route query root");
        }
        // Parent chains must reach the root, including zero-cost links.
        let mut done = vec![false; size];
        done[start] = true;
        let mut walking = vec![false; size];
        for i in 0..size {
            if search.visited[i] == 0 {
                continue;
            }
            let mut chain = vec![];
            let mut at = i;
            while !done[at] {
                if walking[at] || search.visited[at] == 0 {
                    return Err("cyclic route query parents");
                }
                walking[at] = true;
                chain.push(at);
                let (parent, via) = search.parents[at];
                let p = point(parent).ok_or("missing route query parent")?;
                let next = via.unwrap_or(at);
                if !p.edges.iter().any(|e| e.0 == next)
                    || via.is_some_and(|v| !point(v).unwrap().edges.iter().any(|e| e.0 == at))
                {
                    return Err("disconnected route query parent");
                }
                at = parent;
            }
            for j in chain {
                done[j] = true;
                walking[j] = false;
            }
        }
        let n = r.u32()? as usize;
        if n == 0 || n > 8_000_000 {
            return Err("invalid route query frontier size");
        }
        for _ in 0..n {
            let index = r.u32()? as usize;
            let cost = r.f64()?;
            let estimate = r.f64()?;
            if index >= size
                || search.visited[index] == 0
                || cost < search.costs[index]
                || estimate < cost
            {
                return Err("invalid route query frontier");
            }
            search.open.push(Step {
                index,
                cost,
                estimate,
            });
        }
        Ok(Self { anchors, search })
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::vector::Vector3;
    fn query() -> (RouteGraph, RouteQuery) {
        let mut graph = RouteGraph::new();
        for i in 0..9 {
            graph.add_point(i, Vector3::new((i % 3) as f32, 0., (i / 3) as f32), 1.);
        }
        for i in 0..9 {
            if i % 3 < 2 {
                graph.connect_points(i, i + 1);
            }
            if i < 6 {
                graph.connect_points(i, i + 3);
            }
        }
        graph.add_point(100, Vector3::new(-1., 0., 0.), 1.);
        graph.add_point(101, Vector3::new(3., 0., 2.), 1.);
        graph.connect_points(100, 0);
        graph.connect_points(101, 8);
        let mut q = graph.query(100, 101, &[], None);
        graph.remove_point(100);
        graph.remove_point(101);
        assert!(q.poll(&graph, 1).is_none());
        (graph, q)
    }
    #[test]
    fn corrupt_frontiers_and_parent_cycles_are_rejected() {
        for kind in 0..3 {
            let (graph, mut query) = query();
            match kind {
                0 => {
                    let i = query.search.open.peek().unwrap().index;
                    query.search.parents[i] = (i, None);
                }
                1 => query.search.open.push(Step {
                    index: usize::MAX,
                    cost: 1.,
                    estimate: 1.,
                }),
                _ => {
                    query.anchors.get_mut(&query.search.start).unwrap().edges[0].1 += 1.;
                }
            }
            let mut w = Writer::new(b"FLQT\x01\0\0\0");
            query.write(&mut w);
            let mut r = Reader::new(&w.0, b"FLQT\x01\0\0\0").unwrap();
            assert!(RouteQuery::read(&mut r, &graph).is_err());
        }
    }
}
