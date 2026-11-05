use frontline_core::actors::{Actor, Actors};
use frontline_core::collision::{BoxShape, CollisionWorld, Mat3};
use frontline_core::cover::{Anchor, AnchorKind};
use frontline_core::infantry::{Goal, Infantry};
use frontline_core::infantry_cover::{CoverIntent, CoverWorld};
use frontline_core::path_planner::PathPlanner;
use frontline_core::random::SimulationRandom;
use frontline_core::spatial::{SpatialIndex, STRUCTURE_CELL, UNIT_CELL};
use frontline_core::squad::{Report, Squad};
use frontline_core::structure::Structure;
use frontline_core::terrain::Terrain;
use frontline_core::vector::Vector3;

fn soldier(id: u32) -> Infantry {
    let mut s = Infantry::default();
    s.identity.id = id;
    s.identity.unit = "rifleman".into();
    s.identity.squad = 9;
    s.orders.hold_face = Vector3::Z;
    s
}
fn wall() -> Structure {
    Structure {
        id: 10,
        kind: "low_wall".into(),
        built: true,
        radius: 8.0,
        anchors: [-2.0, 2.0]
            .into_iter()
            .map(|x| Anchor {
                position: Vector3::X * x,
                normal: Vector3::Z,
                height: 1.2,
                kind: AnchorKind::Over,
            })
            .collect(),
        ..Default::default()
    }
}
fn actors(s: Infantry, wall: Option<Structure>, mate: Option<Infantry>) -> Actors {
    let mut entries = vec![Actor::Soldier(Box::new(s))];
    if let Some(s) = wall {
        entries.push(Actor::Structure(Box::new(s)));
    }
    if let Some(s) = mate {
        entries.push(Actor::Soldier(Box::new(s)));
    }
    Actors::from_entries(100, entries).unwrap()
}
struct Field {
    terrain: Terrain,
    nav: PathPlanner,
    collision: CollisionWorld,
    units: SpatialIndex,
    structures: SpatialIndex,
}
impl Field {
    fn new(actors: &Actors) -> Self {
        let mut f = Self {
            terrain: Terrain::blank(64).unwrap(),
            nav: PathPlanner::new(64).unwrap(),
            collision: CollisionWorld::default(),
            units: SpatialIndex::new(UNIT_CELL).unwrap(),
            structures: SpatialIndex::new(STRUCTURE_CELL).unwrap(),
        };
        actors.rebuild_units(&mut f.units).unwrap();
        if let Some(wall) = actors.structure(10) {
            f.structures.insert(10, wall.position, wall.radius).unwrap();
            assert!(f.collision.replace(
                10,
                &[BoxShape {
                    body: 10,
                    shape: 0,
                    center: Vector3::new(0.0, 0.6, 1.0),
                    basis: Mat3::IDENTITY,
                    half: Vector3::new(8.0, 0.6, 0.2)
                }]
            ));
        }
        f
    }
    fn context(&mut self) -> CoverWorld<'_> {
        CoverWorld {
            terrain: &self.terrain,
            nav: &self.nav,
            collision: &mut self.collision,
            heat: &[],
            deck: &[],
            units: &self.units,
            structures: &self.structures,
        }
    }
}
fn intent() -> CoverIntent {
    CoverIntent {
        now: 10.0,
        anchor: Vector3::ZERO,
        radius: 8.0,
        weapon_range: 50.0,
        unarmed: false,
    }
}
fn squad() -> Squad {
    Squad {
        id: 9,
        members: vec![1, 2],
        heard: vec![Report {
            position: Vector3::Z * 20.0,
            time: 9.0,
        }],
        ..Default::default()
    }
}

#[test]
fn cover_search_borrows_registered_anchors_and_respects_distant_squad_claims() {
    let mut mate = soldier(2);
    mate.motion.position = Vector3::X * 25.0;
    mate.cover.position = Vector3::X * -2.0;
    mate.cover.at_cover = true;
    let mut a = actors(soldier(1), Some(wall()), Some(mate));
    let mut field = Field::new(&a);
    let mut q = squad();
    let out = a
        .seek_infantry_cover(
            1,
            intent(),
            Some(&mut q),
            &mut field.context(),
            &mut SimulationRandom::new(1),
        )
        .unwrap();
    assert_eq!(out.search.choice.unwrap().anchor, 1);
    assert_eq!(out.search.candidates, 2);
    assert_eq!(a.soldier(1).unwrap().orders.purpose, Goal::Cover);
    assert_eq!(a.soldier(1).unwrap().orders.move_mode, 1);
    assert_eq!(q.combat_at, 10.0);
}

