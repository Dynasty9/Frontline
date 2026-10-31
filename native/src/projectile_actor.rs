use crate::simulation_random::SimulationRandomCore;
use frontline_core::guided::GuidedFlight;
use frontline_core::projectile::{Flight, Holder};
use frontline_core::projectile_actor::{Event, Motion, Projectile, Smotherer, Step};
use frontline_core::support::SupportFlight;
use godot::prelude::*;

#[derive(GodotClass)]
#[class(base=RefCounted, init)]
struct ProjectileActorCore {
    base: Base<RefCounted>,
    core: Option<Projectile>,
}
fn read<T: FromGodot>(r: &Array<Variant>, i: usize) -> Option<T> {
    r.get(i)?.try_to().ok()
}
fn vector(p: frontline_core::vector::Vector3) -> Vector3 {
    Vector3::new(p.x, p.y, p.z)
}
fn metadata(s: &Projectile) -> PackedInt64Array {
    [
        i64::from(s.id),
        i64::from(s.team),
        i64::from(s.thrower),
        i64::from(s.called_by),
        i64::from(s.held_by),
        i64::from(s.smothered_by),
        i64::from(s.handler),
        i64::from(s.thrown_back),
        i64::from(s.target_id),
    ]
    .as_slice()
    .into()
}
fn ballistic_values(f: Flight) -> PackedFloat64Array {
    [
        f.position.x as f64,
        f.position.y as f64,
        f.position.z as f64,
        f.velocity.x as f64,
        f.velocity.y as f64,
        f.velocity.z as f64,
        f.origin.x as f64,
        f.origin.y as f64,
        f.origin.z as f64,
        f.target.x as f64,
        f.target.y as f64,
        f.target.z as f64,
        f.fuse,
        f64::from(f.flying),
        f.life,
        f.smoke_time,
        f.smoke_radius,
        f.shell_duration,
    ]
    .as_slice()
    .into()
}
fn events(events: Vec<Event>) -> Array<Variant> {
    events
        .into_iter()
        .map(|e| {
            match e {
                Event::Explosion(e) => {
                    let direction = e
                        .direction
                        .map_or_else(PackedVector3Array::new, |p| [vector(p)].as_slice().into());
                    varray![
                        0,
                        vector(e.position),
                        &PackedFloat64Array::from(
                            [
                                e.damage,
                                e.radius,
                                e.fling,
                                e.antitank,
                                e.track,
                                e.size,
                                e.structure_multiplier
                            ]
                            .as_slice()
                        ),
                        &direction,
                        e.top,
                        i64::from(e.source),
                        i32::from(e.team),
                        e.called_by
                    ]
                }
                Event::Spawn(p) => varray![
                    1,
                    p.flight.kind as i32,
                    &ballistic_values(p.flight),
                    i32::from(p.team),
                    i64::from(p.thrower),
                    p.called_by
                ],
                Event::DamageSmotherer { soldier, source } => {
                    varray![2, i64::from(soldier), i64::from(source)]
                }
                Event::SmotherNotice(id) => varray![3, i64::from(id)],
                Event::Photograph {
                    team,
                    position,
                    radius,
                    linger,
                } => varray![4, i32::from(team), vector(position), radius, linger],
                Event::Sound {
                    name,
                    volume,
                    position,
                } => varray![5, &GString::from(name), volume, vector(position)],
                Event::Stat(key) => varray![6, &GString::from(key)],
                Event::Despawn => varray![7],
            }
            .to_variant()
        })
        .collect()
}

#[godot_api]
impl ProjectileActorCore {
    #[func]
    fn load_state(&mut self, meta: PackedInt64Array, motion: u8, bytes: PackedByteArray) -> bool {
        let m = meta.as_slice();
        if m.len() != 9 {
            return false;
        }
        let result = (|| {
            let motion = match motion {
                0 => Motion::Ballistic(Flight::restore(bytes.as_slice()).ok()?),
                1 => Motion::Guided(GuidedFlight::restore(bytes.as_slice()).ok()?),
                2 => Motion::Support(SupportFlight::restore(bytes.as_slice()).ok()?),
                _ => return None,
            };
            Some(Projectile {
                id: u32::try_from(m[0]).ok()?,
                team: i8::try_from(m[1]).ok()?,
                thrower: u32::try_from(m[2]).ok()?,
                called_by: i32::try_from(m[3]).ok()?,
                held_by: u32::try_from(m[4]).ok()?,
                smothered_by: u32::try_from(m[5]).ok()?,
                handler: u32::try_from(m[6]).ok()?,
                thrown_back: u32::try_from(m[7]).ok()?,
                target_id: u32::try_from(m[8]).ok()?,
                motion,
            })
        })();
        let Some(state) = result.filter(Projectile::valid) else {
            return false;
        };
        self.core = Some(state);
        true
    }

