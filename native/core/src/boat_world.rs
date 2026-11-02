//! Boat crews steer, land troops and fight against the same retained battlefield.
use crate::actors::Actor;
use crate::attack_plan::AttackPlan;
use crate::boat_navigation::BoatNavigation;
use crate::bullet_world::Gunfire;
use crate::infantry_action_owned::Defense;
use crate::squad::Report;
use crate::supply_network::SupplyNetwork;
use crate::vehicle::Vehicle;
use crate::vehicle_boat::BoatProfile;
use crate::vehicle_combat_world::Profile as Weapons;
use crate::vehicle_damage::Armor;
use crate::vehicle_loss_world::Context;
use crate::vehicle_movement_world::Event as Movement;
use crate::vehicle_scan::ScanProfile;
use crate::vehicle_world::Event;
use crate::water::Water;

#[derive(Clone, Copy, Debug)]
pub struct Profile<'a> {
    pub movement: BoatProfile,
    pub scan: ScanProfile,
    pub weapons: Weapons<'a>,
    pub traverse: [f64; 2],
}
impl Context<'_> {
    pub fn advance_boat<'a>(
        &mut self,
        id: u32,
        dt: f64,
        p: Profile<'_>,
        navigation: &mut BoatNavigation,
        water: Option<&Water>,
        gunfire: &mut Gunfire,
        network: &mut SupplyNetwork,
        impacts: &mut Vec<Report>,
        plans: &mut Vec<AttackPlan>,
        next_plan: &mut u64,
        armor: &dyn Fn(&Vehicle) -> Armor,
        vehicle_hit: &dyn Fn(&Vehicle) -> f64,
        defense: &dyn Fn(&Vehicle) -> Defense<'a>,
    ) -> Result<Vec<Event>, &'static str> {
        if !crate::infantry_fight_world::valid_step(dt, self.now, None)
            || dt > 1.0
            || !p.movement.valid()
            || !p.scan.valid()
            || !p.weapons.valid()
            || p.traverse
                .into_iter()
                .any(|n| !n.is_finite() || !(0.0..=1000.0).contains(&n))
            || navigation.half() != self.geometry.terrain.half()
            || water.is_some_and(|w| !w.valid() || w.side as f64 * 0.5 != navigation.half())
        {
            return Err("invalid boat update");
        }
        let v = self.actors.vehicle(id).ok_or("missing boat")?;
        if v.tries >= 1_000_000 {
            return Err("boat recovery attempts exhausted");
        }
        if let Some(out) = self.begin_vehicle(id, dt)? {
            return Ok(out);
        }
        let v = self.actors.vehicle_mut(id).unwrap();
        v.scan_timer -= dt;
        if v.scan_timer <= 0.0 {
            v.scan_timer = 0.5;
            self.scan_vehicle_world(id, p.scan)?;
        }
        let v = self.actors.vehicle(id).unwrap();
        let target = self
            .actors
            .get(v.target)
            .filter(|_| self.actors.vehicle_target_valid(v.target))
            .map(Actor::position);
        let traffic = self.vehicle_traffic();
        let driven = self.actors.vehicle_mut(id).unwrap().boat_drive(
            dt, self.now, p.movement, target, navigation, water, &traffic,
        )?;
        let mut out = vec![];
        for (occurred, key) in [
            (driven.unstuck, "boat_unstick"),
            (driven.aground, "boat_aground"),
            (driven.rejoined, "boat_rejoin"),
            (driven.seaward, "boat_about_seaward"),
        ] {
            if occurred {
                out.push(Event::Movement(Movement::Stat(key)));
            }
        }
        self.geometry
            .refresh_vehicle_collision(self.actors.vehicle(id).unwrap(), p.movement.hull)?;
        if self.actors.dismount_due(
            id,
            dt,
            false,
            true,
            &self.geometry.navigation.planner,
            self.units,
            crate::traversal::Ground::new(&self.geometry.terrain, &self.geometry.deck),
        )? {
            out.extend(
                self.dismount_vehicle_world(id, true, plans, next_plan)?
                    .into_iter()
                    .map(Event::Attack),
            );
        }
        self.aim_vehicle(id, dt, false, p.traverse)?;
        out.extend(
            self.advance_vehicle_fire(
                id,
                p.weapons,
                gunfire,
                network,
                impacts,
                armor,
                vehicle_hit,
                defense,
            )?
            .into_iter()
            .map(Event::Combat),
        );
        if let Some(v) = self.actors.vehicle_mut(id) {
            v.update_flags(self.now, false, false)?;
        }
        Ok(out)
    }
}
