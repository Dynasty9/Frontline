use godot::prelude::*;

struct Candidate {
    position: Vector3,
    cover: f64,
    trench: f64,
    occupied: usize,
}

#[derive(GodotClass)]
#[class(base=RefCounted, init)]
struct FormationGround {
    base: Base<RefCounted>,
    candidates: Vec<Candidate>,
}

fn distance(a: Vector3, b: Vector3) -> f64 {
    let delta = a - b;
    Vector3::new(delta.x, 0.0, delta.z).length() as f64
}

#[godot_api]
impl FormationGround {
    /// One synchronous formation owns this snapshot; no scene objects or RNG.
    #[func]
    fn prepare(&mut self, positions: PackedVector3Array, scores: PackedFloat64Array) -> bool {
        self.candidates.clear();
        let points = positions.as_slice();
        let scores = scores.as_slice();
        if scores.len() != points.len() * 2
            || !scores.iter().all(|v| v.is_finite())
            || !points.iter().all(|p| p.is_finite())
        {
            return false;
        }
        self.candidates
            .extend(
                points
                    .iter()
                    .zip(scores.chunks_exact(2))
                    .map(|(p, score)| Candidate {
                        position: *p,
                        cover: score[0],
                        trench: score[1],
                        occupied: 0,
                    }),
            );
        true
    }

    #[func]
    fn add_taken(&mut self, point: Vector3) {
        for candidate in &mut self.candidates {
            if distance(candidate.position, point) < 1.4 {
                candidate.occupied += 1;
            }
        }
    }

    #[func]
    fn best(&self, point: Vector3) -> PackedFloat64Array {
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
        PackedFloat64Array::from(&[index, best])
    }
}
