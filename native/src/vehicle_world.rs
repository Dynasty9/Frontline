//! Input and effect conversion for the complete-vehicle reference test.
use frontline_core::attack_plan::AttackPlan;
use frontline_core::infantry_supply::Loadout;
use frontline_core::vehicle_artillery::ArtilleryProfile;
use frontline_core::vehicle_motion::GroundProfile;
use frontline_core::vehicle_scan::ScanProfile;
use frontline_core::vehicle_service::Service;
use godot::prelude::*;
use std::collections::{BTreeMap, BTreeSet, HashMap};

pub(crate) struct Input {
    pub movement: GroundProfile,
    pub scan: ScanProfile,
    pub traverse: [f64; 2],
    pub artillery: Option<(ArtilleryProfile, [f64; 2])>,
    pub service: Option<Service>,
    pub stock: HashMap<u32, (Option<Loadout>, String, i32)>,
    pub missiles: BTreeMap<u32, [i32; 2]>,
    pub owned: Vec<u32>,
    pub mission: bool,
    pub cannons: BTreeSet<u32>,
    pub plans: Vec<AttackPlan>,
    pub next: u64,
    pub light: bool,
}
fn read<T: FromGodot>(a: &Array<Variant>, i: usize) -> Option<T> {
    a.get(i)?.try_to().ok()
}
fn ids(a: PackedInt64Array) -> Option<Vec<u32>> {
    if a.len() > 100_000 {
        return None;
    }
    a.as_slice()
        .iter()
        .map(|&id| u32::try_from(id).ok().filter(|&id| id != 0))
        .collect()
}
fn scan_profile(scan: PackedFloat64Array) -> Option<ScanProfile> {
    if scan.len() != 6 || scan.as_slice()[2..].iter().any(|v| *v != 0.0 && *v != 1.0) {
        return None;
    }
    Some(ScanProfile {
        sight: scan[0],
        gun_height: scan[1],
        cannon: scan[2] != 0.0,
        gunship: scan[3] != 0.0,
        anti_air: scan[4] != 0.0,
        penetrating_mg: scan[5] != 0.0,
    })
}
fn read_plans(rows: Array<Variant>) -> Option<Vec<AttackPlan>> {
    if rows.len() > 100_000 {
        return None;
    }
    let mut plans = vec![];
    let mut seen = BTreeSet::new();
    for row in rows.iter_shared() {
        let bytes = row.try_to::<PackedByteArray>().ok()?;
        let p = AttackPlan::restore(bytes.as_slice()).ok()?;
        if !seen.insert(p.id) {
            return None;
        }
        plans.push(p);
    }
    Some(plans)
}
pub(crate) struct AirInput {
    pub kind: frontline_core::aircraft_world::Kind,
    pub flight: frontline_core::vehicle_flight::FlightProfile,
    pub scan: ScanProfile,
    pub traverse: [f64; 2],
    pub plans: Vec<AttackPlan>,
    pub next: u64,
    pub income: [Vec<(f64, i32)>; 2],
}
pub(crate) fn parse_air(a: &Array<Variant>) -> Option<AirInput> {
    use frontline_core::aircraft_world::Kind;
    if a.len() != 9 {
        return None;
    }
    let flight = crate::vehicle::flight_profile(&read(a, 0)?)?;
    let scan = scan_profile(read(a, 1)?)?;
    let traverse: PackedFloat64Array = read(a, 2)?;
    let values: PackedFloat64Array = read(a, 4)?;
    if traverse.len() != 2 || values.len() != 2 || values.as_slice().iter().any(|n| !n.is_finite())
    {
        return None;
    }
    let kind = match read::<GString>(a, 3)?.to_string().as_str() {
        "lift_heli" if values[0].fract() == 0.0 && (-1.0..=2.0).contains(&values[0]) => {
            Kind::Lift {
                capacity: values[0] as i8,
            }
        }
        "supply" if values[0].fract() == 0.0 && (0.0..=1_000_000.0).contains(&values[0]) => {
            Kind::Supply {
                load: values[0] as i32,
            }
        }
        "attack_heli" if values[0].fract() == 0.0 && (0.0..=10000.0).contains(&values[0]) => {
            Kind::Gunship {
                rockets: values[0] as u32,
            }
        }
        "uav" => Kind::Uav {
            altitude: values[0],
            radius: values[1],
        },
        _ => return None,
    };
    let mut income = [vec![], vec![]];
    for (side, out) in income.iter_mut().enumerate() {
        let rows: Array<Variant> = read(a, 7 + side)?;
        if rows.len() >= 100_000 {
            return None;
        }
        for row in rows.iter_shared() {
            let r = row.try_to::<Array<Variant>>().ok()?;
            if r.len() != 2 {
                return None;
            }
            let t: f64 = read(&r, 0)?;
            let n: i32 = read(&r, 1)?;
            if !t.is_finite() || t.abs() > 1e12 || !(0..=1_000_000).contains(&n) {
                return None;
            }
            out.push((t, n));
        }
    }
    Some(AirInput {
        kind,
        flight,
        scan,
        traverse: [traverse[0], traverse[1]],
        plans: read_plans(read(a, 5)?)?,
        next: u64::try_from(read::<i64>(a, 6)?).ok()?,
        income,
    })
}
pub(crate) fn parse(a: &Array<Variant>) -> Option<Input> {
    if a.len() != 11 {
        return None;
    }
    let movement = crate::vehicle::ground_profile(&read(a, 0)?)?;
    let scan = scan_profile(read(a, 1)?)?;
    let traverse: PackedFloat64Array = read(a, 2)?;
    if traverse.len() != 2 {
        return None;
    }
    let art: Array<Variant> = read(a, 3)?;
    let artillery = if art.is_empty() {
        None
    } else {
        let profile = crate::actors::artillery_profile(&read(&art, 0)?)?;
        let range: PackedFloat64Array = read(&art, 1)?;
        if art.len() != 2 || range.len() != 2 {
            return None;
        }
        Some((profile, [range[0], range[1]]))
    };
    let service_data: Array<Variant> = read(a, 4)?;
    let (mut stock, mut missiles) = (HashMap::new(), BTreeMap::new());
    let service = if service_data.is_empty() {
        None
    } else {
        if service_data.len() != 3 {
            return None;
        }
        let service = match read::<GString>(&service_data, 0)?.to_string().as_str() {
            "repair" => Service::Repair,
            "ammo" => Service::Ammo,
            "medical" => Service::Medical,
            _ => return None,
        };
        stock = crate::actors::service_stock(read(&service_data, 1)?)?;
        let rows: Array<Variant> = read(&service_data, 2)?;
        if rows.len() > 100_000 {
            return None;
        }
        for row in rows.iter_shared() {
            let r = row.try_to::<PackedInt64Array>().ok()?;
            if r.len() != 3 || !(0..=1_000_000).contains(&r[1]) || !(0..=1_000_000).contains(&r[2])
            {
                return None;
            }
            let id = u32::try_from(r[0]).ok()?;
            if id == 0 || missiles.insert(id, [r[1] as i32, r[2] as i32]).is_some() {
                return None;
            }
        }
        Some(service)
    };
    let plans = read_plans(read(a, 8)?)?;
    Some(Input {
        movement,
        scan,
        traverse: [traverse[0], traverse[1]],
        artillery,
        service,
        stock,
        missiles,
        owned: ids(read(a, 5)?)?,
        mission: read(a, 6)?,
        cannons: ids(read(a, 7)?)?.into_iter().collect(),
        plans,
        next: u64::try_from(read::<i64>(a, 9)?).ok()?,
        light: read(a, 10)?,
    })
}
pub(crate) fn effects(
    events: Vec<frontline_core::vehicle_world::Event>,
    extra: &mut Array<Variant>,
) -> Vec<frontline_core::vehicle_combat_world::Event> {
    use frontline_core::attack_plan::Event as Attack;
    use frontline_core::infantry_fight_world::Event as Fight;
    use frontline_core::squad_movement::Event as Squad;
    use frontline_core::vehicle_combat_world::Event as Combat;
    use frontline_core::vehicle_movement_world::Event as Motion;
    use frontline_core::vehicle_world::Event;
    use frontline_core::world_combat::Event as World;
    events
        .into_iter()
        .filter_map(|e| {
            let world = match e {
                Event::Combat(e) => return Some(e),
                Event::Sling {
                    helicopter,
                    cargo,
                    released,
                } => {
                    extra.push(&varray!["sling", helicopter, cargo, released].to_variant());
                    return None;
                }
                Event::Delivered {
                    team,
                    position,
                    amount,
                } => {
                    extra.push(
                        &varray![
                            "delivered",
                            Vector3::new(position.x, position.y, position.z),
                            amount,
                            team
                        ]
                        .to_variant(),
                    );
                    return None;
                }

                Event::Loss(e) | Event::Movement(Motion::Loss(e)) => World::Vehicle(e),
                Event::Movement(Motion::Stat(key))
                | Event::Attack(Attack::Stat(key))
                | Event::Attack(Attack::Squad(Squad::Stat(key))) => World::Stat(key),
                Event::Movement(Motion::Track(id)) => {
                    extra.push(&varray!["track", id].to_variant());
                    return None;
                }
                Event::Movement(Motion::Smashed { structure, .. }) => {
                    extra.push(&varray!["smash", structure.id].to_variant());
                    return None;
                }
                Event::Movement(Motion::Crew { .. }) => return None,
                Event::Attack(Attack::Speech { soldier, text }) => {
                    return Some(Combat::Combat(Fight::Speech { id: soldier, text }))
                }
                Event::Attack(Attack::Squad(Squad::Speech {
                    soldier,
                    call,
                    variant,
                })) => {
                    return Some(Combat::Combat(Fight::Speech {
                        id: soldier,
                        text: format!("@squad:{}:{variant}", call as u8),
                    }))
                }
                Event::Attack(Attack::Squad(e)) => {
                    World::Vehicle(frontline_core::vehicle_loss_world::Event::Squad(e))
                }
                Event::Attack(Attack::NeedsSupport {
                    team,
                    squad,
                    position,
                }) => {
                    extra.push(
                        &varray![
                            "needs_support",
                            team,
                            squad,
                            Vector3::new(position.x, position.y, position.z)
                        ]
                        .to_variant(),
                    );
                    return None;
                }
            };
            Some(Combat::Combat(Fight::World(world)))
        })
        .collect()
}
