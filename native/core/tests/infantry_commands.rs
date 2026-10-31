use frontline_core::infantry::{Goal, Identity, Infantry};
use frontline_core::infantry_action::{Action, Round, Throw};
use frontline_core::infantry_commands::{Command, Release};
use frontline_core::infantry_controller::Task;
use frontline_core::infantry_vitals::Life;
use frontline_core::path_planner::PathPlanner;
use frontline_core::vector::Vector3;

fn soldier() -> Infantry {
    Infantry {
        identity: Identity {
            id: 1,
            unit: "rifleman".into(),
            squad: 8,
            ..Default::default()
        },
        ..Default::default()
    }
}

#[test]
fn move_orders_wait_for_a_stacked_breacher_without_discarding_his_cooked_throw() {
    let nav = PathPlanner::new(32).unwrap();
    let mut s = soldier();
    s.duty.kind = Task::Breach;
    s.duty.phase = 2;
    s.action.current = Action::Cook;
    s.action.remaining = 0.5;
    s.action.queued_throw = Some(Throw {
        position: Vector3::X,
        round: Round::Frag,
        fuse: 1.2,
    });
    let before = s.action;
    let out = s
        .command(
            Command::Move {
                slot: Vector3::Z * 9.0,
                mode: 2,
                face: Vector3::X,
            },
            &nav,
            None,
        )
        .unwrap();
    assert!(out.accepted && out.route.is_none() && out.release.is_none());
    assert_eq!(s.action, before);
    assert_eq!(s.duty.kind, Task::Breach);
    assert!(s.entry.reordered);
    assert_eq!(s.orders.hold_position, Vector3::Z * 9.0);
    assert_eq!(s.orders.hold_face, Vector3::X);
    s.duty.phase = 0;
    let out = s
        .command(
            Command::Move {
                slot: Vector3::Z * 10.0,
                mode: 1,
                face: Vector3::ZERO,
            },
            &nav,
            None,
        )
        .unwrap();
    assert_eq!(out.release, Some(Release::Breach(8)));
    assert_eq!(s.duty.kind, Task::Fight);
    assert_eq!(s.orders.hold_face, Vector3::X);
    assert_eq!(out.route.unwrap().job.care, 0.35);
}

#[test]
fn ordinary_orders_do_not_interrupt_carriers_but_retreat_can_release_a_rescuer() {
    let nav = PathPlanner::new(32).unwrap();
    let mut s = soldier();
    s.duty.kind = Task::Rescue;
    s.duty.entity = 7;
    s.duty.partner = 9;
    s.duty.phase = 1;
    s.orders.backwards = true;
    let before = s.clone();
    assert!(!s.command(Command::Stop, &nav, None).unwrap().accepted);
    assert_eq!(s, before);
    let out = s
        .command(
            Command::Retreat {
                position: Vector3::NEG_Z * 8.0,
            },
            &nav,
            None,
        )
        .unwrap();
    assert_eq!(out.release, Some(Release::Rescue(7)));
    assert_eq!(out.route.unwrap().job.care, 1.6);
    assert_eq!((s.duty.entity, s.duty.partner), (0, 0));
    assert!(!s.orders.backwards);
    assert_eq!(s.duty.kind, Task::Retreat);
    for task in [Task::Stretcher, Task::Captor, Task::Limp, Task::Tunnel] {
        s.duty.kind = task;
        let before = s.clone();
        assert!(
            !s.command(
                Command::Retreat {
                    position: Vector3::ZERO
                },
                &nav,
                None
            )
            .unwrap()
            .accepted
        );
        assert_eq!(s, before);
    }
}

#[test]
fn formation_adjustments_keep_a_nearby_route_and_halt_uses_walkable_ground() {
    let mut nav = PathPlanner::new(32).unwrap();
    let mut s = soldier();
    s.orders.goal = Vector3::X * 5.0;
    s.orders.purpose = Goal::Cover;
    s.orders.pending_path = true;
    let out = s
        .command(
            Command::Follow {
                position: Vector3::X * 7.9,
                mode: 2,
                face: Vector3::Z,
            },
            &nav,
            None,
        )
        .unwrap();
    assert!(out.route.is_none());
    assert_eq!(s.orders.goal, Vector3::X * 5.0);
    assert_eq!(s.orders.move_mode, 2);
    let out = s
        .command(
            Command::Follow {
                position: Vector3::X * 8.0,
                mode: 1,
                face: Vector3::ZERO,
            },
            &nav,
            None,
        )
        .unwrap();
    assert!(out.route.is_some());
    assert_eq!(s.orders.hold_face, Vector3::ZERO);
    let mut kinds = vec![0; 1024];
    kinds[16 * 32 + 16] = 3;
    assert!(nav.load_cells(&kinds, &[0; 1024], &[0; 1024]));
    let hold = nav.nearest_walkable(s.motion.position).unwrap();
    let out = s
        .command(Command::Halt { face: Vector3::Z }, &nav, None)
        .unwrap();
    assert!(out.cancel_path);
    assert_eq!(s.orders.hold_position, hold);
    assert_eq!(nav.kind_at(hold, false), 0);
    assert!(!s.is_moving());
    assert_eq!(s.orders.leash, 8.0);
}

