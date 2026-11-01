use frontline_core::actors::{Actor, Actors};
use frontline_core::infantry::Infantry;
use frontline_core::random::SimulationRandom;
use frontline_core::spatial::{SpatialIndex, UNIT_CELL};
use frontline_core::squad::{Report, Squad};
use frontline_core::squad_movement::{Context, Event, ManProfile};
use frontline_core::structure::Structure;
use frontline_core::terrain::Terrain;
use frontline_core::vector::Vector3;
use frontline_core::world_geometry::WorldGeometry;

pub struct Scene {
    pub actors: Actors,
    pub geometry: WorldGeometry,
    pub units: SpatialIndex,
    pub squads: Vec<Squad>,
    pub rng: SimulationRandom,
    pub now: f64,
}
impl Scene {
    pub fn new(seed: u64) -> Self {
        let mut actors = Actors::default();
        let mut q = Squad::new(7, 0, 1, "rifle_squad".into()).unwrap();
        for k in 0..6 {
            let mut s = Infantry::default();
            s.identity.unit = if k % 3 == 0 { "mg_gunner" } else { "rifleman" }.into();
            s.motion.position = Vector3::new(-30.3 + k as f32 * 0.71, 0.0, k as f32 * 1.37 - 3.7);
            let id = actors.spawn(Actor::Soldier(Box::new(s))).unwrap();
            q.add_member(id, &mut actors).unwrap();
        }
        q.leader = 1;
        let mut units = SpatialIndex::new(UNIT_CELL).unwrap();
        actors.rebuild_units(&mut units).unwrap();
        let mut geometry = WorldGeometry::new(Terrain::blank(128).unwrap(), vec![], 16).unwrap();
        geometry
            .spawn_structure(
                &mut actors,
                Structure {
                    kind: "hesco".into(),
                    size: Vector3::new(16.0, 2.0, 1.0),
                    position: Vector3::new(8.0, 0.0, -4.0),
                    ..Default::default()
                },
                None,
            )
            .unwrap();
        geometry.tick_cover(100_000).unwrap();
        assert!(geometry.navigation.finalize(1));
        Self {
            actors,
            geometry,
            units,
            squads: vec![q],
            rng: SimulationRandom::new(seed),
            now: 100.0,
        }
    }
    pub fn context(&mut self) -> Context<'_> {
        Context {
            actors: &mut self.actors,
            geometry: &mut self.geometry,
            units: &self.units,
            squads: &mut self.squads,
            rng: &mut self.rng,
            now: self.now,
            town: [-20.0, -20.0, 40.0, 40.0],
            man: &|_| ManProfile {
                bearer: false,
                weapon_range: Some(180.0),
            },
            automatic: &|_| false,
            player_building: &|k| k == "fob",
        }
    }
    pub fn change(&mut self, id: u32, mut f: impl FnMut(&mut Infantry)) {
        let mut entries: Vec<_> = self.actors.iter().cloned().collect();
        for a in &mut entries {
            if let Actor::Soldier(s) = a {
                if s.identity.id == id {
                    f(s);
                }
            }
        }
        self.actors = Actors::from_entries(self.actors.entities().next_id(), entries).unwrap();
    }
    pub fn resume(&mut self) {
        self.actors = Actors::restore(&self.actors.checkpoint().unwrap()).unwrap();
        self.geometry = WorldGeometry::restore(&self.geometry.checkpoint()).unwrap();
        self.units = SpatialIndex::restore(&self.units.checkpoint()).unwrap();
        for q in &mut self.squads {
            *q = Squad::restore(&q.checkpoint().unwrap()).unwrap();
        }
        let state = self.rng.state();
        self.rng = SimulationRandom::new(self.rng.seed());
        self.rng.set_state(state);
    }
}
fn block(out: &mut Vec<u8>, data: &[u8]) {
    out.extend_from_slice(&(data.len() as u32).to_le_bytes());
    out.extend_from_slice(data);
}
pub fn checkpoint_delta(out: &mut Vec<u8>, previous: &mut Vec<u8>, next: Vec<u8>) {
    // Record every changed byte without repeating unchanged checkpoint blocks.
    if previous.is_empty() {
        out.push(1);
        block(out, &next);
    } else {
        out.push(0);
        out.extend_from_slice(&(next.len() as u32).to_le_bytes());
        for (index, &byte) in next.iter().enumerate() {
            if previous.get(index) != Some(&byte) {
                out.extend_from_slice(&(index as u32).to_le_bytes());
                out.push(byte);
            }
        }
        out.extend_from_slice(&u32::MAX.to_le_bytes());
    }
    *previous = next;
}
fn navigation(out: &mut Vec<u8>, previous: &mut [Vec<u8>; 3], scene: &Scene) {
    // Separate blocks keep a changed queue length from shifting the unchanged hierarchies.
    for (before, after) in previous.iter_mut().zip([
        scene.geometry.navigation.planner.checkpoint(),
        scene.geometry.navigation.infantry.checkpoint(),
        scene.geometry.navigation.vehicles.checkpoint(),
    ]) {
        checkpoint_delta(out, before, after);
    }
}
pub fn transcript() -> Vec<u8> {
    let mut out = vec![];
    let mut previous_nav = [vec![], vec![], vec![]];
    for trial in 0..16 {
        let mut s = Scene::new(137 + trial);
        s.squads[0].owner = trial as i32 % 3 - 1;
        s.squads[0].alert_time = if trial % 2 == 0 { 99.0 } else { -99.0 };
        s.squads[0].heard.push(Report {
            position: Vector3::new(30.0, 0.0, 8.0),
            time: 95.0,
        });
        for step in 0..24 {
            s.now = 100.0 + step as f64 * 3.7;
            if step % 4 == 3 {
                for id in 1..=6 {
                    s.change(id, |m| {
                        m.motion.position.x += 2.7;
                        m.motion.last_direction = Vector3::new(0.7, 0.0, 0.3);
                    });
                }
            }
            let events = if step % 8 == 0 {
                s.context()
                    .order_move(
                        7,
                        Vector3::new(30.7, 0.0, step as f32 - 8.3),
                        Vector3::ZERO,
                        (trial % 3) as u8,
                        true,
                    )
                    .unwrap()
            } else if s.squads[0].travel {
                s.context().follow_tick(7).unwrap()
            } else {
                s.context().overwatch_tick(7).unwrap()
            };
            for e in events {
                match e {
                    Event::Speech {
                        soldier,
                        call,
                        variant,
                    } => {
                        out.push(0);
                        out.extend_from_slice(&soldier.to_le_bytes());
                        out.extend_from_slice(&[call as u8, variant]);
                    }
                    Event::CancelAmbush(id) => {
                        out.push(1);
                        out.extend_from_slice(&id.to_le_bytes());
                    }
                    Event::CrewHome { squad, fob } => {
                        out.push(3);
                        out.extend_from_slice(&squad.to_le_bytes());
                        out.extend_from_slice(&fob.to_le_bytes());
                    }
                    Event::Despawn(id) => {
                        out.push(4);
                        out.extend_from_slice(&id.to_le_bytes());
                    }
                    Event::Stat(name) => {
                        out.push(2);
                        block(&mut out, name.as_bytes());
                    }
                }
            }
            out.push(255);
            s.geometry
                .navigation
                .process_paths(&mut s.actors, 3, s.now, &mut s.rng)
                .unwrap();
            block(&mut out, &s.actors.checkpoint().unwrap());
            block(&mut out, &s.squads[0].checkpoint().unwrap());
            navigation(&mut out, &mut previous_nav, &s);
            block(&mut out, &s.rng.state().to_le_bytes());
            if step % 7 == 6 {
                s.resume();
            }
        }
    }
    out
}

