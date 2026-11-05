use crate::vector::Vector3;

struct Candidate {
    position: Vector3,
    cover: f64,
    trench: f64,
    occupied: usize,
}

#[derive(Default)]
pub struct FormationGround {
    candidates: Vec<Candidate>,
}

fn distance(a: Vector3, b: Vector3) -> f64 {
    let delta = a - b;
    Vector3::new(delta.x, 0.0, delta.z).length() as f64
}

impl FormationGround {
    /// One synchronous formation owns this snapshot; no scene objects or RNG.
    pub fn prepare(
        &mut self,
        points: impl ExactSizeIterator<Item = Vector3>,
        scores: &[f64],
    ) -> bool {
        self.candidates.clear();
        if scores.len() != points.len() * 2 || !scores.iter().all(|v| v.is_finite()) {
            return false;
        }
        for (position, score) in points.zip(scores.chunks_exact(2)) {
            if !position.is_finite() {
                self.candidates.clear();
                return false;
            }
            self.candidates.push(Candidate {
                position,
                cover: score[0],
                trench: score[1],
                occupied: 0,
            });
        }
        true
    }

    pub fn add_taken(&mut self, point: Vector3) {
        for candidate in &mut self.candidates {
            if distance(candidate.position, point) < 1.4 {
                candidate.occupied += 1;
            }
        }
    }

    pub fn best(&self, point: Vector3) -> [f64; 2] {
        let mut index = -1.0;
        let mut best = -1e9;
        for (i, candidate) in self.candidates.iter().enumerate() {
            let mut score =
                candidate.cover - distance(candidate.position, point) * 0.6 + candidate.trench;
            // Preserve subtraction order and first-wins ties from GDScript.
            for _ in 0..candidate.occupied {
                score -= 100.0;
            }
            if score > best {
                best = score;
                index = i as f64;
            }
        }
        [index, best]
    }
}
