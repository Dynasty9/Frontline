//! Mission objectives and scripted reinforcements advance on the authoritative clock.
use crate::content::Content;
use frontline_core as sim;
use sim::actors::Actor;
use sim::infantry_vitals::Life;
use sim::match_commands::{Action, Command, Event, Profiles};
use sim::match_state::{MatchState, Shared, Upgrades, FIXED_DELTA};
use sim::vector::{normalized, Vector3};
use std::collections::{BTreeMap, BTreeSet};
mod codec;
mod info;
mod program;
#[cfg(test)]
mod tests;
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Kind {
    Bridgehead,
    Beachhead,
    Skyhook,
    Ambush,
    Kingpin,
}

impl Kind {
    pub fn parse(key: &str) -> Result<Self, &'static str> {
        match key {
            "bridgehead" => Ok(Self::Bridgehead),
            "beachhead" => Ok(Self::Beachhead),
            "skyhook" => Ok(Self::Skyhook),
            "ambush" => Ok(Self::Ambush),
            "kingpin" => Ok(Self::Kingpin),
            _ => Err("unknown mission"),
        }
    }

    pub fn key(self) -> &'static str {
        match self {
            Self::Bridgehead => "bridgehead",
            Self::Beachhead => "beachhead",
            Self::Skyhook => "skyhook",
            Self::Ambush => "ambush",
            Self::Kingpin => "kingpin",
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Goal {
    Reach,
    Clear,
    Hold,
    Guard,
    Destroy,
    Protect,
    Timer,
    Deliver,
    Extract,
}

#[derive(Clone, Debug, PartialEq)]
pub struct Objective {
    pub id: String,
    pub text: String,
    pub goal: Goal,
    pub state: u8,
    pub position: Option<Vector3>,
    pub radius: f64,
    pub need: i32,
    pub have: i32,
    pub seconds: f64,
    pub progress: f64,
    pub entities: Vec<u32>,
    pub optional: bool,
    pub label: String,
    pub lost: f64,
    pub grace: f64,
    pub fraction: f64,
    pub track: bool,
    pub afoot: bool,
    pub mark: bool,
    pub failure: String,
    pub done: u8,
}

impl Objective {
    fn new(id: &str, text: &str, goal: Goal, position: Option<Vector3>, radius: f64) -> Self {
        Self {
            id: id.into(),
            text: text.into(),
            goal,
            state: 0,
            position,
            radius,
            need: -1,
            have: 0,
            seconds: 0.,
            progress: 0.,
            entities: vec![],
            optional: false,
            label: String::new(),
            lost: 0.,
            grace: 30.,
            fraction: 0.75,
            track: false,
            afoot: false,
            mark: true,
            failure: String::new(),
            done: 0,
        }
    }
}

#[derive(Clone, Debug, PartialEq)]
pub struct Landmark {
    pub kind: String,
    pub position: Vector3,
}

#[derive(Clone, Debug, PartialEq)]
pub struct Mission {
    pub kind: Kind,
    pub side: i8,
    pub owners: Vec<i32>,
    pub forced_autopilot: bool,
    pub autopilot: bool,
    pub objectives: Vec<Objective>,
    pub over: u8,
    pub end_text: String,
    pub start_time: f64,
    pub deadline: f64,
    pub deadline_text: String,
    pub support: Vec<String>,
    pub focus: Vector3,
    pub focus_yaw: f64,
    events: Vec<(f64, u8)>,
    evaluate_timer: f64,
    drive_timer: f64,
    owner_cursor: u64,
    ours: BTreeSet<u32>,
    theirs: BTreeSet<u32>,
    places: BTreeMap<String, Vector3>,
    groups: BTreeMap<String, Vec<u32>>,
    route: Vec<Vector3>,
    waypoints: Vec<u32>,
    staged: BTreeMap<String, (String, f64)>,
    flags: u8,
}

fn flat(p: Vector3) -> Vector3 {
    Vector3::new(p.x, 0., p.z)
}

fn distance(a: Vector3, b: Vector3) -> f32 {
    flat(a - b).length()
}

fn alive(state: &MatchState, id: u32) -> bool {
    match state.field.actors.get(id) {
        Some(Actor::Soldier(s)) => {
            !s.identity.gone && matches!(s.vitals.life, Life::Alive | Life::Hidden)
        }

        Some(Actor::Vehicle(v)) => !v.gone && v.hp > 0.,
        Some(Actor::Structure(s)) => !s.gone && !s.wrecked && s.hp > 0.,
        _ => false,
    }
}

fn position(state: &MatchState, id: u32) -> Option<Vector3> {
    match state.field.actors.get(id)? {
        Actor::Soldier(s) => Some(s.motion.position),
        Actor::Vehicle(v) => Some(v.position),
        Actor::Structure(s) => Some(s.position),
        _ => None,
    }
}

struct Context<'a, 's, 'p> {
    state: &'a mut MatchState,
    content: &'a Content,
    shared: &'a Shared<'s>,
    profiles: &'a Profiles<'p>,
    host: i32,
    events: &'a mut Vec<Event>,
}

