use crate::simulation_random::SimulationRandomCore;
use frontline_core::infantry_vitals::{
    DamageResult, FatigueInput, InfantryVitals, Life, Protection,
};
use godot::prelude::*;

#[derive(GodotClass)]
#[class(base=RefCounted, init)]
struct InfantryVitalsCore {
    base: Base<RefCounted>,
    core: InfantryVitals,
}

pub(crate) fn observation(s: InfantryVitals) -> PackedFloat64Array {
    PackedFloat64Array::from(&[
        s.life as u8 as f64,
        f64::from(s.times_downed),
        s.hp,
        s.max_hp,
        s.base_hp,
        s.suppression,
        s.last_suppression,
        s.reveal_until,
        s.bleed,
        s.bleed_max,
        s.stamina,
        s.speech_cooldown,
        s.hit_dirt_timer,
        s.downed_at,
        s.dead_at,
        s.scream_timer,
        s.pistol_timer,
        s.crawl_timer,
    ])
}

pub(crate) fn decode(v: &[f64]) -> Option<InfantryVitals> {
    if v.len() != 18
        || v.iter().any(|x| !x.is_finite())
        || v[0].fract() != 0.0
        || !(0.0..=5.0).contains(&v[0])
        || v[1].fract() != 0.0
        || !(0.0..=1_000_000.0).contains(&v[1])
    {
        return None;
    }
    let state = InfantryVitals {
        life: Life::try_from(v[0] as u8).ok()?,
        times_downed: v[1] as u32,
        hp: v[2],
        max_hp: v[3],
        base_hp: v[4],
        suppression: v[5],
        last_suppression: v[6],
        reveal_until: v[7],
        bleed: v[8],
        bleed_max: v[9],
        stamina: v[10],
        speech_cooldown: v[11],
        hit_dirt_timer: v[12],
        downed_at: v[13],
        dead_at: v[14],
        scream_timer: v[15],
        pistol_timer: v[16],
        crawl_timer: v[17],
    };
    state.valid().then_some(state)
}

fn flag(v: i32) -> bool {
    v == 0 || v == 1
}
fn protection(v: &[i32]) -> Option<Protection> {
    if v.len() != 6
        || ![0, 3, 4, 5].iter().all(|i| flag(v[*i]))
        || !(0..=3).contains(&v[1])
        || !(-1..=3).contains(&v[2])
    {
        return None;
    }
    Some(Protection {
        at_cover: v[0] != 0,
        cover_kind: v[1] as u8,
        material: (v[2] >= 0).then_some(v[2] as u8),
        peek_up: v[3] != 0,
        protected_mount: v[4] != 0,
        in_trench: v[5] != 0,
    })
}

#[godot_api]
impl InfantryVitalsCore {
    #[func]
    fn checkpoint(&self) -> PackedByteArray {
        self.core.checkpoint().as_slice().into()
    }

    #[func]
    fn restore(&mut self, bytes: PackedByteArray) -> bool {
        let Ok(state) = InfantryVitals::restore(bytes.as_slice()) else {
            return false;
        };
        self.core = state;
        true
    }

    #[func]
    fn recover(
        &mut self,
        values: PackedFloat64Array,
        dt: f64,
        time: f64,
        cover: PackedInt32Array,
    ) -> PackedFloat64Array {
        let (Some(mut state), Some(cover)) =
            (decode(values.as_slice()), protection(cover.as_slice()))
        else {
            godot_error!("Invalid infantry recovery input");
            return PackedFloat64Array::new();
        };
        if state.recover(dt, time, cover).is_err() {
            godot_error!("Invalid infantry recovery");
            return PackedFloat64Array::new();
        }
        self.core = state;
        observation(state)
    }

    #[func]
    fn fatigue(
        &mut self,
        values: PackedFloat64Array,
        dt: f64,
        flags: PackedInt32Array,
    ) -> PackedFloat64Array {
        let Some(mut state) = decode(values.as_slice()) else {
            godot_error!("Invalid infantry fatigue state");
            return PackedFloat64Array::new();
        };
        let v = flags.as_slice();
        if v.len() != 6 || ![0, 2, 3, 4, 5].iter().all(|i| flag(v[*i])) {
            godot_error!("Invalid infantry fatigue input");
            return PackedFloat64Array::new();
        }
        let input = FatigueInput {
            moving_or_diving: v[0] != 0,
            move_mode: v[1],
            crawling: v[2] != 0,
            heavy_task: v[3] != 0,
            carrying: v[4] != 0,
            standing: v[5] != 0,
        };
        if state.fatigue(dt, input).is_err() {
            godot_error!("Invalid infantry fatigue");
            return PackedFloat64Array::new();
        }
        self.core = state;
        observation(state)
    }

