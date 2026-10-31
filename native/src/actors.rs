use frontline_core::actors::{Actor, Actors};
use frontline_core::drone::DroneFlight;
use frontline_core::drone_actor::Drone;
use frontline_core::entities::Kind;
use frontline_core::infantry_casualty::Released;
use frontline_core::projectile_actor::{Event, Explosion};
use frontline_core::vehicle_sling::SlingSpec;
use godot::prelude::*;
use std::collections::HashMap;

type ServiceStock = HashMap<
    u32,
    (
        Option<frontline_core::infantry_supply::Loadout>,
        String,
        i32,
    ),
>;
fn infantry_stock(
    stock: &PackedFloat64Array,
) -> Result<Option<(i32, frontline_core::infantry_weapon::Weapon)>, ()> {
    Ok(if stock.is_empty() {
        None
    } else {
        if stock.len() != 4
            || [0, 1, 2].into_iter().any(|i| {
                !stock[i].is_finite()
                    || stock[i].fract() != 0.0
                    || !(0.0..=1_000_000.0).contains(&stock[i])
            })
        {
            return Err(());
        }
        Some((
            stock[0] as i32,
            frontline_core::infantry_weapon::Weapon {
                ammunition: stock[1] as i32,
                magazine: stock[2] as i32,
                reload_time: stock[3],
            },
        ))
    })
}
fn armor_ratings(values: &PackedInt64Array) -> Option<HashMap<u32, i32>> {
    if values.len() % 2 != 0 || values.len() > 200_000 {
        return None;
    }
    let mut ratings = HashMap::new();
    for row in values.as_slice().chunks_exact(2) {
        let id = u32::try_from(row[0]).ok()?;
        if id == 0 || !(0..=16).contains(&row[1]) || ratings.insert(id, row[1] as i32).is_some() {
            return None;
        }
    }
    Some(ratings)
}
fn service_stock(rows: Array<Variant>) -> Option<ServiceStock> {
    use frontline_core::infantry_supply::Loadout;
    use frontline_core::infantry_weapon::Weapon;
    if rows.len() > 100_000 {
        return None;
    }
    let mut out = HashMap::new();
    for row in rows.iter_shared() {
        let row = row.try_to::<Array<Variant>>().ok()?;
        if row.len() != 5 {
            return None;
        }
        let id: u32 = row.get(0)?.try_to().ok()?;
        let stock = row.get(1)?.try_to::<PackedInt32Array>().ok()?;
        let reload_time: f64 = row.get(2)?.try_to().ok()?;
        let weapon = row.get(3)?.try_to::<GString>().ok()?.to_string();
        let magazine: i32 = row.get(4)?.try_to().ok()?;
        if id == 0
            || stock.len() != 8
            || weapon.len() > 128
            || weapon.contains('\0')
            || !(0..=1_000_000).contains(&magazine)
        {
            return None;
        }
        let loadout = if stock[0] == -1 {
            None
        } else {
            let p = Loadout {
                ammunition: stock[0],
                special: stock.as_slice()[1..6].try_into().ok()?,
                reload_weapon: Weapon {
                    ammunition: stock[6],
                    magazine: stock[7],
                    reload_time,
                },
            };
            if !p.valid() {
                return None;
            }
            Some(p)
        };
        if out.insert(id, (loadout, weapon, magazine)).is_some() {
            return None;
        }
    }
    Some(out)
}

#[derive(GodotClass)]
#[class(base=RefCounted, init)]
pub(crate) struct ActorStateCore {
    base: Base<RefCounted>,
    pub(crate) core: Actors,
}
fn released(r: Released) -> PackedInt64Array {
    [r.patient, r.stretcher, r.squad, r.drone]
        .map(i64::from)
        .as_slice()
        .into()
}
fn impact(r: Result<Option<Explosion>, &'static str>) -> Array<Variant> {
    match r {
        Ok(e) => varray![&crate::projectile_actor::events(
            e.into_iter().map(Event::Explosion).collect()
        )],
        Err(_) => Array::new(),
    }
}
fn vector(p: frontline_core::vector::Vector3) -> Vector3 {
    Vector3::new(p.x, p.y, p.z)
}
fn mounted_gun(
    a: &PackedFloat64Array,
) -> Result<Option<frontline_core::infantry_fire::MountedGun>, ()> {
    if a.is_empty() {
        return Ok(None);
    }
    if a.len() != 5 {
        return Err(());
    }
    let gun = frontline_core::infantry_fire::MountedGun {
        bore: a[0],
        muzzle: a[1],
        grip_z: a[2] as f32,
        nest_height: a[3],
        trench_height: a[4],
    };
    if !gun.valid() {
        return Err(());
    }
    Ok(Some(gun))
}
fn sling_spec(a: &PackedInt32Array) -> Result<SlingSpec, &'static str> {
    let a = a.as_slice();
    if a.len() != 6 || [0, 3, 4, 5].into_iter().any(|i| a[i] != 0 && a[i] != 1) {
        return Err("invalid sling profile");
    }
    Ok(SlingSpec {
        lift: a[0] != 0,
        capacity: a[1].try_into().map_err(|_| "invalid capacity")?,
        cargo_weight: a[2].try_into().map_err(|_| "invalid weight")?,
        cargo_helicopter: a[3] != 0,
        cargo_boat: a[4] != 0,
        cargo_automatic: a[5] != 0,
    })
}
fn artillery_profile(
    a: &Array<Variant>,
) -> Option<frontline_core::vehicle_artillery::ArtilleryProfile> {
    if a.len() != 3 {
        return None;
    }
    let kind = a.get(0)?.try_to::<GString>().ok()?;
    let n = a.get(1)?.try_to::<PackedFloat64Array>().ok()?;
    if n.len() != 8 {
        return None;
    }
    Some(frontline_core::vehicle_artillery::ArtilleryProfile {
        shell: frontline_core::projectile::Kind::parse(&kind.to_string())?,
        gun_height: n[0],
        muzzle: n[1],
        scatter: n[2],
        lay: n[3],
        gap: n[4],
        cooldown: n[5],
        traverse: n[6],
        traverse_accel: n[7],
        salvo: a.get(2)?.try_to().ok()?,
    })
}

fn read_squads(
    nodes: &Array<Gd<crate::squad::SquadStateCore>>,
) -> Option<Vec<frontline_core::squad::Squad>> {
    if nodes.len() > 100_000 {
        return None;
    }
    let mut seen = std::collections::HashSet::new();
    nodes
        .iter_shared()
        .map(|q| {
            let q = q.bind();
            let q = q.core.as_ref()?;
            seen.insert(q.id).then(|| q.clone())
        })
        .collect()
}
fn write_squads(
    nodes: Array<Gd<crate::squad::SquadStateCore>>,
    state: Vec<frontline_core::squad::Squad>,
) {
    for (mut node, state) in nodes.iter_shared().zip(state) {
        node.bind_mut().core = Some(state);
    }
}

