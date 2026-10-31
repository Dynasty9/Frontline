use crate::actors::ActorStateCore;
use crate::simulation_random::SimulationRandomCore;
use frontline_core::infantry::Opening;
use frontline_core::squad::*;
use godot::prelude::*;

#[derive(GodotClass)]
#[class(base=RefCounted, init)]
pub(crate) struct SquadStateCore {
    base: Base<RefCounted>,
    pub(crate) core: Option<Squad>,
}

fn read<T: FromGodot>(a: &Array<Variant>, n: usize) -> Option<T> {
    a.get(n)?.try_to().ok()
}
fn row(a: &Array<Variant>, n: usize, size: usize) -> Option<Array<Variant>> {
    let a: Array<Variant> = read(a, n)?;
    (a.len() == size).then_some(a)
}
fn text(a: &Array<Variant>, n: usize) -> Option<String> {
    let v: GString = read(a, n)?;
    if v.len() > 128 {
        return None;
    }
    let v = v.to_string();
    (v.len() <= 128).then_some(v)
}
fn id(a: &Array<Variant>, n: usize) -> Option<u32> {
    u32::try_from(read::<i64>(a, n)?).ok()
}
fn p(a: &Array<Variant>, n: usize) -> Option<frontline_core::vector::Vector3> {
    Some(crate::point(read(a, n)?))
}
fn vector(p: frontline_core::vector::Vector3) -> Vector3 {
    Vector3::new(p.x, p.y, p.z)
}
fn rows<T>(
    a: &Array<Variant>,
    n: usize,
    limit: usize,
    mut f: impl FnMut(&Array<Variant>) -> Option<T>,
) -> Option<Vec<T>> {
    let v: Array<Variant> = read(a, n)?;
    if v.len() > limit {
        return None;
    }
    v.iter_shared()
        .map(|v| f(&v.try_to::<Array<Variant>>().ok()?))
        .collect()
}
fn points(
    a: &Array<Variant>,
    n: usize,
    limit: usize,
) -> Option<Vec<frontline_core::vector::Vector3>> {
    let v: PackedVector3Array = read(a, n)?;
    if v.len() > limit {
        return None;
    }
    Some(v.as_slice().iter().copied().map(crate::point).collect())
}
fn pairs(a: &Array<Variant>, n: usize) -> Option<Vec<(u32, f64)>> {
    rows(a, n, 100_000, |r| {
        (r.len() == 2).then(|| Some((id(r, 0)?, read(r, 1)?)))?
    })
}
fn reports(a: &Array<Variant>, n: usize, limit: usize) -> Option<Vec<Report>> {
    rows(a, n, limit, |r| {
        (r.len() == 2).then(|| {
            Some(Report {
                position: p(r, 0)?,
                time: read(r, 1)?,
            })
        })?
    })
}
fn contacts(a: &Array<Variant>, n: usize) -> Option<Vec<Contact>> {
    rows(a, n, 100_000, |r| {
        (r.len() == 3).then(|| {
            Some(Contact {
                id: id(r, 0)?,
                report: Report {
                    position: p(r, 1)?,
                    time: read(r, 2)?,
                },
            })
        })?
    })
}
fn state(a: &Array<Variant>) -> Option<Squad> {
    if a.len() != 9 {
        return None;
    }
    let ident = row(a, 0, 11)?;
    let strings = row(a, 1, 4)?;
    let times: PackedFloat64Array = read(a, 2)?;
    let v = points(a, 3, 7)?;
    let flags: PackedInt32Array = read(a, 4)?;
    if times.len() != 17
        || v.len() != 7
        || flags.len() != 8
        || flags.as_slice()[..3].iter().any(|b| !matches!(b, 0 | 1))
    {
        return None;
    }
    let knowledge = row(a, 5, 6)?;
    let dictionaries = row(a, 6, 5)?;
    let opt = row(a, 8, 6)?;
    let members: PackedInt64Array = read(&ident, 4)?;
    if members.len() > 4096 {
        return None;
    }
    let members: Option<Vec<u32>> = members
        .as_slice()
        .iter()
        .map(|&id| u32::try_from(id).ok())
        .collect();
    let tunnel = points(&opt, 0, 1)?;
    let previous: Array<Variant> = read(&opt, 1)?;
    let previous_order = if previous.is_empty() {
        None
    } else {
        if previous.len() != 4 {
            return None;
        }
        Some(SavedOrder {
            order: text(&previous, 0)?,
            position: p(&previous, 1)?,
            facing: p(&previous, 2)?,
            mode: read(&previous, 3)?,
        })
    };
    let defend = points(&opt, 2, 2)?;
    let halt = points(&opt, 3, 2)?;
    if defend.len() == 1 || halt.len() == 1 {
        return None;
    }
    let clear: Array<Variant> = read(&opt, 4)?;
    let clear_house = if clear.is_empty() {
        None
    } else {
        if clear.len() != 4 {
            return None;
        }
        let opening = row(&clear, 1, 4)?;
        Some(ClearHouse {
            house: id(&clear, 0)?,
            soldier: id(&clear, 2)?,
            buddy: id(&clear, 3)?,
            opening: Opening {
                id: u64::from(id(&opening, 0)?),
                center: p(&opening, 1)?,
                normal: p(&opening, 2)?,
                door: read(&opening, 3)?,
            },
        })
    };
    let call: Array<Variant> = read(&opt, 5)?;
    let clear_call = if call.is_empty() {
        None
    } else {
        if call.len() != 2 {
            return None;
        }
        Some((id(&call, 0)?, read(&call, 1)?))
    };
    let s = Squad {
        id: id(&ident, 0)?,
        team: read(&ident, 1)?,
        owner: read(&ident, 2)?,
        kind: text(&ident, 3)?,
        members: members?,
        leader: id(&ident, 5)?,
        plan: id(&ident, 6)?,
        ambush_plan: id(&ident, 7)?,
        build_target: id(&ident, 8)?,
        breach_by: id(&ident, 9)?,
        order_number: u64::try_from(read::<i64>(&ident, 10)?).ok()?,
        order: text(&strings, 0)?,
        shown_order: text(&strings, 1)?,
        drill: text(&strings, 2)?,
        technique: text(&strings, 3)?,
        combat_at: times[0],
        centroid_at: times[1],
        briefing_at: times[2],
        buildings_at: times[3],
        cover_fire_until: times[4],
        think_timer: times[5],
        bound_time: times[6],
        contact_time: times[7],
        alert_time: times[8],
        morale: times[9],
        drill_time: times[10],
        last_casualty: times[11],
        displace_cooldown: times[12],
        ammo_timer: times[13],
        ambush_time: times[14],
        overwatch_time: times[15],
        recon_fire_time: times[16],
        center: v[0],
        order_position: v[1],
        facing: v[2],
        cover_fire_position: v[3],
        drill_position: v[4],
        halt_destination: v[5],
        halt_face: v[6],
        combat: flags[0] != 0,
        travel: flags[1] != 0,
        ambush: flags[2] != 0,
        bound_team: u8::try_from(flags[3]).ok()?,
        travel_mode: u8::try_from(flags[4]).ok()?,
        halt_mode: u8::try_from(flags[5]).ok()?,
        move_mode: u8::try_from(flags[6]).ok()?,
        overwatch_team: u8::try_from(flags[7]).ok()?,
        known: contacts(&knowledge, 0)?,
        known_at_order: contacts(&knowledge, 1)?,
        heard: reports(&knowledge, 2, 8)?,
        impacts: reports(&knowledge, 3, 100_000)?,
        briefing: points(&knowledge, 4, 3)?,
        buildings: rows(&knowledge, 5, 100_000, |r| {
            (r.len() == 2).then(|| Some((id(r, 0)?, id(r, 1)?)))?
        })?,
        smoked: pairs(&dictionaries, 0)?,
        cleared: pairs(&dictionaries, 1)?,
        final_slots: rows(&dictionaries, 2, 4096, |r| {
            (r.len() == 2).then(|| Some((id(r, 0)?, p(r, 1)?)))?
        })?,
        offsets: rows(&dictionaries, 3, 4096, |r| {
            if r.len() != 2 {
                return None;
            }
            let p: Vector2 = read(r, 1)?;
            Some((id(r, 0)?, [p.x, p.y]))
        })?,
        cooldowns: rows(&dictionaries, 4, 1024, |r| {
            (r.len() == 2).then(|| Some((text(r, 0)?, read(r, 1)?)))?
        })?,
        fire_queue: rows(a, 7, 100_000, |r| {
            (r.len() == 2).then(|| Some((p(r, 0)?, read(r, 1)?)))?
        })?,
        tunnel_exit: tunnel.first().copied(),
        previous_order,
        then_defend: defend.try_into().ok(),
        halt_then: halt.try_into().ok(),
        clear_house,
        clear_call,
    };
    s.valid().then_some(s)
}
fn vectors(p: impl IntoIterator<Item = frontline_core::vector::Vector3>) -> PackedVector3Array {
    p.into_iter().map(vector).collect()
}
fn entries<T>(items: &[T], mut f: impl FnMut(&T) -> Array<Variant>) -> Array<Variant> {
    items.iter().map(|v| f(v).to_variant()).collect()
}
fn values(s: &Squad) -> Array<Variant> {
    let ident = varray![
        i64::from(s.id),
        i32::from(s.team),
        s.owner,
        &GString::from(&s.kind),
        &s.members
            .iter()
            .copied()
            .map(i64::from)
            .collect::<PackedInt64Array>(),
        i64::from(s.leader),
        i64::from(s.plan),
        i64::from(s.ambush_plan),
        i64::from(s.build_target),
        i64::from(s.breach_by),
        s.order_number as i64
    ];
    let strings = varray![
        &GString::from(&s.order),
        &GString::from(&s.shown_order),
        &GString::from(&s.drill),
        &GString::from(&s.technique)
    ];
    let times = PackedFloat64Array::from(
        [
            s.combat_at,
            s.centroid_at,
            s.briefing_at,
            s.buildings_at,
            s.cover_fire_until,
            s.think_timer,
            s.bound_time,
            s.contact_time,
            s.alert_time,
            s.morale,
            s.drill_time,
            s.last_casualty,
            s.displace_cooldown,
            s.ammo_timer,
            s.ambush_time,
            s.overwatch_time,
            s.recon_fire_time,
        ]
        .as_slice(),
    );
    let pts = vectors([
        s.center,
        s.order_position,
        s.facing,
        s.cover_fire_position,
        s.drill_position,
        s.halt_destination,
        s.halt_face,
    ]);
    let flags = PackedInt32Array::from(
        [
            i32::from(s.combat),
            i32::from(s.travel),
            i32::from(s.ambush),
            s.bound_team as i32,
            s.travel_mode as i32,
            s.halt_mode as i32,
            s.move_mode as i32,
            s.overwatch_team as i32,
        ]
        .as_slice(),
    );
    let cs = |c: &Contact| varray![i64::from(c.id), vector(c.report.position), c.report.time];
    let rs = |r: &Report| varray![vector(r.position), r.time];
    let knowledge = varray![
        &entries(&s.known, cs),
        &entries(&s.known_at_order, cs),
        &entries(&s.heard, rs),
        &entries(&s.impacts, rs),
        &vectors(s.briefing.iter().copied()),
        &entries(&s.buildings, |(a, b)| varray![i64::from(*a), i64::from(*b)])
    ];
    let pairs = |p: &(u32, f64)| varray![i64::from(p.0), p.1];
    let dicts = varray![
        &entries(&s.smoked, pairs),
        &entries(&s.cleared, pairs),
        &entries(&s.final_slots, |(id, p)| varray![
            i64::from(*id),
            vector(*p)
        ]),
        &entries(&s.offsets, |(id, p)| varray![
            i64::from(*id),
            Vector2::new(p[0], p[1])
        ]),
        &entries(&s.cooldowns, |(k, t)| varray![&GString::from(k), *t])
    ];
    let previous = s.previous_order.as_ref().map_or_else(Array::new, |o| {
        varray![
            &GString::from(&o.order),
            vector(o.position),
            vector(o.facing),
            o.mode as i32
        ]
    });
    let clear = s.clear_house.map_or_else(Array::new, |c| {
        varray![
            i64::from(c.house),
            &varray![
                c.opening.id as i64,
                vector(c.opening.center),
                vector(c.opening.normal),
                c.opening.door
            ],
            i64::from(c.soldier),
            i64::from(c.buddy)
        ]
    });
    let call = s
        .clear_call
        .map_or_else(Array::new, |(id, t)| varray![i64::from(id), t]);
    let options = varray![
        &vectors(s.tunnel_exit),
        &previous,
        &vectors(s.then_defend.into_iter().flatten()),
        &vectors(s.halt_then.into_iter().flatten()),
        &clear,
        &call
    ];
    varray![
        &ident,
        &strings,
        &times,
        &pts,
        &flags,
        &knowledge,
        &dicts,
        &entries(&s.fire_queue, |(p, b)| varray![vector(*p), *b]),
        &options
    ]
}