    #[func]
    fn suppress(
        &mut self,
        values: PackedFloat64Array,
        amount: f64,
        time: f64,
        retreat: bool,
        squad: bool,
        cover: PackedInt32Array,
        mut random: Gd<SimulationRandomCore>,
    ) -> Array<Variant> {
        let (Some(mut state), Some(cover)) =
            (decode(values.as_slice()), protection(cover.as_slice()))
        else {
            godot_error!("Invalid infantry suppression input");
            return Array::new();
        };
        let Ok(result) = state.suppress(
            amount,
            time,
            retreat,
            squad,
            cover,
            &mut random.bind_mut().core,
        ) else {
            godot_error!("Invalid infantry suppression");
            return Array::new();
        };
        self.core = state;
        varray![
            &observation(state),
            result.report_position,
            result.speech.map_or(-1, i32::from)
        ]
    }

    #[func]
    fn damage(
        &mut self,
        values: PackedFloat64Array,
        amount: f64,
        explosion: bool,
        bearer: bool,
        mut random: Gd<SimulationRandomCore>,
    ) -> Array<Variant> {
        let Some(mut state) = decode(values.as_slice()) else {
            godot_error!("Invalid infantry damage state");
            return Array::new();
        };
        let Ok(result) = state.damage(amount, explosion, bearer, &mut random.bind_mut().core)
        else {
            godot_error!("Invalid infantry damage");
            return Array::new();
        };
        self.core = state;
        let (transition, speech) = match result {
            DamageResult::Ignored => (0, -1),
            DamageResult::Survived(speech) => (1, speech.map_or(-1, i32::from)),
            DamageResult::Down => (2, -1),
            DamageResult::Die => (3, -1),
        };
        varray![&observation(state), transition, speech]
    }

    #[func]
    fn wounded_step(
        &mut self,
        values: PackedFloat64Array,
        stage: i32,
        dt: f64,
        rescued: bool,
        medicine: bool,
        mut random: Gd<SimulationRandomCore>,
    ) -> Array<Variant> {
        let Some(mut state) = decode(values.as_slice()) else {
            return Array::new();
        };
        let result = match stage {
            0 => state.bleed_step(dt, rescued, medicine),
            1 => state.scream_step(dt, &mut random.bind_mut().core),
            2 => state.pistol_step(dt, &mut random.bind_mut().core),
            3 => state.crawl_step(dt),
            _ => Err("invalid wounded infantry stage"),
        };
        let Ok(event) = result else {
            return Array::new();
        };
        self.core = state;
        varray![&observation(state), event]
    }

    #[func]
    fn corpse_step(
        &mut self,
        values: PackedFloat64Array,
        height: f32,
        ground: f64,
        time: f64,
        carried: bool,
        carrier_alive: bool,
        stretcher_claimed: bool,
    ) -> Array<Variant> {
        let Some(state) = decode(values.as_slice()) else {
            return Array::new();
        };
        let Ok(result) = state.corpse_step(
            height,
            ground,
            time,
            carried,
            carrier_alive,
            stretcher_claimed,
        ) else {
            return Array::new();
        };
        self.core = state;
        varray![
            result.height,
            result.carried,
            result.clear_carriers,
            result.despawn
        ]
    }

    #[func]
    fn transition(
        &mut self,
        values: PackedFloat64Array,
        kind: i64,
        time: f64,
        full: bool,
    ) -> PackedFloat64Array {
        let Some(mut state) = decode(values.as_slice()) else {
            godot_error!("Invalid infantry transition state");
            return PackedFloat64Array::new();
        };
        let result = match kind {
            0 => state.go_down(time),
            1 => state.die(time),
            2 => state.revive(full),
            _ => Err("invalid infantry transition"),
        };
        if result.is_err() {
            godot_error!("Invalid infantry transition");
            return PackedFloat64Array::new();
        }
        self.core = state;
        observation(state)
    }
}
