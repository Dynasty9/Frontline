//! Fire updates shared actors and geometry before the next victim or burning structure acts.
use crate::actors::{Actor, Actors};
use crate::battle_stats::BattleStats;
use crate::cover::{rotation, transform};
use crate::deferred_effects::DeferredEffects;
use crate::fire_escape::Escape;
use crate::infantry::Infantry;
use crate::infantry_effects::{Damage as Hit, InfantryHit};
use crate::infantry_vitals::{DamageResult, Life};
use crate::random::SimulationRandom;
use crate::spatial::{SpatialIndex, UNIT_CELL};
use crate::squad::Squad;
use crate::state_codec::{Reader, Writer};
use crate::structure::Structure;
use crate::structure_damage::{Damage, Event as Destruction};
use crate::terrain::{BASE, SOLID, TRENCH, WOODS};
use crate::vector::{normalized, Vector3};
use crate::visibility::{Smoke, Visibility};
use crate::world_geometry::WorldGeometry;
use glam::Vec2;

const WIND: Vector3 = Vector3::new(0.92, 0.0, 0.38);
const LIMIT: usize = 100_000;
const TICK: f64 = 0.25;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum Remains {
    Snag,
    Ash,
    Stands,
    Shell,
}
#[derive(Clone, Copy)]
struct Fuel {
    catches: f64,
    seconds: f64,
    remains: Remains,
    smoke: f64,
}
fn fuel(kind: &str) -> Option<Fuel> {
    use Remains::*;
    let (catches, seconds, remains, smoke) = match kind {
        "tree" => (0.35, 80.0, Snag, 2.5),
        "hedge" => (0.6, 45.0, Ash, 2.0),
        "crates" => (0.75, 40.0, Ash, 1.8),
        "watchtower" => (0.55, 60.0, Ash, 2.5),
        "medic_tent" => (0.85, 35.0, Ash, 2.5),
        "barracks" => (0.22, 70.0, Stands, 3.5),
        "log_bunker" => (0.12, 60.0, Stands, 2.5),
        "roof" => (0.3, 75.0, Ash, 4.0),
        "car" => (0.45, 55.0, Shell, 3.0),
        "wreck" => (0.0, 40.0, Shell, 3.5),
        "camo_net" => (0.9, 16.0, Ash, 1.5),
        "barricade" => (0.3, 90.0, Stands, 4.0),
        _ => return None,
    };
    Some(Fuel {
        catches,
        seconds,
        remains,
        smoke,
    })
}

#[derive(Clone, Copy, Debug)]
pub struct ManProfile {
    pub bearer: bool,
    pub ammunition: Option<i32>,
    pub value: f64,
}
#[derive(Clone, Copy, Debug)]
pub struct BuildingProfile {
    pub player: bool,
    pub value: f64,
}

pub struct Context<'a> {
    pub actors: &'a mut Actors,
    pub geometry: &'a mut WorldGeometry,
    pub units: &'a SpatialIndex,
    pub squads: &'a mut [Squad],
    pub battle: &'a mut BattleStats,
    pub deferred: &'a mut DeferredEffects,
    pub visibility: &'a mut Visibility,
    pub rng: &'a mut SimulationRandom,
    pub now: f64,
    pub town: [f32; 4],
    /// These read immutable game definitions; no engine or rendering state participates.
    pub man: &'a dyn Fn(&Infantry, &[Squad]) -> ManProfile,
    pub building: &'a dyn Fn(&Structure) -> BuildingProfile,
    pub role: &'a dyn Fn(&Infantry) -> String,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Burning {
    pub structure: u32,
    pub position: Vector3,
    pub radius: f64,
}
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Patch {
    pub position: Vector3,
    pub radius: f64,
    pub life: f64,
    pub generation: u32,
}
#[derive(Clone, Debug, PartialEq)]
pub enum Event {
    Ignited {
        structure: u32,
        kind: String,
        alert: bool,
    },
    Grass(Patch),
    GrassLit,
    GrassSpread,
    BurnedDown {
        structure: u32,
        damage: Damage,
    },
    Charred {
        structure: u32,
        variant: i32,
    },
    Scorched {
        soldier: u32,
        hit: InfantryHit,
        escape: Option<Escape>,
    },
}

