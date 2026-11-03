use super::*;
impl Mission {
    pub(in crate::mission) fn event(
        &mut self,
        w: &mut Context<'_, '_, '_>,
        event: u8,
    ) -> Result<(), &'static str> {
        let now = w.state.field.now;
        let foe = self.foe();
        let enemy = -1 - i32::from(foe);
        match (self.kind, event) {
            (_, 0) => {}
            (Kind::Bridgehead, 1) => {
                self.radio(w, "Overlord: Village is clear. Push on to the bridge, they're wiring it now.", Some(self.p("c")));
                self.start(w, "bridge", 2);
            }

            (Kind::Bridgehead, 2) => {
                let e = self.p("e");
                let n = self.p("n");
                let east = self.p("east");
                let fv = self.p("fv");
                self.radio(w, concat!("Overlord: Bridge is ours. Enemy column forming up across the river. Dig in ", "on this bank: the tanks are two minutes out."), Some(self.p("c")));
                self.start(w, "hold", 3);
                self.enemy_squad(w, "fighter_cell", fv, Action::Assault { position: east + e * 10., face: e })?;
                self.enemy_squad(w, "rpg_team", fv - e * 8. + n * 6., Action::Assault { position: east + e * 6., face: e })?;
                self.after(now, 40., 5);
                if self.places.contains_key("ford") {
                    self.after(now, 60., 6);
                }
                self.after(now, 80., 7);
                self.after(now, 20., 8);
            }

            (Kind::Bridgehead, 3) => {
                let e = self.p("e");
                let n = self.p("n");
                let east = self.p("east");
                for i in 0..2 {
                    let id = w.vehicle("tank", self.side, -1 - i32::from(self.side), w.walk(east + e * (170. + i as f32 * 16.) + n * (i as f32 * 6. - 3.)), yaw_of(-e), false)?;
                    w.vehicle_order(id, Action::Assault { position: east + e * (14. + i as f32 * 8.), face: Vector3::ZERO })?;
                }

                self.radio(w, "Lancer 6: Tanks on the bridge. Good work, we have it from here.", None);
                self.after(now, 6., 4);
            }

            (Kind::Bridgehead, 4) => self.finish(w, true, "The bridge is ours, intact, and the armour is across."),
            (Kind::Bridgehead, 5) => {
                let e = self.p("e");
                let id = w.vehicle("btr", foe, enemy, w.walk(self.p("fv") - e * 20.), yaw_of(e), true)?;
                w.vehicle_order(id, Action::Assault { position: self.p("east") + e * 20., face: Vector3::ZERO })?;
                self.radio(w, "Overlord: BTR heading for the bridge. Get your AT up.", Some(self.p("west")));
            }

            (Kind::Bridgehead, 6) => {
                let ford = *self.places.get("ford").ok_or("missing mission ford")?;
                let e = self.p("e");
                self.enemy_squad(w, "fighter_cell", ford - e * 40., Action::Assault { position: self.p("east") + e * 12., face: e })?;
                self.radio(w, "Overlord: Movement at the ford. They're coming round your flank.", Some(ford));
            }

            (Kind::Bridgehead, 7) => self.enemy_support(w, "mortars", self.p("east") + self.p("e") * 10.)?,
            (Kind::Bridgehead, 8) => {
                let e = self.p("e");
                let n = self.p("n");
                let start = self.p("nv") + e * 120.;
                let east = self.p("east");
                for (kind, p, dest) in [("rifle_squad", start + n * 6., east + e * 14. + n * 8.), ("at_team", start - n * 6., east + e * 12. - n * 8.)] {
                    let q = self.ours_squad(w, kind, p, None)?;
                    w.squad_order(q, Action::Move { position: dest, face: -e, mode: 2 })?;
                }

                self.radio(w, "2nd Platoon: Sending you a squad and an AT team up the lane. Hold on.", Some(start));
            }

            (Kind::Beachhead, 9) => {
                let ids = self.groups.get("enemy_boats").cloned().unwrap_or_default();
                for (i, id) in ids.into_iter().enumerate() {
                    if alive(w.state, id) {
                        w.vehicle_order(
                            id,
                            Action::Assault {
                                position: self.p("sea0") + if i == 0 { Vector3::new(-20., 0., -90.) } else { Vector3::new(-10., 0., -70.) },
                                face: Vector3::ZERO,
                            },
                        )?;
                    }
                }

                self.radio(w, "Neptune: Two enemy boats coming out of the harbour. Engaging.", Some(self.p("h") + Vector3::X * 40.));
            }

            (Kind::Beachhead, 10) => {
                self.radio(w, concat!("Overlord: Feet dry. The AA guns are just inland of the harbour. Bring the ", "patrol ship in close: once they're spotted its guns can reach them from ", "the water."), Some(self.p("h") - Vector3::X * 28.));
                self.start(w, "aa", 11);
            }

            (Kind::Beachhead, 11) => {
                let h = self.p("h");
                let beach = self.p("beach");
                let hx = w.state.water.side as f32 * 0.5 - 12.;
                self.radio(w, concat!("Overlord: AA is down! Blackfoot and a Ghost Hawk with reinforcements ", "inbound from the sea. A-10 on call."), Some(h));
                self.grant(w, &["a10"], 300.)?;
                let gs = w.vehicle("blackfoot", self.side, -1 - i32::from(self.side), Vector3::new(hx, 0., h.z + 60.), std::f64::consts::FRAC_PI_2, false)?;
                w.vehicle_order(gs, Action::Move { position: h - Vector3::X * 30., face: Vector3::ZERO, mode: 0 })?;
                let owner = self.owner();
                let gh = w.vehicle("ghosthawk", self.side, owner, Vector3::new(hx, 0., beach.z + 30.), std::f64::consts::FRAC_PI_2, true)?;
                w.vehicle_order(
                    gh,
                    Action::Move {
                        position: beach + Vector3::new(-30., 0., -10.),
                        face: Vector3::ZERO,
                        mode: 0,
                    },
                )?;
                self.start(w, "harbour", 12);
                self.after(now, 20., 15);
                self.after(now, 55., 16);
            }

            (Kind::Beachhead, 12) => {
                self.radio(w, "Overlord: Harbour's clear. Landing craft are ninety seconds out: hold the quay till they're in.", Some(self.p("h")));
                self.start(w, "hold", 13);
            }

            (Kind::Beachhead, 13) => self.finish(w, true, "The harbour is ours, and the battalion is coming ashore."),
            (Kind::Beachhead, 14) => self.radio(w, "Neptune: Enemy boats are on the bottom. Coast is clear.", None),
            (Kind::Beachhead, 15) => {
                let h = self.p("h");
                let src = w.walk(h - Vector3::X * 190.);
                for i in 0..2 {
                    let id = w.vehicle("technical", foe, enemy, w.walk(src + Vector3::Z * (i as f32 * 12. - 6.)), yaw_of(Vector3::X), false)?;
                    w.vehicle_order(
                        id,
                        Action::Assault {
                            position: h - Vector3::X * 10. + Vector3::Z * (i as f32 * 10. - 5.),
                            face: Vector3::ZERO,
                        },
                    )?;
                }

                self.enemy_squad(w, "fighter_cell", src - Vector3::X * 10., Action::Assault { position: h - Vector3::X * 8., face: Vector3::X })?;
                self.radio(w, "Overlord: Two technicals and a cell coming down the road from the town to the harbour.", Some(src));
            }

            (Kind::Beachhead, 16) => {
                let h = self.p("h");
                let src = w.walk(h - Vector3::X * 190.);
                self.enemy_squad(w, "fighter_cell", src + Vector3::Z * 30., Action::Assault { position: h + Vector3::new(-14., 0., 20.), face: Vector3::X })?;
            }

            (Kind::Skyhook, 17) => self.radio(w, "Overlord: Kilo, help is on the way by air. Mohawk, hook that Nyx and get it over the river.", Some(self.p("pad"))),
            (Kind::Skyhook, 18) => self.radio(w, "Kilo: Nyx is on the ground. Thanks for the lift.", Some(self.p("op"))),
            (Kind::Skyhook, 19 | 20) => {
                let c0 = self.p("c0");
                let op = self.p("op");
                let mut column = vec![];
                if event == 19 {
                    let id = w.vehicle("technical", foe, enemy, w.walk(c0), yaw_of(Vector3::Z), false)?;
                    w.vehicle_order(id, Action::Assault { position: op - Vector3::Z * 20., face: Vector3::ZERO })?;
                    column.push(id);
                    self.enemy_squad(w, "fighter_cell", c0 - Vector3::Z * 16., Action::Assault { position: op - Vector3::Z * 14., face: Vector3::Z })?;
                    self.radio(w, "Kilo: Contact north! A technical and infantry coming down the road. Armour behind them.", Some(c0));
                    self.start(w, "column", 21);
                } else {
                    for (offset, ahead) in [(Vector3::new(-8., 0., -10.), 24.), (Vector3::new(10., 0., -24.), 30.)] {
                        let id = w.vehicle("btr", foe, enemy, w.walk(c0 + offset), yaw_of(Vector3::Z), false)?;
                        w.vehicle_order(id, Action::Assault { position: op - Vector3::Z * ahead, face: Vector3::ZERO })?;
                        column.push(id);
                    }

                    self.radio(w, "Kilo: Two BTRs behind them! Where's that Nyx?", Some(c0));
                }

                self.objectives.iter_mut().find(|o| o.id == "column").ok_or("missing column objective")?.entities.extend(column);
            }

            (Kind::Skyhook, 21) => self.finish(w, true, "The column is burning on the road north of Kilo. The outpost holds."),
            (Kind::Ambush, 22) => self.radio(w, "Cell leader: In position. Wait for it... let the lead car into the bend.", None),
            (Kind::Ambush, 23) => {
                let first = self.route[0];
                let fwd = normalized(flat(self.route[4.min(self.route.len() - 1)] - first));
                let mut convoy = vec![];
                for (i, kind) in ["hunter_hmg", "hemtt", "humvee", "marshall"].into_iter().enumerate() {
                    convoy.push(w.vehicle(kind, foe, enemy, w.walk(first - fwd * (i as f32 * 16.)), yaw_of(fwd), true)?);
                }

                self.groups.insert("convoy".into(), convoy.clone());
                self.objectives.iter_mut().find(|o| o.id == "convoy").ok_or("missing convoy objective")?.entities = convoy;
                self.radio(w, "Lookout: They're moving! Four vehicles, a Hunter in front.", Some(first));
                self.start(w, "convoy", 24);
                self.convoy(w)?;
                self.after(now, 45., 26);
            }

            (Kind::Ambush, 24) => {
                self.radio(w, "Cell leader: That's enough, they'll have called it in. Back to the rally point, move!", Some(self.p("rp")));
                self.deadline = now + 150.;
                self.deadline_text = "The reaction force has cut you off.".into();
                self.start(w, "exfil", 25);
            }

            (Kind::Ambush, 25) => self.finish(w, true, "The convoy is burning and the cell has melted away into the dusk."),
            (Kind::Ambush, 26) => {
                let kz = self.p("kz");
                let t = self.p("t");
                let n = self.p("n");
                let ap = self.p("ap");
                let half = w.state.water.side as f32 * 0.5;
                let qrf = w.vehicle("hunter_hmg", foe, enemy, w.walk(kz - t * 220. - n * 10.), yaw_of(t), true)?;
                w.vehicle_order(qrf, Action::Assault { position: ap, face: Vector3::ZERO })?;
                let heli = w.vehicle("pawnee", foe, enemy, Vector3::new(kz.x.clamp(-half + 20., half - 20.), 0., half - 30.), 0., false)?;
                w.vehicle_order(heli, Action::Move { position: ap, face: Vector3::ZERO, mode: 0 })?;
                self.radio(w, "Lookout: Helicopter coming up from the south, and a Hunter on the main road. QRF!", Some(kz));
            }

            (Kind::Ambush, 27) => self.convoy(w)?,
            (Kind::Kingpin, 28) => self.radio(w, "Overlord: Greyhawk is on station over the town. Call it in if you need it.", None),
            (Kind::Kingpin, 29) => {
                self.radio(w, "Overlord: Checkpoint down. The house is seventy metres up the street, doors barred. Breach it.", Some(self.p("hv")));
                self.start(w, "hvt", 30);
            }

            (Kind::Kingpin, 30) => {
                self.radio(w, "Overlord: Jackpot, Kassem is down. The whole town is waking up: get back to the Hunters, now!", Some(self.p("start")));
                self.deadline = now + 150.;
                self.deadline_text = "The Rebels have cut the road out of town.".into();
                self.start(w, "exfil", 31);
                for i in 0..2 {
                    self.enemy_squad(
                        w,
                        "fighter_cell",
                        self.p("hv") - Vector3::Z * 90. + Vector3::X * (i as f32 * 30. - 15.),
                        Action::Assault {
                            position: self.p("cp") + Vector3::X * (i as f32 * 14. - 7.),
                            face: Vector3::Z,
                        },
                    )?;
                }
                self.after(now, 25., 32);
            }

            (Kind::Kingpin, 31) => self.finish(w, true, "Kassem is off the board and the raid is out of the town."),
            (Kind::Kingpin, 32) => {
                for i in 0..2 {
                    let id = w.vehicle("technical", foe, enemy, w.walk(self.p("hv") - Vector3::Z * 140. + Vector3::X * (i as f32 * 14.)), yaw_of(Vector3::Z), false)?;
                    w.vehicle_order(id, Action::Assault { position: self.p("start") + Vector3::Z * 30., face: Vector3::ZERO })?;
                }
            }

            _ => return Err("event does not belong to this mission"),
        }

