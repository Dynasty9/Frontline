//! Fixture definitions and rule snapshots; the production dispatcher itself has no engine calls.
use frontline_core::command_ownership::{Away, Ownership};
use frontline_core::economy::Economy;
use frontline_core::infantry_spawn::Loadout;
use frontline_core::squad_birth::Definition;
use frontline_core::structure_production::{Event, Product};
use frontline_core::vehicle_birth;
use godot::prelude::*;
fn read<T: FromGodot>(a: &Array<Variant>, i: usize) -> Option<T> {
    a.get(i)?.try_to().ok()
}
pub(crate) fn state(a: &Array<Variant>) -> Option<(Economy, Ownership)> {
    if a.len() != 3 {
        return None;
    }
    let upgrades: Array<Variant> = read(a, 0)?;
    let peers: PackedInt64Array = read(a, 1)?;
    let away: Array<Variant> = read(a, 2)?;
    if upgrades.len() != 2 || peers.len() > 200_000 || peers.len() % 2 != 0 || away.len() > 100_000
    {
        return None;
    }
    let mut e = Economy::default();
    let mut o = Ownership::default();
    for (i, keys) in upgrades.iter_shared().enumerate() {
        e.upgrades[i] = keys
            .try_to::<PackedStringArray>()
            .ok()?
            .as_slice()
            .iter()
            .map(|s| s.to_string())
            .collect();
    }
    for p in peers.as_slice().chunks_exact(2) {
        o.players
            .push((i32::try_from(p[0]).ok()?, i8::try_from(p[1]).ok()?));
    }
    for value in away.iter_shared() {
        let row: Array<Variant> = value.try_to().ok()?;
        if row.len() != 3 {
            return None;
        }
        let ids = |i| -> Option<Vec<u32>> {
            let a: PackedInt64Array = read(&row, i)?;
            if a.len() > 100_000 {
                return None;
            }
            a.as_slice()
                .iter()
                .map(|&v| u32::try_from(v).ok())
                .collect()
        };
        o.away.push(Away {
            peer: read(&row, 0)?,
            squads: ids(1)?,
            vehicles: ids(2)?,
        });
    }
    (e.valid() && o.valid()).then_some((e, o))
}
pub(crate) fn values(e: &Economy, o: &Ownership) -> Array<Variant> {
    let upgrades: Array<Variant> = e
        .upgrades
        .iter()
        .map(|keys| {
            keys.iter()
                .map(|s| GString::from(s.as_str()))
                .collect::<PackedStringArray>()
                .to_variant()
        })
        .collect();
    let peers: PackedInt64Array = o
        .players
        .iter()
        .flat_map(|&(p, t)| [i64::from(p), i64::from(t)])
        .collect();
    let away: Array<Variant> = o
        .away
        .iter()
        .map(|a| {
            let squads: PackedInt64Array = a.squads.iter().map(|&i| i64::from(i)).collect();
            let vehicles: PackedInt64Array = a.vehicles.iter().map(|&i| i64::from(i)).collect();
            varray![a.peer, &squads, &vehicles].to_variant()
        })
        .collect();
    varray![&upgrades, &peers, &away]
}
pub(crate) struct Squad {
    key: String,
    name: String,
    members: Vec<Loadout>,
}
impl Squad {
    fn parse(a: &Array<Variant>) -> Option<Self> {
        if a.len() != 3 {
            return None;
        }
        let members: Array<Variant> = read(a, 2)?;
        if members.len() > 4096 {
            return None;
        }
        Some(Self {
            key: read::<GString>(a, 0)?.to_string(),
            name: read::<GString>(a, 1)?.to_string(),
            members: members
                .iter_shared()
                .map(|r| crate::actors::birth_loadout(&r.try_to::<Array<Variant>>().ok()?))
                .collect::<Option<_>>()?,
        })
    }
    fn view(&self) -> Definition<'_> {
        Definition {
            kind: &self.key,
            name: &self.name,
            members: &self.members,
            armor_upgrade: false,
            grenade_upgrade: false,
        }
    }
}
pub(crate) enum Item {
    Squad(Squad),
    Vehicle {
        key: String,
        base: String,
        hp: f64,
        hull: frontline_core::vector::Vector3,
        missiles: [i32; 2],
        name: String,
        cap: u32,
        air: bool,
        supply: bool,
        automatic: bool,
        passengers: Option<Squad>,
    },
    Research(String, String),
}
impl Item {
    pub(crate) fn parse(a: &Array<Variant>) -> Option<Self> {
        match read::<u8>(a, 0)? {
            0 if a.len() == 2 => Some(Self::Squad(Squad::parse(&read(a, 1)?)?)),
            1 if a.len() == 13 => {
                let rows: Array<Variant> = read(a, 12)?;
                Some(Self::Vehicle {
                    key: read::<GString>(a, 1)?.to_string(),
                    base: read::<GString>(a, 2)?.to_string(),
                    hp: read(a, 3)?,
                    hull: crate::point(read(a, 4)?),
                    missiles: [read(a, 5)?, read(a, 6)?],
                    name: read::<GString>(a, 7)?.to_string(),
                    cap: read(a, 8)?,
                    air: read(a, 9)?,
                    supply: read(a, 10)?,
                    automatic: read(a, 11)?,
                    passengers: if rows.is_empty() {
                        None
                    } else {
                        Some(Squad::parse(&rows)?)
                    },
                })
            }
            2 if a.len() == 3 => Some(Self::Research(
                read::<GString>(a, 1)?.to_string(),
                read::<GString>(a, 2)?.to_string(),
            )),
            _ => None,
        }
    }
    pub(crate) fn members(&self) -> &[Loadout] {
        match self {
            Self::Squad(q) => &q.members,
            Self::Vehicle {
                passengers: Some(q),
                ..
            } => &q.members,
            _ => &[],
        }
    }
    pub(crate) fn view(&self) -> Product<'_> {
        match self {
            Self::Squad(q) => Product::Squad(q.view()),
            Self::Vehicle {
                key,
                base,
                hp,
                hull,
                missiles,
                name,
                cap,
                air,
                supply,
                automatic,
                passengers,
            } => Product::Vehicle {
                definition: vehicle_birth::Definition {
                    kind: key,
                    base,
                    hp: *hp,
                    hull: *hull,
                    missiles: *missiles,
                },
                name,
                cap: *cap,
                air: *air,
                supply: *supply,
                automatic: *automatic,
                passengers: passengers.as_ref().map(Squad::view),
            },
            Self::Research(key, name) => Product::Research { key, name },
        }
    }
}
pub(crate) fn event(e: &Event) -> Variant {
    match e {
        Event::CapWarning { peer, team } => varray![0, *peer, i32::from(*team)].to_variant(),
        Event::Squad(id) => varray![1, *id].to_variant(),
        Event::Vehicle(id) => varray![2, *id].to_variant(),
        Event::Research { team, name } => {
            varray![3, i32::from(*team), &GString::from(name.as_str())].to_variant()
        }
        Event::Ready { team, name } => {
            varray![4, i32::from(*team), &GString::from(name.as_str())].to_variant()
        }
        Event::Movement(e) => varray![5, &crate::squad_movement::event(e.clone())].to_variant(),
    }
}
