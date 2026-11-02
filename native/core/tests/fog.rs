use frontline_core::actors::{Actor, Actors};
use frontline_core::fog::{self, Fog, VehicleProfile};
use frontline_core::infantry::Infantry;
use frontline_core::infantry_vitals::Life;
use frontline_core::projectile_actor::{Motion, Projectile};
use frontline_core::structure::Structure;
use frontline_core::support::{Kind, SupportFlight};
use frontline_core::terrain::{Terrain, NETTED};
use frontline_core::vector::Vector3;
use frontline_core::vehicle::Vehicle;
fn profile(_: &Vehicle) -> VehicleProfile {
    VehicleProfile {
        sight: 50.,
        helicopter: false,
        automatic: false,
        cannon: false,
    }
}
#[test]
fn a_new_drone_starts_unseen_and_its_first_visibility_change_is_reported() {
    use frontline_core::drone::DroneFlight;
    use frontline_core::drone_actor::Drone;
    let mut a = actors(vec![Actor::Drone(Drone {
        id: 1,
        team: 0,
        operator: 0,
        target: 0,
        operator_at_spawn: 0,
        target_at_spawn: 0,
        warhead: 1.,
        flight: DroneFlight::new(Vector3::ZERO, 0.),
    })]);
    let mut f = Fog::default();
    assert_eq!(
        f.update(&mut a, &Terrain::blank(256).unwrap(), 100., &profile)
            .unwrap(),
        vec![1]
    );
    assert_eq!(f.drones, vec![(1, 1)]);
}
fn soldier(id: u32, team: i8, x: f32, life: Life) -> Actor {
    let mut s = Infantry::default();
    s.identity.id = id;
    s.identity.team = team;
    s.identity.unit = "rifleman".into();
    s.identity.visible = 0;
    s.vitals.life = life;
    s.motion.position = Vector3::new(x, 0., 0.);
    Actor::Soldier(Box::new(s))
}
fn actors(v: Vec<Actor>) -> Actors {
    Actors::from_entries(1000, v).unwrap()
}
#[test]
fn friendly_hidden_soldiers_and_enemy_mines_keep_their_private_masks() {
    let mut a = actors(vec![
        soldier(1, 0, 0., Life::Alive),
        soldier(2, 1, 10., Life::Hidden),
        Actor::Structure(Box::new(Structure {
            id: 30,
            team: 1,
            kind: "mines".into(),
            built: true,
            position: Vector3::X * 5.,
            visible: 0,
            seen: 0,
            ..Default::default()
        })),
    ]);
    let mut f = Fog::default();
    f.update(&mut a, &Terrain::blank(256).unwrap(), 100., &profile)
        .unwrap();
    assert_eq!(a.soldier(1).unwrap().identity.visible, 1);
    assert_eq!(a.soldier(2).unwrap().identity.visible, 2);
    assert_eq!(a.structure(30).unwrap().visible, 2);
    assert_eq!(a.structure(30).unwrap().seen, 2);
    assert!(f.sighted[0].is_empty());
}
#[test]
fn camouflage_requires_half_range_except_for_airborne_aircraft() {
    let mut terrain = Terrain::blank(256).unwrap();
    let i = terrain.index(Vector3::X * 40.);
    terrain.layers[NETTED][i] = 1;
    for (height, helicopter, expected) in [(0., false, 2), (3., true, 2), (3.01, true, 3)] {
        let mut a = actors(vec![
            soldier(1, 0, 0., Life::Alive),
            Actor::Vehicle(Box::new(Vehicle {
                id: 20,
                team: 1,
                position: Vector3::new(40., height, 0.),
                ..Default::default()
            })),
        ]);
        let mut f = Fog::default();
        f.update(&mut a, &terrain, 100., &|_| VehicleProfile {
            helicopter,
            ..profile(&Vehicle::default())
        })
        .unwrap();
        assert_eq!(a.vehicle(20).unwrap().visible, expected);
    }
}
#[test]
fn reconnaissance_expiry_is_inclusive_and_remembered_sightings_survive_loss_of_contact() {
    let mut a = actors(vec![soldier(2, 1, 80., Life::Alive)]);
    let terrain = Terrain::blank(256).unwrap();
    let mut f = Fog::default();
    f.add_mark(0, Vector3::X * 80., 20., 100., 0.5).unwrap();
    f.update(&mut a, &terrain, 100.5, &profile).unwrap();
    assert_eq!(a.soldier(2).unwrap().identity.visible, 3);
    assert_eq!(f.sighted[0][0].time, 100.5);
    f.update(&mut a, &terrain, 100.50001, &profile).unwrap();
    assert!(f.marks[0].is_empty());
    assert_eq!(a.soldier(2).unwrap().identity.visible, 2);
    assert_eq!(f.sighted[0][0].time, 100.5);
}
#[test]
fn support_aircraft_observe_their_flight_and_orbit_without_ground_entities() {
    let mut flight = SupportFlight::new(
        Kind::Orbit,
        Vector3::new(-80., 50., 0.),
        Vector3::ZERO,
        Vector3::X * 80.,
    );
    flight.life = 3.;
    let p = Projectile {
        id: 20,
        team: 0,
        thrower: 0,
        called_by: 0,
        held_by: 0,
        smothered_by: 0,
        handler: 0,
        thrown_back: 0,
        target_id: 0,
        motion: Motion::Support(flight),
    };
    let mut a = actors(vec![
        soldier(1, 1, 80., Life::Alive),
        soldier(2, 1, -80., Life::Alive),
        Actor::Projectile(p),
    ]);
    let mut f = Fog::default();
    f.update(&mut a, &Terrain::blank(256).unwrap(), 100., &profile)
        .unwrap();
    assert_eq!(a.soldier(1).unwrap().identity.visible, 3);
    assert_eq!(a.soldier(2).unwrap().identity.visible, 3);
    assert_eq!(
        f.sighted[0].iter().map(|s| s.id).collect::<Vec<_>>(),
        vec![1, 2]
    );
}
#[test]
fn remembered_gun_positions_and_visible_weapons_update_both_route_danger_grids() {
    let a = actors(vec![
        soldier(1, 1, 0., Life::Alive),
        Actor::Structure(Box::new(Structure {
            id: 30,
            team: 1,
            kind: "mg_nest".into(),
            built: true,
            seen: 1,
            ..Default::default()
        })),
    ]);
    let mut nav = frontline_core::navigation_scene::NavigationScene::new(
        &Terrain::blank(256).unwrap(),
        &[],
        16,
    )
    .unwrap();
    assert!(nav.finalize(1));
    let maps = fog::update_danger(&a, &mut nav, &profile).unwrap();
    assert!(maps[0].iter().any(|&v| v > 2.));
    assert!(maps[1].iter().all(|&v| v == 0.));
    assert!(maps[0].iter().all(|&v| v <= 4.));
    let restored =
        frontline_core::navigation_scene::NavigationScene::restore(&nav.checkpoint()).unwrap();
    assert_eq!(nav.checkpoint(), restored.checkpoint());
}
#[test]
fn fog_resumes_exactly_and_rejects_invalid_or_excessive_observation_grids() {
    let mut a = actors(vec![
        soldier(1, 0, 0., Life::Alive),
        soldier(2, 1, 70., Life::Alive),
    ]);
    let terrain = Terrain::blank(256).unwrap();
    let mut f = Fog::default();
    f.add_mark(0, Vector3::X * 70., 30., 100., 3.).unwrap();
    let mut b = Actors::restore(&a.checkpoint().unwrap()).unwrap();
    let mut g = Fog::restore(&f.checkpoint().unwrap()).unwrap();
    for now in [100., 103., 104.] {
        assert_eq!(
            f.update(&mut a, &terrain, now, &profile).unwrap(),
            g.update(&mut b, &terrain, now, &profile).unwrap()
        );
        assert_eq!(f, g);
        assert_eq!(a.checkpoint().unwrap(), b.checkpoint().unwrap());
    }
    let before = f.clone();
    assert!(f.update(&mut a, &terrain, f64::NAN, &profile).is_err());
    assert_eq!(f, before);
    let mut bytes = f.checkpoint().unwrap();
    bytes.push(0);
    assert!(Fog::restore(&bytes).is_err());
    let mut huge = actors(vec![Actor::Structure(Box::new(Structure {
        id: 30,
        team: 0,
        kind: "town".into(),
        built: true,
        zone_radius: 100_000.,
        ..Default::default()
    }))]);
    let snapshot = huge.checkpoint().unwrap();
    assert!(f.update(&mut huge, &terrain, 104., &profile).is_err());
    assert_eq!(f, before);
    assert_eq!(huge.checkpoint().unwrap(), snapshot);
}
