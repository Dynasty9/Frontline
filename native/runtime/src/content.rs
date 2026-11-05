//! Immutable game definitions are baked from Godot at build time, never supplied by a peer.
use frontline_core as sim;
use sim::infantry::Infantry;
use sim::infantry_spawn::Loadout;
use sim::structure::Structure;
use sim::vector::Vector3;
use sim::vehicle::Vehicle;
use std::collections::BTreeMap;

pub mod definitions;
mod load;
mod vehicles;
use definitions::Definitions;

pub const SOURCE: &str = include_str!("../../content.json");

struct WeaponDefinition {
    fire: sim::infantry_fire::FireProfile,
    bullet: sim::bullet::Weapon,
    interval: f64,
    suppression: f64,
    sound: String,
    piercing: bool,
}
impl WeaponDefinition {
    fn profile(&self) -> sim::infantry_fight_world::Profile<'_> {
        sim::infantry_fight_world::Profile {
            fire: self.fire,
            bullet: self.bullet,
            interval: self.interval,
            suppression: self.suppression,
            sound: &self.sound,
            piercing: self.piercing,
            optics: false,
        }
    }
}

/// A loaded catalog cannot be edited behind running matches.
/// ```compile_fail
/// fn edit(content: &mut frontline_runtime::content::Content) {
///     content.definitions().vehicles.clear();
/// }
/// ```
pub struct Content {
    digest: [u8; 32],
    definitions: Definitions,
    loadouts: BTreeMap<String, Loadout>,
    members: BTreeMap<String, Vec<Loadout>>,
    names: [Vec<String>; 2],
    weapons: BTreeMap<String, WeaponDefinition>,
    vehicles: BTreeMap<String, vehicles::Vehicle>,
    crew: [Loadout; 2],
    fob_names: [Vec<String>; 2],
    items: BTreeMap<String, sim::production_orders::Item>,
    research: Vec<sim::production_orders::Research>,
    produces: BTreeMap<String, Vec<String>>,
}

