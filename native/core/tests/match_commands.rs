#[path = "fixtures/match_commands.rs"]
mod fixture;
use fixture::*;
use frontline_core::actors::Actor;
use frontline_core::infantry_control::HiddenReason;
use frontline_core::infantry_controller::Task;
use frontline_core::infantry_vitals::Life;
use frontline_core::match_commands::{Action, Audience, Command, Event, Placement, UnitOrder};
use frontline_core::vector::Vector3;

#[test]
fn allied_control_keeps_human_credit_deduplicates_and_excludes_enemy_and_automatic_vehicles() {
    let mut s = scene();
    s.world.world.squads[0].owner = -1;
    let mut c = command(Action::Move {
        position: Vector3::new(-10., 0., 0.),
        face: Vector3::NEG_Z,
        mode: 0,
    });
    c.squads = vec![7, 7, 999];
    c.vehicles = vec![TANK, ALLY, ENEMY, ROBOT, TANK];
    s.execute(7, &c).unwrap();
    assert_eq!(s.world.world.squads[0].owner, 7);
    assert_eq!(s.world.world.squads[0].order_number, 1);
    assert_eq!(s.world.world.actors.vehicle(TANK).unwrap().owner, 7);
    assert_eq!(s.world.world.actors.vehicle(ALLY).unwrap().owner, 8);
    assert_eq!(
        s.world.world.actors.vehicle(ENEMY).unwrap().path_revision,
        0
    );
    assert_eq!(
        s.world.world.actors.vehicle(ROBOT).unwrap().path_revision,
        0
    );
    assert_eq!(
        s.world.world.actors.vehicle(TANK).unwrap().path_destination,
        Some(Vector3::new(-14.5, 0., 6.))
    );
    assert_eq!(
        s.world.world.actors.vehicle(ALLY).unwrap().path_destination,
        Some(Vector3::new(-5.5, 0., 6.))
    );
}
#[test]
fn routing_refuses_squad_orders_but_allows_individual_orders_and_retreat() {
    let mut s = scene();
    s.world.world.squads[0].drill = "rout".into();
    let events = s.execute(7, &command(Action::Stop)).unwrap();
    assert_eq!(s.world.world.squads[0].order_number, 0);
    assert!(events.iter().any(|e|matches!(e,Event::Message {audience:Audience::Peer(7),text,..} if text.contains("routing"))));
    s.execute(
        7,
        &command(Action::Unit {
            soldier: 1,
            order: UnitOrder::Stop,
        }),
    )
    .unwrap();
    assert!(s.world.world.actors.soldier(1).unwrap().orders.detached);
    assert_eq!(s.world.world.squads[0].order_number, 0);
    s.execute(7, &command(Action::Retreat)).unwrap();
    assert_eq!(s.world.world.squads[0].order_number, 1);
}
#[test]
fn invalid_packets_and_observers_cannot_change_gameplay_state() {
    let mut s = scene();
    let before = s.state();
    let bad = command(Action::Move {
        position: Vector3::NAN,
        face: Vector3::ZERO,
        mode: 0,
    });
    assert!(s.execute(7, &bad).is_err());
    assert_eq!(s.state(), before);
    assert!(s.execute(10, &command(Action::Stop)).unwrap().is_empty());
    assert_eq!(s.state(), before);
    s.winner = 0;
    assert!(s.execute(7, &command(Action::Stop)).unwrap().is_empty());
    assert_eq!(s.state(), before);
}
#[test]
fn friendly_attack_does_not_claim_units_and_individual_ai_orders_take_the_whole_squad() {
    let mut s = scene();
    s.world.world.squads[0].owner = -1;
    s.execute(7, &command(Action::Attack(ALLY))).unwrap();
    assert_eq!(s.world.world.squads[0].owner, -1);
    s.execute(
        7,
        &command(Action::Unit {
            soldier: 1,
            order: UnitOrder::Attack(ENEMY),
        }),
    )
    .unwrap();
    assert_eq!(s.world.world.squads[0].owner, 7);
    for id in 1..=6 {
        assert_eq!(s.world.world.actors.soldier(id).unwrap().identity.owner, 7);
    }
}
#[test]
fn mortar_and_artillery_orders_preserve_range_caps_and_immediate_readiness() {
    let mut s = scene();
    s.change(MORTAR, |a| {
        if let Actor::Structure(st) = a {
            st.gunner = 1;
        }
    });
    s.change(1, |a| {
        if let Actor::Soldier(m) = a {
            m.duty.kind = Task::Man;
        }
    });
    let c = command(Action::FireMission {
        building: MORTAR,
        position: Vector3::new(0., 0., -30.),
        smoke: true,
    });
    for _ in 0..4 {
        s.execute(7, &c).unwrap();
    }
    assert_eq!(
        s.world
            .world
            .actors
            .structure(MORTAR)
            .unwrap()
            .fire_queue
            .len(),
        6
    );
    assert!(s
        .world
        .world
        .actors
        .structure(MORTAR)
        .unwrap()
        .fire_queue
        .iter()
        .all(|p| p.1));
    assert_eq!(s.world.world.squads[0].fire_queue.len(), 4);
    assert_eq!(
        s.world.world.actors.vehicle(TANK).unwrap().fire_queue.len(),
        0
    ); // Too close to the gun.
    let c = command(Action::FireMission {
        building: MORTAR,
        position: Vector3::new(50., 0., -30.),
        smoke: false,
    });
    for _ in 0..4 {
        s.execute(7, &c).unwrap();
    }
    assert_eq!(
        s.world.world.actors.vehicle(TANK).unwrap().fire_queue.len(),
        3
    );
}
#[test]
fn tunnel_orders_keep_membership_and_draw_travel_then_scatter_in_entry_order() {
    let mut s = scene();
    s.change(TUNNEL, |a| {
        if let Actor::Structure(st) = a {
            st.inside = vec![2, 1];
        }
    });
    for id in [1, 2] {
        s.change(id, |a| {
            if let Actor::Soldier(m) = a {
                m.vitals.life = Life::Hidden;
                m.links.hidden_in = TUNNEL.into();
                m.control.hidden = HiddenReason::TunnelWait;
            }
        });
    }
    let mut expected = s.world.world.rng;
    let mut values = vec![];
    for id in [2, 1] {
        values.push((
            id,
            3. + 20. / 14. + f64::from(expected.randf()) * 1.5,
            Vector3::new(40., 0., 30.)
                + Vector3::new(
                    expected.randf_range(-3., 3.),
                    0.,
                    expected.randf_range(-3., 3.),
                ),
        ));
    }
    s.execute(
        7,
        &command(Action::TunnelExit {
            building: TUNNEL,
            exit: EXIT,
        }),
    )
    .unwrap();
    assert_eq!(s.world.world.rng, expected);
    assert_eq!(
        s.world.world.actors.structure(TUNNEL).unwrap().inside,
        vec![2, 1]
    );
    for (id, time, at) in values {
        let m = s.world.world.actors.soldier(id).unwrap();
        assert_eq!(m.links.hidden_in, TUNNEL.into());
        assert_eq!(m.control.hidden, HiddenReason::TunnelTravel);
        assert_eq!(m.control.hidden_timer, time);
        assert_eq!(m.duty.position, at);
    }
}
#[test]
fn production_and_cancel_use_shared_stock_and_the_original_buyer() {
    let mut s = scene();
    let supply = s.world.world.actors.structure(FOB).unwrap().supply;
    s.execute(
        7,
        &command(Action::Produce {
            building: BARRACKS,
            item: "rifle_squad".into(),
            research: false,
        }),
    )
    .unwrap();
    assert_eq!(
        s.world.world.actors.structure(FOB).unwrap().supply,
        supply - 100.
    );
    assert_eq!(
        s.world.world.actors.structure(BARRACKS).unwrap().queue[0].owner,
        7
    );
    s.execute(8, &command(Action::Cancel(BARRACKS))).unwrap();
    assert!(s
        .world
        .world
        .actors
        .structure(BARRACKS)
        .unwrap()
        .queue
        .is_empty());
    assert_eq!(s.world.world.actors.structure(FOB).unwrap().supply, supply);
}
#[test]
fn multi_build_assigns_only_the_first_successful_segment_and_charges_each() {
    let mut s = scene();
    let supply = s.world.world.actors.structure(FOB).unwrap().supply;
    let c = command(Action::BuildMany {
        kind: "sandbags".into(),
        items: vec![
            Placement {
                position: Vector3::new(-40., 0., 40.),
                yaw: 0.,
                length: None,
            },
            Placement {
                position: Vector3::new(-30., 0., 20.),
                yaw: 0.,
                length: Some(99.),
            },
            Placement {
                position: Vector3::new(-15., 0., 20.),
                yaw: 0.,
                length: Some(0.5),
            },
        ],
    });
    let events = s.execute(7, &c).unwrap();
    let placed: Vec<_> = events
        .iter()
        .filter_map(|e| {
            if let Event::Placement(frontline_core::placement_world::Event::Placed { id, .. }) = e {
                Some(*id)
            } else {
                None
            }
        })
        .collect();
    assert_eq!(placed.len(), 2);
    assert_eq!(s.world.world.squads[0].build_target, placed[0]);
    assert_eq!(
        s.world.world.actors.structure(placed[0]).unwrap().size.x,
        8.
    );
    assert_eq!(
        s.world.world.actors.structure(placed[1]).unwrap().size.x,
        1.5
    );
    assert_eq!(
        s.world.world.actors.structure(FOB).unwrap().supply,
        supply - 200.
    );
}
#[test]
fn support_is_paid_once_and_observer_demo_is_restricted_to_host_or_ai_only_matches() {
    let mut s = scene();
    let support = command(Action::Support {
        kind: "mortars".into(),
        position: Vector3::ZERO,
        direction: Vector3::X,
    });
    let supply = s.world.world.actors.structure(FOB).unwrap().supply;
    s.execute(7, &support).unwrap();
    s.execute(7, &support).unwrap();
    assert_eq!(
        s.world.world.actors.structure(FOB).unwrap().supply,
        supply - 100.
    );
    s.owners.connect(11, -1).unwrap();
    let demo = command(Action::DemoSupport {
        kind: "mortars".into(),
        position: Vector3::ZERO,
        direction: Vector3::X,
    });
    let before = s.state();
    assert!(s.execute(11, &demo).unwrap().is_empty());
    assert_eq!(s.state(), before);
    assert!(!s.execute(10, &demo).unwrap().is_empty());
}
#[test]
fn chat_truncates_characters_and_preserves_team_privacy() {
    let mut s = scene();
    let events = s
        .execute(
            7,
            &command(Action::Chat {
                text: format!("  {}  ", "é".repeat(220)),
                team_only: true,
            }),
        )
        .unwrap();
    assert!(events.iter().any(|e|matches!(e,Event::Message {audience:Audience::Team(0),text,..} if text==&format!("[TEAM] Commander: {}","é".repeat(200)))));
}
#[test]
fn mixed_commands_continue_exactly_after_restoring_every_mutable_component() {
    let mut s = scene();
    let actions = [
        Action::Move {
            position: Vector3::new(-10., 0., 4.),
            face: Vector3::ZERO,
            mode: 0,
        },
        Action::Attack(ENEMY),
        Action::Defend {
            position: Vector3::new(-5., 0., 8.),
            face: Vector3::X,
        },
        Action::Stop,
        Action::Assault {
            position: Vector3::new(40., 0., -5.),
            face: Vector3::X,
        },
        Action::Retreat,
        Action::Rally {
            building: BARRACKS,
            position: Vector3::new(-15., 0., 4.),
        },
        Action::Produce {
            building: RESEARCH,
            item: "deep_tunnels".into(),
            research: true,
        },
        Action::Cancel(RESEARCH),
    ];
    for action in actions {
        let mut copy = s.resume();
        let c = Command::decode(&command(action).encode().unwrap()).unwrap();
        assert_eq!(s.execute(7, &c).unwrap(), copy.execute(7, &c).unwrap());
        assert_eq!(s.state(), copy.state());
    }
}

