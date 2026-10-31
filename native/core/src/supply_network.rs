//! New supply routes clear obstacles in order; later routes see the cleared ground.
use crate::actors::{Actor, Actors};
use crate::entities::Kind;
use crate::state_codec::{Reader, Writer};
use crate::structure::Structure;
use crate::vector::{normalized, Vector3};
use crate::world_geometry::WorldGeometry;
use std::collections::HashSet;

const LIMIT: usize = 100_000;
const POINTS: usize = 1_000_000;
type Roads = Vec<Vec<Vector3>>;

#[derive(Clone, Debug, Default, PartialEq)]
pub struct SupplyNetwork {
    pub depots: [u32; 2],
    pub towns: Vec<u32>,
    pub completed: u32,
    pub roads: [Roads; 3],
    pub painted: [Roads; 3],
}
fn flat(p: Vector3) -> Vector3 {
    Vector3::new(p.x, 0.0, p.z)
}
fn fobs(actors: &Actors, team: i8, wrecked: bool) -> Vec<u32> {
    actors
        .iter_kind(Kind::Structure)
        .filter_map(|a| match a {
            Actor::Structure(st)
                if st.kind == "fob" && st.team == team && st.built && (wrecked || !st.wrecked) =>
            {
                Some(st.id)
            }
            _ => None,
        })
        .collect()
}
fn distance(p: Vector3, a: Vector3, b: Vector3) -> f64 {
    let ab = b - a;
    let l2 = f64::from(ab.length_squared());
    f64::from(p.distance(if l2 < 0.0001 {
        a
    } else {
        a + ab * (f64::from((p - a).dot(ab)) / l2).clamp(0.0, 1.0) as f32
    }))
}
fn structure_mut(actors: &mut Actors, id: u32) -> &mut Structure {
    let Some(Actor::Structure(st)) = actors.get_mut(id) else {
        unreachable!()
    };
    st
}
impl SupplyNetwork {
    pub fn valid(&self) -> bool {
        if self.towns.len() > LIMIT
            || self.towns.contains(&0)
            || self.towns.iter().copied().collect::<HashSet<_>>().len() != self.towns.len()
        {
            return false;
        }
        let mut points = 0;
        for group in self.roads.iter().chain(&self.painted) {
            if group.len() > LIMIT {
                return false;
            }
            for line in group {
                points += line.len();
                if points > POINTS
                    || line
                        .iter()
                        .any(|p| !p.is_finite() || p.abs().max_element() > 1_000_000.0)
                {
                    return false;
                }
            }
        }
        true
    }
    pub fn register_start(&mut self, id: u32, actors: &mut Actors) -> Result<(), &'static str> {
        if !actors
            .structure(id)
            .is_some_and(|st| st.kind == "fob" && !st.gone)
        {
            return Err("missing starting FOB");
        }
        let next = self
            .completed
            .checked_add(1)
            .ok_or("FOB completion order exhausted")?;
        structure_mut(actors, id).completed_order = next;
        self.completed = next;
        Ok(())
    }
    pub fn rebuild(
        &mut self,
        team: u8,
        actors: &mut Actors,
        geometry: &mut WorldGeometry,
    ) -> Result<Vec<u32>, &'static str> {
        if team > 1 || !self.valid() {
            return Err("invalid supply network");
        }
        let depot = self.depots[team as usize];
        if actors.structure(depot).is_none() {
            return Ok(vec![]);
        }
        let mut list = fobs(actors, team as i8, true);
        list.sort_by_key(|id| actors.structure(*id).unwrap().completed_order);
        let mut nodes = vec![depot];
        let mut lines = vec![];
        let mut removed = vec![];
        for id in list {
            let position = actors.structure(id).unwrap().position;
            let mut best = depot;
            let mut nearest = 1e9;
            for candidate in &nodes {
                let d = f64::from(
                    flat(actors.structure(*candidate).unwrap().position - position).length(),
                );
                if d < nearest {
                    nearest = d;
                    best = *candidate;
                }
            }
            let parent = actors.structure(best).unwrap();
            let start = parent.position
                + normalized(flat(position - parent.position)) * (parent.radius * 0.6) as f32;
            let path = geometry.navigation.planner.find_path(
                &mut geometry.navigation.vehicles,
                start,
                position,
                true,
                -1,
                0.0,
            );
            let mut line = vec![geometry
                .navigation
                .planner
                .nearest_walkable_for(start, true)
                .unwrap()];
            line.extend(path);
            let st = structure_mut(actors, id);
            st.supply_parent = best;
            st.road = line.clone();
            Self::bulldoze(&line, actors, geometry, &mut removed)?;
            lines.push(line);
            nodes.push(id);
        }
        for id in &self.towns {
            if actors
                .structure(*id)
                .is_some_and(|st| st.team == team as i8)
            {
                Self::town_road(*id, actors, geometry, &mut lines, &mut removed)?;
            }
        }
        self.roads[team as usize] = lines;
        self.paint(geometry)?;
        Ok(removed)
    }
    fn town_road(
        id: u32,
        actors: &mut Actors,
        geometry: &mut WorldGeometry,
        lines: &mut Roads,
        removed: &mut Vec<u32>,
    ) -> Result<(), &'static str> {
        let town = actors.structure(id).unwrap();
        let team = town.team;
        let position = town.position;
        let exit = town.exit();
        let mut best = 0;
        let mut nearest = 1e9;
        for candidate in fobs(actors, team, false) {
            let d =
                f64::from(flat(actors.structure(candidate).unwrap().position - position).length());
            if d < nearest {
                nearest = d;
                best = candidate;
            }
        }
        let st = structure_mut(actors, id);
        st.supply_parent = best;
        st.road.clear();
        if best == 0 {
            st.supply_status = "No FOB".into();
            return Ok(());
        }
        let start = geometry
            .navigation
            .planner
            .nearest_walkable_for(exit, true)
            .unwrap();
        let path = geometry.navigation.planner.find_path(
            &mut geometry.navigation.vehicles,
            start,
            actors.structure(best).unwrap().position,
            true,
            -1,
            0.0,
        );
        if path.is_empty() {
            structure_mut(actors, id).supply_status = "No road".into();
            return Ok(());
        }
        let mut line = vec![start];
        line.extend(path);
        structure_mut(actors, id).road = line.clone();
        Self::bulldoze(&line, actors, geometry, removed)?;
        lines.push(line);
        let st = structure_mut(actors, id);
        if matches!(st.supply_status.as_str(), "No FOB" | "No road") {
            st.supply_status = "OK".into();
        }
        Ok(())
    }
    fn bulldoze(
        line: &[Vector3],
        actors: &mut Actors,
        geometry: &mut WorldGeometry,
        removed: &mut Vec<u32>,
    ) -> Result<(), &'static str> {
        for pair in line.windows(2) {
            let (a, b) = (pair[0], pair[1]);
            for id in actors.structures_near(
                &geometry.structures,
                (a + b) * 0.5,
                f64::from(a.distance(b)) * 0.5 + 4.0,
                false,
            )? {
                let st = actors.structure(id).unwrap();
                if st.team >= 0 || !st.smashable || st.gone {
                    continue;
                }
                let footprint = glam::Vec2::from_array(st.footprint);
                if distance(flat(st.position), flat(a), flat(b))
                    < 2.6 + f64::from(footprint.length()) * 0.5
                {
                    let Some(Actor::Structure(mut st)) = actors.remove(id) else {
                        unreachable!()
                    };
                    st.gone = true;
                    geometry.retire_structure(&mut st, actors)?;
                    removed.push(id);
                }
            }
        }
        Ok(())
    }
    fn paint(&mut self, geometry: &mut WorldGeometry) -> Result<(), &'static str> {
        if !self.valid() {
            return Err("supply roads exceed limits");
        }
        for side in 0..3 {
            if self.roads[side] == self.painted[side] {
                continue;
            }
            let added: Roads = self.roads[side]
                .iter()
                .filter(|line| !self.painted[side].contains(line))
                .cloned()
                .collect();
            if !added.is_empty() {
                let keep = geometry.terrain.fresh && !geometry.navigation.infantry.built;
                let changed =
                    geometry
                        .terrain
                        .paint_roads(&added, if side == 2 { 2.4 } else { 1.8 }, keep);
                for index in changed {
                    geometry.navigation.terrain_changed(
                        index as usize,
                        &geometry.terrain,
                        &geometry.deck,
                    )?;
                }
            }
            self.painted[side] = self.roads[side].clone();
        }
        Ok(())
    }
    pub fn route_to(&self, actors: &Actors, id: u32) -> Vec<Vector3> {
        let mut chain = vec![];
        let mut current = actors.structure(id);
        while let Some(st) = current.filter(|s| s.kind == "fob" && chain.len() < 24) {
            chain.push(st);
            current = actors.structure(st.supply_parent);
        }
        if !current.is_some_and(|st| st.kind == "depot") {
            return vec![];
        }
        chain
            .into_iter()
            .rev()
            .flat_map(|st| st.road.iter().copied())
            .collect()
    }
    pub fn checkpoint(&self) -> Result<Vec<u8>, &'static str> {
        if !self.valid() {
            return Err("invalid supply network checkpoint");
        }
        let mut w = Writer::new(b"FLSN\x01\0\0\0");
        for id in self.depots {
            w.u32(id);
        }
        w.u32(self.completed);
        w.u32(self.towns.len() as u32);
        for id in &self.towns {
            w.u32(*id);
        }
        for group in self.roads.iter().chain(&self.painted) {
            w.u32(group.len() as u32);
            for line in group {
                w.u32(line.len() as u32);
                for p in line {
                    w.point(*p);
                }
            }
        }
        Ok(w.0)
    }
    pub fn restore(bytes: &[u8]) -> Result<Self, &'static str> {
        let mut r = Reader::new(bytes, b"FLSN\x01\0\0\0")?;
        let mut state = Self {
            depots: [r.u32()?, r.u32()?],
            completed: r.u32()?,
            ..Default::default()
        };
        let count = r.u32()? as usize;
        if count > LIMIT {
            return Err("too many supply towns");
        }
        for _ in 0..count {
            state.towns.push(r.u32()?);
        }
        let mut remaining = POINTS;
        for group in state.roads.iter_mut().chain(&mut state.painted) {
            let count = r.u32()? as usize;
            if count > LIMIT {
                return Err("too many supply roads");
            }
            for _ in 0..count {
                let count = r.u32()? as usize;
                if count > remaining {
                    return Err("too many supply road points");
                }
                remaining -= count;
                let mut line = vec![];
                for _ in 0..count {
                    line.push(r.point()?);
                }
                group.push(line);
            }
        }
        r.finish()?;
        if !state.valid() {
            return Err("invalid restored supply network");
        }
        Ok(state)
    }
}