#[godot_api]
impl SquadStateCore {
    #[func]
    fn load_state(&mut self, values: Array<Variant>) -> bool {
        let Some(s) = state(&values) else {
            return false;
        };
        self.core = Some(s);
        true
    }
    #[func]
    fn values(&self) -> Array<Variant> {
        self.core.as_ref().map_or_else(Array::new, values)
    }
    #[func]
    fn checkpoint(&self) -> PackedByteArray {
        self.core
            .as_ref()
            .and_then(|s| s.checkpoint().ok())
            .map_or_else(PackedByteArray::new, |b| b.as_slice().into())
    }
    #[func]
    fn restore(&mut self, bytes: PackedByteArray) -> bool {
        let Ok(s) = Squad::restore(bytes.as_slice()) else {
            return false;
        };
        self.core = Some(s);
        true
    }
    #[func]
    fn centroid(&mut self, now: f64, actors: Gd<ActorStateCore>) -> PackedVector3Array {
        if !now.is_finite() || now.abs() > 1e12 {
            return PackedVector3Array::new();
        }
        self.core
            .as_mut()
            .map_or_else(PackedVector3Array::new, |s| {
                vectors([s.centroid(now, &actors.bind().core)])
            })
    }
    #[func]
    fn report(&mut self, id: u32, position: Vector3, now: f64) -> bool {
        self.core.as_mut().is_some_and(|s| {
            s.report(Contact {
                id,
                report: Report {
                    position: crate::point(position),
                    time: now,
                },
            })
            .is_ok()
        })
    }
    #[func]
    fn report_position(&mut self, position: Vector3, now: f64) -> bool {
        self.core
            .as_mut()
            .is_some_and(|s| s.report_position(crate::point(position), now).is_ok())
    }
    #[func]
    fn in_combat(&mut self, now: f64) -> i32 {
        if !now.is_finite() || now.abs() > 1e12 {
            return -1;
        }
        self.core
            .as_mut()
            .map_or(-1, |s| i32::from(s.in_combat(now)))
    }
    #[func]
    fn tactical(&self, now: f64) -> i32 {
        if !now.is_finite() || now.abs() > 1e12 {
            return -1;
        }
        self.core
            .as_ref()
            .map_or(-1, |s| i32::from(s.tactical(now)))
    }
    #[func]
    fn get_leader(
        &mut self,
        mut actors: Gd<ActorStateCore>,
        bearers: PackedInt64Array,
        mut rng: Gd<SimulationRandomCore>,
    ) -> PackedInt64Array {
        if bearers.len() > 4096
            || bearers
                .as_slice()
                .iter()
                .any(|&id| u32::try_from(id).is_err() || id == 0)
        {
            return PackedInt64Array::new();
        }
        let Some(s) = self.core.as_mut() else {
            return PackedInt64Array::new();
        };
        let (id, speech) = s.get_leader(
            &mut actors.bind_mut().core,
            |s| bearers.as_slice().contains(&i64::from(s.identity.id)),
            &mut rng.bind_mut().core,
        );
        [i64::from(id), speech.map_or(-1, |s| i64::from(s.cue))]
            .as_slice()
            .into()
    }
    #[func]
    fn casualty(
        &mut self,
        id: u32,
        now: f64,
        mut actors: Gd<ActorStateCore>,
        mut rng: Gd<SimulationRandomCore>,
    ) -> PackedInt64Array {
        let Some(s) = self.core.as_mut() else {
            return PackedInt64Array::new();
        };
        match s.casualty(
            id,
            now,
            &mut actors.bind_mut().core,
            &mut rng.bind_mut().core,
        ) {
            Ok(speech) => [
                speech.map_or(0, |s| i64::from(s.soldier)),
                speech.map_or(-1, |s| i64::from(s.cue)),
            ]
            .as_slice()
            .into(),
            Err(_) => PackedInt64Array::new(),
        }
    }
    #[func]
    fn threat_points(
        &mut self,
        origin: Vector3,
        count: i32,
        now: f64,
        sector: bool,
        actors: Gd<ActorStateCore>,
    ) -> Array<Variant> {
        if !origin.is_finite()
            || crate::point(origin).abs().max_element() > 1_000_000.0
            || !now.is_finite()
            || now.abs() > 1e12
            || !(0..=100_000).contains(&count)
        {
            return Array::new();
        }
        let Some(s) = self.core.as_mut() else {
            return Array::new();
        };
        let result = if sector {
            s.sector_threats(crate::point(origin), now, &actors.bind().core)
        } else {
            s.threat_points(
                crate::point(origin),
                count as usize,
                now,
                &actors.bind().core,
            )
        };
        varray![&vectors(result)]
    }
}
