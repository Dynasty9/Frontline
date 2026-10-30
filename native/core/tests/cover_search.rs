use frontline_core::collision::{BoxShape, CollisionWorld, Mat3};
use frontline_core::cover::{Anchor, AnchorKind, CoverType};
use frontline_core::cover_search::{self, Input, NearbyClaim, Scene, SquadClaim, Structure};
use frontline_core::path_planner::PathPlanner;
use frontline_core::terrain::{Terrain, COVER, CRATER, RUBBLE, WOODS};
use frontline_core::vector::Vector3;

fn soldier() -> Input {
    Input {
        id: 1,
        team: 0,
        position: Vector3::ZERO,
        anchor: Vector3::ZERO,
        radius: 8.0,
        grouped: false,
        prone: false,
        unarmed: false,
        weapon_range: 50.0,
        current_structure: 0,
        current_anchor: -1,
    }
}
fn wall() -> Structure {
    Structure {
        id: 10,
        built: true,
        burn: 0.0,
        material: 2,
        positions: [-2.0, 2.0]
            .into_iter()
            .map(|x| Anchor {
                position: Vector3::new(x, 0.0, 0.0),
                normal: Vector3::Z,
                height: 1.2,
                kind: AnchorKind::Over,
            })
            .collect(),
    }
}
fn collision() -> CollisionWorld {
    let mut world = CollisionWorld::default();
    world.replace(
        10,
        &[BoxShape {
            body: 10,
            shape: 0,
            center: Vector3::new(0.0, 0.6, 1.0),
            basis: Mat3::IDENTITY,
            half: Vector3::new(8.0, 0.6, 0.2),
        }],
    );
    world
}

#[test]
fn cover_prefers_occupied_actor_position_then_yields_to_squad_claims() {
    let terrain = Terrain::blank(64).unwrap();
    let nav = PathPlanner::new(64).unwrap();
    let mut collision = collision();
    let structures = [wall()];
    let mut scene = Scene {
        terrain: &terrain,
        navigation: &nav,
        collision: &mut collision,
        heat: &[],
        deck: &[],
        structures: &structures,
        squad_claims: &[],
        nearby_claims: &[],
    };
    let threats = [Vector3::new(0.0, 1.6, 20.0)];
    let first = cover_search::find(soldier(), &threats, &mut scene).unwrap();
    assert_eq!((first.candidates, first.evaluations), (2, 2));
    assert_eq!(first.choice.unwrap().anchor, 0);
    let mut s = soldier();
    s.current_structure = 10;
    s.current_anchor = 1;
    assert_eq!(
        cover_search::find(s, &threats, &mut scene)
            .unwrap()
            .choice
            .unwrap()
            .anchor,
        1
    );
    let claims = [SquadClaim {
        id: 2,
        alive: true,
        covering: true,
        position: Vector3::new(-2.0, 0.0, 0.0),
    }];
    scene.squad_claims = &claims;
    assert_eq!(
        cover_search::find(soldier(), &threats, &mut scene)
            .unwrap()
            .choice
            .unwrap()
            .anchor,
        1
    );
}

#[test]
fn nearby_claims_use_existing_spatial_membership_and_team() {
    let terrain = Terrain::blank(64).unwrap();
    let nav = PathPlanner::new(64).unwrap();
    let mut collision = collision();
    let structures = [wall()];
    let mut claim = NearbyClaim {
        id: 2,
        team: 0,
        alive: true,
        gone: false,
        position: Vector3::new(-2.0, 0.0, 0.0),
        cover_position: Vector3::new(-2.0, 0.0, 0.0),
        cell: [-1, 0],
    };
    for case in 0..4 {
        claim.team = if case == 1 { 1 } else { 0 };
        claim.cell = if case == 2 { [10, 10] } else { [-1, 0] };
        claim.gone = case == 3;
        let mut scene = Scene {
            terrain: &terrain,
            navigation: &nav,
            collision: &mut collision,
            heat: &[],
            deck: &[],
            structures: &structures,
            squad_claims: &[],
            nearby_claims: &[claim],
        };
        assert_eq!(
            cover_search::find(soldier(), &[Vector3::new(0.0, 1.6, 20.0)], &mut scene)
                .unwrap()
                .choice
                .unwrap()
                .anchor,
            if case == 0 { 1 } else { 0 }
        );
    }
}

