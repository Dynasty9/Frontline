//! Both sides of a conversation are owned by the simulation, including its random draws.
use crate::actors::Actors;
use crate::infantry_controller::Task;
use crate::infantry_idle::{self, Calm, Decision, Mate, LAUGH};
use crate::infantry_pose::Posture;
use crate::infantry_vitals::Life;
use crate::random::SimulationRandom;
use crate::spatial::{SpatialIndex, UNIT_CELL};
use crate::squad::Squad;

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Event {
    Banter,
    Speech(String),
}

impl Actors {
    pub fn advance_infantry_idle(
        &mut self,
        id: u32,
        dt: f64,
        now: f64,
        moving: bool,
        squads: &mut [Squad],
        last_chat: &mut [f64; 2],
        units: &SpatialIndex,
        rng: &mut SimulationRandom,
    ) -> Result<Vec<Event>, &'static str> {
        if !dt.is_finite()
            || !(0.0..=10.0).contains(&dt)
            || !now.is_finite()
            || now.abs() > 1e12 - 100.0
            || last_chat.iter().any(|t| !t.is_finite() || t.abs() > 1e12)
            || units.cell_size() != UNIT_CELL
        {
            return Err("invalid infantry downtime context");
        }
        let s = self.soldier(id).ok_or("missing resting infantry")?;
        let partner = s.idle.partner as u32;
        let partner_valid = self
            .soldier(partner)
            .is_some_and(|p| p.idle.partner == id.into() && p.vitals.life == Life::Alive);
        let calm = Calm {
            moving,
            danger: !moving && self.infantry_danger(id, now, squads),
            sector: s.fight.sector,
            reload: s.weapon.reload_timer,
            last_shot: s.weapon.last_shot,
            mounted: s.emplacement.structure != 0,
            target: self.infantry_target_valid(s.fight.target as u32),
        };
        let decision = self
            .soldier_mut(id)
            .unwrap()
            .idle
            .tick(dt, now, calm, partner_valid)?;
        let mut events = Vec::new();
        match decision {
            Decision::Wait => {}
            Decision::End => {
                let partner = self.soldier_mut(id).unwrap().idle.end(now, rng)? as u32;
                if let Some(p) = self
                    .soldier_mut(partner)
                    .filter(|p| p.idle.partner == id.into())
                {
                    p.idle.partner = 0;
                }
            }
            Decision::Pose | Decision::Chat => {
                let other = self.soldier(partner).map(|p| p.motion.position);
                let s = self.soldier_mut(id).unwrap();
                s.activity = s.idle.activity;
                s.posture = Posture::Stand;
                if decision == Decision::Chat {
                    s.motion.yaw = infantry_idle::chat_yaw(
                        s.motion.position,
                        other.unwrap(),
                        s.motion.yaw,
                        dt,
                        None,
                    )?;
                    while let Some(line) = s.idle.next_line(now, rng)? {
                        if let Some(text) = line {
                            s.vitals.speech_cooldown = 2.6;
                            events.push(Event::Speech(text));
                        }
                    }
                    if now < s.idle.laugh_until {
                        s.activity = LAUGH;
                    }
                }
            }
            Decision::Start => {
                let s = self.soldier_mut(id).unwrap();
                let team = i32::from(s.identity.team);
                let side = usize::from(team == 1);
                let chat = s.idle.begin(now, last_chat[side], rng)?;
                let position = s.motion.position;
                let mate = if chat {
                    let nearby: Vec<_> = self
                        .units_near(units, position, 6.0, -1)?
                        .into_iter()
                        .filter_map(|who| self.soldier(who))
                        .map(|p| Mate {
                            id: p.identity.id.into(),
                            team: p.identity.team.into(),
                            life: p.vitals.life,
                            chatting: p.idle.partner != 0,
                            calm: p.idle.calm,
                            free: p.duty.kind == Task::Fight,
                            moving: p.is_moving(),
                        })
                        .collect();
                    infantry_idle::select_mate(id.into(), team, &nearby)?
                } else {
                    None
                };
                if let Some(mate) = mate {
                    let s = self.soldier(id).unwrap();
                    let p = self.soldier(mate as u32).unwrap();
                    let (mut actor, mut other) = (s.idle.clone(), p.idle.clone());
                    actor.start_chat(
                        &mut other,
                        id.into(),
                        mate,
                        now,
                        team,
                        &s.identity.name,
                        &p.identity.name,
                        rng,
                    )?;
                    self.soldier_mut(id).unwrap().idle = actor;
                    self.soldier_mut(mate as u32).unwrap().idle = other;
                    last_chat[side] = now;
                    events.push(Event::Banter);
                } else {
                    let s = self.soldier_mut(id).unwrap();
                    if let Some(text) = s.idle.solo(now, team, rng)? {
                        if s.vitals.speech_cooldown <= 0.0 {
                            s.vitals.speech_cooldown = 2.6;
                            events.push(Event::Speech(text.into()));
                        }
                    }
                }
            }
        }
        Ok(events)
    }
}
