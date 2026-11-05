use super::*;
use sim::vector::yaw_of;
mod drive;
mod events;
mod setup;

fn nearest(points: impl IntoIterator<Item = Vector3>, at: Vector3) -> Option<Vector3> {
    points
        .into_iter()
        .min_by(|a, b| distance(*a, at).total_cmp(&distance(*b, at)))
}
fn houses(state: &MatchState, at: Vector3, radius: f32) -> Vec<Vector3> {
    let roofs: Vec<_> = state
        .field
        .actors
        .iter()
        .filter_map(|a| match a {
            Actor::Structure(s) if s.kind == "roof" => Some(s.position),
            _ => None,
        })
        .collect();
    let mut floors: Vec<_> = state
        .field
        .actors
        .iter()
        .filter_map(|a| match a {
            Actor::Structure(s)
                if s.kind == "floor"
                    && distance(s.position, at) < radius
                    && roofs.iter().any(|p| {
                        ((p.x * 4.).round(), (p.z * 4.).round())
                            == ((s.position.x * 4.).round(), (s.position.z * 4.).round())
                    }) =>
            {
                Some(s.position)
            }
            _ => None,
        })
        .collect();
    floors.sort_by(|a, b| distance(*a, at).total_cmp(&distance(*b, at)));
    floors
}
fn road_near(state: &MatchState, at: Vector3, skip: &[Vector3]) -> Vec<Vector3> {
    state.rules.network.roads[2]
        .iter()
        .filter(|r| r.len() >= 2 && r.as_slice() != skip)
        .min_by(|a, b| {
            let score = |r: &Vec<Vector3>| {
                r.iter()
                    .map(|p| distance(*p, at))
                    .fold(f32::INFINITY, f32::min)
            };
            score(a).total_cmp(&score(b))
        })
        .cloned()
        .unwrap_or_default()
}
fn resample(line: &[Vector3], step: f32) -> Vec<Vector3> {
    let Some(&first) = line.first() else {
        return vec![];
    };
    let mut out = vec![first];
    let mut carry = 0.;
    for pair in line.windows(2) {
        let length = distance(pair[0], pair[1]);
        let mut t = step - carry;
        while t <= length {
            out.push(pair[0] + (pair[1] - pair[0]) * (t / length.max(0.001)));
            t += step;
        }
        carry = length - (t - step);
    }
    if let Some(&p) = line.last() {
        if distance(*out.last().unwrap(), p) > step * 0.4 {
            out.push(p);
        }
    }
    out
}
impl Context<'_, '_, '_> {
    fn boat(&self, p: Vector3) -> Vector3 {
        self.state.boats.nearest(p, 300., -1).unwrap_or(p)
    }
    fn building(
        &mut self,
        kind: &str,
        p: Vector3,
        yaw: f64,
        team: i8,
        free: bool,
    ) -> Result<Option<u32>, &'static str> {
        let mut s = sim::structure::Structure {
            kind: kind.into(),
            position: p,
            yaw,
            team,
            built: true,
            ..Default::default()
        };
        s.position.y += self.state.field.geometry.terrain.landform.height(p) as f32;
        let profile = self.content.building(kind).map(|d| d.body);
        if free {
            let g = &self.state.field.geometry;
            let half = (g.terrain.n as f32) * 0.5;
            if p.x.abs() > half - 6. || p.z.abs() > half - 6. || g.terrain.too_deep(p, &g.deck) {
                return Ok(None);
            }
            s.id = u32::try_from(self.state.field.actors.entities().next_id())
                .map_err(|_| "mission entity registry exhausted")?;
            s.initialize(profile, f64::from(half))?;
            if !g.terrain.landform.fits(p, s.footprint.into(), yaw, 0.35) || self.state.field.actors.iter().any(|a| matches!(a,Actor::Structure(other) if sim::vehicle_movement_world::overlaps(p,s.footprint.into(),yaw,other,-0.3))) {
                return Ok(None);
            }
            // Spawn initializes geometry once; the probe is only for footprint clearance.
            s = sim::structure::Structure {
                kind: kind.into(),
                position: s.position,
                yaw,
                team,
                built: true,
                ..Default::default()
            };
        }
        let f = &mut self.state.field;
        Ok(Some(f.geometry.spawn_structure(
            &mut f.actors,
            s,
            profile,
        )?))
    }
    fn infantry(
        &mut self,
        unit: &str,
        team: i8,
        owner: i32,
        p: Vector3,
        squad: u32,
        name: &str,
    ) -> Result<u32, &'static str> {
        let p = self.walk(p);
        let f = &mut self.state.field;
        let id = f.actors.spawn_infantry(
            sim::infantry_spawn::Spawn {
                team,
                owner,
                position: p,
                yaw: 0.,
                name: name.into(),
                squad,
                life: Life::Alive,
                posture: sim::infantry_pose::Posture::Stand,
                armor_upgrade: false,
                grenade_upgrade: false,
            },
            self.content
                .loadouts()
                .get(unit)
                .ok_or("unknown mission soldier")?,
            &mut f.rng,
        )?;
        if squad != 0 {
            f.squads
                .iter_mut()
                .find(|q| q.id == squad)
                .ok_or("missing mission squad")?
                .members
                .push(id);
        }
        Ok(id)
    }
}
impl Mission {
    pub fn setup(
        &mut self,
        state: &mut MatchState,
        content: &Content,
        shared: &Shared<'_>,
        profiles: &Profiles<'_>,
        host: i32,
        landmarks: &[Landmark],
    ) -> Result<Vec<Event>, &'static str> {
        if !self.objectives.is_empty() || state.victory.winner >= 0 {
            return Err("mission already started");
        }
        let mut events = vec![];
        let mut w = Context {
            state,
            content,
            shared,
            profiles,
            host,
            events: &mut events,
        };
        w.state.victory.mission = true;
        let fobs: Vec<_> = sim::economy::fobs(&w.state.field.actors, self.side, false)
            .map(|s| s.id)
            .collect();
        for id in fobs {
            w.state.field.actors.set_structure_supply(id, 0.)?;
        }
        match self.kind {
            Kind::Bridgehead => self.setup_bridge(&mut w, landmarks)?,
            Kind::Beachhead => self.setup_beach(&mut w, landmarks)?,
            Kind::Skyhook => self.setup_skyhook(&mut w, landmarks)?,
            Kind::Ambush => self.setup_ambush(&mut w, landmarks)?,
            Kind::Kingpin => self.setup_kingpin(&mut w, landmarks)?,
        }
        self.census(w.state);
        self.checkpoint()?;
        Ok(events)
    }
    fn places(&mut self, places: &[(&str, Vector3)]) {
        for &(key, p) in places {
            self.places.insert(key.into(), p);
        }
    }
    fn ours_squad(
        &mut self,
        w: &mut Context<'_, '_, '_>,
        kind: &str,
        p: Vector3,
        dest: Option<Vector3>,
    ) -> Result<u32, &'static str> {
        let owner = self.owner();
        w.squad(kind, self.side, owner, p, dest)
    }
    fn enemy_squad(
        &self,
        w: &mut Context<'_, '_, '_>,
        kind: &str,
        p: Vector3,
        order: Action,
    ) -> Result<u32, &'static str> {
        let id = w.squad(kind, self.foe(), -1 - i32::from(self.foe()), p, None)?;
        w.squad_order(id, order)?;
        Ok(id)
    }
    fn grant(
        &mut self,
        w: &mut Context<'_, '_, '_>,
        kinds: &[&str],
        supply: f64,
    ) -> Result<(), &'static str> {
        self.support = kinds.iter().map(|s| (*s).into()).collect();
        for &key in kinds {
            let rows = &mut w.state.rules.support.ready[self.side as usize];
            if let Some(row) = rows.iter_mut().find(|r| r.0 == key) {
                row.1 = 0.;
            } else {
                rows.push((key.into(), 0.));
            }
        }
        let id = sim::economy::fobs(&w.state.field.actors, self.side, false)
            .next()
            .map(|s| s.id);
        if let Some(id) = id {
            w.state.field.actors.set_structure_supply(id, supply)?;
        }
        Ok(())
    }
    fn ready(&self, w: &Context<'_, '_, '_>, kind: &str) -> bool {
        self.support.iter().any(|s| s == kind)
            && w.state.rules.support.ready[self.side as usize]
                .iter()
                .find(|r| r.0 == kind)
                .is_none_or(|r| r.1 <= w.state.field.now)
    }
    fn call(
        &self,
        w: &mut Context<'_, '_, '_>,
        kind: &str,
        p: Vector3,
    ) -> Result<bool, &'static str> {
        if !self.ready(w, kind) {
            return Ok(false);
        }
        let before = w.state.rules.support.ready[self.side as usize].clone();
        w.command(
            self.owners[0],
            vec![],
            vec![],
            Action::Support {
                kind: kind.into(),
                position: p,
                direction: Vector3::ZERO,
            },
        )?;
        Ok(before != w.state.rules.support.ready[self.side as usize])
    }
    fn enemy_support(
        &self,
        w: &mut Context<'_, '_, '_>,
        kind: &str,
        p: Vector3,
    ) -> Result<(), &'static str> {
        let foe = self.foe();
        let rows = &mut w.state.rules.support.ready[foe as usize];
        if let Some(row) = rows.iter_mut().find(|r| r.0 == kind) {
            row.1 = 0.;
        } else {
            rows.push((kind.into(), 0.));
        }
        let fobs: Vec<_> = sim::economy::fobs(&w.state.field.actors, foe, false)
            .map(|s| (s.id, s.supply.max(400.)))
            .collect();
        for (id, supply) in fobs {
            w.state.field.actors.set_structure_supply(id, supply)?;
        }
        w.command(
            -1 - i32::from(foe),
            vec![],
            vec![],
            Action::Support {
                kind: kind.into(),
                position: p,
                direction: Vector3::ZERO,
            },
        )
    }
    fn force(&self, state: &MatchState) -> Vec<u32> {
        state
            .field
            .squads
            .iter()
            .filter(|q| {
                q.team == self.side
                    && self.owners.contains(&q.owner)
                    && q.alive(&state.field.actors).any(|s| s.links.vehicle == 0)
            })
            .map(|q| q.id)
            .collect()
    }
}
