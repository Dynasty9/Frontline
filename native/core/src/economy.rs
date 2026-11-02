//! Supplies and research belong to the battle, including wounded men and absent commanders' orders.
use crate::actors::{Actor, Actors};
use crate::entities::Kind;
use crate::infantry::Infantry;
use crate::infantry_control::HiddenReason;
use crate::infantry_vitals::Life;
use crate::state_codec::{Reader, Writer};
use crate::structure::Structure;
use crate::vector::Vector3;
use crate::vehicle::Vehicle;
use std::collections::HashSet;

#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct Economy {
    pub upgrades: [Vec<String>; 2],
}
fn team_valid(team: i8) -> bool {
    (0..=1).contains(&team)
}
pub fn fobs(actors: &Actors, team: i8, wrecked: bool) -> impl Iterator<Item = &Structure> {
    actors
        .iter_kind(Kind::Structure)
        .filter_map(move |a| match a {
            Actor::Structure(s)
                if s.kind == "fob" && s.team == team && s.built && (wrecked || !s.wrecked) =>
            {
                Some(s.as_ref())
            }
            _ => None,
        })
}
pub fn nearest_fob(actors: &Actors, team: i8, position: Vector3) -> Option<u32> {
    let mut best = None;
    let mut distance = 1e9;
    for s in fobs(actors, team, true) {
        let delta = s.position - position;
        let d = f64::from(Vector3::new(delta.x, 0., delta.z).length())
            + if s.wrecked { 60. } else { 0. };
        if d < distance {
            best = Some(s.id);
            distance = d;
        }
    }
    best
}
pub fn capacity(actors: &Actors, team: i8, base: u32, per_fob: u32) -> u64 {
    u64::from(base) + u64::from(per_fob) * fobs(actors, team, false).count() as u64
}
pub fn used(
    actors: &Actors,
    team: i8,
    bearer: &dyn Fn(&Infantry) -> bool,
    vehicle_cap: &dyn Fn(&Vehicle) -> u32,
) -> u64 {
    actors
        .iter()
        .map(|a| match a {
            Actor::Soldier(s)
                if s.identity.team == team
                    && !bearer(s)
                    && (matches!(s.vitals.life, Life::Alive | Life::Downed)
                        || s.vitals.life == Life::Hidden
                            && matches!(
                                s.control.hidden,
                                HiddenReason::Tent
                                    | HiddenReason::TunnelWait
                                    | HiddenReason::TunnelTravel
                            )) =>
            {
                1
            }
            Actor::Vehicle(v) if v.team == team => u64::from(vehicle_cap(v)),
            _ => 0,
        })
        .sum()
}
fn structure(actors: &mut Actors, id: u32) -> &mut Structure {
    let Some(Actor::Structure(s)) = actors.get_mut(id) else {
        unreachable!()
    };
    s
}
pub fn spend(
    actors: &mut Actors,
    team: i8,
    position: Vector3,
    amount: i32,
) -> Result<bool, &'static str> {
    if !team_valid(team)
        || !crate::squad_movement::point(position)
        || !(0..=1_000_000).contains(&amount)
    {
        return Err("invalid supply payment");
    }
    let available: Vec<_> = fobs(actors, team, false)
        .map(|s| {
            let d = s.position - position;
            (
                s.id,
                f64::from(Vector3::new(d.x, 0., d.z).length()),
                s.supply,
            )
        })
        .collect();
    if available.iter().map(|v| v.2 as i64).sum::<i64>() < i64::from(amount) {
        return Ok(false);
    }
    let order = crate::godot_sort::score_order(&available.iter().map(|v| v.1).collect::<Vec<_>>());
    for &i in &order {
        if available[i].2 >= f64::from(amount) {
            structure(actors, available[i].0).supply -= f64::from(amount);
            return Ok(true);
        }
    }
    let mut left = amount;
    for i in order {
        let take = left.min(available[i].2 as i32);
        if take <= 0 {
            continue;
        }
        structure(actors, available[i].0).supply -= f64::from(take);
        left -= take;
        if left <= 0 {
            break;
        }
    }
    Ok(true)
}
pub fn refund(
    actors: &mut Actors,
    team: i8,
    position: Vector3,
    amount: i32,
) -> Result<Option<u32>, &'static str> {
    if !team_valid(team)
        || !crate::squad_movement::point(position)
        || !(0..=1_000_000).contains(&amount)
    {
        return Err("invalid supply refund");
    }
    let id = nearest_fob(actors, team, position);
    if let Some(id) = id {
        let s = structure(actors, id);
        if s.supply + f64::from(amount) > 1e12 {
            return Err("supply refund exceeds limit");
        }
        s.supply += f64::from(amount);
    }
    Ok(id)
}
impl Economy {
    pub fn valid(&self) -> bool {
        self.upgrades.iter().all(|keys| {
            let mut seen = HashSet::new();
            keys.len() <= 4096
                && keys
                    .iter()
                    .all(|k| !k.is_empty() && k.len() <= 128 && !k.contains('\0') && seen.insert(k))
        })
    }
    pub fn has_upgrade(&self, team: i8, key: &str) -> bool {
        team_valid(team) && self.upgrades[team as usize].iter().any(|k| k == key)
    }
    pub fn apply_upgrade(
        &mut self,
        actors: &mut Actors,
        team: i8,
        key: &str,
        bearer: &dyn Fn(&Infantry) -> bool,
    ) -> Result<(), &'static str> {
        if !self.valid()
            || !team_valid(team)
            || key.is_empty()
            || key.len() > 128
            || key.contains('\0')
            || (!self.has_upgrade(team, key) && self.upgrades[team as usize].len() >= 4096)
        {
            return Err("invalid research");
        }
        let ids: Vec<_> = actors
            .iter_kind(Kind::Soldier)
            .filter_map(|a| match a {
                Actor::Soldier(s) if s.identity.team == team => Some(s.identity.id),
                _ => None,
            })
            .collect();
        for &id in &ids {
            let s = actors.soldier(id).unwrap();
            if key == "armor"
                && [s.vitals.base_hp, s.vitals.max_hp, s.vitals.hp]
                    .iter()
                    .any(|v| (v * 1.2).abs() > 1e12)
                || key == "grenades" && !bearer(s) && s.grenades.frags >= 1_000_000
            {
                return Err("research exceeds soldier limits");
            }
        }
        if !self.has_upgrade(team, key) {
            self.upgrades[team as usize].push(key.into());
        }
        for id in ids {
            let s = actors.soldier_mut(id).unwrap();
            if key == "armor" {
                s.vitals.base_hp *= 1.2;
                s.vitals.max_hp *= 1.2;
                s.vitals.hp *= 1.2;
            } else if key == "grenades" && !bearer(s) {
                s.grenades.frags += 1;
            }
        }
        Ok(())
    }
    pub fn checkpoint(&self) -> Result<Vec<u8>, &'static str> {
        if !self.valid() {
            return Err("invalid economy");
        }
        let mut w = Writer::new(b"FLEC\x01\0\0\0");
        for keys in &self.upgrades {
            w.u32(keys.len() as u32);
            for k in keys {
                w.bytes(k.as_bytes());
            }
        }
        Ok(w.0)
    }
    pub fn restore(bytes: &[u8]) -> Result<Self, &'static str> {
        let mut r = Reader::new(bytes, b"FLEC\x01\0\0\0")?;
        let mut out = Self::default();
        for keys in &mut out.upgrades {
            let n = r.u32()?;
            if n > 4096 {
                return Err("research limit exceeded");
            }
            for _ in 0..n {
                keys.push(
                    std::str::from_utf8(r.bytes(128)?)
                        .map_err(|_| "invalid research name")?
                        .into(),
                );
            }
        }
        r.finish()?;
        if !out.valid() {
            return Err("invalid economy");
        }
        Ok(out)
    }
}
