#[allow(dead_code)]
#[path = "vehicle_loss_world.rs"]
mod fixture;
use fixture::{shared, Scene};
use frontline_core::actors::Actor;
use frontline_core::bullet;
use frontline_core::bullet_world::Gunfire;
use frontline_core::infantry::Infantry;
use frontline_core::infantry_action::{Action, Round, Throw};
use frontline_core::infantry_action_owned::Defense;
use frontline_core::infantry_control::HiddenReason;
use frontline_core::infantry_controller::Task;
use frontline_core::infantry_fight_world::Profile;
use frontline_core::infantry_fire::{FireProfile, MountedGun};
use frontline_core::infantry_travel_owned::Transport;
use frontline_core::infantry_vitals::Life;
use frontline_core::infantry_weapon::Weapon;
use frontline_core::infantry_world::{Event, Profiles, Tick, Unit};
use frontline_core::perception::PerceptionSearch;
use frontline_core::squad::{Report, Squad};
use frontline_core::supply_network::SupplyNetwork;
use frontline_core::vehicle_brain::CrewProfile;
use frontline_core::vehicle_damage::Armor;
use frontline_core::vehicle_launch::SmokeProfile;

pub fn weapon() -> Weapon {
    Weapon {
        ammunition: 120,
        magazine: 30,
        reload_time: 2.2,
    }
}
pub fn profile(s: &Infantry) -> Option<Profile<'static>> {
    (!s.identity.weapon.is_empty()).then_some(Profile {
        fire: FireProfile {
            weapon: weapon(),
            burst_min: 2,
            burst_max: 4,
        },
        bullet: bullet::Weapon {
            accuracy: 0.6,
            range: 60.0,
            damage: 30.0,
            anti_air: false,
            penetration: 0,
            drone_accuracy: 0.03,
            explosive_radius: None,
            airburst: false,
        },
        interval: 0.12,
        suppression: 11.0,
        sound: "rifle",
        optics: false,
        piercing: false,
    })
}
pub struct Field {
    pub scene: Scene,
    gunfire: Gunfire,
    network: SupplyNetwork,
    impacts: Vec<Report>,
    chat: [f64; 2],
}
impl Field {
    pub fn new(mut man: Infantry, mut patient: Infantry) -> Self {
        man.identity.squad = 1;
        patient.identity.squad = 2;
        let mut scene = Scene::new(
            vec![
                Actor::Soldier(Box::new(man)),
                Actor::Soldier(Box::new(patient)),
            ],
            8197,
        );
        scene.world.squads = (0..2)
            .map(|team| Squad {
                id: team + 1,
                team: team as i8,
                owner: 7 + team as i32,
                members: vec![team + 1],
                ..Default::default()
            })
            .collect();
        Self {
            scene,
            gunfire: Gunfire::default(),
            network: SupplyNetwork::default(),
            impacts: vec![],
            chat: [0.0; 2],
        }
    }
    pub fn resume(&self) -> Self {
        Self {
            scene: self.scene.resume(),
            gunfire: Gunfire::restore(&self.gunfire.checkpoint()).unwrap(),
            network: SupplyNetwork::restore(&self.network.checkpoint().unwrap()).unwrap(),
            impacts: self.impacts.clone(),
            chat: self.chat,
        }
    }
    pub fn compare(&self, other: &Self) {
        self.scene.world.compare(&other.scene.world);
        assert_eq!(self.gunfire.checkpoint(), other.gunfire.checkpoint());
        assert_eq!(
            self.network.checkpoint().unwrap(),
            other.network.checkpoint().unwrap()
        );
        assert_eq!(self.impacts, other.impacts);
        assert_eq!(self.chat, other.chat);
    }
    pub fn step(&mut self, dt: f64) -> Result<Vec<Event>, &'static str> {
        let mut search = PerceptionSearch::default();
        search.rebuild_actors(
            &self.scene.world.actors,
            &self.scene.world.geometry.terrain,
            self.scene.world.now,
            |_| false,
        )?;
        self.scene.context().advance_infantry(
            1,
            dt,
            &Profiles {
                unit: &|_| Unit {
                    bearer: false,
                    healing: 1.0,
                    building: 1.0,
                    weapon: Some(("rifle", weapon())),
                },
                weapon: &profile,
                gun: &|_| {
                    Some(MountedGun {
                        bore: 0.15,
                        muzzle: 1.0,
                        grip_z: 0.25,
                        nest_height: 0.8,
                        trench_height: 0.6,
                    })
                },
                build_time: &|_| Some(10.0),
                defense: &|_| Defense {
                    smoke: SmokeProfile {
                        armor: 0,
                        helicopter: false,
                        gun_height: 2.2,
                    },
                    crew: CrewProfile {
                        base: "tank",
                        helicopter: false,
                        automatic: false,
                        artillery: false,
                        tracked: true,
                        armor: 0,
                    },
                },
                armor: &|_| Armor {
                    level: 0,
                    helicopter: false,
                    boat: false,
                    supply: false,
                    toss: 1.0,
                },
                vehicle_hit: &|_| 2.0,
                transport: &|_| Transport {
                    seats: 4,
                    helicopter: false,
                    boat: false,
                },
            },
            &mut Tick {
                search: &search,
                gunfire: &mut self.gunfire,
                network: &mut self.network,
                impacts: &mut self.impacts,
                chat: &mut self.chat,
                owned: &[],
                players: &[(7, 0), (8, 1)],
                depots: [0; 2],
                medicine: [false; 2],
                optics: [false; 2],
                warheads: [false; 2],
                squad_names: ["Section", "Section"],
            },
        )
    }
}
pub fn soldiers() -> (Infantry, Infantry) {
    let mut man = shared::soldier(1, 0.0, Life::Alive);
    man.weapon.magazine = 7;
    man.weapon.reserve = 30;
    man.weapon.last_shot = -10.0;
    let mut enemy = shared::soldier(2, 10.0, Life::Alive);
    enemy.identity.team = 1;
    enemy.identity.owner = 8;
    (man, enemy)
}

