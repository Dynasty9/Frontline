use crate::simulation_random::SimulationRandomCore;
use frontline_core::drone_reaction::{Drone, DroneMemory};
use godot::prelude::*;

#[derive(GodotClass)]
#[class(base=RefCounted, init)]
struct DroneReactionCore {
    base: Base<RefCounted>,
    core: DroneMemory,
}

#[godot_api]
impl DroneReactionCore {
    #[func]
    fn react(
        &mut self,
        position: Vector3,
        team: i32,
        heard: PackedInt64Array,
        drones: Array<Variant>,
        mut random: Gd<SimulationRandomCore>,
    ) -> Array<Variant> {
        if heard.len() > 17 || drones.len() > 100_000 {
            return Array::new();
        }
        let Some(heard) = heard
            .as_slice()
            .iter()
            .map(|v| u64::try_from(*v).ok())
            .collect::<Option<Vec<_>>>()
        else {
            return Array::new();
        };
        let drones = drones
            .iter_shared()
            .map(|row| {
                let v: Array<Variant> = row.try_to().ok()?;
                if v.len() != 6 {
                    return None;
                }
                Some(Drone {
                    id: u64::try_from(v.get(0)?.try_to::<i64>().ok()?).ok()?,
                    position: crate::point(v.get(1)?.try_to().ok()?),
                    target: crate::point(v.get(2)?.try_to().ok()?),
                    team: v.get(3)?.try_to().ok()?,
                    dead: v.get(4)?.try_to().ok()?,
                    diving: v.get(5)?.try_to().ok()?,
                })
            })
            .collect::<Option<Vec<_>>>();
        let Some(drones) = drones else {
            return Array::new();
        };
        let mut core = DroneMemory { heard };
        let Ok(result) = core.react(
            crate::point(position),
            team,
            &drones,
            &mut random.bind_mut().core,
        ) else {
            return Array::new();
        };
        let heard: PackedInt64Array = core.heard.iter().map(|v| *v as i64).collect();
        let warnings: PackedInt32Array = result
            .warnings
            .iter()
            .map(|w| i32::from(w.variant))
            .collect();
        let dive = result
            .dive_from
            .map_or(Variant::nil(), |p| Vector3::new(p.x, p.y, p.z).to_variant());
        self.core = core;
        varray![&heard, &warnings, &dive]
    }

    #[func]
    fn checkpoint(&self) -> PackedByteArray {
        self.core.checkpoint().as_slice().into()
    }

    #[func]
    fn restore(&mut self, bytes: PackedByteArray) -> bool {
        let Ok(core) = DroneMemory::restore(bytes.as_slice()) else {
            return false;
        };
        self.core = core;
        true
    }
}
