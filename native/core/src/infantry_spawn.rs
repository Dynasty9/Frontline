//! Birth state uses the match's unit definitions; rendering never initializes gameplay.
use crate::actors::{Actor, Actors};
use crate::infantry::Infantry;
use crate::infantry_pose::Posture;
use crate::infantry_vitals::Life;
use crate::random::SimulationRandom;
use crate::vector::Vector3;

#[derive(Clone, Debug)]
pub struct Loadout {
    pub unit: String,
    pub weapon: String,
    pub hp: f64,
    pub magazine: i32,
    pub ammunition: i32,
    pub grenades: i32,
    pub smokes: i32,
    pub rockets: i32,
    pub mortar_rounds: i32,
    pub drones: i32,
    pub bearer: bool,
}

#[derive(Clone, Debug)]
pub struct Spawn {
    pub team: i8,
    pub owner: i32,
    pub position: Vector3,
    pub yaw: f64,
    pub name: String,
    pub squad: u32,
    pub life: Life,
    pub posture: Posture,
    pub armor_upgrade: bool,
    pub grenade_upgrade: bool,
}

impl Loadout {
    pub fn valid(&self) -> bool {
        !self.unit.is_empty()
            && self.unit.len() <= 128
            && !self.unit.contains('\0')
            && self.weapon.len() <= 128
            && !self.weapon.contains('\0')
            && self.hp.is_finite()
            && (0.0..=1_000_000.0).contains(&self.hp)
            && [
                self.magazine,
                self.ammunition,
                self.grenades,
                self.smokes,
                self.rockets,
                self.mortar_rounds,
                self.drones,
            ]
            .into_iter()
            .all(|n| (0..=1_000_000).contains(&n))
            && self.magazine <= self.ammunition
            && (self.weapon.is_empty() == (self.magazine == 0 && self.ammunition == 0))
            && (self.bearer || self.grenades < 1_000_000)
    }
}

impl Infantry {
    pub fn from_spawn(
        id: u32,
        spawn: Spawn,
        loadout: &Loadout,
        rng: &mut SimulationRandom,
    ) -> Result<Self, &'static str> {
        if !loadout.valid() || !spawn.yaw.is_finite() || spawn.yaw.abs() > 1e12 {
            return Err("invalid infantry birth");
        }
        let mut s = Self::default();
        s.identity.id = id;
        s.identity.unit = loadout.unit.clone();
        s.identity.weapon = loadout.weapon.clone();
        s.identity.team = spawn.team;
        s.identity.owner = spawn.owner;
        s.identity.name = spawn.name;
        s.identity.squad = spawn.squad;
        s.vitals.life = spawn.life;
        s.posture = spawn.posture;
        s.motion.position = spawn.position;
        s.motion.yaw = f64::from(spawn.yaw as f32);
        s.motion.last_direction = Vector3::NEG_Z;
        s.orders.hold_position = spawn.position;
        s.orders.hold_face = Vector3::new(
            -libm::sin(s.motion.yaw) as f32,
            0.0,
            -libm::cos(s.motion.yaw) as f32,
        );
        s.vitals.base_hp = loadout.hp * if spawn.armor_upgrade { 1.2 } else { 1.0 };
        s.vitals.max_hp = s.vitals.base_hp;
        s.vitals.hp = s.vitals.base_hp;
        s.vitals.last_suppression = -99.0;
        s.weapon.last_shot = -99.0;
        s.weapon.magazine = loadout.magazine;
        s.weapon.reserve = loadout.ammunition - loadout.magazine;
        s.grenades.frags = loadout.grenades + i32::from(spawn.grenade_upgrade && !loadout.bearer);
        s.fight.smokes = loadout.smokes;
        s.arsenal.rockets = loadout.rockets;
        s.arsenal.mortar_rounds = loadout.mortar_rounds;
        s.arsenal.drones = loadout.drones;
        s.arsenal.drone_ready = 4.0;
        if !s.valid() {
            return Err("invalid infantry birth");
        }
        s.controller.think_timer = f64::from(rng.randf()) * 0.3;
        Ok(s)
    }
}

pub fn random_name(names: &[String], rng: &mut SimulationRandom) -> Result<String, &'static str> {
    if names.is_empty()
        || names.len() > 4096
        || names.iter().any(|n| n.len() > 1024 || n.contains('\0'))
    {
        return Err("invalid soldier names");
    }
    Ok(names[rng.randi() as usize % names.len()].clone())
}

impl Actors {
    pub fn spawn_infantry(
        &mut self,
        spawn: Spawn,
        loadout: &Loadout,
        rng: &mut SimulationRandom,
    ) -> Result<u32, &'static str> {
        let id =
            u32::try_from(self.entities().next_id()).map_err(|_| "entity registry exhausted")?;
        let mut random = *rng;
        let soldier = Infantry::from_spawn(id, spawn, loadout, &mut random)?;
        let id = self.spawn(Actor::Soldier(Box::new(soldier)))?;
        *rng = random;
        Ok(id)
    }
}
