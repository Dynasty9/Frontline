//! Strategic orders use the player's dispatcher; tactical plans remain with the squads.
use crate::content::Content;
use frontline_core as sim;
use sim::actors::Actor;
use sim::infantry_vitals::Life;
use sim::match_commands::{Action, Command, Event, Profiles};
use sim::match_state::{MatchState, Shared};
use sim::random::SimulationRandom;
use sim::state_codec::{Reader, Writer};
use sim::vector::{normalized, Vector3};
use std::collections::BTreeMap;
mod naval;

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
fn number(d: &serde_json::Value, key: &str, default: f64) -> f64 {
    d[key].as_f64().unwrap_or(default)
}
fn flag(d: &serde_json::Value, key: &str) -> bool {
    d[key].as_bool().unwrap_or(false)
}
fn text<'a>(d: &'a serde_json::Value, key: &str) -> &'a str {
    d[key].as_str().unwrap_or("")
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
        for a in f.actors.iter() {
            match a {
                Actor::Structure(s) if s.team == team => c.structures.push(s.id),
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
                    c.enemy_air |= flag(self.content.vehicle(v), "air");
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
        let d = &self.content.definitions;
        let actors = &self.state.field.actors;
        sim::economy::used(
            actors,
            team,
            &|s| flag(self.content.unit(s), "bearer"),
            &|v| number(self.content.vehicle(v), "cap", 0.) as u32,
        ) + count
            <= sim::economy::capacity(
                actors,
                team,
                number(d, "base_cap", 0.) as u32,
                number(d, "cap_per_fob", 0.) as u32,
            )
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
        let choices: Vec<_> = w.content.definitions["support"]
            .as_object()
            .unwrap()
            .iter()
            .filter(|(k, d)| {
                number(d, "team", -1.) as i8 == self.team
                    && flag(d, "recon") == recon
                    && w.stock(self.team) >= number(d, "cost", 0.) as i32 + reserve
                    && now >= number(d, "from", 0.)
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
    fn engineer(&self, w: &Context<'_, '_, '_>, c: &Census, p: Vector3) -> Option<u32> {
        c.squads
            .iter()
            .filter(|q| {
                q.engineer
                    && w.state
                        .field
                        .squads
                        .iter()
                        .find(|s| s.id == q.id)
                        .is_some_and(|s| {
                            w.state
                                .field
                                .actors
                                .structure(s.build_target)
                                .is_none_or(|b| b.built && b.hp >= b.max_hp)
                        })
            })
            .min_by(|a, b| {
                distance(a.position, p)
                    .total_cmp(&distance(b.position, p))
                    .then(a.id.cmp(&b.id))
            })
            .map(|q| q.id)
    }
    fn find_spot(
        &mut self,
        w: &Context<'_, '_, '_>,
        kind: &str,
        center: Vector3,
        lo: f32,
        hi: f32,
    ) -> Result<Option<Vector3>, &'static str> {
        for _ in 0..20 {
            let angle = if matches!(
                kind,
                "barracks" | "factory" | "medic_tent" | "research" | "mortar_pit"
            ) {
                self.rng
                    .randf_range(std::f32::consts::FRAC_PI_2, std::f32::consts::PI * 1.5)
            } else {
                self.rng.randf_range(-1.1, 1.1)
            };
            let p =
                center + rotate(self.forward(), f64::from(angle)) * self.rng.randf_range(lo, hi);
            let mut p = Vector3::new(p.x.round(), 0., p.z.round());
            if let Some(definition) = w.content.building(kind) {
                let [x, z] = definition.body.size;
                if x.min(z) >= 2. && kind != "trench" {
                    p.x = (p.x - x * 0.5).round() + x * 0.5;
                    p.z = (p.z - z * 0.5).round() + z * 0.5;
                }
            }
            if w.placeable(self.team, kind, p, self.yaw())? {
                return Ok(Some(p));
            }
        }
        Ok(None)
    }
    fn build(
        &self,
        w: &mut Context<'_, '_, '_>,
        c: &Census,
        kind: &str,
        position: Vector3,
    ) -> Result<(), &'static str> {
        let engineer = self
            .engineer(w, c, position)
            .or_else(|| c.squads.iter().find(|q| q.engineer).map(|q| q.id));
        w.command(
            self.team,
            engineer.into_iter().collect(),
            vec![],
            Action::Build {
                kind: kind.into(),
                position,
                yaw: self.yaw(),
            },
        )
    }
    fn economy(&mut self, w: &mut Context<'_, '_, '_>, c: &Census) -> Result<(), &'static str> {
        let fobs = self.fobs(w);
        let Some(front) = self.front(w) else {
            return Ok(());
        };
        let sites: Vec<_> = c
            .structures
            .iter()
            .copied()
            .filter(|id| {
                w.state
                    .field
                    .actors
                    .structure(*id)
                    .is_some_and(|s| s.kind != "depot" && (!s.built || s.hp < s.max_hp))
            })
            .collect();
        for &id in &sites {
            if !w
                .state
                .field
                .squads
                .iter()
                .any(|q| q.team == self.team && q.build_target == id)
            {
                if let Some(engineer) =
                    self.engineer(w, c, w.state.field.actors.structure(id).unwrap().position)
                {
                    w.command(self.team, vec![engineer], vec![], Action::Work(id))?;
                }
            }
        }
        if sites.len() >= 2 || !c.squads.iter().any(|q| q.engineer) {
            return Ok(());
        }
        let now = w.state.field.now;
        let stock = w.stock(self.team);
        let reserve = self.reserve(w);
        if now > self.expand_at
            && stock > 300
            && fobs.len() < 3 + w.state.field.geometry.terrain.n / 256
        {
            if let Some(p) = self.find_spot(w, "fob", front, 60., 105.)? {
                let enemy = w
                    .state
                    .field
                    .actors
                    .units_near(&w.state.field.units, p, 40., -1)?
                    .iter()
                    .any(|id| {
                        w.state.field.actors.soldier(*id).is_some_and(|s| {
                            s.identity.team >= 0
                                && s.identity.team != self.team
                                && s.vitals.life == Life::Alive
                        })
                    });
                if !enemy {
                    self.expand_at = now + f64::from(self.rng.randf_range(120., 200.));
                    return self.build(w, c, "fob", p);
                }
            }
            self.expand_at = now + 30.;
        }
        if self.dock(w, c)? {
            return Ok(());
        }
        let main = w.state.field.actors.structure(fobs[0]).unwrap().position;
        let mut plan = vec![];
        for (kind, due, lo, hi) in [
            ("barracks", true, 12., 30.),
            ("medic_tent", now > 70., 10., 28.),
            ("factory", now > 220. || stock > 500, 14., 36.),
            ("research", now > 330. && stock > 300, 12., 34.),
            (
                "helipad",
                now > 450. && stock > 350 && self.has(w, c, "factory"),
                14.,
                36.,
            ),
        ] {
            if due && !self.has(w, c, kind) {
                plan.push((kind, main, lo, hi));
                break;
            }
        }
        if self.team == 1 && now > 120. && self.near(w, c, "tunnel", front, 40.) == 0 {
            plan.push(("tunnel", front, 10., 30.));
        }
        for id in fobs {
            let p = w.state.field.actors.structure(id).unwrap().position;
            for (kind, start, count, radius, lo, hi) in [
                ("sandbags", 40., 4, 24., 9., 20.),
                (
                    if self.team == 0 { "hesco" } else { "barricade" },
                    if self.team == 0 { 140. } else { 90. },
                    3,
                    26.,
                    10.,
                    20.,
                ),
                ("ammo_cache", 200., 1, 45., 14., 26.),
                ("mg_nest", 100., 1, 30., 9., 18.),
                ("trench", 110., 6, 34., 17., 25.),
                ("hmg_nest", 170., 1, 30., 9., 18.),
                ("mortar_pit", 240., 1, 35., 8., 18.),
                ("bunker", 320., 1, 30., 10., 22.),
                (
                    "at_post",
                    if c.enemy_armor > 0 { 0. } else { 1e12 },
                    1,
                    35.,
                    10.,
                    22.,
                ),
                ("watchtower", 260., 1, 30., 8., 18.),
            ] {
                if now > start && self.near(w, c, kind, p, radius) < count {
                    plan.push((kind, p, lo, hi));
                }
            }
        }
        if now > self.obstacle_at {
            self.obstacle_at = now + f64::from(self.rng.randf_range(80., 140.));
            plan.push((
                ["wire", "mines", "tank_trap"][self.rng.randi() as usize % 3],
                front,
                18.,
                34.,
            ));
        }
        if now > 260. && stock > w.content.building("camo_net").unwrap().cost + 60 + reserve {
            for &id in &c.structures {
                let s = w.state.field.actors.structure(id).unwrap();
                if s.built
                    && matches!(s.kind.as_str(), "mortar_pit" | "at_post" | "hmg_nest")
                    && self.near(w, c, "camo_net", s.position, 2.5) == 0
                    && w.placeable(self.team, "camo_net", s.position, s.yaw)?
                {
                    let (position, yaw) = (s.position, s.yaw);
                    w.command(
                        self.team,
                        self.engineer(w, c, position).into_iter().collect(),
                        vec![],
                        Action::Build {
                            kind: "camo_net".into(),
                            position,
                            yaw,
                        },
                    )?;
                    return Ok(());
                }
            }
        }
        for (kind, center, lo, hi) in plan {
            let Some(definition) = w.content.building(kind) else {
                continue;
            };
            if definition.teams & (1 << self.team) == 0 || stock < definition.cost + 40 + reserve {
                continue;
            }
            if kind == "trench" {
                if stock > 150 + reserve {
                    self.dig_line(w, c, center)?;
                }
                break;
            }
            if let Some(p) = self.find_spot(w, kind, center, lo, hi)? {
                self.build(w, c, kind, p)?;
            }
            break;
        }
        Ok(())
    }
    fn dig_line(
        &mut self,
        w: &mut Context<'_, '_, '_>,
        c: &Census,
        base: Vector3,
    ) -> Result<(), &'static str> {
        use sim::match_commands::Placement;
        let center = base + self.forward() * (17. + self.rng.randf_range(-2., 3.));
        let half = self.rng.randf_range(13., 18.);
        let across = self.forward().cross(Vector3::Y);
        let start = center - across * half;
        let start = Vector3::new(start.x.round(), 0., start.z.round());
        let count = ((half * 2. / 6.).round() as usize).clamp(1, 9);
        let mut items = vec![];
        let jog_yaw = if self.team == 0 {
            -std::f64::consts::FRAC_PI_2
        } else {
            std::f64::consts::FRAC_PI_2
        };
        for i in 0..count {
            if items.len() >= 9 {
                break;
            }
            let off = if i % 2 == 1 { 2.8 } else { 0. };
            let position = start + across * 6. * (i as f32 + 0.5) - self.forward() * off;
            if w.placeable(self.team, "trench", position, self.yaw())? {
                items.push(Placement {
                    position,
                    yaw: self.yaw(),
                    length: Some(6.),
                });
            }
            if i < count - 1 && items.len() < 9 {
                let position = start + across * 6. * (i + 1) as f32 - self.forward() * 1.4;
                if w.placeable(self.team, "trench", position, jog_yaw)? {
                    items.push(Placement {
                        position,
                        yaw: jog_yaw,
                        length: Some(2.8),
                    });
                }
            }
        }
        if items.len() < 3 {
            return Ok(());
        }
        let mid = Vector3::new(center.x.round(), 0., center.z.round());
        for i in 0..2 {
            let position = mid - self.forward() * (i as f32 + 0.5) * 6.;
            if w.placeable(self.team, "trench", position, jog_yaw)? {
                items.push(Placement {
                    position,
                    yaw: jog_yaw,
                    length: Some(6.),
                });
            }
        }
        let engineer = self
            .engineer(w, c, center)
            .or_else(|| c.squads.iter().find(|q| q.engineer).map(|q| q.id));
        w.command(
            self.team,
            engineer.into_iter().collect(),
            vec![],
            Action::BuildMany {
                kind: "trench".into(),
                items,
            },
        )
    }
    fn pick_squad(&mut self, c: &Census, now: f64) -> &'static str {
        let engineers = c.squads.iter().filter(|q| q.engineer).count();
        let count = |key| c.squads.iter().filter(|q| q.kind == key).count();
        if engineers < 1 || engineers < 2 && now > 400. {
            return if self.team == 0 {
                "engineer_team"
            } else {
                "digger_team"
            };
        }
        let roll = self.rng.randf();
        if self.team == 0 {
            if c.enemy_armor > 0 && count("at_team") < c.enemy_armor + 1 && roll < 0.5 {
                "at_team"
            } else if roll < 0.5 {
                "rifle_squad"
            } else if roll < 0.62 && count("mortar_team") < 2 {
                "mortar_team"
            } else if roll < 0.75 {
                "mg_team"
            } else if roll < 0.87 {
                "at_team"
            } else {
                "rifle_squad"
            }
        } else {
            if c.enemy_armor > 0 && count("rpg_team") < c.enemy_armor + 1 && roll < 0.45 {
                "rpg_team"
            } else if roll < 0.4 {
                "fighter_cell"
            } else if roll < 0.48 && count("r_mortar_team") < 2 {
                "r_mortar_team"
            } else if roll < 0.62 {
                "pkm_team"
            } else if roll < 0.8 {
                "fpv_team"
            } else {
                "rpg_team"
            }
        }
    }
    fn vehicle_pick(&mut self, w: &Context<'_, '_, '_>, c: &Census) -> String {
        let mut picks = vec![];
        let mut total = 0.;
        for key in (w.profiles.produces)("factory") {
            if !w.unlocked(self.team, key) {
                continue;
            }
            let d = &w.content.definitions["vehicles"][key];
            let weight = match text(d, "base") {
                "tank" => 2.2 + c.enemy_armor as f64 * 0.6,
                "afv" => 2.4,
                "car" => 1.6,
                "spaa" => {
                    if c.enemy_air {
                        3.3
                    } else {
                        0.3
                    }
                }
                "arty" => 0.8,
                "util" => {
                    if d["service"].is_null() {
                        0.8
                    } else {
                        0.5
                    }
                }
                _ => 1.,
            } * (1. + 0.25 * (number(d, "tier", 1.) - 1.));
            total += weight;
            picks.push((key, weight));
        }
        let mut roll = f64::from(self.rng.randf()) * total;
        for (key, weight) in &picks {
            roll -= weight;
            if roll <= 0. {
                return (*key).clone();
            }
        }
        picks.last().map_or_else(String::new, |p| p.0.clone())
    }
    fn production(&mut self, w: &mut Context<'_, '_, '_>, c: &Census) -> Result<(), &'static str> {
        let now = w.state.field.now;
        let boat_saving = self.boat_production(w, c)?;
        let buildings: Vec<_> = c
            .structures
            .iter()
            .filter_map(|id| {
                w.state
                    .field
                    .actors
                    .structure(*id)
                    .filter(|s| s.built)
                    .map(|s| (s.id, s.kind.clone(), s.queue.len()))
            })
            .collect();
        let mut saving = 0;
        let mut room = 0;
        if let Some((id, _, _)) = buildings
            .iter()
            .find(|(_, kind, n)| kind == "factory" && *n == 0)
        {
            if c.vehicles.len() < 1 + (now / 420.) as usize {
                if self.next_vehicle.is_empty() {
                    self.next_vehicle = self.vehicle_pick(w, c);
                }
                if let Some(item) = (w.profiles.item)(&self.next_vehicle, false) {
                    saving = item.cost;
                    room = number(
                        &w.content.definitions["vehicles"][&self.next_vehicle],
                        "cap",
                        0.,
                    ) as u64;
                    if w.stock(self.team) >= saving + self.reserve(w) && w.room(self.team, room) {
                        w.command(
                            self.team,
                            vec![],
                            vec![],
                            Action::Produce {
                                building: *id,
                                item: self.next_vehicle.clone(),
                                research: false,
                            },
                        )?;
                        saving = 0;
                        room = 0;
                        self.next_vehicle.clear();
                    }
                }
            }
        }
        saving += self.reserve(w);
        if self.dock_wanted(w, c) && now > 600. {
            saving += w.content.building("dock").unwrap().cost / 2;
        }
        if !self.has(w, c, "factory") && now > 200. {
            saving += w.content.building("factory").unwrap().cost;
        }
        if c.squads.len() < 3 {
            saving = 0;
            room = 0;
        }
        saving += boat_saving;
        for (id, kind, queued) in buildings {
            let item = match kind.as_str() {
                "barracks" if queued < 2 && w.room(self.team, 6 + room) => {
                    Some((self.pick_squad(c, now).to_owned(), false, 30))
                }
                "helipad" if queued == 0 => {
                    let count = |base: &str| {
                        w.state.field.actors.iter().filter(|a| matches!(a, Actor::Vehicle(v) if v.team == self.team && if base == "supply" {flag(w.content.vehicle(v),"supply")} else {text(w.content.vehicle(v),"base") == base && !flag(w.content.vehicle(v),"supply")})).count()
                    };
                    let want = if count("supply") < 1 {
                        "supply"
                    } else if count("attack_heli") < 1 + (now / 900.) as usize {
                        "attack_heli"
                    } else if count("uav") < 1 && now > 360. {
                        "uav"
                    } else if count("lift_heli") < 1 && now > 500. {
                        "lift_heli"
                    } else {
                        ""
                    };
                    let opts: Vec<_> = (w.profiles.produces)("helipad")
                        .iter()
                        .filter(|k| {
                            let d = &w.content.definitions["vehicles"][*k];
                            w.unlocked(self.team, k)
                                && if want == "supply" {
                                    flag(d, "supply")
                                } else {
                                    text(d, "base") == want && !flag(d, "supply")
                                }
                        })
                        .collect();
                    (!opts.is_empty()).then(|| {
                        (
                            opts[self.rng.randi() as usize % opts.len()].clone(),
                            false,
                            80,
                        )
                    })
                }
                "research" if queued == 0 => w.content.definitions["upgrades"]
                    .as_object()
                    .unwrap()
                    .keys()
                    .find(|k| {
                        (w.profiles.item)(k, true).is_some_and(|i| {
                            i.teams & (1 << self.team) != 0
                                && !w.state.rules.economy.has_upgrade(self.team, k)
                                && (i.requires.is_empty()
                                    || w.state.rules.economy.has_upgrade(self.team, &i.requires))
                                && now >= 300. * i.tier as f64
                                && w.stock(self.team) > i.cost + 200
                        })
                    })
                    .map(|k| (k.clone(), true, 200)),
                _ => None,
            };
            if let Some((item, research, reserve)) = item {
                let cost = (w.profiles.item)(&item, research).unwrap().cost;
                if w.stock(self.team) >= cost + reserve + if research { 0 } else { saving } {
                    w.command(
                        self.team,
                        vec![],
                        vec![],
                        Action::Produce {
                            building: id,
                            item,
                            research,
                        },
                    )?;
                }
            }
        }
        Ok(())
    }
    fn military(&mut self, w: &mut Context<'_, '_, '_>, c: &Census) -> Result<(), &'static str> {
        let Some(front) = self.front(w) else {
            return Ok(());
        };
        let now = w.state.field.now;
        let fighters: Vec<_> = c
            .squads
            .iter()
            .filter(|q| {
                q.alive > 0
                    && !matches!(
                        q.kind.as_str(),
                        "crew" | "r_crew" | "engineer_team" | "digger_team"
                    )
            })
            .collect();
        for q in &fighters {
            if q.alive * 100 < q.total * 34 && self.role(q.id) != "retreat" {
                self.assign(q.id, "retreat", now, 0, q.position);
                w.command(self.team, vec![q.id], vec![], Action::Retreat)?;
            } else if self.roles.get(&q.id).is_some_and(|r| {
                matches!(r.kind.as_str(), "retreat" | "defend") && now - r.since > 45.
            }) {
                self.assign(q.id, "idle", now, 0, q.position);
            }
        }
        for id in self.fobs(w) {
            let p = w.state.field.actors.structure(id).unwrap().position;
            if now > self.defense_at {
                let threats = w
                    .state
                    .field
                    .actors
                    .units_near(&w.state.field.units, p, 45., -1)?
                    .iter()
                    .filter(|id| {
                        w.state.field.actors.soldier(**id).is_some_and(|s| {
                            s.identity.team >= 0
                                && s.identity.team != self.team
                                && s.vitals.life == Life::Alive
                                && s.identity.visible & (1 << self.team) != 0
                        })
                    })
                    .count();
                if threats >= 2 {
                    self.defense_at = now + 20.;
                    for q in by_distance(&fighters, p)
                        .into_iter()
                        .filter(|q| {
                            distance(q.position, p) <= 120.
                                && q.drill != "rout"
                                && self.role(q.id) != "retreat"
                        })
                        .take(2)
                        .collect::<Vec<_>>()
                    {
                        self.assign(q.id, "defend", now, id, p);
                        w.command(
                            self.team,
                            vec![q.id],
                            vec![],
                            Action::Defend {
                                position: p + self.forward() * 8.,
                                face: self.forward(),
                            },
                        )?;
                    }
                }
            }
            if self
                .roles
                .values()
                .any(|r| r.kind == "garrison" && r.target == id)
            {
                continue;
            }
            if let Some(q) = by_distance(&fighters, p)
                .into_iter()
                .find(|q| self.role(q.id) == "idle" && q.plan == 0 && q.drill.is_empty())
            {
                self.assign(q.id, "garrison", now, id, p);
                let bunker = c.structures.iter().find(|id| {
                    w.state.field.actors.structure(**id).is_some_and(|s| {
                        s.built && s.kind == "bunker" && distance(p, s.position) < 30.
                    })
                });
                let action = if let Some(bunker) = bunker {
                    Action::Enter(*bunker)
                } else {
                    Action::Defend {
                        position: p
                            + self.forward() * 9.
                            + Vector3::X * self.rng.randf_range(-6., 6.),
                        face: self.forward(),
                    }
                };
                w.command(self.team, vec![q.id], vec![], action)?;
            }
        }
        self.towns(w, &fighters)?;
        self.reinforce(w, &fighters)?;
        self.outposts(w, &fighters)?;
        if w.state
            .field
            .actors
            .structure(self.attack_target)
            .is_none_or(|s| s.team == self.team || s.gone)
        {
            self.attack_target = w
                .state
                .field
                .actors
                .iter()
                .filter_map(|a| match a {
                    Actor::Structure(s)
                        if s.team >= 0
                            && s.team != self.team
                            && s.built
                            && (s.kind == "fob"
                                && (s.seen & (1 << self.team) != 0 || s.completed_order <= 2)
                                || s.kind == "town") =>
                    {
                        Some((
                            s.id,
                            distance(front, s.zone_center.unwrap_or(s.position))
                                * if s.kind == "town" { 0.8 } else { 1. },
                        ))
                    }
                    _ => None,
                })
                .min_by(|a, b| a.1.total_cmp(&b.1).then(a.0.cmp(&b.0)))
                .map_or(0, |p| p.0);
        }
        let attackers: Vec<_> = fighters
            .iter()
            .copied()
            .filter(|q| {
                q.drill.is_empty()
                    && (self.role(q.id) == "idle"
                        || self.roles.get(&q.id).is_some_and(|r| {
                            r.kind == "attack"
                                && q.plan == 0
                                && (q.order != "assault" || now - r.since >= 90.)
                        }))
            })
            .collect();
        let target = w
            .state
            .field
            .actors
            .structure(self.attack_target)
            .map(|s| s.position);
        let mut vehicles = vec![];
        let mut back = vec![];
        for &id in &c.vehicles {
            let v = w.state.field.actors.vehicle(id).unwrap();
            let d = w.content.vehicle(v);
            match text(d, "base") {
                "boat" => {}
                "uav" => {
                    let position = target.unwrap_or(front + self.forward() * 45.);
                    if distance(v.uav_destination.unwrap_or(v.position), position) > 25. {
                        w.command(
                            self.team,
                            vec![],
                            vec![id],
                            Action::Move {
                                position,
                                face: self.forward(),
                                mode: 0,
                            },
                        )?;
                    }
                }
                "arty" => back.push(id),
                "lift_heli" if v.passengers.is_empty() => {}
                _ if !d["service"].is_null() => back.push(id),
                _ => vehicles.push(id),
            }
        }
        if now > self.back_at {
            self.back_at = now + 30.;
            for (i, &id) in back.iter().enumerate() {
                let v = w.state.field.actors.vehicle(id).unwrap();
                let position = front
                    - self.forward()
                        * if text(w.content.vehicle(v), "base") == "arty" {
                            24.
                        } else {
                            10.
                        }
                    + self.forward().cross(Vector3::Y) * (i as f32 - back.len() as f32 * 0.5) * 9.;
                if distance(v.position, position) > 14. && v.path_index as usize >= v.path.len() {
                    w.command(
                        self.team,
                        vec![],
                        vec![id],
                        Action::Move {
                            position,
                            face: self.forward(),
                            mode: 0,
                        },
                    )?;
                }
            }
        }
        let wave = if now < 600. { 3 } else { 4 };
        if let Some(target) = target.filter(|_| {
            now - self.last_wave > 25.
                && (attackers.len() >= wave || attackers.len() >= 2 && now - self.last_wave > 200.)
        }) {
            self.last_wave = now;
            let center =
                attackers.iter().map(|q| q.position).sum::<Vector3>() / attackers.len() as f32;
            let face = normalized(flat(target - center));
            let mut ids = vec![];
            for q in &attackers {
                if !self.try_tunnel(w, q, target)? {
                    self.assign(q.id, "attack", now, 0, target);
                    ids.push(q.id);
                }
            }
            if !ids.is_empty() {
                w.command(
                    self.team,
                    ids,
                    vec![],
                    Action::Assault {
                        position: target - face * 4.,
                        face,
                    },
                )?;
            }
            if !vehicles.is_empty() {
                w.command(
                    self.team,
                    vec![],
                    vehicles,
                    Action::Assault {
                        position: target - face * 25.,
                        face,
                    },
                )?;
            }
        } else if now - self.last_wave > 60. {
            let ids = vehicles
                .into_iter()
                .filter(|id| {
                    w.state.field.actors.vehicle(*id).is_some_and(|v| {
                        v.path_index as usize >= v.path.len() && distance(v.position, front) > 30.
                    })
                })
                .collect::<Vec<_>>();
            if !ids.is_empty() {
                w.command(
                    self.team,
                    vec![],
                    ids,
                    Action::Move {
                        position: front + self.forward() * 15.,
                        face: self.forward(),
                        mode: 0,
                    },
                )?;
            }
        }
        self.naval(w, c)?;
        self.sling(w, c)?;
        self.tunnel_progress(w)?;
        self.ambush(w, &attackers)?;
        Ok(())
    }
    fn outposts(
        &mut self,
        w: &mut Context<'_, '_, '_>,
        fighters: &[&Squad],
    ) -> Result<(), &'static str> {
        let now = w.state.field.now;
        if now < self.outpost_at || w.landmarks.is_empty() {
            return Ok(());
        }
        self.outpost_at = now + 15.;
        let Some(front) = self.front(w) else {
            return Ok(());
        };
        let mut held = vec![];
        let mut idle = 0_usize;
        for q in fighters {
            if self.role(q.id) == "outpost" {
                let role = &self.roles[&q.id];
                if now - role.since > 300.
                    || q.alive * 2 < q.total
                    || matches!(q.drill.as_str(), "rout" | "withdraw")
                {
                    self.assign(q.id, "idle", now, 0, Vector3::ZERO);
                } else {
                    held.push(role.position);
                }
            } else if self.role(q.id) == "town" {
                held.push(self.roles[&q.id].position);
            } else if self.role(q.id) == "idle" && q.plan == 0 {
                idle += 1;
            }
        }
        let wave = if now < 600. { 3 } else { 4 };
        let mut want = idle.saturating_sub(wave).min(1 + self.fobs(w).len() / 2);
        if held.is_empty() && idle >= 2 && now > 90. {
            want = want.max(1);
        }
        if held.len() >= want {
            return Ok(());
        }
        let face = self.forward();
        let mut best = None;
        let mut score = f32::NEG_INFINITY;
        for point in w.landmarks {
            let p = point.position;
            let ahead = flat(p - front).dot(face);
            if !(25. ..=190.).contains(&ahead)
                || held.iter().any(|h| distance(*h, p) < 40.)
                || sim::economy::fobs(&w.state.field.actors, 1 - self.team, false)
                    .any(|f| distance(f.position, p) < 90.)
            {
                continue;
            }
            let side = flat(p - front).dot(face.cross(Vector3::Y)).abs();
            let value = -ahead * 0.5 - side * 0.3
                + match point.kind.as_str() {
                    "town" => 40.,
                    "village" => 30.,
                    "woods" => 10.,
                    _ => 0.,
                };
            if value > score {
                score = value;
                best = Some(p);
            }
        }
        if let Some(p) = best {
            if let Some(q) = by_distance(fighters, p).into_iter().find(|q| {
                self.role(q.id) == "idle" && q.plan == 0 && q.drill.is_empty() && q.alive >= 2
            }) {
                self.assign(q.id, "outpost", now, 0, p);
                let g = &w.state.field.geometry;
                let at = g
                    .navigation
                    .planner
                    .nearest_walkable(p, sim::traversal::Ground::new(&g.terrain, &g.deck))
                    .unwrap_or(p);
                w.command(
                    self.team,
                    vec![q.id],
                    vec![],
                    Action::Defend { position: at, face },
                )?;
            }
        }
        Ok(())
    }
    fn towns(
        &mut self,
        w: &mut Context<'_, '_, '_>,
        fighters: &[&Squad],
    ) -> Result<(), &'static str> {
        let now = w.state.field.now;
        if now < self.town_at {
            return Ok(());
        }
        self.town_at = now + 6.;
        for q in fighters {
            let Some(role) = self.roles.get_mut(&q.id).filter(|r| r.kind == "town") else {
                continue;
            };
            let done = if q.alive * 2 < q.total || matches!(q.drill.as_str(), "rout" | "withdraw") {
                true
            } else if let Some(town) = w.state.field.actors.structure(role.target) {
                if town.team == self.team {
                    let held = *role.held.get_or_insert(now);
                    town.capture_team < 0 && now - held > 180.
                } else {
                    now - role.since > 300.
                }
            } else {
                true
            };
            if done {
                role.kind = "idle".into();
                role.since = now;
            }
        }
        let busy = self.roles.values().filter(|r| r.kind == "town").count();
        let from = |side, p| {
            sim::economy::fobs(&w.state.field.actors, side, true)
                .map(|s| distance(s.position, p))
                .fold(1e9_f32, f32::min)
        };
        let target = w
            .state
            .field
            .actors
            .iter()
            .filter_map(|a| match a {
                Actor::Structure(s) if s.kind == "town" => {
                    let threatened = s.team == self.team
                        && s.capture_team == 1 - self.team
                        && s.capture_progress > 0.;
                    if s.team == self.team && !threatened
                        || self
                            .roles
                            .values()
                            .filter(|r| r.kind == "town" && r.target == s.id)
                            .count()
                            >= if s.team == 1 - self.team { 2 } else { 1 }
                    {
                        return None;
                    }
                    let p = s.zone_center.unwrap_or(s.position);
                    let d = from(self.team, p);
                    let de = from(1 - self.team, p);
                    if de < 90.
                        || d > 340. && s.team != self.team
                        || busy >= 1 + fighters.len() / 3 && s.team != self.team
                    {
                        return None;
                    }
                    let score = -d
                        + if threatened { 150. } else { 0. }
                        + if s.variant == 1 { 60. } else { 0. }
                        - if s.team == 1 - self.team { 40. } else { 0. }
                        - if d > de + 60. { 150. } else { 0. };
                    Some((s.id, p, s.team, score))
                }
                _ => None,
            })
            .max_by(|a, b| a.3.total_cmp(&b.3).then(b.0.cmp(&a.0)));
        if let Some((id, p, team, _)) = target {
            if let Some(q) = by_distance(fighters, p).into_iter().find(|q| {
                matches!(self.role(q.id), "idle" | "outpost")
                    && q.plan == 0
                    && q.drill.is_empty()
                    && q.alive >= 2
            }) {
                self.assign(q.id, "town", now, id, p);
                let face = normalized(flat(p - q.position));
                w.command(
                    self.team,
                    vec![q.id],
                    vec![],
                    if team == 1 - self.team {
                        Action::Assault { position: p, face }
                    } else {
                        Action::Defend { position: p, face }
                    },
                )?;
            }
        }
        Ok(())
    }
    fn reinforce(
        &mut self,
        w: &mut Context<'_, '_, '_>,
        fighters: &[&Squad],
    ) -> Result<(), &'static str> {
        let now = w.state.field.now;
        let plans: Vec<_> = w
            .state
            .attacks
            .iter()
            .filter(|p| {
                p.team == self.team
                    && !p.done
                    && p.phase == sim::attack_plan::Phase::Fix
                    && self.helped.get(&p.id).is_none_or(|t| now - *t >= 40.)
            })
            .map(|p| (p.id, p.objective))
            .collect();
        self.helped
            .retain(|id, _| w.state.attacks.iter().any(|p| p.id == *id && !p.done));
        for (id, objective) in plans {
            self.helped.insert(id, now);
            let squads: Vec<_> = by_distance(fighters, objective)
                .into_iter()
                .filter(|q| {
                    distance(q.position, objective) <= 220.
                        && q.plan == 0
                        && matches!(self.role(q.id), "idle" | "attack")
                })
                .take(2)
                .map(|q| q.id)
                .collect();
            let Some(plan) = w.state.attacks.iter_mut().find(|p| p.id == id) else {
                continue;
            };
            let f = &mut w.state.field;
            for sid in squads {
                self.assign(sid, "attack", now, 0, objective);
                let mut ctx = sim::squad_movement::Context {
                    actors: &mut f.actors,
                    geometry: &mut f.geometry,
                    units: &f.units,
                    squads: &mut f.squads,
                    rng: &mut f.rng,
                    now: f.now,
                    town: f.town,
                    man: w.shared.movement,
                    automatic: w.shared.automatic,
                    player_building: w.shared.player_building,
                };
                w.events
                    .extend(plan.join(&mut ctx, sid)?.into_iter().map(Event::Attack));
            }
        }
        Ok(())
    }
    fn try_tunnel(
        &mut self,
        w: &mut Context<'_, '_, '_>,
        q: &Squad,
        destination: Vector3,
    ) -> Result<bool, &'static str> {
        if self.team != 1 {
            return Ok(false);
        }
        let tunnels: Vec<_> = w
            .state
            .field
            .actors
            .iter()
            .filter_map(|a| match a {
                Actor::Structure(s) if s.team == self.team && s.kind == "tunnel" && s.built => {
                    Some((s.id, s.position))
                }
                _ => None,
            })
            .collect();
        let entry = tunnels
            .iter()
            .filter(|p| distance(q.position, p.1) < 40.)
            .min_by(|a, b| distance(q.position, a.1).total_cmp(&distance(q.position, b.1)));
        let exit = tunnels
            .iter()
            .min_by(|a, b| distance(destination, a.1).total_cmp(&distance(destination, b.1)));
        let (Some(entry), Some(exit)) = (entry, exit) else {
            return Ok(false);
        };
        if entry.0 == exit.0
            || distance(destination, q.position) - distance(destination, exit.1) < 40.
        {
            return Ok(false);
        }
        self.assign(q.id, "tunnel", w.state.field.now, entry.0, destination);
        self.roles.get_mut(&q.id).unwrap().exit = exit.0;
        w.command(self.team, vec![q.id], vec![], Action::Enter(entry.0))?;
        Ok(true)
    }
    fn tunnel_progress(&mut self, w: &mut Context<'_, '_, '_>) -> Result<(), &'static str> {
        use sim::infantry_control::HiddenReason;
        for (&id, r) in self.roles.iter_mut().filter(|(_, r)| r.kind == "tunnel") {
            let Some(q) = w.state.field.squads.iter().find(|q| q.id == id) else {
                continue;
            };
            let mut alive = 0;
            let mut inside = 0;
            let mut travelling = 0;
            for s in q
                .members
                .iter()
                .filter_map(|id| w.state.field.actors.soldier(*id))
                .filter(|s| !matches!(s.vitals.life, Life::Dead | Life::Downed))
            {
                alive += 1;
                if s.vitals.life == Life::Hidden {
                    inside += usize::from(s.control.hidden == HiddenReason::TunnelWait);
                    travelling += usize::from(s.control.hidden == HiddenReason::TunnelTravel);
                }
            }
            if !r.sent && alive > 0 && inside == alive {
                w.command(
                    self.team,
                    vec![],
                    vec![],
                    Action::TunnelExit {
                        building: r.target,
                        exit: r.exit,
                    },
                )?;
                r.sent = true;
            } else if r.sent && inside == 0 && travelling == 0 || w.state.field.now - r.since > 60.
            {
                if inside > 0 {
                    w.command(
                        self.team,
                        vec![],
                        vec![],
                        Action::TunnelExit {
                            building: r.target,
                            exit: r.target,
                        },
                    )?;
                }
                r.kind = "idle".into();
                r.since = w.state.field.now;
            }
        }
        Ok(())
    }
    fn ambush(
        &mut self,
        w: &mut Context<'_, '_, '_>,
        fighters: &[&Squad],
    ) -> Result<(), &'static str> {
        let now = w.state.field.now;
        for (&id, r) in self.roles.iter_mut().filter(|(_, r)| r.kind == "ambush") {
            if !w.state.ambushes.iter().any(|p| p.squad == id && !p.done) {
                r.kind = "idle".into();
                r.since = now;
                self.ambush_at = self
                    .ambush_at
                    .max(now + if self.team == 1 { 120. } else { 200. });
            }
        }
        if now < self.ambush_at || self.roles.values().any(|r| r.kind == "ambush") {
            return Ok(());
        }
        self.ambush_at = now + 40.;
        let mut best = None;
        let mut score = -1e9_f32;
        // Supply roads already describe where the enemy drives; sample their segments directly.
        for f in sim::economy::fobs(&w.state.field.actors, 1 - self.team, false) {
            for segment in f.road.windows(2).take(128) {
                let zone = (segment[0] + segment[1]) * 0.5;
                let road = normalized(flat(segment[1] - segment[0]));
                if road.length_squared() < 0.5
                    || [self.team, 1 - self.team].into_iter().any(|t| {
                        sim::economy::fobs(&w.state.field.actors, t, true)
                            .any(|b| distance(zone, b.position) < 65.)
                    })
                {
                    continue;
                }
                for side in [road.cross(Vector3::Y), -road.cross(Vector3::Y)] {
                    let p = zone + side * 24.;
                    let terrain = &w.state.field.geometry.terrain;
                    let value =
                        (1. - terrain.concealment(p)) as f32 + terrain.cover(p) as f32 * 0.2;
                    if value > score {
                        score = value;
                        best = Some((zone, road, side));
                    }
                }
            }
        }
        let Some((zone, road, side)) = best else {
            return Ok(());
        };
        let free: Vec<_> = fighters
            .iter()
            .copied()
            .filter(|q| {
                self.role(q.id) == "idle" && q.plan == 0 && q.drill.is_empty() && q.alive >= 3
            })
            .collect();
        if free.is_empty() || free.len() == 1 && fighters.len() < 4 {
            return Ok(());
        }
        let q = by_distance(&free, zone)[0];
        let id = u32::try_from(w.state.next_ambush).map_err(|_| "ambush identity exhausted")?;
        let f = &mut w.state.field;
        let mut ctx = sim::squad_movement::Context {
            actors: &mut f.actors,
            geometry: &mut f.geometry,
            units: &f.units,
            squads: &mut f.squads,
            rng: &mut f.rng,
            now: f.now,
            town: f.town,
            man: w.shared.movement,
            automatic: w.shared.automatic,
            player_building: w.shared.player_building,
        };
        let (plan, events) =
            sim::ambush_plan::AmbushPlan::make(&mut ctx, id, q.id, zone, road, side)?;
        w.state.ambushes.push(plan);
        w.state.next_ambush += 1;
        w.events.extend(events.into_iter().map(Event::Brain));
        self.assign(q.id, "ambush", now, 0, zone);
        Ok(())
    }
    pub fn checkpoint(&self) -> Result<Vec<u8>, &'static str> {
        if !(0..=1).contains(&self.team)
            || self.phase > 3
            || self.next_tick > i64::MAX as u64
            || self.support_cursor > 100_000
            || self.roles.len() > 100_000
            || self.helped.len() > 100_000
            || self.next_vehicle.len() > 128
            || self.next_vehicle.contains('\0')
        {
            return Err("invalid commander state");
        }
        let mut w = Writer::new(b"FLCA\x01\0\0\0");
        w.byte(self.team as u8);
        w.byte(u8::from(self.permanent));
        w.u64(self.rng.seed());
        w.u64(self.rng.state());
        w.u64(self.next_tick);
        w.byte(self.phase);
        w.u32(self.attack_target);
        w.u32(self.support_cursor as u32);
        w.bytes(self.next_vehicle.as_bytes());
        for t in [
            self.last_wave,
            self.expand_at,
            self.defense_at,
            self.obstacle_at,
            self.recon_at,
            self.town_at,
            self.outpost_at,
            self.back_at,
            self.ambush_at,
        ] {
            if !clock(t) {
                return Err("invalid commander clock");
            }
            w.f64(t);
        }
        w.u32(self.roles.len() as u32);
        for (&id, r) in &self.roles {
            if id == 0
                || !matches!(
                    r.kind.as_str(),
                    "idle"
                        | "attack"
                        | "retreat"
                        | "defend"
                        | "garrison"
                        | "outpost"
                        | "town"
                        | "tunnel"
                        | "raid"
                        | "ambush"
                )
                || !clock(r.since)
                || !point(r.position)
                || r.held.is_some_and(|t| !clock(t))
            {
                return Err("invalid commander role");
            }
            w.u32(id);
            w.bytes(r.kind.as_bytes());
            w.f64(r.since);
            w.u32(r.target);
            w.point(r.position);
            w.byte(u8::from(r.held.is_some()));
            if let Some(t) = r.held {
                w.f64(t);
            }
            w.u32(r.exit);
            w.byte(u8::from(r.sent));
        }
        w.u32(self.helped.len() as u32);
        for (&id, &t) in &self.helped {
            if id == 0 || !clock(t) {
                return Err("invalid reinforcement clock");
            }
            w.u32(id);
            w.f64(t);
        }
        self.write_naval(&mut w)?;
        Ok(w.0)
    }
    pub fn restore(bytes: &[u8]) -> Result<Self, &'static str> {
        let mut r = Reader::new(bytes, b"FLCA\x01\0\0\0")?;
        let team = r.byte()? as i8;
        let permanent = r.boolean()?;
        let seed = r.u64()?;
        let mut c = Self::new(team, 0, 0)?;
        c.permanent = permanent;
        c.rng = SimulationRandom::new(seed);
        c.rng.set_state(r.u64()?);
        c.next_tick = r.u64()?;
        c.phase = r.byte()?;
        c.attack_target = r.u32()?;
        c.support_cursor = r.u32()? as usize;
        c.next_vehicle =
            String::from_utf8(r.bytes(128)?.to_vec()).map_err(|_| "invalid vehicle key")?;
        c.last_wave = r.f64()?;
        c.expand_at = r.f64()?;
        c.defense_at = r.f64()?;
        c.obstacle_at = r.f64()?;
        c.recon_at = r.f64()?;
        c.town_at = r.f64()?;
        c.outpost_at = r.f64()?;
        c.back_at = r.f64()?;
        c.ambush_at = r.f64()?;
        let n = r.u32()?;
        if n > 100_000 {
            return Err("commander role limit exceeded");
        }
        for _ in 0..n {
            let id = r.u32()?;
            let role = Role {
                kind: String::from_utf8(r.bytes(32)?.to_vec()).map_err(|_| "invalid role")?,
                since: r.f64()?,
                target: r.u32()?,
                position: r.point()?,
                held: if r.boolean()? { Some(r.f64()?) } else { None },
                exit: r.u32()?,
                sent: r.boolean()?,
            };
            if c.roles.insert(id, role).is_some() {
                return Err("duplicate commander role");
            }
        }
        let n = r.u32()?;
        if n > 100_000 {
            return Err("commander reinforcement limit exceeded");
        }
        for _ in 0..n {
            if c.helped.insert(r.u32()?, r.f64()?).is_some() {
                return Err("duplicate reinforcement");
            }
        }
        c.read_naval(&mut r)?;
        r.finish()?;
        if c.checkpoint()? != bytes {
            return Err("noncanonical commander checkpoint");
        }
        Ok(c)
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
