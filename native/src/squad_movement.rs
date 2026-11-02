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
            24 | 25 => {
                let result = apply_ambush(&mut context, id, operation, input);
                write_squads(nodes, squads);
                return match result {
                    Ok((plan, events)) => {
                        let events: Array<Variant> = events.into_iter().map(brain_event).collect();
                        let bytes = plan.checkpoint().unwrap();
                        varray![&events, &PackedByteArray::from(bytes.as_slice())]
                    }
                    Err(error) => {
                        godot_error!("{error}");
                        Array::new()
                    }
                };
            }
            12..=23 => {
                let result = if operation <= 16 {
                    apply_brain(&mut context, id, operation, input)
                } else {
                    apply_duties(&mut context, id, operation, input)
                };
                write_squads(nodes, squads);
                return match result {
                    Ok((handled, events)) => {
                        let events: Array<Variant> = events.into_iter().map(brain_event).collect();
                        varray![&events, handled]
                    }
                    Err(error) => {
                        godot_error!("{error}");
                        Array::new()
                    }
                };
            }
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
fn brain_event(e: frontline_core::squad_brain::Event) -> Variant {
    use frontline_core::squad_brain::Event as E;
    match e {
        E::Movement(e) => event(e),
        E::Stat(name) => varray![2, &GString::from(name)].to_variant(),
        E::Speech {
            soldier,
            call,
            variant,
            target,
        } => {
            let at = target.map_or(Vector3::INF, |p| Vector3::new(p.x, p.y, p.z));
            varray![7, soldier, call as u8, variant, at].to_variant()
        }
        E::Message {
            squad,
            message,
            position,
        } => varray![
            8,
            squad,
            message as u8,
            Vector3::new(position.x, position.y, position.z)
        ]
        .to_variant(),
        E::Joined {
            from,
            to,
            soldier,
            position,
        } => varray![
            9,
            from,
            to,
            soldier,
            Vector3::new(position.x, position.y, position.z)
        ]
        .to_variant(),
        E::Surrendered {
            soldier,
            team,
            position,
            drop_direction,
        } => varray![
            10,
            soldier,
            team,
            Vector3::new(position.x, position.y, position.z),
            Vector3::new(drop_direction.x, drop_direction.y, drop_direction.z)
        ]
        .to_variant(),
    }
}
fn apply_duties(
    ctx: &mut Context<'_>,
    id: u32,
    op: i32,
    input: Array<Variant>,
) -> Result<(bool, Vec<frontline_core::squad_brain::Event>), &'static str> {
    use frontline_core::squad_duties::Role;
    if input.len() != 2 {
        return Err("invalid squad duty input");
    }
    let rows = input
        .at(0)
        .try_to::<Array<Variant>>()
        .map_err(|_| "invalid squad roles")?;
    let mut battle = input
        .at(1)
        .try_to::<Gd<crate::battle_stats::BattleStatsCore>>()
        .map_err(|_| "invalid squad ledger")?;
    if rows.len() > 100_000 {
        return Err("squad role limit exceeded");
    }
    let mut roles = BTreeMap::new();
    for row in rows.iter_shared() {
        let row = row
            .try_to::<Array<Variant>>()
            .map_err(|_| "invalid squad role")?;
        if row.len() != 3 {
            return Err("invalid squad role width");
        }
        let id = row
            .at(0)
            .try_to::<u32>()
            .map_err(|_| "invalid squad role actor")?;
        let medic = row
            .at(1)
            .try_to::<bool>()
            .map_err(|_| "invalid medic role")?;
        let engineer = row
            .at(2)
            .try_to::<bool>()
            .map_err(|_| "invalid engineer role")?;
        if ctx.actors.soldier(id).is_none() || roles.insert(id, Role { medic, engineer }).is_some()
        {
            return Err("invalid squad role identity");
        }
    }
    if ctx
        .actors
        .iter()
        .any(|a| matches!(a,Actor::Soldier(s) if !roles.contains_key(&s.identity.id)))
    {
        return Err("missing squad role");
    }
    let role = |s: &frontline_core::infantry::Infantry| roles[&s.identity.id];
    let events = match op {
        17 => ctx.squad_rescue(id, &role)?,
        18 => {
            ctx.squad_medics(id, &role)?;
            vec![]
        }
        19 => {
            ctx.squad_engineers(id, &role)?;
            vec![]
        }
        20 => ctx.squad_surrender(id)?,
        21 => ctx.squad_straggler_tick(id, &mut battle.bind_mut().core)?,
        22 => ctx.squad_then_defend_tick(id)?,
        23 => ctx.squad_clear_call_tick(id)?,
        _ => return Err("invalid squad duty operation"),
    };
    Ok((true, events))
}
fn apply_brain(
    ctx: &mut Context<'_>,
    id: u32,
    op: i32,
    input: Array<Variant>,
) -> Result<(bool, Vec<frontline_core::squad_brain::Event>), &'static str> {
    use frontline_core::{infantry_weapon::Weapon, squad::Report, squad_brain::Profile};
    if input.len() != 4 {
        return Err("invalid squad brain input");
    }
    let dt = input
        .at(0)
        .try_to::<f64>()
        .map_err(|_| "invalid squad step")?;
    let rows = input
        .at(1)
        .try_to::<Array<Variant>>()
        .map_err(|_| "invalid squad profiles")?;
    let saved = input
        .at(2)
        .try_to::<Array<PackedByteArray>>()
        .map_err(|_| "invalid squad plans")?;
    let impacts = input
        .at(3)
        .try_to::<Array<Variant>>()
        .map_err(|_| "invalid squad impacts")?;
    if rows.len() > 100_000 || saved.len() > 100_000 || impacts.len() > 100_000 {
        return Err("squad brain input limit exceeded");
    }
    let mut weapons = BTreeMap::new();
    let mut armor = BTreeMap::new();
    for row in rows.iter_shared() {
        let row = row
            .try_to::<Array<Variant>>()
            .map_err(|_| "invalid squad profile")?;
        if row.len() != 5 {
            return Err("invalid squad profile width");
        }
        let id = row
            .at(0)
            .try_to::<u32>()
            .map_err(|_| "invalid profile actor")?;
        let ammunition = row
            .at(1)
            .try_to::<i32>()
            .map_err(|_| "invalid profile ammunition")?;
        let magazine = row
            .at(2)
            .try_to::<i32>()
            .map_err(|_| "invalid profile magazine")?;
        let reload_time = row
            .at(3)
            .try_to::<f64>()
            .map_err(|_| "invalid profile reload")?;
        let protection = row
            .at(4)
            .try_to::<i32>()
            .map_err(|_| "invalid profile armor")?;
        if !(-1..=1_000_000).contains(&ammunition)
            || !(0..=1_000_000).contains(&magazine)
            || !reload_time.is_finite()
            || !(0.0..=3600.0).contains(&reload_time)
            || !(0..=100).contains(&protection)
        {
            return Err("invalid squad profile values");
        }
        match ctx.actors.get(id) {
            Some(Actor::Soldier(_)) => {
                weapons.insert(
                    id,
                    (ammunition >= 0).then_some(Weapon {
                        ammunition,
                        magazine,
                        reload_time,
                    }),
                );
            }
            Some(Actor::Vehicle(v)) => {
                armor.insert(v.kind.clone(), protection);
            }
            _ => return Err("missing squad profile actor"),
        }
    }
    if ctx.actors.iter().any(|a| match a {
        Actor::Soldier(s) => !weapons.contains_key(&s.identity.id),
        Actor::Vehicle(v) => !armor.contains_key(&v.kind),
        _ => false,
    }) {
        return Err("missing squad definition");
    }
    let plans = saved
        .iter_shared()
        .map(|b| AttackPlan::restore(b.as_slice()))
        .collect::<Result<Vec<_>, _>>()?;
    let mut reports = vec![];
    for row in impacts.iter_shared() {
        let row = row
            .try_to::<Array<Variant>>()
            .map_err(|_| "invalid impact")?;
        if row.len() != 2 {
            return Err("invalid impact width");
        }
        let at = row
            .at(0)
            .try_to::<Vector3>()
            .map_err(|_| "invalid impact position")?;
        let time = row
            .at(1)
            .try_to::<f64>()
            .map_err(|_| "invalid impact time")?;
        if !at.is_finite()
            || at.abs().max_axis().is_none()
            || at.x.abs().max(at.y.abs()).max(at.z.abs()) > 1e6
            || !time.is_finite()
            || time.abs() > 1e12
        {
            return Err("invalid impact values");
        }
        reports.push(Report {
            position: crate::point(at),
            time,
        });
    }
    let p = Profile {
        plans: &plans,
        impacts: &reports,
        armor: &|k| armor.get(k).copied().unwrap_or(0),
        weapon: &|s| weapons[&s.identity.id],
    };
    Ok(match op {
        12 => {
            ctx.squad_morale_tick(id, dt, &p)?;
            (true, vec![])
        }
        13 => ctx.squad_think(id, &p)?,
        14 => (true, ctx.squad_ambush_tick(id)?),
        15 => (true, ctx.squad_share_ammo(id, &p)?),
        16 => (true, ctx.squad_retreat(id)?),
        _ => unreachable!(),
    })
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

