//! Prisoners reveal facts in world order and remember what they have already told the enemy.
use crate::actors::{Actor, Actors};
use crate::entities::Kind;
use crate::infantry::Infantry;
use crate::infantry_prison_owned::IntelMode;
use crate::infantry_vitals::Life;
use crate::random::SimulationRandom;
use crate::spatial::{SpatialIndex, UNIT_CELL};
use crate::state_codec::{Reader, Writer};
use crate::structure::Structure;
use crate::vector::Vector3;
use std::collections::{BTreeMap, HashSet};

pub(crate) fn grid_ref(position: Vector3, map_side: u32) -> String {
    let half = f64::from(map_side) * 0.5;
    let cell = f64::from(map_side) / 8.0;
    let col = (((f64::from(position.x) + half) / cell) as i64).clamp(0, 7);
    let row = (((f64::from(position.z) + half) / cell) as i64).clamp(0, 7);
    format!("{}{}", char::from(b'A' + col as u8), row + 1)
}

#[derive(Clone, Debug, PartialEq)]
pub struct Fact {
    pub key: String,
    pub text: String,
    pub position: Option<Vector3>,
}
#[derive(Clone, Debug, PartialEq)]
pub struct Intelligence {
    pub team: i8,
    pub text: String,
    pub fact: Fact,
}
#[derive(Clone, Debug, Default, PartialEq)]
pub struct PrisonerIntelligence {
    given: BTreeMap<u32, Vec<String>>,
}
const LIMIT: usize = 1_000_000;

