use crate::collision_index::CollisionIndexCore;
use crate::visibility::VisibilityCore;
use frontline_core::infantry_mount::{self as crew, Contact, GunPose, Mount, Station};
use godot::prelude::*;

#[derive(GodotClass)]
#[class(base=RefCounted, init)]
struct InfantryMountCore {
    base: Base<RefCounted>,
    core: Mount,
}

fn read<T: FromGodot>(row: &Array<Variant>, index: usize) -> Option<T> {
    row.get(index)?.try_to::<T>().ok()
}

#[godot_api]
impl InfantryMountCore {
    #[func]
    fn station(
        &mut self,
        phase: i32,
        timer: f64,
        dt: f64,
        tower: bool,
        moving: bool,
    ) -> PackedFloat64Array {
        let Ok(phase) = u8::try_from(phase) else {
            return PackedFloat64Array::new();
        };
        let mut core = Mount {
            phase,
            timer,
            ..self.core
        };
        let Ok(station) = core.station(dt, tower, moving) else {
            return PackedFloat64Array::new();
        };
        let (code, height) = match station {
            Station::Move => (0.0, 0.0),
            Station::StartClimb => (1.0, 0.0),
            Station::Climb { height, finished } => {
                (if finished { 3.0 } else { 2.0 }, f64::from(height))
            }
            Station::Man => (4.0, 0.0),
            Station::Ready => (5.0, 0.0),
        };
        self.core = core;
        [f64::from(core.phase), core.timer, code, height]
            .as_slice()
            .into()
    }

    #[func]
    fn scan_due(&mut self, timer: f64, target: i64, dt: f64) -> PackedFloat64Array {
        let Ok(target) = u64::try_from(target) else {
            return PackedFloat64Array::new();
        };
        let mut core = Mount {
            scan_timer: timer,
            target,
            ..self.core
        };
        let Ok(due) = core.scan_due(dt) else {
            return PackedFloat64Array::new();
        };
        self.core = core;
        [core.scan_timer, f64::from(due)].as_slice().into()
    }

    #[func]
    fn gun_aim(
        &self,
        position: Vector3,
        yaw: f64,
        dt: f64,
        mounted: PackedFloat64Array,
        structure: Vector3,
        target: Vector3,
        antitank: bool,
    ) -> PackedFloat64Array {
        let mount = match mounted.len() {
            0 => None,
            4 => Some((
                frontline_core::vector::Vector3::new(
                    mounted[0] as f32,
                    mounted[1] as f32,
                    mounted[2] as f32,
                ),
                mounted[3],
            )),
            _ => return PackedFloat64Array::new(),
        };
        let pose = GunPose {
            position: crate::point(position),
            yaw,
            dt,
            mount,
        };
        let result = if antitank {
            crew::antitank_aim(pose, crate::point(structure), crate::point(target))
        } else {
            crew::mortar_aim(pose, crate::point(target))
                .map(|aim| (aim, frontline_core::vector::Vector3::ZERO))
        };
        let Ok((aim, direction)) = result else {
            return PackedFloat64Array::new();
        };
        [
            aim.yaw,
            f64::from(aim.aligned),
            f64::from(direction.x),
            f64::from(direction.y),
            f64::from(direction.z),
        ]
        .as_slice()
        .into()
    }

    #[func]
    fn scan(
        &mut self,
        mut collision: Gd<CollisionIndexCore>,
        mut visibility: Gd<VisibilityCore>,
        team: i32,
        position: Vector3,
        rows: Array<Variant>,
    ) -> PackedInt64Array {
        let Some(contacts) = contacts(&rows) else {
            return PackedInt64Array::new();
        };
        let Ok(result) = crew::scan(
            team,
            crate::point(position),
            &contacts,
            &mut collision.bind_mut().core,
            &mut visibility.bind_mut().core,
        ) else {
            return PackedInt64Array::new();
        };
        self.core.target = result.target;
        [result.target as i64, result.reused as i64]
            .as_slice()
            .into()
    }

    #[func]
    fn checkpoint(&self) -> PackedByteArray {
        self.core.checkpoint().as_slice().into()
    }

    #[func]
    fn restore(&mut self, bytes: PackedByteArray) -> bool {
        let Ok(core) = Mount::restore(bytes.as_slice()) else {
            return false;
        };
        self.core = core;
        true
    }
}

fn contacts(rows: &Array<Variant>) -> Option<Vec<Contact>> {
    if rows.len() > 100_000 {
        return None;
    }
    let mut out = Vec::with_capacity(rows.len());
    for row in rows.iter_shared() {
        let row = row.try_to::<Array<Variant>>().ok()?;
        if row.len() != 6 {
            return None;
        }
        let points: PackedVector3Array = read(&row, 4)?;
        let excluded: PackedInt64Array = read(&row, 5)?;
        if points.len() > 256 || excluded.len() > 4096 {
            return None;
        }
        out.push(Contact {
            id: u64::try_from(read::<i64>(&row, 0)?).ok()?,
            team: read(&row, 1)?,
            revealed: read(&row, 2)?,
            position: crate::point(read(&row, 3)?),
            points: points
                .as_slice()
                .iter()
                .copied()
                .map(crate::point)
                .collect(),
            excluded: excluded.as_slice().to_vec(),
        });
    }
    Some(out)
}
