#[allow(dead_code)]
#[path = "fires_world.rs"]
pub mod shared;
use frontline_core::actors::Actor;
use frontline_core::fires::{BuildingProfile, Fires, ManProfile};
use frontline_core::infantry_spawn::Loadout;
use frontline_core::random::SimulationRandom;
use frontline_core::squad_movement;
use frontline_core::vector::Vector3;
use frontline_core::vehicle::{LastBlast, Vehicle};
use frontline_core::vehicle_loss::Crew;
use frontline_core::vehicle_loss_world::{Context, Event, Profile};

pub struct Scene {
    pub world: shared::Battle,
    pub fires: Fires,
    pub next: u64,
    names: [Vec<String>; 2],
    loadouts: [Loadout; 2],
}
fn profile(v: &Vehicle) -> Profile<'static> {
    let base = match v.kind.as_str() {
        "boat" => "boat",
        "supply" => "supply",
        "heli" => "lift_heli",
        _ => "tank",
    };
    Profile {
        name: "Test vehicle",
        weight: 2,
        hull: Vector3::new(3.0, 2.0, 5.0),
        crew: Crew {
            base,
            helicopter: base == "lift_heli",
            automatic: v.kind == "robot",
            count: Some(3),
            cost: 500.0,
            armor_upgrade: false,
            grenade_upgrade: false,
        },
    }
}
pub fn vehicle(id: u32, kind: &str) -> Actor {
    Actor::Vehicle(Box::new(Vehicle {
        id,
        kind: kind.into(),
        team: 0,
        owner: 7,
        hp: 100.0,
        max_hp: 100.0,
        position: Vector3::ZERO,
        yaw: 0.37,
        ..Default::default()
    }))
}
impl Scene {
    pub fn new(entries: Vec<Actor>, seed: u64) -> Self {
        let mut world = shared::Battle::new(entries);
        world.rng = SimulationRandom::new(seed);
        world.now = 100.0;
        for actor in world.actors.iter() {
            if let Actor::Vehicle(v) = actor {
                world
                    .geometry
                    .refresh_vehicle_collision(v, profile(v).hull)
                    .unwrap();
            }
        }
        Self {
            world,
            fires: Fires::new(32, false).unwrap(),
            next: 7,
            names: [vec!["Jones".into(), "Perez".into()], vec!["Petrov".into()]],
            loadouts: std::array::from_fn(|side| Loadout {
                unit: if side == 0 { "crewman" } else { "r_crewman" }.into(),
                weapon: "smg".into(),
                hp: 90.0,
                magazine: 30,
                ammunition: 120,
                grenades: 0,
                smokes: 1,
                rockets: 0,
                mortar_rounds: 0,
                drones: 0,
                bearer: false,
            }),
        }
    }
    pub fn damage(
        &mut self,
        id: u32,
        amount: f64,
        source: u32,
    ) -> Result<Vec<Event>, &'static str> {
        Context {
            actors: &mut self.world.actors,
            geometry: &mut self.world.geometry,
            units: &self.world.units,
            squads: &mut self.world.squads,
            next_squad: &mut self.next,
            fires: &mut self.fires,
            battle: &mut self.world.battle,
            deferred: &mut self.world.deferred,
            visibility: &mut self.world.visibility,
            rng: &mut self.world.rng,
            now: self.world.now,
            town: [0.0; 4],
            names: &self.names,
            crew_loadouts: &self.loadouts,
            crew_name: "Tank Crew",
            team_names: &["Coalition", "Rebels"],
            vehicle: &|v| profile(v),
            man: &|_, _| ManProfile {
                bearer: false,
                ammunition: Some(120),
                value: 17.0,
            },
            movement: &|_| squad_movement::ManProfile {
                bearer: false,
                weapon_range: Some(85.0),
            },
            building: &|st| BuildingProfile {
                player: st.kind == "fob",
                value: 100.0,
            },
            role: &|s| s.identity.unit.clone(),
            automatic: &|k| k == "robot",
            player_building: &|k| k == "fob",
        }
        .damage(id, amount, source)
    }
    pub fn resume(&self) -> Self {
        Self {
            world: self.world.resume(),
            fires: Fires::restore(&self.fires.checkpoint()).unwrap(),
            next: self.next,
            names: self.names.clone(),
            loadouts: self.loadouts.clone(),
        }
    }
}

pub fn transcript() -> Vec<u8> {
    fn block(out: &mut Vec<u8>, bytes: &[u8]) {
        out.extend_from_slice(&(bytes.len() as u32).to_le_bytes());
        out.extend_from_slice(bytes);
    }
    let mut out = vec![];
    for seed in 0..20 {
        let mut v = vehicle(
            20,
            ["tank", "supply", "boat", "heli", "robot"][seed as usize % 5],
        );
        if let Actor::Vehicle(v) = &mut v {
            v.destination_fob = 30;
            v.cargo = 71;
            v.last_blast = Some(LastBlast {
                position: Vector3::new(-1.3, 0.0, 0.7),
                size: 2.7,
                time: 99.8,
            });
            v.passengers = vec![1, 2];
        }
        let mut entries = vec![v, shared::actor(shared::structure(30, "fob", -9.0))];
        if seed % 5 == 3 {
            if let Actor::Vehicle(v) = &mut entries[0] {
                v.sling_cargo = 21;
                v.position.y = 30.0;
            }
            let mut cargo = vehicle(21, "robot");
            if let Actor::Vehicle(v) = &mut cargo {
                v.slung_by = 20;
                v.position.y = 27.0;
                v.hp = 20.0;
            }
            entries.push(cargo);
        }
        for id in [1, 2] {
            let mut s = shared::soldier(id, 0.0, frontline_core::infantry_vitals::Life::Hidden);
            s.links.vehicle = 20;
            entries.push(Actor::Soldier(Box::new(s)));
        }
        let mut s = Scene::new(entries, 137 + seed);
        for amount in [31.7, 89.1] {
            s = s.resume();
            let events = s.damage(20, amount, 0).unwrap();
            block(&mut out, format!("{events:?}").as_bytes());
            block(&mut out, &s.world.actors.checkpoint().unwrap());
            block(&mut out, &s.world.geometry.checkpoint());
            block(&mut out, &s.world.units.checkpoint());
            for q in &s.world.squads {
                block(&mut out, &q.checkpoint().unwrap());
            }
            block(&mut out, &s.fires.checkpoint());
            block(&mut out, &s.world.battle.checkpoint());
            block(&mut out, &s.world.deferred.checkpoint());
            block(&mut out, &s.world.visibility.checkpoint());
            block(&mut out, &s.world.rng.state().to_le_bytes());
            block(&mut out, &s.next.to_le_bytes());
        }
    }
    out
}
