//! A completed order creates its forces and rally routes before another building checks capacity.
use crate::actors::Actor;
use crate::battle_stats::Unit;
use crate::boat_navigation::BoatNavigation;
use crate::command_ownership::Ownership;
use crate::economy::{self, Economy};
use crate::squad_birth::{self, Definition as Squad};
use crate::squad_movement;
use crate::structure::{Tick, TownEconomy};
use crate::vector::Vector3;
use crate::vehicle::{Route, Vehicle};
use crate::vehicle_birth;
use crate::world::WorldContext;

pub enum Product<'a> {
    Squad(Squad<'a>),
    Vehicle {
        definition: vehicle_birth::Definition<'a>,
        name: &'a str,
        cap: u32,
        air: bool,
        supply: bool,
        automatic: bool,
        passengers: Option<Squad<'a>>,
    },
    Research {
        key: &'a str,
        name: &'a str,
    },
}
pub struct Profiles<'a> {
    pub product: Option<Product<'a>>,
    pub base_cap: u32,
    pub cap_per_fob: u32,
    pub vehicle_cap: &'a dyn Fn(&Vehicle) -> u32,
}
#[derive(Clone, Debug, PartialEq)]
pub enum Event {
    CapWarning { peer: i32, team: i8 },
    Squad(u32),
    Vehicle(u32),
    Research { team: i8, name: String },
    Ready { team: i8, name: String },
    Movement(squad_movement::Event),
}
fn text(s: &str, max: usize) -> bool {
    !s.is_empty() && s.len() <= max && !s.contains('\0')
}
fn valid_squad(q: &Squad<'_>) -> bool {
    text(q.kind, 128)
        && text(q.name, 4096)
        && (1..=4096).contains(&q.members.len())
        && q.members.iter().all(|m| m.valid())
}
impl Product<'_> {
    fn valid(&self) -> bool {
        match self {
            Self::Squad(q) => valid_squad(q),
            Self::Vehicle {
                definition,
                name,
                cap,
                passengers,
                ..
            } => {
                definition.valid()
                    && text(name, 4096)
                    && *cap <= 1_000_000
                    && passengers.as_ref().is_none_or(valid_squad)
            }
            Self::Research { key, name } => text(key, 128) && text(name, 4096),
        }
    }
    fn key(&self) -> &str {
        match self {
            Self::Squad(q) => q.kind,
            Self::Vehicle { definition, .. } => definition.kind,
            Self::Research { key, .. } => key,
        }
    }
    fn name(&self) -> &str {
        match self {
            Self::Squad(q) => q.name,
            Self::Vehicle { name, .. } | Self::Research { name, .. } => name,
        }
    }
    fn cap(&self) -> u64 {
        match self {
            Self::Squad(q) => q.members.len() as u64,
            Self::Vehicle { cap, .. } => u64::from(*cap),
            Self::Research { .. } => 0,
        }
    }
}
fn upgrades<'a>(q: Squad<'a>, team: i8, economy: &Economy) -> Squad<'a> {
    Squad {
        armor_upgrade: economy.has_upgrade(team, "armor"),
        grenade_upgrade: economy.has_upgrade(team, "grenades"),
        ..q
    }
}
impl WorldContext<'_> {
    pub fn advance_production(
        &mut self,
        id: u32,
        dt: f64,
        p: Profiles<'_>,
        economy: &mut Economy,
        ownership: &mut Ownership,
        boats: &mut BoatNavigation,
    ) -> Result<Vec<Event>, &'static str> {
        let st = self
            .actors
            .structure(id)
            .filter(|s| !s.gone)
            .ok_or("missing production building")?;
        if !crate::infantry_fight_world::valid_step(dt, self.now, None)
            || !matches!(
                st.kind.as_str(),
                "barracks" | "factory" | "research" | "helipad" | "dock"
            )
            || !economy.valid()
            || !ownership.valid()
            || p.base_cap > 1_000_000
            || p.cap_per_fob > 1_000_000
            || boats.half() != self.geometry.terrain.half()
            || p.product.as_ref().is_some_and(|v| !v.valid())
            || st.queue.first().is_some_and(|q| {
                p.product.as_ref().is_none_or(|v| {
                    v.key() != q.item
                        || matches!(v, Product::Research { .. }) != (st.kind == "research")
                })
            })
        {
            return Err("invalid production update");
        }
        let team = st.team;
        let peer = st.queue.first().map_or(0, |q| q.owner);
        let has_cap = st.kind == "research"
            || p.product.as_ref().is_none_or(|item| {
                economy::used(
                    self.actors,
                    team,
                    &|s| (self.movement)(s).bearer,
                    p.vehicle_cap,
                ) + item.cap()
                    <= economy::capacity(self.actors, team, p.base_cap, p.cap_per_fob)
            });
        let Some(Actor::Structure(st)) = self.actors.get_mut(id) else {
            unreachable!()
        };
        if st.begin_tick(
            dt,
            TownEconomy {
                stock: 0.,
                yield_per_minute: 0.,
                capture_pace: 0.,
            },
        )? == Tick::None
        {
            return Ok(vec![]);
        }
        let produced = st.produce(dt, has_cap)?;
        let mut out = vec![];
        if produced.cap_warning {
            out.push(Event::CapWarning { peer, team });
        }
        let Some(order) = produced.item else {
            return Ok(out);
        };
        let product = p.product.unwrap();
        let name = product.name().to_owned();
        let owner = ownership.acting_owner(order.owner, team);
        self.battle.add(
            owner,
            team,
            match &product {
                Product::Squad(_) => 15,
                Product::Research { .. } => 18,
                _ => 16,
            },
            1.,
        )?;
        if let Product::Research { key, .. } = product {
            economy.apply_upgrade(self.actors, team, key, &|s| (self.movement)(s).bearer)?;
            return Ok(vec![Event::Research { team, name }]);
        }
        let st = self.actors.structure(id).unwrap();
        let position = st.position;
        let yaw = st.yaw;
        let front = Vector3::new(-libm::sin(yaw) as f32, 0., -libm::cos(yaw) as f32);
        let exit = position + front * (f64::from(st.size.z) * 0.5 + 3.) as f32;
        let rally = st.rally;
        let size_z = st.size.z;
        let mut dest = rally.unwrap_or(exit + front * 8.);
        match product {
            Product::Squad(q) => {
                let (sid, events) = self.spawn_squad(
                    squad_birth::Spawn {
                        team,
                        owner,
                        position: exit,
                        destination: Some(dest),
                    },
                    upgrades(q, team, economy),
                )?;
                ownership.hold_squad(order.owner, sid)?;
                out.push(Event::Squad(sid));
                out.extend(events.into_iter().map(Event::Movement));
            }
            Product::Vehicle {
                definition,
                air,
                supply,
                automatic,
                passengers,
                ..
            } => {
                let mut at = if air {
                    position
                } else {
                    self.geometry
                        .navigation
                        .planner
                        .nearest_walkable_for(
                            exit + front * 2.,
                            true,
                            definition.tracked,
                            crate::traversal::Ground::new(
                                &self.geometry.terrain,
                                &self.geometry.deck,
                            ),
                        )
                        .ok_or("invalid production exit")?
                };
                if definition.base == "boat" {
                    let raw = position + front * (f64::from(size_z) * 0.5 + 16.) as f32;
                    at = boats.nearest(raw, 50., -1).unwrap_or(raw);
                    dest = rally.unwrap_or(at + front * 14.);
                }
                let vehicle = self.geometry.spawn_vehicle(
                    self.actors,
                    vehicle_birth::Spawn {
                        team,
                        owner,
                        position: at,
                        yaw,
                    },
                    definition,
                )?;
                if !automatic && definition.kind != "truck" {
                    self.battle.register_unit(Unit {
                        key: format!("v{vehicle}"),
                        name: name.clone(),
                        kind: "vehicle".into(),
                        team,
                        owner,
                        started: self.now,
                        ended: -1.,
                        alive: 1,
                        ..Default::default()
                    })?;
                }
                if air {
                    self.actors.vehicle_mut(vehicle).unwrap().heli_home = id;
                }
                if !air || !supply {
                    if let Some(q) = passengers {
                        self.embark_new_squad(vehicle, upgrades(q, team, economy))?;
                    }
                }
                if !air || definition.base == "uav" {
                    let v = self.actors.vehicle_mut(vehicle).unwrap();
                    match v.order_move(dest, definition.base, dest)? {
                        Route::None => (),
                        Route::Boat { destination } => {
                            v.complete_boat_path(boats.path(v.position, destination))?
                        }
                        Route::Ground {
                            destination,
                            care,
                            revision,
                        } => {
                            self.geometry.navigation.submit_vehicle(
                                v,
                                destination,
                                care,
                                revision,
                                crate::traversal::Ground::new(
                                    &self.geometry.terrain,
                                    &self.geometry.deck,
                                ),
                            )?;
                        }
                    }
                }
                ownership.hold_vehicle(order.owner, vehicle, self.actors)?;
                out.push(Event::Vehicle(vehicle));
            }
            Product::Research { .. } => unreachable!(),
        }
        out.push(Event::Ready { team, name });
        Ok(out)
    }
}
