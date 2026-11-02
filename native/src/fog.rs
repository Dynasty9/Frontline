use crate::actors::ActorStateCore;
use crate::world_geometry::WorldGeometryCore;
use frontline_core::actors::{Actor, Actors};
use frontline_core::fog::{self, Fog, Sighting, VehicleProfile};
use godot::prelude::*;
use std::collections::HashMap;
fn read<T: FromGodot>(a: &Array<Variant>, i: usize) -> Option<T> {
    a.get(i)?.try_to().ok()
}
fn profiles(rows: Array<Variant>, actors: &Actors) -> Option<HashMap<u32, VehicleProfile>> {
    if rows.len() > 100_000 {
        return None;
    }
    let mut out = HashMap::new();
    for value in rows.iter_shared() {
        let a: Array<Variant> = value.try_to().ok()?;
        if a.len() != 5 {
            return None;
        }
        let id: u32 = read(&a, 0)?;
        let p = VehicleProfile {
            sight: read(&a, 1)?,
            helicopter: read(&a, 2)?,
            automatic: read(&a, 3)?,
            cannon: read(&a, 4)?,
        };
        if !p.sight.is_finite() || !(0.0..=4096.).contains(&p.sight) || out.insert(id, p).is_some()
        {
            return None;
        }
    }
    if actors
        .iter()
        .any(|a| matches!(a,Actor::Vehicle(v) if !out.contains_key(&v.id)))
    {
        return None;
    }
    Some(out)
}
#[derive(GodotClass)]
#[class(base=RefCounted,init)]
struct FogCore {
    base: Base<RefCounted>,
    core: Fog,
}
#[godot_api]
impl FogCore {
    #[func]
    fn load_state(&mut self, state: Array<Variant>) -> bool {
        let parse = || -> Option<Fog> {
            if state.len() != 3 {
                return None;
            }
            let marks: Array<Variant> = read(&state, 0)?;
            let seen: Array<Variant> = read(&state, 1)?;
            let drones: PackedInt64Array = read(&state, 2)?;
            if marks.len() != 2
                || seen.len() != 2
                || drones.len() % 2 != 0
                || drones.len() > 200_000
            {
                return None;
            }
            let mut out = Fog::default();
            for t in 0..2 {
                let m: PackedFloat32Array = read(&marks, t)?;
                if m.len() % 4 != 0 || m.len() > 400_000 {
                    return None;
                }
                out.marks[t] = m
                    .as_slice()
                    .chunks_exact(4)
                    .map(|v| [v[0], v[1], v[2], v[3]])
                    .collect();
                let sightings: Array<Variant> = read(&seen, t)?;
                if sightings.len() > 1_000_000 {
                    return None;
                }
                for value in sightings.iter_shared() {
                    let s: Array<Variant> = value.try_to().ok()?;
                    if s.len() != 3 {
                        return None;
                    }
                    out.sighted[t].push(Sighting {
                        id: read(&s, 0)?,
                        position: crate::point(read(&s, 1)?),
                        time: read(&s, 2)?,
                    });
                }
            }
            for v in drones.as_slice().chunks_exact(2) {
                out.drones
                    .push((u32::try_from(v[0]).ok()?, u8::try_from(v[1]).ok()?));
            }
            out.valid().then_some(out)
        };
        let Some(state) = parse() else {
            return false;
        };
        self.core = state;
        true
    }
    #[func]
    fn values(&self) -> Array<Variant> {
        let marks: Array<Variant> = self
            .core
            .marks
            .iter()
            .map(|m| {
                m.iter()
                    .flatten()
                    .copied()
                    .collect::<PackedFloat32Array>()
                    .to_variant()
            })
            .collect();
        let seen: Array<Variant> = self
            .core
            .sighted
            .iter()
            .map(|s| {
                s.iter()
                    .map(|v| {
                        varray![
                            v.id,
                            Vector3::new(v.position.x, v.position.y, v.position.z),
                            v.time
                        ]
                        .to_variant()
                    })
                    .collect::<Array<Variant>>()
                    .to_variant()
            })
            .collect();
        let drones: PackedInt64Array = self
            .core
            .drones
            .iter()
            .flat_map(|&(id, m)| [i64::from(id), i64::from(m)])
            .collect();
        varray![&marks, &seen, &drones]
    }
    #[func]
    fn update(
        &mut self,
        mut actors: Gd<ActorStateCore>,
        geometry: Gd<WorldGeometryCore>,
        now: f64,
        rows: Array<Variant>,
    ) -> Array<Variant> {
        let mut a = actors.bind_mut();
        let g = geometry.bind();
        let Some(g) = g.core.as_ref() else {
            return Array::new();
        };
        let Some(p) = profiles(rows, &a.core) else {
            return Array::new();
        };
        match self
            .core
            .update(&mut a.core, &g.terrain, now, &|v| p[&v.id])
        {
            Ok(ids) => {
                let ids: PackedInt64Array = ids.into_iter().map(i64::from).collect();
                varray![&ids]
            }
            Err(_) => Array::new(),
        }
    }
    #[func]
    fn update_danger(
        &self,
        actors: Gd<ActorStateCore>,
        mut geometry: Gd<WorldGeometryCore>,
        rows: Array<Variant>,
    ) -> Array<Variant> {
        let a = actors.bind();
        let mut g = geometry.bind_mut();
        let Some(g) = g.core.as_mut() else {
            return Array::new();
        };
        let Some(p) = profiles(rows, &a.core) else {
            return Array::new();
        };
        match fog::update_danger(&a.core, &mut g.navigation, &|v| p[&v.id]) {
            Ok(maps) => maps
                .into_iter()
                .map(|m| m.into_iter().collect::<PackedFloat32Array>().to_variant())
                .collect(),
            Err(_) => Array::new(),
        }
    }
    #[func]
    fn checkpoint(&self) -> PackedByteArray {
        self.core
            .checkpoint()
            .map_or_else(|_| PackedByteArray::new(), |v| v.as_slice().into())
    }
    #[func]
    fn restore(&mut self, bytes: PackedByteArray) -> bool {
        let Ok(f) = Fog::restore(bytes.as_slice()) else {
            return false;
        };
        self.core = f;
        true
    }
}