impl Content {
    pub fn validate_state(&self, state: &sim::match_state::MatchState) -> Result<(), &'static str> {
        for actor in state.field.actors.iter() {
            match actor {
                sim::actors::Actor::Soldier(s) => {
                    if !self.loadouts.contains_key(&s.identity.unit)
                        || [&s.identity.weapon, &s.identity.mounted_weapon]
                            .into_iter()
                            .any(|k| !k.is_empty() && !self.weapons.contains_key(k))
                    {
                        return Err("checkpoint references unknown infantry content");
                    }
                }
                sim::actors::Actor::Vehicle(v)
                    if !self.definitions.vehicles.contains_key(&v.kind) =>
                {
                    return Err("checkpoint references unknown vehicle content")
                }
                sim::actors::Actor::Structure(s)
                    if s.queue.iter().any(|q| !self.items.contains_key(&q.item)) =>
                {
                    return Err("checkpoint references unknown production content")
                }
                _ => {}
            }
        }
        if state
            .field
            .squads
            .iter()
            .any(|q| !self.members.contains_key(&q.kind))
        {
            return Err("checkpoint references unknown squad content");
        }
        Ok(())
    }

    pub fn definitions(&self) -> &Definitions {
        &self.definitions
    }
    pub fn digest(&self) -> [u8; 32] {
        self.digest
    }
    pub fn loadouts(&self) -> &BTreeMap<String, Loadout> {
        &self.loadouts
    }
    pub fn members(&self) -> &BTreeMap<String, Vec<Loadout>> {
        &self.members
    }
    pub fn unit(&self, s: &Infantry) -> &definitions::Unit {
        &self.definitions.units[&s.identity.unit]
    }
    pub fn vehicle(&self, v: &Vehicle) -> &definitions::Vehicle {
        &self.definitions.vehicles[&v.kind]
    }
    pub fn seats(&self, kind: &str) -> u32 {
        let Some(d) = self.definitions.vehicles.get(kind) else {
            return 0;
        };
        d.seats.map(|n| n as u32).unwrap_or_else(|| {
            self.members
                .get(d.carry.as_str())
                .map_or(0, |q| q.len().max(4) as u32)
        })
    }
    pub fn weapon(&self, key: &str) -> Option<sim::infantry_fight_world::Profile<'_>> {
        self.weapons.get(key).map(WeaponDefinition::profile)
    }
    pub fn infantry_weapon(&self, s: &Infantry) -> Option<sim::infantry_fight_world::Profile<'_>> {
        self.weapon(if s.identity.mounted_weapon.is_empty() {
            &s.identity.weapon
        } else {
            &s.identity.mounted_weapon
        })
    }
    pub fn mounted_gun(&self, s: &Structure) -> Option<sim::infantry_fire::MountedGun> {
        if !matches!(s.kind.as_str(), "mg_nest" | "hmg_nest") {
            return None;
        }
        let kind = match (s.kind.as_str(), s.team) {
            ("hmg_nest", 1) => "dshk",
            ("hmg_nest", _) => "m2",
            (_, 1) => "pkm",
            _ => "m240",
        };
        let d = &self.definitions.mounted_guns[kind];
        Some(sim::infantry_fire::MountedGun {
            bore: d.bore.unwrap_or(0.),
            muzzle: d.muzzle.unwrap_or(0.),
            grip_z: d.grip_r[2] as f32,
            nest_height: d.nest_h.unwrap_or(0.),
            trench_height: d.trench_h.unwrap_or(0.),
        })
    }
    pub fn armor(&self, v: &Vehicle) -> sim::vehicle_damage::Armor {
        self.vehicles[&v.kind].armor
    }

    pub fn crew(&self, v: &Vehicle) -> sim::vehicle_brain::CrewProfile<'_> {
        let d = self.vehicle(v);
        sim::vehicle_brain::CrewProfile {
            base: d.base.as_str(),
            helicopter: d.air,
            automatic: d.automatic,
            artillery: d.art.is_some(),
            tracked: d.tracked,
            armor: d.armor.unwrap_or(0.) as u8,
        }
    }
    pub fn loss(&self, v: &Vehicle) -> sim::vehicle_loss_world::Profile<'_> {
        let d = self.vehicle(v);
        sim::vehicle_loss_world::Profile {
            name: d.name.as_str(),
            crew: sim::vehicle_loss::Crew {
                base: d.base.as_str(),
                helicopter: d.air,
                automatic: d.automatic,
                count: d.crew.map(|n| n as u32),
                cost: d.cost.unwrap_or(0.),
                armor_upgrade: false,
                grenade_upgrade: false,
            },
            weight: d.weight.unwrap_or(1.) as u8,
            hull: Vector3::new(d.size[0] as f32, d.size[1] as f32, d.size[2] as f32),
        }
    }

    pub fn vehicle_tick(&self, v: &Vehicle) -> sim::match_tick::VehicleProfile<'_> {
        self.vehicles[&v.kind].profile(
            self.crew(v),
            self.definitions.supply_per_truck[v.team.max(0) as usize] as i32,
        )
    }

    pub fn vehicle_birth(&self, key: &str) -> Option<sim::vehicle_birth::Definition<'_>> {
        let d = self.definitions.vehicles.get(key)?;
        Some(sim::vehicle_birth::Definition {
            kind: d.key.as_str(),
            base: d.base.as_str(),
            hp: d.hp.unwrap_or(100.),
            hull: Vector3::new(d.size[0] as f32, d.size[1] as f32, d.size[2] as f32),
            missiles: [
                d.atgm.map_or(0., |m| m[0]) as i32,
                d.sam.map_or(0., |m| m[0]) as i32,
            ],
            tracked: d.tracked,
        })
    }
    pub fn squad(&self, key: &str) -> Option<sim::squad_birth::Definition<'_>> {
        let d = self.definitions.squads.get(key)?;
        self.members
            .get(key)
            .map(|members| sim::squad_birth::Definition {
                kind: d.key.as_str(),
                name: d.name.as_str(),
                members,
                armor_upgrade: false,
                grenade_upgrade: false,
            })
    }
    pub fn product(&self, s: &Structure) -> Option<sim::structure_production::Product<'_>> {
        use sim::structure_production::Product;
        let key = &s.queue.first()?.item;
        if let Some(squad) = self.squad(key) {
            return Some(Product::Squad(squad));
        }
        if let Some(definition) = self.vehicle_birth(key) {
            let d = &self.definitions.vehicles[key];
            return Some(Product::Vehicle {
                definition,
                name: d.name.as_str(),
                cap: d.cap.unwrap_or(0.) as u32,
                air: d.air,
                supply: d.supply,
                automatic: d.automatic,
                passengers: self.squad(d.carry.as_str()),
            });
        }
        let d = self.definitions.upgrades.get(key)?;
        Some(Product::Research {
            key: d.key.as_str(),
            name: d.name.as_str(),
        })
    }
    pub fn supply(&self, s: &Infantry) -> sim::structure_services::Supply {
        let d = self.unit(s);
        let weapon = self.weapon(&s.identity.weapon);
        sim::structure_services::Supply {
            ammunition: weapon.map(|w| w.fire.weapon.ammunition),
            frags: d.frags.unwrap_or(0.) as i32,
            loadout: weapon.map(|w| sim::infantry_supply::Loadout {
                ammunition: w.fire.weapon.ammunition,
                special: [d.frags, d.smokes, d.rockets, d.drones, d.mortar]
                    .map(|n| n.unwrap_or(0.) as i32),
                reload_weapon: self
                    .infantry_weapon(s)
                    .map_or(w.fire.weapon, |w| w.fire.weapon),
            }),
        }
    }
    pub fn building(&self, key: &str) -> Option<sim::building_placement::Definition<'_>> {
        let d = self.definitions.buildings.get(key)?;
        Some(sim::building_placement::Definition {
            key: d.key.as_str(),
            name: d.name.as_str(),
            teams: d.teams.iter().fold(0, |bits, t| bits | (1 << t)),
            cost: d.cost.unwrap_or(0.) as i32,
            body: sim::structure_birth::BuildingProfile {
                size: d.size.map(|v| v as f32),
                hp: d.hp.unwrap_or(0.),
            },
        })
    }
    pub fn support(&self, key: &str) -> Option<sim::support_calls::Definition<'_>> {
        use sim::support_calls::Sortie;
        let d = self.definitions.support.get(key)?;
        let fly = if d.fly.is_empty() { &d.key } else { &d.fly };
        let sortie = match fly.as_str() {
            "recon" => Sortie::Recon,
            "watch" => Sortie::Watch,
            "jet" => Sortie::Jet,
            "a10" => Sortie::GunRun,
            "orbit" => Sortie::Orbit,
            "artillery" => Sortie::Artillery,
            "barrage" => Sortie::Barrage,
            "mortars" => Sortie::Mortars,
            "smoke" => Sortie::Smoke,
            _ => return None,
        };
        Some(sim::support_calls::Definition {
            key: d.key.as_str(),
            name: d.name.as_str(),
            model: d.model.as_str(),
            team: d.team.unwrap_or(-1.) as i8,
            cost: d.cost.unwrap_or(0.) as i32,
            from: d.from.unwrap_or(300.),
            cooldown: d.cooldown.unwrap_or(0.),
            radius: d.r.unwrap_or(14.),
            sortie,
            quiet: d.quiet,
            leg: d.leg.unwrap_or(420.),
            altitude: d.alt.unwrap_or(60.),
            speed: d.speed.unwrap_or(90.),
            sight: d.sight.unwrap_or(0.),
            stay: d.stay.unwrap_or(0.),
            bombs: d.bombs.unwrap_or(4.) as u32,
            guns: sim::support::Gunset::parse(if d.guns.is_empty() {
                if fly == "watch" {
                    "none"
                } else {
                    "ac130"
                }
            } else {
                &d.guns
            }),
            muzzles: d.muzzles.map(vector),
        })
    }
    pub fn display(&self, s: &Structure) -> String {
        if !s.name.is_empty() {
            s.name.clone()
        } else {
            self.definitions
                .buildings
                .get(&s.kind)
                .map_or(s.kind.as_str(), |d| &d.name)
                .into()
        }
    }
    pub fn item_name(&self, key: &str) -> String {
        self.definitions
            .squads
            .get(key)
            .map(|d| &d.name)
            .or_else(|| self.definitions.vehicles.get(key).map(|d| &d.name))
            .or_else(|| self.definitions.buildings.get(key).map(|d| &d.name))
            .or_else(|| self.definitions.upgrades.get(key).map(|d| &d.name))
            .map_or_else(|| key.into(), Clone::clone)
    }
    pub fn with_profiles<T>(
        &self,
        commanders: &[(i8, u32)],
        f: impl FnOnce(&sim::match_tick::Profiles<'_>, &sim::match_commands::Profiles<'_>) -> T,
    ) -> T {
        let teams = std::array::from_fn(|i| self.definitions.team_names[i].as_str());
        let squad_names =
            ["rifle_squad", "fighter_cell"].map(|k| self.definitions.squads[k].name.as_str());
        let movement = |s: &Infantry| sim::squad_movement::ManProfile {
            bearer: self.unit(s).bearer,
            weapon_range: self
                .weapon(self.unit(s).weapon.as_str())
                .map(|w| w.bullet.range),
        };
        let armor = |v: &Vehicle| self.armor(v);
        let mounted = |s: &Structure| self.mounted_gun(s);
        let stock = |s: &Infantry| {
            let loadout = self
                .loadouts
                .get(&s.identity.unit)
                .ok_or("unknown infantry unit")?;
            Ok(sim::vehicle_service::SoldierSupply {
                loadout: self.supply(s).loadout,
                restored_weapon: (!loadout.weapon.is_empty())
                    .then_some((loadout.weapon.as_str(), loadout.magazine)),
            })
        };
        let profiles = sim::match_tick::Profiles {
            shared: sim::match_state::Shared {
                names: &self.names,
                crew_loadouts: &self.crew,
                crew_name: "Tank Crew",
                team_names: &teams,
                vehicle: &|v| self.loss(v),
                man: &|s, squads| {
                    let squad = squads.iter().find(|q| q.id == s.identity.squad);
                    let value = squad
                        .and_then(|q| {
                            let d = self.definitions.squads.get(&q.kind)?;
                            let cost = d.cost?;
                            (cost > 0.).then(|| cost / d.members.len().max(1) as f64)
                        })
                        .unwrap_or(20.);
                    sim::fires::ManProfile {
                        bearer: self.unit(s).bearer,
                        ammunition: self
                            .weapon(&s.identity.weapon)
                            .map(|w| w.fire.weapon.ammunition),
                        value,
                    }
                },
                movement: &movement,
                building: &|s| sim::fires::BuildingProfile {
                    player: self.definitions.buildings.contains_key(&s.kind),
                    value: self
                        .definitions
                        .buildings
                        .get(&s.kind)
                        .and_then(|d| d.cost)
                        .unwrap_or(0.),
                },
                role: &|s| self.unit(s).name.as_str().into(),
                automatic: &|k| {
                    self.definitions
                        .vehicles
                        .get(k)
                        .is_some_and(|d| d.automatic)
                },
                player_building: &|k| self.definitions.buildings.contains_key(k),
            },
            infantry: sim::infantry_world::Profiles {
                unit: &|s| {
                    let d = self.unit(s);
                    let key = d.weapon.as_str();
                    sim::infantry_world::Unit {
                        bearer: d.bearer,
                        healing: d.heal.unwrap_or(1.),
                        building: d.build.unwrap_or(1.),
                        weapon: self.weapon(key).map(|w| (key, w.fire.weapon)),
                    }
                },
                weapon: &|s| self.infantry_weapon(s),
                gun: &mounted,
                build_time: &|s| self.definitions.buildings.get(&s.kind).and_then(|d| d.time),
                defense: &|v| sim::infantry_action_owned::Defense {
                    crew: self.crew(v),
                    smoke: sim::vehicle_launch::SmokeProfile {
                        armor: self.armor(v).level,
                        helicopter: self.vehicle(v).air,
                        gun_height: self.vehicle(v).gun_h.unwrap_or(2.),
                    },
                },
                armor: &armor,
                vehicle_hit: &|v| self.vehicle(v).hit.unwrap_or(2.),
                transport: &|v| sim::infantry_travel_owned::Transport {
                    seats: self.seats(&v.kind),
                    helicopter: self.vehicle(v).air,
                    boat: self.vehicle(v).base.as_str() == "boat",
                },
            },
            buildings: sim::structures_tick::Profiles {
                product: &|s| self.product(s),
                base_cap: self.definitions.base_cap as u32,
                cap_per_fob: self.definitions.cap_per_fob as u32,
                vehicle_cap: &|v| self.vehicle(v).cap.unwrap_or(0.) as u32,
                supply: &|s| self.supply(s),
                bearers: [&self.loadouts["bearer"]; 2],
                gun: &mounted,
                armor: &armor,
                fob_radius: self.definitions.fob_radius,
                towns: std::array::from_fn(|i| sim::structure::TownEconomy {
                    stock: self.definitions.town_stock[i],
                    yield_per_minute: self.definitions.town_yield[i],
                    capture_pace: self.definitions.town_pace[i],
                }),
            },
            squads: sim::squad_world::Profiles {
                role: &|s| sim::squad_duties::Role {
                    medic: self.unit(s).medic,
                    engineer: self.unit(s).engineer,
                },
                armor: &|k| self.definitions.vehicles[k].armor.unwrap_or(0.) as i32,
                weapon: &|s| self.infantry_weapon(s).map(|w| w.fire.weapon),
                air: &|k| self.definitions.vehicles[k].air,
            },
            rules: sim::rules_world::Profiles {
                reserves: ["rifle_squad", "fighter_cell"].map(|k| self.squad(k).unwrap()),
                truck: sim::rules_logistics::TruckProfile {
                    vehicle: self.vehicle_birth("truck").unwrap(),
                    town_load: self.definitions.town_load.map(|n| n as i32),
                    town_stock: self.definitions.town_stock,
                    supply: self.definitions.supply_per_truck.map(|n| n as i32),
                },
                vehicle: &|v| sim::fog::VehicleProfile {
                    sight: self.vehicle(v).sight.unwrap_or(50.),
                    helicopter: self.vehicle(v).air,
                    automatic: self.vehicle(v).automatic,
                    cannon: self.vehicle(v).cannon,
                },
                prisoner: &|s| {
                    let d = self.unit(s);
                    let key = d.weapon.as_str();
                    sim::rules_world::PrisonerProfile {
                        weapon: self.weapon(key).map(|w| (key, w.fire.weapon.magazine)),
                        squad_name: squad_names[s.identity.team as usize],
                    }
                },
                display: &|s| self.display(s),
                item_name: &|k| self.item_name(k),
                commanders,
            },
            vehicle: &|v| self.vehicle_tick(v),
            soldier_stock: &stock,
            vehicle_stock: &|v| {
                self.vehicle_birth(&v.kind)
                    .map(|d| d.missiles)
                    .ok_or("unknown vehicle")
            },
            squad_names,
        };
        let distances = sim::building_placement::Distances {
            build: self.definitions.build_radius,
            fob_spacing: self.definitions.fob_min_spacing,
            fob_expand: self.definitions.fob_expand_radius,
        };
        let commands = sim::match_commands::Profiles {
            building: &|k| self.building(k),
            support: &|k| self.support(k),
            item: &|k, research| self.items.get(k).filter(|i| i.research == research),
            produces: &|k| self.produces.get(k).map_or(&[], Vec::as_slice),
            research: &self.research,
            vehicle: &|v| {
                let d = self.vehicle(v);
                sim::match_commands::VehicleOptions {
                    seats: self.seats(&v.kind) as i32,
                    artillery: d
                        .art
                        .as_ref()
                        .map(|art| (art.min.unwrap_or(40.), art.max.unwrap_or(230.))),
                    sling_capacity: (d.base.as_str() == "lift_heli" && !d.supply)
                        .then(|| d.sling.unwrap_or(-1.) as i8),
                }
            },
            mount: &mounted,
            engineer: &|s| self.unit(s).engineer,
            mortar: &|s| self.unit(s).mortar.unwrap_or(0.) > 0.,
            structure_name: &|s| self.display(s),
            squad_name: &|q| self.item_name(&q.kind),
            distances: &distances,
            fob_names: &self.fob_names,
        };
        f(&profiles, &commands)
    }
}

fn vector(p: [f64; 3]) -> Vector3 {
    Vector3::new(p[0] as f32, p[1] as f32, p[2] as f32)
}
