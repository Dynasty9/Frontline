use crate::random::SimulationRandom;
use crate::state_codec::{Reader, Writer};
use crate::vector::{normalized, Vector3};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
#[repr(u8)]
pub enum Kind {
    Jet,
    GunRun,
    Orbit,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
#[repr(u8)]
pub enum Gunset {
    Ac130,
    Blackfish,
    Xian,
    Greyhawk,
    Unarmed,
}

impl Gunset {
    pub fn parse(name: &str) -> Self {
        match name {
            "blackfish" => Self::Blackfish,
            "xian" => Self::Xian,
            "greyhawk" => Self::Greyhawk,
            "none" => Self::Unarmed,
            _ => Self::Ac130,
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Gun {
    pub kind: &'static str,
    pub every: f64,
    pub burst: u32,
    pub gap: f64,
    pub duration: f64,
    pub spread: f32,
    pub sound: &'static str,
    pub volume: f64,
}

const AC130: [Gun; 3] = [
    Gun {
        kind: "ac105",
        every: 3.4,
        burst: 1,
        gap: 0.0,
        duration: 2.6,
        spread: 2.5,
        sound: "ac105",
        volume: 5.0,
    },
    Gun {
        kind: "ac40",
        every: 2.3,
        burst: 3,
        gap: 0.38,
        duration: 1.8,
        spread: 2.2,
        sound: "ac40",
        volume: 0.0,
    },
    Gun {
        kind: "ac25",
        every: 3.8,
        burst: 14,
        gap: 0.07,
        duration: 1.35,
        spread: 3.2,
        sound: "",
        volume: 0.0,
    },
];
const BLACKFISH: [Gun; 3] = [
    Gun {
        kind: "ac105",
        every: 5.2,
        burst: 1,
        gap: 0.0,
        duration: 2.4,
        spread: 2.8,
        sound: "ac105",
        volume: 4.0,
    },
    Gun {
        kind: "ac40",
        every: 2.6,
        burst: 3,
        gap: 0.4,
        duration: 1.7,
        spread: 2.4,
        sound: "ac40",
        volume: 0.0,
    },
    Gun {
        kind: "ac25",
        every: 3.2,
        burst: 16,
        gap: 0.06,
        duration: 1.3,
        spread: 3.4,
        sound: "",
        volume: 0.0,
    },
];
const XIAN: [Gun; 2] = [
    Gun {
        kind: "ac25",
        every: 2.6,
        burst: 10,
        gap: 0.09,
        duration: 1.3,
        spread: 3.0,
        sound: "",
        volume: 0.0,
    },
    Gun {
        kind: "grad",
        every: 5.0,
        burst: 4,
        gap: 0.25,
        duration: 1.6,
        spread: 4.5,
        sound: "",
        volume: 0.0,
    },
];
const GREYHAWK: [Gun; 1] = [Gun {
    kind: "ac40",
    every: 4.2,
    burst: 1,
    gap: 0.0,
    duration: 2.0,
    spread: 1.2,
    sound: "",
    volume: 0.0,
}];

pub fn guns(set: Gunset) -> &'static [Gun] {
    match set {
        Gunset::Ac130 => &AC130,
        Gunset::Blackfish => &BLACKFISH,
        Gunset::Xian => &XIAN,
        Gunset::Greyhawk => &GREYHAWK,
        Gunset::Unarmed => &[],
    }
}

#[derive(Clone, Debug, PartialEq)]
pub enum Event {
    Bomb {
        position: Vector3,
        velocity: Vector3,
    },
    GunRunStarted,
    Impact(Vector3),
    Shell {
        kind: &'static str,
        position: Vector3,
        target: Vector3,
        duration: f64,
    },
    Sound {
        name: &'static str,
        volume: f64,
    },
    Photograph,
    Despawn,
}

#[derive(Clone, Debug, PartialEq)]
pub struct SupportFlight {
    pub kind: Kind,
    pub gunset: Gunset,
    pub position: Vector3,
    pub velocity: Vector3,
    pub target: Vector3,
    pub life: f64,
    pub fuse: f64,
    pub stay: f64,
    pub sight: f64,
    pub fire_elapsed: f64,
    pub bombs_initial: f64,
    pub mark_time: f64,
    hits: Vec<(f64, Vector3)>,
    next: [Option<(f64, u32)>; 3],
    pub dead: bool,
}

impl SupportFlight {
    pub fn new(kind: Kind, position: Vector3, velocity: Vector3, target: Vector3) -> Self {
        Self {
            kind,
            gunset: Gunset::Ac130,
            position,
            velocity,
            target,
            life: 0.0,
            fuse: 3.4,
            stay: 0.0,
            sight: 0.0,
            fire_elapsed: -1.0,
            bombs_initial: -1.0,
            mark_time: 0.0,
            hits: Vec::new(),
            next: [None; 3],
            dead: false,
        }
    }

    pub fn needs_candidates(&self, dt: f64) -> bool {
        let life = self.life + dt;
        self.kind == Kind::Orbit
            && !self.dead
            && life >= 3.0
            && life <= self.on_station()
            && self
                .next
                .iter()
                .take(guns(self.gunset).len())
                .any(|schedule| schedule.is_none_or(|(at, _)| life >= at))
    }

    pub fn on_station(&self) -> f64 {
        if self.stay > 0.0 {
            self.stay
        } else {
            26.0
        }
    }

    pub fn orbit_position(&self, time: f64) -> Vector3 {
        let angle = self.fuse - time * 52.0 / 165.0;
        self.target
            + Vector3::new(
                (angle.cos() * 165.0) as f32,
                88.0,
                (angle.sin() * 165.0) as f32,
            )
    }

    pub fn advance(
        &mut self,
        dt: f64,
        time: f64,
        team: i32,
        map_half: f64,
        candidates: &[Vector3],
        rng: &mut SimulationRandom,
    ) -> Vec<Event> {
        let mut events = Vec::new();
        if self.dead {
            return events;
        }
        self.life += dt;
        match self.kind {
            Kind::Jet => {
                self.position += self.velocity * dt as f32;
                let direction = normalized(flat(self.velocity));
                let along = f64::from(flat(self.position - self.target).dot(direction));
                if self.bombs_initial < 0.0 {
                    self.bombs_initial = self.fuse;
                }
                if self.fuse > 0.0 {
                    let index = self.bombs_initial - self.fuse;
                    if along > -70.0 - 5.0 * (self.bombs_initial - 1.0) + index * 10.0 {
                        self.fuse -= 1.0;
                        events.push(Event::Bomb {
                            position: self.position + Vector3::new(0.0, -1.4, 0.0),
                            velocity: self.velocity * 0.95,
                        });
                    }
                }
                if self.sight > 0.0 {
                    self.mark_time -= dt;
                    if self.mark_time <= 0.0
                        && team >= 0
                        && f64::from(self.position.x.abs()) < map_half + self.sight
                        && f64::from(self.position.z.abs()) < map_half + self.sight
                    {
                        self.mark_time = 0.45;
                        events.push(Event::Photograph);
                    }
                }
                self.dead = along > if self.stay > 0.0 { self.stay } else { 340.0 };
            }
            Kind::GunRun => {
                let direction = normalized(flat(self.velocity));
                self.position += direction * 58.0 * dt as f32;
                let along = f64::from(flat(self.position - self.target).dot(direction));
                self.position.y = gun_run_altitude(along) as f32;
                self.velocity = direction * 58.0
                    + Vector3::Y
                        * ((gun_run_altitude(along + 1.0) - gun_run_altitude(along)) * 58.0) as f32;
                if along >= -50.0 && self.fire_elapsed < 1.0 {
                    if self.fire_elapsed < 0.0 {
                        self.fire_elapsed = 0.0;
                        events.push(Event::GunRunStarted);
                    }
                    let side = direction.cross(Vector3::Y);
                    let count = (30.0 * dt + f64::from(rng.randf()) * 0.5).round() as usize;
                    for _ in 0..count {
                        let progress = self.fire_elapsed.clamp(0.0, 1.0);
                        let mut aim = self.target
                            + direction * (-18.0 + 36.0 * progress) as f32
                            + side * rng.randf_range(-3.0, 3.0)
                            + direction * rng.randf_range(-2.0, 2.0);
                        aim.y = 0.15;
                        self.hits
                            .push((time + f64::from(self.position.distance(aim)) / 950.0, aim));
                    }
                    self.fire_elapsed += dt;
                }
                for i in (0..self.hits.len()).rev() {
                    if time >= self.hits[i].0 {
                        events.push(Event::Impact(self.hits.remove(i).1));
                    }
                }
                self.dead = along > 420.0;
            }
            Kind::Orbit => {
                self.position = self.orbit_position(self.life);
                self.velocity = (self.orbit_position(self.life + 0.1) - self.position) / 0.1;
                if self.life >= 3.0 && self.life <= self.on_station() {
                    for (index, gun) in guns(self.gunset).iter().enumerate() {
                        let (at, fired) = self.next[index].unwrap_or_else(|| {
                            (
                                self.life + f64::from(rng.randf_range(0.0, gun.every as f32)),
                                0,
                            )
                        });
                        if self.life < at {
                            self.next[index] = Some((at, fired));
                            continue;
                        }
                        let mut aim = self.aim(candidates, rng);
                        aim += Vector3::new(
                            rng.randf_range(-gun.spread, gun.spread),
                            0.0,
                            rng.randf_range(-gun.spread, gun.spread),
                        );
                        aim.y = 0.15;
                        events.push(Event::Shell {
                            kind: gun.kind,
                            position: self.position + Vector3::new(0.0, -1.5, 0.0),
                            target: aim,
                            duration: gun.duration * f64::from(rng.randf_range(0.9, 1.1)),
                        });
                        if !gun.sound.is_empty() {
                            events.push(Event::Sound {
                                name: gun.sound,
                                volume: gun.volume,
                            });
                        } else if fired == 0 {
                            events.push(Event::Sound {
                                name: "ac25",
                                volume: 0.0,
                            });
                        }
                        self.next[index] = Some(if fired + 1 >= gun.burst {
                            (
                                self.life + gun.every * f64::from(rng.randf_range(0.8, 1.2)),
                                0,
                            )
                        } else {
                            (self.life + gun.gap, fired + 1)
                        });
                    }
                }
                self.dead = self.life > self.on_station() + 8.0;
            }
        }
        if self.dead {
            events.push(Event::Despawn);
        }
        events
    }

    fn aim(&self, candidates: &[Vector3], rng: &mut SimulationRandom) -> Vector3 {
        if !candidates.is_empty() {
            return candidates[rng.randi() as usize % candidates.len()];
        }
        let angle = f64::from(rng.randf()) * std::f64::consts::TAU;
        let radius = f64::from(rng.randf()).sqrt() * 25.0;
        self.target
            + Vector3::new(
                (angle.cos() * radius) as f32,
                0.0,
                (angle.sin() * radius) as f32,
            )
    }

    pub fn checkpoint(&self) -> Vec<u8> {
        let mut out = Writer::new(b"FLSF\x01\0\0\0");
        out.byte(self.kind as u8);
        out.byte(self.gunset as u8);
        out.byte(u8::from(self.dead));
        for point in [self.position, self.velocity, self.target] {
            out.point(point);
        }
        for value in [
            self.life,
            self.fuse,
            self.stay,
            self.sight,
            self.fire_elapsed,
            self.bombs_initial,
            self.mark_time,
        ] {
            out.f64(value);
        }
        for schedule in self.next {
            out.byte(u8::from(schedule.is_some()));
            if let Some((at, count)) = schedule {
                out.f64(at);
                out.u32(count);
            }
        }
        out.u32(self.hits.len() as u32);
        for &(time, point) in &self.hits {
            out.f64(time);
            out.point(point);
        }
        out.0
    }

    pub fn restore(bytes: &[u8]) -> Result<Self, &'static str> {
        let mut input = Reader::new(bytes, b"FLSF\x01\0\0\0")?;
        let kind = *[Kind::Jet, Kind::GunRun, Kind::Orbit]
            .get(input.byte()? as usize)
            .ok_or("invalid support kind")?;
        let gunset = *[
            Gunset::Ac130,
            Gunset::Blackfish,
            Gunset::Xian,
            Gunset::Greyhawk,
            Gunset::Unarmed,
        ]
        .get(input.byte()? as usize)
        .ok_or("invalid support guns")?;
        let dead = input.boolean()?;
        let mut state = Self::new(kind, input.point()?, input.point()?, input.point()?);
        state.gunset = gunset;
        state.dead = dead;
        state.life = input.f64()?;
        state.fuse = input.f64()?;
        state.stay = input.f64()?;
        state.sight = input.f64()?;
        state.fire_elapsed = input.f64()?;
        state.bombs_initial = input.f64()?;
        state.mark_time = input.f64()?;
        for (i, schedule) in state.next.iter_mut().enumerate() {
            if input.boolean()? {
                let at = input.f64()?;
                let count = input.u32()?;
                if guns(gunset).get(i).is_none_or(|gun| count >= gun.burst) {
                    return Err("invalid support burst position");
                }
                *schedule = Some((at, count));
            }
        }
        let count = input.u32()?;
        if count > 1024 {
            return Err("too many pending support hits");
        }
        for _ in 0..count {
            state.hits.push((input.f64()?, input.point()?));
        }
        input.finish()?;
        Ok(state)
    }
}

fn flat(p: Vector3) -> Vector3 {
    Vector3::new(p.x, 0.0, p.z)
}

pub fn gun_run_altitude(along: f64) -> f64 {
    if along < -160.0 {
        62.0 + (27.0 - 62.0) * ((along + 420.0) / 260.0).clamp(0.0, 1.0)
    } else if along < 0.0 {
        27.0 + (21.0 - 27.0) * ((along + 160.0) / 160.0)
    } else {
        21.0 + along * 0.42
    }
}