#[godot_api]
impl ActorStateCore {
    #[func]
    fn think_infantry(
        &mut self,
        id: u32,
        context: Array<Variant>,
        mut squad: Option<Gd<crate::squad::SquadStateCore>>,
        heat: PackedByteArray,
        deck: PackedByteArray,
        terrain: Gd<crate::terrain::TerrainCore>,
        nav: Gd<crate::path_planner::PathPlannerCore>,
        units: Gd<crate::spatial::SpatialIndexCore>,
        structures: Gd<crate::spatial::SpatialIndexCore>,
        mut collision: Gd<crate::collision_index::CollisionIndexCore>,
        visibility: Gd<crate::visibility::VisibilityCore>,
        mut rng: Gd<crate::simulation_random::SimulationRandomCore>,
    ) -> Array<Variant> {
        use frontline_core::infantry_cover::CoverWorld;
        use frontline_core::infantry_decision::{Profile, Speech};
        if context.len() != 7 {
            return Array::new();
        }
        let Some((now, stock, weapon, bearer, owned, armor, bearers)) = (|| {
            Some((
                context.get(0)?.try_to::<f64>().ok()?,
                context.get(1)?.try_to::<PackedFloat64Array>().ok()?,
                context.get(2)?.try_to::<PackedFloat64Array>().ok()?,
                context.get(3)?.try_to::<bool>().ok()?,
                context.get(4)?.try_to::<PackedInt64Array>().ok()?,
                context.get(5)?.try_to::<PackedInt64Array>().ok()?,
                context.get(6)?.try_to::<PackedInt64Array>().ok()?,
            ))
        })() else {
            return Array::new();
        };
        if !(weapon.is_empty()
            || weapon.len() == 2
                && weapon[1].is_finite()
                && weapon[1].fract() == 0.0
                && (0.0..=1_000_000.0).contains(&weapon[1]))
            || owned.len() > 100_000
            || bearers.len() > 100_000
        {
            return Array::new();
        }
        let (Ok(stock), Some(armor)) = (infantry_stock(&stock), armor_ratings(&armor)) else {
            return Array::new();
        };
        let Some(owned) = owned
            .as_slice()
            .iter()
            .map(|&id| u32::try_from(id).ok().filter(|id| *id != 0))
            .collect::<Option<Vec<_>>>()
        else {
            return Array::new();
        };
        if bearers
            .as_slice()
            .iter()
            .any(|&id| id <= 0 || id > u32::MAX as i64)
        {
            return Array::new();
        }
        let profile = Profile {
            stock,
            weapon_range: (!weapon.is_empty()).then(|| weapon[0]),
            weapon_ammunition: if weapon.is_empty() {
                0
            } else {
                weapon[1] as i32
            },
            bearer,
        };
        let terrain = terrain.bind();
        let nav = nav.bind();
        let units = units.bind();
        let structures = structures.bind();
        let (Some(terrain), Some(nav), Some(units), Some(structures)) =
            (&terrain.core, &nav.core, &units.core, &structures.core)
        else {
            return Array::new();
        };
        let mut squad = squad.as_mut().map(Gd::bind_mut);
        if squad.as_ref().is_some_and(|q| q.core.is_none()) {
            return Array::new();
        }
        let squad = squad.as_mut().and_then(|q| q.core.as_mut());
        let mut collision = collision.bind_mut();
        let mut world = CoverWorld {
            terrain,
            nav,
            units,
            structures,
            collision: &mut collision.core,
            heat: heat.as_slice(),
            deck: deck.as_slice(),
        };
        self.core
            .think_infantry(
                id,
                now,
                profile,
                squad,
                &mut world,
                &visibility.bind().core,
                &owned,
                |v| *armor.get(&v.id).unwrap_or(&1),
                |s| bearers.as_slice().contains(&i64::from(s.identity.id)),
                &mut rng.bind_mut().core,
            )
            .map_or_else(
                |_| Array::new(),
                |out| {
                    let route = out.route.map_or_else(Array::new, |r| {
                        varray![
                            r.revision as i64,
                            r.job.id as i64,
                            vector(r.job.destination),
                            r.job.care
                        ]
                    });
                    let speech: Array<Variant> = out
                        .speech
                        .into_iter()
                        .map(|s| {
                            let (kind, cue) = match s {
                                Speech::Reflex(c) => (0, c),
                                Speech::Scavenge(c) => (1, c),
                                Speech::Reload(c) => (2, c),
                                Speech::Special(c) => (3, c),
                                Speech::Cook(c) => (4, c),
                                Speech::Throw(c) => (5, c),
                                Speech::Breach(c) => (6, c),
                                Speech::OutOfAmmo => (7, 0),
                                Speech::Supply(cache) => (8, u8::from(cache)),
                            };
                            varray![kind, i32::from(cue)].to_variant()
                        })
                        .collect();
                    let stats: Array<GString> = out.stats.into_iter().map(GString::from).collect();
                    varray![
                        &speech,
                        &stats,
                        &route,
                        out.cancel_path,
                        i32::from(out.reflex_leaf)
                    ]
                },
            )
    }

    #[func]
    fn advance_infantry_grenade_task(
        &mut self,
        id: u32,
        dt: f64,
        now: f64,
        gun: PackedFloat64Array,
        units: Gd<crate::spatial::SpatialIndexCore>,
        nav: Gd<crate::path_planner::PathPlannerCore>,
        mut rng: Gd<crate::simulation_random::SimulationRandomCore>,
    ) -> Array<Variant> {
        let Ok(gun) = mounted_gun(&gun) else {
            return Array::new();
        };
        let units = units.bind();
        let nav = nav.bind();
        let (Some(units), Some(nav)) = (&units.core, &nav.core) else {
            return Array::new();
        };
        self.core
            .advance_infantry_grenade_task(id, dt, now, gun, units, nav, &mut rng.bind_mut().core)
            .map_or_else(|_| Array::new(), |out| varray![out.cancel_path, out.dived])
    }

    #[func]
    fn react_infantry(
        &mut self,
        id: u32,
        kind: u8,
        now: f64,
        armed: bool,
        mut squad: Option<Gd<crate::squad::SquadStateCore>>,
        units: Gd<crate::spatial::SpatialIndexCore>,
        nav: Gd<crate::path_planner::PathPlannerCore>,
        mut collision: Gd<crate::collision_index::CollisionIndexCore>,
        mut rng: Gd<crate::simulation_random::SimulationRandomCore>,
    ) -> Array<Variant> {
        use frontline_core::infantry_reflex::Reflex;
        let kind = match kind {
            0 => Reflex::Grenade,
            1 => Reflex::BusyGrenade,
            2 => Reflex::Shell,
            3 => Reflex::BusyShell,
            4 => Reflex::Drone,
            _ => return Array::new(),
        };
        let units = units.bind();
        let nav = nav.bind();
        let (Some(units), Some(nav)) = (&units.core, &nav.core) else {
            return Array::new();
        };
        let mut squad = squad.as_mut().map(Gd::bind_mut);
        if squad.as_ref().is_some_and(|q| q.core.is_none()) {
            return Array::new();
        }
        let squad = squad.as_mut().and_then(|q| q.core.as_mut());
        self.core
            .react_infantry(
                id,
                kind,
                now,
                armed,
                squad,
                units,
                nav,
                &mut collision.bind_mut().core,
                &mut rng.bind_mut().core,
            )
            .map_or_else(
                |_| Array::new(),
                |out| {
                    let speech = PackedByteArray::from(out.speech.as_slice());
                    let stats: Array<GString> = out.stats.into_iter().map(GString::from).collect();
                    varray![
                        out.handled,
                        out.cancel_path,
                        i32::from(out.leaf),
                        &speech,
                        &stats
                    ]
                },
            )
    }

