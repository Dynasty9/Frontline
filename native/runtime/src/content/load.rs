//! Validate authoring data and compile immutable profiles before a match starts.
use super::*;
use serde_json::Value;

fn number(d: &Value, key: &str, default: f64) -> f64 {
    d[key].as_f64().unwrap_or(default)
}
fn flag(d: &Value, key: &str) -> bool {
    d[key].as_bool().unwrap_or(false)
}
fn text<'a>(d: &'a Value, key: &str, default: &'a str) -> &'a str {
    d[key].as_str().unwrap_or(default)
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
}

impl Content {
    pub fn bundled() -> Result<Self, String> {
        Self::load(SOURCE)
    }
    fn load(source: &str) -> Result<Self, String> {
        let definitions: Value = serde_json::from_str(source).map_err(|e| e.to_string())?;
        let typed: Definitions =
            serde_json::from_value(definitions.clone()).map_err(|e| e.to_string())?;
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
        let crew = [
            loadouts.get("crewman").ok_or("missing crewman")?.clone(),
            loadouts
                .get("r_crewman")
                .ok_or("missing r_crewman")?
                .clone(),
        ];
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
                    teams: teams(d)?,
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
        let mut content = Self {
            vehicles: BTreeMap::new(),
            weapons,
            digest: *blake3::hash(source.replace("\r\n", "\n").as_bytes()).as_bytes(),
            definitions: typed,
            loadouts,
            members,
            names,
            crew,
            fob_names,
            items,
            research,
            produces,
        };
        content.validate_definitions()?;
        for key in content.definitions.vehicles.keys() {
            let actor = Vehicle {
                kind: key.clone(),
                ..Default::default()
            };
            content
                .vehicles
                .insert(key.clone(), vehicles::Vehicle::new(&content, &actor));
        }
        Ok(content)
    }
    fn validate_definitions(&self) -> Result<(), String> {
        for (key, d) in &self.definitions.buildings {
            if d.teams.iter().any(|&t| t > 1) || !self.building(key).is_some_and(|p| p.valid()) {
                return Err(format!("invalid building definition {key}"));
            }
        }
        for key in self.definitions.support.keys() {
            if !self.support(key).is_some_and(|p| p.valid()) {
                return Err(format!("invalid support definition {key}"));
            }
        }
        for (key, d) in &self.definitions.vehicles {
            if d.key != *key
                || d.name.is_empty()
                || d.base.is_empty()
                || !self.definitions.motion.contains_key(key)
                || !(0. ..=2.).contains(&d.weight.unwrap_or(1.))
                || (!d.mg.is_empty() && !self.weapons.contains_key(&d.mg))
                || (!d.carry.is_empty() && !self.members.contains_key(&d.carry))
                || (d.air && !matches!(d.base.as_str(), "lift_heli" | "attack_heli" | "uav"))
            {
                return Err(format!("invalid vehicle definition {key}"));
            }
        }
        if !self.definitions.boat_hulls.contains_key("gun_trawler") {
            return Err("missing default boat response".into());
        }
        Ok(())
    }
    pub(super) fn compile_armor(&self, v: &Vehicle) -> sim::vehicle_damage::Armor {
        let d = self.vehicle(v);
        let base = d.base.as_str();
        sim::vehicle_damage::Armor {
            level: d.armor.unwrap_or(0.) as u8,
            helicopter: d.air,
            boat: base == "boat",
            supply: base == "supply",
            toss: [2.2, 0.9, 0.3][d.weight.unwrap_or(1.) as usize],
        }
    }
    pub(super) fn movement(&self, v: &Vehicle) -> sim::vehicle_motion::GroundProfile {
        let d = self.vehicle(v);
        let p = &self.definitions.motion[&v.kind];
        let base = d.base.as_str();
        sim::vehicle_motion::GroundProfile {
            hull: Vector3::new(d.size[0] as f32, d.size[1] as f32, d.size[2] as f32),
            tracked: d.tracked,
            weight: d.weight.unwrap_or(1.) as u8,
            supply: base == "supply",
            tank: base == "tank",
            cannon: d.cannon,
            speed: d.speed.unwrap_or(0.),
            turn: p.hull_turn.unwrap_or(0.),
            turn_accel: p.hull_accel.unwrap_or(0.),
            handling: p.handling,
        }
    }
    pub(super) fn scan(&self, v: &Vehicle) -> sim::vehicle_scan::ScanProfile {
        let d = self.vehicle(v);
        let gunship = d.base.as_str() == "attack_heli";
        let w = self.weapons.get(d.mg.as_str());
        sim::vehicle_scan::ScanProfile {
            sight: d.sight.unwrap_or(50.),
            gun_height: d.gun_h.unwrap_or(if gunship { 0.8 } else { 2.2 }),
            cannon: d.cannon,
            gunship,
            anti_air: d.aa,
            penetrating_mg: w.is_some_and(|w| w.piercing),
        }
    }
    pub(super) fn muzzle(&self, v: &Vehicle, gun: &str) -> sim::vehicle_cannon::Muzzle {
        let d = self.vehicle(v);
        let socket = self
            .definitions
            .sockets
            .get(&v.kind)
            .and_then(|s| s.get(gun));
        let gunship = d.base.as_str() == "attack_heli";
        sim::vehicle_cannon::Muzzle {
            socket: socket.map(|socket| sim::vehicle_cannon::Socket {
                point: vector(socket.point),
                pivot: socket.pivot.map(vector),
            }),
            helicopter: d.air,
            gunship,
            gun_height: d.gun_h.unwrap_or(if gunship { 0.8 } else { 2.2 }),
        }
    }
    pub(super) fn vehicle_weapons(&self, v: &Vehicle) -> sim::vehicle_combat_world::Profile<'_> {
        let d = self.vehicle(v);
        let gun = d.gun.as_ref();
        let mg = d.mg.as_str();
        let w = self.weapons.get(mg);
        sim::vehicle_combat_world::Profile {
            cycle: sim::vehicle_weapon::FireProfile {
                base: d.base.as_str(),
                cannon: d.cannon,
                armor: d.armor.unwrap_or(0.) as u8,
                machine_gun: mg,
                burst: w.map_or([1, 1], |w| [w.fire.burst_min, w.fire.burst_max]),
                interval: w.map_or(0.1, |w| w.interval),
                cannon_cooldown: gun.and_then(|g| g.cd).unwrap_or(5.5),
                sam_cooldown: d.sam.map_or(0., |m| m[1]),
                sam_range: d.sam_range.unwrap_or(160.),
                atgm_cooldown: d.atgm.map_or(0., |m| m[1]),
                atgm_range: d.atgm_range.unwrap_or(125.),
            },
            muzzle: self.muzzle(v, "mg"),
            cannon: d.cannon.then(|| sim::vehicle_cannon::CannonProfile {
                muzzle: self.muzzle(v, "gun"),
                damage: gun.and_then(|g| g.dmg).unwrap_or(160.),
                radius: gun.and_then(|g| g.radius).unwrap_or(5.5),
                anti_tank: gun.and_then(|g| g.at).unwrap_or(320.),
                size: gun.and_then(|g| g.size).unwrap_or(1.4),
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
    pub(super) fn compile_vehicle(&self, v: &Vehicle) -> sim::match_tick::VehicleProfile<'_> {
        use sim::match_tick::VehicleProfile;
        let d = self.vehicle(v);
        let p = &self.definitions.motion[&v.kind];
        let base = d.base.as_str();
        let traverse = [p.traverse.unwrap_or(0.), p.traverse_accel.unwrap_or(0.)];
        let scan = self.scan(v);
        let weapons = self.vehicle_weapons(v);
        if d.air {
            use sim::aircraft_world::Kind;
            let kind = match base {
                "lift_heli" if d.supply => Kind::Supply {
                    load: d.load.unwrap_or(80.) as i32,
                },
                "lift_heli" => Kind::Lift {
                    capacity: d.sling.unwrap_or(-1.) as i8,
                },
                "attack_heli" => Kind::Gunship {
                    rockets: d.rockets.unwrap_or(4.) as u32,
                },
                "uav" => Kind::Uav {
                    altitude: d.alt.unwrap_or(20.),
                    radius: d.orbit.unwrap_or(16.),
                },
                _ => panic!("unknown aircraft family {base}"),
            };
            return VehicleProfile::Aircraft(sim::aircraft_world::Profile {
                kind,
                scan,
                weapons,
                traverse,
                flight: sim::vehicle_flight::FlightProfile {
                    speed: d.speed.unwrap_or(0.),
                    accel: p.handling[0],
                    brake: p.handling[1],
                    turn: p.hull_turn.unwrap_or(0.),
                    turn_accel: p.hull_accel.unwrap_or(0.),
                },
            });
        }
        if base == "boat" {
            let hulls = &self.definitions.boat_hulls;
            let response = hulls.get(&v.kind).unwrap_or(&hulls["gun_trawler"]);
            return VehicleProfile::Boat(sim::boat_world::Profile {
                scan,
                weapons,
                traverse,
                movement: sim::vehicle_boat::BoatProfile {
                    hull: Vector3::new(d.size[0] as f32, d.size[1] as f32, d.size[2] as f32),
                    speed: d.speed.unwrap_or(0.),
                    response: *response,
                    cannon: d.cannon,
                },
            });
        }
        let movement = self.movement(v);
        if base == "supply" {
            return VehicleProfile::Truck {
                movement,
                load: self.definitions.supply_per_truck[v.team.max(0) as usize] as i32,
            };
        }
        let art = d.art.as_ref();
        VehicleProfile::Ground(sim::vehicle_world::Ground {
            movement,
            scan,
            crew: self.crew(v),
            weapons,
            traverse,
            artillery: art.map(|art| {
                (
                    sim::vehicle_artillery::ArtilleryProfile {
                        shell: if art.shell.as_str() == "grad" {
                            sim::projectile::Kind::Grad
                        } else {
                            sim::projectile::Kind::Arty
                        },
                        gun_height: d.gun_h.unwrap_or(2.2),
                        muzzle: art.muzzle.unwrap_or(4.),
                        scatter: art.scatter.unwrap_or(3.),
                        salvo: art.salvo.unwrap_or(3.) as i32,
                        lay: art.lay.unwrap_or(2.),
                        gap: art.gap.unwrap_or(0.8),
                        cooldown: art.cd.unwrap_or(18.),
                        traverse: traverse[0],
                        traverse_accel: traverse[1],
                    },
                    [art.min.unwrap_or(40.), art.max.unwrap_or(230.)],
                )
            }),
            service: match d.service.as_str() {
                "repair" => Some(sim::vehicle_service::Service::Repair),
                "ammo" => Some(sim::vehicle_service::Service::Ammo),
                "medical" => Some(sim::vehicle_service::Service::Medical),
                _ => None,
            },
            light: matches!(base, "car" | "spaa" | "ugv") && d.weight.unwrap_or(1.) == 0.,
        })
    }
}

fn teams(d: &Value) -> Result<u8, String> {
    if let Some(teams) = d["teams"].as_array() {
        let mut bits = 0;
        for team in teams {
            let team = team
                .as_u64()
                .filter(|&t| t < 2)
                .ok_or("invalid content team")?;
            bits |= 1 << team;
        }
        Ok(bits)
    } else {
        Ok(match d["team"].as_i64() {
            Some(0) => 1,
            Some(1) => 2,
            _ => 0,
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn malformed_definitions_fail_before_a_match_can_start() {
        for (table, key, field, value) in [
            ("weapons", "m4", "burst", serde_json::json!([1])),
            ("vehicles", "tank", "weight", serde_json::json!(3)),
            ("vehicles", "tank", "mg", serde_json::json!("missing")),
            (
                "vehicles",
                "ghosthawk",
                "base",
                serde_json::json!("missing"),
            ),
            ("buildings", "factory", "teams", serde_json::json!([9])),
        ] {
            let mut source: Value = serde_json::from_str(SOURCE).unwrap();
            source[table][key][field] = value;
            assert!(
                Content::load(&source.to_string()).is_err(),
                "{table}/{key}/{field}"
            );
        }
    }
}