pub fn crew_transcript() -> Vec<u8> {
    let mut out = vec![];
    let mut previous_nav = [vec![], vec![], vec![]];
    for trial in 0..16 {
        let mut s = Scene::new(791 + trial);
        let team = (trial % 2) as i8;
        for id in 1..=6 {
            s.change(id, |m| {
                m.identity.team = team;
                if id % 3 == 0 {
                    m.vitals.life = frontline_core::infantry_vitals::Life::Downed;
                }
            });
        }
        let fob = s
            .geometry
            .spawn_structure(
                &mut s.actors,
                Structure {
                    kind: "fob".into(),
                    team,
                    position: Vector3::new(38.7, 0.0, 11.3),
                    supply: 17.25,
                    ..Default::default()
                },
                None,
            )
            .unwrap();
        s.squads[0].kind = if team == 0 { "crew" } else { "r_crew" }.into();
        s.squads[0].team = team;
        s.squads[0].cooldowns = vec![
            ("refund".into(), 50.7),
            ("crew_n".into(), if trial % 4 == 0 { 1.0 } else { 0.0 }),
        ];
        for step in 0..12 {
            s.now = 100.0 + step as f64 * 0.37;
            if step == 6 {
                let p = s.actors.structure(fob).unwrap().position;
                for id in 1..=6 {
                    s.change(id, |m| {
                        m.motion.position = p + Vector3::new(id as f32 * 0.3, 0.0, 1.3)
                    });
                }
            }
            let events = s.context().crew_tick(7).unwrap();
            for e in events {
                match e {
                    Event::Speech {
                        soldier,
                        call,
                        variant,
                    } => {
                        out.push(0);
                        out.extend_from_slice(&soldier.to_le_bytes());
                        out.extend_from_slice(&[call as u8, variant]);
                    }
                    Event::CancelAmbush(id) | Event::Despawn(id) => {
                        out.push(1);
                        out.extend_from_slice(&id.to_le_bytes());
                    }
                    Event::CrewHome { squad, fob } => {
                        out.push(3);
                        out.extend_from_slice(&squad.to_le_bytes());
                        out.extend_from_slice(&fob.to_le_bytes());
                    }
                    Event::Stat(name) => {
                        out.push(2);
                        block(&mut out, name.as_bytes());
                    }
                }
            }
            out.push(255);
            s.geometry
                .navigation
                .process_paths(&mut s.actors, 3, s.now, &mut s.rng)
                .unwrap();
            block(&mut out, &s.actors.checkpoint().unwrap());
            block(&mut out, &s.squads[0].checkpoint().unwrap());
            block(&mut out, &s.rng.state().to_le_bytes());
            if step % 5 == 4 {
                s.resume();
            }
        }
        navigation(&mut out, &mut previous_nav, &s);
    }
    out
}
