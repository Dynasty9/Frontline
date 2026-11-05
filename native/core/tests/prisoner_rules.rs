use frontline_core::actors::{Actor, Actors};
use frontline_core::battle_stats::BattleStats;
use frontline_core::infantry::{Goal, Infantry};
use frontline_core::infantry_control::HiddenReason;
use frontline_core::infantry_controller::Task;
use frontline_core::infantry_prison_owned::{Custody, CustodyProfile, IntelMode};
use frontline_core::infantry_vitals::Life;
use frontline_core::prisoner_intelligence::{Intelligence, PrisonerIntelligence};
use frontline_core::random::SimulationRandom;
use frontline_core::spatial::{SpatialIndex, UNIT_CELL};
use frontline_core::squad::Squad;
use frontline_core::structure::{Production, Structure};
use frontline_core::vector::Vector3;

fn soldier(id: u32, team: i8, x: f32) -> Infantry {
    let mut s = Infantry::default();
    s.identity.id = id;
    s.identity.unit = "rifleman".into();
    s.identity.weapon = "rifle".into();
    s.identity.name = format!("Soldier {id}");
    s.identity.team = team;
    s.motion.position.x = x;
    s
}
fn actors(soldiers: Vec<Infantry>, structures: Vec<Structure>) -> Actors {
    Actors::from_entries(
        1000,
        soldiers
            .into_iter()
            .map(|s| Actor::Soldier(Box::new(s)))
            .chain(
                structures
                    .into_iter()
                    .map(|s| Actor::Structure(Box::new(s))),
            )
            .collect(),
    )
    .unwrap()
}
fn custody(a: &mut Actors, now: f64, mission: bool) -> Result<Custody, &'static str> {
    let mut units = SpatialIndex::new(UNIT_CELL).unwrap();
    a.rebuild_units(&mut units).unwrap();
    a.advance_prisoner(
        1,
        now,
        CustodyProfile {
            mission,
            depots: [0, 0],
            restored_weapon: Some(("rifle", 30)),
            squad_name: "Rifle Squad",
        },
        &[],
        &mut vec![],
        &mut 1,
        &mut BattleStats::default(),
        &units,
        |s| s.identity.unit == "bearer",
    )
}
fn prisoner() -> Infantry {
    let mut p = soldier(1, 0, 0.0);
    p.vitals.life = Life::Surrender;
    p.identity.weapon.clear();
    p.links.captor = 999;
    p
}

#[test]
fn friends_release_and_rearm_before_forming_a_new_section() {
    let mut a = actors(vec![prisoner(), soldier(2, 0, 5.999)], vec![]);
    let Custody::Freed(joined) = custody(&mut a, 10.0, false).unwrap() else {
        panic!()
    };
    assert!(joined.created);
    let p = a.soldier(1).unwrap();
    assert_eq!(p.vitals.life, Life::Alive);
    assert_eq!(p.links.captor, 0);
    assert_eq!(p.identity.weapon, "rifle");
    assert_eq!((p.weapon.magazine, p.weapon.reserve), (30, 30));
    assert_eq!(p.vitals.speech_cooldown, 2.6);
    assert_eq!(p.identity.squad, joined.squad);
}

#[test]
fn only_free_armed_enemy_soldiers_can_claim_an_unguarded_prisoner() {
    let mut friend = soldier(2, 0, 1.0);
    friend.identity.unit = "bearer".into();
    let mut busy = soldier(3, 1, 1.0);
    busy.duty.kind = Task::Heal;
    let mut unarmed = soldier(4, 1, 1.0);
    unarmed.identity.weapon.clear();
    let mut dead = soldier(5, 1, 1.0);
    dead.vitals.life = Life::Dead;
    let guard = soldier(6, 1, 34.999);
    let mut a = actors(vec![prisoner(), friend, busy, unarmed, dead, guard], vec![]);
    let Custody::Assigned { captor, route } = custody(&mut a, 10.0, false).unwrap() else {
        panic!()
    };
    assert_eq!(captor, 6);
    assert_eq!(route.job.destination, Vector3::ZERO);
    let c = a.soldier(6).unwrap();
    assert_eq!(c.duty.kind, Task::Captor);
    assert_eq!(c.duty.entity, 1);
    assert_eq!(c.orders.purpose, Goal::Task);
    assert_eq!(a.soldier(1).unwrap().links.captor, 6);
    let mut a = actors(vec![prisoner(), soldier(6, 1, 35.0)], vec![]);
    assert_eq!(custody(&mut a, 10.0, false).unwrap(), Custody::Unchanged);
    assert_eq!(a.soldier(1).unwrap().links.captor, 0);
}

