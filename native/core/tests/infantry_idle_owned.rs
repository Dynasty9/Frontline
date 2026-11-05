use frontline_core::actors::{Actor, Actors};
use frontline_core::infantry::Infantry;
use frontline_core::infantry_idle::{Idle, Line, CHAT, LAUGH};
use frontline_core::infantry_idle_owned::Event;
use frontline_core::random::SimulationRandom;
use frontline_core::spatial::{SpatialIndex, UNIT_CELL};
use frontline_core::squad::Squad;
use frontline_core::vector::Vector3;

fn soldier(id: u32) -> Infantry {
    let mut s = Infantry::default();
    s.identity.id = id;
    s.identity.unit = "rifleman".into();
    s.identity.name = format!("Soldier {id}");
    s.identity.squad = 9;
    s.motion.position = Vector3::X * id as f32;
    s.weapon.last_shot = -99.0;
    s.idle.calm = 12.0;
    s
}
struct Field {
    a: Actors,
    units: SpatialIndex,
    squads: Vec<Squad>,
    last_chat: [f64; 2],
    rng: SimulationRandom,
}
impl Field {
    fn new(soldiers: Vec<Infantry>, seed: u64) -> Self {
        let a = Actors::from_entries(
            100,
            soldiers
                .into_iter()
                .map(|s| Actor::Soldier(Box::new(s)))
                .collect(),
        )
        .unwrap();
        let mut units = SpatialIndex::new(UNIT_CELL).unwrap();
        a.rebuild_units(&mut units).unwrap();
        Self {
            a,
            units,
            squads: vec![Squad {
                id: 9,
                combat_at: 3.0,
                ..Default::default()
            }],
            last_chat: [-99.0; 2],
            rng: SimulationRandom::new(seed),
        }
    }
    fn step(&mut self, id: u32, now: f64, moving: bool) -> Vec<Event> {
        self.a
            .advance_infantry_idle(
                id,
                0.1,
                now,
                moving,
                &mut self.squads,
                &mut self.last_chat,
                &self.units,
                &mut self.rng,
            )
            .unwrap()
    }
}

#[test]
fn conversation_claims_first_eligible_partner_before_his_turn() {
    let seed = (1..100)
        .find(|&seed| {
            let mut rng = SimulationRandom::new(seed);
            rng.randf_range(6.0, 16.0);
            rng.randf() < 0.35
        })
        .unwrap();
    let mut f = Field::new(vec![soldier(1), soldier(3), soldier(2)], seed);
    assert_eq!(f.step(1, 30.0, false), [Event::Banter]);
    assert_eq!(f.a.soldier(1).unwrap().idle.partner, 3);
    assert_eq!(f.a.soldier(3).unwrap().idle.partner, 1);
    assert_eq!(f.a.soldier(2).unwrap().idle.partner, 0);
    assert_eq!(f.last_chat, [30.0, -99.0]);
    f.a = Actors::restore(&f.a.checkpoint().unwrap()).unwrap();
    let cursor = f.rng.state();
    assert!(f.step(3, 30.0, false).is_empty());
    assert_eq!(f.a.soldier(3).unwrap().activity, CHAT);
    assert_eq!(f.rng.state(), cursor);
}

#[test]
fn interrupted_chat_disconnects_both_soldiers_without_erasing_the_partners_other_state() {
    let mut a = soldier(1);
    let mut b = soldier(2);
    a.idle.activity = CHAT;
    a.idle.partner = 2;
    b.idle.activity = CHAT;
    b.idle.partner = 1;
    b.idle.until = 100.0;
    let mut f = Field::new(vec![a, b], 731);
    f.step(1, 30.0, true);
    assert_eq!(f.a.soldier(1).unwrap().idle.activity, 0);
    assert_eq!(f.a.soldier(2).unwrap().idle.partner, 0);
    assert_eq!(f.a.soldier(2).unwrap().idle.activity, CHAT);
    assert_eq!(f.squads[0].combat_at, 3.0); // Moving short-circuits the danger query.
    f.step(2, 30.0, false);
    assert_eq!(f.a.soldier(2).unwrap().idle.activity, 0);
    assert_eq!(f.squads[0].combat_at, 30.0);
}

#[test]
fn due_lines_and_laughter_override_speech_cooldown_in_order() {
    let mut a = soldier(1);
    let mut b = soldier(2);
    a.idle.activity = CHAT;
    a.idle.partner = 2;
    a.idle.until = 100.0;
    a.idle.lines = [
        Line {
            at: 29.0,
            text: "First".into(),
        },
        Line {
            at: 30.0,
            text: "!laugh".into(),
        },
        Line {
            at: 30.0,
            text: "Last".into(),
        },
    ]
    .into();
    a.vitals.speech_cooldown = 3.0;
    b.idle.partner = 1;
    let mut f = Field::new(vec![a, b], 713);
    let mut expected = f.a.soldier(1).unwrap().idle.clone();
    let mut rng = f.rng;
    let mut speech = vec![];
    while let Some(line) = expected.next_line(30.0, &mut rng).unwrap() {
        if let Some(text) = line {
            speech.push(Event::Speech(text));
        }
    }
    assert_eq!(f.step(1, 30.0, false), speech);
    let a = f.a.soldier(1).unwrap();
    assert!(a.idle.lines.is_empty());
    assert_eq!(a.activity, LAUGH);
    assert_eq!(a.vitals.speech_cooldown, 2.6);
    assert_eq!(f.rng.state(), rng.state());
}

#[test]
fn an_unavailable_partner_falls_back_to_solo_without_skipping_random_draws() {
    for seed in 1..100 {
        let mut a = soldier(1);
        a.vitals.speech_cooldown = 4.0;
        let mut expected = a.idle.clone();
        let mut random = SimulationRandom::new(seed);
        expected.calm += 0.1;
        expected.begin(30.0, -99.0, &mut random).unwrap();
        expected.solo(30.0, 0, &mut random).unwrap();
        let mut f = Field::new(vec![a], seed);
        assert!(f.step(1, 30.0, false).is_empty());
        assert_eq!(f.a.soldier(1).unwrap().idle, expected);
        assert_eq!(f.rng.state(), random.state());
    }
}

#[test]
fn the_idle_deadline_is_strict_and_invalid_clocks_leave_state_unchanged() {
    let mut a = soldier(1);
    a.idle = Idle {
        activity: 29,
        until: 30.0,
        ..Default::default()
    };
    let mut f = Field::new(vec![a], 991);
    let cursor = f.rng.state();
    f.step(1, 30.0, false);
    assert_eq!(f.a.soldier(1).unwrap().activity, 29);
    assert_eq!(cursor, f.rng.state());
    f.step(1, 30.00001, false);
    assert_eq!(f.a.soldier(1).unwrap().idle.activity, 0);
    let before = f.a.checkpoint().unwrap();
    let cursor = f.rng.state();
    assert!(f
        .a
        .advance_infantry_idle(
            1,
            -0.1,
            31.0,
            false,
            &mut f.squads,
            &mut f.last_chat,
            &f.units,
            &mut f.rng
        )
        .is_err());
    assert_eq!(before, f.a.checkpoint().unwrap());
    assert_eq!(cursor, f.rng.state());
}
