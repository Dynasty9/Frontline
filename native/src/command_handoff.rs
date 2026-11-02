use crate::actors::ActorStateCore;
use crate::battle_stats::BattleStatsCore;
use crate::squad::SquadStateCore;
use frontline_core::command_ownership::Ownership;
use frontline_core::economy::Economy;
use godot::prelude::*;
fn read<T: FromGodot>(a: &Array<Variant>, i: usize) -> Option<T> {
    a.get(i)?.try_to().ok()
}
fn ids(a: PackedInt64Array) -> Option<Vec<u32>> {
    if a.len() > 100_000 {
        return None;
    }
    a.as_slice()
        .iter()
        .map(|&v| u32::try_from(v).ok())
        .collect()
}
fn packed(a: &[u32]) -> PackedInt64Array {
    a.iter().map(|&i| i64::from(i)).collect()
}
#[derive(GodotClass)]
#[class(base=RefCounted,init)]
struct CommandOwnershipCore {
    base: Base<RefCounted>,
    core: Ownership,
}
#[godot_api]
impl CommandOwnershipCore {
    #[func]
    fn load_state(&mut self, input: Array<Variant>) -> bool {
        if let Some((_, core)) = crate::production::state(&input) {
            self.core = core;
            true
        } else {
            false
        }
    }
    #[func]
    fn values(&self) -> Array<Variant> {
        crate::production::values(&Economy::default(), &self.core)
    }
    #[func]
    fn checkpoint(&self) -> PackedByteArray {
        PackedByteArray::from(self.core.checkpoint().unwrap().as_slice())
    }
    #[func]
    fn restore(&mut self, bytes: PackedByteArray) -> bool {
        if let Ok(core) = Ownership::restore(bytes.as_slice()) {
            self.core = core;
            true
        } else {
            false
        }
    }
    #[func]
    fn join_peer(&mut self, peer: i32, team: i8) -> bool {
        self.core.connect(peer, team).is_ok()
    }
    #[func]
    fn select(
        &self,
        actors: Gd<ActorStateCore>,
        squads: Array<Gd<SquadStateCore>>,
        peer: i32,
        squad_ids: PackedInt64Array,
        vehicle_ids: PackedInt64Array,
        automatic: PackedStringArray,
    ) -> Array<Variant> {
        let run = || -> Option<Array<Variant>> {
            if squads.len() > 100_000 || automatic.len() > 4096 {
                return None;
            }
            let a = actors.bind();
            let qs: Option<Vec<_>> = squads
                .iter_shared()
                .map(|q| q.bind().core.clone())
                .collect();
            let qs = qs?;
            let automatic: Vec<_> = automatic
                .as_slice()
                .iter()
                .map(ToString::to_string)
                .collect();
            let s = self.core.select_squads(peer, &ids(squad_ids)?, &qs).ok()?;
            let v = self
                .core
                .select_vehicles(peer, &ids(vehicle_ids)?, &a.core, &|key| {
                    automatic.iter().any(|k| k == key)
                })
                .ok()?;
            Some(varray![&packed(&s), &packed(&v)])
        };
        run().unwrap_or_default()
    }
    #[func]
    fn advance(
        &mut self,
        mut actors: Gd<ActorStateCore>,
        squads: Array<Gd<SquadStateCore>>,
        mut battle: Gd<BattleStatsCore>,
        request: Array<Variant>,
        automatic: PackedStringArray,
    ) -> Array<Variant> {
        let mut run = || -> Option<Array<Variant>> {
            if request.len() != 7 || squads.len() > 100_000 || automatic.len() > 4096 {
                return None;
            }
            let op: u8 = read(&request, 0)?;
            let peer: i32 = read(&request, 1)?;
            let old: i32 = read(&request, 2)?;
            let name: GString = read(&request, 3)?;
            let stand: bool = read(&request, 4)?;
            let s = ids(read(&request, 5)?)?;
            let v = ids(read(&request, 6)?)?;
            let qs: Option<Vec<_>> = squads
                .iter_shared()
                .map(|q| q.bind().core.clone())
                .collect();
            let mut qs = qs?;
            let automatic: Vec<_> = automatic
                .as_slice()
                .iter()
                .map(ToString::to_string)
                .collect();
            let mut a = actors.bind_mut();
            let mut b = battle.bind_mut();
            let (meta, changed) = match op {
                0 => (
                    varray![1],
                    self.core
                        .take_command(peer, &s, &v, &mut qs, &mut a.core)
                        .ok()?,
                ),
                1 => match self.core.depart(peer, &mut qs, &mut a.core).ok()? {
                    Some((team, heir, c)) => (varray![1, i32::from(team), heir], c),
                    None => (varray![0], Default::default()),
                },
                2 => {
                    let (count, c) = self
                        .core
                        .reclaim(
                            peer,
                            old,
                            &name.to_string(),
                            &mut qs,
                            &mut a.core,
                            &mut b.core,
                            stand,
                            &|key| automatic.iter().any(|k| k == key),
                        )
                        .ok()?;
                    (varray![count], c)
                }
                _ => return None,
            };
            let states: Array<Variant> = qs
                .iter()
                .map(|q| PackedByteArray::from(q.checkpoint().unwrap().as_slice()).to_variant())
                .collect();
            let changed = varray![
                &packed(&changed.squads),
                &packed(&changed.vehicles),
                &packed(&changed.soldiers)
            ];
            Some(varray![&meta, &states, &changed])
        };
        run().unwrap_or_default()
    }
}