    #[func]
    fn values(&self) -> Array<Variant> {
        self.core.as_ref().map_or_else(Array::new, |s| {
            let (kind, bytes) = match &s.motion {
                Motion::Ballistic(f) => (0, f.checkpoint()),
                Motion::Guided(f) => (1, f.checkpoint()),
                Motion::Support(f) => (2, f.checkpoint()),
            };
            varray![&metadata(s), kind, &PackedByteArray::from(bytes.as_slice())]
        })
    }

    #[func]
    fn view_state(&self) -> Array<Variant> {
        self.core
            .as_ref()
            .map_or_else(Array::new, |s| match &s.motion {
                Motion::Ballistic(f) => varray![
                    vector(f.position),
                    vector(f.velocity),
                    f.life,
                    f.fuse,
                    f.flying,
                    f.smoke_time,
                    f.smoke_radius
                ],
                Motion::Guided(f) => varray![
                    vector(f.position),
                    vector(f.velocity),
                    f.life,
                    vector(f.target)
                ],
                Motion::Support(f) => varray![
                    vector(f.position),
                    vector(f.velocity),
                    f.life,
                    f.fuse,
                    f.fire_elapsed,
                    f.bombs_initial,
                    f.mark_time
                ],
            })
    }

    #[func]
    fn checkpoint(&self) -> PackedByteArray {
        self.core
            .as_ref()
            .and_then(|s| s.checkpoint().ok())
            .map_or_else(PackedByteArray::new, |b| b.as_slice().into())
    }

    #[func]
    fn restore(&mut self, bytes: PackedByteArray) -> bool {
        let Ok(core) = Projectile::restore(bytes.as_slice()) else {
            return false;
        };
        self.core = Some(core);
        true
    }

    #[func]
    fn pick_up(&mut self, soldier: u32) -> bool {
        self.core
            .as_mut()
            .is_some_and(|s| s.pick_up(soldier).is_ok())
    }

    #[func]
    fn kick(&mut self, velocity: Vector3) -> bool {
        self.core
            .as_mut()
            .is_some_and(|s| s.kick(crate::point(velocity)).is_ok())
    }

    #[func]
    fn release_throw(
        &mut self,
        soldier: u32,
        team: i8,
        position: Vector3,
        target: Vector3,
    ) -> bool {
        self.core.as_mut().is_some_and(|s| {
            s.release_throw(soldier, team, crate::point(position), crate::point(target))
                .is_ok()
        })
    }

    #[func]
    fn advance(
        &mut self,
        input: Array<Variant>,
        candidates: PackedVector3Array,
        excluded: PackedInt64Array,
        mut collision: Gd<crate::collision_index::CollisionIndexCore>,
        mut rng: Gd<SimulationRandomCore>,
    ) -> Array<Variant> {
        if input.len() != 8 || candidates.len() > 1_000_000 || excluded.len() > 1_000_000 {
            return Array::new();
        }
        let result = (|| {
            let holder = match read::<u8>(&input, 3)? {
                0 => Holder::Free,
                1 => Holder::Alive(crate::point(read(&input, 4)?)),
                2 => Holder::Dropped,
                _ => return None,
            };
            let target: PackedVector3Array = read(&input, 5)?;
            if target.len() > 1 {
                return None;
            }
            let candidates: Vec<_> = candidates
                .as_slice()
                .iter()
                .copied()
                .map(crate::point)
                .collect();
            let covering: Array<Variant> = read(&input, 7)?;
            let smotherer = if covering.is_empty() {
                None
            } else {
                if covering.len() != 5 {
                    return None;
                }
                Some(Smotherer {
                    id: read(&covering, 0)?,
                    position: crate::point(read(&covering, 1)?),
                    yaw: read(&covering, 2)?,
                    alive: read(&covering, 3)?,
                    covering: read(&covering, 4)?,
                })
            };
            let i = Step {
                dt: read(&input, 0)?,
                time: read(&input, 1)?,
                map_half: read(&input, 2)?,
                holder,
                target: target.as_slice().first().copied().map(crate::point),
                smoke: read(&input, 6)?,
                smotherer,
                candidates: &candidates,
                excluded: excluded.as_slice(),
            };
            self.core
                .as_mut()?
                .advance(i, &mut collision.bind_mut().core, &mut rng.bind_mut().core)
                .ok()
        })();
        result.map_or_else(Array::new, |out| varray![&events(out)])
    }
}
