use frontline_core::actors::{Actor, Actors};
use frontline_core::battle_stats::BattleStats;
use frontline_core::economy::Economy;
use frontline_core::production_orders::{Item, Research};
use frontline_core::structure::Structure;
use frontline_core::vector::Vector3;
pub fn transcript() -> Vec<u8> {
    let mut out = Vec::new();
    for trial in 0..12 {
        let team = (trial % 2) as i8;
        let research = vec![Research {
            key: "tier2".into(),
            name: "Advanced equipment".into(),
            teams: 3,
            tier: 2,
        }];
        let item = Item {
            key: if trial % 3 == 0 { "armor" } else { "tank" }.into(),
            name: "Equipment".into(),
            cost: 70,
            time: 21.3,
            tier: if trial % 4 == 0 { 2 } else { 1 },
            research: trial % 3 == 0,
            teams: 3,
            requires: if trial % 3 == 0 { "tier2" } else { "" }.into(),
        };
        let create = |id, kind: &str, x, stock| {
            Actor::Structure(Box::new(Structure {
                id,
                kind: kind.into(),
                team,
                built: true,
                position: Vector3::new(x, 0., 0.),
                supply: stock,
                ..Default::default()
            }))
        };
        let mut actors = Actors::from_entries(
            10,
            vec![
                create(
                    1,
                    if item.research { "research" } else { "factory" },
                    0.,
                    0.,
                ),
                create(2, "fob", 10., 260.7),
                create(3, "fob", 20., 170.3),
            ],
        )
        .unwrap();
        let mut battle = BattleStats::default();
        let mut economy = Economy::default();
        if trial % 2 == 0 {
            economy.upgrades[team as usize].push("tier2".into());
        }
        for step in 0..18 {
            let mut a = Actors::restore(&actors.checkpoint().unwrap()).unwrap();
            let mut b = BattleStats::restore(&battle.checkpoint()).unwrap();
            let e = Economy::restore(&economy.checkpoint().unwrap()).unwrap();
            let run = |a: &mut Actors, b: &mut BattleStats, e: &Economy| {
                if step >= 7 && step % 3 == 1 {
                    e.cancel_production(a, b, 1, team)
                } else {
                    e.order_production(
                        a,
                        b,
                        1,
                        if trial == 5 { -2 } else { 7 + step % 2 },
                        team,
                        &item,
                        &[item.key.clone()],
                        &research,
                    )
                }
                .unwrap()
            };
            let one = run(&mut actors, &mut battle, &economy);
            assert_eq!(one, run(&mut a, &mut b, &e));
            let states = [
                actors.checkpoint().unwrap(),
                battle.checkpoint(),
                economy.checkpoint().unwrap(),
            ];
            assert_eq!(
                states,
                [
                    a.checkpoint().unwrap(),
                    b.checkpoint(),
                    e.checkpoint().unwrap()
                ]
            );
            for bytes in states
                .into_iter()
                .chain([format!("{trial}/{step} {one:?}").into_bytes()])
            {
                out.extend_from_slice(&(bytes.len() as u32).to_le_bytes());
                out.extend_from_slice(&bytes);
            }
        }
    }
    out
}