impl Context<'_, '_, '_> {
    fn command(
        &mut self,
        peer: i32,
        squads: Vec<u32>,
        vehicles: Vec<u32>,
        action: Action,
    ) -> Result<(), &'static str> {
        self.events.extend(self.state.execute(
            peer,
            "Mission",
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

    fn squad_order(&mut self, id: u32, action: Action) -> Result<(), &'static str> {
        if let Some(q) = self.state.field.squads.iter().find(|q| q.id == id) {
            self.command(q.owner, vec![id], vec![], action)?;
        }

        Ok(())
    }

    fn vehicle_order(&mut self, id: u32, action: Action) -> Result<(), &'static str> {
        if let Some(v) = self.state.field.actors.vehicle(id) {
            self.command(v.owner, vec![], vec![id], action)?;
        }

        Ok(())
    }

    fn walk(&self, p: Vector3) -> Vector3 {
        let g = &self.state.field.geometry;
        g.navigation
            .planner
            .nearest_walkable(p, sim::traversal::Ground::new(&g.terrain, &g.deck))
            .unwrap_or(p)
    }

    fn vehicle_approach(&mut self, from: Vector3, to: Vector3) -> Result<Vector3, &'static str> {
        // Mountain slopes can isolate the old flat-map reinforcement positions.
        let length = distance(from, to);
        let mut candidates = vec![from];
        let mut roads: Vec<_> = self.state.rules.network.roads[2]
            .iter()
            .flat_map(|road| road.iter().copied())
            .filter(|p| distance(*p, to) >= 60. && distance(*p, to) <= length * 1.5)
            .collect();
        roads.sort_by(|a, b| distance(*a, from).total_cmp(&distance(*b, from)));
        candidates.extend(roads.into_iter().take(64));
        for step in 1..=32 {
            let advance = step as f32 * 10.;
            if length - advance < 60. {
                break;
            }
            candidates.push(from.lerp(to, advance / length));
        }
        let g = &mut self.state.field.geometry;
        let ground = sim::traversal::Ground::new(&g.terrain, &g.deck);
        for requested in candidates {
            let p = g
                .navigation
                .planner
                .nearest_walkable_for(requested, true, false, ground)
                .ok_or("invalid mission vehicle approach")?;
            if g.navigation.planner.kind_at(p, true) != 3
                && distance(p, to) >= 60.
                && !g
                    .navigation
                    .planner
                    .find_path(
                        &mut g.navigation.vehicles,
                        p,
                        to,
                        true,
                        -1,
                        0.,
                        false,
                        ground,
                    )
                    .is_empty()
            {
                return Ok(p);
            }
        }
        Err("no reachable mission vehicle approach")
    }

    fn squad(
        &mut self,
        kind: &str,
        team: i8,
        owner: i32,
        p: Vector3,
        destination: Option<Vector3>,
    ) -> Result<u32, &'static str> {
        let position = self.walk(p);
        let profile = self.content.squad(kind).ok_or("unknown mission squad")?;
        let (id, events) = self.state.field.with_context(
            self.shared,
            Upgrades::from(&self.state.rules.economy),
            |w| {
                w.spawn_squad(
                    sim::squad_birth::Spawn {
                        team,
                        owner,
                        position,
                        destination,
                    },
                    profile,
                )
            },
        )?;
        self.events.extend(events.into_iter().map(Event::Squad));
        Ok(id)
    }

    fn vehicle(
        &mut self,
        kind: &str,
        team: i8,
        owner: i32,
        position: Vector3,
        yaw: f64,
        embark: bool,
    ) -> Result<u32, &'static str> {
        let profile = self
            .content
            .vehicle_birth(kind)
            .ok_or("unknown mission vehicle")?;
        let f = &mut self.state.field;
        let id = f.geometry.spawn_vehicle(
            &mut f.actors,
            sim::vehicle_birth::Spawn {
                team,
                owner,
                position,
                yaw,
            },
            profile,
        )?;
        if embark {
            let key = self.content.definitions().vehicles[kind].carry.as_str();
            if let Some(profile) = self.content.squad(key) {
                f.with_context(
                    self.shared,
                    Upgrades::from(&self.state.rules.economy),
                    |w| w.embark_new_squad(id, profile),
                )?;
            }
        }

        Ok(id)
    }

    fn board(&mut self, vehicle: u32, squad: u32) -> Result<(), &'static str> {
        let v = self
            .state
            .field
            .actors
            .vehicle(vehicle)
            .ok_or("missing mission transport")?;
        let d = self.content.vehicle(v);
        let ground_height = sim::traversal::Ground::new(
            &self.state.field.geometry.terrain,
            &self.state.field.geometry.deck,
        )
        .height(v.position);
        let seats = self.content.seats(&v.kind);
        let helicopter = matches!(d.base.as_str(), "attack_heli" | "lift_heli");
        let ids = self
            .state
            .field
            .squads
            .iter()
            .find(|q| q.id == squad)
            .ok_or("missing mission passengers")?
            .members
            .clone();
        for id in ids {
            if !self
                .state
                .field
                .actors
                .board(vehicle, id, seats, helicopter, ground_height)?
            {
                return Err("mission passengers exceed transport capacity");
            }
        }

        Ok(())
    }
}