pub fn transcript() -> Vec<u8> {
    fn block(out: &mut Vec<u8>, bytes: &[u8]) {
        out.extend_from_slice(&(bytes.len() as u32).to_le_bytes());
        out.extend_from_slice(bytes);
    }
    let mut out = vec![];
    for trial in 0..12 {
        let (mut man, mut enemy) = soldiers();
        match trial {
            1 => man.vitals.suppression = 70.0,
            2 => {
                man.controller.think_timer = 1.0;
                man.duty.kind = Task::Rescue;
                man.duty.entity = 2;
                man.duty.phase = 2;
                man.duty.timer = 0.05;
                enemy.vitals.life = Life::Downed;
                enemy.vitals.hp = 0.0;
                enemy.identity.team = 0;
                enemy.links.rescue_claimed = 1;
                enemy.motion.position.x = 1.0;
            }
            3 => {
                man.vitals.life = Life::Hidden;
                man.control.hidden = HiddenReason::Tent;
                man.control.hidden_timer = 0.05;
                man.identity.weapon.clear();
            }
            4 => {
                man.action.current = Action::Cook;
                man.action.remaining = 0.05;
                man.action.queued_throw = Some(Throw {
                    position: enemy.motion.position,
                    round: Round::Frag,
                    fuse: 1.8,
                });
            }
            5 => {
                man.vitals.life = Life::Downed;
                man.vitals.hp = 0.0;
            }
            6 => man.vitals.life = Life::Surrender,
            7 => man.vitals.life = Life::Captive,
            8 => man.shock.dazed_timer = 0.4,
            9 => man.shock.flinch_timer = 0.05,
            10 => {
                man.controller.think_timer = 1.0;
                man.duty.kind = Task::Limp;
            }
            11 => {
                man.action.current = Action::Melee { target: 2 };
                man.action.remaining = 0.05;
                enemy.motion.position.x = 1.0;
            }
            _ => {}
        }
        let mut field = Field::new(man, enemy);
        for _ in 0..16 {
            field.scene.world.now += 0.1;
            let mut resumed = field.resume();
            let events = field.step(0.1).unwrap();
            assert_eq!(events, resumed.step(0.1).unwrap());
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
            for time in field.chat {
                out.extend_from_slice(&time.to_le_bytes());
            }
        }
    }
    out
}
