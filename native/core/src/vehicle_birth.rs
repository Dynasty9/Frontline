//! Vehicle birth initializes gameplay and collision without constructing a renderer.
use crate::actors::{Actor, Actors};
use crate::vector::Vector3;
use crate::vehicle::Vehicle;
use crate::world_geometry::WorldGeometry;
#[derive(Clone, Copy)]
pub struct Definition<'a> {
    pub kind: &'a str,
    pub base: &'a str,
    pub hp: f64,
    pub hull: Vector3,
    pub missiles: [i32; 2],
}
#[derive(Clone, Copy)]
pub struct Spawn {
    pub team: i8,
    pub owner: i32,
    pub position: Vector3,
    pub yaw: f64,
}
impl Definition<'_> {
    pub fn valid(self) -> bool {
        !self.kind.is_empty()
            && self.kind.len() <= 128
            && !self.kind.contains('\0')
            && !self.base.is_empty()
            && self.base.len() <= 128
            && !self.base.contains('\0')
            && self.hp.is_finite()
            && (0.0..=1_000_000.0).contains(&self.hp)
            && self.hull.is_finite()
            && self.hull.min_element() > 0.0
            && self.hull.max_element() <= 4096.0
            && self
                .missiles
                .into_iter()
                .all(|n| (0..=1_000_000).contains(&n))
    }
}
impl Vehicle {
    pub fn from_spawn(
        id: u32,
        spawn: Spawn,
        profile: Definition<'_>,
    ) -> Result<Self, &'static str> {
        if !profile.valid() || !spawn.yaw.is_finite() || spawn.yaw.abs() > 1e12 {
            return Err("invalid vehicle birth");
        }
        let v =
            Self {
                id,
                kind: profile.kind.into(),
                team: spawn.team,
                owner: spawn.owner,
                position: spawn.position,
                yaw: f64::from(spawn.yaw as f32),
                hp: profile.hp,
                max_hp: profile.hp,
                atgm_left: profile.missiles[0],
                sam_left: profile.missiles[1],
                flight: matches!(profile.base, "attack_heli" | "lift_heli").then_some([0.; 3]),
                uav_destination: matches!(profile.base, "lift_heli" | "uav")
                    .then_some(Vector3::new(spawn.position.x, 0., spawn.position.z)),
                ..Default::default()
            };
        if !v.valid() {
            return Err("invalid vehicle birth");
        }
        Ok(v)
    }
}
impl WorldGeometry {
    pub fn spawn_vehicle(
        &mut self,
        actors: &mut Actors,
        spawn: Spawn,
        profile: Definition<'_>,
    ) -> Result<u32, &'static str> {
        if actors.entities().len() >= crate::entities::MAX_ENTITIES {
            return Err("entity registry exhausted");
        }
        let id =
            u32::try_from(actors.entities().next_id()).map_err(|_| "entity registry exhausted")?;
        let v = Vehicle::from_spawn(id, spawn, profile)?;
        if self.collision.contains(i64::from(id)) {
            return Err("vehicle identity already has collision");
        }
        self.refresh_vehicle_collision(&v, profile.hull)?;
        actors.spawn(Actor::Vehicle(Box::new(v)))
    }
}
