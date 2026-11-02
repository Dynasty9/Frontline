//! The placement preview and command admission use the same occupied ground and supply routes.
use crate::actors::{Actor, Actors};
use crate::cover::{rotation, transform};
use crate::entities::Kind;
use crate::structure::Structure;
use crate::structure_birth::BuildingProfile;
use crate::supply_network::SupplyNetwork;
use crate::terrain::{BASE, SHALLOW, WATER};
use crate::vector::{normalized, Vector3};
use crate::water::Water;
use crate::world_geometry::WorldGeometry;
use glam::Vec2;

pub struct Definition<'a> {
    pub key: &'a str,
    pub name: &'a str,
    pub teams: u8,
    pub cost: i32,
    pub body: BuildingProfile,
}
pub struct Distances {
    pub build: f64,
    pub fob_spacing: f64,
    pub fob_expand: f64,
}
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Spot {
    pub position: Vector3,
    pub yaw: f64,
    pub variant: i32,
}
fn flat(p: Vector3) -> Vector3 {
    Vector3::new(p.x, 0., p.z)
}
fn direction(yaw: f64) -> Vector3 {
    Vector3::new(-libm::sin(yaw) as f32, 0., -libm::cos(yaw) as f32)
}
fn segment_distance(p: Vector3, a: Vector3, b: Vector3) -> f64 {
    let ab = b - a;
    let l2 = f64::from(ab.length_squared());
    if l2 < 0.0001 {
        return f64::from(p.distance(a));
    }
    let t = (f64::from((p - a).dot(ab)) / l2).clamp(0., 1.);
    f64::from(p.distance(a + ab * t as f32))
}
impl Definition<'_> {
    pub fn valid(&self) -> bool {
        !self.key.is_empty()
            && self.key.len() <= 128
            && !self.key.contains('\0')
            && !self.name.is_empty()
            && self.name.len() <= 4096
            && !self.name.contains('\0')
            && self.teams <= 3
            && (0..=1_000_000).contains(&self.cost)
            && self.body.hp.is_finite()
            && (0.0..=1e12).contains(&self.body.hp)
            && self
                .body
                .size
                .iter()
                .all(|v| v.is_finite() && (0.0..=8192.).contains(v))
    }
}
impl WorldGeometry {
    pub fn trench_mount_spot(
        &self,
        actors: &Actors,
        position: Vector3,
        yaw: f64,
    ) -> Result<Option<Spot>, &'static str> {
        if !crate::squad_movement::point(position) || !yaw.is_finite() || yaw.abs() > 1e12 {
            return Err("invalid trench placement");
        }
        let mut best = None;
        let mut distance = 1.7;
        for id in actors.structures_near(&self.structures, position, 8., false)? {
            let st = actors.structure(id).unwrap();
            if st.kind != "trench" {
                continue;
            }
            let d = transform(rotation(st.yaw), Vector3::new(st.size.x * 0.5, 0., 0.));
            let a = flat(st.position - d);
            let b = flat(st.position + d);
            let ab = b - a;
            let length = f64::from(ab.length());
            if length < 2. {
                continue;
            }
            let t = f64::from((flat(position) - a).dot(ab)) / (length * length);
            let (lo, hi) = (1.2 / length, 1. - 1.2 / length);
            let t = if t < lo {
                lo
            } else if t > hi {
                hi
            } else {
                t
            };
            let q = a + ab * t as f32;
            let near = f64::from(flat(position - q).length());
            if near < distance {
                distance = near;
                let mut n = normalized(Vector3::new(-ab.z, 0., ab.x));
                if n.dot(direction(yaw)) < 0. {
                    n = -n;
                }
                best = Some(Spot {
                    position: q,
                    yaw: libm::atan2(-f64::from(n.x), -f64::from(n.z)),
                    variant: 1,
                });
            }
        }
        Ok(best)
    }
    pub fn placement_error(
        &self,
        actors: &Actors,
        network: &SupplyNetwork,
        water: &Water,
        team: i8,
        p: Option<&Definition<'_>>,
        at: Vector3,
        yaw: f64,
        dist: &Distances,
        display: &dyn Fn(&Structure) -> String,
    ) -> Result<String, &'static str> {
        if !crate::squad_movement::point(at)
            || !yaw.is_finite()
            || yaw.abs() > 1e12
            || !(-1..=1).contains(&team)
            || !water.valid()
            || water.side != self.terrain.n
            || !network.valid()
            || [dist.build, dist.fob_spacing, dist.fob_expand]
                .into_iter()
                .any(|v| !v.is_finite() || !(0.0..=8192.).contains(&v))
            || p.is_some_and(|p| !p.valid())
        {
            return Err("invalid building placement");
        }
        let Some(p) = p else {
            return Ok("Unknown building.".into());
        };
        if team < 0 || p.teams & (1 << team) == 0 {
            return Ok("Your side can't build that.".into());
        }
        if f64::from(at.x).abs() >= self.terrain.half() - 8.
            || f64::from(at.z).abs() >= self.terrain.half() - 8.
        {
            return Ok("Too close to the map edge.".into());
        }
        let mut half = Vec2::from_array(p.body.size) * 0.5;
        if p.key == "trench" {
            half.x = (f64::from(half.x) + 0.72) as f32;
        }
        if !self.terrain.landform.fits(at, half, yaw, 0.35) {
            return Ok("The ground is too steep or uneven to build here.".into());
        }
        let wet = |q| {
            matches!(
                self.terrain.layers[BASE][self.terrain.index(q)],
                WATER | SHALLOW
            )
        };
        let deck = |q| !self.deck.is_empty() && self.deck[self.terrain.index(q)] == 1;
        if !water.is_empty() {
            let b = rotation(yaw);
            for offset in [
                Vector3::ZERO,
                Vector3::new(half.x, 0., half.y),
                Vector3::new(-half.x, 0., half.y),
                Vector3::new(half.x, 0., -half.y),
                Vector3::new(-half.x, 0., -half.y),
            ] {
                let q = at + transform(b, offset);
                if wet(q) || deck(q) {
                    return Ok(if p.key == "dock" {
                        "A dock stands on the shore, its jetty out over the water."
                    } else {
                        "Can't build in the water."
                    }
                    .into());
                }
            }
            if p.key == "dock" {
                let mut wet_near = false;
                let mut deep = false;
                let f = direction(yaw);
                for k in ((half.y as i32 + 1)..(half.y as i32 + 28)).step_by(3) {
                    let q = at + f * k as f32;
                    if f64::from(k) <= f64::from(half.y) + 12. && wet(q) {
                        wet_near = true;
                    }
                    if self.terrain.layers[BASE][self.terrain.index(q)] == WATER {
                        deep = true;
                        break;
                    }
                }
                if !(wet_near && deep) {
                    return Ok("A dock must face open water: put it on the shore with its front to the sea or the river.".into());
                }
                if team == 0 && at.z < -40. || team == 1 && at.z > 40. {
                    return Ok("Build docks on your own half of the map.".into());
                }
            }
        } else if p.key == "dock" {
            return Ok("There's no water on this map.".into());
        }
        for id in actors.structures_near(&self.structures, at, 16., false)? {
            let st = actors.structure(id).unwrap();
            if st.kind == "floor"
                || st.kind == "trench" && matches!(p.key, "trench" | "mg_nest" | "hmg_nest")
            {
                continue;
            }
            if p.key == "camo_net" || st.kind == "camo_net" {
                if p.key == "camo_net"
                    && st.kind == "camo_net"
                    && flat(st.position - at).length() < 3.
                {
                    return Ok("There's a net here already.".into());
                }
                continue;
            }
            if crate::vehicle_movement_world::overlaps(at, half, yaw, st, 0.12) {
                return Ok(format!("Blocked by {}.", display(st)));
            }
        }
        if !matches!(
            p.key,
            "mines" | "wire" | "trench" | "sandbags" | "fob" | "camo_net"
        ) {
            for road in &network.roads[team as usize] {
                for pair in road.windows(2) {
                    if segment_distance(flat(at), flat(pair[0]), flat(pair[1]))
                        < f64::from(half.length()) + 3.
                    {
                        return Ok("That would block your own supply road.".into());
                    }
                }
            }
        }
        if p.key == "dock" {
            return Ok(String::new());
        }
        if p.key == "fob" {
            let mut near = false;
            for st in actors.iter_kind(Kind::Structure).filter_map(|a| match a {
                Actor::Structure(st) if matches!(st.kind.as_str(), "fob" | "depot" | "town") => {
                    Some(st)
                }
                _ => None,
            }) {
                let d = f64::from(flat(st.position - at).length());
                if st.kind == "fob" && d < dist.fob_spacing {
                    return Ok("Too close to another FOB.".into());
                }
                if st.team == team && st.built && d < dist.fob_expand {
                    near = true;
                }
            }
            if !near {
                return Ok(format!(
                    "A new FOB must be within {} m of one of yours, or of a town you hold.",
                    dist.fob_expand as i64
                ));
            }
        } else if !crate::economy::fobs(actors, team, false)
            .any(|st| f64::from(flat(st.position - at).length()) < dist.build)
        {
            return Ok(format!(
                "Must be within {} m of a working FOB.",
                dist.build as i64
            ));
        }
        Ok(String::new())
    }
}
