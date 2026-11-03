use super::*;
use sim::state_codec::{Reader, Writer};

fn string(r: &mut Reader<'_>, limit: usize) -> Result<String, &'static str> {
    let s = String::from_utf8(r.bytes(limit)?.to_vec()).map_err(|_| "invalid mission text")?;
    if s.contains('\0') {
        return Err("invalid mission text");
    }
    Ok(s)
}
fn count(r: &mut Reader<'_>, limit: u32) -> Result<u32, &'static str> {
    let n = r.u32()?;
    if n > limit {
        Err("mission collection exceeds limit")
    } else {
        Ok(n)
    }
}
fn ids(w: &mut Writer, values: &[u32]) {
    w.u32(values.len() as u32);
    for &v in values {
        w.u32(v);
    }
}
fn read_ids(r: &mut Reader<'_>, limit: u32) -> Result<Vec<u32>, &'static str> {
    (0..count(r, limit)?).map(|_| r.u32()).collect()
}
fn valid_string(s: &str, limit: usize) -> bool {
    s.len() <= limit && !s.contains('\0')
}
fn valid_point(p: Vector3) -> bool {
    p.is_finite() && p.abs().max_element() <= 1_000_000.
}
fn time(t: f64) -> bool {
    t.is_finite() && t.abs() <= 1e12
}

impl Mission {
    fn valid(&self) -> bool {
        let cue = |n: u8| {
            n == 0
                || match self.kind {
                    Kind::Bridgehead => (1..=8).contains(&n),
                    Kind::Beachhead => (9..=16).contains(&n),
                    Kind::Skyhook => (17..=21).contains(&n),
                    Kind::Ambush => (22..=27).contains(&n),
                    Kind::Kingpin => (28..=32).contains(&n),
                }
        };
        let required: &[&str] = match self.kind {
            Kind::Bridgehead => &["c", "east", "west", "nv", "fv", "e", "n"],
            Kind::Beachhead => &["h", "beach", "sea0"],
            Kind::Skyhook => &["op", "pad", "c", "e", "c0"],
            Kind::Ambush => &["kz", "t", "n", "ap", "rp"],
            Kind::Kingpin => &["hv", "cp", "start", "street"],
        };
        self.side == if self.kind == Kind::Ambush { 1 } else { 0 }
            && (1..=32).contains(&self.owners.len())
            && self
                .owners
                .iter()
                .all(|p| *p > 0 || *p == -1 - i32::from(self.side))
            && self.owners.iter().copied().collect::<BTreeSet<_>>().len() == self.owners.len()
            && self.over <= 2
            && self.flags <= 7
            && valid_string(&self.end_text, 4096)
            && valid_string(&self.deadline_text, 4096)
            && [
                self.start_time,
                self.deadline,
                self.evaluate_timer,
                self.drive_timer,
                self.focus_yaw,
            ]
            .into_iter()
            .all(time)
            && self.start_time >= 0.
            && self.deadline >= 0.
            && valid_point(self.focus)
            && self.objectives.len() <= 26
            && self
                .objectives
                .iter()
                .map(|o| &o.id)
                .collect::<BTreeSet<_>>()
                .len()
                == self.objectives.len()
            && self.objectives.iter().all(|o| {
                !o.id.is_empty()
                    && valid_string(&o.id, 64)
                    && valid_string(&o.text, 4096)
                    && valid_string(&o.failure, 4096)
                    && valid_string(&o.label, 1)
                    && o.state <= 3
                    && cue(o.done)
                    && o.position.is_none_or(valid_point)
                    && [o.radius, o.seconds, o.progress, o.lost, o.grace]
                        .into_iter()
                        .all(|n| time(n) && n >= 0.)
                    && o.radius <= 100_000.
                    && (0. ..=1.).contains(&o.fraction)
                    && o.need >= -1
                    && o.have >= 0
                    && o.entities.len() <= 100_000
                    && o.entities.iter().all(|id| *id != 0)
            })
            && self.events.len() <= 128
            && self
                .events
                .iter()
                .all(|(t, e)| time(*t) && *t >= 0. && cue(*e))
            && self.support.len() <= 64
            && self
                .support
                .iter()
                .all(|s| !s.is_empty() && valid_string(s, 128))
            && self.ours.len() <= 100_000
            && self.theirs.len() <= 100_000
            && self.ours.iter().chain(&self.theirs).all(|id| *id != 0)
            && self.places.len() <= 64
            && required.iter().all(|k| self.places.contains_key(*k))
            && self
                .places
                .iter()
                .all(|(k, p)| !k.is_empty() && valid_string(k, 64) && valid_point(*p))
            && self.groups.len() <= 64
            && self.groups.iter().all(|(k, ids)| {
                !k.is_empty()
                    && valid_string(k, 64)
                    && ids.len() <= 100_000
                    && ids.iter().all(|id| *id != 0)
            })
            && self.route.len() <= 100_000
            && self.route.iter().copied().all(valid_point)
            && self.waypoints.len() <= 16
            && self.waypoints.iter().all(|n| *n <= 100_000)
            && (self.kind != Kind::Ambush || self.route.len() >= 2 && self.waypoints.len() == 4)
            && (self.kind != Kind::Beachhead || self.waypoints.len() == 3)
            && self.staged.len() <= 100_000
            && self
                .staged
                .iter()
                .all(|(k, (s, t))| valid_string(k, 128) && valid_string(s, 128) && time(*t))
    }
    pub fn checkpoint(&self) -> Result<Vec<u8>, &'static str> {
        if !self.valid() {
            return Err("invalid mission state");
        }
        let mut w = Writer::new(b"FLMS\x01\0\0\0");
        w.byte(self.kind as u8);
        w.byte(self.side as u8);
        w.u32(self.owners.len() as u32);
        for &owner in &self.owners {
            w.u32(owner as u32);
        }
        w.byte(self.forced_autopilot.into());
        w.byte(self.autopilot.into());
        w.byte(self.over);
        w.byte(self.flags);
        w.bytes(self.end_text.as_bytes());
        w.bytes(self.deadline_text.as_bytes());
        for t in [
            self.start_time,
            self.deadline,
            self.evaluate_timer,
            self.drive_timer,
            self.focus_yaw,
        ] {
            w.f64(t);
        }
        w.point(self.focus);
        w.u64(self.owner_cursor);
        w.u32(self.objectives.len() as u32);
        for o in &self.objectives {
            for s in [&o.id, &o.text, &o.label, &o.failure] {
                w.bytes(s.as_bytes());
            }
            w.byte(o.goal as u8);
            w.byte(o.state);
            w.byte(o.done);
            w.byte(o.position.is_some().into());
            if let Some(p) = o.position {
                w.point(p);
            }
            for t in [o.radius, o.seconds, o.progress, o.lost, o.grace, o.fraction] {
                w.f64(t);
            }
            w.u32(o.need as u32);
            w.u32(o.have as u32);
            ids(&mut w, &o.entities);
            for b in [o.optional, o.track, o.afoot, o.mark] {
                w.byte(b.into());
            }
        }
        w.u32(self.events.len() as u32);
        for &(t, event) in &self.events {
            w.f64(t);
            w.byte(event);
        }
        w.u32(self.support.len() as u32);
        for s in &self.support {
            w.bytes(s.as_bytes());
        }
        for set in [&self.ours, &self.theirs] {
            w.u32(set.len() as u32);
            for &id in set {
                w.u32(id);
            }
        }
        w.u32(self.places.len() as u32);
        for (key, p) in &self.places {
            w.bytes(key.as_bytes());
            w.point(*p);
        }
        w.u32(self.groups.len() as u32);
        for (key, values) in &self.groups {
            w.bytes(key.as_bytes());
            ids(&mut w, values);
        }
        w.u32(self.route.len() as u32);
        for &p in &self.route {
            w.point(p);
        }
        ids(&mut w, &self.waypoints);
        w.u32(self.staged.len() as u32);
        for (key, (stage, t)) in &self.staged {
            w.bytes(key.as_bytes());
            w.bytes(stage.as_bytes());
            w.f64(*t);
        }
        if w.0.len() > 16 * 1024 * 1024 {
            return Err("mission state exceeds limit");
        }
        Ok(w.0)
    }
    pub fn restore(bytes: &[u8]) -> Result<Self, &'static str> {
        if bytes.len() > 16 * 1024 * 1024 {
            return Err("mission state exceeds limit");
        }
        let mut r = Reader::new(bytes, b"FLMS\x01\0\0\0")?;
        let kind = *[
            Kind::Bridgehead,
            Kind::Beachhead,
            Kind::Skyhook,
            Kind::Ambush,
            Kind::Kingpin,
        ]
        .get(r.byte()? as usize)
        .ok_or("unknown mission")?;
        let side = r.byte()? as i8;
        let owners = (0..count(&mut r, 32)?)
            .map(|_| r.u32().map(|n| n as i32))
            .collect::<Result<_, _>>()?;
        let forced_autopilot = r.boolean()?;
        let autopilot = r.boolean()?;
        let over = r.byte()?;
        let flags = r.byte()?;
        let end_text = string(&mut r, 4096)?;
        let deadline_text = string(&mut r, 4096)?;
        let start_time = r.f64()?;
        let deadline = r.f64()?;
        let evaluate_timer = r.f64()?;
        let drive_timer = r.f64()?;
        let focus_yaw = r.f64()?;
        let focus = r.point()?;
        let owner_cursor = r.u64()?;
        let mut objectives = vec![];
        for _ in 0..count(&mut r, 26)? {
            let id = string(&mut r, 64)?;
            let text = string(&mut r, 4096)?;
            let label = string(&mut r, 1)?;
            let failure = string(&mut r, 4096)?;
            let goal = *[
                Goal::Reach,
                Goal::Clear,
                Goal::Hold,
                Goal::Guard,
                Goal::Destroy,
                Goal::Protect,
                Goal::Timer,
                Goal::Deliver,
                Goal::Extract,
            ]
            .get(r.byte()? as usize)
            .ok_or("unknown mission goal")?;
            let state = r.byte()?;
            let done = r.byte()?;
            let position = if r.boolean()? { Some(r.point()?) } else { None };
            let radius = r.f64()?;
            let seconds = r.f64()?;
            let progress = r.f64()?;
            let lost = r.f64()?;
            let grace = r.f64()?;
            let fraction = r.f64()?;
            let need = r.u32()? as i32;
            let have = r.u32()? as i32;
            let entities = read_ids(&mut r, 100_000)?;
            let optional = r.boolean()?;
            let track = r.boolean()?;
            let afoot = r.boolean()?;
            let mark = r.boolean()?;
            objectives.push(Objective {
                id,
                text,
                label,
                failure,
                goal,
                state,
                done,
                position,
                radius,
                seconds,
                progress,
                lost,
                grace,
                fraction,
                need,
                have,
                entities,
                optional,
                track,
                afoot,
                mark,
            });
        }
        let mut events = vec![];
        for _ in 0..count(&mut r, 128)? {
            events.push((r.f64()?, r.byte()?));
        }
        let mut support = vec![];
        for _ in 0..count(&mut r, 64)? {
            support.push(string(&mut r, 128)?);
        }
        let ours = read_ids(&mut r, 100_000)?.into_iter().collect();
        let theirs = read_ids(&mut r, 100_000)?.into_iter().collect();
        let mut places = BTreeMap::new();
        for _ in 0..count(&mut r, 64)? {
            let k = string(&mut r, 64)?;
            let p = r.point()?;
            if places.insert(k, p).is_some() {
                return Err("duplicate mission place");
            }
        }
        let mut groups = BTreeMap::new();
        for _ in 0..count(&mut r, 64)? {
            let k = string(&mut r, 64)?;
            let v = read_ids(&mut r, 100_000)?;
            if groups.insert(k, v).is_some() {
                return Err("duplicate mission group");
            }
        }
        let route = (0..count(&mut r, 100_000)?)
            .map(|_| r.point())
            .collect::<Result<_, _>>()?;
        let waypoints = read_ids(&mut r, 16)?;
        let mut staged = BTreeMap::new();
        for _ in 0..count(&mut r, 100_000)? {
            let k = string(&mut r, 128)?;
            let s = string(&mut r, 128)?;
            let t = r.f64()?;
            if staged.insert(k, (s, t)).is_some() {
                return Err("duplicate mission stage");
            }
        }
        r.finish()?;
        let result = Self {
            kind,
            side,
            owners,
            forced_autopilot,
            autopilot,
            objectives,
            over,
            end_text,
            start_time,
            deadline,
            deadline_text,
            support,
            focus,
            focus_yaw,
            events,
            evaluate_timer,
            drive_timer,
            owner_cursor,
            ours,
            theirs,
            places,
            groups,
            route,
            waypoints,
            staged,
            flags,
        };
        if result.checkpoint()? != bytes {
            return Err("noncanonical mission state");
        }
        Ok(result)
    }
}
