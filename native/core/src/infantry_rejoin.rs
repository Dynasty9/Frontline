//! Recovered soldiers return to their commander's nearby section, or form a new one.
use crate::actors::Actors;
use crate::battle_stats::{BattleStats, Unit};
use crate::infantry::Goal;
use crate::infantry_orders::RouteOrder;
use crate::squad::Squad;
use crate::vector::Vector3;
use std::collections::HashSet;

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Rejoined {
    pub squad: u32,
    pub created: bool,
    pub owner_changed: Option<i32>,
    pub route: Option<RouteOrder>,
}
fn flat(p: Vector3) -> Vector3 {
    Vector3::new(p.x, 0.0, p.z)
}

impl Actors {
    pub fn rejoin_infantry(
        &mut self,
        id: u32,
        now: f64,
        players: &[(i32, i8)],
        squads: &mut Vec<Squad>,
        next_squad: &mut u64,
        battle: &mut BattleStats,
        new_squad_name: &str,
    ) -> Result<Rejoined, &'static str> {
        let mut peers = HashSet::new();
        let mut ids = HashSet::new();
        if !now.is_finite()
            || now.abs() > 1e12
            || players.len() > 100_000
            || players
                .iter()
                .any(|&(peer, team)| peer <= 0 || !(-1..=1).contains(&team) || !peers.insert(peer))
            || squads.len() >= 100_000
            || squads
                .iter()
                .any(|q| !q.valid() || !ids.insert(q.id) || u64::from(q.id) >= *next_squad)
            || !(1..=u64::from(u32::MAX)).contains(next_squad)
            || new_squad_name.len() > 128
            || new_squad_name.contains('\0')
        {
            return Err("invalid infantry rejoin context");
        }
        let s = self.soldier(id).ok_or("missing returning soldier")?;
        if s.orders.path_revision == i64::MAX as u64 {
            return Err("returning soldier path revision exhausted");
        }
        let team = s.identity.team;
        let position = s.motion.position;
        let previous_owner = s.identity.owner;
        let owner = if previous_owner <= 0 || peers.contains(&previous_owner) {
            previous_owner
        } else {
            players
                .iter()
                .rev()
                .find(|(_, t)| *t == team)
                .map_or(-1 - i32::from(team), |p| p.0)
        };
        let mut nearest = None;
        let mut distance = 90.0;
        for (i, q) in squads.iter_mut().enumerate() {
            if q.owner != owner || q.team != team || q.members.len() >= 6 {
                continue;
            }
            let d = f64::from(flat(q.centroid(now, self) - position).length());
            if d < distance {
                distance = d;
                nearest = Some(i);
            }
        }
        let created = nearest.is_none();
        let index = if let Some(i) = nearest {
            i
        } else {
            let mut q = Squad::new(
                *next_squad as u32,
                team,
                owner,
                if team == 0 {
                    "rifle_squad"
                } else {
                    "fighter_cell"
                }
                .into(),
            )?;
            q.order_position = position;
            battle.register_unit(Unit {
                key: format!("s{}", q.id),
                name: q.callsign(),
                kind: new_squad_name.into(),
                team,
                owner,
                started: now,
                ended: -1.0,
                ..Default::default()
            })?;
            *next_squad += 1;
            squads.push(q);
            squads.len() - 1
        };
        let q = &mut squads[index];
        if q.add_member(id, self)? {
            battle.squad_grew(q);
        }
        let s = self.soldier_mut(id).unwrap();
        s.identity.owner = owner;
        s.orders.hold_position = if f64::from(flat(q.order_position - position).length()) < 40.0 {
            q.order_position
        } else {
            position
        };
        s.cover.at_cover = false;
        s.cover.evaluate_at = 0.0;
        let route = if f64::from(flat(s.orders.hold_position - position).length()) > 3.0 {
            Some(s.go_to(s.orders.hold_position, Goal::Slot, 0)?)
        } else {
            None
        };
        Ok(Rejoined {
            squad: q.id,
            created,
            owner_changed: (owner != previous_owner).then_some(owner),
            route,
        })
    }
}
