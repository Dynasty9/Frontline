use frontline_core::actors::Actors;
use frontline_core::terrain::Terrain;
use frontline_core::vector::Vector3;
use frontline_core::vehicle::Vehicle;
use frontline_core::vehicle_birth::{Definition, Spawn};
use frontline_core::world_geometry::WorldGeometry;
fn definition(base: &str) -> Definition<'_> {
    Definition {
        kind: "test",
        base,
        hp: 500.,
        hull: Vector3::new(2.3, 2.6, 6.),
        missiles: [6, 8],
        tracked: false,
    }
}
fn spawn() -> Spawn {
    Spawn {
        team: 0,
        owner: 1,
        position: Vector3::new(4., 0.2, -7.),
        yaw: 0.317,
    }
}
#[test]
fn vehicle_birth_initializes_health_missiles_and_only_the_required_flight_state() {
    for base in ["tank", "boat", "supply", "attack_heli", "lift_heli", "uav"] {
        let v = Vehicle::from_spawn(7, spawn(), definition(base)).unwrap();
        assert_eq!(v.hp, 500.);
        assert_eq!(v.max_hp, 500.);
        assert_eq!([v.atgm_left, v.sam_left], [6, 8]);
        assert_eq!(v.smoke_left, 2);
        assert_eq!(
            v.flight.is_some(),
            matches!(base, "attack_heli" | "lift_heli")
        );
        assert_eq!(
            v.uav_destination.is_some(),
            matches!(base, "lift_heli" | "uav")
        );
        assert_eq!(v.yaw, f64::from(0.317f32));
    }
}
#[test]
fn spawning_registers_collision_without_changing_navigation_or_consuming_an_extra_id() {
    let mut a = Actors::default();
    let mut g = WorldGeometry::new(Terrain::blank(64).unwrap(), vec![], 16).unwrap();
    let nav = g.navigation.checkpoint();
    let id = g
        .spawn_vehicle(&mut a, spawn(), definition("tank"))
        .unwrap();
    assert_eq!(id, 1);
    assert_eq!(a.entities().next_id(), 2);
    assert!(g.collision.contains(1));
    assert_eq!(nav, g.navigation.checkpoint());
    assert_eq!(
        a.checkpoint().unwrap(),
        Actors::restore(&a.checkpoint().unwrap())
            .unwrap()
            .checkpoint()
            .unwrap()
    );
    assert_eq!(
        g.checkpoint(),
        WorldGeometry::restore(&g.checkpoint())
            .unwrap()
            .checkpoint()
    );
}
#[test]
fn rejected_vehicle_birth_preserves_identity_and_geometry() {
    let mut a = Actors::default();
    let mut g = WorldGeometry::new(Terrain::blank(64).unwrap(), vec![], 16).unwrap();
    let before = g.checkpoint();
    for bad in [
        Definition {
            hp: f64::NAN,
            ..definition("tank")
        },
        Definition {
            hull: Vector3::ZERO,
            ..definition("tank")
        },
        Definition {
            missiles: [-1, 0],
            tracked: false,
            ..definition("tank")
        },
    ] {
        assert!(g.spawn_vehicle(&mut a, spawn(), bad).is_err());
        assert_eq!(a.entities().next_id(), 1);
        assert_eq!(g.checkpoint(), before);
    }
    for bad in [
        Spawn {
            position: Vector3::NAN,
            ..spawn()
        },
        Spawn {
            owner: -3,
            ..spawn()
        },
        Spawn { team: 2, ..spawn() },
        Spawn {
            yaw: f64::INFINITY,
            ..spawn()
        },
    ] {
        assert!(g.spawn_vehicle(&mut a, bad, definition("tank")).is_err());
        assert_eq!(a.entities().next_id(), 1);
        assert_eq!(g.checkpoint(), before);
    }
}

#[test]
fn births_keep_boats_on_water_and_ground_trucks_before_collision_registration() {
    let mut terrain = Terrain::blank(32).unwrap();
    assert!(terrain.set_landform(vec![12.; 81]));
    terrain.heights.fill(12.);
    let mut world = WorldGeometry::new(terrain, vec![], 16).unwrap();
    let mut actors = Actors::default();
    for (base, height, expected) in [
        ("boat", -0.45, -0.45),
        ("tank", 0., 12.),
        ("attack_heli", 20., 20.),
        ("supply", 20., 12.),
    ] {
        let id = world
            .spawn_vehicle(
                &mut actors,
                Spawn {
                    team: 0,
                    owner: 1,
                    position: Vector3::new(0., height, 0.),
                    yaw: 0.,
                },
                Definition {
                    kind: base,
                    base,
                    hp: 100.,
                    hull: Vector3::new(2., 2., 4.),
                    missiles: [0, 0],
                    tracked: base == "tank",
                },
            )
            .unwrap();
        let v = actors.vehicle(id).unwrap();
        assert_eq!(v.position.y, expected);
        assert_eq!(v.tracked, base == "tank");
    }
}
