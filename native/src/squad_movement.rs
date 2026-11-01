//! Reference-only binding for complete squad orders against retained world state.
use crate::actors::{read_squads, write_squads, ActorStateCore};
use crate::simulation_random::SimulationRandomCore;
use crate::spatial::SpatialIndexCore;
use crate::squad::SquadStateCore;
use crate::visibility::VisibilityCore;
use crate::world_geometry::WorldGeometryCore;
use frontline_core::actors::Actor;
use frontline_core::attack_plan::{AttackPlan, Event as AttackEvent};
use frontline_core::squad_movement::{Context, Event, ManProfile};
use godot::prelude::*;
use std::collections::{BTreeMap, HashSet};

#[derive(GodotClass)]
#[class(base=RefCounted, init)]
struct SquadMovementCore {
    base: Base<RefCounted>,
}
#[godot_api]
impl SquadMovementCore {
    #[func]
    fn apply(
        &self,
        mut actors: Gd<ActorStateCore>,
        mut geometry: Gd<WorldGeometryCore>,
        units: Gd<SpatialIndexCore>,
        nodes: Array<Gd<SquadStateCore>>,
        mut rng: Gd<SimulationRandomCore>,
        profiles: Array<Variant>,
        now: f64,
        town: Rect2,
        id: u32,
        operation: i32,
        input: Array<Variant>,
    ) -> Array<Variant> {
        let mut actors = actors.bind_mut();
        let mut geometry = geometry.bind_mut();
        let units = units.bind();
        let (Some(geometry), Some(units)) = (&mut geometry.core, &units.core) else {
            return Array::new();
        };
        let Some(mut squads) = read_squads(&nodes) else {
            return Array::new();
        };
        let mut men = BTreeMap::new();
        let mut automatic = HashSet::new();
        let mut buildings = HashSet::new();
        if profiles.len() > 100_000 {
            return Array::new();
        }
        for row in profiles.iter_shared() {
            let Ok(row) = row.try_to::<Array<Variant>>() else {
                return Array::new();
            };
            if row.len() != 5 {
                return Array::new();
            }
            let (Ok(id), Ok(bearer), Ok(range), Ok(auto), Ok(building)) = (
                row.at(0).try_to::<u32>(),
                row.at(1).try_to::<bool>(),
                row.at(2).try_to::<f64>(),
                row.at(3).try_to::<bool>(),
                row.at(4).try_to::<bool>(),
            ) else {
                return Array::new();
            };
            if !range.is_finite() || !(-1.0..=1_000_000.0).contains(&range) {
                return Array::new();
            }
            match actors.core.get(id) {
                Some(Actor::Soldier(_)) => {
                    men.insert(
                        id,
                        ManProfile {
                            bearer,
                            weapon_range: (range >= 0.0).then_some(range),
                        },
                    );
                }
                Some(Actor::Vehicle(v)) if auto => {
                    automatic.insert(v.kind.clone());
                }
                Some(Actor::Structure(st)) if building => {
                    buildings.insert(st.kind.clone());
                }
                _ => (),
            }
        }
        if actors
            .core
            .iter()
            .any(|a| matches!(a, Actor::Soldier(s) if !men.contains_key(&s.identity.id)))
        {
            return Array::new();
        }
        let mut rng = rng.bind_mut();
        let mut context = Context {
            actors: &mut actors.core,
            geometry,
            units,
            squads: &mut squads,
            rng: &mut rng.core,
            now,
            town: [town.position.x, town.position.y, town.size.x, town.size.y],
            man: &|s| men[&s.identity.id],
            automatic: &|kind| automatic.contains(kind),
            player_building: &|kind| buildings.contains(kind),
        };
        let result = match operation {
            0 if input.len() == 4 => {
                let (Ok(p), Ok(f), Ok(m), Ok(t)) = (
                    input.at(0).try_to::<Vector3>(),
                    input.at(1).try_to::<Vector3>(),
                    input.at(2).try_to::<u8>(),
                    input.at(3).try_to::<bool>(),
                ) else {
                    return Array::new();
                };
                context.order_move(id, crate::point(p), crate::point(f), m, t)
            }
            1 if input.is_empty() => context.follow_tick(id),
            2 if input.is_empty() => context.overwatch_tick(id),
            3 if input.is_empty() => context.crew_tick(id),
            4 if input.len() == 3 => {
                let (Ok(p), Ok(f), Ok(direct)) = (
                    input.at(0).try_to::<Vector3>(),
                    input.at(1).try_to::<Vector3>(),
                    input.at(2).try_to::<bool>(),
                ) else {
                    return Array::new();
                };
                context.order_defend(id, crate::point(p), crate::point(f), direct)
            }
            5 if input.len() == 2 => {
                let (Ok(p), Ok(f)) = (
                    input.at(0).try_to::<Vector3>(),
                    input.at(1).try_to::<Vector3>(),
                ) else {
                    return Array::new();
                };
                context.order_assault_bounds(id, crate::point(p), crate::point(f))
            }
            6 if input.is_empty() => context.assault_bounds_tick(id),
            7..=11 => {
                let result = apply_attack(&mut context, id, operation, input);
                write_squads(nodes, squads);
                return match result {
                    Ok((plan, events)) => {
                        let events: Array<Variant> = events
                            .into_iter()
                            .map(|e| match e {
                                AttackEvent::Squad(e) => event(e),
                                AttackEvent::Speech { soldier, text } => {
                                    varray![5, soldier, &GString::from(&text)].to_variant()
                                }
                                AttackEvent::NeedsSupport {
                                    team,
                                    squad,
                                    position,
                                } => varray![
                                    6,
                                    team,
                                    squad,
                                    Vector3::new(position.x, position.y, position.z)
                                ]
                                .to_variant(),
                                AttackEvent::Stat(name) => {
                                    varray![2, &GString::from(name)].to_variant()
                                }
                            })
                            .collect();
                        let bytes = plan.map_or_else(Vec::new, |p| p.checkpoint().unwrap());
                        varray![&events, &PackedByteArray::from(bytes.as_slice())]
                    }
                    Err(error) => {
                        godot_error!("{error}");
                        Array::new()
                    }
                };
            }
            _ => return Array::new(),
        };
        write_squads(nodes, squads);
        match result {
            Ok(events) => {
                let events: Array<Variant> = events.into_iter().map(event).collect();
                varray![&events]
            }
            Err(error) => {
                godot_error!("{error}");
                Array::new()
            }
        }
    }
}
fn event(e: Event) -> Variant {
    match e {
        Event::Speech {
            soldier,
            call,
            variant,
        } => varray![0, soldier, call as u8, variant].to_variant(),
        Event::CancelAmbush(id) => varray![1, id].to_variant(),
        Event::CrewHome { squad, fob } => varray![3, squad, fob].to_variant(),
        Event::Despawn(id) => varray![4, id].to_variant(),
        Event::Stat(name) => varray![2, &GString::from(name)].to_variant(),
    }
}
fn apply_attack(
    ctx: &mut Context<'_>,
    id: u32,
    op: i32,
    input: Array<Variant>,
) -> Result<(Option<AttackPlan>, Vec<AttackEvent>), &'static str> {
    if op == 11 && input.len() == 3 {
        let (Ok(boat), Ok(plan), Ok(visibility)) = (
            input.at(0).try_to::<bool>(),
            input.at(1).try_to::<u32>(),
            input.at(2).try_to::<Gd<VisibilityCore>>(),
        ) else {
            return Err("invalid dismount order");
        };
        return ctx.dismount_vehicle(id, boat, plan, &visibility.bind().core);
    }
    if matches!(op, 8 | 9) && input.len() == 1 {
        let bytes = input
            .at(0)
            .try_to::<PackedByteArray>()
            .map_err(|_| "invalid attack checkpoint")?;
        let mut p = AttackPlan::restore(bytes.as_slice())?;
        let out = if op == 8 {
            p.tick(ctx)?
        } else {
            p.join(ctx, id)?
        };
        return Ok((Some(p), out));
    }
    if matches!(op, 7 | 10) && input.len() == 4 {
        let (Ok(p), Ok(f), Ok(visibility)) = (
            input.at(0).try_to::<Vector3>(),
            input.at(1).try_to::<Vector3>(),
            input.at(2).try_to::<Gd<VisibilityCore>>(),
        ) else {
            return Err("invalid attack order");
        };
        let visibility = visibility.bind();
        if op == 7 {
            let plan = input
                .at(3)
                .try_to::<u32>()
                .map_err(|_| "invalid attack id")?;
            return ctx.order_assault(id, crate::point(p), crate::point(f), plan, &visibility.core);
        }
        let ids = input
            .at(3)
            .try_to::<PackedInt64Array>()
            .map_err(|_| "invalid attack squads")?;
        let ids = ids
            .as_slice()
            .iter()
            .map(|&id| u32::try_from(id).map_err(|_| "invalid attack squad"))
            .collect::<Result<Vec<_>, _>>()?;
        return AttackPlan::make(
            ctx,
            id,
            &ids,
            crate::point(p),
            crate::point(f),
            &visibility.core,
        );
    }
    Err("invalid attack operation")
}
