use frontline_core::actors::{Actor, Actors};
use frontline_core::battle_stats::{BattleStats, Unit};
use frontline_core::infantry::{Goal, Infantry};
use frontline_core::infantry_rejoin::Rejoined;
use frontline_core::squad::Squad;
use frontline_core::vector::Vector3;

struct Field {
    a: Actors,
    squads: Vec<Squad>,
    next: u64,
    battle: BattleStats,
}
impl Field {
    fn new(owner: i32, team: i8, squads: Vec<Squad>) -> Self {
        let mut s = Infantry::default();
        s.identity.id = 1;
        s.identity.unit = "rifleman".into();
        s.identity.owner = owner;
        s.identity.team = team;
        s.cover.at_cover = true;
        s.cover.evaluate_at = 20.0;
        let mut battle = BattleStats::default();
        for q in &squads {
            battle
                .register_unit(Unit {
                    key: format!("s{}", q.id),
                    name: q.callsign(),
                    kind: "Squad".into(),
                    team: q.team,
                    owner: q.owner,
                    ended: -1.0,
                    ..Default::default()
                })
                .unwrap();
        }
        Self {
            a: Actors::from_entries(100, vec![Actor::Soldier(Box::new(s))]).unwrap(),
            squads,
            next: 100,
            battle,
        }
    }
    fn step(&mut self, players: &[(i32, i8)]) -> Result<Rejoined, &'static str> {
        self.a.rejoin_infantry(
            1,
            10.0,
            players,
            &mut self.squads,
            &mut self.next,
            &mut self.battle,
            "Rifle Squad",
        )
    }
}
fn squad(id: u32, owner: i32, x: f32) -> Squad {
    Squad {
        id,
        owner,
        order_position: Vector3::X * x,
        ..Default::default()
    }
}

#[test]
fn nearest_matching_section_wins_with_registration_order_ties() {
    let mut f = Field::new(
        7,
        0,
        vec![squad(12, 7, 15.0), squad(11, 7, -15.0), squad(13, 8, 1.0)],
    );
    let out = f.step(&[(7, 0)]).unwrap();
    assert_eq!(out.squad, 12);
    assert!(!out.created);
    assert_eq!(f.next, 100);
    assert_eq!(f.squads[0].members, [1]);
    assert_eq!(f.squads[0].centroid_at, -1.0);
    assert_eq!(f.squads[1].centroid_at, 10.0);
    assert_eq!(f.squads[2].centroid_at, -1.0);
    let s = f.a.soldier(1).unwrap();
    assert_eq!(s.identity.squad, 12);
    assert_eq!(s.orders.purpose, Goal::Slot);
    assert_eq!(out.route.unwrap().job.destination, Vector3::X * 15.0);
    assert!(!s.cover.at_cover);
    assert_eq!(s.cover.evaluate_at, 0.0);
    assert_eq!(f.battle.units[0].men, 1);
}

#[test]
fn disconnected_commanders_pass_control_to_the_last_teammate_or_ai() {
    for (peers, expected) in [
        (vec![(8, 0), (9, 1), (6, 0)], 6),
        (vec![(8, 1)], -1),
        (vec![(7, 0)], 7),
    ] {
        let mut f = Field::new(7, 0, vec![]);
        let out = f.step(&peers).unwrap();
        assert_eq!(f.a.soldier(1).unwrap().identity.owner, expected);
        assert_eq!(out.owner_changed, (expected != 7).then_some(expected));
        assert_eq!(f.squads[0].owner, expected);
        assert_eq!(f.battle.units[0].owner, expected);
    }
}

#[test]
fn no_nearby_space_creates_a_section_and_records_its_birth() {
    for team in [0, 1] {
        let mut q = squad(12, -1 - i32::from(team), 90.0);
        q.team = team;
        let mut f = Field::new(q.owner, team, vec![q]);
        let out = f.step(&[]).unwrap();
        assert!(out.created && out.route.is_none());
        assert_eq!(out.squad, 100);
        assert_eq!(f.next, 101);
        let q = &f.squads[1];
        assert_eq!(
            q.kind,
            if team == 0 {
                "rifle_squad"
            } else {
                "fighter_cell"
            }
        );
        assert_eq!(q.think_timer, (100.0 * 0.309016994) % 0.5);
        assert_eq!(
            q.callsign(),
            if team == 0 { "Echo 13" } else { "Scorpion 13" }
        );
        assert_eq!(f.battle.units[1].started, 10.0);
        assert_eq!(f.battle.units[1].ended, -1.0);
        assert_eq!(f.battle.units[1].men, 1);
    }
}

#[test]
fn a_full_section_is_skipped_and_duplicate_membership_does_not_grow_the_record() {
    let mut full = squad(12, 7, 1.0);
    full.members = vec![2, 3, 4, 5, 6, 7];
    let mut f = Field::new(7, 0, vec![full, squad(13, 7, 4.0)]);
    assert_eq!(f.step(&[(7, 0)]).unwrap().squad, 13);
    f.a = Actors::restore(&f.a.checkpoint().unwrap()).unwrap();
    let before = f.battle.checkpoint();
    assert_eq!(f.step(&[(7, 0)]).unwrap().squad, 13);
    assert_eq!(f.squads[1].members, [1]);
    assert_eq!(f.battle.checkpoint(), before);
}

#[test]
fn hold_and_return_routes_keep_the_strict_distance_thresholds() {
    for (distance, routed) in [(3.0, false), (3.01, true), (39.99, true), (40.0, false)] {
        let mut f = Field::new(7, 0, vec![squad(12, 7, distance)]);
        let out = f.step(&[(7, 0)]).unwrap();
        assert_eq!(out.route.is_some(), routed);
        let s = f.a.soldier(1).unwrap();
        assert_eq!(
            s.orders.hold_position,
            if distance < 40.0 {
                Vector3::X * distance
            } else {
                Vector3::ZERO
            }
        );
    }
}

#[test]
fn bad_rosters_and_reused_squad_cursors_do_not_change_state() {
    let mut f = Field::new(7, 0, vec![squad(12, 7, 4.0)]);
    let before = f.a.checkpoint().unwrap();
    let squad_before = f.squads[0].checkpoint().unwrap();
    let battle_before = f.battle.checkpoint();
    assert!(f.step(&[(7, 0), (7, 1)]).is_err());
    f.next = 12;
    assert!(f.step(&[]).is_err());
    assert_eq!(f.a.checkpoint().unwrap(), before);
    assert_eq!(f.squads[0].checkpoint().unwrap(), squad_before);
    assert_eq!(f.battle.checkpoint(), battle_before);
}
