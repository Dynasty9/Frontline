#[path = "squad_movement_world.rs"]
#[allow(dead_code)]
mod shared;
use frontline_core::battle_stats::BattleStats;
use frontline_core::building_placement::{Definition, Distances};
use frontline_core::command_ownership::Ownership;
use frontline_core::placement_world::{Event, Request};
use frontline_core::rules_world::Rules;
use frontline_core::structure::Structure;
use frontline_core::structure_birth::BuildingProfile;
use frontline_core::vector::Vector3;
use frontline_core::water::Water;
pub struct Scene {
    pub world: shared::Scene,
    pub rules: Rules,
    pub owners: Ownership,
    pub battle: BattleStats,
    pub water: Water,
}
pub fn scene() -> Scene {
    let mut world = shared::Scene::new(37);
    world
        .geometry
        .spawn_structure(
            &mut world.actors,
            Structure {
                kind: "fob".into(),
                team: 0,
                position: Vector3::new(-40., 0., 40.),
                supply: 1000.,
                ..Default::default()
            },
            Some(BuildingProfile {
                size: [8., 8.],
                hp: 1000.,
            }),
        )
        .unwrap();
    world.geometry.tick_cover(100_000).unwrap();
    world.geometry.navigation.finalize(1);
    let mut owners = Ownership::default();
    owners.connect(8, 0).unwrap();
    owners.connect(9, 1).unwrap();
    Scene {
        world,
        rules: Rules::default(),
        owners,
        battle: BattleStats::default(),
        water: Water {
            side: 128,
            coast: None,
            rivers: vec![],
            ponds: vec![],
            fords: vec![],
            bridges: vec![],
        },
    }
}
pub fn place(
    s: &mut Scene,
    peer: i32,
    kind: &str,
    at: Vector3,
    assign: bool,
    qs: &[u32],
) -> Result<Vec<Event>, &'static str> {
    s.world.context().place_building(
        &mut s.rules,
        &s.owners,
        &mut s.battle,
        &s.water,
        Request {
            peer,
            team: 0,
            position: at,
            yaw: 0.37,
            size: None,
            squads: qs,
            assign,
        },
        Some(&Definition {
            key: kind,
            name: "Field works",
            teams: 3,
            cost: 100,
            body: BuildingProfile {
                size: [4., 2.],
                hp: 400.,
            },
        }),
        &Distances {
            build: 70.,
            fob_spacing: 45.,
            fob_expand: 130.,
        },
        &["Alpha".into(), "Bravo".into()],
        &|m| m.identity.id == 2,
        &|st| st.kind.clone(),
    )
}

impl Scene {
    pub fn resume(&self) -> Self {
        use frontline_core::{
            actors::Actors, spatial::SpatialIndex, squad::Squad, world_geometry::WorldGeometry,
        };
        let mut copy = scene();
        copy.world.actors = Actors::restore(&self.world.actors.checkpoint().unwrap()).unwrap();
        copy.world.geometry = WorldGeometry::restore(&self.world.geometry.checkpoint()).unwrap();
        copy.world.units = SpatialIndex::restore(&self.world.units.checkpoint()).unwrap();
        copy.world.squads = self
            .world
            .squads
            .iter()
            .map(|q| Squad::restore(&q.checkpoint().unwrap()).unwrap())
            .collect();
        copy.world.rng = self.world.rng;
        copy.world.now = self.world.now;
        copy.rules = Rules::restore(&self.rules.checkpoint().unwrap()).unwrap();
        copy.owners = Ownership::restore(&self.owners.checkpoint().unwrap()).unwrap();
        copy.battle = BattleStats::restore(&self.battle.checkpoint()).unwrap();
        copy.water = self.water.clone();
        copy
    }
    pub fn state(&self) -> [Vec<u8>; 8] {
        [
            self.world.actors.checkpoint().unwrap(),
            self.world.geometry.checkpoint(),
            self.world.units.checkpoint(),
            self.world.squads[0].checkpoint().unwrap(),
            self.world.rng.state().to_le_bytes().to_vec(),
            self.rules.checkpoint().unwrap(),
            self.owners.checkpoint().unwrap(),
            self.battle.checkpoint(),
        ]
    }
}
pub fn transcript() -> Vec<u8> {
    let mut out = vec![];
    let mut before: [Vec<u8>; 8] = Default::default();
    for trial in 0..12 {
        let mut s = scene();
        if trial % 2 == 1 {
            s.world.squads[0].owner = -1;
        }
        for step in 0..5 {
            let mut copy = s.resume();
            let kind = if step == 3 {
                "fob"
            } else {
                [
                    "sandbags",
                    "trench",
                    "barracks",
                    "watchtower",
                    "wire",
                    "camo_net",
                ][trial % 6]
            };
            let at = if step == 3 {
                Vector3::new(30., 0., 20.)
            } else if step == 4 {
                Vector3::new(120., 0., 0.)
            } else {
                Vector3::new(if step == 2 { -10. } else { -20. }, 0., 15.)
            };
            let selected = if trial % 3 == 0 { &[7][..] } else { &[][..] };
            let events = place(&mut s, 8, kind, at, step != 2, selected).unwrap();
            assert_eq!(
                events,
                place(&mut copy, 8, kind, at, step != 2, selected).unwrap()
            );
            let bytes = s.state();
            assert_eq!(bytes, copy.state());
            for (old, next) in before.iter_mut().zip(bytes) {
                let prefix = old.iter().zip(&next).take_while(|(a, b)| a == b).count();
                let suffix = old[prefix..]
                    .iter()
                    .rev()
                    .zip(next[prefix..].iter().rev())
                    .take_while(|(a, b)| a == b)
                    .count();
                let middle = &next[prefix..next.len() - suffix];
                for n in [prefix, suffix, middle.len()] {
                    out.extend_from_slice(&(n as u32).to_le_bytes());
                }
                out.extend_from_slice(middle);
                assert_eq!(
                    [&old[..prefix], middle, &old[old.len() - suffix..]].concat(),
                    next
                );
                *old = next;
            }
            let events = format!("{trial}/{step} {events:?}").into_bytes();
            out.extend_from_slice(&(events.len() as u32).to_le_bytes());
            out.extend(events);
        }
    }
    out
}
