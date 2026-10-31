use frontline_core::cover::{Anchor, AnchorKind};
use frontline_core::infantry::Credit;
use frontline_core::structure::*;
use godot::prelude::*;

#[derive(GodotClass)]
#[class(base=RefCounted, init)]
struct StructureStateCore {
    base: Base<RefCounted>,
    core: Option<Structure>,
}
fn read<T: FromGodot>(a: &Array<Variant>, n: usize) -> Option<T> {
    a.get(n)?.try_to().ok()
}
fn text(a: &Array<Variant>, n: usize, limit: usize) -> Option<String> {
    let s: GString = read(a, n)?;
    if s.len() > limit {
        return None;
    }
    let s = s.to_string();
    (s.len() <= limit).then_some(s)
}
fn rows(a: &Array<Variant>, n: usize, limit: usize) -> Option<Vec<Array<Variant>>> {
    let rows: Array<Variant> = read(a, n)?;
    if rows.len() > limit {
        return None;
    }
    rows.iter_shared().map(|v| v.try_to().ok()).collect()
}
fn ids(a: &Array<Variant>, n: usize, limit: usize) -> Option<Vec<u32>> {
    let ids: PackedInt64Array = read(a, n)?;
    if ids.len() > limit {
        return None;
    }
    ids.as_slice()
        .iter()
        .map(|&id| id.try_into().ok())
        .collect()
}
fn points(
    a: &Array<Variant>,
    n: usize,
    limit: usize,
) -> Option<Vec<frontline_core::vector::Vector3>> {
    let p: PackedVector3Array = read(a, n)?;
    if p.len() > limit {
        return None;
    }
    Some(p.as_slice().iter().copied().map(crate::point).collect())
}
fn vector(p: frontline_core::vector::Vector3) -> Vector3 {
    Vector3::new(p.x, p.y, p.z)
}
fn vectors(p: &[frontline_core::vector::Vector3]) -> PackedVector3Array {
    p.iter().copied().map(vector).collect()
}
fn state(a: &Array<Variant>) -> Option<Structure> {
    if a.len() != 10 {
        return None;
    }
    let m: PackedInt64Array = read(a, 0)?;
    let strings: Array<Variant> = read(a, 1)?;
    let values: PackedFloat64Array = read(a, 2)?;
    let flags: PackedByteArray = read(a, 3)?;
    let g: Array<Variant> = read(a, 4)?;
    let opt: Array<Variant> = read(a, 5)?;
    let links: Array<Variant> = read(a, 7)?;
    let credit: Array<Variant> = read(a, 9)?;
    if m.len() != 12
        || strings.len() != 6
        || values.len() != 18
        || flags.len() != 8
        || flags.as_slice().iter().any(|&b| b > 1)
        || g.len() != 13
        || opt.len() != 3
        || links.len() != 2
        || !matches!(credit.len(), 0 | 4)
    {
        return None;
    }
    let m = m.as_slice();
    let v = values.as_slice();
    let b = flags.as_slice();
    let foot: Vector2 = read(&g, 2)?;
    let tilt: Vector2 = read(&g, 3)?;
    let mut parts = Vec::new();
    for p in rows(&g, 4, 100_000)? {
        if p.len() != 8 {
            return None;
        }
        parts.push(Part {
            position: crate::point(read(&p, 0)?),
            size: crate::point(read(&p, 1)?),
            yaw: read(&p, 2)?,
            infantry: read::<i64>(&p, 3)?.try_into().ok()?,
            vehicle: read::<i64>(&p, 4)?.try_into().ok()?,
            cover: read(&p, 5)?,
            collision: read(&p, 6)?,
            door: read(&p, 7)?,
        });
    }
    let anchor_p = points(&g, 6, 1_000_000)?;
    let anchor_n = points(&g, 7, 1_000_000)?;
    let anchor_h: PackedFloat32Array = read(&g, 8)?;
    let anchor_k: PackedByteArray = read(&g, 9)?;
    if anchor_p.len() != anchor_n.len()
        || anchor_p.len() != anchor_h.len()
        || anchor_p.len() != anchor_k.len()
    {
        return None;
    }
    let mut anchors = Vec::with_capacity(anchor_p.len());
    for i in 0..anchor_p.len() {
        let kind = match anchor_k[i] {
            1 => AnchorKind::Over,
            2 => AnchorKind::EdgeLeft,
            3 => AnchorKind::EdgeRight,
            4 => AnchorKind::Shelter,
            5 => AnchorKind::Stack,
            _ => return None,
        };
        anchors.push(Anchor {
            position: anchor_p[i],
            normal: anchor_n[i],
            height: f64::from(anchor_h[i]),
            kind,
        });
    }
    let nav: PackedInt32Array = read(&g, 10)?;
    if nav.len() > 10_000_000 {
        return None;
    }
    let nav_cells: Option<Vec<u32>> = nav.as_slice().iter().map(|&v| v.try_into().ok()).collect();
    let cells: Array<Vector2i> = read(&g, 11)?;
    if cells.len() > 1_000_000 {
        return None;
    }
    let zone = points(&opt, 0, 1)?;
    let rally = points(&opt, 1, 1)?;
    let hit = points(&opt, 2, 1)?;
    let mut queue = Vec::new();
    for q in rows(a, 6, 6)? {
        if q.len() != 5 {
            return None;
        }
        queue.push(Production {
            item: text(&q, 0, 128)?,
            remaining: read(&q, 1)?,
            total: read(&q, 2)?,
            owner: read::<i64>(&q, 3)?.try_into().ok()?,
            cost: read::<i64>(&q, 4)?.try_into().ok()?,
        });
    }
    let mut fire_queue = Vec::new();
    for q in rows(a, 8, 100_000)? {
        if q.len() != 2 {
            return None;
        }
        fire_queue.push((crate::point(read(&q, 0)?), read(&q, 1)?));
    }
    let hit_by = if credit.is_empty() {
        None
    } else {
        Some(Credit {
            owner: read::<i64>(&credit, 0)?.try_into().ok()?,
            team: read::<i64>(&credit, 1)?.try_into().ok()?,
            unit: text(&credit, 2, 128)?,
            soldier: read::<i64>(&credit, 3)?.try_into().ok()?,
        })
    };
    let s = Structure {
        id: m[0].try_into().ok()?,
        team: m[1].try_into().ok()?,
        owner: m[2].try_into().ok()?,
        visible: m[3].try_into().ok()?,
        seen: m[4].try_into().ok()?,
        variant: m[5].try_into().ok()?,
        capture_team: m[6].try_into().ok()?,
        completed_order: m[7].try_into().ok()?,
        supply_parent: m[8].try_into().ok()?,
        truck: m[9].try_into().ok()?,
        initial_houses: m[10].try_into().ok()?,
        gunner: m[11].try_into().ok()?,
        kind: text(&strings, 0, 128)?,
        name: text(&strings, 1, 1024)?,
        supply_status: text(&strings, 2, 128)?,
        production_status: text(&strings, 3, 128)?,
        wreck_kind: text(&strings, 4, 128)?,
        fire_kind: text(&strings, 5, 128)?,
        yaw: v[0],
        progress: v[1],
        hp: v[2],
        max_hp: v[3],
        radius: v[4],
        supply: v[5],
        capture_progress: v[6],
        truck_timer: v[7],
        alert_time: v[8],
        zone_radius: v[9],
        intact: v[10],
        house_timer: v[11],
        queue_fraction: v[12],
        bearer_timer: v[13],
        tick_timer: v[14],
        burn: v[15],
        fuel: v[16],
        fuel_max: v[17],
        gone: b[0] != 0,
        built: b[1] != 0,
        smashable: b[2] != 0,
        indestructible: b[3] != 0,
        wrecked: b[4] != 0,
        manned: b[5] != 0,
        door_closed: b[6] != 0,
        burnt: b[7] != 0,
        position: crate::point(read(&g, 0)?),
        size: crate::point(read(&g, 1)?),
        footprint: [foot.x, foot.y],
        tilt: [tilt.x, tilt.y],
        parts,
        cover_points: points(&g, 5, 1_000_000)?,
        anchors,
        nav_cells: nav_cells?,
        hash_cells: cells.iter_shared().map(|p| [p.x, p.y]).collect(),
        road: points(&g, 12, 1_000_000)?,
        zone_center: zone.first().copied(),
        rally: rally.first().copied(),
        hit_from: hit.first().copied(),
        queue,
        inside: ids(&links, 0, 100_000)?,
        bearers: ids(&links, 1, 100_000)?,
        fire_queue,
        hit_by,
    };
    s.valid().then_some(s)
}
fn production(q: &Production) -> Array<Variant> {
    varray![
        &GString::from(&q.item),
        q.remaining,
        q.total,
        q.owner,
        q.cost
    ]
}
fn values(s: &Structure) -> Array<Variant> {
    let meta: PackedInt64Array = [
        i64::from(s.id),
        s.team.into(),
        s.owner.into(),
        s.visible.into(),
        s.seen.into(),
        s.variant.into(),
        s.capture_team.into(),
        s.completed_order.into(),
        s.supply_parent.into(),
        s.truck.into(),
        s.initial_houses.into(),
        s.gunner.into(),
    ]
    .as_slice()
    .into();
    let strings: Array<Variant> = [
        &s.kind,
        &s.name,
        &s.supply_status,
        &s.production_status,
        &s.wreck_kind,
        &s.fire_kind,
    ]
    .into_iter()
    .map(|s| GString::from(s).to_variant())
    .collect();
    let numbers: PackedFloat64Array = [
        s.yaw,
        s.progress,
        s.hp,
        s.max_hp,
        s.radius,
        s.supply,
        s.capture_progress,
        s.truck_timer,
        s.alert_time,
        s.zone_radius,
        s.intact,
        s.house_timer,
        s.queue_fraction,
        s.bearer_timer,
        s.tick_timer,
        s.burn,
        s.fuel,
        s.fuel_max,
    ]
    .as_slice()
    .into();
    let flags: PackedByteArray = [
        s.gone,
        s.built,
        s.smashable,
        s.indestructible,
        s.wrecked,
        s.manned,
        s.door_closed,
        s.burnt,
    ]
    .map(u8::from)
    .as_slice()
    .into();
    let parts: Array<Variant> = s
        .parts
        .iter()
        .map(|p| {
            varray![
                vector(p.position),
                vector(p.size),
                p.yaw,
                p.infantry,
                p.vehicle,
                p.cover,
                p.collision,
                p.door
            ]
            .to_variant()
        })
        .collect();
    let ap: PackedVector3Array = s.anchors.iter().map(|a| vector(a.position)).collect();
    let an: PackedVector3Array = s.anchors.iter().map(|a| vector(a.normal)).collect();
    let ah: PackedFloat32Array = s.anchors.iter().map(|a| a.height as f32).collect();
    let ak: PackedByteArray = s.anchors.iter().map(|a| a.kind as u8).collect();
    let nav: PackedInt32Array = s.nav_cells.iter().map(|&n| n as i32).collect();
    let cells: Array<Vector2i> = s
        .hash_cells
        .iter()
        .map(|p| Vector2i::new(p[0], p[1]))
        .collect();
    let geometry = varray![
        vector(s.position),
        vector(s.size),
        Vector2::new(s.footprint[0], s.footprint[1]),
        Vector2::new(s.tilt[0], s.tilt[1]),
        &parts,
        &vectors(&s.cover_points),
        &ap,
        &an,
        &ah,
        &ak,
        &nav,
        &cells,
        &vectors(&s.road)
    ];
    let opt: Array<Variant> = [s.zone_center, s.rally, s.hit_from]
        .into_iter()
        .map(|p| {
            p.into_iter()
                .map(vector)
                .collect::<PackedVector3Array>()
                .to_variant()
        })
        .collect();
    let queue: Array<Variant> = s.queue.iter().map(|q| production(q).to_variant()).collect();
    let links: Array<Variant> = [&s.inside, &s.bearers]
        .into_iter()
        .map(|v| {
            v.iter()
                .copied()
                .map(i64::from)
                .collect::<PackedInt64Array>()
                .to_variant()
        })
        .collect();
    let fire: Array<Variant> = s
        .fire_queue
        .iter()
        .map(|&(p, smoke)| varray![vector(p), smoke].to_variant())
        .collect();
    let credit = s.hit_by.as_ref().map_or_else(Array::new, |h| {
        varray![h.owner, h.team, &GString::from(&h.unit), h.soldier]
    });
    varray![&meta, &strings, &numbers, &flags, &geometry, &opt, &queue, &links, &fire, &credit]
}
fn economy(a: &PackedFloat64Array) -> Option<TownEconomy> {
    let v = a.as_slice();
    (v.len() == 3).then(|| TownEconomy {
        stock: v[0],
        yield_per_minute: v[1],
        capture_pace: v[2],
    })
}
fn capture(result: Result<Capture, &'static str>) -> PackedInt32Array {
    result.map_or_else(
        |_| PackedInt32Array::new(),
        |r| {
            [
                i32::from(r.changed),
                i32::from(r.warning),
                i32::from(r.last_stand),
                r.captured_by.map_or(-1, i32::from),
                i32::from(r.resupply),
            ]
            .as_slice()
            .into()
        },
    )
}
#[godot_api]
impl StructureStateCore {
    #[func]
    fn load_state(&mut self, a: Array<Variant>) -> bool {
        let Some(s) = state(&a) else {
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
        let Ok(s) = Structure::restore(bytes.as_slice()) else {
            return false;
        };
        self.core = Some(s);
        true
    }
    #[func]
    fn add_work(&mut self, amount: f64, build_time: PackedFloat64Array) -> PackedByteArray {
        if build_time.len() > 1 {
            return PackedByteArray::new();
        }
        self.core
            .as_mut()
            .and_then(|s| {
                s.add_work(amount, build_time.as_slice().first().copied())
                    .ok()
            })
            .map_or_else(PackedByteArray::new, |r| {
                [
                    u8::from(r.worked),
                    u8::from(r.completed),
                    u8::from(r.repaired_fob),
                ]
                .as_slice()
                .into()
            })
    }
    #[func]
    fn char_out(&mut self) -> i32 {
        self.core
            .as_mut()
            .and_then(|s| s.char_out().ok())
            .map_or(-1, i32::from)
    }
    #[func]
    fn open_door(&mut self) -> i32 {
        self.core.as_mut().map_or(-1, |s| i32::from(s.open_door()))
    }
    #[func]
    fn queries(&self, position: Vector3, direction: Vector3) -> Array<Variant> {
        self.core.as_ref().map_or_else(Array::new, |s| {
            varray![
                vector(s.front()),
                vector(s.exit()),
                s.needs_work(),
                &GString::from(s.fire_kind()),
                s.door_blocks(crate::point(position), crate::point(direction)),
                s.town_yield_factor()
            ]
        })
    }
    #[func]
    fn begin_tick(&mut self, dt: f64, rules: PackedFloat64Array) -> i32 {
        let Some(e) = economy(&rules) else {
            return -1;
        };
        self.core
            .as_mut()
            .and_then(|s| s.begin_tick(dt, e).ok())
            .map_or(-1, |t| match t {
                Tick::None => 0,
                Tick::Fob => 1,
                Tick::Town {
                    count_houses: false,
                } => 2,
                Tick::Town { count_houses: true } => 3,
                Tick::Production => 4,
                Tick::Tent => 5,
                Tick::Mount => 6,
                Tick::Mine => 7,
                Tick::Cache => 8,
            })
    }
    #[func]
    fn count_houses(&mut self, count: u32) -> i32 {
        self.core
            .as_mut()
            .and_then(|s| s.count_houses(count).ok())
            .map_or(-1, i32::from)
    }
    #[func]
    fn fob_capture(&mut self, counts: PackedInt32Array, last: bool) -> PackedInt32Array {
        if counts.len() != 2 || counts.as_slice().iter().any(|&n| n < 0) {
            return PackedInt32Array::new();
        }
        capture(
            self.core
                .as_mut()
                .ok_or("missing structure")
                .and_then(|s| s.fob_capture([counts[0] as u32, counts[1] as u32], last)),
        )
    }
    #[func]
    fn town_capture(
        &mut self,
        counts: PackedInt32Array,
        now: f64,
        rules: PackedFloat64Array,
    ) -> PackedInt32Array {
        let Some(e) = economy(&rules) else {
            return PackedInt32Array::new();
        };
        if counts.len() != 2 || counts.as_slice().iter().any(|&n| n < 0) {
            return PackedInt32Array::new();
        }
        capture(
            self.core
                .as_mut()
                .ok_or("missing structure")
                .and_then(|s| s.town_capture([counts[0] as u32, counts[1] as u32], now, e)),
        )
    }
    #[func]
    fn produce(&mut self, dt: f64, has_cap: bool) -> Array<Variant> {
        self.core
            .as_mut()
            .and_then(|s| s.produce(dt, has_cap).ok())
            .map_or_else(Array::new, |r| {
                varray![
                    r.fraction_changed,
                    r.cap_warning,
                    &r.item.as_ref().map_or_else(Array::new, production)
                ]
            })
    }
}
