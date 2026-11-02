//! A match owns mutable simulation state; scene nodes and socket connections own none of it.
use crate::actors::Actors;
use crate::ambush_plan::AmbushPlan;
use crate::attack_plan::AttackPlan;
use crate::battle_stats::BattleStats;
use crate::boat_navigation::BoatNavigation;
use crate::bullet_world::Gunfire;
use crate::command_ownership::Ownership;
use crate::deferred_effects::DeferredEffects;
use crate::fires::{self, Fires};
use crate::infantry::Infantry;
use crate::infantry_spawn::Loadout;
use crate::random::SimulationRandom;
use crate::rules_world::Rules;
use crate::spatial::{SpatialIndex, UNIT_CELL};
use crate::squad::{Report, Squad};
use crate::squad_movement;
use crate::state_codec::{Reader, Writer};
use crate::structure::Structure;
use crate::structure_world::Victory;
use crate::vehicle::Vehicle;
use crate::vehicle_loss_world::{Context, Profile};
use crate::visibility::Visibility;
use crate::water::Water;
use crate::world_geometry::WorldGeometry;
use std::collections::HashSet;

pub const FIXED_DELTA: f64 = 1. / 60.;
const MAX_CHECKPOINT: usize = 512 * 1024 * 1024;
const MAX_GROUPS: usize = 100_000;

#[derive(Clone, Copy, Default)]
pub struct Upgrades {
    pub armor: [bool; 2],
    pub grenades: [bool; 2],
    pub medicine: [bool; 2],
    pub optics: [bool; 2],
    pub warheads: [bool; 2],
}
impl From<&crate::economy::Economy> for Upgrades {
    fn from(e: &crate::economy::Economy) -> Self {
        let has = |key| std::array::from_fn(|t| e.has_upgrade(t as i8, key));
        Self {
            armor: has("armor"),
            grenades: has("grenades"),
            medicine: has("medicine"),
            optics: has("optics"),
            warheads: has("warheads"),
        }
    }
}

