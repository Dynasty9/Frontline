//! Public render state uses the existing Godot entity payloads, never actor checkpoints.
pub mod events;
mod hud;
mod speech;
use crate::{content::Content, simulation::Simulation};
use frontline_core as sim;
pub use hud::{hud, report};
use serde_json::{json, Value};
use sim::{actors::Actor, infantry_vitals::Life, projectile_actor::Motion, vector::Vector3};
use std::{
    collections::BTreeMap,
    hash::{DefaultHasher, Hash, Hasher},
};

fn point(p: Vector3) -> Value {
    json!([p.x, p.y, p.z])
}
fn fraction(v: f64) -> u8 {
    (v.clamp(0., 1.) * 255.) as u8
}
fn angle(out: &mut Vec<u8>, v: f64) {
    out.extend_from_slice(
        &((v.rem_euclid(std::f64::consts::TAU) / std::f64::consts::TAU * 65535.) as u16)
            .to_le_bytes(),
    );
}
fn position(out: &mut Vec<u8>, p: Vector3) {
    for v in [p.x, p.y, p.z] {
        out.extend_from_slice(&v.to_le_bytes());
    }
}
pub fn team(a: &Actor) -> i8 {
    match a {
        Actor::Soldier(s) => s.identity.team,
        Actor::Vehicle(v) => v.team,
        Actor::Structure(s) => s.team,
        Actor::Projectile(p) => p.team,
        Actor::Drone(d) => d.team,
    }
}
fn drone_visibility(s: &Simulation, id: u32) -> u8 {
    s.state
        .rules
        .fog
        .drones
        .iter()
        .find(|d| d.0 == id)
        .map_or(0, |d| d.1)
}
pub fn can_know(s: &Simulation, a: &Actor, view: i8) -> bool {
    if view < 0 || team(a) < 0 || team(a) == view {
        return true;
    }
    let mask = match a {
        Actor::Soldier(s) => s.identity.visible,
        Actor::Vehicle(v) => v.visible,
        Actor::Structure(s) => s.seen,
        Actor::Drone(d) => drone_visibility(s, d.id),
        Actor::Projectile(_) => return true,
    };
    mask & (1 << view) != 0
}

