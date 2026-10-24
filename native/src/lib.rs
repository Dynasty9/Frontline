use godot::prelude::*;
use std::collections::HashMap;

mod route_graph;

struct FrontlineSimulation;
#[gdextension]
unsafe impl ExtensionLibrary for FrontlineSimulation {}

#[derive(Clone, Copy)]
struct Contact {
    id: i32,
    team: i32,
    x: f64,
    z: f64,
    factor: f64,
    vehicle: bool,
}

const CELL: f64 = 24.0;

#[derive(GodotClass)]
#[class(base=RefCounted, init)]
struct PerceptionSearch {
    base: Base<RefCounted>,
    cells: HashMap<(i32, i32), Vec<Contact>>,
}

#[godot_api]
impl PerceptionSearch {
    /// A complete immutable tick snapshot: IDs, teams and kinds, then x/z/factor.
    /// No Godot objects, physics or gameplay randomness are accessed here.
    #[func]
    fn rebuild(&mut self, meta: PackedInt32Array, values: PackedFloat64Array) -> bool {
        self.cells.clear();
        let m = meta.as_slice();
        let v = values.as_slice();
        if m.len() % 3 != 0 || v.len() != m.len() {
            return false;
        }
        for (m, v) in m.chunks_exact(3).zip(v.chunks_exact(3)) {
            if !v.iter().all(|x| x.is_finite()) || v[2] <= 0.0 {
                continue;
            }
            let c = Contact {
                id: m[0],
                team: m[1],
                vehicle: m[2] != 0,
                x: v[0],
                z: v[1],
                factor: v[2],
            };
            self.cells
                .entry(((c.x / CELL).floor() as i32, (c.z / CELL).floor() as i32))
                .or_default()
                .push(c);
        }
        true
    }

    #[func]
    fn nearest(&self, x: f64, z: f64, team: i32, sight: f64) -> PackedInt32Array {
        let mut best: Vec<(f64, i32)> = Vec::with_capacity(8);
        let radius = sight.max(85.0);
        for cx in ((x - radius) / CELL).floor() as i32..=((x + radius) / CELL).floor() as i32 {
            for cz in ((z - radius) / CELL).floor() as i32..=((z + radius) / CELL).floor() as i32 {
                if let Some(contacts) = self.cells.get(&(cx, cz)) {
                    for c in contacts {
                        if c.team < 0 || c.team == team {
                            continue;
                        }
                        let d2 = (c.x - x).powi(2) + (c.z - z).powi(2);
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