#[test]
fn leaving_an_emplacement_resets_its_aim_and_places_the_gunner_beside_it() {
    let nav = PathPlanner::new(32).unwrap();
    let mut s = soldier();
    s.duty.kind = Task::Man;
    s.duty.entity = 10;
    s.duty.partner = 19;
    s.orders.backwards = true;
    s.orders.base_y = 4.25;
    s.identity.mounted_weapon = "hmg".into();
    s.emplacement.structure = 10;
    s.emplacement.target = 31;
    s.emplacement.mortar_aim = Some(Vector3::X);
    s.emplacement.scan_timer = 0.7;
    s.cover.kind = 1;
    s.cover.structure = 10;
    let out = s
        .command(Command::Stop, &nav, Some(Vector3::new(3.0, 0.0, 5.0)))
        .unwrap();
    assert!(out.accepted && out.cancel_path);
    assert_eq!(s.motion.position, Vector3::new(5.0, 0.0, 5.0));
    assert_eq!(s.orders.hold_position, s.motion.position);
    assert_eq!(s.emplacement.structure, 0);
    assert_eq!(s.emplacement.target, 0);
    assert_eq!(s.emplacement.mortar_aim, None);
    assert!(s.identity.mounted_weapon.is_empty());
    assert_eq!(s.cover.kind, 0);
    // The existing release-mount return keeps these fields until the next duty takes them.
    assert_eq!(s.duty.partner, 19);
    assert!(s.orders.backwards);
}

#[test]
fn attack_and_throw_orders_preserve_approach_ranges_and_reject_invalid_input_atomically() {
    let nav = PathPlanner::new(32).unwrap();
    let mut s = soldier();
    let out = s
        .command(
            Command::Attack {
                target: 17,
                position: Vector3::Z * 12.0,
                slot: Vector3::Z * 3.0,
            },
            &nav,
            None,
        )
        .unwrap();
    assert!(out.accepted);
    assert_eq!(s.fight.forced_target, 17);
    assert_eq!(s.orders.hold_face, Vector3::Z);
    assert_eq!(s.orders.leash, 10.0);
    let before = s.clone();
    assert!(s
        .command(
            Command::Throw {
                position: Vector3::Z,
                round: Round::HighExplosive
            },
            &nav,
            None
        )
        .is_err());
    assert_eq!(s, before);
    assert!(s
        .command(
            Command::Move {
                slot: Vector3::splat(f32::NAN),
                mode: 0,
                face: Vector3::ZERO
            },
            &nav,
            None
        )
        .is_err());
    assert_eq!(s, before);
    let out = s
        .command(
            Command::Throw {
                position: Vector3::Z * 24.0,
                round: Round::Smoke,
            },
            &nav,
            None,
        )
        .unwrap();
    assert!(out.route.is_none());
    assert_eq!(s.orders.goal, before.orders.goal);
    let out = s
        .command(
            Command::Throw {
                position: Vector3::Z * 30.0,
                round: Round::Frag,
            },
            &nav,
            None,
        )
        .unwrap();
    assert_eq!(out.route.unwrap().job.destination, Vector3::Z * 8.0);
    assert_eq!(s.duty.throw_kind, Round::Frag);
}

#[test]
fn returning_to_hold_keeps_nearby_soldiers_in_place_and_rejoins_distant_ones() {
    let nav = PathPlanner::new(32).unwrap();
    let mut s = soldier();
    s.duty.kind = Task::Heal;
    s.duty.entity = 3;
    s.orders.leash = 9.0;
    s.orders.hold_position = Vector3::Z * 9.0;
    assert!(s
        .command(Command::ReturnToHold, &nav, None)
        .unwrap()
        .route
        .is_none());
    assert_eq!(s.duty.kind, Task::Fight);
    assert_eq!(s.duty.entity, 0);
    s.orders.hold_position.z = 9.1;
    let out = s.command(Command::ReturnToHold, &nav, None).unwrap();
    assert_eq!(out.route.unwrap().job.care, 0.35);
    s.vitals.life = Life::Downed;
    let before = s.clone();
    assert!(
        !s.command(
            Command::Attack {
                target: 3,
                position: Vector3::Z,
                slot: Vector3::ZERO
            },
            &nav,
            None
        )
        .unwrap()
        .accepted
    );
    assert_eq!(s, before);
}
