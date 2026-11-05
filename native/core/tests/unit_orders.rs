#[path = "fixtures/unit_orders.rs"]
#[allow(dead_code)]
mod fixture;
use fixture::{scene, state};
use frontline_core::infantry_action::Round;
use frontline_core::infantry_controller::Task;
use frontline_core::infantry_vitals::Life;
use frontline_core::squad_movement::{Call, Event};
use frontline_core::unit_orders::Order;
use frontline_core::vector::Vector3;

#[test]
fn unavailable_soldiers_keep_their_orders_and_claims() {
    for unavailable in [false, true] {
        let mut s = scene(0);
        s.change(3, |m| {
            if unavailable {
                m.vitals.life = Life::Downed;
            } else {
                m.duty.kind = Task::Rescue;
                m.duty.phase = 1;
            }
        });
        let before = state(&s);
        assert!(s
            .context()
            .unit_order(3, Order::Stop, None)
            .unwrap()
            .is_empty());
        assert_eq!(before, state(&s));
    }
}
#[test]
fn stopping_a_rescuer_releases_both_patient_links() {
    let mut s = scene(0);
    let out = s.context().unit_order(3, Order::Stop, None).unwrap();
    assert_eq!(s.actors.soldier(2).unwrap().links.rescue_claimed, 0);
    assert_eq!(s.actors.soldier(2).unwrap().links.dragged_by, 0);
    assert!(s.actors.soldier(3).unwrap().orders.detached);
    assert_eq!(s.actors.soldier(3).unwrap().duty.kind, Task::Fight);
    assert!(matches!(
        out.as_slice(),
        [Event::Speech {
            call: Call::Individual,
            ..
        }]
    ));
}
#[test]
fn empty_grenades_do_not_detach_or_draw_acknowledgment_randomness() {
    let mut s = scene(1);
    let before = s.rng.state();
    let out = s
        .context()
        .unit_order(
            2,
            Order::Throw {
                position: Vector3::ZERO,
                round: Round::Frag,
            },
            None,
        )
        .unwrap();
    assert_eq!(
        out,
        vec![Event::Speech {
            soldier: 2,
            call: Call::OutOfAmmo,
            variant: 0
        }]
    );
    assert!(!s.actors.soldier(2).unwrap().orders.detached);
    assert_eq!(before, s.rng.state());
}
#[test]
fn friendly_targets_do_not_interrupt_but_enemy_orders_detach() {
    let mut s = scene(1);
    let before = state(&s);
    assert!(s
        .context()
        .unit_order(3, Order::Attack(2), None)
        .unwrap()
        .is_empty());
    assert_eq!(before, state(&s));
    s.context()
        .unit_order(3, Order::Attack(10), Some(40.))
        .unwrap();
    let m = s.actors.soldier(3).unwrap();
    assert!(m.orders.detached);
    assert_eq!(m.fight.forced_target, 10);
}
#[test]
fn movement_uses_the_individual_leash() {
    let mut s = scene(1);
    s.context()
        .unit_order(
            3,
            Order::Move {
                position: Vector3::new(10., 0., 10.),
                face: Vector3::ZERO,
                mode: 1,
            },
            None,
        )
        .unwrap();
    assert_eq!(s.actors.soldier(3).unwrap().orders.leash, 5.);
    assert!(s.actors.soldier(3).unwrap().orders.detached);
}
#[test]
fn mounting_assigns_one_gunner_and_preserves_that_claim_against_a_second_order() {
    let mut s = scene(5);
    let order = Order::Man {
        target: 9,
        gun: Some(fixture::gun()),
    };
    let out = s.context().unit_order(3, order, None).unwrap();
    assert!(out.contains(&Event::Stat("manned")));
    assert_eq!(s.actors.structure(9).unwrap().gunner, 3);
    assert_eq!(s.actors.soldier(3).unwrap().emplacement.structure, 9);
    let out = s.context().unit_order(4, order, None).unwrap();
    assert!(!out.contains(&Event::Stat("manned")));
    assert_eq!(s.actors.structure(9).unwrap().gunner, 3);
    assert!(s.actors.soldier(4).unwrap().orders.detached);
}
#[test]
fn invalid_input_rejects_before_mutation() {
    let mut s = scene(1);
    let before = state(&s);
    for order in [
        Order::Move {
            position: Vector3::ZERO,
            face: Vector3::ZERO,
            mode: 3,
        },
        Order::Throw {
            position: Vector3::ZERO,
            round: Round::HighExplosive,
        },
    ] {
        assert!(s.context().unit_order(3, order, None).is_err());
        assert_eq!(before, state(&s));
    }
    assert!(s
        .context()
        .unit_order(3, Order::Stop, Some(f64::NAN))
        .is_err());
    assert_eq!(before, state(&s));
}
