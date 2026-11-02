//! Completed actions update routes, doors and battle credit before the next actor runs.
use crate::infantry_action::Action;
use crate::infantry_action_owned::{Defense, Event as Ordnance};
use crate::infantry_fight_world::Event;
use crate::infantry_travel_owned::Event as Movement;
use crate::infantry_vitals::Life;
use crate::vehicle::Vehicle;
use crate::vehicle_loss_world::Context;
use crate::world_combat;

impl Context<'_> {
    pub fn advance_infantry_action<'a>(
        &mut self,
        id: u32,
        warhead: f64,
        defense: &dyn Fn(&Vehicle) -> Defense<'a>,
    ) -> Result<Vec<Event>, &'static str> {
        let s = self.actors.soldier(id).ok_or("missing acting infantry")?;
        if s.vitals.life != Life::Alive {
            return Err("acting infantry is not alive");
        }
        let victim = match s.action.current {
            Action::Melee { target } => self
                .actors
                .soldier(target as u32)
                .map(|s| (self.man)(s, self.squads)),
            _ => None,
        };
        // Capture the victim's profile before damage can release claims or a mount.
        let completed = self.actors.complete_infantry_action(
            id,
            self.now,
            warhead,
            self.squads,
            self.units,
            &self.geometry.navigation.planner,
            |_| victim.map_or((None, false), |p| (p.ammunition, p.bearer)),
            defense,
            self.rng,
            crate::traversal::Ground::new(&self.geometry.terrain, &self.geometry.deck),
        )?;
        let mut out = vec![];
        if completed.cancel_path {
            self.geometry.navigation.planner.cancel(u64::from(id));
        }
        if let Some(cue) = completed.speech {
            out.push(Event::Speech {
                id,
                text: [
                    "Frag out!",
                    "Grenade out!",
                    "Fire in the hole!",
                    "Throwing it back!",
                ][cue as usize]
                    .into(),
            });
        }
        for event in &completed.events {
            match event {
                Ordnance::Door(door) => self.apply_infantry_movement(
                    id,
                    Movement::Door {
                        id: *door,
                        kicked: true,
                    },
                )?,
                Ordnance::Melee { target, hit, .. } => {
                    Self::record_infantry_hit(
                        self.battle,
                        self.actors,
                        *target,
                        hit,
                        victim.ok_or("missing melee victim profile")?,
                        self.role,
                    )?;
                    if hit.released.is_some() {
                        self.geometry.navigation.planner.cancel(u64::from(*target));
                    }
                    out.push(Event::World(world_combat::Event::InfantryHit {
                        id: *target,
                        hit: hit.clone(),
                    }));
                }
                _ => {}
            }
        }
        self.apply_ordnance(completed, &mut out)?;
        Ok(out)
    }
}
