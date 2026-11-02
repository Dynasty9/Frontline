//! Road ambushes share soldiers, routes and the battle's random stream.
use crate::actors::Actor;
use crate::infantry_commands::Command;
use crate::infantry_vitals::Life;
use crate::squad_brain::{Call, Event, Message};
use crate::squad_movement::{available, flat, point, Context};
use crate::state_codec::{Reader, Writer};
use crate::vector::{normalized, Vector3};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
#[repr(u8)]
pub enum Phase {
    Move,
    Wait,
    Spring,
}
#[derive(Clone, Debug, PartialEq)]
pub struct AmbushPlan {
    pub id: u32,
    pub squad: u32,
    pub zone: Vector3,
    pub road: Vector3,
    pub side: Vector3,
    pub rally: Vector3,
    pub gun_end: f64,
    pub phase: Phase,
    pub phase_time: f64,
    pub fire_time: f64,
    pub quiet_time: f64,
    pub done: bool,
    pub caught: u32,
}
impl AmbushPlan {
    pub fn make(
        ctx: &mut Context<'_>,
        id: u32,
        squad: u32,
        zone: Vector3,
        along: Vector3,
        toward: Vector3,
    ) -> Result<(Self, Vec<Event>), &'static str> {
        if id == 0 || ![zone, along, toward].into_iter().all(point) {
            return Err("invalid ambush order");
        }
        let i = ctx.index(squad)?;
        let road = normalized(flat(along));
        let side = normalized(flat(toward));
        let rally = ctx
            .geometry
            .navigation
            .planner
            .nearest_walkable(zone + side * 54.0)
            .unwrap();
        let mut gun_end = 1.0;
        let mut best = -1e9;
        for end in [-1.0, 1.0] {
            let at = zone + side * 24.0 * 0.75 + road * end * 30.0;
            let score = 1.0 - ctx.geometry.terrain.concealment(at)
                + f64::from(ctx.geometry.terrain.cover(at) + 1) * 0.2;
            if score > best {
                best = score;
                gun_end = f64::from(end);
            }
        }
        let p = Self {
            id,
            squad,
            zone,
            road,
            side,
            rally,
            gun_end,
            phase: Phase::Move,
            phase_time: ctx.now,
            fire_time: 0.0,
            quiet_time: 0.0,
            done: false,
            caught: 0,
        };
        let mut out: Vec<_> = ctx
            .order_move(squad, rally, -side, 0, true)?
            .into_iter()
            .map(Event::Movement)
            .collect();
        ctx.squads[i].ambush_plan = id;
        ctx.squads[i].shown_order = "ambush".into();
        let mut events = vec![];
        let leader = ctx.leader(i, &mut events);
        out.extend(events.into_iter().map(Event::Movement));
        if leader != 0 {
            let cue = (ctx.rng.randi() % if ctx.squads[i].team == 0 { 3 } else { 2 }) as u8;
            ctx.brain_say(leader, Call::AmbushSetOut, cue, true, None, &mut out);
        }
        out.push(Event::Stat("ambush_set_out"));
        Ok((p, out))
    }
    pub fn tick(
        &mut self,
        ctx: &mut Context<'_>,
        air: &dyn Fn(&str) -> bool,
    ) -> Result<Vec<Event>, &'static str> {
        let mut out = vec![];
        if self.done {
            return Ok(out);
        }
        let i = ctx.index(self.squad)?;
        let alive: Vec<_> = ctx.squads[i]
            .alive(ctx.actors)
            .map(|s| s.identity.id)
            .collect();
        if alive.is_empty() || matches!(ctx.squads[i].drill.as_str(), "rout" | "withdraw") {
            self.done = true;
            return Ok(out);
        }
        match self.phase {
            Phase::Move => {
                let center = ctx.squads[i].centroid(ctx.now, ctx.actors);
                let still = alive
                    .iter()
                    .all(|&id| !ctx.actors.soldier(id).unwrap().is_moving());
                let engaged = ctx.squad_suppression(i) > 15.0
                    || ctx.now - ctx.squads[i].last_casualty < 5.0
                    || ctx.squads[i].known.iter().any(|k| {
                        ctx.now - k.report.time < 4.0
                            && flat(k.report.position - center).length() < 70.0
                    });
                if engaged {
                    self.give_up(ctx, i, &mut out);
                } else if flat(self.rally - center).length() < 14.0
                    || still
                        && ctx.now - self.phase_time > 20.0
                        && !ctx.squads[i].travel
                        && ctx.squads[i].technique.is_empty()
                {
                    self.occupy(ctx, i, &alive, &mut out)?;
                } else if ctx.now - self.phase_time > 150.0 {
                    self.give_up(ctx, i, &mut out);
                }
            }
            Phase::Wait => self.wait(ctx, i, &alive, air, &mut out)?,
            Phase::Spring => self.fire(ctx, i, air, &mut out)?,
        }
        Ok(out)
    }
    fn post(
        ctx: &mut Context<'_>,
        id: u32,
        at: Vector3,
        face: Vector3,
    ) -> Result<(), &'static str> {
        ctx.command(
            id,
            Command::Move {
                slot: at,
                mode: 0,
                face,
            },
        )?;
        ctx.actors.soldier_mut(id).unwrap().orders.leash = 3.0;
        Ok(())
    }
    fn occupy(
        &mut self,
        ctx: &mut Context<'_>,
        i: usize,
        alive: &[u32],
        out: &mut Vec<Event>,
    ) -> Result<(), &'static str> {
        let mut gun = None;
        let mut line = vec![];
        for &id in alive {
            let m = ctx.actors.soldier(id).unwrap();
            if !available(m) || m.emplacement.structure != 0 {
                continue;
            }
            if gun.is_none() && matches!(m.identity.unit.as_str(), "mg_gunner" | "pkm") {
                gun = Some(id);
            } else {
                line.push(id);
            }
        }
        let guard = if line.len() >= 4 {
            let scores: Vec<_> = line
                .iter()
                .map(|&id| {
                    f64::from(
                        flat(ctx.actors.soldier(id).unwrap().motion.position - self.zone)
                            .dot(self.road),
                    ) * self.gun_end
                })
                .collect();
            line = crate::godot_sort::score_order(&scores)
                .into_iter()
                .map(|j| line[j])
                .collect();
            Some(line.remove(0))
        } else {
            None
        };
        let face = -self.side;
        let center = ctx
            .geometry
            .navigation
            .planner
            .nearest_walkable(self.zone + self.side * 24.0)
            .unwrap();
        let slots = ctx.formation(center, face, &line, true)?;
        for (&id, at) in line.iter().zip(slots) {
            Self::post(ctx, id, at, face)?;
        }
        if let Some(id) = gun {
            let at = ctx
                .geometry
                .navigation
                .planner
                .nearest_walkable(
                    self.zone + self.side * 24.0 * 0.75 + self.road * self.gun_end as f32 * 30.0,
                )
                .unwrap();
            Self::post(ctx, id, at, normalized(flat(self.zone - at)))?;
        }
        if let Some(id) = guard {
            let at = ctx
                .geometry
                .navigation
                .planner
                .nearest_walkable(
                    self.zone + self.side * 30.0 - self.road * self.gun_end as f32 * 38.0,
                )
                .unwrap();
            Self::post(ctx, id, at, -self.road * self.gun_end as f32)?;
        }
        let q = &mut ctx.squads[i];
        q.order = "defend".into();
        q.order_position = center;
        q.facing = face;
        q.ambush = true;
        q.shown_order = "ambush".into();
        self.phase = Phase::Wait;
        self.phase_time = ctx.now;
        out.push(Event::Stat("ambush_laid"));
        Ok(())
    }
    fn enemy(ctx: &Context<'_>, id: u32, air: &dyn Fn(&str) -> bool) -> bool {
        match ctx.actors.get(id) {
            Some(Actor::Soldier(s)) => !s.identity.gone && s.vitals.life == Life::Alive,
            Some(Actor::Vehicle(v)) => !v.gone && !air(&v.kind),
            _ => false,
        }
    }
    fn wait(
        &mut self,
        ctx: &mut Context<'_>,
        i: usize,
        alive: &[u32],
        air: &dyn Fn(&str) -> bool,
        out: &mut Vec<Event>,
    ) -> Result<(), &'static str> {
        ctx.squads[i].ambush = true;
        let found = ctx.squad_suppression(i) > 8.0 || ctx.now - ctx.squads[i].last_casualty < 3.0;
        let mut inside = 0;
        let mut vehicle = false;
        let mut close = false;
        for id in ctx
            .actors
            .units_near(ctx.units, self.zone, 52.0, ctx.squads[i].team)?
        {
            if !Self::enemy(ctx, id, air) {
                continue;
            }
            let e = ctx.actors.get(id).unwrap();
            let rel = flat(e.position() - self.zone);
            if rel.dot(self.road).abs() < 22.0 && rel.dot(self.side).abs() < 12.0 {
                inside += 1;
                vehicle |= matches!(e, Actor::Vehicle(_));
            }
            close |= alive.iter().any(|&id| {
                flat(e.position() - ctx.actors.soldier(id).unwrap().motion.position).length() < 14.0
            });
        }
        if found
            || close
            || vehicle
            || inside >= 2
            || inside >= 1 && ctx.now - self.quiet_time > 4.0 && self.quiet_time > 0.0
        {
            self.phase = Phase::Spring;
            self.caught = inside;
            self.fire_time = ctx.now;
            self.quiet_time = 0.0;
            let q = &mut ctx.squads[i];
            q.ambush = false;
            q.ambush_time = ctx.now + 4.0;
            q.cover_fire_position = self.zone;
            q.cover_fire_until = ctx.now + 6.0;
            let count = if q.team == 0 { 4 } else { 3 };
            ctx.brain_call(i, Call::AmbushSpring, count, None, out);
            out.push(Event::Message {
                squad: self.squad,
                message: Message::AmbushSprang,
                position: self.zone,
            });
            out.push(Event::Stat("ambush_sprung"));
            for _ in 0..inside {
                out.push(Event::Stat("ambush_caught"));
            }
            return Ok(());
        }
        if inside == 1 && self.quiet_time <= 0.0 {
            self.quiet_time = ctx.now;
        } else if inside == 0 {
            self.quiet_time = 0.0;
        }
        if ctx.now - self.phase_time > 260.0 {
            self.give_up(ctx, i, out);
        }
        Ok(())
    }
    fn fire(
        &mut self,
        ctx: &mut Context<'_>,
        i: usize,
        air: &dyn Fn(&str) -> bool,
        out: &mut Vec<Event>,
    ) -> Result<(), &'static str> {
        let live = ctx
            .actors
            .units_near(ctx.units, self.zone, 47.0, ctx.squads[i].team)?
            .into_iter()
            .any(|id| Self::enemy(ctx, id, air));
        if live {
            self.quiet_time = ctx.now;
            if ctx.now - self.fire_time < 12.0 {
                ctx.squads[i].cover_fire_position = self.zone;
                ctx.squads[i].cover_fire_until = ctx.now + 2.0;
            }
        }
        if !(ctx.now - self.fire_time > 28.0
            || ctx.now - self.quiet_time > 6.0 && ctx.now - self.fire_time > 8.0)
        {
            return Ok(());
        }
        self.done = true;
        ctx.squads[i].ambush_plan = 0;
        ctx.brain_call(i, Call::AmbushWithdraw, 3, None, out);
        if ctx.squads[i].team == 1 {
            ctx.squad_smoke_screen(i, -self.side)?;
            out.extend(
                ctx.order_move(self.squad, self.rally, -self.side, 2, true)?
                    .into_iter()
                    .map(Event::Movement),
            );
        } else {
            ctx.squad_start_withdraw(i, out)?;
        }
        out.push(Event::Stat("ambush_withdraw"));
        Ok(())
    }
    fn give_up(&mut self, ctx: &mut Context<'_>, i: usize, out: &mut Vec<Event>) {
        self.done = true;
        let q = &mut ctx.squads[i];
        q.ambush_plan = 0;
        q.ambush = false;
        q.shown_order.clear();
        out.push(Event::Stat("ambush_abandoned"));
    }
    fn valid(&self) -> bool {
        self.id != 0
            && self.squad != 0
            && [self.zone, self.road, self.side, self.rally]
                .into_iter()
                .all(point)
            && matches!(self.gun_end, -1.0 | 1.0)
            && self.caught <= 1_000_000
            && [self.phase_time, self.fire_time, self.quiet_time]
                .into_iter()
                .all(|t| t.is_finite() && t.abs() <= 1e12)
    }
    pub fn checkpoint(&self) -> Result<Vec<u8>, &'static str> {
        if !self.valid() {
            return Err("invalid ambush state");
        }
        let mut w = Writer::new(b"FLAM01\0\0");
        w.u32(self.id);
        w.u32(self.squad);
        for p in [self.zone, self.road, self.side, self.rally] {
            w.point(p);
        }
        w.f64(self.gun_end);
        w.byte(self.phase as u8);
        for t in [self.phase_time, self.fire_time, self.quiet_time] {
            w.f64(t);
        }
        w.byte(self.done as u8);
        w.u32(self.caught);
        Ok(w.0)
    }
    pub fn restore(bytes: &[u8]) -> Result<Self, &'static str> {
        let mut r = Reader::new(bytes, b"FLAM01\0\0")?;
        let p = Self {
            id: r.u32()?,
            squad: r.u32()?,
            zone: r.point()?,
            road: r.point()?,
            side: r.point()?,
            rally: r.point()?,
            gun_end: r.f64()?,
            phase: match r.byte()? {
                0 => Phase::Move,
                1 => Phase::Wait,
                2 => Phase::Spring,
                _ => return Err("invalid ambush phase"),
            },
            phase_time: r.f64()?,
            fire_time: r.f64()?,
            quiet_time: r.f64()?,
            done: r.boolean()?,
            caught: r.u32()?,
        };
        r.finish()?;
        if !p.valid() {
            return Err("invalid ambush checkpoint");
        }
        Ok(p)
    }
}
