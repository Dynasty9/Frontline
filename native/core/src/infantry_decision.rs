//! Infantry decisions run in their existing priority order against owned shared state.
use crate::actors::Actors;
use crate::breach_selection::{self, Building};
use crate::grenade_attack::{Contact, Input};
use crate::infantry::{BreachChoice, Goal, Infantry};
use crate::infantry_action::{Action, Round, Throw};
use crate::infantry_controller::Task;
use crate::infantry_cover::CoverWorld;
use crate::infantry_orders::RouteOrder;
use crate::infantry_reflex::Reflex;
use crate::infantry_vitals::Life;
use crate::infantry_weapon::Weapon;
use crate::random::SimulationRandom;
use crate::spatial::{SpatialIndex, STRUCTURE_CELL, UNIT_CELL};
use crate::squad::Squad;
use crate::structure::Structure;
use crate::vector::Vector3;
use crate::vehicle::Vehicle;
use crate::visibility::Visibility;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Speech {
    Reflex(u8),
    Scavenge(u8),
    Reload(u8),
    Special(u8),
    Cook(u8),
    Throw(u8),
    Breach(u8),
    OutOfAmmo,
    Supply(bool),
}
#[derive(Clone, Debug, Default, PartialEq)]
pub struct Decision {
    pub speech: Vec<Speech>,
    pub stats: Vec<&'static str>,
    pub route: Option<RouteOrder>,
    pub cancel_path: bool,
    pub reflex_leaf: u8,
}
#[derive(Clone, Copy, Debug)]
pub struct Profile {
    pub stock: Option<(i32, Weapon)>,
    pub weapon_range: Option<f64>,
    pub weapon_ammunition: i32,
    pub bearer: bool,
}
impl Profile {
    fn valid(self) -> bool {
        self.stock
            .is_none_or(|(capacity, w)| (0..=1_000_000).contains(&capacity) && w.valid())
            && self
                .weapon_range
                .is_none_or(|r| r.is_finite() && (0.0..=1_000_000.0).contains(&r))
            && (0..=1_000_000).contains(&self.weapon_ammunition)
    }
}
fn flat(p: Vector3) -> Vector3 {
    Vector3::new(p.x, 0.0, p.z)
}
fn building(st: &Structure) -> Building {
    Building {
        id: st.id.into(),
        position: st.position,
        size: st.size,
        yaw: st.yaw,
        kind: if st.kind == "floor" {
            0
        } else if st.kind == "house_wall" && matches!(st.variant, 1 | 2) {
            st.variant as u8
        } else {
            3
        },
        gone: false,
        wrecked: st.wrecked,
    }
}

