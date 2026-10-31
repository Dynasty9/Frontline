use crate::actors::ActorStateCore;
use crate::spatial::SpatialIndexCore;
use crate::squad::SquadStateCore;
use frontline_core::battle_stats::*;
use frontline_core::infantry::Credit;
use godot::prelude::*;

#[derive(GodotClass)]
#[class(base=RefCounted, init)]
pub(crate) struct BattleStatsCore {
    base: Base<RefCounted>,
    core: BattleStats,
}
fn counters(c: &Counters) -> PackedFloat64Array {
    c.as_slice().into()
}
fn players(p: &[Player]) -> Array<Variant> {
    p.iter()
        .map(|p| {
            varray![
                p.owner,
                p.team as i64,
                p.ai,
                p.name.as_str(),
                &counters(&p.counters)
            ]
            .to_variant()
        })
        .collect()
}
fn units(units: &[Unit]) -> Array<Variant> {
    units
        .iter()
        .map(|u| {
            varray![
                u.key.as_str(),
                u.name.as_str(),
                u.kind.as_str(),
                u.team as i64,
                u.owner,
                u.started,
                u.ended,
                u.men as i64,
                u.alive as i64,
                u.kills as i64,
                u.downs as i64,
                u.vehicle_kills as i64,
                u.lost as i64
            ]
            .to_variant()
        })
        .collect()
}
fn heroes(heroes: &[Hero]) -> Array<Variant> {
    heroes
        .iter()
        .map(|h| {
            varray![
                h.id as i64,
                h.name.as_str(),
                h.role.as_str(),
                h.team as i64,
                h.owner,
                h.unit.as_str(),
                h.kills as i64,
                h.vehicles as i64,
                h.alive
            ]
            .to_variant()
        })
        .collect()
}
fn timeline(rows: &[[f64; 9]]) -> Array<Variant> {
    rows.iter()
        .map(|r| PackedFloat64Array::from(r.as_slice()).to_variant())
        .collect()
}
fn events(events: &[Event]) -> Array<Variant> {
    events
        .iter()
        .map(|e| varray![e.time, e.team as i64, e.kind.as_str(), e.text.as_str()].to_variant())
        .collect()
}
fn credit(by: Option<&Credit>) -> Array<Variant> {
    by.map_or_else(Array::new, |c| {
        varray![c.owner, c.team as i64, c.unit.as_str(), c.soldier as i64]
    })
}
fn read_credit(a: &Array<Variant>) -> Option<Option<Credit>> {
    if a.is_empty() {
        return Some(None);
    }
    if a.len() != 4 {
        return None;
    }
    Some(Some(Credit {
        owner: a.get(0)?.try_to().ok()?,
        team: a.get(1)?.try_to().ok()?,
        unit: a.get(2)?.try_to::<GString>().ok()?.to_string(),
        soldier: a.get(3)?.try_to().ok()?,
    }))
}
fn squads(nodes: &Array<Gd<SquadStateCore>>) -> Option<Vec<frontline_core::squad::Squad>> {
    if nodes.len() > 100_000 {
        return None;
    }
    nodes.iter_shared().map(|q| q.bind().core.clone()).collect()
}

