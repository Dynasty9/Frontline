//! Loaded once; borrowed core profiles contain only copies and references to owned text.
use frontline_core as sim;
use sim::{match_tick::VehicleProfile, vehicle_combat_world, vehicle_weapon};

pub(super) struct Weapons {
    base: String,
    machine_gun: String,
    sound: String,
    cannon_enabled: bool,
    armor: u8,
    burst: [i32; 2],
    interval: f64,
    cannon_cooldown: f64,
    sam_cooldown: f64,
    sam_range: f64,
    atgm_cooldown: f64,
    atgm_range: f64,
    muzzle: sim::vehicle_cannon::Muzzle,
    cannon: Option<sim::vehicle_cannon::CannonProfile>,
    bullet: Option<sim::bullet::Weapon>,
    suppression: f64,
    piercing: bool,
}
impl Weapons {
    fn new(p: vehicle_combat_world::Profile<'_>) -> Self {
        Self {
            base: p.cycle.base.into(),
            machine_gun: p.cycle.machine_gun.into(),
            sound: p.machine_gun.map_or("", |g| g.sound).into(),
            cannon_enabled: p.cycle.cannon,
            armor: p.cycle.armor,
            burst: p.cycle.burst,
            interval: p.cycle.interval,
            cannon_cooldown: p.cycle.cannon_cooldown,
            sam_cooldown: p.cycle.sam_cooldown,
            sam_range: p.cycle.sam_range,
            atgm_cooldown: p.cycle.atgm_cooldown,
            atgm_range: p.cycle.atgm_range,
            muzzle: p.muzzle,
            cannon: p.cannon,
            bullet: p.machine_gun.map(|g| g.weapon),
            suppression: p.machine_gun.map_or(0., |g| g.suppression),
            piercing: p.machine_gun.is_some_and(|g| g.piercing),
        }
    }
    fn profile(&self) -> vehicle_combat_world::Profile<'_> {
        vehicle_combat_world::Profile {
            cycle: vehicle_weapon::FireProfile {
                base: &self.base,
                machine_gun: &self.machine_gun,
                cannon: self.cannon_enabled,
                armor: self.armor,
                burst: self.burst,
                interval: self.interval,
                cannon_cooldown: self.cannon_cooldown,
                sam_cooldown: self.sam_cooldown,
                sam_range: self.sam_range,
                atgm_cooldown: self.atgm_cooldown,
                atgm_range: self.atgm_range,
            },
            muzzle: self.muzzle,
            cannon: self.cannon,
            machine_gun: self.bullet.map(|weapon| vehicle_combat_world::MachineGun {
                weapon,
                suppression: self.suppression,
                sound: &self.sound,
                optics: false,
                piercing: self.piercing,
            }),
        }
    }
}
pub(super) enum Motion {
    Ground {
        movement: sim::vehicle_motion::GroundProfile,
        artillery: Option<(sim::vehicle_artillery::ArtilleryProfile, [f64; 2])>,
        service: Option<sim::vehicle_service::Service>,
        light: bool,
    },
    Aircraft {
        kind: sim::aircraft_world::Kind,
        flight: sim::vehicle_flight::FlightProfile,
    },
    Boat(sim::vehicle_boat::BoatProfile),
    Truck {
        movement: sim::vehicle_motion::GroundProfile,
    },
}
pub(super) struct Vehicle {
    pub armor: sim::vehicle_damage::Armor,
    scan: sim::vehicle_scan::ScanProfile,
    traverse: [f64; 2],
    weapons: Weapons,
    motion: Motion,
}
impl Vehicle {
    pub fn new(content: &super::Content, actor: &sim::vehicle::Vehicle) -> Self {
        let scan = content.scan(actor);
        let weapons = Weapons::new(content.vehicle_weapons(actor));
        let (motion, traverse) = match content.compile_vehicle(actor) {
            VehicleProfile::Ground(p) => (
                Motion::Ground {
                    movement: p.movement,
                    artillery: p.artillery,
                    service: p.service,
                    light: p.light,
                },
                p.traverse,
            ),
            VehicleProfile::Aircraft(p) => (
                Motion::Aircraft {
                    kind: p.kind,
                    flight: p.flight,
                },
                p.traverse,
            ),
            VehicleProfile::Boat(p) => (Motion::Boat(p.movement), p.traverse),
            VehicleProfile::Truck { movement, .. } => (Motion::Truck { movement }, [0.; 2]),
        };
        Self {
            armor: content.compile_armor(actor),
            scan,
            traverse,
            weapons,
            motion,
        }
    }
    pub fn profile(
        &self,
        crew: sim::vehicle_brain::CrewProfile<'_>,
        load: i32,
    ) -> VehicleProfile<'_> {
        let weapons = self.weapons.profile();
        let scan = self.scan;
        let traverse = self.traverse;
        match self.motion {
            Motion::Ground {
                movement,
                artillery,
                service,
                light,
            } => VehicleProfile::Ground(sim::vehicle_world::Ground {
                movement,
                scan,
                crew: sim::vehicle_brain::CrewProfile {
                    base: &self.weapons.base,
                    ..crew
                },
                weapons,
                traverse,
                artillery,
                service,
                light,
            }),
            Motion::Aircraft { kind, flight } => {
                VehicleProfile::Aircraft(sim::aircraft_world::Profile {
                    kind,
                    flight,
                    scan,
                    weapons,
                    traverse,
                })
            }
            Motion::Boat(movement) => VehicleProfile::Boat(sim::boat_world::Profile {
                movement,
                scan,
                weapons,
                traverse,
            }),
            Motion::Truck { movement } => VehicleProfile::Truck { movement, load },
        }
    }
}
