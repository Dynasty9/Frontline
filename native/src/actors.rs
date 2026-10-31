use frontline_core::actors::{Actor, Actors};
use frontline_core::drone::DroneFlight;
use frontline_core::drone_actor::Drone;
use frontline_core::entities::Kind;
use frontline_core::infantry_casualty::Released;
use frontline_core::projectile_actor::{Event, Explosion};
use godot::prelude::*;

#[derive(GodotClass)]
#[class(base=RefCounted, init)]
struct ActorStateCore {
    base: Base<RefCounted>,
    core: Actors,
}
fn released(r: Released) -> PackedInt64Array {
    [r.patient, r.stretcher, r.squad, r.drone]
        .map(i64::from)
        .as_slice()
        .into()
}
fn impact(r: Result<Option<Explosion>, &'static str>) -> Array<Variant> {
    match r {
        Ok(e) => varray![&crate::projectile_actor::events(
            e.into_iter().map(Event::Explosion).collect()
        )],
        Err(_) => Array::new(),
    }
}
fn vector(p: frontline_core::vector::Vector3) -> Vector3 {
    Vector3::new(p.x, p.y, p.z)
}

#[godot_api]
impl ActorStateCore {
    #[func]
    fn load_state(&mut self, next_id: i64, kinds: PackedByteArray, blocks: Array<Variant>) -> bool {
        if kinds.len() != blocks.len() || blocks.len() > frontline_core::entities::MAX_ENTITIES {
            return false;
        }
        let mut actors = Vec::with_capacity(blocks.len());
        let mut size = 0usize;
        for (index, kind) in kinds.as_slice().iter().enumerate() {
            let Ok(kind) = Kind::try_from(*kind) else {
                return false;
            };
            let Some(bytes) = blocks
                .get(index)
                .and_then(|v| v.try_to::<PackedByteArray>().ok())
            else {
                return false;
            };
            size += bytes.len();
            if bytes.len() > 16 * 1024 * 1024 || size > 256 * 1024 * 1024 {
                return false;
            }
            let Ok(actor) = Actor::restore(kind, bytes.as_slice()) else {
                return false;
            };
            actors.push(actor);
        }
        let Ok(next_id) = u64::try_from(next_id) else {
            return false;
        };
        let Ok(core) = Actors::from_entries(next_id, actors) else {
            return false;
        };
        self.core = core;
        true
    }
    #[func]
    fn actor_state(&self, id: u32) -> PackedByteArray {
        self.core
            .get(id)
            .and_then(|a| a.checkpoint().ok())
            .map_or_else(PackedByteArray::new, |b| b.as_slice().into())
    }
    #[func]
    fn identities(&self) -> PackedInt64Array {
        self.core
            .entities()
            .iter()
            .flat_map(|i| [i64::from(i.id), i.kind as i64])
            .collect()
    }
    #[func]
    fn next_id(&self) -> i64 {
        self.core.entities().next_id() as i64
    }
    #[func]
    fn spawn(&mut self, kind: u8, bytes: PackedByteArray) -> u32 {
        Kind::try_from(kind)
            .and_then(|k| Actor::restore(k, bytes.as_slice()))
            .and_then(|a| self.core.spawn(a))
            .unwrap_or(0)
    }
    #[func]
    fn remove(&mut self, id: u32) -> bool {
        self.core.remove(id).is_some()
    }
    #[func]
    fn checkpoint(&self) -> PackedByteArray {
        self.core
            .checkpoint()
            .map_or_else(|_| PackedByteArray::new(), |b| b.as_slice().into())
    }
    #[func]
    fn restore(&mut self, bytes: PackedByteArray) -> bool {
        let Ok(core) = Actors::restore(bytes.as_slice()) else {
            return false;
        };
        self.core = core;
        true
    }
    #[func]
    fn release_all(&mut self, id: u32) -> PackedInt64Array {
        self.core
            .release_all(id)
            .map_or_else(|_| PackedInt64Array::new(), released)
    }
    #[func]
    fn go_down(&mut self, id: u32, now: f64) -> PackedInt64Array {
        self.core
            .go_down(id, now)
            .map_or_else(|_| PackedInt64Array::new(), released)
    }
    #[func]
    fn die(&mut self, id: u32, now: f64, ammunition: i32) -> Array<Variant> {
        match self
            .core
            .die(id, now, (ammunition >= 0).then_some(ammunition))
        {
            Ok(r) => varray![r.is_some(), &released(r.unwrap_or_default())],
            Err(_) => Array::new(),
        }
    }
    #[func]
    fn fling_from(
        &mut self,
        id: u32,
        center: Vector3,
        power: f64,
        mut rng: Gd<crate::simulation_random::SimulationRandomCore>,
    ) -> Array<Variant> {
        match self
            .core
            .fling_from(id, crate::point(center), power, &mut rng.bind_mut().core)
        {
            Ok(r) => varray![r.is_some(), &released(r.unwrap_or_default())],
            Err(_) => Array::new(),
        }
    }
    #[func]
    fn drone_checkpoint(
        meta: PackedInt64Array,
        warhead: f64,
        flight: PackedByteArray,
    ) -> PackedByteArray {
        if meta.len() != 6 {
            return PackedByteArray::new();
        }
        let result = (|| {
            let d = Drone {
                id: u32::try_from(meta[0]).ok()?,
                team: i8::try_from(meta[1]).ok()?,
                operator: u32::try_from(meta[2]).ok()?,
                target: u32::try_from(meta[3]).ok()?,
                operator_at_spawn: u32::try_from(meta[4]).ok()?,
                target_at_spawn: u32::try_from(meta[5]).ok()?,
                warhead,
                flight: DroneFlight::restore(flight.as_slice()).ok()?,
            };
            d.checkpoint().ok()
        })();
        result.map_or_else(PackedByteArray::new, |b| b.as_slice().into())
    }
    #[func]
    fn drone_state(&self, id: u32) -> Array<Variant> {
        let Some(Actor::Drone(d)) = self.core.get(id) else {
            return Array::new();
        };
        let f = d.flight;
        varray![
            vector(f.position),
            vector(f.velocity),
            vector(f.target),
            f.life,
            f.phase as i32,
            f.diving,
            f.dead,
            f64::from(f.yaw),
            i64::from(d.operator),
            i64::from(d.target),
            i64::from(d.operator_at_spawn),
            i64::from(d.target_at_spawn),
            d.warhead
        ]
    }
    #[func]
    fn step_drone(
        &mut self,
        id: u32,
        dt: f64,
        mut collision: Gd<crate::collision_index::CollisionIndexCore>,
        map_half: f64,
    ) -> Array<Variant> {
        impact(
            self.core
                .step_drone(id, dt, &mut collision.bind_mut().core, map_half as f32),
        )
    }
    #[func]
    fn detonate_drone(&mut self, id: u32) -> Array<Variant> {
        impact(self.core.detonate_drone(id))
    }
    #[func]
    fn shoot_drone(&mut self, id: u32) -> i32 {
        self.core.shoot_drone(id).map_or(-1, i32::from)
    }
}
