//! Fixed-work battlefield phases retain registration order and immediate shared effects.
use crate::actors::Actor;
use crate::aircraft_world;
use crate::boat_world;
use crate::entities::Kind;
use crate::infantry::Infantry;
use crate::infantry_orders::{Arrival, PathFinish};
use crate::infantry_prison_owned;
use crate::infantry_world;
use crate::match_state::{MatchState, Shared, Upgrades, FIXED_DELTA};
use crate::perception::PerceptionSearch;
use crate::rules_world;
use crate::squad_movement;
use crate::squad_world;
use crate::structures_tick;
use crate::vehicle::Vehicle;
use crate::vehicle_motion::GroundProfile;
use crate::vehicle_service::SoldierSupply;
use crate::vehicle_world;
use crate::world_routes::Completion;

#[derive(Clone, Copy)]
pub enum VehicleProfile<'a> {
    Ground(vehicle_world::Ground<'a>),
    Aircraft(aircraft_world::Profile<'a>),
    Boat(boat_world::Profile<'a>),
    Truck { movement: GroundProfile, load: i32 },
}
/// These are base definitions. Live research is applied when each phase starts.
pub struct Profiles<'a> {
    pub shared: Shared<'a>,
    pub infantry: infantry_world::Profiles<'a>,
    pub buildings: structures_tick::Profiles<'a>,
    pub squads: squad_world::Profiles<'a>,
    pub rules: rules_world::Profiles<'a>,
    pub vehicle: &'a dyn Fn(&Vehicle) -> VehicleProfile<'a>,
    pub soldier_stock: &'a dyn Fn(&Infantry) -> Result<SoldierSupply<'a>, &'static str>,
    pub vehicle_stock: &'a dyn Fn(&Vehicle) -> Result<[i32; 2], &'static str>,
    pub squad_names: [&'a str; 2],
}
#[derive(Clone, Debug, PartialEq)]
pub enum Event {
    Infantry(infantry_world::Event),
    Building(structures_tick::Event),
    Fire(crate::fires::Event),
    Vehicle(vehicle_world::Event),
    Ordnance(crate::ordnance_world::Event),
    Squad(squad_world::Event),
    Rules(rules_world::Event),
    Deferred(crate::world_combat::Event),
}
fn upgraded_stock<'a>(
    mut stock: SoldierSupply<'a>,
    s: &Infantry,
    p: &Shared<'_>,
    u: Upgrades,
) -> SoldierSupply<'a> {
    if !(p.movement)(s).bearer && u.grenades.get(s.identity.team as usize) == Some(&true) {
        if let Some(loadout) = &mut stock.loadout {
            loadout.special[0] += 1;
        }
    }
    stock
}
fn optics(weapons: &mut crate::vehicle_combat_world::Profile<'_>, team: i8, u: Upgrades) {
    if let Some(gun) = &mut weapons.machine_gun {
        gun.optics = u.optics.get(team as usize).copied().unwrap_or(false);
    }
}
impl MatchState {
    /// The caller admits commands before this phase and runs commanders/missions afterward.
    pub fn advance_battlefield(
        &mut self,
        p: &Profiles<'_>,
        search: &mut PerceptionSearch,
    ) -> Result<Vec<Event>, &'static str> {
        self.advance_battlefield_profiled(p, search, |_| {})
    }
    /// Phase boundaries are observations only; their timing never changes the work quota.
    pub fn advance_battlefield_profiled(
        &mut self,
        p: &Profiles<'_>,
        search: &mut PerceptionSearch,
        mut phase: impl FnMut(&'static str),
    ) -> Result<Vec<Event>, &'static str> {
        if self.tick >= i64::MAX as u64
            || !self.field.now.is_finite()
            || !(0. ..1e12 - 100_000.).contains(&self.field.now)
        {
            return Err("match clock exhausted");
        }
        let dt = FIXED_DELTA;
        let f = &mut self.field;
        f.geometry.tick_cover(2500)?;
        f.now += dt;
        self.tick += 1;
        if !f.geometry.navigation.update_hierarchy(1) {
            return Err("navigation update failed");
        }
        let routes = f.geometry.navigation.process_paths(
            &mut f.actors,
            4,
            f.now,
            &mut f.rng,
            crate::traversal::Ground::new(&f.geometry.terrain, &f.geometry.deck),
        )?;
        let mut out = vec![];
        for route in routes {
            if let Completion::Infantry {
                id,
                finish: PathFinish::Arrived(Arrival::Prison),
            } = route
            {
                let events = f.actors.arrive_infantry_prison(
                    id,
                    f.now,
                    &f.geometry.navigation.planner,
                    crate::traversal::Ground::new(&f.geometry.terrain, &f.geometry.deck),
                )?;
                for e in events {
                    if let infantry_prison_owned::Event::Movement(id, movement) = &e {
                        f.with_context(&p.shared, Upgrades::from(&self.rules.economy), |w| {
                            w.apply_infantry_movement(*id, *movement)
                        })?;
                    }
                    out.push(Event::Infantry(infantry_world::Event::Prison(e)));
                }
            }
        }
        phase("navigation");
        f.actors.rebuild_units(&mut f.units)?;
        search.rebuild_actors(&f.actors, &f.geometry.terrain, f.now, |v| {
            (p.shared.vehicle)(v).crew.helicopter
        })?;
        phase("perception_index");
        let owned: Vec<_> = f
            .actors
            .iter_kind(Kind::Structure)
            .filter_map(|a| match a {
                Actor::Structure(s) if s.team >= 0 => Some(s.id),
                _ => None,
            })
            .collect();
        let ids: Vec<_> = f
            .actors
            .iter_kind(Kind::Soldier)
            .map(|a| a.identity().id)
            .collect();
        let upgrades = Upgrades::from(&self.rules.economy);
        let weapon = |s: &Infantry| {
            (p.infantry.weapon)(s).map(|mut w| {
                w.optics = upgrades
                    .optics
                    .get(s.identity.team as usize)
                    .copied()
                    .unwrap_or(false);
                w
            })
        };
        let unit = |s: &Infantry| (p.infantry.unit)(s);
        let defense = |v: &Vehicle| (p.infantry.defense)(v);
        let infantry = infantry_world::Profiles {
            weapon: &weapon,
            unit: &unit,
            gun: p.infantry.gun,
            build_time: p.infantry.build_time,
            defense: &defense,
            armor: p.infantry.armor,
            vehicle_hit: p.infantry.vehicle_hit,
            transport: p.infantry.transport,
        };
        for id in ids {
            if f.actors.soldier(id).is_none() {
                continue;
            }
            let depots = self.rules.network.depots;
            out.extend(
                f.with_context(&p.shared, upgrades, |w| {
                    w.advance_infantry(
                        id,
                        dt,
                        &infantry,
                        &mut infantry_world::Tick {
                            search,
                            gunfire: &mut self.gunfire,
                            network: &mut self.rules.network,
                            impacts: &mut self.impacts,
                            chat: &mut self.chat,
                            owned: &owned,
                            players: &self.owners.players,
                            depots,
                            medicine: upgrades.medicine,
                            optics: upgrades.optics,
                            warheads: upgrades.warheads,
                            squad_names: p.squad_names,
                        },
                    )
                })?
                .into_iter()
                .map(Event::Infantry),
            );
        }
        phase("infantry");
        let structures = f.actors.simulated_structures().to_vec();
        for id in structures {
            // A preceding research building can change later tent staff, refills and vehicle crews.
            let upgrades = Upgrades::from(&self.rules.economy);
            let supply = |s: &Infantry| {
                let mut stock = (p.buildings.supply)(s);
                if !(p.shared.movement)(s).bearer
                    && upgrades.grenades.get(s.identity.team as usize) == Some(&true)
                {
                    stock.frags += 1;
                    if let Some(loadout) = &mut stock.loadout {
                        loadout.special[0] += 1;
                    }
                }
                stock
            };
            let product = |s: &crate::structure::Structure| (p.buildings.product)(s);
            let buildings = structures_tick::Profiles {
                supply: &supply,
                product: &product,
                base_cap: p.buildings.base_cap,
                cap_per_fob: p.buildings.cap_per_fob,
                vehicle_cap: p.buildings.vehicle_cap,
                bearers: p.buildings.bearers,
                gun: p.buildings.gun,
                armor: p.buildings.armor,
                fob_radius: p.buildings.fob_radius,
                towns: p.buildings.towns,
            };
            out.extend(
                f.with_context(&p.shared, upgrades, |w| {
                    w.advance_structure(
                        id,
                        dt,
                        &mut self.rules,
                        &mut self.owners,
                        &mut self.boats,
                        &mut self.victory,
                        &mut self.impacts,
                        &buildings,
                    )
                })?
                .into_iter()
                .map(Event::Building),
            );
        }
        phase("structures");
        out.extend(
            f.fires
                .tick(
                    dt,
                    &mut crate::fires::Context {
                        actors: &mut f.actors,
                        geometry: &mut f.geometry,
                        units: &f.units,
                        squads: &mut f.squads,
                        battle: &mut f.battle,
                        deferred: &mut f.deferred,
                        visibility: &mut f.visibility,
                        rng: &mut f.rng,
                        now: f.now,
                        town: f.town,
                        man: p.shared.man,
                        building: p.shared.building,
                        role: p.shared.role,
                    },
                )?
                .into_iter()
                .map(Event::Fire),
        );
        phase("fires");
        // Snapshot all three lists before vehicles fire. Their new rounds fly on the next tick.
        let [vehicles, projectiles, drones] =
            [Kind::Vehicle, Kind::Projectile, Kind::Drone].map(|k| {
                f.actors
                    .iter_kind(k)
                    .map(|a| a.identity().id)
                    .collect::<Vec<_>>()
            });
        let owned: Vec<_> = if vehicles.is_empty() {
            vec![]
        } else {
            f.actors
                .iter_kind(Kind::Structure)
                .filter_map(|a| match a {
                    Actor::Structure(s) if s.team >= 0 => Some(s.id),
                    _ => None,
                })
                .collect()
        };
        let upgrades = Upgrades::from(&self.rules.economy);
        let cannon = |v: &Vehicle| match (p.vehicle)(v) {
            VehicleProfile::Ground(p) => p.weapons.cannon.is_some(),
            VehicleProfile::Aircraft(p) => p.weapons.cannon.is_some(),
            VehicleProfile::Boat(p) => p.weapons.cannon.is_some(),
            VehicleProfile::Truck { .. } => false,
        };
        let soldier_stock = |s: &Infantry| {
            (p.soldier_stock)(s).map(|stock| upgraded_stock(stock, s, &p.shared, upgrades))
        };
        for id in vehicles {
            let Some(v) = f.actors.vehicle(id) else {
                continue;
            };
            let team = v.team;
            let profile = (p.vehicle)(v);
            let events = f.with_context(&p.shared, upgrades, |w| match profile {
                VehicleProfile::Ground(mut profile) => {
                    optics(&mut profile.weapons, team, upgrades);
                    w.advance_ground_vehicle(
                        id,
                        dt,
                        profile,
                        &mut self.gunfire,
                        &mut self.rules.network,
                        &mut self.impacts,
                        &mut self.attacks,
                        &mut self.next_attack,
                        self.victory.mission,
                        &owned,
                        p.infantry.armor,
                        p.infantry.vehicle_hit,
                        p.infantry.defense,
                        &cannon,
                        &soldier_stock,
                        p.vehicle_stock,
                    )
                }
                VehicleProfile::Aircraft(mut profile) => {
                    optics(&mut profile.weapons, team, upgrades);
                    w.advance_aircraft(
                        id,
                        dt,
                        profile,
                        &mut self.gunfire,
                        &mut self.rules.network,
                        &mut self.impacts,
                        &mut self.attacks,
                        &mut self.next_attack,
                        &mut self.rules.income,
                        p.infantry.armor,
                        p.infantry.vehicle_hit,
                        p.infantry.defense,
                    )
                }
                VehicleProfile::Boat(mut profile) => {
                    optics(&mut profile.weapons, team, upgrades);
                    w.advance_boat(
                        id,
                        dt,
                        profile,
                        &mut self.boats,
                        Some(&self.water),
                        &mut self.gunfire,
                        &mut self.rules.network,
                        &mut self.impacts,
                        &mut self.attacks,
                        &mut self.next_attack,
                        p.infantry.armor,
                        p.infantry.vehicle_hit,
                        p.infantry.defense,
                    )
                }
                VehicleProfile::Truck { movement, load } => {
                    w.advance_supply_truck(id, dt, movement, load, &mut self.rules.income)
                }
            })?;
            out.extend(events.into_iter().map(Event::Vehicle));
        }
        phase("vehicles");
        for id in projectiles {
            if f.actors.get(id).is_none() {
                continue;
            }
            out.extend(
                f.with_context(&p.shared, upgrades, |w| {
                    w.advance_projectile_world(
                        id,
                        dt,
                        &mut self.rules.fog.marks,
                        &mut self.rules.network,
                        &mut self.impacts,
                        p.infantry.armor,
                    )
                })?
                .into_iter()
                .map(Event::Ordnance),
            );
        }
        for id in drones {
            if f.actors.get(id).is_none() {
                continue;
            }
            out.extend(
                f.with_context(&p.shared, upgrades, |w| {
                    w.advance_drone_world(
                        id,
                        dt,
                        &mut self.rules.network,
                        &mut self.impacts,
                        p.infantry.armor,
                    )
                })?
                .into_iter()
                .map(Event::Ordnance),
            );
        }
        phase("ordnance");
        let squads: Vec<_> = f.squads.iter().map(|q| q.id).collect();
        for id in squads {
            let events = squad_movement::Context {
                actors: &mut f.actors,
                geometry: &mut f.geometry,
                units: &f.units,
                squads: &mut f.squads,
                rng: &mut f.rng,
                now: f.now,
                town: f.town,
                man: p.shared.movement,
                automatic: p.shared.automatic,
                player_building: p.shared.player_building,
            }
            .squad_tick(
                id,
                dt,
                &mut squad_world::Tick {
                    attacks: &mut self.attacks,
                    ambushes: &mut self.ambushes,
                    battle: &mut f.battle,
                    impacts: &self.impacts,
                },
                &p.squads,
            )?;
            for event in events {
                if let squad_world::Event::Removed(id) = &event {
                    f.squads.retain(|q| q.id != *id);
                }
                out.push(Event::Squad(event));
            }
        }
        phase("squads");
        let rules = rules_world::Profiles {
            reserves: p.rules.reserves,
            truck: p.rules.truck,
            vehicle: p.rules.vehicle,
            prisoner: p.rules.prisoner,
            display: p.rules.display,
            item_name: p.rules.item_name,
            commanders: p.rules.commanders,
        };
        out.extend(
            f.with_context(&p.shared, upgrades, |w| {
                w.advance_rules(
                    dt,
                    &mut self.rules,
                    &self.owners,
                    &mut self.victory,
                    self.scenario,
                    rules,
                )
            })?
            .into_iter()
            .map(Event::Rules),
        );
        let supply = std::array::from_fn(|t| {
            crate::economy::fobs(&f.actors, t as i8, true)
                .map(|s| s.supply.trunc())
                .sum()
        });
        f.battle.tick(dt, f.now, supply, &f.actors, |s| {
            (p.shared.movement)(s).bearer
        })?;
        phase("rules_and_ledger");
        Ok(out)
    }

    /// Run after commanders and mission events, before publishing the tick's observations.
    pub fn finish_battlefield(&mut self, p: &Profiles<'_>) -> Result<Vec<Event>, &'static str> {
        let u = Upgrades::from(&self.rules.economy);
        let out = self
            .field
            .with_context(&p.shared, u, |w| {
                w.flush_deferred(&mut self.rules.network, &mut self.impacts, p.infantry.armor)
            })?
            .into_iter()
            .map(Event::Deferred)
            .collect();
        self.field.geometry.finish_tick();
        Ok(out)
    }
}
