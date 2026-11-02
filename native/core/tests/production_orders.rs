use frontline_core::actors::{Actor, Actors};
use frontline_core::battle_stats::BattleStats;
use frontline_core::economy::Economy;
use frontline_core::production_orders::{tier_needed, Item, Outcome, Research};
use frontline_core::structure::Structure;
use frontline_core::vector::Vector3;

fn scene(kind: &str, supply: f64) -> (Actors, BattleStats, Economy) {
    let make = |id, kind: &str, x, supply| {
        Actor::Structure(Box::new(Structure {
            id,
            kind: kind.into(),
            team: 0,
            built: true,
            position: Vector3::new(x, 0., 0.),
            supply,
            ..Default::default()
        }))
    };
    (
        Actors::from_entries(
            10,
            vec![
                make(1, kind, 0., 0.),
                make(2, "fob", 10., supply),
                make(3, "fob", 20., 40.),
            ],
        )
        .unwrap(),
        BattleStats::default(),
        Economy::default(),
    )
}
fn item() -> Item {
    Item {
        key: "tank".into(),
        name: "Tank".into(),
        cost: 60,
        time: 15.,
        tier: 1,
        research: false,
        teams: 1,
        requires: String::new(),
    }
}
fn research() -> Vec<Research> {
    vec![
        Research {
            key: "tier2".into(),
            name: "Heavy weapons".into(),
            teams: 1,
            tier: 2,
        },
        Research {
            key: "tier3".into(),
            name: "Heavy armor".into(),
            teams: 1,
            tier: 3,
        },
    ]
}
fn order(a: &mut Actors, b: &mut BattleStats, e: &Economy, i: &Item, peer: i32) -> Outcome {
    e.order_production(a, b, 1, peer, 0, i, &["tank".into()], &research())
        .unwrap()
}
#[test]
fn orders_spend_then_cancel_the_last_item_for_its_original_buyer() {
    let (mut a, mut b, e) = scene("factory", 200.);
    assert_eq!(order(&mut a, &mut b, &e, &item(), 7), Outcome::Changed);
    assert_eq!(order(&mut a, &mut b, &e, &item(), 8), Outcome::Changed);
    assert_eq!(a.structure(2).unwrap().supply, 80.);
    assert_eq!(a.structure(1).unwrap().queue[0].remaining, 15.);
    assert_eq!(
        e.cancel_production(&mut a, &mut b, 1, 0).unwrap(),
        Outcome::Changed
    );
    assert_eq!(a.structure(2).unwrap().supply, 140.);
    assert_eq!(a.structure(1).unwrap().queue[0].owner, 7);
    assert_eq!(
        b.players.iter().find(|p| p.owner == 7).unwrap().counters[14],
        60.
    );
    assert_eq!(
        b.players.iter().find(|p| p.owner == 8).unwrap().counters[14],
        0.
    );
}
#[test]
fn tier_checks_precede_payment_and_warnings_stay_private_to_humans() {
    let (mut a, mut b, mut e) = scene("factory", 200.);
    let mut i = item();
    i.tier = 3;
    let before = a.checkpoint().unwrap();
    assert_eq!(
        order(&mut a, &mut b, &e, &i, 7),
        Outcome::Warning {
            peer: 7,
            text: "Tank needs research first: Heavy armor.".into()
        }
    );
    assert_eq!(order(&mut a, &mut b, &e, &i, -1), Outcome::Ignored);
    assert_eq!(a.checkpoint().unwrap(), before);
    e.upgrades[0].push("tier3".into());
    assert_eq!(order(&mut a, &mut b, &e, &i, 7), Outcome::Changed);
    i.tier = 4;
    assert_eq!(tier_needed(&e, 0, &i, &research()), "tier 4");
}
#[test]
fn research_requires_its_predecessor_and_rejects_duplicate_or_completed_orders() {
    let (mut a, mut b, mut e) = scene("research", 500.);
    let mut i = item();
    i.key = "tier3".into();
    i.name = "Heavy armor".into();
    i.research = true;
    i.requires = "tier2".into();
    assert_eq!(
        order(&mut a, &mut b, &e, &i, 7),
        Outcome::Warning {
            peer: 7,
            text: "Heavy armor needs Heavy weapons first.".into()
        }
    );
    e.upgrades[0].push("tier2".into());
    assert_eq!(order(&mut a, &mut b, &e, &i, 7), Outcome::Changed);
    assert_eq!(order(&mut a, &mut b, &e, &i, 8), Outcome::Ignored);
    e.cancel_production(&mut a, &mut b, 1, 0).unwrap();
    e.upgrades[0].push("tier3".into());
    assert_eq!(order(&mut a, &mut b, &e, &i, 7), Outcome::Ignored);
}
#[test]
fn queue_limits_eligibility_and_shared_stock_match_existing_orders() {
    let (mut a, mut b, e) = scene("factory", 1000.);
    for _ in 0..6 {
        assert_eq!(order(&mut a, &mut b, &e, &item(), 7), Outcome::Changed);
    }
    assert_eq!(order(&mut a, &mut b, &e, &item(), 7), Outcome::Ignored);
    assert_eq!(
        e.cancel_production(&mut a, &mut b, 1, 1).unwrap(),
        Outcome::Ignored
    );
    assert_eq!(
        e.order_production(
            &mut a,
            &mut b,
            1,
            7,
            1,
            &item(),
            &["tank".into()],
            &research()
        )
        .unwrap(),
        Outcome::Ignored
    );
    let (mut a, mut b, e) = scene("research", 1000.);
    for n in 0..5 {
        let mut i = item();
        i.key = format!("upgrade{n}");
        i.research = true;
        assert_eq!(
            order(&mut a, &mut b, &e, &i, 7),
            if n < 4 {
                Outcome::Changed
            } else {
                Outcome::Ignored
            }
        );
    }
    let (mut a, mut b, e) = scene("factory", 30.9);
    assert_eq!(order(&mut a, &mut b, &e, &item(), 7), Outcome::Changed);
    assert!((a.structure(2).unwrap().supply - 0.9).abs() < 1e-12);
    assert_eq!(a.structure(3).unwrap().supply, 10.);
    assert!(matches!(
        order(&mut a, &mut b, &e, &item(), 7),
        Outcome::Warning { .. }
    ));
}
#[test]
fn invalid_definitions_or_credit_overflow_do_not_charge_or_change_the_queue() {
    let (mut a, mut b, e) = scene("factory", 100.);
    let before = a.checkpoint().unwrap();
    let mut i = item();
    i.time = f64::NAN;
    assert!(e
        .order_production(&mut a, &mut b, 1, 7, 0, &i, &["tank".into()], &research())
        .is_err());
    assert_eq!(a.checkpoint().unwrap(), before);
    b.sides[0][14] = 1e15;
    assert!(e
        .order_production(
            &mut a,
            &mut b,
            1,
            7,
            0,
            &item(),
            &["tank".into()],
            &research()
        )
        .is_err());
    assert_eq!(a.checkpoint().unwrap(), before);
    b.sides[0][14] = 0.;
    order(&mut a, &mut b, &e, &item(), 7);
    b.sides[0][14] = -1e15;
    let before = a.checkpoint().unwrap();
    assert!(e.cancel_production(&mut a, &mut b, 1, 0).is_err());
    assert_eq!(a.checkpoint().unwrap(), before);
}
#[test]
fn order_stream_continues_identically_after_every_saved_state() {
    let (mut a, mut b, e) = scene("factory", 200.);
    let (mut resumed, mut ledger, mut rules) = (a.clone(), b.clone(), e.clone());
    for step in 0..24 {
        let one = if step % 3 == 2 {
            e.cancel_production(&mut a, &mut b, 1, 0).unwrap()
        } else {
            order(&mut a, &mut b, &e, &item(), 7 + step % 2)
        };
        let two = if step % 3 == 2 {
            rules
                .cancel_production(&mut resumed, &mut ledger, 1, 0)
                .unwrap()
        } else {
            order(&mut resumed, &mut ledger, &rules, &item(), 7 + step % 2)
        };
        assert_eq!(one, two);
        assert_eq!(a.checkpoint().unwrap(), resumed.checkpoint().unwrap());
        assert_eq!(b.checkpoint(), ledger.checkpoint());
        resumed = Actors::restore(&resumed.checkpoint().unwrap()).unwrap();
        ledger = BattleStats::restore(&ledger.checkpoint()).unwrap();
        rules = Economy::restore(&rules.checkpoint().unwrap()).unwrap();
    }
}
