use crate::{collision_index::CollisionIndexCore, simulation_random::SimulationRandomCore};
use frontline_core::grenade_reaction::{
    self as grenade, Grenade, GrenadeMemory, Mate, Reaction, Soldier,
};
use frontline_core::infantry_pose::Posture;
use frontline_core::infantry_vitals::Life;
use godot::prelude::*;

#[derive(GodotClass)]
#[class(base=RefCounted, init)]
struct GrenadeReactionCore {
    base: Base<RefCounted>,
    core: GrenadeMemory,
}

fn id(v: Variant) -> Option<u64> {
    u64::try_from(v.try_to::<i64>().ok()?)
        .ok()
        .filter(|id| *id > 0)
}
fn round(v: &Array<Variant>) -> Option<Grenade> {
    if v.len() != 9 {
        return None;
    }
    let g = Grenade {
        id: id(v.get(0)?)?,
        position: crate::point(v.get(1)?.try_to().ok()?),
        fuse: v.get(2)?.try_to().ok()?,
        held: v.get(3)?.try_to().ok()?,
        gone: v.get(4)?.try_to().ok()?,
        flying: v.get(5)?.try_to().ok()?,
        free: v.get(6)?.try_to().ok()?,
        smothered: v.get(7)?.try_to().ok()?,
        thrown_back: u32::try_from(v.get(8)?.try_to::<i64>().ok()?).ok()?,
    };
    if !g.valid() {
        return None;
    }
    Some(g)
}
fn soldier(v: &Array<Variant>) -> Option<Soldier> {
    if v.len() != 11 {
        return None;
    }
    let s = Soldier {
        id: id(v.get(0)?)?,
        position: crate::point(v.get(1)?.try_to().ok()?),
        center: crate::point(v.get(2)?.try_to().ok()?),
        yaw: v.get(3)?.try_to().ok()?,
        team: v.get(4)?.try_to().ok()?,
        suppression: v.get(5)?.try_to().ok()?,
        posture: Posture::try_from(u8::try_from(v.get(6)?.try_to::<i64>().ok()?).ok()?).ok()?,
        squad: v.get(7)?.try_to().ok()?,
        mounted: v.get(8)?.try_to().ok()?,
        riding: v.get(9)?.try_to().ok()?,
        armed: v.get(10)?.try_to().ok()?,
    };
    s.valid().then_some(s)
}
fn mates(rows: &Array<Variant>) -> Option<Vec<Mate>> {
    if rows.len() > 100_000 {
        return None;
    }
    rows.iter_shared()
        .map(|row| {
            let row = row.try_to::<Array<Variant>>().ok()?;
            if row.len() != 6 {
                return None;
            }
            Some(Mate {
                id: id(row.get(0)?)?,
                position: crate::point(row.get(1)?.try_to().ok()?),
                center: crate::point(row.get(2)?.try_to().ok()?),
                team: row.get(3)?.try_to().ok()?,
                life: Life::try_from(u8::try_from(row.get(4)?.try_to::<i64>().ok()?).ok()?).ok()?,
                helpless: row.get(5)?.try_to().ok()?,
            })
        })
        .collect()
}

#[godot_api]
impl GrenadeReactionCore {
    #[func]
    fn checkpoint(&self) -> PackedByteArray {
        self.core.checkpoint().as_slice().into()
    }
    #[func]
    fn restore(&mut self, bytes: PackedByteArray) -> bool {
        let Ok(core) = GrenadeMemory::restore(bytes.as_slice()) else {
            return false;
        };
        self.core = core;
        true
    }
    #[func]
    fn notice(
        &mut self,
        position: Vector3,
        seen: PackedInt64Array,
        rounds: Array<Variant>,
        skip_gone: bool,
    ) -> Array<Variant> {
        if seen.len() > 25 || rounds.len() > 100_000 {
            return Array::new();
        }
        let Some(seen) = seen
            .as_slice()
            .iter()
            .map(|id| u64::try_from(*id).ok())
            .collect::<Option<Vec<_>>>()
        else {
            return Array::new();
        };
        let Some(rounds) = rounds
            .iter_shared()
            .map(|v| round(&v.try_to::<Array<Variant>>().ok()?))
            .collect::<Option<Vec<_>>>()
        else {
            return Array::new();
        };
        let mut core = GrenadeMemory { seen };
        let Ok(id) = core.notice(crate::point(position), &rounds, skip_gone) else {
            return Array::new();
        };
        let seen: PackedInt64Array = core.seen.iter().map(|id| *id as i64).collect();
        self.core = core;
        varray![id.unwrap_or(0) as i64, &seen]
    }
    #[func]
    fn react(
        &self,
        actor: Array<Variant>,
        target: Array<Variant>,
        contacts: Array<Variant>,
        mut collision: Gd<CollisionIndexCore>,
        mut rng: Gd<SimulationRandomCore>,
    ) -> PackedInt64Array {
        let (Some(s), Some(g), Some(mates)) = (soldier(&actor), round(&target), mates(&contacts))
        else {
            return PackedInt64Array::new();
        };
        let Ok(result) = grenade::react(
            s,
            g,
            &mates,
            &mut collision.bind_mut().core,
            &mut rng.bind_mut().core,
        ) else {
            return PackedInt64Array::new();
        };
        let (kind, body) = match result {
            Reaction::Smother => (0, 0),
            Reaction::ThrowBack => (1, 0),
            Reaction::Kick => (2, 0),
            Reaction::Shelter(body) => (3, body),
            Reaction::Dive => (4, 0),
        };
        PackedInt64Array::from(&[kind, body])
    }
    #[func]
    fn kick_velocity(
        &self,
        actor: Array<Variant>,
        target: Array<Variant>,
        contacts: Array<Variant>,
        thrower: Variant,
    ) -> Variant {
        let (Some(s), Some(g), Some(mates)) = (soldier(&actor), round(&target), mates(&contacts))
        else {
            return Variant::nil();
        };
        let from = if thrower.is_nil() {
            None
        } else {
            let Ok(p) = thrower.try_to::<Vector3>() else {
                return Variant::nil();
            };
            Some(crate::point(p))
        };
        match grenade::kick_velocity(s, g, &mates, from) {
            Ok(v) => Vector3::new(v.x, v.y, v.z).to_variant(),
            Err(_) => Variant::nil(),
        }
    }
    #[func]
    fn cook_time(
        &self,
        team: i32,
        distance: f64,
        hard_cover: bool,
        mut rng: Gd<SimulationRandomCore>,
    ) -> Variant {
        match grenade::cook_time(team, distance, hard_cover, &mut rng.bind_mut().core) {
            Ok(time) => time.to_variant(),
            Err(_) => Variant::nil(),
        }
    }
}
