use crate::{
    collision_index::CollisionIndexCore, path_planner::PathPlannerCore,
    simulation_random::SimulationRandomCore, terrain::TerrainCore,
};
use frontline_core::infantry_motion::{
    self, Door, InfantryMotion, MoveInput, Neighbor, StationaryInput,
};
use frontline_core::infantry_vitals::Life;
use godot::prelude::*;

#[derive(GodotClass)]
#[class(base=RefCounted, init)]
struct InfantryMotionCore {
    base: Base<RefCounted>,
    core: InfantryMotion,
}

pub(crate) fn state(values: &[f64], path: PackedVector3Array, door: i64) -> Option<InfantryMotion> {
    if values.len() != 22
        || values.iter().any(|v| !v.is_finite())
        || door < 0
        || [11, 16, 21]
            .iter()
            .any(|i| values[*i] != 0.0 && values[*i] != 1.0)
        || values[4] < 0.0
        || values[4].fract() != 0.0
        || values[4] > path.len() as f64
        || path.len() > 1_000_000
    {
        return None;
    }
    let p = |i| {
        frontline_core::vector::Vector3::new(
            values[i] as f32,
            values[i + 1] as f32,
            values[i + 2] as f32,
        )
    };
    let state = InfantryMotion {
        position: p(0),
        yaw: values[3],
        path: path.as_slice().iter().copied().map(crate::point).collect(),
        path_index: values[4] as usize,
        stuck_position: p(5),
        stuck_timer: values[8],
        slide_timer: values[9],
        slide_cooldown: values[10],
        vaulting: values[11] != 0.0,
        last_direction: p(12),
        barrier_until: values[15],
        barrier: values[16] != 0.0,
        ground_until: values[17],
        ground: values[18],
        door_wait: values[19],
        door_until: values[20],
        door: door as u64,
        door_kick: values[21] != 0.0,
    };
    state.valid().then_some(state)
}

fn context(values: &[f64]) -> Option<MoveInput> {
    if values.len() != 18
        || values.iter().any(|v| !v.is_finite())
        || [4, 5, 6, 9, 10, 11, 12, 13]
            .iter()
            .any(|i| values[*i] != 0.0 && values[*i] != 1.0)
        || values[7].fract() != 0.0
        || !(-100.0..=100.0).contains(&values[7])
    {
        return None;
    }
    Some(MoveInput {
        dt: values[0],
        time: values[1],
        speed: values[2],
        base_y: values[3],
        alive: values[4] != 0.0,
        path_pending: values[5] != 0.0,
        cover_goal: values[6] != 0.0,
        move_mode: values[7] as i32,
        suppression: values[8],
        backwards: values[9] != 0.0,
        danger: values[10] != 0.0,
        has_doors: values[11] != 0.0,
        door_still_closed: values[12] != 0.0,
        mount: (values[13] != 0.0).then(|| {
            (
                frontline_core::vector::Vector3::new(
                    values[14] as f32,
                    values[15] as f32,
                    values[16] as f32,
                ),
                values[17],
            )
        }),
    })
}

fn doors(rows: Array<Variant>) -> Option<Vec<Door>> {
    if rows.len() > 4096 {
        return None;
    }
    rows.iter_shared()
        .map(|row| {
            let row = row.try_to::<Array<Variant>>().ok()?;
            if row.len() != 3 {
                return None;
            }
            let id = row.get(0)?.try_to::<i64>().ok()?;
            if id <= 0 {
                return None;
            }
            Some(Door {
                id: id as u64,
                position: crate::point(row.get(1)?.try_to::<Vector3>().ok()?),
                yaw: row.get(2)?.try_to::<f64>().ok()?,
            })
        })
        .collect()
}

pub(crate) fn observation(s: &InfantryMotion) -> PackedFloat64Array {
    PackedFloat64Array::from(&[
        f64::from(s.position.x),
        f64::from(s.position.y),
        f64::from(s.position.z),
        s.yaw,
        s.path_index as f64,
        f64::from(s.stuck_position.x),
        f64::from(s.stuck_position.y),
        f64::from(s.stuck_position.z),
        s.stuck_timer,
        s.slide_timer,
        s.slide_cooldown,
        f64::from(s.vaulting),
        f64::from(s.last_direction.x),
        f64::from(s.last_direction.y),
        f64::from(s.last_direction.z),
        s.barrier_until,
        f64::from(s.barrier),
        s.ground_until,
        s.ground,
        s.door_wait,
        s.door_until,
        f64::from(s.door_kick),
    ])
}

