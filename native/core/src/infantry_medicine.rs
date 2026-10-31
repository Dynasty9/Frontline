//! Rescue, treatment and escort decisions; shared casualty ownership stays with the actor world.
use crate::path_planner::PathPlanner;
use crate::state_codec::{Reader, Writer};
use crate::vector::{normalized, turn_yaw, Vector3};

const SCHEMA: &[u8; 8] = b"FLMD\x01\0\0\0";

#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct Treatment {
    pub phase: u8,
    pub timer: f64,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Rescue {
    Cancel,
    Approach { repath: bool },
    Claim,
    Drag,
    Treat,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Heal {
    Cancel,
    Approach { repath: bool },
    Start,
    Treat,
}

fn scalar(v: f64) -> bool {
    v.is_finite() && v.abs() <= 1e12
}
fn point(p: Vector3) -> bool {
    p.is_finite() && p.abs().max_element() <= 1_000_000.0
}
fn flat(p: Vector3) -> Vector3 {
    Vector3::new(p.x, 0.0, p.z)
}

pub fn heal_time(rate: f64, medicine: bool) -> Result<f64, &'static str> {
    if !rate.is_finite() || !(0.000001..=1_000_000.0).contains(&rate) {
        return Err("invalid medical training");
    }
    Ok(8.0 / rate * if medicine { 0.67 } else { 1.0 })
}

impl Treatment {
    pub fn valid(self) -> bool {
        self.phase <= 2 && scalar(self.timer)
    }

    pub fn rescue(
        &mut self,
        patient_valid: bool,
        position: Vector3,
        patient: Vector3,
        moving: bool,
        goal: Vector3,
    ) -> Result<Rescue, &'static str> {
        if !self.valid() || ![position, patient, goal].into_iter().all(point) {
            return Err("invalid rescue state");
        }
        if !patient_valid {
            return Ok(Rescue::Cancel);
        }
        Ok(match self.phase {
            0 => {
                if f64::from(flat(patient - position).length()) < 1.2 {
                    self.phase = 1;
                    Rescue::Claim
                } else {
                    Rescue::Approach {
                        repath: !moving || f64::from(patient.distance(goal)) > 1.5,
                    }
                }
            }
            1 => Rescue::Drag,
            _ => Rescue::Treat,
        })
    }

    /// Called after the movement request or dragging step and its casualty-pose update.
    pub fn finish_drag(&mut self, moving: bool, duration: f64) -> Result<bool, &'static str> {
        if !self.valid() || !scalar(duration) || duration < 0.0 {
            return Err("invalid drag completion");
        }
        if moving {
            return Ok(false);
        }
        self.phase = 2;
        self.timer = duration;
        Ok(true)
    }

    pub fn heal(
        &mut self,
        patient_valid: bool,
        position: Vector3,
        patient: Vector3,
        moving: bool,
        duration: f64,
    ) -> Result<Heal, &'static str> {
        if !self.valid()
            || !point(position)
            || !point(patient)
            || !scalar(duration)
            || duration < 0.0
        {
            return Err("invalid healing state");
        }
        if !patient_valid {
            return Ok(Heal::Cancel);
        }
        Ok(if self.phase == 0 {
            if f64::from(flat(patient - position).length()) < 1.4 {
                self.phase = 1;
                self.timer = duration * 0.6;
                Heal::Start
            } else {
                Heal::Approach { repath: !moving }
            }
        } else {
            Heal::Treat
        })
    }

    pub fn treat(&mut self, dt: f64) -> Result<bool, &'static str> {
        if !self.valid() || !dt.is_finite() || !(0.0..=10.0).contains(&dt) {
            return Err("invalid treatment step");
        }
        self.timer -= dt;
        Ok(self.timer <= 0.0)
    }

    pub fn checkpoint(self) -> Vec<u8> {
        let mut w = Writer::new(SCHEMA);
        w.byte(self.phase);
        w.f64(self.timer);
        w.0
    }
    pub fn restore(bytes: &[u8]) -> Result<Self, &'static str> {
        let mut r = Reader::new(bytes, SCHEMA)?;
        let state = Self {
            phase: r.byte()?,
            timer: r.f64()?,
        };
        r.finish()?;
        if !state.valid() {
            return Err("invalid treatment checkpoint");
        }
        Ok(state)
    }
}

