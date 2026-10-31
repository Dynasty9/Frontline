//! Projectiles retain ownership and handlers with their flight; impacts return ordered world effects.
use crate::collision::CollisionWorld;
use crate::guided::{GuidedFlight, Kind as GuidedKind};
use crate::projectile::{Flight, Holder, Kind, Outcome};
use crate::random::SimulationRandom;
use crate::state_codec::{Reader, Writer};
use crate::support::{Event as SupportEvent, SupportFlight};
use crate::vector::{normalized, Vector3};

#[derive(Clone, Debug, PartialEq)]
pub enum Motion {
    Ballistic(Flight),
    Guided(GuidedFlight),
    Support(SupportFlight),
}

#[derive(Clone, Debug, PartialEq)]
pub struct Projectile {
    pub id: u32,
    pub team: i8,
    pub thrower: u32,
    pub called_by: i32,
    pub held_by: u32,
    pub smothered_by: u32,
    pub handler: u32,
    pub thrown_back: u32,
    pub target_id: u32,
    pub motion: Motion,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Explosion {
    pub position: Vector3,
    pub damage: f64,
    pub radius: f64,
    pub fling: f64,
    pub antitank: f64,
    pub direction: Option<Vector3>,
    pub top: bool,
    pub track: f64,
    pub source: u32,
    pub team: i8,
    pub called_by: i32,
    pub size: f64,
    pub structure_multiplier: f64,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Spawn {
    pub flight: Flight,
    pub team: i8,
    pub thrower: u32,
    pub called_by: i32,
}

#[derive(Clone, Debug, PartialEq)]
pub enum Event {
    Explosion(Explosion),
    Spawn(Spawn),
    DamageSmotherer {
        soldier: u32,
        source: u32,
    },
    SmotherNotice(u32),
    Photograph {
        team: i8,
        position: Vector3,
        radius: f64,
        linger: f64,
    },
    Sound {
        name: &'static str,
        volume: f64,
        position: Vector3,
    },
    Stat(&'static str),
    Despawn,
}

#[derive(Clone, Copy, Debug)]
pub struct Smotherer {
    pub id: u32,
    pub position: Vector3,
    pub yaw: f64,
    pub alive: bool,
    pub covering: bool,
}

#[derive(Clone, Copy, Debug)]
pub struct Step<'a> {
    pub dt: f64,
    pub time: f64,
    pub map_half: f64,
    pub holder: Holder,
    pub target: Option<Vector3>,
    pub smoke: bool,
    pub smotherer: Option<Smotherer>,
    pub candidates: &'a [Vector3],
    pub excluded: &'a [i64],
}

fn point(p: Vector3) -> bool {
    p.is_finite() && p.abs().max_element() <= 1_000_000.0
}
fn time(t: f64) -> bool {
    t.is_finite() && t.abs() <= 1e12
}
fn team(t: i8) -> bool {
    (-1..=1).contains(&t)
}

pub fn ballistic(kind: Kind, position: Vector3, velocity: Vector3) -> Flight {
    Flight {
        kind,
        position,
        velocity,
        origin: Vector3::ZERO,
        target: Vector3::ZERO,
        fuse: 3.4,
        flying: true,
        life: 0.0,
        smoke_time: 0.0,
        smoke_radius: 0.0,
        shell_duration: 3.0,
    }
}

pub fn ballistic_velocity(from: Vector3, to: Vector3) -> Vector3 {
    let delta = to - from;
    let duration = (f64::from(Vector3::new(delta.x, 0.0, delta.z).length()) / 14.0).clamp(0.6, 1.7);
    delta / duration as f32 + Vector3::new(0.0, (9.0 * duration) as f32, 0.0)
}

impl Motion {
    pub fn position(&self) -> Vector3 {
        match self {
            Self::Ballistic(f) => f.position,
            Self::Guided(f) => f.position,
            Self::Support(f) => f.position,
        }
    }
    pub fn valid(&self) -> bool {
        match self {
            Self::Ballistic(f) => {
                [f.position, f.velocity, f.origin, f.target]
                    .into_iter()
                    .all(point)
                    && [
                        f.fuse,
                        f.life,
                        f.smoke_time,
                        f.smoke_radius,
                        f.shell_duration,
                    ]
                    .into_iter()
                    .all(time)
            }
            Self::Guided(f) => {
                [f.position, f.velocity, f.target].into_iter().all(point) && time(f.life)
            }
            Self::Support(f) => f.valid(),
        }
    }
}

impl Projectile {
    pub fn from_spawn(id: u32, spawn: Spawn) -> Result<Self, &'static str> {
        let s = Self {
            id,
            team: spawn.team,
            thrower: spawn.thrower,
            called_by: spawn.called_by,
            held_by: 0,
            smothered_by: 0,
            handler: 0,
            thrown_back: 0,
            target_id: 0,
            motion: Motion::Ballistic(spawn.flight),
        };
        if !s.valid() {
            return Err("invalid projectile spawn");
        }
        Ok(s)
    }

    pub fn valid(&self) -> bool {
        self.id != 0 && team(self.team) && self.thrown_back <= 1_000_000 && self.motion.valid()
    }

    pub fn checkpoint(&self) -> Result<Vec<u8>, &'static str> {
        if !self.valid() {
            return Err("invalid projectile actor");
        }
        let mut out = Writer::new(b"FLPA\x01\0\0\0");
        out.u32(self.id);
        out.byte(self.team as u8);
        out.u32(self.called_by as u32);
        for id in [
            self.thrower,
            self.held_by,
            self.smothered_by,
            self.handler,
            self.thrown_back,
            self.target_id,
        ] {
            out.u32(id);
        }
        let (kind, bytes) = match &self.motion {
            Motion::Ballistic(f) => (0, f.checkpoint()),
            Motion::Guided(f) => (1, f.checkpoint()),
            Motion::Support(f) => (2, f.checkpoint()),
        };
        out.byte(kind);
        out.bytes(&bytes);
        Ok(out.0)
    }

