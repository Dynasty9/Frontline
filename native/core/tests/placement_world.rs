#[path = "fixtures/placement_world.rs"]
#[allow(dead_code)]
mod fixture;
use fixture::{place, scene};
use frontline_core::placement_world::Event;
use frontline_core::vector::Vector3;

#[test]
fn placement_spends_registers_geometry_and_assigns_an_allied_engineer() {
    let mut s = scene();
    let events = place(
        &mut s,
        8,
        "sandbags",
        Vector3::new(-20., 0., 15.),
        true,
        &[],
    )
    .unwrap();
    let Event::Placed { id, ownership } = &events[0] else {
        panic!("missing building")
    };
    let st = s.world.actors.structure(*id).unwrap();
    assert!(!st.built);
    assert_eq!(st.progress, 0.);
    assert_eq!(st.hp, 40.);
    assert!(!st.hash_cells.is_empty());
    assert_eq!(s.world.actors.structure(8).unwrap().supply, 900.);
    assert_eq!(s.battle.sides[0][14], 100.);
    assert_eq!(s.world.squads[0].build_target, *id);
    assert_eq!(s.world.squads[0].owner, 1);
    assert!(ownership.squads.is_empty());
}
#[test]
fn explicitly_selected_ai_builders_transfer_to_the_human_once() {
    let mut s = scene();
    s.world.squads[0].owner = -1;
    let events = place(
        &mut s,
        8,
        "sandbags",
        Vector3::new(-20., 0., 15.),
        true,
        &[7, 7, 999],
    )
    .unwrap();
    let Event::Placed { ownership, .. } = &events[0] else {
        panic!("missing building")
    };
    assert_eq!(ownership.squads, vec![7]);
    assert_eq!(s.world.squads[0].owner, 8);
    assert_eq!(s.world.actors.soldier(1).unwrap().identity.owner, 8);
}
#[test]
fn later_segments_leave_the_first_build_assignment_intact() {
    let mut s = scene();
    place(
        &mut s,
        8,
        "sandbags",
        Vector3::new(-20., 0., 15.),
        true,
        &[7],
    )
    .unwrap();
    let assigned = s.world.squads[0].build_target;
    place(
        &mut s,
        8,
        "sandbags",
        Vector3::new(-10., 0., 15.),
        false,
        &[7],
    )
    .unwrap();
    assert_eq!(s.world.squads[0].build_target, assigned);
    assert_eq!(s.world.actors.structure(8).unwrap().supply, 800.);
}
#[test]
fn invalid_authority_and_blocked_footprints_do_not_spend_or_spawn() {
    let mut s = scene();
    let before = s.world.actors.checkpoint().unwrap();
    assert!(place(&mut s, 9, "sandbags", Vector3::ZERO, true, &[7])
        .unwrap()
        .is_empty());
    assert!(matches!(
        &place(
            &mut s,
            8,
            "sandbags",
            Vector3::new(-40., 0., 40.),
            true,
            &[7]
        )
        .unwrap()[0],
        Event::Warning { peer: 8, .. }
    ));
    assert_eq!(s.world.actors.checkpoint().unwrap(), before);
    assert_eq!(s.battle.sides[0][14], 0.);
}
#[test]
fn base_names_only_advance_after_successful_paid_placement() {
    let mut s = scene();
    let events = place(&mut s, 8, "fob", Vector3::new(30., 0., 20.), false, &[]).unwrap();
    let Event::Placed { id, .. } = events[0] else {
        panic!("missing base")
    };
    assert_eq!(s.world.actors.structure(id).unwrap().name, "Alpha");
    assert_eq!(s.rules.fob_names_used, [1, 0]);
    assert!(matches!(
        place(&mut s, 8, "fob", Vector3::new(30., 0., 20.), false, &[]).unwrap()[0],
        Event::Warning { .. }
    ));
    assert_eq!(s.rules.fob_names_used, [1, 0]);
}

#[test]
fn insufficient_supply_does_not_change_actors_geometry_or_assignment() {
    use frontline_core::actors::{Actor, Actors};
    let mut s = scene();
    let mut entries: Vec<_> = s.world.actors.iter().cloned().collect();
    for a in &mut entries {
        if let Actor::Structure(st) = a {
            if st.kind == "fob" {
                st.supply = 0.;
            }
        }
    }
    s.world.actors = Actors::from_entries(s.world.actors.entities().next_id(), entries).unwrap();
    let before = s.state();
    let events = place(
        &mut s,
        8,
        "sandbags",
        Vector3::new(-20., 0., 15.),
        true,
        &[7],
    )
    .unwrap();
    assert!(
        matches!(&events[0],Event::Warning{peer:8,text} if text=="Not enough supply at a nearby FOB for Field works (100).")
    );
    assert_eq!(before, s.state());
}
#[test]
fn exhausted_battle_credit_rejects_before_payment_or_birth() {
    let mut s = scene();
    s.battle.sides[0][14] = 1e15;
    let before = s.state();
    assert!(place(
        &mut s,
        8,
        "sandbags",
        Vector3::new(-20., 0., 15.),
        true,
        &[7]
    )
    .is_err());
    assert_eq!(before, s.state());
}
