#[path = "fixtures/command_handoff.rs"]
mod fixture;
use frontline_core::command_ownership::Ownership;

#[test]
fn authority_comes_from_the_connected_side_and_preserves_selection_order() {
    let (o, a, qs, _) = fixture::scene(0, true);
    assert_eq!(
        o.select_squads(8, &[4, 1, 4, 5, 999, 2], &qs).unwrap(),
        vec![4, 1, 2]
    );
    assert_eq!(o.select_squads(-1, &[1, 4, 5], &qs).unwrap(), vec![4]);
    assert_eq!(
        o.select_vehicles(8, &[21, 20, 23, 22, 20], &a, &|k| k == "truck")
            .unwrap(),
        vec![20, 22]
    );
    for peer in [0, 11, 999] {
        assert!(o.select_squads(peer, &[1, 4], &qs).unwrap().is_empty());
    }
    assert!(!o.can_command(7, 1, 7));
    assert!(!o.can_command(-1, 0, 7));
}
#[test]
fn taking_command_only_changes_ai_attribution() {
    let (o, mut a, mut qs, _) = fixture::scene(0, true);
    let changed = o
        .take_command(8, &[1, 4, 4, 5], &[20, 22, 22], &mut qs, &mut a)
        .unwrap();
    assert_eq!(changed.squads, vec![4]);
    assert_eq!(changed.vehicles, vec![22]);
    assert_eq!(changed.soldiers, vec![4]);
    assert_eq!(qs[0].owner, 7);
    assert_eq!(a.soldier(4).unwrap().identity.owner, 8);
    assert_eq!(a.vehicle(20).unwrap().owner, 7);
}
#[test]
fn departing_hands_all_forces_to_the_last_teammate_or_ai() {
    for humans in [false, true] {
        let (mut o, mut a, mut qs, _) = fixture::scene(1, humans);
        let (team, heir, changed) = o.depart(7, &mut qs, &mut a).unwrap().unwrap();
        assert_eq!(team, 1);
        assert_eq!(heir, if humans { 10 } else { -2 });
        assert_eq!(changed.squads, vec![1, 2, 3]);
        assert_eq!(changed.vehicles, vec![20, 21]);
        assert_eq!(o.away[0].squads, vec![1, 2, 3]);
        assert_eq!(a.soldier(2).unwrap().identity.owner, heir);
        assert!(o.depart(7, &mut qs, &mut a).unwrap().is_none());
    }
}
#[test]
fn returning_reclaims_survivors_queues_and_credit_without_claiming_other_humans() {
    let (mut o, mut a, mut qs, mut b) = fixture::scene(0, true);
    o.depart(7, &mut qs, &mut a).unwrap();
    o.connect(17, 0).unwrap();
    b.add(17, 0, 14, 25.).unwrap();
    let (n, c) = o
        .reclaim(17, 7, "Returned", &mut qs, &mut a, &mut b, false, &|k| {
            k == "truck"
        })
        .unwrap();
    assert_eq!(n, 4);
    assert_eq!(c.squads, vec![1, 3]);
    assert_eq!(qs[1].owner, 10);
    assert_eq!(a.structure(30).unwrap().queue[0].owner, 17);
    assert_eq!(
        b.players.iter().find(|p| p.owner == 17).unwrap().counters[14],
        175.
    );
    assert!(!b.players.iter().any(|p| p.owner == 7));
    assert!(o.away.is_empty());
}
#[test]
fn standing_down_ai_includes_casualty_squads_but_excludes_automatic_trucks() {
    let (mut o, mut a, mut qs, mut b) = fixture::scene(0, false);
    o.depart(7, &mut qs, &mut a).unwrap();
    o.connect(17, 0).unwrap();
    let (n, _) = o
        .reclaim(17, 7, "Returned", &mut qs, &mut a, &mut b, true, &|k| {
            k == "truck"
        })
        .unwrap();
    assert_eq!(n, 4);
    assert_eq!(qs[1].owner, 17);
    assert_eq!(qs[3].owner, 17);
    assert_eq!(a.vehicle(22).unwrap().owner, 17);
    assert_eq!(a.vehicle(23).unwrap().owner, -1);
    assert_eq!(a.vehicle(21).unwrap().owner, 17);
}
#[test]
fn observers_and_rejected_connections_cannot_mutate_forces() {
    let (mut o, mut a, mut qs, mut b) = fixture::scene(0, true);
    let before = a.checkpoint().unwrap();
    let old = qs.clone();
    let saved = o.checkpoint().unwrap();
    assert!(o.connect(7, 1).is_err());
    assert!(o.connect(-1, 0).is_err());
    assert_eq!(o.checkpoint().unwrap(), saved);
    assert_eq!(o.depart(11, &mut qs, &mut a).unwrap().unwrap().1, 0);
    o.connect(12, -1).unwrap();
    assert_eq!(
        o.reclaim(12, 11, "Watcher", &mut qs, &mut a, &mut b, true, &|_| false)
            .unwrap()
            .0,
        0
    );
    assert_eq!(a.checkpoint().unwrap(), before);
    assert_eq!(qs, old);
    assert_eq!(Ownership::restore(&o.checkpoint().unwrap()).unwrap(), o);
}
#[test]
fn credit_overflow_rejects_rejoin_before_any_ownership_changes() {
    let (mut o, mut a, mut qs, mut b) = fixture::scene(0, false);
    o.depart(7, &mut qs, &mut a).unwrap();
    o.connect(17, 0).unwrap();
    b.joined(17, 0, "New").unwrap();
    for p in &mut b.players {
        p.counters[14] = 1e15;
    }
    let before = (o.clone(), a.checkpoint().unwrap(), qs.clone(), b.clone());
    assert!(o
        .reclaim(17, 7, "Returned", &mut qs, &mut a, &mut b, true, &|_| false)
        .is_err());
    assert_eq!((o, a.checkpoint().unwrap(), qs, b), before);
}
#[test]
fn all_handoff_continuations_survive_exact_checkpoint_resumes() {
    assert!(!fixture::transcript().is_empty());
}
