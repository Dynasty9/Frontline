#[path = "fixtures/squad_brain_world.rs"]
#[allow(dead_code)]
mod fixture;
use fixture::{contact, Scene};
use frontline_core::ambush_plan::AmbushPlan;
use frontline_core::attack_plan::AttackPlan;
use frontline_core::battle_stats::{BattleStats, Unit};
use frontline_core::infantry_vitals::Life;
use frontline_core::infantry_weapon::Weapon;
use frontline_core::squad_brain::Event as Brain;
use frontline_core::squad_duties::Role;
use frontline_core::squad_world::{Event, Profiles, Tick};
use frontline_core::vector::Vector3;
fn profile() -> Profiles<'static> {
    Profiles {
        role: &|m| Role {
            medic: m.identity.id == 6,
            engineer: m.identity.id == 5,
        },
        armor: &|_| 1,
        weapon: &|_| {
            Some(Weapon {
                ammunition: 200,
                magazine: 30,
                reload_time: 2.,
            })
        },
        air: &|_| false,
    }
}
fn advance(
    s: &mut Scene,
    dt: f64,
    battle: &mut BattleStats,
    attacks: &mut [AttackPlan],
    ambushes: &mut [AmbushPlan],
) -> Vec<Event> {
    s.context()
        .squad_tick(
            7,
            dt,
            &mut Tick {
                attacks,
                ambushes,
                battle,
                impacts: &[],
            },
            &profile(),
        )
        .unwrap()
}
#[test]
fn think_deadline_skips_all_decisions_and_invalid_steps_do_not_mutate() {
    let mut s = Scene::new(5);
    s.squads[0].think_timer = 0.5;
    let rng = s.rng.state();
    let actors = s.actors.checkpoint().unwrap();
    let mut battle = BattleStats::default();
    assert!(advance(&mut s, 0.25, &mut battle, &mut [], &mut []).is_empty());
    assert_eq!(s.squads[0].think_timer, 0.25);
    assert_eq!(actors, s.actors.checkpoint().unwrap());
    assert_eq!(rng, s.rng.state());
    let saved = s.squads[0].clone();
    for dt in [-1., f64::NAN, 11.] {
        assert!(s
            .context()
            .squad_tick(
                7,
                dt,
                &mut Tick {
                    attacks: &mut [],
                    ambushes: &mut [],
                    battle: &mut battle,
                    impacts: &[]
                },
                &profile()
            )
            .is_err());
        assert_eq!(saved, s.squads[0]);
    }
}
#[test]
fn wiped_out_squads_release_bodies_and_cancel_plans_before_retirement() {
    let mut s = Scene::new(7);
    let (mut plan, _) = AmbushPlan::make(
        &mut s.context(),
        19,
        7,
        Vector3::ZERO,
        Vector3::Z,
        Vector3::NEG_X,
    )
    .unwrap();
    s.squads[0].plan = 17;
    for id in 1..=6 {
        s.change(id, |m| m.vitals.life = Life::Dead);
    }
    let mut battle = BattleStats::default();
    battle
        .register_unit(Unit {
            key: "s7".into(),
            team: 0,
            owner: 1,
            men: 6,
            alive: 6,
            ..Default::default()
        })
        .unwrap();
    let out = advance(
        &mut s,
        0.5,
        &mut battle,
        &mut [],
        std::slice::from_mut(&mut plan),
    );
    assert_eq!(
        out,
        vec![
            Event::Brain(Brain::Stat("plan_squad_lost")),
            Event::Removed(7)
        ]
    );
    assert!(plan.done);
    assert!(s.squads[0].members.is_empty());
    assert_eq!(battle.units[0].ended, 100.);
    for id in 1..=6 {
        assert_eq!(s.actors.soldier(id).unwrap().identity.squad, 0);
    }
}
#[test]
fn surviving_wounded_keep_the_squad_and_rescue_runs_after_decisions() {
    let mut s = Scene::new(9);
    contact(&mut s, 50.);
    s.change(1, |m| m.vitals.life = Life::Downed);
    let mut battle = BattleStats::default();
    let out = advance(&mut s, 0.5, &mut battle, &mut [], &mut []);
    assert!(!out.contains(&Event::Removed(7)));
    assert!(s.squads[0].morale >= 0.);
    s.now += 0.5;
    advance(&mut s, 0.5, &mut battle, &mut [], &mut []);
    assert_ne!(s.actors.soldier(1).unwrap().links.rescue_claimed, 0);
}
#[test]
fn tactical_regroup_cancels_the_retained_ambush_immediately() {
    let mut s = Scene::new(13);
    let (mut plan, _) = AmbushPlan::make(
        &mut s.context(),
        19,
        7,
        Vector3::ZERO,
        Vector3::Z,
        Vector3::NEG_X,
    )
    .unwrap();
    s.squads[0].morale = 70.;
    let center = s.squads[0].centroid(s.now, &s.actors);
    s.squads[0].then_defend = Some([center, Vector3::X]);
    s.squads[0].technique.clear();
    plan.phase = frontline_core::ambush_plan::Phase::Wait;
    let mut battle = BattleStats::default();
    advance(
        &mut s,
        0.5,
        &mut battle,
        &mut [],
        std::slice::from_mut(&mut plan),
    );
    assert!(plan.done);
    assert_eq!(s.squads[0].ambush_plan, 0);
    assert_eq!(s.squads[0].order, "defend");
}
