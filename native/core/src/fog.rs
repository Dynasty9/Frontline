//! Team visibility and remembered sightings are authoritative; clients receive only their team's view.
use crate::actors::{Actor, Actors};
use crate::entities::Kind;
use crate::infantry_vitals::Life;
use crate::navigation_scene::NavigationScene;
use crate::projectile_actor::Motion;
use crate::state_codec::{Reader, Writer};
use crate::structure::Structure;
use crate::support;
use crate::terrain::{Terrain, NETTED};
use crate::vector::Vector3;
use crate::vehicle::Vehicle;
use std::collections::{HashMap, HashSet};
const LIMIT: usize = 100_000;
pub type Mark = [f32; 4];
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Sighting {
    pub id: u32,
    pub position: Vector3,
    pub time: f64,
}
#[derive(Clone, Debug, Default, PartialEq)]
pub struct Fog {
    pub marks: [Vec<Mark>; 2],
    pub sighted: [Vec<Sighting>; 2],
    pub drones: Vec<(u32, u8)>,
}
#[derive(Clone, Copy)]
pub struct VehicleProfile {
    pub sight: f64,
    pub helicopter: bool,
    pub automatic: bool,
    pub cannon: bool,
}
#[derive(Clone, Copy)]
struct Eye {
    position: Vector3,
    radius: f32,
}
fn team(a: &Actor) -> i8 {
    match a {
        Actor::Soldier(s) => s.identity.team,
        Actor::Vehicle(v) => v.team,
        Actor::Structure(s) => s.team,
        Actor::Projectile(p) => p.team,
        Actor::Drone(d) => d.team,
    }
}
fn structure_sight(s: &Structure) -> f64 {
    match s.kind.as_str() {
        "fob" | "depot" => 50.,
        "watchtower" => {
            if s.manned {
                115.
            } else {
                85.
            }
        }
        "town" => s.zone_radius,
        "mines" | "wire" | "tank_trap" | "sandbags" | "trench" | "hesco" | "barricade"
        | "concrete_wall" | "camo_net" | "ammo_cache" => 0.,
        _ => 30.,
    }
}
fn point(p: Vector3) -> bool {
    p.is_finite() && p.abs().max_element() <= 1_000_000.
}
fn visible(a: &Actor) -> u8 {
    match a {
        Actor::Soldier(s) => s.identity.visible,
        Actor::Vehicle(v) => v.visible,
        Actor::Structure(s) => s.visible,
        _ => 3,
    }
}
fn eyes(
    actors: &Actors,
    side: i8,
    marks: &[Mark],
    half: f64,
    profiles: &HashMap<u32, VehicleProfile>,
) -> Vec<Eye> {
    let mut out = vec![];
    let mut add = |p: Vector3, r: f64| {
        out.push(Eye {
            position: Vector3::new(p.x, 0., p.z),
            radius: r as f32,
        })
    };
    for kind in [
        Kind::Soldier,
        Kind::Vehicle,
        Kind::Structure,
        Kind::Drone,
        Kind::Projectile,
    ] {
        for a in actors.iter_kind(kind).filter(|a| team(a) == side) {
            match a {
                Actor::Soldier(s) => match s.vitals.life {
                    Life::Alive => add(
                        s.motion.position,
                        if s.duty.phase == 2
                            && actors
                                .structure(s.emplacement.structure as u32)
                                .is_some_and(|s| s.kind == "watchtower")
                        {
                            75.
                        } else {
                            56.
                        },
                    ),
                    Life::Downed => add(s.motion.position, 22.),
                    _ => (),
                },
                Actor::Vehicle(v) => add(v.position, profiles[&v.id].sight),
                Actor::Structure(s) if s.built => {
                    let r = structure_sight(s);
                    if r > 0. {
                        add(
                            if s.kind == "town" {
                                s.zone_center.unwrap_or(s.position)
                            } else {
                                s.position
                            },
                            r,
                        );
                    }
                }
                Actor::Drone(d) => add(d.flight.position, 40.),
                Actor::Projectile(p) => {
                    if let Motion::Support(f) = &p.motion {
                        match f.kind {
                            support::Kind::Jet | support::Kind::GunRun => {
                                if f64::from(f.position.x.abs()) < half + 40.
                                    && f64::from(f.position.z.abs()) < half + 40.
                                {
                                    add(
                                        f.position,
                                        if f.kind == support::Kind::GunRun {
                                            55.
                                        } else if f.sight > 0. {
                                            f.sight
                                        } else {
                                            70.
                                        },
                                    );
                                }
                            }
                            support::Kind::Orbit => {
                                if f.life > 2. && f.life < f.on_station() {
                                    add(f.target, if f.sight > 0. { f.sight } else { 70. });
                                }
                                add(f.position, 40.);
                            }
                        }
                    }
                }
                _ => (),
            }
        }
    }
    for m in marks {
        add(Vector3::new(m[0], 0., m[1]), f64::from(m[2]));
    }
    out
}
fn bounds(e: Eye) -> [i32; 4] {
    let x = f64::from(e.position.x);
    let z = f64::from(e.position.z);
    let r = f64::from(e.radius);
    [
        libm::floor((x - r) / 16.) as i32,
        libm::floor((x + r) / 16.) as i32,
        libm::floor((z - r) / 16.) as i32,
        libm::floor((z + r) / 16.) as i32,
    ]
}
impl Fog {
    pub fn valid(&self) -> bool {
        self.marks.iter().all(|ms| {
            ms.len() <= LIMIT
                && ms.iter().all(|m| {
                    m.iter().all(|v| v.is_finite())
                        && m[0].abs() <= 1_000_000.
                        && m[1].abs() <= 1_000_000.
                        && (0.0..=4096.).contains(&m[2])
                        && f64::from(m[3]).abs() <= 1e12
                })
        }) && self.sighted.iter().all(|ss| {
            let mut ids = HashSet::new();
            ss.len() <= 1_000_000
                && ss.iter().all(|s| {
                    s.id != 0
                        && ids.insert(s.id)
                        && point(s.position)
                        && s.time.is_finite()
                        && s.time.abs() <= 1e12
                })
        }) && {
            let mut ids = HashSet::new();
            self.drones.len() <= LIMIT
                && self
                    .drones
                    .iter()
                    .all(|&(id, m)| id != 0 && m <= 3 && ids.insert(id))
        }
    }
    pub fn add_mark(
        &mut self,
        side: i8,
        position: Vector3,
        radius: f64,
        now: f64,
        linger: f64,
    ) -> Result<(), &'static str> {
        if !(0..=1).contains(&side) {
            return Ok(());
        }
        if !point(position)
            || !radius.is_finite()
            || !(0.0..=4096.).contains(&radius)
            || !now.is_finite()
            || !linger.is_finite()
            || (now + linger).abs() > 1e12 - 65536.
            || self.marks[side as usize].len() >= LIMIT
        {
            return Err("invalid reconnaissance mark");
        }
        self.marks[side as usize].push([
            position.x,
            position.z,
            radius as f32,
            (now + linger) as f32,
        ]);
        Ok(())
    }
    pub fn update(
        &mut self,
        actors: &mut Actors,
        terrain: &Terrain,
        now: f64,
        profile: &dyn Fn(&Vehicle) -> VehicleProfile,
    ) -> Result<Vec<u32>, &'static str> {
        if !self.valid() || !now.is_finite() || !(0.0..=1e12).contains(&now) {
            return Err("invalid fog update");
        }
        let profiles: HashMap<_, _> = actors
            .iter_kind(Kind::Vehicle)
            .map(|a| {
                let Actor::Vehicle(v) = a else { unreachable!() };
                (v.id, profile(v))
            })
            .collect();
        if profiles
            .values()
            .any(|p| !p.sight.is_finite() || !(0.0..=4096.).contains(&p.sight))
        {
            return Err("invalid vehicle sight");
        }
        let marks: [Vec<_>; 2] = std::array::from_fn(|t| {
            self.marks[t]
                .iter()
                .copied()
                .filter(|m| f64::from(m[3]) >= now)
                .collect()
        });
        let eyes: [Vec<_>; 2] =
            std::array::from_fn(|t| eyes(actors, t as i8, &marks[t], terrain.half(), &profiles));
        let cells: u64 = eyes
            .iter()
            .flatten()
            .map(|&e| {
                let b = bounds(e);
                (b[1] - b[0] + 1) as u64 * (b[3] - b[2] + 1) as u64
            })
            .sum();
        if cells > 10_000_000 {
            return Err("visibility cell limit exceeded");
        }
        let mut grids: [HashMap<(i32, i32), Vec<usize>>; 2] =
            std::array::from_fn(|_| HashMap::new());
        for t in 0..2 {
            for (i, &e) in eyes[t].iter().enumerate() {
                let b = bounds(e);
                for x in b[0]..=b[1] {
                    for z in b[2]..=b[3] {
                        grids[t].entry((x, z)).or_default().push(i);
                    }
                }
            }
        }
        self.marks = marks;
        let mut known: [HashMap<u32, usize>; 2] = std::array::from_fn(|t| {
            self.sighted[t]
                .iter()
                .enumerate()
                .map(|(i, s)| (s.id, i))
                .collect()
        });
        let old_drones: HashMap<_, _> = self.drones.iter().copied().collect();
        self.drones.clear();
        let ids: Vec<_> = [Kind::Soldier, Kind::Vehicle, Kind::Drone, Kind::Structure]
            .into_iter()
            .flat_map(|k| {
                actors
                    .iter_kind(k)
                    .filter(move |a| k != Kind::Structure || team(a) >= 0)
                    .map(|a| a.identity().id)
            })
            .collect();
        let mut changed = vec![];
        for id in ids {
            let a = actors.get(id).unwrap();
            let side = team(a);
            let p = a.position();
            let mut mask = 0;
            let k = (
                libm::floor(f64::from(p.x) / 16.) as i32,
                libm::floor(f64::from(p.z) / 16.) as i32,
            );
            let hide = if matches!(a,Actor::Vehicle(v) if profiles[&v.id].helicopter && v.position.y>3.)
                || terrain.layers[NETTED][terrain.index(p)] == 0
            {
                1.
            } else {
                0.5
            };
            for t in 0..2 {
                if side == t as i8 {
                    mask |= 1 << t;
                    continue;
                }
                if grids[t].get(&k).is_some_and(|obs| {
                    obs.iter().any(|&i| {
                        let eye = eyes[t][i];
                        let d = eye.position - p;
                        let r = f64::from(eye.radius);
                        f64::from(Vector3::new(d.x, 0., d.z).length_squared())
                            <= r * r * hide * hide
                    })
                }) {
                    mask |= 1 << t;
                }
            }
            if matches!(a,Actor::Structure(s) if s.kind=="mines")
                || matches!(a,Actor::Soldier(s) if s.vitals.life==Life::Hidden && side>=0)
            {
                mask = 1 << side;
            }
            if side >= 0
                && matches!(a, Actor::Vehicle(_) | Actor::Soldier(_))
                && !matches!(a,Actor::Soldier(s) if s.vitals.life!=Life::Alive)
            {
                for t in 0..2 {
                    if side != t as i8 && mask & (1 << t) != 0 {
                        let s = Sighting {
                            id,
                            position: p,
                            time: now,
                        };
                        if let Some(&i) = known[t].get(&id) {
                            self.sighted[t][i] = s;
                        } else {
                            known[t].insert(id, self.sighted[t].len());
                            self.sighted[t].push(s);
                        }
                    }
                }
            }
            let old = if matches!(a, Actor::Drone(_)) {
                *old_drones.get(&id).unwrap_or(&0)
            } else {
                visible(a)
            };
            let mut dirty = old != mask;
            match actors.get_mut(id).unwrap() {
                Actor::Soldier(s) => s.identity.visible = mask,
                Actor::Vehicle(v) => v.visible = mask,
                Actor::Structure(s) => {
                    s.visible = mask;
                    dirty |= s.seen | mask != s.seen;
                    s.seen |= mask;
                }
                Actor::Drone(_) => self.drones.push((id, mask)),
                _ => unreachable!(),
            }
            if dirty {
                changed.push(id);
            }
        }
        Ok(changed)
    }
    pub fn checkpoint(&self) -> Result<Vec<u8>, &'static str> {
        if !self.valid() {
            return Err("invalid fog state");
        }
        let mut w = Writer::new(b"FLFG\x01\0\0\0");
        for ms in &self.marks {
            w.u32(ms.len() as u32);
            for m in ms {
                for &v in m {
                    w.f32(v);
                }
            }
        }
        for ss in &self.sighted {
            w.u32(ss.len() as u32);
            for s in ss {
                w.u32(s.id);
                w.point(s.position);
                w.f64(s.time);
            }
        }
        w.u32(self.drones.len() as u32);
        for &(id, m) in &self.drones {
            w.u32(id);
            w.byte(m);
        }
        Ok(w.0)
    }
    pub fn restore(bytes: &[u8]) -> Result<Self, &'static str> {
        let mut r = Reader::new(bytes, b"FLFG\x01\0\0\0")?;
        let mut out = Self::default();
        for ms in &mut out.marks {
            let n = r.u32()? as usize;
            if n > LIMIT {
                return Err("reconnaissance mark limit exceeded");
            }
            for _ in 0..n {
                ms.push([r.f32()?, r.f32()?, r.f32()?, r.f32()?]);
            }
        }
        for ss in &mut out.sighted {
            let n = r.u32()?;
            if n > 1_000_000 {
                return Err("sighting limit exceeded");
            }
            for _ in 0..n {
                ss.push(Sighting {
                    id: r.u32()?,
                    position: r.point()?,
                    time: r.f64()?,
                });
            }
        }
        let n = r.u32()? as usize;
        if n > LIMIT {
            return Err("drone visibility limit exceeded");
        }
        for _ in 0..n {
            out.drones.push((r.u32()?, r.byte()?));
        }
        r.finish()?;
        if !out.valid() {
            return Err("invalid fog state");
        }
        Ok(out)
    }
}

