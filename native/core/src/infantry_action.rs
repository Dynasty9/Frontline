//! Typed action state and completion decisions; actor effects apply in the returned order.
use crate::infantry_pose::Posture;
use crate::state_codec::{Reader, Writer};
use crate::vector::Vector3;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
#[repr(u8)]
pub enum Round {
    Frag,
    Smoke,
    HighExplosive,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Throw {
    pub position: Vector3,
    pub round: Round,
    pub fuse: f64,
}

#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub enum Action {
    #[default]
    None,
    Throw(Throw),
    Rethrow {
        grenade: u64,
        position: Vector3,
    },
    ThrowIn {
        position: Vector3,
        fuse: f64,
    },
    Kick {
        grenade: u64,
        velocity: Vector3,
    },
    DoorKick {
        door: u64,
        position: Vector3,
    },
    Cook,
    Melee {
        target: u64,
    },
    Pickup {
        grenade: u64,
    },
    Launch {
        target: u64,
    },
    LaunchDrone {
        target: u64,
    },
    Mortar {
        position: Vector3,
        round: Round,
    },
}

#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct ActionState {
    pub current: Action,
    pub remaining: f64,
    pub queued_throw: Option<Throw>,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Gesture {
    Throw,
    Kick,
    Cook,
    Melee,
    Pickup,
    Launch,
}

#[derive(Clone, Copy, Debug)]
pub struct Related {
    pub id: u64,
    pub position: Vector3,
    pub gone: bool,
    pub holder: u64,
}

#[derive(Clone, Copy, Debug)]
pub struct Context {
    pub actor: u64,
    pub position: Vector3,
    pub related: Option<Related>,
}

#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct Pose {
    pub posture: Option<Posture>,
    pub yaw: Option<f64>,
}

#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct Completion {
    pub effect: Action,
    pub begin_throw: bool,
    pub duck_after: bool,
}

fn point(p: Vector3) -> bool {
    p.is_finite() && p.abs().max_element() <= 1_000_000.0
}
fn id(id: u64) -> bool {
    id <= i64::MAX as u64
}
fn time(t: f64) -> bool {
    t.is_finite() && t.abs() <= 1e12
}
fn fuse(t: f64) -> bool {
    t.is_finite() && (0.0..=3600.0).contains(&t)
}
fn facing(position: Vector3, target: Vector3) -> Option<f64> {
    let d = target - position;
    let d = Vector3::new(d.x, 0.0, d.z);
    (f64::from(d.length_squared()) > 0.0001)
        .then(|| f64::from(libm::atan2(-f64::from(d.x), -f64::from(d.z)) as f32))
}

impl Throw {
    pub fn valid(self) -> bool {
        point(self.position) && self.round != Round::HighExplosive && fuse(self.fuse)
    }
}
impl Context {
    fn valid(self) -> bool {
        self.actor > 0
            && id(self.actor)
            && point(self.position)
            && self
                .related
                .is_none_or(|r| r.id > 0 && id(r.id) && point(r.position) && id(r.holder))
    }
    fn get(self, wanted: u64) -> Option<Related> {
        self.related.filter(|r| r.id == wanted)
    }
}
impl Action {
    pub fn valid(self) -> bool {
        match self {
            Self::None | Self::Cook => true,
            Self::Throw(t) => t.valid(),
            Self::ThrowIn { position, fuse: f } => point(position) && fuse(f),
            Self::Rethrow { grenade, position } => id(grenade) && point(position),
            Self::Kick { grenade, velocity } => id(grenade) && point(velocity),
            Self::DoorKick { door, position } => id(door) && point(position),
            Self::Melee { target } | Self::Launch { target } | Self::LaunchDrone { target } => {
                id(target)
            }
            Self::Pickup { grenade } => id(grenade),
            Self::Mortar { position, round } => point(position) && round != Round::Frag,
        }
    }

