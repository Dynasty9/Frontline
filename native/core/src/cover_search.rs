//! A complete cover search over numeric scene, terrain, navigation and occupancy data.
use crate::collision::CollisionWorld;
use crate::cover::{self, Anchor, AnchorKind, CoverType, Evaluation};
use crate::godot_sort::score_order;
use crate::path_planner::PathPlanner;
use crate::terrain::{Terrain, COVER, CRATER, RUBBLE, SOLID, TRENCH, WOODS};
use crate::vector::{normalized, Vector3};

#[derive(Clone, Debug)]
pub struct Structure {
    pub id: u64,
    pub built: bool,
    pub burn: f64,
    pub material: u8,
    pub positions: Vec<Anchor>,
}

#[derive(Clone, Copy, Debug)]
pub struct SquadClaim {
    pub id: u64,
    pub alive: bool,
    pub covering: bool,
    pub position: Vector3,
}

#[derive(Clone, Copy, Debug)]
pub struct NearbyClaim {
    pub id: u64,
    pub team: i32,
    pub alive: bool,
    pub gone: bool,
    pub position: Vector3,
    pub cover_position: Vector3,
    // Membership comes from the world's last spatial rebuild, not a fresh position hash.
    pub cell: [i32; 2],
}

#[derive(Clone, Copy, Debug)]
pub struct Input {
    pub id: u64,
    pub team: i32,
    pub position: Vector3,
    pub anchor: Vector3,
    pub radius: f64,
    pub grouped: bool,
    pub prone: bool,
    pub unarmed: bool,
    pub weapon_range: f64,
    pub current_structure: u64,
    pub current_anchor: i32,
}

pub struct Scene<'a> {
    pub terrain: &'a Terrain,
    pub navigation: &'a PathPlanner,
    pub collision: &'a mut CollisionWorld,
    pub heat: &'a [u8],
    pub deck: &'a [u8],
    pub structures: &'a [Structure],
    pub squad_claims: &'a [SquadClaim],
    pub nearby_claims: &'a [NearbyClaim],
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Choice {
    pub evaluation: Evaluation,
    pub position: Vector3,
    pub normal: Vector3,
    pub height: f64,
    pub material: u8,
    pub structure: u64,
    pub anchor: i32,
}

#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct SearchResult {
    pub choice: Option<Choice>,
    pub candidates: usize,
    pub evaluations: usize,
}

#[derive(Clone, Copy)]
struct Candidate {
    position: Vector3,
    structure: Option<(usize, usize)>,
}

fn point(p: Vector3) -> bool {
    p.is_finite() && p.abs().max_element() <= 1_000_000.0
}
fn id(id: u64) -> bool {
    id > 0 && id <= i64::MAX as u64
}
fn flat(p: Vector3) -> Vector3 {
    Vector3::new(p.x, 0.0, p.z)
}

