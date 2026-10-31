use crate::simulation_random::SimulationRandomCore;
use frontline_core::infantry_idle::{self as idle, Calm, Decision, Idle, Line, Mate};
use godot::prelude::*;

#[derive(GodotClass)]
#[class(base=RefCounted, init)]
struct InfantryIdleCore {
    base: Base<RefCounted>,
    core: Idle,
}

fn read<T: FromGodot>(v: &Array<Variant>, n: usize) -> Option<T> {
    v.get(n)?.try_to().ok()
}
fn state(v: &Array<Variant>) -> Option<Idle> {
    if v.len() != 7 {
        return None;
    }
    let lines: Array<Variant> = read(v, 5)?;
    if lines.len() > 128 {
        return None;
    }
    let lines = lines
        .iter_shared()
        .map(|line| {
            let line: Array<Variant> = line.try_to().ok()?;
            if line.len() != 2 {
                return None;
            }
            Some(Line {
                at: read(&line, 0)?,
                text: read::<GString>(&line, 1)?.to_string(),
            })
        })
        .collect::<Option<_>>()?;
    let s = Idle {
        calm: read(v, 0)?,
        activity: u8::try_from(read::<i32>(v, 1)?).ok()?,
        until: read(v, 2)?,
        next: read(v, 3)?,
        partner: u64::try_from(read::<i64>(v, 4)?).ok()?,
        lines,
        laugh_until: read(v, 6)?,
    };
    s.valid().then_some(s)
}
fn encode(s: &Idle) -> Array<Variant> {
    let mut lines = Array::<Variant>::new();
    for line in &s.lines {
        lines.push(&varray![line.at, &GString::from(&line.text)].to_variant());
    }
    varray![
        s.calm,
        i32::from(s.activity),
        s.until,
        s.next,
        s.partner as i64,
        &lines,
        s.laugh_until
    ]
}
fn calm(v: &Array<Variant>) -> Option<Calm> {
    if v.len() != 10 {
        return None;
    }
    Some(Calm {
        moving: read(v, 2)?,
        danger: read(v, 3)?,
        sector: crate::point(read(v, 4)?),
        reload: read(v, 5)?,
        last_shot: read(v, 6)?,
        mounted: read(v, 7)?,
        target: read(v, 8)?,
    })
}

#[godot_api]
impl InfantryIdleCore {
    #[func]
    fn step(&mut self, values: Array<Variant>, context: Array<Variant>) -> Array<Variant> {
        let (Some(mut s), Some(c), Some(dt), Some(now), Some(partner)) = (
            state(&values),
            calm(&context),
            read(&context, 0),
            read(&context, 1),
            read(&context, 9),
        ) else {
            return Array::new();
        };
        let Ok(result) = s.tick(dt, now, c, partner) else {
            return Array::new();
        };
        let code = match result {
            Decision::Wait => 0,
            Decision::End => 1,
            Decision::Pose => 2,
            Decision::Chat => 3,
            Decision::Start => 4,
        };
        self.core = s;
        varray![&encode(&self.core), code]
    }

    #[func]
    fn begin(
        &mut self,
        values: Array<Variant>,
        now: f64,
        last_chat: f64,
        mut rng: Gd<SimulationRandomCore>,
    ) -> Array<Variant> {
        let Some(mut s) = state(&values) else {
            return Array::new();
        };
        let Ok(search) = s.begin(now, last_chat, &mut rng.bind_mut().core) else {
            return Array::new();
        };
        self.core = s;
        varray![&encode(&self.core), search]
    }

    #[func]
    fn solo(
        &mut self,
        values: Array<Variant>,
        now: f64,
        team: i32,
        mut rng: Gd<SimulationRandomCore>,
    ) -> Array<Variant> {
        let Some(mut s) = state(&values) else {
            return Array::new();
        };
        let Ok(text) = s.solo(now, team, &mut rng.bind_mut().core) else {
            return Array::new();
        };
        self.core = s;
        varray![&encode(&self.core), &GString::from(text.unwrap_or(""))]
    }