impl Mission {
    pub fn owner_changed(&mut self, old: i32, next: i32) {
        if !self.owners.contains(&old) {
            return;
        }

        self.owners.retain(|p| *p != old);
        if !self.owners.contains(&next) {
            self.owners.push(next);
        }

        if next < 0 {
            self.autopilot = true;
        }
    }

    pub fn joined(
        &mut self,
        state: &mut MatchState,
        peer: i32,
        returned: bool,
    ) -> Result<sim::command_handoff::Changed, &'static str> {
        if state.owners.team_of(peer) != self.side {
            return Ok(Default::default());
        }

        let ai = -1 - i32::from(self.side);
        if self.owners.contains(&ai) {
            self.owners.retain(|p| *p != ai);
            if !self.owners.contains(&peer) {
                self.owners.push(peer);
            }

            self.autopilot = self.forced_autopilot;
            return state.owners.share_force(
                ai,
                peer,
                1,
                &mut state.field.squads,
                &mut state.field.actors,
            );
        }

        if self.owners.contains(&peer) {
            return Ok(Default::default());
        }

        self.owners.push(peer);
        if returned {
            return Ok(Default::default());
        }

        let mut largest = (0, 0);
        for &owner in &self.owners {
            let n = state
                .field
                .squads
                .iter()
                .filter(|q| q.team == self.side && q.owner == owner)
                .count();
            if n > largest.1 {
                largest = (owner, n);
            }
        }

