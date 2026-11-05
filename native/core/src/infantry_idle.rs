//! Downtime is part of the seeded simulation: conversations consume gameplay draws.
use crate::infantry_vitals::Life;
use crate::random::SimulationRandom;
use crate::state_codec::{Reader, Writer};
use crate::vector::{normalized, turn_yaw, Vector3};
use std::collections::VecDeque;

pub const CHAT: u8 = 26;
pub const LAUGH: u8 = 27;

#[derive(Clone, Debug, PartialEq)]
pub struct Line {
    pub at: f64,
    pub text: String,
}

#[derive(Clone, Debug, Default, PartialEq)]
pub struct Idle {
    pub calm: f64,
    pub activity: u8,
    pub until: f64,
    pub next: f64,
    pub partner: u64,
    pub lines: VecDeque<Line>,
    pub laugh_until: f64,
}

#[derive(Clone, Copy, Debug)]
pub struct Calm {
    pub moving: bool,
    pub danger: bool,
    pub sector: Vector3,
    pub reload: f64,
    pub last_shot: f64,
    pub mounted: bool,
    pub target: bool,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Decision {
    Wait,
    End,
    Pose,
    Chat,
    Start,
}

#[derive(Clone, Copy, Debug)]
pub struct Mate {
    pub id: u64,
    pub team: i32,
    pub life: Life,
    pub chatting: bool,
    pub calm: f64,
    pub free: bool,
    pub moving: bool,
}

fn time(t: f64) -> bool {
    t.is_finite() && t.abs() <= 1e12
}
fn id(id: u64) -> bool {
    id <= i64::MAX as u64
}
fn point(p: Vector3) -> bool {
    p.is_finite() && p.abs().max_element() <= 1_000_000.0
}
fn team_index(team: i32) -> usize {
    usize::from(team == 1)
}

impl Idle {
    pub fn valid(&self) -> bool {
        [self.calm, self.until, self.next, self.laugh_until]
            .into_iter()
            .all(time)
            && matches!(self.activity, 0 | 26 | 28..=32)
            && id(self.partner)
            && self.lines.len() <= 128
            && self
                .lines
                .iter()
                .all(|l| time(l.at) && l.text.len() <= 4096)
    }

    pub fn tick(
        &mut self,
        dt: f64,
        now: f64,
        c: Calm,
        partner_valid: bool,
    ) -> Result<Decision, &'static str> {
        if !self.valid()
            || !time(now)
            || !dt.is_finite()
            || !(0.0..=10.0).contains(&dt)
            || !time(self.calm + dt)
            || !point(c.sector)
            || !time(c.reload)
            || !time(c.last_shot)
        {
            return Err("invalid infantry downtime");
        }
        let calm = !c.moving
            && !c.danger
            && c.sector == Vector3::ZERO
            && c.reload <= 0.0
            && now - c.last_shot > 12.0
            && !c.mounted
            && !c.target;
        if !calm {
            self.calm = 0.0;
            return Ok(if self.activity != 0 {
                Decision::End
            } else {
                Decision::Wait
            });
        }
        self.calm += dt;
        if self.activity != 0 {
            return Ok(
                if now > self.until || (self.activity == CHAT && !partner_valid) {
                    Decision::End
                } else if self.activity == CHAT && self.partner != 0 {
                    Decision::Chat
                } else {
                    Decision::Pose
                },
            );
        }
        Ok(if self.calm < 12.0 || now < self.next {
            Decision::Wait
        } else {
            Decision::Start
        })
    }

