//! The authoritative after-action ledger. Display formatting stays with the client.
use crate::actors::{Actor, Actors};
use crate::infantry::{Credit, Infantry};
use crate::infantry_control::HiddenReason;
use crate::infantry_vitals::Life;
use crate::spatial::SpatialIndex;
use crate::squad::Squad;
use crate::state_codec::{Reader, Writer};
use crate::vector::Vector3;
use std::collections::HashSet;

pub const FIELDS: [&str; 25] = [
    "kills",
    "downs",
    "veh_kills",
    "bld_kills",
    "lost",
    "wounded",
    "captured",
    "veh_lost",
    "bld_lost",
    "shots",
    "hits",
    "dmg",
    "val_killed",
    "val_lost",
    "spent",
    "squads",
    "vehicles",
    "built",
    "research",
    "support",
    "captures",
    "towns",
    "prisoners",
    "revived",
    "delivered",
];
pub const KILLS: usize = 0;
pub const DOWNS: usize = 1;
pub const VEH_KILLS: usize = 2;
pub const BLD_KILLS: usize = 3;
pub const LOST: usize = 4;
pub const WOUNDED: usize = 5;
pub const CAPTURED: usize = 6;
pub const VEH_LOST: usize = 7;
pub const BLD_LOST: usize = 8;
pub const SHOTS: usize = 9;
pub const HITS: usize = 10;
pub const DAMAGE: usize = 11;
pub const VALUE_KILLED: usize = 12;
pub const VALUE_LOST: usize = 13;
pub const DELIVERED: usize = 24;
pub type Counters = [f64; 25];

#[derive(Clone, Debug, PartialEq)]
pub struct Player {
    pub owner: i32,
    pub team: i8,
    pub ai: bool,
    pub name: String,
    pub counters: Counters,
}
#[derive(Clone, Debug, Default, PartialEq)]
pub struct Unit {
    pub key: String,
    pub name: String,
    pub kind: String,
    pub team: i8,
    pub owner: i32,
    pub started: f64,
    pub ended: f64,
    pub men: u32,
    pub alive: u32,
    pub kills: u32,
    pub downs: u32,
    pub vehicle_kills: u32,
    pub lost: u32,
}
#[derive(Clone, Debug, PartialEq)]
pub struct Hero {
    pub id: u32,
    pub name: String,
    pub role: String,
    pub team: i8,
    pub owner: i32,
    pub unit: String,
    pub kills: u32,
    pub vehicles: u32,
    pub alive: bool,
}
#[derive(Clone, Debug, PartialEq)]
pub struct Event {
    pub time: f64,
    pub team: i8,
    pub kind: String,
    pub text: String,
}
#[derive(Clone, Debug, PartialEq)]
pub struct BattleStats {
    pub commander_names: Vec<(i32, String)>,
    pub players: Vec<Player>,
    pub sides: [Counters; 2],
    pub units: Vec<Unit>,
    pub heroes: Vec<Hero>,
    pub timeline: Vec<[f64; 9]>,
    pub events: Vec<Event>,
    pub every: f64,
    pub sample_timer: f64,
    pub blame: Option<Credit>,
}
#[derive(Clone, Debug, PartialEq)]
pub struct Report {
    pub players: Vec<Player>,
    pub sides: [Option<Counters>; 2],
    pub units: Vec<Unit>,
    pub heroes: Vec<Hero>,
    pub timeline: Vec<[f64; 9]>,
    pub events: Vec<Event>,
}
impl Default for BattleStats {
    fn default() -> Self {
        Self {
            commander_names: Vec::new(),
            players: Vec::new(),
            sides: [[0.0; 25]; 2],
            units: Vec::new(),
            heroes: Vec::new(),
            timeline: Vec::new(),
            events: Vec::new(),
            every: 10.0,
            sample_timer: 0.0,
            blame: None,
        }
    }
}

