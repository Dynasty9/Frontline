#[allow(dead_code)]
#[path = "squad_movement_world.rs"]
mod movement;
use frontline_core::actors::{Actor, Actors};
use frontline_core::battle_stats::BattleStats;
use frontline_core::random::SimulationRandom;
use frontline_core::structure::Structure;
use frontline_core::support::Gunset;
use frontline_core::support_calls::{Definition, Event, Sortie, SupportCalls};
use frontline_core::vector::Vector3;
fn update(
    s: &mut SupportCalls,
    a: &mut Actors,
    b: &mut BattleStats,
    r: &mut SimulationRandom,
    p: &Definition<'_>,
    trial: usize,
    step: usize,
) -> Vec<Event> {
    let now = [
        299.99, 300., 300.01, 390., 391., 391.5, 392., 394., 400., 420.,
    ][step];
    let mut events = vec![];
    if step < 4 {
        let pos = Vector3::new(step as f32 * 4.3 - 8.1, 3.7, trial as f32 * 7.1 - 10.4);
        let dir = [
            Vector3::ZERO,
            Vector3::new(1., 2., 3.),
            Vector3::Y,
            Vector3::new(-1., 0., 2.),
        ][step];
        if trial % 4 == 3 {
            events = s.demo(a, r, now, pos, dir, p, 2048).unwrap();
        } else {
            let team = if trial % 4 == 2 { 1 } else { 0 };
            let peer = if trial % 4 == 1 { -1 } else { 7 };
            events = s
                .call(a, b, r, now, peer, team, pos, dir, p, 2048)
                .unwrap()
                .1;
        }
    }
    events.extend(s.advance(a, r, now).unwrap());
    events
}
pub fn transcript() -> Vec<u8> {
    let mut out = vec![];
    for trial in 0..8 {
        for sortie in [
            Sortie::Recon,
            Sortie::Watch,
            Sortie::Jet,
            Sortie::GunRun,
            Sortie::Orbit,
            Sortie::Artillery,
            Sortie::Barrage,
            Sortie::Mortars,
            Sortie::Smoke,
        ] {
            let p = Definition {
                key: "support",
                name: "Test Aircraft Strike",
                model: "test_model",
                team: 0,
                cost: 100,
                from: 300.,
                cooldown: 90.,
                radius: 20.,
                sortie,
                quiet: trial % 2 == 0,
                leg: 420.,
                altitude: 60.,
                speed: 90.,
                sight: 85.,
                stay: 60.,
                bombs: 4,
                guns: [
                    Gunset::Ac130,
                    Gunset::Blackfish,
                    Gunset::Xian,
                    Gunset::Greyhawk,
                ][trial % 4],
                muzzles: [
                    Vector3::new(-1.7, -0.3, 2.1),
                    Vector3::new(-1.6, -0.2, 0.1),
                    Vector3::new(-1.5, -0.1, -2.1),
                ],
            };
            let mut a = Actors::from_entries(
                100,
                vec![Actor::Structure(Box::new(Structure {
                    id: 1,
                    kind: "fob".into(),
                    team: 0,
                    built: true,
                    supply: if trial % 4 == 1 { 5. } else { 1000. },
                    ..Default::default()
                }))],
            )
            .unwrap();
            let mut b = BattleStats::default();
            let mut r = SimulationRandom::new(3917 + trial as u64);
            let mut s = SupportCalls::default();
            let mut previous: [Vec<u8>; 4] = std::array::from_fn(|_| vec![]);
            for step in 0..10 {
                let mut sa = SupportCalls::restore(&s.checkpoint().unwrap()).unwrap();
                let mut aa = Actors::restore(&a.checkpoint().unwrap()).unwrap();
                let mut ba = BattleStats::restore(&b.checkpoint()).unwrap();
                let mut ra = r;
                let events = update(&mut s, &mut a, &mut b, &mut r, &p, trial, step);
                assert_eq!(
                    events,
                    update(&mut sa, &mut aa, &mut ba, &mut ra, &p, trial, step)
                );
                let state = [
                    s.checkpoint().unwrap(),
                    a.checkpoint().unwrap(),
                    b.checkpoint(),
                    r.state().to_le_bytes().to_vec(),
                ];
                assert_eq!(
                    state,
                    [
                        sa.checkpoint().unwrap(),
                        aa.checkpoint().unwrap(),
                        ba.checkpoint(),
                        ra.state().to_le_bytes().to_vec()
                    ]
                );
                for (before, after) in previous.iter_mut().zip(state) {
                    movement::checkpoint_delta(&mut out, before, after);
                }
                let text = format!("{trial}/{sortie:?}/{step} {events:?}").into_bytes();
                out.extend_from_slice(&(text.len() as u32).to_le_bytes());
                out.extend_from_slice(&text);
            }
        }
    }
    out
}