#[godot_api]
impl InfantryMotionCore {
    #[func]
    fn separation(
        &self,
        id: i64,
        position: Vector3,
        active: bool,
        neighbors: Array<Variant>,
        mut random: Gd<SimulationRandomCore>,
    ) -> PackedVector3Array {
        let Some(neighbors) = (|| {
            if id <= 0 || neighbors.len() > 100_000 {
                return None;
            }
            neighbors
                .iter_shared()
                .map(|v| {
                    let v: Array<Variant> = v.try_to().ok()?;
                    if v.len() != 3 {
                        return None;
                    }
                    Some(Neighbor {
                        id: u64::try_from(v.get(0)?.try_to::<i64>().ok()?).ok()?,
                        position: crate::point(v.get(1)?.try_to().ok()?),
                        life: Life::try_from(u8::try_from(v.get(2)?.try_to::<i64>().ok()?).ok()?)
                            .ok()?,
                    })
                })
                .collect::<Option<Vec<_>>>()
        })() else {
            return PackedVector3Array::new();
        };
        let Ok(result) = infantry_motion::separation(
            id as u64,
            crate::point(position),
            active,
            &neighbors,
            &mut random.bind_mut().core,
        ) else {
            return PackedVector3Array::new();
        };
        [Vector3::new(result.x, result.y, result.z)]
            .as_slice()
            .into()
    }

    #[func]
    fn stationary(
        &mut self,
        values: PackedFloat64Array,
        path: PackedVector3Array,
        door: i64,
        inputs: Array<Variant>,
        planner: Gd<PathPlannerCore>,
        terrain: Gd<TerrainCore>,
        decks: PackedByteArray,
    ) -> Array<Variant> {
        let Some(input) = stationary_input(&inputs) else {
            return Array::new();
        };
        let Some(mut motion) = state(values.as_slice(), path, door) else {
            return Array::new();
        };
        let planner = planner.bind();
        let terrain = terrain.bind();
        let (Some(planner), Some(terrain)) = (&planner.core, &terrain.core) else {
            return Array::new();
        };
        let Ok(shuffle) = motion.stationary(input, planner, terrain, decks.as_slice()) else {
            return Array::new();
        };
        self.core = motion;
        varray![&observation(&self.core), shuffle]
    }

    #[func]
    fn checkpoint(&self) -> PackedByteArray {
        self.core.checkpoint().as_slice().into()
    }

    #[func]
    fn restore(&mut self, data: PackedByteArray) -> bool {
        let Ok(core) = InfantryMotion::restore(data.as_slice()) else {
            return false;
        };
        self.core = core;
        true
    }

    #[func]
    fn advance(
        &mut self,
        values: PackedFloat64Array,
        path: PackedVector3Array,
        door: i64,
        inputs: PackedFloat64Array,
        candidates: Array<Variant>,
        planner: Gd<PathPlannerCore>,
        terrain: Gd<TerrainCore>,
        mut collision: Gd<CollisionIndexCore>,
        mut random: Gd<SimulationRandomCore>,
        decks: PackedByteArray,
    ) -> Array<Variant> {
        let (Some(mut motion), Some(input), Some(doors)) = (
            state(values.as_slice(), path, door),
            context(inputs.as_slice()),
            doors(candidates),
        ) else {
            godot_error!("Invalid infantry motion input");
            return Array::new();
        };
        let planner = planner.bind();
        let terrain = terrain.bind();
        let (Some(planner), Some(terrain)) = (&planner.core, &terrain.core) else {
            return Array::new();
        };
        let Ok(result) = motion.step(
            input,
            planner,
            terrain,
            &mut collision.bind_mut().core,
            &mut random.bind_mut().core,
            decks.as_slice(),
            &doors,
        ) else {
            godot_error!("Invalid infantry motion state");
            return Array::new();
        };
        self.core = motion;
        let state = observation(&self.core);
        let ids = PackedInt64Array::from(&[self.core.door as i64, result.opened_door as i64]);
        varray![
            &state,
            &ids,
            result.progress as u8 as i32,
            result.speech.map_or(-1, i32::from),
            result.slid
        ]
    }
}

fn stationary_input(v: &Array<Variant>) -> Option<StationaryInput> {
    if v.len() != 14 {
        return None;
    }
    let mount: PackedFloat64Array = v.get(13)?.try_to().ok()?;
    if !mount.is_empty() && mount.len() != 4 {
        return None;
    }
    Some(StationaryInput {
        dt: v.get(0)?.try_to().ok()?,
        time: v.get(1)?.try_to().ok()?,
        base_y: v.get(2)?.try_to().ok()?,
        separation: crate::point(v.get(3)?.try_to().ok()?),
        prone: v.get(4)?.try_to().ok()?,
        at_cover: v.get(5)?.try_to().ok()?,
        cover_position: crate::point(v.get(6)?.try_to().ok()?),
        cover_normal: crate::point(v.get(7)?.try_to().ok()?),
        cover_kind: u8::try_from(v.get(8)?.try_to::<i64>().ok()?).ok()?,
        last_shot: v.get(9)?.try_to().ok()?,
        peek_up: v.get(10)?.try_to().ok()?,
        target_valid: v.get(11)?.try_to().ok()?,
        sector: crate::point(v.get(12)?.try_to().ok()?),
        mount: (!mount.is_empty()).then(|| {
            (
                frontline_core::vector::Vector3::new(
                    mount[0] as f32,
                    mount[1] as f32,
                    mount[2] as f32,
                ),
                mount[3],
            )
        }),
    })
}