fn side(team: i8) -> bool {
    (0..=1).contains(&team)
}
fn text(s: &str) -> bool {
    s.len() <= 4096 && !s.contains('\0')
}
fn number(n: f64) -> bool {
    n.is_finite() && n.abs() <= 1e15
}
fn credit(c: &Credit) -> bool {
    c.owner >= -2 && side(c.team) && text(&c.unit)
}

impl BattleStats {
    fn remember_name(&mut self, owner: i32, name: &str) {
        if let Some((_, current)) = self.commander_names.iter_mut().find(|(id, _)| *id == owner) {
            *current = name.into();
        } else {
            self.commander_names.push((owner, name.into()));
        }
    }
    fn player(&mut self, owner: i32, team: i8) -> &mut Player {
        let index = self
            .players
            .iter()
            .position(|p| p.owner == owner)
            .unwrap_or_else(|| {
                let index = self.players.len();
                self.players.push(Player {
                    owner,
                    team,
                    ai: owner < 0,
                    name: if let Some((_, name)) =
                        self.commander_names.iter().find(|(id, _)| *id == owner)
                    {
                        name.clone()
                    } else if owner > 0 {
                        format!("Player {owner}")
                    } else {
                        "AI Commander".into()
                    },
                    counters: [0.0; 25],
                });
                index
            });
        &mut self.players[index]
    }
    pub fn joined(&mut self, owner: i32, team: i8, name: &str) -> Result<(), &'static str> {
        if owner < -2 || !text(name) {
            return Err("invalid commander");
        }
        if side(team) {
            self.remember_name(owner, name);
            self.player(owner, team);
        }
        Ok(())
    }
    pub fn rejoined(
        &mut self,
        old: i32,
        now: i32,
        team: i8,
        name: &str,
    ) -> Result<(), &'static str> {
        if old < -2 || now < -2 || !side(team) || !text(name) {
            return Err("invalid commander rejoin");
        }
        let Some(index) = self.players.iter().position(|p| p.owner == old) else {
            return self.joined(now, team, name);
        };
        let mut record = self.players[index].clone();
        if old != now {
            if let Some(current) = self.players.iter().find(|p| p.owner == now) {
                for (n, c) in record.counters.iter_mut().zip(current.counters) {
                    *n += c;
                }
            }
        }
        if !record.counters.iter().all(|&n| number(n)) {
            return Err("commander totals overflow");
        }
        self.remember_name(now, name);
        self.players.remove(index);
        record.owner = now;
        record.name = name.into();
        if let Some(current) = self.players.iter_mut().find(|p| p.owner == now) {
            *current = record;
        } else {
            self.players.push(record);
        }
        for unit in &mut self.units {
            if unit.owner == old {
                unit.owner = now;
            }
        }
        for hero in &mut self.heroes {
            if hero.owner == old {
                hero.owner = now;
            }
        }
        Ok(())
    }
    pub fn add(
        &mut self,
        owner: i32,
        team: i8,
        field: usize,
        amount: f64,
    ) -> Result<(), &'static str> {
        if owner < -2 || field >= FIELDS.len() || !number(amount) {
            return Err("invalid battle statistic");
        }
        if !side(team) {
            return Ok(());
        }
        let next_side = self.sides[team as usize][field] + amount;
        let next_player = self
            .players
            .iter()
            .find(|p| p.owner == owner)
            .map_or(0.0, |p| p.counters[field])
            + amount;
        if !number(next_side) || !number(next_player) {
            return Err("battle statistic overflow");
        }
        self.sides[team as usize][field] = next_side;
        if owner != 0 {
            self.player(owner, team).counters[field] = next_player;
        }
        Ok(())
    }
    fn unit_add(&mut self, key: &str, field: usize) {
        if let Some(u) = self.units.iter_mut().find(|u| u.key == key) {
            let count = match field {
                KILLS => &mut u.kills,
                DOWNS => &mut u.downs,
                VEH_KILLS => &mut u.vehicle_kills,
                LOST => &mut u.lost,
                _ => return,
            };
            *count += 1;
        }
    }
    pub fn shot(&mut self, owner: i32, team: i8, hit: bool) -> Result<(), &'static str> {
        self.add(owner, team, SHOTS, 1.0)?;
        if hit {
            self.add(owner, team, HITS, 1.0)?;
        }
        Ok(())
    }
    pub fn set_blame(&mut self, by: Option<Credit>) -> Result<Option<Credit>, &'static str> {
        if by.as_ref().is_some_and(|c| !credit(c)) {
            return Err("invalid battle blame");
        }
        Ok(std::mem::replace(&mut self.blame, by))
    }
    pub fn who(&self, source: u32, actors: &Actors) -> Option<Credit> {
        actors
            .get(source)
            .map_or_else(|| self.blame.clone(), Actor::credit)
    }
    pub fn damage(&mut self, by: Option<&Credit>, amount: f64) -> Result<(), &'static str> {
        if let Some(by) = by {
            if !credit(by) {
                return Err("invalid damage credit");
            }
            self.add(by.owner, by.team, DAMAGE, amount)?;
        }
        Ok(())
    }
    pub fn record_hit(
        &mut self,
        id: u32,
        source: u32,
        amount: f64,
        actors: &mut Actors,
    ) -> Result<(), &'static str> {
        if !number(amount) || amount < 0.0 {
            return Err("invalid recorded hit");
        }
        let by = self.who(source, actors);
        let target = actors.get_mut(id).ok_or("missing hit recipient")?;
        let (team, health, last) = match target {
            Actor::Soldier(s) => (
                s.identity.team,
                (s.vitals.life == Life::Alive).then_some(s.vitals.hp),
                &mut s.identity.hit_by,
            ),
            Actor::Vehicle(v) => (v.team, Some(v.hp), &mut v.hit_by),
            Actor::Structure(s) => (s.team, None, &mut s.hit_by),
            _ => return Err("invalid hit recipient"),
        };
        if let Some(by) = by.filter(|by| by.team != team) {
            if let Some(hp) = health {
                self.damage(Some(&by), amount.min(hp.max(0.0)))?;
            }
            *last = Some(by);
        }
        Ok(())
    }
    pub fn soldier_down(&mut self, s: &Infantry, bearer: bool) -> Result<(), &'static str> {
        if bearer {
            return Ok(());
        }
        self.add(s.identity.owner, s.identity.team, WOUNDED, 1.0)?;
        if let Some(by) = &s.identity.hit_by {
            self.add(by.owner, by.team, DOWNS, 1.0)?;
            self.unit_add(&by.unit, DOWNS);
        }
        Ok(())
    }
    fn hero(&mut self, by: &Credit, vehicle: bool, actors: &Actors, role: &str) {
        if by.soldier == 0 {
            return;
        }
        let index = if let Some(index) = self.heroes.iter().position(|h| h.id == by.soldier) {
            index
        } else {
            let Some(s) = actors.soldier(by.soldier) else {
                return;
            };
            let index = self.heroes.len();
            self.heroes.push(Hero {
                id: by.soldier,
                name: s.identity.name.clone(),
                role: role.into(),
                team: s.identity.team,
                owner: s.identity.owner,
                unit: by.unit.clone(),
                kills: 0,
                vehicles: 0,
                alive: s.vitals.life != Life::Dead,
            });
            index
        };
        if vehicle {
            self.heroes[index].vehicles += 1;
        } else {
            self.heroes[index].kills += 1;
        }
    }
    pub fn soldier_died(
        &mut self,
        s: &Infantry,
        previous: Life,
        bearer: bool,
        value: f64,
        actors: &Actors,
        killer_role: &str,
    ) -> Result<(), &'static str> {
        if !number(value) || value < 0.0 || !text(killer_role) {
            return Err("invalid casualty value");
        }
        if previous == Life::Captive || s.identity.team < 0 || bearer {
            return Ok(());
        }
        self.add(s.identity.owner, s.identity.team, LOST, 1.0)?;
        self.add(s.identity.owner, s.identity.team, VALUE_LOST, value)?;
        if s.identity.squad != 0 {
            self.unit_add(&format!("s{}", s.identity.squad), LOST);
        }
        if let Some(h) = self.heroes.iter_mut().find(|h| h.id == s.identity.id) {
            h.alive = false;
        }
        if let Some(by) = &s.identity.hit_by {
            self.add(by.owner, by.team, KILLS, 1.0)?;
            self.add(by.owner, by.team, VALUE_KILLED, value)?;
            self.unit_add(&by.unit, KILLS);
            self.hero(by, false, actors, killer_role);
        }
        Ok(())
    }
    pub fn prisoner(
        &mut self,
        prisoner: &Infantry,
        captor: &Infantry,
        value: f64,
    ) -> Result<(), &'static str> {
        if !number(value) || value < 0.0 {
            return Err("invalid prisoner value");
        }
        self.add(
            prisoner.identity.owner,
            prisoner.identity.team,
            CAPTURED,
            1.0,
        )?;
        self.add(
            prisoner.identity.owner,
            prisoner.identity.team,
            VALUE_LOST,
            value,
        )?;
        if prisoner.identity.squad != 0 {
            self.unit_add(&format!("s{}", prisoner.identity.squad), LOST);
        }
        self.add(captor.identity.owner, captor.identity.team, 22, 1.0)?;
        self.add(
            captor.identity.owner,
            captor.identity.team,
            VALUE_KILLED,
            value,
        )
    }
    pub fn vehicle_destroyed(
        &mut self,
        id: u32,
        value: f64,
        now: f64,
        description: &str,
        killer_role: &str,
        actors: &Actors,
    ) -> Result<(), &'static str> {
        if !number(value) || value < 0.0 || !number(now) || !text(description) || !text(killer_role)
        {
            return Err("invalid vehicle loss");
        }
        let v = actors.vehicle(id).ok_or("missing lost vehicle")?;
        if !side(v.team) {
            return Ok(());
        }
        self.add(v.owner, v.team, VEH_LOST, 1.0)?;
        self.add(v.owner, v.team, VALUE_LOST, value)?;
        let key = format!("v{id}");
        if let Some(u) = self.units.iter_mut().find(|u| u.key == key) {
            u.ended = now;
            u.alive = 0;
        }
        self.event(Event {
            time: now,
            team: v.team,
            kind: "veh".into(),
            text: description.into(),
        })?;
        if let Some(by) = &v.hit_by {
            self.add(by.owner, by.team, VEH_KILLS, 1.0)?;
            self.add(by.owner, by.team, VALUE_KILLED, value)?;
            self.unit_add(&by.unit, VEH_KILLS);
            self.hero(by, true, actors, killer_role);
        }
        Ok(())
    }
    pub fn building_destroyed(
        &mut self,
        id: u32,
        value: f64,
        now: f64,
        description: &str,
        actors: &Actors,
    ) -> Result<(), &'static str> {
        if !number(value) || value < 0.0 || !number(now) || !text(description) {
            return Err("invalid building loss");
        }
        let s = actors.structure(id).ok_or("missing lost building")?;
        if !side(s.team) {
            return Ok(());
        }
        self.add(s.owner, s.team, BLD_LOST, 1.0)?;
        self.add(s.owner, s.team, VALUE_LOST, value)?;
        if s.kind == "fob" {
            self.event(Event {
                time: now,
                team: s.team,
                kind: "fob".into(),
                text: description.into(),
            })?;
        }
        if let Some(by) = &s.hit_by {
            self.add(by.owner, by.team, BLD_KILLS, 1.0)?;
            self.add(by.owner, by.team, VALUE_KILLED, value)?;
        }
        Ok(())
    }
    pub fn register_unit(&mut self, unit: Unit) -> Result<(), &'static str> {
        if !unit.valid() {
            return Err("invalid fielded unit");
        }
        if !side(unit.team) {
            return Ok(());
        }
        if let Some(u) = self.units.iter_mut().find(|u| u.key == unit.key) {
            *u = unit;
        } else {
            self.units.push(unit);
        }
        Ok(())
    }
    pub fn squad_grew(&mut self, q: &Squad) {
        let key = format!("s{}", q.id);
        if let Some(u) = self.units.iter_mut().find(|u| u.key == key) {
            u.men = u.men.max(q.members.len() as u32);
        }
    }
    pub fn squad_gone(&mut self, id: u32, now: f64) -> Result<(), &'static str> {
        if !number(now) {
            return Err("invalid loss time");
        }
        let key = format!("s{id}");
        if let Some(u) = self.units.iter_mut().find(|u| u.key == key) {
            u.ended = now;
            u.alive = 0;
        }
        Ok(())
    }
    pub fn refresh_units(&mut self, squads: &[Squad], actors: &Actors) {
        for q in squads {
            let key = format!("s{}", q.id);
            if let Some(u) = self.units.iter_mut().find(|u| u.key == key) {
                u.alive = q
                    .members
                    .iter()
                    .filter_map(|&id| actors.soldier(id))
                    .filter(|s| matches!(s.vitals.life, Life::Alive | Life::Downed | Life::Hidden))
                    .count() as u32;
                u.men = u.men.max(q.members.len() as u32);
                u.owner = q.owner;
            }
        }
    }
    pub fn taker(
        &self,
        position: Vector3,
        radius: f64,
        team: i8,
        actors: &Actors,
        units: &SpatialIndex,
    ) -> Result<i32, &'static str> {
        let mut counts: Vec<(i32, u32)> = Vec::new();
        for id in actors.units_near(units, position, radius, -1)? {
            let Some(s) = actors.soldier(id) else {
                continue;
            };
            if s.identity.team == team && s.vitals.life == Life::Alive {
                if let Some((_, n)) = counts
                    .iter_mut()
                    .find(|(owner, _)| *owner == s.identity.owner)
                {
                    *n += 1;
                } else {
                    counts.push((s.identity.owner, 1));
                }
            }
        }
        let (mut owner, mut count) = (0, 0);
        for (candidate, n) in counts {
            if owner == 0 || n > count {
                owner = candidate;
                count = n;
            }
        }
        Ok(owner)
    }
    pub fn event(&mut self, event: Event) -> Result<(), &'static str> {
        if !number(event.time)
            || !(-1..=1).contains(&event.team)
            || !text(&event.kind)
            || !text(&event.text)
        {
            return Err("invalid battle event");
        }
        if self.events.len() < 90 || event.kind == "fob" || event.kind == "town" {
            self.events.push(event);
        }
        Ok(())
    }
    pub fn row(
        &self,
        now: f64,
        supply: [f64; 2],
        actors: &Actors,
        mut bearer: impl FnMut(&Infantry) -> bool,
    ) -> Result<[f64; 9], &'static str> {
        if !number(now) || !supply.into_iter().all(number) {
            return Err("invalid battle sample");
        }
        let mut men = [0.0; 2];
        let mut vehicles = [0.0; 2];
        for a in actors.iter() {
            match a {
                Actor::Soldier(s)
                    if side(s.identity.team)
                        && !bearer(s)
                        && (matches!(s.vitals.life, Life::Alive | Life::Downed)
                            || (s.vitals.life == Life::Hidden
                                && !matches!(
                                    s.control.hidden,
                                    HiddenReason::Held | HiddenReason::Interrogation
                                ))) =>
                {
                    men[s.identity.team as usize] += 1.0
                }
                Actor::Vehicle(v) if side(v.team) && v.hp > 0.0 && v.kind != "truck" => {
                    vehicles[v.team as usize] += 1.0
                }
                _ => {}
            }
        }
        Ok([
            now,
            men[0],
            men[1],
            vehicles[0],
            vehicles[1],
            self.sides[0][KILLS].trunc(),
            self.sides[1][KILLS].trunc(),
            supply[0],
            supply[1],
        ])
    }
    pub fn tick(
        &mut self,
        dt: f64,
        now: f64,
        supply: [f64; 2],
        actors: &Actors,
        bearer: impl FnMut(&Infantry) -> bool,
    ) -> Result<(), &'static str> {
        if !dt.is_finite()
            || !(0.0..=10.0).contains(&dt)
            || !number(now)
            || !supply.into_iter().all(number)
        {
            return Err("invalid battle sampling step");
        }
        self.sample_timer -= dt;
        if self.sample_timer > 0.0 {
            return Ok(());
        }
        let row = self.row(now, supply, actors, bearer)?;
        self.sample_timer = self.every;
        self.timeline.push(row);
        if self.timeline.len() > 240 {
            let last = self.timeline.len() - 1;
            let mut i = 0;
            self.timeline.retain(|_| {
                let keep = i % 2 == 0 || i == last;
                i += 1;
                keep
            });
            self.every *= 2.0;
        }
        Ok(())
    }
    pub fn hero_order(&self, view: i8, over: bool) -> Vec<usize> {
        let mut out = Vec::new();
        for team in 0..2 {
            if view >= 0 && !over && view != team {
                continue;
            }
            let selected: Vec<_> = self
                .heroes
                .iter()
                .enumerate()
                .filter(|(_, h)| h.team == team)
                .map(|(i, _)| i)
                .collect();
            let scores: Vec<_> = selected
                .iter()
                .map(|&i| {
                    -(f64::from(self.heroes[i].kills) + f64::from(self.heroes[i].vehicles) * 3.0)
                })
                .collect();
            out.extend(
                crate::godot_sort::score_order(&scores)
                    .into_iter()
                    .take(8)
                    .map(|i| selected[i]),
            );
        }
        out
    }
    pub fn visible_timeline(
        &self,
        view: i8,
        over: bool,
        row: [f64; 9],
    ) -> Result<Vec<[f64; 9]>, &'static str> {
        if !(-1..=1).contains(&view) || !row.into_iter().all(number) {
            return Err("invalid battle report");
        }
        let mut timeline = self.timeline.clone();
        if timeline.last().is_none_or(|last| row[0] - last[0] > 1.0) {
            timeline.push(row);
        }
        if view >= 0 && !over {
            let foe = 1 - view as usize;
            for row in &mut timeline {
                for index in [1 + foe, 3 + foe, 7 + foe] {
                    row[index] = -1.0;
                }
            }
        }
        Ok(timeline)
    }
    pub fn report(
        &mut self,
        view: i8,
        over: bool,
        row: [f64; 9],
        squads: &[Squad],
        actors: &Actors,
    ) -> Result<Report, &'static str> {
        let timeline = self.visible_timeline(view, over, row)?;
        self.refresh_units(squads, actors);
        let full = view < 0 || over;
        Ok(Report {
            players: self
                .players
                .iter()
                .filter(|p| full || p.team == view)
                .cloned()
                .collect(),
            sides: std::array::from_fn(|i| (full || i == view as usize).then_some(self.sides[i])),
            units: self
                .units
                .iter()
                .filter(|u| full || u.team == view)
                .cloned()
                .collect(),
            heroes: self
                .hero_order(view, over)
                .into_iter()
                .map(|i| self.heroes[i].clone())
                .collect(),
            timeline,
            events: self
                .events
                .iter()
                .filter(|e| full || e.team == view || e.kind != "sup")
                .cloned()
                .collect(),
        })
    }
}

