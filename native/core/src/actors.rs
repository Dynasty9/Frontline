//! Owned actors share stable identities. Lookup order never determines simulation order.
use crate::drone_actor::Drone;
use crate::entities::{Entities, Identity, Kind, MAX_ENTITIES};
use crate::infantry::Infantry;
use crate::infantry_casualty::Released;
use crate::infantry_vitals::Life;
use crate::projectile_actor::{Explosion, Projectile};
use crate::random::SimulationRandom;
use crate::state_codec::{Reader, Writer};
use crate::vector::Vector3;
use std::collections::HashMap;

#[derive(Clone, Debug, PartialEq)]
pub enum Actor {
    Soldier(Box<Infantry>),
    Projectile(Projectile),
    Drone(Drone),
}

impl Actor {
    pub fn identity(&self) -> Identity {
        match self {
            Self::Soldier(s) => Identity {
                id: s.identity.id,
                kind: Kind::Soldier,
            },
            Self::Projectile(p) => Identity {
                id: p.id,
                kind: Kind::Projectile,
            },
            Self::Drone(d) => Identity {
                id: d.id,
                kind: Kind::Drone,
            },
        }
    }
    fn set_id(&mut self, id: u32) {
        match self {
            Self::Soldier(s) => s.identity.id = id,
            Self::Projectile(p) => p.id = id,
            Self::Drone(d) => d.id = id,
        }
    }
    fn valid(&self) -> bool {
        match self {
            Self::Soldier(s) => !s.identity.gone && s.valid(),
            Self::Projectile(p) => p.valid(),
            Self::Drone(d) => d.valid(),
        }
    }
    pub fn checkpoint(&self) -> Result<Vec<u8>, &'static str> {
        match self {
            Self::Soldier(s) => s.checkpoint(),
            Self::Projectile(p) => p.checkpoint(),
            Self::Drone(d) => d.checkpoint(),
        }
    }
    pub fn restore(kind: Kind, bytes: &[u8]) -> Result<Self, &'static str> {
        match kind {
            Kind::Soldier => Ok(Self::Soldier(Box::new(Infantry::restore(bytes)?))),
            Kind::Projectile => Ok(Self::Projectile(Projectile::restore(bytes)?)),
            Kind::Drone => Ok(Self::Drone(Drone::restore(bytes)?)),
            _ => Err("actor kind has not migrated"),
        }
    }
}

#[derive(Clone, Debug, Default)]
pub struct Actors {
    entities: Entities,
    values: HashMap<u32, Actor>,
}