    pub fn restore(bytes: &[u8]) -> Result<Self, &'static str> {
        let mut input = Reader::new(bytes, b"FLPA\x01\0\0\0")?;
        let id = input.u32()?;
        let team = input.byte()? as i8;
        let called_by = input.u32()? as i32;
        let thrower = input.u32()?;
        let held_by = input.u32()?;
        let smothered_by = input.u32()?;
        let handler = input.u32()?;
        let thrown_back = input.u32()?;
        let target_id = input.u32()?;
        let motion = match input.byte()? {
            0 => Motion::Ballistic(Flight::restore(input.bytes(98)?)?),
            1 => Motion::Guided(GuidedFlight::restore(input.bytes(55)?)?),
            2 => Motion::Support(SupportFlight::restore(input.bytes(32_768)?)?),
            _ => return Err("unknown projectile motion"),
        };
        input.finish()?;
        let s = Self {
            id,
            team,
            called_by,
            thrower,
            held_by,
            smothered_by,
            handler,
            thrown_back,
            target_id,
            motion,
        };
        if !s.valid() {
            return Err("invalid projectile checkpoint");
        }
        Ok(s)
    }

    pub fn pick_up(&mut self, soldier: u32) -> Result<(), &'static str> {
        if !self.valid() || soldier == 0 {
            return Err("invalid projectile holder");
        }
        let Motion::Ballistic(f) = &mut self.motion else {
            return Err("only ballistic projectiles can be held");
        };
        self.held_by = soldier;
        f.flying = false;
        f.velocity = Vector3::ZERO;
        Ok(())
    }

    pub fn kick(&mut self, velocity: Vector3) -> Result<(), &'static str> {
        if !self.valid() || !point(velocity) || self.thrown_back == 1_000_000 {
            return Err("invalid projectile kick");
        }
        let Motion::Ballistic(f) = &mut self.motion else {
            return Err("only ballistic projectiles can be kicked");
        };
        f.flying = true;
        f.velocity = velocity;
        self.thrown_back += 1;
        f.position.y = f.position.y.max(0.15);
        self.smothered_by = 0;
        Ok(())
    }

    pub fn release_throw(
        &mut self,
        soldier: u32,
        side: i8,
        position: Vector3,
        target: Vector3,
    ) -> Result<(), &'static str> {
        let from = position + Vector3::new(0.0, 1.7, 0.0);
        let velocity = ballistic_velocity(from, target);
        if !self.valid()
            || soldier == 0
            || !team(side)
            || !point(position)
            || !point(target)
            || !point(from)
            || !point(velocity)
            || self.thrown_back == 1_000_000
        {
            return Err("invalid projectile rethrow");
        }
        let Motion::Ballistic(f) = &mut self.motion else {
            return Err("only ballistic projectiles can be rethrown");
        };
        self.held_by = 0;
        self.team = side;
        self.thrower = soldier;
        self.thrown_back += 1;
        f.flying = true;
        f.position = from;
        f.velocity = velocity;
        Ok(())
    }

    fn explosion(&self, position: Vector3) -> Explosion {
        Explosion {
            position,
            damage: 120.0,
            radius: 5.0,
            fling: 8.0,
            antitank: 0.0,
            direction: None,
            top: false,
            track: 0.3,
            source: self.thrower,
            team: self.team,
            called_by: self.called_by,
            size: 1.0,
            structure_multiplier: 1.0,
        }
    }

    fn spawn(&self, flight: Flight, thrower: u32) -> Event {
        Event::Spawn(Spawn {
            flight,
            team: self.team,
            thrower,
            called_by: self.called_by,
        })
    }

    fn impact(
        &self,
        kind: Kind,
        position: Vector3,
        velocity: Vector3,
        smothered: bool,
        events: &mut Vec<Event>,
    ) {
        let base = self.explosion(position);
        let blast = match kind {
            Kind::Frag if smothered => {
                events.push(Event::DamageSmotherer {
                    soldier: self.smothered_by,
                    source: self.thrower,
                });
                events.push(Event::Explosion(Explosion {
                    damage: 32.0,
                    radius: 2.6,
                    fling: 0.0,
                    size: 0.55,
                    called_by: 0,
                    ..base
                }));
                events.push(Event::SmotherNotice(self.smothered_by));
                events.push(Event::Stat("smother_saved"));
                None
            }
            Kind::Frag => Some(Explosion {
                damage: 150.0,
                radius: 6.0,
                fling: 9.0,
                ..base
            }),
            Kind::Rocket | Kind::Recoilless => Some(Explosion {
                damage: 110.0,
                radius: 4.0,
                fling: 8.0,
                antitank: if kind == Kind::Recoilless {
                    450.0
                } else {
                    380.0
                },
                direction: Some(normalized(velocity)),
                track: if kind == Kind::Recoilless { 0.25 } else { 0.2 },
                structure_multiplier: 2.0,
                ..base
            }),
            Kind::Bomb => Some(Explosion {
                damage: 220.0,
                radius: 10.0,
                fling: 15.0,
                antitank: 300.0,
                top: true,
                size: 2.6,
                track: 0.6,
                structure_multiplier: 3.0,
                ..base
            }),
            Kind::Mortar => Some(Explosion {
                damage: 130.0,
                radius: 6.5,
                fling: 9.0,
                antitank: 80.0,
                top: true,
                size: 1.2,
                structure_multiplier: 2.0,
                ..base
            }),
            Kind::Grad => Some(Explosion {
                damage: 150.0,
                radius: 7.0,
                fling: 10.0,
                antitank: 120.0,
                top: true,
                size: 1.6,
                structure_multiplier: 2.0,
                ..base
            }),
            Kind::Arty => Some(Explosion {
                damage: 230.0,
                radius: 10.0,
                fling: 14.0,
                antitank: 220.0,
                top: true,
                size: 2.3,
                structure_multiplier: 3.0,
                ..base
            }),
            Kind::Ac105 => Some(Explosion {
                damage: 220.0,
                radius: 8.5,
                fling: 13.0,
                antitank: 300.0,
                top: true,
                size: 2.0,
                structure_multiplier: 2.5,
                ..base
            }),
            Kind::Ac40 => Some(Explosion {
                damage: 95.0,
                radius: 3.8,
                fling: 6.0,
                antitank: 140.0,
                top: true,
                size: 0.85,
                structure_multiplier: 1.5,
                ..base
            }),
            Kind::Ac25 => Some(Explosion {
                damage: 50.0,
                radius: 1.8,
                fling: 0.0,
                antitank: 70.0,
                top: true,
                size: 0.38,
                ..base
            }),
            Kind::MortarSmoke => {
                let mut smoke = ballistic(
                    Kind::Smoke,
                    position + Vector3::new(0.0, 0.2, 0.0),
                    Vector3::ZERO,
                );
                smoke.fuse = 0.0;
                events.push(self.spawn(smoke, self.thrower));
                None
            }
            Kind::Smoke => None,
        };
        if let Some(blast) = blast {
            events.push(Event::Explosion(blast));
        }
        events.push(Event::Despawn);
    }

    pub fn advance(
        &mut self,
        input: Step<'_>,
        collision: &mut CollisionWorld,
        rng: &mut SimulationRandom,
    ) -> Result<Vec<Event>, &'static str> {
        if !self.valid()
            || !input.dt.is_finite()
            || !(0.0..=10.0).contains(&input.dt)
            || !time(input.time)
            || !input.map_half.is_finite()
            || !(1.0..=1_000_000.0).contains(&input.map_half)
            || input.target.is_some_and(|p| !point(p))
            || input.candidates.len() > 1_000_000
            || !input.candidates.iter().copied().all(point)
            || input.excluded.len() > 1_000_000
            || input
                .excluded
                .iter()
                .any(|id| *id <= 0 || *id > u32::MAX as i64)
            || matches!(input.holder, Holder::Alive(p) if !point(p))
            || input.smotherer.is_some_and(|s| {
                s.id == 0 || s.id != self.smothered_by || !point(s.position) || !time(s.yaw)
            })
            || ((self.held_by == 0) != (input.holder == Holder::Free))
        {
            return Err("invalid projectile update");
        }
        let mut next = self.clone();
        let mut random = *rng;
        let events = next.advance_validated(input, collision, &mut random);
        if !next.valid()
            || events.iter().any(|event| match event {
                Event::Explosion(e) => !point(e.position),
                Event::Spawn(p) => !Motion::Ballistic(p.flight).valid(),
                _ => false,
            })
        {
            return Err("projectile update exceeds state limits");
        }
        *self = next;
        *rng = random;
        Ok(events)
    }

    fn advance_validated(
        &mut self,
        input: Step<'_>,
        collision: &mut CollisionWorld,
        rng: &mut SimulationRandom,
    ) -> Vec<Event> {
        let mut events = Vec::new();
        match &mut self.motion {
            Motion::Ballistic(f) => {
                let outcome = f.advance_in_world(input.dt, input.holder, collision, input.excluded);
                if input.holder == Holder::Dropped {
                    self.held_by = 0;
                }
                let kind = f.kind;
                let velocity = f.velocity;
                match outcome {
                    Outcome::Flying => {}
                    Outcome::Expired => events.push(Event::Despawn),
                    Outcome::Impact(p) => {
                        let covered = input.smotherer.is_some_and(|s| {
                            s.alive
                                && s.covering
                                && crate::grenade_task::covers_grenade(s.position, s.yaw, p)
                                    .unwrap()
                        });
                        self.impact(kind, p, velocity, covered, &mut events)
                    }
                }
            }
            Motion::Guided(f) => {
                let impact = f.advance(
                    input.dt,
                    input.target,
                    input.smoke,
                    collision,
                    input.excluded,
                );
                if self.target_id != 0 && !f.locked {
                    self.target_id = 0;
                    events.push(Event::Stat("atgm_lost_in_smoke"));
                }
                let kind = f.kind;
                let velocity = f.velocity;
                if let Some(hit) = impact {
                    let base = self.explosion(hit.position);
                    events.push(Event::Explosion(if kind == GuidedKind::AntiTank {
                        Explosion {
                            damage: 90.0,
                            radius: 3.5,
                            fling: 7.0,
                            antitank: 520.0,
                            direction: Some(normalized(velocity)),
                            top: velocity.y < -0.3,
                            track: 0.25,
                            size: 1.1,
                            structure_multiplier: 2.0,
                            ..base
                        }
                    } else {
                        Explosion {
                            damage: 60.0,
                            radius: 4.0,
                            fling: 2.0,
                            antitank: if hit.proximity { 620.0 } else { 0.0 },
                            size: 0.9,
                            structure_multiplier: 0.5,
                            ..base
                        }
                    }));
                    events.push(Event::Despawn);
                }
            }
            Motion::Support(f) => {
                let output = f.advance(
                    input.dt,
                    input.time,
                    i32::from(self.team),
                    input.map_half,
                    input.candidates,
                    rng,
                );
                let position = f.position;
                let target = f.target;
                let sight = f.sight;
                for event in output {
                    events.push(match event {
                        SupportEvent::Bomb { position, velocity } => {
                            self.spawn(ballistic(Kind::Bomb, position, velocity), self.thrower)
                        }
                        SupportEvent::GunRunStarted => Event::Stat("a10_run"),
                        SupportEvent::Impact(p) => Event::Explosion(Explosion {
                            damage: 75.0,
                            radius: 2.6,
                            fling: 5.0,
                            antitank: 170.0,
                            top: true,
                            size: 0.68,
                            structure_multiplier: 1.6,
                            source: 0,
                            ..self.explosion(p)
                        }),
                        SupportEvent::Shell {
                            kind,
                            position,
                            target,
                            duration,
                        } => {
                            let mut f =
                                ballistic(Kind::parse(kind).unwrap(), position, Vector3::ZERO);
                            f.origin = position;
                            f.target = target;
                            f.shell_duration = duration;
                            self.spawn(f, self.id)
                        }
                        SupportEvent::Sound { name, volume } => Event::Sound {
                            name,
                            volume,
                            position: target,
                        },
                        SupportEvent::Photograph => Event::Photograph {
                            team: self.team,
                            position,
                            radius: sight,
                            linger: 6.0,
                        },
                        SupportEvent::Despawn => Event::Despawn,
                    });
                }
            }
        }
        events
    }
}
