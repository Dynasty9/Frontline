use crate::production::{self, Item};
use frontline_core::economy::Economy;
use frontline_core::fog::Fog;
use frontline_core::prisoner_intelligence::PrisonerIntelligence;
use frontline_core::rules_logistics::TruckProfile;
use frontline_core::rules_world::{Event, PrisonerProfile, Profiles, Rules};
use frontline_core::structure_production::Product;
use frontline_core::structure_world::Victory;
use frontline_core::supply_network::SupplyNetwork;
use frontline_core::support_calls::SupportCalls;
use frontline_core::world::WorldContext;
use godot::prelude::*;
use std::collections::HashMap;
fn read<T: FromGodot>(a: &Array<Variant>, i: usize) -> Option<T> {
    a.get(i)?.try_to().ok()
}
fn bytes(a: &Array<Variant>, i: usize) -> Option<PackedByteArray> {
    read(a, i)
}
fn vector(p: frontline_core::vector::Vector3) -> Vector3 {
    Vector3::new(p.x, p.y, p.z)
}
#[derive(GodotClass)]
#[class(base=RefCounted,init)]
pub(crate) struct RulesWorldCore {
    base: Base<RefCounted>,
    pub(crate) core: Rules,
}
#[godot_api]
impl RulesWorldCore {
    #[func]
    fn load_state(&mut self, a: Array<Variant>) -> bool {
        let parse = || -> Option<Rules> {
            if a.len() != 8 {
                return None;
            }
            let upgrades: Array<Variant> = read(&a, 1)?;
            let times: PackedFloat64Array = read(&a, 5)?;
            let income: Array<Variant> = read(&a, 6)?;
            let names: PackedInt64Array = read(&a, 7)?;
            if upgrades.len() != 2 || times.len() != 4 || income.len() != 2 || names.len() != 2 {
                return None;
            }
            let mut e = Economy::default();
            for (i, side) in upgrades.iter_shared().enumerate() {
                let keys: PackedStringArray = side.try_to().ok()?;
                if keys.len() > 100_000 {
                    return None;
                }
                e.upgrades[i] = keys.as_slice().iter().map(ToString::to_string).collect();
            }
            let mut r = Rules {
                network: SupplyNetwork::restore(bytes(&a, 0)?.as_slice()).ok()?,
                economy: e,
                fog: Fog::restore(bytes(&a, 2)?.as_slice()).ok()?,
                support: SupportCalls::restore(bytes(&a, 3)?.as_slice()).ok()?,
                prisoners: PrisonerIntelligence::restore(bytes(&a, 4)?.as_slice()).ok()?,
                visibility_timer: times[0],
                second_timer: times[1],
                reserve_at: [times[2], times[3]],
                fob_names_used: [u64::try_from(names[0]).ok()?, u64::try_from(names[1]).ok()?],
                ..Default::default()
            };
            for (i, side) in income.iter_shared().enumerate() {
                let rows: Array<Variant> = side.try_to().ok()?;
                if rows.len() > 100_000 {
                    return None;
                }
                for row in rows.iter_shared() {
                    let row: Array<Variant> = row.try_to().ok()?;
                    if row.len() != 2 {
                        return None;
                    }
                    r.income[i].push((read(&row, 0)?, read(&row, 1)?));
                }
            }
            r.checkpoint().ok()?;
            Some(r)
        };
        if let Some(core) = parse() {
            self.core = core;
            true
        } else {
            false
        }
    }
    #[func]
    fn values(&self) -> Array<Variant> {
        let r = &self.core;
        let upgrades: Array<Variant> = r
            .economy
            .upgrades
            .iter()
            .map(|s| {
                s.iter()
                    .map(GString::from)
                    .collect::<PackedStringArray>()
                    .to_variant()
            })
            .collect();
        let income: Array<Variant> = r
            .income
            .iter()
            .map(|s| {
                s.iter()
                    .map(|(t, n)| varray![*t, *n].to_variant())
                    .collect::<Array<Variant>>()
                    .to_variant()
            })
            .collect();
        varray![
            &PackedByteArray::from(r.network.checkpoint().unwrap().as_slice()),
            &upgrades,
            &PackedByteArray::from(r.fog.checkpoint().unwrap().as_slice()),
            &PackedByteArray::from(r.support.checkpoint().unwrap().as_slice()),
            &PackedByteArray::from(r.prisoners.checkpoint().as_slice()),
            &PackedFloat64Array::from(
                [
                    r.visibility_timer,
                    r.second_timer,
                    r.reserve_at[0],
                    r.reserve_at[1]
                ]
                .as_slice()
            ),
            &income,
            &PackedInt64Array::from(
                [r.fob_names_used[0] as i64, r.fob_names_used[1] as i64].as_slice()
            )
        ]
    }
    #[func]
    fn checkpoint(&self) -> PackedByteArray {
        self.core
            .checkpoint()
            .map_or_else(|_| PackedByteArray::new(), |b| b.as_slice().into())
    }
    #[func]
    fn restore(&mut self, b: PackedByteArray) -> bool {
        if let Ok(core) = Rules::restore(b.as_slice()) {
            self.core = core;
            true
        } else {
            false
        }
    }
}
pub(crate) fn advance(
    context: &mut WorldContext<'_>,
    input: Array<Variant>,
    rules: &mut Rules,
    known_unit: impl Fn(&str) -> bool,
) -> Option<(i8, Vec<Event>)> {
    if input.len() != 15 {
        return None;
    }
    let dt: f64 = read(&input, 0)?;
    let scenario: bool = read(&input, 1)?;
    let mut victory = Victory {
        winner: read(&input, 2)?,
        mission: read(&input, 3)?,
    };
    let rows: Array<Variant> = read(&input, 4)?;
    if rows.len() != 2 {
        return None;
    }
    let defs = [
        Item::parse(&read(&rows, 0)?)?,
        Item::parse(&read(&rows, 1)?)?,
    ];
    if defs
        .iter()
        .any(|p| p.members().iter().any(|m| !known_unit(&m.unit)))
    {
        return None;
    }
    let [Product::Squad(a), Product::Squad(b)] = defs.each_ref().map(Item::view) else {
        return None;
    };
    let squad_names = [a.name, b.name];
    let truck = Item::parse(&read(&input, 5)?)?;
    let Product::Vehicle { definition, .. } = truck.view() else {
        return None;
    };
    let loads: PackedInt64Array = read(&input, 6)?;
    let stocks: PackedFloat64Array = read(&input, 7)?;
    let supplies: PackedInt64Array = read(&input, 8)?;
    if [loads.len(), stocks.len(), supplies.len()]
        .into_iter()
        .any(|n| n != 2)
    {
        return None;
    }
    let (economy, owners) = production::state(&read(&input, 9)?)?;
    if economy != rules.economy {
        return None;
    }
    let vehicles = crate::fog::profiles(read(&input, 10)?, context.actors)?;
    let rows: Array<Variant> = read(&input, 11)?;
    if rows.len() > 100_000 {
        return None;
    }
    let mut weapons = HashMap::new();
    for row in rows.iter_shared() {
        let row: Array<Variant> = row.try_to().ok()?;
        if row.len() != 3 {
            return None;
        }
        let key = read::<GString>(&row, 0)?.to_string();
        let weapon = read::<GString>(&row, 1)?.to_string();
        let mag: i32 = read(&row, 2)?;
        if key.len() > 128
            || weapon.len() > 128
            || !(0..=1_000_000).contains(&mag)
            || weapons.insert(key, (weapon, mag)).is_some()
        {
            return None;
        }
    }
    if context.actors.iter().any(|a|matches!(a,frontline_core::actors::Actor::Soldier(s) if !weapons.contains_key(&s.identity.unit))) || defs.iter().any(|d|d.members().iter().any(|m|!weapons.contains_key(&m.unit))){return None;}
    let names: VarDictionary = read(&input, 12)?;
    let items: VarDictionary = read(&input, 13)?;
    if names.len() > 1_000_000 || items.len() > 100_000 {
        return None;
    }
    let names: Option<HashMap<u32, String>> = names
        .iter_shared()
        .map(|(k, v)| Some((k.try_to().ok()?, v.try_to::<GString>().ok()?.to_string())))
        .collect();
    let names = names?;
    let items: Option<HashMap<String, String>> = items
        .iter_shared()
        .map(|(k, v)| {
            Some((
                k.try_to::<GString>().ok()?.to_string(),
                v.try_to::<GString>().ok()?.to_string(),
            ))
        })
        .collect();
    let items = items?;
    let commanders: PackedInt64Array = read(&input, 14)?;
    if commanders.len() % 2 != 0 || commanders.len() > 200_000 {
        return None;
    }
    let commanders: Option<Vec<_>> = commanders
        .as_slice()
        .chunks_exact(2)
        .map(|p| Some((i8::try_from(p[0]).ok()?, u32::try_from(p[1]).ok()?)))
        .collect();
    let commanders = commanders?;
    let events = context
        .advance_rules(
            dt,
            rules,
            &owners,
            &mut victory,
            scenario,
            Profiles {
                reserves: [a, b],
                truck: TruckProfile {
                    vehicle: definition,
                    town_load: [i32::try_from(loads[0]).ok()?, i32::try_from(loads[1]).ok()?],
                    town_stock: [stocks[0], stocks[1]],
                    supply: [
                        i32::try_from(supplies[0]).ok()?,
                        i32::try_from(supplies[1]).ok()?,
                    ],
                },
                vehicle: &|v| vehicles[&v.id],
                prisoner: &|s| {
                    let (key, mag) = &weapons[&s.identity.unit];
                    PrisonerProfile {
                        weapon: (!key.is_empty()).then_some((key.as_str(), *mag)),
                        squad_name: squad_names[s.identity.team as usize],
                    }
                },
                display: &|s| names.get(&s.id).cloned().unwrap_or_else(|| s.kind.clone()),
                item_name: &|k| items.get(k).cloned().unwrap_or_else(|| k.into()),
                commanders: &commanders,
            },
        )
        .ok()?;
    Some((victory.winner, events))
}
pub(crate) fn event(e: &Event) -> Variant {
    match e {
        Event::Support(e) => {
            varray![0, &crate::support_calls::events(vec![e.clone()]).at(0)].to_variant()
        }
        Event::Visibility(ids) => varray![
            1,
            &ids.iter()
                .map(|&id| i64::from(id))
                .collect::<PackedInt64Array>()
        ]
        .to_variant(),
        Event::Logistics(e) => match e {
            frontline_core::rules_logistics::Event::Truck { id, town } => {
                varray![2, *id, *town].to_variant()
            }
            frontline_core::rules_logistics::Event::Reserves { squad, team, depot } => {
                varray![3, *squad, i32::from(*team), vector(*depot)].to_variant()
            }
            frontline_core::rules_logistics::Event::Movement(e) => {
                varray![4, &crate::squad_movement::event(e.clone())].to_variant()
            }
        },
        Event::Freed {
            id,
            team,
            name,
            position,
        } => varray![
            5,
            *id,
            i32::from(*team),
            &GString::from(name.as_str()),
            vector(*position)
        ]
        .to_variant(),
        Event::Intelligence(i) => varray![
            6,
            i32::from(i.team),
            &GString::from(i.text.as_str()),
            &i.fact
                .position
                .map_or(Variant::nil(), |p| vector(p).to_variant())
        ]
        .to_variant(),
        Event::Winner(team) => varray![7, i32::from(*team)].to_variant(),
        Event::Captor(id) => varray![8, *id].to_variant(),
    }
}
