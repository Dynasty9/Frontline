//! Hits and near misses update soldiers, their shared links and squad knowledge together.
use crate::actors::{Actor, Actors};
use crate::blast::{Blast, Infantry as Exposure, Protection as BlastProtection};
use crate::collision::CollisionWorld;
use crate::infantry::Credit;
use crate::infantry::Infantry;
use crate::infantry_casualty::Released;
use crate::infantry_controller::Task;
use crate::infantry_vitals::{DamageResult, Life, Protection};
use crate::random::SimulationRandom;
use crate::spatial::{SpatialIndex, UNIT_CELL};
use crate::squad::{Contact, Report, Speech, Squad};
use crate::terrain::{Terrain, CRATER, TRENCH};
use crate::vector::Vector3;

#[derive(Clone, Debug, PartialEq)]
pub struct InfantryHit {
    pub previous_life: Life,
    pub result: DamageResult,
    pub released: Option<Released>,
    pub speech: Option<u8>,
    pub casualty_speech: Option<Speech>,
    pub credited: Option<Credit>,
    pub damage_credited: f64,
}

#[derive(Clone, Debug, PartialEq)]
pub struct BlastVictim {
    pub soldier: u32,
    pub hit: Option<InfantryHit>,
    pub flung: bool,
}

#[derive(Clone, Copy, Debug)]
pub struct Damage<'a> {
    pub amount: f64,
    pub source: u32,
    pub direction: Vector3,
    pub kind: &'a str,
    pub now: f64,
    pub ammunition: Option<i32>,
    pub bearer: bool,
    pub blame: Option<&'a Credit>,
}

fn point(p: Vector3) -> bool {
    p.is_finite() && p.abs().max_element() <= 1_000_000.0
}
fn clock(t: f64) -> bool {
    t.is_finite() && t.abs() <= 1e12 - 10.0
}

impl Actor {
    pub fn position(&self) -> Vector3 {
        match self {
            Self::Soldier(s) => s.motion.position,
            Self::Vehicle(v) => v.position,
            Self::Structure(s) => s.position,
            Self::Projectile(p) => p.motion.position(),
            Self::Drone(d) => d.flight.position,
        }
    }

    /// A neutral source has no credit; only a missing source falls back to blast blame.
    pub fn credit(&self) -> Option<Credit> {
        let (owner, team, unit, soldier) = match self {
            Self::Soldier(s) => (
                s.identity.owner,
                s.identity.team,
                if s.identity.squad == 0 {
                    String::new()
                } else {
                    format!("s{}", s.identity.squad)
                },
                s.identity.id,
            ),
            Self::Vehicle(v) => (v.owner, v.team, format!("v{}", v.id), 0),
            Self::Structure(s) => (s.owner, s.team, String::new(), 0),
            Self::Projectile(p) => (0, p.team, String::new(), 0),
            Self::Drone(d) => (0, d.team, String::new(), 0),
        };
        (team >= 0).then_some(Credit {
            owner,
            team,
            unit,
            soldier,
        })
    }
}