    pub fn gesture(self) -> Option<Gesture> {
        Some(match self {
            Self::None => return None,
            Self::Throw(_) | Self::Rethrow { .. } | Self::ThrowIn { .. } => Gesture::Throw,
            Self::Kick { .. } | Self::DoorKick { .. } => Gesture::Kick,
            Self::Cook => Gesture::Cook,
            Self::Melee { .. } => Gesture::Melee,
            Self::Pickup { .. } => Gesture::Pickup,
            Self::Launch { .. } | Self::LaunchDrone { .. } | Self::Mortar { .. } => Gesture::Launch,
        })
    }

    pub fn begin_yaw(self, context: Context) -> Result<Option<f64>, &'static str> {
        if !self.valid() || !context.valid() {
            return Err("invalid action start pose");
        }
        let target = match self {
            Self::Throw(t) => Some(t.position),
            Self::Rethrow { position, .. }
            | Self::ThrowIn { position, .. }
            | Self::DoorKick { position, .. }
            | Self::Mortar { position, .. } => Some(position),
            Self::Melee { target } | Self::Launch { target } | Self::LaunchDrone { target } => {
                context.get(target).map(|r| r.position)
            }
            _ => None,
        };
        Ok(target.and_then(|p| facing(context.position, p)))
    }

    pub fn pose(self, context: Context) -> Result<Pose, &'static str> {
        if !self.valid() || !context.valid() {
            return Err("invalid action pose");
        }
        let posture = match self {
            Self::Mortar { .. } | Self::Launch { .. } => Some(Posture::Crouch),
            Self::Kick { .. }
            | Self::DoorKick { .. }
            | Self::Throw(_)
            | Self::Rethrow { .. }
            | Self::ThrowIn { .. } => Some(Posture::Stand),
            _ => None,
        };
        let yaw = match self {
            Self::Launch { target } => context
                .get(target)
                .filter(|r| !r.gone)
                .and_then(|r| facing(context.position, r.position)),
            _ => None,
        };
        Ok(Pose { posture, yaw })
    }
}

impl ActionState {
    pub fn valid(self) -> bool {
        self.current.valid() && time(self.remaining) && self.queued_throw.is_none_or(Throw::valid)
    }

    pub fn begin(
        &mut self,
        action: Action,
        duration: f64,
    ) -> Result<Option<Gesture>, &'static str> {
        if !self.valid() || !action.valid() || !fuse(duration) {
            return Err("invalid infantry action");
        }
        self.current = action;
        self.remaining = duration;
        Ok(action.gesture())
    }

    pub fn advance(&mut self, dt: f64) -> Result<bool, &'static str> {
        if !self.valid()
            || !dt.is_finite()
            || !(0.0..=10.0).contains(&dt)
            || !time(self.remaining - dt)
        {
            return Err("invalid action duration");
        }
        self.remaining -= dt;
        Ok(self.remaining <= 0.0)
    }

    pub fn finish(&mut self, context: Context) -> Result<Completion, &'static str> {
        if !self.valid() || !context.valid() {
            return Err("invalid action completion");
        }
        let action = self.current;
        self.current = Action::None;
        let mut out = Completion::default();
        out.effect = match action {
            Action::Cook => {
                if let Some(throw) = self.queued_throw.take() {
                    out.begin_throw = true;
                    Action::Throw(throw)
                } else {
                    Action::None
                }
            }
            Action::Kick { grenade, .. } => {
                out.duck_after = true;
                if context.get(grenade).is_some_and(|r| {
                    let d = r.position - context.position;
                    !r.gone
                        && r.holder == 0
                        && f64::from(Vector3::new(d.x, 0.0, d.z).length()) < 1.4
                }) {
                    action
                } else {
                    Action::None
                }
            }
            Action::Pickup { grenade } | Action::Rethrow { grenade, .. } => {
                if context
                    .get(grenade)
                    .is_some_and(|r| !r.gone && r.holder == context.actor)
                {
                    action
                } else {
                    Action::None
                }
            }
            Action::DoorKick { door, .. } => {
                if context.get(door).is_some_and(|r| !r.gone) {
                    action
                } else {
                    Action::None
                }
            }
            Action::Launch { target } | Action::LaunchDrone { target } => {
                if context.get(target).is_some_and(|r| !r.gone) {
                    action
                } else {
                    Action::None
                }
            }
            Action::Melee { target } => Action::Melee {
                target: context.get(target).map_or(0, |r| r.id),
            },
            _ => action,
        };
        Ok(out)
    }

    pub fn checkpoint(self) -> Vec<u8> {
        let mut out = Writer::new(b"FLAC\x01\0\0\0");
        write_action(&mut out, self.current);
        out.f64(self.remaining);
        out.byte(u8::from(self.queued_throw.is_some()));
        if let Some(t) = self.queued_throw {
            write_throw(&mut out, t);
        }
        out.0
    }

    pub fn restore(bytes: &[u8]) -> Result<Self, &'static str> {
        let mut input = Reader::new(bytes, b"FLAC\x01\0\0\0")?;
        let current = read_action(&mut input)?;
        let remaining = input.f64()?;
        let queued_throw = if input.boolean()? {
            Some(read_throw(&mut input)?)
        } else {
            None
        };
        input.finish()?;
        let state = Self {
            current,
            remaining,
            queued_throw,
        };
        if !state.valid() {
            return Err("invalid action checkpoint");
        }
        Ok(state)
    }
}

