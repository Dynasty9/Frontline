//! Construction, supply expansion and recruitment.
use super::*;

impl Commander {
    pub(super) fn engineer(&self, w: &Context<'_, '_, '_>, c: &Census, p: Vector3) -> Option<u32> {
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
    pub(super) fn find_spot(
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
    pub(super) fn build(
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
    pub(super) fn economy(
        &mut self,
        w: &mut Context<'_, '_, '_>,
        c: &Census,
    ) -> Result<(), &'static str> {
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
    pub(super) fn dig_line(
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
    pub(super) fn pick_squad(&mut self, c: &Census, now: f64) -> &'static str {
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
    pub(super) fn vehicle_pick(&mut self, w: &Context<'_, '_, '_>, c: &Census) -> String {
        let mut picks = vec![];
        let mut total = 0.;
        for key in (w.profiles.produces)("factory") {
            if !w.unlocked(self.team, key) {
                continue;
            }
            let d = &w.content.definitions().vehicles[key];
            let weight = match d.base.as_str() {
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
                    if d.service.is_empty() {
                        0.8
                    } else {
                        0.5
                    }
                }
                _ => 1.,
            } * (1. + 0.25 * (d.tier.unwrap_or(1.) - 1.));
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
    pub(super) fn production(
        &mut self,
        w: &mut Context<'_, '_, '_>,
        c: &Census,
    ) -> Result<(), &'static str> {
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
                    room = w.content.definitions().vehicles[&self.next_vehicle]
                        .cap
                        .unwrap_or(0.) as u64;
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
                        w.state.field.actors.iter().filter(|a| matches!(a, Actor::Vehicle(v) if v.team == self.team && if base == "supply" {w.content.vehicle(v).supply} else {w.content.vehicle(v).base.as_str() == base && !w.content.vehicle(v).supply})).count()
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
                            let d = &w.content.definitions().vehicles[*k];
                            w.unlocked(self.team, k)
                                && if want == "supply" {
                                    d.supply
                                } else {
                                    d.base.as_str() == want && !d.supply
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
                "research" if queued == 0 => w
                    .content
                    .definitions()
                    .upgrades
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
}
