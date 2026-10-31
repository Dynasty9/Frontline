use crate::collision_index::CollisionIndexCore;
use crate::simulation_random::SimulationRandomCore;
use crate::visibility::VisibilityCore;
use frontline_core::bullet::{
    self, Body, Bullet, ShotInput, Target, TargetEffect, TargetKind, TargetLocation,
    ThroughContact, Weapon,
};
use godot::prelude::*;

#[derive(GodotClass)]
#[class(base=RefCounted, init)]
struct BulletCore {
    base: Base<RefCounted>,
    core: Option<Bullet>,
}

fn vector(p: frontline_core::vector::Vector3) -> Vector3 {
    Vector3::new(p.x, p.y, p.z)
}
fn flag(v: f64) -> bool {
    v == 0.0 || v == 1.0
}

#[godot_api]
impl BulletCore {
    #[func]
    fn fire(
        &mut self,
        mut collision: Gd<CollisionIndexCore>,
        visibility: Gd<VisibilityCore>,
        mut rng: Gd<SimulationRandomCore>,
        muzzle: Vector3,
        aim: Vector3,
        values: PackedFloat64Array,
        target: PackedFloat64Array,
        excluded: PackedInt64Array,
    ) -> bool {
        let v = values.as_slice();
        let t = target.as_slice();
        if v.len() != 11
            || (!t.is_empty() && t.len() != 4)
            || excluded.len() > 4096
            || v.iter().chain(t).any(|v| !v.is_finite())
            || ![3, 7, 10].iter().all(|i| flag(v[*i]))
            || v[4].fract() != 0.0
            || !(0.0..=3.0).contains(&v[4])
            || (!t.is_empty()
                && (t[0].fract() != 0.0 || !(0.0..=3.0).contains(&t[0]) || !flag(t[3])))
        {
            return false;
        }
        let target = if t.is_empty() {
            None
        } else {
            Some(Target {
                kind: match t[0] as u8 {
                    0 => TargetKind::Infantry,
                    1 => TargetKind::Drone,
                    2 => TargetKind::AirVehicle,
                    _ => TargetKind::Other,
                },
                hit_factor: t[1],
                terrain_multiplier: t[2],
                trench_protected: t[3] != 0.0,
            })
        };
        let input = ShotInput {
            muzzle: crate::point(muzzle),
            aim: crate::point(aim),
            target,
            weapon: Weapon {
                accuracy: v[0],
                range: v[1],
                damage: v[2],
                anti_air: v[3] != 0.0,
                penetration: v[4] as u8,
                drone_accuracy: v[5],
                explosive_radius: (v[6] != -1.0).then_some(v[6]),
                airburst: v[7] != 0.0,
            },
            accuracy_multiplier: v[8],
            soldier_suppression: (v[9] != -1.0).then_some(v[9]),
            optics: v[10] != 0.0,
            excluded: excluded.as_slice(),
        };
        let Ok(core) = Bullet::fire(
            input,
            &mut collision.bind_mut().core,
            &visibility.bind().core,
            &mut rng.bind_mut().core,
        ) else {
            return false;
        };
        self.core = Some(core);
        true
    }

    #[func]
    fn state(&self) -> Array<Variant> {
        let Some(b) = self.core else {
            return Array::new();
        };
        varray![
            b.hit,
            vector(b.end),
            vector(b.direction),
            i32::from(b.impact),
            b.ray.map_or(0, |r| r.body),
            b.ray.map_or(Vector3::ZERO, |r| vector(r.position)),
            b.penetration_multiplier()
        ]
    }

    #[func]
    fn resolve_obstacle(
        &mut self,
        kind: i32,
        material: i32,
        mut rng: Gd<SimulationRandomCore>,
    ) -> Array<Variant> {
        let Some(core) = &mut self.core else {
            return Array::new();
        };
        let body = match kind {
            0 => Body::Other,
            1 if (0..=3).contains(&material) => Body::Structure {
                material: material as u8,
            },
            2 => Body::Vehicle,
            _ => return Array::new(),
        };
        let Ok(result) = core.resolve_obstacle(body, &mut rng.bind_mut().core) else {
            return Array::new();
        };
        varray![
            result.penetrated,
            result.penetration_damage,
            &result
                .through_end
                .map_or_else(Variant::nil, |p| vector(p).to_variant()),
            result.structure_damage,
            result.vehicle_hit,
            result.structure_surface
        ]
    }

