use crate::actors::ActorStateCore;
use crate::simulation_random::SimulationRandomCore;
use crate::spatial::SpatialIndexCore;
use frontline_core::infantry_prison_owned::IntelMode;
use frontline_core::prisoner_intelligence::PrisonerIntelligence;
use godot::prelude::*;
use std::collections::{HashMap, HashSet};

#[derive(GodotClass)]
#[class(base=RefCounted, init)]
struct PrisonerIntelligenceCore {
    base: Base<RefCounted>,
    core: PrisonerIntelligence,
}

#[godot_api]
impl PrisonerIntelligenceCore {
    #[func]
    fn checkpoint(&self) -> PackedByteArray {
        self.core.checkpoint().as_slice().into()
    }
    #[func]
    fn restore(&mut self, bytes: PackedByteArray) -> bool {
        match PrisonerIntelligence::restore(bytes.as_slice()) {
            Ok(core) => {
                self.core = core;
                true
            }
            Err(_) => false,
        }
    }
    #[func]
    fn given(&self, id: u32) -> PackedStringArray {
        self.core.given(id).iter().map(GString::from).collect()
    }
    #[func]
    fn forget(&mut self, id: u32) {
        self.core.forget(id);
    }
    #[func]
    fn reveal(
        &mut self,
        id: u32,
        mode: i32,
        actors: Gd<ActorStateCore>,
        units: Gd<SpatialIndexCore>,
        towns: PackedInt64Array,
        commanders: PackedInt64Array,
        map_side: u32,
        bearer_ids: PackedInt64Array,
        structure_names: Dictionary<Variant, Variant>,
        item_names: Dictionary<Variant, Variant>,
        mut rng: Gd<SimulationRandomCore>,
    ) -> Array<Variant> {
        let mode = match mode {
            0 => IntelMode::March,
            1 => IntelMode::Held,
            2 => IntelMode::Interrogation,
            _ => return Array::new(),
        };
        let towns: Result<Vec<_>, _> = towns
            .as_slice()
            .iter()
            .map(|id| u32::try_from(*id))
            .collect();
        if commanders.len() % 2 != 0 || commanders.len() > 200_000 || bearer_ids.len() > 1_000_000 {
            return Array::new();
        }
        let commanders: Result<Vec<_>, _> = commanders
            .as_slice()
            .chunks_exact(2)
            .map(|c| Ok((i8::try_from(c[0])?, u32::try_from(c[1])?)))
            .collect::<Result<_, std::num::TryFromIntError>>();
        let bearers: Result<HashSet<_>, _> = bearer_ids
            .as_slice()
            .iter()
            .map(|id| u32::try_from(*id))
            .collect();
        let names: Result<HashMap<u32, String>, ()> = structure_names
            .iter_shared()
            .map(|(id, name)| {
                Ok((
                    id.try_to().map_err(|_| ())?,
                    name.try_to::<GString>().map_err(|_| ())?.to_string(),
                ))
            })
            .collect();
        let items: Result<HashMap<String, String>, ()> = item_names
            .iter_shared()
            .map(|(id, name)| {
                Ok((
                    id.try_to::<GString>().map_err(|_| ())?.to_string(),
                    name.try_to::<GString>().map_err(|_| ())?.to_string(),
                ))
            })
            .collect();
        let (Ok(towns), Ok(commanders), Ok(bearers), Ok(names), Ok(items)) =
            (towns, commanders, bearers, names, items)
        else {
            return Array::new();
        };
        let actors = actors.bind();
        let units = units.bind();
        let Some(units) = &units.core else {
            return Array::new();
        };
        match self.core.reveal(
            id,
            mode,
            &actors.core,
            units,
            &towns,
            &commanders,
            map_side,
            |s| bearers.contains(&s.identity.id),
            |st| {
                names
                    .get(&st.id)
                    .cloned()
                    .unwrap_or_else(|| st.kind.clone())
            },
            |item| items.get(item).cloned().unwrap_or_else(|| item.to_owned()),
            &mut rng.bind_mut().core,
        ) {
            Ok(out) => {
                let position = out
                    .fact
                    .position
                    .map_or_else(Variant::nil, |p| Vector3::new(p.x, p.y, p.z).to_variant());
                varray![
                    out.team as i64,
                    "intel",
                    out.text.as_str(),
                    &position,
                    out.fact.key.as_str()
                ]
            }
            Err(_) => Array::new(),
        }
    }
}
