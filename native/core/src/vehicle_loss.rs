//! Passengers, crew and wrecks resolve in battle order, before another vehicle is hit.
use crate::actors::{Actor, Actors};
use crate::entities::MAX_ENTITIES;
use crate::infantry::{Credit, Infantry};
use crate::infantry_effects::{Damage, InfantryHit};
use crate::infantry_pose::Posture;
use crate::infantry_spawn::{random_name, valid_names, Loadout, Spawn};
use crate::infantry_vitals::Life;
use crate::path_planner::PathPlanner;
use crate::random::SimulationRandom;
use crate::spatial::{SpatialIndex, UNIT_CELL};
use crate::squad::Squad;
use crate::vector::{normalized, Vector3};
use crate::vehicle::Vehicle;

#[derive(Clone, Copy, Debug)]
pub struct Crew<'a> {
    pub base: &'a str,
    pub helicopter: bool,
    pub automatic: bool,
    pub count: Option<u32>,
    pub cost: f64,
    pub armor_upgrade: bool,
    pub grenade_upgrade: bool,
}
#[derive(Clone, Debug, Default, PartialEq)]
pub struct Bailout {
    pub attempted: bool,
    pub crew: u32,
    // The world records formation/growth and runs the crew's return order before spawning the wreck.
    pub squad: Option<Squad>,
}
#[derive(Clone, Debug, PartialEq)]
pub struct PassengerHit {
    pub soldier: u32,
    pub hit: InfantryHit,
}
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Wreck {
    pub position: Vector3,
    pub yaw: f64,
    pub tilt: [f32; 2],
    pub velocity: Vector3,
    pub spin: Vector3,
}
fn flat(p: Vector3) -> Vector3 {
    Vector3::new(p.x, 0.0, p.z)
}
fn direction(yaw: f64) -> Vector3 {
    Vector3::new(-libm::sin(yaw) as f32, 0.0, -libm::cos(yaw) as f32)
}

