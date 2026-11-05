//! Strategic orders use the player's dispatcher; tactical plans remain with the squads.
use crate::content::Content;
use frontline_core as sim;
use sim::actors::Actor;
use sim::infantry_vitals::Life;
use sim::match_commands::{Action, Command, Event, Profiles};
use sim::match_state::{MatchState, Shared};
use sim::random::SimulationRandom;
use sim::vector::{normalized, Vector3};
use std::collections::BTreeMap;
mod codec;
mod logistics;
mod naval;
mod tactics;

#[derive(Clone, Debug, PartialEq)]
pub struct Role {
    pub kind: String,
    pub since: f64,
    pub target: u32,
    pub position: Vector3,
    pub held: Option<f64>,
    pub exit: u32,
    pub sent: bool,
}
#[derive(Clone, Debug, PartialEq)]
pub struct Commander {
    pub team: i8,
    pub permanent: bool,
    pub rng: SimulationRandom,
    pub next_tick: u64,
    pub phase: u8,
    pub attack_target: u32,
    pub roles: BTreeMap<u32, Role>,
    pub last_wave: f64,
    pub expand_at: f64,
    pub defense_at: f64,
    pub obstacle_at: f64,
    pub recon_at: f64,
    pub town_at: f64,
    pub outpost_at: f64,
    pub back_at: f64,
    pub next_vehicle: String,
    pub support_cursor: usize,
    pub ambush_at: f64,
    pub helped: BTreeMap<u32, f64>,
    naval_at: f64,
    sling_at: f64,
    boats: BTreeMap<u32, naval::BoatRole>,
}
fn flat(p: Vector3) -> Vector3 {
    Vector3::new(p.x, 0., p.z)
}
fn distance(a: Vector3, b: Vector3) -> f32 {
    flat(a - b).length()
}
fn rotate(p: Vector3, angle: f64) -> Vector3 {
    sim::cover::transform(sim::cover::rotation(angle), p)
}
fn point(p: Vector3) -> bool {
    p.is_finite() && p.abs().max_element() <= 1_000_000.
}
fn clock(t: f64) -> bool {
    t.is_finite() && (0. ..=1e12).contains(&t)
}

