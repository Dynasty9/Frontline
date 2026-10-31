//! Attack helicopters circle their target while keeping the nose and chin gun on it.
use crate::terrain::Terrain;
use crate::vector::Vector3;
use crate::vehicle::Vehicle;
use crate::vehicle_flight::FlightProfile;

fn flat(p: Vector3) -> Vector3 {
    Vector3::new(p.x, 0.0, p.z)
}
fn point(p: Vector3) -> bool {
    p.is_finite() && p.abs().max_element() <= 1_000_000.0
}
impl Vehicle {
    pub fn gunship_begin(&mut self, dt: f64) -> Result<bool, &'static str> {
        if !dt.is_finite()
            || !(0.0..=3600.0).contains(&dt)
            || (self.scan_timer - dt).abs() > 1e12
            || (self.rocket_timer - dt).abs() > 1e12
        {
            return Err("invalid gunship clocks");
        }
        self.scan_timer -= dt;
        self.rocket_timer -= dt;
        let scan = self.scan_timer <= 0.0;
        if scan {
            self.scan_timer = 0.4;
        }
        Ok(scan)
    }
    pub fn gunship_guidance(
        &mut self,
        dt: f64,
        target: Option<Vector3>,
        p: FlightProfile,
        terrain: &Terrain,
        deck: &[u8],
    ) -> Result<(), &'static str> {
        if !dt.is_finite() || !(0.0..=3600.0).contains(&dt) || target.is_some_and(|v| !point(v)) {
            return Err("invalid gunship target");
        }
        let mut goal = Vector3::new(self.position.x, 14.0, self.position.z);
        let mut face = None;
        if let Some(target) = target {
            let to = flat(self.position - target);
            let angle = libm::atan2(f64::from(to.z), f64::from(to.x)) + dt * 0.22;
            let radius = to.length().clamp(60.0, 75.0);
            goal = target
                + Vector3::new(libm::cos(angle) as f32, 0.0, libm::sin(angle) as f32) * radius;
            if let Some(destination) = self.gunship_destination {
                if flat(target - destination).length() > 110.0 {
                    goal = destination;
                }
            }
            let toward = flat(target - self.position);
            face = Some(libm::atan2(-f64::from(toward.x), -f64::from(toward.z)));
        } else if let Some(destination) = self.gunship_destination {
            goal = destination;
        }
        goal.y = if self.hp > self.max_hp * 0.25 {
            14.0
        } else {
            (14.0f64 * 0.7) as f32
        };
        self.fly_to(goal, dt, face, p, terrain, deck)?;
        Ok(())
    }
    pub fn gunship_rockets_due(
        &mut self,
        target: Option<Vector3>,
        worth: bool,
        rockets: i32,
    ) -> Result<bool, &'static str> {
        if target.is_some_and(|p| !point(p)) || !(0..=10000).contains(&rockets) {
            return Err("invalid gunship salvo target");
        }
        let Some(target) = target else {
            return Ok(false);
        };
        if self.rocket_timer <= 0.0
            && self.aim_error(Some(target)) < 0.35
            && worth
            && flat(target - self.position).length() < 100.0
            && rockets > 0
        {
            self.rocket_timer = 9.0;
            Ok(true)
        } else {
            Ok(false)
        }
    }
}
