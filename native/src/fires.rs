//! The reference fixture binds existing retained state; the standalone core has no Godot objects.
use crate::actors::{read_squads, write_squads, ActorStateCore};
use crate::battle_stats::BattleStatsCore;
use crate::deferred_effects::DeferredEffectsCore;
use crate::simulation_random::SimulationRandomCore;
use crate::spatial::SpatialIndexCore;
use crate::squad::SquadStateCore;
use crate::visibility::VisibilityCore;
use crate::world_geometry::WorldGeometryCore;
use frontline_core::fires::{BuildingProfile, Context, Event, Fires, ManProfile};
use godot::prelude::*;
use std::collections::BTreeMap;

struct Profile {
    man: ManProfile,
    building: BuildingProfile,
    role: String,
}
struct State {
    actors: Gd<ActorStateCore>,
    geometry: Gd<WorldGeometryCore>,
    units: Gd<SpatialIndexCore>,
    squads: Array<Gd<SquadStateCore>>,
    battle: Gd<BattleStatsCore>,
    deferred: Gd<DeferredEffectsCore>,
    visibility: Gd<VisibilityCore>,
    rng: Gd<SimulationRandomCore>,
    profiles: BTreeMap<u32, Profile>,
}
#[derive(GodotClass)]
#[class(base=RefCounted, init)]
pub(crate) struct FiresCore {
    base: Base<RefCounted>,
    pub(crate) core: Option<Fires>,
    state: Option<State>,
}
impl FiresCore {
    fn apply(
        &mut self,
        now: f64,
        town: Rect2,
        call: impl FnOnce(&mut Fires, &mut Context<'_>) -> Result<Vec<Event>, &'static str>,
    ) -> bool {
        let (Some(fires), Some(s)) = (&mut self.core, &mut self.state) else {
            return false;
        };
        let mut actors = s.actors.bind_mut();
        if actors
            .core
            .iter()
            .any(|a| !s.profiles.contains_key(&a.identity().id))
        {
            return false;
        }
        let mut geometry = s.geometry.bind_mut();
        let units = s.units.bind();
        let (Some(geometry), Some(units)) = (&mut geometry.core, &units.core) else {
            return false;
        };
        let Some(mut squads) = read_squads(&s.squads) else {
            return false;
        };
        let mut battle = s.battle.bind_mut();
        let mut deferred = s.deferred.bind_mut();
        let mut visibility = s.visibility.bind_mut();
        let mut rng = s.rng.bind_mut();
        let result = call(
            fires,
            &mut Context {
                actors: &mut actors.core,
                geometry,
                units,
                squads: &mut squads,
                battle: &mut battle.core,
                deferred: &mut deferred.core,
                visibility: &mut visibility.core,
                rng: &mut rng.core,
                now,
                town: [town.position.x, town.position.y, town.size.x, town.size.y],
                man: &|man, _| s.profiles[&man.identity.id].man,
                building: &|building| s.profiles[&building.id].building,
                role: &|man| s.profiles[&man.identity.id].role.clone(),
            },
        );
        write_squads(s.squads.clone(), squads);
        match result {
            Ok(_) => true,
            Err(error) => {
                godot_error!("{error}");
                false
            }
        }
    }
}
#[godot_api]
impl FiresCore {
    #[func]
    fn configure(&mut self, side: i32, wet: bool) -> bool {
        let Ok(fires) = Fires::new(side as usize, wet) else {
            return false;
        };
        self.core = Some(fires);
        true
    }
    #[func]
    fn bind_state(
        &mut self,
        actors: Gd<ActorStateCore>,
        geometry: Gd<WorldGeometryCore>,
        units: Gd<SpatialIndexCore>,
        squads: Array<Gd<SquadStateCore>>,
        battle: Gd<BattleStatsCore>,
        deferred: Gd<DeferredEffectsCore>,
        visibility: Gd<VisibilityCore>,
        rng: Gd<SimulationRandomCore>,
        rows: Array<Variant>,
    ) -> bool {
        if rows.len() > 100_000 {
            return false;
        }
        let parse = || -> Option<BTreeMap<u32, Profile>> {
            let mut profiles = BTreeMap::new();
            for row in rows.iter_shared() {
                let row = row.try_to::<Array<Variant>>().ok()?;
                if row.len() != 7 {
                    return None;
                }
                let id: u32 = row.get(0)?.try_to().ok()?;
                let ammo: i32 = row.get(2)?.try_to().ok()?;
                let value: f64 = row.get(3)?.try_to().ok()?;
                let cost: f64 = row.get(5)?.try_to().ok()?;
                if id == 0
                    || !value.is_finite()
                    || !(0.0..=1e15).contains(&value)
                    || !cost.is_finite()
                    || !(0.0..=1e15).contains(&cost)
                    || ammo < -1
                {
                    return None;
                }
                if profiles
                    .insert(
                        id,
                        Profile {
                            man: ManProfile {
                                bearer: row.get(1)?.try_to().ok()?,
                                ammunition: (ammo >= 0).then_some(ammo),
                                value,
                            },
                            building: BuildingProfile {
                                player: row.get(4)?.try_to().ok()?,
                                value: cost,
                            },
                            role: row.get(6)?.try_to::<GString>().ok()?.to_string(),
                        },
                    )
                    .is_some()
                {
                    return None;
                }
            }
            Some(profiles)
        };
        let Some(profiles) = parse() else {
            return false;
        };
        self.state = Some(State {
            actors,
            geometry,
            units,
            squads,
            battle,
            deferred,
            visibility,
            rng,
            profiles,
        });
        true
    }
    #[func]
    fn ignite(&mut self, id: u32, heat: f64, now: f64) -> bool {
        self.apply(now, Rect2::default(), |fires, c| {
            let mut events = vec![];
            fires.ignite(id, heat, c, &mut events)?;
            Ok(events)
        })
    }
    #[func]
    fn start_patch(&mut self, position: Vector3, radius: f64, life: f64, generation: u32) -> bool {
        self.apply(0.0, Rect2::default(), |fires, c| {
            let mut events = vec![];
            fires.start_patch(
                crate::point(position),
                radius,
                life,
                generation,
                c.geometry,
                &mut events,
            )?;
            Ok(events)
        })
    }
    #[func]
    fn blast(&mut self, position: Vector3, size: f64, radius: f64, now: f64, town: Rect2) -> bool {
        self.apply(now, town, |fires, c| {
            fires.blast(crate::point(position), size, radius, c)
        })
    }
    #[func]
    fn tick(&mut self, dt: f64, now: f64, town: Rect2) -> bool {
        self.apply(now, town, |fires, c| fires.tick(dt, c))
    }
    #[func]
    fn checkpoint(&self) -> PackedByteArray {
        self.core
            .as_ref()
            .map_or_else(PackedByteArray::new, |f| f.checkpoint().as_slice().into())
    }
    #[func]
    fn restore(&mut self, bytes: PackedByteArray) -> bool {
        let Ok(fires) = Fires::restore(bytes.as_slice()) else {
            return false;
        };
        self.core = Some(fires);
        true
    }
    #[func]
    fn values(&self) -> Array<Variant> {
        let Some(f) = &self.core else {
            return Array::new();
        };
        let burning: Array<Variant> = f
            .burning()
            .iter()
            .map(|b| {
                varray![
                    b.structure,
                    Vector3::new(b.position.x, b.position.y, b.position.z),
                    b.radius
                ]
                .to_variant()
            })
            .collect();
        let patches: Array<Variant> = f
            .patches()
            .iter()
            .map(|p| {
                varray![
                    Vector3::new(p.position.x, p.position.y, p.position.z),
                    p.radius,
                    p.life,
                    p.generation
                ]
                .to_variant()
            })
            .collect();
        let smokes: Array<Variant> = f
            .smokes()
            .iter()
            .map(|s| {
                varray![Vector3::new(s.center.x, s.center.y, s.center.z), s.radius].to_variant()
            })
            .collect();
        varray![
            &burning,
            &patches,
            &PackedByteArray::from(f.hot()),
            &smokes,
            f.wet,
            f.clocks()[0],
            f.clocks()[1]
        ]
    }
}
