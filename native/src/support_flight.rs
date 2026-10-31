use frontline_core::support::{Event, Gunset, Kind, SupportFlight};
use godot::prelude::*;

#[derive(GodotClass)]
#[class(base=RefCounted, init)]
struct SupportFlightCore {
    base: Base<RefCounted>,
    core: Option<SupportFlight>,
}

#[godot_api]
impl SupportFlightCore {
    #[func]
    fn reset(
        &mut self,
        kind: GString,
        guns: GString,
        state: PackedFloat64Array,
        muzzles: PackedVector3Array,
    ) -> bool {
        let kind = match kind.to_string().as_str() {
            "jet" => Kind::Jet,
            "a10" => Kind::GunRun,
            "ac130" => Kind::Orbit,
            _ => return false,
        };
        let s = state.as_slice();
        if s.len() != 14
            || !s.iter().all(|v| v.is_finite())
            || !s[..9].iter().all(|v| (*v as f32).is_finite())
        {
            return false;
        }
        let point =
            |i| frontline_core::vector::Vector3::new(s[i] as f32, s[i + 1] as f32, s[i + 2] as f32);
        let mut core = SupportFlight::new(kind, point(0), point(3), point(6));
        core.gunset = Gunset::parse(&guns.to_string());
        let count = if kind == Kind::Orbit {
            frontline_core::support::guns(core.gunset).len()
        } else {
            0
        };
        if muzzles.len() != count || !muzzles.as_slice().iter().all(|p| p.is_finite()) {
            return false;
        }
        for (slot, point) in core.muzzles.iter_mut().zip(muzzles.as_slice()) {
            *slot = crate::point(*point);
        }
        core.life = s[9];
        core.fuse = s[10];
        core.stay = s[11];
        core.sight = s[12];
        core.mark_time = s[13];
        self.core = Some(core);
        true
    }

    #[func]
    fn checkpoint(&self) -> PackedByteArray {
        self.core
            .as_ref()
            .map_or_else(PackedByteArray::new, |core| {
                core.checkpoint().as_slice().into()
            })
    }

    #[func]
    fn restore(&mut self, bytes: PackedByteArray) -> bool {
        let Ok(core) = SupportFlight::restore(bytes.as_slice()) else {
            return false;
        };
        self.core = Some(core);
        true
    }

    #[func]
    fn needs_candidates(&self, dt: f64) -> bool {
        self.core
            .as_ref()
            .is_some_and(|core| dt.is_finite() && dt >= 0.0 && core.needs_candidates(dt))
    }

    #[func]
    fn advance(
        &mut self,
        dt: f64,
        time: f64,
        team: i32,
        map_half: f64,
        candidates: PackedVector3Array,
        mut rng: Gd<crate::simulation_random::SimulationRandomCore>,
    ) -> VarDictionary {
        if !dt.is_finite()
            || !(0.0..=1.0).contains(&dt)
            || !time.is_finite()
            || !map_half.is_finite()
            || map_half <= 0.0
            || candidates.len() > 100_000
            || !candidates.as_slice().iter().all(|p| p.is_finite())
        {
            return Dictionary::new();
        }
        let Some(core) = self.core.as_mut() else {
            return Dictionary::new();
        };
        let candidates: Vec<_> = candidates
            .as_slice()
            .iter()
            .copied()
            .map(crate::point)
            .collect();
        let events = core.advance(
            dt,
            time,
            team,
            map_half,
            &candidates,
            &mut rng.bind_mut().core,
        );
        let mut output: Array<Variant> = Array::new();
        for event in events {
            let event = match event {
                Event::Bomb { position, velocity } => varray![0, point(position), point(velocity)],
                Event::GunRunStarted => varray![1],
                Event::Impact(position) => varray![2, point(position)],
                Event::Shell {
                    kind,
                    position,
                    target,
                    duration,
                } => varray![3, kind, point(position), point(target), duration],
                Event::Sound { name, volume } => varray![4, name, volume],
                Event::Photograph => varray![5],
                Event::Despawn => varray![6],
            };
            output.push(&event.to_variant());
        }
        let p = core.position;
        let v = core.velocity;
        let state = PackedFloat64Array::from(&[
            p.x as f64,
            p.y as f64,
            p.z as f64,
            v.x as f64,
            v.y as f64,
            v.z as f64,
            core.life,
            core.fuse,
            core.fire_elapsed,
            core.bombs_initial,
            core.mark_time,
        ]);
        dict! { "state" => &state, "events" => &output }
    }
}

fn point(p: frontline_core::vector::Vector3) -> Vector3 {
    Vector3::new(p.x, p.y, p.z)
}
