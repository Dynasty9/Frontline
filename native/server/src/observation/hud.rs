use super::*;
use sim::{
    battle_stats::{self, Counters},
    economy,
};

fn symbol(c: &Content, a: &Actor) -> String {
    match a {
        Actor::Structure(_) => "post".into(),
        Actor::Vehicle(v) => {
            let d = c.vehicle(v);
            if let Some(s) = d["symbol"][0].as_str() {
                return s.into();
            }
            match d["base"].as_str().unwrap_or("") {
                "tank" => "armor",
                "afv" => "mech",
                "arty" => "arty",
                "attack_heli" | "lift_heli" => "air",
                "spaa" if d["tracked"].as_bool() == Some(true) => "armor",
                _ => "motor",
            }
            .into()
        }
        _ => "inf".into(),
    }
}
fn alive(a: &Actor) -> bool {
    !matches!(a, Actor::Soldier(s) if s.vitals.life!=Life::Alive)
}
fn summary(s: &Simulation, c: &Content, team: i8) -> Value {
    let f = &s.state.field;
    let rules = &s.state.rules;
    let actors = &f.actors;
    let t = team as usize;
    let fobs: Vec<_> = economy::fobs(actors, team, true).collect();
    let supply: i64 = fobs.iter().map(|b| b.supply as i64).sum();
    let used = economy::used(
        actors,
        team,
        &|i| c.loadouts.get(&i.identity.unit).is_some_and(|l| l.bearer),
        &|v| c.vehicle(v)["cap"].as_u64().unwrap_or(0) as u32,
    );
    let cap = economy::capacity(
        actors,
        team,
        c.definitions["base_cap"].as_u64().unwrap_or(6) as u32,
        c.definitions["cap_per_fob"].as_u64().unwrap_or(20) as u32,
    );
    let mut squads = serde_json::Map::new();
    let mut intel = BTreeMap::<u32, (Vector3, String, f64)>::new();
    for q in &f.squads {
        if q.team != team {
            continue;
        }
        for k in &q.known {
            let age = f.now - k.report.time;
            if age > 90. || intel.get(&k.id).is_some_and(|p| p.2 <= age) {
                continue;
            }
            if let Some(a) = actors.get(k.id).filter(|a| alive(a)) {
                intel.insert(k.id, (k.report.position, symbol(c, a), age));
            }
        }
        if q.alive(actors).next().is_none() {
            continue;
        }
        let shown = if !q.shown_order.is_empty() {
            q.shown_order.as_str()
        } else if q.then_defend.is_some() && q.order == "move" {
            "defend"
        } else if q.technique == "bound" {
            "bound"
        } else {
            q.order.as_str()
        };
        let plan = s.state.attacks.iter().find(|p| p.id == q.plan).map(|p| {
            json!([
                p.phase.name(),
                point(p.objective),
                point(p.support_position),
                point(p.assault_position),
                p.side,
                if p.support.iter().any(|e| e.squad == q.id && e.team < 0) {
                    "support"
                } else {
                    "assault"
                }
            ])
        });
        squads.insert(
            q.id.to_string(),
            json!([
                shown,
                point(q.order_position),
                point(q.facing),
                q.order_number,
                plan,
                q.morale.max(0.) as i64,
                q.drill
            ]),
        );
    }
    for k in &rules.fog.sighted[t] {
        let age = f.now - k.time;
        if !(2. ..=90.).contains(&age) || intel.get(&k.id).is_some_and(|p| p.2 <= age) {
            continue;
        }
        if let Some(a) = actors.get(k.id).filter(|a| alive(a)) {
            intel.insert(k.id, (k.position, symbol(c, a), age));
        }
    }
    let mut contacts: Vec<_> = intel.into_values().collect();
    if contacts.len() > 80 {
        contacts.sort_by(|a, b| a.2.total_cmp(&b.2));
        contacts.truncate(80);
    }
    let towns: Vec<_> = rules
        .network
        .towns
        .iter()
        .filter_map(|id| actors.structure(*id))
        .filter(|b| b.team == team)
        .map(|b| {
            let rate = c.definitions["town_yield"][b.variant.clamp(0, 1) as usize]
                .as_f64()
                .unwrap_or(0.)
                * (0.35 + 0.65 * b.intact);
            json!([
                b.id,
                b.name,
                b.supply as i64,
                b.supply_status,
                rate.round() as i64,
                actors
                    .structure(b.supply_parent)
                    .map_or("", |b| b.name.as_str())
            ])
        })
        .collect();
    let income: i64 = rules.income[t]
        .iter()
        .filter(|(time, _)| f.now - time <= 120.)
        .map(|(_, n)| i64::from(*n))
        .sum();
    let support: serde_json::Map<_, _> = rules.support.ready[t]
        .iter()
        .map(|(k, t)| (k.clone(), json!(t)))
        .collect();
    json!({"supply":supply,"units":used,"cap":cap,"fobs":fobs.iter().map(|b|json!([b.id,b.name,b.supply as i64,if b.wrecked{"Wrecked"}else{b.supply_status.as_str()}])).collect::<Vec<_>>(),
        "up":rules.economy.upgrades[t],"sup":support,"sq":squads,"intel":contacts.into_iter().map(|(p,k,a)|json!([point(p),k,a])).collect::<Vec<_>>(),
        "marks":rules.fog.marks[t],"towns":towns,"inc":(income as f64*60./f.now.clamp(30.,120.)) as i64})
}
pub fn hud(s: &Simulation, c: &Content, view: i8) -> Result<Value, &'static str> {
    if !(-1..=1).contains(&view) {
        return Err("invalid HUD view");
    }
    let teams: Vec<_> = (0..2)
        .map(|t| {
            if view < 0 || view == t {
                summary(s, c, t)
            } else {
                json!({})
            }
        })
        .collect();
    let mut result = json!({"teams":teams});
    if let Some(m) = &s.mission {
        result["mission"] = m.info(&s.state, c);
    }
    Ok(result)
}
fn counters(c: &Counters) -> Value {
    Value::Object(
        battle_stats::FIELDS
            .iter()
            .zip(c)
            .map(|(k, v)| (k.to_string(), json!(v)))
            .collect(),
    )
}
pub fn report(s: &Simulation, c: &Content, view: i8) -> Result<Value, &'static str> {
    let f = &s.state.field;
    let over = s.state.victory.winner >= 0;
    let supply = std::array::from_fn(|t| {
        economy::fobs(&f.actors, t as i8, true)
            .map(|b| b.supply.trunc())
            .sum()
    });
    let row = f.battle.row(f.now, supply, &f.actors, |i| {
        c.loadouts.get(&i.identity.unit).is_some_and(|l| l.bearer)
    })?;
    // Refreshing display totals must not mutate a checkpoint according to who requested a report.
    let r = f
        .battle
        .clone()
        .report(view, over, row, &f.squads, &f.actors)?;
    let players: Vec<_> = r
        .players
        .iter()
        .map(|p| {
            let mut v = counters(&p.counters);
            v.as_object_mut().unwrap().extend(
                json!({"id":p.owner,"team":p.team,"ai":p.ai,"name":p.name,
        "left":p.owner>0&&!s.names.contains_key(&p.owner)})
                .as_object()
                .unwrap()
                .clone(),
            );
            v
        })
        .collect();
    let units:Vec<_>=r.units.iter().map(|u|json!({"key":u.key,"name":u.name,"kind":u.kind,"team":u.team,"owner":u.owner,
        "t0":u.started,"t1":u.ended,"men":u.men,"alive":u.alive,"kills":u.kills,"downs":u.downs,"veh_kills":u.vehicle_kills,"lost":u.lost})).collect();
    let heroes:Vec<_>=r.heroes.iter().map(|h|json!({"name":h.name,"role":h.role,"team":h.team,"owner":h.owner,"unit":h.unit,"kills":h.kills,"veh":h.vehicles,"alive":h.alive})).collect();
    let mut out = json!({"t":f.now,"over":over,"winner":s.state.victory.winner,"full":view<0||over,"view":view,"every":f.battle.every,
        "players":players,"sides":r.sides.iter().map(|c|c.as_ref().map_or(json!({}),counters)).collect::<Vec<_>>(),"units":units,"heroes":heroes,"tl":r.timeline,
        "ev":r.events.iter().map(|e|json!([e.time,e.team,e.kind,e.text])).collect::<Vec<_>>()});
    if s.mission.is_some() {
        out["mission"] = json!(true);
    }
    Ok(out)
}