pub fn state(s: &Simulation, a: &Actor, view: i8, content: &Content) -> Vec<u8> {
    let mut out = Vec::with_capacity(32);
    write_state(s, a, view, content, &mut out);
    out
}
fn write_state(s: &Simulation, a: &Actor, view: i8, content: &Content, out: &mut Vec<u8>) {
    out.clear();
    match a {
        Actor::Soldier(s) => {
            position(out, s.motion.position);
            angle(out, s.motion.yaw);
            let v = &s.vitals;
            out.extend_from_slice(&[
                v.life as u8,
                s.posture as u8,
                s.activity,
                s.flags,
                fraction(if v.life == Life::Alive {
                    v.hp / v.max_hp.max(1.)
                } else {
                    v.bleed / v.bleed_max.max(1.)
                }),
            ]);
            out.extend_from_slice(&(s.identity.squad as u16).to_le_bytes());
            let weapon = if s.identity.mounted_weapon.is_empty() {
                &s.identity.weapon
            } else {
                &s.identity.mounted_weapon
            };
            let ammo = content.definitions["weapons"][weapon]["ammo"]
                .as_f64()
                .unwrap_or(9000.);
            let cover = if s.cover.at_cover
                && s.cover.height > 0.
                && s.emplacement.structure == 0
                && !s.orders.pending_path
                && s.motion.path_index >= s.motion.path.len()
            {
                (s.cover.height / 0.04).round().clamp(1., 63.) as u8
                    | ((if s.weapon.blind { 2 } else { 1 }) << 6)
            } else {
                0
            };
            out.extend_from_slice(&[
                s.identity.visible,
                v.suppression as u8,
                if ammo >= 9000. {
                    255
                } else {
                    fraction(f64::from(s.weapon.magazine + s.weapon.reserve) / ammo.max(1.))
                },
                s.identity.team as u8,
                s.doing,
            ]);
            out.extend_from_slice(&(s.doing_entity as u32).to_le_bytes());
            out.push(cover);
        }
        Actor::Vehicle(v) => {
            position(out, v.position);
            angle(out, v.yaw);
            angle(out, v.turret_yaw);
            out.extend_from_slice(&[
                fraction(v.hp / v.max_hp.max(1.)),
                v.flags,
                v.visible,
                v.team as u8,
            ]);
            out.extend_from_slice(&v.sling_cargo.to_le_bytes());
            angle(out, v.flight_pitch);
            angle(out, v.flight_roll);
        }
        Actor::Structure(s) => {
            let private = view >= 0 && s.team >= 0 && view != s.team;
            out.extend_from_slice(
                &(((s.hp / s.max_hp.max(1.)).clamp(0., 1.) * 65535.) as u16).to_le_bytes(),
            );
            out.extend_from_slice(&[
                fraction(s.progress),
                s.team as u8,
                s.capture_progress.clamp(0., 100.) as u8,
                s.capture_team as u8,
            ]);
            out.extend_from_slice(
                &(if private {
                    0
                } else {
                    s.supply.clamp(0., 65535.) as u16
                })
                .to_le_bytes(),
            );
            out.extend_from_slice(&[
                u8::from(s.built)
                    | (u8::from(s.wrecked) << 1)
                    | (u8::from(s.production_status == "cap") << 2)
                    | (u8::from(s.door_closed) << 3)
                    | (u8::from(s.manned) << 5),
                s.visible,
                s.seen,
                if private {
                    0
                } else {
                    fraction(s.queue_fraction)
                },
                if private {
                    0
                } else {
                    s.inside.len().min(255) as u8
                },
                fraction(s.burn),
            ]);
            if s.kind == "town" {
                out.push(fraction(s.intact));
            }
        }
        Actor::Projectile(p) => {
            position(out, p.motion.position());
            match &p.motion {
                Motion::Ballistic(f) => {
                    out.extend_from_slice(&[(f.smoke_radius * 20.) as u8, f.flying.into()])
                }
                _ => out.extend_from_slice(&[0, 1]),
            }
        }
        Actor::Drone(d) => {
            position(out, d.flight.position);
            angle(out, f64::from(d.flight.yaw));
            out.extend_from_slice(&[
                u8::from(d.flight.diving)
                    | (u8::from(d.flight.phase == sim::drone::Phase::Uncontrolled) << 1),
                drone_visibility(s, d.id),
            ]);
        }
    }
}

