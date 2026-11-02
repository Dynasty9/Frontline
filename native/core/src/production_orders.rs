//! Production orders spend shared stock immediately; cancellation credits the original buyer.
use crate::actors::{Actor, Actors};
use crate::battle_stats::BattleStats;
use crate::economy::{self, Economy};
use crate::structure::Production;

#[derive(Clone, Debug)]
pub struct Research {
    pub key: String,
    pub name: String,
    pub teams: u8,
    pub tier: u32,
}
#[derive(Clone, Debug)]
pub struct Item {
    pub key: String,
    pub name: String,
    pub cost: i32,
    pub time: f64,
    pub tier: u32,
    pub research: bool,
    pub teams: u8,
    pub requires: String,
}
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Outcome {
    Ignored,
    Changed,
    Warning { peer: i32, text: String },
}
fn text(s: &str, max: usize) -> bool {
    !s.is_empty() && s.len() <= max && !s.contains('\0')
}
impl Item {
    pub fn valid(&self) -> bool {
        text(&self.key, 128)
            && text(&self.name, 4096)
            && (0..=1_000_000).contains(&self.cost)
            && self.time.is_finite()
            && (0.000001..=1_000_000.).contains(&self.time)
            && self.tier <= 1_000_000
            && self.teams <= 3
            && (self.requires.is_empty() || text(&self.requires, 128))
    }
}
impl Research {
    pub fn valid(&self) -> bool {
        text(&self.key, 128) && text(&self.name, 4096) && self.teams <= 3 && self.tier <= 1_000_000
    }
}
pub fn tier(economy: &Economy, team: i8, research: &[Research]) -> u32 {
    research
        .iter()
        .filter(|r| economy.has_upgrade(team, &r.key))
        .map(|r| r.tier)
        .max()
        .unwrap_or(1)
        .max(1)
}
pub fn tier_needed(economy: &Economy, team: i8, item: &Item, research: &[Research]) -> String {
    if item.tier <= tier(economy, team, research) {
        return String::new();
    }
    research
        .iter()
        .find(|r| r.tier == item.tier && (0..=1).contains(&team) && r.teams & (1 << team) != 0)
        .map_or_else(|| format!("tier {}", item.tier), |r| r.name.clone())
}
fn warning(peer: i32, text: String) -> Outcome {
    if peer > 0 {
        Outcome::Warning { peer, text }
    } else {
        Outcome::Ignored
    }
}
impl Economy {
    pub fn order_production(
        &self,
        actors: &mut Actors,
        battle: &mut BattleStats,
        id: u32,
        peer: i32,
        team: i8,
        item: &Item,
        produces: &[String],
        research: &[Research],
    ) -> Result<Outcome, &'static str> {
        if peer < -2
            || !self.valid()
            || !item.valid()
            || produces.len() > 4096
            || produces.iter().any(|s| !text(s, 128))
            || research.len() > 4096
            || research.iter().any(|r| !r.valid())
        {
            return Err("invalid production order");
        }
        let Some(st) = actors
            .structure(id)
            .filter(|s| !s.gone && s.built && s.team == team && (0..=1).contains(&team))
        else {
            return Ok(Outcome::Ignored);
        };
        if item.research {
            if st.kind != "research"
                || item.teams & (1 << team) == 0
                || self.has_upgrade(team, &item.key)
                || st.queue.len() >= 4
            {
                return Ok(Outcome::Ignored);
            }
            if !item.requires.is_empty() && !self.has_upgrade(team, &item.requires) {
                let name = research
                    .iter()
                    .find(|r| r.key == item.requires)
                    .map_or(item.requires.as_str(), |r| r.name.as_str());
                return Ok(warning(
                    peer,
                    format!("{} needs {} first.", item.name, name),
                ));
            }
            if st.queue.iter().any(|q| q.item == item.key) {
                return Ok(Outcome::Ignored);
            }
        } else {
            if st.kind == "research" || st.queue.len() >= 6 || !produces.contains(&item.key) {
                return Ok(Outcome::Ignored);
            }
            let need = tier_needed(self, team, item, research);
            if !need.is_empty() {
                return Ok(warning(
                    peer,
                    format!("{} needs research first: {}.", item.name, need),
                ));
            }
        }
        let position = st.position;
        battle.check_add(peer, team, 14, f64::from(item.cost))?;
        if !economy::spend(actors, team, position, item.cost)? {
            return Ok(warning(
                peer,
                if item.research {
                    format!("Not enough supply for {} ({}).", item.name, item.cost)
                } else {
                    format!(
                        "Not enough supply at a nearby FOB for {} ({}).",
                        item.name, item.cost
                    )
                },
            ));
        }
        battle.add(peer, team, 14, f64::from(item.cost))?;
        let Some(Actor::Structure(st)) = actors.get_mut(id) else {
            unreachable!()
        };
        st.queue.push(Production {
            item: item.key.clone(),
            remaining: item.time,
            total: item.time,
            owner: peer,
            cost: item.cost,
        });
        Ok(Outcome::Changed)
    }
    pub fn cancel_production(
        &self,
        actors: &mut Actors,
        battle: &mut BattleStats,
        id: u32,
        team: i8,
    ) -> Result<Outcome, &'static str> {
        let Some(st) = actors
            .structure(id)
            .filter(|s| !s.gone && s.team == team && (0..=1).contains(&team))
        else {
            return Ok(Outcome::Ignored);
        };
        let Some(order) = st.queue.last() else {
            return Ok(Outcome::Ignored);
        };
        let (peer, cost, position) = (order.owner, order.cost, st.position);
        battle.check_add(peer, team, 14, -f64::from(cost))?;
        economy::refund(actors, team, position, cost)?;
        battle.add(peer, team, 14, -f64::from(cost))?;
        let Some(Actor::Structure(st)) = actors.get_mut(id) else {
            unreachable!()
        };
        st.queue.pop();
        Ok(Outcome::Changed)
    }
}
