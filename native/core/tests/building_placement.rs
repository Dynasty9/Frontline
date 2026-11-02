use frontline_core::actors::Actors;
use frontline_core::building_placement::{Definition, Distances};
use frontline_core::structure::Structure;
use frontline_core::structure_birth::BuildingProfile;
use frontline_core::supply_network::SupplyNetwork;
use frontline_core::terrain::{Terrain, BASE, WATER};
use frontline_core::vector::Vector3;
use frontline_core::water::Water;
use frontline_core::world_geometry::WorldGeometry;
fn scene() -> (Actors, WorldGeometry, Water, SupplyNetwork) {
    (
        Actors::default(),
        WorldGeometry::new(Terrain::blank(256).unwrap(), vec![0; 256 * 256], 16).unwrap(),
        Water {
            side: 256,
            coast: None,
            rivers: vec![],
            ponds: vec![],
            fords: vec![],
            bridges: vec![],
        },
        SupplyNetwork::default(),
    )
}
fn def(key: &str) -> Definition<'_> {
    Definition {
        key,
        name: "Building",
        teams: 3,
        cost: 100,
        body: BuildingProfile {
            size: [8., 8.],
            hp: 500.,
        },
    }
}
fn add(a: &mut Actors, g: &mut WorldGeometry, kind: &str, team: i8, x: f32, z: f32) -> u32 {
    g.spawn_structure(
        a,
        Structure {
            kind: kind.into(),
            team,
            built: true,
            position: Vector3::new(x, 0., z),
            ..Default::default()
        },
        Some(def(kind).body),
    )
    .unwrap()
}
fn check(
    a: &Actors,
    g: &WorldGeometry,
    w: &Water,
    n: &SupplyNetwork,
    team: i8,
    key: &str,
    x: f32,
    z: f32,
) -> String {
    g.placement_error(
        a,
        n,
        w,
        team,
        Some(&def(key)),
        Vector3::new(x, 0., z),
        0.,
        &Distances {
            build: 70.,
            fob_spacing: 45.,
            fob_expand: 130.,
        },
        &|s| s.kind.clone(),
    )
    .unwrap()
}
#[test]
fn placement_requires_a_working_base_and_preserves_strict_map_edges() {
    let (mut a, mut g, w, n) = scene();
    assert_eq!(
        check(&a, &g, &w, &n, 0, "barracks", 0., 0.),
        "Must be within 70 m of a working FOB."
    );
    add(&mut a, &mut g, "fob", 0, -40., 0.);
    assert_eq!(check(&a, &g, &w, &n, 0, "barracks", 0., 0.), "");
    assert_eq!(
        check(&a, &g, &w, &n, 0, "barracks", 120., 0.),
        "Too close to the map edge."
    );
    assert_ne!(
        check(&a, &g, &w, &n, 0, "barracks", 119.99, 0.),
        "Too close to the map edge."
    );
    assert_eq!(
        check(&a, &g, &w, &n, 0, "barracks", 30., 0.),
        "Must be within 70 m of a working FOB."
    );
}
#[test]
fn foundations_reject_slopes_but_allow_level_high_ground() {
    let (mut a, mut g, w, n) = scene();
    add(&mut a, &mut g, "fob", 0, -40., 0.);
    let ramp = (0..65 * 65).map(|i| (i % 65) as f32 * 0.4).collect();
    assert!(g.terrain.set_landform(ramp));
    assert_eq!(
        check(&a, &g, &w, &n, 0, "barracks", 0., 0.),
        "The ground is too steep or uneven to build here."
    );
    assert!(g.terrain.set_landform(vec![12.; 65 * 65]));
    assert_eq!(check(&a, &g, &w, &n, 0, "barracks", 0., 0.), "");
}
#[test]
fn footholds_include_friendly_towns_but_all_fobs_enforce_spacing() {
    let (mut a, mut g, w, n) = scene();
    add(&mut a, &mut g, "town", 0, 0., 0.);
    assert_eq!(check(&a, &g, &w, &n, 0, "fob", 100., 0.), "");
    add(&mut a, &mut g, "fob", 1, 65., 0.);
    assert_eq!(
        check(&a, &g, &w, &n, 0, "fob", 100., 0.),
        "Too close to another FOB."
    );
    assert_eq!(check(&a, &g, &w, &n, 0, "fob", 110., 0.), "");
    assert_eq!(
        check(&a, &g, &w, &n, 1, "fob", -100., 0.),
        "A new FOB must be within 130 m of one of yours, or of a town you hold."
    );
}
#[test]
fn roads_and_camouflage_keep_the_existing_exemptions() {
    let (mut a, mut g, w, mut n) = scene();
    add(&mut a, &mut g, "fob", 0, -40., 20.);
    n.roads[0].push(vec![Vector3::new(-60., 0., 0.), Vector3::new(60., 0., 0.)]);
    assert_eq!(
        check(&a, &g, &w, &n, 0, "barracks", 0., 0.),
        "That would block your own supply road."
    );
    assert_eq!(check(&a, &g, &w, &n, 0, "trench", 0., 0.), "");
    add(&mut a, &mut g, "camo_net", 0, 0., 20.);
    assert_eq!(check(&a, &g, &w, &n, 0, "barracks", 0., 20.), "");
    assert_eq!(
        check(&a, &g, &w, &n, 0, "camo_net", 0., 20.),
        "There's a net here already."
    );
    add(&mut a, &mut g, "sandbags", 0, 20., 20.);
    assert_eq!(
        check(&a, &g, &w, &n, 0, "barracks", 20., 20.),
        "Blocked by sandbags."
    );
}
#[test]
fn docks_require_dry_footings_open_water_and_the_correct_half() {
    let (a, mut g, mut w, n) = scene();
    assert_eq!(
        check(&a, &g, &w, &n, 0, "dock", 0., 0.),
        "There's no water on this map."
    );
    w.coast = Some([0., 0.]);
    for z in 0..116 {
        for x in 0..256 {
            g.terrain.layers[BASE][z * 256 + x] = WATER;
        }
    }
    assert_eq!(check(&a, &g, &w, &n, 0, "dock", 0., 0.), "");
    assert_eq!(
        check(&a, &g, &w, &n, 0, "dock", 0., -10.),
        "A dock stands on the shore, its jetty out over the water."
    );
    assert_eq!(
        check(&a, &g, &w, &n, 0, "dock", 0., 40.),
        "A dock must face open water: put it on the shore with its front to the sea or the river."
    );
    g.terrain.layers[BASE].fill(0);
    for z in 0..72 {
        for x in 0..256 {
            g.terrain.layers[BASE][z * 256 + x] = WATER;
        }
    }
    assert_eq!(
        check(&a, &g, &w, &n, 0, "dock", 0., -48.),
        "Build docks on your own half of the map."
    );
    assert_eq!(check(&a, &g, &w, &n, 1, "dock", 0., -48.), "");
    let i = g.terrain.index(Vector3::new(0., 0., -48.));
    g.deck[i] = 1;
    assert_eq!(
        check(&a, &g, &w, &n, 1, "dock", 0., -48.),
        "A dock stands on the shore, its jetty out over the water."
    );
}
#[test]
fn trench_snap_stays_inside_the_bay_and_bad_coordinates_are_rejected() {
    let (mut a, mut g, w, n) = scene();
    add(&mut a, &mut g, "trench", 0, 0., 0.);
    let p = Vector3::new(0., 0., 1.);
    let s = g.trench_mount_spot(&a, p, 0.).unwrap().unwrap();
    assert_eq!(s.position, Vector3::ZERO);
    assert_eq!(s.variant, 1);
    assert!(g
        .trench_mount_spot(&a, Vector3::new(f32::NAN, 0., 0.), 0.)
        .is_err());
    let d = Distances {
        build: 70.,
        fob_spacing: 45.,
        fob_expand: 130.,
    };
    assert!(g
        .placement_error(
            &a,
            &n,
            &w,
            0,
            Some(&def("barracks")),
            p,
            f64::INFINITY,
            &d,
            &|s| s.kind.clone()
        )
        .is_err());
}
