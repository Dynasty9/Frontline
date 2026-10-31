//! Damage removes shared occupants and schedules secondary effects before the next hit.
use crate::actors::{Actor, Actors};
use crate::deferred_effects::{DeferredEffects, Rubble};
use crate::infantry::Credit;
use crate::path_planner::PathPlanner;
use crate::random::SimulationRandom;
use crate::structure::Structure;
use crate::vector::Vector3;

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum Event {
    Door,
    UnderAttack,
    BuildingLost,
    FobWrecked,
    Unhidden(u32),
    ReleasedGunner(u32),
    CacheCookOff(usize),
    Debris(u8),
    TreeFall(f64),
    Rubble,
    DestroyedAlert,
    IgnitedCar,
}

#[derive(Clone, Debug, Default, PartialEq)]
pub struct Damage {
    pub applied: bool,
    pub events: Vec<Event>,
    /// The world uses the removed geometry to update collision, navigation and observations.
    pub removed: Option<Box<Structure>>,
}

impl Actors {
    pub fn release_infantry_mount(
        &mut self,
        id: u32,
        nav: &PathPlanner,
    ) -> Result<(), &'static str> {
        let s = self.soldier(id).ok_or("missing gunner")?;
        let position = self
            .structure(s.emplacement.structure as u32)
            .map(|st| st.position);
        self.soldier_mut(id).unwrap().release_mount(nav, position)
    }

    pub fn damage_structure(
        &mut self,
        id: u32,
        amount: f64,
        source: u32,
        blame: Option<&Credit>,
        now: f64,
        player_building: bool,
        car_fuel: Option<f64>,
        nav: &PathPlanner,
        deferred: &mut DeferredEffects,
        rng: &mut SimulationRandom,
    ) -> Result<Damage, &'static str> {
        if !amount.is_finite()
            || !(0.0..=1e12).contains(&amount)
            || !now.is_finite()
            || !(0.0..=1e12 - 30.0).contains(&now)
            || car_fuel.is_some_and(|v| !v.is_finite() || !(0.0..=1_000_000.0).contains(&v))
            || blame.is_some_and(|c| {
                c.owner < -2
                    || !(0..=1).contains(&c.team)
                    || c.unit.len() > 128
                    || c.unit.contains('\0')
            })
        {
            return Err("invalid shared structure damage");
        }
        let Some(st) = self.structure(id) else {
            return Ok(Damage::default());
        };
        if st.indestructible || st.gone || st.kind == "fob" && st.wrecked {
            return Ok(Damage::default());
        }
        let credit = if player_building && st.team >= 0 {
            match self.get(source) {
                Some(a) => a.credit(),
                None => blame.cloned(),
            }
            .filter(|c| c.team != st.team)
        } else {
            None
        };
        let Some(Actor::Structure(st)) = self.get_mut(id) else {
            unreachable!()
        };
        if let Some(credit) = credit {
            st.hit_by = Some(credit);
        }
        st.hp -= amount;
        let mut out = Damage {
            applied: true,
            ..Default::default()
        };
        if st.door_closed && amount >= 20.0 && st.open_door() {
            out.events.push(Event::Door);
        }
        if st.team >= 0
            && player_building
            && now > st.alert_time
            && amount > 5.0
            && !matches!(
                st.kind.as_str(),
                "trench"
                    | "sandbags"
                    | "wire"
                    | "mines"
                    | "tank_trap"
                    | "concrete_wall"
                    | "hesco"
                    | "barricade"
                    | "camo_net"
            )
        {
            st.alert_time = now + 25.0;
            out.events.push(Event::UnderAttack);
        }
        if st.hp <= 0.0 {
            st.hp = 0.0;
            let destroyed =
                self.destroy_structure(id, false, now, player_building, nav, deferred, rng)?;
            out.events.extend(destroyed.events);
            out.removed = destroyed.removed;
        } else if st.kind == "car"
            && st.burn <= 0.0
            && st.hp < st.max_hp * 0.5
            && car_fuel.is_some()
            && rng.randf() < 0.35
            && !st.burnt
            && st.fire_kind() == "car"
        {
            st.fire_kind = "car".into();
            st.fuel_max = car_fuel.unwrap() * f64::from(rng.randf_range(0.8, 1.2));
            st.fuel = st.fuel_max;
            st.burn = 0.3;
            out.events.push(Event::IgnitedCar);
        }
        Ok(out)
    }

    pub fn destroy_structure(
        &mut self,
        id: u32,
        quiet: bool,
        now: f64,
        player_building: bool,
        nav: &PathPlanner,
        deferred: &mut DeferredEffects,
        rng: &mut SimulationRandom,
    ) -> Result<Damage, &'static str> {
        if !now.is_finite() || !(0.0..=1e12 - 30.0).contains(&now) {
            return Err("invalid structure destruction time");
        }
        let Some(st) = self.structure(id) else {
            return Ok(Damage::default());
        };
        let mut events = vec![];
        if st.team >= 0 && player_building {
            events.push(Event::BuildingLost);
        }
        let position = st.position;
        match st.kind.as_str() {
            "fob" => {
                let Some(Actor::Structure(st)) = self.get_mut(id) else {
                    unreachable!()
                };
                st.wrecked = true;
                events.push(Event::FobWrecked);
                return Ok(Damage {
                    applied: true,
                    events,
                    removed: None,
                });
            }
            "tunnel" => {
                let occupants = st.inside.clone();
                for who in occupants {
                    if let Some(s) = self.soldier_mut(who) {
                        let exit = position
                            + Vector3::new(
                                rng.randf_range(-2.0, 2.0),
                                0.0,
                                rng.randf_range(-2.0, 2.0),
                            );
                        s.unhide(exit, nav)?;
                        events.push(Event::Unhidden(who));
                    }
                }
                let Some(Actor::Structure(st)) = self.get_mut(id) else {
                    unreachable!()
                };
                st.inside.clear();
            }
            "mg_nest" | "watchtower" => {
                let gunner = st.gunner;
                if self.soldier(gunner).is_some() {
                    self.release_infantry_mount(gunner, nav)?;
                    events.push(Event::ReleasedGunner(gunner));
                }
            }
            "ammo_cache" => events.push(Event::CacheCookOff(
                deferred.cook_off(now, position, st.supply, rng)?,
            )),
            _ => (),
        }
        let st = self.structure(id).unwrap();
        if st.kind == "tree" {
            let away = st.hit_from.map_or(Vector3::ZERO, |p| position - p);
            let away = Vector3::new(away.x, 0.0, away.z);
            let angle = if away.length() > 0.2 {
                libm::atan2(-f64::from(away.x), -f64::from(away.z))
            } else {
                f64::from(rng.randf()) * std::f64::consts::TAU
            };
            events.extend([Event::Debris(8), Event::TreeFall(angle)]);
        } else {
            if !quiet {
                events.push(Event::Debris(14));
            }
            if !quiet
                && st.size.x > 3.0
                && matches!(
                    st.kind.as_str(),
                    "house_wall"
                        | "tall_wall"
                        | "barracks"
                        | "factory"
                        | "research"
                        | "concrete_wall"
                        | "medic_tent"
                )
            {
                deferred.defer_rubble(Rubble {
                    position,
                    yaw: st.yaw,
                    size: Vector3::new(
                        (f64::from(st.size.x) * 0.8) as f32,
                        0.0,
                        if st.size.z < 2.0 {
                            1.6
                        } else {
                            (f64::from(st.size.z) * 0.6) as f32
                        },
                    ),
                })?;
                events.push(Event::Rubble);
            }
            if st.team >= 0 && player_building {
                events.push(Event::DestroyedAlert);
            }
        }
        let Some(Actor::Structure(mut removed)) = self.remove(id) else {
            unreachable!()
        };
        removed.gone = true;
        Ok(Damage {
            applied: true,
            events,
            removed: Some(removed),
        })
    }
}
