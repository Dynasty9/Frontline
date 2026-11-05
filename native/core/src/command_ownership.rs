//! Queued reinforcements remain reclaimable by the commander who ordered them.
use crate::actors::Actors;
use crate::state_codec::{Reader, Writer};
use std::collections::HashSet;
const LIMIT: usize = 100_000;
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct Away {
    pub peer: i32,
    pub squads: Vec<u32>,
    pub vehicles: Vec<u32>,
}
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct Ownership {
    pub players: Vec<(i32, i8)>,
    pub away: Vec<Away>,
}
pub fn acting_owner(players: &[(i32, i8)], peer: i32, team: i8) -> i32 {
    if peer <= 0 || players.iter().any(|p| p.0 == peer) {
        peer
    } else {
        players
            .iter()
            .rev()
            .find(|p| p.1 == team)
            .map_or(-1 - i32::from(team), |p| p.0)
    }
}
fn ids_valid(ids: &[u32]) -> bool {
    let mut seen = HashSet::new();
    ids.len() <= LIMIT && ids.iter().all(|id| *id != 0 && seen.insert(id))
}
impl Ownership {
    pub fn valid(&self) -> bool {
        let mut peers = HashSet::new();
        let mut absent = HashSet::new();
        self.players.len() <= LIMIT
            && self.away.len() <= LIMIT
            && self
                .players
                .iter()
                .all(|&(p, t)| p > 0 && (-1..=1).contains(&t) && peers.insert(p))
            && self.away.iter().all(|a| {
                a.peer > 0
                    && absent.insert(a.peer)
                    && ids_valid(&a.squads)
                    && ids_valid(&a.vehicles)
            })
    }
    pub fn acting_owner(&self, peer: i32, team: i8) -> i32 {
        acting_owner(&self.players, peer, team)
    }
    pub fn hold_squad(&mut self, peer: i32, squad: u32) -> Result<(), &'static str> {
        if let Some(a) = self.away.iter_mut().find(|a| a.peer == peer) {
            if !a.squads.contains(&squad) {
                if squad == 0 || a.squads.len() >= LIMIT {
                    return Err("held squad limit exceeded");
                }
                a.squads.push(squad);
            }
        }
        Ok(())
    }
    pub fn hold_vehicle(
        &mut self,
        peer: i32,
        id: u32,
        actors: &Actors,
    ) -> Result<(), &'static str> {
        let Some(a) = self.away.iter_mut().find(|a| a.peer == peer) else {
            return Ok(());
        };
        let v = actors.vehicle(id).ok_or("missing held vehicle")?;
        let mut squads = a.squads.clone();
        for s in v.passengers.iter().filter_map(|&id| actors.soldier(id)) {
            let sid = s.identity.squad;
            if sid != 0 && !squads.contains(&sid) {
                squads.push(sid);
            }
        }
        if squads.len() > LIMIT || !a.vehicles.contains(&id) && a.vehicles.len() >= LIMIT {
            return Err("held force limit exceeded");
        }
        a.squads = squads;
        if !a.vehicles.contains(&id) {
            a.vehicles.push(id);
        }
        Ok(())
    }
    pub fn checkpoint(&self) -> Result<Vec<u8>, &'static str> {
        if !self.valid() {
            return Err("invalid command ownership");
        }
        let mut w = Writer::new(b"FLOW\x01\0\0\0");
        w.u32(self.players.len() as u32);
        for &(p, t) in &self.players {
            w.u32(p as u32);
            w.byte(t as u8);
        }
        w.u32(self.away.len() as u32);
        for a in &self.away {
            w.u32(a.peer as u32);
            for ids in [&a.squads, &a.vehicles] {
                w.u32(ids.len() as u32);
                for &id in ids {
                    w.u32(id);
                }
            }
        }
        Ok(w.0)
    }
    pub fn restore(bytes: &[u8]) -> Result<Self, &'static str> {
        let mut r = Reader::new(bytes, b"FLOW\x01\0\0\0")?;
        let mut out = Self::default();
        let n = r.u32()?;
        if n as usize > LIMIT {
            return Err("peer limit exceeded");
        }
        for _ in 0..n {
            out.players.push((r.u32()? as i32, r.byte()? as i8));
        }
        let n = r.u32()?;
        if n as usize > LIMIT {
            return Err("absent peer limit exceeded");
        }
        for _ in 0..n {
            let mut a = Away {
                peer: r.u32()? as i32,
                ..Default::default()
            };
            for ids in [&mut a.squads, &mut a.vehicles] {
                let n = r.u32()?;
                if n as usize > LIMIT {
                    return Err("held force limit exceeded");
                }
                for _ in 0..n {
                    ids.push(r.u32()?);
                }
            }
            out.away.push(a);
        }
        r.finish()?;
        if !out.valid() {
            return Err("invalid command ownership");
        }
        Ok(out)
    }
}
