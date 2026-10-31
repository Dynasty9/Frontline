//! Hidden soldiers follow retained transport, leave tunnels and recover in tents.
use crate::actors::{Actor, Actors};
use crate::infantry::{Goal, Infantry};
use crate::infantry_control::Hidden;
use crate::infantry_controller::Task;
use crate::infantry_orders::RouteOrder;
use crate::infantry_vitals::Life;
use crate::path_planner::PathPlanner;
use crate::random::SimulationRandom;
use crate::squad::Squad;
use crate::vector::Vector3;

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum Event {
    Stat(&'static str),
    Revived(u8),
    Route(RouteOrder),
    PatchedUp,
}
#[derive(Clone, Debug, Default, PartialEq)]
pub struct Update {
    pub events: Vec<Event>,
    pub removed: Option<Box<Infantry>>,
}

impl Actors {
    pub fn advance_infantry_hidden(
        &mut self,
        id: u32,
        dt: f64,
        restored_weapon: Option<(&str, i32)>,
        nav: &PathPlanner,
        squads: &mut [Squad],
        rng: &mut SimulationRandom,
    ) -> Result<Update, &'static str> {
        if !dt.is_finite()
            || !(0.0..=10.0).contains(&dt)
            || restored_weapon.is_some_and(|(k, n)| {
                k.is_empty() || k.len() > 128 || k.contains('\0') || !(0..=1_000_000).contains(&n)
            })
        {
            return Err("invalid hidden infantry context");
        }
        let s = self.soldier(id).ok_or("missing hidden infantry")?;
        if s.vitals.life != Life::Hidden {
            return Err("infantry is not hidden");
        }
        let vehicle = self.vehicle(s.links.vehicle as u32).map(|v| v.position);
        let decision = self.soldier_mut(id).unwrap().hidden_tick(dt, vehicle)?;
        let mut out = Update::default();
        match decision {
            Hidden::Wait | Hidden::FollowVehicle(_) => {}
            Hidden::BailOut => {
                let s = self.soldier_mut(id).unwrap();
                s.links.vehicle = 0;
                s.unhide(s.motion.position, nav)?;
            }
            Hidden::LeaveTunnel => {
                let s = self.soldier(id).unwrap();
                let tunnel = s.links.hidden_in as u32;
                let destination = s.duty.position;
                if let Some(Actor::Structure(st)) = self.get_mut(tunnel) {
                    st.inside.retain(|&who| who != id);
                }
                self.soldier_mut(id).unwrap().unhide(destination, nav)?;
            }
            Hidden::LeaveTent => {
                let s = self.soldier(id).unwrap();
                let exit = self.structure(s.links.hidden_in as u32).map(|st| st.exit());
                out.events.push(Event::Stat("out_of_tent"));
                let s = self.soldier_mut(id).unwrap();
                s.vitals.life = Life::Alive;
                let cue = s.revive(true, restored_weapon, rng)?;
                out.events.push(Event::Revived(cue));
                s.unhide(exit.unwrap_or(s.motion.position), nav)?;
                let s = self.soldier(id).unwrap();
                let destination = self
                    .nearest_fob(s.identity.team, s.motion.position)
                    .map(|st| st.position);
                let s = self.soldier_mut(id).unwrap();
                s.duty.kind = Task::Limp;
                let destination = destination.map_or(s.motion.position, |p| {
                    p + Vector3::new(rng.randf_range(-5.0, 5.0), 0.0, rng.randf_range(-5.0, 5.0))
                });
                out.events
                    .push(Event::Route(s.go_to(destination, Goal::Task, 0)?));
                out.events.push(Event::PatchedUp);
            }
            Hidden::PrisonerDone => {
                let qid = self.soldier(id).unwrap().identity.squad;
                if let Some(q) = squads.iter_mut().find(|q| q.id == qid) {
                    // World despawn removes membership without refreshing the cached centroid.
                    q.members.retain(|&who| who != id);
                }
                let Some(Actor::Soldier(mut s)) = self.remove(id) else {
                    unreachable!()
                };
                s.identity.gone = true;
                out.removed = Some(s);
            }
        }
        Ok(out)
    }
}
