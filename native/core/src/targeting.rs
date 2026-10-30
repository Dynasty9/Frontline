//! Infantry contact evaluation. Candidate order and report order are gameplay state.
use crate::collision::CollisionWorld;
use crate::vector::{normalized, Vector3};
use crate::visibility::{Sight, Visibility};

#[derive(Clone, Copy, Debug)]
pub enum TargetKind {
    Infantry { downed: bool, machine_gunner: bool },
    Vehicle { armor: i32 },
    Other,
}

#[derive(Clone, Debug)]
pub struct Contact {
    pub id: u64,
    pub position: Vector3,
    pub kind: TargetKind,
    pub points: Vec<Vector3>,
    pub excluded: Vec<i64>,
}

#[derive(Clone, Copy, Debug)]
pub struct DroneContact {
    pub id: u64,
    pub position: Vector3,
    pub team: i32,
    pub dead: bool,
    pub diving: bool,
}

#[derive(Clone, Copy, Debug)]
pub struct Observer {
    pub position: Vector3,
    pub eye: Vector3,
    pub team: i32,
    pub current: u64,
    pub forced: u64,
    pub forced_structure: Option<Vector3>,
    pub weapon_range: f64,
    pub rockets: bool,
    pub armor_piercing: bool,
    pub mount_forward: Option<Vector3>,
    pub cache_obstruction: bool,
}

#[derive(Debug, Default, PartialEq)]
pub struct Scan {
    pub target: u64,
    pub visible: Vec<u64>,
    pub reported: usize,
    pub reused: usize,
}

fn valid_point(p: Vector3) -> bool {
    p.is_finite() && p.abs().max_element() <= 1_000_000.0
}
fn valid_id(id: u64) -> bool {
    id > 0 && id <= i64::MAX as u64
}
fn flat(p: Vector3) -> Vector3 {
    Vector3::new(p.x, 0.0, p.z)
}

pub fn scan(
    observer: Observer,
    contacts: &[Contact],
    drones: &[DroneContact],
    collision: &mut CollisionWorld,
    sight: &mut Visibility,
) -> Result<Scan, &'static str> {
    if !valid_point(observer.position)
        || !valid_point(observer.eye)
        || observer.current > i64::MAX as u64
        || observer.forced > i64::MAX as u64
        || observer.forced_structure.is_some_and(|p| !valid_point(p))
        || observer.mount_forward.is_some_and(|p| !valid_point(p))
        || !observer.weapon_range.is_finite()
        || !(0.0..=1_000_000.0).contains(&observer.weapon_range)
        || contacts.len() > 7
        || drones.len() > 100_000
        || contacts.iter().any(|c| {
            !valid_id(c.id)
                || !valid_point(c.position)
                || c.points.len() > 256
                || c.points.iter().any(|p| !valid_point(*p))
                || c.excluded.len() > 4096
                || c.excluded.iter().any(|id| *id < 0)
        })
        || drones
            .iter()
            .any(|d| !valid_id(d.id) || !valid_point(d.position))
    {
        return Err("invalid infantry scan");
    }
    let mut output = Scan::default();
    let mut best = -1e9;
    for contact in contacts {
        match sight.can_see(
            collision,
            observer.eye,
            contact.id,
            &contact.points,
            &contact.excluded,
            observer.cache_obstruction,
        ) {
            Some(Sight::Visible) => (),
            Some(Sight::ReusedObstruction) => {
                output.reused += 1;
                continue;
            }
            _ => continue,
        }
        output.visible.push(contact.id);
        let delta = contact.position - observer.position;
        if observer
            .mount_forward
            .is_some_and(|forward| f64::from(normalized(flat(delta)).dot(forward)) <= 1.3_f64.cos())
        {
            continue;
        }
        // GDScript squares the float-vector components using scalar doubles.
        let mut score = -(f64::from(delta.x).powi(2) + f64::from(delta.z).powi(2)).sqrt();
        match contact.kind {
            TargetKind::Infantry {
                downed,
                machine_gunner,
            } => {
                if downed {
                    score -= 35.0;
                }
                if machine_gunner {
                    score += 5.0;
                }
            }
            TargetKind::Vehicle { armor } => {
                if observer.rockets {
                    score += 30.0;
                } else if armor >= 2 && !observer.armor_piercing {
                    continue;
                } else if armor >= 1 && !observer.armor_piercing {
                    score -= 40.0;
                } else {
                    score -= 12.0;
                }
            }
            TargetKind::Other => (),
        }
        if contact.id == observer.current {
            score += 6.0;
        }
        if score > best {
            best = score;
            output.target = contact.id;
        }
    }
    output.reported = output.visible.len();
    for drone in drones {
        if drone.team == observer.team || drone.dead {
            continue;
        }
        let distance = f64::from(observer.position.distance(drone.position));
        if distance < 38.0
            && collision.ray(observer.eye, drone.position, &[]).is_none()
            && !sight.smoke_blocks(observer.eye, drone.position)
        {
            output.visible.push(drone.id);
            if distance < 30.0 || drone.diving {
                output.target = drone.id;
            }
        }
    }
    if observer.forced != 0
        && (output.visible.contains(&observer.forced)
            || observer.forced_structure.is_some_and(|p| {
                f64::from(flat(p - observer.position).length()) < observer.weapon_range
            }))
    {
        output.target = observer.forced;
    }
    Ok(output)
}