pub fn update_danger(
    actors: &Actors,
    nav: &mut NavigationScene,
    profile: &dyn Fn(&Vehicle) -> VehicleProfile,
) -> Result<[Vec<f32>; 2], &'static str> {
    let cs = nav.infantry.cluster_side();
    let nc = nav.infantry.side() / cs;
    let half = nav.infantry.side() as f64 * 0.5;
    if nav.vehicles.side() != nav.infantry.side() || nav.vehicles.cluster_side() != cs {
        return Err("incompatible danger grids");
    }
    let mut maps: [Vec<f32>; 2] = std::array::from_fn(|_| vec![0.; nc * nc]);
    for t in 0..2 {
        let mut threat = |p: Vector3, r: f64, w: f64| {
            let cell =
                |v: f64| (libm::floor(v / cs as f64) as i32).clamp(0, nc as i32 - 1) as usize;
            for z in cell(f64::from(p.z) + half - r)..=cell(f64::from(p.z) + half + r) {
                for x in cell(f64::from(p.x) + half - r)..=cell(f64::from(p.x) + half + r) {
                    let c = Vector3::new(
                        (x as f64 * cs as f64 - half + cs as f64 * 0.5) as f32,
                        0.,
                        (z as f64 * cs as f64 - half + cs as f64 * 0.5) as f32,
                    );
                    let d = c - p;
                    let distance = f64::from(Vector3::new(d.x, 0., d.z).length());
                    if distance < r {
                        let i = z * nc + x;
                        maps[t][i] = (f64::from(maps[t][i]) + w * (1. - 0.5 * distance / r)) as f32;
                    }
                }
            }
        };
        for kind in [Kind::Soldier, Kind::Vehicle, Kind::Structure] {
            for a in actors.iter_kind(kind) {
                if team(a) < 0 || team(a) == t as i8 {
                    continue;
                }
                match a {
                    Actor::Soldier(s)
                        if s.vitals.life == Life::Alive && s.identity.visible & (1 << t) != 0 =>
                    {
                        threat(
                            s.motion.position,
                            42.,
                            if matches!(s.identity.unit.as_str(), "mg_gunner" | "pkm") {
                                2.
                            } else {
                                1.
                            },
                        )
                    }
                    Actor::Vehicle(v) if v.visible & (1 << t) != 0 => {
                        let p = profile(v);
                        if !p.automatic {
                            threat(v.position, 60., if p.cannon { 3. } else { 2. });
                        }
                    }
                    Actor::Structure(s)
                        if s.built
                            && s.seen & (1 << t) != 0
                            && matches!(
                                s.kind.as_str(),
                                "mg_nest" | "hmg_nest" | "bunker" | "at_post"
                            ) =>
                    {
                        threat(s.position, 55., 3.)
                    }
                    _ => (),
                }
            }
        }
        for v in &mut maps[t] {
            *v = v.min(4.);
        }
        if !nav.infantry.set_danger(t, &maps[t]) || !nav.vehicles.set_danger(t, &maps[t]) {
            return Err("invalid danger map");
        }
    }
    Ok(maps)
}