#[test]
fn cover_limits_structure_evaluations_and_checks_group_approaches() {
    let terrain = Terrain::blank(64).unwrap();
    let mut nav = PathPlanner::new(64).unwrap();
    let mut collision = collision();
    let mut structure = wall();
    structure.positions = vec![structure.positions[0]; 24];
    let structures = [structure];
    let threats = [Vector3::new(0.0, 1.6, 20.0)];
    {
        let mut scene = Scene {
            terrain: &terrain,
            navigation: &nav,
            collision: &mut collision,
            heat: &[],
            deck: &[],
            structures: &structures,
            squad_claims: &[],
            nearby_claims: &[],
        };
        let found = cover_search::find(soldier(), &threats, &mut scene).unwrap();
        assert_eq!((found.candidates, found.evaluations), (24, 20));
    }
    nav.load_cells(&[3; 4096], &[0; 4096], &[0; 4096]);
    let mut scene = Scene {
        terrain: &terrain,
        navigation: &nav,
        collision: &mut collision,
        heat: &[],
        deck: &[],
        structures: &structures,
        squad_claims: &[],
        nearby_claims: &[],
    };
    let mut s = soldier();
    s.grouped = true;
    assert_eq!(
        cover_search::find(s, &threats, &mut scene)
            .unwrap()
            .evaluations,
        0
    );
}

#[test]
fn ground_cover_keeps_crater_rubble_woods_and_heat_rules() {
    let nav = PathPlanner::new(64).unwrap();
    let mut collision = CollisionWorld::default();
    for (layer, height, material) in [(CRATER, 0.45, 2), (RUBBLE, 0.75, 2), (WOODS, 0.0, 0)] {
        let mut terrain = Terrain::blank(64).unwrap();
        terrain.layers[COVER].fill(2);
        terrain.layers[layer].fill(1);
        let mut scene = Scene {
            terrain: &terrain,
            navigation: &nav,
            collision: &mut collision,
            heat: &[],
            deck: &[],
            structures: &[],
            squad_claims: &[],
            nearby_claims: &[],
        };
        let result =
            cover_search::find(soldier(), &[Vector3::new(0.0, 1.6, 20.0)], &mut scene).unwrap();
        assert!(result.candidates > 20);
        assert_eq!(result.evaluations, 0);
        let choice = result.choice.unwrap();
        assert_eq!(
            (choice.evaluation.kind, choice.height, choice.material),
            (CoverType::Low, height, material)
        );
        assert_eq!((choice.structure, choice.anchor), (0, -1));
        scene.heat = &[1; 289];
        assert_eq!(
            cover_search::find(soldier(), &[Vector3::Z * 20.0], &mut scene)
                .unwrap()
                .candidates,
            0
        );
        assert!(cover_search::find(soldier(), &[], &mut scene)
            .unwrap()
            .choice
            .is_none());
    }
}

#[test]
fn malformed_cover_search_is_rejected_before_geometry_queries() {
    let terrain = Terrain::blank(64).unwrap();
    let nav = PathPlanner::new(64).unwrap();
    let mut collision = collision();
    let mut scene = Scene {
        terrain: &terrain,
        navigation: &nav,
        collision: &mut collision,
        heat: &[0; 10],
        deck: &[],
        structures: &[],
        squad_claims: &[],
        nearby_claims: &[],
    };
    assert!(cover_search::find(soldier(), &[Vector3::Z], &mut scene).is_err());
    scene.heat = &[];
    let mut s = soldier();
    s.radius = f64::NAN;
    assert!(cover_search::find(s, &[Vector3::Z], &mut scene).is_err());
    assert!(cover_search::find(soldier(), &[Vector3::splat(f32::NAN)], &mut scene).is_err());
}