fn apply_ambush(
    ctx: &mut Context<'_>,
    id: u32,
    op: i32,
    input: Array<Variant>,
) -> Result<
    (
        frontline_core::ambush_plan::AmbushPlan,
        Vec<frontline_core::squad_brain::Event>,
    ),
    &'static str,
> {
    use frontline_core::ambush_plan::AmbushPlan;
    if op == 24 && input.len() == 4 {
        let (Ok(plan), Ok(zone), Ok(road), Ok(side)) = (
            input.at(0).try_to::<u32>(),
            input.at(1).try_to::<Vector3>(),
            input.at(2).try_to::<Vector3>(),
            input.at(3).try_to::<Vector3>(),
        ) else {
            return Err("invalid ambush order");
        };
        return AmbushPlan::make(
            ctx,
            plan,
            id,
            crate::point(zone),
            crate::point(road),
            crate::point(side),
        );
    }
    if op == 25 && input.len() == 2 {
        let (Ok(bytes), Ok(rows)) = (
            input.at(0).try_to::<PackedByteArray>(),
            input.at(1).try_to::<Array<Variant>>(),
        ) else {
            return Err("invalid ambush input");
        };
        if rows.len() > 1_000_000 {
            return Err("ambush profile limit exceeded");
        }
        let mut air = BTreeMap::new();
        for row in rows.iter_shared() {
            let row = row
                .try_to::<Array<Variant>>()
                .map_err(|_| "invalid ambush profile")?;
            if row.len() != 2 {
                return Err("invalid ambush profile");
            }
            let (Ok(id), Ok(value)) = (row.at(0).try_to::<u32>(), row.at(1).try_to::<bool>())
            else {
                return Err("invalid ambush profile");
            };
            let Some(Actor::Vehicle(v)) = ctx.actors.get(id) else {
                return Err("unknown ambush vehicle");
            };
            if air
                .insert(v.kind.clone(), value)
                .is_some_and(|old| old != value)
            {
                return Err("inconsistent aircraft profile");
            }
        }
        if ctx
            .actors
            .iter()
            .any(|a| matches!(a,Actor::Vehicle(v) if !air.contains_key(&v.kind)))
        {
            return Err("missing ambush vehicle profile");
        }
        let mut p = AmbushPlan::restore(bytes.as_slice())?;
        if p.squad != id {
            return Err("wrong ambush squad");
        }
        let out = p.tick(ctx, &|kind| air.get(kind).copied().unwrap_or(false))?;
        return Ok((p, out));
    }
    Err("invalid ambush operation")
}
