use crate::vector::Vector3;
use std::cmp::Ordering;
use std::collections::{BinaryHeap, HashMap};

struct Point {
    id: i64,
    position: Vector3,
    weight: f64,
    edges: Vec<(usize, f64)>,
}

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

/// HPA's two-edge cost nodes need not become separate A* search states.
/// Keep their directional costs and include them when reconstructing the path.
#[derive(Default)]
pub struct RouteGraph {
    ids: HashMap<i64, usize>,
    points: Vec<Option<Point>>,
    free: Vec<usize>,
    costs: Vec<f64>,
    parents: Vec<(usize, Option<usize>)>,
    visited: Vec<u64>,
    generation: u64,
    open: BinaryHeap<Step>,
    minimum_weight: f64,
}

impl RouteGraph {
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
            self.visited[index] = 0;
            index
        } else {
            let index = self.points.len();
            self.points.push(point);
            self.costs.push(0.0);
            self.parents.push((index, None));
            self.visited.push(0);
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

    pub fn get_point_position(&self, id: i64) -> Vector3 {
        self.ids
            .get(&id)
            .and_then(|&i| self.points[i].as_ref())
            .map_or(Vector3::ZERO, |p| p.position)
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
        let (Some(&start), Some(&goal)) = (self.ids.get(&from), self.ids.get(&to)) else {
            return Vec::new();
        };
        self.generation = self.generation.wrapping_add(1);
        if self.generation == 0 {
            self.visited.fill(0);
            self.generation = 1;
        }
        let generation = self.generation;
        let destination = self.points[goal].as_ref().unwrap().position;
        self.open.clear();
        self.costs[start] = 0.0;
        self.visited[start] = generation;
        self.open.push(Step {
            index: start,
            cost: 0.0,
            estimate: 0.0,
        });
        while let Some(step) = self.open.pop() {
            if step.cost != self.costs[step.index] {
                continue;
            }
            if step.index == goal {
                let mut path = vec![to];
                let mut index = goal;
                while index != start {
                    let (parent, via) = self.parents[index];
                    if let Some(via) = via {
                        path.push(self.points[via].as_ref().unwrap().id);
                    }
                    path.push(self.points[parent].as_ref().unwrap().id);
                    index = parent;
                }
                path.reverse();
                return path;
            }
            for &(neighbour, distance) in &self.points[step.index].as_ref().unwrap().edges {
                let point = self.points[neighbour].as_ref().unwrap();
                let mut next = neighbour;
                let mut cost = step.cost + distance * point.weight;
                let mut via = None;
                if neighbour != goal && point.edges.len() == 2 {
                    let &(other, length) = point.edges.iter().find(|e| e.0 != step.index).unwrap();
                    next = other;
                    cost += length * self.points[other].as_ref().unwrap().weight;
                    via = Some(neighbour);
                }
                if self.visited[next] == generation && cost >= self.costs[next] {
                    continue;
                }
                self.visited[next] = generation;
                self.costs[next] = cost;
                self.parents[next] = (step.index, via);
                let estimate = cost
                    + self.points[next]
                        .as_ref()
                        .unwrap()
                        .position
                        .distance(destination) as f64
                        * self.minimum_weight;
                self.open.push(Step {
                    index: next,
                    cost,
                    estimate,
                });
            }
        }
        Vec::new()
    }
}
