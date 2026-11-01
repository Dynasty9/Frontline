#[allow(dead_code)]
#[path = "vehicle_combat_world.rs"]
mod combat;
pub use combat::Field;
use frontline_core::actors::Actor;
use frontline_core::drone::{DroneFlight, Phase};
use frontline_core::drone_actor::Drone;
use frontline_core::guided::{GuidedFlight, Kind as GuidedKind};
use frontline_core::infantry_controller::Task;
use frontline_core::infantry_vitals::Life;
use frontline_core::ordnance_world::Event;
use frontline_core::projectile::Kind;
use frontline_core::projectile_actor::{ballistic, Motion, Projectile, Spawn};
use frontline_core::support::{Kind as SupportKind, SupportFlight};
use frontline_core::vector::Vector3;
use frontline_core::visibility::Smoke;

pub struct Battle {
    pub field: Field,
    pub marks: [Vec<[f32; 4]>; 2],
    pub id: u32,
    pub drone: bool,
}
impl Battle {
    pub fn new(case: usize) -> Self {
        let mut victim = combat::infantry(Life::Alive);
        if case == 1 {
            if let Actor::Soldier(s) = &mut victim {
                s.motion.position = Vector3::new(0.0, 0.0, -9.25);
                s.motion.yaw = 0.0;
                s.duty.kind = Task::Smother;
            }
        }
        let mut field = Field::new(combat::vehicle(20, 0, 10.0), victim);
        let mut flight = ballistic(
            if case == 2 { Kind::Smoke } else { Kind::Frag },
            Vector3::new(0.0, 0.06, -10.0),
            Vector3::ZERO,
        );
        flight.fuse = 0.05;
        flight.flying = false;
        let mut p = Projectile::from_spawn(
            1,
            Spawn {
                flight,
                team: 0,
                thrower: 20,
                called_by: 7,
            },
        )
        .unwrap();
        if case == 1 {
            p.smothered_by = 1;
        }
        if case == 3 {
            p.target_id = 1;
            p.motion = Motion::Guided(GuidedFlight {
                kind: GuidedKind::AntiTank,
                position: Vector3::new(0.0, 3.0, 8.0),
                velocity: Vector3::new(0.0, 0.0, -12.0),
                target: Vector3::new(0.0, 1.0, -10.0),
                life: 0.24,
                locked: true,
                dead: false,
            });
            assert!(field.scene.world.visibility.set_projectile(
                999,
                Smoke {
                    center: Vector3::Y,
                    radius: 4.0
                }
            ));
        }
        if case == 4 {
            let mut flight = SupportFlight::new(
                SupportKind::Jet,
                Vector3::new(-40.0, 62.0, 0.0),
                Vector3::X * 58.0,
                Vector3::ZERO,
            );
            flight.sight = 65.0;
            p.motion = Motion::Support(flight);
        }
        if case == 6 {
            p.held_by = 999;
        }
        let actor = if case == 5 {
            let mut flight = DroneFlight::new(Vector3::new(0.0, 1.1, 10.0), 0.0);
            flight.phase = Phase::Dive;
            flight.diving = true;
            Actor::Drone(Drone {
                id: 1,
                team: 1,
                operator: 1,
                target: 20,
                operator_at_spawn: 1,
                target_at_spawn: 20,
                warhead: 1.0,
                flight,
            })
        } else {
            Actor::Projectile(p)
        };
        let id = field.scene.world.actors.spawn(actor).unwrap();
        Self {
            field,
            marks: Default::default(),
            id,
            drone: case == 5,
        }
    }
    pub fn resume(&self) -> Self {
        Self {
            field: self.field.resume(),
            marks: self.marks.clone(),
            id: self.id,
            drone: self.drone,
        }
    }
    pub fn step(&mut self, dt: f64) -> Result<Vec<Event>, &'static str> {
        let field = &mut self.field;
        if self.drone {
            field.scene.context().advance_drone_world(
                self.id,
                dt,
                &mut field.network,
                &mut field.impacts,
                &combat::armor,
            )
        } else {
            field.scene.context().advance_projectile_world(
                self.id,
                dt,
                &mut self.marks,
                &mut field.network,
                &mut field.impacts,
                &combat::armor,
            )
        }
    }
    pub fn compare(&self, other: &Self) {
        self.field.compare(&other.field);
        assert_eq!(self.marks, other.marks);
    }
}

pub fn transcript() -> Vec<u8> {
    fn block(out: &mut Vec<u8>, bytes: &[u8]) {
        out.extend_from_slice(&(bytes.len() as u32).to_le_bytes());
        out.extend_from_slice(bytes);
    }
    let mut out = vec![];
    for case in 0..7 {
        let mut battle = Battle::new(case);
        for _ in 0..8 {
            if battle.field.scene.world.actors.get(battle.id).is_none() {
                break;
            }
            battle.field.scene.world.now += 0.1;
            let mut resumed = battle.resume();
            let events = battle.step(0.1).unwrap();
            assert_eq!(events, resumed.step(0.1).unwrap());
            battle.compare(&resumed);
            let field = &battle.field;
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
            block(&mut out, &field.network.checkpoint().unwrap());
            block(&mut out, format!("{:?}", field.impacts).as_bytes());
            for marks in &battle.marks {
                out.extend_from_slice(&(marks.len() as u32).to_le_bytes());
                for mark in marks {
                    for value in mark {
                        out.extend_from_slice(&value.to_le_bytes());
                    }
                }
            }
            out.extend_from_slice(&field.scene.world.rng.state().to_le_bytes());
            out.extend_from_slice(&field.scene.next.to_le_bytes());
        }
    }
    out
}
