use std::collections::HashMap;

#[derive(Clone, Copy)]
struct Contact {
    id: i64,
    team: i32,
    x: f64,
    z: f64,
    factor: f64,
    vehicle: bool,
}

const CELL: f64 = 24.0;

#[derive(Default)]
pub struct PerceptionSearch {
    cells: HashMap<(i32, i32), Vec<Contact>>,
}

impl PerceptionSearch {
    /// A complete immutable tick snapshot: IDs, teams and kinds, then x/z/factor.
    /// No Godot objects, physics or gameplay randomness are accessed here.
    pub fn rebuild(&mut self, m: &[i32], v: &[f64]) -> bool {
        for contacts in self.cells.values_mut() {
            contacts.clear();
        }
        if m.len() % 3 != 0 || v.len() != m.len() {
            return false;
        }
        for (m, v) in m.chunks_exact(3).zip(v.chunks_exact(3)) {
            if !v.iter().all(|x| x.is_finite()) || v[2] <= 0.0 {
                continue;
            }
            let c = Contact {
                id: i64::from(m[0]),
                team: m[1],
                vehicle: m[2] != 0,
                x: v[0],
                z: v[1],
                factor: v[2],
            };
            self.insert(c);
        }
        self.cells.retain(|_, contacts| !contacts.is_empty());
        true
    }

    fn insert(&mut self, c: Contact) {
        self.cells
            .entry(((c.x / CELL).floor() as i32, (c.z / CELL).floor() as i32))
            .or_default()
            .push(c);
    }

    pub fn rebuild_actors(
        &mut self,
        actors: &crate::actors::Actors,
        terrain: &crate::terrain::Terrain,
        now: f64,
        helicopter: impl Fn(&crate::vehicle::Vehicle) -> bool,
    ) -> Result<(), &'static str> {
        use crate::actors::Actor;
        use crate::infantry_pose::Posture;
        use crate::infantry_vitals::Life;
        if !now.is_finite() || now.abs() > 1e12 {
            return Err("invalid perception time");
        }
        for contacts in self.cells.values_mut() {
            contacts.clear();
        }
        for actor in actors.iter() {
            let c = match actor {
                Actor::Soldier(s)
                    if s.identity.team >= 0
                        && (s.vitals.life == Life::Alive
                            || s.vitals.life == Life::Downed
                                && now - s.weapon.last_shot <= 2.0) =>
                {
                    let mut factor = terrain.concealment(s.motion.position);
                    if now - s.weapon.last_shot > 8.0
                        && !s.is_moving()
                        && (s.cover.at_cover || s.posture == Posture::Prone)
                    {
                        factor *= 0.7;
                    }
                    Contact {
                        id: s.identity.id.into(),
                        team: s.identity.team.into(),
                        x: s.motion.position.x.into(),
                        z: s.motion.position.z.into(),
                        factor,
                        vehicle: false,
                    }
                }
                Actor::Vehicle(v) => Contact {
                    id: v.id.into(),
                    team: v.team.into(),
                    x: v.position.x.into(),
                    z: v.position.z.into(),
                    factor: if !(helicopter(v) && v.position.y > 3.0)
                        && terrain.layers[crate::terrain::NETTED][terrain.index(v.position)] > 0
                    {
                        0.5
                    } else {
                        1.0
                    },
                    vehicle: true,
                },
                _ => continue,
            };
            self.insert(c);
        }
        self.cells.retain(|_, contacts| !contacts.is_empty());
        Ok(())
    }

    pub fn nearest(&self, x: f64, z: f64, team: i32, sight: f64) -> Vec<i32> {
        self.nearest_ids(x, z, team, sight)
            .into_iter()
            .map(|id| id as i32)
            .collect()
    }

    pub fn nearest_owned(&self, x: f64, z: f64, team: i8, sight: f64) -> Vec<u32> {
        self.nearest_ids(x, z, team.into(), sight)
            .into_iter()
            .filter_map(|id| u32::try_from(id).ok())
            .collect()
    }

    fn nearest_ids(&self, x: f64, z: f64, team: i32, sight: f64) -> Vec<i64> {
        let mut best: Vec<(f64, i64)> = Vec::with_capacity(8);
        let radius = sight.max(85.0);
        for cx in ((x - radius) / CELL).floor() as i32..=((x + radius) / CELL).floor() as i32 {
            for cz in ((z - radius) / CELL).floor() as i32..=((z + radius) / CELL).floor() as i32 {
                if let Some(contacts) = self.cells.get(&(cx, cz)) {
                    for c in contacts {
                        if c.team < 0 || c.team == team {
                            continue;
                        }
                        let dx = c.x - x;
                        let dz = c.z - z;
                        let d2 = dx * dx + dz * dz;
                        let range = if c.vehicle { radius } else { sight } * c.factor;
                        if d2 > range * range {
                            continue;
                        }
                        let at = best.partition_point(|&(d, id)| d < d2 || (d == d2 && id < c.id));
                        if at < 7 {
                            best.insert(at, (d2, c.id));
                            best.truncate(7);
                        }
                    }
                }
            }
        }
        best.iter().map(|&(_, id)| id).collect()
    }
}
