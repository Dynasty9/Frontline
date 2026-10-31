use frontline_core::actors::{Actor, Actors};
use frontline_core::battle_stats::BattleStats;
use frontline_core::collision::{BoxShape, Mat3};
use frontline_core::deferred_effects::DeferredEffects;
use frontline_core::fires::{BuildingProfile, Context, ManProfile};
use frontline_core::infantry::Infantry;
use frontline_core::infantry_vitals::Life;
use frontline_core::random::SimulationRandom;
use frontline_core::spatial::{SpatialIndex, UNIT_CELL};
use frontline_core::squad::Squad;
use frontline_core::structure::{Part, Structure};
use frontline_core::terrain::Terrain;
use frontline_core::vector::Vector3;
use frontline_core::visibility::Visibility;
use frontline_core::world_geometry::WorldGeometry;

fn man(s: &Infantry, _: &[Squad]) -> ManProfile {
    ManProfile {
        bearer: s.identity.unit == "bearer",
        ammunition: (!s.identity.weapon.is_empty()).then_some(180),
        value: 17.0,
    }
}
fn building(st: &Structure) -> BuildingProfile {
    BuildingProfile {
        player: matches!(st.kind.as_str(), "medic_tent" | "watchtower" | "barracks"),
        value: 100.0,
    }
}
fn role(s: &Infantry) -> String {
    s.identity.unit.clone()
}
pub struct Battle {
    pub actors: Actors,
    pub geometry: WorldGeometry,
    pub units: SpatialIndex,
    pub squads: Vec<Squad>,
    pub battle: BattleStats,
    pub deferred: DeferredEffects,
    pub visibility: Visibility,
    pub rng: SimulationRandom,
    pub now: f64,
}
impl Battle {
    pub fn new(mut entries: Vec<Actor>) -> Self {
        let mut geometry = WorldGeometry::new(Terrain::blank(32).unwrap(), vec![], 16).unwrap();
        for actor in &mut entries {
            if let Actor::Structure(st) = actor {
                geometry
                    .structures
                    .insert(st.id, st.position, st.radius)
                    .unwrap();
                st.hash_cells = geometry
                    .structures
                    .cells()
                    .filter(|(_, ids)| ids.contains(&st.id))
                    .map(|((x, z), _)| [x, z])
                    .collect();
                geometry.sync_structure(st, true).unwrap();
                geometry
                    .navigation
                    .add_structure(st, &geometry.terrain, &[])
                    .unwrap();
                assert!(geometry.collision.replace(
                    i64::from(st.id),
                    &[BoxShape {
                        body: i64::from(st.id),
                        shape: 0,
                        center: st.position + Vector3::Y,
                        basis: Mat3::IDENTITY,
                        half: st.size * 0.5
                    }]
                ));
            }
        }
        assert!(geometry.navigation.finalize(1));
        let actors = Actors::from_entries(1000, entries).unwrap();
        let mut units = SpatialIndex::new(UNIT_CELL).unwrap();
        actors.rebuild_units(&mut units).unwrap();
        Self {
            actors,
            geometry,
            units,
            squads: vec![],
            battle: BattleStats::default(),
            deferred: DeferredEffects::default(),
            visibility: Visibility::default(),
            rng: SimulationRandom::new(137),
            now: 0.0,
        }
    }
    pub fn context(&mut self) -> Context<'_> {
        Context {
            actors: &mut self.actors,
            geometry: &mut self.geometry,
            units: &self.units,
            squads: &mut self.squads,
            battle: &mut self.battle,
            deferred: &mut self.deferred,
            visibility: &mut self.visibility,
            rng: &mut self.rng,
            now: self.now,
            town: [0.0; 4],
            man: &man,
            building: &building,
            role: &role,
        }
    }
    pub fn resume(&self) -> Self {
        let mut rng = SimulationRandom::new(self.rng.seed());
        rng.set_state(self.rng.state());
        Self {
            actors: Actors::restore(&self.actors.checkpoint().unwrap()).unwrap(),
            geometry: WorldGeometry::restore(&self.geometry.checkpoint()).unwrap(),
            units: SpatialIndex::restore(&self.units.checkpoint()).unwrap(),
            squads: self.squads.clone(),
            battle: BattleStats::restore(&self.battle.checkpoint()).unwrap(),
            deferred: DeferredEffects::restore(&self.deferred.checkpoint()).unwrap(),
            visibility: Visibility::restore(&self.visibility.checkpoint()).unwrap(),
            rng,
            now: self.now,
        }
    }
    pub fn compare(&self, other: &Self) {
        assert_eq!(
            self.actors.checkpoint().unwrap(),
            other.actors.checkpoint().unwrap()
        );
        assert_eq!(self.geometry.checkpoint(), other.geometry.checkpoint());
        assert_eq!(self.units.checkpoint(), other.units.checkpoint());
        assert_eq!(self.battle.checkpoint(), other.battle.checkpoint());
        assert_eq!(self.deferred.checkpoint(), other.deferred.checkpoint());
        assert_eq!(self.visibility.checkpoint(), other.visibility.checkpoint());
        assert_eq!(self.rng, other.rng);
    }
}
pub fn structure(id: u32, kind: &str, x: f32) -> Structure {
    Structure {
        id,
        kind: kind.into(),
        built: true,
        team: 0,
        owner: 7,
        hp: 100.0,
        max_hp: 100.0,
        position: Vector3::X * x,
        size: Vector3::new(4.0, 2.0, 1.0),
        radius: 2.0,
        footprint: [2.0, 0.5],
        parts: vec![Part {
            position: Vector3::Y,
            size: Vector3::new(4.0, 2.0, 1.0),
            yaw: 0.0,
            infantry: 3,
            vehicle: 3,
            cover: true,
            collision: true,
            door: false,
        }],
        ..Default::default()
    }
}
pub fn soldier(id: u32, x: f32, life: Life) -> Infantry {
    let mut s = Infantry::default();
    s.identity.id = id;
    s.identity.unit = "rifleman".into();
    s.identity.weapon = "rifle".into();
    s.identity.team = 0;
    s.identity.owner = 7;
    s.motion.position = Vector3::X * x;
    s.vitals.life = life;
    s.vitals.hp = 100.0;
    s.vitals.bleed = 2.0;
    s
}
pub fn actor(st: Structure) -> Actor {
    Actor::Structure(Box::new(st))
}
