//! Sling transport updates the helicopter and its load in the same actor collection.
use crate::actors::Actors;
use crate::path_planner::PathPlanner;
use crate::vector::Vector3;

#[derive(Clone, Copy, Debug)]
pub struct SlingSpec {
    pub lift: bool,
    pub capacity: i8,
    pub cargo_weight: u8,
    pub cargo_helicopter: bool,
    pub cargo_boat: bool,
    pub cargo_automatic: bool,
}
impl SlingSpec {
    fn valid(self) -> bool {
        (-1..=2).contains(&self.capacity) && self.cargo_weight <= 2
    }
}
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct SlingDrop {
    pub position: Vector3,
    pub damage: f64,
    pub impact: bool,
}
impl Actors {
    pub fn can_sling(
        &self,
        helicopter: u32,
        cargo: u32,
        spec: SlingSpec,
    ) -> Result<bool, &'static str> {
        if !spec.valid() {
            return Err("invalid sling capacity");
        }
        let h = self.vehicle(helicopter).ok_or("missing helicopter")?;
        let Some(v) = self.vehicle(cargo) else {
            return Ok(false);
        };
        Ok(spec.lift
            && spec.capacity >= 0
            && helicopter != cargo
            && !v.gone
            && v.team == h.team
            && !spec.cargo_helicopter
            && !spec.cargo_boat
            && !spec.cargo_automatic
            && spec.cargo_weight as i8 <= spec.capacity
            && v.slung_by == 0
            && h.sling_cargo == 0)
    }
    pub fn order_sling(
        &mut self,
        helicopter: u32,
        cargo: u32,
        spec: SlingSpec,
    ) -> Result<bool, &'static str> {
        if !self.can_sling(helicopter, cargo, spec)? {
            return Ok(false);
        }
        let h = self.vehicle_mut(helicopter).unwrap();
        h.sling_target = cargo;
        h.lift_destination = None;
        h.sling_timer = 0.0;
        h.lift_phase = if h.position.y > 3.0 { 5 } else { 1 };
        Ok(true)
    }
    pub fn hook_sling(
        &mut self,
        helicopter: u32,
        cargo: u32,
        spec: SlingSpec,
    ) -> Result<bool, &'static str> {
        if !self.can_sling(helicopter, cargo, spec)? {
            return Ok(false);
        }
        let h = self.vehicle_mut(helicopter).unwrap();
        h.sling_target = 0;
        h.sling_cargo = cargo;
        h.swing = Vector3::ZERO;
        h.lift_phase = 1;
        let v = self.vehicle_mut(cargo).unwrap();
        v.slung_by = helicopter;
        v.path.clear();
        v.path_index = 0;
        v.speed = 0.0;
        v.velocity = Vector3::ZERO;
        v.assault = false;
        Ok(true)
    }
    pub fn step_sling(
        &mut self,
        helicopter: u32,
        dt: f64,
        height: f64,
    ) -> Result<bool, &'static str> {
        if !dt.is_finite()
            || !(0.0..=3600.0).contains(&dt)
            || !height.is_finite()
            || !(0.0..=1000.0).contains(&height)
        {
            return Err("invalid sling step");
        }
        let h = self.vehicle(helicopter).ok_or("missing helicopter")?;
        let cargo = h.sling_cargo;
        if cargo == 0 {
            return Ok(false);
        }
        if cargo == helicopter {
            return Err("self-linked sling");
        }
        if self.vehicle(cargo).is_none_or(|v| v.gone) {
            self.vehicle_mut(helicopter).unwrap().sling_cargo = 0;
            return Ok(false);
        }
        let h = self.vehicle_mut(helicopter).unwrap();
        let trail = -h.velocity * 0.09;
        h.swing += (trail - h.swing) * (1.0 - libm::exp(-dt * 1.6)) as f32;
        let position = h.position + Vector3::new(h.swing.x, (-7.0 - height) as f32, h.swing.z);
        let velocity = h.velocity;
        let yaw = h.yaw;
        let v = self.vehicle_mut(cargo).unwrap();
        v.position = position;
        let difference = (yaw - v.yaw) % std::f64::consts::TAU;
        let distance = (2.0 * difference) % std::f64::consts::TAU - difference;
        v.yaw = f64::from((v.yaw + distance * (1.0 - libm::exp(-dt * 0.8))) as f32);
        v.velocity = velocity;
        Ok(true)
    }
    pub fn release_sling(
        &mut self,
        helicopter: u32,
        nav: &PathPlanner,
    ) -> Result<Option<u32>, &'static str> {
        let cargo = self
            .vehicle(helicopter)
            .ok_or("missing helicopter")?
            .sling_cargo;
        if cargo == helicopter {
            return Err("self-linked sling");
        }
        let position = self
            .vehicle(cargo)
            .filter(|v| !v.gone)
            .map(|v| Vector3::new(v.position.x, 0.0, v.position.z));
        if let Some(position) = position {
            let position = nav
                .nearest_walkable_for(position, true)
                .ok_or("invalid cargo position")?;
            let v = self.vehicle_mut(cargo).unwrap();
            v.slung_by = 0;
            v.position = position;
            v.velocity = Vector3::ZERO;
        }
        self.vehicle_mut(helicopter).unwrap().sling_cargo = 0;
        Ok(position.map(|_| cargo))
    }
    pub fn drop_sling(&mut self, cargo: u32, nav: &PathPlanner) -> Result<SlingDrop, &'static str> {
        let v = self.vehicle(cargo).ok_or("missing cargo")?;
        let height = f64::from(v.position.y);
        let position = nav
            .nearest_walkable_for(Vector3::new(v.position.x, 0.0, v.position.z), true)
            .ok_or("invalid cargo position")?;
        let damage = if height > 3.0 {
            v.max_hp * (height / 30.0).clamp(0.15, 0.9)
        } else {
            0.0
        };
        let v = self.vehicle_mut(cargo).unwrap();
        v.slung_by = 0;
        v.position = position;
        v.velocity = Vector3::ZERO;
        Ok(SlingDrop {
            position,
            damage,
            impact: height > 3.0,
        })
    }
}
