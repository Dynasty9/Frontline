use frontline_core::infantry_supply::{
    self as supply, Body, Cache, Depot, Search, SupplyTimers, Transfer,
};
use frontline_core::random::SimulationRandom;
use frontline_core::vector::Vector3;

fn body(id: u64, distance: f32, loot: i32) -> Body {
    Body {
        id,
        position: Vector3::X * distance,
        dead: true,
        loot,
    }
}
fn cache(id: u64, distance: f32) -> Cache {
    Cache {
        depot: Depot {
            id,
            position: Vector3::X * distance,
        },
        team: 0,
        built: true,
        gone: false,
        ammo_cache: true,
    }
}

#[test]
fn scavenging_keeps_truncated_threshold_query_order_and_probe_delay() {
    let mut state = SupplyTimers::default();
    let bodies = [body(1, 3.0, 0), body(2, 2.0, 5), body(3, 1.0, 100)];
    assert_eq!(state.scavenge(10.0, 20, Some(31), &bodies).unwrap(), None);
    assert_eq!(state.scavenge_at, 0.0);
    assert_eq!(
        state.scavenge(10.0, 19, Some(31), &bodies).unwrap(),
        Some(Transfer { body: 2, rounds: 5 })
    );
    assert_eq!(state.scavenge_at, 11.5);
    assert_eq!(state.scavenge(11.49, 0, Some(31), &bodies).unwrap(), None);
    assert_eq!(
        state.scavenge(11.5, 0, Some(31), &bodies[2..]).unwrap(),
        Some(Transfer {
            body: 3,
            rounds: 31
        })
    );
    assert_eq!(state.scavenge(20.0, 0, Some(9000), &bodies).unwrap(), None);
    assert_eq!(state.scavenge(20.0, 0, None, &bodies).unwrap(), None);
    assert_eq!(state.scavenge_at, 13.0);
    assert_eq!(state.scavenge(20.0, 0, Some(31), &[]).unwrap(), None);
    assert_eq!(state.scavenge_at, 21.5);
}

#[test]
fn resupply_search_retains_nearest_body_ties_and_six_second_delay() {
    let mut state = SupplyTimers::default();
    assert_eq!(
        state
            .search_bodies(10.0, Vector3::ZERO, &[body(1, 25.0, 10)])
            .unwrap(),
        Search::Depots
    );
    assert_eq!(
        state
            .search_bodies(15.99, Vector3::ZERO, &[body(1, 2.0, 10)])
            .unwrap(),
        Search::Wait
    );
    let bodies = [
        body(1, 25.0, 10),
        body(2, 1.0, 0),
        body(3, 20.0, 10),
        body(4, -20.0, 10),
    ];
    assert_eq!(
        state.search_bodies(16.0, Vector3::ZERO, &bodies).unwrap(),
        Search::Body(3)
    );
    assert_eq!(state.search_at, 22.0);
}

#[test]
fn depots_preserve_cache_filters_strict_ties_and_destination_draws() {
    let mut rng = SimulationRandom::new(991);
    let initial = rng;
    assert!(supply::choose_depot(
        Vector3::ZERO,
        0,
        Some(Depot {
            id: 1,
            position: Vector3::X * 90.0
        }),
        &[],
        &mut rng
    )
    .unwrap()
    .is_none());
    assert_eq!(rng, initial);
    let fob = Some(Depot {
        id: 1,
        position: Vector3::X * 50.0,
    });
    let mut wrong_team = cache(2, 5.0);
    wrong_team.team = 1;
    let mut unbuilt = cache(3, 5.0);
    unbuilt.built = false;
    let mut gone = cache(4, 5.0);
    gone.gone = true;
    let mut wrong_kind = cache(5, 5.0);
    wrong_kind.ammo_cache = false;
    let result = supply::choose_depot(
        Vector3::ZERO,
        0,
        fob,
        &[
            wrong_team,
            unbuilt,
            gone,
            wrong_kind,
            cache(6, 50.0),
            cache(7, 20.0),
            cache(8, 20.0),
        ],
        &mut rng,
    )
    .unwrap()
    .unwrap();
    let mut expected = initial;
    assert_eq!((result.depot, result.cache), (7, true));
    assert_eq!(
        result.position,
        Vector3::new(20.0 - 2.2, 0.0, 0.0)
            + Vector3::new(
                expected.randf_range(-1.0, 1.0),
                0.0,
                expected.randf_range(-1.0, 1.0)
            )
    );
    assert_eq!(rng, expected);
    let result = supply::choose_depot(Vector3::ZERO, 0, fob, &[cache(6, 50.0)], &mut rng)
        .unwrap()
        .unwrap();
    assert_eq!((result.depot, result.cache), (1, false));
    assert_eq!(
        result.position,
        Vector3::new(50.0, 0.0, 0.0)
            + Vector3::new(
                expected.randf_range(-4.0, 4.0),
                0.0,
                expected.randf_range(-4.0, 4.0)
            )
    );
    assert_eq!(rng, expected);
}