impl Actors {
    /// A carrier's injury can free the next victim before their exposure is evaluated.
    pub fn blast_infantry(
        &mut self,
        mut blast: Blast,
        source: u32,
        now: f64,
        blame: Option<&Credit>,
        terrain: &Terrain,
        units: &SpatialIndex,
        collision: &mut CollisionWorld,
        squads: &mut [Squad],
        ammunition: impl Fn(&Infantry) -> (Option<i32>, bool),
        rng: &mut SimulationRandom,
    ) -> Result<Vec<BlastVictim>, &'static str> {
        if !blast.valid()
            || !clock(now)
            || blame.is_some_and(|c| {
                c.owner < -2
                    || !(0..=1).contains(&c.team)
                    || c.unit.len() > 128
                    || c.unit.contains('\0')
            })
        {
            return Err("invalid retained infantry blast");
        }
        let ids = self.units_near(units, blast.position, blast.radius * 2.4, -1)?;
        blast.in_trench = terrain.layers[TRENCH][terrain.index(blast.position)] > 0;
        let mut victims = Vec::new();
        for id in ids {
            let Some(s) = self.soldier(id).filter(|s| s.vitals.life != Life::Hidden) else {
                continue;
            };
            let center = crate::infantry_pose::center(s.motion.position, s.posture, s.vitals.life);
            let nearby = f64::from(blast.position.distance(center)) < blast.radius;
            let ray = if nearby {
                collision.ray(blast.position + Vector3::new(0.0, 0.35, 0.0), center, &[])
            } else {
                None
            };
            let cell = terrain.index(s.motion.position);
            let injury = blast.infantry(
                Exposure {
                    center,
                    life: s.vitals.life,
                    posture: s.posture,
                    in_trench: nearby && terrain.layers[TRENCH][cell] > 0,
                    terrain_multiplier: if nearby && terrain.layers[CRATER][cell] > 0 {
                        0.6
                    } else {
                        1.0
                    },
                },
                BlastProtection {
                    blocked: ray.is_some(),
                    material: ray
                        .and_then(|r| u32::try_from(r.body).ok())
                        .and_then(|id| self.structure(id))
                        .map(|st| st.cover_material()),
                },
            )?;
            let hit = if injury.damage > 0.0 {
                let (stock, bearer) = ammunition(s);
                Some(self.damage_infantry(
                    id,
                    Damage {
                        amount: injury.damage,
                        source,
                        direction: injury.direction,
                        kind: "explosion",
                        now,
                        ammunition: stock,
                        bearer,
                        blame,
                    },
                    squads,
                    rng,
                )?)
            } else {
                None
            };
            let released = if injury.fling > 0.0 {
                self.fling_from(id, blast.position, injury.fling, rng)?
            } else {
                None
            };
            if let Some(released) = released {
                if let Some(q) = squads
                    .iter_mut()
                    .find(|q| q.id == released.squad && q.breach_by == id)
                {
                    q.breach_by = 0;
                }
            }
            if injury.flinch_radius > 0.0 {
                self.soldier_mut(id)
                    .unwrap()
                    .flinch_from(injury.distance, injury.flinch_radius)?;
            }
            victims.push(BlastVictim {
                soldier: id,
                hit,
                flung: released.is_some(),
            });
        }
        Ok(victims)
    }

    pub fn damage_infantry(
        &mut self,
        id: u32,
        hit: Damage<'_>,
        squads: &mut [Squad],
        rng: &mut SimulationRandom,
    ) -> Result<InfantryHit, &'static str> {
        if !clock(hit.now)
            || !point(hit.direction)
            || hit.kind.len() > 128
            || hit.kind.contains('\0')
            || !hit.amount.is_finite()
            || !(0.0..=1e12).contains(&hit.amount)
            || hit
                .ammunition
                .is_some_and(|n| !(0..=1_000_000).contains(&n))
            || hit.blame.is_some_and(|c| {
                c.owner < -2
                    || !(0..=1).contains(&c.team)
                    || c.unit.len() > 128
                    || c.unit.contains('\0')
            })
        {
            return Err("invalid shared infantry damage");
        }
        let s = self.soldier(id).ok_or("missing damaged soldier")?;
        let previous_life = s.vitals.life;
        let mut out = InfantryHit {
            previous_life,
            result: DamageResult::Ignored,
            released: None,
            speech: None,
            casualty_speech: None,
            credited: None,
            damage_credited: 0.0,
        };
        if matches!(previous_life, Life::Dead | Life::Hidden) {
            return Ok(out);
        }
        let victim_squad = squads.iter().position(|q| q.id == s.identity.squad);
        let source = self.get(hit.source);
        let attacker_squad = match source {
            Some(Actor::Soldier(a)) if a.identity.team != s.identity.team => {
                squads.iter().position(|q| q.id == a.identity.squad)
            }
            _ => None,
        };
        for i in [victim_squad, attacker_squad].into_iter().flatten() {
            if !squads[i].morale.is_finite() {
                return Err("invalid damage squad");
            }
        }
        let report = if previous_life != Life::Downed {
            source.map(|a| Contact {
                id: hit.source,
                report: Report {
                    position: a.position(),
                    time: hit.now,
                },
            })
        } else {
            None
        };
        if let (Some(i), Some(contact)) = (victim_squad, report) {
            let q = &squads[i];
            if q.known.len() == 100_000 && !q.known.iter().any(|k| k.id == contact.id) {
                return Err("squad contact limit exceeded");
            }
        }
        out.credited = match source {
            Some(a) => a.credit(),
            None => hit.blame.cloned(),
        }
        .filter(|c| c.team != s.identity.team);
        if out.credited.is_some() && previous_life == Life::Alive {
            out.damage_credited = hit.amount.min(s.vitals.hp.max(0.0));
        }
        // Stage the recipient until a route revision or corpse stock limit can no longer reject the hit.
        let mut next = s.clone();
        let mut random = *rng;
        if let Some(credit) = &out.credited {
            next.identity.hit_by = Some(credit.clone());
        }
        out.result =
            next.receive_damage(hit.amount, hit.direction, hit.kind, hit.bearer, &mut random)?;
        let winning = previous_life == Life::Alive && next.vitals.hp <= 0.0;
        out.released = match out.result {
            DamageResult::Down => Some(next.go_down(hit.now)?),
            DamageResult::Die => next.die(hit.now, hit.ammunition)?,
            DamageResult::Survived(speech) => {
                if next.vitals.speech_cooldown <= 0.0 && speech.is_some() {
                    next.vitals.speech_cooldown = 2.6;
                    out.speech = speech;
                }
                None
            }
            DamageResult::Ignored => None,
        };
        if let (Some(i), Some(report)) = (victim_squad, report) {
            squads[i].report(report)?;
        }
        if winning {
            if let Some(i) = attacker_squad {
                squads[i].morale = (squads[i].morale + 3.0).min(100.0);
            }
        }
        *self.soldier_mut(id).unwrap() = next;
        if let Some(released) = out.released {
            self.release_links(id, released);
            if let Some(q) = squads
                .iter_mut()
                .find(|q| q.id == released.squad && q.breach_by == id)
            {
                q.breach_by = 0;
            }
            if let Some(i) = victim_squad {
                out.casualty_speech = squads[i].casualty(id, hit.now, self, &mut random)?;
            }
        }
        *rng = random;
        Ok(out)
    }

    pub fn suppress_infantry(
        &mut self,
        id: u32,
        amount: f64,
        from: Vector3,
        now: f64,
        squad: Option<&mut Squad>,
        rng: &mut SimulationRandom,
    ) -> Result<Option<u8>, &'static str> {
        if !clock(now) || !point(from) {
            return Err("invalid shared suppression");
        }
        let s = self.soldier(id).ok_or("missing suppressed soldier")?;
        if squad.as_ref().is_some_and(|q| q.id != s.identity.squad) {
            return Err("invalid suppressed squad");
        }
        let protection = Protection {
            at_cover: s.cover.at_cover,
            cover_kind: s.cover.kind,
            material: (s.cover.material >= 0).then_some(s.cover.material as u8),
            peek_up: s.weapon.peek_up,
            protected_mount: self
                .structure(s.emplacement.structure as u32)
                .is_some_and(|st| st.kind != "watchtower"),
            in_trench: s.motion.ground < -0.6,
        };
        let retreating = s.duty.kind == Task::Retreat;
        let s = self.soldier_mut(id).unwrap();
        let out = s
            .vitals
            .suppress(amount, now, retreating, squad.is_some(), protection, rng)?;
        let speech = out.speech.filter(|_| s.vitals.speech_cooldown <= 0.0);
        if speech.is_some() {
            s.vitals.speech_cooldown = 2.6;
        }
        if out.report_position {
            squad.unwrap().report_position(from, now)?;
        }
        Ok(speech)
    }

    pub fn suppress_bullet(
        &mut self,
        a: Vector3,
        b: Vector3,
        team: i8,
        amount: f64,
        hit_target: u32,
        now: f64,
        units: &SpatialIndex,
        squads: &mut [Squad],
        rng: &mut SimulationRandom,
    ) -> Result<Vec<Speech>, &'static str> {
        if !point(a)
            || !point(b)
            || !clock(now)
            || !(-1..=1).contains(&team)
            || units.cell_size() != UNIT_CELL
            || !amount.is_finite()
            || !(0.0..=1_000_000.0).contains(&amount)
        {
            return Err("invalid retained bullet suppression");
        }
        let ids: Vec<_> = self
            .units_near(
                units,
                (a + b) * 0.5,
                f64::from(a.distance(b)) * 0.5 + 3.0,
                -1,
            )?
            .into_iter()
            .filter(|&id| {
                id != hit_target
                    && self
                        .soldier(id)
                        .is_some_and(|s| s.identity.team != team && s.vitals.life == Life::Alive)
            })
            .collect();
        let positions: Vec<_> = ids
            .iter()
            .map(|&id| self.soldier(id).unwrap().motion.position)
            .collect();
        let amounts = crate::bullet::suppression(a, b, &positions, amount)?;
        let mut speech = vec![];
        for (id, amount) in ids.into_iter().zip(amounts).filter(|(_, a)| *a >= 0.0) {
            let squad = self.soldier(id).unwrap().identity.squad;
            if let Some(cue) = self.suppress_infantry(
                id,
                amount,
                a,
                now,
                squads.iter_mut().find(|q| q.id == squad),
                rng,
            )? {
                speech.push(Speech { soldier: id, cue });
            }
        }
        Ok(speech)
    }
}