#[godot_api]
impl BattleStatsCore {
    #[func]
    fn checkpoint(&self) -> PackedByteArray {
        self.core.checkpoint().as_slice().into()
    }
    #[func]
    fn restore(&mut self, bytes: PackedByteArray) -> bool {
        match BattleStats::restore(bytes.as_slice()) {
            Ok(state) => {
                self.core = state;
                true
            }
            Err(_) => false,
        }
    }
    #[func]
    fn values(&self) -> Array<Variant> {
        let s = &self.core;
        varray![
            &players(&s.players),
            &varray![&counters(&s.sides[0]), &counters(&s.sides[1])],
            &units(&s.units),
            &heroes(&s.heroes),
            &timeline(&s.timeline),
            &events(&s.events),
            s.every,
            s.sample_timer,
            &credit(s.blame.as_ref())
        ]
    }
    #[func]
    fn joined(&mut self, owner: i32, team: i8, name: GString) -> bool {
        self.core.joined(owner, team, &name.to_string()).is_ok()
    }
    #[func]
    fn rejoined(&mut self, old: i32, now: i32, team: i8, name: GString) -> bool {
        self.core
            .rejoined(old, now, team, &name.to_string())
            .is_ok()
    }
    #[func]
    fn add(&mut self, owner: i32, team: i8, field: u32, amount: f64) -> bool {
        self.core.add(owner, team, field as usize, amount).is_ok()
    }
    #[func]
    fn shot(&mut self, owner: i32, team: i8, hit: bool) -> bool {
        self.core.shot(owner, team, hit).is_ok()
    }
    #[func]
    fn blame(&mut self, by: Array<Variant>) -> bool {
        read_credit(&by).is_some_and(|by| self.core.set_blame(by).is_ok())
    }
    #[func]
    fn record_hit(
        &mut self,
        id: u32,
        source: u32,
        amount: f64,
        mut actors: Gd<ActorStateCore>,
    ) -> bool {
        self.core
            .record_hit(id, source, amount, &mut actors.bind_mut().core)
            .is_ok()
    }
    #[func]
    fn soldier_down(&mut self, id: u32, bearer: bool, actors: Gd<ActorStateCore>) -> bool {
        actors
            .bind()
            .core
            .soldier(id)
            .is_some_and(|s| self.core.soldier_down(s, bearer).is_ok())
    }
    #[func]
    fn soldier_died(
        &mut self,
        id: u32,
        previous: u8,
        bearer: bool,
        value: f64,
        role: GString,
        actors: Gd<ActorStateCore>,
    ) -> bool {
        let Ok(previous) = previous.try_into() else {
            return false;
        };
        let actors = actors.bind();
        actors.core.soldier(id).is_some_and(|s| {
            self.core
                .soldier_died(s, previous, bearer, value, &actors.core, &role.to_string())
                .is_ok()
        })
    }
    #[func]
    fn prisoner(&mut self, id: u32, captor: u32, value: f64, actors: Gd<ActorStateCore>) -> bool {
        let actors = actors.bind();
        match (actors.core.soldier(id), actors.core.soldier(captor)) {
            (Some(p), Some(c)) => self.core.prisoner(p, c, value).is_ok(),
            _ => false,
        }
    }
    #[func]
    fn destroyed(
        &mut self,
        id: u32,
        vehicle: bool,
        value: f64,
        now: f64,
        description: GString,
        role: GString,
        actors: Gd<ActorStateCore>,
    ) -> bool {
        let actors = actors.bind();
        if vehicle {
            self.core
                .vehicle_destroyed(
                    id,
                    value,
                    now,
                    &description.to_string(),
                    &role.to_string(),
                    &actors.core,
                )
                .is_ok()
        } else {
            self.core
                .building_destroyed(id, value, now, &description.to_string(), &actors.core)
                .is_ok()
        }
    }
    #[func]
    fn register_unit(
        &mut self,
        key: GString,
        name: GString,
        kind: GString,
        team: i8,
        owner: i32,
        now: f64,
        alive: u32,
    ) -> bool {
        self.core
            .register_unit(Unit {
                key: key.to_string(),
                name: name.to_string(),
                kind: kind.to_string(),
                team,
                owner,
                started: now,
                ended: -1.0,
                alive,
                ..Default::default()
            })
            .is_ok()
    }
    #[func]
    fn squad_grew(&mut self, q: Gd<SquadStateCore>) -> bool {
        if let Some(q) = &q.bind().core {
            self.core.squad_grew(q);
            true
        } else {
            false
        }
    }
    #[func]
    fn squad_gone(&mut self, id: u32, now: f64) -> bool {
        self.core.squad_gone(id, now).is_ok()
    }
    #[func]
    fn taker(
        &self,
        position: Vector3,
        radius: f64,
        team: i8,
        actors: Gd<ActorStateCore>,
        units: Gd<SpatialIndexCore>,
    ) -> Array<Variant> {
        let units = units.bind();
        let Some(units) = &units.core else {
            return Array::new();
        };
        self.core
            .taker(
                crate::point(position),
                radius,
                team,
                &actors.bind().core,
                units,
            )
            .map_or_else(|_| Array::new(), |owner| varray![owner])
    }
    #[func]
    fn event(&mut self, now: f64, team: i8, kind: GString, text: GString) -> bool {
        self.core
            .event(Event {
                time: now,
                team,
                kind: kind.to_string(),
                text: text.to_string(),
            })
            .is_ok()
    }
    #[func]
    fn tick(
        &mut self,
        dt: f64,
        now: f64,
        supply: PackedFloat64Array,
        bearers: PackedInt64Array,
        actors: Gd<ActorStateCore>,
    ) -> bool {
        let Ok(supply) = supply.as_slice().try_into() else {
            return false;
        };
        if bearers.len() > 100_000 {
            return false;
        }
        self.core
            .tick(dt, now, supply, &actors.bind().core, |s| {
                bearers.as_slice().contains(&i64::from(s.identity.id))
            })
            .is_ok()
    }
    #[func]
    fn report(
        &mut self,
        view: i8,
        over: bool,
        now: f64,
        supply: PackedFloat64Array,
        bearers: PackedInt64Array,
        actors: Gd<ActorStateCore>,
        qs: Array<Gd<SquadStateCore>>,
    ) -> Array<Variant> {
        let Ok(supply) = supply.as_slice().try_into() else {
            return Array::new();
        };
        let Some(qs) = squads(&qs) else {
            return Array::new();
        };
        if bearers.len() > 100_000 {
            return Array::new();
        }
        let actors = actors.bind();
        let Ok(row) = self.core.row(now, supply, &actors.core, |s| {
            bearers.as_slice().contains(&i64::from(s.identity.id))
        }) else {
            return Array::new();
        };
        let Ok(r) = self.core.report(view, over, row, &qs, &actors.core) else {
            return Array::new();
        };
        let sides: Array<Variant> = r
            .sides
            .iter()
            .map(|s| {
                s.as_ref()
                    .map_or_else(PackedFloat64Array::new, counters)
                    .to_variant()
            })
            .collect();
        varray![
            &players(&r.players),
            &sides,
            &units(&r.units),
            &heroes(&r.heroes),
            &timeline(&r.timeline),
            &events(&r.events)
        ]
    }
}
