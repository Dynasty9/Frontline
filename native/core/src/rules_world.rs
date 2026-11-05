//! Match rules run after squads: support, visibility, reserves, prisoners, victory and supplies.
use crate::actors::Actor;
use crate::command_ownership::Ownership;
use crate::economy::Economy;
use crate::entities::Kind;
use crate::fog::{Fog, VehicleProfile};
use crate::infantry::Infantry;
use crate::infantry_prison_owned::{Custody, CustodyProfile};
use crate::infantry_vitals::Life;
use crate::prisoner_intelligence::{Intelligence, PrisonerIntelligence};
use crate::rules_logistics::{self, TruckProfile};
use crate::squad_birth::Definition;
use crate::state_codec::{Reader, Writer};
use crate::structure::Structure;
use crate::structure_world::Victory;
use crate::supply_network::SupplyNetwork;
use crate::support_calls::{self, SupportCalls};
use crate::vector::Vector3;
use crate::vehicle::Vehicle;
use crate::world::WorldContext;

#[derive(Clone, Debug, Default, PartialEq)]
pub struct Rules {
    pub network: SupplyNetwork,
    pub economy: Economy,
    pub fog: Fog,
    pub support: SupportCalls,
    pub prisoners: PrisonerIntelligence,
    pub reserve_at: [f64; 2],
    pub visibility_timer: f64,
    pub second_timer: f64,
    pub income: [Vec<(f64, i32)>; 2],
    pub fob_names_used: [u64; 2],
}
#[derive(Clone, Copy)]
pub struct PrisonerProfile<'a> {
    pub weapon: Option<(&'a str, i32)>,
    pub squad_name: &'a str,
}
pub struct Profiles<'a> {
    pub reserves: [Definition<'a>; 2],
    pub truck: TruckProfile<'a>,
    pub vehicle: &'a dyn Fn(&Vehicle) -> VehicleProfile,
    pub prisoner: &'a dyn Fn(&Infantry) -> PrisonerProfile<'a>,
    pub display: &'a dyn Fn(&Structure) -> String,
    pub item_name: &'a dyn Fn(&str) -> String,
    pub commanders: &'a [(i8, u32)],
}
#[derive(Clone, Debug, PartialEq)]
pub enum Event {
    Support(support_calls::Event),
    Visibility(Vec<u32>),
    Logistics(rules_logistics::Event),
    Freed {
        id: u32,
        team: i8,
        name: String,
        position: Vector3,
    },
    Intelligence(Intelligence),
    Captor(u32),
    Winner(i8),
}
impl Rules {
    fn valid_clocks(&self) -> bool {
        [self.visibility_timer, self.second_timer]
            .into_iter()
            .all(|t| t.is_finite() && t.abs() <= 1e12)
            && self
                .reserve_at
                .into_iter()
                .all(|t| t.is_finite() && (0.0..=1e12).contains(&t))
            && self.income.iter().all(|side| {
                side.len() <= 100_000
                    && side.iter().all(|(t, n)| {
                        t.is_finite() && (0.0..=1e12).contains(t) && (0..=1_000_000).contains(n)
                    })
            })
    }
    pub fn income_per_minute(&mut self, team: i8, now: f64) -> Result<i64, &'static str> {
        if !(0..=1).contains(&team) || !now.is_finite() || !(0.0..=1e12).contains(&now) {
            return Err("invalid income report");
        }
        let rows = &mut self.income[team as usize];
        let expired = rows.iter().take_while(|(t, _)| now - *t > 120.).count();
        rows.drain(..expired);
        let amount: i64 = rows.iter().map(|(_, n)| i64::from(*n)).sum();
        Ok((amount as f64 * 60. / now.clamp(30., 120.)) as i64)
    }
    pub fn checkpoint(&self) -> Result<Vec<u8>, &'static str> {
        if !self.valid_clocks() {
            return Err("invalid rules clocks");
        }
        let mut w = Writer::new(b"FLRU\x01\0\0\0");
        for bytes in [
            self.network.checkpoint()?,
            self.economy.checkpoint()?,
            self.fog.checkpoint()?,
            self.support.checkpoint()?,
            self.prisoners.checkpoint(),
        ] {
            w.bytes(&bytes);
        }
        w.f64(self.visibility_timer);
        w.f64(self.second_timer);
        for t in self.reserve_at {
            w.f64(t);
        }
        for n in self.fob_names_used {
            w.u64(n);
        }
        for side in &self.income {
            w.u32(side.len() as u32);
            for (t, n) in side {
                w.f64(*t);
                w.u32(*n as u32);
            }
        }
        Ok(w.0)
    }
    pub fn restore(bytes: &[u8]) -> Result<Self, &'static str> {
        let mut r = Reader::new(bytes, b"FLRU\x01\0\0\0")?;
        let mut out = Self {
            network: SupplyNetwork::restore(r.bytes(256_000_000)?)?,
            economy: Economy::restore(r.bytes(32_000_000)?)?,
            fog: Fog::restore(r.bytes(128_000_000)?)?,
            support: SupportCalls::restore(r.bytes(64_000_000)?)?,
            prisoners: PrisonerIntelligence::restore(r.bytes(272_000_000)?)?,
            visibility_timer: r.f64()?,
            second_timer: r.f64()?,
            reserve_at: [r.f64()?, r.f64()?],
            fob_names_used: [r.u64()?, r.u64()?],
            ..Default::default()
        };
        for side in &mut out.income {
            let n = r.u32()?;
            if n > 100_000 {
                return Err("income history limit exceeded");
            }
            for _ in 0..n {
                side.push((r.f64()?, r.u32()? as i32));
            }
        }
        r.finish()?;
        if !out.valid_clocks() {
            return Err("invalid rules state");
        }
        Ok(out)
    }
}
impl WorldContext<'_> {
    pub fn advance_rules(
        &mut self,
        dt: f64,
        rules: &mut Rules,
        owners: &Ownership,
        victory: &mut Victory,
        scenario: bool,
        p: Profiles<'_>,
    ) -> Result<Vec<Event>, &'static str> {
        if !crate::infantry_fight_world::valid_step(dt, self.now, None)
            || !rules.valid_clocks()
            || !owners.valid()
            || !(-1..=1).contains(&victory.winner)
        {
            return Err("invalid rules update");
        }
        let mut out = vec![];
        if !rules.support.queue.is_empty() {
            out.extend(
                rules
                    .support
                    .advance(self.actors, self.rng, self.now)?
                    .into_iter()
                    .map(Event::Support),
            );
        }
        rules.visibility_timer -= dt;
        if rules.visibility_timer <= 0. {
            rules.visibility_timer = 0.4;
            out.push(Event::Visibility(rules.fog.update(
                self.actors,
                &self.geometry.terrain,
                self.now,
                p.vehicle,
            )?));
        }
        rules.second_timer -= dt;
        if rules.second_timer <= 0. {
            rules.second_timer = 1.;
            out.extend(
                self.reinforce(
                    &mut rules.reserve_at,
                    &rules.network,
                    &rules.economy,
                    owners,
                    p.reserves,
                    scenario,
                    victory.mission,
                )?
                .into_iter()
                .map(Event::Logistics),
            );
            let prisoners: Vec<_> = self
                .actors
                .iter_kind(Kind::Soldier)
                .filter_map(|a| match a {
                    Actor::Soldier(s)
                        if s.identity.team >= 0
                            && matches!(
                                s.vitals.life,
                                Life::Surrender | Life::Captive | Life::Hidden
                            ) =>
                    {
                        Some(s.identity.id)
                    }
                    _ => None,
                })
                .collect();
            for id in prisoners {
                let profile = (p.prisoner)(self.actors.soldier(id).unwrap());
                match self.actors.advance_prisoner(
                    id,
                    self.now,
                    CustodyProfile {
                        mission: victory.mission,
                        depots: rules.network.depots,
                        restored_weapon: profile.weapon,
                        squad_name: profile.squad_name,
                    },
                    &owners.players,
                    self.squads,
                    self.next_squad,
                    self.battle,
                    self.units,
                    |s| (self.movement)(s).bearer,
                )? {
                    Custody::Freed(joined) => {
                        let s = self.actors.soldier(id).unwrap();
                        out.push(Event::Freed {
                            id,
                            team: s.identity.team,
                            name: s.identity.name.clone(),
                            position: s.motion.position,
                        });
                        if let Some(route) = joined.route {
                            self.geometry.navigation.submit_infantry(
                                self.actors.soldier_mut(id).unwrap(),
                                route,
                                self.now,
                                self.rng,
                                crate::traversal::Ground::new(
                                    &self.geometry.terrain,
                                    &self.geometry.deck,
                                ),
                            )?;
                        }
                    }
                    Custody::Assigned { captor, route } => {
                        out.push(Event::Captor(captor));
                        self.geometry.navigation.submit_infantry(
                            self.actors.soldier_mut(captor).unwrap(),
                            route,
                            self.now,
                            self.rng,
                            crate::traversal::Ground::new(
                                &self.geometry.terrain,
                                &self.geometry.deck,
                            ),
                        )?;
                    }
                    Custody::Intelligence(mode) => {
                        let intel = rules.prisoners.reveal(
                            id,
                            mode,
                            self.actors,
                            self.units,
                            &rules.network.towns,
                            p.commanders,
                            (self.geometry.terrain.half() * 2.) as u32,
                            |s| (self.movement)(s).bearer,
                            p.display,
                            p.item_name,
                            self.rng,
                        )?;
                        out.push(Event::Intelligence(intel));
                    }
                    _ => (),
                }
            }
            if let Some(winner) = self.check_victory(victory) {
                out.push(Event::Winner(winner));
            }
            crate::fog::update_danger(self.actors, &mut self.geometry.navigation, p.vehicle)?;
        }
        if !victory.mission {
            out.extend(
                self.dispatch_supply(dt, &rules.network, p.truck)?
                    .into_iter()
                    .map(Event::Logistics),
            );
        }
        Ok(out)
    }
}
