use frontline_core::actors::{Actor, Actors};
use frontline_core::infantry::{Credit, Infantry};
use frontline_core::infantry_controller::Task;
use frontline_core::infantry_effects::Damage;
use frontline_core::infantry_vitals::{DamageResult, Life};
use frontline_core::random::SimulationRandom;
use frontline_core::spatial::{SpatialIndex, UNIT_CELL};
use frontline_core::squad::Squad;
use frontline_core::structure::Structure;
use frontline_core::vector::Vector3;

fn soldier(id: u32, team: i8) -> Infantry {
    let mut s = Infantry::default();
    s.identity.id = id;
    s.identity.team = team;
    s.identity.squad = 9 + (team == 1) as u32;
    s.identity.unit = "rifleman".into();
    s.identity.weapon = "rifle".into();
    s.weapon.magazine = 20;
    s.weapon.reserve = 100;
    s
}
fn squads() -> [Squad; 2] {
    [
        Squad {
            id: 9,
            members: vec![1, 2, 3],
            leader: 1,
            morale: 75.0,
            ..Default::default()
        },
        Squad {
            id: 10,
            team: 1,
            members: vec![4],
            morale: 80.0,
            ..Default::default()
        },
    ]
}
fn actors(s: Infantry) -> Actors {
    Actors::from_entries(
        100,
        vec![
            Actor::Soldier(Box::new(s)),
            Actor::Soldier(Box::new(soldier(2, 0))),
            Actor::Soldier(Box::new(soldier(3, 0))),
            Actor::Soldier(Box::new(soldier(4, 1))),
        ],
    )
    .unwrap()
}
fn hit(amount: f64) -> Damage<'static> {
    Damage {
        amount,
        source: 4,
        direction: Vector3::X,
        kind: "bullet",
        now: 10.0,
        ammunition: Some(120),
        bearer: false,
        blame: None,
    }
}

#[test]
fn lethal_hits_credit_the_attacker_release_claims_and_change_both_squads() {
    let mut found_down = false;
    let mut found_dead = false;
    for seed in 0..128 {
        let mut s = soldier(1, 0);
        s.duty.kind = Task::Breach;
        s.orders.pending_path = true;
        s.vitals.speech_cooldown = 5.0;
        let mut a = actors(s);
        let mut qs = squads();
        qs[0].breach_by = 1;
        let r = a
            .damage_infantry(1, hit(105.0), &mut qs, &mut SimulationRandom::new(seed))
            .unwrap();
        let s = a.soldier(1).unwrap();
        assert_eq!(s.identity.hit_by.as_ref().unwrap().soldier, 4);
        assert_eq!(r.damage_credited, 100.0);
        assert_eq!(qs[1].morale, 83.0);
        assert_eq!(qs[0].breach_by, 0);
        assert_eq!(qs[0].known[0].id, 4);
        assert_eq!(s.duty.kind, Task::Fight);
        assert!(!s.is_moving());
        match r.result {
            DamageResult::Down => {
                found_down = true;
                assert_eq!(qs[0].morale, 62.0);
                assert_eq!(r.casualty_speech.unwrap().soldier, 2);
                assert_eq!(a.soldier(2).unwrap().vitals.speech_cooldown, 2.6);
                assert!(s.hit_kind.is_empty());
            }
            DamageResult::Die => {
                found_dead = true;
                assert_eq!(qs[0].morale, 59.0);
                assert_eq!(r.casualty_speech, None);
                assert_eq!(s.fight.loot, 120);
                assert_eq!(s.hit_kind, "bullet");
            }
            other => panic!("expected casualty, got {other:?}"),
        }
    }
    assert!(found_down && found_dead);
}

#[test]
fn downed_hits_update_credit_without_another_report_or_winning_morale() {
    let mut s = soldier(1, 0);
    s.vitals.life = Life::Downed;
    s.vitals.hp = 0.0;
    s.vitals.bleed = 30.0;
    s.vitals.downed_at = 1.0;
    let mut a = actors(s);
    let mut qs = squads();
    let mut damage = hit(50.0);
    damage.kind = "explosion";
    let r = a
        .damage_infantry(1, damage, &mut qs, &mut SimulationRandom::new(1))
        .unwrap();
    assert_eq!(r.result, DamageResult::Die);
    assert_eq!(r.damage_credited, 0.0);
    assert!(qs[0].known.is_empty());
    assert_eq!(qs[0].morale, 65.0);
    assert_eq!(qs[1].morale, 80.0);
    assert_eq!(
        a.soldier(1)
            .unwrap()
            .identity
            .hit_by
            .as_ref()
            .unwrap()
            .soldier,
        4
    );
}

#[test]
fn missing_sources_use_blast_blame_but_friendly_hits_keep_the_last_enemy_credit() {
    let credit = Credit {
        owner: 7,
        team: 1,
        unit: "v19".into(),
        soldier: 0,
    };
    let mut a = actors(soldier(1, 0));
    let mut qs = squads();
    let mut damage = hit(1.0);
    damage.source = 999;
    damage.blame = Some(&credit);
    let r = a
        .damage_infantry(1, damage, &mut qs, &mut SimulationRandom::new(8))
        .unwrap();
    assert_eq!(r.credited, Some(credit.clone()));
    assert!(qs[0].known.is_empty());
    damage.source = 2;
    let r = a
        .damage_infantry(1, damage, &mut qs, &mut SimulationRandom::new(8))
        .unwrap();
    assert_eq!(r.credited, None);
    assert_eq!(a.soldier(1).unwrap().identity.hit_by, Some(credit));
    assert_eq!(qs[0].known[0].id, 2);
}