impl Actors {
    pub fn from_entries(next_id: u64, actors: Vec<Actor>) -> Result<Self, &'static str> {
        if actors.len() > MAX_ENTITIES || actors.iter().any(|a| !a.valid()) {
            return Err("invalid actor collection");
        }
        let identities: Vec<_> = actors.iter().map(Actor::identity).collect();
        let entities = Entities::from_entries(next_id, &identities)?;
        Ok(Self {
            entities,
            values: actors.into_iter().map(|a| (a.identity().id, a)).collect(),
        })
    }
    pub fn entities(&self) -> &Entities {
        &self.entities
    }
    pub fn get(&self, id: u32) -> Option<&Actor> {
        self.values.get(&id)
    }
    pub fn soldier(&self, id: u32) -> Option<&Infantry> {
        match self.get(id)? {
            Actor::Soldier(s) => Some(s),
            _ => None,
        }
    }
    pub(crate) fn soldier_mut(&mut self, id: u32) -> Option<&mut Infantry> {
        match self.values.get_mut(&id)? {
            Actor::Soldier(s) => Some(s),
            _ => None,
        }
    }
    pub fn iter(&self) -> impl Iterator<Item = &Actor> {
        self.entities.iter().map(|entry| &self.values[&entry.id])
    }
    pub fn spawn(&mut self, mut actor: Actor) -> Result<u32, &'static str> {
        let id = u32::try_from(self.entities.next_id()).map_err(|_| "entity registry exhausted")?;
        actor.set_id(id);
        if !actor.valid() {
            return Err("invalid actor spawn");
        }
        let id = self.entities.spawn(actor.identity().kind)?;
        self.values.insert(id, actor);
        Ok(id)
    }
    pub fn remove(&mut self, id: u32) -> Option<Actor> {
        if !self.entities.remove(id) {
            return None;
        }
        self.values.remove(&id)
    }

    pub fn release_all(&mut self, id: u32) -> Result<Released, &'static str> {
        let released = self
            .soldier_mut(id)
            .ok_or("missing infantry")?
            .release_all()?;
        self.release_links(id, released);
        Ok(released)
    }
    pub fn go_down(&mut self, id: u32, now: f64) -> Result<Released, &'static str> {
        let released = self
            .soldier_mut(id)
            .ok_or("missing infantry")?
            .go_down(now)?;
        self.release_links(id, released);
        Ok(released)
    }
    pub fn die(
        &mut self,
        id: u32,
        now: f64,
        ammunition: Option<i32>,
    ) -> Result<Option<Released>, &'static str> {
        let released = self
            .soldier_mut(id)
            .ok_or("missing infantry")?
            .die(now, ammunition)?;
        if let Some(released) = released {
            self.release_links(id, released);
        }
        Ok(released)
    }
    pub fn fling_from(
        &mut self,
        id: u32,
        center: Vector3,
        power: f64,
        rng: &mut SimulationRandom,
    ) -> Result<Option<Released>, &'static str> {
        let released = self
            .soldier_mut(id)
            .ok_or("missing infantry")?
            .fling_from(center, power, rng)?;
        if let Some(released) = released {
            self.release_links(id, released);
        }
        Ok(released)
    }
    pub(crate) fn release_links(&mut self, id: u32, released: Released) {
        if let Some(patient) = self.soldier_mut(released.patient) {
            if patient.links.dragged_by == u64::from(id) {
                patient.links.dragged_by = 0;
            }
            if patient.links.rescue_claimed == u64::from(id) {
                patient.links.rescue_claimed = 0;
            }
        }
        if let Some(patient) = self.soldier_mut(released.stretcher) {
            if let Some(index) = patient
                .links
                .carried_by
                .iter()
                .position(|&s| s == u64::from(id))
            {
                patient.links.carried_by.remove(index);
            }
        }
        if let Some(Actor::Drone(drone)) = self.values.get_mut(&released.drone) {
            drone.lose_control();
        }
        // Squad breach claims are applied by the squad owner, using the returned squad ID.
    }

    pub fn step_drone(
        &mut self,
        id: u32,
        dt: f64,
        collision: &mut crate::collision::CollisionWorld,
        map_half: f32,
    ) -> Result<Option<Explosion>, &'static str> {
        let Some(Actor::Drone(drone)) = self.get(id) else {
            return Err("missing drone");
        };
        let alive = self
            .soldier(drone.operator)
            .is_some_and(|s| s.vitals.life == Life::Alive);
        let target = self
            .soldier(drone.target)
            .filter(|s| s.vitals.life == Life::Alive)
            .map(|s| crate::infantry_pose::center(s.motion.position, s.posture, s.vitals.life));
        let Some(Actor::Drone(drone)) = self.values.get_mut(&id) else {
            unreachable!()
        };
        drone.advance(dt, alive, target, collision, map_half)
    }

    pub fn detonate_drone(&mut self, id: u32) -> Result<Option<Explosion>, &'static str> {
        let Some(Actor::Drone(drone)) = self.values.get_mut(&id) else {
            return Err("missing drone");
        };
        Ok(drone.detonate())
    }
    pub fn shoot_drone(&mut self, id: u32) -> Result<bool, &'static str> {
        let Some(Actor::Drone(drone)) = self.values.get_mut(&id) else {
            return Err("missing drone");
        };
        Ok(drone.shot_down())
    }

    pub fn checkpoint(&self) -> Result<Vec<u8>, &'static str> {
        let mut out = Writer::new(b"FLAS\x01\0\0\0");
        out.bytes(&self.entities.checkpoint());
        for actor in self.iter() {
            let bytes = actor.checkpoint()?;
            if bytes.len() > 16 * 1024 * 1024 || out.0.len() + 4 + bytes.len() > 256 * 1024 * 1024 {
                return Err("actor collection exceeds limit");
            }
            out.bytes(&bytes);
        }
        Ok(out.0)
    }
    pub fn restore(bytes: &[u8]) -> Result<Self, &'static str> {
        // A single actor may contain a million route points. Bound the aggregate before allocating.
        if bytes.len() > 256 * 1024 * 1024 {
            return Err("actor collection exceeds limit");
        }
        let mut input = Reader::new(bytes, b"FLAS\x01\0\0\0")?;
        let entities = Entities::restore(input.bytes(20 + MAX_ENTITIES * 5)?)?;
        let mut values = HashMap::new();
        for identity in entities.iter() {
            let actor = Actor::restore(identity.kind, input.bytes(16 * 1024 * 1024)?)?;
            if actor.identity() != identity || !actor.valid() {
                return Err("actor identity mismatch");
            }
            values.insert(identity.id, actor);
        }
        input.finish()?;
        Ok(Self { entities, values })
    }
}
