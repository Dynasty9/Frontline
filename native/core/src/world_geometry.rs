//! Geometry leaves navigation immediately, but shields shots until the current tick ends.
use crate::actors::Actors;
use crate::collision::CollisionWorld;
use crate::cover::{rotation, transform};
use crate::navigation_scene::NavigationScene;
use crate::spatial::{SpatialIndex, DOOR_CELL, STRUCTURE_CELL};
use crate::state_codec::{Reader, Writer};
use crate::structure::Structure;
use crate::terrain::Terrain;
use crate::terrain_cover::{CoverPart, CoverStructure};
use crate::vector::Vector3;
use glam::Vec2;
use std::collections::HashSet;

pub struct WorldGeometry {
    pub terrain: Terrain,
    pub navigation: NavigationScene,
    pub collision: CollisionWorld,
    pub structures: SpatialIndex,
    pub doors: SpatialIndex,
    pub deck: Vec<u8>,
    retired: Vec<u32>,
}

impl WorldGeometry {
    pub fn new(terrain: Terrain, deck: Vec<u8>, cluster: usize) -> Result<Self, &'static str> {
        let navigation = NavigationScene::new(&terrain, &deck, cluster)?;
        Ok(Self {
            terrain,
            navigation,
            collision: CollisionWorld::default(),
            structures: SpatialIndex::new(STRUCTURE_CELL)?,
            doors: SpatialIndex::new(DOOR_CELL)?,
            deck,
            retired: vec![],
        })
    }
    pub fn pending_removals(&self) -> &[u32] {
        &self.retired
    }

    /// The actor has already been removed; its old cells are needed until all geometry is retired.
    pub fn retire_structure(
        &mut self,
        st: &mut Structure,
        actors: &Actors,
    ) -> Result<(), &'static str> {
        if !st.valid()
            || !st.gone
            || actors.get(st.id).is_some()
            || self.navigation.planner.side() != self.terrain.n
            || !self.deck.is_empty() && self.deck.len() != self.terrain.n * self.terrain.n
            || st
                .nav_cells
                .iter()
                .any(|&i| i as usize >= self.terrain.n * self.terrain.n)
            || self.structures.cell_size() != STRUCTURE_CELL
            || self.doors.cell_size() != DOOR_CELL
            || self.retired.len() >= 1_000_000
        {
            return Err("invalid retired structure geometry");
        }
        let nets = nearby_nets(st, actors, &self.structures, false)?;
        if self.collision.contains(i64::from(st.id)) && !self.retired.contains(&st.id) {
            self.retired.push(st.id);
        }
        self.structures.remove(st.id);
        self.terrain.scene.remove(u64::from(st.id));
        let changed = change_ground(&mut self.terrain, st, false, &nets);
        st.hash_cells.clear();
        for i in changed {
            self.navigation
                .terrain_changed(i as usize, &self.terrain, &self.deck)?;
        }
        self.navigation
            .remove_structure(st, &self.terrain, &self.deck)?;
        if st.door_closed {
            self.doors.remove(st.id);
        }
        Ok(())
    }
    pub fn finish_tick(&mut self) {
        for id in self.retired.drain(..) {
            self.collision.remove(i64::from(id));
        }
    }
    pub fn sync_structure(&mut self, st: &Structure, reindex: bool) -> Result<(), &'static str> {
        if !st.valid() || st.parts.iter().any(|p| p.size.min_element() < 0.0) {
            return Err("invalid structure geometry");
        }
        if st.hash_cells.is_empty() {
            return Ok(());
        }
        if st.gone {
            self.terrain.scene.remove(u64::from(st.id));
            return Ok(());
        }
        let shape = st.cover_geometry();
        let accepted = if reindex {
            self.terrain.scene.register(
                u64::from(st.id),
                shape,
                st.hash_cells.iter().map(|p| (p[0], p[1])).collect(),
            )
        } else {
            self.terrain.scene.update(u64::from(st.id), shape)
        };
        if accepted {
            Ok(())
        } else {
            Err("invalid registered structure geometry")
        }
    }
    pub fn tick_cover(&mut self, budget: usize) -> Result<Vec<u32>, &'static str> {
        let cells = self.terrain.tick_cover(budget);
        for &i in &cells {
            self.navigation
                .terrain_changed(i as usize, &self.terrain, &self.deck)?;
        }
        Ok(cells)
    }
    pub fn checkpoint(&self) -> Vec<u8> {
        let mut w = Writer::new(b"FLWG\x01\0\0\0");
        for bytes in [
            self.terrain.checkpoint(),
            self.navigation.checkpoint(),
            self.collision.checkpoint(),
            self.structures.checkpoint(),
            self.doors.checkpoint(),
        ] {
            w.bytes(&bytes);
        }
        w.bytes(&self.deck);
        w.u32(self.retired.len() as u32);
        for &id in &self.retired {
            w.u32(id);
        }
        w.0
    }
    pub fn restore(bytes: &[u8]) -> Result<Self, &'static str> {
        let mut r = Reader::new(bytes, b"FLWG\x01\0\0\0")?;
        let terrain = Terrain::restore(r.bytes(512 * 1024 * 1024)?)?;
        let navigation = NavigationScene::restore(r.bytes(512 * 1024 * 1024)?)?;
        let collision = CollisionWorld::restore(r.bytes(512 * 1024 * 1024)?)?;
        let structures = SpatialIndex::restore(r.bytes(512 * 1024 * 1024)?)?;
        let doors = SpatialIndex::restore(r.bytes(512 * 1024 * 1024)?)?;
        let deck = r.bytes(terrain.n * terrain.n)?.to_vec();
        let count = r.u32()? as usize;
        if navigation.planner.side() != terrain.n
            || !deck.is_empty() && deck.len() != terrain.n * terrain.n
            || structures.cell_size() != STRUCTURE_CELL
            || doors.cell_size() != DOOR_CELL
            || count > 1_000_000
        {
            return Err("invalid world geometry dimensions");
        }
        let mut retired = vec![];
        let mut seen = HashSet::new();
        for _ in 0..count {
            let id = r.u32()?;
            if id == 0 || !collision.contains(i64::from(id)) || !seen.insert(id) {
                return Err("invalid pending collision removal");
            }
            retired.push(id);
        }
        r.finish()?;
        Ok(Self {
            terrain,
            navigation,
            collision,
            structures,
            doors,
            deck,
            retired,
        })
    }
}