#[test]
fn refills_preserve_integer_rate_caps_and_four_draw_order() {
    assert_eq!(
        supply::refill_reserve(150, 20, 10, 0.0).unwrap(),
        (11, true)
    );
    assert_eq!(
        supply::refill_reserve(150, 20, 10, 0.5).unwrap(),
        (41, true)
    );
    assert_eq!(
        supply::refill_reserve(150, 20, 125, 1.0).unwrap(),
        (130, true)
    );
    assert_eq!(
        supply::refill_reserve(150, 160, 10, 1.0).unwrap(),
        (10, false)
    );
    assert_eq!(supply::refill_reserve(9000, 0, 0, 1.0).unwrap(), (0, false));
    for seed in 0..256 {
        let mut stock = [2, 0, 0, 0, 0];
        let capacity = [1, 2, 3, 4, 5];
        let mut expected_stock = stock;
        let mut rng = SimulationRandom::new(seed);
        let mut expected = rng;
        let dt = [0.0, 0.5, 1.0, 10.0][seed as usize % 4];
        supply::refill_special(&mut stock, capacity, dt, &mut rng).unwrap();
        if f64::from(expected.randf()) < dt * 0.1 {
            expected_stock[0] = 1;
            expected_stock[1] = 1;
        }
        for (index, rate) in [(2, 0.12), (3, 0.05), (4, 0.2)] {
            if f64::from(expected.randf()) < dt * rate {
                expected_stock[index] += 1;
            }
        }
        assert_eq!(stock, expected_stock);
        assert_eq!(rng, expected);
    }
}

#[test]
fn invalid_supply_input_does_not_advance_timers_stock_or_randomness() {
    let mut state = SupplyTimers {
        scavenge_at: 3.0,
        search_at: 4.0,
    };
    let checkpoint = state.checkpoint();
    assert_eq!(SupplyTimers::restore(&checkpoint).unwrap(), state);
    for length in 0..checkpoint.len() {
        assert!(SupplyTimers::restore(&checkpoint[..length]).is_err());
    }
    let mut bad = checkpoint.clone();
    bad.push(0);
    assert!(SupplyTimers::restore(&bad).is_err());
    assert!(state
        .scavenge(10.0, 0, Some(100), &[body(0, 1.0, 10)])
        .is_err());
    assert!(state.search_bodies(f64::NAN, Vector3::ZERO, &[]).is_err());
    assert_eq!(state.checkpoint(), checkpoint);
    let mut rng = SimulationRandom::new(1);
    let initial = rng;
    let mut stock = [1, 2, 3, 4, 5];
    assert!(supply::refill_special(&mut stock, [0, 0, 0, 0, -1], 1.0, &mut rng).is_err());
    assert_eq!(stock, [1, 2, 3, 4, 5]);
    assert!(supply::choose_depot(
        Vector3::ZERO,
        0,
        None,
        &[cache(1, 3.0), cache(0, 1.0)],
        &mut rng
    )
    .is_err());
    assert_eq!(rng, initial);
}