#[test]
fn a_combined_assault_uses_one_shared_plan_and_keeps_order_selection_spacing() {
    let mut s = scene();
    let mut q = frontline_core::squad::Squad::new(8, 0, 7, "rifle_squad".into()).unwrap();
    s.world.world.squads[0].members.retain(|id| *id < 4);
    for id in 4..=6 {
        q.add_member(id, &mut s.world.world.actors).unwrap();
    }
    q.leader = 4;
    s.world.world.squads.push(q);
    let mut c = command(Action::Assault {
        position: Vector3::new(40., 0., 0.),
        face: Vector3::X,
    });
    c.squads = vec![7, 8];
    s.execute(7, &c).unwrap();
    assert_eq!(s.plans.len(), 1);
    assert_eq!(s.next_plan, 2);
    assert!(s
        .world
        .world
        .squads
        .iter()
        .all(|q| q.order_number == 1 && q.plan == 1));
    assert_eq!(s.plans[0].objective, Vector3::new(40., 0., 0.));
}

#[test]
fn sling_selection_claims_cargo_and_dismount_does_not_increment_squad_orders() {
    let mut s = scene();
    let mut c = command(Action::Sling(TANK));
    c.vehicles = vec![HELI];
    s.execute(7, &c).unwrap();
    assert_eq!(
        s.world.world.actors.vehicle(HELI).unwrap().sling_target,
        TANK
    );
    assert_eq!(s.world.world.actors.vehicle(TANK).unwrap().owner, 7);
    let before = s.world.world.squads[0].order_number;
    s.execute(7, &command(Action::Dismount)).unwrap();
    assert_eq!(s.world.world.squads[0].order_number, before);
}

