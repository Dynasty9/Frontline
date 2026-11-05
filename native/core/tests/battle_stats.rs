use frontline_core::actors::{Actor, Actors};
use frontline_core::battle_stats::*;
use frontline_core::infantry::{Credit, Infantry};
use frontline_core::infantry_control::HiddenReason;
use frontline_core::infantry_vitals::Life;
use frontline_core::spatial::{SpatialIndex, UNIT_CELL};
use frontline_core::squad::Squad;
use frontline_core::vector::Vector3;
use frontline_core::vehicle::Vehicle;

fn soldier(id: u32, team: i8, owner: i32) -> Infantry {
    let mut s = Infantry::default();
    s.identity.id = id;
    s.identity.unit = "rifleman".into();
    s.identity.name = format!("Soldier {id}");
    s.identity.team = team;
    s.identity.owner = owner;
    s.identity.squad = u32::from(team.max(0) as u8) + 9;
    s
}
fn make_actors(soldiers: Vec<Infantry>) -> Actors {
    Actors::from_entries(
        100,
        soldiers
            .into_iter()
            .map(|s| Actor::Soldier(Box::new(s)))
            .collect(),
    )
    .unwrap()
}
fn unit(key: &str, owner: i32, team: i8) -> Unit {
    Unit {
        key: key.into(),
        name: key.into(),
        kind: "infantry".into(),
        owner,
        team,
        ended: -1.0,
        ..Default::default()
    }
}
fn killer() -> Credit {
    Credit {
        owner: 5,
        team: 0,
        unit: "s9".into(),
        soldier: 1,
    }
}

#[test]
fn casualty_credit_survives_wounds_and_ignores_captive_and_bearer_deaths() {
    let a = soldier(1, 0, 5);
    let mut b = soldier(2, 1, 6);
    b.identity.hit_by = Some(killer());
    let actors = make_actors(vec![a, b.clone()]);
    let mut stats = BattleStats::default();
    stats.register_unit(unit("s9", 5, 0)).unwrap();
    stats.register_unit(unit("s10", 6, 1)).unwrap();
    stats.damage(b.identity.hit_by.as_ref(), 77.0).unwrap();
    stats.soldier_down(&b, false).unwrap();
    stats
        .soldier_died(&b, Life::Downed, false, 35.0, &actors, "Rifleman")
        .unwrap();
    stats
        .soldier_died(&b, Life::Captive, false, 35.0, &actors, "Rifleman")
        .unwrap();
    stats
        .soldier_died(&b, Life::Alive, true, 35.0, &actors, "Rifleman")
        .unwrap();
    assert_eq!(stats.sides[0][KILLS], 1.0);
    assert_eq!(stats.sides[0][DOWNS], 1.0);
    assert_eq!(stats.sides[0][DAMAGE], 77.0);
    assert_eq!(stats.sides[1][LOST], 1.0);
    assert_eq!(stats.units[0].kills, 1);
    assert_eq!(stats.units[1].lost, 1);
    assert_eq!(stats.heroes[0].role, "Rifleman");
    let missing = make_actors(Vec::new());
    stats
        .soldier_died(&b, Life::Alive, false, 20.0, &missing, "")
        .unwrap();
    assert_eq!(
        stats.heroes[0].kills, 2,
        "the existing hero survives his actor's removal"
    );
}

#[test]
fn hit_credit_clamps_living_damage_and_keeps_last_enemy_through_friendly_fire() {
    let a = soldier(1, 0, 5);
    let mut b = soldier(2, 1, 6);
    b.vitals.hp = 17.7;
    let c = soldier(3, -1, 0);
    let mut d = soldier(4, 1, 6);
    d.vitals.life = Life::Downed;
    let mut actors = make_actors(vec![a, b, c, d]);
    let mut stats = BattleStats::default();
    stats.set_blame(Some(killer())).unwrap();
    stats.record_hit(2, 3, 50.0, &mut actors).unwrap();
    assert!(actors.soldier(2).unwrap().identity.hit_by.is_none());
    stats.record_hit(2, 1, 50.0, &mut actors).unwrap();
    assert_eq!(stats.sides[0][DAMAGE], 17.7);
    stats.record_hit(2, 4, 50.0, &mut actors).unwrap();
    assert_eq!(actors.soldier(2).unwrap().identity.hit_by, Some(killer()));
    stats.record_hit(4, 1, 50.0, &mut actors).unwrap();
    assert_eq!(actors.soldier(4).unwrap().identity.hit_by, Some(killer()));
    assert_eq!(stats.sides[0][DAMAGE], 17.7);
    let before = stats.checkpoint();
    let actors_before = actors.checkpoint().unwrap();
    assert!(stats.record_hit(2, 1, -1.0, &mut actors).is_err());
    assert_eq!(stats.checkpoint(), before);
    assert_eq!(actors.checkpoint().unwrap(), actors_before);
}

