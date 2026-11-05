#[path = "fixtures/squad_brain_world.rs"]
#[allow(dead_code)]
mod fixture;
use fixture::{contact, Scene};
use frontline_core::battle_stats::{BattleStats, Unit};
use frontline_core::infantry::Infantry;
use frontline_core::infantry_controller::Task;
use frontline_core::infantry_vitals::Life;
use frontline_core::random::SimulationRandom;
use frontline_core::squad::Squad;
use frontline_core::squad_brain::{Call, Event};
use frontline_core::squad_duties::Role;
use frontline_core::structure::Structure;
use frontline_core::vector::Vector3;

fn role(s: &Infantry) -> Role {
    Role {
        medic: s.identity.id == 6,
        engineer: s.identity.id == 5,
    }
}
#[test]
fn rescue_waits_for_cover_then_claims_the_casualty_and_assigns_an_escort() {
    let mut s = Scene::new(17);
    contact(&mut s, 20.0);
    s.change(1, |m| m.vitals.life = Life::Downed);
    for id in 2..=6 {
        s.change(id, |m| m.fight.smokes = 1);
    }
    let out = s.context().squad_rescue(7, &role).unwrap();
    assert!(out.iter().any(|e| matches!(
        e,
        Event::Speech {
            call: Call::CoverRescue,
            ..
        }
    )));
    assert_eq!(s.actors.soldier(1).unwrap().links.rescue_claimed, 0);
    assert_eq!(s.squads[0].smoked.len(), 1);
    s.now += 0.5;
    let out = s.context().squad_rescue(7, &role).unwrap();
    assert_eq!(s.actors.soldier(1).unwrap().links.rescue_claimed, 6);
    assert_eq!(s.actors.soldier(6).unwrap().duty.kind, Task::Rescue);
    assert!(out.contains(&Event::Stat("rescue")));
    assert!(out.contains(&Event::Stat("escort")));
    s.now += 7.0;
    let out = s.context().squad_rescue(7, &role).unwrap();
    assert!(out.is_empty());
    assert_eq!(s.squads[0].cover_fire_until, s.now + 3.0);
}
#[test]
fn medics_wait_for_quiet_and_treat_the_first_idle_wounded_man() {
    let mut s = Scene::new(23);
    contact(&mut s, 30.0);
    s.change(2, |m| m.vitals.hp = 30.0);
    s.change(3, |m| m.vitals.hp = 20.0);
    s.context().squad_medics(7, &role).unwrap();
    assert_eq!(s.actors.soldier(6).unwrap().duty.kind, Task::Fight);
    s.now += 30.0;
    s.context().squad_medics(7, &role).unwrap();
    let m = s.actors.soldier(6).unwrap();
    assert_eq!(m.duty.kind, Task::Heal);
    assert_eq!(m.duty.entity, 2);
    assert!(m.is_moving());
}
#[test]
fn engineers_ignore_depots_and_busy_workers_then_take_the_nearest_repair() {
    let mut s = Scene::new(29);
    let at = s.actors.soldier(5).unwrap().motion.position;
    s.geometry
        .spawn_structure(
            &mut s.actors,
            Structure {
                kind: "depot".into(),
                position: at + Vector3::X,
                team: 0,
                hp: 50.0,
                max_hp: 100.0,
                ..Default::default()
            },
            None,
        )
        .unwrap();
    let house = s
        .geometry
        .spawn_structure(
            &mut s.actors,
            Structure {
                kind: "hesco".into(),
                position: at + Vector3::Z * 10.0,
                team: 0,
                hp: 50.0,
                max_hp: 100.0,
                ..Default::default()
            },
            None,
        )
        .unwrap();
    s.context().squad_engineers(7, &role).unwrap();
    let m = s.actors.soldier(5).unwrap();
    assert_eq!(m.duty.kind, Task::Build);
    assert_eq!(m.duty.entity, house.into());
    assert_eq!(s.actors.soldier(1).unwrap().duty.kind, Task::Fight);
    let random = s.rng.state();
    s.context().squad_engineers(7, &role).unwrap();
    assert_eq!(s.rng.state(), random);
}
#[test]
fn stragglers_join_the_same_owners_squad_and_update_its_battle_record() {
    let mut s = Scene::new(31);
    s.change(2, |m| m.vitals.life = Life::Dead);
    let mut other = Squad::new(8, 0, 1, "rifle_squad".into()).unwrap();
    for id in 3..=6 {
        s.squads[0].remove_member(id, &mut s.actors).unwrap();
        other.add_member(id, &mut s.actors).unwrap();
    }
    other.leader = 3;
    s.squads.push(other);
    let mut battle = BattleStats::default();
    battle
        .register_unit(Unit {
            key: "s8".into(),
            name: "Test".into(),
            kind: "Rifle squad".into(),
            team: 0,
            owner: 1,
            men: 4,
            ..Default::default()
        })
        .unwrap();
    let out = s.context().squad_straggler_tick(7, &mut battle).unwrap();
    assert!(out.contains(&Event::Stat("straggler_joined")));
    assert_eq!(s.actors.soldier(1).unwrap().identity.squad, 8);
    assert_eq!(s.squads[0].members, vec![2]);
    assert_eq!(s.squads[1].members, vec![3, 4, 5, 6, 1]);
    assert_eq!(battle.units[0].men, 5);
}
#[test]
fn a_straggler_stays_with_a_wounded_squadmate() {
    let mut s = Scene::new(37);
    for id in 2..=6 {
        s.change(id, |m| m.vitals.life = Life::Downed);
    }
    let random = s.rng.state();
    let mut battle = BattleStats::default();
    assert!(s
        .context()
        .squad_straggler_tick(7, &mut battle)
        .unwrap()
        .is_empty());
    assert_eq!(random, s.rng.state());
    assert_eq!(s.squads[0].members.len(), 6);
}
#[test]
fn surrender_releases_the_weapon_route_and_squad_membership() {
    let mut s = Scene::new(41);
    contact(&mut s, 20.0);
    for id in 2..=6 {
        s.change(id, |m| m.vitals.life = Life::Dead);
    }
    s.change(1, |m| {
        m.vitals.suppression = 60.0;
        m.identity.weapon = "rifle".into();
        m.weapon.magazine = 30;
        m.weapon.reserve = 170;
    });
    let seed = (0..1000)
        .find(|&seed| f64::from(SimulationRandom::new(seed).randf()) < 0.035)
        .unwrap();
    s.rng = SimulationRandom::new(seed);
    let out = s.context().squad_surrender(7).unwrap();
    let m = s.actors.soldier(1).unwrap();
    assert_eq!(m.vitals.life, Life::Surrender);
    assert_eq!(m.identity.squad, 0);
    assert!(m.identity.weapon.is_empty());
    assert_eq!((m.weapon.magazine, m.weapon.reserve), (0, 0));
    assert!(!m.is_moving());
    assert!(out.contains(&Event::Stat("surrender")));
}
#[test]
fn final_defense_and_clearing_calls_respect_their_deadlines() {
    let mut s = Scene::new(43);
    s.squads[0].order = "move".into();
    s.squads[0].then_defend = Some([Vector3::new(20.0, 0.0, 10.0), Vector3::NEG_Z]);
    s.context().squad_then_defend_tick(7).unwrap();
    assert_eq!(s.squads[0].order, "defend");
    assert!(s.squads[0].then_defend.is_none());
    s.squads[0].clear_call = Some((1, 101.0));
    assert!(s.context().squad_clear_call_tick(7).unwrap().is_empty());
    s.now = 101.0;
    assert!(s
        .context()
        .squad_clear_call_tick(7)
        .unwrap()
        .contains(&Event::Stat("house_cleared")));
    assert!(s.squads[0].clear_call.is_none());
}