pub fn props(s: &Simulation, a: &Actor, view: i8) -> Value {
    match a {
        Actor::Soldier(s) => {
            json!({"utype":s.identity.unit,"team":s.identity.team,"owner":s.identity.owner,
            "pos":point(s.motion.position),"yaw":s.motion.yaw,"name":s.identity.name,"squad":s.identity.squad,
            "max_hp":s.vitals.max_hp,"life":s.vitals.life as u8,"posture":s.posture as u8})
        }
        Actor::Vehicle(v) => {
            json!({"vkind":v.kind,"team":v.team,"owner":v.owner,"pos":point(v.position),"yaw":v.yaw,"max_hp":v.max_hp})
        }
        Actor::Structure(b) => {
            let private = view >= 0 && b.team >= 0 && view != b.team;
            let mut p = json!({"skind":b.kind,"team":b.team,"owner":b.owner,"pos":point(b.position),"yaw":b.yaw,
                "size":point(b.size),"variant":b.variant,"built":b.built,"progress":b.progress,"hp":b.hp,"max_hp":b.max_hp,
                "sname":b.name,"seen":b.seen,"vk":b.wreck_kind,"tilt":b.tilt,"door":b.door_closed,"burnt":b.burnt});
            if !private {
                p["supply"] = json!(b.supply);
                p["queue"] = json!(b.queue.iter().map(|q| &q.item).collect::<Vec<_>>());
            }
            if b.kind == "town" {
                p["zc"] = point(b.zone_center.unwrap_or(b.position));
                p["zr"] = json!(b.zone_radius);
            }
            p
        }
        Actor::Drone(d) => {
            json!({"team":d.team,"pos":point(d.flight.position),"operator":d.operator,"target":d.target})
        }
        Actor::Projectile(p) => {
            let mut v = json!({"team":p.team,"pos":point(p.motion.position()),"thrower":p.thrower,"tgt":p.target_id});
            match &p.motion {
                Motion::Ballistic(f) => {
                    use sim::projectile::Kind::*;
                    v["ptype"] = json!(match f.kind {
                        Frag => "frag",
                        Smoke => "smoke",
                        Rocket => "rocket",
                        Recoilless => "recoilless",
                        Mortar => "mortar",
                        MortarSmoke => "mortar_smoke",
                        Grad => "grad",
                        Arty => "arty",
                        Ac105 => "ac105",
                        Ac40 => "ac40",
                        Ac25 => "ac25",
                        Bomb => "bomb",
                    });
                    v["vel"] = point(f.velocity);
                    v["origin"] = point(f.origin);
                    v["target"] = point(f.target);
                    v["fuse"] = json!(f.fuse);
                    v["T"] = json!(f.shell_duration);
                }
                Motion::Guided(f) => {
                    v["ptype"] = json!(if f.kind == sim::guided::Kind::AntiTank {
                        "atgm"
                    } else {
                        "sam"
                    });
                    v["vel"] = point(f.velocity);
                    v["target"] = point(f.target);
                }
                Motion::Support(f) => {
                    v["ptype"] = json!(match f.kind {
                        sim::support::Kind::Jet => "jet",
                        sim::support::Kind::GunRun => "a10",
                        sim::support::Kind::Orbit => "ac130",
                    });
                    v["vel"] = point(f.velocity);
                    v["target"] = point(f.target);
                    v["fuse"] = json!(f.fuse);
                    v["guns"] = json!(match f.gunset {
                        sim::support::Gunset::Ac130 => "ac130",
                        sim::support::Gunset::Blackfish => "blackfish",
                        sim::support::Gunset::Xian => "xian",
                        sim::support::Gunset::Greyhawk => "greyhawk",
                        sim::support::Gunset::Unarmed => "none",
                    });
                    v["sight"] = json!(f.sight);
                    v["stay"] = json!(f.stay);
                    v["mk"] = json!(s.aircraft_models.get(&p.id).map_or("", String::as_str));
                }
            }
            v
        }
    }
}

