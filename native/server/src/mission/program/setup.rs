use super::*;

fn village(landmarks: &[Landmark], at: Vector3, side: i8) -> Vector3 {
    nearest(
        landmarks
            .iter()
            .filter(|p| {
                p.kind == "village"
                    && (side == 0
                        || if side > 0 {
                            p.position.x > at.x + 30.
                        } else {
                            p.position.x < at.x - 30.
                        })
            })
            .map(|p| p.position),
        at,
    )
    .unwrap_or(at + Vector3::X * (130. * if side < 0 { -1. } else { 1. }))
}
fn bridge(state: &MatchState, zsign: f32) -> Result<sim::water::Bridge, &'static str> {
    state
        .water
        .bridges
        .iter()
        .filter(|b| !b.quay)
        .max_by(|a, b| {
            let score = |br: &sim::water::Bridge| {
                let p = (br.a + br.b) * 0.5;
                p.z * zsign - if p.z.abs() > 60. { 0. } else { 1000. }
            };
            score(a).total_cmp(&score(b))
        })
        .copied()
        .ok_or("mission requires a river bridge")
}
impl Mission {
    pub(super) fn setup_bridge(
        &mut self,
        w: &mut Context<'_, '_, '_>,
        landmarks: &[Landmark],
    ) -> Result<(), &'static str> {
        let br = bridge(w.state, 1.)?;
        let c = (br.a + br.b) * 0.5;
        let (east, west) = if br.a.x > br.b.x {
            (br.a, br.b)
        } else {
            (br.b, br.a)
        };
        let nv = village(landmarks, c, 1);
        let fv = village(landmarks, c, -1);
        let e = normalized(flat(nv - c));
        let n = Vector3::new(-e.z, 0., e.x);
        let start = nv + e * 125.;
        self.places(&[
            ("c", c),
            ("east", east),
            ("west", west),
            ("nv", nv),
            ("fv", fv),
            ("e", e),
            ("n", n),
        ]);
        if let Some(ford) =
            nearest(w.state.water.fords.iter().copied(), c).filter(|p| distance(*p, c) < 260.)
        {
            self.places.insert("ford".into(), ford);
        }
        self.focus = start - e * 18.;
        self.focus_yaw = yaw_of(-e);
        for (kind, p) in [
            ("rifle_squad", start + n * 12.),
            ("rifle_squad", start - n * 12.),
            ("mg_team", start + n * 3. + e * 6.),
            ("at_team", start - n * 4. + e * 7.),
        ] {
            self.ours_squad(w, kind, p, Some(p - e * 4.))?;
        }
        let owner = self.owner();
        let ifv = w.vehicle(
            "marshall",
            self.side,
            owner,
            w.walk(start + e * 18.),
            yaw_of(-e),
            true,
        )?;
        self.groups.insert("ifv".into(), vec![ifv]);
        let h = houses(w.state, nv, 45.).first().copied().unwrap_or(nv);
        for (kind, p, at) in [
            ("fighter_cell", h + e * 4., h + e * 4.),
            ("pkm_team", nv - n * 16. + e * 6., nv - n * 16. + e * 6.),
            ("pkm_team", east + e * 10., east + e * 8.),
        ] {
            self.enemy_squad(
                w,
                kind,
                p,
                Action::Defend {
                    position: at,
                    face: e,
                },
            )?;
        }
        let tech = w.vehicle(
            "technical",
            self.foe(),
            -1 - i32::from(self.foe()),
            w.walk(nv - e * 10.),
            yaw_of(e),
            false,
        )?;
        w.vehicle_order(tech, Action::Stop)?;
        self.grant(w, &["artillery"], 650.)?;
        self.add(Objective::new(
            "village",
            "Clear the village",
            Goal::Clear,
            Some(nv),
            42.,
        ));
        self.add(Objective::new(
            "bridge",
            "Seize the bridge",
            Goal::Clear,
            Some(c + e * 6.),
            26.,
        ));
        let mut o = Objective::new(
            "hold",
            "Hold the bridge until the tanks arrive",
            Goal::Hold,
            Some(east + e * 6.),
            40.,
        );
        o.seconds = 120.;
        o.failure = "The Rebels have retaken the bridge.".into();
        self.add(o);
        let mut o = Objective::new(
            "marshall",
            "Keep the Marshall in the fight",
            Goal::Protect,
            None,
            30.,
        );
        o.entities = vec![ifv];
        o.optional = true;
        self.add(o);
        self.radio(
            w,
            concat!(
                "Overlord: Rebels hold the village and the bridge behind it. Clear the ",
                "village, then take that bridge before they blow it."
            ),
            Some(nv),
        );
        self.start(w, "marshall", 0);
        self.start(w, "village", 1);
        Ok(())
    }
    pub(super) fn setup_beach(
        &mut self,
        w: &mut Context<'_, '_, '_>,
        landmarks: &[Landmark],
    ) -> Result<(), &'static str> {
        if w.state.water.coast.is_none() {
            return Err("beachhead requires a coast");
        }
        let h = landmarks.iter().find(|p| p.kind == "harbour").map_or(
            Vector3::new(w.state.water.coast_x(0.) as f32 - 6., 0., 0.),
            |p| p.position,
        );
        let zb = h.z + 145.;
        let beach = Vector3::new(w.state.water.coast_x(f64::from(zb)) as f32 - 12., 0., zb);
        let z0 = h.z + 290.;
        let half = w.state.water.side as f32 * 0.5;
        let sea0 = Vector3::new(
            (w.state.water.coast_x(f64::from(z0)) as f32 + 95.).min(half - 20.),
            0.,
            z0,
        );
        self.places(&[("h", h), ("beach", beach), ("sea0", sea0)]);
        self.focus = sea0 + Vector3::new(-50., 0., -40.);
        self.focus_yaw = yaw_of(normalized(flat(h - sea0)));
        let mut boats = vec![];
        for (i, loads) in [
            &["rifle_squad"][..],
            &["rifle_squad"][..],
            &["mg_team", "at_team"][..],
        ]
        .into_iter()
        .enumerate()
        {
            let p = w.boat(sea0 + Vector3::new(-(i as f32) * 14., 0., i as f32 * 18.));
            let owner = self.owner();
            let boat = w.vehicle("rhib", self.side, owner, p, yaw_of(flat(beach - p)), false)?;
            for kind in loads {
                let squad = self.ours_squad(w, kind, beach, None)?;
                w.board(boat, squad)?;
            }
            boats.push(boat);
        }
        self.groups.insert("boats".into(), boats);
        self.waypoints = vec![0; 3];
        let owner = self.owner();
        let ship = w.vehicle(
            "patrol_ship",
            self.side,
            owner,
            w.boat(sea0 + Vector3::new(14., 0., -30.)),
            yaw_of(flat(h - sea0)),
            false,
        )?;
        self.groups.insert("ship".into(), vec![ship]);
        let post = h + Vector3::new(-24., 0., 52.);
        self.enemy_squad(
            w,
            "pkm_team",
            post,
            Action::Defend {
                position: post,
                face: normalized(Vector3::new(0.6, 0., 0.8)),
            },
        )?;
        for k in 0..3 {
            w.building(
                "sandbags",
                (post + Vector3::new(2., 0., (k as f32 - 1.) * 4.4 + 2.)).round(),
                std::f64::consts::FRAC_PI_2,
                self.foe(),
                true,
            )?;
        }
        self.enemy_squad(
            w,
            "fighter_cell",
            h + Vector3::new(-14., 0., 10.),
            Action::Defend {
                position: h - Vector3::X * 12.,
                face: Vector3::X,
            },
        )?;
        let mut aa = vec![];
        for p in [
            h + Vector3::new(-26., 0., 30.),
            h + Vector3::new(-30., 0., -24.),
        ] {
            let id = w.vehicle(
                "aa_tech",
                self.foe(),
                -1 - i32::from(self.foe()),
                w.walk(p),
                yaw_of(Vector3::X),
                false,
            )?;
            w.vehicle_order(id, Action::Stop)?;
            aa.push(id);
        }
        self.groups.insert("aa".into(), aa.clone());
        let mut enemy_boats = vec![];
        for (kind, offset) in [
            ("motorboat", Vector3::new(36., 0., -26.)),
            ("speedboat_hmg", Vector3::new(54., 0., 24.)),
        ] {
            enemy_boats.push(w.vehicle(
                kind,
                self.foe(),
                -1 - i32::from(self.foe()),
                w.boat(h + offset),
                std::f64::consts::FRAC_PI_2,
                false,
            )?);
        }
        self.groups
            .insert("enemy_boats".into(), enemy_boats.clone());
        self.after(w.state.field.now, 22., 9);
        self.grant(w, &["artillery"], 320.)?;
        let mut o = Objective::new("land", "Land on the beach", Goal::Reach, Some(beach), 30.);
        o.need = 4;
        o.afoot = true;
        self.add(o);
        let mut o = Objective::new(
            "aa",
            "Destroy the two AA guns",
            Goal::Destroy,
            Some(h - Vector3::X * 28.),
            30.,
        );
        o.entities = aa;
        self.add(o);
        let mut o = Objective::new(
            "harbour",
            "Clear the harbour",
            Goal::Clear,
            Some(h - Vector3::X * 8.),
            42.,
        );
        o.afoot = true;
        self.add(o);
        let mut o = Objective::new(
            "hold",
            "Hold the harbour until the landing craft are in",
            Goal::Hold,
            Some(h - Vector3::X * 8.),
            50.,
        );
        o.seconds = 90.;
        o.afoot = true;
        o.failure = "The Rebels have retaken the harbour.".into();
        self.add(o);
        let mut o = Objective::new(
            "boats",
            "Sink the enemy boats",
            Goal::Destroy,
            Some(h + Vector3::X * 40.),
            30.,
        );
        o.entities = enemy_boats;
        o.optional = true;
        o.track = true;
        self.add(o);
        self.radio(
            w,
            concat!(
                "Overlord: Two AA guns cover the harbour and our helicopters can't get in. ",
                "Land on the beach, find the guns and kill them."
            ),
            Some(beach),
        );
        self.start(w, "boats", 14);
        self.start(w, "land", 10);
        Ok(())
    }
    pub(super) fn setup_skyhook(
        &mut self,
        w: &mut Context<'_, '_, '_>,
        landmarks: &[Landmark],
    ) -> Result<(), &'static str> {
        let br = bridge(w.state, -1.)?;
        let c = (br.a + br.b) * 0.5;
        let nv = village(landmarks, c, 1);
        let op = village(landmarks, c, -1);
        let e = normalized(flat(nv - c));
        let pad = w.walk(nv + e * 70.);
        let north = Vector3::NEG_Z;
        let west = Vector3::NEG_X;
        let c0 = op + north * 240.;
        self.places(&[("op", op), ("pad", pad), ("c", c), ("e", e), ("c0", c0)]);
        self.focus = pad - Vector3::X * 30.;
        self.focus_yaw = yaw_of(west);
        w.building("helipad", pad, 0., self.side, false)?;
        let owner = self.owner();
        let mh = w.vehicle("mohawk", self.side, owner, pad, yaw_of(west), false)?;
        let owner = self.owner();
        let nyx = w.vehicle(
            "nyx_at",
            self.side,
            owner,
            w.walk(pad + Vector3::Z * 20.),
            yaw_of(west),
            false,
        )?;
        w.vehicle_order(nyx, Action::Stop)?;
        self.groups.insert("mh".into(), vec![mh]);
        self.groups.insert("nyx".into(), vec![nyx]);
        self.ours_squad(
            w,
            "rifle_squad",
            pad + Vector3::new(14., 0., -10.),
            Some(pad + Vector3::new(10., 0., -12.)),
        )?;
        for k in 0..5 {
            w.building(
                "sandbags",
                (op + north * 16. + west * ((k as f32 - 2.) * 4.6)).round(),
                0.,
                self.side,
                true,
            )?;
        }
        if let Some(nest) = w.building(
            "hmg_nest",
            (op + north * 19. + west * 13.).round(),
            0.,
            self.side,
            true,
        )? {
            let owner = self.owner();
            let gunner = w.infantry(
                "mg_gunner",
                self.side,
                owner,
                op + north * 19. + west * 13.,
                0,
                "",
            )?;
            w.command(
                owner,
                vec![],
                vec![],
                Action::Unit {
                    soldier: gunner,
                    order: sim::match_commands::UnitOrder::Man(nest),
                },
            )?;
        }
        for (kind, p, at) in [
            ("rifle_squad", op + north * 10., op + north * 12.),
            (
                "mg_team",
                op + north * 12. - west * 10.,
                op + north * 14. - west * 10.,
            ),
        ] {
            let q = self.ours_squad(w, kind, p, None)?;
            w.squad_order(
                q,
                Action::Defend {
                    position: at,
                    face: north,
                },
            )?;
        }
        self.grant(w, &["artillery"], 320.)?;
        for (index, offset, ahead) in [
            (0, Vector3::ZERO, 20.),
            (1, Vector3::new(-8., 0., -10.), 24.),
            (2, Vector3::new(10., 0., -24.), 30.),
        ] {
            let p = w.vehicle_approach(c0 + offset, op - Vector3::Z * ahead)?;
            self.places.insert(format!("column_{index}"), p);
        }
        let mut o = Objective::new(
            "deliver",
            "Sling the Nyx to Outpost Kilo",
            Goal::Deliver,
            Some(op),
            34.,
        );
        o.entities = vec![nyx];
        o.failure = "The Nyx has been lost.".into();
        self.add(o);
        let mut o = Objective::new("kilo", "Don't let Kilo fall", Goal::Guard, Some(op), 40.);
        o.grace = 25.;
        o.mark = false;
        o.failure = "Outpost Kilo has been overrun.".into();
        self.add(o);
        let mut o = Objective::new(
            "column",
            "Stop the armoured column",
            Goal::Destroy,
            Some(op + north * 60.),
            30.,
        );
        o.need = 2;
        self.add(o);
        self.radio(
            w,
            concat!(
                "Kilo: Overlord, Kilo. Armour forming up a click north of us and we've got ",
                "nothing that can touch it. Requesting anti-armour, over."
            ),
            Some(op),
        );
        self.after(w.state.field.now, 6., 17);
        self.start(w, "deliver", 18);
        self.start(w, "kilo", 0);
        self.after(w.state.field.now, 80., 19);
        self.after(w.state.field.now, 140., 20);
        Ok(())
    }
    pub(super) fn setup_ambush(
        &mut self,
        w: &mut Context<'_, '_, '_>,
        landmarks: &[Landmark],
    ) -> Result<(), &'static str> {
        let want = Vector3::new(160., 0., -200.);
        let ev = nearest(
            landmarks
                .iter()
                .filter(|p| p.kind == "village" && p.position.x > 60. && p.position.z < 0.)
                .map(|p| p.position),
            want,
        )
        .unwrap_or_else(|| village(landmarks, want, 0));
        let lane = road_near(w.state, ev, &[]);
        let mut pts = resample(&lane, 4.);
        if pts.len() < 3 {
            return Err("ambush requires a village road");
        }
        if distance(pts[0], ev) > distance(*pts.last().unwrap(), ev) {
            pts.reverse();
        }
        let i0 = (0..pts.len())
            .min_by(|a, b| distance(pts[*a], ev).total_cmp(&distance(pts[*b], ev)))
            .unwrap();
        let mut route = pts[i0..].to_vec();
        let junction = *route.last().unwrap();
        let main = resample(&road_near(w.state, junction, &lane), 4.);
        if main.len() < 2 {
            return Err("ambush requires a connecting road");
        }
        let j0 = (0..main.len())
            .min_by(|a, b| distance(main[*a], junction).total_cmp(&distance(main[*b], junction)))
            .unwrap();
        let lane_n = route.len();
        let direction = if main.last().unwrap().z > main[0].z {
            1
        } else {
            -1
        };
        let mut k = j0 as i32;
        for _ in 0..100 {
            if k < 0 || k as usize >= main.len() {
                break;
            }
            route.push(main[k as usize]);
            k += direction;
        }
        if route.len() < 3 {
            return Err("ambush route is too short");
        }
        let ki = ((lane_n as f64 * 0.72) as usize).clamp(1, route.len() - 2);
        let kz = route[ki];
        let t = normalized(flat(
            route[(ki + 3).min(route.len() - 1)] - route[ki.saturating_sub(3)],
        ));
        let mut n = Vector3::new(-t.z, 0., t.x);
        if n.z > 0. {
            n = -n;
        }
        let ap = w.walk(kz + n * 36.);
        let rp = w.walk(ap + n * 150. - t * 30.);
        let start = w.walk(ap + n * 120.);
        self.places(&[("kz", kz), ("t", t), ("n", n), ("ap", ap), ("rp", rp)]);
        self.route = route;
        self.waypoints = vec![1; 4];
        self.groups.insert("convoy".into(), vec![]);
        self.focus = start - n * 30.;
        self.focus_yaw = yaw_of(-n);
        for (center, count) in [(ap + n * 4., 14), (ap - t * 26. + n * 6., 8)] {
            for _ in 0..count {
                let p = center
                    + Vector3::new(
                        w.state.field.rng.randf_range(-11., 11.) as f32,
                        0.,
                        w.state.field.rng.randf_range(-11., 11.) as f32,
                    );
                w.building("tree", p, 0., -1, true)?;
            }
        }
        w.building("mines", (kz + t * 6.).round(), yaw_of(t), self.side, false)?;
        for (kind, p) in [
            ("fighter_cell", start + t * 12.),
            ("rpg_team", start - t * 12.),
            ("rpg_team", start + t * 2.),
            ("pkm_team", start - t * 4. + n * 6.),
        ] {
            self.ours_squad(w, kind, p, Some(p - n * 4.))?;
        }
        self.grant(w, &["mortars"], 260.)?;
        let mut o = Objective::new(
            "position",
            "Get into the woods above the lane",
            Goal::Reach,
            Some(ap),
            26.,
        );
        o.need = 6;
        self.add(o);
        let mut o = Objective::new(
            "depart",
            "The convoy leaves the village",
            Goal::Timer,
            None,
            30.,
        );
        o.seconds = 100.;
        self.add(o);
        let mut o = Objective::new("convoy", "Destroy the convoy", Goal::Destroy, Some(kz), 30.);
        o.need = 3;
        o.track = true;
        self.add(o);
        let mut o = Objective::new(
            "exfil",
            "Break contact: back to the rally point",
            Goal::Extract,
            Some(rp),
            30.,
        );
        o.fraction = 0.6;
        self.add(o);
        self.radio(
            w,
            concat!(
                "Cell leader: The convoy leaves the village when the light goes. Into the ",
                "woods above the lane, and nobody fires before the RPGs."
            ),
            Some(ap),
        );
        self.start(w, "position", 22);
        self.start(w, "depart", 23);
        Ok(())
    }
    pub(super) fn setup_kingpin(
        &mut self,
        w: &mut Context<'_, '_, '_>,
        landmarks: &[Landmark],
    ) -> Result<(), &'static str> {
        let town = landmarks
            .iter()
            .find(|p| p.kind == "town")
            .map_or(Vector3::ZERO, |p| p.position);
        let main = w.state.rules.network.roads[2]
            .iter()
            .filter(|road| road.iter().any(|p| distance(*p, town) < 60.))
            .max_by(|a, b| {
                let span = |r: &Vec<Vector3>| {
                    r.iter().map(|p| p.z).fold(f32::NEG_INFINITY, f32::max)
                        - r.iter().map(|p| p.z).fold(f32::INFINITY, f32::min)
                };
                span(a).total_cmp(&span(b))
            })
            .ok_or("kingpin requires a town street")?;
        let main = resample(main, 4.);
        let want = town + Vector3::new(18., 0., -55.);
        let hv = houses(w.state, want, 60.).first().copied().unwrap_or(want);
        let street = nearest(main.iter().copied(), hv).ok_or("empty mission street")?;
        let cp = nearest(main.iter().copied(), hv + Vector3::Z * 75.).unwrap();
        let start = nearest(main.iter().copied(), hv + Vector3::Z * 220.).unwrap();
        self.places(&[("hv", hv), ("cp", cp), ("start", start), ("street", street)]);
        self.focus = start + Vector3::Z * 12.;
        self.focus_yaw = 0.;
        for (kind, p) in [
            ("rifle_squad", start + Vector3::X * 8.),
            ("rifle_squad", start - Vector3::X * 8.),
            ("mg_team", start + Vector3::Z * 6.),
        ] {
            self.ours_squad(w, kind, p, Some(p - Vector3::Z * 4.))?;
        }
        let mut hunters = vec![];
        for i in 0..2 {
            let owner = self.owner();
            let id = w.vehicle(
                "hunter_hmg",
                self.side,
                owner,
                w.walk(start + Vector3::Z * (16. + i as f32 * 12.)),
                0.,
                false,
            )?;
            w.vehicle_order(id, Action::Stop)?;
            hunters.push(id);
        }
        self.groups.insert("vh".into(), hunters);
        for k in 0..3 {
            w.building(
                "sandbags",
                (cp + Vector3::X * ((k as f32 - 1.) * 4.4) + Vector3::Z * 2.).round(),
                0.,
                self.foe(),
                true,
            )?;
        }
        w.building(
            "wreck",
            cp + Vector3::X * 8. - Vector3::Z * 3.,
            0.4,
            -1,
            true,
        )?;
        self.enemy_squad(
            w,
            "fighter_cell",
            cp - Vector3::Z * 4.,
            Action::Defend {
                position: cp,
                face: Vector3::Z,
            },
        )?;
        self.enemy_squad(
            w,
            "rpg_team",
            cp - Vector3::Z * 8. - Vector3::X * 9.,
            Action::Defend {
                position: cp - Vector3::Z * 4. - Vector3::X * 9.,
                face: Vector3::Z,
            },
        )?;
        let wp = houses(w.state, (cp + hv) * 0.5, 30.)
            .first()
            .copied()
            .unwrap_or((cp + hv) * 0.5 + Vector3::X * 12.);
        self.enemy_squad(
            w,
            "pkm_team",
            wp,
            Action::Defend {
                position: wp,
                face: Vector3::Z,
            },
        )?;
        let guard = self.enemy_squad(
            w,
            "fighter_cell",
            hv,
            Action::Defend {
                position: hv,
                face: Vector3::Z,
            },
        )?;
        let hvt = w.infantry(
            "fighter",
            self.foe(),
            -1 - i32::from(self.foe()),
            hv,
            guard,
            "Commander Rashid Kassem",
        )?;
        self.groups.insert("hvt".into(), vec![hvt]);
        self.grant(w, &["greyhawk"], 260.)?;
        if let Some(row) = w.state.rules.support.ready[self.side as usize]
            .iter_mut()
            .find(|r| r.0 == "greyhawk")
        {
            row.1 = w.state.field.now + 120.;
        }
        self.after(w.state.field.now, 120., 28);
        self.add(Objective::new(
            "checkpoint",
            "Clear the checkpoint",
            Goal::Clear,
            Some(cp),
            24.,
        ));
        let mut o = Objective::new(
            "hvt",
            "Kill or capture Commander Kassem",
            Goal::Destroy,
            Some(hv),
            30.,
        );
        o.entities = vec![hvt];
        self.add(o);
        self.add(Objective::new(
            "exfil",
            "Get back to the Hunters",
            Goal::Extract,
            Some(start),
            30.,
        ));
        self.radio(w, "Overlord: Kassem is in the marked house. Checkpoint on the main street first. Quiet as you can.", Some(hv));
        self.start(w, "checkpoint", 29);
        Ok(())
    }
}