impl Actors {
    pub fn evacuate_destroyed_vehicle(
        &mut self,
        id: u32,
        boat: bool,
        now: f64,
        surrounding_blame: Option<&Credit>,
        nav: &PathPlanner,
        units: &SpatialIndex,
        squads: &mut [Squad],
        ammunition: impl Fn(&Infantry) -> (Option<i32>, bool),
        rng: &mut SimulationRandom,
    ) -> Result<Vec<PassengerHit>, &'static str> {
        if units.cell_size() != UNIT_CELL
            || !now.is_finite()
            || now.abs() > 1e12 - 10.0
            || surrounding_blame.is_some_and(|c| {
                c.owner < -2
                    || !(0..=1).contains(&c.team)
                    || c.unit.len() > 128
                    || c.unit.contains('\0')
            })
        {
            return Err("invalid vehicle evacuation");
        }
        let v = self.vehicle(id).ok_or("missing destroyed transport")?;
        let position = v.position;
        let passengers = v.passengers.clone();
        let blame = if boat {
            surrounding_blame.cloned()
        } else {
            v.hit_by.clone()
        };
        let shore = if boat {
            nav.nearest_walkable(position)
                .ok_or("invalid sinking position")?
        } else {
            position
        };
        let near = flat(shore - position).length() < 60.0;
        let mut hits = vec![];
        for who in passengers {
            let Some(s) = self.soldier(who).filter(|s| s.vitals.life == Life::Hidden) else {
                continue;
            };
            let (stock, bearer) = ammunition(s);
            let spread = if boat { 3.0 } else { 2.5 };
            let exit = shore
                + Vector3::new(
                    rng.randf_range(-spread, spread),
                    0.0,
                    rng.randf_range(-spread, spread),
                );
            let exit = if boat {
                nav.nearest_walkable(exit).ok_or("invalid swimming exit")?
            } else {
                exit
            };
            let s = self.soldier_mut(who).unwrap();
            s.links.vehicle = 0;
            s.unhide(exit, nav)?;
            let amount = if boat && !near {
                999.0
            } else {
                f64::from(rng.randf_range(30.0, if boat { 110.0 } else { 150.0 }))
            };
            let hit = self.damage_infantry(
                who,
                Damage {
                    amount,
                    source: 0,
                    direction: Vector3::Y,
                    kind: "explosion",
                    now,
                    ammunition: stock,
                    bearer,
                    blame: blame.as_ref(),
                },
                squads,
                rng,
            )?;
            hits.push(PassengerHit { soldier: who, hit });
        }
        self.vehicle_mut(id).unwrap().passengers.clear();
        if !boat {
            for who in self.units_near(units, position, 7.0, -1)? {
                if let Some(s) = self.soldier_mut(who) {
                    s.flinch_from(f64::from(flat(s.motion.position - position).length()), 7.0)?;
                }
            }
        }
        Ok(hits)
    }

    pub fn bail_out_vehicle(
        &mut self,
        id: u32,
        overkill: f64,
        crew: Crew<'_>,
        loadout: &Loadout,
        names: &[String],
        next_squad: &mut u64,
        nav: &PathPlanner,
        rng: &mut SimulationRandom,
    ) -> Result<Bailout, &'static str> {
        if !loadout.valid()
            || !valid_names(names)
            || !overkill.is_finite()
            || overkill.abs() > 1e12
            || !crew.cost.is_finite()
            || !(0.0..=1_000_000.0).contains(&crew.cost)
            || crew.base.len() > 128
            || crew.count.is_some_and(|n| n > 4096)
        {
            return Err("invalid vehicle crew");
        }
        let v = self.vehicle(id).ok_or("missing vehicle crew")?;
        if crew.helicopter
            || crew.automatic
            || matches!(
                crew.base,
                "supply" | "uav" | "ugv" | "attack_heli" | "lift_heli" | "boat"
            )
        {
            return Ok(Bailout::default());
        }
        let count = crew
            .count
            .unwrap_or(if matches!(crew.base, "tank" | "afv") {
                3
            } else {
                2
            });
        let squad_id = u32::try_from(*next_squad).map_err(|_| "squad registry exhausted")?;
        let next_id = self.entities().next_id();
        if squad_id == 0
            || next_id + u64::from(count) > u32::MAX as u64 + 1
            || self.entities().len() + count as usize > MAX_ENTITIES
        {
            return Err("entity registry exhausted");
        }
        let position = v.position;
        let yaw = v.yaw;
        let team = v.team;
        let owner = v.owner;
        let probability = if overkill > v.max_hp * 0.35 { 0.2 } else { 0.6 };
        let mut random = *rng;
        let mut survivors = vec![];
        for i in 0..count {
            if f64::from(random.randf()) > probability {
                continue;
            }
            let offset = direction(yaw + std::f64::consts::FRAC_PI_2)
                * if i % 2 == 0 { 1.7 } else { -1.7 }
                + direction(yaw) * (i as f32 - 1.0) * 1.3;
            let exit = nav
                .nearest_walkable(position + offset)
                .ok_or("invalid crew exit")?;
            let mut s = Infantry::from_spawn(
                (next_id + survivors.len() as u64) as u32,
                Spawn {
                    team,
                    owner,
                    position: exit,
                    yaw,
                    name: random_name(names, &mut random)?,
                    squad: squad_id,
                    life: Life::Alive,
                    posture: Posture::Stand,
                    armor_upgrade: crew.armor_upgrade,
                    grenade_upgrade: crew.grenade_upgrade,
                },
                loadout,
                &mut random,
            )?;
            s.vitals.hp = s.vitals.max_hp * f64::from(random.randf_range(0.35, 0.85));
            survivors.push(s);
        }
        let squad = if survivors.is_empty() {
            None
        } else {
            let mut q = Squad::new(
                squad_id,
                team,
                owner,
                if team == 0 { "crew" } else { "r_crew" }.into(),
            )?;
            for s in survivors {
                let id = self.spawn(Actor::Soldier(Box::new(s)))?;
                q.add_member(id, self)?;
            }
            q.order_position = position;
            q.cooldowns.push((
                "refund".into(),
                (crew.cost * 0.12 * q.members.len() as f64 / f64::from(count.max(1))).trunc(),
            ));
            q.cooldowns.push(("crew_n".into(), q.order_number as f64));
            self.soldier_mut(q.members[0])
                .unwrap()
                .vitals
                .speech_cooldown = 2.6;
            *next_squad += 1;
            Some(q)
        };
        *rng = random;
        Ok(Bailout {
            attempted: true,
            crew: count,
            squad,
        })
    }
}

