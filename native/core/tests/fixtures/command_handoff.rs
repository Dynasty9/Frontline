use frontline_core::actors::{Actor, Actors};
use frontline_core::battle_stats::BattleStats;
use frontline_core::command_ownership::Ownership;
use frontline_core::infantry::Infantry;
use frontline_core::infantry_vitals::Life;
use frontline_core::squad::Squad;
use frontline_core::structure::{Production, Structure};
use frontline_core::vehicle::Vehicle;

pub fn scene(team: i8, other_humans: bool) -> (Ownership, Actors, Vec<Squad>, BattleStats) {
    let mut ownership = Ownership::default();
    ownership.connect(7, team).unwrap();
    ownership.connect(9, 1 - team).unwrap();
    if other_humans {
        ownership.connect(8, team).unwrap();
        ownership.connect(10, team).unwrap();
    }
    ownership.connect(11, -1).unwrap();
    let mut entries = Vec::new();
    let mut squads = Vec::new();
    for id in 1..=5 {
        let side = if id == 5 { 1 - team } else { team };
        let owner = if id == 4 {
            -1 - i32::from(team)
        } else if id == 5 {
            9
        } else {
            7
        };
        let mut soldier = Infantry::default();
        soldier.identity.id = id;
        soldier.identity.team = side;
        soldier.identity.owner = owner;
        soldier.identity.unit = "rifleman".into();
        soldier.identity.squad = id;
        soldier.vitals.life = if id == 2 { Life::Downed } else { Life::Alive };
        entries.push(Actor::Soldier(Box::new(soldier)));
        squads.push(Squad {
            id,
            team: side,
            owner,
            kind: "rifle_squad".into(),
            members: vec![id],
            ..Default::default()
        });
    }
    for id in 20..24 {
        entries.push(Actor::Vehicle(Box::new(Vehicle {
            id,
            team,
            owner: if id < 22 { 7 } else { -1 - i32::from(team) },
            kind: if id % 2 == 0 { "tank" } else { "truck" }.into(),
            ..Default::default()
        })));
    }
    entries.push(Actor::Structure(Box::new(Structure {
        id: 30,
        kind: "barracks".into(),
        team: 1 - team,
        queue: vec![Production {
            item: "rifle_squad".into(),
            remaining: 3.,
            total: 10.,
            owner: 7,
            cost: 50,
        }],
        ..Default::default()
    })));
    let actors = Actors::from_entries(100, entries).unwrap();
    let mut battle = BattleStats::default();
    battle.joined(7, team, "First").unwrap();
    battle.add(7, team, 14, 150.).unwrap();
    (ownership, actors, squads, battle)
}
pub fn transcript() -> Vec<u8> {
    let mut out = Vec::new();
    for trial in 0..24 {
        let team = (trial % 2) as i8;
        let (mut o, mut a, mut qs, mut b) = scene(team, trial % 3 == 0);
        for step in 0..5 {
            let mut oo = Ownership::restore(&o.checkpoint().unwrap()).unwrap();
            let mut aa = Actors::restore(&a.checkpoint().unwrap()).unwrap();
            let mut qq: Vec<_> = qs
                .iter()
                .map(|q| Squad::restore(&q.checkpoint().unwrap()).unwrap())
                .collect();
            let mut bb = BattleStats::restore(&b.checkpoint()).unwrap();
            let run = |o: &mut Ownership,
                       a: &mut Actors,
                       qs: &mut Vec<Squad>,
                       b: &mut BattleStats|
             -> String {
                match step {
                    0 => format!(
                        "{:?}",
                        o.take_command(7, &[4, 4, 5], &[22, 22], qs, a).unwrap()
                    ),
                    1 => format!("{:?}", o.depart(7, qs, a).unwrap()),
                    2 => {
                        o.connect(17, team).unwrap();
                        format!(
                            "{:?}",
                            o.reclaim(17, 7, "Returned", qs, a, b, trial % 4 == 0, &|k| k
                                == "truck")
                                .unwrap()
                        )
                    }
                    3 => format!("{:?}", o.depart(17, qs, a).unwrap()),
                    _ => {
                        o.connect(27, team).unwrap();
                        format!(
                            "{:?}",
                            o.reclaim(27, 17, "Again", qs, a, b, true, &|k| k == "truck")
                                .unwrap()
                        )
                    }
                }
            };
            let event = run(&mut o, &mut a, &mut qs, &mut b);
            assert_eq!(event, run(&mut oo, &mut aa, &mut qq, &mut bb));
            assert_eq!(o, oo);
            assert_eq!(qs, qq);
            assert_eq!(b, bb);
            assert_eq!(a.checkpoint().unwrap(), aa.checkpoint().unwrap());
            for block in [
                o.checkpoint().unwrap(),
                a.checkpoint().unwrap(),
                b.checkpoint(),
                event.into_bytes(),
            ]
            .into_iter()
            .chain(qs.iter().map(|q| q.checkpoint().unwrap()))
            {
                out.extend_from_slice(&(block.len() as u32).to_le_bytes());
                out.extend_from_slice(&block);
            }
        }
    }
    out
}