        if largest.1 >= 2 {
            state.owners.share_force(
                largest.0,
                peer,
                2,
                &mut state.field.squads,
                &mut state.field.actors,
            )
        } else {
            Ok(Default::default())
        }
    }

    pub fn new(kind: Kind, state: &MatchState, autoplay: bool) -> Self {
        let side = if kind == Kind::Ambush { 1 } else { 0 };
        let mut owners: Vec<_> = state
            .owners
            .players
            .iter()
            .filter(|p| p.1 == side)
            .map(|p| p.0)
            .collect();
        let autopilot = autoplay || owners.is_empty();
        if owners.is_empty() {
            owners.push(-1 - i32::from(side));
        }

        Self {
            kind,
            side,
            owners,
            forced_autopilot: autoplay,
            autopilot,
            objectives: vec![],
            over: 0,
            end_text: String::new(),
            start_time: state.field.now,
            deadline: 0.,
            deadline_text: String::new(),
            support: vec![],
            focus: Vector3::ZERO,
            focus_yaw: 0.,
            events: vec![],
            evaluate_timer: 0.,
            drive_timer: 2.,
            owner_cursor: 0,
            ours: BTreeSet::new(),
            theirs: BTreeSet::new(),
            places: BTreeMap::new(),
            groups: BTreeMap::new(),
            route: vec![],
            waypoints: vec![],
            staged: BTreeMap::new(),
            flags: 0,
        }
    }

    fn owner(&mut self) -> i32 {
        let owner = self.owners[(self.owner_cursor % self.owners.len() as u64) as usize];
        self.owner_cursor += 1;
        owner
    }

    fn foe(&self) -> i8 {
        1 - self.side
    }

    fn p(&self, key: &str) -> Vector3 {
        self.places[key]
    }

    fn id(&self, key: &str) -> u32 {
        self.groups
            .get(key)
            .and_then(|v| v.first())
            .copied()
            .unwrap_or(0)
    }

    fn objective(&self, key: &str) -> Option<&Objective> {
        self.objectives.iter().find(|o| o.id == key)
    }

    fn active(&self, key: &str) -> bool {
        self.objective(key).is_some_and(|o| o.state == 1)
    }

    fn done(&self, key: &str) -> bool {
        self.objective(key).is_some_and(|o| o.state == 2)
    }

    fn add(&mut self, mut o: Objective) {
        if o.position.is_some() && o.mark {
            let letters = self
                .objectives
                .iter()
                .filter(|o| !o.label.is_empty())
                .count();
            o.label = char::from(b'A' + letters as u8).to_string();
        }

        self.objectives.push(o);
    }

    fn message(
        &self,
        w: &mut Context<'_, '_, '_>,
        kind: sim::match_commands::MessageKind,
        text: impl Into<String>,
        position: Option<Vector3>,
    ) {
        w.events.push(Event::Message {
            audience: sim::match_commands::Audience::Team(self.side),
            kind,
            text: text.into(),
            position,
        });
    }

    fn radio(
        &self,
        w: &mut Context<'_, '_, '_>,
        text: impl Into<String>,
        position: Option<Vector3>,
    ) {
        self.message(w, sim::match_commands::MessageKind::Radio, text, position);
    }

    fn start(&mut self, w: &mut Context<'_, '_, '_>, id: &str, done: u8) {
        if let Some(o) = self
            .objectives
            .iter_mut()
            .find(|o| o.id == id && o.state == 0)
        {
            o.state = 1;
            o.progress = 0.;
            o.done = done;
            let text = format!(
                "{}: {}",
                if o.optional {
                    "Optional"
                } else {
                    "New objective"
                },
                o.text
            );
            let p = o.position;
            self.message(w, sim::match_commands::MessageKind::Intel, text, p);
        }
    }

    fn after(&mut self, now: f64, delay: f64, event: u8) {
        self.events.push((now + delay, event));
    }

    fn once(&mut self, now: f64, key: String, stage: &str, again: f64) -> bool {
        if self
            .staged
            .get(&key)
            .is_some_and(|(s, t)| s == stage && (again <= 0. || now - t < again))
        {
            return false;
        }

        self.staged.insert(key, (stage.into(), now));
        true
    }

    fn census(&mut self, state: &MatchState) {
        for actor in state.field.actors.iter() {
            if let Actor::Soldier(s) = actor {
                if s.identity.team == self.side && self.owners.contains(&s.identity.owner) {
                    self.ours.insert(s.identity.id);
                } else if s.identity.team == self.foe() {
                    self.theirs.insert(s.identity.id);
                }
            }
        }
    }

    fn count(&self, w: &Context<'_, '_, '_>, p: Vector3, r: f64, ours: bool, afoot: bool) -> i32 {
        let mut count = 0;
        for a in w.state.field.actors.iter() {
            match a {
                Actor::Soldier(s)
                    if s.identity.team == if ours { self.side } else { self.foe() }
                        && (!ours || self.owners.contains(&s.identity.owner)) =>
                {
                    let riding = s.links.vehicle != 0;
                    if s.vitals.life != Life::Alive
                        && !(s.vitals.life == Life::Hidden && (!ours || riding))
                    {
                        continue;
                    }

                    if afoot && (riding || s.vitals.life != Life::Alive) {
                        continue;
                    }

                    let at = w
                        .state
                        .field
                        .actors
                        .vehicle(s.links.vehicle as u32)
                        .map_or(s.motion.position, |v| v.position);
                    count += i32::from(f64::from(distance(at, p)) <= r);
                }

                Actor::Vehicle(v)
                    if !afoot
                        && v.team == if ours { self.side } else { self.foe() }
                        && !v.gone
                        && v.hp > 0.
                        && v.position.y < 3.
                        && if ours {
                            self.owners.contains(&v.owner)
                        } else {
                            !(w.shared.automatic)(&v.kind)
                        } =>
                {
                    count += i32::from(f64::from(distance(v.position, p)) <= r);
                }

                _ => {}
            }
        }

        count
    }

    fn finish(&mut self, w: &mut Context<'_, '_, '_>, won: bool, text: impl Into<String>) {
        if self.over != 0 {
            return;
        }

        self.over = if won { 1 } else { 2 };
        self.end_text = text.into();
        for o in &mut self.objectives {
            if won && o.state == 1 && matches!(o.goal, Goal::Protect | Goal::Guard) {
                o.state = 2;
            }
        }

        self.census(w.state);
        w.state.victory.winner = if won { self.side } else { self.foe() };
    }

    fn evaluate(&mut self, w: &mut Context<'_, '_, '_>) -> Result<(), &'static str> {
        self.census(w.state);
        for index in 0..self.objectives.len() {
            if self.over != 0 {
                break;
            }

            let o = &self.objectives[index];
            if o.state != 1 {
                continue;
            }

            let p = o.position.unwrap_or(Vector3::ZERO);
            let ours = self.count(w, p, o.radius, true, o.afoot);
            let foes = self.count(w, p, o.radius, false, false);
            let o = &mut self.objectives[index];
            let (mut complete, mut failed) = (false, false);
            match o.goal {
                Goal::Reach => complete = ours >= o.need.max(1),
                Goal::Clear => {
                    o.have = foes;
                    complete = foes <= o.need.max(0) && ours > 0;
                }

                Goal::Hold | Goal::Guard => {
                    o.have = foes;
                    if ours > 0 {
                        if o.goal == Goal::Hold {
                            o.progress += 0.5;
                        }

                        o.lost = 0.;
                    } else if foes > 0 {
                        o.lost += 0.5;
                        failed = o.lost >= o.grace;
                    }

                    complete = o.goal == Goal::Hold && o.progress >= o.seconds && ours > foes;
                }

                Goal::Destroy | Goal::Protect => {
                    let left: Vec<_> = o
                        .entities
                        .iter()
                        .copied()
                        .filter(|id| alive(w.state, *id))
                        .collect();
                    o.have = (o.entities.len() - left.len()) as i32;
                    if o.track && !left.is_empty() {
                        let sum = left
                            .iter()
                            .filter_map(|id| position(w.state, *id))
                            .fold(Vector3::ZERO, |a, b| a + b);
                        o.position = Some(flat(sum / left.len() as f32));
                    }

                    if o.goal == Goal::Destroy {
                        complete = o.have
                            >= if o.need > 0 {
                                o.need
                            } else {
                                o.entities.len() as i32
                            };
                    } else {
                        failed = o.have > o.need.max(0);
                    }
                }

                Goal::Timer => {
                    o.progress += 0.5;
                    complete = o.progress >= o.seconds;
                }

                Goal::Deliver => {
                    let id = o.entities.first().copied().unwrap_or(0);
                    failed = !alive(w.state, id);
                    complete = w.state.field.actors.vehicle(id).is_some_and(|v| {
                        v.slung_by == 0
                            && v.position.y < 1.
                            && f64::from(distance(v.position, p)) <= o.radius
                    }) && !failed;
                }

                Goal::Extract => {
                    let (mut total, mut inside) = (0, 0);
                    for a in w.state.field.actors.iter() {
                        if let Actor::Soldier(s) = a {
                            if s.identity.team == self.side
                                && self.owners.contains(&s.identity.owner)
                                && (s.vitals.life == Life::Alive
                                    || s.vitals.life == Life::Hidden && s.links.vehicle != 0)
                            {
                                total += 1;
                                let at = w
                                    .state
                                    .field
                                    .actors
                                    .vehicle(s.links.vehicle as u32)
                                    .map_or(s.motion.position, |v| v.position);
                                inside += i32::from(f64::from(distance(at, p)) <= o.radius);
                            }
                        }
                    }

                    o.have = inside;
                    o.need = ((f64::from(total) * o.fraction).ceil() as i32).max(1);
                    complete = total > 0 && inside >= o.need;
                }
            }

            if failed {
                o.state = 3;
                let text = if o.failure.is_empty() {
                    format!("Objective failed: {}.", o.text)
                } else {
                    o.failure.clone()
                };
                if !o.optional {
                    self.finish(w, false, text);
                } else {
                    self.message(w, sim::match_commands::MessageKind::Alert, text, None);
                }
            } else if complete {
                o.state = 2;
                let event = o.done;
                let text = format!("Objective complete: {}", o.text);
                self.message(w, sim::match_commands::MessageKind::Info, text, None);
                self.event(w, event)?;
            }
        }

        if self.over == 0 {
            if self.deadline > 0. && w.state.field.now >= self.deadline {
                self.finish(w, false, if self.deadline_text.is_empty() { "Out of time.".into() } else { self.deadline_text.clone() });
            } else if w.state.field.now - self.start_time > 5. && !w.state.field.actors.iter().any(|a| matches!(a,Actor::Soldier(s) if s.identity.team==self.side&&self.owners.contains(&s.identity.owner)&&matches!(s.vitals.life,Life::Alive|Life::Hidden))) {
                self.finish(w, false, "Your force has been wiped out.");
            }
        }

        Ok(())
    }

    pub fn advance(
        &mut self,
        state: &mut MatchState,
        content: &Content,
        shared: &Shared<'_>,
        profiles: &Profiles<'_>,
        host: i32,
    ) -> Result<Vec<Event>, &'static str> {
        let mut events = vec![];
        let mut w = Context {
            state,
            content,
            shared,
            profiles,
            host,
            events: &mut events,
        };
        let mut i = 0;
        let mut fired = 0;
        while i < self.events.len() {
            if w.state.field.now >= self.events[i].0 {
                let (_, event) = self.events.remove(i);
                if self.over == 0 {
                    self.event(&mut w, event)?;
                    fired += 1;
                    if fired > 128 {
                        return Err("mission event loop exceeded limit");
                    }
                }
            } else {
                i += 1;
            }
        }

        self.evaluate_timer -= FIXED_DELTA;
        if self.evaluate_timer <= 0. {
            self.evaluate_timer = 0.5;
            if self.over == 0 {
                self.evaluate(&mut w)?;
            }
        }

        if self.autopilot && self.over == 0 {
            self.drive_timer -= FIXED_DELTA;
            if self.drive_timer <= 0. {
                self.drive_timer = 4.;
                self.drive(&mut w)?;
            }
        }

        Ok(events)
    }
}