impl PrisonerIntelligence {
    pub fn given(&self, id: u32) -> &[String] {
        self.given.get(&id).map_or(&[], Vec::as_slice)
    }
    pub fn forget(&mut self, id: u32) {
        self.given.remove(&id);
    }
    pub fn checkpoint(&self) -> Vec<u8> {
        let mut w = Writer::new(b"FLPI\x01\0\0\0");
        w.u32(self.given.len() as u32);
        for (id, keys) in &self.given {
            w.u32(*id);
            w.u32(keys.len() as u32);
            for key in keys {
                w.bytes(key.as_bytes());
            }
        }
        w.0
    }
    pub fn restore(bytes: &[u8]) -> Result<Self, &'static str> {
        let mut r = Reader::new(bytes, b"FLPI\x01\0\0\0")?;
        let count = r.u32()? as usize;
        if count > LIMIT {
            return Err("too many prisoner histories");
        }
        let mut given = BTreeMap::new();
        let mut total = 0;
        for _ in 0..count {
            let id = r.u32()?;
            let count = r.u32()? as usize;
            if count > LIMIT {
                return Err("too many prisoner reports");
            }
            total += count;
            if id == 0 || given.contains_key(&id) || count == 0 || total > LIMIT {
                return Err("invalid prisoner history");
            }
            let mut keys = Vec::new();
            for _ in 0..count {
                let key =
                    std::str::from_utf8(r.bytes(256)?).map_err(|_| "invalid intelligence key")?;
                if key.is_empty() || key.contains('\0') {
                    return Err("invalid intelligence key");
                }
                keys.push(key.to_owned());
            }
            given.insert(id, keys);
        }
        r.finish()?;
        Ok(Self { given })
    }

    pub fn reveal(
        &mut self,
        id: u32,
        mode: IntelMode,
        actors: &Actors,
        units: &SpatialIndex,
        towns: &[u32],
        commanders: &[(i8, u32)],
        map_side: u32,
        bearer: impl Fn(&Infantry) -> bool,
        display: impl Fn(&Structure) -> String,
        item_name: impl Fn(&str) -> String,
        rng: &mut SimulationRandom,
    ) -> Result<Intelligence, &'static str> {
        let p = actors.soldier(id).ok_or("missing prisoner")?;
        if !(0..=1).contains(&p.identity.team)
            || units.cell_size() != UNIT_CELL
            || !(8..=16384).contains(&map_side)
            || towns.len() > LIMIT
            || towns.iter().copied().collect::<HashSet<_>>().len() != towns.len()
            || commanders.len() > 100_000
            || commanders.iter().any(|(team, _)| !(0..=1).contains(team))
            || self.given.values().map(Vec::len).sum::<usize>() >= LIMIT
        {
            return Err("invalid prisoner intelligence context");
        }
        let about = p.identity.team;
        let grid = |position| grid_ref(position, map_side);
        let mut facts = vec![];
        let structures: Vec<_> = actors
            .iter_kind(Kind::Structure)
            .filter_map(|a| match a {
                Actor::Structure(st) if st.team == about && st.built => Some(st.as_ref()),
                _ => None,
            })
            .collect();
        let fobs: Vec<_> = structures
            .iter()
            .copied()
            .filter(|st| st.kind == "fob")
            .collect();
        for f in &fobs {
            let count = actors
                .units_near(units, f.position, 25.0, -1)?
                .into_iter()
                .filter(|id| {
                    actors
                        .soldier(*id)
                        .is_some_and(|s| s.identity.team == about && s.vitals.life == Life::Alive)
                })
                .count();
            facts.push(Fact {
                key: format!("fob{}", f.id),
                text: format!(
                    "{} at {} has {} supply and {} men guarding it.",
                    display(f),
                    grid(f.position),
                    f.supply as i64,
                    count
                ),
                position: Some(f.position),
            });
        }
        for st in structures {
            let location = match actors.nearest_fob(about, st.position) {
                Some(f) if flat(f.position - st.position).length() < 80.0 => {
                    format!("{} of {}", compass(f.position, st.position), display(f))
                }
                _ => format!("at {}", grid(st.position)),
            };
            let (prefix, text) = match st.kind.as_str() {
                "mg_nest" => ("mg", format!("There's an MG nest {location}.")),
                "hmg_nest" => (
                    "hm",
                    format!("There's a .50 cal {location}. Don't go near it."),
                ),
                "mortar_pit" => ("mp", format!("Our mortars are dug in {location}.")),
                "bunker" => ("bk", format!("There's a bunker {location}.")),
                "at_post" => (
                    "at",
                    format!("An anti-tank post covers the approach {location}."),
                ),
                "trench" => ("tr", format!("The trenches are {location}.")),
                "watchtower" => ("wt", format!("We have a watchtower {location}.")),
                "mines" => (
                    "mn",
                    format!("There are mines at {}. Watch your step.", grid(st.position)),
                ),
                "tunnel" => (
                    "tn",
                    format!("One of the tunnel entrances is at {}.", grid(st.position)),
                ),
                "medic_tent" => ("mt", format!("Our medic tent is {location}.")),
                "barracks" | "factory" if !st.queue.is_empty() => {
                    let item = &st.queue[0].item;
                    facts.push(Fact {
                        key: format!("pq{}_{}", st.id, item),
                        text: format!(
                            "They're making {} at the {} {location}.",
                            item_name(item),
                            display(st).to_lowercase()
                        ),
                        position: Some(st.position),
                    });
                    continue;
                }
                _ => continue,
            };
            facts.push(Fact {
                key: format!("{prefix}{}", st.id),
                text,
                position: Some(st.position),
            });
        }
        for f in fobs {
            if let Some(truck) = actors.vehicle(f.truck) {
                facts.push(Fact {
                    key: format!("tr{}", truck.id),
                    text: format!(
                        "A supply truck is driving to {} right now. It's at {}.",
                        display(f),
                        grid(truck.position)
                    ),
                    position: Some(truck.position),
                });
            }
        }
        for town in towns
            .iter()
            .filter_map(|id| actors.structure(*id))
            .filter(|st| st.team == about)
        {
            facts.push(Fact {
                key: format!("tn{}", town.id),
                text: format!(
                    "We hold {}. There's {} supply in the dump there.",
                    town.name, town.supply as i64
                ),
                position: town.zone_center,
            });
            if let Some(truck) = actors.vehicle(town.truck) {
                facts.push(Fact {
                    key: format!("tt{}", truck.id),
                    text: format!(
                        "A truck is bringing supply from {}. It's at {}.",
                        town.name,
                        grid(truck.position)
                    ),
                    position: Some(truck.position),
                });
            }
        }
        let men = actors.iter_kind(Kind::Soldier).filter(|a| matches!(a, Actor::Soldier(s) if s.identity.team == about && s.vitals.life == Life::Alive && !bearer(s))).count();
        let vehicles = actors
            .iter_kind(Kind::Vehicle)
            .filter(|a| matches!(a, Actor::Vehicle(v) if v.team == about && v.kind != "truck"))
            .count();
        facts.push(Fact {
            key: "army".into(),
            text: format!("We've only got about {men} men and {vehicles} vehicles left."),
            position: None,
        });
        for (_, target) in commanders.iter().filter(|(team, _)| *team == about) {
            if let Some(st) = actors.structure(*target) {
                facts.push(Fact {
                    key: format!("plan{}", st.id),
                    text: format!("They're planning to hit {}.", display(st)),
                    position: Some(st.position),
                });
            }
        }
        if facts.iter().any(|f| {
            f.key.len() > 256
                || f.key.contains('\0')
                || f.text.len() > 16384
                || f.text.contains('\0')
        }) {
            return Err("invalid intelligence content");
        }
        let given: HashSet<_> = self.given(id).iter().collect();
        let mut pool: Vec<_> = facts.iter().filter(|f| !given.contains(&f.key)).collect();
        if pool.is_empty() {
            pool = facts.iter().collect();
        }
        let fact = pool[(rng.randi() as usize) % pool.len()].clone();
        self.given.entry(id).or_default().push(fact.key.clone());
        let openers = [
            "Okay, okay! ",
            "Please... ",
            "I'll talk! ",
            "Fine. ",
            "Don't hurt me! ",
            "",
        ];
        let opener = openers[(rng.randi() % 6) as usize];
        let tag = if mode == IntelMode::Interrogation {
            "Interrogation"
        } else {
            "Prisoner"
        };
        Ok(Intelligence {
            team: 1 - about,
            text: format!("[{tag}] {}: \"{opener}{}\"", p.identity.name, fact.text),
            fact,
        })
    }
}
fn flat(p: Vector3) -> Vector3 {
    Vector3::new(p.x, 0.0, p.z)
}
fn compass(from: Vector3, to: Vector3) -> &'static str {
    let d = to - from;
    let angle = libm::atan2(f64::from(d.x), -f64::from(d.z)).to_degrees();
    let direction = (libm::round(angle / 45.0) as i64).rem_euclid(8) as usize;
    [
        "north",
        "north-east",
        "east",
        "south-east",
        "south",
        "south-west",
        "west",
        "north-west",
    ][direction]
}