    pub fn begin(
        &mut self,
        now: f64,
        last_chat: f64,
        rng: &mut SimulationRandom,
    ) -> Result<bool, &'static str> {
        if !self.valid() || !time(now) || !time(now + 60.0) || !time(last_chat) {
            return Err("invalid downtime start");
        }
        self.next = now + f64::from(rng.randf_range(6.0, 16.0));
        Ok(f64::from(rng.randf()) < 0.35 && now - last_chat > 8.0)
    }

    pub fn solo(
        &mut self,
        now: f64,
        team: i32,
        rng: &mut SimulationRandom,
    ) -> Result<Option<&'static str>, &'static str> {
        if !self.valid() || !time(now) || !time(now + 32.0) {
            return Err("invalid solo downtime");
        }
        self.activity = [28, 29, 30, 31, 32, 32][rng.randi() as usize % 6];
        let duration = match self.activity {
            28 => 16.0,
            29 => 24.0,
            30 => 3.2,
            31 => 5.0,
            _ => 6.0,
        };
        self.until = now + duration * f64::from(rng.randf_range(0.8, 1.3));
        Ok((f64::from(rng.randf()) < 0.22)
            .then(|| BORED[team_index(team)][rng.randi() as usize % 5]))
    }

    pub fn start_chat(
        &mut self,
        other: &mut Self,
        actor: u64,
        mate: u64,
        now: f64,
        team: i32,
        actor_name: &str,
        mate_name: &str,
        rng: &mut SimulationRandom,
    ) -> Result<(), &'static str> {
        if !self.valid()
            || !other.valid()
            || actor == 0
            || mate == 0
            || actor == mate
            || !id(actor)
            || !id(mate)
            || !time(now)
            || !time(now + 80.0)
            || actor_name.len() > 1024
            || mate_name.len() > 1024
        {
            return Err("invalid conversation");
        }
        let catalogue = BANTER[team_index(team)];
        let exchange = catalogue[rng.randi() as usize % catalogue.len()];
        let duration = 3.5 + exchange.len() as f64 * 2.8;
        for (state, partner) in [(&mut *self, mate), (&mut *other, actor)] {
            state.partner = partner;
            state.activity = CHAT;
            state.until = now + duration;
            state.next = now + duration + f64::from(rng.randf_range(25.0, 60.0));
            state.lines.clear();
        }
        for (i, text) in exchange.iter().enumerate() {
            let (who, name) = if i % 2 == 0 {
                (&mut *self, mate_name)
            } else {
                (&mut *other, actor_name)
            };
            who.lines.push_back(Line {
                at: now + 0.3 + i as f64 * 2.8,
                text: text.replace("%s", name),
            });
        }
        let listener = if exchange.len() % 2 == 1 { other } else { self };
        listener.lines.push_back(Line {
            at: now + exchange.len() as f64 * 2.8 - 0.6,
            text: "!laugh".into(),
        });
        Ok(())
    }

    // Apply each speech event before asking for another; callbacks may consume randomness.
    pub fn next_line(
        &mut self,
        now: f64,
        rng: &mut SimulationRandom,
    ) -> Result<Option<Option<String>>, &'static str> {
        if !self.valid() || !time(now) || !time(now + 1.8) {
            return Err("invalid conversation tick");
        }
        if self.lines.front().is_none_or(|line| now < line.at) {
            return Ok(None);
        }
        let line = self.lines.pop_front().unwrap();
        if line.text == "!laugh" {
            self.laugh_until = now + 1.8;
            Ok(Some((f64::from(rng.randf()) < 0.6).then(|| {
                LAUGHS[rng.randi() as usize % LAUGHS.len()].to_owned()
            })))
        } else {
            Ok(Some(Some(line.text)))
        }
    }

    pub fn end(&mut self, now: f64, rng: &mut SimulationRandom) -> Result<u64, &'static str> {
        if !self.valid() || !time(now) || !time(now + 12.0) {
            return Err("invalid downtime end");
        }
        self.activity = 0;
        self.lines.clear();
        self.laugh_until = 0.0;
        let partner = self.partner;
        self.partner = 0;
        self.next = now + f64::from(rng.randf_range(5.0, 12.0));
        Ok(partner)
    }

    pub fn checkpoint(&self) -> Vec<u8> {
        let mut out = Writer::new(b"FLID\x01\0\0\0");
        out.f64(self.calm);
        out.byte(self.activity);
        out.f64(self.until);
        out.f64(self.next);
        out.u64(self.partner);
        out.f64(self.laugh_until);
        out.u32(self.lines.len() as u32);
        for line in &self.lines {
            out.f64(line.at);
            out.bytes(line.text.as_bytes());
        }
        out.0
    }
    pub fn restore(bytes: &[u8]) -> Result<Self, &'static str> {
        let mut input = Reader::new(bytes, b"FLID\x01\0\0\0")?;
        let mut state = Self {
            calm: input.f64()?,
            activity: input.byte()?,
            until: input.f64()?,
            next: input.f64()?,
            partner: input.u64()?,
            laugh_until: input.f64()?,
            lines: VecDeque::new(),
        };
        let count = input.u32()?;
        if count > 128 {
            return Err("too many conversation lines");
        }
        for _ in 0..count {
            state.lines.push_back(Line {
                at: input.f64()?,
                text: std::str::from_utf8(input.bytes(4096)?)
                    .map_err(|_| "invalid speech text")?
                    .into(),
            });
        }
        input.finish()?;
        state
            .valid()
            .then_some(state)
            .ok_or("invalid downtime checkpoint")
    }
}

