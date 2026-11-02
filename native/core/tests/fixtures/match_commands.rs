#[path = "squad_movement_world.rs"]
#[allow(dead_code)]
mod movement;
#[path = "squad_orders.rs"]
#[allow(dead_code)]
mod order_fixture;
#[path = "vehicle_loss_world.rs"]
#[allow(dead_code)]
pub mod shared;
use frontline_core::actors::{Actor, Actors};
use frontline_core::ambush_plan::AmbushPlan;
use frontline_core::attack_plan::AttackPlan;
use frontline_core::boat_navigation::BoatNavigation;
use frontline_core::building_placement::{Definition, Distances};
use frontline_core::command_ownership::Ownership;
use frontline_core::fires::Fires;
use frontline_core::match_commands::{
    Action, Command, Dispatcher, Event, Profiles, VehicleOptions,
};
use frontline_core::production_orders::{Item, Research};
use frontline_core::rules_world::Rules;
use frontline_core::structure::Structure;
use frontline_core::structure_birth::BuildingProfile;
use frontline_core::support::Gunset;
use frontline_core::support_calls::{self, Sortie};
use frontline_core::vector::Vector3;
use frontline_core::water::Water;

pub const TANK: u32 = 8;
pub const ENEMY: u32 = 9;
pub const ALLY: u32 = 10;
pub const ROBOT: u32 = 11;
pub const HELI: u32 = 12;
pub const FOB: u32 = 13;
pub const BARRACKS: u32 = 14;
pub const MORTAR: u32 = 15;
pub const TUNNEL: u32 = 16;
pub const EXIT: u32 = 17;
pub const RESEARCH: u32 = 18;
pub struct Scene {
    pub world: shared::Scene,
    pub rules: Rules,
    pub owners: Ownership,
    pub boats: BoatNavigation,
    pub water: Water,
    pub plans: Vec<AttackPlan>,
    pub ambushes: Vec<AmbushPlan>,
    pub next_plan: u64,
    pub winner: i8,
}
pub fn command(action: Action) -> Command {
    Command {
        squads: vec![7],
        vehicles: vec![TANK],
        action,
    }
}
pub fn scene() -> Scene {
    let moved = movement::Scene::new(137);
    let mut world = shared::Scene::new(vec![], 137);
    world.world.actors = moved.actors;
    world.world.geometry = moved.geometry;
    world.world.units = moved.units;
    world.world.squads = moved.squads;
    world.fires = Fires::new(128, false).unwrap();
    for (id, kind, team, owner) in [
        (TANK, "tank", 0, -1),
        (ENEMY, "tank", 1, -2),
        (ALLY, "tank", 0, 8),
        (ROBOT, "robot", 0, -1),
        (HELI, "heli", 0, -1),
    ] {
        let mut a = shared::vehicle(id, kind);
        if let Actor::Vehicle(v) = &mut a {
            v.team = team;
            v.owner = owner;
            v.position = Vector3::new(
                -30.,
                if kind == "heli" { 5. } else { 0. },
                -15. + (id - TANK) as f32 * 5.,
            );
        }
        assert_eq!(world.world.actors.spawn(a).unwrap(), id);
    }
    for (id, kind, p) in [
        (FOB, "fob", Vector3::new(-40., 0., 40.)),
        (BARRACKS, "barracks", Vector3::new(-24., 0., 40.)),
        (MORTAR, "mortar_pit", Vector3::new(0., 0., 30.)),
        (TUNNEL, "tunnel", Vector3::new(20., 0., 30.)),
        (EXIT, "tunnel", Vector3::new(40., 0., 30.)),
        (RESEARCH, "research", Vector3::new(-8., 0., 40.)),
    ] {
        assert_eq!(
            world
                .world
                .geometry
                .spawn_structure(
                    &mut world.world.actors,
                    Structure {
                        kind: kind.into(),
                        team: 0,
                        owner: 7,
                        position: p,
                        supply: 5000.,
                        ..Default::default()
                    },
                    Some(BuildingProfile {
                        size: [4., 4.],
                        hp: 1000.
                    })
                )
                .unwrap(),
            id
        );
    }
    world.world.geometry.tick_cover(100_000).unwrap();
    world.world.geometry.navigation.finalize(1);
    world
        .world
        .actors
        .rebuild_units(&mut world.world.units)
        .unwrap();
    let mut owners = Ownership::default();
    for (id, side) in [(7, 0), (8, 0), (9, 1), (10, -1)] {
        owners.connect(id, side).unwrap();
        world.world.battle.joined(id, side, "Commander").unwrap();
    }
    Scene {
        world,
        rules: Rules::default(),
        owners,
        boats: BoatNavigation::new(64, &vec![0; 4096], &vec![1.; 4096]).unwrap(),
        water: Water {
            side: 128,
            coast: None,
            rivers: vec![],
            ponds: vec![],
            fords: vec![],
            bridges: vec![],
        },
        plans: vec![],
        ambushes: vec![],
        next_plan: 1,
        winner: -1,
    }
}
impl Scene {
    #[allow(dead_code)]
    pub fn change(&mut self, id: u32, f: impl FnOnce(&mut Actor)) {
        let mut entries: Vec<_> = self.world.world.actors.iter().cloned().collect();
        f(entries.iter_mut().find(|a| a.identity().id == id).unwrap());
        self.world.world.actors =
            Actors::from_entries(self.world.world.actors.entities().next_id(), entries).unwrap();
    }
    pub fn execute(&mut self, peer: i32, command: &Command) -> Result<Vec<Event>, &'static str> {
        let rifle = Item {
            key: "rifle_squad".into(),
            name: "Rifle Squad".into(),
            cost: 100,
            time: 10.,
            tier: 1,
            research: false,
            teams: 3,
            requires: String::new(),
        };
        let upgrade = Item {
            key: "deep_tunnels".into(),
            name: "Deep tunnels".into(),
            cost: 200,
            time: 10.,
            tier: 1,
            research: true,
            teams: 3,
            requires: String::new(),
        };
        let research = vec![Research {
            key: upgrade.key.clone(),
            name: upgrade.name.clone(),
            teams: 3,
            tier: 1,
        }];
        let produces = vec![rifle.key.clone()];
        let profiles = Profiles {
            building: &|key| {
                Some(Definition {
                    key: match key {
                        "sandbags" => "sandbags",
                        "trench" => "trench",
                        _ => return None,
                    },
                    name: "Field works",
                    teams: 3,
                    cost: 100,
                    body: BuildingProfile {
                        size: [4., 2.],
                        hp: 400.,
                    },
                })
            },
            support: &|key| {
                (key == "mortars").then_some(support_calls::Definition {
                    key: "mortars",
                    name: "Mortar barrage",
                    model: "",
                    team: 0,
                    cost: 100,
                    from: 0.,
                    cooldown: 30.,
                    radius: 4.,
                    sortie: Sortie::Mortars,
                    quiet: false,
                    leg: 1.,
                    altitude: 100.,
                    speed: 100.,
                    sight: 100.,
                    stay: 10.,
                    bombs: 0,
                    guns: Gunset::Unarmed,
                    muzzles: [Vector3::ZERO; 3],
                })
            },
            item: &|key, is_research| {
                if is_research && key == upgrade.key {
                    Some(&upgrade)
                } else if !is_research && key == rifle.key {
                    Some(&rifle)
                } else {
                    None
                }
            },
            produces: &|key| if key == "barracks" { &produces } else { &[] },
            research: &research,
            vehicle: &|v| VehicleOptions {
                seats: 4,
                artillery: (v.id == TANK).then_some((40., 240.)),
                sling_capacity: Some(2),
            },
            mount: &|_| None,
            engineer: &|s| s.identity.id == 2,
            mortar: &|s| s.identity.id == 4,
            structure_name: &|s| s.kind.clone(),
            squad_name: &|q| q.kind.clone(),
            distances: &Distances {
                build: 70.,
                fob_spacing: 45.,
                fob_expand: 130.,
            },
            fob_names: &["Alpha".into(), "Bravo".into()],
        };
        Dispatcher {
            world: &mut self.world.context(),
            rules: &mut self.rules,
            owners: &self.owners,
            boats: &mut self.boats,
            water: &self.water,
            plans: &mut self.plans,
            ambushes: &mut self.ambushes,
            next_plan: &mut self.next_plan,
            profiles: &profiles,
            winner: self.winner,
            host_peer: 10,
        }
        .execute(peer, "Commander", command)
    }
    pub fn resume(&self) -> Self {
        Self {
            world: self.world.resume(),
            rules: Rules::restore(&self.rules.checkpoint().unwrap()).unwrap(),
            owners: Ownership::restore(&self.owners.checkpoint().unwrap()).unwrap(),
            boats: BoatNavigation::restore(&self.boats.checkpoint()).unwrap(),
            water: Water::restore(&self.water.checkpoint()).unwrap(),
            plans: self
                .plans
                .iter()
                .map(|p| AttackPlan::restore(&p.checkpoint().unwrap()).unwrap())
                .collect(),
            next_plan: self.next_plan,
            ambushes: self
                .ambushes
                .iter()
                .map(|p| AmbushPlan::restore(&p.checkpoint().unwrap()).unwrap())
                .collect(),
            winner: self.winner,
        }
    }
    pub fn state(&self) -> Vec<Vec<u8>> {
        let w = &self.world.world;
        let mut state = vec![
            w.actors.checkpoint().unwrap(),
            w.geometry.checkpoint(),
            w.units.checkpoint(),
            w.battle.checkpoint(),
            w.deferred.checkpoint(),
            w.visibility.checkpoint(),
            w.rng.state().to_le_bytes().to_vec(),
            self.world.fires.checkpoint(),
            self.world.next.to_le_bytes().to_vec(),
            self.rules.checkpoint().unwrap(),
            self.owners.checkpoint().unwrap(),
            self.boats.checkpoint(),
            self.next_plan.to_le_bytes().to_vec(),
        ];
        for blocks in [
            w.squads
                .iter()
                .map(|q| q.checkpoint().unwrap())
                .collect::<Vec<_>>(),
            self.plans.iter().map(|p| p.checkpoint().unwrap()).collect(),
            self.ambushes
                .iter()
                .map(|p| p.checkpoint().unwrap())
                .collect(),
        ] {
            let mut combined = vec![];
            for block in blocks {
                combined.extend_from_slice(&(block.len() as u32).to_le_bytes());
                combined.extend(block);
            }
            state.push(combined);
        }
        state
    }
}
#[allow(dead_code)]
pub fn transcript() -> Vec<u8> {
    use frontline_core::match_commands::{Placement, UnitOrder};
    let mut out = vec![];
    let mut previous: Vec<Vec<u8>> = vec![];
    for trial in 0..4 {
        let mut s = scene();
        s.world.world.rng = frontline_core::random::SimulationRandom::new(137 + trial);
        s.world.world.squads[0].owner = if trial % 2 == 0 { -1 } else { 8 };
        let position = Vector3::new(-12., 0., 4.);
        let face = Vector3::NEG_Z;
        let actions = vec![
            Action::Move {
                position,
                face,
                mode: trial as u8 % 3,
            },
            Action::Attack(ENEMY),
            Action::Defend { position, face },
            Action::Stop,
            Action::Assault {
                position: Vector3::new(40., 0., -5.),
                face: Vector3::X,
            },
            Action::Retreat,
            Action::Unit {
                soldier: 1,
                order: UnitOrder::Move {
                    position,
                    face,
                    mode: 0,
                },
            },
            Action::Unit {
                soldier: 1,
                order: UnitOrder::Attack(ENEMY),
            },
            Action::Unit {
                soldier: 1,
                order: UnitOrder::Throw {
                    position,
                    smoke: false,
                },
            },
            Action::Unit {
                soldier: 1,
                order: UnitOrder::Stop,
            },
            Action::Unit {
                soldier: 1,
                order: UnitOrder::Retreat,
            },
            Action::Unit {
                soldier: 1,
                order: UnitOrder::Man(MORTAR),
            },
            Action::Build {
                kind: "sandbags".into(),
                position: Vector3::new(-30., 0., 20.),
                yaw: 0.37,
            },
            Action::BuildMany {
                kind: "trench".into(),
                items: vec![
                    Placement {
                        position: Vector3::new(-15., 0., 20.),
                        yaw: 0.,
                        length: Some(4.),
                    },
                    Placement {
                        position: Vector3::new(-5., 0., 20.),
                        yaw: 0.,
                        length: Some(5.),
                    },
                ],
            },
            Action::FireMission {
                building: MORTAR,
                position: Vector3::new(40., 0., -30.),
                smoke: true,
            },
            Action::Work(BARRACKS),
            Action::Enter(TUNNEL),
            Action::Board(TANK),
            Action::Throw {
                position,
                smoke: true,
            },
            Action::Support {
                kind: "mortars".into(),
                position,
                direction: face,
            },
            Action::Produce {
                building: BARRACKS,
                item: "rifle_squad".into(),
                research: false,
            },
            Action::Produce {
                building: RESEARCH,
                item: "deep_tunnels".into(),
                research: true,
            },
            Action::Rally {
                building: BARRACKS,
                position,
            },
            Action::Cancel(BARRACKS),
            Action::TunnelExit {
                building: TUNNEL,
                exit: EXIT,
            },
            Action::Chat {
                text: "Ready".into(),
                team_only: true,
            },
            Action::Sling(TANK),
            Action::Dismount,
        ];
        for action in actions {
            let mut c = command(action);
            c.vehicles.push(HELI);
            let bytes = c.encode().unwrap();
            let c = Command::decode(&bytes).unwrap();
            let mut copy = s.resume();
            let events = s.execute(7, &c).unwrap();
            assert_eq!(events, copy.execute(7, &c).unwrap());
            let mut state = s.state();
            assert_eq!(state, copy.state());
            state.push(bytes);
            state.push(format!("{events:?}").into_bytes());
            if previous.is_empty() {
                previous.resize(state.len(), vec![]);
            }
            assert_eq!(previous.len(), state.len());
            for (before, after) in previous.iter_mut().zip(state) {
                order_fixture::delta(&mut out, before, after);
            }
        }
    }
    out
}
