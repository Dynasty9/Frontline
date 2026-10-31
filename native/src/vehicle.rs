use frontline_core::infantry::Credit;
use frontline_core::vehicle::{LastBlast, Resume, Route, Vehicle};
use godot::prelude::*;
#[derive(GodotClass)]
#[class(base=RefCounted,init)]
struct VehicleStateCore {
    base: Base<RefCounted>,
    core: Option<Vehicle>,
}
fn read<T: FromGodot>(a: &Array<Variant>, i: usize) -> Option<T> {
    a.get(i)?.try_to().ok()
}
fn text(a: &Array<Variant>, i: usize) -> Option<String> {
    let s: GString = read(a, i)?;
    if s.len() > 128 {
        return None;
    }
    let s = s.to_string();
    (s.len() <= 128).then_some(s)
}
fn vector(p: frontline_core::vector::Vector3) -> Vector3 {
    Vector3::new(p.x, p.y, p.z)
}
fn vectors(p: &[frontline_core::vector::Vector3]) -> PackedVector3Array {
    p.iter().copied().map(vector).collect()
}
fn opt_point(p: Option<frontline_core::vector::Vector3>) -> PackedVector3Array {
    p.into_iter().map(vector).collect()
}
fn read_opt(a: &Array<Variant>, i: usize) -> Option<Option<frontline_core::vector::Vector3>> {
    let p: PackedVector3Array = read(a, i)?;
    if p.len() > 1 {
        return None;
    }
    Some(p.as_slice().first().copied().map(crate::point))
}
fn state(a: &Array<Variant>) -> Option<Vehicle> {
    if a.len() != 13 {
        return None;
    }
    let meta: PackedInt64Array = read(a, 0)?;
    let strings: Array<Variant> = read(a, 1)?;
    let floats: PackedFloat64Array = read(a, 2)?;
    let flags: PackedByteArray = read(a, 3)?;
    let points: PackedVector3Array = read(a, 4)?;
    let optional: Array<Variant> = read(a, 5)?;
    let times: Array<Variant> = read(a, 6)?;
    let lists: Array<Variant> = read(a, 7)?;
    let cds: Array<Variant> = read(a, 8)?;
    let resume: Array<Variant> = read(a, 9)?;
    let blast: Array<Variant> = read(a, 10)?;
    let flight: PackedFloat64Array = read(a, 11)?;
    let credit: Array<Variant> = read(a, 12)?;
    if meta.len() != 28
        || strings.len() != 2
        || floats.len() != 44
        || flags.len() != 13
        || flags.as_slice().iter().any(|&v| v > 1)
        || points.len() != 7
        || optional.len() != 8
        || times.len() != 4
        || lists.len() != 4
        || cds.len() > 4096
        || !matches!(resume.len(), 0 | 3)
        || !matches!(blast.len(), 0 | 3)
        || !matches!(flight.len(), 0 | 3)
        || !matches!(credit.len(), 0 | 4)
    {
        return None;
    }
    let m = meta.as_slice();
    let f = floats.as_slice();
    let b = flags.as_slice();
    let p = points.as_slice();
    let mut paths = Vec::new();
    for i in 0..3 {
        let path: PackedVector3Array = read(&lists, i)?;
        if path.len() > 1_000_000 {
            return None;
        }
        paths.push(path.as_slice().iter().copied().map(crate::point).collect());
    }
    let passenger_ids: PackedInt64Array = read(&lists, 3)?;
    if passenger_ids.len() > 100_000 {
        return None;
    }
    let passengers: Option<Vec<u32>> = passenger_ids
        .as_slice()
        .iter()
        .map(|&id| id.try_into().ok())
        .collect();
    let mut cooldowns = Vec::new();
    for row in cds.iter_shared() {
        let row: Array<Variant> = row.try_to().ok()?;
        if row.len() != 2 {
            return None;
        }
        cooldowns.push((text(&row, 0)?, read(&row, 1)?));
    }
    let mut optional_times = Vec::new();
    for value in times.iter_shared() {
        let value: PackedFloat64Array = value.try_to().ok()?;
        if value.len() > 1 {
            return None;
        }
        optional_times.push(value.as_slice().first().copied());
    }
    let v = Vehicle {
        id: m[0].try_into().ok()?,
        aim_target: m[1].try_into().ok()?,
        target: m[2].try_into().ok()?,
        forced_target: m[3].try_into().ok()?,
        destination_fob: m[4].try_into().ok()?,
        source_town: m[5].try_into().ok()?,
        heli_home: m[6].try_into().ok()?,
        heli_destination: m[7].try_into().ok()?,
        sling_cargo: m[8].try_into().ok()?,
        sling_target: m[9].try_into().ok()?,
        slung_by: m[10].try_into().ok()?,
        team: m[11].try_into().ok()?,
        owner: m[12].try_into().ok()?,
        visible: m[13].try_into().ok()?,
        seen: m[14].try_into().ok()?,
        path_revision: m[15].try_into().ok()?,
        path_index: m[16].try_into().ok()?,
        route_index: m[17].try_into().ok()?,
        mg_burst: m[18].try_into().ok()?,
        flags: m[19].try_into().ok()?,
        smoke_left: m[20].try_into().ok()?,
        cargo: m[21].try_into().ok()?,
        heli_phase: m[22].try_into().ok()?,
        atgm_left: m[23].try_into().ok()?,
        sam_left: m[24].try_into().ok()?,
        salvo: m[25].try_into().ok()?,
        lift_phase: m[26].try_into().ok()?,
        tries: m[27].try_into().ok()?,
        hp: f[0],
        max_hp: f[1],
        yaw: f[2],
        turret_yaw: f[3],
        traverse: f[4],
        stabilization_rate: f[5],
        aim_time: f[6],
        speed: f[7],
        track_fix: f[8],
        cannon_timer: f[9],
        mg_timer: f[10],
        scan_timer: f[11],
        smash_timer: f[12],
        last_fire: f[13],
        alert_time: f[14],
        smoke_until: f[15],
        blocked_timer: f[16],
        stuck_timer: f[17],
        stuck_yaw: f[18],
        unstick_timer: f[19],
        unstick_direction: f[20],
        dismount_timer: f[21],
        heli_timer: f[22],
        flight_pitch: f[23],
        flight_roll: f[24],
        atgm_until: f[25],
        sam_until: f[26],
        artillery_until: f[27],
        salvo_timer: f[28],
        service_timer: f[29],
        lift_timer: f[30],
        orbit: f[31],
        sling_timer: f[32],
        brain_time: f[33],
        yaw_rate: f[34],
        sway: f[35],
        throttle: f[36],
        rudder: f[37],
        current_timer: f[38],
        about: f[39],
        rejoin_timer: f[40],
        astern_timer: f[41],
        gunship_orbit: f[42],
        rocket_timer: f[43],
        gone: b[0] != 0,
        track_broken: b[1] != 0,
        path_pending: b[2] != 0,
        returning: b[3] != 0,
        assault: b[4] != 0,
        brain_hold: b[5] != 0,
        brain_overruled: b[6] != 0,
        brain_order: b[7] != 0,
        reverse: b[8] != 0,
        landing: b[9] != 0,
        grounded: b[10] != 0,
        astern: b[11] != 0,
        astern_stop: b[12] != 0,
        position: crate::point(p[0]),
        velocity: crate::point(p[1]),
        knock_velocity: crate::point(p[2]),
        stuck_position: crate::point(p[3]),
        swing: crate::point(p[4]),
        current: crate::point(p[5]),
        astern_from: crate::point(p[6]),
        path_destination: read_opt(&optional, 0)?,
        assault_destination: read_opt(&optional, 1)?,
        flight_hold: read_opt(&optional, 2)?,
        salvo_at: read_opt(&optional, 3)?,
        lift_destination: read_opt(&optional, 4)?,
        uav_destination: read_opt(&optional, 5)?,
        gunship_destination: read_opt(&optional, 6)?,
        tries_for: read_opt(&optional, 7)?,
        lay_yaw: optional_times[0],
        face_yaw: optional_times[1],
        tries_time: optional_times[2],
        avoid_cap: optional_times[3],
        kind: text(&strings, 0)?,
        brain_state: text(&strings, 1)?,
        path: paths.remove(0),
        route: paths.remove(0),
        fire_queue: paths.remove(0),
        passengers: passengers?,
        cooldowns,
        resume: if resume.is_empty() {
            None
        } else {
            Some(Resume {
                destination: read_opt(&resume, 0)?,
                assault: read(&resume, 1)?,
                assault_destination: read_opt(&resume, 2)?,
            })
        },
        last_blast: if blast.is_empty() {
            None
        } else {
            Some(LastBlast {
                position: crate::point(read(&blast, 0)?),
                size: read(&blast, 1)?,
                time: read(&blast, 2)?,
            })
        },
        flight: if flight.is_empty() {
            None
        } else {
            Some(flight.as_slice().try_into().ok()?)
        },
        hit_by: if credit.is_empty() {
            None
        } else {
            Some(Credit {
                owner: read::<i64>(&credit, 0)?.try_into().ok()?,
                team: read::<i64>(&credit, 1)?.try_into().ok()?,
                unit: text(&credit, 2)?,
                soldier: read::<i64>(&credit, 3)?.try_into().ok()?,
            })
        },
    };
    v.valid().then_some(v)
}
fn values(v: &Vehicle) -> Array<Variant> {
    let optional: Array<Variant> = [
        v.path_destination,
        v.assault_destination,
        v.flight_hold,
        v.salvo_at,
        v.lift_destination,
        v.uav_destination,
        v.gunship_destination,
        v.tries_for,
    ]
    .into_iter()
    .map(|p| opt_point(p).to_variant())
    .collect();
    let times: Array<Variant> = [v.lay_yaw, v.face_yaw, v.tries_time, v.avoid_cap]
        .into_iter()
        .map(|t| t.into_iter().collect::<PackedFloat64Array>().to_variant())
        .collect();
    let cds: Array<Variant> = v
        .cooldowns
        .iter()
        .map(|(k, t)| varray![&GString::from(k.as_str()), *t].to_variant())
        .collect();
    let resume = v.resume.map_or_else(Array::new, |r| {
        varray![
            &opt_point(r.destination),
            r.assault,
            &opt_point(r.assault_destination)
        ]
    });
    let blast = v
        .last_blast
        .map_or_else(Array::new, |b| varray![vector(b.position), b.size, b.time]);
    let flight: PackedFloat64Array = v
        .flight
        .map_or_else(PackedFloat64Array::new, |f| f.as_slice().into());
    let credit = v.hit_by.as_ref().map_or_else(Array::new, |c| {
        varray![c.owner, c.team, &GString::from(c.unit.as_str()), c.soldier]
    });
    varray![
        &PackedInt64Array::from(
            &[
                v.id as i64,
                v.aim_target as i64,
                v.target as i64,
                v.forced_target as i64,
                v.destination_fob as i64,
                v.source_town as i64,
                v.heli_home as i64,
                v.heli_destination as i64,
                v.sling_cargo as i64,
                v.sling_target as i64,
                v.slung_by as i64,
                v.team as i64,
                v.owner as i64,
                v.visible as i64,
                v.seen as i64,
                v.path_revision as i64,
                v.path_index as i64,
                v.route_index as i64,
                v.mg_burst as i64,
                v.flags as i64,
                v.smoke_left as i64,
                v.cargo as i64,
                v.heli_phase as i64,
                v.atgm_left as i64,
                v.sam_left as i64,
                v.salvo as i64,
                v.lift_phase as i64,
                v.tries as i64
            ][..]
        ),
        &varray![
            &GString::from(v.kind.as_str()),
            &GString::from(v.brain_state.as_str())
        ],
        &PackedFloat64Array::from(
            &[
                v.hp,
                v.max_hp,
                v.yaw,
                v.turret_yaw,
                v.traverse,
                v.stabilization_rate,
                v.aim_time,
                v.speed,
                v.track_fix,
                v.cannon_timer,
                v.mg_timer,
                v.scan_timer,
                v.smash_timer,
                v.last_fire,
                v.alert_time,
                v.smoke_until,
                v.blocked_timer,
                v.stuck_timer,
                v.stuck_yaw,
                v.unstick_timer,
                v.unstick_direction,
                v.dismount_timer,
                v.heli_timer,
                v.flight_pitch,
                v.flight_roll,
                v.atgm_until,
                v.sam_until,
                v.artillery_until,
                v.salvo_timer,
                v.service_timer,
                v.lift_timer,
                v.orbit,
                v.sling_timer,
                v.brain_time,
                v.yaw_rate,
                v.sway,
                v.throttle,
                v.rudder,
                v.current_timer,
                v.about,
                v.rejoin_timer,
                v.astern_timer,
                v.gunship_orbit,
                v.rocket_timer
            ][..]
        ),
        &PackedByteArray::from(
            &[
                u8::from(v.gone),
                u8::from(v.track_broken),
                u8::from(v.path_pending),
                u8::from(v.returning),
                u8::from(v.assault),
                u8::from(v.brain_hold),
                u8::from(v.brain_overruled),
                u8::from(v.brain_order),
                u8::from(v.reverse),
                u8::from(v.landing),
                u8::from(v.grounded),
                u8::from(v.astern),
                u8::from(v.astern_stop)
            ][..]
        ),
        &vectors(&[
            v.position,
            v.velocity,
            v.knock_velocity,
            v.stuck_position,
            v.swing,
            v.current,
            v.astern_from
        ]),
        &optional,
        &times,
        &varray![
            &vectors(&v.path),
            &vectors(&v.route),
            &vectors(&v.fire_queue),
            &v.passengers
                .iter()
                .copied()
                .map(i64::from)
                .collect::<PackedInt64Array>()
        ],
        &cds,
        &resume,
        &blast,
        &flight,
        &credit
    ]
}
fn route(r: Result<Route, &'static str>) -> Array<Variant> {
    match r {
        Ok(Route::None) => varray![0, Vector3::ZERO, 0.0, 0],
        Ok(Route::Ground {
            destination,
            care,
            revision,
        }) => varray![1, vector(destination), care, revision as i64],
        Ok(Route::Boat { destination }) => varray![2, vector(destination), 0.0, 0],
        Err(_) => Array::new(),
    }
}
#[godot_api]
impl VehicleStateCore {
    #[func]
    fn load_state(&mut self, a: Array<Variant>) -> bool {
        let Some(v) = state(&a) else {
            return false;
        };
        self.core = Some(v);
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
            .and_then(|v| v.checkpoint().ok())
            .map_or_else(PackedByteArray::new, |b| b.as_slice().into())
    }
    #[func]
    fn restore(&mut self, b: PackedByteArray) -> bool {
        let Ok(v) = Vehicle::restore(b.as_slice()) else {
            return false;
        };
        self.core = Some(v);
        true
    }
    #[func]
    fn repair(&mut self, amount: f64) -> i32 {
        self.core
            .as_mut()
            .and_then(|v| v.repair(amount).ok())
            .map_or(-1, i32::from)
    }
    #[func]
    fn rearm(&mut self, atgm: i32, sam: i32) -> bool {
        self.core
            .as_mut()
            .is_some_and(|v| v.rearm(atgm, sam).is_ok())
    }
    #[func]
    fn order_move(
        &mut self,
        p: Vector3,
        base: GString,
        landing: Vector3,
        assault: bool,
    ) -> Array<Variant> {
        route(self.core.as_mut().ok_or("missing vehicle").and_then(|v| {
            if assault {
                v.order_assault(crate::point(p), &base.to_string(), crate::point(landing))
            } else {
                v.order_move(crate::point(p), &base.to_string(), crate::point(landing))
            }
        }))
    }
    #[func]
    fn order_attack(&mut self, id: u32, p: Vector3, base: GString) -> Array<Variant> {
        route(
            self.core
                .as_mut()
                .ok_or("missing vehicle")
                .and_then(|v| v.order_attack(id, crate::point(p), &base.to_string())),
        )
    }
    #[func]
    fn order_stop(&mut self, base: GString, automatic: bool) -> bool {
        self.core
            .as_mut()
            .is_some_and(|v| v.order_stop(&base.to_string(), automatic).is_ok())
    }
    #[func]
    fn complete_path(&mut self, revision: i64, path: PackedVector3Array) -> i32 {
        let Ok(revision) = u64::try_from(revision) else {
            return -1;
        };
        if path.len() > 1_000_000 {
            return -1;
        }
        self.core
            .as_mut()
            .and_then(|v| {
                v.complete_path(
                    revision,
                    path.as_slice().iter().copied().map(crate::point).collect(),
                )
                .ok()
            })
            .map_or(-1, i32::from)
    }
    #[func]
    fn update_flags(&mut self, now: f64, helicopter: bool, artillery: bool) -> i32 {
        self.core
            .as_mut()
            .and_then(|v| v.update_flags(now, helicopter, artillery).ok())
            .map_or(-1, i32::from)
    }
    #[func]
    fn complete_boat_path(&mut self, path: PackedVector3Array) -> bool {
        if path.len() > 1_000_000 {
            return false;
        }
        self.core.as_mut().is_some_and(|v| {
            v.complete_boat_path(path.as_slice().iter().copied().map(crate::point).collect())
                .is_ok()
        })
    }
    #[func]
    fn turret_tick(
        &mut self,
        id: u32,
        p: Vector3,
        dt: f64,
        gunship: bool,
        rate: f64,
        accel: f64,
    ) -> bool {
        self.core.as_mut().is_some_and(|v| {
            v.turret_tick(
                (id != 0).then_some((id, crate::point(p))),
                dt,
                gunship,
                rate,
                accel,
            )
            .is_ok()
        })
    }
}
