use crate::actors::ActorStateCore;
use crate::battle_stats::BattleStatsCore;
use crate::simulation_random::SimulationRandomCore;
use frontline_core::projectile::Kind;
use frontline_core::support::Gunset;
use frontline_core::support_calls::{Definition, Event, Salvo, Sortie, SupportCalls};
use godot::prelude::*;
fn read<T: FromGodot>(a: &Array<Variant>, i: usize) -> Option<T> {
    a.get(i)?.try_to().ok()
}
fn vector(p: frontline_core::vector::Vector3) -> Vector3 {
    Vector3::new(p.x, p.y, p.z)
}
pub(crate) fn events(out: Vec<Event>) -> Array<Variant> {
    out.into_iter()
        .map(|e| match e {
            Event::Warn { peer, text } => varray![0, peer, &GString::from(&text)].to_variant(),
            Event::Mark { position, radius } => varray![1, vector(position), radius].to_variant(),
            Event::Stat(key) => varray![2, &GString::from(&key)].to_variant(),
            Event::Born { id, model } => varray![3, id, &GString::from(&model)].to_variant(),
            Event::Message {
                team,
                alert,
                text,
                position,
            } => varray![
                4,
                i32::from(team),
                alert,
                &GString::from(&text),
                vector(position)
            ]
            .to_variant(),
            Event::Sound { name, position } => varray![5, name, vector(position)].to_variant(),
        })
        .collect()
}
#[derive(GodotClass)]
#[class(base=RefCounted, init)]
struct SupportCallsCore {
    base: Base<RefCounted>,
    core: SupportCalls,
}
#[godot_api]
impl SupportCallsCore {
    #[func]
    fn load_state(&mut self, input: Array<Variant>) -> bool {
        let parse = || -> Option<SupportCalls> {
            if input.len() != 2 {
                return None;
            }
            let ready: Array<Variant> = read(&input, 0)?;
            let queue: Array<Variant> = read(&input, 1)?;
            if ready.len() != 2 || queue.len() > 100_000 {
                return None;
            }
            let mut out = SupportCalls::default();
            for (i, side) in ready.iter_shared().enumerate() {
                let rows: Array<Variant> = side.try_to().ok()?;
                if rows.len() > 100_000 {
                    return None;
                }
                for row in rows.iter_shared() {
                    let row: Array<Variant> = row.try_to().ok()?;
                    if row.len() != 2 {
                        return None;
                    }
                    out.ready[i].push((read::<GString>(&row, 0)?.to_string(), read(&row, 1)?));
                }
            }
            for row in queue.iter_shared() {
                let row: Array<Variant> = row.try_to().ok()?;
                if row.len() != 7 {
                    return None;
                }
                out.queue.push(Salvo {
                    at: read(&row, 0)?,
                    kind: Kind::parse(&read::<GString>(&row, 1)?.to_string())?,
                    team: read(&row, 2)?,
                    position: crate::point(read(&row, 3)?),
                    radius: read(&row, 4)?,
                    back: crate::point(read(&row, 5)?),
                    called_by: read(&row, 6)?,
                });
            }
            out.valid().then_some(out)
        };
        if let Some(out) = parse() {
            self.core = out;
            true
        } else {
            false
        }
    }
    #[func]
    fn values(&self) -> Array<Variant> {
        let ready: Array<Variant> = self
            .core
            .ready
            .iter()
            .map(|s| {
                s.iter()
                    .map(|(k, t)| varray![&GString::from(k.as_str()), *t].to_variant())
                    .collect::<Array<Variant>>()
                    .to_variant()
            })
            .collect();
        let queue: Array<Variant> = self
            .core
            .queue
            .iter()
            .map(|q| {
                varray![
                    q.at,
                    match q.kind {
                        Kind::Arty => "arty",
                        Kind::Grad => "grad",
                        Kind::Mortar => "mortar",
                        _ => "mortar_smoke",
                    },
                    i32::from(q.team),
                    vector(q.position),
                    q.radius,
                    vector(q.back),
                    q.called_by
                ]
                .to_variant()
            })
            .collect();
        varray![&ready, &queue]
    }
    #[func]
    fn request(
        &mut self,
        mut actors: Gd<ActorStateCore>,
        mut battle: Gd<BattleStatsCore>,
        mut rng: Gd<SimulationRandomCore>,
        now: f64,
        peer: i32,
        team: i32,
        position: Vector3,
        direction: Vector3,
        definition: Array<Variant>,
        map_side: u32,
        demo: bool,
    ) -> Array<Variant> {
        let parse = || -> Option<_> {
            let a = &definition;
            if a.len() != 18 {
                return None;
            }
            let key = read::<GString>(a, 0)?.to_string();
            let name = read::<GString>(a, 1)?.to_string();
            let model = read::<GString>(a, 2)?.to_string();
            let team: i8 = read(a, 3)?;
            let cost: i32 = read(a, 4)?;
            let from: f64 = read(a, 5)?;
            let cooldown: f64 = read(a, 6)?;
            let radius: f64 = read(a, 7)?;
            let sortie = match read::<GString>(a, 8)?.to_string().as_str() {
                "recon" => Sortie::Recon,
                "watch" => Sortie::Watch,
                "jet" => Sortie::Jet,
                "a10" => Sortie::GunRun,
                "orbit" => Sortie::Orbit,
                "artillery" => Sortie::Artillery,
                "barrage" => Sortie::Barrage,
                "mortars" => Sortie::Mortars,
                "smoke" => Sortie::Smoke,
                _ => return None,
            };
            let quiet: bool = read(a, 9)?;
            let leg: f64 = read(a, 10)?;
            let altitude: f64 = read(a, 11)?;
            let speed: f64 = read(a, 12)?;
            let sight: f64 = read(a, 13)?;
            let stay: f64 = read(a, 14)?;
            let bombs: u32 = read(a, 15)?;
            let guns = Gunset::parse(&read::<GString>(a, 16)?.to_string());
            let muzzles: PackedVector3Array = read(a, 17)?;
            if muzzles.len() != 3 {
                return None;
            }
            Some((
                key,
                name,
                model,
                team,
                cost,
                from,
                cooldown,
                radius,
                sortie,
                quiet,
                leg,
                altitude,
                speed,
                sight,
                stay,
                bombs,
                guns,
                [
                    crate::point(muzzles[0]),
                    crate::point(muzzles[1]),
                    crate::point(muzzles[2]),
                ],
            ))
        };
        let Some((
            key,
            name,
            model,
            pteam,
            cost,
            from,
            cooldown,
            radius,
            sortie,
            quiet,
            leg,
            altitude,
            speed,
            sight,
            stay,
            bombs,
            guns,
            muzzles,
        )) = parse()
        else {
            return Array::new();
        };
        let Ok(team) = i8::try_from(team) else {
            return Array::new();
        };
        let p = Definition {
            key: &key,
            name: &name,
            model: &model,
            team: pteam,
            cost,
            from,
            cooldown,
            radius,
            sortie,
            quiet,
            leg,
            altitude,
            speed,
            sight,
            stay,
            bombs,
            guns,
            muzzles,
        };
        let mut actors = actors.bind_mut();
        let mut rng = rng.bind_mut();
        let result = if demo {
            self.core
                .demo(
                    &mut actors.core,
                    &mut rng.core,
                    now,
                    crate::point(position),
                    crate::point(direction),
                    &p,
                    map_side,
                )
                .map(|e| (true, e))
        } else {
            self.core.call(
                &mut actors.core,
                &mut battle.bind_mut().core,
                &mut rng.core,
                now,
                peer,
                team,
                crate::point(position),
                crate::point(direction),
                &p,
                map_side,
            )
        };
        result.map_or_else(|_| Array::new(), |(ok, e)| varray![ok, &events(e)])
    }
    #[func]
    fn advance(
        &mut self,
        mut actors: Gd<ActorStateCore>,
        mut rng: Gd<SimulationRandomCore>,
        now: f64,
    ) -> Array<Variant> {
        self.core
            .advance(&mut actors.bind_mut().core, &mut rng.bind_mut().core, now)
            .map_or_else(|_| Array::new(), |out| varray![&events(out)])
    }
    #[func]
    fn checkpoint(&self) -> PackedByteArray {
        self.core
            .checkpoint()
            .map_or_else(|_| PackedByteArray::new(), |b| b.as_slice().into())
    }
    #[func]
    fn restore(&mut self, bytes: PackedByteArray) -> bool {
        if let Ok(core) = SupportCalls::restore(bytes.as_slice()) {
            self.core = core;
            true
        } else {
            false
        }
    }
}
