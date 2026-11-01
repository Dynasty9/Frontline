#[allow(dead_code)]
#[path = "vehicle_loss_world.rs"]
mod fixture;
pub use fixture::shared;
use fixture::Scene;
use frontline_core::actors::Actor;
use frontline_core::bullet;
use frontline_core::bullet_world::Gunfire;
use frontline_core::infantry_action_owned::Defense;
use frontline_core::infantry_vitals::Life;
use frontline_core::squad::Report;
use frontline_core::supply_network::SupplyNetwork;
use frontline_core::vector::Vector3;
use frontline_core::vehicle::Vehicle;
use frontline_core::vehicle_brain::CrewProfile;
use frontline_core::vehicle_cannon::{CannonProfile, Muzzle};
use frontline_core::vehicle_combat_world::{Event, MachineGun, Profile};
use frontline_core::vehicle_damage::Armor;
use frontline_core::vehicle_launch::SmokeProfile;
use frontline_core::vehicle_weapon::FireProfile;

pub fn muzzle() -> Muzzle {
    Muzzle {
        socket: None,
        helicopter: false,
        gunship: false,
        gun_height: 2.2,
    }
}
pub fn profile(cannon: bool) -> Profile<'static> {
    Profile {
        cycle: FireProfile {
            base: "tank",
            cannon,
            armor: 2,
            machine_gun: "mmg",
            burst: [1, 1],
            interval: 0.1,
            cannon_cooldown: 5.5,
            sam_cooldown: 8.0,
            sam_range: 160.0,
            atgm_cooldown: 9.0,
            atgm_range: 125.0,
        },
        muzzle: muzzle(),
        cannon: cannon.then_some(CannonProfile {
            muzzle: muzzle(),
            damage: 160.0,
            radius: 5.5,
            anti_tank: 320.0,
            size: 1.4,
        }),
        machine_gun: Some(MachineGun {
            weapon: bullet::Weapon {
                accuracy: 1.0,
                range: 70.0,
                damage: 30.0,
                anti_air: false,
                penetration: 1,
                drone_accuracy: 0.045,
                explosive_radius: None,
                airburst: false,
            },
            suppression: 15.0,
            sound: "mg",
            optics: false,
            piercing: false,
        }),
    }
}
pub fn armor(v: &Vehicle) -> Armor {
    Armor {
        level: 2,
        helicopter: v.kind == "heli",
        boat: false,
        supply: false,
        toss: 2.0,
    }
}
pub fn defense(_: &Vehicle) -> Defense<'static> {
    Defense {
        smoke: SmokeProfile {
            armor: 2,
            helicopter: false,
            gun_height: 2.2,
        },
        crew: CrewProfile {
            base: "tank",
            helicopter: false,
            automatic: false,
            artillery: false,
            tracked: true,
            armor: 2,
        },
    }
}
pub fn vehicle(id: u32, team: i8, z: f32) -> Vehicle {
    Vehicle {
        id,
        team,
        owner: 7 + team as i32,
        kind: "tank".into(),
        position: Vector3::Z * z,
        cannon_timer: 0.0,
        aim_time: 1.0,
        ..Default::default()
    }
}
pub struct Field {
    pub scene: Scene,
    pub gunfire: Gunfire,
    pub network: SupplyNetwork,
    pub impacts: Vec<Report>,
}
impl Field {
    pub fn new(v: Vehicle, target: Actor) -> Self {
        Self {
            scene: Scene::new(vec![Actor::Vehicle(Box::new(v)), target], 7135),
            gunfire: Gunfire::default(),
            network: SupplyNetwork::default(),
            impacts: vec![],
        }
    }
    pub fn resume(&self) -> Self {
        Self {
            scene: self.scene.resume(),
            gunfire: Gunfire::restore(&self.gunfire.checkpoint()).unwrap(),
            network: SupplyNetwork::restore(&self.network.checkpoint().unwrap()).unwrap(),
            impacts: self.impacts.clone(),
        }
    }
    pub fn fire(&mut self, p: Profile<'_>) -> Result<Vec<Event>, &'static str> {
        self.scene.context().advance_vehicle_fire(
            20,
            p,
            &mut self.gunfire,
            &mut self.network,
            &mut self.impacts,
            &armor,
            &|_| 2.0,
            &defense,
        )
    }
    pub fn compare(&self, other: &Self) {
        self.scene.world.compare(&other.scene.world);
        assert_eq!(
            self.scene.fires.checkpoint(),
            other.scene.fires.checkpoint()
        );
        assert_eq!(self.scene.next, other.scene.next);
        assert_eq!(self.gunfire.checkpoint(), other.gunfire.checkpoint());
        assert_eq!(
            self.network.checkpoint().unwrap(),
            other.network.checkpoint().unwrap()
        );
        assert_eq!(self.impacts, other.impacts);
    }
}
pub fn infantry(life: Life) -> Actor {
    let mut s = shared::soldier(1, 0.0, life);
    s.identity.team = 1;
    s.identity.owner = 8;
    s.motion.position.z = -10.0;
    Actor::Soldier(Box::new(s))
}

pub fn transcript() -> Vec<u8> {
    use frontline_core::infantry_supply::Loadout;
    use frontline_core::infantry_weapon::Weapon;
    use frontline_core::projectile::Kind;
    use frontline_core::vehicle_artillery::ArtilleryProfile;
    use frontline_core::vehicle_service::{Service, SoldierSupply};
    fn block(out: &mut Vec<u8>, bytes: &[u8]) {
        out.extend_from_slice(&(bytes.len() as u32).to_le_bytes());
        out.extend_from_slice(bytes);
    }
    fn step(field: &mut Field, trial: usize) -> Vec<Event> {
        if trial < 4 {
            field.fire(profile(trial != 0)).unwrap()
        } else if trial == 4 {
            field
                .scene
                .context()
                .advance_vehicle_artillery(
                    20,
                    1.0,
                    ArtilleryProfile {
                        shell: Kind::Grad,
                        gun_height: 2.2,
                        muzzle: 4.0,
                        scatter: 3.0,
                        salvo: 3,
                        lay: 0.5,
                        gap: 0.8,
                        cooldown: 18.0,
                        traverse: 1.0,
                        traverse_accel: 2.0,
                    },
                    [40.0, 230.0],
                    &[],
                )
                .unwrap()
        } else {
            field
                .scene
                .context()
                .advance_vehicle_service(
                    20,
                    1.0,
                    [Service::Repair, Service::Ammo, Service::Medical][trial - 5],
                    &|_| {
                        Ok(SoldierSupply {
                            loadout: Some(Loadout {
                                ammunition: 120,
                                special: [2, 1, 3, 1, 4],
                                reload_weapon: Weapon {
                                    ammunition: 120,
                                    magazine: 30,
                                    reload_time: 2.2,
                                },
                            }),
                            restored_weapon: Some(("rifle", 30)),
                        })
                    },
                    &|_| Ok([4, 4]),
                )
                .unwrap()
        }
    }
    let mut out = vec![];
    for trial in 0..8 {
        let mut v = vehicle(
            20,
            if trial >= 5 { 1 } else { 0 },
            if trial >= 5 { 0.0 } else { 10.0 },
        );
        let mut target = if (1..=3).contains(&trial) || trial == 5 {
            let mut enemy = vehicle(21, 1, -10.0);
            if trial == 3 {
                enemy.kind = "heli".into();
                enemy.position.y = 8.0;
            }
            if trial == 5 {
                enemy.hp = 15.0;
                enemy.track_broken = true;
            }
            Actor::Vehicle(Box::new(enemy))
        } else {
            infantry(if trial == 7 {
                Life::Downed
            } else {
                Life::Alive
            })
        };
        if trial == 6 {
            if let Actor::Soldier(s) = &mut target {
                s.weapon.magazine = 0;
                s.weapon.reserve = 0;
            }
        }
        v.target = if (1..=3).contains(&trial) { 21 } else { 1 };
        if trial == 2 {
            v.atgm_left = 3;
        }
        if trial == 3 {
            v.sam_left = 3;
        }
        if trial == 4 {
            v.artillery_until = 0.0;
            v.fire_queue = vec![Vector3::Z * -10.0];
        }
        let mut field = Field::new(v, target);
        for _ in 0..12 {
            field.scene.world.now += 1.0;
            let mut resumed = field.resume();
            let events = step(&mut field, trial);
            assert_eq!(events, step(&mut resumed, trial));
            field.compare(&resumed);
            block(&mut out, format!("{events:?}").as_bytes());
            block(&mut out, &field.scene.world.actors.checkpoint().unwrap());
            for q in &field.scene.world.squads {
                block(&mut out, &q.checkpoint().unwrap());
            }
            block(&mut out, &field.scene.world.geometry.checkpoint());
            block(&mut out, &field.scene.world.units.checkpoint());
            block(&mut out, &field.scene.world.battle.checkpoint());
            block(&mut out, &field.scene.world.deferred.checkpoint());
            block(&mut out, &field.scene.world.visibility.checkpoint());
            block(&mut out, &field.scene.fires.checkpoint());
            block(&mut out, &field.gunfire.checkpoint());
            block(&mut out, &field.network.checkpoint().unwrap());
            block(&mut out, format!("{:?}", field.impacts).as_bytes());
            out.extend_from_slice(&field.scene.world.rng.state().to_le_bytes());
            out.extend_from_slice(&field.scene.next.to_le_bytes());
        }
    }
    out
}