pub struct Spawn {
    pub id: u32,
    pub kind: u8,
    pub props: Value,
    pub state: Vec<u8>,
}
fn property_stamp(a: &Actor, view: i8) -> u64 {
    let mut h = DefaultHasher::new();
    match a {
        Actor::Soldier(s) => {
            (
                &s.identity.unit,
                s.identity.team,
                s.identity.owner,
                &s.identity.name,
                s.identity.squad,
                s.vitals.max_hp.to_bits(),
            )
                .hash(&mut h);
        }
        Actor::Vehicle(v) => (&v.kind, v.team, v.owner, v.max_hp.to_bits()).hash(&mut h),
        Actor::Drone(d) => (d.team, d.operator, d.target).hash(&mut h),
        Actor::Projectile(p) => (p.team, p.thrower, p.target_id).hash(&mut h),
        Actor::Structure(s) => {
            (
                &s.kind,
                s.team,
                s.owner,
                s.variant,
                &s.name,
                s.max_hp.to_bits(),
                &s.wreck_kind,
                s.burnt,
                s.zone_radius.to_bits(),
            )
                .hash(&mut h);
            for p in [s.position, s.size, s.zone_center.unwrap_or(s.position)] {
                p.to_array().map(f32::to_bits).hash(&mut h);
            }
            s.yaw.to_bits().hash(&mut h);
            s.tilt.map(f32::to_bits).hash(&mut h);
            if view < 0 || s.team < 0 || s.team == view {
                for q in &s.queue {
                    q.item.hash(&mut h);
                }
            }
        }
    }
    h.finish()
}
#[derive(Default)]
pub struct Update {
    pub births: Vec<Spawn>,
    pub properties: Vec<(u32, Value)>,
    pub despawns: Vec<u32>,
    pub snapshots: Vec<Vec<u8>>,
}
struct Known {
    stamp: u64,
    revision: Option<u64>,
    props: Value,
    state: Vec<u8>,
    refresh: u64,
}
pub struct View {
    team: i8,
    known: BTreeMap<u32, Known>,
    sequence: u64,
}
impl View {
    pub fn new(team: i8) -> Result<Self, &'static str> {
        if !(-1..=1).contains(&team) {
            return Err("invalid observation team");
        }
        Ok(Self {
            team,
            known: BTreeMap::new(),
            sequence: 0,
        })
    }
    pub fn update(&mut self, simulation: &Simulation, content: &Content) -> Update {
        let mut out = Update::default();
        self.sequence += 1;
        let mut packet = (simulation.state.field.now as f32).to_le_bytes().to_vec();
        let mut bytes = Vec::with_capacity(32);
        for a in simulation.state.field.actors.iter() {
            let id = a.identity().id;
            let visible = can_know(simulation, a, self.team);
            let revision = simulation.state.field.actors.structure_revision(id);
            if visible
                && revision.is_some()
                && self.known.get(&id).is_some_and(|known| {
                    known.revision == revision && self.sequence < known.refresh
                })
            {
                continue;
            }
            if !visible && !self.known.contains_key(&id) {
                continue;
            }
            bytes.clear();
            if visible {
                write_state(simulation, a, self.team, content, &mut bytes);
            }
            let stamp = if visible {
                property_stamp(a, self.team)
            } else {
                0
            };
            if visible && !self.known.contains_key(&id) {
                let p = props(simulation, a, self.team);
                out.births.push(Spawn {
                    id,
                    kind: a.identity().kind as u8,
                    props: p.clone(),
                    state: bytes.clone(),
                });
                self.known.insert(
                    id,
                    Known {
                        stamp,
                        revision,
                        props: p,
                        state: vec![],
                        refresh: 0,
                    },
                );
            }
            let known = self.known.get_mut(&id).unwrap();
            known.revision = if visible { revision } else { None };
            if visible && known.stamp != stamp {
                known.stamp = stamp;
                // Position and per-tick fields travel in the compact state, not reliable property updates.
                let mut p = props(simulation, a, self.team);
                if matches!(
                    a,
                    Actor::Soldier(_) | Actor::Vehicle(_) | Actor::Drone(_) | Actor::Projectile(_)
                ) {
                    for key in ["pos", "yaw", "life", "posture", "vel", "fuse"] {
                        p.as_object_mut().unwrap().remove(key);
                    }
                    if matches!(a, Actor::Projectile(_)) {
                        p.as_object_mut().unwrap().remove("target");
                    }
                } else {
                    for key in ["hp", "progress", "built", "seen", "supply", "door"] {
                        p.as_object_mut().unwrap().remove(key);
                    }
                    if !p.as_object().unwrap().contains_key("queue") {
                        p["queue"] = json!([]);
                    }
                }
                let changed: serde_json::Map<_, _> = p
                    .as_object()
                    .unwrap()
                    .iter()
                    .filter(|(k, v)| known.props.get(*k) != Some(*v))
                    .map(|(k, v)| (k.clone(), v.clone()))
                    .collect();
                if !changed.is_empty() {
                    for (k, v) in &changed {
                        known.props[k] = v.clone();
                    }
                    out.properties.push((id, Value::Object(changed)));
                }
            }
            let moving_kind = matches!(
                a,
                Actor::Soldier(_) | Actor::Vehicle(_) | Actor::Projectile(_) | Actor::Drone(_)
            );
            if known.state == bytes && (!visible || !moving_kind) && self.sequence < known.refresh {
                continue;
            }
            if packet.len() + 5 + bytes.len() > 1100 {
                out.snapshots.push(packet);
                packet = (simulation.state.field.now as f32).to_le_bytes().to_vec();
            }
            packet.extend_from_slice(&id.to_le_bytes());
            packet.push(bytes.len() as u8);
            packet.extend_from_slice(&bytes);
            std::mem::swap(&mut known.state, &mut bytes);
            known.refresh = self.sequence + 45 + u64::from(id % 15);
        }
        if packet.len() > 4 {
            out.snapshots.push(packet);
        }
        self.known.retain(|id, _| {
            if simulation.state.field.actors.get(*id).is_some() {
                true
            } else {
                out.despawns.push(*id);
                false
            }
        });
        out
    }
}
