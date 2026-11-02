//! Orders release shared claims and complete direct routes before the next soldier acts.
use crate::actors::Actors;
use crate::infantry_casualty::Released;
use crate::infantry_commands::{Command, Release};
use crate::navigation_scene::NavigationScene;
use crate::random::SimulationRandom;
use crate::squad::Squad;

impl Actors {
    pub(crate) fn clear_infantry_duty(
        &mut self,
        id: u32,
        nav: &crate::path_planner::PathPlanner,
        squads: &mut [Squad],
    ) -> Result<(), &'static str> {
        let s = self.soldier(id).ok_or("missing assigned soldier")?;
        let mount = self
            .structure(s.emplacement.structure as u32)
            .map(|st| st.position);
        let release = self.soldier_mut(id).unwrap().clear_duty(nav, mount);
        self.release_duty_claim(id, release, squads);
        Ok(())
    }
    fn release_duty_claim(&mut self, id: u32, release: Option<Release>, squads: &mut [Squad]) {
        match release {
            Some(Release::Rescue(patient)) => self.release_links(
                id,
                Released {
                    patient,
                    ..Default::default()
                },
            ),
            Some(Release::Breach(squad)) => {
                if let Some(q) = squads
                    .iter_mut()
                    .find(|q| q.id == squad && q.breach_by == id)
                {
                    q.breach_by = 0;
                }
            }
            None => (),
        }
    }
    pub fn command_infantry(
        &mut self,
        id: u32,
        command: Command,
        navigation: &mut NavigationScene,
        squads: &mut [Squad],
        now: f64,
        rng: &mut SimulationRandom,
    ) -> Result<bool, &'static str> {
        if !now.is_finite() || now.abs() > 1e12 - 100.0 {
            return Err("invalid infantry command time");
        }
        let s = self.soldier(id).ok_or("missing commanded soldier")?;
        let mount = self
            .structure(s.emplacement.structure as u32)
            .map(|st| st.position);
        let ordered = self
            .soldier_mut(id)
            .unwrap()
            .command(command, &navigation.planner, mount)?;
        self.release_duty_claim(id, ordered.release, squads);
        if ordered.cancel_path {
            navigation.planner.cancel(u64::from(id));
        }
        if let Some(route) = ordered.route {
            navigation.submit_infantry(self.soldier_mut(id).unwrap(), route, now, rng)?;
        }
        Ok(ordered.accepted)
    }
}