fn nearby_nets<'a>(
    st: &'a Structure,
    actors: &'a Actors,
    index: &SpatialIndex,
    added: bool,
) -> Result<Vec<&'a Structure>, &'static str> {
    let mut nets = vec![];
    if st.kind != "camo_net" {
        return Ok(nets);
    }
    for id in actors.structures_near(index, st.position, st.radius + 8.5, false)? {
        let other = actors.structure(id).unwrap();
        if other.kind == "camo_net" && other.built && !other.gone && (id != st.id || added) {
            nets.push(other);
        }
    }
    if added && st.built && !nets.iter().any(|n| n.id == st.id) {
        nets.push(st);
    }
    Ok(nets)
}

fn extent(half: Vec2, yaw: f64) -> Vec2 {
    let c = libm::cos(yaw).abs();
    let s = libm::sin(yaw).abs();
    Vec2::new(
        (c * f64::from(half.x) + s * f64::from(half.y)) as f32,
        (s * f64::from(half.x) + c * f64::from(half.y)) as f32,
    )
}

/// Cover changes are queued in cell order; tree ground and camouflage masks change immediately.
fn change_ground(
    terrain: &mut Terrain,
    st: &Structure,
    added: bool,
    nets: &[&Structure],
) -> Vec<u32> {
    if st.kind == "tree" {
        return terrain.tree(st.position, if added { 1 } else { -1 });
    }
    if st.kind == "camo_net" {
        let footprints: Vec<_> = nets
            .iter()
            .map(|n| {
                [
                    Vec2::new(n.position.x, n.position.z),
                    Vec2::from_array(n.footprint) - Vec2::splat(0.3),
                    Vec2::new(libm::cos(n.yaw) as f32, -libm::sin(n.yaw) as f32),
                    Vec2::new(libm::sin(n.yaw) as f32, libm::cos(n.yaw) as f32),
                ]
            })
            .collect();
        terrain.nets(st.position, st.radius + 0.5, &footprints);
        return vec![];
    }
    if matches!(
        st.kind.as_str(),
        "floor" | "wire" | "mines" | "tank_trap" | "tunnel" | "helipad"
    ) {
        return vec![];
    }
    let c = Vec2::new(st.position.x, st.position.z);
    let h = extent(Vec2::from_array(st.footprint), st.yaw);
    let mut lo = c - h;
    let mut size = h * 2.0;
    let basis = rotation(st.yaw);
    for part in st.parts.iter().filter(|p| p.cover) {
        let p = st.position + transform(basis, part.position);
        let c = Vec2::new(p.x, p.z);
        let h = extent(Vec2::new(part.size.x, part.size.z) * 0.5, st.yaw + part.yaw);
        // Rect2.merge computes ends from stored positions and sizes, with float rounding at each step.
        let other_lo = c - h;
        let other_size = h * 2.0;
        let end = (lo + size).max(other_lo + other_size);
        lo = lo.min(other_lo);
        size = end - lo;
    }
    // Rect2.grow accepts real_t, while its scalar compound assignments round after subtraction/addition.
    let amount = f64::from(2.1_f32);
    lo = Vec2::new(
        (f64::from(lo.x) - amount) as f32,
        (f64::from(lo.y) - amount) as f32,
    );
    size = Vec2::new(
        (f64::from(size.x) + amount * 2.0) as f32,
        (f64::from(size.y) + amount * 2.0) as f32,
    );
    let end = lo + size;
    terrain.queue_rect([
        f64::from(lo.x),
        f64::from(lo.y),
        f64::from(end.x),
        f64::from(end.y),
    ]);
    vec![]
}