    #[func]
    fn chat(
        &mut self,
        values: Array<Variant>,
        other: Array<Variant>,
        ids: PackedInt64Array,
        now: f64,
        team: i32,
        names: PackedStringArray,
        mut rng: Gd<SimulationRandomCore>,
    ) -> Array<Variant> {
        let (Some(mut s), Some(mut other)) = (state(&values), state(&other)) else {
            return Array::new();
        };
        if ids.len() != 2 || names.len() != 2 || ids.as_slice().iter().any(|i| *i <= 0) {
            return Array::new();
        }
        if s.start_chat(
            &mut other,
            ids[0] as u64,
            ids[1] as u64,
            now,
            team,
            &names[0].to_string(),
            &names[1].to_string(),
            &mut rng.bind_mut().core,
        )
        .is_err()
        {
            return Array::new();
        }
        self.core = s;
        varray![&encode(&self.core), &encode(&other)]
    }

    #[func]
    fn line(
        &mut self,
        values: Array<Variant>,
        now: f64,
        mut rng: Gd<SimulationRandomCore>,
    ) -> Array<Variant> {
        let Some(mut s) = state(&values) else {
            return Array::new();
        };
        let Ok(line) = s.next_line(now, &mut rng.bind_mut().core) else {
            return Array::new();
        };
        let (code, text) = match line {
            None => (0, String::new()),
            Some(None) => (1, String::new()),
            Some(Some(text)) => (2, text),
        };
        self.core = s;
        varray![&encode(&self.core), code, &GString::from(&text)]
    }

    #[func]
    fn end(
        &mut self,
        values: Array<Variant>,
        now: f64,
        mut rng: Gd<SimulationRandomCore>,
    ) -> Array<Variant> {
        let Some(mut s) = state(&values) else {
            return Array::new();
        };
        let Ok(partner) = s.end(now, &mut rng.bind_mut().core) else {
            return Array::new();
        };
        self.core = s;
        varray![&encode(&self.core), partner as i64]
    }

    #[func]
    fn mate(&self, actor: i64, team: i32, nearby: Array<Variant>) -> i64 {
        if actor <= 0 || nearby.len() > 100_000 {
            return -1;
        }
        let nearby = nearby
            .iter_shared()
            .map(|row| {
                let row: Array<Variant> = row.try_to().ok()?;
                if row.len() != 7 {
                    return None;
                }
                Some(Mate {
                    id: u64::try_from(read::<i64>(&row, 0)?).ok()?,
                    team: read(&row, 1)?,
                    life: u8::try_from(read::<i32>(&row, 2)?).ok()?.try_into().ok()?,
                    chatting: read(&row, 3)?,
                    calm: read(&row, 4)?,
                    free: read(&row, 5)?,
                    moving: read(&row, 6)?,
                })
            })
            .collect::<Option<Vec<_>>>();
        let Some(nearby) = nearby else {
            return -1;
        };
        idle::select_mate(actor as u64, team, &nearby).map_or(-1, |id| id.unwrap_or(0) as i64)
    }

    #[func]
    fn facing(
        &self,
        position: Vector3,
        other: Vector3,
        yaw: f64,
        dt: f64,
        mounted: PackedFloat64Array,
    ) -> Variant {
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
            _ => return Variant::nil(),
        };
        idle::chat_yaw(crate::point(position), crate::point(other), yaw, dt, mount)
            .map_or_else(|_| Variant::nil(), |yaw| yaw.to_variant())
    }

    #[func]
    fn checkpoint(&self) -> PackedByteArray {
        self.core.checkpoint().as_slice().into()
    }
    #[func]
    fn restore(&mut self, bytes: PackedByteArray) -> bool {
        let Ok(core) = Idle::restore(bytes.as_slice()) else {
            return false;
        };
        self.core = core;
        true
    }
}
