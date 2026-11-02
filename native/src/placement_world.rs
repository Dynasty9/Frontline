use crate::battle_stats::BattleStatsCore;
use crate::command_handoff::CommandOwnershipCore;
use crate::rules_world::RulesWorldCore;
use crate::water_raster::WaterRaster;
use frontline_core::building_placement::{Definition, Distances};
use frontline_core::placement_world::{Event, Request};
use frontline_core::squad_movement::Context;
use frontline_core::structure_birth::BuildingProfile;
use godot::prelude::*;
use std::collections::{HashMap, HashSet};
fn read<T: FromGodot>(a: &Array<Variant>, i: usize) -> Result<T, &'static str> {
    a.get(i)
        .ok_or("missing placement field")?
        .try_to()
        .map_err(|_| "invalid placement field")
}
fn ids(a: PackedInt64Array) -> Result<Vec<u32>, &'static str> {
    if a.len() > 100_000 {
        return Err("placement selection limit exceeded");
    }
    a.as_slice()
        .iter()
        .map(|&id| u32::try_from(id).map_err(|_| "invalid placement identity"))
        .collect()
}
fn packed(ids: &[u32]) -> PackedInt64Array {
    ids.iter().map(|&id| i64::from(id)).collect()
}
pub(crate) fn apply(
    ctx: &mut Context<'_>,
    a: &Array<Variant>,
) -> Result<Array<Variant>, &'static str> {
    if a.len() != 10 {
        return Err("invalid placement input");
    }
    let mut rules: Gd<RulesWorldCore> = read(a, 0)?;
    let owners: Gd<CommandOwnershipCore> = read(a, 1)?;
    let mut battle: Gd<BattleStatsCore> = read(a, 2)?;
    let water: Gd<WaterRaster> = read(a, 3)?;
    let req: Array<Variant> = read(a, 4)?;
    let def: Array<Variant> = read(a, 5)?;
    let distances: PackedFloat64Array = read(a, 6)?;
    let names: PackedStringArray = read(a, 7)?;
    let engineers: HashSet<_> = ids(read(a, 8)?)?.into_iter().collect();
    let display: VarDictionary = read(a, 9)?;
    if req.len() != 7
        || !matches!(def.len(), 0 | 6)
        || distances.len() != 3
        || names.len() > 4096
        || display.len() > 1_000_000
    {
        return Err("invalid placement profile");
    }
    let peer = read(&req, 0)?;
    let team = read(&req, 1)?;
    let position = crate::point(read(&req, 2)?);
    let yaw = read(&req, 3)?;
    let size = crate::point(read(&req, 4)?);
    let squads = ids(read(&req, 5)?)?;
    let assign = read(&req, 6)?;
    let key = if def.is_empty() {
        String::new()
    } else {
        read::<GString>(&def, 0)?.to_string()
    };
    let name = if def.is_empty() {
        String::new()
    } else {
        read::<GString>(&def, 1)?.to_string()
    };
    let definition = if def.is_empty() {
        None
    } else {
        let size: Vector2 = read(&def, 4)?;
        Some(Definition {
            key: &key,
            name: &name,
            teams: read(&def, 2)?,
            cost: read(&def, 3)?,
            body: BuildingProfile {
                size: [size.x, size.y],
                hp: read(&def, 5)?,
            },
        })
    };
    let mut labels = HashMap::new();
    for (id, name) in display.iter_shared() {
        labels.insert(
            id.try_to::<u32>()
                .map_err(|_| "invalid displayed building")?,
            name.try_to::<GString>()
                .map_err(|_| "invalid building label")?
                .to_string(),
        );
    }
    if ctx
        .actors
        .iter_kind(frontline_core::entities::Kind::Structure)
        .any(|a| !labels.contains_key(&a.identity().id))
    {
        return Err("missing building label");
    }
    let names: Vec<_> = names.as_slice().iter().map(ToString::to_string).collect();
    let mut rules = rules.bind_mut();
    let owners = owners.bind();
    let mut battle = battle.bind_mut();
    let water = water.bind();
    let water = water.core.as_ref().ok_or("missing water")?;
    let events = ctx.place_building(
        &mut rules.core,
        &owners.core,
        &mut battle.core,
        water,
        Request {
            peer,
            team,
            position,
            yaw,
            size: (size != frontline_core::vector::Vector3::ZERO).then_some(size),
            squads: &squads,
            assign,
        },
        definition.as_ref(),
        &Distances {
            build: distances[0],
            fob_spacing: distances[1],
            fob_expand: distances[2],
        },
        &names,
        &|m| engineers.contains(&m.identity.id),
        &|st| labels[&st.id].clone(),
    )?;
    Ok(events
        .into_iter()
        .map(|event| match event {
            Event::Warning { peer, text } => varray![0, peer, &GString::from(&text)].to_variant(),
            Event::Placed { id, ownership } => varray![
                1,
                id,
                &packed(&ownership.squads),
                &packed(&ownership.vehicles),
                &packed(&ownership.soldiers)
            ]
            .to_variant(),
            Event::Squad(event) => varray![2, &crate::squad_movement::event(event)].to_variant(),
        })
        .collect())
}
