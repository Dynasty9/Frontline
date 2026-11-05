//! Reserves and replacement trucks enter the same actor registry as player purchases.
use crate::actors::Actor;
use crate::command_ownership::Ownership;
use crate::economy::Economy;
use crate::entities::Kind;
use crate::infantry_vitals::Life;
use crate::squad_birth::{Definition as Squad, Spawn};
use crate::squad_movement;
use crate::supply_network::SupplyNetwork;
use crate::vector::Vector3;
use crate::vehicle_birth;
use crate::world::WorldContext;

#[derive(Clone, Debug, PartialEq)]
pub enum Event {
    Truck {
        id: u32,
        town: u32,
    },
    Reserves {
        squad: u32,
        team: i8,
        depot: Vector3,
    },
    Movement(squad_movement::Event),
}
#[derive(Clone, Copy)]
pub struct TruckProfile<'a> {
    pub vehicle: vehicle_birth::Definition<'a>,
    pub town_load: [i32; 2],
    pub town_stock: [f64; 2],
    pub supply: [i32; 2],
}
impl WorldContext<'_> {
    pub fn dispatch_supply(
        &mut self,
        dt: f64,
        network: &SupplyNetwork,
        p: TruckProfile<'_>,
    ) -> Result<Vec<Event>, &'static str> {
        if !crate::infantry_fight_world::valid_step(dt, self.now, None)
            || !network.valid()
            || !p.vehicle.valid()
            || p.vehicle.kind != "truck"
            || p.town_load
                .iter()
                .chain(&p.supply)
                .any(|n| !(0..=1_000_000).contains(n))
            || p.town_stock
                .iter()
                .any(|v| !v.is_finite() || !(0.0..=1e12).contains(v))
        {
            return Err("invalid supply dispatch");
        }
        let mut out = vec![];
        let fobs: Vec<_> = self
            .actors
            .simulated_structures()
            .iter()
            .filter_map(|&id| self.actors.structure(id))
            .filter(|s| s.kind == "fob" && s.built && s.team >= 0)
            .map(|s| s.id)
            .collect();
        // Town lorries take their stock before FOB replacements get an identity.
        for (id, town) in network
            .towns
            .iter()
            .map(|&id| (id, true))
            .chain(fobs.into_iter().map(|id| (id, false)))
        {
            let Some(st) = self.actors.structure(id).filter(|s| !s.gone && s.team >= 0) else {
                continue;
            };
            if st.truck != 0 && self.actors.vehicle(st.truck).is_some_and(|v| !v.gone) {
                continue;
            }
            let Some(Actor::Structure(st)) = self.actors.get_mut(id) else {
                unreachable!()
            };
            st.truck = 0;
            st.truck_timer -= dt;
            if st.truck_timer > 0.0 {
                continue;
            }
            let (team, variant, parent, stock) = (
                st.team,
                st.variant.clamp(0, 1) as usize,
                st.supply_parent,
                st.supply,
            );
            let route = if town {
                st.road.clone()
            } else {
                network.route_to(self.actors, id)
            };
            let parent_ok = !town
                || self
                    .actors
                    .structure(parent)
                    .is_some_and(|s| !s.gone && s.team == team);
            let Some(Actor::Structure(st)) = self.actors.get_mut(id) else {
                unreachable!()
            };
            if !parent_ok || route.len() < 2 {
                st.truck_timer = 8.;
                continue;
            }
            if town && stock < f64::from(p.town_load[variant]) && stock < p.town_stock[variant] - 1.
            {
                st.truck_timer = 3.;
                continue;
            }
            let load = if town {
                (stock as i32).min(p.town_load[variant] * 2)
            } else {
                p.supply[team as usize]
            };
            if town {
                st.supply -= f64::from(load);
            }
            let dir = route[1] - route[0];
            let vehicle = self.geometry.spawn_vehicle(
                self.actors,
                vehicle_birth::Spawn {
                    team,
                    owner: -1 - i32::from(team),
                    position: route[0],
                    yaw: libm::atan2(-f64::from(dir.x), -f64::from(dir.z)),
                },
                p.vehicle,
            )?;
            let v = self.actors.vehicle_mut(vehicle).unwrap();
            v.route = route;
            v.route_index = 1;
            v.destination_fob = if town { parent } else { id };
            v.source_town = if town { id } else { 0 };
            v.cargo = load;
            let Some(Actor::Structure(st)) = self.actors.get_mut(id) else {
                unreachable!()
            };
            st.truck = vehicle;
            st.supply_status = "Truck en route".into();
            out.push(Event::Truck {
                id: vehicle,
                town: if town { id } else { 0 },
            });
        }
        Ok(out)
    }
    pub fn reinforce(
        &mut self,
        ready: &mut [f64; 2],
        network: &SupplyNetwork,
        economy: &Economy,
        ownership: &Ownership,
        definitions: [Squad<'_>; 2],
        scenario: bool,
        mission: bool,
    ) -> Result<Vec<Event>, &'static str> {
        if !self.now.is_finite()
            || !(0.0..=1e12 - 100.).contains(&self.now)
            || ready
                .iter()
                .any(|v| !v.is_finite() || !(0.0..=1e12).contains(v))
            || !network.valid()
            || !economy.valid()
            || !ownership.valid()
            || definitions.iter().any(|d| {
                d.kind.is_empty()
                    || d.kind.len() > 128
                    || d.name.is_empty()
                    || d.name.len() > 4096
                    || d.name.contains('\0')
                    || d.kind.contains('\0')
                    || !(1..=4096).contains(&d.members.len())
                    || d.members.iter().any(|m| !m.valid())
            })
        {
            return Err("invalid reserves update");
        }
        let mut out = vec![];
        if scenario || mission || self.now < 120. {
            return Ok(out);
        }
        for (team, definition) in definitions.into_iter().enumerate() {
            let Some(depot) = self
                .actors
                .structure(network.depots[team])
                .filter(|d| !d.gone)
            else {
                continue;
            };
            if self.now < ready[team] {
                continue;
            }
            let alive = self.actors.iter_kind(Kind::Soldier).filter(|a| matches!(a, Actor::Soldier(s) if s.identity.team == team as i8 && s.vitals.life == Life::Alive)).take(6).count();
            if alive >= 6 {
                continue;
            }
            let position = depot.position;
            let owner = ownership
                .players
                .iter()
                .find(|(_, t)| *t == team as i8)
                .map_or(-1 - team as i32, |(id, _)| *id);
            ready[team] = self.now + 75.;
            let forward = if team == 0 { -Vector3::Z } else { Vector3::Z };
            let (squad, events) = self.spawn_squad(
                Spawn {
                    team: team as i8,
                    owner,
                    position: position + forward * 14.,
                    destination: Some(position + forward * 22.),
                },
                Squad {
                    armor_upgrade: economy.has_upgrade(team as i8, "armor"),
                    grenade_upgrade: economy.has_upgrade(team as i8, "grenades"),
                    ..definition
                },
            )?;
            out.extend(events.into_iter().map(Event::Movement));
            out.push(Event::Reserves {
                squad,
                team: team as i8,
                depot: position,
            });
        }
        Ok(out)
    }
}