#[test]
fn unconnected_peers_cannot_trigger_observer_demonstrations_in_an_empty_match() {
    let mut s = scene();
    s.owners.players.clear();
    let before = s.state();
    let demo = command(Action::DemoSupport {
        kind: "mortars".into(),
        position: Vector3::ZERO,
        direction: Vector3::X,
    });
    for peer in [0, -3, 10, 999] {
        assert!(s.execute(peer, &demo).unwrap().is_empty());
        assert_eq!(s.state(), before);
    }
}

#[test]
fn regrouping_cancels_the_retained_ambush_before_another_tick() {
    use frontline_core::ambush_plan::{AmbushPlan, Phase};
    let mut s = scene();
    s.world.world.squads[0].ambush_plan = 1;
    s.ambushes.push(AmbushPlan {
        id: 1,
        squad: 7,
        zone: Vector3::ZERO,
        road: Vector3::X,
        side: Vector3::Z,
        rally: Vector3::ZERO,
        gun_end: 1.,
        phase: Phase::Wait,
        phase_time: 0.,
        fire_time: 0.,
        quiet_time: 0.,
        done: false,
        caught: 0,
    });
    s.execute(7, &command(Action::Stop)).unwrap();
    assert!(s.ambushes[0].done);
    assert_eq!(s.world.world.squads[0].ambush_plan, 0);
}

#[test]
fn an_exhausted_order_counter_is_rejected_before_ownership_or_orders_change() {
    let mut s = scene();
    s.world.world.squads[0].order_number = i64::MAX as u64;
    let before = s.state();
    assert!(s.execute(7, &command(Action::Stop)).is_err());
    assert_eq!(s.state(), before);
}
