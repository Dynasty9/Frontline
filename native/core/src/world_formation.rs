//! A formation shares its ground search and approach checks without copying scene state.
use crate::actors::Actors;
use crate::cover::AnchorKind;
use crate::formation::FormationGround;
use crate::terrain::{SOLID, TRENCH};
use crate::vector::{normalized, Vector3};
use crate::world_geometry::WorldGeometry;
use std::collections::HashMap;

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Slot {
    pub position: Vector3,
    pub cover: i32,
    pub anchor: Option<(u32, usize)>,
}
fn flat(p: Vector3) -> Vector3 {
    Vector3::new(p.x, 0.0, p.z)
}
fn point(p: Vector3) -> bool {
    p.is_finite() && p.abs().max_element() <= 1_000_000.0
}

impl WorldGeometry {
    pub fn formation_slots(
        &self,
        actors: &Actors,
        mut center: Vector3,
        mut face: Vector3,
        count: usize,
        wide: bool,
    ) -> Result<Vec<Slot>, &'static str> {
        if !point(center)
            || !point(face)
            || count > 4096
            || self.navigation.planner.side() != self.terrain.n
        {
            return Err("invalid formation");
        }
        let nav = &self.navigation.planner;
        if face.length() < 0.1 {
            face = Vector3::NEG_Z;
        }
        center = nav
            .nearest_walkable(
                center,
                crate::traversal::Ground::new(&self.terrain, &self.deck),
            )
            .ok_or("invalid formation center")?;
        if nav.kind_at(center, false) != 0 {
            let clicked = center;
            let mut best = f64::INFINITY;
            for z in -3..4 {
                for x in -3..4 {
                    let p = clicked + Vector3::new(x as f32, 0.0, z as f32);
                    let score = f64::from(p.distance_squared(clicked))
                        + f64::from(face.dot(p - clicked)) * 0.1;
                    if nav.kind_at(p, false) == 0 && score < best {
                        best = score;
                        center = p;
                    }
                }
            }
        }
        let side = normalized(face.cross(Vector3::Y));
        let threat = center + face * 40.0;
        let radius: f64 = if wide { 6.5 } else { 5.5 };
        let group_spot = |p: Vector3, normal: Vector3| {
            let approach = p - normal * 0.8;
            f64::from(flat(p - center).length_squared()) <= radius * radius
                && nav.kind_at(approach, false) != 3
                && nav.line_free(
                    center,
                    approach,
                    false,
                    false,
                    crate::traversal::Ground::new(&self.terrain, &self.deck),
                )
        };
        let mut ground = vec![];
        let mut scores = vec![];
        if count > 0 {
            let cell = self.terrain.index(center);
            let cx = (cell % self.terrain.n) as i32;
            let cz = (cell / self.terrain.n) as i32;
            let ri = radius.ceil() as i32;
            for z in (cz - ri).max(0)..(cz + ri + 1).min(self.terrain.n as i32) {
                for x in (cx - ri).max(0)..(cx + ri + 1).min(self.terrain.n as i32) {
                    let i = z as usize * self.terrain.n + x as usize;
                    let p = self.terrain.center(i);
                    if self.terrain.layers[SOLID][i] == 0 && group_spot(p, Vector3::ZERO) {
                        ground.push(p);
                        scores.push(f64::from(self.terrain.cover_vs(p, threat)) * 3.0);
                        scores.push(if self.terrain.layers[TRENCH][i] > 0 {
                            2.5
                        } else {
                            0.0
                        });
                    }
                }
            }
        }
        let mut scorer = FormationGround::default();
        if !scorer.prepare(ground.iter().copied(), &scores) {
            return Err("invalid formation ground");
        }
        let mut approaches = HashMap::new();
        let mut occupancy: HashMap<(u32, usize), (usize, usize)> = HashMap::new();
        let mut taken: Vec<Vector3> = vec![];
        let mut out = Vec::with_capacity(count);
        for i in 0..count {
            let angle = i as f64 * 2.399963;
            let spread = (libm::sqrt(i as f64) * 1.5).min(if wide { 4.5 } else { 3.5 });
            let p = center
                + (side * libm::cos(angle) as f32 + face * libm::sin(angle) as f32) * spread as f32;
            let [ground_index, ground_score] = scorer.best(p);
            let mut slot = Slot {
                position: if ground_index >= 0.0 {
                    ground[ground_index as usize]
                } else {
                    center
                },
                cover: 0,
                anchor: None,
            };
            let mut best = -1e9;
            let mut anchor = None;
            let reach = radius * 2.0;
            for id in actors.structures_near(&self.structures, p, reach + 2.0, false)? {
                let st = actors.structure(id).unwrap();
                if !st.built || st.cover_points.is_empty() {
                    continue;
                }
                for (ai, a) in st.anchors.iter().enumerate() {
                    let distance = f64::from(flat(a.position - p).length());
                    if distance > reach
                        || !*approaches
                            .entry((id, ai))
                            .or_insert_with(|| group_spot(a.position, a.normal))
                    {
                        continue;
                    }
                    let toward = flat(threat - a.position);
                    if toward.length() < 0.5 || a.normal.dot(normalized(toward)) < 0.3 {
                        continue;
                    }
                    let material = if a.kind == AnchorKind::Stack {
                        st.cover_material().saturating_sub(1)
                    } else {
                        st.cover_material()
                    };
                    let mut score = [3.5, 5.0, 6.5, 7.0][material as usize] - distance * 0.6
                        + if st.kind == "trench" { 2.5 } else { 0.0 };
                    match a.kind {
                        AnchorKind::Shelter => score -= 1.5,
                        AnchorKind::Stack => score -= 2.5,
                        AnchorKind::Over if a.height < 0.62 => score -= 0.5,
                        _ => (),
                    }
                    let (seen, occupied) = occupancy.entry((id, ai)).or_default();
                    for &other in &taken[*seen..] {
                        if f64::from(flat(other - a.position).length()) < 1.15 {
                            *occupied += 1;
                        }
                    }
                    *seen = taken.len();
                    for _ in 0..*occupied {
                        score -= 100.0;
                    }
                    if score > best {
                        best = score;
                        anchor = Some((id, ai, a.position, material));
                    }
                }
            }
            if let Some((id, ai, position, material)) =
                anchor.filter(|_| best + 0.5 >= ground_score)
            {
                slot.position = position;
                slot.cover = if material >= 2 { 2 } else { 1 };
                slot.anchor = Some((id, ai));
            } else {
                slot.cover = self.terrain.cover_vs(slot.position, threat);
            }
            taken.push(slot.position);
            scorer.add_taken(slot.position);
            out.push(slot);
        }
        Ok(out)
    }
}