struct Squad {
    id: u32,
    position: Vector3,
    alive: usize,
    total: usize,
    engineer: bool,
    kind: String,
    plan: u32,
    drill: String,
    order: String,
}
struct Census {
    squads: Vec<Squad>,
    structures: Vec<u32>,
    vehicles: Vec<u32>,
    enemy_armor: usize,
    enemy_air: bool,
}
struct Context<'a, 's, 'p> {
    state: &'a mut MatchState,
    content: &'a Content,
    landmarks: &'a [crate::mission::Landmark],
    shared: &'a Shared<'s>,
    profiles: &'a Profiles<'p>,
    host: i32,
    events: &'a mut Vec<Event>,
}
impl Context<'_, '_, '_> {
    fn command(
        &mut self,
        team: i8,
        squads: Vec<u32>,
        vehicles: Vec<u32>,
        action: Action,
    ) -> Result<(), &'static str> {
        self.events.extend(self.state.execute(
            -1 - i32::from(team),
            "AI",
            self.host,
            &Command {
                squads,
                vehicles,
                action,
            },
            self.shared,
            self.profiles,
        )?);
        Ok(())
    }
    fn census(&mut self, team: i8) -> Census {
        let f = &mut self.state.field;
        let mut c = Census {
            squads: vec![],
            structures: vec![],
            vehicles: vec![],
            enemy_armor: 0,
            enemy_air: false,
        };
        for q in &mut f.squads {
            if q.team != team || q.owner != -1 - i32::from(team) {
                continue;
            }
            c.squads.push(Squad {
                id: q.id,
                position: q.centroid(f.now, &f.actors),
                alive: q.alive(&f.actors).count(),
                total: q.members.len(),
                engineer: q.alive(&f.actors).any(|s| (self.profiles.engineer)(s)),
                kind: q.kind.clone(),
                plan: q.plan,
                drill: q.drill.clone(),
                order: q.order.clone(),
            });
        }
        c.structures.extend(
            f.actors
                .owned_structures()
                .iter()
                .copied()
                .filter(|&id| f.actors.structure(id).is_some_and(|s| s.team == team)),
        );
        for a in f.actors.iter_kind(sim::entities::Kind::Vehicle) {
            match a {
                Actor::Vehicle(v)
                    if v.team == team
                        && v.owner == -1 - i32::from(team)
                        && !(self.shared.automatic)(&v.kind) =>
                {
                    c.vehicles.push(v.id)
                }
                Actor::Vehicle(v)
                    if v.team >= 0 && v.team != team && v.visible & (1 << team) != 0 =>
                {
                    c.enemy_armor += usize::from(!(self.shared.automatic)(&v.kind));
                    c.enemy_air |= self.content.vehicle(v).air;
                }
                _ => {}
            }
        }
        c
    }
    fn stock(&self, team: i8) -> i32 {
        sim::economy::fobs(&self.state.field.actors, team, false)
            .map(|s| s.supply as i32)
            .sum()
    }
    fn room(&self, team: i8, count: u64) -> bool {
        let d = &self.content.definitions();
        let actors = &self.state.field.actors;
        sim::economy::used(actors, team, &|s| self.content.unit(s).bearer, &|v| {
            self.content.vehicle(v).cap.unwrap_or(0.) as u32
        }) + count
            <= sim::economy::capacity(actors, team, d.base_cap as u32, d.cap_per_fob as u32)
    }
    fn placeable(
        &self,
        team: i8,
        kind: &str,
        position: Vector3,
        yaw: f64,
    ) -> Result<bool, &'static str> {
        Ok(self
            .state
            .field
            .geometry
            .placement_error(
                &self.state.field.actors,
                &self.state.rules.network,
                &self.state.water,
                team,
                (self.profiles.building)(kind).as_ref(),
                position,
                yaw,
                self.profiles.distances,
                self.profiles.structure_name,
            )?
            .is_empty())
    }
    fn unlocked(&self, team: i8, key: &str) -> bool {
        (self.profiles.item)(key, false).is_some_and(|item| {
            item.teams & (1 << team) != 0
                && sim::production_orders::tier_needed(
                    &self.state.rules.economy,
                    team,
                    item,
                    self.profiles.research,
                )
                .is_empty()
        })
    }
}
impl Commander {
    pub fn new(team: i8, seed: u64, tick: u64) -> Result<Self, &'static str> {
        if !(0..=1).contains(&team) || tick > i64::MAX as u64 - 240 {
            return Err("invalid commander");
        }
        Ok(Self {
            team,
            permanent: true,
            rng: SimulationRandom::new(seed.wrapping_add(101 * (team as u64 + 1))),
            next_tick: tick + 180 + 60 * team as u64,
            phase: 0,
            attack_target: 0,
            roles: BTreeMap::new(),
            last_wave: 0.,
            expand_at: 150.,
            defense_at: 0.,
            obstacle_at: 240.,
            recon_at: 150.,
            town_at: 0.,
            outpost_at: 0.,
            back_at: 0.,
            next_vehicle: String::new(),
            support_cursor: 0,
            ambush_at: 160.,
            helped: BTreeMap::new(),
            naval_at: 0.,
            sling_at: 0.,
            boats: BTreeMap::new(),
        })
    }
    fn forward(&self) -> Vector3 {
        if self.team == 0 {
            Vector3::NEG_Z
        } else {
            Vector3::Z
        }
    }
    fn yaw(&self) -> f64 {
        if self.team == 0 {
            0.
        } else {
            std::f64::consts::PI
        }
    }
    fn fobs(&self, w: &Context<'_, '_, '_>) -> Vec<u32> {
        sim::economy::fobs(&w.state.field.actors, self.team, false)
            .map(|s| s.id)
            .collect()
    }
    fn front(&self, w: &Context<'_, '_, '_>) -> Option<Vector3> {
        sim::economy::fobs(&w.state.field.actors, self.team, false)
            .max_by(|a, b| {
                a.position
                    .dot(self.forward())
                    .total_cmp(&b.position.dot(self.forward()))
                    .then(b.id.cmp(&a.id))
            })
            .map(|s| s.position)
    }
    fn reserve(&self, w: &Context<'_, '_, '_>) -> i32 {
        let n = self.fobs(w).len();
        let t = w.state.field.now;
        if t > self.expand_at
            && n < 3 + w.state.field.geometry.terrain.n / 256
            && n < 2 + (t / 360.) as usize
        {
            260
        } else {
            0
        }
    }
    fn role(&self, id: u32) -> &str {
        self.roles.get(&id).map_or("idle", |r| r.kind.as_str())
    }
    fn assign(&mut self, id: u32, kind: &str, now: f64, target: u32, position: Vector3) {
        self.roles.insert(
            id,
            Role {
                kind: kind.into(),
                since: now,
                target,
                position,
                held: None,
                exit: 0,
                sent: false,
            },
        );
    }
    fn has(&self, w: &Context<'_, '_, '_>, c: &Census, kind: &str) -> bool {
        c.structures.iter().any(|id| {
            w.state
                .field
                .actors
                .structure(*id)
                .is_some_and(|s| s.kind == kind)
        })
    }
    fn near(
        &self,
        w: &Context<'_, '_, '_>,
        c: &Census,
        kind: &str,
        p: Vector3,
        radius: f32,
    ) -> usize {
        c.structures
            .iter()
            .filter(|id| {
                w.state
                    .field
                    .actors
                    .structure(**id)
                    .is_some_and(|s| s.kind == kind && distance(p, s.position) < radius)
            })
            .count()
    }
    pub fn advance(
        &mut self,
        state: &mut MatchState,
        content: &Content,
        landmarks: &[crate::mission::Landmark],
        shared: &Shared<'_>,
        profiles: &Profiles<'_>,
        host: i32,
    ) -> Result<Vec<Event>, &'static str> {
        if state.tick < self.next_tick || state.victory.winner >= 0 {
            return Ok(vec![]);
        }
        self.next_tick = state
            .tick
            .checked_add(30)
            .ok_or("commander clock exhausted")?;
        let mut events = vec![];
        let mut w = Context {
            state,
            content,
            landmarks,
            shared,
            profiles,
            host,
            events: &mut events,
        };
        let c = w.census(self.team);
        self.roles
            .retain(|id, _| c.squads.iter().any(|q| q.id == *id));
        // Spread strategic work over half-second phases; no wall-clock budget affects decisions.
        match self.phase {
            0 => self.support(&mut w)?,
            1 => self.economy(&mut w, &c)?,
            2 => self.production(&mut w, &c)?,
            3 => self.military(&mut w, &c)?,
            _ => return Err("invalid commander phase"),
        }
        self.phase = (self.phase + 1) % 4;
        Ok(events)
    }
    fn support_kind(
        &mut self,
        w: &Context<'_, '_, '_>,
        recon: bool,
        reserve: i32,
    ) -> Option<String> {
        let now = w.state.field.now;
        let choices: Vec<_> = w
            .content
            .definitions()
            .support
            .iter()
            .filter(|(k, d)| {
                d.team.unwrap_or(-1.) as i8 == self.team
                    && d.recon == recon
                    && w.stock(self.team) >= d.cost.unwrap_or(0.) as i32 + reserve
                    && now >= d.from.unwrap_or(0.)
                    && w.state.rules.support.ready[self.team as usize]
                        .iter()
                        .find(|p| p.0 == **k)
                        .is_none_or(|p| p.1 <= now)
            })
            .map(|(k, _)| k.clone())
            .collect();
        (!choices.is_empty()).then(|| choices[self.rng.randi() as usize % choices.len()].clone())
    }
    fn support(&mut self, w: &mut Context<'_, '_, '_>) -> Result<(), &'static str> {
        if let Some(kind) = self.support_kind(w, false, 40) {
            let candidates: Vec<_> = w
                .state
                .field
                .actors
                .iter()
                .filter_map(|a| match a {
                    Actor::Soldier(s)
                        if s.identity.team >= 0
                            && s.identity.team != self.team
                            && s.vitals.life == Life::Alive
                            && s.identity.visible & (1 << self.team) != 0 =>
                    {
                        Some(s.motion.position)
                    }
                    _ => None,
                })
                .collect();
            let mut best = None;
            let mut score = 3.99;
            // Nearby candidates share most neighbours; rotate a bounded sample across thoughts.
            for i in 0..candidates.len().min(64) {
                let p = candidates[(self.support_cursor + i) % candidates.len()];
                let mut value = 0.;
                let mut friendly = false;
                for id in w
                    .state
                    .field
                    .actors
                    .units_near(&w.state.field.units, p, 24., -1)?
                {
                    match w.state.field.actors.get(id) {
                        Some(Actor::Soldier(s)) if s.vitals.life == Life::Alive => {
                            if s.identity.team == self.team {
                                friendly = true;
                                break;
                            }
                            if s.identity.team >= 0 && distance(p, s.motion.position) < 14. {
                                value += 1.;
                            }
                        }
                        Some(Actor::Vehicle(v))
                            if v.team >= 0
                                && v.team != self.team
                                && distance(p, v.position) < 14. =>
                        {
                            value += 2.5
                        }
                        _ => {}
                    }
                }
                if !friendly && value > score {
                    best = Some(p);
                    score = value;
                }
            }
            self.support_cursor = if candidates.is_empty() {
                0
            } else {
                (self.support_cursor + 64) % candidates.len()
            };
            if let Some(position) = best {
                w.command(
                    self.team,
                    vec![],
                    vec![],
                    Action::Support {
                        kind,
                        position,
                        direction: normalized(flat(
                            position - self.front(w).unwrap_or(Vector3::ZERO),
                        )),
                    },
                )?;
            }
        }
        if w.state.field.now >= self.recon_at {
            self.recon_at = w.state.field.now + 20.;
            if let Some(front) = self.front(w) {
                let position = w
                    .state
                    .field
                    .actors
                    .structure(self.attack_target)
                    .map_or(front + self.forward() * 170., |s| s.position);
                let seen = w
                    .state
                    .field
                    .actors
                    .units_near(&w.state.field.units, position, 70., -1)?
                    .iter()
                    .filter(|id| {
                        w.state.field.actors.soldier(**id).is_some_and(|s| {
                            s.identity.team != self.team
                                && s.identity.team >= 0
                                && s.vitals.life == Life::Alive
                                && s.identity.visible & (1 << self.team) != 0
                        })
                    })
                    .count();
                if seen < 4 {
                    if let Some(kind) = self.support_kind(w, true, 200 + self.reserve(w)) {
                        w.command(
                            self.team,
                            vec![],
                            vec![],
                            Action::Support {
                                kind,
                                position,
                                direction: normalized(flat(position - front)),
                            },
                        )?;
                        self.recon_at = w.state.field.now + 150.;
                    }
                }
            }
        }
        Ok(())
    }
}
fn by_distance<'a>(squads: &[&'a Squad], p: Vector3) -> Vec<&'a Squad> {
    let mut out = squads.to_vec();
    out.sort_by(|a, b| {
        distance(a.position, p)
            .total_cmp(&distance(b.position, p))
            .then(a.id.cmp(&b.id))
    });
    out
}
