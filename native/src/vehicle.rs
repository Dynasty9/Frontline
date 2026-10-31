use crate::path_planner::PathPlannerCore;
use crate::simulation_random::SimulationRandomCore;
use crate::terrain::TerrainCore;
use frontline_core::infantry::Credit;
use frontline_core::vehicle::{LastBlast, Resume, Route, Vehicle};
use frontline_core::vehicle_brain::{Contact, CrewEvent, CrewProfile, Perception, UnitKind};
use frontline_core::vehicle_flight::FlightProfile;
use frontline_core::vehicle_motion::{GroundProfile, Traffic};
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
fn ground_profile(a: &Array<Variant>) -> Option<GroundProfile> {
    if a.len() != 4 {
        return None;
    }
    let hull: Vector3 = read(a, 0)?;
    let flags: PackedByteArray = read(a, 1)?;
    let weight: u8 = read(a, 2)?;
    let rates: PackedFloat64Array = read(a, 3)?;
    if flags.len() != 4 || flags.as_slice().iter().any(|v| *v > 1) || rates.len() != 7 {
        return None;
    }
    let f = flags.as_slice();
    let r = rates.as_slice();
    Some(GroundProfile {
        hull: crate::point(hull),
        tracked: f[0] != 0,
        supply: f[1] != 0,
        tank: f[2] != 0,
        cannon: f[3] != 0,
        weight,
        speed: r[0],
        turn: r[1],
        turn_accel: r[2],
        handling: [r[3], r[4], r[5], r[6]],
    })
}
fn flight_profile(a: &PackedFloat64Array) -> Option<FlightProfile> {
    if a.len() != 5 {
        return None;
    }
    let p = a.as_slice();
    Some(FlightProfile {
        speed: p[0],
        accel: p[1],
        brake: p[2],
        turn: p[3],
        turn_accel: p[4],
    })
}
pub(crate) fn muzzle_profile(a: &Array<Variant>) -> Option<frontline_core::vehicle_cannon::Muzzle> {
    use frontline_core::vehicle_cannon::{Muzzle, Socket};
    if a.len() != 3 {
        return None;
    }
    let flags: PackedByteArray = read(a, 0)?;
    let points: PackedVector3Array = read(a, 2)?;
    if flags.len() != 2 || flags.as_slice().iter().any(|&v| v > 1) || points.len() > 2 {
        return None;
    }
    Some(Muzzle {
        helicopter: flags[0] != 0,
        gunship: flags[1] != 0,
        gun_height: read(a, 1)?,
        socket: points.as_slice().first().map(|&p| Socket {
            point: crate::point(p),
            pivot: points.as_slice().get(1).copied().map(crate::point),
        }),
    })
}
fn armor_profile(a: &Array<Variant>) -> Option<frontline_core::vehicle_damage::Armor> {
    if a.len() != 2 {
        return None;
    }
    let flags: PackedInt32Array = read(a, 0)?;
    if flags.len() != 4 || flags.as_slice()[1..].iter().any(|&v| v != 0 && v != 1) {
        return None;
    }
    Some(frontline_core::vehicle_damage::Armor {
        level: flags[0].try_into().ok()?,
        helicopter: flags[1] != 0,
        boat: flags[2] != 0,
        supply: flags[3] != 0,
        toss: read(a, 1)?,
    })
}
fn fire_profile<'a>(
    a: &Array<Variant>,
    base: &'a str,
    gun: &'a str,
) -> Option<frontline_core::vehicle_weapon::FireProfile<'a>> {
    if a.len() != 6 {
        return None;
    }
    let burst: PackedInt32Array = read(a, 4)?;
    let rates: PackedFloat64Array = read(a, 5)?;
    if burst.len() != 2 || rates.len() != 6 {
        return None;
    }
    Some(frontline_core::vehicle_weapon::FireProfile {
        base,
        cannon: read(a, 1)?,
        armor: read(a, 2)?,
        machine_gun: gun,
        burst: [burst[0], burst[1]],
        interval: rates[0],
        cannon_cooldown: rates[1],
        sam_cooldown: rates[2],
        sam_range: rates[3],
        atgm_cooldown: rates[4],
        atgm_range: rates[5],
    })
}
fn fire_target(a: &Array<Variant>) -> Option<Option<frontline_core::vehicle_weapon::Target>> {
    use frontline_core::vehicle_weapon::{Target, TargetKind};
    if a.is_empty() {
        return Some(None);
    }
    if a.len() != 3 {
        return None;
    }
    let kind: i32 = read(a, 1)?;
    let flags: PackedInt32Array = read(a, 2)?;
    let f = flags.as_slice();
    let bit = |v: i32| -> Option<bool> {
        match v {
            0 => Some(false),
            1 => Some(true),
            _ => None,
        }
    };
    let kind = match kind {
        0 if f.len() == 3 => TargetKind::Soldier {
            nearby: f[0].try_into().ok()?,
            rockets: bit(f[1])?,
            mounted: bit(f[2])?,
        },
        1 if f.len() == 2 => TargetKind::Vehicle {
            air: bit(f[0])?,
            armor: f[1].try_into().ok()?,
        },
        2 if f.len() == 1 => TargetKind::Structure {
            fortified: bit(f[0])?,
        },
        3 if f.is_empty() => TargetKind::Other,
        _ => return None,
    };
    Some(Some(Target {
        position: crate::point(read(a, 0)?),
        kind,
    }))
}
fn traffic(a: &Array<Variant>) -> Option<Vec<Traffic>> {
    if a.len() > 100_000 {
        return None;
    }
    a.iter_shared()
        .map(|v| {
            let row = v.try_to::<Array<Variant>>().ok()?;
            if row.len() != 6 {
                return None;
            }
            Some(Traffic {
                id: read(&row, 0)?,
                position: crate::point(read(&row, 1)?),
                yaw: read(&row, 2)?,
                speed: read(&row, 3)?,
                hull: crate::point(read(&row, 4)?),
                air: read(&row, 5)?,
            })
        })
        .collect()
}
fn crew_contacts(rows: &Array<Variant>) -> Option<Vec<Contact>> {
    if rows.len() > 100_000 {
        return None;
    }
    rows.iter_shared()
        .map(|row| {
            let a = row.try_to::<Array<Variant>>().ok()?;
            if a.len() != 7 {
                return None;
            }
            let kind: u8 = read(&a, 5)?;
            let fields: PackedInt64Array = read(&a, 6)?;
            let f = fields.as_slice();
            let boolean = |i: usize| f.get(i).filter(|&&v| v == 0 || v == 1).map(|&v| v == 1);
            let kind = match kind {
                0 if f.len() == 4 => UnitKind::Soldier {
                    alive: boolean(0)?,
                    rockets: f[1].try_into().ok()?,
                    antitank: boolean(2)?,
                    riding: boolean(3)?,
                },
                1 if f.len() == 3 => UnitKind::Vehicle {
                    air: boolean(0)?,
                    cannon: boolean(1)?,
                    missiles: f[2].try_into().ok()?,
                },
                _ => return None,
            };
            Some(Contact {
                id: read(&a, 0)?,
                position: crate::point(read(&a, 1)?),
                team: read(&a, 2)?,
                visible: read(&a, 3)?,
                gone: read(&a, 4)?,
                kind,
            })
        })
        .collect()
}
#[godot_api]
impl VehicleStateCore {
    #[func]
    fn weapon_muzzle(&self, profile: Array<Variant>, main_gun: bool) -> PackedVector3Array {
        let (Some(v), Some(p)) = (self.core.as_ref(), muzzle_profile(&profile)) else {
            return PackedVector3Array::new();
        };
        v.weapon_muzzle(p, main_gun).map_or_else(
            |_| PackedVector3Array::new(),
            |p| [vector(p)].as_slice().into(),
        )
    }
    #[func]
    fn choose_weapon(
        &mut self,
        now: f64,
        profile: Array<Variant>,
        target: Array<Variant>,
        mut random: Gd<SimulationRandomCore>,
    ) -> i32 {
        use frontline_core::vehicle_weapon::Fire;
        let (Some(base), Some(gun)) = (text(&profile, 0), text(&profile, 3)) else {
            return -1;
        };
        let (Some(p), Some(t), Some(v)) = (
            fire_profile(&profile, &base, &gun),
            fire_target(&target),
            self.core.as_mut(),
        ) else {
            return -1;
        };
        match v.choose_weapon(now, p, t, &mut random.bind_mut().core) {
            Ok(Fire::None) => 0,
            Ok(Fire::Sam) => 1,
            Ok(Fire::Atgm) => 2,
            Ok(Fire::Cannon) => 3,
            Ok(Fire::MachineGun) => 4,
            Err(_) => -1,
        }
    }
    #[func]
    fn finish_weapon(
        &mut self,
        shot: i32,
        now: f64,
        profile: Array<Variant>,
        mut random: Gd<SimulationRandomCore>,
    ) -> bool {
        use frontline_core::vehicle_weapon::Fire;
        let shot = match shot {
            0 => Fire::None,
            1 => Fire::Sam,
            2 => Fire::Atgm,
            3 => Fire::Cannon,
            4 => Fire::MachineGun,
            _ => return false,
        };
        let (Some(base), Some(gun)) = (text(&profile, 0), text(&profile, 3)) else {
            return false;
        };
        let (Some(p), Some(v)) = (fire_profile(&profile, &base, &gun), self.core.as_mut()) else {
            return false;
        };
        v.finish_weapon(shot, now, p, &mut random.bind_mut().core)
            .is_ok()
    }
    #[func]
    fn bullet_damage(
        &self,
        armor: Array<Variant>,
        damage: f64,
        piercing: bool,
        anti_air: bool,
    ) -> PackedFloat64Array {
        let (Some(v), Some(a)) = (self.core.as_ref(), armor_profile(&armor)) else {
            return PackedFloat64Array::new();
        };
        v.bullet_damage(a, damage, piercing, anti_air)
            .map_or_else(|_| PackedFloat64Array::new(), |d| [d].as_slice().into())
    }
    #[func]
    fn bullet_ricochet(
        &self,
        armor: Array<Variant>,
        position: Vector3,
        direction: Vector3,
        mut random: Gd<SimulationRandomCore>,
    ) -> Array<Variant> {
        let (Some(v), Some(a)) = (self.core.as_ref(), armor_profile(&armor)) else {
            return Array::new();
        };
        match v.bullet_ricochet(
            a,
            crate::point(position),
            crate::point(direction),
            &mut random.bind_mut().core,
        ) {
            Ok(p) => varray![&opt_point(p)],
            Err(_) => Array::new(),
        }
    }
    #[func]
    fn explosion_hit(
        &mut self,
        now: f64,
        armor: Array<Variant>,
        blast: Array<Variant>,
        mut random: Gd<SimulationRandomCore>,
    ) -> PackedFloat64Array {
        let parse = || -> Option<frontline_core::vehicle_damage::Blast> {
            if blast.len() != 9 {
                return None;
            }
            Some(frontline_core::vehicle_damage::Blast {
                position: crate::point(read(&blast, 0)?),
                size: read(&blast, 1)?,
                anti_tank: read(&blast, 2)?,
                direction: read_opt(&blast, 3)?,
                top: read(&blast, 4)?,
                track: read(&blast, 5)?,
                radius: read(&blast, 6)?,
                damage: read(&blast, 7)?,
                vehicle_multiplier: read(&blast, 8)?,
            })
        };
        let (Some(v), Some(a), Some(b)) = (self.core.as_mut(), armor_profile(&armor), parse())
        else {
            return PackedFloat64Array::new();
        };
        match v.explosion_hit(now, a, b, &mut random.bind_mut().core) {
            Ok(h) => [
                h.damage,
                f64::from(h.anti_tank),
                f64::from(h.bounced),
                f64::from(h.track_broken),
            ]
            .as_slice()
            .into(),
            Err(_) => PackedFloat64Array::new(),
        }
    }
    #[func]
    fn take_damage(&mut self, amount: f64, now: f64, automatic: bool) -> PackedByteArray {
        let Some(v) = self.core.as_mut() else {
            return PackedByteArray::new();
        };
        match v.take_damage(amount, now, automatic) {
            Ok(d) => [
                u8::from(d.applied),
                u8::from(d.alert),
                u8::from(d.destroyed),
            ]
            .as_slice()
            .into(),
            Err(_) => PackedByteArray::new(),
        }
    }
    #[func]
    fn gunship_begin(&mut self, dt: f64) -> i32 {
        self.core
            .as_mut()
            .and_then(|v| v.gunship_begin(dt).ok())
            .map_or(-1, i32::from)
    }
    #[func]
    fn gunship_guidance(
        &mut self,
        dt: f64,
        target: PackedVector3Array,
        profile: PackedFloat64Array,
        terrain: Gd<TerrainCore>,
        deck: PackedByteArray,
    ) -> bool {
        let Some(p) = flight_profile(&profile) else {
            return false;
        };
        if target.len() > 1 {
            return false;
        }
        let terrain = terrain.bind();
        let (Some(v), Some(terrain)) = (self.core.as_mut(), terrain.core.as_ref()) else {
            return false;
        };
        v.gunship_guidance(
            dt,
            target.as_slice().first().copied().map(crate::point),
            p,
            terrain,
            deck.as_slice(),
        )
        .is_ok()
    }
    #[func]
    fn gunship_rockets_due(
        &mut self,
        target: PackedVector3Array,
        worth: bool,
        rockets: i32,
    ) -> i32 {
        if target.len() > 1 {
            return -1;
        }
        self.core
            .as_mut()
            .and_then(|v| {
                v.gunship_rockets_due(
                    target.as_slice().first().copied().map(crate::point),
                    worth,
                    rockets,
                )
                .ok()
            })
            .map_or(-1, i32::from)
    }
    #[func]
    fn lift_guidance(
        &mut self,
        dt: f64,
        profile: PackedFloat64Array,
        terrain: Gd<TerrainCore>,
        deck: PackedByteArray,
        cargo_height: f64,
        target: Array<Variant>,
        home: PackedVector3Array,
    ) -> PackedInt64Array {
        use frontline_core::vehicle_air::{HomeLanding, LiftEvent, SlingTarget};
        let parse = || -> Option<(FlightProfile, Option<SlingTarget>, Option<HomeLanding>)> {
            if !matches!(target.len(), 0 | 3) || !matches!(home.len(), 0 | 2) {
                return None;
            }
            let t = if target.is_empty() {
                None
            } else {
                Some(SlingTarget {
                    id: read(&target, 0)?,
                    position: crate::point(read(&target, 1)?),
                    height: read(&target, 2)?,
                })
            };
            let h = if home.is_empty() {
                None
            } else {
                Some(HomeLanding {
                    position: crate::point(home[0]),
                    landing: crate::point(home[1]),
                })
            };
            Some((flight_profile(&profile)?, t, h))
        };
        let Some((p, target, home)) = parse() else {
            return PackedInt64Array::new();
        };
        let terrain = terrain.bind();
        let (Some(v), Some(terrain)) = (self.core.as_mut(), terrain.core.as_ref()) else {
            return PackedInt64Array::new();
        };
        match v.lift_guidance(dt, p, terrain, deck.as_slice(), cargo_height, target, home) {
            Ok(LiftEvent::None) => [0, 0].as_slice().into(),
            Ok(LiftEvent::Hook(id)) => [1, i64::from(id)].as_slice().into(),
            Ok(LiftEvent::Release) => [2, 0].as_slice().into(),
            Ok(LiftEvent::Dismount) => [3, 0].as_slice().into(),
            Err(_) => PackedInt64Array::new(),
        }
    }
    #[func]
    fn supply_guidance(
        &mut self,
        dt: f64,
        profile: PackedFloat64Array,
        terrain: Gd<TerrainCore>,
        deck: PackedByteArray,
        fobs: Array<Variant>,
        destination: Array<Variant>,
        home: Vector3,
    ) -> i64 {
        use frontline_core::vehicle_air::SupplyPoint;
        let parse = |row: &Array<Variant>| -> Option<SupplyPoint> {
            if row.len() != 3 {
                return None;
            }
            Some(SupplyPoint {
                id: read(row, 0)?,
                position: crate::point(read(row, 1)?),
                supply: read(row, 2)?,
            })
        };
        if fobs.len() > 100_000 {
            return -1;
        }
        let fobs: Option<Vec<_>> = fobs
            .iter_shared()
            .map(|v| parse(&v.try_to::<Array<Variant>>().ok()?))
            .collect();
        let destination = if destination.is_empty() {
            None
        } else {
            let Some(v) = parse(&destination) else {
                return -1;
            };
            Some(v)
        };
        let (Some(fobs), Some(p)) = (fobs, flight_profile(&profile)) else {
            return -1;
        };
        let terrain = terrain.bind();
        let (Some(v), Some(terrain)) = (self.core.as_mut(), terrain.core.as_ref()) else {
            return -1;
        };
        v.supply_guidance(
            dt,
            p,
            terrain,
            deck.as_slice(),
            &fobs,
            destination,
            crate::point(home),
        )
        .map_or(-1, |id| i64::from(id.unwrap_or(0)))
    }