    #[func]
    fn set_surface(&mut self, impact: i32) -> bool {
        let (Some(core), Ok(impact)) = (&mut self.core, u8::try_from(impact)) else {
            return false;
        };
        core.set_surface(impact).is_ok()
    }

    #[func]
    fn finish_target(&mut self, mut rng: Gd<SimulationRandomCore>) -> Array<Variant> {
        let Some(core) = &mut self.core else {
            return Array::new();
        };
        match core.finish_target(&mut rng.bind_mut().core) {
            Ok(TargetEffect::None) => varray![0, 0.0],
            Ok(TargetEffect::Damage(amount)) => varray![1, amount],
            Ok(TargetEffect::DownDrone) => varray![2, 0.0],
            Err(_) => Array::new(),
        }
    }

    #[func]
    fn explosion(
        &mut self,
        location: Array<Variant>,
        mut rng: Gd<SimulationRandomCore>,
    ) -> Array<Variant> {
        let Some(core) = &mut self.core else {
            return Array::new();
        };
        let location = if location.is_empty() {
            None
        } else {
            if location.len() != 3 {
                return Array::new();
            }
            let (Ok(position), Ok(center), Ok(in_trench)) = (
                location.at(0).try_to::<Vector3>(),
                location.at(1).try_to::<Vector3>(),
                location.at(2).try_to::<bool>(),
            ) else {
                return Array::new();
            };
            Some(TargetLocation {
                position: crate::point(position),
                center: crate::point(center),
                in_trench,
            })
        };
        match core.explosion(location, &mut rng.bind_mut().core) {
            Ok(Some(e)) => varray![vector(e.position), e.damage, e.radius],
            Ok(None) => varray![&Variant::nil()],
            Err(_) => Array::new(),
        }
    }

    #[func]
    fn through_hit(
        &self,
        end: Vector3,
        meta: PackedInt64Array,
        positions: PackedVector3Array,
        shooter_team: i32,
        mut rng: Gd<SimulationRandomCore>,
    ) -> Array<Variant> {
        let Some(core) = self.core else {
            return Array::new();
        };
        let Some(ray) = core.ray else {
            return Array::new();
        };
        if positions.len() > 100_000 || meta.len() != positions.len() * 3 {
            return Array::new();
        }
        let mut contacts = Vec::with_capacity(positions.len());
        for (row, p) in meta.as_slice().chunks_exact(3).zip(positions.as_slice()) {
            if row[0] <= 0 || i32::try_from(row[1]).is_err() || !(0..=1).contains(&row[2]) {
                return Array::new();
            }
            contacts.push(ThroughContact {
                id: row[0] as u64,
                team: row[1] as i32,
                alive: row[2] != 0,
                center: crate::point(*p),
            });
        }
        match bullet::through_hit(
            ray.position,
            crate::point(end),
            &contacts,
            shooter_team,
            core.damage(),
            core.penetration_multiplier(),
            &mut rng.bind_mut().core,
        ) {
            Ok(Some(hit)) => varray![hit.target as i64, hit.damage, vector(hit.direction)],
            Ok(None) => varray![0, 0.0, Vector3::ZERO],
            Err(_) => Array::new(),
        }
    }

    #[func]
    fn suppression(&self, positions: PackedVector3Array, amount: f64) -> PackedFloat64Array {
        let Some(core) = self.core else {
            return PackedFloat64Array::new();
        };
        if positions.len() > 100_000 {
            return PackedFloat64Array::new();
        }
        let positions: Vec<_> = positions
            .as_slice()
            .iter()
            .map(|p| crate::point(*p))
            .collect();
        match bullet::suppression(core.muzzle(), core.end, &positions, amount) {
            Ok(values) => values.as_slice().into(),
            Err(_) => PackedFloat64Array::new(),
        }
    }
}
