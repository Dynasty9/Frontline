//! Tents, gun positions and caches change shared soldiers before the next building acts.
use crate::actors::Actor;
use crate::entities::Kind;
use crate::infantry::{Goal, Infantry};
use crate::infantry_controller::Task;
use crate::infantry_fire::MountedGun;
use crate::infantry_pose::Posture;
use crate::infantry_spawn::{self, Loadout, Spawn};
use crate::infantry_supply;
use crate::infantry_vitals::Life;
use crate::structure::{Structure, Tick, TownEconomy};
use crate::vector::{normalized, Vector3};
use crate::vehicle_loss_world::Context;

#[derive(Clone, Copy)]
pub struct Supply {
    pub ammunition: Option<i32>,
    pub frags: i32,
    pub loadout: Option<infantry_supply::Loadout>,
}
impl Supply {
    pub fn valid(self) -> bool {
        self.ammunition.is_none_or(|v| (1..=1_000_000).contains(&v))
            && (0..=1_000_000).contains(&self.frags)
            && self.loadout.is_none_or(infantry_supply::Loadout::valid)
    }
}
pub struct Profiles<'a> {
    pub supply: &'a dyn Fn(&Infantry) -> Supply,
    pub bearer: &'a Loadout,
    pub armor_upgrade: bool,
    pub grenade_upgrade: bool,
    pub gun: Option<MountedGun>,
}
#[derive(Clone, Debug, PartialEq)]
pub enum Event {
    Born {
        tent: u32,
        soldier: u32,
    },
    Reload {
        soldier: u32,
        variant: u8,
    },
    CacheEmpty {
        id: u32,
        team: i8,
        position: Vector3,
    },
    Despawn(u32),
    Stat(&'static str),
}
fn flat(v: Vector3) -> Vector3 {
    Vector3::new(v.x, 0.0, v.z)
}
fn structure<'a>(ctx: &'a mut Context<'_>, id: u32) -> &'a mut Structure {
    let Some(Actor::Structure(st)) = ctx.actors.get_mut(id) else {
        unreachable!()
    };
    st
}
impl Context<'_> {
    pub fn advance_structure_service(
        &mut self,
        id: u32,
        dt: f64,
        p: &Profiles<'_>,
    ) -> Result<Vec<Event>, &'static str> {
        let st = self
            .actors
            .structure(id)
            .filter(|s| !s.gone)
            .ok_or("missing service building")?;
        if !crate::infantry_fight_world::valid_step(dt, self.now, p.gun)
            || !matches!(
                st.kind.as_str(),
                "medic_tent"
                    | "watchtower"
                    | "mg_nest"
                    | "hmg_nest"
                    | "mortar_pit"
                    | "at_post"
                    | "ammo_cache"
            )
            || matches!(st.kind.as_str(), "mg_nest" | "hmg_nest") && p.gun.is_none()
            || !p.bearer.valid()
        {
            return Err("invalid building service update");
        }
        let tick = structure(self, id).begin_tick(
            dt,
            TownEconomy {
                stock: 0.0,
                yield_per_minute: 0.0,
                capture_pace: 0.0,
            },
        )?;
        let mut out = vec![];
        match tick {
            Tick::Tent => self.tent_service(id, p, &mut out)?,
            Tick::Mount => self.mount_service(id, p.gun, &mut out)?,
            Tick::Cache => self.cache_service(id, p.supply, &mut out)?,
            Tick::None => (),
            _ => unreachable!(),
        }
        Ok(out)
    }
    fn service_route(&mut self, id: u32, position: Vector3) -> Result<(), &'static str> {
        let s = self.actors.soldier_mut(id).unwrap();
        let route = s.go_to(position, Goal::Task, 1)?;
        self.geometry.navigation.submit_infantry(
            s,
            route,
            self.now,
            self.rng,
            crate::traversal::Ground::new(&self.geometry.terrain, &self.geometry.deck),
        )?;
        Ok(())
    }
    fn tent_service(
        &mut self,
        id: u32,
        p: &Profiles<'_>,
        out: &mut Vec<Event>,
    ) -> Result<(), &'static str> {
        let st = self.actors.structure(id).unwrap();
        let team = st.team;
        let position = st.position;
        let keep = st
            .bearers
            .iter()
            .copied()
            .filter(|&id| {
                self.actors.soldier(id).is_some_and(|s| {
                    !s.identity.gone && s.vitals.life != Life::Dead && s.identity.team == team
                })
            })
            .collect::<Vec<_>>();
        let st = structure(self, id);
        st.bearers = keep;
        if st.bearers.len() < 2 {
            st.bearer_timer -= 1.0;
            if st.bearer_timer <= 0.0 {
                let at = st.position
                    + Vector3::new(-libm::sin(st.yaw) as f32, 0.0, -libm::cos(st.yaw) as f32)
                        * (f64::from(st.size.z) * 0.5 + 3.0) as f32;
                let name = infantry_spawn::random_name(&self.names[team as usize], self.rng)?;
                let soldier = self.actors.spawn_infantry(
                    Spawn {
                        team,
                        owner: -1 - i32::from(team),
                        position: at,
                        yaw: 0.0,
                        name,
                        squad: 0,
                        life: Life::Alive,
                        posture: Posture::Stand,
                        armor_upgrade: p.armor_upgrade,
                        grenade_upgrade: p.grenade_upgrade,
                    },
                    p.bearer,
                    self.rng,
                )?;
                self.actors.soldier_mut(soldier).unwrap().links.home = u64::from(id);
                let st = structure(self, id);
                st.bearer_timer = 25.0;
                st.bearers.push(soldier);
                out.push(Event::Born { tent: id, soldier });
            }
        }
        let st = self.actors.structure(id).unwrap();
        let idle = st
            .bearers
            .iter()
            .copied()
            .filter(|&id| {
                self.actors
                    .soldier(id)
                    .is_some_and(|s| s.vitals.life == Life::Alive && s.duty.kind == Task::Fight)
            })
            .collect::<Vec<_>>();
        if idle.len() >= 2 || idle.len() == 1 && st.bearers.len() == 1 {
            let mut nearest = 120.0;
            let mut patient = None;
            for a in self.actors.iter_kind(Kind::Soldier) {
                let Actor::Soldier(s) = a else { unreachable!() };
                if s.identity.team != team
                    || (self.movement)(s).bearer
                    || s.links.stretcher_claimed
                    || !s.links.carried_by.is_empty()
                    || s.links.dragged_by != 0
                {
                    continue;
                }
                let mut distance = f64::from(flat(s.motion.position - position).length());
                if s.vitals.life == Life::Downed
                    && self.now - s.vitals.downed_at > 6.0
                    && s.links.rescue_claimed == 0
                {
                    distance -= 30.0;
                } else if s.vitals.life != Life::Dead || self.now - s.vitals.dead_at >= 240.0 {
                    continue;
                }
                if distance < nearest {
                    nearest = distance;
                    patient = Some((s.identity.id, s.motion.position));
                }
            }
            if let Some((patient, at)) = patient {
                let partner = idle.get(1).copied().unwrap_or(0);
                for (soldier, other, front) in [(idle[0], partner, true), (partner, idle[0], false)]
                {
                    if soldier == 0 {
                        continue;
                    }
                    self.actors.clear_infantry_duty(
                        soldier,
                        &self.geometry.navigation.planner,
                        self.squads,
                        crate::traversal::Ground::new(&self.geometry.terrain, &self.geometry.deck),
                    )?;
                    let s = self.actors.soldier_mut(soldier).unwrap();
                    s.duty.kind = Task::Stretcher;
                    s.duty.entity = u64::from(patient);
                    s.duty.partner = u64::from(other);
                    s.duty.phase = 0;
                    s.links.home = u64::from(id);
                    s.duty.front = front;
                    out.push(Event::Stat("stretcher_job"));
                    self.service_route(soldier, at + Vector3::X * if front { 1.1 } else { -1.1 })?;
                }
                self.actors
                    .soldier_mut(patient)
                    .unwrap()
                    .links
                    .stretcher_claimed = true;
            }
        }
        Ok(())
    }
    fn mount_service(
        &mut self,
        id: u32,
        gun: Option<MountedGun>,
        out: &mut Vec<Event>,
    ) -> Result<(), &'static str> {
        let st = self.actors.structure(id).unwrap();
        let mut gunner = st.gunner;
        if gunner != 0
            && !self.actors.soldier(gunner).is_some_and(|s| {
                !s.identity.gone
                    && s.vitals.life == Life::Alive
                    && s.duty.kind == Task::Man
                    && s.duty.entity == u64::from(id)
            })
        {
            gunner = 0;
        }
        if gunner == 0 {
            let position = st.position;
            let team = st.team;
            let tower = st.kind == "watchtower";
            let at = flat(st.mount_position(gun)?);
            let preferred: &[&str] = match st.kind.as_str() {
                "mg_nest" | "hmg_nest" => &["mg_gunner", "pkm"],
                "mortar_pit" => &["mortar_gunner", "r_mortar"],
                "at_post" => &["at_soldier", "rpg"],
                _ => &[],
            };
            let mut distance = 6.5;
            for who in self.actors.units_near(self.units, position, 6.5, -1)? {
                let Some(s) = self.actors.soldier(who) else {
                    continue;
                };
                if s.identity.team != team
                    || s.vitals.life != Life::Alive
                    || s.duty.kind != Task::Fight
                    || (self.movement)(s).bearer
                    || s.is_moving()
                {
                    continue;
                }
                let d = f64::from(flat(s.motion.position - position).length())
                    - if preferred.contains(&s.identity.unit.as_str()) {
                        4.0
                    } else {
                        0.0
                    };
                if d < distance {
                    distance = d;
                    gunner = who;
                }
            }
            if gunner != 0 {
                self.actors.clear_infantry_duty(
                    gunner,
                    &self.geometry.navigation.planner,
                    self.squads,
                    crate::traversal::Ground::new(&self.geometry.terrain, &self.geometry.deck),
                )?;
                let s = self.actors.soldier_mut(gunner).unwrap();
                s.duty.kind = Task::Man;
                s.duty.entity = u64::from(id);
                s.duty.phase = 0;
                s.emplacement.structure = u64::from(id);
                let dest = at
                    + if tower {
                        normalized(flat(s.motion.position - position)) * 1.8
                    } else {
                        Vector3::ZERO
                    };
                out.push(Event::Stat("manned"));
                self.service_route(gunner, dest)?;
            }
        }
        let st = self.actors.structure(id).unwrap();
        let up = st.kind == "watchtower"
            && self
                .actors
                .soldier(gunner)
                .is_some_and(|s| s.duty.phase == 2);
        if up != st.manned && up {
            out.push(Event::Stat("tower_manned"));
        }
        let st = structure(self, id);
        st.gunner = gunner;
        st.manned = up;
        Ok(())
    }
    pub fn resupply_at(
        &mut self,
        position: Vector3,
        radius: f64,
        team: i8,
        profile: &dyn Fn(&Infantry) -> Supply,
    ) -> Result<Vec<Event>, &'static str> {
        let mut out = vec![];
        for id in self.actors.units_near(self.units, position, radius, -1)? {
            let Some(s) = self
                .actors
                .soldier(id)
                .filter(|s| s.identity.team == team && s.vitals.life == Life::Alive)
            else {
                continue;
            };
            let p = profile(s);
            if !p.valid() {
                return Err("invalid building resupply profile");
            }
            if let Some(variant) = self
                .actors
                .soldier_mut(id)
                .unwrap()
                .resupply(0.5, p.loadout, self.rng)?
            {
                out.push(Event::Reload {
                    soldier: id,
                    variant,
                });
            }
        }
        Ok(out)
    }
    fn cache_service(
        &mut self,
        id: u32,
        profile: &dyn Fn(&Infantry) -> Supply,
        out: &mut Vec<Event>,
    ) -> Result<(), &'static str> {
        let st = self.actors.structure(id).unwrap();
        let position = st.position;
        let team = st.team;
        for soldier in self.actors.units_near(self.units, position, 7.0, -1)? {
            let Some(s) = self.actors.soldier(soldier).filter(|s| {
                s.identity.team == team
                    && s.vitals.life == Life::Alive
                    && !(self.movement)(s).bearer
            }) else {
                continue;
            };
            let p = profile(s);
            if !p.valid() {
                return Err("invalid cache resupply profile");
            }
            let fraction = p.ammunition.filter(|&n| n < 9000).map_or(1.0, |n| {
                (f64::from(s.weapon.magazine + s.weapon.reserve) / f64::from(n)).clamp(0.0, 1.0)
            });
            if fraction >= 0.98 && s.grenades.frags >= p.frags {
                continue;
            }
            if let Some(variant) = self
                .actors
                .soldier_mut(soldier)
                .unwrap()
                .resupply(0.5, p.loadout, self.rng)?
            {
                out.push(Event::Reload { soldier, variant });
            }
            structure(self, id).supply -= 0.5;
            out.push(Event::Stat("cache_draw"));
        }
        if self.actors.structure(id).unwrap().supply <= 0.0 {
            structure(self, id).supply = 0.0;
            out.push(Event::CacheEmpty { id, team, position });
            out.push(Event::Stat("cache_empty"));
            let Some(Actor::Structure(mut st)) = self.actors.remove(id) else {
                unreachable!()
            };
            st.gone = true;
            self.geometry.retire_structure(&mut st, self.actors)?;
            out.push(Event::Despawn(id));
        }
        Ok(())
    }
}
