use super::*;
impl Mission {
    pub(in crate::mission) fn drive(
        &mut self,
        w: &mut Context<'_, '_, '_>,
    ) -> Result<(), &'static str> {
        match self.kind {
            Kind::Bridgehead => self.drive_bridge(w),
            Kind::Beachhead => self.drive_beach(w),
            Kind::Skyhook => self.drive_skyhook(w),
            Kind::Ambush => self.drive_ambush(w),
            Kind::Kingpin => self.drive_kingpin(w),
        }
    }

    fn drive_bridge(&mut self, w: &mut Context<'_, '_, '_>) -> Result<(), &'static str> {
        let e = self.p("e");
        let n = self.p("n");
        let now = w.state.field.now;
        let (stage, at) = if self.active("village") {
            ("village", self.p("nv"))
        } else if self.active("bridge") {
            ("bridge", self.p("c") + e * 6.)
        } else if self.active("hold") {
            ("hold", self.p("east") + e * 10.)
        } else {
            return Ok(());
        };
        if stage == "village" {
            self.call(w, "artillery", self.p("nv") - e * 6.)?;
        }

        for (i, id) in self.force(w.state).into_iter().enumerate() {
            if self.once(now, format!("sq{id}"), stage, 45.) {
                let p = at + n * ((i % 3) as f32 - 1.) * 12.;
                w.squad_order(
                    id,
                    if stage == "hold" {
                        Action::Defend {
                            position: p,
                            face: -e,
                        }
                    } else {
                        Action::Assault {
                            position: p,
                            face: -e,
                        }
                    },
                )?;
            }
        }

        let ifv = self.id("ifv");
        if alive(w.state, ifv) && self.once(now, "ifv".into(), stage, 45.) {
            w.vehicle_order(
                ifv,
                Action::Assault {
                    position: at + e * if stage == "hold" { 14. } else { 0. },
                    face: Vector3::ZERO,
                },
            )?;
        }

        Ok(())
    }

    fn drive_beach(&mut self, w: &mut Context<'_, '_, '_>) -> Result<(), &'static str> {
        let beach = self.p("beach");
        let h = self.p("h");
        let now = w.state.field.now;
        let boats = self.groups.get("boats").cloned().unwrap_or_default();
        if boats.len() > self.waypoints.len() {
            return Err("invalid landing boat attempts");
        }

        for (i, id) in boats.into_iter().enumerate() {
            if w.state
                .field
                .actors
                .vehicle(id)
                .is_some_and(|v| !v.gone && v.hp > 0. && !v.passengers.is_empty())
                && self.once(now, format!("rhib{id}"), "land", 20.)
            {
                let tries = self.waypoints[i];
                self.waypoints[i] = tries.saturating_add(1).min(100_000);
                w.vehicle_order(
                    id,
                    Action::Move {
                        position: beach
                            + Vector3::new(-6., 0., (i as f32 - 1.) * 14. + tries as f32 * 9.),
                        face: Vector3::ZERO,
                        mode: 0,
                    },
                )?;
            }
        }

        let ship = self.id("ship");
        if alive(w.state, ship) && self.once(now, "ship".into(), "cover", 0.) {
            let p = Vector3::new(
                w.state.water.coast_x(f64::from(h.z - 6.)) as f32 + 16.,
                0.,
                h.z - 6.,
            );
            w.vehicle_order(
                ship,
                Action::Assault {
                    position: w.boat(p),
                    face: Vector3::ZERO,
                },
            )?;
        }

        if alive(w.state, ship) {
            for id in self.groups.get("aa").cloned().unwrap_or_default() {
                if alive(w.state, id)
                    && w.state
                        .field
                        .actors
                        .vehicle(id)
                        .is_some_and(|v| v.visible & (1 << self.side) != 0)
                    && self.once(now, "ship_aa".into(), &format!("aa{id}"), 30.)
                {
                    w.vehicle_order(ship, Action::Attack(id))?;
                    break;
                }
            }
        }

        let (stage, at) = if self.active("aa") || self.active("land") {
            let points: Vec<_> = self
                .groups
                .get("aa")
                .into_iter()
                .flatten()
                .filter(|id| alive(w.state, **id))
                .filter_map(|id| position(w.state, *id))
                .collect();
            (
                format!("aa{}", points.len()),
                if points.is_empty() {
                    h
                } else {
                    points.iter().copied().fold(Vector3::ZERO, |a, b| a + b) / points.len() as f32
                },
            )
        } else if self.active("harbour") || self.active("hold") {
            ("harbour".into(), h - Vector3::X * 8.)
        } else {
            return Ok(());
        };
        if stage.starts_with("aa") && self.done("land") {
            self.call(w, "artillery", at)?;
        }

        for (i, id) in self.force(w.state).into_iter().enumerate() {
            if self.once(now, format!("sq{id}"), &stage, 45.) {
                w.squad_order(
                    id,
                    Action::Assault {
                        position: at + Vector3::Z * ((i % 3) as f32 - 1.) * 12.,
                        face: Vector3::NEG_X,
                    },
                )?;
            }
        }

        Ok(())
    }

    fn drive_skyhook(&mut self, w: &mut Context<'_, '_, '_>) -> Result<(), &'static str> {
        let mh = self.id("mh");
        let nyx = self.id("nyx");
        let op = self.p("op");
        let now = w.state.field.now;
        if self.active("deliver") && alive(w.state, mh) && alive(w.state, nyx) {
            let helicopter = w.state.field.actors.vehicle(mh).unwrap();
            let cargo = w.state.field.actors.vehicle(nyx).unwrap();
            if cargo.slung_by == 0 && helicopter.sling_cargo == 0 && helicopter.sling_target == 0 {
                w.vehicle_order(mh, Action::Sling(nyx))?;
            } else if helicopter.sling_cargo == nyx && self.once(now, "mh".into(), "carry", 0.) {
                w.vehicle_order(
                    mh,
                    Action::Move {
                        position: op + Vector3::new(8., 0., 6.),
                        face: Vector3::ZERO,
                        mode: 0,
                    },
                )?;
            }

            return Ok(());
        }

        if self.done("deliver") && alive(w.state, nyx) && self.once(now, "nyx".into(), "fight", 0.)
        {
            w.vehicle_order(
                nyx,
                Action::Move {
                    position: op - Vector3::Z * 6.,
                    face: Vector3::ZERO,
                    mode: 0,
                },
            )?;
        }

        if self.active("column") {
            let ids = self.objective("column").unwrap().entities.clone();
            let mut near = None;
            let mut nd = f32::INFINITY;
            for id in ids {
                if !alive(w.state, id) {
                    continue;
                }

                if let Some(v) = w.state.field.actors.vehicle(id) {
                    let at = v.position;
                    let d = distance(at, op);
                    if w.content.vehicle(v)["weight"].as_u64().unwrap_or(1) < 1 {
                        continue;
                    }

                    if d > 80. && d < 180. {
                        self.call(w, "artillery", at)?;
                    }

                    if d < nd {
                        nd = d;
                        near = Some(id);
                    }
                }
            }

            if let Some(id) = near.filter(|_| alive(w.state, nyx)) {
                if nd < 75.
                    && self.once(
                        now,
                        "nyx_back".into(),
                        &format!("back{}", (now / 12.) as u64),
                        0.,
                    )
                {
                    w.vehicle_order(
                        nyx,
                        Action::Move {
                            position: op + Vector3::Z * 22.,
                            face: Vector3::ZERO,
                            mode: 0,
                        },
                    )?;
                } else if (75. ..140.).contains(&nd)
                    && self.once(now, format!("nyx_atk{id}"), "atk", 20.)
                {
                    w.vehicle_order(nyx, Action::Attack(id))?;
                }
            }
        }

        for id in self.force(w.state) {
            if self.once(now, format!("sq{id}"), "kilo", 45.) {
                w.squad_order(
                    id,
                    Action::Defend {
                        position: op - Vector3::Z * 10.,
                        face: Vector3::NEG_Z,
                    },
                )?;
            }
        }

        if alive(w.state, mh) && self.done("deliver") && self.once(now, "mh".into(), "home", 0.) {
            w.vehicle_order(
                mh,
                Action::Move {
                    position: self.p("pad"),
                    face: Vector3::ZERO,
                    mode: 0,
                },
            )?;
        }

        Ok(())
    }

    fn drive_ambush(&mut self, w: &mut Context<'_, '_, '_>) -> Result<(), &'static str> {
        let ap = self.p("ap");
        let n = self.p("n");
        let t = self.p("t");
        let now = w.state.field.now;
        if self.active("convoy") {
            for id in self.groups.get("convoy").cloned().unwrap_or_default() {
                if let Some(v) = w.state.field.actors.vehicle(id).filter(|v| {
                    !v.gone
                        && v.hp > 0.
                        && v.visible & (1 << self.side) != 0
                        && v.speed.abs() < 2.
                        && distance(v.position, ap) > 35.
                }) {
                    let p = v.position;
                    self.call(w, "mortars", p)?;
                    break;
                }
            }
        }

        let stage = if self.active("exfil") {
            "exfil"
        } else {
            "ambush"
        };
        for (i, id) in self.force(w.state).into_iter().enumerate() {
            if self.once(now, format!("sq{id}"), stage, 45.) {
                w.squad_order(
                    id,
                    if stage == "exfil" {
                        Action::Move {
                            position: self.p("rp") + t * ((i % 3) as f32 - 1.) * 8.,
                            face: n,
                            mode: 2,
                        }
                    } else {
                        Action::Defend {
                            position: ap + t * ((i % 4) as f32 - 1.5) * 9.,
                            face: -n,
                        }
                    },
                )?;
            }
        }

        Ok(())
    }

    fn known(
        &self,
        state: &MatchState,
        seconds: f64,
        soldiers_only: bool,
    ) -> BTreeMap<u32, sim::squad::Report> {
        let mut known: BTreeMap<u32, sim::squad::Report> = BTreeMap::new();
        for q in state.field.squads.iter().filter(|q| q.team == self.side) {
            for k in &q.known {
                let valid = match state.field.actors.get(k.id) {
                    Some(Actor::Soldier(s)) => !s.identity.gone && s.vitals.life == Life::Alive,
                    Some(Actor::Vehicle(v)) => !soldiers_only && !v.gone && v.hp > 0.,
                    _ => false,
                };
                if valid
                    && state.field.now - k.report.time <= seconds
                    && known.get(&k.id).is_none_or(|old| k.report.time > old.time)
                {
                    known.insert(k.id, k.report);
                }
            }
        }

        known
    }

    fn stuck(&self, state: &MatchState, force: &[u32]) -> Option<Vector3> {
        for id in force {
            if let Some(q) = state.field.squads.iter().find(|q| q.id == *id) {
                if let Some(p) = state.attacks.iter().find(|p| {
                    p.id == q.plan
                        && !p.done
                        && matches!(
                            p.phase,
                            sim::attack_plan::Phase::Fix | sim::attack_plan::Phase::Fallback
                        )
                }) {
                    return Some(p.fire_at);
                }
            }
        }

        None
    }

    fn rpgs(&self, w: &Context<'_, '_, '_>, p: Vector3, r: f32) -> bool {
        self.known(w.state, 60., true).into_iter().any(|(id, k)| {
            w.state
                .field
                .actors
                .soldier(id)
                .is_some_and(|s| s.arsenal.rockets > 0 && distance(k.position, p) < r)
        })
    }

    fn kingpin_target(&mut self, w: &Context<'_, '_, '_>, stage: &str) -> Vector3 {
        let known = self.known(w.state, 30., true);
        if stage == "cp" {
            let points: Vec<_> = known
                .values()
                .filter(|k| distance(k.position, self.p("cp")) < 30.)
                .map(|k| k.position)
                .collect();
            return if points.is_empty() {
                self.p("cp")
            } else {
                points.iter().copied().fold(Vector3::ZERO, |a, b| a + b) / points.len() as f32
            };
        }

        let hv = self.p("hv");
        let Some(h) = w
            .state
            .field
            .actors
            .soldier(self.id("hvt"))
            .filter(|s| matches!(s.vitals.life, Life::Alive | Life::Hidden))
        else {
            return hv;
        };
        let gone = distance(h.motion.position, hv) > 15.;
        if gone && self.count(w, hv, 12., true, true) > 0 {
            self.flags |= 1;
        }

        if h.identity.visible & (1 << self.side) != 0 {
            return h.motion.position;
        }

        if let Some(k) = known.get(&h.identity.id) {
            return k.position;
        }

        let guards: Vec<_> = known
            .iter()
            .filter(|(id, k)| {
                w.state
                    .field
                    .actors
                    .soldier(**id)
                    .is_some_and(|s| s.identity.squad == h.identity.squad)
                    && distance(k.position, hv) > 15.
            })
            .map(|(_, k)| k.position)
            .collect();
        if !guards.is_empty() {
            return guards.iter().copied().fold(Vector3::ZERO, |a, b| a + b) / guards.len() as f32;
        }

        if gone && self.flags & 1 != 0 {
            h.motion.position
        } else {
            hv
        }
    }

    fn kingpin_drone(
        &mut self,
        w: &mut Context<'_, '_, '_>,
        stage: &str,
        at: Vector3,
    ) -> Result<(), &'static str> {
        if self.flags & 2 != 0 || !self.ready(w, "greyhawk") {
            return Ok(());
        }

        let mut aim = if stage == "exfil" {
            self.known(w.state, 8., false)
                .values()
                .filter(|k| distance(k.position, at) < 160.)
                .min_by(|a, b| distance(a.position, at).total_cmp(&distance(b.position, at)))
                .map(|k| k.position)
        } else {
            self.stuck(w.state, &self.force(w.state))
        };
        if stage == "hvt" {
            if let Some(h) = w
                .state
                .field
                .actors
                .soldier(self.id("hvt"))
                .filter(|_| alive(w.state, self.id("hvt")))
            {
                let out = distance(h.motion.position, self.p("hv")) > 15.;
                if out && h.identity.visible & (1 << self.side) != 0 {
                    aim = Some(h.motion.position);
                } else if !out && aim.is_some_and(|p| distance(p, self.p("hv")) < 30.) {
                    aim = None;
                }
            }
        }

        if let Some(p) = aim {
            if !w.state.field.actors.iter().any(|a| matches!(a,Actor::Soldier(s) if s.identity.team==self.side&&s.vitals.life==Life::Alive&&distance(s.motion.position,p)<30.)) && self.call(w, "greyhawk", p)? {
                self.flags |= 2;
            }
        }

        Ok(())
    }

    fn drive_kingpin(&mut self, w: &mut Context<'_, '_, '_>) -> Result<(), &'static str> {
        let stage = if self.active("checkpoint") {
            "cp"
        } else if self.active("hvt") {
            "hvt"
        } else if self.active("exfil") {
            "exfil"
        } else {
            return Ok(());
        };
        let now = w.state.field.now;
        let start = self.p("start");
        let hunters = self.groups.get("vh").cloned().unwrap_or_default();
        if stage == "exfil" {
            for (i, id) in self.force(w.state).into_iter().enumerate() {
                if self.once(now, format!("sq{id}"), stage, 20.) {
                    w.squad_order(
                        id,
                        Action::Move {
                            position: start + Vector3::X * ((i % 3) as f32 - 1.) * 8.,
                            face: Vector3::NEG_Z,
                            mode: 2,
                        },
                    )?;
                }
            }

            for id in hunters {
                if alive(w.state, id) && self.once(now, format!("vh{id}"), stage, 45.) {
                    w.vehicle_order(
                        id,
                        Action::Assault {
                            position: w.walk(start - Vector3::Z * 40.),
                            face: Vector3::ZERO,
                        },
                    )?;
                }
            }

            self.kingpin_drone(w, stage, start)?;
            return Ok(());
        }

        let at = self.kingpin_target(w, stage);
        let force: Vec<_> = self
            .force(w.state)
            .into_iter()
            .filter(|id| {
                w.state
                    .field
                    .squads
                    .iter()
                    .any(|q| q.id == *id && q.kind != "crew")
            })
            .collect();
        if !force.is_empty() {
            let mut center = Vector3::ZERO;
            let mut going = false;
            let mut by_owner: BTreeMap<i32, Vec<u32>> = BTreeMap::new();
            for &id in &force {
                let q = w
                    .state
                    .field
                    .squads
                    .iter_mut()
                    .find(|q| q.id == id)
                    .unwrap();
                center += q.centroid(now, &w.state.field.actors);
                going |= w.state.attacks.iter().any(|p| p.id == q.plan && !p.done);
                by_owner.entry(q.owner).or_default().push(id);
            }

            center /= force.len() as f32;
            let moved = self
                .places
                .get("force_target")
                .is_none_or(|p| distance(*p, at) > 25.);
            let continue_order = self
                .staged
                .get("kp_force")
                .is_some_and(|(s, t)| s == stage && (now - t < 20. || going && !moved));
            if !continue_order {
                self.staged.insert("kp_force".into(), (stage.into(), now));
                self.places.insert("force_target".into(), at);
                let action = if stage == "hvt"
                    && distance(at, center) > 100.
                    && distance(at, self.p("hv")) > 25.
                {
                    Action::Move {
                        position: w.walk(at + normalized(flat(center - at)) * 70.),
                        face: Vector3::ZERO,
                        mode: 2,
                    }
                } else {
                    Action::Assault {
                        position: at,
                        face: Vector3::ZERO,
                    }
                };
                for (owner, ids) in by_owner {
                    w.command(owner, ids, vec![], action.clone())?;
                }
            }
        }

        self.kingpin_drone(w, stage, at)?;
        let cp = self.p("cp");
        let back = normalized(flat(start - at));
        let mut fb = cp + Vector3::Z * 85.;
        if stage == "cp"
            && (self.flags & 4 != 0 || self.stuck(w.state, &force).is_some())
            && !self.rpgs(w, cp, 110.)
        {
            self.flags |= 4;
            fb = at + back * 50.;
        } else if stage == "hvt" && !self.rpgs(w, at + back * 55., 90.) {
            fb = at + back * 55.;
        }

        fb = w.walk(fb);
        let hvt = self.id("hvt");
        let chase = stage == "hvt"
            && alive(w.state, hvt)
            && w.state.field.actors.soldier(hvt).is_some_and(|s| {
                s.identity.visible & (1 << self.side) != 0
                    && distance(s.motion.position, self.p("hv")) > 15.
                    && !self.rpgs(w, s.motion.position, 90.)
            });
        for id in hunters {
            if !alive(w.state, id) {
                continue;
            }

            if chase {
                if self.once(now, format!("vh{id}"), "chase", 10.) {
                    w.vehicle_order(id, Action::Attack(hvt))?;
                }
            } else {
                let key = format!(
                    "{stage}:{:.0},{:.0}",
                    (fb.x / 20.).round(),
                    (fb.z / 20.).round()
                );
                if self.once(now, format!("vh{id}"), &key, 45.) {
                    w.vehicle_order(
                        id,
                        Action::Assault {
                            position: fb,
                            face: Vector3::ZERO,
                        },
                    )?;
                }
            }
        }

        Ok(())
    }
}
