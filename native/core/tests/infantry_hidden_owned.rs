use frontline_core::actors::{Actor, Actors};
use frontline_core::infantry::Infantry;
use frontline_core::infantry_control::HiddenReason;
use frontline_core::infantry_controller::Task;
use frontline_core::infantry_hidden_owned::{Event, Update};
use frontline_core::infantry_vitals::Life;
use frontline_core::path_planner::PathPlanner;
use frontline_core::random::SimulationRandom;
use frontline_core::squad::Squad;
use frontline_core::structure::Structure;
use frontline_core::vector::Vector3;
use frontline_core::vehicle::Vehicle;

fn soldier(reason: HiddenReason) -> Infantry {
    let mut s = Infantry::default();
    s.identity.id = 1;
    s.identity.squad = 9;
    s.identity.unit = "rifleman".into();
    s.vitals.life = Life::Hidden;
    s.control.hidden = reason;
    s.links.hidden_in = 10;
    s
}
fn structure(id: u32, kind: &str, x: f32) -> Structure {
    Structure {
        id,
        kind: kind.into(),
        team: 0,
        position: Vector3::X * x,
        ..Default::default()
    }
}
struct Field {
    a: Actors,
    nav: PathPlanner,
    squads: Vec<Squad>,
    rng: SimulationRandom,
}
impl Field {
    fn new(s: Infantry, extra: Vec<Actor>) -> Self {
        let mut entries = vec![Actor::Soldier(Box::new(s))];
        entries.extend(extra);
        Self {
            a: Actors::from_entries(100, entries).unwrap(),
            nav: PathPlanner::new(128).unwrap(),
            squads: vec![Squad {
                id: 9,
                members: vec![1],
                centroid_at: 3.0,
                ..Default::default()
            }],
            rng: SimulationRandom::new(1739),
        }
    }
    fn step(&mut self, dt: f64) -> Result<Update, &'static str> {
        self.a.advance_infantry_hidden(
            1,
            dt,
            Some(("rifle", 30)),
            &self.nav,
            &mut self.squads,
            &mut self.rng,
        )
    }
}

#[test]
fn hidden_passengers_follow_current_transport_without_spending_the_timer() {
    let mut s = soldier(HiddenReason::Vehicle);
    s.links.vehicle = 20;
    s.control.hidden_timer = 15.0;
    let position = Vector3::new(3.0, 20.0, -7.0);
    let mut f = Field::new(
        s,
        vec![Actor::Vehicle(Box::new(Vehicle {
            id: 20,
            position,
            ..Default::default()
        }))],
    );
    let before = f.rng.state();
    assert_eq!(f.step(0.5).unwrap(), Update::default());
    let s = f.a.soldier(1).unwrap();
    assert_eq!(s.motion.position, position);
    assert_eq!(s.control.hidden_timer, 15.0);
    f.a.remove(20);
    f.step(0.5).unwrap();
    let s = f.a.soldier(1).unwrap();
    assert_eq!(s.vitals.life, Life::Alive);
    assert_eq!(s.links.vehicle, 0);
    assert_eq!(s.motion.position, Vector3::new(3.0, 0.0, -7.0));
    assert_eq!(f.rng.state(), before);
}

#[test]
fn tunnel_completion_removes_shared_occupancy_after_the_deadline() {
    let mut s = soldier(HiddenReason::TunnelTravel);
    s.control.hidden_timer = 0.2;
    s.duty.position = Vector3::new(11.0, 4.0, 3.0);
    let mut tunnel = structure(10, "tunnel", 0.0);
    tunnel.inside = vec![1, 2];
    let mut f = Field::new(s, vec![Actor::Structure(Box::new(tunnel))]);
    assert_eq!(f.step(0.1).unwrap(), Update::default());
    assert_eq!(f.a.structure(10).unwrap().inside, [1, 2]);
    f.a = Actors::restore(&f.a.checkpoint().unwrap()).unwrap();
    f.step(0.1).unwrap();
    assert_eq!(f.a.structure(10).unwrap().inside, [2]);
    assert_eq!(
        f.a.soldier(1).unwrap().motion.position,
        Vector3::new(11.0, 0.0, 3.0)
    );
}

