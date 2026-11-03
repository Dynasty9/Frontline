use super::*;

#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub(super) struct BoatRole {
    phase: u8,
    at: f64,
    squad: u32,
    boarding: bool,
}
const IDLE: u8 = 0;
const PICKUP: u8 = 1;
const RAID: u8 = 2;
const HOME: u8 = 3;
const HUNT: u8 = 4;
const PATROL: u8 = 5;
fn armed(w: &Context<'_, '_, '_>, id: u32) -> bool {
    let d = w.content.vehicle(w.state.field.actors.vehicle(id).unwrap());
    !text(d, "mg").is_empty() || flag(d, "cannon")
}
fn seats(w: &Context<'_, '_, '_>, id: u32) -> i32 {
    w.content
        .seats(&w.state.field.actors.vehicle(id).unwrap().kind) as i32
}
fn enemy(a: &Actor, team: i8) -> bool {
    match a {
        Actor::Soldier(s) => {
            s.identity.team >= 0
                && s.identity.team != team
                && s.identity.visible & (1 << team) != 0
                && s.vitals.life == Life::Alive
        }
        Actor::Vehicle(v) => v.team >= 0 && v.team != team && v.visible & (1 << team) != 0,
        _ => false,
    }
}
impl Commander {
    pub(super) fn dock_wanted(&self, w: &Context<'_, '_, '_>, c: &Census) -> bool {
        w.state.water.coast.is_some()
            && !self.has(w, c, "dock")
            && self.has(w, c, "factory")
            && w.state.field.now > 420.
    }
    pub(super) fn dock(
        &mut self,
        w: &mut Context<'_, '_, '_>,
        c: &Census,
    ) -> Result<bool, &'static str> {
        if !self.dock_wanted(w, c)
            || w.stock(self.team) <= w.content.building("dock").unwrap().cost + 60 + self.reserve(w)
        {
            return Ok(false);
        }
        let front = self.front(w).unwrap();
        let half = w.state.field.geometry.terrain.half() as f32;
        let mut best = None;
        let mut score = f32::INFINITY;
        let yaw = -std::f64::consts::FRAC_PI_2;
        for i in 0..20 {
            let offset = if i % 2 == 0 { 1. } else { -1. } * (i / 2) as f32 * 12.;
            let z = front.z + offset;
            if z.abs() > half - 70.
                || (self.team == 0 && z < half * 0.12)
                || (self.team == 1 && z > -half * 0.12)
            {
                continue;
            }
            let p = Vector3::new(
                (w.state.water.coast_x(z as f64) - 10.).round() as f32,
                0.,
                z.round(),
            );
            if w.placeable(self.team, "dock", p, yaw)? {
                let value = (z - front.z).abs() + self.rng.randf() * 10.;
                if value < score {
                    score = value;
                    best = Some(p);
                }
            }
        }
        if let Some(position) = best {
            let engineer = self
                .engineer(w, c, position)
                .or_else(|| c.squads.iter().find(|q| q.engineer).map(|q| q.id));
            w.command(
                self.team,
                engineer.into_iter().collect(),
                vec![],
                Action::Build {
                    kind: "dock".into(),
                    position,
                    yaw,
                },
            )?;
            return Ok(true);
        }
        Ok(false)
    }
    fn boat_pick(&self, w: &Context<'_, '_, '_>, gun: bool) -> Option<String> {
        (w.profiles.produces)("dock")
            .iter()
            .filter(|key| w.unlocked(self.team, key))
            .filter_map(|key| {
                let d = &w.content.definitions["vehicles"][key];
                let armed = !text(d, "mg").is_empty();
                let seats = f64::from(w.content.seats(key));
                if gun && !armed || !gun && seats <= 0. {
                    return None;
                }
                Some((
                    key,
                    if gun {
                        number(d, "hp", 0.)
                    } else {
                        seats * 50. + if armed { 30. } else { 0. }
                    },
                ))
            })
            .max_by(|a, b| a.1.total_cmp(&b.1).then(b.0.cmp(a.0)))
            .map(|p| p.0.clone())
    }
    pub(super) fn boat_production(
        &mut self,
        w: &mut Context<'_, '_, '_>,
        c: &Census,
    ) -> Result<i32, &'static str> {
        let boats: Vec<_> = w
            .state
            .field
            .actors
            .iter()
            .filter_map(|a| match a {
                Actor::Vehicle(v)
                    if v.team == self.team && text(w.content.vehicle(v), "base") == "boat" =>
                {
                    Some(v.id)
                }
                _ => None,
            })
            .collect();
        let docks: Vec<_> = c
            .structures
            .iter()
            .copied()
            .filter(|id| {
                w.state
                    .field
                    .actors
                    .structure(*id)
                    .is_some_and(|s| s.kind == "dock" && s.built && s.queue.is_empty())
            })
            .collect();
        for id in &docks {
            let mut want = None;
            if boats.iter().filter(|id| armed(w, **id)).count()
                < 1 + (w.state.field.now / 1000.) as usize
            {
                want = self.boat_pick(w, true);
            }
            if want.is_none()
                && !boats.iter().any(|id| seats(w, *id) > 0)
                && w.state.field.now > 520.
            {
                want = self.boat_pick(w, false);
            }
            if let Some(item) =
                want.filter(|key| w.stock(self.team) >= (w.profiles.item)(key, false).unwrap().cost)
            {
                w.command(
                    self.team,
                    vec![],
                    vec![],
                    Action::Produce {
                        building: *id,
                        item,
                        research: false,
                    },
                )?;
            }
        }
        Ok(
            if boats.is_empty()
                && docks.iter().any(|id| {
                    w.state
                        .field
                        .actors
                        .structure(*id)
                        .is_some_and(|s| s.queue.is_empty())
                })
            {
                self.boat_pick(w, true)
                    .or_else(|| self.boat_pick(w, false))
                    .and_then(|key| (w.profiles.item)(&key, false).map(|i| i.cost))
                    .unwrap_or(0)
            } else {
                0
            },
        )
    }
    pub(super) fn naval(
        &mut self,
        w: &mut Context<'_, '_, '_>,
        c: &Census,
    ) -> Result<(), &'static str> {
        if w.state.field.now < self.naval_at {
            return Ok(());
        }
        self.naval_at = w.state.field.now + 5.;
        let boats: Vec<_> = c
            .vehicles
            .iter()
            .copied()
            .filter(|id| {
                text(
                    w.content
                        .vehicle(w.state.field.actors.vehicle(*id).unwrap()),
                    "base",
                ) == "boat"
            })
            .collect();
        self.boats.retain(|id, _| boats.contains(id));
        let ferry = boats
            .iter()
            .copied()
            .filter(|id| seats(w, *id) > 0)
            .min_by_key(|id| (armed(w, *id), *id));
        for id in boats {
            if Some(id) == ferry {
                self.raid(w, c, id)?;
            } else {
                self.patrol(w, id)?;
            }
        }
        Ok(())
    }
    fn patrol(&mut self, w: &mut Context<'_, '_, '_>, id: u32) -> Result<(), &'static str> {
        let v = w.state.field.actors.vehicle(id).unwrap();
        let position = v.position;
        let active = (v.path_index as usize) < v.path.len();
        let now = w.state.field.now;
        let mut best = None;
        let mut range = 260.;
        for target in w
            .state
            .field
            .actors
            .units_near(&w.state.field.units, position, 260., -1)?
        {
            let a = w.state.field.actors.get(target).unwrap();
            if !enemy(a, self.team)
                || matches!(a,Actor::Vehicle(v) if flag(w.content.vehicle(v),"air"))
            {
                continue;
            }
            let p = match a {
                Actor::Soldier(s) => s.motion.position,
                Actor::Vehicle(v) => v.position,
                _ => continue,
            };
            let d = distance(position, p);
            if d < range && w.state.boats.nearest(p, 45., -1).is_some() {
                best = Some(p);
                range = d;
            }
        }
        let role = self.boats.get(&id).copied().unwrap_or_default();
        if let Some(p) = best {
            if role.phase != HUNT || now - role.at > 15. {
                if let Some(position) =
                    w.state
                        .boats
                        .nearest(p + normalized(flat(position - p)) * 35., 45., -1)
                {
                    w.command(
                        self.team,
                        vec![],
                        vec![id],
                        Action::Assault {
                            position,
                            face: self.forward(),
                        },
                    )?;
                    self.boats.insert(
                        id,
                        BoatRole {
                            phase: HUNT,
                            at: now,
                            ..Default::default()
                        },
                    );
                }
            }
            return Ok(());
        }
        if active && now - role.at < 50. {
            return Ok(());
        }
        let z = self.front(w).unwrap_or(Vector3::ZERO).z
            + self.forward().z * self.rng.randf_range(30., 110.);
        let body = w.state.boats.body(position);
        let mut candidate = if w.state.water.coast.is_some() {
            w.state.boats.nearest(
                Vector3::new(
                    w.state.water.coast_x(z as f64) as f32 + self.rng.randf_range(25., 70.),
                    0.,
                    z,
                ),
                60.,
                body,
            )
        } else {
            None
        };
        if candidate.is_some_and(|p| w.state.boats.path(position, p).is_empty()) {
            candidate = None;
        }
        if candidate.is_none() {
            candidate = w
                .state
                .water
                .rivers
                .first()
                .and_then(|r| {
                    r.points
                        .iter()
                        .min_by(|a, b| (a.z - z).abs().total_cmp(&(b.z - z).abs()))
                })
                .and_then(|p| w.state.boats.nearest(*p, 30., body));
        }
        if let Some(position) = candidate {
            w.command(
                self.team,
                vec![],
                vec![id],
                Action::Assault {
                    position,
                    face: self.forward(),
                },
            )?;
            self.boats.insert(
                id,
                BoatRole {
                    phase: PATROL,
                    at: now,
                    ..Default::default()
                },
            );
        }
        Ok(())
    }
    fn raid(
        &mut self,
        w: &mut Context<'_, '_, '_>,
        c: &Census,
        id: u32,
    ) -> Result<(), &'static str> {
        let now = w.state.field.now;
        let mut role = self.boats.get(&id).copied().unwrap_or_default();
        let v = w.state.field.actors.vehicle(id).unwrap();
        let position = v.position;
        let body = w.state.boats.body(position);
        let stopped = v.path_index as usize >= v.path.len();
        let speed = v.speed;
        let aboard = v.passengers.len();
        match role.phase {
            IDLE | HUNT | PATROL => {
                if now < role.at {
                    return Ok(());
                }
                let garrisons = self.roles.values().filter(|r| r.kind == "garrison").count();
                let capacity = seats(w, id) as usize;
                let mut pick = None;
                let mut score = 300.;
                for q in &c.squads {
                    if q.plan != 0
                        || !q.drill.is_empty()
                        || q.alive < 3
                        || q.alive > capacity + 2
                        || !matches!(
                            q.kind.as_str(),
                            "rifle_squad"
                                | "fighter_cell"
                                | "mech_team"
                                | "mech_cell"
                                | "at_team"
                                | "rpg_team"
                                | "mg_team"
                                | "pkm_team"
                        )
                        || !(matches!(self.role(q.id), "idle" | "outpost")
                            || garrisons >= 3 && self.role(q.id) == "garrison")
                    {
                        continue;
                    }
                    if let Some(p) = w.state.boats.nearest(q.position, 200., body) {
                        let value = distance(q.position, p) + distance(p, position) * 0.2;
                        if value < score {
                            pick = Some((q.id, p));
                            score = value;
                        }
                    }
                }
                if let Some((squad, p)) =
                    pick.filter(|(_, p)| !w.state.boats.path(position, *p).is_empty())
                {
                    self.assign(squad, "raid", now, 0, p);
                    w.command(
                        self.team,
                        vec![],
                        vec![id],
                        Action::Move {
                            position: p,
                            face: self.forward(),
                            mode: 0,
                        },
                    )?;
                    role = BoatRole {
                        phase: PICKUP,
                        at: now,
                        squad,
                        boarding: false,
                    };
                } else {
                    role = BoatRole {
                        at: now + 30.,
                        ..Default::default()
                    };
                }
            }
            PICKUP => {
                let q = c.squads.iter().find(|q| q.id == role.squad);
                if q.is_none() {
                    role.phase = HOME;
                } else {
                    if stopped && speed.abs() < 0.8 && !role.boarding {
                        w.command(self.team, vec![role.squad], vec![], Action::Board(id))?;
                        role.boarding = true;
                    }
                    if aboard > 0 && (q.unwrap().alive == 0 || now - role.at > 110.) {
                        self.launch(w, id, role.squad)?;
                        return Ok(());
                    } else if now - role.at > 170. {
                        self.assign(role.squad, "idle", now, 0, position);
                        role.phase = HOME;
                    }
                }
            }
            RAID => {
                if aboard == 0 {
                    role.phase = HOME;
                    role.at = now;
                } else if stopped && speed.abs() < 0.5 && now - role.at > 20. {
                    w.command(self.team, vec![], vec![id], Action::Dismount)?;
                }
            }
            HOME => {
                if let Some(dock) = c
                    .structures
                    .iter()
                    .filter_map(|id| w.state.field.actors.structure(*id))
                    .find(|s| s.kind == "dock" && s.built)
                {
                    let p = dock.position
                        + rotate(Vector3::NEG_Z, dock.yaw) * (dock.size.z * 0.5 + 18.);
                    if let Some(position) = w.state.boats.nearest(p, 40., body) {
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
                role = BoatRole {
                    at: now + f64::from(self.rng.randf_range(150., 260.)),
                    ..Default::default()
                };
            }
            _ => return Err("invalid boat role"),
        }
        self.boats.insert(id, role);
        Ok(())
    }
    fn launch(
        &mut self,
        w: &mut Context<'_, '_, '_>,
        id: u32,
        squad: u32,
    ) -> Result<(), &'static str> {
        let position = w.state.field.actors.vehicle(id).unwrap().position;
        let body = w.state.boats.body(position);
        let front = self.front(w).unwrap_or(position);
        let goals: Vec<_> = w
            .state
            .field
            .actors
            .iter()
            .filter_map(|a| match a {
                Actor::Structure(s)
                    if s.id == self.attack_target
                        || s.kind == "fob" && s.team == 1 - self.team
                        || s.kind == "town" && s.team != self.team =>
                {
                    Some(s.zone_center.unwrap_or(s.position))
                }
                _ => None,
            })
            .collect();
        let mut best = None;
        let mut score = 1e9;
        for goal in goals {
            if let Some(p) = w.state.boats.nearest(goal, 200., body) {
                let mut value = distance(p, goal) + distance(goal, front) * 0.3;
                for target in w
                    .state
                    .field
                    .actors
                    .units_near(&w.state.field.units, p, 45., -1)?
                {
                    if enemy(w.state.field.actors.get(target).unwrap(), self.team) {
                        value += 60.;
                    }
                }
                if value < score && !w.state.boats.path(position, p).is_empty() {
                    best = Some((p, goal));
                    score = value;
                }
            }
        }
        let now = w.state.field.now;
        if let Some((p, target)) = best {
            w.command(
                self.team,
                vec![],
                vec![id],
                Action::Move {
                    position: p,
                    face: self.forward(),
                    mode: 0,
                },
            )?;
            w.state.field.actors.set_landing_objective(id, target)?;
            self.assign(squad, "attack", now, 0, target);
            self.boats.insert(
                id,
                BoatRole {
                    phase: RAID,
                    at: now,
                    squad,
                    boarding: true,
                },
            );
        } else {
            w.command(self.team, vec![], vec![id], Action::Dismount)?;
            self.assign(squad, "idle", now, 0, position);
            self.boats.insert(
                id,
                BoatRole {
                    phase: HOME,
                    at: now,
                    ..Default::default()
                },
            );
        }
        Ok(())
    }
    pub(super) fn sling(
        &mut self,
        w: &mut Context<'_, '_, '_>,
        c: &Census,
    ) -> Result<(), &'static str> {
        if w.state.field.now < self.sling_at {
            return Ok(());
        }
        self.sling_at = w.state.field.now + 6.;
        let Some(front) = self.front(w) else {
            return Ok(());
        };
        for &id in &c.vehicles {
            let h = w.state.field.actors.vehicle(id).unwrap();
            let d = w.content.vehicle(h);
            if text(d, "base") != "lift_heli"
                || number(d, "sling", -1.) < 0.
                || !h.passengers.is_empty()
            {
                continue;
            }
            if h.lift_phase == 1 && h.lift_destination.is_none() && h.position.y > 10. {
                let position = if h.sling_cargo != 0 {
                    front - self.forward() * 14. + Vector3::X * self.rng.randf_range(-12., 12.)
                } else if h.sling_target == 0 {
                    w.state
                        .field
                        .actors
                        .structure(h.heli_home)
                        .map_or(front, |s| s.position)
                } else {
                    continue;
                };
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
                continue;
            }
            if h.sling_target != 0 || h.sling_cargo != 0 || h.lift_phase != 0 {
                continue;
            }
            let mut best = None;
            let mut far = 220.;
            for &cargo in &c.vehicles {
                let v = w.state.field.actors.vehicle(cargo).unwrap();
                let vd = w.content.vehicle(v);
                let range = distance(v.position, front);
                if range <= far || (v.path_index as usize) < v.path.len() {
                    continue;
                }
                if w.state.field.actors.can_sling(
                    id,
                    cargo,
                    sim::vehicle_sling::SlingSpec {
                        lift: true,
                        capacity: number(d, "sling", -1.) as i8,
                        cargo_weight: number(vd, "weight", 1.) as u8,
                        cargo_helicopter: flag(vd, "air"),
                        cargo_boat: text(vd, "base") == "boat",
                        cargo_automatic: flag(vd, "auto"),
                    },
                )? {
                    best = Some(cargo);
                    far = range;
                }
            }
            if let Some(cargo) = best {
                w.command(self.team, vec![], vec![id], Action::Sling(cargo))?;
            }
        }
        Ok(())
    }
    pub(super) fn write_naval(&self, w: &mut Writer) -> Result<(), &'static str> {
        if !clock(self.naval_at) || !clock(self.sling_at) || self.boats.len() > 100_000 {
            return Err("invalid naval clock");
        }
        w.f64(self.naval_at);
        w.f64(self.sling_at);
        w.u32(self.boats.len() as u32);
        for (&id, r) in &self.boats {
            if id == 0 || r.phase > PATROL || !clock(r.at) {
                return Err("invalid boat role");
            }
            w.u32(id);
            w.byte(r.phase);
            w.f64(r.at);
            w.u32(r.squad);
            w.byte(u8::from(r.boarding));
        }
        Ok(())
    }
    pub(super) fn read_naval(&mut self, r: &mut Reader<'_>) -> Result<(), &'static str> {
        self.naval_at = r.f64()?;
        self.sling_at = r.f64()?;
        let n = r.u32()?;
        if n > 100_000 {
            return Err("boat role limit exceeded");
        }
        for _ in 0..n {
            let id = r.u32()?;
            let role = BoatRole {
                phase: r.byte()?,
                at: r.f64()?,
                squad: r.u32()?,
                boarding: r.boolean()?,
            };
            if self.boats.insert(id, role).is_some() {
                return Err("duplicate boat role");
            }
        }
        Ok(())
    }
}
