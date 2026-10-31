//! Transport pilots retain their flight phases; shared cargo effects run in tick order.
use crate::terrain::Terrain;
use crate::vector::Vector3;
use crate::vehicle::Vehicle;
use crate::vehicle_flight::FlightProfile;

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum LiftEvent {
    None,
    Hook(u32),
    Release,
    Dismount,
}
#[derive(Clone, Copy, Debug)]
pub struct SlingTarget {
    pub id: u32,
    pub position: Vector3,
    pub height: f64,
}
#[derive(Clone, Copy, Debug)]
pub struct SupplyPoint {
    pub id: u32,
    pub position: Vector3,
    pub supply: f64,
}
#[derive(Clone, Copy, Debug)]
pub struct HomeLanding {
    pub position: Vector3,
    pub landing: Vector3,
}
fn point(p: Vector3) -> bool {
    p.is_finite() && p.abs().max_element() <= 1_000_000.0
}
fn flat(p: Vector3) -> Vector3 {
    Vector3::new(p.x, 0.0, p.z)
}
fn ground(p: Vector3, terrain: &Terrain, deck: &[u8]) -> f64 {
    terrain
        .ground_y(p, !deck.is_empty() && deck[terrain.index(p)] != 0)
        .max(0.0)
        + 0.15
}
fn validate(v: &Vehicle, dt: f64, p: FlightProfile, terrain: &Terrain, deck: &[u8]) -> bool {
    dt.is_finite()
        && (0.0..=3600.0).contains(&dt)
        && p.valid()
        && v.flight.is_some()
        && (deck.is_empty() || deck.len() == terrain.n * terrain.n)
}
impl Vehicle {
    pub fn lift_guidance(
        &mut self,
        dt: f64,
        p: FlightProfile,
        terrain: &Terrain,
        deck: &[u8],
        cargo_height: f64,
        target: Option<SlingTarget>,
        home_landing: Option<HomeLanding>,
    ) -> Result<LiftEvent, &'static str> {
        if !validate(self, dt, p, terrain, deck)
            || !cargo_height.is_finite()
            || !(0.0..=1000.0).contains(&cargo_height)
            || target.is_some_and(|t| {
                t.id == 0
                    || !point(t.position)
                    || !t.height.is_finite()
                    || !(0.0..=1000.0).contains(&t.height)
            })
            || home_landing.is_some_and(|h| !point(h.position) || !point(h.landing))
            || (matches!(self.lift_phase, 2 | 3) && self.lift_destination.is_none())
            || (self.lift_phase == 7 && self.flight_hold.is_none())
        {
            return Err("invalid lift guidance");
        }
        let landed = Vector3::new(
            self.position.x,
            ground(self.position, terrain, deck) as f32,
            self.position.z,
        );
        match self.lift_phase {
            0 => {
                self.fly_to(landed, dt, None, p, terrain, deck)?;
                if self
                    .lift_destination
                    .is_some_and(|d| flat(d - self.position).length() > 0.7)
                {
                    self.lift_phase = 1;
                }
            }
            1 => {
                if self.fly_to(
                    Vector3::new(self.position.x, 16.0, self.position.z),
                    dt,
                    None,
                    p,
                    terrain,
                    deck,
                )? {
                    if self.sling_target != 0 {
                        self.lift_phase = 5;
                    } else if self.lift_destination.is_some() {
                        self.lift_phase = 2;
                    }
                }
            }
            2 => {
                let d = self.lift_destination.unwrap();
                if self.fly_to(Vector3::new(d.x, 16.0, d.z), dt, None, p, terrain, deck)? {
                    self.lift_phase = 3;
                }
            }
            3 => {
                let d = self.lift_destination.unwrap();
                let y = ground(d, terrain, deck);
                if self.sling_cargo != 0 {
                    let drop = Vector3::new(d.x, (y + cargo_height + 7.0) as f32, d.z);
                    if self.fly_to(drop, dt, None, p, terrain, deck)? {
                        self.sling_timer += dt;
                        if self.sling_timer > 1.2 {
                            self.lift_destination = None;
                            self.lift_phase = 1;
                            return Ok(LiftEvent::Release);
                        }
                    }
                } else if self.fly_to(
                    Vector3::new(d.x, y as f32, d.z),
                    dt,
                    None,
                    p,
                    terrain,
                    deck,
                )? {
                    self.lift_destination = None;
                    if !self.passengers.is_empty() {
                        self.lift_timer = 3.0;
                        self.lift_phase = 4;
                        return Ok(LiftEvent::Dismount);
                    }
                    self.lift_phase = 0;
                }
            }
            4 => {
                self.fly_to(landed, dt, None, p, terrain, deck)?;
                self.lift_timer -= dt;
                if self.lift_timer <= 0.0 {
                    self.lift_phase = 0;
                    if let Some(h) =
                        home_landing.filter(|h| flat(h.position - self.position).length() > 20.0)
                    {
                        self.lift_destination = Some(h.landing);
                    }
                }
            }
            5 | 6 => {
                let Some(t) = target.filter(|t| t.id == self.sling_target) else {
                    self.sling_target = 0;
                    self.lift_phase = 1;
                    return Ok(LiftEvent::None);
                };
                if self.lift_phase == 5 {
                    if self.fly_to(
                        Vector3::new(t.position.x, 16.0, t.position.z),
                        dt,
                        None,
                        p,
                        terrain,
                        deck,
                    )? {
                        self.sling_timer = 0.0;
                        self.lift_phase = 6;
                    }
                } else {
                    let hover = t.position + Vector3::Y * (t.height + 7.0) as f32;
                    if self.fly_to(hover, dt, None, p, terrain, deck)? {
                        self.sling_timer += dt;
                        if self.sling_timer > 1.5 {
                            return Ok(LiftEvent::Hook(t.id));
                        }
                    } else {
                        self.sling_timer = 0.0;
                    }
                }
            }
            7 => {
                self.fly_to(self.flight_hold.unwrap(), dt, None, p, terrain, deck)?;
            }
            _ => return Err("invalid lift phase"),
        }
        Ok(LiftEvent::None)
    }
    pub fn supply_guidance(
        &mut self,
        dt: f64,
        p: FlightProfile,
        terrain: &Terrain,
        deck: &[u8],
        fobs: &[SupplyPoint],
        destination: Option<SupplyPoint>,
        home: Vector3,
    ) -> Result<Option<u32>, &'static str> {
        if !validate(self, dt, p, terrain, deck)
            || !point(home)
            || fobs.len() > 100_000
            || fobs.iter().any(|f| {
                f.id == 0 || !point(f.position) || !f.supply.is_finite() || f.supply.abs() > 1e12
            })
            || destination.is_some_and(|f| f.id == 0 || !point(f.position))
            || (matches!(self.heli_phase, 3 | 6 | 7) && self.flight_hold.is_none())
        {
            return Err("invalid supply flight");
        }
        match self.heli_phase {
            0 => {
                let goal = Vector3::new(
                    self.position.x,
                    ground(self.position, terrain, deck) as f32,
                    self.position.z,
                );
                self.fly_to(goal, dt, None, p, terrain, deck)?;
                self.heli_timer -= dt;
                if self.heli_timer > 0.0 {
                    return Ok(None);
                }
                self.heli_destination = 0;
                let mut low = 1e9;
                for f in fobs {
                    let need =
                        f.supply + f64::from(flat(f.position - self.position).length()) * 0.5;
                    if need < low {
                        low = need;
                        self.heli_destination = f.id;
                    }
                }
                if self.heli_destination == 0 {
                    self.heli_timer = 5.0;
                } else {
                    self.heli_phase = 1;
                }
            }
            1 | 4 => {
                if self.fly_to(
                    Vector3::new(self.position.x, 15.0, self.position.z),
                    dt,
                    None,
                    p,
                    terrain,
                    deck,
                )? {
                    self.heli_phase += 1;
                }
            }
            2 | 5 => {
                let mut goal = home;
                if self.heli_phase == 2 {
                    let Some(f) = destination.filter(|f| f.id == self.heli_destination) else {
                        self.heli_phase = 5;
                        return Ok(None);
                    };
                    goal = f.position + Vector3::X * 9.0;
                }
                goal.y = 15.0;
                if self.fly_to(goal, dt, None, p, terrain, deck)? {
                    self.flight_hold = Some(Vector3::new(
                        goal.x,
                        ground(goal, terrain, deck) as f32,
                        goal.z,
                    ));
                    self.heli_phase += 1;
                }
            }
            3 | 6 | 7 => {
                let mut goal = self.flight_hold.unwrap();
                goal.y = ground(goal, terrain, deck) as f32;
                self.flight_hold = Some(goal);
                let settled = self.fly_to(goal, dt, None, p, terrain, deck)?;
                if self.heli_phase == 7 {
                    self.heli_timer -= dt;
                    if self.heli_timer <= 0.0 {
                        self.heli_phase = 4;
                        return Ok(destination
                            .filter(|f| f.id == self.heli_destination)
                            .map(|f| f.id));
                    }
                } else if settled {
                    if self.heli_phase == 3 {
                        self.heli_timer = 3.0;
                        self.heli_phase = 7;
                    } else {
                        self.heli_phase = 0;
                        self.heli_timer = 12.0;
                    }
                }
            }
            _ => return Err("invalid supply phase"),
        }
        Ok(None)
    }
}
