use frontline_core::infantry_pose::{InfantryPose, Posture};
use frontline_core::infantry_vitals::Life;
use godot::prelude::*;

#[derive(GodotClass)]
#[class(base=RefCounted, init)]
struct InfantryPoseCore {
    base: Base<RefCounted>,
}

fn read<T: FromGodot>(values: &Array<Variant>, i: usize) -> Option<T> {
    values.get(i)?.try_to::<T>().ok()
}

fn decode(values: &Array<Variant>) -> Option<InfantryPose> {
    if values.len() != 16 {
        return None;
    }
    let pose = InfantryPose {
        position: crate::point(read(values, 0)?),
        posture: Posture::try_from(read::<u8>(values, 1)?).ok()?,
        life: Life::try_from(read::<u8>(values, 2)?).ok()?,
        at_cover: read(values, 3)?,
        cover_kind: read(values, 4)?,
        cover_height: read(values, 5)?,
        cover_normal: crate::point(read(values, 6)?),
        lean_direction: crate::point(read(values, 7)?),
        mounted: read(values, 8)?,
        gun_mount: read(values, 9)?,
        tower_mount: read(values, 10)?,
        peek_up: read(values, 11)?,
        blind: read(values, 12)?,
        moving: read(values, 13)?,
        move_mode: read(values, 14)?,
        ground: read(values, 15)?,
    };
    pose.valid().then_some(pose)
}

#[godot_api]
impl InfantryPoseCore {
    #[func]
    fn query(&self, values: Array<Variant>, kind: i32) -> Variant {
        let Some(p) = decode(&values) else {
            return Variant::nil();
        };
        match kind {
            0 => {
                let v = p.eye();
                Vector3::new(v.x, v.y, v.z).to_variant()
            }
            1 => {
                let v = p.scan_eye();
                Vector3::new(v.x, v.y, v.z).to_variant()
            }
            2 => p
                .exposed_points()
                .as_slice()
                .iter()
                .map(|v| Vector3::new(v.x, v.y, v.z))
                .collect::<Array<Vector3>>()
                .to_variant(),
            3 => {
                let v = p.center();
                Vector3::new(v.x, v.y, v.z).to_variant()
            }
            4 => p.hit_factor().to_variant(),
            5 => (p.cover_posture(false) as i32).to_variant(),
            6 => (p.cover_posture(true) as i32).to_variant(),
            _ => Variant::nil(),
        }
    }
}
