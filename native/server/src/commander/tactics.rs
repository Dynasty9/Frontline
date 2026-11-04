//! Squad assignments, attacks, defenses and ambushes.
use super::*;

impl Commander {
    pub(super) fn military(
        &mut self,
        w: &mut Context<'_, '_, '_>,
        c: &Census,
    ) -> Result<(), &'static str> {
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
    pub(super) fn outposts(
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
    pub(super) fn towns(
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
    pub(super) fn reinforce(
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
    pub(super) fn try_tunnel(
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
    pub(super) fn tunnel_progress(
        &mut self,
        w: &mut Context<'_, '_, '_>,
    ) -> Result<(), &'static str> {
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
    pub(super) fn ambush(
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
}