fn write_throw(out: &mut Writer, t: Throw) {
    out.point(t.position);
    out.byte(t.round as u8);
    out.f64(t.fuse);
}
fn read_round(input: &mut Reader<'_>) -> Result<Round, &'static str> {
    match input.byte()? {
        0 => Ok(Round::Frag),
        1 => Ok(Round::Smoke),
        2 => Ok(Round::HighExplosive),
        _ => Err("invalid action round"),
    }
}
fn read_throw(input: &mut Reader<'_>) -> Result<Throw, &'static str> {
    Ok(Throw {
        position: input.point()?,
        round: read_round(input)?,
        fuse: input.f64()?,
    })
}
fn write_action(out: &mut Writer, a: Action) {
    match a {
        Action::None => out.byte(0),
        Action::Throw(t) => {
            out.byte(1);
            write_throw(out, t);
        }
        Action::Rethrow { grenade, position } => {
            out.byte(2);
            out.u64(grenade);
            out.point(position);
        }
        Action::ThrowIn { position, fuse } => {
            out.byte(3);
            out.point(position);
            out.f64(fuse);
        }
        Action::Kick { grenade, velocity } => {
            out.byte(4);
            out.u64(grenade);
            out.point(velocity);
        }
        Action::DoorKick { door, position } => {
            out.byte(5);
            out.u64(door);
            out.point(position);
        }
        Action::Cook => out.byte(6),
        Action::Melee { target } => {
            out.byte(7);
            out.u64(target);
        }
        Action::Pickup { grenade } => {
            out.byte(8);
            out.u64(grenade);
        }
        Action::Launch { target } => {
            out.byte(9);
            out.u64(target);
        }
        Action::LaunchDrone { target } => {
            out.byte(10);
            out.u64(target);
        }
        Action::Mortar { position, round } => {
            out.byte(11);
            out.point(position);
            out.byte(round as u8);
        }
    }
}
fn read_action(input: &mut Reader<'_>) -> Result<Action, &'static str> {
    Ok(match input.byte()? {
        0 => Action::None,
        1 => Action::Throw(read_throw(input)?),
        2 => Action::Rethrow {
            grenade: input.u64()?,
            position: input.point()?,
        },
        3 => Action::ThrowIn {
            position: input.point()?,
            fuse: input.f64()?,
        },
        4 => Action::Kick {
            grenade: input.u64()?,
            velocity: input.point()?,
        },
        5 => Action::DoorKick {
            door: input.u64()?,
            position: input.point()?,
        },
        6 => Action::Cook,
        7 => Action::Melee {
            target: input.u64()?,
        },
        8 => Action::Pickup {
            grenade: input.u64()?,
        },
        9 => Action::Launch {
            target: input.u64()?,
        },
        10 => Action::LaunchDrone {
            target: input.u64()?,
        },
        11 => Action::Mortar {
            position: input.point()?,
            round: read_round(input)?,
        },
        _ => return Err("invalid action tag"),
    })
}