impl Unit {
    fn valid(&self) -> bool {
        [self.key.as_str(), &self.name, &self.kind]
            .into_iter()
            .all(text)
            && !self.key.is_empty()
            && (-1..=1).contains(&self.team)
            && self.owner >= -2
            && number(self.started)
            && number(self.ended)
            && [
                self.men,
                self.alive,
                self.kills,
                self.downs,
                self.vehicle_kills,
                self.lost,
            ]
            .into_iter()
            .all(|n| n <= 1_000_000_000)
    }
}

const SCHEMA: &[u8; 8] = b"FLBS\x01\0\0\0";
fn count(input: &mut Reader<'_>) -> Result<usize, &'static str> {
    let n = input.u32()? as usize;
    if n <= 100_000 {
        Ok(n)
    } else {
        Err("battle record count exceeds limit")
    }
}
fn string(input: &mut Reader<'_>) -> Result<String, &'static str> {
    String::from_utf8(input.bytes(4096)?.to_vec()).map_err(|_| "invalid battle record text")
}
fn counters(input: &mut Reader<'_>) -> Result<Counters, &'static str> {
    let mut out = [0.0; 25];
    for n in &mut out {
        *n = input.f64()?;
    }
    Ok(out)
}
impl BattleStats {
    pub fn valid(&self) -> bool {
        let mut names = HashSet::new();
        let mut owners = HashSet::new();
        let mut keys = HashSet::new();
        let mut heroes = HashSet::new();
        [
            self.commander_names.len(),
            self.players.len(),
            self.units.len(),
            self.heroes.len(),
            self.events.len(),
        ]
        .into_iter()
        .all(|n| n <= 100_000)
            && self
                .commander_names
                .iter()
                .all(|(owner, name)| *owner >= -2 && text(name) && names.insert(owner))
            && self.players.iter().all(|p| {
                p.owner >= -2
                    && side(p.team)
                    && text(&p.name)
                    && p.counters.into_iter().all(number)
                    && owners.insert(p.owner)
            })
            && self.sides.iter().flatten().all(|&n| number(n))
            && self.units.iter().all(|u| u.valid() && keys.insert(&u.key))
            && self.heroes.iter().all(|h| {
                h.id > 0
                    && h.owner >= -2
                    && (-1..=1).contains(&h.team)
                    && [&h.name, &h.role, &h.unit].into_iter().all(|s| text(s))
                    && h.kills <= 1_000_000_000
                    && h.vehicles <= 1_000_000_000
                    && heroes.insert(h.id)
            })
            && self.timeline.len() <= 240
            && self.timeline.iter().flatten().all(|&n| number(n))
            && self.events.iter().all(|e| {
                number(e.time) && (-1..=1).contains(&e.team) && text(&e.kind) && text(&e.text)
            })
            && number(self.every)
            && self.every >= 10.0
            && number(self.sample_timer)
            && self.blame.as_ref().is_none_or(credit)
    }
    pub fn checkpoint(&self) -> Vec<u8> {
        let mut out = Writer::new(SCHEMA);
        out.u32(self.commander_names.len() as u32);
        for (owner, name) in &self.commander_names {
            out.u32(*owner as u32);
            out.bytes(name.as_bytes());
        }
        out.u32(self.players.len() as u32);
        for p in &self.players {
            out.u32(p.owner as u32);
            out.byte(p.team as u8);
            out.byte(p.ai as u8);
            out.bytes(p.name.as_bytes());
            for n in p.counters {
                out.f64(n);
            }
        }
        for n in self.sides.iter().flatten() {
            out.f64(*n);
        }
        out.u32(self.units.len() as u32);
        for u in &self.units {
            for s in [&u.key, &u.name, &u.kind] {
                out.bytes(s.as_bytes());
            }
            out.byte(u.team as u8);
            out.u32(u.owner as u32);
            out.f64(u.started);
            out.f64(u.ended);
            for n in [u.men, u.alive, u.kills, u.downs, u.vehicle_kills, u.lost] {
                out.u32(n);
            }
        }
        out.u32(self.heroes.len() as u32);
        for h in &self.heroes {
            out.u32(h.id);
            for s in [&h.name, &h.role, &h.unit] {
                out.bytes(s.as_bytes());
            }
            out.byte(h.team as u8);
            out.u32(h.owner as u32);
            out.u32(h.kills);
            out.u32(h.vehicles);
            out.byte(h.alive as u8);
        }
        out.u32(self.timeline.len() as u32);
        for row in &self.timeline {
            for n in row {
                out.f64(*n);
            }
        }
        out.u32(self.events.len() as u32);
        for e in &self.events {
            out.f64(e.time);
            out.byte(e.team as u8);
            out.bytes(e.kind.as_bytes());
            out.bytes(e.text.as_bytes());
        }
        out.f64(self.every);
        out.f64(self.sample_timer);
        out.byte(self.blame.is_some() as u8);
        if let Some(c) = &self.blame {
            out.u32(c.owner as u32);
            out.byte(c.team as u8);
            out.bytes(c.unit.as_bytes());
            out.u32(c.soldier);
        }
        out.0
    }
    pub fn restore(bytes: &[u8]) -> Result<Self, &'static str> {
        if bytes.len() > 64 * 1024 * 1024 {
            return Err("battle record exceeds size limit");
        }
        let mut input = Reader::new(bytes, SCHEMA)?;
        let mut out = Self::default();
        for _ in 0..count(&mut input)? {
            out.commander_names
                .push((input.u32()? as i32, string(&mut input)?));
        }
        for _ in 0..count(&mut input)? {
            out.players.push(Player {
                owner: input.u32()? as i32,
                team: input.byte()? as i8,
                ai: input.boolean()?,
                name: string(&mut input)?,
                counters: counters(&mut input)?,
            });
        }
        out.sides = [counters(&mut input)?, counters(&mut input)?];
        for _ in 0..count(&mut input)? {
            out.units.push(Unit {
                key: string(&mut input)?,
                name: string(&mut input)?,
                kind: string(&mut input)?,
                team: input.byte()? as i8,
                owner: input.u32()? as i32,
                started: input.f64()?,
                ended: input.f64()?,
                men: input.u32()?,
                alive: input.u32()?,
                kills: input.u32()?,
                downs: input.u32()?,
                vehicle_kills: input.u32()?,
                lost: input.u32()?,
            });
        }
        for _ in 0..count(&mut input)? {
            out.heroes.push(Hero {
                id: input.u32()?,
                name: string(&mut input)?,
                role: string(&mut input)?,
                unit: string(&mut input)?,
                team: input.byte()? as i8,
                owner: input.u32()? as i32,
                kills: input.u32()?,
                vehicles: input.u32()?,
                alive: input.boolean()?,
            });
        }
        let n = count(&mut input)?;
        if n > 240 {
            return Err("too many timeline samples");
        }
        for _ in 0..n {
            let mut row = [0.0; 9];
            for n in &mut row {
                *n = input.f64()?;
            }
            out.timeline.push(row);
        }
        for _ in 0..count(&mut input)? {
            out.events.push(Event {
                time: input.f64()?,
                team: input.byte()? as i8,
                kind: string(&mut input)?,
                text: string(&mut input)?,
            });
        }
        out.every = input.f64()?;
        out.sample_timer = input.f64()?;
        if input.boolean()? {
            out.blame = Some(Credit {
                owner: input.u32()? as i32,
                team: input.byte()? as i8,
                unit: string(&mut input)?,
                soldier: input.u32()?,
            });
        }
        input.finish()?;
        if !out.valid() {
            return Err("invalid battle record");
        }
        Ok(out)
    }
}
