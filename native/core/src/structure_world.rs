//! Captures change ownership, battle credit and supply roads before the next building updates.
use crate::actors::Actor;
use crate::battle_stats;
use crate::infantry::Infantry;
use crate::infantry_vitals::Life;
use crate::squad::Report;
use crate::structure::{Structure, Tick, TownEconomy};
use crate::structure_services::{self, Supply};
use crate::supply_network::SupplyNetwork;
use crate::vector::Vector3;
use crate::vehicle::Vehicle;
use crate::vehicle_damage::Armor;
use crate::world::WorldContext;
use crate::world_combat::{self, Explosion};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Victory {
    pub winner: i8,
    pub mission: bool,
}
pub struct Profiles<'a> {
    pub fob_radius: f64,
    pub town: [TownEconomy; 2],
    pub supply: &'a dyn Fn(&Infantry) -> Supply,
}
#[derive(Clone, Debug, PartialEq)]
pub struct Place {
    pub id: u32,
    pub team: i8,
    pub kind: String,
    pub name: String,
    pub position: Vector3,
    pub variant: i32,
}
impl Place {
    fn new(st: &Structure) -> Self {
        Self {
            id: st.id,
            team: st.team,
            kind: st.kind.clone(),
            name: st.name.clone(),
            position: if st.kind == "town" {
                st.zone_center.unwrap_or(st.position)
            } else {
                st.position
            },
            variant: st.variant,
        }
    }
}
#[derive(Clone, Debug, PartialEq)]
pub enum Event {
    Warning {
        place: Place,
        last_stand: bool,
    },
    Captured {
        place: Place,
        old_team: i8,
        supply: i32,
        parent: u32,
    },
    Winner(i8),
    Service(structure_services::Event),
    Combat(world_combat::Event),
    Despawn(u32),
    Stat(&'static str),
}
fn structure<'a>(ctx: &'a mut WorldContext<'_>, id: u32) -> &'a mut Structure {
    let Some(Actor::Structure(st)) = ctx.actors.get_mut(id) else {
        unreachable!()
    };
    st
}
fn fobs(ctx: &WorldContext<'_>, team: i8) -> usize {
    ctx.actors
        .simulated_structures()
        .iter()
        .filter_map(|&id| ctx.actors.structure(id))
        .filter(|st| st.kind == "fob" && st.team == team && st.built)
        .count()
}
impl WorldContext<'_> {
    pub fn check_victory(&self, victory: &mut Victory) -> Option<i8> {
        if victory.winner >= 0 || self.now < 10.0 || victory.mission {
            return None;
        }
        for team in 0..2 {
            if fobs(self, team) == 0 {
                victory.winner = 1 - team;
                return Some(victory.winner);
            }
        }
        None
    }
    pub fn advance_territory(
        &mut self,
        id: u32,
        dt: f64,
        p: &Profiles<'_>,
        network: &mut SupplyNetwork,
        victory: &mut Victory,
    ) -> Result<Vec<Event>, &'static str> {
        let st = self
            .actors
            .structure(id)
            .filter(|s| !s.gone)
            .ok_or("missing territory")?;
        if !crate::infantry_fight_world::valid_step(dt, self.now, None)
            || !matches!(st.kind.as_str(), "fob" | "town")
            || !p.fob_radius.is_finite()
            || !(0.0..=8192.0).contains(&p.fob_radius)
            || !(-1..=1).contains(&victory.winner)
            || !network.valid()
        {
            return Err("invalid territory update");
        }
        let economy = p.town[st.variant.clamp(0, 1) as usize];
        let tick = structure(self, id).begin_tick(dt, economy)?;
        if tick == Tick::None {
            return Ok(vec![]);
        }
        if let Tick::Town { count_houses: true } = tick {
            let st = self.actors.structure(id).unwrap();
            let center = st.zone_center.unwrap_or(st.position);
            let radius = st.zone_radius;
            let houses = self
                .actors
                .structures_near(&self.geometry.structures, center, radius, false)?
                .into_iter()
                .filter(|&id| {
                    let st = self.actors.structure(id).unwrap();
                    let d = st.position - center;
                    st.kind == "roof" && f64::from(Vector3::new(d.x, 0.0, d.z).length()) <= radius
                })
                .count();
            structure(self, id).count_houses(houses as u32)?;
        }
        let st = self.actors.structure(id).unwrap();
        let team = st.team;
        let position = st.position;
        let (center, radius) = if st.kind == "town" {
            (st.zone_center.unwrap_or(position), st.zone_radius)
        } else {
            (position, p.fob_radius)
        };
        let mut counts = [0; 2];
        for who in self.actors.units_near(self.units, center, radius, -1)? {
            if let Some(s) = self.actors.soldier(who).filter(|s| {
                s.vitals.life == Life::Alive
                    && (0..=1).contains(&s.identity.team)
                    && !(self.movement)(s).bearer
            }) {
                counts[s.identity.team as usize] += 1;
            }
        }
        let capture = if tick == Tick::Fob {
            let last = fobs(self, team) <= 1;
            structure(self, id).fob_capture(counts, last)?
        } else {
            let now = self.now;
            structure(self, id).town_capture(counts, now, economy)?
        };
        let mut out = vec![];
        if capture.warning {
            out.push(Event::Warning {
                place: Place::new(self.actors.structure(id).unwrap()),
                last_stand: capture.last_stand,
            });
        }
        if let Some(team) = capture.captured_by {
            self.capture_territory(id, team, p.fob_radius, network, victory, &mut out)?;
        } else if capture.resupply {
            out.extend(
                self.resupply_at(
                    position,
                    if tick == Tick::Fob {
                        p.fob_radius + 2.0
                    } else {
                        9.0
                    },
                    team,
                    p.supply,
                )?
                .into_iter()
                .map(Event::Service),
            );
        }
        Ok(out)
    }
    fn capture_territory(
        &mut self,
        id: u32,
        team: i8,
        radius: f64,
        network: &mut SupplyNetwork,
        victory: &mut Victory,
        out: &mut Vec<Event>,
    ) -> Result<(), &'static str> {
        let st = self.actors.structure(id).unwrap();
        let old = st.team;
        let town = st.kind == "town";
        let position = if town {
            st.zone_center.unwrap_or(st.position)
        } else {
            st.position
        };
        let radius = if town { st.zone_radius } else { radius };
        let owner = self
            .battle
            .taker(position, radius, team, self.actors, self.units)?;
        self.battle
            .add(owner, team, if town { 21 } else { 20 }, 1.0)?;
        self.battle.event(battle_stats::Event {
            time: self.now,
            team,
            kind: if town { "town" } else { "fob" }.into(),
            text: if town {
                format!("{} took {}", self.team_names[team as usize], st.name)
            } else {
                format!(
                    "{} captured FOB {}",
                    self.team_names[team as usize], st.name
                )
            },
        })?;
        out.push(Event::Stat(if town {
            "town_captured"
        } else {
            "fob_captured"
        }));
        self.actors.set_structure_team(id, team)?;
        let st = structure(self, id);
        st.owner = -1 - i32::from(team);
        st.supply_parent = 0;
        st.road.clear();
        st.truck = 0;
        st.truck_timer = 6.0;
        st.supply_status = "OK".into();
        if !town {
            st.queue.clear();
            out.push(Event::Captured {
                place: Place::new(st),
                old_team: old,
                supply: st.supply as i32,
                parent: 0,
            });
        }
        if old >= 0 {
            out.extend(
                network
                    .rebuild(old as u8, self.actors, self.geometry)?
                    .into_iter()
                    .map(Event::Despawn),
            );
        }
        out.extend(
            network
                .rebuild(team as u8, self.actors, self.geometry)?
                .into_iter()
                .map(Event::Despawn),
        );
        if town {
            let st = self.actors.structure(id).unwrap();
            out.push(Event::Captured {
                place: Place::new(st),
                old_team: old,
                supply: st.supply as i32,
                parent: st.supply_parent,
            });
        } else if let Some(winner) = self.check_victory(victory) {
            out.push(Event::Winner(winner));
        }
        Ok(())
    }
    pub fn advance_mine(
        &mut self,
        id: u32,
        dt: f64,
        network: &mut SupplyNetwork,
        impacts: &mut Vec<Report>,
        armor: &dyn Fn(&Vehicle) -> Armor,
    ) -> Result<Vec<Event>, &'static str> {
        let st = self
            .actors
            .structure(id)
            .filter(|s| !s.gone && s.kind == "mines")
            .ok_or("missing minefield")?;
        if !crate::infantry_fight_world::valid_step(dt, self.now, None) || !network.valid() {
            return Err("invalid mine update");
        }
        let team = st.team;
        let position = st.position;
        let owner = st.owner;
        if structure(self, id).begin_tick(
            dt,
            TownEconomy {
                stock: 0.,
                yield_per_minute: 0.,
                capture_pace: 0.,
            },
        )? == Tick::None
        {
            return Ok(vec![]);
        }
        for who in self.actors.units_near(self.units, position, 2.6, team)? {
            let a = self.actors.get(who).unwrap();
            if matches!(a,Actor::Soldier(s) if s.vitals.life!=Life::Alive) {
                continue;
            }
            let blast = Explosion {
                position: position + Vector3::new(0., 0.2, 0.),
                damage: Some(150.),
                radius: 4.,
                fling: 9.,
                anti_tank: if matches!(a, Actor::Vehicle(_)) {
                    520.
                } else {
                    0.
                },
                track: 0.85,
                team,
                owner,
                ..Default::default()
            };
            let mut out = self
                .explode(blast, network, impacts, armor)?
                .into_iter()
                .map(Event::Combat)
                .collect::<Vec<_>>();
            if let Some(Actor::Structure(mut st)) = self.actors.remove(id) {
                st.gone = true;
                self.geometry.retire_structure(&mut st, self.actors)?;
                out.push(Event::Despawn(id));
            }
            return Ok(out);
        }
        Ok(vec![])
    }
}
