use crate::simulation_random::SimulationRandomCore;
use frontline_core::infantry_weapon::{CoverInput, InfantryWeapon, ShotInput, StanceInput, Weapon};
use godot::prelude::*;

#[derive(GodotClass)]
#[class(base=RefCounted, init)]
struct InfantryWeaponCore {
    base: Base<RefCounted>,
    core: InfantryWeapon,
}

pub(crate) fn observation(s: &InfantryWeapon) -> PackedFloat64Array {
    PackedFloat64Array::from(&[
        s.peek_timer,
        s.peek_from,
        s.up_suppression,
        s.reload_timer,
        f64::from(s.peek_up),
        f64::from(s.stayed),
        f64::from(s.watching),
        f64::from(s.blind),
        f64::from(s.burst_left),
        f64::from(s.magazine),
        f64::from(s.reserve),
        s.fire_timer,
        s.last_shot,
        f64::from(s.low_ammo_said),
    ])
}

fn flag(value: f64) -> bool {
    value == 0.0 || value == 1.0
}
fn integer(value: f64) -> bool {
    value.is_finite() && value.fract() == 0.0 && value.abs() <= 1_000_000.0
}

pub(crate) fn decode_state(values: &[f64]) -> Option<InfantryWeapon> {
    if values.len() != 14
        || values.iter().any(|v| !v.is_finite())
        || !values[4..8].iter().chain(&values[13..14]).all(|v| flag(*v))
        || !values[8..11].iter().all(|v| integer(*v))
    {
        return None;
    }
    let state = InfantryWeapon {
        peek_timer: values[0],
        peek_from: values[1],
        up_suppression: values[2],
        reload_timer: values[3],
        peek_up: values[4] != 0.0,
        stayed: values[5] != 0.0,
        watching: values[6] != 0.0,
        blind: values[7] != 0.0,
        burst_left: values[8] as i32,
        magazine: values[9] as i32,
        reserve: values[10] as i32,
        fire_timer: values[11],
        last_shot: values[12],
        low_ammo_said: values[13] != 0.0,
    };
    state.valid().then_some(state)
}

fn decode(values: &[f64], input: &[f64]) -> Option<(InfantryWeapon, CoverInput)> {
    let state = decode_state(values)?;
    if input.len() != 17
        || input.iter().any(|v| !v.is_finite())
        || !input[10..14].iter().all(|v| flag(*v))
        || ![2, 7, 9, 14, 15].iter().all(|i| integer(input[*i]))
        || !(0.0..=3.0).contains(&input[7])
        || input[14] < -1.0
    {
        return None;
    }
    let context = CoverInput {
        dt: input[0],
        time: input[1],
        team: input[2] as i32,
        suppression: input[3],
        last_suppression: input[4],
        hit_dirt_timer: input[5],
        ground: input[6],
        cover_kind: input[7] as u8,
        cover_height: input[8],
        cover_material: input[9] as i32,
        want_fire: input[10] != 0.0,
        pinned: input[11] != 0.0,
        target_valid: input[12] != 0.0,
        buddy_up: input[13] != 0.0,
        weapon: (input[14] >= 0.0).then_some(Weapon {
            ammunition: input[14] as i32,
            magazine: input[15] as i32,
            reload_time: input[16],
        }),
    };
    Some((state, context))
}

fn decode_weapon(values: &[f64]) -> Option<Weapon> {
    if values.len() < 3 || !integer(values[0]) || !integer(values[1]) {
        return None;
    }
    Some(Weapon {
        ammunition: values[0] as i32,
        magazine: values[1] as i32,
        reload_time: values[2],
    })
}

#[godot_api]
impl InfantryWeaponCore {
    #[func]
    fn stance(
        &mut self,
        values: PackedFloat64Array,
        inputs: PackedFloat64Array,
        entity: i64,
        threat: Vector3,
        lean: Vector3,
    ) -> Array<Variant> {
        let Some(mut state) = decode_state(values.as_slice()) else {
            godot_error!("Invalid infantry stance state");
            return Array::new();
        };
        let i = inputs.as_slice();
        if i.len() != 26
            || entity < 0
            || ![1, 5, 8]
                .iter()
                .all(|n| integer(i[*n]) && (0.0..=3.0).contains(&i[*n]))
            || ![
                2, 3, 4, 6, 7, 10, 11, 12, 13, 16, 17, 18, 19, 20, 21, 22, 23, 25,
            ]
            .iter()
            .all(|n| flag(i[*n]))
        {
            godot_error!("Invalid infantry stance parameters");
            return Array::new();
        }
        let input = StanceInput {
            time: i[0],
            entity: entity as u64,
            mode: i[1] as u8,
            moving: i[2] != 0.0,
            crawling: i[3] != 0.0,
            near_cover: i[4] != 0.0,
            move_mode: i[5] as u8,
            shifting: i[6] != 0.0,
            at_cover: i[7] != 0.0,
            cover_kind: i[8] as u8,
            cover_height: i[9],
            mounted: i[10] != 0.0,
            bay: i[11] != 0.0,
            danger: i[12] != 0.0,
            pinned: i[13] != 0.0,
            suppression: i[14],
            hit_dirt_timer: i[15],
            sector: i[16] != 0.0,
            machine_gunner: i[17] != 0.0,
            target_valid: i[18] != 0.0,
            covering: i[19] != 0.0,
            crew_mount: i[20] != 0.0,
            armed: i[21] != 0.0,
            ambush: i[22] != 0.0,
            forced_target: i[23] != 0.0,
            yaw: i[24],
            threat: frontline_core::vector::Vector3::new(threat.x, threat.y, threat.z),
            lean_direction: frontline_core::vector::Vector3::new(lean.x, lean.y, lean.z),
        };
        let Ok(result) = state.stance(input, i[25] != 0.0) else {
            godot_error!("Invalid infantry stance");
            return Array::new();
        };
        self.core = state;
        varray![
            &observation(&state),
            i32::from(result.posture),
            result.can_aim,
            i32::from(result.face_threat)
        ]
    }