    #[func]
    fn fly_to(
        &mut self,
        goal: Vector3,
        dt: f64,
        face: PackedFloat64Array,
        profile: PackedFloat64Array,
        terrain: Gd<TerrainCore>,
        deck: PackedByteArray,
    ) -> i32 {
        let Some(p) = flight_profile(&profile) else {
            return -1;
        };
        if face.len() > 1 {
            return -1;
        }
        let terrain = terrain.bind();
        let (Some(v), Some(terrain)) = (self.core.as_mut(), terrain.core.as_ref()) else {
            return -1;
        };
        v.fly_to(
            crate::point(goal),
            dt,
            face.as_slice().first().copied(),
            p,
            terrain,
            deck.as_slice(),
        )
        .map_or(-1, i32::from)
    }
    #[func]
    fn fly_uav(
        &mut self,
        dt: f64,
        altitude: f64,
        radius: f64,
        profile: PackedFloat64Array,
    ) -> bool {
        let Some(p) = flight_profile(&profile) else {
            return false;
        };
        self.core
            .as_mut()
            .is_some_and(|v| v.fly_uav(dt, altitude, radius, p).is_ok())
    }
    #[func]
    fn crew_step(
        &mut self,
        now: f64,
        profile: Array<Variant>,
        nearby: Array<Variant>,
        fob: Array<Variant>,
        mission: bool,
        planner: Gd<PathPlannerCore>,
        mut random: Gd<SimulationRandomCore>,
        threat: PackedVector3Array,
    ) -> Array<Variant> {
        if profile.len() != 3
            || nearby.len() != 3
            || !matches!(fob.len(), 0 | 2)
            || threat.len() > 1
        {
            return Array::new();
        }
        let Some(base) = text(&profile, 0) else {
            return Array::new();
        };
        let Some(flags) = read::<PackedByteArray>(&profile, 1) else {
            return Array::new();
        };
        if flags.len() != 4 || flags.as_slice().iter().any(|v| *v > 1) {
            return Array::new();
        }
        let Some(armor) = read(&profile, 2) else {
            return Array::new();
        };
        let f = flags.as_slice();
        let profile = CrewProfile {
            base: &base,
            helicopter: f[0] != 0,
            automatic: f[1] != 0,
            artillery: f[2] != 0,
            tracked: f[3] != 0,
            armor,
        };
        let mut sets = Vec::with_capacity(3);
        for row in nearby.iter_shared() {
            let Ok(rows) = row.try_to::<Array<Variant>>() else {
                return Array::new();
            };
            let Some(contacts) = crew_contacts(&rows) else {
                return Array::new();
            };
            sets.push(contacts);
        }
        let fob = if fob.is_empty() {
            None
        } else {
            let (Some(id), Some(p)) = (read(&fob, 0), read(&fob, 1)) else {
                return Array::new();
            };
            Some((id, crate::point(p)))
        };
        let nav = planner.bind();
        let (Some(v), Some(nav)) = (self.core.as_mut(), nav.core.as_ref()) else {
            return Array::new();
        };
        let out = if let Some(&from) = threat.as_slice().first() {
            v.crew_threat(
                now,
                crate::point(from),
                profile,
                nav,
                &mut random.bind_mut().core,
            )
        } else {
            v.crew_think(
                now,
                profile,
                Perception {
                    threats: &sets[0],
                    ahead: &sets[1],
                    support: &sets[2],
                    fob,
                    mission,
                },
                nav,
            )
        };
        match out {
            Ok(out) => {
                let (event, id) = match out.event {
                    None => (0, 0),
                    Some(CrewEvent::Withdraw(id)) => (1, id),
                    Some(CrewEvent::PatchedUp) => (2, 0),
                    Some(CrewEvent::WaitInfantry) => (3, 0),
                    Some(CrewEvent::Evade) => (4, 0),
                };
                varray![&route(Ok(out.route)), event, id, out.repaired_track]
            }
            Err(_) => Array::new(),
        }
    }
    #[func]
    fn ground_tick(
        &mut self,
        dt: f64,
        profile: Array<Variant>,
        target: PackedVector3Array,
        trench: bool,
        planner: Gd<PathPlannerCore>,
        terrain: Gd<TerrainCore>,
        nearby: Array<Variant>,
        mut random: Gd<SimulationRandomCore>,
        truck_route: bool,
    ) -> Array<Variant> {
        if target.len() > 1 {
            return Array::new();
        }
        let Some(p) = ground_profile(&profile) else {
            return Array::new();
        };
        let Some(nearby) = traffic(&nearby) else {
            return Array::new();
        };
        let nav = planner.bind();
        let terrain = terrain.bind();
        let (Some(v), Some(nav), Some(terrain)) =
            (self.core.as_mut(), nav.core.as_ref(), terrain.core.as_ref())
        else {
            return Array::new();
        };
        if truck_route {
            return if v.follow_truck_route(dt, p, nav, terrain, &nearby).is_ok() {
                varray![&route(Ok(Route::None)), false, false]
            } else {
                Array::new()
            };
        }
        let target = target
            .as_slice()
            .first()
            .map(|&p| (crate::point(p), trench));
        match v.drive_ground(
            dt,
            p,
            target,
            nav,
            terrain,
            &nearby,
            &mut random.bind_mut().core,
        ) {
            Ok(out) => varray![&route(Ok(out.route)), out.unstuck, out.shove],
            Err(_) => Array::new(),
        }
    }
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
