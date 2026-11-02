//! A squad completes upkeep, decisions and duties before the next squad runs.
use crate::actors::Actor;
use crate::ambush_plan::AmbushPlan;
use crate::attack_plan::{AttackPlan, Event as Attack};
use crate::battle_stats::BattleStats;
use crate::infantry::Infantry;
use crate::infantry_vitals::Life;
use crate::infantry_weapon::Weapon;
use crate::squad::Report;
use crate::squad_brain::{Event as Brain, Profile};
use crate::squad_duties::Role;
use crate::squad_movement::{Context, Event as Movement};

pub struct Profiles<'a> {
    pub role: &'a dyn Fn(&Infantry) -> Role,
    pub armor: &'a dyn Fn(&str) -> i32,
    pub weapon: &'a dyn Fn(&Infantry) -> Option<Weapon>,
    pub air: &'a dyn Fn(&str) -> bool,
}
pub struct Tick<'a> {
    pub attacks: &'a mut [AttackPlan],
    pub ambushes: &'a mut [AmbushPlan],
    pub battle: &'a mut BattleStats,
    pub impacts: &'a [Report],
}
#[derive(Clone, Debug, PartialEq)]
pub enum Event {
    Brain(Brain),
    Attack(Attack),
    /// The owner removes this squad before advancing the next squad.
    Removed(u32),
}
fn cancel(plans: &mut [AmbushPlan], event: &Movement) {
    if let Movement::CancelAmbush(id) = event {
        if let Some(p) = plans.iter_mut().find(|p| p.id == *id) {
            p.done = true;
        }
    }
}
fn append(out: &mut Vec<Event>, plans: &mut [AmbushPlan], events: impl IntoIterator<Item = Brain>) {
    for e in events {
        if let Brain::Movement(m) = &e {
            cancel(plans, m);
        }
        out.push(Event::Brain(e));
    }
}
impl Context<'_> {
    pub fn squad_tick(
        &mut self,
        id: u32,
        dt: f64,
        tick: &mut Tick<'_>,
        profiles: &Profiles<'_>,
    ) -> Result<Vec<Event>, &'static str> {
        let i = self.index(id)?;
        if !dt.is_finite() || !(0.0..=10.0).contains(&dt) {
            return Err("invalid squad tick");
        }
        let mut out = vec![];
        self.squads[i].think_timer -= dt;
        if self.squads[i].think_timer > 0.0 {
            return Ok(out);
        }
        let q = &mut self.squads[i];
        q.think_timer = 0.5;
        q.members.retain(|&id| {
            self.actors
                .soldier(id)
                .is_some_and(|s| !s.identity.gone && s.identity.squad == q.id)
        });
        if !q.members.iter().any(|&id| {
            self.actors
                .soldier(id)
                .is_some_and(|s| matches!(s.vitals.life, Life::Alive | Life::Downed | Life::Hidden))
        }) {
            if q.plan != 0 {
                out.push(Event::Brain(Brain::Stat("plan_squad_lost")));
            }
            for &id in &q.members {
                self.actors.soldier_mut(id).unwrap().identity.squad = 0;
            }
            q.members.clear();
            q.plan = 0;
            if q.ambush_plan != 0 {
                cancel(tick.ambushes, &Movement::CancelAmbush(q.ambush_plan));
                q.ambush_plan = 0;
            }
            tick.battle.squad_gone(id, self.now)?;
            out.push(Event::Removed(id));
            return Ok(out);
        }
        let old = q.known.len();
        q.known.retain(|k| {
            self.now - k.report.time <= 20.0
                && self.actors.get(k.id).is_some_and(|a| match a {
                    Actor::Soldier(s) => !s.identity.gone,
                    Actor::Vehicle(v) => !v.gone,
                    Actor::Structure(s) => !s.gone,
                    _ => true,
                })
        });
        if old != q.known.len() {
            q.combat_at = -1.0;
        }
        if !q.known.is_empty() || q.heard.last().is_some_and(|r| self.now - r.time < 10.0) {
            q.alert_time = self.now;
        }
        let mut leaders = vec![];
        self.leader(i, &mut leaders);
        append(
            &mut out,
            tick.ambushes,
            leaders.into_iter().map(Brain::Movement),
        );
        if self.squads[i].morale < 0.0 {
            self.squads[i].morale = if self.squads[i].team == 0 { 78.0 } else { 72.0 };
        }
        self.squad_morale_tick(
            id,
            0.5,
            &Profile {
                plans: tick.attacks,
                impacts: tick.impacts,
                armor: profiles.armor,
                weapon: profiles.weapon,
            },
        )?;
        let plan = self.squads[i].ambush_plan;
        if plan != 0 {
            let p = tick
                .ambushes
                .iter_mut()
                .find(|p| p.id == plan)
                .ok_or("missing squad ambush")?;
            let events = p.tick(self, profiles.air)?;
            let done = p.done;
            append(&mut out, tick.ambushes, events);
            if self.squads[i].ambush_plan != 0 && done {
                self.squads[i].ambush_plan = 0;
            }
        } else {
            append(&mut out, tick.ambushes, self.squad_ambush_tick(id)?);
        }
        let (_, events) = self.squad_think(
            id,
            &Profile {
                plans: tick.attacks,
                impacts: tick.impacts,
                armor: profiles.armor,
                weapon: profiles.weapon,
            },
        )?;
        append(&mut out, tick.ambushes, events);
        append(
            &mut out,
            tick.ambushes,
            self.crew_tick(id)?.into_iter().map(Brain::Movement),
        );
        append(
            &mut out,
            tick.ambushes,
            self.squad_straggler_tick(id, tick.battle)?,
        );
        append(
            &mut out,
            tick.ambushes,
            self.overwatch_tick(id)?.into_iter().map(Brain::Movement),
        );
        append(&mut out, tick.ambushes, self.squad_then_defend_tick(id)?);
        append(&mut out, tick.ambushes, self.squad_clear_call_tick(id)?);
        if self.squads[i].drill == "rout" {
            append(&mut out, tick.ambushes, self.squad_surrender(id)?);
            return Ok(out);
        }
        if self.squads[i].travel && self.squads[i].order == "move" {
            append(
                &mut out,
                tick.ambushes,
                self.follow_tick(id)?.into_iter().map(Brain::Movement),
            );
        }
        append(
            &mut out,
            tick.ambushes,
            self.squad_rescue(id, profiles.role)?,
        );
        append(&mut out, tick.ambushes, self.squad_surrender(id)?);
        self.squad_medics(id, profiles.role)?;
        self.squad_engineers(id, profiles.role)?;
        if self.squads[i].order == "assault" {
            let plan = self.squads[i].plan;
            if plan != 0 {
                let p = tick
                    .attacks
                    .iter_mut()
                    .find(|p| p.id == plan)
                    .ok_or("missing squad attack")?;
                for event in p.tick(self)? {
                    if let Attack::Squad(m) = &event {
                        cancel(tick.ambushes, m);
                    }
                    out.push(Event::Attack(event));
                }
            } else {
                append(
                    &mut out,
                    tick.ambushes,
                    self.assault_bounds_tick(id)?
                        .into_iter()
                        .map(Brain::Movement),
                );
            }
        }
        append(
            &mut out,
            tick.ambushes,
            self.squad_share_ammo(
                id,
                &Profile {
                    plans: tick.attacks,
                    impacts: tick.impacts,
                    armor: profiles.armor,
                    weapon: profiles.weapon,
                },
            )?,
        );
        Ok(out)
    }
}