        Ok(())
    }

    fn convoy(&mut self, w: &mut Context<'_, '_, '_>) -> Result<(), &'static str> {
        let convoy = self.groups.get("convoy").cloned().unwrap_or_default();
        let mut escaped = 0;
        if convoy.len() > self.waypoints.len() || self.route.len() < 2 {
            return Err("invalid convoy route");
        }

        for (i, &id) in convoy.iter().enumerate() {
            if !alive(w.state, id) {
                continue;
            }

            let v = w
                .state
                .field
                .actors
                .vehicle(id)
                .ok_or("invalid convoy vehicle")?;
            let at = v.position;
            let empty = v.path.is_empty();
            let mut wi = (self.waypoints[i] as usize).min(self.route.len() - 1);
            if wi >= self.route.len() - 1 && distance(at, *self.route.last().unwrap()) < 14. {
                escaped += 1;
                continue;
            }

            if i > 0
                && alive(w.state, convoy[i - 1])
                && position(w.state, convoy[i - 1]).is_some_and(|p| distance(p, at) < 12.)
                && wi > 2
            {
                continue;
            }

            if distance(at, self.route[wi]) < 10.
                || empty
                || self.once(w.state.field.now, format!("cv{i}"), &format!("wp{wi}"), 0.)
            {
                while wi < self.route.len() - 1 && distance(at, self.route[wi]) < 12. {
                    wi += 1;
                }

                self.waypoints[i] = wi as u32;
                let target = self.route[(wi + 6).min(self.route.len() - 1)];
                w.vehicle_order(
                    id,
                    Action::Move {
                        position: target,
                        face: Vector3::ZERO,
                        mode: 0,
                    },
                )?;
            }
        }

        if escaped >= 2 {
            self.finish(w, false, "The convoy got through.");
        } else {
            self.after(w.state.field.now, 1.5, 27);
        }

        Ok(())
    }
}
