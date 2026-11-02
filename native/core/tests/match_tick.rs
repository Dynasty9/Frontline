#[path = "fixtures/match_tick.rs"]
#[allow(dead_code)]
mod fixture;
use fixture::shared::shared::{actor, soldier, structure};
use frontline_core::actors::Actor;
use frontline_core::entities::Kind;
use frontline_core::infantry::Goal;
use frontline_core::infantry_action::{Action, Round, Throw};
use frontline_core::infantry_control::HiddenReason;
use frontline_core::infantry_vitals::Life;
use frontline_core::match_state::{MatchState, FIXED_DELTA};
use frontline_core::match_tick::Event;
use frontline_core::perception::PerceptionSearch;
use frontline_core::projectile_actor::Motion;
use frontline_core::structure::Production;
use frontline_core::vector::Vector3;

fn order(item: &str) -> Production {
    Production {
        item: item.into(),
        remaining: 0.001,
        total: 10.,
        owner: 7,
        cost: 100,
    }
}
fn smoke_man() -> Actor {
    let mut man = soldier(1, -8., Life::Alive);
    man.action.remaining = 0.001;
    man.action.current = Action::Throw(Throw {
        position: Vector3::new(8., 0., 0.),
        round: Round::Smoke,
        fuse: 1.8,
    });
    Actor::Soldier(Box::new(man))
}
#[test]
fn infantry_rounds_advance_now_but_late_support_rounds_wait_until_next_tick() {
    fixture::with_profiles(|p| {
        let mut s = fixture::state(vec![smoke_man()]);
        s.rules
            .support
            .queue
            .push(frontline_core::support_calls::Salvo {
                at: s.field.now,
                kind: frontline_core::projectile::Kind::Mortar,
                team: 0,
                position: Vector3::new(12., 0., 12.),
                radius: 0.,
                back: Vector3::Z * 380.,
                called_by: 7,
            });
        let mut search = PerceptionSearch::default();
        s.advance_battlefield(p, &mut search).unwrap();
        let rounds: Vec<_> = s.field.actors.iter_kind(Kind::Projectile).collect();
        assert_eq!(rounds.len(), 2);
        for a in rounds {
            let Actor::Projectile(a) = a else { panic!() };
            let Motion::Ballistic(f) = &a.motion else {
                panic!()
            };
            if f.kind == frontline_core::projectile::Kind::Smoke {
                assert_eq!(f.life, FIXED_DELTA);
            } else {
                assert_eq!(f.life, 0.);
            }
        }
        s.finish_battlefield(p).unwrap();
        s.advance_battlefield(p, &mut search).unwrap();
        for a in s.field.actors.iter_kind(Kind::Projectile) {
            let Actor::Projectile(a) = a else { panic!() };
            let Motion::Ballistic(f) = &a.motion else {
                panic!()
            };
            assert!(f.life >= FIXED_DELTA);
        }
    });
}
#[test]
fn recruits_wait_for_the_next_infantry_pass_but_new_vehicles_update_immediately() {
    fixture::with_profiles(|p| {
        let mut lab = structure(30, "research", -12.);
        lab.queue.push(order("armor"));
        let mut barracks = structure(31, "barracks", -6.);
        barracks.queue.push(order("rifle_squad"));
        let mut factory = structure(32, "factory", 8.);
        factory.queue.push(order("tank"));
        let mut s = fixture::state(vec![actor(lab), actor(barracks), actor(factory)]);
        let events = s
            .advance_battlefield(p, &mut PerceptionSearch::default())
            .unwrap();
        let recruit = s.field.actors.soldier(1000).unwrap();
        assert_eq!(recruit.vitals.max_hp, 108.);
        assert_eq!(recruit.controller.activity_timer, 0.0);
        let v = s.field.actors.vehicle(1001).unwrap();
        assert_eq!(v.mg_timer, -FIXED_DELTA);
        assert!(events.iter().any(|e| matches!(
            e,
            Event::Building(frontline_core::structures_tick::Event::Production(
                frontline_core::structure_production::Event::Research { .. }
            ))
        )));
        s.finish_battlefield(p).unwrap();
        s.advance_battlefield(p, &mut PerceptionSearch::default())
            .unwrap();
        assert!(
            s.field
                .actors
                .soldier(1000)
                .unwrap()
                .controller
                .activity_timer
                > 0.
        );
    });
}
#[test]
fn queued_empty_prison_route_finishes_custody_before_the_soldier_tick() {
    fixture::with_profiles(|p| {
        let mut prisoner = soldier(1, 8., Life::Captive);
        prisoner.links.prison_destination = 30;
        let route = prisoner
            .go_to(prisoner.motion.position, Goal::Prison, 0)
            .unwrap();
        let mut s = fixture::state(vec![
            Actor::Soldier(Box::new(prisoner)),
            actor(structure(30, "depot", 8.)),
        ]);
        assert!(s.field.geometry.navigation.planner.request(route.job));
        s.advance_battlefield(p, &mut PerceptionSearch::default())
            .unwrap();
        let prisoner = s.field.actors.soldier(1).unwrap();
        assert_eq!(prisoner.vitals.life, Life::Hidden);
        assert_eq!(prisoner.control.hidden, HiddenReason::Held);
        assert!(prisoner.control.hidden_timer > 0.);
        assert!(!prisoner.orders.pending_path);
    });
}
#[test]
fn mixed_battlefield_resumes_with_identical_events_and_state() {
    fixture::with_profiles(|p| {
        let mut enemy = soldier(2, 12., Life::Alive);
        enemy.identity.team = 1;
        let mut barracks = structure(30, "barracks", -9.);
        barracks.queue.push(order("rifle_squad"));
        let mut v = fixture::ground::vehicle(20, 0, 6.);
        v.target = 2;
        let mut a = fixture::state(vec![
            smoke_man(),
            Actor::Soldier(Box::new(enemy)),
            actor(barracks),
            Actor::Vehicle(Box::new(v)),
        ]);
        let mut b = MatchState::restore(&a.checkpoint().unwrap()).unwrap();
        let mut ac = PerceptionSearch::default();
        let mut bc = PerceptionSearch::default();
        for tick in 0..180 {
            assert_eq!(
                a.advance_battlefield(p, &mut ac).unwrap(),
                b.advance_battlefield(p, &mut bc).unwrap(),
                "tick {tick}"
            );
            assert_eq!(
                a.finish_battlefield(p).unwrap(),
                b.finish_battlefield(p).unwrap()
            );
            let state = a.checkpoint().unwrap();
            assert_eq!(state, b.checkpoint().unwrap(), "tick {tick}");
            if tick % 11 == 0 {
                b = MatchState::restore(&state).unwrap();
                bc = PerceptionSearch::default();
            }
        }
        assert_eq!(a.tick, 6180);
        assert!(a.field.actors.entities().next_id() > 1001);
    });
}
#[test]
fn exhausted_clock_rejects_a_tick_without_mutation() {
    fixture::with_profiles(|p| {
        let mut s = fixture::state(vec![]);
        s.tick = i64::MAX as u64;
        let before = s.checkpoint().unwrap();
        assert!(s
            .advance_battlefield(p, &mut PerceptionSearch::default())
            .is_err());
        assert_eq!(s.checkpoint().unwrap(), before);
    });
}

