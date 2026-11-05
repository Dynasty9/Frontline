#[path = "squad_brain_world.rs"]
#[allow(dead_code)]
mod brain;
#[path = "squad_movement_world.rs"]
#[allow(dead_code)]
mod movement;
use brain::{contact, Scene};
use frontline_core::ambush_plan::AmbushPlan;
use frontline_core::attack_plan::AttackPlan;
use frontline_core::battle_stats::{BattleStats, Unit};
use frontline_core::infantry_vitals::Life;
use frontline_core::infantry_weapon::Weapon;
use frontline_core::squad::{Report, Squad};
use frontline_core::squad_duties::Role;
use frontline_core::squad_world::{Event, Profiles, Tick};
use frontline_core::structure::Structure;
use frontline_core::vector::Vector3;
use frontline_core::visibility::Visibility;
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
struct Field {
    s: Scene,
    attacks: Vec<AttackPlan>,
    ambushes: Vec<AmbushPlan>,
    battle: BattleStats,
}
fn field(trial: u64) -> Field {
    let mut s = Scene::new(43171 + trial);
    let team = (trial / 16) as i8;
    s.squads[0].team = team;
    s.squads[0].morale = 70.;
    for id in 1..=6 {
        s.change(id, |m| {
            m.identity.team = team;
            m.weapon.magazine = 30;
            m.weapon.reserve = 170;
            m.fight.smokes = 1;
        });
    }
    let mut attacks = vec![];
    let mut ambushes = vec![];
    match trial % 16 {
        0 => {
            s.change(1, |m| m.vitals.life = Life::Downed);
            contact(&mut s, 40.);
        }
        1 => {
            s.change(2, |m| m.vitals.hp = 30.);
            s.change(3, |m| m.vitals.hp = 20.);
        }
        2 => {
            s.geometry
                .spawn_structure(
                    &mut s.actors,
                    Structure {
                        kind: "hesco".into(),
                        team,
                        position: Vector3::new(-15., 0., 7.),
                        hp: 50.,
                        max_hp: 100.,
                        ..Default::default()
                    },
                    None,
                )
                .unwrap();
        }
        3 | 4 => {
            s.squads[0].morale = if trial % 16 == 3 { 25. } else { 2. };
            contact(&mut s, 45.);
        }
        5 => {
            ambushes.push(
                AmbushPlan::make(
                    &mut s.context(),
                    19,
                    7,
                    Vector3::ZERO,
                    Vector3::Z,
                    Vector3::NEG_X,
                )
                .unwrap()
                .0,
            );
        }
        6 => {
            attacks.push(
                s.context()
                    .order_assault(
                        7,
                        Vector3::new(30., 0., 7.),
                        Vector3::X,
                        17,
                        &Visibility::default(),
                    )
                    .unwrap()
                    .0
                    .unwrap(),
            );
        }
        7 => {
            s.context()
                .order_move(7, Vector3::new(30., 0., 5.), Vector3::X, 0, true)
                .unwrap();
            s.squads[0].morale = -1.;
        }
        8 => s.squads[0].think_timer = 2.,
        9 => {
            contact(&mut s, 30.);
            s.squads[0].known[0].report.time = 70.;
            for id in 1..=6 {
                s.change(id, |m| m.vitals.life = Life::Downed);
            }
        }
        10 => {
            let c = s.squads[0].centroid(s.now, &s.actors);
            s.squads[0].impacts = vec![
                Report {
                    position: c,
                    time: 99.,
                },
                Report {
                    position: c + Vector3::Z,
                    time: 99.5,
                },
            ];
        }
        11 => s.squads[0].kind = "crew".into(),
        12 => {
            s.change(2, |m| m.vitals.life = Life::Dead);
            let mut q = Squad::new(8, team, 1, "rifle_squad".into()).unwrap();
            q.leader = 3;
            for id in 3..=6 {
                s.squads[0].remove_member(id, &mut s.actors).unwrap();
                q.add_member(id, &mut s.actors).unwrap();
            }
            s.squads.push(q);
        }
        13 => {
            let c = s.squads[0].centroid(s.now, &s.actors);
            s.squads[0].order = "move".into();
            s.squads[0].clear_call = Some((3, 100.5));
            s.squads[0].then_defend = Some([c, Vector3::NEG_Z]);
        }
        14 => {
            contact(&mut s, 20.);
            for id in 2..=6 {
                s.change(id, |m| m.vitals.life = Life::Dead);
            }
            s.change(1, |m| m.vitals.suppression = 60.);
        }
        15 => {
            for id in 1..=6 {
                s.change(id, |m| m.vitals.life = Life::Dead);
            }
        }
        _ => unreachable!(),
    }
    let mut battle = BattleStats::default();
    for q in &s.squads {
        battle
            .register_unit(Unit {
                key: format!("s{}", q.id),
                name: "Test".into(),
                kind: "Squad".into(),
                team,
                owner: 1,
                men: q.members.len() as u32,
                ..Default::default()
            })
            .unwrap();
    }
    s.actors.rebuild_units(&mut s.units).unwrap();
    s.geometry.tick_cover(100_000).unwrap();
    s.geometry.navigation.finalize(1);
    Field {
        s,
        attacks,
        ambushes,
        battle,
    }
}
fn advance(f: &mut Field, tick: u32) -> Vec<Event> {
    f.s.now = 100. + tick as f64 * 0.25;
    if tick == 3 && !f.ambushes.is_empty() {
        let at = f.ambushes[0].rally;
        for id in 1..=6 {
            f.s.change(id, |m| m.motion.position = at);
        }
        if let Some(q) = f.s.squads.first_mut() {
            q.centroid_at = -1.;
        }
        f.s.actors.rebuild_units(&mut f.s.units).unwrap();
    }
    let mut out = vec![];
    let ids: Vec<_> = f.s.squads.iter().map(|q| q.id).collect();
    for id in ids {
        let events =
            f.s.context()
                .squad_tick(
                    id,
                    0.25,
                    &mut Tick {
                        attacks: &mut f.attacks,
                        ambushes: &mut f.ambushes,
                        battle: &mut f.battle,
                        impacts: &[],
                    },
                    &profile(),
                )
                .unwrap();
        for e in &events {
            if let Event::Removed(id) = e {
                f.s.squads.retain(|q| q.id != *id);
            }
        }
        out.extend(events);
    }
    f.s.geometry
        .navigation
        .process_paths(
            &mut f.s.actors,
            3,
            f.s.now,
            &mut f.s.rng,
            frontline_core::traversal::Ground::new(&f.s.geometry.terrain, &f.s.geometry.deck),
        )
        .unwrap();
    out
}
fn state_list<'a>(states: impl Iterator<Item = Vec<u8>>) -> Vec<u8> {
    let mut out = vec![];
    for b in states {
        out.extend_from_slice(&(b.len() as u32).to_le_bytes());
        out.extend_from_slice(&b);
    }
    out
}
pub fn transcript() -> Vec<u8> {
    let mut out = vec![];
    let mut previous = vec![vec![]; 9];
    for trial in 0..32 {
        let mut a = field(trial);
        let mut b = field(trial);
        for tick in 0..8 {
            b.s.resume();
            b.battle = BattleStats::restore(&b.battle.checkpoint()).unwrap();
            for p in &mut b.attacks {
                *p = AttackPlan::restore(&p.checkpoint().unwrap()).unwrap();
            }
            for p in &mut b.ambushes {
                *p = AmbushPlan::restore(&p.checkpoint().unwrap()).unwrap();
            }
            let events = advance(&mut a, tick);
            assert_eq!(events, advance(&mut b, tick));
            assert_eq!(
                a.s.actors.checkpoint().unwrap(),
                b.s.actors.checkpoint().unwrap()
            );
            assert_eq!(a.s.squads, b.s.squads);
            assert_eq!(a.s.geometry.checkpoint(), b.s.geometry.checkpoint());
            assert_eq!(a.s.rng.state(), b.s.rng.state());
            assert_eq!(a.attacks, b.attacks);
            assert_eq!(a.ambushes, b.ambushes);
            assert_eq!(a.battle, b.battle);
            let e = format!("{trial}/{tick} {events:?}").into_bytes();
            out.extend_from_slice(&(e.len() as u32).to_le_bytes());
            out.extend_from_slice(&e);
            for (last, state) in previous.iter_mut().zip([
                a.s.actors.checkpoint().unwrap(),
                state_list(a.s.squads.iter().map(|q| q.checkpoint().unwrap())),
                a.s.geometry.navigation.planner.checkpoint(),
                a.s.geometry.navigation.infantry.checkpoint(),
                a.s.geometry.navigation.vehicles.checkpoint(),
                a.s.units.checkpoint(),
                a.battle.checkpoint(),
                state_list(a.attacks.iter().map(|p| p.checkpoint().unwrap())),
                state_list(a.ambushes.iter().map(|p| p.checkpoint().unwrap())),
            ]) {
                movement::checkpoint_delta(&mut out, last, state);
            }
            out.extend_from_slice(&a.s.rng.state().to_le_bytes());
        }
    }
    out
}