#[derive(Clone, Debug, PartialEq)]
pub struct Fires {
    side: usize,
    burning: Vec<Burning>,
    patches: Vec<Patch>,
    hot: Vec<u8>,
    smokes: Vec<Smoke>,
    pub wet: bool,
    elapsed: f64,
    beat: f64,
}
fn point(p: Vector3) -> bool {
    p.is_finite() && p.abs().max_element() <= 1_000_000.0
}
fn flat(p: Vector3) -> Vector3 {
    Vector3::new(p.x, 0.0, p.z)
}
#[derive(Clone, Copy)]
struct Footprint {
    position: Vector3,
    yaw: f64,
    half: [f32; 2],
}
impl From<&Structure> for Footprint {
    fn from(st: &Structure) -> Self {
        Self {
            position: st.position,
            yaw: st.yaw,
            half: st.footprint,
        }
    }
}
impl Footprint {
    fn distance(self, p: Vector3) -> f64 {
        let local = transform(rotation(-self.yaw), p - self.position);
        let x = (f64::from(local.x).abs() - f64::from(self.half[0])).max(0.0);
        let z = (f64::from(local.z).abs() - f64::from(self.half[1])).max(0.0);
        libm::sqrt(x * x + z * z)
    }
}

impl Fires {
    pub fn new(side: usize, wet: bool) -> Result<Self, &'static str> {
        if !(2..=3072).contains(&side) {
            return Err("invalid fire map size");
        }
        Ok(Self {
            side,
            burning: vec![],
            patches: vec![],
            hot: vec![0; (side.div_ceil(4) + 1).pow(2)],
            smokes: vec![],
            wet,
            elapsed: 0.0,
            beat: 0.0,
        })
    }
    pub fn burning(&self) -> &[Burning] {
        &self.burning
    }
    pub fn patches(&self) -> &[Patch] {
        &self.patches
    }
    pub fn hot(&self) -> &[u8] {
        &self.hot
    }
    pub fn side(&self) -> usize {
        self.side
    }
    pub fn smokes(&self) -> &[Smoke] {
        &self.smokes
    }
    pub fn clocks(&self) -> [f64; 2] {
        [self.elapsed, self.beat]
    }
    fn context(&self, c: &Context<'_>) -> bool {
        self.side == c.geometry.terrain.n
            && self.side == c.geometry.navigation.planner.side()
            && c.units.cell_size() == UNIT_CELL
            && c.now.is_finite()
            && (0.0..=1e12 - 100.0).contains(&c.now)
            && c.town
                .iter()
                .all(|v| v.is_finite() && v.abs() <= 1_000_000.0)
            && c.town[2] >= 0.0
            && c.town[3] >= 0.0
            && (c.geometry.deck.is_empty() || c.geometry.deck.len() == self.side * self.side)
    }
    pub fn hot_at(&self, p: Vector3) -> bool {
        if !point(p) {
            return false;
        }
        let half = self.side as f64 * 0.5;
        let n = self.side.div_ceil(4) as i32 + 1;
        let x = ((f64::from(p.x) + half) / 4.0) as i32;
        let z = ((f64::from(p.z) + half) / 4.0) as i32;
        x >= 0 && z >= 0 && x < n && z < n && self.hot[(z * n + x) as usize] > 0
    }
    fn stamp(
        &mut self,
        p: Vector3,
        r: f64,
        delta: i8,
        g: &mut WorldGeometry,
    ) -> Result<(), &'static str> {
        g.navigation
            .stamp_heat(p, r - 0.5, delta, &g.terrain, &g.deck)?;
        let half = self.side as f64 * 0.5;
        let n = self.side.div_ceil(4) as i32 + 1;
        let x0 = (((f64::from(p.x) - r + half) / 4.0) as i32).max(0);
        let x1 = (((f64::from(p.x) + r + half) / 4.0) as i32).min(n - 1);
        let z0 = (((f64::from(p.z) - r + half) / 4.0) as i32).max(0);
        let z1 = (((f64::from(p.z) + r + half) / 4.0) as i32).min(n - 1);
        for z in z0..=z1 {
            for x in x0..=x1 {
                let cell = &mut self.hot[(z * n + x) as usize];
                *cell = (i16::from(*cell) + i16::from(delta)).clamp(0, 255) as u8;
            }
        }
        Ok(())
    }
    pub fn ignite(
        &mut self,
        id: u32,
        heat: f64,
        c: &mut Context<'_>,
        out: &mut Vec<Event>,
    ) -> Result<bool, &'static str> {
        if !self.context(c) || !heat.is_finite() {
            return Err("invalid fire ignition");
        }
        let Some(st) = c.actors.structure(id) else {
            return Ok(false);
        };
        if st.gone || st.burn > 0.0 || st.burnt || st.fire_kind().is_empty() {
            return Ok(false);
        }
        if self.burning.len() + self.patches.len() >= LIMIT || st.radius > 8189.5 {
            return Err("fire ignition exceeds limit");
        }
        let kind = st.fire_kind().to_owned();
        let spec = fuel(&kind).ok_or("unknown fire fuel")?;
        let Some(Actor::Structure(st)) = c.actors.get_mut(id) else {
            unreachable!()
        };
        st.fire_kind = kind;
        st.fuel_max = spec.seconds * f64::from(c.rng.randf_range(0.8, 1.2));
        st.fuel = st.fuel_max;
        st.burn = heat.clamp(0.1, 1.0);
        self.track_ignition(id, c, out)?;
        Ok(true)
    }
    /// Structure damage can already have consumed the car's ignition draw and fuel draw.
    pub fn track_ignition(
        &mut self,
        id: u32,
        c: &mut Context<'_>,
        out: &mut Vec<Event>,
    ) -> Result<(), &'static str> {
        let st = c.actors.structure(id).ok_or("missing burning structure")?;
        if !self.context(c)
            || st.burn <= 0.0
            || fuel(&st.fire_kind).is_none()
            || st.radius > 8189.5
            || self.burning.len() + self.patches.len() >= LIMIT
        {
            return Err("invalid retained ignition");
        }
        let burning = Burning {
            structure: id,
            position: st.position,
            radius: st.radius + 2.5,
        };
        let event = Event::Ignited {
            structure: id,
            kind: st.fire_kind.clone(),
            alert: st.team >= 0 && (c.building)(st).player,
        };
        self.stamp(burning.position, burning.radius, 1, c.geometry)?;
        self.burning.push(burning);
        out.push(event);
        Ok(())
    }
    pub fn start_patch(
        &mut self,
        p: Vector3,
        r: f64,
        life: f64,
        generation: u32,
        g: &mut WorldGeometry,
        out: &mut Vec<Event>,
    ) -> Result<(), &'static str> {
        if self.side != g.terrain.n
            || !point(p)
            || !r.is_finite()
            || !(0.0..=4096.0).contains(&r)
            || !life.is_finite()
            || !(0.0..=1_000_000.0).contains(&life)
            || generation > 1_000_000
            || self.burning.len() + self.patches.len() >= LIMIT
        {
            return Err("invalid grass fire");
        }
        let patch = Patch {
            position: flat(p),
            radius: r,
            life,
            generation,
        };
        self.stamp(patch.position, r + 1.0, 1, g)?;
        self.patches.push(patch);
        out.push(Event::Grass(patch));
        Ok(())
    }
    fn grass_at(&self, p: Vector3, c: &Context<'_>) -> bool {
        if !self.in_map(p, 2.0) {
            return false;
        }
        let start = Vec2::new(c.town[0], c.town[1]);
        let end = start + Vec2::new(c.town[2], c.town[3]);
        if p.x >= start.x && p.z >= start.y && p.x < end.x && p.z < end.y {
            return false;
        }
        let terrain = &c.geometry.terrain;
        let i = terrain.index(p);
        terrain.layers[TRENCH][i] == 0
            && terrain.layers[SOLID][i] == 0
            && matches!(terrain.layers[BASE][i], 0 | 2)
    }
    fn in_map(&self, p: Vector3, margin: f64) -> bool {
        f64::from(p.x).abs() < self.side as f64 * 0.5 - margin
            && f64::from(p.z).abs() < self.side as f64 * 0.5 - margin
    }
    pub fn blast(
        &mut self,
        p: Vector3,
        size: f64,
        radius: f64,
        c: &mut Context<'_>,
    ) -> Result<Vec<Event>, &'static str> {
        if !self.context(c)
            || !point(p)
            || !size.is_finite()
            || !(0.0..=1024.0).contains(&size)
            || !radius.is_finite()
            || !(0.000001..=8192.0).contains(&radius)
        {
            return Err("invalid fire blast");
        }
        let mut out = vec![];
        let mut strength = ((size - 0.6) / 1.6).clamp(0.0, 1.0);
        if strength <= 0.0 {
            return Ok(out);
        }
        if self.wet {
            strength *= 0.3;
        }
        for id in c
            .actors
            .structures_near(&c.geometry.structures, p, radius + 3.0, false)?
        {
            let st = c.actors.structure(id).unwrap();
            if st.gone || st.burn > 0.0 || st.burnt {
                continue;
            }
            let Some(spec) = fuel(st.fire_kind()) else {
                continue;
            };
            let d = Footprint::from(st).distance(p);
            if d > radius {
                continue;
            }
            let chance = spec.catches * (0.15 + 0.85 * strength) * (1.0 - d / radius);
            if f64::from(c.rng.randf()) < chance {
                self.ignite(id, 0.2 + 0.4 * strength, c, &mut out)?;
            }
        }
        if f64::from(p.y) < 1.6 && !self.wet && size >= 1.15 {
            let woods = c.geometry.terrain.layers[WOODS][c.geometry.terrain.index(p)] > 0;
            if f64::from(c.rng.randf()) < 0.28 * strength * if woods { 1.6 } else { 1.0 }
                && self.grass_at(p, c)
            {
                let r = f64::from(c.rng.randf_range(1.6, 2.4)) + size * 0.5;
                let life = f64::from(c.rng.randf_range(14.0, 24.0));
                self.start_patch(p, r, life, 0, c.geometry, &mut out)?;
                out.push(Event::GrassLit);
            }
        }
        Ok(out)
    }
    pub fn tick(&mut self, dt: f64, c: &mut Context<'_>) -> Result<Vec<Event>, &'static str> {
        if !self.context(c) || !dt.is_finite() || !(0.0..=10.0).contains(&dt) {
            return Err("invalid fire tick");
        }
        let mut out = vec![];
        self.elapsed += dt;
        if self.elapsed < TICK {
            return Ok(out);
        }
        let step = self.elapsed;
        self.elapsed = 0.0;
        self.beat -= step;
        let beat = self.beat <= 0.0;
        if beat {
            self.beat = 1.0;
        }
        for i in (0..self.burning.len()).rev() {
            let b = self.burning[i];
            if c.actors.structure(b.structure).is_some() {
                self.burn(b.structure, step, beat, c, &mut out)?;
            }
            if c.actors
                .structure(b.structure)
                .is_none_or(|st| st.gone || st.burn <= 0.0)
            {
                self.burning.remove(i);
                self.stamp(b.position, b.radius, -1, c.geometry)?;
            }
        }
        for i in (0..self.patches.len()).rev() {
            self.patches[i].life -= step;
            let patch = self.patches[i];
            if patch.life <= 0.0 {
                self.patches.remove(i);
                self.stamp(patch.position, patch.radius + 1.0, -1, c.geometry)?;
            } else if beat {
                self.patch_beat(patch, c, &mut out)?;
            }
        }
        self.smokes.clear();
        for b in &self.burning {
            let Some(st) = c.actors.structure(b.structure) else {
                continue;
            };
            let pall = fuel(&st.fire_kind).ok_or("unknown burning fuel")?.smoke * st.burn;
            if st.burn > 0.45 && pall > 1.2 {
                self.smokes.push(Smoke {
                    center: st.position + WIND * pall as f32 * 1.3 + Vector3::new(0.0, 1.4, 0.0),
                    radius: pall,
                });
            }
        }
        for p in &self.patches {
            let r = p.radius * 0.9 * (p.life / 4.0).clamp(0.3, 1.0);
            self.smokes.push(Smoke {
                center: p.position + WIND * r as f32 + Vector3::new(0.0, 1.2, 0.0),
                radius: r,
            });
        }
        if !c.visibility.set_fires(&self.smokes) {
            return Err("fire smoke exceeds limit");
        }
        Ok(out)
    }
    fn burn(
        &mut self,
        id: u32,
        dt: f64,
        beat: bool,
        c: &mut Context<'_>,
        out: &mut Vec<Event>,
    ) -> Result<(), &'static str> {
        let Some(Actor::Structure(st)) = c.actors.get_mut(id) else {
            return Ok(());
        };
        let spec = fuel(&st.fire_kind).ok_or("unknown burning fuel")?;
        let left = st.fuel / st.fuel_max.max(1.0);
        let mut want = if left > 0.3 {
            1.0
        } else {
            0.08 + 0.92 * left / 0.3
        };
        if self.wet {
            want *= 0.6;
        }
        let delta = dt
            * if st.burn < want {
                0.07 + 0.1 * spec.catches
            } else {
                0.3
            };
        let b = if (st.burn - want).abs() <= delta {
            want
        } else {
            st.burn + (want - st.burn).signum() * delta
        };
        st.fuel -= dt * b;
        let eat = dt * b / st.fuel_max.max(1.0);
        match spec.remains {
            Remains::Ash => st.hp -= st.max_hp * eat * 1.05,
            Remains::Stands => st.hp -= st.max_hp * eat * 0.45,
            _ if st.fire_kind != "wreck" => {
                st.hp = st
                    .hp
                    .min(st.max_hp * 0.3)
                    .max(st.hp - st.max_hp * eat * 0.7)
            }
            _ => (),
        }
        if st.hp <= 0.0 {
            st.hp = 0.0;
            st.burn = 0.0;
            let profile = (c.building)(st);
            if profile.player && st.team >= 0 {
                let text = format!("FOB {} wrecked", st.name);
                c.battle
                    .building_destroyed(id, profile.value, c.now, &text, c.actors)?;
            }
            let mut damage = c.actors.destroy_structure(
                id,
                true,
                c.now,
                profile.player,
                &c.geometry.navigation.planner,
                c.deferred,
                c.rng,
                crate::traversal::Ground::new(&c.geometry.terrain, &c.geometry.deck),
            )?;
            for event in &damage.events {
                if let Destruction::Unhidden(id) | Destruction::ReleasedGunner(id) = event {
                    c.geometry.navigation.planner.cancel(u64::from(*id));
                }
            }
            if let Some(removed) = &mut damage.removed {
                c.geometry.retire_structure(removed, c.actors)?;
            }
            out.push(Event::BurnedDown {
                structure: id,
                damage,
            });
            return Ok(());
        }
        if st.fuel <= 0.0 {
            st.burn = 0.0;
            if matches!(spec.remains, Remains::Snag | Remains::Shell) && st.char_out()? {
                out.push(Event::Charred {
                    structure: id,
                    variant: st.variant,
                });
            }
            return Ok(());
        }
        st.burn = b;
        let foot = Footprint::from(st.as_ref());
        let radius = st.radius;
        let roof = st.fire_kind == "roof";
        if beat {
            if b > 0.25 {
                self.scorch(
                    foot.position,
                    b,
                    |p| foot.distance(p),
                    radius + 3.0,
                    1.0 + 1.2 * b,
                    roof,
                    c,
                    out,
                )?;
            }
            if b > 0.45 {
                self.spread(id, b, c, out)?;
            }
        }
        Ok(())
    }
    fn spread(
        &mut self,
        id: u32,
        strength: f64,
        c: &mut Context<'_>,
        out: &mut Vec<Event>,
    ) -> Result<(), &'static str> {
        let st = c.actors.structure(id).ok_or("missing spreading fire")?;
        let p = st.position;
        let radius = st.radius;
        let reach = 2.0
            + 3.0 * strength
            + if matches!(st.fire_kind.as_str(), "roof" | "watchtower" | "tree") {
                1.5
            } else {
                0.0
            };
        for other in
            c.actors
                .structures_near(&c.geometry.structures, p, reach + radius + 6.0, false)?
        {
            let st = c.actors.structure(other).unwrap();
            if other == id || st.gone || st.burn > 0.0 || st.burnt {
                continue;
            }
            let Some(spec) = fuel(st.fire_kind()).filter(|s| s.catches > 0.0) else {
                continue;
            };
            let d = (Footprint::from(st).distance(p) - radius * 0.5).max(0.0);
            if d > reach {
                continue;
            }
            let direction = normalized(flat(st.position - p));
            let mut chance = 0.1
                * spec.catches
                * strength
                * (1.0 - d / reach)
                * (1.0 + 0.9 * f64::from(direction.dot(WIND)));
            if self.wet {
                chance *= 0.25;
            }
            if f64::from(c.rng.randf()) < chance {
                self.ignite(other, 0.15, c, out)?;
            }
        }
        Ok(())
    }
    fn patch_beat(
        &mut self,
        patch: Patch,
        c: &mut Context<'_>,
        out: &mut Vec<Event>,
    ) -> Result<(), &'static str> {
        let p = patch.position;
        let r = patch.radius;
        self.scorch(
            p,
            (patch.life / 4.0).clamp(0.2, 1.0),
            |at| (f64::from(flat(at - p).length()) - r * 0.8).max(0.0),
            r + 2.0,
            1.0,
            false,
            c,
            out,
        )?;
        for id in c
            .actors
            .structures_near(&c.geometry.structures, p, r + 4.0, false)?
        {
            let st = c.actors.structure(id).unwrap();
            if st.gone || st.burn > 0.0 || st.burnt {
                continue;
            }
            let Some(spec) = fuel(st.fire_kind()) else {
                continue;
            };
            if Footprint::from(st).distance(p) < r + 0.8
                && f64::from(c.rng.randf()) < 0.12 * spec.catches
            {
                self.ignite(id, 0.15, c, out)?;
            }
        }
        if patch.generation >= 2
            || self.patches.len() >= 36
            || patch.life < 5.0
            || f64::from(c.rng.randf()) > 0.05
        {
            return Ok(());
        }
        let direction = transform(rotation(f64::from(c.rng.randf_range(-1.1, 1.1))), WIND);
        let next = p + direction * r as f32 * c.rng.randf_range(1.3, 1.8);
        if !self.in_map(next, 6.0) || !self.grass_at(next, c) {
            return Ok(());
        }
        if self
            .patches
            .iter()
            .any(|o| f64::from(flat(o.position - next).length()) < o.radius * 1.1)
        {
            return Ok(());
        }
        let radius = r * f64::from(c.rng.randf_range(0.85, 1.05));
        let life = f64::from(c.rng.randf_range(12.0, 20.0));
        self.start_patch(next, radius, life, patch.generation + 1, c.geometry, out)?;
        out.push(Event::GrassSpread);
        Ok(())
    }
    fn scorch(
        &self,
        p: Vector3,
        strength: f64,
        distance: impl Fn(Vector3) -> f64,
        near: f64,
        radius: f64,
        roof: bool,
        c: &mut Context<'_>,
        out: &mut Vec<Event>,
    ) -> Result<(), &'static str> {
        for id in c.actors.units_near(c.units, p, near + radius, -1)? {
            let Some(s) = c.actors.soldier(id) else {
                continue;
            };
            if matches!(s.vitals.life, Life::Dead | Life::Hidden) {
                continue;
            }
            let d = distance(s.motion.position);
            if d > radius {
                continue;
            }
            let profile = (c.man)(s, c.squads);
            if !profile.value.is_finite() || !(0.0..=1e15).contains(&profile.value) {
                return Err("invalid fire victim value");
            }
            let hit = Hit {
                amount: (3.0 + 12.0 * (1.0 - d / radius)) * strength * if roof { 0.6 } else { 1.0 },
                source: 0,
                direction: normalized(flat(s.motion.position - p)),
                kind: "fire",
                now: c.now,
                ammunition: profile.ammunition,
                bearer: profile.bearer,
                blame: c.battle.blame.as_ref(),
            };
            let hit = c.actors.damage_infantry(id, hit, c.squads, c.rng)?;
            let s = c.actors.soldier(id).unwrap();
            if hit.previous_life == Life::Alive {
                c.battle
                    .damage(hit.credited.as_ref(), hit.damage_credited)?;
            }
            match hit.result {
                DamageResult::Down => c.battle.soldier_down(s, profile.bearer)?,
                DamageResult::Die => {
                    let role = s
                        .identity
                        .hit_by
                        .as_ref()
                        .and_then(|by| c.actors.soldier(by.soldier))
                        .map_or_else(String::new, c.role);
                    c.battle.soldier_died(
                        s,
                        hit.previous_life,
                        profile.bearer,
                        profile.value,
                        c.actors,
                        &role,
                    )?;
                }
                _ => (),
            }
            if hit.released.is_some() {
                c.geometry.navigation.planner.cancel(u64::from(id));
            }
            let s = c.actors.soldier_mut(id).unwrap();
            let escape = s.flee_fire(
                p,
                c.now,
                &c.geometry.navigation.planner,
                c.rng,
                crate::traversal::Ground::new(&c.geometry.terrain, &c.geometry.deck),
            )?;
            if let Some(escape) = escape {
                c.geometry.navigation.submit_infantry(
                    s,
                    escape.route,
                    c.now,
                    c.rng,
                    crate::traversal::Ground::new(&c.geometry.terrain, &c.geometry.deck),
                )?;
            }
            out.push(Event::Scorched {
                soldier: id,
                hit,
                escape,
            });
        }
        Ok(())
    }
    pub fn checkpoint(&self) -> Vec<u8> {
        let mut w = Writer::new(b"FLFR\x01\0\0\0");
        w.u32(self.side as u32);
        w.byte(u8::from(self.wet));
        w.f64(self.elapsed);
        w.f64(self.beat);
        w.bytes(&self.hot);
        w.u32(self.burning.len() as u32);
        for b in &self.burning {
            w.u32(b.structure);
            w.point(b.position);
            w.f64(b.radius);
        }
        w.u32(self.patches.len() as u32);
        for p in &self.patches {
            w.point(p.position);
            w.f64(p.radius);
            w.f64(p.life);
            w.u32(p.generation);
        }
        w.u32(self.smokes.len() as u32);
        for s in &self.smokes {
            w.point(s.center);
            w.f64(s.radius);
        }
        w.0
    }
    pub fn restore(bytes: &[u8]) -> Result<Self, &'static str> {
        let mut r = Reader::new(bytes, b"FLFR\x01\0\0\0")?;
        let side = r.u32()? as usize;
        let wet = r.boolean()?;
        let mut fires = Self::new(side, wet)?;
        fires.elapsed = r.f64()?;
        fires.beat = r.f64()?;
        if !(0.0..TICK).contains(&fires.elapsed) || !(0.0..=1.0).contains(&fires.beat) {
            return Err("invalid fire clocks");
        }
        let hot = r.bytes(fires.hot.len())?;
        if hot.len() != fires.hot.len() {
            return Err("invalid fire heat grid");
        }
        fires.hot.copy_from_slice(hot);
        let count = r.u32()? as usize;
        if count > LIMIT {
            return Err("too many burning structures");
        }
        for _ in 0..count {
            let b = Burning {
                structure: r.u32()?,
                position: r.point()?,
                radius: r.f64()?,
            };
            if b.structure == 0 || !point(b.position) || !(2.5..=8192.0).contains(&b.radius) {
                return Err("invalid burning structure");
            }
            fires.burning.push(b);
        }
        let count = r.u32()? as usize;
        if count > LIMIT - fires.burning.len() {
            return Err("too many grass fires");
        }
        for _ in 0..count {
            let p = Patch {
                position: r.point()?,
                radius: r.f64()?,
                life: r.f64()?,
                generation: r.u32()?,
            };
            if !point(p.position)
                || p.position.y != 0.0
                || !(0.0..=4096.0).contains(&p.radius)
                || !(0.0..=1_000_000.0).contains(&p.life)
                || p.generation > 1_000_000
            {
                return Err("invalid grass fire");
            }
            fires.patches.push(p);
        }
        let count = r.u32()? as usize;
        if count > LIMIT {
            return Err("too many fire smoke volumes");
        }
        for _ in 0..count {
            let smoke = Smoke {
                center: r.point()?,
                radius: r.f64()?,
            };
            if !point(smoke.center) || !(0.0..=4096.0).contains(&smoke.radius) {
                return Err("invalid fire smoke");
            }
            fires.smokes.push(smoke);
        }
        r.finish()?;
        Ok(fires)
    }
}