#[test]
fn rounds_fired_by_vehicles_start_flying_on_the_next_tick() {
    fixture::with_profiles(|p| {
        let mut v = fixture::ground::vehicle(20, 0, 0.);
        v.kind = "arty".into();
        v.yaw = 0.;
        v.turret_yaw = 0.;
        v.scan_timer = 10.;
        v.salvo = 1;
        v.salvo_at = Some(Vector3::new(0., 0., -12.));
        v.salvo_timer = 0.;
        let mut s = fixture::state(vec![Actor::Vehicle(Box::new(v))]);
        let mut search = PerceptionSearch::default();
        for tick in 0..2 {
            s.advance_battlefield(p, &mut search).unwrap();
            let rounds: Vec<_> = s.field.actors.iter_kind(Kind::Projectile).collect();
            assert_eq!(rounds.len(), 1);
            let Actor::Projectile(round) = rounds[0] else {
                panic!()
            };
            let Motion::Ballistic(flight) = &round.motion else {
                panic!()
            };
            assert_eq!(flight.life, tick as f64 * FIXED_DELTA);
            s.finish_battlefield(p).unwrap();
        }
    });
}

#[test]
fn encoded_player_order_drives_the_same_restored_battlefield() {
    use frontline_core::match_commands::{Action as Order, Command};
    use frontline_core::squad::Squad;
    fixture::with_profiles(|p| {
        fixture::with_commands(|commands| {
            let mut soldier = soldier(1, -8., Life::Alive);
            soldier.identity.owner = 7;
            soldier.identity.squad = 1;
            let mut s = fixture::state(vec![Actor::Soldier(Box::new(soldier))]);
            let mut squad = Squad::new(1, 0, 7, "rifle_squad".into()).unwrap();
            squad.members = vec![1];
            s.field.squads.push(squad);
            s.owners.connect(7, 0).unwrap();
            let bytes = Command {
                squads: vec![1],
                vehicles: vec![],
                action: Order::Move {
                    position: Vector3::new(8., 0., 0.),
                    face: Vector3::NEG_Z,
                    mode: 0,
                },
            }
            .encode()
            .unwrap();
            let order = Command::decode(&bytes).unwrap();
            let mut resumed = MatchState::restore(&s.checkpoint().unwrap()).unwrap();
            assert_eq!(
                s.execute(7, "Commander", 7, &order, &p.shared, commands)
                    .unwrap(),
                resumed
                    .execute(7, "Commander", 7, &order, &p.shared, commands)
                    .unwrap()
            );
            for _ in 0..120 {
                assert_eq!(
                    s.advance_battlefield(p, &mut PerceptionSearch::default())
                        .unwrap(),
                    resumed
                        .advance_battlefield(p, &mut PerceptionSearch::default())
                        .unwrap()
                );
                assert_eq!(
                    s.finish_battlefield(p).unwrap(),
                    resumed.finish_battlefield(p).unwrap()
                );
            }
            assert_eq!(s.checkpoint().unwrap(), resumed.checkpoint().unwrap());
            assert!(s.field.actors.soldier(1).unwrap().motion.position.x > -5.);
        })
    });
}
