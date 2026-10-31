//! Geometry leaves navigation immediately, but shields shots until the current tick ends.
use crate::actors::{Actor, Actors};
use crate::collision::{BoxShape, CollisionWorld};
use crate::cover::{rotation, transform};
use crate::navigation_scene::NavigationScene;
use crate::random::SimulationRandom;
use crate::spatial::{SpatialIndex, DOOR_CELL, STRUCTURE_CELL};
use crate::state_codec::{Reader, Writer};
use crate::structure::Structure;
use crate::structure_birth::BuildingProfile;
use crate::terrain::Terrain;
use crate::terrain_cover::{CoverPart, CoverStructure};
use crate::vector::{normalized, Vector3};
use crate::vehicle::Vehicle;
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

/// The renderer animates the flight; its final cover position is authoritative immediately.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Toss {
    pub origin: Vector3,
    pub yaw: f64,
    pub velocity: Vector3,
    pub spin: Vector3,
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

    pub fn refresh_vehicle_collision(
        &mut self,
        vehicle: &Vehicle,
        hull: Vector3,
    ) -> Result<(), &'static str> {
        if !vehicle.valid()
            || vehicle.gone
            || !hull.is_finite()
            || hull.min_element() <= 0.0
            || hull.max_element() > 4096.0
            || self.retired.contains(&vehicle.id)
        {
            return Err("invalid vehicle collision state");
        }
        if !self.collision.replace(
            i64::from(vehicle.id),
            &[BoxShape {
                body: i64::from(vehicle.id),
                shape: 0,
                center: vehicle.position + Vector3::Y * (hull.y * 0.5),
                basis: rotation(vehicle.yaw),
                half: hull * 0.5,
            }],
        ) {
            return Err("vehicle collision exceeds world limits");
        }
        Ok(())
    }

    pub fn toss_structure(
        &mut self,
        actors: &mut Actors,
        id: u32,
        blast: Vector3,
        size: f64,
        rng: &mut SimulationRandom,
    ) -> Result<Option<Toss>, &'static str> {
        if !blast.is_finite()
            || blast.abs().max_element() > 1_000_000.0
            || !size.is_finite()
            || !(0.0..=1000.0).contains(&size)
        {
            return Err("invalid structure toss");
        }
        let Some(st) = actors.structure(id) else {
            return Ok(None);
        };
        if st.gone || !matches!(st.kind.as_str(), "car" | "crates") {
            return Ok(None);
        }
        if self.retired.contains(&id)
            || st.hash_cells.is_empty()
            || self.navigation.planner.side() != self.terrain.n
        {
            return Err("invalid tossed structure geometry");
        }
        let mut away = st.position - blast;
        away.y = 0.0;
        let distance = f64::from(away.length());
        away = if distance > 0.1 {
            normalized(away)
        } else {
            let angle = f64::from(rng.randf()) * std::f64::consts::TAU;
            Vector3::new(-libm::sin(angle) as f32, 0.0, -libm::cos(angle) as f32)
        };
        let power = (size * (1.0 - distance / (4.0 + size * 3.0)) / 2.6).clamp(0.0, 1.0);
        if power < 0.15 {
            return Ok(None);
        }
        let light = st.kind == "crates";
        let up = 3.0 + ((if light { 9.0 } else { 7.0 }) - 3.0) * power;
        let out = 2.0 + ((if light { 7.0 } else { 5.0 }) - 2.0) * power;
        let air_time = 2.0 * up / 19.6;
        let destination = st.position + away * out as f32 * air_time as f32;
        let bound = self.terrain.n as f64 * 0.5 - 4.0;
        if f64::from(destination.x.abs()) >= bound
            || f64::from(destination.z.abs()) >= bound
            || self.navigation.planner.kind_at(destination, false) == 3
        {
            return Ok(None);
        }
        let mut moved = st.clone();
        let pitch = f64::from(rng.randf_range(-0.08, 0.08));
        let mut roll = f64::from(rng.randf_range(-0.08, 0.08));
        let r = f64::from(rng.randf());
        if r < 0.35 * power {
            roll = std::f64::consts::PI;
        } else if r < 0.7 * power {
            roll = std::f64::consts::PI * 0.5 * if rng.randf() < 0.5 { 1.0 } else { -1.0 };
        }
        let dyaw = f64::from(rng.randf_range(-1.3, 1.3)) * power;
        let origin = moved.position;
        let yaw = moved.yaw;
        self.navigation
            .remove_structure(&mut moved, &self.terrain, &self.deck)?;
        change_ground(&mut self.terrain, &moved, false, &[]);
        self.structures.remove(id);
        self.terrain.scene.remove(u64::from(id));
        moved.position = Vector3::new(destination.x, 0.0, destination.z);
        moved.yaw = yaw + dyaw;
        moved.tilt = [pitch as f32, roll as f32];
        self.structures.insert(id, moved.position, moved.radius)?;
        moved.hash_cells = self
            .structures
            .membership(id)
            .iter()
            .map(|&(x, z)| [x, z])
            .collect();
        self.sync_structure(&moved, true)?;
        self.navigation
            .add_structure(&mut moved, &self.terrain, &self.deck)?;
        change_ground(&mut self.terrain, &moved, true, &[]);
        moved.refresh_anchors(self.terrain.n as f64 * 0.5)?;
        self.refresh_structure_collision(&moved)?;
        *actors.get_mut(id).unwrap() = Actor::Structure(Box::new(moved));
        let axis = normalized(away.cross(Vector3::Y));
        let denominator = air_time.max(0.35) as f32;
        Ok(Some(Toss {
            origin,
            yaw,
            velocity: away * out as f32 + Vector3::Y * up as f32,
            spin: -axis * (roll.abs() + 1.0) as f32 / denominator
                + Vector3::Y * dyaw as f32 / denominator,
        }))
    }

    /// A spawned wreck's ignition is dispatched immediately afterwards, in the caller's fire order.
    pub fn spawn_structure(
        &mut self,
        actors: &mut Actors,
        mut st: Structure,
        profile: Option<BuildingProfile>,
    ) -> Result<u32, &'static str> {
        if actors.entities().len() >= crate::entities::MAX_ENTITIES {
            return Err("entity registry exhausted");
        }
        st.id =
            u32::try_from(actors.entities().next_id()).map_err(|_| "entity registry exhausted")?;
        st.initialize(profile, self.terrain.n as f64 * 0.5)?;
        self.register_structure(&mut st, actors)?;
        actors.spawn(Actor::Structure(Box::new(st)))
    }

    pub fn register_structure(
        &mut self,
        st: &mut Structure,
        actors: &Actors,
    ) -> Result<(), &'static str> {
        if !st.valid()
            || st.gone
            || !st.nav_cells.is_empty()
            || !st.hash_cells.is_empty()
            || self.navigation.planner.side() != self.terrain.n
            || !self.deck.is_empty() && self.deck.len() != self.terrain.n * self.terrain.n
            || self.structures.cell_size() != STRUCTURE_CELL
            || self.doors.cell_size() != DOOR_CELL
            || !self.structures.membership(st.id).is_empty()
            || !self.doors.membership(st.id).is_empty()
            || self.collision.contains(i64::from(st.id))
            || self.retired.contains(&st.id)
        {
            return Err("invalid new structure geometry");
        }
        st.collision_shapes()?;
        self.navigation
            .add_structure(st, &self.terrain, &self.deck)?;
        self.refresh_structure_collision(st)?;
        if st.door_closed {
            self.doors.insert_door(st.id, st.position)?;
        }
        self.structures.insert(st.id, st.position, st.radius)?;
        st.hash_cells = self
            .structures
            .membership(st.id)
            .iter()
            .map(|&(x, z)| [x, z])
            .collect();
        self.sync_structure(st, true)?;
        let nets = nearby_nets(st, actors, &self.structures, true)?;
        for i in change_ground(&mut self.terrain, st, true, &nets) {
            self.navigation
                .terrain_changed(i as usize, &self.terrain, &self.deck)?;
        }
        Ok(())
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
    pub fn retire_collision(&mut self, id: u32) -> Result<(), &'static str> {
        if id == 0 {
            return Err("invalid retired collision identity");
        }
        if self.collision.contains(i64::from(id)) && !self.retired.contains(&id) {
            if self.retired.len() >= 1_000_000 {
                return Err("retired collision limit exceeded");
            }
            self.retired.push(id);
        }
        Ok(())
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
    pub fn complete_structure(&mut self, id: u32, actors: &Actors) -> Result<(), &'static str> {
        let st = actors
            .structure(id)
            .filter(|st| st.built && !st.gone)
            .ok_or("missing completed structure")?;
        self.sync_structure(st, false)?;
        let nets = nearby_nets(st, actors, &self.structures, true)?;
        for i in change_ground(&mut self.terrain, st, true, &nets) {
            self.navigation
                .terrain_changed(i as usize, &self.terrain, &self.deck)?;
        }
        self.refresh_structure_collision(st)
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
