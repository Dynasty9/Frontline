//! Special weapons select owned targets and retain their ammunition, action and speech.
use crate::actors::Actors;
use crate::collision::CollisionWorld;
use crate::fire_targets;
use crate::infantry::Infantry;
use crate::infantry_action::{Action, Related, Round};
use crate::infantry_arsenal::{
    MeleeContact, MortarDecision, MortarTarget, RocketContact, RocketInput,
};
use crate::random::SimulationRandom;
use crate::spatial::{SpatialIndex, UNIT_CELL};
use crate::squad::Squad;
use crate::terrain::Terrain;
use crate::vector::Vector3;
use crate::vehicle::Vehicle;
use crate::visibility::Visibility;

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct Attempt {
    pub started: bool,
    pub cleared_mission: bool,
    // Blue rocket, red rocket, drone, out-of-range, then the three mortar calls.
    pub speech: Option<u8>,
}
fn clock(now: f64) -> bool {
    now.is_finite() && now.abs() <= 1e12 - 100.0
}
fn distance(a: Vector3, b: Vector3) -> f64 {
    let d = a - b;
    f64::from(Vector3::new(d.x, 0.0, d.z).length())
}
fn related(id: u64, position: Vector3) -> Related {
    Related {
        id,
        position,
        gone: false,
        holder: 0,
    }
}

