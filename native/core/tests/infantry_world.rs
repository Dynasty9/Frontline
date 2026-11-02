#[allow(dead_code)]
#[path = "fixtures/infantry_world.rs"]
mod fixture;
use fixture::{soldiers, Field};
use frontline_core::infantry_action::{Action, Round, Throw};
use frontline_core::infantry_control::HiddenReason;
use frontline_core::infantry_controller::Task;
use frontline_core::infantry_fight_world::Event as Combat;
use frontline_core::infantry_vitals::Life;
use frontline_core::infantry_world::Event;
use frontline_core::world_combat;

#[test]
fn a_removed_crossing_recovers_living_infantry_and_wading_cancels_a_dive() {
    use frontline_core::{
        infantry_pose::Posture,
        terrain::{BASE, SHALLOW},
        traversal::Ground,
    };
    for deep in [false, true] {
        let (mut man, enemy) = soldiers();
        man.controller.dive_timer = 0.8;
        man.posture = Posture::Prone;
        man.shock.flinch_timer = 2.0;
        let start = man.motion.position;
        let mut field = Field::new(man, enemy);
        let geometry = &mut field.scene.world.geometry;
        let cell = geometry.terrain.index(start);
        geometry.terrain.layers[BASE][cell] = SHALLOW;
        geometry
            .terrain
            .heights
            .fill(if deep { -2.0 } else { -0.8 });
        let mut resumed = field.resume();
        assert_eq!(field.step(0.05).unwrap(), resumed.step(0.05).unwrap());
        field.compare(&resumed);
        let s = field.scene.world.actors.soldier(1).unwrap();
        let g = Ground::new(
            &field.scene.world.geometry.terrain,
            &field.scene.world.geometry.deck,
        );
        assert!(!g.too_deep(s.motion.position));
        if deep {
            assert_ne!(s.motion.position, start);
        } else {
            assert_eq!(s.controller.dive_timer, 0.0);
            assert_eq!(s.posture, Posture::Stand);
        }
    }
}

#[test]
fn a_complete_fight_resumes_decisions_bullets_and_status_exactly() {
    let (man, enemy) = soldiers();
    let mut field = Field::new(man, enemy);
    let mut shot = false;
    for _ in 0..40 {
        let mut resumed = field.resume();
        let events = field.step(0.1).unwrap();
        assert_eq!(events, resumed.step(0.1).unwrap());
        field.compare(&resumed);
        shot |= field.scene.world.battle.sides[0][frontline_core::battle_stats::SHOTS] > 0.0;
        field.scene.world.now += 0.1;
    }
    assert!(shot);
}
#[test]
fn recovery_precedes_an_action_and_the_new_action_keeps_its_delay() {
    let (mut man, enemy) = soldiers();
    man.vitals.suppression = 70.0;
    man.action.current = Action::Cook;
    man.action.remaining = 0.05;
    man.action.queued_throw = Some(Throw {
        position: enemy.motion.position,
        round: Round::Frag,
        fuse: 1.8,
    });
    let mut field = Field::new(man, enemy);
    let events = field.step(0.1).unwrap();
    let s = field.scene.world.actors.soldier(1).unwrap();
    assert!(s.vitals.suppression < 70.0);
    assert_eq!(s.action.remaining, 0.6);
    assert!(events
        .iter()
        .any(|e| matches!(e, Event::Combat(Combat::Speech { id: 1, .. }))));
    assert_eq!(field.scene.world.actors.entities().len(), 2);
}
#[test]
fn treatment_updates_the_patient_and_ledger_in_the_same_tick() {
    let (mut medic, mut patient) = soldiers();
    medic.controller.think_timer = 1.0;
    medic.duty.kind = Task::Rescue;
    medic.duty.entity = 2;
    medic.duty.phase = 2;
    medic.duty.timer = 0.05;
    patient.vitals.life = Life::Downed;
    patient.vitals.hp = 0.0;
    patient.identity.team = 0;
    patient.links.rescue_claimed = 1;
    patient.motion.position.x = 1.0;
    let mut field = Field::new(medic, patient);
    let events = field.step(0.1).unwrap();
    assert_eq!(
        field.scene.world.actors.soldier(2).unwrap().vitals.life,
        Life::Alive
    );
    assert_eq!(field.scene.world.battle.sides[0][23], 1.0);
    assert!(
        events.contains(&Event::Combat(Combat::World(world_combat::Event::Stat(
            "patched_up"
        ))))
    );
    assert_eq!(
        field.scene.world.actors.soldier(1).unwrap().duty.kind,
        Task::Fight
    );
}
#[test]
fn a_tent_discharge_restores_a_magazine_and_records_the_revival() {
    let (mut man, enemy) = soldiers();
    man.vitals.life = Life::Hidden;
    man.control.hidden = HiddenReason::Tent;
    man.control.hidden_timer = 0.05;
    man.identity.weapon.clear();
    let mut field = Field::new(man, enemy);
    field.step(0.1).unwrap();
    let s = field.scene.world.actors.soldier(1).unwrap();
    assert_eq!(s.vitals.life, Life::Alive);
    assert_eq!(s.weapon.magazine, 30);
    assert_eq!(s.duty.kind, Task::Limp);
    assert_eq!(field.scene.world.battle.sides[0][23], 1.0);
}
#[test]
fn each_lifecycle_and_missing_duty_target_can_finish_a_tick() {
    for life in [
        Life::Downed,
        Life::Dead,
        Life::Surrender,
        Life::Captive,
        Life::Hidden,
    ] {
        let (mut man, enemy) = soldiers();
        man.vitals.life = life;
        Field::new(man, enemy).step(0.1).unwrap();
    }
    for task in [
        Task::Rescue,
        Task::Escort,
        Task::Heal,
        Task::Build,
        Task::Stretcher,
        Task::Limp,
        Task::Captor,
        Task::Man,
        Task::Tunnel,
        Task::Board,
        Task::Resupply,
        Task::GrenadePickup,
        Task::Smother,
        Task::GrenadeKick,
        Task::Breach,
        Task::Retreat,
        Task::Throw,
        Task::Pilot,
        Task::Unknown,
    ] {
        let (mut man, enemy) = soldiers();
        man.duty.kind = task;
        man.controller.think_timer = 1.0;
        Field::new(man, enemy)
            .step(0.1)
            .unwrap_or_else(|e| panic!("{task:?}: {e}"));
    }
}
#[test]
fn invalid_time_does_not_recover_or_advance_any_soldier_state() {
    let (man, enemy) = soldiers();
    let mut field = Field::new(man, enemy);
    let before = field.resume();
    assert!(field.step(f64::NAN).is_err());
    field.compare(&before);
}
