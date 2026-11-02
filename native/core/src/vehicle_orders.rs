//! Vehicle orders choose landing sites and submit routes against the retained battlefield.
use crate::boat_navigation::BoatNavigation;
use crate::squad_movement::point;
use crate::vector::Vector3;
use crate::vehicle::Route;
use crate::vehicle_loss_world::Context;

#[derive(Clone, Copy, Debug)]
pub enum Order {
    Move(Vector3),
    Assault(Vector3),
    Attack(u32),
    Stop,
}
impl Context<'_> {
    pub fn order_vehicle(
        &mut self,
        id: u32,
        order: Order,
        boats: &mut BoatNavigation,
    ) -> Result<(), &'static str> {
        if matches!(order, Order::Move(p) | Order::Assault(p) if !point(p)) {
            return Err("invalid vehicle order position");
        }
        let v = self.actors.vehicle(id).ok_or("missing ordered vehicle")?;
        let profile = (self.vehicle)(v);
        let base = profile.crew.base;
        let route = match order {
            Order::Move(p) | Order::Assault(p) => {
                if v.crew_busy() {
                    return Ok(());
                }
                let landing = if base == "lift_heli" {
                    self.landing_spot(p)?
                } else {
                    p
                };
                let v = self.actors.vehicle_mut(id).unwrap();
                if matches!(order, Order::Assault(_)) {
                    v.order_assault(p, base, landing)?
                } else {
                    v.order_move(p, base, landing)?
                }
            }
            Order::Attack(target) => {
                let Some(t) = self.actors.get(target) else {
                    return Ok(());
                };
                let p = t.position();
                self.actors
                    .vehicle_mut(id)
                    .unwrap()
                    .order_attack(target, p, base)?
            }
            Order::Stop => {
                self.actors
                    .vehicle_mut(id)
                    .unwrap()
                    .order_stop(base, profile.crew.automatic)?;
                self.geometry.navigation.planner.cancel(u64::from(id));
                Route::None
            }
        };
        let v = self.actors.vehicle_mut(id).unwrap();
        match route {
            Route::None => (),
            Route::Boat { destination } => {
                v.complete_boat_path(boats.path(v.position, destination))?
            }
            Route::Ground {
                destination,
                care,
                revision,
            } => {
                self.geometry
                    .navigation
                    .submit_vehicle(v, destination, care, revision)?;
            }
        }
        Ok(())
    }
}
