//! Fighting positions use the same collision world as sight and gunfire.
use crate::collision::CollisionWorld;
use crate::vector::{normalized, Vector3};
use glam::{Mat3, Vec2};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
#[repr(u8)]
pub enum AnchorKind {
    Over = 1,
    EdgeLeft = 2,
    EdgeRight = 3,
    Shelter = 4,
    Stack = 5,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Anchor {
    pub position: Vector3,
    pub normal: Vector3,
    pub height: f64,
    pub kind: AnchorKind,
}

#[derive(Clone, Copy, Debug)]
pub struct Part {
    pub position: Vector3,
    pub size: Vector3,
    pub yaw: f64,
    pub cover: bool,
    pub collision: bool,
    pub blocks_navigation: bool,
}

fn rotation(yaw: f64) -> Mat3 {
    let c = (yaw as f32).cos();
    let s = (yaw as f32).sin();
    Mat3::from_cols(
        Vector3::new(c, 0.0, -s),
        Vector3::Y,
        Vector3::new(s, 0.0, c),
    )
}

fn transform(basis: Mat3, p: Vector3) -> Vector3 {
    // Match Basis's row dot products, including the order of float rounding.
    let rows = basis.transpose();
    Vector3::new(rows.x_axis.dot(p), rows.y_axis.dot(p), rows.z_axis.dot(p))
}

pub fn generate(
    kind: &str,
    variant: i32,
    position: Vector3,
    yaw: f64,
    size: Vector3,
    parts: &[Part],
    map_half: f64,
) -> Result<Vec<Anchor>, &'static str> {
    let valid_point = |p: Vector3| p.is_finite() && p.abs().max_element() <= 1_000_000.0;
    if !valid_point(position)
        || !yaw.is_finite()
        || yaw.abs() > 1_000_000.0
        || !valid_point(size)
        || size.min_element() < 0.0
        || !map_half.is_finite()
        || !(2.0..=1_000_000.0).contains(&map_half)
        || parts.len() > 4096
        || parts.iter().any(|p| {
            !valid_point(p.position)
                || !p.size.is_finite()
                || p.size.min_element() < 0.0
                || p.size.max_element() > 8192.0
                || !p.yaw.is_finite()
                || p.yaw.abs() > 1_000_000.0
        })
    {
        return Err("invalid cover structure");
    }
    let mut anchors = Vec::new();
    if matches!(
        kind,
        "floor"
            | "roof"
            | "wire"
            | "mines"
            | "tank_trap"
            | "tunnel"
            | "helipad"
            | "tree"
            | "camo_net"
    ) {
        return Ok(anchors);
    }
    if parts
        .iter()
        .map(|p| f64::from(p.size.x) + f64::from(p.size.z))
        .sum::<f64>()
        > 100_000.0
    {
        return Err("cover geometry exceeds limit");
    }
    let basis = rotation(yaw);
    if kind == "trench" {
        let d = transform(basis, Vector3::new(size.x * 0.5, 0.0, 0.0));
        let mut a = position - d;
        let mut end = position + d;
        a.y = 0.0;
        end.y = 0.0;
        let ab = end - a;
        let length = ab.length();
        if length < 0.5 {
            return Ok(anchors);
        }
        let direction = Vector3::new(ab.x / length, ab.y / length, ab.z / length);
        let side = Vector3::new(-direction.z, 0.0, direction.x);
        let count = ((f64::from(length) / 1.25) as usize).max(1);
        if count > 500_000 {
            return Err("too many cover anchors");
        }
        for k in 0..count {
            let c = a + direction * (((k as f64 + 0.5) / count as f64 * f64::from(length)) as f32);
            for sign in [-1.0_f32, 1.0] {
                anchors.push(Anchor {
                    position: c + side * sign * ((0.72_f64 - 0.34) as f32),
                    normal: side * sign,
                    height: f64::from((0.34_f64 - (-1.2 + 0.15)) as f32),
                    kind: AnchorKind::Over,
                });
            }
        }
        return Ok(anchors);
    }
    let blockers: Vec<_> = parts
        .iter()
        .filter(|p| p.collision && p.blocks_navigation)
        .map(|p| {
            let center = position + transform(basis, p.position);
            let angle = yaw + p.yaw;
            let (s, c) = (angle.sin() as f32, angle.cos() as f32);
            (
                Vec2::new(center.x, center.z),
                Vec2::new(
                    (f64::from(p.size.x) * 0.5 + 0.25) as f32,
                    (f64::from(p.size.z) * 0.5 + 0.25) as f32,
                ),
                Vec2::new(c, -s),
                Vec2::new(s, c),
            )
        })
        .collect();
    let mut add = |mut p: Vector3,
                   normal: Vector3,
                   height: f64,
                   kind: AnchorKind|
     -> Result<(), &'static str> {
        p.y = 0.0;
        if f64::from(p.x.abs()) >= map_half - 2.0
            || f64::from(p.z.abs()) >= map_half - 2.0
            || blockers.iter().any(|(c, h, x, z)| {
                let delta = Vec2::new(p.x, p.z) - *c;
                delta.dot(*x).abs() <= h.x && delta.dot(*z).abs() <= h.y
            })
        {
            return Ok(());
        }
        if anchors.len() >= 1_000_000 {
            return Err("too many cover anchors");
        }
        anchors.push(Anchor {
            position: p,
            normal,
            height: f64::from(height as f32),
            kind,
        });
        Ok(())
    };
    for part in parts {
        if !part.cover || !part.collision {
            continue;
        }
        let bottom = f64::from(part.position.y) - f64::from(part.size.y) * 0.5;
        let mut top = f64::from(part.position.y) + f64::from(part.size.y) * 0.5;
        if bottom > 0.5 || top < 0.3 {
            continue;
        }
        if kind == "low_wall" && variant % 3 != 1 {
            top += 0.08;
        }
        let pr = rotation(part.yaw);
        let combined = Mat3::from_cols(
            transform(basis, pr.x_axis),
            transform(basis, pr.y_axis),
            transform(basis, pr.z_axis),
        );
        let base = Vector3::new(part.position.x, 0.0, part.position.z);
        for (nl, tl, hl, hd) in [
            (
                -Vector3::Z,
                Vector3::X,
                f64::from(part.size.x) * 0.5,
                f64::from(part.size.z) * 0.5,
            ),
            (
                Vector3::Z,
                -Vector3::X,
                f64::from(part.size.x) * 0.5,
                f64::from(part.size.z) * 0.5,
            ),
            (
                -Vector3::X,
                -Vector3::Z,
                f64::from(part.size.z) * 0.5,
                f64::from(part.size.x) * 0.5,
            ),
            (
                Vector3::X,
                Vector3::Z,
                f64::from(part.size.z) * 0.5,
                f64::from(part.size.x) * 0.5,
            ),
        ] {
            if hl < 0.4 {
                continue;
            }
            let normal = normalized(transform(combined, -nl));
            let tangent = normalized(transform(combined, tl));
            if top > 1.55 {
                for sign in [-1.0_f32, 1.0] {
                    let local = base
                        + transform(
                            pr,
                            nl * (hd + 0.5) as f32 + tl * sign * (hl - 0.35).max(0.0) as f32,
                        );
                    let edge = if normal.cross(Vector3::Y).dot(tangent * sign) > 0.0 {
                        AnchorKind::EdgeRight
                    } else {
                        AnchorKind::EdgeLeft
                    };
                    add(position + transform(basis, local), normal, top, edge)?;
                }
                let count = (((hl * 2.0 - 1.6) / 1.6) as i32).max(0) as usize;
                for (offset, kind) in [
                    (hd + 0.5, AnchorKind::Shelter),
                    (hd + 0.5 + 1.5, AnchorKind::Stack),
                ] {
                    for k in 0..count {
                        let t = ((k as f64 + 0.5) / count as f64 - 0.5) * (hl * 2.0 - 1.6);
                        let local = base + transform(pr, nl * offset as f32 + tl * t as f32);
                        add(position + transform(basis, local), normal, top, kind)?;
                    }
                }
            } else {
                let offset = if top < 0.62 {
                    1.02
                } else if top < 1.12 {
                    0.56
                } else {
                    0.46
                };
                let count = (((hl * 2.0 + 0.2) / 1.25) as usize).max(1);
                let usable = (hl * 2.0 - 0.6).max(0.0);
                for k in 0..count {
                    let t = ((k as f64 + 0.5) / count as f64 - 0.5) * usable;
                    let local = base + transform(pr, nl * (hd + offset) as f32 + tl * t as f32);
                    add(
                        position + transform(basis, local),
                        normal,
                        top,
                        AnchorKind::Over,
                    )?;
                }
            }
        }
    }
    Ok(anchors)
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
#[repr(u8)]
pub enum CoverType {
    Low = 1,
    Lean = 2,
    Hide = 3,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Evaluation {
    pub kind: CoverType,
    pub protection: f64,
    pub fire: bool,
    pub lean: Vector3,
    pub threat_direction: Vector3,
}

pub fn evaluate(
    collision: &mut CollisionWorld,
    anchor: Anchor,
    ground: f64,
    threats: &[Vector3],
    prone: bool,
) -> Result<Option<Evaluation>, &'static str> {
    let valid_point = |p: Vector3| p.is_finite() && p.abs().max_element() <= 1_000_000.0;
    if !valid_point(anchor.position)
        || !valid_point(anchor.normal)
        || !anchor.height.is_finite()
        || !(0.0..=1_000_000.0).contains(&anchor.height)
        || !ground.is_finite()
        || ground.abs() > 1_000_000.0
        || threats.len() > 4096
        || threats.iter().any(|p| !valid_point(*p))
    {
        return Err("invalid cover evaluation");
    }
    let Anchor {
        position,
        normal,
        height,
        kind,
    } = anchor;
    let hide_height = if prone || height < 0.8 {
        0.28
    } else if height < 1.12 {
        height - 0.2
    } else {
        1.0
    };
    let lean = match kind {
        AnchorKind::EdgeRight => normal.cross(Vector3::Y),
        AnchorKind::EdgeLeft => -normal.cross(Vector3::Y),
        _ => Vector3::ZERO,
    };
    let hidden = position + Vector3::new(0.0, (ground + hide_height) as f32, 0.0);
    let firing = match kind {
        AnchorKind::Over => {
            Some(position + normal * 0.2 + Vector3::new(0.0, (ground + height + 0.14) as f32, 0.0))
        }
        AnchorKind::EdgeLeft | AnchorKind::EdgeRight => {
            Some(position + lean * 0.75 + Vector3::new(0.0, (ground + 1.45) as f32, 0.0))
        }
        _ => None,
    };
    let mut protected = 0;
    let mut fire = false;
    let mut direction = Vector3::ZERO;
    for &threat in threats {
        let delta = threat - position;
        let to = Vector3::new(delta.x, 0.0, delta.z);
        if to.length() < 0.5 {
            continue;
        }
        let to = normalized(to);
        direction += to;
        if normal.dot(to) < 0.25 {
            continue;
        }
        if !collision
            .ray(hidden, threat, &[])
            .is_some_and(|hit| hidden.distance(hit.position) < 3.5)
        {
            continue;
        }
        protected += 1;
        // Once one firing lane is clear, further rays cannot change this answer.
        if !fire && firing.is_some_and(|p| collision.ray(p, threat, &[]).is_none()) {
            fire = true;
        }
    }
    if protected == 0 {
        return Ok(None);
    }
    Ok(Some(Evaluation {
        kind: match kind {
            AnchorKind::Over => CoverType::Low,
            AnchorKind::EdgeLeft | AnchorKind::EdgeRight if fire => CoverType::Lean,
            _ => CoverType::Hide,
        },
        protection: protected as f64 / threats.len() as f64,
        fire,
        lean,
        threat_direction: if f64::from(direction.length()) > 0.01 {
            normalized(direction)
        } else {
            normal
        },
    }))
}
