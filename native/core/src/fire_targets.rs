//! Shared mortar and FPV target selection reads the live actors and retained spatial cells.
use crate::actors::{Actor, Actors};
use crate::infantry::Infantry;
use crate::infantry_vitals::Life;
use crate::spatial::{SpatialIndex, UNIT_CELL};
use crate::vector::Vector3;
use crate::vehicle::Vehicle;

fn distance(a: Vector3, b: Vector3) -> f64 {
    let d = a - b;
    f64::from(Vector3::new(d.x, 0.0, d.z).length())
}
fn valid(team: i8, origin: Vector3, radius: f64, units: &SpatialIndex) -> bool {
    (0..=1).contains(&team)
        && origin.is_finite()
        && origin.abs().max_element() <= 1_000_000.0
        && radius.is_finite()
        && (0.0..=1_000_000.0).contains(&radius)
        && units.cell_size() == UNIT_CELL
}
fn neighbors<'a>(
    actors: &'a Actors,
    units: &'a SpatialIndex,
    position: Vector3,
    radius: f64,
) -> Result<impl Iterator<Item = &'a Infantry> + 'a, &'static str> {
    Ok(units
        .candidates(position, radius)?
        .filter_map(|id| actors.soldier(id))
        .filter(move |s| {
            let dx = f64::from(s.motion.position.x) - f64::from(position.x);
            let dz = f64::from(s.motion.position.z) - f64::from(position.z);
            dx * dx + dz * dz <= radius * radius
        }))
}

pub fn mortar(
    actors: &Actors,
    units: &SpatialIndex,
    owned_structures: &[u32],
    team: i8,
    origin: Vector3,
    minimum: f64,
    maximum: f64,
) -> Result<Option<Vector3>, &'static str> {
    if !valid(team, origin, maximum, units)
        || !minimum.is_finite()
        || !(0.0..=maximum).contains(&minimum)
        || owned_structures.len() > 100_000
    {
        return Err("invalid mortar target query");
    }
    let mut best = None;
    let mut score = 6.0;
    for actor in actors.iter_kind(crate::entities::Kind::Soldier) {
        let Actor::Soldier(s) = actor else {
            continue;
        };
        if s.identity.team < 0
            || s.identity.team == team
            || s.vitals.life != Life::Alive
            || s.identity.visible & (1 << team) == 0
        {
            continue;
        }
        let d = distance(s.motion.position, origin);
        if d < minimum || d > maximum {
            continue;
        }
        let mut count = 0;
        let mut danger = false;
        for other in neighbors(actors, units, s.motion.position, 12.0)? {
            if other.vitals.life != Life::Alive {
                continue;
            }
            if other.identity.team == team {
                if distance(other.motion.position, s.motion.position) < 8.0 {
                    danger = true;
                    break;
                }
                continue;
            }
            if distance(other.motion.position, s.motion.position) < 6.0 {
                count += 1;
            }
        }
        if danger {
            continue;
        }
        let candidate = count as f64 * 6.0
            + if s.emplacement.structure != 0 {
                8.0
            } else {
                0.0
            }
            + if s.cover.at_cover { 4.0 } else { 0.0 }
            - d * 0.02;
        if candidate > score {
            score = candidate;
            best = Some(s.motion.position);
        }
    }
    // Ownership changes can append a building later than its original registration.
    for &id in owned_structures {
        let Some(s) = actors.structure(id) else {
            continue;
        };
        if s.team < 0
            || s.team == team
            || !s.built
            || s.seen & (1 << team) == 0
            || !matches!(
                s.kind.as_str(),
                "mg_nest" | "hmg_nest" | "mortar_pit" | "at_post" | "bunker" | "watchtower"
            )
        {
            continue;
        }
        let d = distance(s.position, origin);
        if d < minimum || d > maximum {
            continue;
        }
        let candidate = 16.0 - d * 0.02;
        if candidate > score {
            score = candidate;
            best = Some(s.position);
        }
    }
    Ok(best)
}

pub fn fpv(
    actors: &Actors,
    units: &SpatialIndex,
    team: i8,
    origin: Vector3,
    radius: f64,
    armor: impl Fn(&Vehicle) -> i32,
    bearer: impl Fn(&Infantry) -> bool,
) -> Result<Option<u32>, &'static str> {
    if !valid(team, origin, radius, units) {
        return Err("invalid FPV target query");
    }
    let mut best = None;
    let mut score = -1e9;
    for actor in actors.iter_kind(crate::entities::Kind::Vehicle) {
        let Actor::Vehicle(v) = actor else {
            continue;
        };
        if v.team < 0 || v.team == team {
            continue;
        }
        let d = distance(v.position, origin);
        if (v.visible & (1 << team) == 0 && d >= 150.0) || d > radius {
            continue;
        }
        let candidate = 120.0 - d * 0.2 + if armor(v) >= 2 { 40.0 } else { 0.0 };
        if candidate > score {
            score = candidate;
            best = Some(v.id);
        }
    }
    for actor in actors.iter_kind(crate::entities::Kind::Soldier) {
        let Actor::Soldier(s) = actor else {
            continue;
        };
        if s.identity.team < 0
            || s.identity.team == team
            || s.vitals.life != Life::Alive
            || bearer(s)
        {
            continue;
        }
        let d = distance(s.motion.position, origin);
        if (s.identity.visible & (1 << team) == 0 && d >= 150.0) || d > radius || d < 25.0 {
            continue;
        }
        let count = neighbors(actors, units, s.motion.position, 5.0)?
            .filter(|other| {
                other.identity.team == s.identity.team && other.vitals.life == Life::Alive
            })
            .count();
        if count < 2 && s.emplacement.structure == 0 {
            continue;
        }
        let candidate = count as f64 * 12.0 - d * 0.15
            + if s.emplacement.structure != 0 {
                25.0
            } else {
                0.0
            };
        if candidate > score {
            score = candidate;
            best = Some(s.identity.id);
        }
    }
    Ok(best)
}