    #[func]
    fn fire_targets(
        &self,
        team: i8,
        origin: Vector3,
        ranges: PackedFloat64Array,
        owned: PackedInt64Array,
        units: Gd<crate::spatial::SpatialIndexCore>,
        armor: PackedInt64Array,
        bearers: PackedInt64Array,
    ) -> Array<Variant> {
        if ranges.len() != 3 || owned.len() > 100_000 || bearers.len() > 100_000 {
            return Array::new();
        }
        let Some(armor) = armor_ratings(&armor) else {
            return Array::new();
        };
        let Some(owned) = owned
            .as_slice()
            .iter()
            .map(|&id| u32::try_from(id).ok())
            .collect::<Option<Vec<_>>>()
        else {
            return Array::new();
        };
        let units = units.bind();
        let Some(units) = &units.core else {
            return Array::new();
        };
        let mortar = frontline_core::fire_targets::mortar(
            &self.core,
            units,
            &owned,
            team,
            crate::point(origin),
            ranges[0],
            ranges[1],
        );
        let drone = frontline_core::fire_targets::fpv(
            &self.core,
            units,
            team,
            crate::point(origin),
            ranges[2],
            |v| *armor.get(&v.id).unwrap_or(&1),
            |s| bearers.as_slice().contains(&i64::from(s.identity.id)),
        );
        match (mortar, drone) {
            (Ok(m), Ok(d)) => varray![
                &m.map_or(Variant::nil(), |p| vector(p).to_variant()),
                i64::from(d.unwrap_or(0))
            ],
            _ => Array::new(),
        }
    }
    #[func]
    fn try_infantry_special(
        &mut self,
        soldier: u32,
        kind: u8,
        now: f64,
        armed: bool,
        mut squad: Option<Gd<crate::squad::SquadStateCore>>,
        owned: PackedInt64Array,
        units: Gd<crate::spatial::SpatialIndexCore>,
        terrain: Gd<crate::terrain::TerrainCore>,
        deck: PackedByteArray,
        mut collision: Gd<crate::collision_index::CollisionIndexCore>,
        visibility: Gd<crate::visibility::VisibilityCore>,
        armor: PackedInt64Array,
        bearers: PackedInt64Array,
        mut rng: Gd<crate::simulation_random::SimulationRandomCore>,
    ) -> Array<Variant> {
        if kind > 3 || owned.len() > 100_000 || bearers.len() > 100_000 {
            return Array::new();
        }
        let Some(armor) = armor_ratings(&armor) else {
            return Array::new();
        };
        let Some(owned) = owned
            .as_slice()
            .iter()
            .map(|&id| u32::try_from(id).ok())
            .collect::<Option<Vec<_>>>()
        else {
            return Array::new();
        };
        let units = units.bind();
        let terrain = terrain.bind();
        let (Some(units), Some(terrain)) = (&units.core, &terrain.core) else {
            return Array::new();
        };
        let mut squad = squad.as_mut().map(Gd::bind_mut);
        if squad.as_ref().is_some_and(|q| q.core.is_none()) {
            return Array::new();
        }
        let squad = squad.as_mut().and_then(|q| q.core.as_mut());
        let out = match kind {
            0 => self.core.try_infantry_melee(soldier, now, armed, units),
            1 => self.core.try_infantry_rocket(
                soldier,
                now,
                squad.as_deref(),
                terrain,
                deck.as_slice(),
                &mut collision.bind_mut().core,
                &visibility.bind().core,
            ),
            2 => self.core.try_infantry_drone(
                soldier,
                now,
                units,
                |v| *armor.get(&v.id).unwrap_or(&1),
                |s| bearers.as_slice().contains(&i64::from(s.identity.id)),
                &mut rng.bind_mut().core,
            ),
            _ => self.core.try_infantry_mortar(
                soldier,
                now,
                squad,
                units,
                &owned,
                &mut rng.bind_mut().core,
            ),
        };
        out.map_or_else(
            |_| Array::new(),
            |r| {
                varray![
                    r.started,
                    r.cleared_mission,
                    r.speech.map_or(-1i64, i64::from)
                ]
            },
        )
    }
    #[func]
    fn decide_infantry_cover(
        &mut self,
        soldier: u32,
        anchor: Vector3,
        input: PackedFloat64Array,
        mut squad: Option<Gd<crate::squad::SquadStateCore>>,
        heat: PackedByteArray,
        deck: PackedByteArray,
        terrain: Gd<crate::terrain::TerrainCore>,
        nav: Gd<crate::path_planner::PathPlannerCore>,
        units: Gd<crate::spatial::SpatialIndexCore>,
        structures: Gd<crate::spatial::SpatialIndexCore>,
        mut collision: Gd<crate::collision_index::CollisionIndexCore>,
        mut rng: Gd<crate::simulation_random::SimulationRandomCore>,
    ) -> Array<Variant> {
        use frontline_core::infantry_cover::{CoverIntent, CoverWorld};
        if input.len() != 5 || ![0.0, 1.0].contains(&input[3]) || ![0.0, 1.0].contains(&input[4]) {
            return Array::new();
        }
        let terrain = terrain.bind();
        let nav = nav.bind();
        let units = units.bind();
        let structures = structures.bind();
        let (Some(terrain), Some(nav), Some(units), Some(structures)) = (
            terrain.core.as_ref(),
            nav.core.as_ref(),
            units.core.as_ref(),
            structures.core.as_ref(),
        ) else {
            return Array::new();
        };
        let mut squad = squad.as_mut().map(Gd::bind_mut);
        if squad.as_ref().is_some_and(|q| q.core.is_none()) {
            return Array::new();
        }
        let squad = squad.as_mut().and_then(|q| q.core.as_mut());
        let mut collision = collision.bind_mut();
        let mut world = CoverWorld {
            terrain,
            nav,
            units,
            structures,
            collision: &mut collision.core,
            heat: heat.as_slice(),
            deck: deck.as_slice(),
        };
        let mut rng = rng.bind_mut();
        let out = if input[4] != 0.0 {
            self.core.review_infantry_cover(
                soldier,
                input[0],
                input[2],
                input[3] != 0.0,
                squad,
                &mut world,
                &mut rng.core,
            )
        } else {
            self.core
                .seek_infantry_cover(
                    soldier,
                    CoverIntent {
                        now: input[0],
                        anchor: crate::point(anchor),
                        radius: input[1],
                        weapon_range: input[2],
                        unarmed: input[3] != 0.0,
                    },
                    squad,
                    &mut world,
                    &mut rng.core,
                )
                .map(Some)
        };
        match out {
            Ok(out) => {
                let route = out.and_then(|o| o.route).map_or_else(Array::new, |r| {
                    varray![
                        r.revision as i64,
                        r.job.id as i64,
                        vector(r.job.destination),
                        r.job.care
                    ]
                });
                varray![
                    out.is_some(),
                    out.map_or(0, |o| o.search.candidates as i64),
                    out.map_or(0, |o| o.search.evaluations as i64),
                    &route
                ]
            }
            Err(_) => Array::new(),
        }
    }
    #[func]
    fn damage_infantry(
        &mut self,
        soldier: u32,
        source: u32,
        direction: Vector3,
        kind: GString,
        values: PackedFloat64Array,
        blame: Array<Variant>,
        squads: Array<Gd<crate::squad::SquadStateCore>>,
        mut rng: Gd<crate::simulation_random::SimulationRandomCore>,
    ) -> Array<Variant> {
        use frontline_core::infantry::Credit;
        use frontline_core::infantry_effects::Damage;
        use frontline_core::infantry_vitals::DamageResult;
        if values.len() != 4
            || !values[2].is_finite()
            || values[2].fract() != 0.0
            || !(-1.0..=1_000_000.0).contains(&values[2])
            || ![0.0, 1.0].contains(&values[3])
        {
            return Array::new();
        }
        let blame = if blame.is_empty() {
            None
        } else {
            if blame.len() != 4 {
                return Array::new();
            }
            let parsed = (|| {
                Some(Credit {
                    owner: blame.get(0)?.try_to().ok()?,
                    team: blame.get(1)?.try_to().ok()?,
                    unit: blame.get(2)?.try_to::<GString>().ok()?.to_string(),
                    soldier: blame.get(3)?.try_to().ok()?,
                })
            })();
            let Some(c) = parsed else {
                return Array::new();
            };
            Some(c)
        };
        let Some(mut state) = read_squads(&squads) else {
            return Array::new();
        };
        let kind = kind.to_string();
        let hit = Damage {
            amount: values[0],
            now: values[1],
            ammunition: (values[2] >= 0.0).then_some(values[2] as i32),
            bearer: values[3] != 0.0,
            source,
            direction: frontline_core::vector::Vector3::new(direction.x, direction.y, direction.z),
            kind: &kind,
            blame: blame.as_ref(),
        };
        match self
            .core
            .damage_infantry(soldier, hit, &mut state, &mut rng.bind_mut().core)
        {
            Ok(r) => {
                write_squads(squads, state);
                let code = match r.result {
                    DamageResult::Ignored => 0,
                    DamageResult::Survived(_) => 1,
                    DamageResult::Down => 2,
                    DamageResult::Die => 3,
                };
                let credit = r.credited.map_or_else(Array::new, |c| {
                    varray![c.owner, c.team as i32, c.unit.as_str(), c.soldier as i64]
                });
                varray![
                    code,
                    r.previous_life as i32,
                    r.speech.map_or(-1, i32::from),
                    r.casualty_speech.map_or(0, |s| i64::from(s.soldier)),
                    r.casualty_speech.map_or(-1, |s| i32::from(s.cue)),
                    &released(r.released.unwrap_or_default()),
                    &credit,
                    r.damage_credited
                ]
            }
            Err(_) => Array::new(),
        }
    }
    #[func]
    fn suppress_infantry(
        &mut self,
        soldier: u32,
        amount: f64,
        from: Vector3,
        now: f64,
        mut squad: Option<Gd<crate::squad::SquadStateCore>>,
        mut rng: Gd<crate::simulation_random::SimulationRandomCore>,
    ) -> Array<Variant> {
        let mut q = squad.as_mut().map(Gd::bind_mut);
        if q.as_ref().is_some_and(|q| q.core.is_none()) {
            return Array::new();
        }
        match self.core.suppress_infantry(
            soldier,
            amount,
            frontline_core::vector::Vector3::new(from.x, from.y, from.z),
            now,
            q.as_mut().and_then(|q| q.core.as_mut()),
            &mut rng.bind_mut().core,
        ) {
            Ok(cue) => varray![cue.map_or(-1, i32::from)],
            Err(_) => Array::new(),
        }
    }
    #[func]
    fn suppress_bullet(
        &mut self,
        from: Vector3,
        to: Vector3,
        team: i32,
        amount: f64,
        hit_target: u32,
        now: f64,
        units: Gd<crate::spatial::SpatialIndexCore>,
        squads: Array<Gd<crate::squad::SquadStateCore>>,
        mut rng: Gd<crate::simulation_random::SimulationRandomCore>,
    ) -> Array<Variant> {
        let Ok(team) = i8::try_from(team) else {
            return Array::new();
        };
        let Some(mut state) = read_squads(&squads) else {
            return Array::new();
        };
        let units = units.bind();
        let Some(units) = units.core.as_ref() else {
            return Array::new();
        };
        match self.core.suppress_bullet(
            frontline_core::vector::Vector3::new(from.x, from.y, from.z),
            frontline_core::vector::Vector3::new(to.x, to.y, to.z),
            team,
            amount,
            hit_target,
            now,
            units,
            &mut state,
            &mut rng.bind_mut().core,
        ) {
            Ok(lines) => {
                write_squads(squads, state);
                let mut out = PackedInt64Array::new();
                for line in lines {
                    out.push(i64::from(line.soldier));
                    out.push(i64::from(line.cue));
                }
                varray![&out]
            }
            Err(_) => Array::new(),
        }
    }
    #[func]
    fn arrive_infantry_supply(
        &mut self,
        soldier: u32,
        capacity: i32,
        nav: Gd<crate::path_planner::PathPlannerCore>,
    ) -> Array<Variant> {
        let nav = nav.bind();
        let Some(nav) = nav.core.as_ref() else {
            return Array::new();
        };
        match self.core.arrive_infantry_supply(soldier, capacity, nav) {
            Ok(r) => {
                let route = r.route.map_or_else(Array::new, |r| {
                    varray![r.revision as i64, vector(r.job.destination), r.job.care]
                });
                varray![r.missing, r.spoke, r.returned, r.rounds, &route]
            }
            Err(_) => Array::new(),
        }
    }
    #[func]
    fn scavenge_infantry(
        &mut self,
        soldier: u32,
        now: f64,
        stock: PackedFloat64Array,
        units: Gd<crate::spatial::SpatialIndexCore>,
        mut rng: Gd<crate::simulation_random::SimulationRandomCore>,
    ) -> Array<Variant> {
        let Ok(stock) = infantry_stock(&stock) else {
            return Array::new();
        };
        let units = units.bind();
        let Some(units) = units.core.as_ref() else {
            return Array::new();
        };
        match self
            .core
            .scavenge_infantry(soldier, now, stock, units, &mut rng.bind_mut().core)
        {
            Ok(Some(r)) => varray![
                r.body as i64,
                r.rounds,
                r.speech.map_or(-1, i32::from),
                r.reload_speech.map_or(-1, i32::from)
            ],
            Ok(None) => varray![0i64, 0, -1, -1],
            Err(_) => Array::new(),
        }
    }
    #[func]
    fn seek_infantry_supply(
        &mut self,
        soldier: u32,
        now: f64,
        units: Gd<crate::spatial::SpatialIndexCore>,
        structures: Gd<crate::spatial::SpatialIndexCore>,
        mut rng: Gd<crate::simulation_random::SimulationRandomCore>,
    ) -> Array<Variant> {
        let units = units.bind();
        let structures = structures.bind();
        let (Some(units), Some(structures)) = (units.core.as_ref(), structures.core.as_ref())
        else {
            return Array::new();
        };
        match self.core.seek_infantry_supply(
            soldier,
            now,
            units,
            structures,
            &mut rng.bind_mut().core,
        ) {
            Ok(Some(r)) => varray![
                r.source as i32,
                r.entity as i64,
                r.route.revision as i64,
                vector(r.route.job.destination),
                r.route.job.care
            ],
            Ok(None) => varray![-1, 0i64, 0i64, Vector3::ZERO, 0.0],
            Err(_) => Array::new(),
        }
    }
    #[func]
    fn ready_infantry_weapon(
        &mut self,
        soldier: u32,
        input: PackedFloat64Array,
        weapon: PackedFloat64Array,
        gun: PackedFloat64Array,
        mut squad: Option<Gd<crate::squad::SquadStateCore>>,
        nav: Gd<crate::path_planner::PathPlannerCore>,
        units: Gd<crate::spatial::SpatialIndexCore>,
        mut collision: Gd<crate::collision_index::CollisionIndexCore>,
        mut visibility: Gd<crate::visibility::VisibilityCore>,
        mut rng: Gd<crate::simulation_random::SimulationRandomCore>,
    ) -> Array<Variant> {
        use frontline_core::infantry_fighting::{Mode, WeaponInput};
        if input.len() != 5 || (input[2] != 0.0 && input[2] != 1.0) {
            return Array::new();
        }
        let mode = match input[3] {
            0.0 => Mode::Normal,
            1.0 => Mode::Escort,
            2.0 => Mode::Crew,
            _ => return Array::new(),
        };
        let weapon = if weapon.is_empty() {
            None
        } else {
            if weapon.len() != 3
                || [0, 1].into_iter().any(|i| {
                    !weapon[i].is_finite()
                        || weapon[i].fract() != 0.0
                        || !(0.0..=1_000_000.0).contains(&weapon[i])
                })
            {
                return Array::new();
            }
            Some(frontline_core::infantry_weapon::Weapon {
                ammunition: weapon[0] as i32,
                magazine: weapon[1] as i32,
                reload_time: weapon[2],
            })
        };
        let Ok(gun) = mounted_gun(&gun) else {
            return Array::new();
        };
        let mut squad = squad.as_mut().map(Gd::bind_mut);
        if squad.as_ref().is_some_and(|q| q.core.is_none()) {
            return Array::new();
        }
        let nav = nav.bind();
        let units = units.bind();
        let (Some(nav), Some(units)) = (nav.core.as_ref(), units.core.as_ref()) else {
            return Array::new();
        };
        let p = WeaponInput {
            dt: input[0],
            now: input[1],
            moving: input[2] != 0.0,
            mode,
            weapon,
            gun,
        };
        match self.core.ready_infantry_weapon(
            soldier,
            p,
            input[4],
            squad.as_mut().and_then(|q| q.core.as_mut()),
            nav,
            units,
            &mut collision.bind_mut().core,
            &mut visibility.bind_mut().core,
            &mut rng.bind_mut().core,
        ) {
            Ok(r) => {
                let route = r.route.map_or_else(Array::new, |r| {
                    varray![
                        r.revision as i64,
                        r.job.id as i64,
                        vector(r.job.destination),
                        r.job.vehicle,
                        r.job.team,
                        r.job.care
                    ]
                });
                let cycle: PackedInt32Array = [
                    i32::from(r.cycle.drew_fire),
                    i32::from(r.cycle.peeked),
                    i32::from(r.cycle.blind_fire),
                    r.cycle.reload_speech.map_or(-1, i32::from),
                    i32::from(r.cycle.call_cover),
                    i32::from(r.cycle.shift_along),
                ]
                .as_slice()
                .into();
                varray![
                    r.aim.point.map_or(Vector3::INF, vector),
                    r.aim.target as i64,
                    r.aim.reused_obstruction,
                    r.covering,
                    &cycle,
                    r.reply.soldier as i64,
                    r.reply.speech.map_or(-1, i32::from),
                    &route
                ]
            }
            Err(_) => Array::new(),
        }
    }
    #[func]
    fn aim_infantry(
        &mut self,
        soldier: u32,
        now: f64,
        range: f64,
        squad: Option<Gd<crate::squad::SquadStateCore>>,
        mut collision: Gd<crate::collision_index::CollisionIndexCore>,
        mut visibility: Gd<crate::visibility::VisibilityCore>,
        mut rng: Gd<crate::simulation_random::SimulationRandomCore>,
    ) -> Array<Variant> {
        let squad = squad.as_ref().map(Gd::bind);
        if squad.as_ref().is_some_and(|q| q.core.is_none()) {
            return Array::new();
        }
        match self.core.aim_infantry(
            soldier,
            now,
            range,
            squad.as_ref().and_then(|q| q.core.as_ref()),
            &mut collision.bind_mut().core,
            &mut visibility.bind_mut().core,
            &mut rng.bind_mut().core,
        ) {
            Ok(r) => varray![
                r.point.map_or(Vector3::INF, vector),
                r.target as i64,
                r.reused_obstruction
            ],
            Err(_) => Array::new(),
        }
    }
    #[func]
    fn infantry_cover_reply(
        &mut self,
        soldier: u32,
        now: f64,
        squad: Option<Gd<crate::squad::SquadStateCore>>,
        mut rng: Gd<crate::simulation_random::SimulationRandomCore>,
    ) -> Array<Variant> {
        let squad = squad.as_ref().map(Gd::bind);
        if squad.as_ref().is_some_and(|q| q.core.is_none()) {
            return Array::new();
        }
        let squad = squad.as_ref().and_then(|q| q.core.as_ref());
        let Ok(buddy) = self.core.buddy_up(soldier, now, squad) else {
            return Array::new();
        };
        match self
            .core
            .call_cover(soldier, squad, &mut rng.bind_mut().core)
        {
            Ok(r) => varray![buddy, r.soldier as i64, r.speech.map_or(-1, i32::from)],
            Err(_) => Array::new(),
        }
    }
    #[func]
    fn prepare_infantry_shot(
        &mut self,
        soldier: u32,
        now: f64,
        moving: bool,
        profile: PackedFloat64Array,
        gun: PackedFloat64Array,
        squad: Option<Gd<crate::squad::SquadStateCore>>,
        mut rng: Gd<crate::simulation_random::SimulationRandomCore>,
    ) -> Array<Variant> {
        if profile.len() != 5
            || [0, 1, 3, 4].into_iter().any(|i| {
                !profile[i].is_finite()
                    || profile[i].fract() != 0.0
                    || !(0.0..=1_000_000.0).contains(&profile[i])
            })
        {
            return Array::new();
        }
        let Ok(gun) = mounted_gun(&gun) else {
            return Array::new();
        };
        let squad = squad.as_ref().map(Gd::bind);
        if squad.as_ref().is_some_and(|q| q.core.is_none()) {
            return Array::new();
        }
        let p = frontline_core::infantry_fire::FireProfile {
            weapon: frontline_core::infantry_weapon::Weapon {
                ammunition: profile[0] as i32,
                magazine: profile[1] as i32,
                reload_time: profile[2],
            },
            burst_min: profile[3] as i32,
            burst_max: profile[4] as i32,
        };
        match self.core.prepare_infantry_shot(
            soldier,
            now,
            moving,
            p,
            gun,
            squad.as_ref().and_then(|q| q.core.as_ref()),
            &mut rng.bind_mut().core,
        ) {
            Ok(r) => varray![
                r.shot.fired,
                r.shot.low_ammo,
                r.shot.announce_low_ammo,
                r.shot.reload_speech.map_or(-1, i32::from),
                r.shot.accuracy,
                r.origin.map_or(Vector3::INF, vector)
            ],
            Err(_) => Array::new(),
        }
    }
    #[func]
    fn finish_infantry_shot(
        &mut self,
        soldier: u32,
        profile: PackedFloat64Array,
        low_ammo: bool,
        cover_fire: bool,
        mut rng: Gd<crate::simulation_random::SimulationRandomCore>,
    ) -> Array<Variant> {
        if profile.len() != 4
            || [0, 1].into_iter().any(|i| {
                !profile[i].is_finite()
                    || profile[i].fract() != 0.0
                    || !(0.0..=1_000_000.0).contains(&profile[i])
            })
        {
            return Array::new();
        }
        let w = frontline_core::infantry_weapon::Weapon {
            ammunition: profile[0] as i32,
            magazine: profile[1] as i32,
            reload_time: profile[2],
        };
        match self.core.finish_infantry_shot(
            soldier,
            w,
            profile[3],
            low_ammo,
            cover_fire,
            &mut rng.bind_mut().core,
        ) {
            Ok(speech) => varray![speech.map_or(-1, i32::from)],
            Err(_) => Array::new(),
        }
    }
    #[func]
    fn scan_infantry(
        &mut self,
        soldier: u32,
        now: f64,
        profile: PackedFloat64Array,
        search: Gd<crate::PerceptionSearch>,
        mut collision: Gd<crate::collision_index::CollisionIndexCore>,
        mut visibility: Gd<crate::visibility::VisibilityCore>,
        armor: PackedInt64Array,
    ) -> Array<Variant> {
        if profile.len() != 3
            || [profile[0], profile[2]]
                .into_iter()
                .any(|v| v != 0.0 && v != 1.0)
        {
            return Array::new();
        }
        let Some(ratings) = armor_ratings(&armor) else {
            return Array::new();
        };
        let p = frontline_core::infantry_scan::ScanProfile {
            bearer: profile[0] != 0.0,
            weapon_range: profile[1],
            armor_piercing: profile[2] != 0.0,
        };
        match self.core.scan_infantry(
            soldier,
            now,
            p,
            &search.bind().core,
            &mut collision.bind_mut().core,
            &mut visibility.bind_mut().core,
            |v| *ratings.get(&v.id).unwrap_or(&1),
        ) {
            Ok(scan) => varray![
                scan.target as i64,
                scan.reported as i64,
                scan.reused as i64,
                &scan
                    .visible
                    .into_iter()
                    .map(|id| id as i64)
                    .collect::<PackedInt64Array>()
            ],
            Err(_) => Array::new(),
        }
    }
    #[func]
    fn scan_vehicle(
        &mut self,
        vehicle: u32,
        profile: PackedFloat64Array,
        units: Gd<crate::spatial::SpatialIndexCore>,
        structures: Gd<crate::spatial::SpatialIndexCore>,
        mut collision: Gd<crate::collision_index::CollisionIndexCore>,
        mut visibility: Gd<crate::visibility::VisibilityCore>,
        aircraft: PackedInt64Array,
        buildings: PackedStringArray,
    ) -> Array<Variant> {
        use std::collections::HashSet;
        if profile.len() != 6
            || profile.as_slice()[2..]
                .iter()
                .any(|v| *v != 0.0 && *v != 1.0)
            || aircraft.len() > 100_000
            || buildings.len() > 4096
        {
            return Array::new();
        }
        let p = frontline_core::vehicle_scan::ScanProfile {
            sight: profile[0],
            gun_height: profile[1],
            cannon: profile[2] != 0.0,
            gunship: profile[3] != 0.0,
            anti_air: profile[4] != 0.0,
            penetrating_mg: profile[5] != 0.0,
        };
        let Some(aircraft) = aircraft
            .as_slice()
            .iter()
            .map(|id| u32::try_from(*id).ok().filter(|id| *id != 0))
            .collect::<Option<HashSet<_>>>()
        else {
            return Array::new();
        };
        let buildings: HashSet<String> =
            buildings.as_slice().iter().map(|s| s.to_string()).collect();
        if buildings
            .iter()
            .any(|s| s.is_empty() || s.len() > 128 || s.contains('\0'))
        {
            return Array::new();
        }
        let units = units.bind();
        let structures = structures.bind();
        let (Some(units), Some(structures)) = (units.core.as_ref(), structures.core.as_ref())
        else {
            return Array::new();
        };
        match self.core.scan_vehicle(
            vehicle,
            p,
            units,
            structures,
            &mut collision.bind_mut().core,
            &mut visibility.bind_mut().core,
            |v| aircraft.contains(&v.id),
            |kind| buildings.contains(kind),
        ) {
            Ok(scan) => varray![
                scan.target,
                &scan
                    .reports
                    .into_iter()
                    .map(i64::from)
                    .collect::<PackedInt64Array>(),
                scan.reused_obstructions
            ],
            Err(_) => Array::new(),
        }
    }
    #[func]
    fn fire_vehicle_cannon(
        &mut self,
        vehicle: u32,
        target: u32,
        now: f64,
        muzzle: Array<Variant>,
        gun: PackedFloat64Array,
        terrain: Gd<crate::terrain::TerrainCore>,
        mut collision: Gd<crate::collision_index::CollisionIndexCore>,
        mut rng: Gd<crate::simulation_random::SimulationRandomCore>,
    ) -> Array<Variant> {
        let Some(muzzle) = crate::vehicle::muzzle_profile(&muzzle) else {
            return Array::new();
        };
        if gun.len() != 4 {
            return Array::new();
        }
        let p = frontline_core::vehicle_cannon::CannonProfile {
            muzzle,
            damage: gun[0],
            radius: gun[1],
            anti_tank: gun[2],
            size: gun[3],
        };
        let terrain = terrain.bind();
        let Some(terrain) = terrain.core.as_ref() else {
            return Array::new();
        };
        match self.core.fire_vehicle_cannon(
            vehicle,
            target,
            now,
            p,
            terrain,
            &mut collision.bind_mut().core,
            &mut rng.bind_mut().core,
        ) {
            Ok(s) => varray![
                vector(s.from),
                &crate::projectile_actor::events(vec![Event::Explosion(s.blast)])
            ],
            Err(_) => Array::new(),
        }
    }
    #[func]
    fn artillery_needs_target(&self, vehicle: u32, now: f64) -> i32 {
        self.core
            .artillery_needs_target(vehicle, now)
            .map_or(-1, i32::from)
    }
    #[func]
    fn artillery_tick(
        &mut self,
        vehicle: u32,
        now: f64,
        dt: f64,
        profile: Array<Variant>,
        target: PackedVector3Array,
    ) -> i32 {
        let Some(p) = artillery_profile(&profile) else {
            return -1;
        };
        if target.len() > 1 {
            return -1;
        }
        match self.core.artillery_tick(
            vehicle,
            now,
            dt,
            p,
            target.as_slice().first().copied().map(crate::point),
        ) {
            Ok(frontline_core::vehicle_artillery::ArtilleryEvent::None) => 0,
            Ok(frontline_core::vehicle_artillery::ArtilleryEvent::Mission) => 1,
            Ok(frontline_core::vehicle_artillery::ArtilleryEvent::Fire) => 2,
            Err(_) => -1,
        }
    }
    #[func]
    fn finish_artillery_round(&mut self, vehicle: u32, profile: Array<Variant>) -> bool {
        artillery_profile(&profile)
            .is_some_and(|p| self.core.finish_artillery_round(vehicle, p).is_ok())
    }
    #[func]
    fn launch_vehicle_shell(
        &mut self,
        vehicle: u32,
        now: f64,
        profile: Array<Variant>,
        mut rng: Gd<crate::simulation_random::SimulationRandomCore>,
    ) -> Array<Variant> {
        let Some(p) = artillery_profile(&profile) else {
            return Array::new();
        };
        match self
            .core
            .launch_vehicle_shell(vehicle, now, p, &mut rng.bind_mut().core)
        {
            Ok(l) => varray![
                l.id,
                vector(l.flight.position),
                vector(l.flight.target),
                vector(l.forward),
                l.flight.shell_duration
            ],
            Err(_) => Array::new(),
        }
    }
    #[func]
    fn launch_vehicle_rocket(
        &mut self,
        vehicle: u32,
        target: u32,
        index: u32,
        mut rng: Gd<crate::simulation_random::SimulationRandomCore>,
    ) -> Array<Variant> {
        match self
            .core
            .launch_vehicle_rocket(vehicle, target, index, &mut rng.bind_mut().core)
        {
            Ok(l) => varray![l.id, vector(l.position), vector(l.velocity)],
            Err(_) => Array::new(),
        }
    }
    #[func]
    fn launch_vehicle_missile(
        &mut self,
        vehicle: u32,
        target: u32,
        anti_tank: bool,
        gunship: bool,
        gun_height: f64,
    ) -> Array<Variant> {
        let kind = if anti_tank {
            frontline_core::guided::Kind::AntiTank
        } else {
            frontline_core::guided::Kind::SurfaceToAir
        };
        match self
            .core
            .launch_vehicle_missile(vehicle, target, kind, gunship, gun_height)
        {
            Ok(l) => varray![l.id, vector(l.position), vector(l.velocity)],
            Err(_) => Array::new(),
        }
    }
    #[func]
    fn projectile_warning_target(&self, projectile: u32) -> i64 {
        self.core
            .projectile_warning_target(projectile)
            .map_or(-1, |id| i64::from(id.unwrap_or(0)))
    }
    #[func]
    fn launch_vehicle_smoke(
        &mut self,
        vehicle: u32,
        now: f64,
        from: Vector3,
        armor: u8,
        helicopter: bool,
        gun_height: f64,
        mut rng: Gd<crate::simulation_random::SimulationRandomCore>,
    ) -> Array<Variant> {
        let profile = frontline_core::vehicle_launch::SmokeProfile {
            armor,
            helicopter,
            gun_height,
        };
        match self.core.launch_vehicle_smoke(
            vehicle,
            now,
            crate::point(from),
            profile,
            &mut rng.bind_mut().core,
        ) {
            Ok(launches) => {
                let launches: Array<Variant> = launches
                    .into_iter()
                    .map(|l| varray![l.id, vector(l.position), vector(l.velocity)].to_variant())
                    .collect();
                varray![&launches]
            }
            Err(_) => Array::new(),
        }
    }
    #[func]
    fn dismount(
        &mut self,
        vehicle: u32,
        boat: bool,
        planner: Gd<crate::path_planner::PathPlannerCore>,
    ) -> Array<Variant> {
        let planner = planner.bind();
        let Some(nav) = planner.core.as_ref() else {
            return Array::new();
        };
        match self.core.dismount(vehicle, boat, nav) {
            Ok(None) => varray![false, 0, Vector3::ZERO, Vector3::ZERO, false],
            Ok(Some(d)) => varray![
                true,
                d.squad,
                vector(d.position),
                vector(d.forward),
                d.assault
            ],
            Err(_) => Array::new(),
        }
    }
    #[func]
    fn dismount_due(
        &mut self,
        vehicle: u32,
        dt: f64,
        lift: bool,
        boat: bool,
        planner: Gd<crate::path_planner::PathPlannerCore>,
        units: Gd<crate::spatial::SpatialIndexCore>,
    ) -> i32 {
        let planner = planner.bind();
        let units = units.bind();
        let (Some(nav), Some(units)) = (planner.core.as_ref(), units.core.as_ref()) else {
            return -1;
        };
        self.core
            .dismount_due(vehicle, dt, lift, boat, nav, units)
            .map_or(-1, i32::from)
    }
    #[func]
    fn can_sling(&self, helicopter: u32, cargo: u32, spec: PackedInt32Array) -> i32 {
        sling_spec(&spec)
            .and_then(|s| self.core.can_sling(helicopter, cargo, s))
            .map_or(-1, i32::from)
    }
    #[func]
    fn order_sling(&mut self, helicopter: u32, cargo: u32, spec: PackedInt32Array) -> i32 {
        sling_spec(&spec)
            .and_then(|s| self.core.order_sling(helicopter, cargo, s))
            .map_or(-1, i32::from)
    }
    #[func]
    fn hook_sling(&mut self, helicopter: u32, cargo: u32, spec: PackedInt32Array) -> i32 {
        sling_spec(&spec)
            .and_then(|s| self.core.hook_sling(helicopter, cargo, s))
            .map_or(-1, i32::from)
    }
    #[func]
    fn step_sling(&mut self, helicopter: u32, dt: f64, height: f64) -> i32 {
        self.core
            .step_sling(helicopter, dt, height)
            .map_or(-1, i32::from)
    }
    #[func]
    fn release_sling(
        &mut self,
        helicopter: u32,
        planner: Gd<crate::path_planner::PathPlannerCore>,
    ) -> i64 {
        let nav = planner.bind();
        let Some(nav) = nav.core.as_ref() else {
            return -1;
        };
        self.core
            .release_sling(helicopter, nav)
            .map_or(-1, |v| i64::from(v.unwrap_or(0)))
    }
    #[func]
    fn drop_sling(
        &mut self,
        cargo: u32,
        planner: Gd<crate::path_planner::PathPlannerCore>,
    ) -> Array<Variant> {
        let nav = planner.bind();
        let Some(nav) = nav.core.as_ref() else {
            return Array::new();
        };
        match self.core.drop_sling(cargo, nav) {
            Ok(drop) => varray![vector(drop.position), drop.damage, drop.impact],
            Err(_) => Array::new(),
        }
    }
    #[func]
    fn service_vehicle(
        &mut self,
        vehicle: u32,
        dt: f64,
        service: GString,
        units: Gd<crate::spatial::SpatialIndexCore>,
        mut random: Gd<crate::simulation_random::SimulationRandomCore>,
        soldiers: Array<Variant>,
        vehicles: Array<Variant>,
    ) -> Array<Variant> {
        use frontline_core::vehicle_service::{Service, ServiceEffect, SoldierSupply};
        let service = match service.to_string().as_str() {
            "repair" => Service::Repair,
            "ammo" => Service::Ammo,
            "medical" => Service::Medical,
            _ => return Array::new(),
        };
        let Some(stock) = service_stock(soldiers) else {
            return Array::new();
        };
        if vehicles.len() > 100_000 {
            return Array::new();
        }
        let mut missiles = HashMap::new();
        for row in vehicles.iter_shared() {
            let Ok(row) = row.try_to::<PackedInt64Array>() else {
                return Array::new();
            };
            if row.len() != 3 {
                return Array::new();
            }
            let (Ok(id), Ok(atgm), Ok(sam)) = (
                u32::try_from(row[0]),
                i32::try_from(row[1]),
                i32::try_from(row[2]),
            ) else {
                return Array::new();
            };
            if id == 0
                || !(0..=1_000_000).contains(&atgm)
                || !(0..=1_000_000).contains(&sam)
                || missiles.insert(id, [atgm, sam]).is_some()
            {
                return Array::new();
            }
        }
        let units = units.bind();
        let Some(units) = units.core.as_ref() else {
            return Array::new();
        };
        match self.core.service_vehicle(
            vehicle,
            dt,
            service,
            units,
            &mut random.bind_mut().core,
            |s| {
                stock
                    .get(&s.identity.id)
                    .map(|(loadout, key, magazine)| SoldierSupply {
                        loadout: *loadout,
                        restored_weapon: (!key.is_empty()).then_some((key.as_str(), *magazine)),
                    })
                    .ok_or("missing infantry stock")
            },
            |v| missiles.get(&v.id).copied().ok_or("missing vehicle stock"),
        ) {
            Ok(events) => {
                let out: Array<Variant> = events
                    .into_iter()
                    .map(|e| {
                        let row = match e {
                            ServiceEffect::Repaired { vehicle, track } => {
                                [0, i64::from(vehicle), i64::from(track)]
                            }
                            ServiceEffect::Reload { soldier, speech } => {
                                [1, i64::from(soldier), i64::from(speech)]
                            }
                            ServiceEffect::Revived { soldier, speech } => {
                                [2, i64::from(soldier), i64::from(speech)]
                            }
                        };
                        PackedInt64Array::from(row.as_slice()).to_variant()
                    })
                    .collect();
                varray![&out]
            }
            Err(_) => Array::new(),
        }
    }
    #[func]
    fn load_state(&mut self, next_id: i64, kinds: PackedByteArray, blocks: Array<Variant>) -> bool {
        if kinds.len() != blocks.len() || blocks.len() > frontline_core::entities::MAX_ENTITIES {
            return false;
        }
        let mut actors = Vec::with_capacity(blocks.len());
        let mut size = 0usize;
        for (index, kind) in kinds.as_slice().iter().enumerate() {
            let Ok(kind) = Kind::try_from(*kind) else {
                return false;
            };
            let Some(bytes) = blocks
                .get(index)
                .and_then(|v| v.try_to::<PackedByteArray>().ok())
            else {
                return false;
            };
            size += bytes.len();
            if bytes.len() > 16 * 1024 * 1024 || size > 256 * 1024 * 1024 {
                return false;
            }
            let Ok(actor) = Actor::restore(kind, bytes.as_slice()) else {
                return false;
            };
            actors.push(actor);
        }
        let Ok(next_id) = u64::try_from(next_id) else {
            return false;
        };
        let Ok(core) = Actors::from_entries(next_id, actors) else {
            return false;
        };
        self.core = core;
        true
    }
    #[func]
    fn actor_state(&self, id: u32) -> PackedByteArray {
        self.core
            .get(id)
            .and_then(|a| a.checkpoint().ok())
            .map_or_else(PackedByteArray::new, |b| b.as_slice().into())
    }
    #[func]
    fn identities(&self) -> PackedInt64Array {
        self.core
            .entities()
            .iter()
            .flat_map(|i| [i64::from(i.id), i.kind as i64])
            .collect()
    }
    #[func]
    fn next_id(&self) -> i64 {
        self.core.entities().next_id() as i64
    }
    #[func]
    fn spawn(&mut self, kind: u8, bytes: PackedByteArray) -> u32 {
        Kind::try_from(kind)
            .and_then(|k| Actor::restore(k, bytes.as_slice()))
            .and_then(|a| self.core.spawn(a))
            .unwrap_or(0)
    }
    #[func]
    fn remove(&mut self, id: u32) -> bool {
        self.core.remove(id).is_some()
    }
    #[func]
    fn board(&mut self, vehicle: u32, soldier: u32, seats: u32, helicopter: bool) -> i32 {
        self.core
            .board(vehicle, soldier, seats, helicopter)
            .map_or(-1, i32::from)
    }
    #[func]
    fn checkpoint(&self) -> PackedByteArray {
        self.core
            .checkpoint()
            .map_or_else(|_| PackedByteArray::new(), |b| b.as_slice().into())
    }
    #[func]
    fn restore(&mut self, bytes: PackedByteArray) -> bool {
        let Ok(core) = Actors::restore(bytes.as_slice()) else {
            return false;
        };
        self.core = core;
        true
    }
    #[func]
    fn release_all(&mut self, id: u32) -> PackedInt64Array {
        self.core
            .release_all(id)
            .map_or_else(|_| PackedInt64Array::new(), released)
    }
    #[func]
    fn go_down(&mut self, id: u32, now: f64) -> PackedInt64Array {
        self.core
            .go_down(id, now)
            .map_or_else(|_| PackedInt64Array::new(), released)
    }
    #[func]
    fn die(&mut self, id: u32, now: f64, ammunition: i32) -> Array<Variant> {
        match self
            .core
            .die(id, now, (ammunition >= 0).then_some(ammunition))
        {
            Ok(r) => varray![r.is_some(), &released(r.unwrap_or_default())],
            Err(_) => Array::new(),
        }
    }
    #[func]
    fn fling_from(
        &mut self,
        id: u32,
        center: Vector3,
        power: f64,
        mut rng: Gd<crate::simulation_random::SimulationRandomCore>,
    ) -> Array<Variant> {
        match self
            .core
            .fling_from(id, crate::point(center), power, &mut rng.bind_mut().core)
        {
            Ok(r) => varray![r.is_some(), &released(r.unwrap_or_default())],
            Err(_) => Array::new(),
        }
    }
    #[func]
    fn drone_checkpoint(
        meta: PackedInt64Array,
        warhead: f64,
        flight: PackedByteArray,
    ) -> PackedByteArray {
        if meta.len() != 6 {
            return PackedByteArray::new();
        }
        let result = (|| {
            let d = Drone {
                id: u32::try_from(meta[0]).ok()?,
                team: i8::try_from(meta[1]).ok()?,
                operator: u32::try_from(meta[2]).ok()?,
                target: u32::try_from(meta[3]).ok()?,
                operator_at_spawn: u32::try_from(meta[4]).ok()?,
                target_at_spawn: u32::try_from(meta[5]).ok()?,
                warhead,
                flight: DroneFlight::restore(flight.as_slice()).ok()?,
            };
            d.checkpoint().ok()
        })();
        result.map_or_else(PackedByteArray::new, |b| b.as_slice().into())
    }
    #[func]
    fn drone_state(&self, id: u32) -> Array<Variant> {
        let Some(Actor::Drone(d)) = self.core.get(id) else {
            return Array::new();
        };
        let f = d.flight;
        varray![
            vector(f.position),
            vector(f.velocity),
            vector(f.target),
            f.life,
            f.phase as i32,
            f.diving,
            f.dead,
            f64::from(f.yaw),
            i64::from(d.operator),
            i64::from(d.target),
            i64::from(d.operator_at_spawn),
            i64::from(d.target_at_spawn),
            d.warhead
        ]
    }
    #[func]
    fn step_drone(
        &mut self,
        id: u32,
        dt: f64,
        mut collision: Gd<crate::collision_index::CollisionIndexCore>,
        map_half: f64,
    ) -> Array<Variant> {
        impact(
            self.core
                .step_drone(id, dt, &mut collision.bind_mut().core, map_half as f32),
        )
    }
    #[func]
    fn detonate_drone(&mut self, id: u32) -> Array<Variant> {
        impact(self.core.detonate_drone(id))
    }
    #[func]
    fn shoot_drone(&mut self, id: u32) -> i32 {
        self.core.shoot_drone(id).map_or(-1, i32::from)
    }
}