/// Definition providers read versioned match content, rather than the rendering process.
pub struct Shared<'a> {
    pub names: &'a [Vec<String>; 2],
    pub crew_loadouts: &'a [Loadout; 2],
    pub crew_name: &'a str,
    pub team_names: &'a [&'a str; 2],
    pub vehicle: &'a dyn Fn(&Vehicle) -> Profile<'a>,
    pub man: &'a dyn Fn(&Infantry, &[Squad]) -> fires::ManProfile,
    pub movement: &'a dyn Fn(&Infantry) -> squad_movement::ManProfile,
    pub building: &'a dyn Fn(&Structure) -> fires::BuildingProfile,
    pub role: &'a dyn Fn(&Infantry) -> String,
    pub automatic: &'a dyn Fn(&str) -> bool,
    pub player_building: &'a dyn Fn(&str) -> bool,
}
pub struct Battlefield {
    pub actors: Actors,
    pub geometry: WorldGeometry,
    pub units: SpatialIndex,
    pub squads: Vec<Squad>,
    pub next_squad: u64,
    pub fires: Fires,
    pub battle: BattleStats,
    pub deferred: DeferredEffects,
    pub visibility: Visibility,
    pub rng: SimulationRandom,
    pub now: f64,
    pub town: [f32; 4],
}
impl Battlefield {
    pub fn with_context<T>(
        &mut self,
        p: &Shared<'_>,
        upgrades: Upgrades,
        f: impl FnOnce(&mut Context<'_>) -> T,
    ) -> T {
        let vehicle = |v: &Vehicle| {
            let mut profile = (p.vehicle)(v);
            profile.crew.armor_upgrade = upgrades
                .armor
                .get(v.team as usize)
                .copied()
                .unwrap_or(false);
            profile.crew.grenade_upgrade = upgrades
                .grenades
                .get(v.team as usize)
                .copied()
                .unwrap_or(false);
            profile
        };
        f(&mut Context {
            actors: &mut self.actors,
            geometry: &mut self.geometry,
            units: &self.units,
            squads: &mut self.squads,
            next_squad: &mut self.next_squad,
            fires: &mut self.fires,
            battle: &mut self.battle,
            deferred: &mut self.deferred,
            visibility: &mut self.visibility,
            rng: &mut self.rng,
            now: self.now,
            town: self.town,
            names: p.names,
            crew_loadouts: p.crew_loadouts,
            crew_name: p.crew_name,
            team_names: p.team_names,
            vehicle: &vehicle,
            man: p.man,
            movement: p.movement,
            building: p.building,
            role: p.role,
            automatic: p.automatic,
            player_building: p.player_building,
        })
    }
}
pub struct MatchState {
    pub field: Battlefield,
    pub tick: u64,
    pub rules: Rules,
    pub owners: Ownership,
    pub water: Water,
    pub boats: BoatNavigation,
    pub attacks: Vec<AttackPlan>,
    pub ambushes: Vec<AmbushPlan>,
    pub next_attack: u64,
    pub next_ambush: u64,
    pub gunfire: Gunfire,
    pub impacts: Vec<Report>,
    pub chat: [f64; 2],
    pub victory: Victory,
    pub scenario: bool,
}
fn id_counter(next: u64, ids: impl Iterator<Item = u32>) -> bool {
    let mut seen = HashSet::new();
    (1..=u32::MAX as u64 + 1).contains(&next)
        && ids
            .into_iter()
            .all(|id| id != 0 && u64::from(id) < next && seen.insert(id))
}
fn blocks<T>(
    w: &mut Writer,
    values: &[T],
    save: impl Fn(&T) -> Result<Vec<u8>, &'static str>,
) -> Result<(), &'static str> {
    if values.len() > MAX_GROUPS {
        return Err("match collection limit exceeded");
    }
    w.u32(values.len() as u32);
    for value in values {
        w.bytes(&save(value)?);
    }
    Ok(())
}
fn list<T>(
    r: &mut Reader<'_>,
    restore: impl Fn(&[u8]) -> Result<T, &'static str>,
) -> Result<Vec<T>, &'static str> {
    let count = r.u32()? as usize;
    if count > MAX_GROUPS {
        return Err("match collection limit exceeded");
    }
    (0..count)
        .map(|_| restore(r.bytes(MAX_CHECKPOINT)?))
        .collect()
}
impl MatchState {
    pub fn execute(
        &mut self,
        peer: i32,
        name: &str,
        host_peer: i32,
        command: &crate::match_commands::Command,
        shared: &Shared<'_>,
        profiles: &crate::match_commands::Profiles<'_>,
    ) -> Result<Vec<crate::match_commands::Event>, &'static str> {
        let upgrades = Upgrades::from(&self.rules.economy);
        self.field.with_context(shared, upgrades, |world| {
            crate::match_commands::Dispatcher {
                world,
                rules: &mut self.rules,
                owners: &self.owners,
                boats: &mut self.boats,
                water: &self.water,
                plans: &mut self.attacks,
                ambushes: &mut self.ambushes,
                next_plan: &mut self.next_attack,
                profiles,
                winner: self.victory.winner,
                host_peer,
            }
            .execute(peer, name, command)
        })
    }
    pub fn empty(
        geometry: WorldGeometry,
        water: Water,
        boats: BoatNavigation,
        seed: u64,
        wet: bool,
    ) -> Result<Self, &'static str> {
        let side = geometry.terrain.n;
        if !water.valid() || water.side as usize != side || boats.half() != side as f64 * 0.5 {
            return Err("inconsistent battlefield dimensions");
        }
        Ok(Self {
            field: Battlefield {
                actors: Actors::default(),
                geometry,
                units: SpatialIndex::new(UNIT_CELL)?,
                squads: vec![],
                next_squad: 1,
                fires: Fires::new(side, wet)?,
                battle: BattleStats::default(),
                deferred: DeferredEffects::default(),
                visibility: Visibility::default(),
                rng: SimulationRandom::new(seed),
                now: 0.,
                town: [0.; 4],
            },
            tick: 0,
            rules: Rules::default(),
            owners: Ownership::default(),
            water,
            boats,
            attacks: vec![],
            ambushes: vec![],
            next_attack: 1,
            next_ambush: 1,
            gunfire: Gunfire::default(),
            impacts: vec![],
            chat: [0.; 2],
            victory: Victory {
                winner: -1,
                mission: false,
            },
            scenario: false,
        })
    }
    fn valid(&self) -> bool {
        let f = &self.field;
        f.now.is_finite()
            && (0. ..=1e12 - 100_000.).contains(&f.now)
            && self.tick <= i64::MAX as u64
            && f.town
                .into_iter()
                .all(|v| v.is_finite() && v.abs() <= 1_000_000.)
            && self
                .chat
                .into_iter()
                .all(|v| v.is_finite() && v.abs() <= 1e12)
            && self.impacts.len() <= 100_000
            && self.impacts.iter().all(|r| {
                squad_movement::point(r.position) && r.time.is_finite() && r.time.abs() <= 1e12
            })
            && (-1..=1).contains(&self.victory.winner)
            && self.water.valid()
            && self.water.side as usize == f.geometry.terrain.n
            && self.boats.half() == f.geometry.terrain.half()
            && f.units.cell_size() == UNIT_CELL
            && f.fires.side() == f.geometry.terrain.n
            && id_counter(f.next_squad, f.squads.iter().map(|q| q.id))
            && id_counter(self.next_attack, self.attacks.iter().map(|p| p.id))
            && id_counter(self.next_ambush, self.ambushes.iter().map(|p| p.id))
    }
    /// Checkpoints are taken between ticks; the external command queue is recorded by the host.
    pub fn checkpoint(&self) -> Result<Vec<u8>, &'static str> {
        if !self.valid() {
            return Err("invalid match state");
        }
        let f = &self.field;
        let mut w = Writer::new(b"FLMS\x01\0\0\0");
        w.u64(self.tick);
        w.f64(f.now);
        w.u64(f.rng.seed());
        w.u64(f.rng.state());
        for v in f.town {
            w.f32(v);
        }
        w.u64(f.next_squad);
        w.u64(self.next_attack);
        w.u64(self.next_ambush);
        for v in self.chat {
            w.f64(v);
        }
        w.byte(self.victory.winner as u8);
        w.byte(u8::from(self.victory.mission));
        w.byte(u8::from(self.scenario));
        // Release each temporary block before copying the next map-sized subsystem.
        w.bytes(&f.actors.checkpoint()?);
        w.bytes(&f.geometry.checkpoint());
        w.bytes(&f.units.checkpoint());
        w.bytes(&f.fires.checkpoint());
        w.bytes(&f.battle.checkpoint());
        w.bytes(&f.deferred.checkpoint());
        w.bytes(&f.visibility.checkpoint());
        w.bytes(&self.rules.checkpoint()?);
        w.bytes(&self.owners.checkpoint()?);
        w.bytes(&self.water.checkpoint());
        w.bytes(&self.boats.checkpoint());
        w.bytes(&self.gunfire.checkpoint());
        blocks(&mut w, &f.squads, Squad::checkpoint)?;
        blocks(&mut w, &self.attacks, AttackPlan::checkpoint)?;
        blocks(&mut w, &self.ambushes, AmbushPlan::checkpoint)?;
        w.u32(self.impacts.len() as u32);
        for r in &self.impacts {
            w.point(r.position);
            w.f64(r.time);
        }
        if w.0.len() > MAX_CHECKPOINT {
            return Err("match checkpoint limit exceeded");
        }
        Ok(w.0)
    }
    pub fn restore(bytes: &[u8]) -> Result<Self, &'static str> {
        if bytes.len() > MAX_CHECKPOINT {
            return Err("match checkpoint limit exceeded");
        }
        let mut r = Reader::new(bytes, b"FLMS\x01\0\0\0")?;
        let tick = r.u64()?;
        let now = r.f64()?;
        let mut rng = SimulationRandom::new(r.u64()?);
        rng.set_state(r.u64()?);
        let town = [r.f32()?, r.f32()?, r.f32()?, r.f32()?];
        let next_squad = r.u64()?;
        let next_attack = r.u64()?;
        let next_ambush = r.u64()?;
        let chat = [r.f64()?, r.f64()?];
        let victory = Victory {
            winner: r.byte()? as i8,
            mission: r.boolean()?,
        };
        let scenario = r.boolean()?;
        let actors = Actors::restore(r.bytes(MAX_CHECKPOINT)?)?;
        let geometry = WorldGeometry::restore(r.bytes(MAX_CHECKPOINT)?)?;
        let units = SpatialIndex::restore(r.bytes(MAX_CHECKPOINT)?)?;
        let fires = Fires::restore(r.bytes(MAX_CHECKPOINT)?)?;
        let battle = BattleStats::restore(r.bytes(MAX_CHECKPOINT)?)?;
        let deferred = DeferredEffects::restore(r.bytes(MAX_CHECKPOINT)?)?;
        let visibility = Visibility::restore(r.bytes(MAX_CHECKPOINT)?)?;
        let rules = Rules::restore(r.bytes(MAX_CHECKPOINT)?)?;
        let owners = Ownership::restore(r.bytes(MAX_CHECKPOINT)?)?;
        let water = Water::restore(r.bytes(MAX_CHECKPOINT)?)?;
        let boats = BoatNavigation::restore(r.bytes(MAX_CHECKPOINT)?)?;
        let gunfire = Gunfire::restore(r.bytes(MAX_CHECKPOINT)?)?;
        let squads = list(&mut r, Squad::restore)?;
        let attacks = list(&mut r, AttackPlan::restore)?;
        let ambushes = list(&mut r, AmbushPlan::restore)?;
        let count = r.u32()?;
        if count > 100_000 {
            return Err("recent impact limit exceeded");
        }
        let impacts = (0..count)
            .map(|_| {
                Ok(Report {
                    position: r.point()?,
                    time: r.f64()?,
                })
            })
            .collect::<Result<_, &'static str>>()?;
        r.finish()?;
        let out = Self {
            field: Battlefield {
                actors,
                geometry,
                units,
                squads,
                next_squad,
                fires,
                battle,
                deferred,
                visibility,
                rng,
                now,
                town,
            },
            tick,
            rules,
            owners,
            water,
            boats,
            attacks,
            ambushes,
            next_attack,
            next_ambush,
            gunfire,
            impacts,
            chat,
            victory,
            scenario,
        };
        if !out.valid() {
            return Err("invalid match state");
        }
        Ok(out)
    }
}