impl Scene<'_> {
    fn valid(&self) -> bool {
        let heat_side = self.terrain.n.div_ceil(4) + 1;
        self.navigation.side() == self.terrain.n
            && (self.heat.is_empty() || self.heat.len() == heat_side * heat_side)
            && (self.deck.is_empty() || self.deck.len() == self.terrain.n * self.terrain.n)
            && self.structures.len() <= 100_000
            && self
                .structures
                .iter()
                .map(|s| s.positions.len())
                .sum::<usize>()
                <= 1_000_000
            && self.structures.iter().all(|s| {
                id(s.id)
                    && s.burn.is_finite()
                    && s.material <= 3
                    && s.positions.len() <= 100_000
                    && s.positions.iter().all(|p| {
                        point(p.position)
                            && point(p.normal)
                            && p.height.is_finite()
                            && (0.0..=1_000_000.0).contains(&p.height)
                    })
            })
            && self.squad_claims.len() <= 100_000
            && self.nearby_claims.len() <= 100_000
            && self
                .squad_claims
                .iter()
                .all(|s| id(s.id) && point(s.position))
            && self.nearby_claims.iter().all(|s| {
                id(s.id)
                    && (-1..=1).contains(&s.team)
                    && point(s.position)
                    && point(s.cover_position)
                    && s.cell.iter().all(|v| i64::from(*v).abs() <= 1_000_000)
            })
    }

    fn hot(&self, p: Vector3) -> bool {
        if self.heat.is_empty() {
            return false;
        }
        let side = self.terrain.n.div_ceil(4) as i64 + 1;
        let x = ((f64::from(p.x) + self.terrain.half()) / 4.0) as i64;
        let z = ((f64::from(p.z) + self.terrain.half()) / 4.0) as i64;
        x >= 0 && z >= 0 && x < side && z < side && self.heat[(z * side + x) as usize] > 0
    }

    fn ground(&self, p: Vector3) -> f64 {
        self.terrain.ground_y(
            p,
            !self.deck.is_empty() && self.deck[self.terrain.index(p)] == 1,
        )
    }

    fn claimed(&self, p: Vector3, soldier: Input) -> bool {
        if self.squad_claims.iter().any(|s| {
            s.id != soldier.id && s.alive && s.covering && flat(s.position - p).length() < 1.0
        }) {
            return true;
        }
        let first = [p.x, p.z].map(|v| ((f64::from(v) - 1.3) / 12.0).floor() as i32);
        let last = [p.x, p.z].map(|v| ((f64::from(v) + 1.3) / 12.0).floor() as i32);
        self.nearby_claims.iter().any(|s| {
            if s.id == soldier.id
                || s.team != soldier.team
                || !s.alive
                || s.gone
                || s.cell[0] < first[0]
                || s.cell[0] > last[0]
                || s.cell[1] < first[1]
                || s.cell[1] > last[1]
            {
                return false;
            }
            let dx = f64::from(s.position.x) - f64::from(p.x);
            let dz = f64::from(s.position.z) - f64::from(p.z);
            dx * dx + dz * dz <= 1.3 * 1.3
                && (flat(s.cover_position - p).length() < 1.0
                    || flat(s.position - p).length() < 0.8)
        })
    }
}