#[derive(Clone, Copy, Debug)]
pub struct EscortInput {
    pub position: Vector3,
    pub yaw: f64,
    pub rescuer: Vector3,
    pub threat: Vector3,
    pub dt: f64,
    pub mount: Option<(Vector3, f64)>,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct EscortPose {
    pub position: Vector3,
    pub yaw: f64,
    pub backwards: bool,
    pub walking: bool,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct DragPose {
    pub yaw: f64,
    pub patient: Vector3,
}

pub fn drag_pose(
    position: Vector3,
    yaw: f64,
    last_direction: Vector3,
    dt: f64,
    mount: Option<(Vector3, f64)>,
) -> Result<DragPose, &'static str> {
    if !point(position)
        || !point(last_direction)
        || !scalar(yaw)
        || !dt.is_finite()
        || !(0.0..=10.0).contains(&dt)
        || mount.is_some_and(|(p, speed)| {
            !point(p) || !speed.is_finite() || !(0.0..=std::f64::consts::TAU).contains(&speed)
        })
    {
        return Err("invalid casualty dragging pose");
    }
    let yaw = turn_yaw(yaw, -last_direction, position, dt, 12.0, mount);
    let direction = Vector3::new(-libm::sin(yaw) as f32, 0.0, -libm::cos(yaw) as f32);
    Ok(DragPose {
        yaw,
        patient: flat(position + direction * 1.05),
    })
}

pub fn escort(i: EscortInput, nav: &PathPlanner) -> Result<EscortPose, &'static str> {
    if ![i.position, i.rescuer, i.threat].into_iter().all(point)
        || !scalar(i.yaw)
        || !i.dt.is_finite()
        || !(0.0..=10.0).contains(&i.dt)
        || i.mount.is_some_and(|(p, speed)| {
            !point(p) || !speed.is_finite() || !(0.0..=std::f64::consts::TAU).contains(&speed)
        })
    {
        return Err("invalid escort movement");
    }
    let mut side = normalized(i.threat.cross(Vector3::Y));
    if side.dot(flat(i.position - i.rescuer)) < 0.0 {
        side = -side;
    }
    let want = i.rescuer + side * 1.6 + i.threat * 0.9;
    let delta = flat(want - i.position);
    let distance = f64::from(delta.length());
    let speed = if distance > 3.0 { 4.4 } else { 1.3 };
    let next = i.position + normalized(delta) * distance.min(speed * i.dt) as f32;
    let walking = distance > 0.2;
    let position = if walking && nav.kind_at(next, false) != 3 {
        next
    } else {
        i.position
    };
    Ok(EscortPose {
        position,
        yaw: turn_yaw(i.yaw, i.threat, position, i.dt, 8.0, i.mount),
        backwards: walking && normalized(delta).dot(i.threat) < 0.0,
        walking,
    })
}

pub fn safe_anchor(
    patient: Vector3,
    away: Vector3,
    squad_order: Option<Vector3>,
    nav: &PathPlanner,
) -> Result<Vector3, &'static str> {
    if !point(patient) || !point(away) || squad_order.is_some_and(|p| !point(p)) {
        return Err("invalid casualty shelter anchor");
    }
    let mut anchor = patient + away * 11.0;
    if let Some(order) = squad_order {
        let offset = flat(order - patient);
        if f64::from(offset.length()) < 22.0 && offset.dot(away) > 0.0 {
            anchor = order;
        }
    }
    nav.nearest_walkable(anchor)
        .ok_or("invalid casualty shelter ground")
}
