//! Supply trucks deliver once, turn home, and report enemy roadblocks without a scene callback.
use crate::actors::Actor;
use crate::battle_stats::DELIVERED;
use crate::vector::{normalized, Vector3};
use crate::vehicle_motion::GroundProfile;
use crate::vehicle_movement_world::Event as Movement;
use crate::vehicle_world::Event;
use crate::world::WorldContext;

fn flat(v: Vector3) -> Vector3 {
    Vector3::new(v.x, 0.0, v.z)
}
impl WorldContext<'_> {
    fn road_blocked(&self, id: u32) -> Result<bool, &'static str> {
        let v = self.actors.vehicle(id).ok_or("missing supply truck")?;
        if v.route.len() < 2
            || flat(v.route[0] - v.position).length() < 14.0
            || flat(*v.route.last().unwrap() - v.position).length() < 14.0
        {
            return Ok(false);
        }
        let next = v.route[(v.route_index as usize).min(v.route.len() - 1)];
        let dir = flat(next - v.position);
        let ahead = v.position
            + if dir.length() > 0.5 {
                normalized(dir)
            } else {
                Vector3::new(-libm::sin(v.yaw) as f32, 0.0, -libm::cos(v.yaw) as f32)
            } * 4.0;
        for sid in self
            .actors
            .structures_near(&self.geometry.structures, ahead, 3.0, false)?
        {
            let st = self.actors.structure(sid).unwrap();
            if !st.gone
                && st.team >= 0
                && st.team != v.team
                && matches!(
                    st.kind.as_str(),
                    "tank_trap"
                        | "concrete_wall"
                        | "hesco"
                        | "ammo_cache"
                        | "barracks"
                        | "factory"
                        | "research"
                        | "medic_tent"
                )
                && f64::from(flat(st.position - ahead).length()) < st.radius + 1.5
            {
                return Ok(true);
            }
        }
        Ok(self
            .actors
            .units_near(self.units, ahead, 3.0, -1)?
            .into_iter()
            .any(|other| {
                other != id && self.actors.vehicle(other).is_some_and(|o| o.team != v.team)
            }))
    }
    fn truck_arrived(
        &mut self,
        id: u32,
        fallback: i32,
        income: &mut [Vec<(f64, i32)>; 2],
        out: &mut Vec<Event>,
    ) -> Result<(), &'static str> {
        let v = self.actors.vehicle(id).unwrap();
        let (team, town, destination) = (v.team, v.source_town, v.destination_fob);
        let load = if v.cargo > 0 { v.cargo } else { fallback };
        self.actors.vehicle_mut(id).unwrap().cargo = 0;
        let Some(Actor::Structure(fob)) = self
            .actors
            .get_mut(destination)
            .filter(|a| matches!(a, Actor::Structure(s) if !s.gone && s.team == team))
        else {
            return Ok(());
        };
        fob.supply += f64::from(load);
        let position = fob.position + Vector3::Y * 4.0;
        if town == 0 {
            fob.supply_status = "OK".into();
        }
        out.push(Event::Movement(Movement::Stat(if town != 0 {
            "town_truck_delivered"
        } else {
            "truck_delivered"
        })));
        self.battle.add(0, team, DELIVERED, f64::from(load))?;
        if let Some(Actor::Structure(st)) = self.actors.get_mut(town) {
            if !st.gone && st.truck == id {
                st.supply_status = "OK".into();
            }
        }
        if (0..=1).contains(&team) {
            income[team as usize].push((self.now, load));
        }
        out.push(Event::Delivered {
            team,
            position,
            amount: load,
        });
        Ok(())
    }
    fn truck_home(&mut self, id: u32, out: &mut Vec<Event>) -> Result<(), &'static str> {
        let v = self.actors.vehicle(id).unwrap();
        let town = v.source_town;
        if let Some(Actor::Structure(st)) =
            self.actors
                .get_mut(if town != 0 { town } else { v.destination_fob })
        {
            if !st.gone && (town == 0 || st.truck == id) {
                st.truck = 0;
                st.truck_timer = 4.0;
            }
        }
        let mut loss = vec![];
        self.retire(id, &mut loss)?;
        out.extend(loss.into_iter().map(Event::Loss));
        Ok(())
    }
    fn truck_blocked(&mut self, id: u32, out: &mut Vec<Event>) {
        let v = self.actors.vehicle(id).unwrap();
        let (town, team, position) = (v.source_town != 0, v.team, v.position);
        let destination = if town {
            v.source_town
        } else {
            v.destination_fob
        };
        if let Some(Actor::Structure(st)) = self.actors.get_mut(destination) {
            if !st.gone && (!town || st.truck == id) && st.supply_status != "Road blocked" {
                st.supply_status = "Road blocked".into();
                out.push(Event::RoadBlocked {
                    vehicle: id,
                    destination,
                    town,
                    team,
                    position,
                    name: st.name.clone(),
                });
            }
        }
    }
    pub fn advance_supply_truck(
        &mut self,
        id: u32,
        dt: f64,
        profile: GroundProfile,
        fallback_load: i32,
        income: &mut [Vec<(f64, i32)>; 2],
    ) -> Result<Vec<Event>, &'static str> {
        if !crate::infantry_fight_world::valid_step(dt, self.now, None)
            || dt > 10.0
            || !profile.valid()
            || !profile.supply
            || !(0..=1_000_000).contains(&fallback_load)
            || income.iter().any(|side| side.len() >= 100_000)
        {
            return Err("invalid supply truck update");
        }
        if let Some(out) = self.begin_vehicle(id, dt)? {
            return Ok(out);
        }
        let mut out = vec![];
        let v = self.actors.vehicle(id).unwrap();
        if v.route_index as usize >= v.route.len() {
            if v.returning {
                self.truck_home(id, &mut out)?;
            } else {
                self.truck_arrived(id, fallback_load, income, &mut out)?;
                let v = self.actors.vehicle_mut(id).unwrap();
                v.returning = true;
                v.route.reverse();
                v.route_index = 1;
                v.speed = 0.0;
            }
        } else if self.road_blocked(id)? {
            let v = self.actors.vehicle_mut(id).unwrap();
            v.blocked_timer += dt;
            v.speed = 0.0;
            v.velocity = Vector3::ZERO;
            if v.blocked_timer > 5.0 {
                self.truck_blocked(id, &mut out);
            }
        } else {
            self.actors.vehicle_mut(id).unwrap().blocked_timer = 0.0;
            let traffic = self.vehicle_traffic();
            let v = self.actors.vehicle_mut(id).unwrap();
            v.follow_truck_route(
                dt,
                profile,
                &self.geometry.navigation.planner,
                &self.geometry.terrain,
                &traffic,
                &self.geometry.deck,
            )?;
            self.geometry.refresh_vehicle_collision(v, profile.hull)?;
        }
        if let Some(v) = self.actors.vehicle_mut(id) {
            v.update_flags(self.now, false, false)?;
        }
        Ok(out)
    }
}
