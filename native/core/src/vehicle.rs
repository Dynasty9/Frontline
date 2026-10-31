//! Retained vehicle state, including crew orders, transport links and naval/aircraft timers.
use crate::infantry::Credit;
use crate::state_codec::{Reader, Writer};
use crate::vector::Vector3;
use std::collections::HashSet;

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Resume {
    pub destination: Option<Vector3>,
    pub assault: bool,
    pub assault_destination: Option<Vector3>,
}
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct LastBlast {
    pub position: Vector3,
    pub size: f64,
    pub time: f64,
}
#[derive(Clone, Debug, PartialEq)]
pub struct Vehicle {
    pub id: u32,
    pub aim_target: u32,
    pub target: u32,
    pub forced_target: u32,
    pub destination_fob: u32,
    pub source_town: u32,
    pub heli_home: u32,
    pub heli_destination: u32,
    pub sling_cargo: u32,
    pub sling_target: u32,
    pub slung_by: u32,
    pub team: i8,
    pub owner: i32,
    pub visible: u8,
    pub seen: u8,
    pub path_revision: u64,
    pub path_index: u32,
    pub route_index: u32,
    pub mg_burst: i32,
    pub flags: u8,
    pub smoke_left: i32,
    pub cargo: i32,
    pub heli_phase: u8,
    pub atgm_left: i32,
    pub sam_left: i32,
    pub salvo: i32,
    pub lift_phase: u8,
    pub tries: i32,
    pub hp: f64,
    pub max_hp: f64,
    pub yaw: f64,
    pub turret_yaw: f64,
    pub traverse: f64,
    pub stabilization_rate: f64,
    pub aim_time: f64,
    pub speed: f64,
    pub track_fix: f64,
    pub cannon_timer: f64,
    pub mg_timer: f64,
    pub scan_timer: f64,
    pub smash_timer: f64,
    pub last_fire: f64,
    pub alert_time: f64,
    pub smoke_until: f64,
    pub blocked_timer: f64,
    pub stuck_timer: f64,
    pub stuck_yaw: f64,
    pub unstick_timer: f64,
    pub unstick_direction: f64,
    pub dismount_timer: f64,
    pub heli_timer: f64,
    pub flight_pitch: f64,
    pub flight_roll: f64,
    pub atgm_until: f64,
    pub sam_until: f64,
    pub artillery_until: f64,
    pub salvo_timer: f64,
    pub service_timer: f64,
    pub lift_timer: f64,
    pub orbit: f64,
    pub sling_timer: f64,
    pub brain_time: f64,
    pub yaw_rate: f64,
    pub sway: f64,
    pub throttle: f64,
    pub rudder: f64,
    pub current_timer: f64,
    pub about: f64,
    pub rejoin_timer: f64,
    pub astern_timer: f64,
    pub gunship_orbit: f64,
    pub rocket_timer: f64,
    pub gone: bool,
    pub track_broken: bool,
    pub path_pending: bool,
    pub returning: bool,
    pub assault: bool,
    pub brain_hold: bool,
    pub brain_overruled: bool,
    pub brain_order: bool,
    pub reverse: bool,
    pub landing: bool,
    pub grounded: bool,
    pub astern: bool,
    pub astern_stop: bool,
    pub position: Vector3,
    pub velocity: Vector3,
    pub knock_velocity: Vector3,
    pub stuck_position: Vector3,
    pub swing: Vector3,
    pub current: Vector3,
    pub astern_from: Vector3,
    pub path_destination: Option<Vector3>,
    pub assault_destination: Option<Vector3>,
    pub flight_hold: Option<Vector3>,
    pub salvo_at: Option<Vector3>,
    pub lift_destination: Option<Vector3>,
    pub uav_destination: Option<Vector3>,
    pub gunship_destination: Option<Vector3>,
    pub tries_for: Option<Vector3>,
    pub lay_yaw: Option<f64>,
    pub face_yaw: Option<f64>,
    pub tries_time: Option<f64>,
    pub avoid_cap: Option<f64>,
    pub kind: String,
    pub brain_state: String,
    pub path: Vec<Vector3>,
    pub route: Vec<Vector3>,
    pub fire_queue: Vec<Vector3>,
    pub passengers: Vec<u32>,
    pub cooldowns: Vec<(String, f64)>,
    pub resume: Option<Resume>,
    pub last_blast: Option<LastBlast>,
    pub flight: Option<[f64; 3]>,
    pub hit_by: Option<Credit>,
}
impl Default for Vehicle {
    fn default() -> Self {
        Self {
            id: 0,
            aim_target: 0,
            target: 0,
            forced_target: 0,
            destination_fob: 0,
            source_town: 0,
            heli_home: 0,
            heli_destination: 0,
            sling_cargo: 0,
            sling_target: 0,
            slung_by: 0,
            team: -1,
            owner: 0,
            visible: 0,
            seen: 0,
            path_revision: 0,
            path_index: 0,
            route_index: 0,
            mg_burst: 0,
            flags: 0,
            smoke_left: 2,
            cargo: 0,
            heli_phase: 0,
            atgm_left: 0,
            sam_left: 0,
            salvo: 0,
            lift_phase: 0,
            tries: 0,
            hp: 100.0,
            max_hp: 100.0,
            yaw: 0.0,
            turret_yaw: 0.0,
            traverse: 0.0,
            stabilization_rate: 0.0,
            aim_time: 0.0,
            speed: 0.0,
            track_fix: 0.0,
            cannon_timer: 2.0,
            mg_timer: 0.0,
            scan_timer: 0.0,
            smash_timer: 0.0,
            last_fire: -9.0,
            alert_time: 0.0,
            smoke_until: 0.0,
            blocked_timer: 0.0,
            stuck_timer: 0.0,
            stuck_yaw: 0.0,
            unstick_timer: 0.0,
            unstick_direction: 1.0,
            dismount_timer: 0.0,
            heli_timer: 0.0,
            flight_pitch: 0.0,
            flight_roll: 0.0,
            atgm_until: 0.0,
            sam_until: 0.0,
            artillery_until: 4.0,
            salvo_timer: 0.0,
            service_timer: 0.0,
            lift_timer: 0.0,
            orbit: 0.0,
            sling_timer: 0.0,
            brain_time: 0.0,
            yaw_rate: 0.0,
            sway: 0.0,
            throttle: 0.0,
            rudder: 0.0,
            current_timer: 0.0,
            about: 0.0,
            rejoin_timer: 0.0,
            astern_timer: 0.0,
            gunship_orbit: 0.0,
            rocket_timer: 6.0,
            gone: false,
            track_broken: false,
            path_pending: false,
            returning: false,
            assault: false,
            brain_hold: false,
            brain_overruled: false,
            brain_order: false,
            reverse: false,
            landing: false,
            grounded: false,
            astern: false,
            astern_stop: false,
            position: Vector3::ZERO,
            velocity: Vector3::ZERO,
            knock_velocity: Vector3::ZERO,
            stuck_position: Vector3::ZERO,
            swing: Vector3::ZERO,
            current: Vector3::ZERO,
            astern_from: Vector3::ZERO,
            path_destination: None,
            assault_destination: None,
            flight_hold: None,
            salvo_at: None,
            lift_destination: None,
            uav_destination: None,
            gunship_destination: None,
            tries_for: None,
            lay_yaw: None,
            face_yaw: None,
            tries_time: None,
            avoid_cap: None,
            kind: "tank".into(),
            brain_state: String::new(),
            path: vec![],
            route: vec![],
            fire_queue: vec![],
            passengers: vec![],
            cooldowns: vec![],
            resume: None,
            last_blast: None,
            flight: None,
            hit_by: None,
        }
    }
}
fn scalar(v: f64) -> bool {
    v.is_finite() && v.abs() <= 1e12
}
fn point(v: Vector3) -> bool {
    v.is_finite() && v.abs().max_element() <= 1_000_000.0
}
fn points(p: &[Vector3]) -> bool {
    p.len() <= 1_000_000 && p.iter().copied().all(point)
}
impl Vehicle {
    pub fn valid(&self) -> bool {
        self.id != 0
            && (-1..=1).contains(&self.team)
            && self.owner >= -2
            && self.visible <= 3
            && self.seen <= 3
            && self.flags <= 31
            && self.max_hp >= 0.0
            && self.kind.len() <= 128
            && !self.kind.is_empty()
            && matches!(
                self.brain_state.as_str(),
                "" | "withdraw" | "evade" | "wait"
            )
            && self.path_index <= 1_000_000
            && self.path_revision <= i64::MAX as u64
            && self.route_index <= 1_000_000
            && self.heli_phase <= 7
            && self.lift_phase <= 7
            && [
                self.mg_burst,
                self.smoke_left,
                self.cargo,
                self.atgm_left,
                self.sam_left,
                self.salvo,
                self.tries,
            ]
            .into_iter()
            .all(|n| (0..=1_000_000).contains(&n))
            && [
                self.hp,
                self.max_hp,
                self.yaw,
                self.turret_yaw,
                self.traverse,
                self.stabilization_rate,
                self.aim_time,
                self.speed,
                self.track_fix,
                self.cannon_timer,
                self.mg_timer,
                self.scan_timer,
                self.smash_timer,
                self.last_fire,
                self.alert_time,
                self.smoke_until,
                self.blocked_timer,
                self.stuck_timer,
                self.stuck_yaw,
                self.unstick_timer,
                self.unstick_direction,
                self.dismount_timer,
                self.heli_timer,
                self.flight_pitch,
                self.flight_roll,
                self.atgm_until,
                self.sam_until,
                self.artillery_until,
                self.salvo_timer,
                self.service_timer,
                self.lift_timer,
                self.orbit,
                self.sling_timer,
                self.brain_time,
                self.yaw_rate,
                self.sway,
                self.throttle,
                self.rudder,
                self.current_timer,
                self.about,
                self.rejoin_timer,
                self.astern_timer,
                self.gunship_orbit,
                self.rocket_timer,
            ]
            .into_iter()
            .all(scalar)
            && [
                self.position,
                self.velocity,
                self.knock_velocity,
                self.stuck_position,
                self.swing,
                self.current,
                self.astern_from,
            ]
            .into_iter()
            .all(point)
            && [
                self.path_destination,
                self.assault_destination,
                self.flight_hold,
                self.salvo_at,
                self.lift_destination,
                self.uav_destination,
                self.gunship_destination,
                self.tries_for,
            ]
            .into_iter()
            .flatten()
            .all(point)
            && [self.lay_yaw, self.face_yaw, self.tries_time, self.avoid_cap]
                .into_iter()
                .flatten()
                .all(scalar)
            && points(&self.path)
            && points(&self.route)
            && points(&self.fire_queue)
            && self.passengers.len() <= 100_000
            && self.passengers.iter().all(|&id| id != 0)
            && self.cooldowns.len() <= 4096
            && self
                .cooldowns
                .iter()
                .all(|(key, t)| !key.is_empty() && key.len() <= 128 && scalar(*t))
            && self
                .cooldowns
                .iter()
                .map(|(key, _)| key)
                .collect::<HashSet<_>>()
                .len()
                == self.cooldowns.len()
            && self.resume.is_none_or(|r| {
                r.destination.is_none_or(point) && r.assault_destination.is_none_or(point)
            })
            && self.last_blast.is_none_or(|b| {
                point(b.position) && scalar(b.time) && scalar(b.size) && b.size >= 0.0
            })
            && self.flight.is_none_or(|f| f.into_iter().all(scalar))
            && self
                .hit_by
                .as_ref()
                .is_none_or(|c| c.owner >= -2 && (-1..=1).contains(&c.team) && c.unit.len() <= 128)
    }
    pub fn checkpoint(&self) -> Result<Vec<u8>, &'static str> {
        if !self.valid() {
            return Err("invalid vehicle state");
        }
        let mut w = Writer::new(b"FLVE\x01\0\0\0");
        w.u32(self.id);
        w.u32(self.aim_target);
        w.u32(self.target);
        w.u32(self.forced_target);
        w.u32(self.destination_fob);
        w.u32(self.source_town);
        w.u32(self.heli_home);
        w.u32(self.heli_destination);
        w.u32(self.sling_cargo);
        w.u32(self.sling_target);
        w.u32(self.slung_by);
        w.byte(self.team as u8);
        w.u32(self.owner as u32);
        w.byte(self.visible);
        w.byte(self.seen);
        w.u64(self.path_revision);
        w.u32(self.path_index);
        w.u32(self.route_index);
        w.u32(self.mg_burst as u32);
        w.byte(self.flags);
        w.u32(self.smoke_left as u32);
        w.u32(self.cargo as u32);
        w.byte(self.heli_phase);
        w.u32(self.atgm_left as u32);
        w.u32(self.sam_left as u32);
        w.u32(self.salvo as u32);
        w.byte(self.lift_phase);
        w.u32(self.tries as u32);
        w.f64(self.hp);
        w.f64(self.max_hp);
        w.f64(self.yaw);
        w.f64(self.turret_yaw);
        w.f64(self.traverse);
        w.f64(self.stabilization_rate);
        w.f64(self.aim_time);
        w.f64(self.speed);
        w.f64(self.track_fix);
        w.f64(self.cannon_timer);
        w.f64(self.mg_timer);
        w.f64(self.scan_timer);
        w.f64(self.smash_timer);
        w.f64(self.last_fire);
        w.f64(self.alert_time);
        w.f64(self.smoke_until);
        w.f64(self.blocked_timer);
        w.f64(self.stuck_timer);
        w.f64(self.stuck_yaw);
        w.f64(self.unstick_timer);
        w.f64(self.unstick_direction);
        w.f64(self.dismount_timer);
        w.f64(self.heli_timer);
        w.f64(self.flight_pitch);
        w.f64(self.flight_roll);
        w.f64(self.atgm_until);
        w.f64(self.sam_until);
        w.f64(self.artillery_until);
        w.f64(self.salvo_timer);
        w.f64(self.service_timer);
        w.f64(self.lift_timer);
        w.f64(self.orbit);
        w.f64(self.sling_timer);
        w.f64(self.brain_time);
        w.f64(self.yaw_rate);
        w.f64(self.sway);
        w.f64(self.throttle);
        w.f64(self.rudder);
        w.f64(self.current_timer);
        w.f64(self.about);
        w.f64(self.rejoin_timer);
        w.f64(self.astern_timer);
        w.f64(self.gunship_orbit);
        w.f64(self.rocket_timer);
        w.byte(u8::from(self.gone));
        w.byte(u8::from(self.track_broken));
        w.byte(u8::from(self.path_pending));
        w.byte(u8::from(self.returning));
        w.byte(u8::from(self.assault));
        w.byte(u8::from(self.brain_hold));
        w.byte(u8::from(self.brain_overruled));
        w.byte(u8::from(self.brain_order));
        w.byte(u8::from(self.reverse));
        w.byte(u8::from(self.landing));
        w.byte(u8::from(self.grounded));
        w.byte(u8::from(self.astern));
        w.byte(u8::from(self.astern_stop));
        w.point(self.position);
        w.point(self.velocity);
        w.point(self.knock_velocity);
        w.point(self.stuck_position);
        w.point(self.swing);
        w.point(self.current);
        w.point(self.astern_from);
        write_point(&mut w, self.path_destination);
        write_point(&mut w, self.assault_destination);
        write_point(&mut w, self.flight_hold);
        write_point(&mut w, self.salvo_at);
        write_point(&mut w, self.lift_destination);
        write_point(&mut w, self.uav_destination);
        write_point(&mut w, self.gunship_destination);
        write_point(&mut w, self.tries_for);
        write_scalar(&mut w, self.lay_yaw);
        write_scalar(&mut w, self.face_yaw);
        write_scalar(&mut w, self.tries_time);
        write_scalar(&mut w, self.avoid_cap);
        w.bytes(self.kind.as_bytes());
        w.bytes(self.brain_state.as_bytes());
        w.u32(self.path.len() as u32);
        for &p in &self.path {
            w.point(p);
        }
        w.u32(self.route.len() as u32);
        for &p in &self.route {
            w.point(p);
        }
        w.u32(self.fire_queue.len() as u32);
        for &p in &self.fire_queue {
            w.point(p);
        }
        w.u32(self.passengers.len() as u32);
        for &id in &self.passengers {
            w.u32(id);
        }
        w.u32(self.cooldowns.len() as u32);
        for (key, t) in &self.cooldowns {
            w.bytes(key.as_bytes());
            w.f64(*t);
        }
        w.byte(u8::from(self.resume.is_some()));
        if let Some(r) = self.resume {
            write_point(&mut w, r.destination);
            w.byte(u8::from(r.assault));
            write_point(&mut w, r.assault_destination);
        }
        w.byte(u8::from(self.last_blast.is_some()));
        if let Some(b) = self.last_blast {
            w.point(b.position);
            w.f64(b.size);
            w.f64(b.time);
        }
        w.byte(u8::from(self.flight.is_some()));
        if let Some(f) = self.flight {
            for value in f {
                w.f64(value);
            }
        }
        w.byte(u8::from(self.hit_by.is_some()));
        if let Some(c) = &self.hit_by {
            w.u32(c.owner as u32);
            w.byte(c.team as u8);
            w.bytes(c.unit.as_bytes());
            w.u32(c.soldier);
        }
        Ok(w.0)
    }
    pub fn restore(bytes: &[u8]) -> Result<Self, &'static str> {
        if bytes.len() > 64 * 1024 * 1024 {
            return Err("vehicle checkpoint exceeds limit");
        }
        let mut r = Reader::new(bytes, b"FLVE\x01\0\0\0")?;
        let v = Self {
            id: r.u32()?,
            aim_target: r.u32()?,
            target: r.u32()?,
            forced_target: r.u32()?,
            destination_fob: r.u32()?,
            source_town: r.u32()?,
            heli_home: r.u32()?,
            heli_destination: r.u32()?,
            sling_cargo: r.u32()?,
            sling_target: r.u32()?,
            slung_by: r.u32()?,
            team: r.byte()? as i8,
            owner: r.u32()? as i32,
            visible: r.byte()?,
            seen: r.byte()?,
            path_revision: r.u64()?,
            path_index: r.u32()?,
            route_index: r.u32()?,
            mg_burst: r.u32()? as i32,
            flags: r.byte()?,
            smoke_left: r.u32()? as i32,
            cargo: r.u32()? as i32,
            heli_phase: r.byte()?,
            atgm_left: r.u32()? as i32,
            sam_left: r.u32()? as i32,
            salvo: r.u32()? as i32,
            lift_phase: r.byte()?,
            tries: r.u32()? as i32,
            hp: r.f64()?,
            max_hp: r.f64()?,
            yaw: r.f64()?,
            turret_yaw: r.f64()?,
            traverse: r.f64()?,
            stabilization_rate: r.f64()?,
            aim_time: r.f64()?,
            speed: r.f64()?,
            track_fix: r.f64()?,
            cannon_timer: r.f64()?,
            mg_timer: r.f64()?,
            scan_timer: r.f64()?,
            smash_timer: r.f64()?,
            last_fire: r.f64()?,
            alert_time: r.f64()?,
            smoke_until: r.f64()?,
            blocked_timer: r.f64()?,
            stuck_timer: r.f64()?,
            stuck_yaw: r.f64()?,
            unstick_timer: r.f64()?,
            unstick_direction: r.f64()?,
            dismount_timer: r.f64()?,
            heli_timer: r.f64()?,
            flight_pitch: r.f64()?,
            flight_roll: r.f64()?,
            atgm_until: r.f64()?,
            sam_until: r.f64()?,
            artillery_until: r.f64()?,
            salvo_timer: r.f64()?,
            service_timer: r.f64()?,
            lift_timer: r.f64()?,
            orbit: r.f64()?,
            sling_timer: r.f64()?,
            brain_time: r.f64()?,
            yaw_rate: r.f64()?,
            sway: r.f64()?,
            throttle: r.f64()?,
            rudder: r.f64()?,
            current_timer: r.f64()?,
            about: r.f64()?,
            rejoin_timer: r.f64()?,
            astern_timer: r.f64()?,
            gunship_orbit: r.f64()?,
            rocket_timer: r.f64()?,
            gone: r.boolean()?,
            track_broken: r.boolean()?,
            path_pending: r.boolean()?,
            returning: r.boolean()?,
            assault: r.boolean()?,
            brain_hold: r.boolean()?,
            brain_overruled: r.boolean()?,
            brain_order: r.boolean()?,
            reverse: r.boolean()?,
            landing: r.boolean()?,
            grounded: r.boolean()?,
            astern: r.boolean()?,
            astern_stop: r.boolean()?,
            position: r.point()?,
            velocity: r.point()?,
            knock_velocity: r.point()?,
            stuck_position: r.point()?,
            swing: r.point()?,
            current: r.point()?,
            astern_from: r.point()?,
            path_destination: read_point(&mut r)?,
            assault_destination: read_point(&mut r)?,
            flight_hold: read_point(&mut r)?,
            salvo_at: read_point(&mut r)?,
            lift_destination: read_point(&mut r)?,
            uav_destination: read_point(&mut r)?,
            gunship_destination: read_point(&mut r)?,
            tries_for: read_point(&mut r)?,
            lay_yaw: read_scalar(&mut r)?,
            face_yaw: read_scalar(&mut r)?,
            tries_time: read_scalar(&mut r)?,
            avoid_cap: read_scalar(&mut r)?,
            kind: read_text(&mut r)?,
            brain_state: read_text(&mut r)?,
            path: read_points(&mut r)?,
            route: read_points(&mut r)?,
            fire_queue: read_points(&mut r)?,
            passengers: read_ids(&mut r)?,
            cooldowns: read_cooldowns(&mut r)?,
            resume: if r.boolean()? {
                Some(Resume {
                    destination: read_point(&mut r)?,
                    assault: r.boolean()?,
                    assault_destination: read_point(&mut r)?,
                })
            } else {
                None
            },
            last_blast: if r.boolean()? {
                Some(LastBlast {
                    position: r.point()?,
                    size: r.f64()?,
                    time: r.f64()?,
                })
            } else {
                None
            },
            flight: if r.boolean()? {
                Some([r.f64()?, r.f64()?, r.f64()?])
            } else {
                None
            },
            hit_by: if r.boolean()? {
                Some(Credit {
                    owner: r.u32()? as i32,
                    team: r.byte()? as i8,
                    unit: read_text(&mut r)?,
                    soldier: r.u32()?,
                })
            } else {
                None
            },
        };
        r.finish()?;
        if !v.valid() {
            return Err("invalid vehicle checkpoint");
        }
        Ok(v)
    }
}
fn write_point(w: &mut Writer, p: Option<Vector3>) {
    w.byte(u8::from(p.is_some()));
    if let Some(p) = p {
        w.point(p);
    }
}
fn write_scalar(w: &mut Writer, v: Option<f64>) {
    w.byte(u8::from(v.is_some()));
    if let Some(v) = v {
        w.f64(v);
    }
}
fn read_point(r: &mut Reader<'_>) -> Result<Option<Vector3>, &'static str> {
    Ok(if r.boolean()? { Some(r.point()?) } else { None })
}
fn read_scalar(r: &mut Reader<'_>) -> Result<Option<f64>, &'static str> {
    Ok(if r.boolean()? { Some(r.f64()?) } else { None })
}
fn read_text(r: &mut Reader<'_>) -> Result<String, &'static str> {
    std::str::from_utf8(r.bytes(128)?)
        .map(str::to_owned)
        .map_err(|_| "invalid vehicle text")
}
fn count(r: &mut Reader<'_>, limit: usize) -> Result<usize, &'static str> {
    let n = r.u32()? as usize;
    if n > limit {
        Err("vehicle collection exceeds limit")
    } else {
        Ok(n)
    }
}
fn read_points(r: &mut Reader<'_>) -> Result<Vec<Vector3>, &'static str> {
    let n = count(r, 1_000_000)?;
    (0..n).map(|_| r.point()).collect()
}
fn read_ids(r: &mut Reader<'_>) -> Result<Vec<u32>, &'static str> {
    let n = count(r, 100_000)?;
    (0..n).map(|_| r.u32()).collect()
}
fn read_cooldowns(r: &mut Reader<'_>) -> Result<Vec<(String, f64)>, &'static str> {
    let n = count(r, 4096)?;
    (0..n).map(|_| Ok((read_text(r)?, r.f64()?))).collect()
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum Route {
    None,
    Ground {
        destination: Vector3,
        care: f64,
        revision: u64,
    },
    Boat {
        destination: Vector3,
    },
}
fn flat(p: Vector3) -> Vector3 {
    Vector3::new(p.x, 0.0, p.z)
}
fn yaw(p: Vector3) -> f64 {
    libm::atan2(-f64::from(p.x), -f64::from(p.z))
}
fn wrap(v: f64) -> f64 {
    use std::f64::consts::{PI, TAU};
    v - TAU * libm::floor((v + PI) / TAU)
}
impl Vehicle {
    pub fn center(&self) -> Vector3 {
        self.position + Vector3::new(0.0, 1.1, 0.0)
    }
    pub fn exposed_points(&self) -> [Vector3; 3] {
        let forward = Vector3::new(
            -libm::sin(self.yaw) as f32,
            0.0,
            -libm::cos(self.yaw) as f32,
        );
        [
            self.position + Vector3::new(0.0, 1.2, 0.0),
            self.position + Vector3::new(0.0, 1.8, 0.0),
            self.position + forward * 2.0 + Vector3::Y,
        ]
    }
    pub fn is_moving(&self, helicopter: bool) -> bool {
        self.path_pending
            || (self.path_index as usize) < self.path.len()
            || (helicopter && self.velocity.length() > 0.5)
    }
    pub fn needs_repair(&self) -> bool {
        self.track_broken || self.hp < self.max_hp - 1.0
    }
    pub fn repair(&mut self, amount: f64) -> Result<bool, &'static str> {
        if !amount.is_finite() || !(0.0..=1_000_000.0).contains(&amount) {
            return Err("invalid vehicle repair");
        }
        let hp = self.max_hp.min(self.hp + amount * self.max_hp / 40.0);
        let fix = self.track_fix + amount;
        if !scalar(hp) || (self.track_broken && !scalar(fix)) {
            return Err("vehicle repair exceeds state limit");
        }
        self.hp = hp;
        if self.track_broken {
            self.track_fix = fix;
            if fix >= 6.0 {
                self.track_broken = false;
                self.track_fix = 0.0;
                return Ok(true);
            }
        }
        Ok(false)
    }
    pub fn rearm(&mut self, atgm: i32, sam: i32) -> Result<(), &'static str> {
        if !(0..=1_000_000).contains(&atgm) || !(0..=1_000_000).contains(&sam) {
            return Err("invalid vehicle load");
        }
        self.atgm_left = atgm;
        self.sam_left = sam;
        Ok(())
    }
    pub fn request_path(&mut self, destination: Vector3, care: f64) -> Result<Route, &'static str> {
        if !point(destination) || !care.is_finite() || !(0.0..=1.0).contains(&care) {
            return Err("invalid vehicle route");
        }
        let revision = self
            .path_revision
            .checked_add(1)
            .filter(|&revision| revision <= i64::MAX as u64)
            .ok_or("vehicle route revisions exhausted")?;
        self.path_revision = revision;
        self.path_pending = true;
        self.path_destination = Some(destination);
        self.path.clear();
        self.path_index = 0;
        Ok(Route::Ground {
            destination,
            care,
            revision,
        })
    }
    pub fn complete_path(
        &mut self,
        revision: u64,
        path: Vec<Vector3>,
    ) -> Result<bool, &'static str> {
        if !points(&path) {
            return Err("invalid vehicle path");
        }
        if revision != self.path_revision {
            return Ok(false);
        }
        self.path_pending = false;
        if self.gone || self.hp <= 0.0 {
            return Ok(false);
        }
        self.path = path;
        self.path_index = 0;
        Ok(true)
    }
    pub fn crew_busy(&self) -> bool {
        self.brain_state == "withdraw" && self.owner < 0 && !self.brain_order
    }
    pub fn complete_boat_path(&mut self, path: Vec<Vector3>) -> Result<(), &'static str> {
        if !points(&path) {
            return Err("invalid boat path");
        }
        self.path = path;
        self.path_index = 0;
        Ok(())
    }
    pub fn order_move(
        &mut self,
        destination: Vector3,
        base: &str,
        landing: Vector3,
    ) -> Result<Route, &'static str> {
        if !point(destination) || !point(landing) {
            return Err("invalid vehicle destination");
        }
        if self.crew_busy() {
            return Ok(Route::None);
        }
        let route = match base {
            "supply" | "attack_heli" | "lift_heli" | "uav" => Route::None,
            "boat" => Route::Boat { destination },
            _ => self.request_path(destination, 0.5)?,
        };
        self.assault = false;
        match base {
            "supply" => return Ok(route),
            "attack_heli" => {
                self.forced_target = 0;
                self.gunship_destination = Some(flat(destination));
                return Ok(route);
            }
            "lift_heli" => {
                self.lift_destination = Some(landing);
                if matches!(self.lift_phase, 3 | 4 | 7) {
                    self.lift_phase = if self.position.y > 3.0 { 2 } else { 1 };
                }
                return Ok(route);
            }
            "uav" => {
                self.uav_destination = Some(flat(destination));
                return Ok(route);
            }
            _ => {}
        }
        self.forced_target = 0;
        self.path_index = 0;
        self.stuck_timer = 0.0;
        self.stuck_position = self.position;
        if !self.brain_order {
            if self.brain_state == "withdraw" {
                self.brain_overruled = true;
            }
            self.brain_state.clear();
            self.brain_hold = false;
            self.resume = None;
        }
        Ok(route)
    }
    pub fn order_assault(
        &mut self,
        destination: Vector3,
        base: &str,
        landing: Vector3,
    ) -> Result<Route, &'static str> {
        if self.crew_busy() {
            return Ok(Route::None);
        }
        let route = self.order_move(destination, base, landing)?;
        self.assault = true;
        self.assault_destination = Some(destination);
        Ok(route)
    }
    pub fn order_attack(
        &mut self,
        target: u32,
        position: Vector3,
        base: &str,
    ) -> Result<Route, &'static str> {
        if target == 0 || !point(position) {
            return Err("invalid vehicle target");
        }
        if base == "attack_heli" {
            self.forced_target = target;
            self.gunship_destination = Some(flat(position));
            return Ok(Route::None);
        }
        let d = flat(position - self.position);
        let route = if d.length() > 45.0 {
            let destination = position - crate::vector::normalized(d) * 40.0;
            if base == "boat" {
                Route::Boat { destination }
            } else {
                self.request_path(destination, 0.2)?
            }
        } else {
            Route::None
        };
        self.forced_target = target;
        if route != Route::None {
            self.path_index = 0;
        }
        Ok(route)
    }
    pub fn order_stop(&mut self, base: &str, automatic: bool) -> Result<(), &'static str> {
        self.path_revision = self
            .path_revision
            .checked_add(1)
            .filter(|&revision| revision <= i64::MAX as u64)
            .ok_or("vehicle route revisions exhausted")?;
        self.path_pending = false;
        self.path_destination = None;
        if base == "lift_heli" && !automatic {
            self.sling_target = 0;
            self.lift_destination = None;
            self.flight_hold = Some(self.position);
            self.lift_phase = if self.position.y > 0.6 { 7 } else { 0 };
        }
        if base == "uav" {
            self.uav_destination = Some(flat(self.position));
        }
        if base == "attack_heli" {
            self.gunship_destination = Some(flat(self.position));
        }
        self.path.clear();
        self.path_index = 0;
        self.forced_target = 0;
        Ok(())
    }
    pub fn update_flags(
        &mut self,
        now: f64,
        helicopter: bool,
        artillery: bool,
    ) -> Result<u8, &'static str> {
        if !scalar(now) {
            return Err("invalid vehicle time");
        }
        self.flags = u8::from(self.track_broken)
            | if now - self.last_fire < 0.3 { 2 } else { 0 }
            | if self.blocked_timer > 2.0 { 4 } else { 0 }
            | if self.salvo > 0 || (artillery && now - self.last_fire < 4.0) {
                8
            } else {
                0
            }
            | if helicopter && self.position.y < 0.6 {
                16
            } else {
                0
            };
        Ok(self.flags)
    }
    pub fn aim_error(&self, target: Option<Vector3>) -> f64 {
        target.map_or(std::f64::consts::PI, |p| {
            wrap(yaw(flat(p - self.position)) - (self.yaw + self.turret_yaw)).abs()
        })
    }
    pub fn slew_turret(
        &mut self,
        wanted: f64,
        dt: f64,
        returning: bool,
        gunship: bool,
        rate: f64,
        accel: f64,
    ) -> Result<(), &'static str> {
        if !scalar(wanted)
            || !dt.is_finite()
            || !(0.0..=3600.0).contains(&dt)
            || !rate.is_finite()
            || !(0.0..=1000.0).contains(&rate)
            || !accel.is_finite()
            || !(0.0..=1000.0).contains(&accel)
        {
            return Err("invalid turret step");
        }
        let rate = (rate * if returning { 0.5 } else { 1.0 } - self.stabilization_rate).max(0.0);
        // VehicleMotion.slew returns a Godot Vector2, rounding both components to float32.
        let [mut angle, mut velocity] = crate::vehicle_motion::slew(
            self.turret_yaw,
            self.traverse,
            wanted,
            rate,
            accel,
            dt,
            !gunship,
        );
        if gunship {
            let limit = 110.0f64.to_radians();
            if f64::from(angle).abs() > limit {
                angle = f64::from(angle).clamp(-limit, limit) as f32;
                velocity = 0.0;
            }
        }
        self.turret_yaw = f64::from(angle);
        self.traverse = f64::from(velocity);
        Ok(())
    }
    pub fn turret_tick(
        &mut self,
        target: Option<(u32, Vector3)>,
        dt: f64,
        gunship: bool,
        rate: f64,
        accel: f64,
    ) -> Result<(), &'static str> {
        if target.is_some_and(|(id, p)| id == 0 || !point(p)) {
            return Err("invalid turret target");
        }
        let mut wanted = target.map_or(0.0, |(_, p)| yaw(flat(p - self.position)) - self.yaw);
        if gunship {
            let limit = 110.0f64.to_radians();
            wanted = wrap(wanted).clamp(-limit, limit);
        }
        self.slew_turret(wanted, dt, target.is_none(), gunship, rate, accel)?;
        let id = target.map_or(0, |t| t.0);
        if id != self.aim_target {
            self.aim_time = 0.0;
            self.aim_target = id;
        }
        if target.is_some()
            && self.aim_error(target.map(|t| t.1)) < 0.025
            && self.traverse.abs() < 0.12
        {
            self.aim_time += dt;
        } else {
            self.aim_time = 0.0;
        }
        Ok(())
    }
}
