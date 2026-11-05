use crate::actors::ActorStateCore;
use crate::battle_stats::BattleStatsCore;
use frontline_core::economy::Economy;
use frontline_core::production_orders::{Item, Outcome, Research};
use godot::prelude::*;
fn read<T: FromGodot>(a: &Array<Variant>, i: usize) -> Option<T> {
    a.get(i)?.try_to().ok()
}
fn string(a: &Array<Variant>, i: usize) -> Option<String> {
    Some(read::<GString>(a, i)?.to_string())
}
#[derive(GodotClass)]
#[class(base=RefCounted,init)]
struct ProductionOrdersCore {
    base: Base<RefCounted>,
}
#[godot_api]
impl ProductionOrdersCore {
    #[func]
    fn request(
        &self,
        mut actors: Gd<ActorStateCore>,
        mut battle: Gd<BattleStatsCore>,
        id: u32,
        peer: i32,
        team: i8,
        cancel: bool,
        input: Array<Variant>,
    ) -> Array<Variant> {
        let parse = || -> Option<_> {
            if input.len() != 4 {
                return None;
            }
            let upgrades: Array<Variant> = read(&input, 0)?;
            let item: Array<Variant> = read(&input, 1)?;
            let produces: PackedStringArray = read(&input, 2)?;
            let research: Array<Variant> = read(&input, 3)?;
            if upgrades.len() != 2
                || item.len() != 8
                || produces.len() > 4096
                || research.len() > 4096
            {
                return None;
            }
            let mut economy = Economy::default();
            for (i, side) in upgrades.iter_shared().enumerate() {
                let keys: PackedStringArray = side.try_to().ok()?;
                if keys.len() > 4096 {
                    return None;
                }
                economy.upgrades[i] = keys.as_slice().iter().map(ToString::to_string).collect();
            }
            if !economy.valid() {
                return None;
            }
            let p = Item {
                key: string(&item, 0)?,
                name: string(&item, 1)?,
                cost: read(&item, 2)?,
                time: read(&item, 3)?,
                tier: read(&item, 4)?,
                research: read(&item, 5)?,
                teams: read(&item, 6)?,
                requires: string(&item, 7)?,
            };
            let mut r = Vec::new();
            for value in research.iter_shared() {
                let row: Array<Variant> = value.try_to().ok()?;
                if row.len() != 4 {
                    return None;
                }
                r.push(Research {
                    key: string(&row, 0)?,
                    name: string(&row, 1)?,
                    teams: read(&row, 2)?,
                    tier: read(&row, 3)?,
                });
            }
            let produces: Vec<_> = produces
                .as_slice()
                .iter()
                .map(ToString::to_string)
                .collect();
            Some((economy, p, produces, r))
        };
        let Some((e, p, produces, r)) = parse() else {
            return varray![];
        };
        let result = if cancel {
            e.cancel_production(
                &mut actors.bind_mut().core,
                &mut battle.bind_mut().core,
                id,
                team,
            )
        } else {
            e.order_production(
                &mut actors.bind_mut().core,
                &mut battle.bind_mut().core,
                id,
                peer,
                team,
                &p,
                &produces,
                &r,
            )
        };
        match result {
            Ok(Outcome::Ignored) => varray![0],
            Ok(Outcome::Changed) => varray![1],
            Ok(Outcome::Warning { peer, text }) => varray![2, peer, &GString::from(&text)],
            Err(_) => varray![],
        }
    }
}