    #[func]
    fn advance_timers(
        &mut self,
        values: PackedFloat64Array,
        dt: f64,
        weapon: PackedFloat64Array,
    ) -> PackedFloat64Array {
        let (Some(mut state), Some(weapon)) = (
            decode_state(values.as_slice()),
            decode_weapon(weapon.as_slice()),
        ) else {
            godot_error!("Invalid infantry timer input");
            return PackedFloat64Array::new();
        };
        if state.advance_timers(dt, weapon).is_err() {
            godot_error!("Invalid infantry timers");
            return PackedFloat64Array::new();
        }
        self.core = state;
        observation(&state)
    }

    #[func]
    fn prepare_shot(
        &mut self,
        values: PackedFloat64Array,
        inputs: PackedFloat64Array,
        mut random: Gd<SimulationRandomCore>,
    ) -> Array<Variant> {
        let i = inputs.as_slice();
        let (Some(mut state), Some(weapon)) = (decode_state(values.as_slice()), decode_weapon(i))
        else {
            godot_error!("Invalid infantry shot input");
            return Array::new();
        };
        if i.len() != 11
            || !integer(i[3])
            || !integer(i[4])
            || ![7, 8, 10].iter().all(|n| flag(i[*n]))
        {
            godot_error!("Invalid infantry shot parameters");
            return Array::new();
        }
        let input = ShotInput {
            weapon,
            burst_min: i[3] as i32,
            burst_max: i[4] as i32,
            time: i[5],
            stamina: i[6],
            moving: i[7] != 0.0,
            gun_override: i[8] != 0.0,
            squad_accuracy: i[9],
            ambush: i[10] != 0.0,
        };
        let Ok(result) = state.prepare_shot(input, &mut random.bind_mut().core) else {
            godot_error!("Invalid infantry shot state");
            return Array::new();
        };
        self.core = state;
        varray![
            &observation(&state),
            result.fired,
            result.low_ammo,
            result.announce_low_ammo,
            result.reload_speech.map_or(-1, i32::from),
            result.accuracy
        ]
    }

    #[func]
    fn finish_shot(
        &mut self,
        values: PackedFloat64Array,
        inputs: PackedFloat64Array,
        mut random: Gd<SimulationRandomCore>,
    ) -> Array<Variant> {
        let i = inputs.as_slice();
        let (Some(mut state), Some(weapon)) = (decode_state(values.as_slice()), decode_weapon(i))
        else {
            godot_error!("Invalid infantry recovery input");
            return Array::new();
        };
        if i.len() != 7 || !flag(i[5]) || !flag(i[6]) {
            godot_error!("Invalid infantry recovery parameters");
            return Array::new();
        }
        let Ok(speech) = state.finish_shot(
            weapon,
            i[3],
            i[4],
            i[5] != 0.0,
            i[6] != 0.0,
            &mut random.bind_mut().core,
        ) else {
            godot_error!("Invalid infantry recovery state");
            return Array::new();
        };
        self.core = state;
        varray![&observation(&state), speech.map_or(-1, i32::from)]
    }

    #[func]
    fn checkpoint(&self) -> PackedByteArray {
        self.core.checkpoint().as_slice().into()
    }

    #[func]
    fn restore(&mut self, bytes: PackedByteArray) -> bool {
        let Ok(state) = InfantryWeapon::restore(bytes.as_slice()) else {
            return false;
        };
        self.core = state;
        true
    }

    #[func]
    fn cover_cycle(
        &mut self,
        values: PackedFloat64Array,
        inputs: PackedFloat64Array,
        mut random: Gd<SimulationRandomCore>,
    ) -> Array<Variant> {
        let Some((mut state, context)) = decode(values.as_slice(), inputs.as_slice()) else {
            godot_error!("Invalid infantry firing input");
            return Array::new();
        };
        let Ok(result) = state.cover_cycle(context, &mut random.bind_mut().core) else {
            godot_error!("Invalid infantry firing state");
            return Array::new();
        };
        self.core = state;
        let events = PackedInt32Array::from(&[
            i32::from(result.drew_fire),
            i32::from(result.peeked),
            i32::from(result.blind_fire),
            result.reload_speech.map_or(-1, i32::from),
            i32::from(result.call_cover),
            i32::from(result.shift_along),
        ]);
        varray![&observation(&state), &events]
    }
}