pub fn find(
    input: Input,
    threats: &[Vector3],
    scene: &mut Scene<'_>,
) -> Result<SearchResult, &'static str> {
    if !id(input.id)
        || !(-1..=1).contains(&input.team)
        || !point(input.position)
        || !point(input.anchor)
        || !input.radius.is_finite()
        || !(0.0..=512.0).contains(&input.radius)
        || !input.weapon_range.is_finite()
        || !(0.0..=1_000_000.0).contains(&input.weapon_range)
        || input.current_structure > i64::MAX as u64
        || input.current_anchor < -1
        || threats.len() > 4096
        || threats.iter().any(|p| !point(*p))
        || !scene.valid()
    {
        return Err("invalid cover search input");
    }
    if threats.is_empty() {
        return Ok(SearchResult::default());
    }
    let radius = if input.grouped {
        input.radius.min(3.0)
    } else {
        input.radius
    };
    let r2 = radius * radius;
    let mut candidates = Vec::new();
    let mut scores = Vec::new();
    for (si, s) in scene.structures.iter().enumerate() {
        if !s.built || s.burn > 0.0 {
            continue;
        }
        for (ai, a) in s.positions.iter().enumerate() {
            let p = a.position;
            let distance = f64::from(flat(p - input.anchor).length_squared());
            if distance <= r2 && !scene.hot(p) {
                candidates.push(Candidate {
                    position: p,
                    structure: Some((si, ai)),
                });
                scores.push(distance + f64::from(flat(p - input.position).length_squared()) * 0.3);
            }
        }
    }
    let terrain = scene.terrain;
    let ac = terrain.index(input.anchor);
    let ax = ac % terrain.n;
    let az = ac / terrain.n;
    let ri = radius as usize;
    for z in (az.saturating_sub(ri)..terrain.n.min(az + ri + 1)).step_by(2) {
        for x in (ax.saturating_sub(ri)..terrain.n.min(ax + ri + 1)).step_by(2) {
            let i = z * terrain.n + x;
            if terrain.layers[COVER][i] < 2
                || terrain.layers[SOLID][i] > 0
                || terrain.layers[TRENCH][i] > 0
                || terrain.layers[CRATER][i] == 0
                    && terrain.layers[RUBBLE][i] == 0
                    && terrain.layers[WOODS][i] == 0
            {
                continue;
            }
            let p = terrain.center(i);
            let distance = f64::from(flat(p - input.anchor).length_squared());
            if distance <= r2 && scene.navigation.kind_at(p, false) != 3 && !scene.hot(p) {
                candidates.push(Candidate {
                    position: p,
                    structure: None,
                });
                scores.push(
                    distance + f64::from(flat(p - input.position).length_squared()) * 0.3 + 4.0,
                );
            }
        }
    }
    let mut result = SearchResult {
        candidates: candidates.len(),
        ..Default::default()
    };
    let mut best_score = -1e9;
    for index in score_order(&scores) {
        if result.evaluations >= 20 {
            break;
        }
        let c = candidates[index];
        let normal = c.structure.map_or(Vector3::ZERO, |(si, ai)| {
            scene.structures[si].positions[ai].normal
        });
        if input.grouped {
            let approach = c.position - normal * 0.8;
            if f64::from(flat(c.position - input.anchor).length_squared()) > r2
                || scene.navigation.kind_at(approach, false) == 3
                || !scene.navigation.line_free(input.anchor, approach, false)
            {
                continue;
            }
        }
        let ground = scene.ground(c.position);
        let (choice, stack) = if let Some((si, ai)) = c.structure {
            let s = &scene.structures[si];
            let a = s.positions[ai];
            if scene.navigation.kind_at(c.position, false) == 3
                && scene
                    .navigation
                    .nearest_walkable(c.position)
                    .is_none_or(|p| f64::from(flat(p - c.position).length()) >= 1.6)
            {
                continue;
            }
            result.evaluations += 1;
            let Some(evaluation) =
                cover::evaluate(scene.collision, a, ground, threats, input.prone)?
            else {
                continue;
            };
            (
                Choice {
                    evaluation,
                    position: c.position,
                    normal,
                    height: a.height,
                    material: if a.kind == AnchorKind::Stack {
                        s.material.saturating_sub(1)
                    } else {
                        s.material
                    },
                    structure: s.id,
                    anchor: ai as i32,
                },
                a.kind == AnchorKind::Stack,
            )
        } else {
            let ti = terrain.index(c.position);
            let height = if terrain.layers[CRATER][ti] > 0 {
                0.45
            } else if terrain.layers[RUBBLE][ti] > 0 {
                0.75
            } else {
                0.0
            };
            let direction = normalized(flat(threats[0] - c.position));
            (
                Choice {
                    evaluation: Evaluation {
                        kind: CoverType::Low,
                        protection: if height == 0.0 { 0.45 } else { 0.7 },
                        fire: true,
                        lean: Vector3::ZERO,
                        threat_direction: direction,
                    },
                    position: c.position,
                    normal: if height > 0.0 {
                        direction
                    } else {
                        Vector3::ZERO
                    },
                    height,
                    material: if height == 0.0 { 0 } else { 2 },
                    structure: 0,
                    anchor: -1,
                },
                false,
            )
        };
        let e = choice.evaluation;
        let mut score = e.protection * 10.0 + [0.0, 1.8, 3.4, 4.2][choice.material as usize];
        if stack {
            score -= 2.5;
        }
        score += match e.kind {
            CoverType::Low => {
                if input.prone {
                    1.0
                } else if e.fire {
                    4.0
                } else {
                    1.5
                }
            }
            CoverType::Lean => 3.5,
            CoverType::Hide => {
                if input.prone || input.unarmed {
                    4.0
                } else {
                    0.0
                }
            }
        };
        if input.prone && choice.height > 0.0 && choice.height < 0.62 {
            score += 1.5;
        }
        score -= f64::from(flat(choice.position - input.anchor).length()) * 0.35;
        score -= f64::from(flat(choice.position - input.position).length()) * 0.12;
        if choice.structure != 0
            && choice.structure == input.current_structure
            && choice.anchor == input.current_anchor
        {
            score += 2.5;
        }
        if !input.prone
            && f64::from(flat(threats[0] - choice.position).length()) > input.weapon_range
        {
            score -= 3.0;
        }
        if scene.claimed(choice.position, input) {
            score -= 12.0;
        }
        if ground < -0.1 {
            score += 6.0;
        }
        if score > best_score {
            best_score = score;
            result.choice = Some(choice);
        }
    }
    Ok(result)
}