#[test]
fn rejoin_merges_totals_in_existing_order_without_recounting_the_side() {
    let mut stats = BattleStats::default();
    stats.joined(5, 0, "Old").unwrap();
    stats.joined(6, 1, "Foe").unwrap();
    stats.joined(7, 0, "New").unwrap();
    stats.joined(6, 1, "Changed").unwrap();
    assert_eq!(
        stats.players[1].name, "Foe",
        "repeated join does not rewrite an existing report line"
    );
    stats.add(5, 0, KILLS, 3.0).unwrap();
    stats.add(7, 0, KILLS, 2.0).unwrap();
    stats.register_unit(unit("s9", 5, 0)).unwrap();
    stats.rejoined(5, 7, 0, "Returned").unwrap();
    assert_eq!(
        stats.players.iter().map(|p| p.owner).collect::<Vec<_>>(),
        [6, 7]
    );
    assert_eq!(stats.players[1].counters[KILLS], 5.0);
    assert_eq!(stats.sides[0][KILLS], 5.0);
    assert_eq!(stats.units[0].owner, 7);
    stats.rejoined(7, 7, 0, "Same").unwrap();
    assert_eq!(stats.players[1].counters[KILLS], 5.0);
    let mut stats = BattleStats::restore(&stats.checkpoint()).unwrap();
    stats.add(5, 0, KILLS, 1.0).unwrap();
    assert_eq!(
        stats.players.last().unwrap().name,
        "Old",
        "a delayed hit retains the old commander's configured name"
    );
}

#[test]
fn capture_preserves_spatial_ties_and_unowned_mens_legacy_priority() {
    let actors = make_actors(vec![
        soldier(1, 0, 0),
        soldier(2, 0, 0),
        soldier(3, 0, 8),
        soldier(4, 0, 9),
    ]);
    let mut units = SpatialIndex::new(UNIT_CELL).unwrap();
    actors.rebuild_units(&mut units).unwrap();
    assert_eq!(
        BattleStats::default()
            .taker(Vector3::ZERO, 10.0, 0, &actors, &units)
            .unwrap(),
        8
    );
    let mut stats = BattleStats::default();
    stats
        .prisoner(actors.soldier(2).unwrap(), actors.soldier(3).unwrap(), 25.0)
        .unwrap();
    assert_eq!(stats.sides[0][CAPTURED], 1.0);
    assert_eq!(stats.players[0].owner, 8);
    assert_eq!(stats.players[0].counters[22], 1.0);
}

#[test]
fn samples_skip_unneeded_actor_work_and_thin_without_losing_the_last_row() {
    let mut a = soldier(1, 0, 5);
    a.vitals.life = Life::Hidden;
    a.control.hidden = HiddenReason::Held;
    let mut b = soldier(2, 0, 5);
    b.vitals.life = Life::Hidden;
    b.control.hidden = HiddenReason::Vehicle;
    let mut c = soldier(3, 1, 6);
    c.vitals.life = Life::Downed;
    let mut entries: Vec<_> = vec![a, b, c]
        .into_iter()
        .map(|s| Actor::Soldier(Box::new(s)))
        .collect();
    entries.push(Actor::Vehicle(Box::new(Vehicle {
        id: 4,
        kind: "truck".into(),
        hp: 100.0,
        team: 0,
        ..Default::default()
    })));
    let actors = Actors::from_entries(100, entries).unwrap();
    let mut stats = BattleStats::default();
    stats
        .tick(1.0, 1.0, [10.0, 20.0], &actors, |_| false)
        .unwrap();
    assert_eq!(
        stats.timeline[0],
        [1.0, 1.0, 1.0, 0.0, 0.0, 0.0, 0.0, 10.0, 20.0]
    );
    stats
        .tick(0.1, 1.1, [10.0, 20.0], &actors, |_| {
            panic!("not time to sample")
        })
        .unwrap();
    for i in 1..241 {
        stats
            .tick(10.0, i as f64 * 10.0, [10.0, 20.0], &actors, |_| false)
            .unwrap();
    }
    assert_eq!(stats.timeline.len(), 121);
    assert_eq!(stats.every, 20.0);
    assert_eq!(
        stats.sample_timer, 10.0,
        "the current countdown precedes thinning"
    );
    assert_eq!(stats.timeline.last().unwrap()[0], 2400.0);
}