impl Actors {
    pub fn infantry_house_at(
        &self,
        position: Vector3,
        structures: &SpatialIndex,
    ) -> Result<Option<u32>, &'static str> {
        let houses: Vec<_> = self
            .structures_near(structures, position, 9.0, true)?
            .into_iter()
            .filter_map(|id| self.structure(id))
            .map(building)
            .collect();
        Ok(breach_selection::house_at(position, &houses)?.map(|id| id as u32))
    }
    fn building_contacts(
        &self,
        q: &mut Squad,
        now: f64,
        structures: &SpatialIndex,
    ) -> Result<(), &'static str> {
        if q.buildings_at >= 0.0 && now - q.buildings_at < 0.75 {
            return Ok(());
        }
        let mut buildings = Vec::new();
        for k in &q.known {
            let Some(s) = self
                .soldier(k.id)
                .filter(|s| s.vitals.life == Life::Alive && now - k.report.time <= 25.0)
            else {
                continue;
            };
            if let Some(house) = self.infantry_house_at(s.motion.position, structures)? {
                buildings.push((k.id, house));
            }
        }
        q.buildings = buildings;
        q.buildings_at = now;
        Ok(())
    }
    fn select_infantry_breach(
        &mut self,
        id: u32,
        now: f64,
        armed: bool,
        bearer: bool,
        squad: Option<&mut Squad>,
        world: &CoverWorld<'_>,
    ) -> Result<bool, &'static str> {
        let s = self.soldier(id).unwrap();
        if now < s.entry.next_check {
            return Ok(false);
        }
        self.soldier_mut(id).unwrap().entry.next_check = now + 1.5;
        let s = self.soldier(id).unwrap();
        if s.grenades.frags <= 0
            || s.vitals.suppression > 50.0
            || s.emplacement.structure != 0
            || bearer
            || !armed
        {
            return Ok(false);
        }
        let Some(q) = squad else {
            return Ok(false);
        };
        if q.breach_by != id
            && self
                .soldier(q.breach_by)
                .is_some_and(|s| s.vitals.life == Life::Alive && s.duty.kind == Task::Breach)
        {
            return Ok(false);
        }
        let mine = self.infantry_house_at(s.motion.position, world.structures)?;
        self.building_contacts(q, now, world.structures)?;
        let mut contacts = Vec::new();
        let mut enemies = Vec::new();
        for &(enemy, house) in &q.buildings {
            if !self
                .soldier(enemy)
                .is_some_and(|s| s.vitals.life == Life::Alive)
            {
                continue;
            }
            let Some(h) = self.structure(house) else {
                continue;
            };
            let walls: Vec<_> = self
                .structures_near(
                    world.structures,
                    h.position,
                    f64::from(h.size.x.max(h.size.z)) * 0.5 + 1.5,
                    false,
                )?
                .into_iter()
                .filter_map(|id| self.structure(id))
                .map(building)
                .collect();
            contacts.push(breach_selection::Contact {
                house: building(h),
                enemy_alive: true,
                openings: breach_selection::openings(building(h), &walls)?,
            });
            enemies.push(enemy);
        }
        let mates: Vec<_> = q
            .members
            .iter()
            .filter_map(|&other| self.soldier(other))
            .map(|m| breach_selection::Mate {
                position: m.motion.position,
                other: m.identity.id != id,
                alive: m.vitals.life == Life::Alive,
                idle: m.duty.kind == Task::Fight,
                frags: m.grenades.frags,
                mounted: m.emplacement.structure != 0,
            })
            .collect();
        let choice = breach_selection::choose(
            s.motion.position,
            s.orders.hold_position,
            mine.map(u64::from),
            &contacts,
            &mates,
            world.nav,
        )?;
        if let Some((ci, oi)) = choice {
            self.soldier_mut(id).unwrap().entry.selected = Some(BreachChoice {
                house: contacts[ci].house.id,
                opening: contacts[ci].openings[oi],
                enemy: enemies[ci].into(),
            });
        }
        Ok(choice.is_some())
    }
    fn begin_infantry_breach(
        &mut self,
        id: u32,
        now: f64,
        q: &mut Squad,
        world: &CoverWorld<'_>,
        rng: &mut SimulationRandom,
        out: &mut Decision,
    ) -> Result<(), &'static str> {
        let mut s = self.soldier(id).unwrap().clone();
        let choice = s.entry.selected.ok_or("missing selected breach")?;
        let mut random = *rng;
        s.clear_duty(world.nav, None);
        s.entry.clear = false;
        s.entry.no_frag = false;
        s.entry.house = choice.house;
        s.entry.opening = Some(choice.opening);
        s.entry.cooking_started = -1.0;
        s.entry.grenade = 0;
        s.entry.reordered = false;
        s.duty.kind = Task::Breach;
        s.duty.entity = choice.opening.id;
        s.duty.partner = choice.enemy;
        s.duty.phase = 0;
        s.duty.timer = now;
        s.duty.position = world
            .nav
            .nearest_walkable(crate::breach::stack_spot(
                s.motion.position,
                choice.opening.center,
                choice.opening.normal,
                choice.opening.door,
            )?)
            .unwrap();
        s.cover.at_cover = false;
        s.weapon.peek_up = false;
        let own_danger = s.vitals.suppression > 5.0 || !s.fight.visible_targets.is_empty();
        let danger = own_danger || q.combat_status(now);
        let route = s.go_to(s.duty.position, Goal::Task, if danger { 2 } else { 1 })?;
        let cue = (random.randi() % 4) as u8;
        s.vitals.speech_cooldown = 2.6;
        *self.soldier_mut(id).unwrap() = s;
        q.breach_by = id;
        if !own_danger {
            q.in_combat(now);
        }
        *rng = random;
        out.route = Some(route);
        out.speech.push(Speech::Breach(cue));
        out.stats.push("breach");
        Ok(())
    }
    fn try_owned_grenade(
        &mut self,
        id: u32,
        now: f64,
        squad: Option<&Squad>,
        units: &SpatialIndex,
        rng: &mut SimulationRandom,
        out: &mut Decision,
    ) -> Result<bool, &'static str> {
        let s = self.soldier(id).unwrap();
        if s.grenades.frags <= 0
            || now < s.grenades.cooldown
            || s.vitals.suppression > 70.0
            || s.is_moving()
            || squad.is_none_or(|q| q.ambush)
        {
            return Ok(false);
        }
        let q = squad.unwrap();
        let mut contacts = Vec::new();
        for k in &q.known {
            let Some(e) = self.soldier(k.id) else {
                continue;
            };
            if e.vitals.life != Life::Alive || now - k.report.time > 6.0 {
                continue;
            }
            let d = f64::from(flat(e.motion.position - s.motion.position).length());
            if !(9.0..=27.0).contains(&d)
                || s.fight.visible_targets.contains(&u64::from(k.id))
                    && e.posture == crate::infantry_pose::Posture::Stand
            {
                continue;
            }
            let nearby = self
                .units_near(units, e.motion.position, 4.0, -1)?
                .into_iter()
                .filter_map(|id| self.soldier(id))
                .filter(|o| {
                    o.identity.id != k.id
                        && o.identity.team == e.identity.team
                        && o.vitals.life == Life::Alive
                })
                .count() as u32;
            contacts.push(Contact {
                id: k.id.into(),
                position: e.motion.position,
                alive: true,
                age: now - k.report.time,
                visible: s.fight.visible_targets.contains(&u64::from(k.id)),
                posture: e.posture,
                hard_cover: e.cover.at_cover && e.cover.material >= 2,
                nearby_allies: nearby,
            });
        }
        let mut next = s.clone();
        let mut random = *rng;
        let chosen = next.grenades.advance(
            Input {
                position: s.motion.position,
                time: now,
                suppression: s.vitals.suppression,
                squad: true,
                ambush: false,
                moving: false,
            },
            &contacts,
            &mut random,
        )?;
        if let Some(chosen) = chosen {
            let target = self.soldier(chosen.target as u32).unwrap();
            let cook = crate::grenade_reaction::cook_time(
                s.identity.team.into(),
                chosen.distance,
                target.cover.at_cover && target.cover.material >= 2,
                &mut random,
            )?;
            let cue = if cook > 0.0 {
                next.begin_action(Action::Cook, cook, None)?;
                next.action.queued_throw = Some(Throw {
                    position: chosen.position,
                    round: Round::Frag,
                    fuse: 3.4 - cook - 0.6,
                });
                (random.randf() < 0.4).then(|| Speech::Cook((random.randi() % 3) as u8))
            } else {
                next.begin_action(
                    Action::Throw(Throw {
                        position: chosen.position,
                        round: Round::Frag,
                        fuse: 3.4,
                    }),
                    0.6,
                    None,
                )?;
                Some(Speech::Throw((random.randi() % 3) as u8))
            };
            if let Some(cue) = cue {
                next.vitals.speech_cooldown = 2.6;
                out.speech.push(cue);
            }
            out.stats.push("frag_auto");
            if cook > 0.0 {
                out.stats.push("frag_cooked");
            }
            out.cancel_path = true;
        }
        *self.soldier_mut(id).unwrap() = next;
        *rng = random;
        Ok(chosen.is_some())
    }

    pub fn think_infantry(
        &mut self,
        id: u32,
        now: f64,
        profile: Profile,
        mut squad: Option<&mut Squad>,
        world: &mut CoverWorld<'_>,
        visibility: &Visibility,
        owned_structures: &[u32],
        armor: impl Fn(&Vehicle) -> i32,
        bearer: impl Fn(&Infantry) -> bool,
        rng: &mut SimulationRandom,
    ) -> Result<Decision, &'static str> {
        let s = self.soldier(id).ok_or("missing thinking infantry")?;
        if !now.is_finite()
            || now.abs() > 1e12 - 100.0
            || !profile.valid()
            || world.nav.side() != world.terrain.n
            || (!world.heat.is_empty()
                && world.heat.len() != (world.terrain.n.div_ceil(4) + 1).pow(2))
            || (!world.deck.is_empty() && world.deck.len() != world.terrain.n * world.terrain.n)
            || owned_structures.len() > 100_000
            || owned_structures.contains(&0)
            || world.units.cell_size() != UNIT_CELL
            || world.structures.cell_size() != STRUCTURE_CELL
            || squad.as_ref().is_some_and(|q| q.id != s.identity.squad)
        {
            return Err("invalid infantry decision context");
        }
        let mut out = Decision::default();
        if s.duty.kind == Task::Smother {
            return Ok(out);
        }
        let busy = s.duty.kind.busy(s.duty.phase, profile.bearer);
        for kind in if busy {
            &[Reflex::BusyGrenade, Reflex::BusyShell][..]
        } else {
            &[Reflex::Grenade, Reflex::Shell, Reflex::Drone][..]
        } {
            let result = self.react_infantry(
                id,
                *kind,
                now,
                profile.stock.is_some(),
                squad.as_deref_mut(),
                world.units,
                world.nav,
                world.collision,
                rng,
            )?;
            out.speech
                .extend(result.speech.into_iter().map(Speech::Reflex));
            out.stats.extend(result.stats);
            out.cancel_path |= result.cancel_path;
            if result.handled {
                out.reflex_leaf = result.leaf;
                return Ok(out);
            }
        }
        if busy {
            return Ok(out);
        }
        if !matches!(self.soldier(id).unwrap().duty.kind, Task::Man | Task::Pilot)
            && self
                .try_infantry_melee(id, now, profile.stock.is_some(), world.units)?
                .started
        {
            out.cancel_path = true;
            out.stats.push("melee");
            return Ok(out);
        }
        if let Some(found) = self.scavenge_infantry(id, now, profile.stock, world.units, rng)? {
            out.stats.push("scavenge");
            out.speech.extend(found.speech.map(Speech::Scavenge));
            out.speech.extend(found.reload_speech.map(Speech::Reload));
        }
        if self.soldier(id).unwrap().duty.kind != Task::Fight {
            return Ok(out);
        }
        if self.select_infantry_breach(
            id,
            now,
            profile.weapon_range.is_some(),
            profile.bearer,
            squad.as_deref_mut(),
            world,
        )? {
            self.begin_infantry_breach(
                id,
                now,
                squad.as_deref_mut().unwrap(),
                world,
                rng,
                &mut out,
            )?;
        } else {
            let mortar = self.try_infantry_mortar(
                id,
                now,
                squad.as_deref_mut(),
                world.units,
                owned_structures,
                rng,
            )?;
            out.speech.extend(mortar.speech.map(Speech::Special));
            let mut started = mortar.started;
            if !started {
                let r = self.try_infantry_rocket(
                    id,
                    now,
                    squad.as_deref(),
                    world.terrain,
                    world.deck,
                    world.collision,
                    visibility,
                )?;
                out.speech.extend(r.speech.map(Speech::Special));
                started = r.started;
                if started {
                    out.stats.push("rocket");
                }
            }
            if !started {
                let r = self.try_infantry_drone(id, now, world.units, armor, bearer, rng)?;
                out.speech.extend(r.speech.map(Speech::Special));
                started = r.started;
                if started {
                    out.stats.push("drone_launch");
                }
            }
            if !started {
                started =
                    self.try_owned_grenade(id, now, squad.as_deref(), world.units, rng, &mut out)?;
            }
            out.cancel_path |= started;
            if !started {
                if let Some(range) = profile.weapon_range {
                    let s = self.soldier(id).unwrap();
                    let empty = s.weapon.magazine + s.weapon.reserve <= 0
                        && profile.weapon_ammunition < 9000;
                    if empty && !s.fight.out_of_ammo_said {
                        let s = self.soldier_mut(id).unwrap();
                        s.fight.out_of_ammo_said = true;
                        s.vitals.speech_cooldown = 2.6;
                        out.speech.push(Speech::OutOfAmmo);
                    }
                    if empty {
                        if let Some(order) =
                            self.seek_infantry_supply(id, now, world.units, world.structures, rng)?
                        {
                            use crate::infantry_logistics::SupplySource;
                            out.stats.push(match order.source {
                                SupplySource::Body => "resupply_body",
                                SupplySource::Cache => "resupply_cache",
                                SupplySource::Fob => "resupply_fob",
                            });
                            if order.source != SupplySource::Body {
                                out.speech
                                    .push(Speech::Supply(order.source == SupplySource::Cache));
                            }
                            out.route = Some(order.route);
                        }
                    }
                    if out.route.is_none() {
                        out.route = self
                            .review_infantry_cover(
                                id,
                                now,
                                range,
                                false,
                                squad.as_deref_mut(),
                                world,
                                rng,
                            )?
                            .and_then(|c| c.route);
                    }
                }
            }
        }
        let s = self.soldier(id).unwrap();
        let sector = if let Some(q) = squad.filter(|q| q.tactical(now) && !s.is_moving()) {
            let threats = q.sector_threats(s.motion.position, now, self);
            s.sector_direction(
                &threats,
                q.centroid(now, self),
                q.members.len(),
                q.members.last() == Some(&id),
            )?
        } else {
            Vector3::ZERO
        };
        self.soldier_mut(id).unwrap().fight.sector = sector;
        Ok(out)
    }
}
