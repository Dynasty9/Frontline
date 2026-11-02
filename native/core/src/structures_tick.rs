//! Buildings act in registration order, so earlier captures and births affect later decisions.
use crate::boat_navigation::BoatNavigation;
use crate::command_ownership::Ownership;
use crate::infantry::Infantry;
use crate::infantry_fire::MountedGun;
use crate::infantry_spawn::Loadout;
use crate::rules_world::Rules;
use crate::squad::Report;
use crate::structure::{Structure, TownEconomy};
use crate::structure_production::{self, Product};
use crate::structure_services::{self, Supply};
use crate::structure_world::{self, Victory};
use crate::vehicle::Vehicle;
use crate::vehicle_damage::Armor;
use crate::vehicle_loss_world::Context;

pub struct Profiles<'a> {
    pub product: &'a dyn Fn(&Structure) -> Option<Product<'a>>,
    pub base_cap: u32,
    pub cap_per_fob: u32,
    pub vehicle_cap: &'a dyn Fn(&Vehicle) -> u32,
    pub supply: &'a dyn Fn(&Infantry) -> Supply,
    pub bearers: [&'a Loadout; 2],
    pub gun: &'a dyn Fn(&Structure) -> Option<MountedGun>,
    pub armor: &'a dyn Fn(&Vehicle) -> Armor,
    pub fob_radius: f64,
    pub towns: [TownEconomy; 2],
}
#[derive(Clone, Debug, PartialEq)]
pub enum Event {
    Territory(structure_world::Event),
    Production(structure_production::Event),
    Service(structure_services::Event),
}
impl Context<'_> {
    pub fn advance_structures(
        &mut self,
        dt: f64,
        rules: &mut Rules,
        owners: &mut Ownership,
        boats: &mut BoatNavigation,
        victory: &mut Victory,
        impacts: &mut Vec<Report>,
        p: Profiles<'_>,
    ) -> Result<Vec<Event>, &'static str> {
        if !crate::infantry_fight_world::valid_step(dt, self.now, None) {
            return Err("invalid buildings update");
        }
        let ids = self.actors.simulated_structures().to_vec();
        let mut out = vec![];
        for id in ids {
            out.extend(self.advance_structure(id, dt, rules, owners, boats, victory, impacts, &p)?);
        }
        Ok(out)
    }
    pub fn advance_structure(
        &mut self,
        id: u32,
        dt: f64,
        rules: &mut Rules,
        owners: &mut Ownership,
        boats: &mut BoatNavigation,
        victory: &mut Victory,
        impacts: &mut Vec<Report>,
        p: &Profiles<'_>,
    ) -> Result<Vec<Event>, &'static str> {
        if !crate::infantry_fight_world::valid_step(dt, self.now, None) {
            return Err("invalid building update");
        }
        let mut out = vec![];
        let Some(st) = self
            .actors
            .structure(id)
            .filter(|s| !s.gone && s.built && (s.team >= 0 || s.kind == "town"))
        else {
            return Ok(vec![]);
        };
        match st.kind.as_str() {
            "fob" | "town" => out.extend(
                self.advance_territory(
                    id,
                    dt,
                    &structure_world::Profiles {
                        fob_radius: p.fob_radius,
                        town: p.towns,
                        supply: p.supply,
                    },
                    &mut rules.network,
                    victory,
                )?
                .into_iter()
                .map(Event::Territory),
            ),
            "barracks" | "factory" | "research" | "helipad" | "dock" => {
                let product = (p.product)(st);
                out.extend(
                    self.advance_production(
                        id,
                        dt,
                        structure_production::Profiles {
                            product,
                            base_cap: p.base_cap,
                            cap_per_fob: p.cap_per_fob,
                            vehicle_cap: p.vehicle_cap,
                        },
                        &mut rules.economy,
                        owners,
                        boats,
                    )?
                    .into_iter()
                    .map(Event::Production),
                );
            }
            "mines" => out.extend(
                self.advance_mine(id, dt, &mut rules.network, impacts, p.armor)?
                    .into_iter()
                    .map(Event::Territory),
            ),
            _ => {
                let team = st.team;
                let gun = (p.gun)(st);
                out.extend(
                    self.advance_structure_service(
                        id,
                        dt,
                        &structure_services::Profiles {
                            supply: p.supply,
                            bearer: p.bearers[team as usize],
                            armor_upgrade: rules.economy.has_upgrade(team, "armor"),
                            grenade_upgrade: rules.economy.has_upgrade(team, "grenades"),
                            gun,
                        },
                    )?
                    .into_iter()
                    .map(Event::Service),
                );
            }
        }
        Ok(out)
    }
}