#[test]
fn treatment_revives_before_scattering_the_return_route() {
    let s = soldier(HiddenReason::Tent);
    let tent = structure(10, "medic_tent", 0.0);
    let mut wrecked = structure(11, "fob", 3.0);
    wrecked.wrecked = true;
    let mut unfinished = structure(12, "fob", 1.0);
    unfinished.built = false;
    let mut enemy = structure(13, "fob", 2.0);
    enemy.team = 1;
    let base = structure(14, "fob", 20.0);
    let mut f = Field::new(
        s,
        vec![tent, wrecked, unfinished, enemy, base]
            .into_iter()
            .map(|s| Actor::Structure(Box::new(s)))
            .collect(),
    );
    let mut random = f.rng;
    let cue = (random.randi() % 4) as u8;
    let destination = Vector3::X * 20.0
        + Vector3::new(
            random.randf_range(-5.0, 5.0),
            0.0,
            random.randf_range(-5.0, 5.0),
        );
    let out = f.step(0.1).unwrap();
    assert_eq!(out.events[0], Event::Stat("out_of_tent"));
    assert_eq!(out.events[1], Event::Revived(cue));
    let Event::Route(route) = out.events[2] else {
        panic!()
    };
    assert_eq!(route.job.destination, destination);
    assert_eq!(out.events[3], Event::PatchedUp);
    let s = f.a.soldier(1).unwrap();
    assert_eq!(s.vitals.hp, 80.0);
    assert_eq!(s.weapon.magazine, 30);
    assert_eq!(s.duty.kind, Task::Limp);
    assert_eq!(f.rng.state(), random.state());
}

#[test]
fn a_removed_tent_and_no_base_use_the_patient_position_without_scatter_draws() {
    let mut s = soldier(HiddenReason::Tent);
    s.motion.position = Vector3::new(3.0, -0.4, 6.0);
    let mut f = Field::new(s, vec![]);
    let mut random = f.rng;
    random.randi();
    let out = f.step(0.1).unwrap();
    let Event::Route(route) = out.events[2] else {
        panic!()
    };
    assert_eq!(route.job.destination, Vector3::new(3.0, 0.0, 6.0));
    assert_eq!(f.rng.state(), random.state());
}

#[test]
fn completed_prisoners_leave_the_registry_without_reusing_their_identity() {
    for reason in [HiddenReason::Interrogation, HiddenReason::Held] {
        let mut f = Field::new(soldier(reason), vec![]);
        let out = f.step(0.1).unwrap();
        assert!(f.a.soldier(1).is_none() && f.squads[0].members.is_empty());
        assert_eq!(f.squads[0].centroid_at, 3.0);
        let removed = out.removed.unwrap();
        assert!(removed.identity.gone);
        assert_eq!(removed.identity.squad, 9);
        assert_eq!(f.a.entities().next_id(), 100);
    }
}

#[test]
fn waiting_states_renew_only_after_the_deadline_and_bad_input_is_atomic() {
    for reason in [HiddenReason::Waiting, HiddenReason::TunnelWait] {
        let mut s = soldier(reason);
        s.control.hidden_timer = 0.2;
        let mut f = Field::new(s, vec![]);
        let before = f.a.checkpoint().unwrap();
        assert!(f.step(f64::NAN).is_err());
        assert_eq!(f.a.checkpoint().unwrap(), before);
        f.step(0.1).unwrap();
        assert_eq!(f.a.soldier(1).unwrap().control.hidden_timer, 0.1);
        f.step(0.1).unwrap();
        assert_eq!(f.a.soldier(1).unwrap().control.hidden_timer, 9999.0);
    }
}