#[test]
fn muted_pain_keeps_random_draws_and_casualties_release_other_actors() {
    for seed in 0..128 {
        let mut s = soldier(1, 0);
        s.duty.kind = Task::Rescue;
        s.duty.entity = 2;
        let mut p = soldier(2, 0);
        p.links.dragged_by = 1;
        p.links.rescue_claimed = 1;
        let mut a = Actors::from_entries(
            100,
            vec![
                Actor::Soldier(Box::new(s.clone())),
                Actor::Soldier(Box::new(p.clone())),
            ],
        )
        .unwrap();
        s.vitals.speech_cooldown = 5.0;
        let mut b = Actors::from_entries(
            100,
            vec![Actor::Soldier(Box::new(s)), Actor::Soldier(Box::new(p))],
        )
        .unwrap();
        let mut ra = SimulationRandom::new(seed);
        let mut rb = ra;
        a.damage_infantry(1, hit(1.0), &mut [], &mut ra).unwrap();
        let muted = b.damage_infantry(1, hit(1.0), &mut [], &mut rb).unwrap();
        assert_eq!(muted.speech, None);
        assert_eq!(ra.state(), rb.state());
        b.damage_infantry(1, hit(500.0), &mut [], &mut rb).unwrap();
        assert_eq!(b.soldier(2).unwrap().links.dragged_by, 0);
        assert_eq!(b.soldier(2).unwrap().links.rescue_claimed, 0);
    }
}

#[test]
fn suppression_uses_owned_mounts_trenches_and_retreat_and_reports_once_per_deadline() {
    for present in [false, true] {
        let mut s = soldier(1, 0);
        s.emplacement.structure = if present { 100 } else { 5 };
        s.motion.ground = -1.0;
        s.duty.kind = Task::Retreat;
        let mut a = actors(s);
        a.spawn(Actor::Structure(Box::new(Structure {
            kind: "hmg_nest".into(),
            ..Default::default()
        })))
        .unwrap();
        let mut a = Actors::restore(&a.checkpoint().unwrap()).unwrap();
        let mut q = squads()[0].clone();
        let mut rng = SimulationRandom::new(0);
        a.suppress_infantry(1, 40.0, Vector3::Z, 10.0, Some(&mut q), &mut rng)
            .unwrap();
        assert_eq!(
            a.soldier(1).unwrap().vitals.suppression,
            if present { 5.0 } else { 10.0 }
        );
        assert_eq!(q.heard.len(), 1);
        a.suppress_infantry(1, 40.0, Vector3::Z, 11.0, Some(&mut q), &mut rng)
            .unwrap();
        assert_eq!(q.heard.len(), 1);
        a.suppress_infantry(1, 40.0, Vector3::Z, 11.001, Some(&mut q), &mut rng)
            .unwrap();
        assert_eq!(q.heard.len(), 2);
    }
}

#[test]
fn bullet_suppression_ignores_friends_dead_targets_and_the_man_hit() {
    let mut s = soldier(1, 0);
    s.motion.position = Vector3::ZERO;
    let mut dead = soldier(3, 0);
    dead.vitals.life = Life::Dead;
    let mut a = Actors::from_entries(
        100,
        vec![
            Actor::Soldier(Box::new(s)),
            Actor::Soldier(Box::new(soldier(2, 0))),
            Actor::Soldier(Box::new(dead)),
            Actor::Soldier(Box::new(soldier(4, 1))),
        ],
    )
    .unwrap();
    let mut index = SpatialIndex::new(UNIT_CELL).unwrap();
    a.rebuild_units(&mut index).unwrap();
    let mut qs = squads();
    a.suppress_bullet(
        Vector3::new(-10.0, 1.0, 0.0),
        Vector3::new(10.0, 1.0, 0.0),
        1,
        30.0,
        2,
        10.0,
        &index,
        &mut qs,
        &mut SimulationRandom::new(0),
    )
    .unwrap();
    assert_eq!(a.soldier(1).unwrap().vitals.suppression, 30.0);
    for id in 2..=4 {
        assert_eq!(a.soldier(id).unwrap().vitals.suppression, 0.0);
    }
}

#[test]
fn invalid_hits_do_not_change_any_actor_squad_or_random_state() {
    let mut s = soldier(1, 0);
    s.orders.path_revision = i64::MAX as u64;
    let mut a = actors(s);
    let mut qs = squads();
    let before = a.checkpoint().unwrap();
    let old_squads = qs.clone();
    let mut rng = SimulationRandom::new(1);
    let cursor = rng.state();
    assert!(a.damage_infantry(1, hit(500.0), &mut qs, &mut rng).is_err());
    assert_eq!(a.checkpoint().unwrap(), before);
    assert_eq!(qs, old_squads);
    assert_eq!(rng.state(), cursor);
    let mut damage = hit(1.0);
    damage.amount = f64::NAN;
    assert!(a.damage_infantry(1, damage, &mut qs, &mut rng).is_err());
    assert_eq!(a.checkpoint().unwrap(), before);
}
