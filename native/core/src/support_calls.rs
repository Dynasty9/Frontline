//! Paid sorties and delayed salvos share the match clock, random stream and actor identities.
use crate::actors::{Actor, Actors};
use crate::battle_stats::{self, BattleStats};
use crate::economy;
use crate::projectile::Kind;
use crate::projectile_actor::{ballistic, Motion, Projectile};
use crate::random::SimulationRandom;
use crate::state_codec::{Reader, Writer};
use crate::support::{Gunset, Kind as FlightKind, SupportFlight};
use crate::vector::{normalized, Vector3};
use std::collections::HashSet;

const LIMIT: usize = 100_000;
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Sortie {
    Recon,
    Watch,
    Jet,
    GunRun,
    Orbit,
    Artillery,
    Barrage,
    Mortars,
    Smoke,
}
pub struct Definition<'a> {
    pub key: &'a str,
    pub name: &'a str,
    pub model: &'a str,
    pub team: i8,
    pub cost: i32,
    pub from: f64,
    pub cooldown: f64,
    pub radius: f64,
    pub sortie: Sortie,
    pub quiet: bool,
    pub leg: f64,
    pub altitude: f64,
    pub speed: f64,
    pub sight: f64,
    pub stay: f64,
    pub bombs: u32,
    pub guns: Gunset,
    pub muzzles: [Vector3; 3],
}
#[derive(Clone, Debug, PartialEq)]
pub struct Salvo {
    pub at: f64,
    pub kind: Kind,
    pub team: i8,
    pub position: Vector3,
    pub radius: f64,
    pub back: Vector3,
    pub called_by: i32,
}
#[derive(Clone, Debug, Default, PartialEq)]
pub struct SupportCalls {
    pub ready: [Vec<(String, f64)>; 2],
    pub queue: Vec<Salvo>,
}
#[derive(Clone, Debug, PartialEq)]
pub enum Event {
    Warn {
        peer: i32,
        text: String,
    },
    Mark {
        position: Vector3,
        radius: f64,
    },
    Stat(String),
    Born {
        id: u32,
        model: String,
    },
    Message {
        team: i8,
        alert: bool,
        text: String,
        position: Vector3,
    },
    Sound {
        name: &'static str,
        position: Vector3,
    },
}
fn text(s: &str, limit: usize) -> bool {
    s.len() <= limit && !s.contains('\0')
}
fn point(p: Vector3) -> bool {
    p.is_finite() && p.abs().max_element() <= 1_000_000.
}
fn clock(t: f64) -> bool {
    t.is_finite() && (0.0..=1e12 - 100_000.).contains(&t)
}
fn flat(p: Vector3) -> Vector3 {
    Vector3::new(p.x, 0., p.z)
}
impl Definition<'_> {
    pub fn valid(&self) -> bool {
        !self.key.is_empty()
            && text(self.key, 128)
            && text(self.name, 4096)
            && text(self.model, 128)
            && (-1..=1).contains(&self.team)
            && (0..=1_000_000).contains(&self.cost)
            && [
                self.from,
                self.cooldown,
                self.radius,
                self.leg,
                self.altitude,
                self.speed,
                self.sight,
                self.stay,
            ]
            .into_iter()
            .all(|n| n.is_finite() && (0.0..=100_000.).contains(&n))
            && self.bombs <= 4096
            && self.muzzles.into_iter().all(point)
    }
}
impl SupportCalls {
    pub fn valid(&self) -> bool {
        self.queue.len() <= LIMIT
            && self.queue.iter().all(|q| {
                clock(q.at)
                    && matches!(
                        q.kind,
                        Kind::Arty | Kind::Grad | Kind::Mortar | Kind::MortarSmoke
                    )
                    && (-1..=1).contains(&q.team)
                    && q.called_by >= -2
                    && point(q.position)
                    && q.position.abs().max_element() <= 800_000.
                    && point(q.back)
                    && q.back.abs().max_element() <= 100_000.
                    && q.radius.is_finite()
                    && (0.0..=100_000.).contains(&q.radius)
            })
            && self.ready.iter().all(|side| {
                side.len() <= LIMIT
                    && side
                        .iter()
                        .all(|(k, t)| !k.is_empty() && text(k, 128) && clock(*t))
                    && side.iter().map(|(k, _)| k).collect::<HashSet<_>>().len() == side.len()
            })
    }
    pub fn left(&self, team: i8, p: &Definition<'_>, now: f64) -> Option<f64> {
        self.ready.get(team as usize).map(|side| {
            side.iter()
                .find(|(key, _)| key == p.key)
                .map_or(p.from, |(_, at)| *at)
                - now
        })
    }
    fn preflight(
        &self,
        actors: &Actors,
        p: &Definition<'_>,
        now: f64,
        at: Vector3,
        dir: Vector3,
        map_side: u32,
    ) -> Result<(), &'static str> {
        if !self.valid()
            || !p.valid()
            || !clock(now)
            || now > 1e12 - 200_000.
            || !point(at)
            || at.abs().max_element() > 800_000.
            || !point(dir)
            || !(8..=16384).contains(&map_side)
            || self.queue.len() > LIMIT - 16
            || self.ready.iter().any(|s| s.len() >= LIMIT)
            || actors.entities().len() >= crate::entities::MAX_ENTITIES
            || actors.entities().next_id() > u64::from(u32::MAX)
        {
            return Err("invalid support request");
        }
        Ok(())
    }
    pub fn call(
        &mut self,
        actors: &mut Actors,
        battle: &mut BattleStats,
        rng: &mut SimulationRandom,
        now: f64,
        peer: i32,
        team: i8,
        at: Vector3,
        dir: Vector3,
        p: &Definition<'_>,
        map_side: u32,
    ) -> Result<(bool, Vec<Event>), &'static str> {
        self.preflight(actors, p, now, at, dir, map_side)?;
        if peer < -2 {
            return Err("invalid support commander");
        }
        if !(0..=1).contains(&team) || p.team != team {
            return Ok((false, vec![]));
        }
        let left = self.left(team, p, now).unwrap();
        let warn = |text| {
            if peer > 0 {
                vec![Event::Warn { peer, text }]
            } else {
                vec![]
            }
        };
        if left > 0. {
            return Ok((
                false,
                warn(format!("{} not ready yet ({}s).", p.name, left as i64)),
            ));
        }
        for (field, amount) in [(14, f64::from(p.cost)), (19, 1.)] {
            let player = battle
                .players
                .iter()
                .find(|p| p.owner == peer)
                .map_or(0., |p| p.counters[field]);
            if [battle.sides[team as usize][field] + amount, player + amount]
                .into_iter()
                .any(|v| !v.is_finite() || v.abs() > 1e15)
            {
                return Err("support battle credit overflow");
            }
        }
        if !economy::spend(actors, team, at, p.cost)? {
            return Ok((
                false,
                warn(format!(
                    "Not enough supply for the {} ({}).",
                    p.name.to_lowercase(),
                    p.cost
                )),
            ));
        }
        let side = &mut self.ready[team as usize];
        if let Some((_, t)) = side.iter_mut().find(|(k, _)| k == p.key) {
            *t = now + p.cooldown;
        } else {
            side.push((p.key.into(), now + p.cooldown));
        }
        battle.add(peer, team, 14, f64::from(p.cost))?;
        battle.add(peer, team, 19, 1.)?;
        battle.event(battle_stats::Event {
            time: now,
            team,
            kind: "sup".into(),
            text: p.name.into(),
        })?;
        let dir = if dir.length() < 0.1 {
            if team == 0 {
                -Vector3::Z
            } else {
                Vector3::Z
            }
        } else {
            dir
        };
        Ok((
            true,
            self.launch(
                actors,
                rng,
                now,
                team,
                at,
                normalized(flat(dir)),
                peer,
                p,
                map_side,
            )?,
        ))
    }
    pub fn demo(
        &mut self,
        actors: &mut Actors,
        rng: &mut SimulationRandom,
        now: f64,
        at: Vector3,
        dir: Vector3,
        p: &Definition<'_>,
        map_side: u32,
    ) -> Result<Vec<Event>, &'static str> {
        self.preflight(actors, p, now, at, dir, map_side)?;
        self.launch(
            actors,
            rng,
            now,
            -1,
            at,
            normalized(flat(if dir.length() < 0.1 { Vector3::X } else { dir })),
            0,
            p,
            map_side,
        )
    }
    fn launch(
        &mut self,
        actors: &mut Actors,
        rng: &mut SimulationRandom,
        now: f64,
        team: i8,
        at: Vector3,
        dir: Vector3,
        by: i32,
        p: &Definition<'_>,
        map_side: u32,
    ) -> Result<Vec<Event>, &'static str> {
        let at = flat(at);
        let mut events = vec![
            Event::Mark {
                position: at,
                radius: p.radius,
            },
            Event::Stat(format!("support_{}", p.key)),
        ];
        let gr = crate::prisoner_intelligence::grid_ref(at, map_side);
        let mut words = p.name.split(' ');
        let air = format!(
            "{} {}",
            words.next().unwrap_or(""),
            words.next().unwrap_or("")
        );
        let (mine, theirs) = match p.sortie {
            Sortie::Recon => (
                format!("{air} inbound on {gr}. Watch the map."),
                if p.quiet {
                    ""
                } else {
                    "Enemy recon plane overhead. They've seen us."
                },
            ),
            Sortie::Watch => (
                format!(
                    "{air} on station over {gr}. Eyes on for {} seconds.",
                    p.stay as i64
                ),
                if p.quiet { "" } else { "Enemy drone overhead!" },
            ),
            Sortie::Jet => (
                format!("{air} inbound on {gr}."),
                if p.quiet { "" } else { "Enemy jet inbound!" },
            ),
            Sortie::GunRun => (
                format!("{air} inbound, gun run on {gr}. Danger close!"),
                "Enemy jet, low! Get down!",
            ),
            Sortie::Orbit => (
                format!("{air} on station over {gr}. Thirty seconds of fire."),
                "Enemy aircraft overhead!",
            ),
            Sortie::Artillery => (
                format!("Shot, over. 155 on {gr}, eight rounds."),
                "Incoming artillery!",
            ),
            Sortie::Barrage => (
                format!("Rocket barrage on {gr}. Keep your heads down."),
                "Incoming rockets!",
            ),
            Sortie::Mortars => (format!("Mortars firing on {gr}."), "Incoming mortars!"),
            Sortie::Smoke => (format!("Smoke going down on {gr}."), "Incoming mortars!"),
        };
        let flight = match p.sortie {
            Sortie::Recon => {
                let mut f = SupportFlight::new(
                    FlightKind::Jet,
                    at - dir * p.leg as f32 + Vector3::Y * p.altitude as f32,
                    dir * p.speed as f32,
                    at,
                );
                f.fuse = 0.;
                f.sight = p.sight;
                f.stay = p.leg;
                Some(f)
            }
            Sortie::Jet => {
                let mut f = SupportFlight::new(
                    FlightKind::Jet,
                    at - dir * 330. + Vector3::Y * 34.,
                    dir * 95.,
                    at,
                );
                f.fuse = f64::from(p.bombs);
                Some(f)
            }
            Sortie::GunRun => {
                let mut start = at + dir * (-420.);
                start.y = crate::support::gun_run_altitude(-420.) as f32;
                let mut f = SupportFlight::new(FlightKind::GunRun, start, dir * 58., at);
                f.fuse = 0.;
                Some(f)
            }
            Sortie::Watch | Sortie::Orbit => {
                let mut f = SupportFlight::new(
                    FlightKind::Orbit,
                    at + Vector3::new(165., 88., 0.),
                    Vector3::ZERO,
                    at,
                );
                f.fuse = f64::from(rng.randf()) * std::f64::consts::TAU;
                f.gunset = if p.sortie == Sortie::Watch {
                    Gunset::Unarmed
                } else {
                    p.guns
                };
                f.muzzles = p.muzzles;
                if p.sortie == Sortie::Watch {
                    f.sight = p.sight;
                    f.stay = p.stay;
                }
                Some(f)
            }
            _ => None,
        };
        if let Some(f) = flight {
            let mut projectile = Projectile::from_spawn(
                1,
                crate::projectile_actor::Spawn {
                    flight: ballistic(Kind::Frag, at, Vector3::ZERO),
                    team,
                    thrower: 0,
                    called_by: if matches!(p.sortie, Sortie::Recon | Sortie::Watch) {
                        0
                    } else {
                        by
                    },
                },
            )?;
            projectile.motion = Motion::Support(f);
            let id = actors.spawn(Actor::Projectile(projectile))?;
            events.push(Event::Born {
                id,
                model: p.model.into(),
            });
        } else {
            let (n, delay, gap, kind, radius, distance) = match p.sortie {
                Sortie::Artillery => (8, 2., 0.7, Kind::Arty, 22., 380.),
                Sortie::Barrage => (16, 1.5, 0.28, Kind::Grad, 20., 300.),
                Sortie::Mortars => (12, 1., 0.45, Kind::Mortar, 15., 130.),
                _ => (6, 1., 0.45, Kind::MortarSmoke, 10., 130.),
            };
            let back = if team == 0 {
                Vector3::Z
            } else if team == 1 {
                -Vector3::Z
            } else {
                -dir
            };
            for i in 0..n {
                self.queue.push(Salvo {
                    at: now + delay + f64::from(i) * gap,
                    kind,
                    team,
                    position: at,
                    radius,
                    back: back * distance,
                    called_by: by,
                });
            }
        }
        events.push(Event::Message {
            team,
            alert: false,
            text: mine,
            position: at,
        });
        if team >= 0 && !theirs.is_empty() {
            events.push(Event::Message {
                team: 1 - team,
                alert: true,
                text: theirs.into(),
                position: at,
            });
        }
        Ok(events)
    }
    pub fn advance(
        &mut self,
        actors: &mut Actors,
        rng: &mut SimulationRandom,
        now: f64,
    ) -> Result<Vec<Event>, &'static str> {
        if !self.valid() || !clock(now) {
            return Err("invalid support clock");
        }
        let due = self.queue.iter().filter(|q| now >= q.at).count();
        if actors.entities().len() + due > crate::entities::MAX_ENTITIES
            || actors.entities().next_id() + due as u64 > u64::from(u32::MAX) + 1
        {
            return Err("support entity limit exceeded");
        }
        let mut events = vec![];
        // Reverse queue order is gameplay: it chooses which random draw each arriving round gets.
        let arriving: Vec<_> = self.queue.extract_if(.., |q| now >= q.at).collect();
        for q in arriving.into_iter().rev() {
            let a = f64::from(rng.randf()) * std::f64::consts::TAU;
            let r = libm::sqrt(f64::from(rng.randf())) * q.radius;
            let target =
                q.position + Vector3::new((libm::cos(a) * r) as f32, 0., (libm::sin(a) * r) as f32);
            let side = normalized(q.back).cross(Vector3::Y);
            let mut origin = q.position + q.back + side * rng.randf_range(-40., 40.);
            origin.y = 3.;
            let speed = if q.kind == Kind::Grad {
                140.
            } else if q.kind == Kind::Arty {
                110.
            } else {
                60.
            };
            let mut flight = ballistic(q.kind, origin, Vector3::ZERO);
            flight.origin = origin;
            flight.target = target;
            flight.shell_duration = (if q.kind == Kind::Arty { 6. } else { 4.5 })
                + f64::from(flat(target - origin).length()) / speed;
            let id = actors.spawn(Actor::Projectile(Projectile::from_spawn(
                1,
                crate::projectile_actor::Spawn {
                    flight,
                    team: q.team,
                    thrower: 0,
                    called_by: q.called_by,
                },
            )?))?;
            events.push(Event::Born {
                id,
                model: String::new(),
            });
            if matches!(q.kind, Kind::Mortar | Kind::MortarSmoke | Kind::Arty) && rng.randf() < 0.5
            {
                events.push(Event::Sound {
                    name: if q.kind == Kind::Arty {
                        "cannon"
                    } else {
                        "mortar"
                    },
                    position: q.position,
                });
            }
        }
        Ok(events)
    }
    pub fn checkpoint(&self) -> Result<Vec<u8>, &'static str> {
        if !self.valid() {
            return Err("invalid support checkpoint");
        }
        let mut w = Writer::new(b"FLCL\x01\0\0\0");
        for side in &self.ready {
            w.u32(side.len() as u32);
            for (k, t) in side {
                w.bytes(k.as_bytes());
                w.f64(*t);
            }
        }
        w.u32(self.queue.len() as u32);
        for q in &self.queue {
            w.f64(q.at);
            w.byte(q.kind as u8);
            w.byte(q.team as u8);
            w.point(q.position);
            w.f64(q.radius);
            w.point(q.back);
            w.u32(q.called_by as u32);
        }
        Ok(w.0)
    }
    pub fn restore(bytes: &[u8]) -> Result<Self, &'static str> {
        let mut r = Reader::new(bytes, b"FLCL\x01\0\0\0")?;
        let mut s = Self::default();
        for side in &mut s.ready {
            let n = r.u32()? as usize;
            if n > LIMIT {
                return Err("support cooldown limit exceeded");
            }
            for _ in 0..n {
                side.push((
                    String::from_utf8(r.bytes(128)?.to_vec()).map_err(|_| "invalid support key")?,
                    r.f64()?,
                ));
            }
        }
        let n = r.u32()? as usize;
        if n > LIMIT {
            return Err("salvo limit exceeded");
        }
        for _ in 0..n {
            let at = r.f64()?;
            let kind = match r.byte()? {
                4 => Kind::Mortar,
                5 => Kind::MortarSmoke,
                6 => Kind::Grad,
                7 => Kind::Arty,
                _ => return Err("invalid support shell"),
            };
            s.queue.push(Salvo {
                at,
                kind,
                team: r.byte()? as i8,
                position: r.point()?,
                radius: r.f64()?,
                back: r.point()?,
                called_by: r.u32()? as i32,
            });
        }
        r.finish()?;
        if !s.valid() {
            return Err("invalid support state");
        }
        Ok(s)
    }
}
