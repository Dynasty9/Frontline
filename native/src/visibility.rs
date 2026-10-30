use crate::collision_index::CollisionIndexCore;
use frontline_core::targeting::{self, Contact, DroneContact, Observer, TargetKind};
use frontline_core::vector::Vector3 as Point;
use frontline_core::visibility::{Sight, Smoke, Visibility};
use godot::prelude::*;

#[derive(GodotClass)]
#[class(base=RefCounted, init)]
struct VisibilityCore {
    base: Base<RefCounted>,
    core: Visibility,
    points: Vec<Point>,
}

#[godot_api]
impl VisibilityCore {
    #[func]
    fn set_projectile(&mut self, id: i64, center: Vector3, radius: f64) -> bool {
        self.core.set_projectile(
            id as u64,
            Smoke {
                center: crate::point(center),
                radius,
            },
        )
    }
    #[func]
    fn remove_projectile(&mut self, id: i64) {
        self.core.remove_projectile(id as u64);
    }
    #[func]
    fn set_fires(&mut self, rows: PackedFloat64Array) -> bool {
        if rows.len() % 4 != 0 || rows.len() > 400_000 {
            return false;
        }
        let fires: Vec<_> = rows
            .as_slice()
            .chunks_exact(4)
            .map(|r| Smoke {
                center: Point::new(r[0] as f32, r[1] as f32, r[2] as f32),
                radius: r[3],
            })
            .collect();
        self.core.set_fires(&fires)
    }
    #[func]
    fn smoke_blocks(&self, from: Vector3, to: Vector3) -> bool {
        self.core.smoke_blocks(crate::point(from), crate::point(to))
    }
    #[func]
    fn can_see(
        &mut self,
        mut collision: Gd<CollisionIndexCore>,
        eye: Vector3,
        target: i64,
        points: PackedVector3Array,
        excluded: PackedInt64Array,
        cache: bool,
    ) -> i32 {
        if target < 0 || points.len() > 256 || excluded.len() > 4096 {
            return -1;
        }
        self.points.clear();
        self.points
            .extend(points.as_slice().iter().map(|p| crate::point(*p)));
        match self.core.can_see(
            &mut collision.bind_mut().core,
            crate::point(eye),
            target as u64,
            &self.points,
            excluded.as_slice(),
            cache,
        ) {
            Some(Sight::Hidden) => 0,
            Some(Sight::Visible) => 1,
            Some(Sight::ReusedObstruction) => 2,
            None => -1,
        }
    }
    #[func]
    fn rays(&self) -> i64 {
        self.core.rays as i64
    }
    #[func]
    fn scan_contacts(
        &mut self,
        mut collision: Gd<CollisionIndexCore>,
        observer: Array<Variant>,
        contact_meta: PackedInt64Array,
        contact_points: PackedVector3Array,
        excluded: PackedInt64Array,
        drone_meta: PackedInt64Array,
        drone_positions: PackedVector3Array,
    ) -> PackedInt64Array {
        let Some(observer) = read_observer(&observer) else {
            return PackedInt64Array::new();
        };
        if contact_meta.len() > 35
            || contact_meta.len() % 5 != 0
            || contact_points.len() > 7 * 257
            || excluded.len() > 7 * 4096
            || drone_positions.len() > 100_000
            || drone_meta.len() != drone_positions.len() * 4
        {
            return PackedInt64Array::new();
        }
        let mut contacts = Vec::with_capacity(contact_meta.len() / 5);
        let (mut p, mut e) = (0, 0);
        for row in contact_meta.as_slice().chunks_exact(5) {
            let [id, tag, flags, point_count, exclude_count] = <[i64; 5]>::try_from(row).unwrap();
            if id <= 0
                || !(0..=256).contains(&point_count)
                || !(0..=4096).contains(&exclude_count)
                || p + point_count as usize + 1 > contact_points.len()
                || e + exclude_count as usize > excluded.len()
            {
                return PackedInt64Array::new();
            }
            let kind = match tag {
                0 => TargetKind::Other,
                1 if (0..=3).contains(&flags) => TargetKind::Infantry {
                    downed: flags & 1 != 0,
                    machine_gunner: flags & 2 != 0,
                },
                2 if i32::try_from(flags).is_ok() => TargetKind::Vehicle {
                    armor: flags as i32,
                },
                _ => return PackedInt64Array::new(),
            };
            contacts.push(Contact {
                id: id as u64,
                kind,
                position: crate::point(contact_points[p]),
                points: contact_points.as_slice()[p + 1..p + 1 + point_count as usize]
                    .iter()
                    .map(|p| crate::point(*p))
                    .collect(),
                excluded: excluded.as_slice()[e..e + exclude_count as usize].to_vec(),
            });
            p += point_count as usize + 1;
            e += exclude_count as usize;
        }
        if p != contact_points.len() || e != excluded.len() {
            return PackedInt64Array::new();
        };
        let mut drones = Vec::with_capacity(drone_positions.len());
        for (row, position) in drone_meta
            .as_slice()
            .chunks_exact(4)
            .zip(drone_positions.as_slice())
        {
            if row[0] <= 0
                || i32::try_from(row[1]).is_err()
                || !(0..=1).contains(&row[2])
                || !(0..=1).contains(&row[3])
            {
                return PackedInt64Array::new();
            }
            drones.push(DroneContact {
                id: row[0] as u64,
                team: row[1] as i32,
                dead: row[2] != 0,
                diving: row[3] != 0,
                position: crate::point(*position),
            });
        }
        let Ok(result) = targeting::scan(
            observer,
            &contacts,
            &drones,
            &mut collision.bind_mut().core,
            &mut self.core,
        ) else {
            return PackedInt64Array::new();
        };
        [
            result.target as i64,
            result.reported as i64,
            result.reused as i64,
        ]
        .into_iter()
        .chain(result.visible.into_iter().map(|id| id as i64))
        .collect()
    }
    #[func]
    fn checkpoint(&self) -> PackedByteArray {
        self.core.checkpoint().as_slice().into()
    }
    #[func]
    fn restore(&mut self, bytes: PackedByteArray) -> bool {
        let Ok(core) = Visibility::restore(bytes.as_slice()) else {
            return false;
        };
        self.core = core;
        true
    }
}

fn read_observer(d: &Array<Variant>) -> Option<Observer> {
    if d.len() != 11 {
        return None;
    }
    let current = d.get(3)?.try_to::<i64>().ok()?;
    let forced = d.get(4)?.try_to::<i64>().ok()?;
    if current < 0 || forced < 0 {
        return None;
    }
    let structure = d.get(5)?;
    let mount = d.get(6)?;
    Some(Observer {
        position: crate::point(d.get(0)?.try_to::<Vector3>().ok()?),
        eye: crate::point(d.get(1)?.try_to::<Vector3>().ok()?),
        team: d.get(2)?.try_to::<i32>().ok()?,
        current: current as u64,
        forced: forced as u64,
        forced_structure: if structure.is_nil() {
            None
        } else {
            Some(crate::point(structure.try_to::<Vector3>().ok()?))
        },
        mount_forward: if mount.is_nil() {
            None
        } else {
            Some(crate::point(mount.try_to::<Vector3>().ok()?))
        },
        weapon_range: d.get(7)?.try_to::<f64>().ok()?,
        rockets: d.get(8)?.try_to::<bool>().ok()?,
        armor_piercing: d.get(9)?.try_to::<bool>().ok()?,
        cache_obstruction: d.get(10)?.try_to::<bool>().ok()?,
    })
}