impl Vehicle {
    pub fn wreck_plan(
        &self,
        weight: u8,
        now: f64,
        nav: &PathPlanner,
        rng: &mut SimulationRandom,
    ) -> Result<Wreck, &'static str> {
        if !self.valid() || weight > 2 || !now.is_finite() || now.abs() > 1e12 {
            return Err("invalid vehicle wreck");
        }
        let p = flat(self.position);
        let Some(blast) = self.last_blast.filter(|b| now - b.time <= 0.6) else {
            return Ok(Wreck {
                position: p,
                yaw: self.yaw,
                tilt: [rng.randf_range(-0.03, 0.03), rng.randf_range(-0.04, 0.04)],
                velocity: Vector3::ZERO,
                spin: Vector3::ZERO,
            });
        };
        let (up, out, chance): ([f32; 2], [f32; 2], f64) = match weight {
            2 => ([0.8, 2.2], [0.2, 0.8], 0.0),
            1 => ([1.5, 4.5], [0.5, 2.5], 0.15),
            _ => ([3.0, 9.0], [2.0, 6.0], 0.45),
        };
        let away = flat(p - blast.position);
        let distance = f64::from(away.length());
        let away = if distance > 0.1 {
            normalized(away)
        } else {
            direction(f64::from(rng.randf()) * std::f64::consts::TAU)
        };
        let power =
            (blast.size * (1.0 - distance / (5.0 + blast.size * 3.0)) / 2.6).clamp(0.12, 1.0);
        let up = f64::from(up[0]) + (f64::from(up[1]) - f64::from(up[0])) * power;
        let out = f64::from(out[0]) + (f64::from(out[1]) - f64::from(out[0])) * power;
        let air_time = 2.0 * up / 19.6;
        let mut destination = p + away * out as f32 * air_time as f32;
        let limit = nav.side() as f32 * 0.5 - 4.0;
        if destination.x.abs() >= limit
            || destination.z.abs() >= limit
            || nav.kind_at(destination, false) == 3
        {
            destination = p;
        }
        let pitch = rng.randf_range(-0.06, 0.06);
        let mut roll = f64::from(rng.randf_range(-0.07, 0.07));
        let r = f64::from(rng.randf());
        let flip = chance * power;
        if r < flip {
            roll = std::f64::consts::PI;
        } else if r < flip * 2.0 {
            roll = std::f64::consts::FRAC_PI_2 * if rng.randf() < 0.5 { 1.0 } else { -1.0 };
        }
        let dyaw = f64::from(rng.randf_range(-1.0, 1.0)) * power;
        let axis = normalized(away.cross(Vector3::Y));
        let spin = -axis * (roll.abs() + 0.6) as f32 / air_time.max(0.35) as f32
            + Vector3::Y * dyaw as f32 / air_time.max(0.35) as f32;
        Ok(Wreck {
            position: destination,
            yaw: self.yaw + dyaw,
            tilt: [pitch, roll as f32],
            velocity: away * out as f32 + Vector3::Y * up as f32,
            spin,
        })
    }
}
