//! Validated commander checkpoints.
use super::*;
use sim::state_codec::{Reader, Writer};

impl Commander {
    pub fn checkpoint(&self) -> Result<Vec<u8>, &'static str> {
        if !(0..=1).contains(&self.team)
            || self.phase > 3
            || self.next_tick > i64::MAX as u64
            || self.support_cursor > 100_000
            || self.roles.len() > 100_000
            || self.helped.len() > 100_000
            || self.next_vehicle.len() > 128
            || self.next_vehicle.contains('\0')
        {
            return Err("invalid commander state");
        }
        let mut w = Writer::new(b"FLCA\x01\0\0\0");
        w.byte(self.team as u8);
        w.byte(u8::from(self.permanent));
        w.u64(self.rng.seed());
        w.u64(self.rng.state());
        w.u64(self.next_tick);
        w.byte(self.phase);
        w.u32(self.attack_target);
        w.u32(self.support_cursor as u32);
        w.bytes(self.next_vehicle.as_bytes());
        for t in [
            self.last_wave,
            self.expand_at,
            self.defense_at,
            self.obstacle_at,
            self.recon_at,
            self.town_at,
            self.outpost_at,
            self.back_at,
            self.ambush_at,
        ] {
            if !clock(t) {
                return Err("invalid commander clock");
            }
            w.f64(t);
        }
        w.u32(self.roles.len() as u32);
        for (&id, r) in &self.roles {
            if id == 0
                || !matches!(
                    r.kind.as_str(),
                    "idle"
                        | "attack"
                        | "retreat"
                        | "defend"
                        | "garrison"
                        | "outpost"
                        | "town"
                        | "tunnel"
                        | "raid"
                        | "ambush"
                )
                || !clock(r.since)
                || !point(r.position)
                || r.held.is_some_and(|t| !clock(t))
            {
                return Err("invalid commander role");
            }
            w.u32(id);
            w.bytes(r.kind.as_bytes());
            w.f64(r.since);
            w.u32(r.target);
            w.point(r.position);
            w.byte(u8::from(r.held.is_some()));
            if let Some(t) = r.held {
                w.f64(t);
            }
            w.u32(r.exit);
            w.byte(u8::from(r.sent));
        }
        w.u32(self.helped.len() as u32);
        for (&id, &t) in &self.helped {
            if id == 0 || !clock(t) {
                return Err("invalid reinforcement clock");
            }
            w.u32(id);
            w.f64(t);
        }
        self.write_naval(&mut w)?;
        Ok(w.0)
    }
    pub fn restore(bytes: &[u8]) -> Result<Self, &'static str> {
        let mut r = Reader::new(bytes, b"FLCA\x01\0\0\0")?;
        let team = r.byte()? as i8;
        let permanent = r.boolean()?;
        let seed = r.u64()?;
        let mut c = Self::new(team, 0, 0)?;
        c.permanent = permanent;
        c.rng = SimulationRandom::new(seed);
        c.rng.set_state(r.u64()?);
        c.next_tick = r.u64()?;
        c.phase = r.byte()?;
        c.attack_target = r.u32()?;
        c.support_cursor = r.u32()? as usize;
        c.next_vehicle =
            String::from_utf8(r.bytes(128)?.to_vec()).map_err(|_| "invalid vehicle key")?;
        c.last_wave = r.f64()?;
        c.expand_at = r.f64()?;
        c.defense_at = r.f64()?;
        c.obstacle_at = r.f64()?;
        c.recon_at = r.f64()?;
        c.town_at = r.f64()?;
        c.outpost_at = r.f64()?;
        c.back_at = r.f64()?;
        c.ambush_at = r.f64()?;
        let n = r.u32()?;
        if n > 100_000 {
            return Err("commander role limit exceeded");
        }
        for _ in 0..n {
            let id = r.u32()?;
            let role = Role {
                kind: String::from_utf8(r.bytes(32)?.to_vec()).map_err(|_| "invalid role")?,
                since: r.f64()?,
                target: r.u32()?,
                position: r.point()?,
                held: if r.boolean()? { Some(r.f64()?) } else { None },
                exit: r.u32()?,
                sent: r.boolean()?,
            };
            if c.roles.insert(id, role).is_some() {
                return Err("duplicate commander role");
            }
        }
        let n = r.u32()?;
        if n > 100_000 {
            return Err("commander reinforcement limit exceeded");
        }
        for _ in 0..n {
            if c.helped.insert(r.u32()?, r.f64()?).is_some() {
                return Err("duplicate reinforcement");
            }
        }
        c.read_naval(&mut r)?;
        r.finish()?;
        if c.checkpoint()? != bytes {
            return Err("noncanonical commander checkpoint");
        }
        Ok(c)
    }
}