#[test]
fn missions_do_not_send_guards_to_missing_or_distant_prisons() {
    for (prison, assigned) in [(None, false), (Some(200.0), true), (Some(200.01), false)] {
        let st = prison.map(|x| Structure {
            id: 10,
            team: 1,
            kind: "fob".into(),
            position: Vector3::X * x,
            ..Default::default()
        });
        let mut a = actors(
            vec![prisoner(), soldier(2, 1, 1.0)],
            st.into_iter().collect(),
        );
        assert_eq!(
            matches!(
                custody(&mut a, 10.0, true).unwrap(),
                Custody::Assigned { .. }
            ),
            assigned
        );
    }
}

#[test]
fn guard_loss_cancels_the_prison_route_and_rescue_waits_for_the_next_rule_pass() {
    let mut p = prisoner();
    p.vitals.life = Life::Captive;
    p.go_to(Vector3::X * 25.0, Goal::Prison, 0).unwrap();
    let mut a = actors(vec![p, soldier(2, 0, 1.0)], vec![]);
    assert_eq!(custody(&mut a, 10.0, false).unwrap(), Custody::LostGuard);
    let p = a.soldier(1).unwrap();
    assert_eq!(p.vitals.life, Life::Surrender);
    assert!(p.motion.path.is_empty() && !p.orders.pending_path);
    assert!(matches!(
        custody(&mut a, 11.0, false).unwrap(),
        Custody::Freed(_)
    ));
}

#[test]
fn intelligence_uses_strict_deadlines_and_preserves_march_and_detention_cadence() {
    for (life, reason, mode, wait) in [
        (Life::Captive, HiddenReason::Waiting, IntelMode::March, 10.0),
        (Life::Hidden, HiddenReason::Held, IntelMode::Held, 7.0),
        (
            Life::Hidden,
            HiddenReason::Interrogation,
            IntelMode::Interrogation,
            7.0,
        ),
    ] {
        let mut p = prisoner();
        p.vitals.life = life;
        p.control.hidden = reason;
        p.links.captor = 2;
        p.links.intel_left = 1;
        p.links.intel_timer = 10.0;
        let mut c = soldier(2, 1, 0.0);
        c.duty.kind = Task::Captor;
        c.duty.entity = 1;
        let mut a = actors(vec![p, c], vec![]);
        assert_eq!(custody(&mut a, 10.0, false).unwrap(), Custody::Unchanged);
        assert_eq!(
            custody(&mut a, 10.1, false).unwrap(),
            Custody::Intelligence(mode)
        );
        assert_eq!(a.soldier(1).unwrap().links.intel_left, 0);
        assert_eq!(a.soldier(1).unwrap().links.intel_timer, 10.1 + wait);
        assert_eq!(custody(&mut a, 50.0, false).unwrap(), Custody::Unchanged);
    }
}

#[test]
fn rejected_release_does_not_partly_rearm_or_reassign_the_prisoner() {
    let mut a = actors(vec![prisoner(), soldier(2, 0, 1.0)], vec![]);
    let before = a.checkpoint().unwrap();
    let mut units = SpatialIndex::new(UNIT_CELL).unwrap();
    a.rebuild_units(&mut units).unwrap();
    let mut squads = vec![Squad {
        id: 4,
        ..Default::default()
    }];
    let saved = squads.clone();
    assert!(a
        .advance_prisoner(
            1,
            10.0,
            CustodyProfile {
                mission: false,
                depots: [0, 0],
                restored_weapon: Some(("rifle", 30)),
                squad_name: "Rifle Squad"
            },
            &[],
            &mut squads,
            &mut 4,
            &mut BattleStats::default(),
            &units,
            |_| false
        )
        .is_err());
    assert_eq!(a.checkpoint().unwrap(), before);
    assert_eq!(squads, saved);
}

fn reveal(
    history: &mut PrisonerIntelligence,
    a: &Actors,
    rng: &mut SimulationRandom,
    towns: &[u32],
    commanders: &[(i8, u32)],
) -> Intelligence {
    let mut units = SpatialIndex::new(UNIT_CELL).unwrap();
    a.rebuild_units(&mut units).unwrap();
    history
        .reveal(
            1,
            IntelMode::Interrogation,
            a,
            &units,
            towns,
            commanders,
            1024,
            |s| s.identity.unit == "bearer",
            |st| st.name.clone(),
            |item| item.to_owned(),
            rng,
        )
        .unwrap()
}