impl Structure {
    pub fn cover_geometry(&self) -> CoverStructure {
        let none = !self.built
            || matches!(
                self.kind.as_str(),
                "floor"
                    | "wire"
                    | "mines"
                    | "tank_trap"
                    | "tunnel"
                    | "helipad"
                    | "tree"
                    | "camo_net"
            );
        let kind = if none {
            0
        } else if self.kind == "trench" {
            2
        } else if self.kind == "bunker" {
            3
        } else {
            1
        };
        let rubble = self.kind == "rubble";
        let heavy = matches!(
            self.kind.as_str(),
            "tall_wall"
                | "house_wall"
                | "concrete_wall"
                | "sandbags"
                | "hesco"
                | "barricade"
                | "mg_nest"
                | "hmg_nest"
                | "mortar_pit"
                | "at_post"
                | "bunker"
                | "wreck"
                | "fob"
                | "barracks"
                | "factory"
                | "research"
                | "depot"
                | "medic_tent"
        );
        let basis = rotation(self.yaw);
        let mut parts = vec![];
        if kind != 0 {
            for part in &self.parts {
                let top = f64::from(part.position.y) + f64::from(part.size.y) * 0.5;
                if !part.cover || top < 0.55 {
                    continue;
                }
                let yaw = self.yaw + part.yaw;
                parts.push(CoverPart {
                    center: self.position + transform(basis, part.position),
                    cosine: libm::cos(yaw),
                    sine: libm::sin(yaw),
                    half_x: f64::from(part.size.x) * 0.5,
                    half_z: f64::from(part.size.z) * 0.5,
                    level: if rubble {
                        1
                    } else if top >= 1.35 || heavy {
                        2
                    } else {
                        1
                    },
                });
            }
        }
        let trench = if self.kind == "trench" {
            let d = transform(basis, Vector3::new(self.size.x * 0.5, 0.0, 0.0));
            [self.position - d, self.position + d]
        } else {
            [Vector3::ZERO; 2]
        };
        let foot = Vec2::from_array(self.footprint);
        CoverStructure {
            position: self.position,
            radius: self.radius,
            kind,
            rubble,
            dug: self.kind == "trench" && self.built,
            parts,
            footprint: [
                Vec2::new(self.position.x, self.position.z),
                foot + Vec2::splat(0.4),
                foot,
                Vec2::new(libm::cos(self.yaw) as f32, -libm::sin(self.yaw) as f32),
                Vec2::new(libm::sin(self.yaw) as f32, libm::cos(self.yaw) as f32),
            ],
            trench,
        }
    }
}