#[test]
fn local_claims_keep_old_bucket_membership_instead_of_rehashing_moved_soldiers() {
    for present in [false, true] {
        let mut mate = soldier(2);
        mate.motion.position = Vector3::X * -2.0;
        mate.cover.position = mate.motion.position;
        let mut a = actors(soldier(1), Some(wall()), Some(mate));
        let mut field = Field::new(&a);
        if !present {
            field.units.insert(2, Vector3::X * 100.0, 0.0).unwrap();
        }
        let out = a
            .seek_infantry_cover(
                1,
                intent(),
                None,
                &mut field.context(),
                &mut SimulationRandom::new(1),
            )
            .unwrap();
        assert_eq!(
            out.search.choice.unwrap().anchor,
            if present { 1 } else { 0 }
        );
    }
}

#[test]
fn removing_or_burning_the_held_wall_reconsiders_cover_before_its_deadline() {
    for missing in [false, true] {
        let mut s = soldier(1);
        s.cover.at_cover = true;
        s.cover.kind = 1;
        s.cover.structure = 10;
        s.cover.anchor = 0;
        s.cover.position = Vector3::X * -2.0;
        s.cover.evaluate_at = 20.0;
        let mut st = wall();
        st.burn = 0.31;
        let mut a = actors(s, (!missing).then_some(st), None);
        let mut field = Field::new(&a);
        let out = a
            .review_infantry_cover(
                1,
                10.0,
                50.0,
                false,
                None,
                &mut field.context(),
                &mut SimulationRandom::new(1),
            )
            .unwrap()
            .unwrap();
        assert!(out.search.choice.is_none());
        let s = a.soldier(1).unwrap();
        assert_eq!(s.cover.structure, 0);
        assert!(s.cover.at_cover);
        assert_eq!(s.cover.position, s.motion.position);
    }
}

#[test]
fn quiet_reviews_and_searches_without_a_cover_route_do_not_refresh_squad_combat() {
    for at_cover in [false, true] {
        let mut s = soldier(1);
        s.cover.at_cover = at_cover;
        s.cover.kind = 1;
        s.cover.threat = Vector3::Z;
        s.cover.evaluate_at = 0.0;
        let mut a = actors(s, None, None);
        let mut field = Field::new(&a);
        let mut q = squad();
        let mut rng = SimulationRandom::new(1);
        let before = rng.state();
        let out = a
            .review_infantry_cover(
                1,
                10.0,
                50.0,
                false,
                Some(&mut q),
                &mut field.context(),
                &mut rng,
            )
            .unwrap();
        assert_eq!(out.is_none(), at_cover);
        assert_eq!(q.combat_at, -1.0);
        if at_cover {
            assert_eq!(rng.state(), before);
            assert_eq!(a.soldier(1).unwrap().cover.evaluate_at, 12.5);
        }
    }
}

#[test]
fn rejected_cover_context_keeps_actor_random_and_squad_state() {
    let mut a = actors(soldier(1), Some(wall()), None);
    let mut field = Field::new(&a);
    let mut q = squad();
    let before = a.checkpoint().unwrap();
    let previous_squad = q.clone();
    let mut rng = SimulationRandom::new(1);
    let cursor = rng.state();
    let mut context = field.context();
    context.heat = &[1];
    assert!(a
        .seek_infantry_cover(1, intent(), Some(&mut q), &mut context, &mut rng)
        .is_err());
    assert_eq!(a.checkpoint().unwrap(), before);
    assert_eq!(q, previous_squad);
    assert_eq!(rng.state(), cursor);
}

#[test]
fn cover_material_preserves_variant_and_structure_rules() {
    for (kind, variant, expected) in [
        ("low_wall", 1, 0),
        ("low_wall", -2, 2),
        ("crates", 0, 0),
        ("crates", 1, 1),
        ("watchtower", 0, 0),
        ("ammo_cache", 0, 1),
        ("trench", 0, 3),
        ("unknown", 0, 2),
    ] {
        assert_eq!(
            Structure {
                kind: kind.into(),
                variant,
                ..Default::default()
            }
            .cover_material(),
            expected
        );
    }
}
