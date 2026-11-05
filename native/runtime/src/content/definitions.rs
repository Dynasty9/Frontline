//! Typed, immutable authoring data. JSON is discarded after the catalog is loaded.
use serde::Deserialize;
use std::collections::BTreeMap;

#[derive(Debug, Default, Deserialize)]
pub struct Unit {
    pub hp: Option<f64>,
    pub frags: Option<f64>,
    pub smokes: Option<f64>,
    pub rockets: Option<f64>,
    pub mortar: Option<f64>,
    pub drones: Option<f64>,
    pub heal: Option<f64>,
    pub build: Option<f64>,
    #[serde(default)]
    pub key: String,
    #[serde(default)]
    pub name: String,
    #[serde(default)]
    pub weapon: String,
    #[serde(default)]
    pub bearer: bool,
    #[serde(default)]
    pub medic: bool,
    #[serde(default)]
    pub engineer: bool,
}

#[derive(Debug, Default, Deserialize)]
pub struct Vehicle {
    pub armor: Option<f64>,
    pub weight: Option<f64>,
    pub cost: Option<f64>,
    pub speed: Option<f64>,
    pub sight: Option<f64>,
    pub gun_h: Option<f64>,
    pub load: Option<f64>,
    pub sling: Option<f64>,
    pub rockets: Option<f64>,
    pub alt: Option<f64>,
    pub orbit: Option<f64>,
    pub hp: Option<f64>,
    pub cap: Option<f64>,
    pub tier: Option<f64>,
    pub hit: Option<f64>,
    pub seats: Option<f64>,
    pub crew: Option<f64>,
    pub sam_range: Option<f64>,
    pub atgm_range: Option<f64>,
    pub team: Option<f64>,
    #[serde(default)]
    pub key: String,
    #[serde(default)]
    pub name: String,
    #[serde(default)]
    pub base: String,
    #[serde(default)]
    pub mg: String,
    #[serde(default)]
    pub carry: String,
    #[serde(default)]
    pub service: String,
    #[serde(default)]
    pub air: bool,
    #[serde(default)]
    #[serde(rename = "auto")]
    pub automatic: bool,
    #[serde(default)]
    pub tracked: bool,
    #[serde(default)]
    pub cannon: bool,
    #[serde(default)]
    pub aa: bool,
    #[serde(default)]
    pub supply: bool,
    pub size: [f64; 3],
    pub art: Option<Artillery>,
    pub gun: Option<Gun>,
    pub atgm: Option<[f64; 2]>,
    pub sam: Option<[f64; 2]>,
    pub symbol: Option<[String; 2]>,
}

#[derive(Debug, Default, Deserialize)]
pub struct Motion {
    pub hull_turn: Option<f64>,
    pub hull_accel: Option<f64>,
    pub traverse: Option<f64>,
    pub traverse_accel: Option<f64>,
    pub handling: [f64; 4],
}

#[derive(Debug, Default, Deserialize)]
pub struct Artillery {
    pub muzzle: Option<f64>,
    pub scatter: Option<f64>,
    pub salvo: Option<f64>,
    pub lay: Option<f64>,
    pub gap: Option<f64>,
    pub cd: Option<f64>,
    pub min: Option<f64>,
    pub max: Option<f64>,
    #[serde(default)]
    pub shell: String,
}

#[derive(Debug, Default, Deserialize)]
pub struct Gun {
    pub cd: Option<f64>,
    pub dmg: Option<f64>,
    pub radius: Option<f64>,
    pub at: Option<f64>,
    pub size: Option<f64>,
}

#[derive(Debug, Default, Deserialize)]
pub struct Weapon {
    pub ammo: Option<f64>,
    pub interval: Option<f64>,
    #[serde(default)]
    pub ap: bool,
    pub burst: [i32; 2],
}

#[derive(Debug, Default, Deserialize)]
pub struct MountedGun {
    pub bore: Option<f64>,
    pub muzzle: Option<f64>,
    pub nest_h: Option<f64>,
    pub trench_h: Option<f64>,
    pub grip_r: [f64; 3],
}

#[derive(Debug, Default, Deserialize)]
pub struct Socket {
    pub point: [f64; 3],
    pub pivot: Option<[f64; 3]>,
}

#[derive(Debug, Default, Deserialize)]
pub struct Squad {
    pub cost: Option<f64>,
    #[serde(default)]
    pub key: String,
    #[serde(default)]
    pub name: String,
    pub members: Vec<String>,
}

#[derive(Debug, Default, Deserialize)]
pub struct Building {
    pub cost: Option<f64>,
    pub hp: Option<f64>,
    pub time: Option<f64>,
    #[serde(default)]
    pub key: String,
    #[serde(default)]
    pub name: String,
    pub size: [f64; 2],
    pub teams: Vec<u8>,
}

#[derive(Debug, Default, Deserialize)]
pub struct Upgrade {
    #[serde(default)]
    pub key: String,
    #[serde(default)]
    pub name: String,
}

#[derive(Debug, Default, Deserialize)]
pub struct Support {
    #[serde(default)]
    pub recon: bool,
    pub team: Option<f64>,
    pub cost: Option<f64>,
    pub from: Option<f64>,
    pub cooldown: Option<f64>,
    pub r: Option<f64>,
    pub leg: Option<f64>,
    pub alt: Option<f64>,
    pub speed: Option<f64>,
    pub sight: Option<f64>,
    pub stay: Option<f64>,
    pub bombs: Option<f64>,
    #[serde(default)]
    pub key: String,
    #[serde(default)]
    pub name: String,
    #[serde(default)]
    pub model: String,
    #[serde(default)]
    pub fly: String,
    #[serde(default)]
    pub guns: String,
    #[serde(default)]
    pub quiet: bool,
    pub muzzles: [[f64; 3]; 3],
}

#[derive(Debug, Default, Deserialize)]
pub struct Mission {
    #[serde(default)]
    pub key: String,
    #[serde(default)]
    pub title: String,
    #[serde(default)]
    pub op: String,
}

#[derive(Debug, Deserialize)]
pub struct Definitions {
    pub units: BTreeMap<String, Unit>,
    pub vehicles: BTreeMap<String, Vehicle>,
    pub motion: BTreeMap<String, Motion>,
    pub weapons: BTreeMap<String, Weapon>,
    pub mounted_guns: BTreeMap<String, MountedGun>,
    pub squads: BTreeMap<String, Squad>,
    pub buildings: BTreeMap<String, Building>,
    pub upgrades: BTreeMap<String, Upgrade>,
    pub support: BTreeMap<String, Support>,
    pub sockets: BTreeMap<String, BTreeMap<String, Socket>>,
    pub boat_hulls: BTreeMap<String, [f64; 9]>,
    pub missions: Vec<Mission>,
    pub team_names: [String; 2],
    pub base_cap: f64,
    pub cap_per_fob: f64,
    pub fob_radius: f64,
    pub build_radius: f64,
    pub fob_min_spacing: f64,
    pub fob_expand_radius: f64,
    pub town_load: [f64; 2],
    pub town_stock: [f64; 2],
    pub town_yield: [f64; 2],
    pub town_pace: [f64; 2],
    pub supply_per_truck: [f64; 2],
}
