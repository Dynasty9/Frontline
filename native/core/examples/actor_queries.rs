//! Run with cargo run --release -p frontline_core --example actor_queries.
use frontline_core::actors::{Actor, Actors};
use frontline_core::entities::Kind;
use frontline_core::infantry::Infantry;
use frontline_core::projectile_actor::{ballistic, Motion, Projectile};
use frontline_core::structure::Structure;
use frontline_core::vector::Vector3;
use std::hint::black_box;
use std::time::Instant;

fn main() {
    let mut entries = Vec::new();
    for id in 1..=10_000 {
        entries.push(Actor::Structure(Box::new(Structure {
            id,
            kind: "low_wall".into(),
            ..Default::default()
        })));
    }
    for id in 10_001..=10_500 {
        let mut s = Infantry::default();
        s.identity.id = id;
        s.identity.unit = "rifleman".into();
        entries.push(Actor::Soldier(Box::new(s)));
    }
    for id in 10_501..=10_548 {
        entries.push(Actor::Projectile(Projectile {
            id,
            team: 0,
            thrower: 0,
            called_by: 0,
            held_by: 0,
            smothered_by: 0,
            handler: 0,
            thrown_back: 0,
            target_id: 0,
            motion: Motion::Ballistic(ballistic(
                frontline_core::projectile::Kind::Frag,
                Vector3::ZERO,
                Vector3::ZERO,
            )),
        }));
    }
    let actors = Actors::from_entries(10_549, entries).unwrap();
    let expected: u64 = (10_501..=10_548).sum::<u64>() * 2_000;
    for sample in 0..6 {
        for typed in if sample % 2 == 0 {
            [false, true]
        } else {
            [true, false]
        } {
            let begin = Instant::now();
            let mut sum = 0u64;
            for _ in 0..2_000 {
                let actors = black_box(&actors);
                if typed {
                    for actor in actors.iter_kind(Kind::Projectile) {
                        sum = sum.wrapping_add(u64::from(black_box(actor).identity().id));
                    }
                } else {
                    for actor in actors.iter() {
                        if let Actor::Projectile(p) = black_box(actor) {
                            sum = sum.wrapping_add(u64::from(p.id));
                        }
                    }
                }
            }
            assert_eq!(sum, expected);
            println!("sample={sample} typed={typed} queries=2000 scenery=10000 soldiers=500 rounds=48 elapsed_ms={:.3}",begin.elapsed().as_secs_f64()*1000.0);
        }
    }
}