#[test]
fn live_reports_hide_enemy_strength_spending_and_support() {
    let actors = make_actors(vec![soldier(1, 0, 5), soldier(2, 1, 6)]);
    let mut stats = BattleStats::default();
    stats.add(5, 0, KILLS, 3.0).unwrap();
    stats.add(6, 1, KILLS, 2.0).unwrap();
    for team in 0..2 {
        stats
            .register_unit(unit(&format!("s{}", team + 9), team as i32 + 5, team))
            .unwrap();
        for kind in ["sup", "town"] {
            stats
                .event(Event {
                    time: 1.0,
                    team,
                    kind: kind.into(),
                    text: kind.into(),
                })
                .unwrap();
        }
    }
    let row = stats.row(10.0, [123.0, 456.0], &actors, |_| false).unwrap();
    let squads = [Squad {
        id: 9,
        owner: 5,
        members: vec![1],
        ..Default::default()
    }];
    let report = stats.report(0, false, row, &squads, &actors).unwrap();
    assert_eq!(report.players.len(), 1);
    assert_eq!(report.units.len(), 1);
    assert!(report.sides[1].is_none());
    assert_eq!(report.units[0].alive, 1);
    assert_eq!(report.events.len(), 3);
    assert_eq!(
        report.timeline[0],
        [10.0, 1.0, -1.0, 0.0, -1.0, 3.0, 2.0, 123.0, -1.0]
    );
    let full = stats.report(0, true, row, &squads, &actors).unwrap();
    assert_eq!(full.players.len(), 2);
    assert_eq!(full.events.len(), 4);
    assert_eq!(full.timeline[0][8], 456.0);
}

#[test]
fn blame_is_nested_neutral_sources_override_it_and_event_limit_keeps_objectives() {
    let actors = make_actors(vec![soldier(1, -1, 0)]);
    let mut stats = BattleStats::default();
    let old = stats.set_blame(Some(killer())).unwrap();
    assert_eq!(stats.who(0, &actors), Some(killer()));
    assert_eq!(stats.who(1, &actors), None);
    stats.set_blame(old).unwrap();
    assert_eq!(stats.who(0, &actors), None);
    for i in 0..100 {
        stats
            .event(Event {
                time: i as f64,
                team: 0,
                kind: "veh".into(),
                text: "loss".into(),
            })
            .unwrap();
    }
    stats
        .event(Event {
            time: 101.0,
            team: 1,
            kind: "fob".into(),
            text: "captured".into(),
        })
        .unwrap();
    assert_eq!(stats.events.len(), 91);
    assert_eq!(BattleStats::restore(&stats.checkpoint()).unwrap(), stats);
}

#[test]
fn checkpoints_reject_duplicate_identity_corruption_and_invalid_updates() {
    let mut stats = BattleStats::default();
    stats.joined(5, 0, "Commander").unwrap();
    stats.players.push(stats.players[0].clone());
    assert!(BattleStats::restore(&stats.checkpoint()).is_err());
    stats.players.pop();
    let before = stats.checkpoint();
    assert!(stats.add(5, 0, KILLS, f64::NAN).is_err());
    assert!(stats.rejoined(5, 6, 4, "bad").is_err());
    assert_eq!(stats.checkpoint(), before);
    for length in [0, 7, before.len() - 1] {
        assert!(BattleStats::restore(&before[..length]).is_err());
    }
    let mut bad = before.clone();
    bad[6] = 0;
    assert!(BattleStats::restore(&bad).is_err());
    let mut extra = before.clone();
    extra.push(0);
    assert!(BattleStats::restore(&extra).is_err());
    let mut resumed = BattleStats::restore(&before).unwrap();
    for i in 0..200 {
        stats.shot(5, 0, i % 7 == 0).unwrap();
        resumed.shot(5, 0, i % 7 == 0).unwrap();
    }
    assert_eq!(stats, resumed);
}
