//! Immutable game definitions are baked from Godot at build time, never supplied by a peer.
use frontline_core as sim;
use serde_json::Value;
use sim::infantry::Infantry;
use sim::infantry_spawn::Loadout;
use sim::structure::Structure;
use sim::vector::Vector3;
use sim::vehicle::Vehicle;
use std::collections::BTreeMap;

pub const SOURCE: &str = include_str!("../../content.json");

fn number(d: &Value, key: &str, default: f64) -> f64 {
    d[key].as_f64().unwrap_or(default)
}
fn flag(d: &Value, key: &str) -> bool {
    d[key].as_bool().unwrap_or(false)
}
fn text<'a>(d: &'a Value, key: &str, default: &'a str) -> &'a str {
    d[key].as_str().unwrap_or(default)
}
fn array<const N: usize>(d: &Value) -> [f64; N] {
    std::array::from_fn(|i| d[i].as_f64().expect("numeric content array"))
}
fn point(d: &Value) -> Vector3 {
    let a: [f64; 3] = array(d);
    Vector3::new(a[0] as f32, a[1] as f32, a[2] as f32)
}

struct WeaponDefinition {
    fire: sim::infantry_fire::FireProfile,
    bullet: sim::bullet::Weapon,
    interval: f64,
    suppression: f64,
    sound: String,
    piercing: bool,
}
impl WeaponDefinition {
    fn decode(d: &Value) -> Self {
        let sound = text(d, "snd", "rifle");
        let piercing = flag(d, "ap");
        let penetration = if piercing || sound == "hmg" {
            3
        } else if matches!(sound, "mg" | "minigun") {
            2
        } else if sound == "rifle" {
            1
        } else {
            0
        };
        Self {
            fire: sim::infantry_fire::FireProfile {
                weapon: sim::infantry_weapon::Weapon {
                    ammunition: number(d, "ammo", 0.) as i32,
                    magazine: number(d, "mag", 30.) as i32,
                    reload_time: number(d, "reload", 2.),
                },
                burst_min: d["burst"][0].as_i64().unwrap() as i32,
                burst_max: d["burst"][1].as_i64().unwrap() as i32,
            },
            bullet: sim::bullet::Weapon {
                accuracy: number(d, "acc", 0.),
                range: number(d, "range", 0.),
                damage: number(d, "dmg", 0.),
                anti_air: flag(d, "aa"),
                penetration,
                drone_accuracy: if sound == "hmg" {
                    0.08
                } else if sound == "mg" {
                    0.045
                } else {
                    0.03
                },
                explosive_radius: d["he"].as_f64(),
                airburst: flag(d, "airburst"),
            },
            interval: number(d, "interval", 0.),
            suppression: number(d, "supp", 0.),
            sound: sound.into(),
            piercing,
        }
    }
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

pub struct Content {
    pub digest: [u8; 32],
    pub definitions: Value,
    pub loadouts: BTreeMap<String, Loadout>,
    pub members: BTreeMap<String, Vec<Loadout>>,
    pub names: [Vec<String>; 2],
    weapons: BTreeMap<String, WeaponDefinition>,
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
                            .any(|k| !k.is_empty() && self.definitions["weapons"][k].is_null())
                    {
                        return Err("checkpoint references unknown infantry content");
                    }
                }
                sim::actors::Actor::Vehicle(v)
                    if self.definitions["vehicles"][&v.kind].is_null() =>
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
    pub fn bundled() -> Result<Self, String> {
        let definitions: Value = serde_json::from_str(SOURCE).map_err(|e| e.to_string())?;
        if definitions["version"].as_u64() != Some(1) {
            return Err("unsupported game content version".into());
        }
        let mut loadouts = BTreeMap::new();
        for (key, d) in definitions["units"]
            .as_object()
            .ok_or("missing unit definitions")?
        {
            let weapon = text(d, "weapon", "");
            let w = &definitions["weapons"][weapon];
            if !weapon.is_empty() && w.is_null() {
                return Err(format!("unknown weapon for {key}"));
            }
            let loadout = Loadout {
                unit: key.clone(),
                weapon: weapon.into(),
                hp: number(d, "hp", 100.),
                magazine: number(w, "mag", 0.) as i32,
                ammunition: number(w, "ammo", 0.) as i32,
                grenades: number(d, "frags", 0.) as i32,
                smokes: number(d, "smokes", 0.) as i32,
                rockets: number(d, "rockets", 0.) as i32,
                mortar_rounds: number(d, "mortar", 0.) as i32,
                drones: number(d, "drones", 0.) as i32,
                bearer: flag(d, "bearer"),
            };
            if !loadout.valid() {
                return Err(format!("invalid unit definition {key}"));
            }
            loadouts.insert(key.clone(), loadout);
        }
        let mut members = BTreeMap::new();
        for (key, d) in definitions["squads"]
            .as_object()
            .ok_or("missing squad definitions")?
        {
            let mut squad = vec![];
            for unit in d["members"].as_array().ok_or("missing squad members")? {
                squad.push(
                    loadouts
                        .get(unit.as_str().ok_or("invalid squad member")?)
                        .ok_or("unknown squad member")?
                        .clone(),
                );
            }
            if squad.is_empty() {
                return Err(format!("empty squad {key}"));
            }
            members.insert(key.clone(), squad);
        }
        let names: [Vec<String>; 2] =
            serde_json::from_value(definitions["names"].clone()).map_err(|e| e.to_string())?;
        let crew = ["crewman", "r_crewman"].map(|key| loadouts[key].clone());
        let fob_names =
            serde_json::from_value(definitions["fob_names"].clone()).map_err(|e| e.to_string())?;
        let mut items = BTreeMap::new();
        let mut research = vec![];
        let mut produces = BTreeMap::new();
        for table in ["squads", "vehicles", "upgrades"] {
            for (key, d) in definitions[table]
                .as_object()
                .ok_or("missing production definitions")?
            {
                let time = number(d, "time", 0.);
                if time <= 0. {
                    continue;
                }
                let item = sim::production_orders::Item {
                    key: key.clone(),
                    name: text(d, "name", key).into(),
                    cost: number(d, "cost", 0.) as i32,
                    time,
                    tier: number(d, "tier", 1.) as u32,
                    research: table == "upgrades",
                    teams: teams(d),
                    requires: text(d, "requires", "").into(),
                };
                if !item.valid() {
                    return Err(format!("invalid production item {key}"));
                }
                if item.research {
                    research.push(sim::production_orders::Research {
                        key: key.clone(),
                        name: item.name.clone(),
                        teams: item.teams,
                        tier: item.tier,
                    });
                }
                items.insert(key.clone(), item);
            }
        }
        for (key, d) in definitions["buildings"]
            .as_object()
            .ok_or("missing buildings")?
        {
            let mut list = vec![];
            if let Some(sides) = d["produces"].as_array() {
                for side in sides {
                    for item in side.as_array().ok_or("invalid production list")? {
                        let item = item.as_str().ok_or("invalid product")?;
                        if !items.contains_key(item) {
                            return Err(format!("unknown product {item}"));
                        }
                        list.push(item.into());
                    }
                }
            }
            produces.insert(key.clone(), list);
        }
        let weapons: BTreeMap<_, _> = definitions["weapons"]
            .as_object()
            .ok_or("invalid weapon definitions")?
            .iter()
            .map(|(key, value)| (key.clone(), WeaponDefinition::decode(value)))
            .collect();
        if weapons.values().any(|w| !w.profile().valid()) {
            return Err("invalid baked weapon profile".into());
        }
        Ok(Self {
            weapons,
            digest: *blake3::hash(SOURCE.replace("\r\n", "\n").as_bytes()).as_bytes(),
            definitions,
            loadouts,
            members,
            names,
            crew,
            fob_names,
            items,
            research,
            produces,
        })
    }
    pub fn unit(&self, s: &Infantry) -> &Value {
        &self.definitions["units"][&s.identity.unit]
    }
    pub fn vehicle(&self, v: &Vehicle) -> &Value {
        &self.definitions["vehicles"][&v.kind]
    }
    pub fn seats(&self, kind: &str) -> u32 {
        let d = &self.definitions["vehicles"][kind];
        d["seats"].as_u64().map(|n| n as u32).unwrap_or_else(|| {
            self.members
                .get(text(d, "carry", ""))
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
        let d = &self.definitions["mounted_guns"][kind];
        Some(sim::infantry_fire::MountedGun {
            bore: number(d, "bore", 0.),
            muzzle: number(d, "muzzle", 0.),
            grip_z: point(&d["grip_r"]).z,
            nest_height: number(d, "nest_h", 0.),
            trench_height: number(d, "trench_h", 0.),
        })
    }
    pub fn armor(&self, v: &Vehicle) -> sim::vehicle_damage::Armor {
        let d = self.vehicle(v);
        let base = text(d, "base", "tank");
        sim::vehicle_damage::Armor {
            level: number(d, "armor", 0.) as u8,
            helicopter: flag(d, "air"),
            boat: base == "boat",
            supply: base == "supply",
            toss: [2.2, 0.9, 0.3][number(d, "weight", 1.) as usize],
        }
    }
    pub fn crew(&self, v: &Vehicle) -> sim::vehicle_brain::CrewProfile<'_> {
        let d = self.vehicle(v);
        sim::vehicle_brain::CrewProfile {
            base: text(d, "base", "tank"),
            helicopter: flag(d, "air"),
            automatic: flag(d, "auto"),
            artillery: !d["art"].is_null(),
            tracked: flag(d, "tracked"),
            armor: number(d, "armor", 0.) as u8,
        }
    }
    pub fn loss(&self, v: &Vehicle) -> sim::vehicle_loss_world::Profile<'_> {
        let d = self.vehicle(v);
        sim::vehicle_loss_world::Profile {
            name: text(d, "name", "Vehicle"),
            crew: sim::vehicle_loss::Crew {
                base: text(d, "base", "tank"),
                helicopter: flag(d, "air"),
                automatic: flag(d, "auto"),
                count: d["crew"].as_u64().map(|n| n as u32),
                cost: number(d, "cost", 0.),
                armor_upgrade: false,
                grenade_upgrade: false,
            },
            weight: number(d, "weight", 1.) as u8,
            hull: point(&d["size"]),
        }
    }
    pub fn movement(&self, v: &Vehicle) -> sim::vehicle_motion::GroundProfile {
        let d = self.vehicle(v);
        let p = &self.definitions["motion"][&v.kind];
        let base = text(d, "base", "tank");
        sim::vehicle_motion::GroundProfile {
            hull: point(&d["size"]),
            tracked: flag(d, "tracked"),
            weight: number(d, "weight", 1.) as u8,
            supply: base == "supply",
            tank: base == "tank",
            cannon: flag(d, "cannon"),
            speed: number(d, "speed", 0.),
            turn: number(p, "hull_turn", 0.),
            turn_accel: number(p, "hull_accel", 0.),
            handling: array(&p["handling"]),
        }
    }
    pub fn scan(&self, v: &Vehicle) -> sim::vehicle_scan::ScanProfile {
        let d = self.vehicle(v);
        let gunship = text(d, "base", "") == "attack_heli";
        let w = &self.definitions["weapons"][text(d, "mg", "")];
        sim::vehicle_scan::ScanProfile {
            sight: number(d, "sight", 50.),
            gun_height: number(d, "gun_h", if gunship { 0.8 } else { 2.2 }),
            cannon: flag(d, "cannon"),
            gunship,
            anti_air: flag(d, "aa"),
            penetrating_mg: flag(w, "ap"),
        }
    }
    pub fn muzzle(&self, v: &Vehicle, gun: &str) -> sim::vehicle_cannon::Muzzle {
        let d = self.vehicle(v);
        let socket = &self.definitions["sockets"][&v.kind][gun];
        let gunship = text(d, "base", "") == "attack_heli";
        sim::vehicle_cannon::Muzzle {
            socket: (!socket.is_null()).then(|| sim::vehicle_cannon::Socket {
                point: point(&socket["point"]),
                pivot: (!socket["pivot"].is_null()).then(|| point(&socket["pivot"])),
            }),
            helicopter: flag(d, "air"),
            gunship,
            gun_height: number(d, "gun_h", if gunship { 0.8 } else { 2.2 }),
        }
    }
    pub fn vehicle_weapons(&self, v: &Vehicle) -> sim::vehicle_combat_world::Profile<'_> {
        let d = self.vehicle(v);
        let gun = &d["gun"];
        let mg = text(d, "mg", "");
        let w = &self.definitions["weapons"][mg];
        sim::vehicle_combat_world::Profile {
            cycle: sim::vehicle_weapon::FireProfile {
                base: text(d, "base", "tank"),
                cannon: flag(d, "cannon"),
                armor: number(d, "armor", 0.) as u8,
                machine_gun: mg,
                burst: std::array::from_fn(|i| w["burst"][i].as_i64().unwrap_or(1) as i32),
                interval: number(w, "interval", 0.1),
                cannon_cooldown: number(gun, "cd", 5.5),
                sam_cooldown: d["sam"][1].as_f64().unwrap_or(0.),
                sam_range: number(d, "sam_range", 160.),
                atgm_cooldown: d["atgm"][1].as_f64().unwrap_or(0.),
                atgm_range: number(d, "atgm_range", 125.),
            },
            muzzle: self.muzzle(v, "mg"),
            cannon: flag(d, "cannon").then(|| sim::vehicle_cannon::CannonProfile {
                muzzle: self.muzzle(v, "gun"),
                damage: number(gun, "dmg", 160.),
                radius: number(gun, "radius", 5.5),
                anti_tank: number(gun, "at", 320.),
                size: number(gun, "size", 1.4),
            }),
            machine_gun: self
                .weapon(mg)
                .map(|w| sim::vehicle_combat_world::MachineGun {
                    weapon: w.bullet,
                    suppression: w.suppression,
                    sound: w.sound,
                    optics: false,
                    piercing: w.piercing,
                }),
        }
    }
    pub fn vehicle_tick(&self, v: &Vehicle) -> sim::match_tick::VehicleProfile<'_> {
        use sim::match_tick::VehicleProfile;
        let d = self.vehicle(v);
        let p = &self.definitions["motion"][&v.kind];
        let base = text(d, "base", "tank");
        let traverse = [number(p, "traverse", 0.), number(p, "traverse_accel", 0.)];
        let scan = self.scan(v);
        let weapons = self.vehicle_weapons(v);
        if flag(d, "air") {
            use sim::aircraft_world::Kind;
            let kind = match base {
                "lift_heli" if flag(d, "supply") => Kind::Supply {
                    load: number(d, "load", 80.) as i32,
                },
                "lift_heli" => Kind::Lift {
                    capacity: number(d, "sling", -1.) as i8,
                },
                "attack_heli" => Kind::Gunship {
                    rockets: number(d, "rockets", 4.) as u32,
                },
                "uav" => Kind::Uav {
                    altitude: number(d, "alt", 20.),
                    radius: number(d, "orbit", 16.),
                },
                _ => panic!("unknown aircraft family {base}"),
            };
            return VehicleProfile::Aircraft(sim::aircraft_world::Profile {
                kind,
                scan,
                weapons,
                traverse,
                flight: sim::vehicle_flight::FlightProfile {
                    speed: number(d, "speed", 0.),
                    accel: p["handling"][0].as_f64().unwrap(),
                    brake: p["handling"][1].as_f64().unwrap(),
                    turn: number(p, "hull_turn", 0.),
                    turn_accel: number(p, "hull_accel", 0.),
                },
            });
        }
        if base == "boat" {
            let hulls = &self.definitions["boat_hulls"];
            let response = hulls.get(&v.kind).unwrap_or(&hulls["gun_trawler"]);
            return VehicleProfile::Boat(sim::boat_world::Profile {
                scan,
                weapons,
                traverse,
                movement: sim::vehicle_boat::BoatProfile {
                    hull: point(&d["size"]),
                    speed: number(d, "speed", 0.),
                    response: array(response),
                    cannon: flag(d, "cannon"),
                },
            });
        }
        let movement = self.movement(v);
        if base == "supply" {
            return VehicleProfile::Truck {
                movement,
                load: self.definitions["supply_per_truck"][v.team.max(0) as usize]
                    .as_i64()
                    .unwrap() as i32,
            };
        }
        let art = &d["art"];
        VehicleProfile::Ground(sim::vehicle_world::Ground {
            movement,
            scan,
            crew: self.crew(v),
            weapons,
            traverse,
            artillery: (!art.is_null()).then(|| {
                (
                    sim::vehicle_artillery::ArtilleryProfile {
                        shell: if text(art, "shell", "arty") == "grad" {
                            sim::projectile::Kind::Grad
                        } else {
                            sim::projectile::Kind::Arty
                        },
                        gun_height: number(d, "gun_h", 2.2),
                        muzzle: number(art, "muzzle", 4.),
                        scatter: number(art, "scatter", 3.),
                        salvo: number(art, "salvo", 3.) as i32,
                        lay: number(art, "lay", 2.),
                        gap: number(art, "gap", 0.8),
                        cooldown: number(art, "cd", 18.),
                        traverse: traverse[0],
                        traverse_accel: traverse[1],
                    },
                    [number(art, "min", 40.), number(art, "max", 230.)],
                )
            }),
            service: match text(d, "service", "") {
                "repair" => Some(sim::vehicle_service::Service::Repair),
                "ammo" => Some(sim::vehicle_service::Service::Ammo),
                "medical" => Some(sim::vehicle_service::Service::Medical),
                _ => None,
            },
            light: matches!(base, "car" | "spaa" | "ugv") && number(d, "weight", 1.) == 0.,
        })
    }
    pub fn vehicle_birth(&self, key: &str) -> Option<sim::vehicle_birth::Definition<'_>> {
        let d = &self.definitions["vehicles"][key];
        (!d.is_null()).then(|| sim::vehicle_birth::Definition {
            kind: text(d, "key", ""),
            base: text(d, "base", "tank"),
            hp: number(d, "hp", 100.),
            hull: point(&d["size"]),
            missiles: [
                d["atgm"][0].as_i64().unwrap_or(0) as i32,
                d["sam"][0].as_i64().unwrap_or(0) as i32,
            ],
            tracked: flag(d, "tracked"),
        })
    }
    pub fn squad(&self, key: &str) -> Option<sim::squad_birth::Definition<'_>> {
        let d = &self.definitions["squads"][key];
        self.members
            .get(key)
            .map(|members| sim::squad_birth::Definition {
                kind: text(d, "key", ""),
                name: text(d, "name", ""),
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
            let d = &self.definitions["vehicles"][key];
            return Some(Product::Vehicle {
                definition,
                name: text(d, "name", ""),
                cap: number(d, "cap", 0.) as u32,
                air: flag(d, "air"),
                supply: flag(d, "supply"),
                automatic: flag(d, "auto"),
                passengers: self.squad(text(d, "carry", "")),
            });
        }
        let d = &self.definitions["upgrades"][key];
        (!d.is_null()).then(|| Product::Research {
            key: text(d, "key", ""),
            name: text(d, "name", ""),
        })
    }
    pub fn supply(&self, s: &Infantry) -> sim::structure_services::Supply {
        let d = self.unit(s);
        let weapon = self.weapon(&s.identity.weapon);
        sim::structure_services::Supply {
            ammunition: weapon.map(|w| w.fire.weapon.ammunition),
            frags: number(d, "frags", 0.) as i32,
            loadout: weapon.map(|w| sim::infantry_supply::Loadout {
                ammunition: w.fire.weapon.ammunition,
                special: ["frags", "smokes", "rockets", "drones", "mortar"]
                    .map(|k| number(d, k, 0.) as i32),
                reload_weapon: self
                    .infantry_weapon(s)
                    .map_or(w.fire.weapon, |w| w.fire.weapon),
            }),
        }
    }
    pub fn building(&self, key: &str) -> Option<sim::building_placement::Definition<'_>> {
        let d = &self.definitions["buildings"][key];
        (!d.is_null()).then(|| sim::building_placement::Definition {
            key: text(d, "key", ""),
            name: text(d, "name", ""),
            teams: teams(d),
            cost: number(d, "cost", 0.) as i32,
            body: sim::structure_birth::BuildingProfile {
                size: array::<2>(&d["size"]).map(|v| v as f32),
                hp: number(d, "hp", 0.),
            },
        })
    }
    pub fn support(&self, key: &str) -> Option<sim::support_calls::Definition<'_>> {
        use sim::support_calls::Sortie;
        let d = &self.definitions["support"][key];
        if d.is_null() {
            return None;
        }
        let fly = text(d, "fly", text(d, "key", ""));
        let sortie = match fly {
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
            key: text(d, "key", ""),
            name: text(d, "name", ""),
            model: text(d, "model", ""),
            team: number(d, "team", -1.) as i8,
            cost: number(d, "cost", 0.) as i32,
            from: number(d, "from", 300.),
            cooldown: number(d, "cooldown", 0.),
            radius: number(d, "r", 14.),
            sortie,
            quiet: flag(d, "quiet"),
            leg: number(d, "leg", 420.),
            altitude: number(d, "alt", 60.),
            speed: number(d, "speed", 90.),
            sight: number(d, "sight", 0.),
            stay: number(d, "stay", 0.),
            bombs: number(d, "bombs", 4.) as u32,
            guns: sim::support::Gunset::parse(text(
                d,
                "guns",
                if fly == "watch" { "none" } else { "ac130" },
            )),
            muzzles: std::array::from_fn(|i| point(&d["muzzles"][i])),
        })
    }
    pub fn display(&self, s: &Structure) -> String {
        if !s.name.is_empty() {
            s.name.clone()
        } else {
            text(&self.definitions["buildings"][&s.kind], "name", &s.kind).into()
        }
    }
    pub fn item_name(&self, key: &str) -> String {
        for table in ["squads", "vehicles", "buildings", "upgrades"] {
            if let Some(name) = self.definitions[table][key]["name"].as_str() {
                return name.into();
            }
        }
        key.into()
    }
    pub fn with_profiles<T>(
        &self,
        commanders: &[(i8, u32)],
        f: impl FnOnce(&sim::match_tick::Profiles<'_>, &sim::match_commands::Profiles<'_>) -> T,
    ) -> T {
        let teams = std::array::from_fn(|i| self.definitions["team_names"][i].as_str().unwrap());
        let squad_names = ["rifle_squad", "fighter_cell"]
            .map(|k| text(&self.definitions["squads"][k], "name", ""));
        let movement = |s: &Infantry| sim::squad_movement::ManProfile {
            bearer: flag(self.unit(s), "bearer"),
            weapon_range: self
                .weapon(text(self.unit(s), "weapon", ""))
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
                            let d = &self.definitions["squads"][&q.kind];
                            let cost = d["cost"].as_f64()?;
                            (cost > 0.).then(|| {
                                cost / d["members"].as_array().unwrap().len().max(1) as f64
                            })
                        })
                        .unwrap_or(20.);
                    sim::fires::ManProfile {
                        bearer: flag(self.unit(s), "bearer"),
                        ammunition: self
                            .weapon(&s.identity.weapon)
                            .map(|w| w.fire.weapon.ammunition),
                        value,
                    }
                },
                movement: &movement,
                building: &|s| sim::fires::BuildingProfile {
                    player: !self.definitions["buildings"][&s.kind].is_null(),
                    value: number(&self.definitions["buildings"][&s.kind], "cost", 0.),
                },
                role: &|s| text(self.unit(s), "name", &s.identity.unit).into(),
                automatic: &|k| flag(&self.definitions["vehicles"][k], "auto"),
                player_building: &|k| !self.definitions["buildings"][k].is_null(),
            },
            infantry: sim::infantry_world::Profiles {
                unit: &|s| {
                    let d = self.unit(s);
                    let key = text(d, "weapon", "");
                    sim::infantry_world::Unit {
                        bearer: flag(d, "bearer"),
                        healing: number(d, "heal", 1.),
                        building: number(d, "build", 1.),
                        weapon: self.weapon(key).map(|w| (key, w.fire.weapon)),
                    }
                },
                weapon: &|s| self.infantry_weapon(s),
                gun: &mounted,
                build_time: &|s| self.definitions["buildings"][&s.kind]["time"].as_f64(),
                defense: &|v| sim::infantry_action_owned::Defense {
                    crew: self.crew(v),
                    smoke: sim::vehicle_launch::SmokeProfile {
                        armor: self.armor(v).level,
                        helicopter: flag(self.vehicle(v), "air"),
                        gun_height: number(self.vehicle(v), "gun_h", 2.),
                    },
                },
                armor: &armor,
                vehicle_hit: &|v| number(self.vehicle(v), "hit", 2.),
                transport: &|v| sim::infantry_travel_owned::Transport {
                    seats: self.seats(&v.kind),
                    helicopter: flag(self.vehicle(v), "air"),
                    boat: text(self.vehicle(v), "base", "") == "boat",
                },
            },
            buildings: sim::structures_tick::Profiles {
                product: &|s| self.product(s),
                base_cap: number(&self.definitions, "base_cap", 6.) as u32,
                cap_per_fob: number(&self.definitions, "cap_per_fob", 20.) as u32,
                vehicle_cap: &|v| number(self.vehicle(v), "cap", 0.) as u32,
                supply: &|s| self.supply(s),
                bearers: [&self.loadouts["bearer"]; 2],
                gun: &mounted,
                armor: &armor,
                fob_radius: number(&self.definitions, "fob_radius", 16.),
                towns: std::array::from_fn(|i| sim::structure::TownEconomy {
                    stock: self.definitions["town_stock"][i].as_f64().unwrap(),
                    yield_per_minute: self.definitions["town_yield"][i].as_f64().unwrap(),
                    capture_pace: self.definitions["town_pace"][i].as_f64().unwrap(),
                }),
            },
            squads: sim::squad_world::Profiles {
                role: &|s| sim::squad_duties::Role {
                    medic: flag(self.unit(s), "medic"),
                    engineer: flag(self.unit(s), "engineer"),
                },
                armor: &|k| number(&self.definitions["vehicles"][k], "armor", 0.) as i32,
                weapon: &|s| self.infantry_weapon(s).map(|w| w.fire.weapon),
                air: &|k| flag(&self.definitions["vehicles"][k], "air"),
            },
            rules: sim::rules_world::Profiles {
                reserves: ["rifle_squad", "fighter_cell"].map(|k| self.squad(k).unwrap()),
                truck: sim::rules_logistics::TruckProfile {
                    vehicle: self.vehicle_birth("truck").unwrap(),
                    town_load: array::<2>(&self.definitions["town_load"]).map(|n| n as i32),
                    town_stock: array(&self.definitions["town_stock"]),
                    supply: array::<2>(&self.definitions["supply_per_truck"]).map(|n| n as i32),
                },
                vehicle: &|v| sim::fog::VehicleProfile {
                    sight: number(self.vehicle(v), "sight", 50.),
                    helicopter: flag(self.vehicle(v), "air"),
                    automatic: flag(self.vehicle(v), "auto"),
                    cannon: flag(self.vehicle(v), "cannon"),
                },
                prisoner: &|s| {
                    let d = self.unit(s);
                    let key = text(d, "weapon", "");
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
            build: number(&self.definitions, "build_radius", 70.),
            fob_spacing: number(&self.definitions, "fob_min_spacing", 45.),
            fob_expand: number(&self.definitions, "fob_expand_radius", 130.),
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
                    artillery: (!d["art"].is_null()).then(|| {
                        (
                            number(&d["art"], "min", 40.),
                            number(&d["art"], "max", 230.),
                        )
                    }),
                    sling_capacity: (text(d, "base", "") == "lift_heli" && !flag(d, "supply"))
                        .then(|| number(d, "sling", -1.) as i8),
                }
            },
            mount: &mounted,
            engineer: &|s| flag(self.unit(s), "engineer"),
            mortar: &|s| number(self.unit(s), "mortar", 0.) > 0.,
            structure_name: &|s| self.display(s),
            squad_name: &|q| self.item_name(&q.kind),
            distances: &distances,
            fob_names: &self.fob_names,
        };
        f(&profiles, &commands)
    }
}

fn teams(d: &Value) -> u8 {
    if let Some(teams) = d["teams"].as_array() {
        teams
            .iter()
            .fold(0, |bits, t| bits | (1 << t.as_u64().expect("team index")))
    } else {
        match d["team"].as_i64() {
            Some(0) => 1,
            Some(1) => 2,
            _ => 0,
        }
    }
}
