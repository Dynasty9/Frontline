//! Destruction finishes passenger injuries, crew orders and wreck ignition before another hit.
use crate::actors::{Actor, Actors};
use crate::battle_stats::{BattleStats, Unit};
use crate::deferred_effects::DeferredEffects;
use crate::fires::{self, Fires};
use crate::infantry::Infantry;
use crate::infantry_effects::InfantryHit;
use crate::infantry_spawn::Loadout;
use crate::infantry_vitals::{DamageResult, Life};
use crate::random::SimulationRandom;
use crate::spatial::SpatialIndex;
use crate::squad::Squad;
use crate::squad_movement;
use crate::structure::Structure;
use crate::vector::Vector3;
use crate::vehicle::Vehicle;
use crate::vehicle_loss::{Crew, Wreck};
use crate::visibility::Visibility;
use crate::world_geometry::WorldGeometry;

#[derive(Clone, Copy)]
pub struct Profile<'a> {
    pub name: &'a str,
    pub crew: Crew<'a>,
    pub weight: u8,
    pub hull: Vector3,
}
pub struct Context<'a> {
    pub actors: &'a mut Actors,
    pub geometry: &'a mut WorldGeometry,
    pub units: &'a SpatialIndex,
    pub squads: &'a mut Vec<Squad>,
    pub next_squad: &'a mut u64,
    pub fires: &'a mut Fires,
    pub battle: &'a mut BattleStats,
    pub deferred: &'a mut DeferredEffects,
    pub visibility: &'a mut Visibility,
    pub rng: &'a mut SimulationRandom,
    pub now: f64,
    pub town: [f32; 4],
    pub names: &'a [Vec<String>; 2],
    pub crew_loadouts: &'a [Loadout; 2],
    pub crew_name: &'a str,
    pub team_names: &'a [&'a str; 2],
    /// Definition values and retained upgrades; these never call the engine.
    pub vehicle: &'a dyn Fn(&Vehicle) -> Profile<'a>,
    pub man: &'a dyn Fn(&Infantry, &[Squad]) -> fires::ManProfile,
    pub movement: &'a dyn Fn(&Infantry) -> squad_movement::ManProfile,
    pub building: &'a dyn Fn(&Structure) -> fires::BuildingProfile,
    pub role: &'a dyn Fn(&Infantry) -> String,
    pub automatic: &'a dyn Fn(&str) -> bool,
    pub player_building: &'a dyn Fn(&str) -> bool,
}
#[derive(Clone, Debug, PartialEq)]
pub struct Notice {
    pub id: u32,
    pub team: i8,
    pub position: Vector3,
    pub name: String,
}
impl Notice {
    fn new(v: &Vehicle, profile: Profile<'_>) -> Self {
        Self {
            id: v.id,
            team: v.team,
            position: v.position,
            name: profile.name.into(),
        }
    }
}
#[derive(Clone, Debug, PartialEq)]
pub enum Event {
    UnderFire(Notice),
    Destroyed {
        vehicle: Notice,
        supply: bool,
        helicopter: bool,
    },
    Sunk {
        vehicle: Notice,
        heavy: bool,
    },
    SlingDropped {
        id: u32,
        position: Vector3,
        impact: bool,
    },
    Passenger {
        id: u32,
        hit: InfantryHit,
    },
    TruckLost {
        vehicle: Notice,
        town: u32,
        fob: u32,
        destination: String,
        cargo: i32,
    },
    Bailout {
        vehicle: Notice,
        squad: u32,
        crew: u32,
        survivors: Vec<u32>,
    },
    Squad(squad_movement::Event),
    Despawn(u32),
    Wreck {
        id: u32,
        origin: Vector3,
        yaw: f64,
        flight: Option<Wreck>,
    },
    Fire(fires::Event),
    Stat(&'static str),
}
impl Context<'_> {
    pub fn drop_vehicle_sling(&mut self, cargo: u32) -> Result<Vec<Event>, &'static str> {
        if !self.now.is_finite() || self.now.abs() > 1e12 - 100.0 {
            return Err("invalid sling drop time");
        }
        let drop = self
            .actors
            .drop_sling(cargo, &self.geometry.navigation.planner)?;
        let actor = self.actors.vehicle(cargo).unwrap();
        self.geometry
            .refresh_vehicle_collision(actor, (self.vehicle)(actor).hull)?;
        let mut out = vec![];
        if drop.impact {
            self.damage_inner(cargo, drop.damage, 0, &mut out)?;
        }
        out.push(Event::SlingDropped {
            id: cargo,
            position: drop.position,
            impact: drop.impact,
        });
        out.push(Event::Stat("sling_dropped"));
        Ok(out)
    }
    pub fn damage(
        &mut self,
        id: u32,
        amount: f64,
        source: u32,
    ) -> Result<Vec<Event>, &'static str> {
        if !amount.is_finite()
            || !(0.0..=1e12).contains(&amount)
            || !self.now.is_finite()
            || self.now.abs() > 1e12 - 100.0
        {
            return Err("invalid world vehicle damage");
        }
        let mut out = vec![];
        self.damage_inner(id, amount, source, &mut out)?;
        Ok(out)
    }
    fn damage_inner(
        &mut self,
        id: u32,
        amount: f64,
        source: u32,
        out: &mut Vec<Event>,
    ) -> Result<(), &'static str> {
        let Some(v) = self.actors.vehicle(id).filter(|v| !v.gone && v.hp > 0.0) else {
            return Ok(());
        };
        let profile = (self.vehicle)(v);
        if profile.weight > 2
            || !profile.hull.is_finite()
            || profile.hull.min_element() <= 0.0
            || profile.hull.max_element() > 4096.0
            || profile.name.len() > 128
            || profile.name.contains('\0')
        {
            return Err("invalid lost vehicle profile");
        }
        self.battle.record_hit(id, source, amount, self.actors)?;
        let result = self.actors.vehicle_mut(id).unwrap().take_damage(
            amount,
            self.now,
            profile.crew.automatic,
        )?;
        if result.alert {
            out.push(Event::UnderFire(Notice::new(
                self.actors.vehicle(id).unwrap(),
                profile,
            )));
        }
        if result.destroyed {
            self.destroyed(id, profile, out)?;
        }
        Ok(())
    }
    fn destroyed(
        &mut self,
        id: u32,
        profile: Profile<'_>,
        out: &mut Vec<Event>,
    ) -> Result<(), &'static str> {
        out.push(Event::Stat("vehicle_destroyed"));
        let v = self.actors.vehicle(id).unwrap();
        let team = v.team;
        let notice = Notice::new(v, profile);
        let role = v
            .hit_by
            .as_ref()
            .and_then(|c| self.actors.soldier(c.soldier))
            .map_or_else(String::new, self.role);
        let description = if (0..=1).contains(&team) {
            format!("{} {} lost", self.team_names[team as usize], profile.name)
        } else {
            String::new()
        };
        self.battle.vehicle_destroyed(
            id,
            profile.crew.cost,
            self.now,
            &description,
            &role,
            self.actors,
        )?;
        let cargo = self.actors.vehicle(id).unwrap().sling_cargo;
        if self.actors.vehicle(cargo).is_some_and(|v| !v.gone) {
            self.actors.vehicle_mut(id).unwrap().sling_cargo = 0;
            out.extend(self.drop_vehicle_sling(cargo)?);
        }
        let parent = self.actors.vehicle(id).unwrap().slung_by;
        if let Some(v) = self.actors.vehicle_mut(parent) {
            v.sling_cargo = 0;
        }
        let boat = profile.crew.base == "boat";
        let blame = self.battle.blame.clone();
        let hits = self.actors.evacuate_destroyed_vehicle_with(
            id,
            boat,
            self.now,
            blame.as_ref(),
            &self.geometry.navigation.planner,
            self.units,
            self.squads,
            |s, squads| {
                let p = (self.man)(s, squads);
                (p.ammunition, p.bearer)
            },
            |actors, squads, victim| {
                Self::record_infantry_hit(
                    self.battle,
                    actors,
                    victim.soldier,
                    &victim.hit,
                    (self.man)(actors.soldier(victim.soldier).unwrap(), squads),
                    self.role,
                )
            },
            self.rng,
        )?;
        for victim in hits {
            // Evacuation only queries the static grid, so queued routes can be cancelled here.
            if victim.hit.released.is_some() {
                self.geometry
                    .navigation
                    .planner
                    .cancel(u64::from(victim.soldier));
            }
            out.push(Event::Passenger {
                id: victim.soldier,
                hit: victim.hit,
            });
        }
        let v = self.actors.vehicle(id).unwrap();
        let origin = Vector3::new(v.position.x, 0.0, v.position.z);
        let yaw = v.yaw;
        if boat {
            out.push(Event::Sunk {
                vehicle: notice,
                heavy: profile.weight >= 2,
            });
            out.push(Event::Stat("boat_sunk"));
            self.retire(id, out)?;
            return Ok(());
        }
        out.push(Event::Destroyed {
            vehicle: notice.clone(),
            supply: profile.crew.base == "supply",
            helicopter: profile.crew.helicopter,
        });
        if profile.crew.base == "supply" {
            self.truck_lost(notice.clone(), out);
        }
        let v = self.actors.vehicle(id).unwrap();
        let plan = if profile.crew.helicopter {
            None
        } else {
            Some(v.wreck_plan(
                profile.weight,
                self.now,
                &self.geometry.navigation.planner,
                self.rng,
            )?)
        };
        let overkill = -v.hp;
        let wreck = Structure {
            kind: if profile.crew.helicopter {
                "rubble"
            } else {
                "wreck"
            }
            .into(),
            variant: if profile.crew.helicopter {
                9
            } else if profile.weight >= 2 {
                6
            } else {
                8
            },
            position: plan.map_or(origin, |p| p.position),
            yaw: plan.map_or(yaw, |p| p.yaw),
            tilt: plan.map_or([0.0; 2], |p| p.tilt),
            size: if profile.crew.helicopter {
                Vector3::ONE
            } else {
                Vector3::new(profile.hull.x, profile.hull.y.max(1.2), profile.hull.z)
            },
            wreck_kind: if profile.crew.helicopter {
                String::new()
            } else {
                v.kind.clone()
            },
            ..Default::default()
        };
        if self.squads.len() >= 100_000
            || self
                .squads
                .iter()
                .any(|s| u64::from(s.id) == *self.next_squad)
        {
            return Err("invalid crew squad identity");
        }
        let side = if team == 0 { 0 } else { 1 };
        let bailout = self.actors.bail_out_vehicle(
            id,
            overkill,
            profile.crew,
            &self.crew_loadouts[side],
            &self.names[side],
            self.next_squad,
            &self.geometry.navigation.planner,
            self.rng,
        )?;
        if let Some(q) = bailout.squad {
            let sid = q.id;
            let survivors = q.members.clone();
            self.battle.register_unit(Unit {
                key: format!("s{sid}"),
                name: q.callsign(),
                kind: self.crew_name.into(),
                team: q.team,
                owner: q.owner,
                started: self.now,
                ended: -1.0,
                men: q.members.len() as u32,
                ..Default::default()
            })?;
            self.squads.push(q);
            out.push(Event::Bailout {
                vehicle: notice,
                squad: sid,
                crew: bailout.crew,
                survivors,
            });
            out.push(Event::Stat("crew_bailout"));
            let events = squad_movement::Context {
                actors: self.actors,
                geometry: self.geometry,
                units: self.units,
                squads: self.squads,
                rng: self.rng,
                now: self.now,
                town: self.town,
                man: self.movement,
                automatic: self.automatic,
                player_building: self.player_building,
            }
            .crew_tick(sid)?;
            out.extend(events.into_iter().map(Event::Squad));
        } else if bailout.attempted {
            out.push(Event::Stat("crew_lost"));
        }
        self.retire(id, out)?;
        let wreck_id = self.geometry.spawn_structure(self.actors, wreck, None)?;
        out.push(Event::Wreck {
            id: wreck_id,
            origin,
            yaw,
            flight: plan.filter(|p| f64::from(p.velocity.length()) > 0.3),
        });
        let mut fire_events = vec![];
        let (fires, mut context) = self.fire_context();
        fires.ignite(wreck_id, 1.0, &mut context, &mut fire_events)?;
        out.extend(fire_events.into_iter().map(Event::Fire));
        Ok(())
    }
    pub(crate) fn record_infantry_hit(
        battle: &mut BattleStats,
        actors: &Actors,
        id: u32,
        hit: &InfantryHit,
        profile: fires::ManProfile,
        role: &dyn Fn(&Infantry) -> String,
    ) -> Result<(), &'static str> {
        let s = actors.soldier(id).unwrap();
        if hit.previous_life == Life::Alive {
            battle.damage(hit.credited.as_ref(), hit.damage_credited)?;
        }
        match hit.result {
            DamageResult::Down => battle.soldier_down(s, profile.bearer)?,
            DamageResult::Die => {
                let role = s
                    .identity
                    .hit_by
                    .as_ref()
                    .and_then(|by| actors.soldier(by.soldier))
                    .map_or_else(String::new, role);
                battle.soldier_died(
                    s,
                    hit.previous_life,
                    profile.bearer,
                    profile.value,
                    actors,
                    &role,
                )?;
            }
            _ => (),
        }
        Ok(())
    }
    fn truck_lost(&mut self, vehicle: Notice, out: &mut Vec<Event>) {
        let id = vehicle.id;
        let v = self.actors.vehicle(id).unwrap();
        let town = v.source_town;
        let fob = v.destination_fob;
        let cargo = v.cargo;
        let destination = self
            .actors
            .structure(if town != 0 { town } else { fob })
            .map_or_else(String::new, |st| st.name.clone());
        if town != 0 {
            if let Some(Actor::Structure(st)) = self.actors.get_mut(town) {
                if !st.gone && st.truck == id {
                    st.truck = 0;
                    st.truck_timer = 20.0;
                    st.supply_status = "Truck destroyed".into();
                }
            }
        } else if let Some(Actor::Structure(st)) = self
            .actors
            .get_mut(fob)
            .filter(|a| matches!(a,Actor::Structure(st) if !st.gone))
        {
            st.truck = 0;
            st.truck_timer = 28.0;
            st.supply_status = "Truck destroyed".into();
        } else {
            return;
        }
        out.push(Event::Stat("truck_lost"));
        out.push(Event::TruckLost {
            vehicle,
            town,
            fob,
            destination,
            cargo,
        });
    }
    fn retire(&mut self, id: u32, out: &mut Vec<Event>) -> Result<(), &'static str> {
        self.geometry.retire_collision(id)?;
        self.actors.remove(id);
        out.push(Event::Despawn(id));
        Ok(())
    }
}