#[test]
fn exhausted_intelligence_repeats_without_resetting_history_and_consumes_two_draws() {
    let a = actors(vec![prisoner()], vec![]);
    let mut history = PrisonerIntelligence::default();
    let mut rng = SimulationRandom::new(345);
    let mut expected = rng;
    for _ in 0..4 {
        expected.randi();
        expected.randi();
        let intel = reveal(&mut history, &a, &mut rng, &[], &[]);
        assert_eq!(intel.team, 1);
        assert_eq!(intel.fact.key, "army");
        assert_eq!(intel.fact.position, None);
        assert_eq!(
            intel.fact.text,
            "We've only got about 0 men and 0 vehicles left."
        );
        assert!(intel.text.starts_with("[Interrogation] Soldier 1: \""));
        assert_eq!(rng.state(), expected.state());
        history = PrisonerIntelligence::restore(&history.checkpoint()).unwrap();
    }
    assert_eq!(history.given(1), ["army", "army", "army", "army"]);
    history.forget(1);
    assert!(history.given(1).is_empty());
}

#[test]
fn fresh_facts_precede_repeats_and_include_queues_towns_and_attack_plans() {
    let mut st = vec![];
    for (i, kind) in [
        "fob",
        "mg_nest",
        "hmg_nest",
        "mortar_pit",
        "bunker",
        "at_post",
        "trench",
        "watchtower",
        "mines",
        "tunnel",
        "barracks",
        "factory",
        "medic_tent",
        "town",
    ]
    .iter()
    .enumerate()
    {
        let id = i as u32 + 10;
        st.push(Structure {
            id,
            team: 0,
            kind: (*kind).into(),
            name: kind.to_string(),
            position: Vector3::X * i as f32,
            supply: 12.75,
            zone_center: Some(Vector3::Z),
            queue: vec![Production {
                item: "rifle_squad".into(),
                remaining: 2.0,
                total: 4.0,
                owner: 0,
                cost: 5,
            }],
            ..Default::default()
        });
    }
    let a = actors(vec![prisoner(), soldier(2, 0, 1.0)], st);
    let mut history = PrisonerIntelligence::default();
    let mut rng = SimulationRandom::new(345);
    let mut facts = std::collections::BTreeMap::new();
    for _ in 0..16 {
        let intel = reveal(
            &mut history,
            &a,
            &mut rng,
            &[23],
            &[(0, 10), (1, 10), (0, 999)],
        );
        assert!(facts.insert(intel.fact.key.clone(), intel.fact).is_none());
    }
    assert_eq!(
        facts["fob10"].text,
        "fob at E5 has 12 supply and 1 men guarding it."
    );
    assert_eq!(facts["mg11"].text, "There's an MG nest east of fob.");
    assert_eq!(
        facts["pq20_rifle_squad"].text,
        "They're making rifle_squad at the barracks east of fob."
    );
    assert_eq!(facts["tn23"].position, Some(Vector3::Z));
    assert_eq!(facts["plan10"].text, "They're planning to hit fob.");
    let next = reveal(&mut history, &a, &mut rng, &[23], &[(0, 10)]);
    assert!(facts.contains_key(&next.fact.key));
}

#[test]
fn checkpoint_resume_produces_the_same_report_and_rng_cursor() {
    let a = actors(
        vec![prisoner()],
        vec![Structure {
            id: 10,
            team: 0,
            kind: "fob".into(),
            name: "North".into(),
            ..Default::default()
        }],
    );
    let mut history = PrisonerIntelligence::default();
    let mut rng = SimulationRandom::new(345);
    reveal(&mut history, &a, &mut rng, &[], &[]);
    let mut resumed = PrisonerIntelligence::restore(&history.checkpoint()).unwrap();
    let mut resumed_rng = rng;
    for _ in 0..16 {
        assert_eq!(
            reveal(&mut history, &a, &mut rng, &[], &[]),
            reveal(&mut resumed, &a, &mut resumed_rng, &[], &[])
        );
        assert_eq!(history.checkpoint(), resumed.checkpoint());
        assert_eq!(rng.state(), resumed_rng.state());
    }
    let valid = history.checkpoint();
    for n in 0..valid.len() {
        assert!(PrisonerIntelligence::restore(&valid[..n]).is_err());
    }
    let mut invalid = valid.clone();
    invalid[6] = 0;
    assert!(PrisonerIntelligence::restore(&invalid).is_err());
    let mut invalid = valid;
    invalid.push(0);
    assert!(PrisonerIntelligence::restore(&invalid).is_err());
}