impl Actors {
    pub fn try_infantry_melee(
        &mut self,
        id: u32,
        now: f64,
        armed: bool,
        units: &SpatialIndex,
    ) -> Result<Attempt, &'static str> {
        if !clock(now) || units.cell_size() != UNIT_CELL {
            return Err("invalid melee context");
        }
        let s = self.soldier(id).ok_or("missing infantry")?;
        if !armed || now < s.arsenal.melee_ready {
            return Ok(Attempt::default());
        }
        let nearby: Vec<_> = self
            .units_near(units, s.motion.position, 1.9, -1)?
            .into_iter()
            .filter_map(|id| self.soldier(id))
            .map(|s| MeleeContact {
                id: s.identity.id.into(),
                team: s.identity.team.into(),
                life: s.vitals.life,
                flinging: s.shock.flinging,
            })
            .collect();
        let mut next = s.clone();
        let target = next
            .arsenal
            .melee(now, next.identity.team.into(), armed, &nearby)?;
        let Some(target) = target else {
            return Ok(Attempt::default());
        };
        next.begin_action(
            Action::Melee { target },
            0.55,
            Some(related(
                target,
                self.soldier(target as u32).unwrap().motion.position,
            )),
        )?;
        *self.soldier_mut(id).unwrap() = next;
        Ok(Attempt {
            started: true,
            ..Default::default()
        })
    }

    pub fn try_infantry_rocket(
        &mut self,
        id: u32,
        now: f64,
        squad: Option<&Squad>,
        terrain: &Terrain,
        deck: &[u8],
        collision: &mut CollisionWorld,
        visibility: &Visibility,
    ) -> Result<Attempt, &'static str> {
        let s = self.soldier(id).ok_or("missing infantry")?;
        if !clock(now)
            || squad.is_some_and(|q| q.id != s.identity.squad)
            || (!deck.is_empty() && deck.len() != terrain.n * terrain.n)
        {
            return Err("invalid rocket context");
        }
        if s.arsenal.rockets == 0 || now < s.arsenal.rocket_ready || squad.is_some_and(|q| q.ambush)
        {
            return Ok(Attempt::default());
        }
        let mut next = s.clone();
        let visible: Vec<_> = s
            .fight
            .visible_targets
            .iter()
            .filter_map(|&id| self.vehicle(id as u32))
            .map(|v| RocketContact {
                id: v.id.into(),
                position: v.position,
                center: v.position,
                gone: false,
                age: 0.0,
                excluded: Vec::new(),
            })
            .collect();
        let mut eye = s.motion.position;
        let mut reported = Vec::new();
        if !visible
            .iter()
            .any(|v| distance(v.position, s.motion.position) < 75.0)
        {
            if let Some(q) = squad {
                if now > next.motion.ground_until {
                    next.motion.ground_until = now + 0.3;
                    next.motion.ground = terrain.ground_y(
                        next.motion.position,
                        !deck.is_empty() && deck[terrain.index(next.motion.position)] == 1,
                    );
                }
                eye += Vector3::Y * (1.6 + next.motion.ground) as f32;
                for c in &q.known {
                    if let Some(v) = self.vehicle(c.id) {
                        reported.push(RocketContact {
                            id: v.id.into(),
                            position: v.position,
                            center: v.center(),
                            gone: false,
                            age: now - c.report.time,
                            excluded: vec![v.id.into()],
                        });
                    }
                }
            }
        }
        let forced = self
            .structure(s.fight.forced_target as u32)
            .map(|st| RocketContact {
                id: st.id.into(),
                position: st.position,
                center: st.position,
                gone: false,
                age: 0.0,
                excluded: Vec::new(),
            });
        let target = next.arsenal.rocket(
            RocketInput {
                time: now,
                position: s.motion.position,
                eye,
                ambush: false,
                visible: &visible,
                reported: &reported,
                forced,
            },
            collision,
            visibility,
        )?;
        let mut out = Attempt::default();
        if let Some(target) = target {
            next.begin_action(
                Action::Launch { target },
                0.8,
                Some(related(target, self.get(target as u32).unwrap().position())),
            )?;
            next.vitals.speech_cooldown = 2.6;
            out.started = true;
            out.speech = Some(if s.identity.team == 1 { 1 } else { 0 });
        }
        *self.soldier_mut(id).unwrap() = next;
        Ok(out)
    }

    pub fn try_infantry_drone(
        &mut self,
        id: u32,
        now: f64,
        units: &SpatialIndex,
        armor: impl Fn(&Vehicle) -> i32,
        bearer: impl Fn(&Infantry) -> bool,
        rng: &mut SimulationRandom,
    ) -> Result<Attempt, &'static str> {
        if !clock(now) || units.cell_size() != UNIT_CELL {
            return Err("invalid drone launch context");
        }
        let s = self.soldier(id).ok_or("missing infantry")?;
        if s.arsenal.drones == 0 || now < s.arsenal.drone_ready || s.fight.controlled_drone != 0 {
            return Ok(Attempt::default());
        }
        let target = fire_targets::fpv(
            self,
            units,
            s.identity.team,
            s.motion.position,
            230.0,
            armor,
            bearer,
        )?;
        let mut next = s.clone();
        let mut random = *rng;
        let target = next
            .arsenal
            .drone(now, false, target.map(u64::from), &mut random)?;
        let mut out = Attempt::default();
        if let Some(target) = target {
            next.begin_action(
                Action::LaunchDrone { target },
                1.4,
                Some(related(target, self.get(target as u32).unwrap().position())),
            )?;
            next.vitals.speech_cooldown = 2.6;
            out.started = true;
            out.speech = Some(2);
        }
        *self.soldier_mut(id).unwrap() = next;
        *rng = random;
        Ok(out)
    }

    pub fn try_infantry_mortar(
        &mut self,
        id: u32,
        now: f64,
        squad: Option<&mut Squad>,
        units: &SpatialIndex,
        owned_structures: &[u32],
        rng: &mut SimulationRandom,
    ) -> Result<Attempt, &'static str> {
        if !clock(now) || units.cell_size() != UNIT_CELL {
            return Err("invalid mortar context");
        }
        let s = self.soldier(id).ok_or("missing infantry")?;
        if squad.as_ref().is_some_and(|q| q.id != s.identity.squad) {
            return Err("mortar squad mismatch");
        }
        if s.arsenal.mortar_rounds == 0 || now < s.arsenal.mortar_ready || s.is_moving() {
            return Ok(Attempt::default());
        }
        let Some(q) = squad else {
            return Ok(Attempt::default());
        };
        let queued = q.fire_queue.first().copied();
        let target = match queued {
            Some((p, _)) => MortarTarget::Queued(p),
            None => MortarTarget::Automatic(fire_targets::mortar(
                self,
                units,
                owned_structures,
                s.identity.team,
                s.motion.position,
                30.0,
                130.0,
            )?),
        };
        let mut next = s.clone();
        let mut random = *rng;
        let mut out = Attempt::default();
        match next
            .arsenal
            .mortar(now, s.motion.position, false, true, target)?
        {
            MortarDecision::Wait => {}
            MortarDecision::CancelQueue => {
                next.vitals.speech_cooldown = 2.6;
                out.cleared_mission = true;
                out.speech = Some(3);
            }
            MortarDecision::Fire(position) => {
                let round = if queued.is_some_and(|(_, smoke)| smoke) {
                    Round::Smoke
                } else {
                    Round::HighExplosive
                };
                next.begin_action(Action::Mortar { position, round }, 1.0, None)?;
                out.started = true;
                if random.randf() < 0.4 {
                    let cue = (random.randi() % 3) as u8 + 4;
                    if next.vitals.speech_cooldown <= 0.0 {
                        next.vitals.speech_cooldown = 2.6;
                        out.speech = Some(cue);
                    }
                }
            }
        }
        if out.cleared_mission {
            q.fire_queue.clear();
        } else if queued.is_some() {
            q.fire_queue.remove(0);
        }
        *self.soldier_mut(id).unwrap() = next;
        *rng = random;
        Ok(out)
    }
}
