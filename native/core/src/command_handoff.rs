//! Allied humans can direct a unit without stealing attribution from another human commander.
use crate::actors::{Actor, Actors};
use crate::battle_stats::BattleStats;
use crate::command_ownership::{Away, Ownership};
use crate::entities::Kind;
use crate::squad::Squad;
use std::collections::HashSet;
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct Changed {
    pub squads: Vec<u32>,
    pub vehicles: Vec<u32>,
    pub soldiers: Vec<u32>,
}
fn give_squad(q: &mut Squad, peer: i32, a: &mut Actors, out: &mut Changed) {
    q.owner = peer;
    out.squads.push(q.id);
    for &id in &q.members {
        if let Some(s) = a.soldier_mut(id) {
            s.identity.owner = peer;
            out.soldiers.push(id);
        }
    }
}
fn give_vehicle(id: u32, peer: i32, a: &mut Actors, out: &mut Changed) {
    if let Some(v) = a.vehicle_mut(id) {
        v.owner = peer;
        out.vehicles.push(id);
    }
}
impl Ownership {
    pub fn connect(&mut self, peer: i32, team: i8) -> Result<bool, &'static str> {
        if peer <= 0 || !(-1..=1).contains(&team) || !self.valid() {
            return Err("invalid connected commander");
        }
        if let Some(p) = self.players.iter().find(|p| p.0 == peer) {
            return if p.1 == team {
                Ok(false)
            } else {
                Err("commander is already connected on another side")
            };
        }
        if self.players.len() >= 100_000 {
            return Err("commander limit exceeded");
        }
        self.players.push((peer, team));
        Ok(true)
    }
    pub fn team_of(&self, peer: i32) -> i8 {
        match peer {
            -1 => 0,
            -2 => 1,
            p if p > 0 => self
                .players
                .iter()
                .find(|p| p.0 == peer)
                .map_or(-1, |p| p.1),
            _ => -1,
        }
    }
    pub fn can_command(&self, peer: i32, team: i8, owner: i32) -> bool {
        let own = self.team_of(peer);
        (0..=1).contains(&own) && team == own && (peer > 0 || owner == peer)
    }
    pub fn select_squads(
        &self,
        peer: i32,
        ids: &[u32],
        squads: &[Squad],
    ) -> Result<Vec<u32>, &'static str> {
        if ids.len() > 100_000 {
            return Err("command selection limit exceeded");
        }
        let mut seen = HashSet::new();
        Ok(ids
            .iter()
            .copied()
            .filter(|id| {
                seen.insert(*id)
                    && squads
                        .iter()
                        .any(|q| q.id == *id && self.can_command(peer, q.team, q.owner))
            })
            .collect())
    }
    pub fn select_vehicles(
        &self,
        peer: i32,
        ids: &[u32],
        actors: &Actors,
        automatic: &dyn Fn(&str) -> bool,
    ) -> Result<Vec<u32>, &'static str> {
        if ids.len() > 100_000 {
            return Err("command selection limit exceeded");
        }
        let mut seen = HashSet::new();
        Ok(ids
            .iter()
            .copied()
            .filter(|id| {
                seen.insert(*id)
                    && actors.vehicle(*id).is_some_and(|v| {
                        !automatic(&v.kind) && self.can_command(peer, v.team, v.owner)
                    })
            })
            .collect())
    }
    pub fn take_command(
        &self,
        peer: i32,
        squad_ids: &[u32],
        vehicle_ids: &[u32],
        squads: &mut [Squad],
        actors: &mut Actors,
    ) -> Result<Changed, &'static str> {
        if squad_ids.len() > 100_000 || vehicle_ids.len() > 100_000 {
            return Err("command selection limit exceeded");
        }
        let mut out = Changed::default();
        if peer <= 0 {
            return Ok(out);
        }
        for id in squad_ids {
            if let Some(q) = squads
                .iter_mut()
                .find(|q| q.id == *id && q.owner < 0 && self.can_command(peer, q.team, q.owner))
            {
                give_squad(q, peer, actors, &mut out);
            }
        }
        for &id in vehicle_ids {
            if actors
                .vehicle(id)
                .is_some_and(|v| v.owner < 0 && self.can_command(peer, v.team, v.owner))
            {
                give_vehicle(id, peer, actors, &mut out);
            }
        }
        Ok(out)
    }
    pub fn depart(
        &mut self,
        peer: i32,
        squads: &mut [Squad],
        actors: &mut Actors,
    ) -> Result<Option<(i8, i32, Changed)>, &'static str> {
        if peer <= 0 || !self.valid() {
            return Err("invalid departing commander");
        }
        let Some(i) = self.players.iter().position(|p| p.0 == peer) else {
            return Ok(None);
        };
        let team = self.players[i].1;
        if team >= 0 && self.away.len() >= 100_000 && !self.away.iter().any(|a| a.peer == peer) {
            return Err("absent commander limit exceeded");
        }
        let mut keep = Away {
            peer,
            ..Default::default()
        };
        if team >= 0 {
            keep.squads = squads
                .iter()
                .filter(|q| q.owner == peer)
                .map(|q| q.id)
                .collect();
            keep.vehicles = actors
                .iter_kind(Kind::Vehicle)
                .filter_map(|a| match a {
                    Actor::Vehicle(v) if v.owner == peer => Some(v.id),
                    _ => None,
                })
                .collect();
            if keep.squads.len() > 100_000 || keep.vehicles.len() > 100_000 {
                return Err("held force limit exceeded");
            }
        }
        self.players.remove(i);
        let next = if team < 0 {
            0
        } else {
            self.players
                .iter()
                .rev()
                .find(|p| p.1 == team)
                .map_or(-1 - i32::from(team), |p| p.0)
        };
        let mut out = Changed::default();
        if team >= 0 {
            for &id in &keep.squads {
                give_squad(
                    squads.iter_mut().find(|q| q.id == id).unwrap(),
                    next,
                    actors,
                    &mut out,
                );
            }
            for &id in &keep.vehicles {
                give_vehicle(id, next, actors, &mut out);
            }
            if let Some(current) = self.away.iter_mut().find(|a| a.peer == peer) {
                *current = keep;
            } else {
                self.away.push(keep);
            }
        }
        Ok(Some((team, next, out)))
    }
    /// The session owner authenticates the old identity before admitting this external input.
    pub fn reclaim(
        &mut self,
        peer: i32,
        old: i32,
        name: &str,
        squads: &mut [Squad],
        actors: &mut Actors,
        battle: &mut BattleStats,
        stand_down_ai: bool,
        automatic: &dyn Fn(&str) -> bool,
    ) -> Result<(u32, Changed), &'static str> {
        if peer <= 0
            || old <= 0
            || !self.valid()
            || name.is_empty()
            || name.len() > 4096
            || name.contains('\0')
        {
            return Err("invalid returning commander");
        }
        let team = self
            .players
            .iter()
            .find(|p| p.0 == peer)
            .ok_or("returning commander is not connected")?
            .1;
        if team >= 0 {
            battle.rejoined(old, peer, team, name)?;
        }
        let keep = self
            .away
            .iter()
            .position(|a| a.peer == old)
            .map(|i| self.away.remove(i));
        let mut out = Changed::default();
        let mut returned = 0;
        if team < 0 {
            return Ok((returned, out));
        }
        if let Some(keep) = keep {
            for id in keep.squads {
                if let Some(q) = squads
                    .iter_mut()
                    .find(|q| q.id == id && q.team == team && q.alive(actors).next().is_some())
                {
                    give_squad(q, peer, actors, &mut out);
                    returned += 1;
                }
            }
            for id in keep.vehicles {
                if actors.vehicle(id).is_some_and(|v| v.team == team) {
                    give_vehicle(id, peer, actors, &mut out);
                    returned += 1;
                }
            }
        }
        let ids: Vec<_> = actors
            .iter_kind(Kind::Structure)
            .map(|a| a.identity().id)
            .collect();
        for id in ids {
            let Some(Actor::Structure(st)) = actors.get_mut(id) else {
                unreachable!()
            };
            for q in &mut st.queue {
                if q.owner == old {
                    q.owner = peer;
                }
            }
        }
        if stand_down_ai {
            let ai = -1 - i32::from(team);
            for q in squads
                .iter_mut()
                .filter(|q| q.team == team && q.owner == ai)
            {
                give_squad(q, peer, actors, &mut out);
            }
            let vehicles: Vec<_> = actors
                .iter_kind(Kind::Vehicle)
                .filter_map(|a| match a {
                    Actor::Vehicle(v) if v.team == team && v.owner == ai && !automatic(&v.kind) => {
                        Some(v.id)
                    }
                    _ => None,
                })
                .collect();
            for id in vehicles {
                give_vehicle(id, peer, actors, &mut out);
            }
        }
        Ok((returned, out))
    }
}
