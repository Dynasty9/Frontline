//! Deliberate attacks retain their fire teams, timing and decisions across server checkpoints.
use crate::cover::{rotation, transform};
use crate::infantry::Goal;
use crate::infantry_action::Round;
use crate::infantry_commands::Command;
use crate::infantry_controller::Task;
use crate::infantry_vitals::Life;
use crate::squad_movement::{available, flat, point, Context, Event as SquadEvent};
use crate::state_codec::{Reader, Writer};
use crate::vector::{normalized, Vector3};
use crate::visibility::Visibility;
use std::collections::HashSet;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Element {
    pub squad: u32,
    /// -1 denotes the whole squad; 0 and 1 are its fire teams.
    pub team: i8,
}
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
#[repr(u8)]
pub enum Phase {
    Plan,
    Move,
    Assault,
    Fix,
    Fallback,
}
impl Phase {
    pub fn name(self) -> &'static str {
        match self {
            Self::Plan => "plan",
            Self::Move => "move",
            Self::Assault => "assault",
            Self::Fix => "fix",
            Self::Fallback => "fallback",
        }
    }
    fn stat(self) -> &'static str {
        match self {
            Self::Plan => "plan_plan",
            Self::Move => "plan_move",
            Self::Assault => "plan_assault",
            Self::Fix => "plan_fix",
            Self::Fallback => "plan_fallback",
        }
    }
}
#[derive(Clone, Debug, PartialEq)]
pub struct AttackPlan {
    pub id: u32,
    pub team: i8,
    pub objective: Vector3,
    pub axis: Vector3,
    pub side: f64,
    pub support: Vec<Element>,
    pub assault: Vec<Element>,
    pub support_position: Vector3,
    pub assault_position: Vector3,
    pub phase: Phase,
    pub phase_time: f64,
    pub fire_at: Vector3,
    pub support_set: bool,
    pub shifted: bool,
    pub rush_group: u8,
    pub rush_time: f64,
    pub start_count: u32,
    pub pinned_time: f64,
    pub clear_time: f64,
    pub said: Vec<String>,
    pub done: bool,
    pub tick_time: f64,
    pub smoked: bool,
}
#[derive(Clone, Debug, PartialEq)]
pub enum Event {
    Squad(SquadEvent),
    Speech {
        soldier: u32,
        text: String,
    },
    NeedsSupport {
        team: i8,
        squad: u32,
        position: Vector3,
    },
    Stat(&'static str),
}
impl Context<'_> {
    pub fn order_assault(
        &mut self,
        squad: u32,
        position: Vector3,
        face: Vector3,
        plan_id: u32,
        visibility: &Visibility,
    ) -> Result<(Option<AttackPlan>, Vec<Event>), &'static str> {
        if plan_id == 0 {
            return Err("invalid attack plan id");
        }
        let mut movement = vec![];
        let i = self.prepare_assault(squad, position, face, &mut movement)?;
        let mut out = movement.into_iter().map(Event::Squad).collect::<Vec<_>>();
        let face = self.squads[i].facing;
        let (plan, events) = AttackPlan::make(self, plan_id, &[squad], position, face, visibility)?;
        out.extend(events);
        if plan.is_none() {
            let mut movement = vec![];
            self.start_assault_bounds(i, &mut movement)?;
            out.extend(movement.into_iter().map(Event::Squad));
        }
        Ok((plan, out))
    }
}
impl AttackPlan {
    pub fn make(
        ctx: &mut Context<'_>,
        id: u32,
        squads: &[u32],
        objective: Vector3,
        face: Vector3,
        visibility: &Visibility,
    ) -> Result<(Option<Self>, Vec<Event>), &'static str> {
        if id == 0 || !point(objective) || !point(face) || squads.len() > 100_000 {
            return Err("invalid attack plan order");
        }
        let mut seen = HashSet::new();
        let mut live = vec![];
        for &id in squads {
            if !seen.insert(id) {
                return Err("duplicate attack squad");
            }
            let i = ctx.index(id)?;
            if ctx.squads[i].alive(ctx.actors).next().is_some() {
                live.push(i);
            }
        }
        if live.is_empty() {
            return Ok((None, vec![]));
        }
        let team = ctx.squads[live[0]].team;
        if live.iter().any(|&i| ctx.squads[i].team != team) {
            return Err("mixed attack teams");
        }
        let mut center = Vector3::ZERO;
        for &i in &live {
            center += ctx.squads[i].centroid(ctx.now, ctx.actors);
        }
        center /= live.len() as f32;
        let to = flat(objective - center);
        let mut p = Self {
            id,
            team,
            objective,
            axis: if to.length() > 1.0 {
                normalized(to)
            } else if f64::from(face.length()) > 0.1 {
                face
            } else {
                Vector3::NEG_Z
            },
            side: 1.0,
            support: vec![],
            assault: vec![],
            support_position: Vector3::ZERO,
            assault_position: Vector3::ZERO,
            phase: Phase::Plan,
            phase_time: 0.0,
            fire_at: Vector3::ZERO,
            support_set: false,
            shifted: false,
            rush_group: 0,
            rush_time: 0.0,
            start_count: 0,
            pinned_time: 0.0,
            clear_time: 0.0,
            said: vec![],
            done: false,
            tick_time: -1.0,
            smoked: false,
        };
        let mut out = vec![];
        if live.len() >= 2 {
            let mut best = live[0];
            let mut score = -1e9;
            for &i in &live {
                let q = &mut ctx.squads[i];
                let power = q
                    .alive(ctx.actors)
                    .map(|s| {
                        if matches!(s.identity.unit.as_str(), "mg_gunner" | "pkm") {
                            3.0
                        } else {
                            1.0
                        }
                    })
                    .sum::<f64>();
                let power = power
                    - f64::from(flat(q.centroid(ctx.now, ctx.actors) - center).length()) * 0.02;
                if power > score {
                    score = power;
                    best = i;
                }
            }
            p.support.push(Element {
                squad: ctx.squads[best].id,
                team: -1,
            });
            for &i in &live {
                if i != best {
                    p.assault.push(Element {
                        squad: ctx.squads[i].id,
                        team: -1,
                    });
                }
            }
        } else {
            let i = live[0];
            let alive = ctx.squads[i]
                .alive(ctx.actors)
                .map(|s| s.identity.id)
                .collect::<Vec<_>>();
            if alive.len() < 4 {
                return Ok((None, out));
            }
            let mut events = vec![];
            let leader = ctx.leader(i, &mut events);
            out.extend(events.into_iter().map(Event::Squad));
            let mut teams = [vec![], vec![]];
            for &id in &alive {
                let s = ctx.actors.soldier(id).unwrap();
                if matches!(s.identity.unit.as_str(), "mg_gunner" | "pkm") {
                    teams[0].push(id);
                } else if id == leader
                    || matches!(
                        s.identity.unit.as_str(),
                        "medic" | "r_medic" | "at_soldier" | "rpg"
                    )
                {
                    teams[1].push(id);
                }
            }
            for id in alive {
                if teams.iter().any(|t| t.contains(&id)) {
                    continue;
                }
                let k = usize::from(teams[0].len() > teams[1].len());
                teams[k].push(id);
            }
            for (team, ids) in teams.into_iter().enumerate() {
                for id in ids {
                    ctx.actors.soldier_mut(id).unwrap().fight.fire_team = team as u8;
                }
            }
            p.support.push(Element {
                squad: ctx.squads[i].id,
                team: 0,
            });
            p.assault.push(Element {
                squad: ctx.squads[i].id,
                team: 1,
            });
        }
        for &i in &live {
            ctx.squads[i].plan = id;
        }
        p.start_count = p.members(ctx, &p.assault).len() as u32;
        p.choose_ground(ctx, center, visibility);
        Ok((Some(p), out))
    }
    fn elements(&self) -> impl Iterator<Item = &Element> {
        self.support.iter().chain(&self.assault)
    }
    fn members(&self, ctx: &Context<'_>, elements: &[Element]) -> Vec<u32> {
        let mut out = vec![];
        for e in elements {
            let Some(q) = ctx
                .squads
                .iter()
                .find(|q| q.id == e.squad && q.plan == self.id)
            else {
                continue;
            };
            for s in q.alive(ctx.actors) {
                if s.orders.detached || !available(s) && s.duty.kind != Task::Fight {
                    continue;
                }
                if e.team >= 0 && s.fight.fire_team as i8 != e.team {
                    continue;
                }
                out.push(s.identity.id);
            }
        }
        out
    }
    fn all_members(&self, ctx: &Context<'_>) -> Vec<u32> {
        let mut out = self.members(ctx, &self.support);
        out.extend(self.members(ctx, &self.assault));
        out
    }
    fn centroid(&self, ctx: &Context<'_>, ids: &[u32]) -> Vector3 {
        if ids.is_empty() {
            return self.objective;
        }
        let mut center = Vector3::ZERO;
        for &id in ids {
            center += ctx.actors.soldier(id).unwrap().motion.position;
        }
        center / ids.len() as f32
    }
    fn contact(&self, ctx: &mut Context<'_>) -> bool {
        for e in self.elements() {
            if let Some(q) = ctx.squads.iter_mut().find(|q| q.id == e.squad) {
                if q.in_combat(ctx.now) {
                    return true;
                }
            }
        }
        false
    }
    fn choose_ground(&mut self, ctx: &mut Context<'_>, start: Vector3, visibility: &Visibility) {
        let distance = f64::from(flat(self.objective - start).length());
        let back = if distance < 32.0 {
            distance
        } else {
            (distance * 0.55).clamp(28.0, 60.0)
        };
        let lateral = self.axis.cross(Vector3::Y);
        let spread = f64::from(
            (self.centroid(ctx, &self.members(ctx, &self.assault))
                - self.centroid(ctx, &self.members(ctx, &self.support)))
            .dot(lateral),
        );
        let nav = &ctx.geometry.navigation.planner;
        let terrain = &ctx.geometry.terrain;
        let inside = |p: Vector3, margin: f64| {
            f64::from(p.x.abs()) < terrain.half() - margin
                && f64::from(p.z.abs()) < terrain.half() - margin
        };
        let mut best = -1e9;
        for side in [-1.0, 1.0] {
            let p = nav
                .nearest_walkable(
                    self.objective - self.axis * 16.0 + lateral * side as f32 * 22.0,
                    crate::traversal::Ground::new(&ctx.geometry.terrain, &ctx.geometry.deck),
                )
                .unwrap();
            let mut score = (spread * side / 6.0).clamp(-3.0, 3.0);
            if !inside(p, 8.0) {
                score -= 100.0;
            }
            score += f64::from(terrain.cover_vs(p, self.objective)) * 2.0;
            let mid = start + (p - start) * 0.5;
            if terrain.kind(mid) == 2 {
                score += 2.0;
            }
            score += f64::from(terrain.cover_vs(mid, self.objective));
            for e in self.elements() {
                if let Some(q) = ctx.squads.iter().find(|q| q.id == e.squad) {
                    for k in &q.known {
                        if flat(k.report.position - self.objective).length() < 50.0 {
                            score -= 8.0 / f64::from(flat(k.report.position - p).length()).max(4.0)
                                * 4.0;
                        }
                    }
                }
            }
            score += f64::from(ctx.rng.randf_range(0.0, 0.6));
            if score > best {
                best = score;
                self.side = side;
            }
        }
        self.assault_position = nav
            .nearest_walkable(
                self.objective - self.axis * 16.0 + lateral * self.side as f32 * 22.0,
                crate::traversal::Ground::new(&ctx.geometry.terrain, &ctx.geometry.deck),
            )
            .unwrap();
        let support = self.centroid(ctx, &self.members(ctx, &self.support));
        if self.contact(ctx) && flat(self.objective - support).length() < 80.0 {
            self.support_position = support;
            return;
        }
        let nav = &ctx.geometry.navigation.planner;
        let terrain = &ctx.geometry.terrain;
        self.support_position = nav
            .nearest_walkable(
                self.objective
                    - self.axis * back as f32
                    - lateral * self.side as f32 * (back * 0.2).min(10.0) as f32,
                crate::traversal::Ground::new(&ctx.geometry.terrain, &ctx.geometry.deck),
            )
            .unwrap();
        let mut best = -1e9;
        for r in [28.0, 38.0, 48.0, 58.0] {
            if r > distance + 4.0 {
                continue;
            }
            for degree in [0.0_f64, 12.0, 24.0, 36.0] {
                let direction = transform(rotation(degree.to_radians() * -self.side), -self.axis);
                let p = nav
                    .nearest_walkable(
                        self.objective + direction * r as f32,
                        crate::traversal::Ground::new(&ctx.geometry.terrain, &ctx.geometry.deck),
                    )
                    .unwrap();
                if f64::from(p.x.abs()) >= terrain.half() - 6.0
                    || f64::from(p.z.abs()) >= terrain.half() - 6.0
                {
                    continue;
                }
                let mut score =
                    f64::from(terrain.cover_vs(p, self.objective)) * 3.0 - r * 0.03 - degree * 0.01;
                if terrain.kind(p) == 2 {
                    score += 1.0;
                }
                let (eye, target) = (p + Vector3::new(0.0, 1.4, 0.0), self.objective + Vector3::Y);
                if ctx.geometry.collision.ray(eye, target, &[]).is_some()
                    || visibility.smoke_blocks(eye, target)
                {
                    score -= 2.5;
                }
                if score > best {
                    best = score;
                    self.support_position = p;
                }
            }
        }
    }
    fn fire_target(&self, ctx: &Context<'_>) -> Vector3 {
        let mut position = Vector3::ZERO;
        let mut n = 0;
        for e in self.elements() {
            if let Some(q) = ctx.squads.iter().find(|q| q.id == e.squad) {
                for k in &q.known {
                    if flat(k.report.position - self.objective).length() < 45.0
                        && ctx.now - k.report.time < 30.0
                    {
                        position += k.report.position;
                        n += 1;
                    }
                }
            }
        }
        if n == 0 {
            self.objective + Vector3::new(0.0, 0.5, 0.0)
        } else {
            position / n as f32
        }
    }
    fn place(
        ctx: &mut Context<'_>,
        ids: &[u32],
        at: Vector3,
        face: Vector3,
        mode: u8,
        wide: bool,
    ) -> Result<(), &'static str> {
        if ids.is_empty() {
            return Ok(());
        }
        let slots = ctx.formation(at, face, ids, wide)?;
        for (&id, slot) in ids.iter().zip(slots) {
            ctx.command(id, Command::Move { slot, mode, face })?;
            ctx.actors.soldier_mut(id).unwrap().orders.leash = 4.5;
        }
        Ok(())
    }
    fn arrived(ctx: &Context<'_>, ids: &[u32], fraction: f64) -> bool {
        ids.iter()
            .filter(|&&id| {
                let s = ctx.actors.soldier(id).unwrap();
                !(s.orders.purpose == Goal::Slot && s.is_moving())
            })
            .count()
            >= (ids.len() as f64 * fraction).ceil() as usize
    }
    fn spoken(&self, key: &str) -> bool {
        self.said.iter().any(|s| s == key)
    }
    fn forget(&mut self, key: &str) {
        self.said.retain(|s| s != key);
    }
    fn speak(ctx: &mut Context<'_>, id: u32, lines: &[&str], force: bool, out: &mut Vec<Event>) {
        let text = lines[ctx.rng.randi() as usize % lines.len()];
        let s = ctx.actors.soldier_mut(id).unwrap();
        if force || s.vitals.speech_cooldown <= 0.0 {
            s.vitals.speech_cooldown = 2.6;
            out.push(Event::Speech {
                soldier: id,
                text: text.into(),
            });
        }
    }
    fn say(
        &mut self,
        ctx: &mut Context<'_>,
        key: &str,
        ids: &[u32],
        lines: &[&str],
        out: &mut Vec<Event>,
    ) {
        if self.spoken(key) || ids.is_empty() {
            return;
        }
        self.said.push(key.into());
        let mut who = ids[0];
        for &id in ids {
            if ctx.actors.soldier(id).unwrap().flags & 64 != 0 {
                who = id;
            }
        }
        Self::speak(ctx, who, lines, true, out);
    }
    fn set_phase(&mut self, ctx: &Context<'_>, phase: Phase, out: &mut Vec<Event>) {
        self.phase = phase;
        self.phase_time = ctx.now;
        out.push(Event::Stat(phase.stat()));
        if phase == Phase::Fix && !self.spoken("fix_msg") {
            self.said.push("fix_msg".into());
            out.push(Event::NeedsSupport {
                team: self.team,
                squad: self.support[0].squad,
                position: self.objective,
            });
        }
    }
    fn suppress(ctx: &mut Context<'_>, ids: &[u32], at: Vector3) {
        for &id in ids {
            let s = ctx.actors.soldier_mut(id).unwrap();
            s.fight.covering_until = ctx.now + 1.5;
            s.fight.covering_position = at;
        }
    }
    fn suppression(ctx: &Context<'_>, ids: &[u32]) -> f64 {
        ids.iter()
            .map(|&id| ctx.actors.soldier(id).unwrap().vitals.suppression)
            .sum::<f64>()
            / ids.len().max(1) as f64
    }
    fn known_defenders(&self, ctx: &Context<'_>) -> usize {
        let mut seen = HashSet::new();
        for e in self.elements() {
            if let Some(q) = ctx.squads.iter().find(|q| q.id == e.squad) {
                for k in &q.known {
                    if flat(k.report.position - self.objective).length() < 30.0
                        && ctx.now - k.report.time < 25.0
                        && ctx
                            .actors
                            .soldier(k.id)
                            .is_some_and(|s| !s.identity.gone && s.vitals.life == Life::Alive)
                    {
                        seen.insert(k.id);
                    }
                }
            }
        }
        seen.len()
    }
    fn enemies(&self, ctx: &Context<'_>) -> Result<usize, &'static str> {
        Ok(ctx
            .actors
            .units_near(ctx.units, self.objective, 18.0, self.team)?
            .into_iter()
            .filter(|&id| {
                ctx.actors
                    .soldier(id)
                    .is_some_and(|s| s.identity.team >= 0 && s.vitals.life == Life::Alive)
            })
            .count())
    }
    pub fn tick(&mut self, ctx: &mut Context<'_>) -> Result<Vec<Event>, &'static str> {
        self.validate_context(ctx)?;
        let mut out = vec![];
        if self.done || ctx.now - self.tick_time < 0.45 {
            return Ok(out);
        }
        self.tick_time = ctx.now;
        let sup = self.members(ctx, &self.support);
        let asl = self.members(ctx, &self.assault);
        let all = [sup.as_slice(), asl.as_slice()].concat();
        if all.is_empty() {
            self.finish(ctx, false, &mut out)?;
            return Ok(out);
        }
        self.fire_at = self.fire_target(ctx);
        match self.phase {
            Phase::Plan => {
                if self.phase_time == 0.0 {
                    self.phase_time = ctx.now;
                    let side = if self.side > 0.0 { "right" } else { "left" };
                    let first = if self.support[0].team < 0 {
                        format!(
                            "{}, base of fire on the objective! {}, with me, we go {side}!",
                            self.name(ctx, &self.support),
                            self.name(ctx, &self.assault)
                        )
                    } else {
                        format!("Alpha, base of fire! Bravo on me, we flank {side}!")
                    };
                    self.say(ctx, "plan", &all, &[&first, &format!("Listen up: guns set up there and fix them, the rest of us hook round the {side}!"), &format!("Support by fire from that position. Assault team, {side} flank, on me!")], &mut out);
                    for &id in &all {
                        ctx.actors.soldier_mut(id).unwrap().stop_moving()?;
                        ctx.geometry.navigation.planner.cancel(u64::from(id));
                    }
                } else if ctx.now - self.phase_time > 2.0 {
                    let foes = self.known_defenders(ctx);
                    if foes > 0 && (all.len() as f64) < foes as f64 * 1.4 {
                        self.set_phase(ctx, Phase::Fix, &mut out);
                        self.say(
                            ctx,
                            "fix",
                            &all,
                            &[
                                "Too many of them! We hold here and fix them, need support!",
                                "They outnumber us! Go firm, keep them pinned!",
                                "Can't take that alone. Base of fire, everyone, call it in!",
                            ],
                            &mut out,
                        );
                        let at = self.centroid(ctx, &all);
                        let mode = u8::from(self.contact(ctx));
                        Self::place(ctx, &all, at, self.axis, mode, true)?;
                        return Ok(out);
                    }
                    self.set_phase(ctx, Phase::Move, &mut out);
                    let mode = u8::from(self.contact(ctx));
                    Self::place(
                        ctx,
                        &sup,
                        self.support_position,
                        normalized(flat(self.fire_at - self.support_position)),
                        mode,
                        true,
                    )?;
                    Self::place(
                        ctx,
                        &asl,
                        self.assault_position,
                        normalized(flat(self.objective - self.assault_position)),
                        0,
                        true,
                    )?;
                }
            }
            Phase::Move => {
                let foes = self.known_defenders(ctx);
                if foes > 0 && (all.len() as f64) < foes as f64 * 1.2 && !self.spoken("fix") {
                    self.set_phase(ctx, Phase::Fix, &mut out);
                    self.say(
                        ctx,
                        "fix",
                        &all,
                        &[
                            "Too many of them! Go firm, keep them pinned!",
                            "Contact, too many! Base of fire, everyone!",
                            "Can't take that alone. Hold and suppress!",
                        ],
                        &mut out,
                    );
                    Self::place(ctx, &all, self.centroid(ctx, &all), self.axis, 2, true)?;
                    return Ok(out);
                }
                if !self.support_set
                    && (Self::arrived(ctx, &sup, 0.6) || ctx.now - self.phase_time > 40.0)
                {
                    self.support_set = true;
                    self.say(
                        ctx,
                        "set",
                        &sup,
                        &[
                            "Base of fire set!",
                            "Guns up! Firing!",
                            "Alpha set, engaging!",
                            "Set! Suppressing!",
                        ],
                        &mut out,
                    );
                }
                if self.support_set {
                    Self::suppress(ctx, &sup, self.fire_at);
                }
                if self.support_set
                    && (Self::arrived(ctx, &asl, 0.6) || ctx.now - self.phase_time > 50.0)
                {
                    self.set_phase(ctx, Phase::Assault, &mut out);
                    self.rush_time = 0.0;
                    self.say(
                        ctx,
                        "go",
                        &asl,
                        &[
                            "Assault! Go, go, go!",
                            "Bravo, move! Covering fire!",
                            "On my mark... move!",
                        ],
                        &mut out,
                    );
                }
            }
            Phase::Assault => {
                let center = self.centroid(ctx, &asl);
                let distance = f64::from(flat(self.objective - center).length());
                if distance > 24.0 {
                    Self::suppress(ctx, &sup, self.fire_at);
                } else if distance > 11.0 {
                    if !self.shifted {
                        self.shifted = true;
                        self.say(
                            ctx,
                            "shift",
                            &sup,
                            &[
                                "Shift fire! Shift fire!",
                                "Shifting! Watch the friendlies!",
                                "Lift and shift!",
                            ],
                            &mut out,
                        );
                    }
                    Self::suppress(
                        ctx,
                        &sup,
                        self.objective + normalized(flat(self.objective - center)) * 18.0
                            - self.axis.cross(Vector3::Y) * self.side as f32 * 8.0,
                    );
                }
                self.pinned_time = if Self::suppression(ctx, &asl) > 70.0 {
                    self.pinned_time + 0.5
                } else {
                    0.0
                };
                if asl.len() * 10 < self.start_count as usize * 4 || self.pinned_time > 10.0 {
                    self.set_phase(ctx, Phase::Fallback, &mut out);
                    self.say(
                        ctx,
                        "fallback",
                        &asl,
                        &[
                            "Fall back to the assault position!",
                            "Too hot! Back, back!",
                            "Pull back! Regroup!",
                        ],
                        &mut out,
                    );
                    Self::place(
                        ctx,
                        &asl,
                        self.assault_position,
                        normalized(flat(self.objective - self.assault_position)),
                        2,
                        true,
                    )?;
                    return Ok(out);
                }
                if distance < 7.0 || distance < 20.0 && self.enemies(ctx)? == 0 {
                    self.clear_time += 0.5;
                    if self.clear_time > 2.0 || distance < 7.0 {
                        self.finish(ctx, true, &mut out)?;
                        return Ok(out);
                    }
                } else {
                    self.clear_time = 0.0;
                }
                self.rushes(ctx, &asl, distance, &mut out)?;
            }
            Phase::Fix => {
                Self::suppress(ctx, &all, self.fire_at);
                let foes = self.known_defenders(ctx);
                if foes == 0 || all.len() as f64 >= foes as f64 * 1.4 {
                    self.forget("plan");
                    self.set_phase(ctx, Phase::Plan, &mut out);
                    self.phase_time = 0.0;
                } else if ctx.now - self.phase_time > 120.0 {
                    self.finish(ctx, false, &mut out)?;
                }
            }
            Phase::Fallback => {
                Self::suppress(ctx, &sup, self.fire_at);
                Self::suppress(ctx, &asl, self.fire_at);
                if ctx.now - self.phase_time > 20.0 {
                    if Self::suppression(ctx, &asl) < 40.0
                        && asl.len() * 10 >= self.start_count as usize * 4
                    {
                        self.set_phase(ctx, Phase::Assault, &mut out);
                        self.shifted = false;
                        self.forget("shift");
                        self.say(
                            ctx,
                            "again",
                            &asl,
                            &["Again! Move!", "Second try, go!", "They're down, go now!"],
                            &mut out,
                        );
                    } else if ctx.now - self.phase_time > 60.0 {
                        self.finish(ctx, false, &mut out)?;
                    }
                }
            }
        }
        Ok(out)
    }
    fn rushes(
        &mut self,
        ctx: &mut Context<'_>,
        asl: &[u32],
        distance: f64,
        out: &mut Vec<Event>,
    ) -> Result<(), &'static str> {
        let mut groups = [vec![], vec![]];
        for (i, &id) in asl.iter().enumerate() {
            groups[i % 2].push(id);
        }
        let mover = &groups[self.rush_group as usize];
        Self::suppress(ctx, &groups[1 - self.rush_group as usize], self.fire_at);
        if ctx.now < self.rush_time && !Self::arrived(ctx, mover, 0.75)
            || ctx.now < self.rush_time - 3.0
        {
            return Ok(());
        }
        self.rush_group = 1 - self.rush_group;
        let mover = if groups[self.rush_group as usize].is_empty() {
            &groups[1 - self.rush_group as usize]
        } else {
            &groups[self.rush_group as usize]
        };
        let center = self.centroid(ctx, mover);
        let leg = (f64::from(flat(self.objective - center).length()) - 2.0).clamp(2.0, 9.0);
        let direction = normalized(flat(self.objective - center));
        if !self.smoked && distance > 22.0 && self.enemies(ctx)? > 0 {
            for &id in asl {
                if ctx.actors.soldier(id).unwrap().fight.smokes > 0 {
                    self.smoked = true;
                    let center = self.centroid(ctx, asl);
                    ctx.command(
                        id,
                        Command::Throw {
                            position: center + (self.objective - center) * 0.45,
                            round: Round::Smoke,
                        },
                    )?;
                    Self::speak(
                        ctx,
                        id,
                        &["Smoke out!", "Popping smoke!", "Smoke! Wait for it..."],
                        true,
                        out,
                    );
                    self.rush_time = ctx.now + 3.0;
                    return Ok(());
                }
            }
        }
        Self::place(
            ctx,
            mover,
            center + direction * leg as f32,
            direction,
            2,
            false,
        )?;
        for &id in mover {
            ctx.actors.soldier_mut(id).unwrap().fight.covering_until = 0.0;
        }
        self.rush_time = ctx.now + 6.0;
        if distance < 26.0 {
            for &id in mover {
                if ctx.actors.soldier(id).unwrap().grenades.frags > 0 && self.enemies(ctx)? > 0 {
                    let position = self.objective
                        + Vector3::new(
                            ctx.rng.randf_range(-4.0, 4.0),
                            0.0,
                            ctx.rng.randf_range(-4.0, 4.0),
                        );
                    ctx.command(
                        id,
                        Command::Throw {
                            position,
                            round: Round::Frag,
                        },
                    )?;
                    break;
                }
            }
        }
        if f64::from(ctx.rng.randf()) < 0.4 && !mover.is_empty() {
            Self::speak(
                ctx,
                mover[0],
                &[
                    "I'm up!",
                    "Moving!",
                    "Covering!",
                    "Up! He sees me! Down!",
                    "Go!",
                ],
                false,
                out,
            );
        }
        Ok(())
    }
    fn finish(
        &mut self,
        ctx: &mut Context<'_>,
        won: bool,
        out: &mut Vec<Event>,
    ) -> Result<(), &'static str> {
        if self.done {
            return Ok(());
        }
        self.done = true;
        out.push(Event::Stat(if won { "plan_won" } else { "plan_failed" }));
        let mut squads = vec![];
        for e in self.elements() {
            if !squads.contains(&e.squad)
                && ctx
                    .squads
                    .iter()
                    .any(|q| q.id == e.squad && q.plan == self.id)
            {
                squads.push(e.squad);
            }
        }
        for &id in &squads {
            ctx.squads.iter_mut().find(|q| q.id == id).unwrap().plan = 0;
        }
        // Clearing membership also silences the old plan's victory call in the reference game.
        for (i, &id) in squads.iter().enumerate() {
            let at = if won {
                self.objective
                    + self.axis.cross(Vector3::Y)
                        * (i as f64 - (squads.len() - 1) as f64 * 0.5) as f32
                        * 12.0
            } else {
                ctx.squads
                    .iter_mut()
                    .find(|q| q.id == id)
                    .unwrap()
                    .centroid(ctx.now, ctx.actors)
            };
            out.extend(
                ctx.order_defend(id, at, self.axis, false)?
                    .into_iter()
                    .map(Event::Squad),
            );
        }
        Ok(())
    }
    pub fn join(&mut self, ctx: &mut Context<'_>, squad: u32) -> Result<Vec<Event>, &'static str> {
        self.validate_context(ctx)?;
        let i = ctx.index(squad)?;
        if ctx.squads[i].team != self.team {
            return Err("reinforcement belongs to another team");
        }
        if self.elements().any(|e| e.squad == squad) {
            return Ok(vec![]);
        }
        if self.assault.len() >= 100_000 {
            return Err("attack element limit exceeded");
        }
        let count = ctx.squads[i].alive(ctx.actors).count() as u32;
        if self.start_count + count > 100_000 {
            return Err("attack member limit exceeded");
        }
        let mut out = ctx
            .order_assault_bounds(squad, self.objective, self.axis)?
            .into_iter()
            .map(Event::Squad)
            .collect::<Vec<_>>();
        ctx.squads[i].plan = self.id;
        let element = Element { squad, team: -1 };
        self.assault.push(element);
        self.start_count += count;
        let members = self.members(ctx, &[element]);
        let at = if self.phase == Phase::Fix {
            self.centroid(ctx, &self.all_members(ctx)) - self.axis * 6.0
        } else {
            self.assault_position
        };
        let at = ctx
            .geometry
            .navigation
            .planner
            .nearest_walkable(
                at,
                crate::traversal::Ground::new(&ctx.geometry.terrain, &ctx.geometry.deck),
            )
            .unwrap();
        Self::place(ctx, &members, at, self.axis, 1, true)?;
        self.say(
            ctx,
            "join",
            &members,
            &[
                "Moving up to support you!",
                "Reinforcements coming in!",
                "We're on our way, hold on!",
            ],
            &mut out,
        );
        out.push(Event::Stat("plan_reinforced"));
        Ok(out)
    }
    fn name(&self, ctx: &Context<'_>, elements: &[Element]) -> String {
        elements
            .first()
            .and_then(|e| ctx.squads.iter().find(|q| q.id == e.squad))
            .map_or_else(String::new, |q| q.callsign())
    }
    fn validate_context(&self, ctx: &Context<'_>) -> Result<(), &'static str> {
        if !self.valid() || !ctx.now.is_finite() || ctx.now.abs() > 1e12 - 100.0 {
            return Err("invalid attack plan context");
        }
        for e in self.elements() {
            if ctx.squads.iter().any(|q| q.id == e.squad) {
                ctx.index(e.squad)?;
            }
        }
        Ok(())
    }
    pub fn valid(&self) -> bool {
        let mut seen = HashSet::new();
        let mut said = HashSet::new();
        self.id != 0
            && (-1..=1).contains(&self.team)
            && matches!(self.side, -1.0 | 1.0)
            && [
                self.objective,
                self.axis,
                self.support_position,
                self.assault_position,
                self.fire_at,
            ]
            .into_iter()
            .all(point)
            && !self.support.is_empty()
            && !self.assault.is_empty()
            && self.support.len() <= 100_000
            && self.assault.len() <= 100_000
            && self.elements().all(|e| {
                e.squad != 0 && (-1..=1).contains(&e.team) && seen.insert((e.squad, e.team))
            })
            && self.rush_group <= 1
            && self.start_count <= 100_000
            && self.pinned_time >= 0.0
            && self.clear_time >= 0.0
            && [
                self.phase_time,
                self.rush_time,
                self.pinned_time,
                self.clear_time,
                self.tick_time,
            ]
            .into_iter()
            .all(|t| t.is_finite() && t.abs() <= 1e12)
            && self.said.len() <= 11
            && self.said.iter().all(|s| {
                matches!(
                    s.as_str(),
                    "plan"
                        | "fix"
                        | "fix_msg"
                        | "set"
                        | "go"
                        | "shift"
                        | "fallback"
                        | "again"
                        | "won"
                        | "join"
                ) && said.insert(s)
            })
    }
    pub fn checkpoint(&self) -> Result<Vec<u8>, &'static str> {
        if !self.valid() {
            return Err("invalid attack plan state");
        }
        let mut w = Writer::new(b"FLAP01\0\0");
        w.u32(self.id);
        w.byte(self.team as u8);
        w.point(self.objective);
        w.point(self.axis);
        w.f64(self.side);
        for elements in [&self.support, &self.assault] {
            w.u32(elements.len() as u32);
            for e in elements {
                w.u32(e.squad);
                w.byte(e.team as u8);
            }
        }
        w.point(self.support_position);
        w.point(self.assault_position);
        w.byte(self.phase as u8);
        w.f64(self.phase_time);
        w.point(self.fire_at);
        w.byte(self.support_set as u8);
        w.byte(self.shifted as u8);
        w.byte(self.rush_group);
        w.f64(self.rush_time);
        w.u32(self.start_count);
        w.f64(self.pinned_time);
        w.f64(self.clear_time);
        w.u32(self.said.len() as u32);
        for s in &self.said {
            w.bytes(s.as_bytes());
        }
        w.byte(self.done as u8);
        w.f64(self.tick_time);
        w.byte(self.smoked as u8);
        Ok(w.0)
    }
    pub fn restore(bytes: &[u8]) -> Result<Self, &'static str> {
        let mut r = Reader::new(bytes, b"FLAP01\0\0")?;
        let id = r.u32()?;
        let team = r.byte()? as i8;
        let objective = r.point()?;
        let axis = r.point()?;
        let side = r.f64()?;
        let mut elements = [vec![], vec![]];
        for v in &mut elements {
            let n = r.u32()?;
            if n > 100_000 {
                return Err("attack element limit exceeded");
            }
            for _ in 0..n {
                v.push(Element {
                    squad: r.u32()?,
                    team: r.byte()? as i8,
                });
            }
        }
        let [support, assault] = elements;
        let support_position = r.point()?;
        let assault_position = r.point()?;
        let phase = match r.byte()? {
            0 => Phase::Plan,
            1 => Phase::Move,
            2 => Phase::Assault,
            3 => Phase::Fix,
            4 => Phase::Fallback,
            _ => return Err("invalid attack phase"),
        };
        let phase_time = r.f64()?;
        let fire_at = r.point()?;
        let support_set = r.boolean()?;
        let shifted = r.boolean()?;
        let rush_group = r.byte()?;
        let rush_time = r.f64()?;
        let start_count = r.u32()?;
        let pinned_time = r.f64()?;
        let clear_time = r.f64()?;
        let n = r.u32()?;
        if n > 11 {
            return Err("attack speech limit exceeded");
        }
        let mut said = vec![];
        for _ in 0..n {
            said.push(
                std::str::from_utf8(r.bytes(16)?)
                    .map_err(|_| "invalid attack speech key")?
                    .into(),
            );
        }
        let p = Self {
            id,
            team,
            objective,
            axis,
            side,
            support,
            assault,
            support_position,
            assault_position,
            phase,
            phase_time,
            fire_at,
            support_set,
            shifted,
            rush_group,
            rush_time,
            start_count,
            pinned_time,
            clear_time,
            said,
            done: r.boolean()?,
            tick_time: r.f64()?,
            smoked: r.boolean()?,
        };
        r.finish()?;
        if !p.valid() {
            return Err("invalid attack plan checkpoint");
        }
        Ok(p)
    }
}