pub fn select_mate(actor: u64, team: i32, nearby: &[Mate]) -> Result<Option<u64>, &'static str> {
    if actor == 0
        || !id(actor)
        || nearby.len() > 100_000
        || nearby
            .iter()
            .any(|m| m.id == 0 || !id(m.id) || !time(m.calm))
    {
        return Err("invalid nearby conversation partners");
    }
    Ok(nearby
        .iter()
        .find(|m| {
            m.id != actor
                && m.team == team
                && m.life == Life::Alive
                && !m.chatting
                && m.calm >= 5.0
                && m.free
                && !m.moving
        })
        .map(|m| m.id))
}

pub fn chat_yaw(
    position: Vector3,
    other: Vector3,
    yaw: f64,
    dt: f64,
    mount: Option<(Vector3, f64)>,
) -> Result<f64, &'static str> {
    if !point(position)
        || !point(other)
        || !time(yaw)
        || !dt.is_finite()
        || !(0.0..=10.0).contains(&dt)
        || mount.is_some_and(|(p, r)| !point(p) || !r.is_finite() || !(0.0..=1000.0).contains(&r))
    {
        return Err("invalid conversation facing");
    }
    let d = other - position;
    let d = Vector3::new(d.x, 0.0, d.z);
    Ok(if f64::from(d.length()) > 0.3 {
        turn_yaw(yaw, normalized(d), position, dt, 4.0, mount)
    } else {
        yaw
    })
}

const BANTER: &[&[&[&str]]] = &[
    &[
        &[
            "%s, you snore like a diesel generator.",
            "Better than your singing in the shower.",
        ],
        &[
            "Who made this coffee? It's mud.",
            "That IS mud. Coffee ran out Tuesday.",
        ],
        &[
            "Two more weeks and I'm home.",
            "You said that two months ago, %s.",
        ],
        &[
            "Nice shooting yesterday, %s. You almost hit the ground.",
            "At least I hit something. You hit the sergeant's truck.",
        ],
        &[
            "Bet you a ration bar it rains tonight.",
            "You already owe me six ration bars.",
        ],
        &["Hey %s, new haircut?", "It's called a helmet, genius."],
        &[
            "Remind me why I signed up?",
            "The free travel and the fancy hats.",
        ],
        &["You hear that?", "...No.", "Exactly. Too quiet."],
        &[
            "%s, you've been chewing that gum for three days.",
            "It's for luck. Hasn't failed me yet.",
        ],
        &[
            "I could murder a cheeseburger right now.",
            "Keep dreaming. Beans again.",
        ],
        &["Sarge says we move at dawn.", "Sarge says a lot of things."],
        &[
            "When this is over I'm sleeping for a week.",
            "When this is over you'll still be on watch, %s.",
        ],
        &[
            "Did you write your mom back?",
            "Did you write yours? She keeps writing to me.",
        ],
        &[
            "My boots have more holes than the enemy's plan.",
            "Your boots have more holes than your stories, %s.",
        ],
    ],
    &[
        &[
            "%s, your aim is worse than your cooking.",
            "My cooking kept you alive all winter!",
        ],
        &[
            "Who took my last cigarette?",
            "The wind, brother. The wind.",
        ],
        &[
            "When we win, I'm opening a tea shop.",
            "Who would buy your tea? It tastes like diesel.",
        ],
        &[
            "My cousin says the trucks come tonight.",
            "Your cousin said the war would be over last spring.",
        ],
        &["%s, you run like a goat.", "A goat that's still alive."],
        &[
            "This rifle is older than my grandfather.",
            "And it still shoots straighter than you, %s.",
        ],
        &[
            "I miss my mother's bread.",
            "Everyone misses your mother's bread.",
        ],
        &[
            "They say the foreigners have hot showers.",
            "Then let's go and borrow one.",
        ],
        &["Listen...", "What?", "Nothing. Good."],
        &["Did you fix the radio, %s?", "I hit it. It works now."],
        &[
            "You've been cleaning that rifle all day.",
            "Unlike yours, I want it to fire.",
        ],
        &[
            "One day they'll write songs about us.",
            "Not with your singing, %s.",
        ],
    ],
];

const LAUGHS: &[&str] = &[
    "Ha! Fair enough.",
    "Hah!",
    "Heh. Got me.",
    "Ha ha!",
    "Okay, okay.",
];

const BORED: &[&[&str]] = &[
    &[
        "So quiet...",
        "I'm so bored.",
        "Wake me if something happens.",
        "Anyone got a deck of cards?",
        "My feet are killing me.",
    ],
    &[
        "Too quiet.",
        "Wake me when they come.",
        "Anyone have tea?",
        "My back hurts.",
        "Still nothing.",
    ],
];
