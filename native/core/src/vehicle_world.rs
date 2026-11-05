//! Ground vehicles finish movement, unloading and shared combat in one authoritative update.
use crate::attack_plan::{AttackPlan, Event as Attack};
use crate::bullet_world::Gunfire;
use crate::infantry::Infantry;
use crate::infantry_action_owned::Defense;
use crate::squad::Report;
use crate::squad_movement;
use crate::supply_network::SupplyNetwork;
use crate::vector::{wrap_yaw, Vector3};
use crate::vehicle::Vehicle;
use crate::vehicle_artillery::ArtilleryProfile;
use crate::vehicle_brain::CrewProfile;
use crate::vehicle_combat_world::{Event as Combat, Profile as Weapons};
use crate::vehicle_damage::Armor;
use crate::vehicle_flight::move_toward;
use crate::vehicle_loss_world::Event as Loss;
use crate::vehicle_motion::GroundProfile;
use crate::vehicle_movement_world::Event as Movement;
use crate::vehicle_scan::ScanProfile;
use crate::vehicle_service::{Service, SoldierSupply};
use crate::world::WorldContext;

#[derive(Clone, Copy, Debug)]
pub struct Ground<'a> {
    pub movement: GroundProfile,
    pub scan: ScanProfile,
    pub crew: CrewProfile<'a>,
    pub weapons: Weapons<'a>,
    pub traverse: [f64; 2],
    pub artillery: Option<(ArtilleryProfile, [f64; 2])>,
    pub service: Option<Service>,
    pub light: bool,
}
impl Ground<'_> {
    fn valid(self) -> bool {
        self.movement.valid()
            && self.scan.valid()
            && self.crew.valid()
            && !matches!(
                self.crew.base,
                "supply" | "lift_heli" | "attack_heli" | "uav" | "boat"
            )
            && self.weapons.valid()
            && self
                .traverse
                .into_iter()
                .all(|n| n.is_finite() && (0.0..=1000.0).contains(&n))
            && self.artillery.is_none_or(|(p, r)| {
                p.valid()
                    && r.into_iter()
                        .all(|n| n.is_finite() && (0.0..=1e6).contains(&n))
                    && r[0] <= r[1]
            })
    }
}
#[derive(Clone, Debug, PartialEq)]
pub enum Event {
    RoadBlocked {
        vehicle: u32,
        destination: u32,
        town: bool,
        team: i8,
        position: Vector3,
        name: String,
    },
    Movement(Movement),
    Combat(Combat),
    Attack(Attack),
    Loss(Loss),
    Sling {
        helicopter: u32,
        cargo: u32,
        released: bool,
    },
    Delivered {
        team: i8,
        position: Vector3,
        amount: i32,
    },
}
impl WorldContext<'_> {
    pub(crate) fn begin_vehicle(
        &mut self,
        id: u32,
        dt: f64,
    ) -> Result<Option<Vec<Event>>, &'static str> {
        if !crate::infantry_fight_world::valid_step(dt, self.now, None) || dt > 10.0 {
            return Err("invalid vehicle step");
        }
        let v = self.actors.vehicle(id).ok_or("missing vehicle")?;
        let mut out = vec![];
        if v.slung_by != 0 {
            if self
                .actors
                .vehicle(v.slung_by)
                .is_none_or(|carrier| carrier.sling_cargo != id)
            {
                out.extend(self.drop_vehicle_sling(id)?.into_iter().map(Event::Loss));
            }
            return Ok(Some(out));
        }
        let v = self.actors.vehicle_mut(id).unwrap();
        v.cannon_timer -= dt;
        v.mg_timer -= dt;
        let knocked = f64::from(v.knock_velocity.length_squared()) > 0.0025;
        if knocked {
            let next = v.position + v.knock_velocity * dt as f32;
            let half = self.geometry.terrain.half() - 4.0;
            if self.geometry.navigation.planner.kind_at(next, false) != 3
                && f64::from(next.x.abs()) < half
                && f64::from(next.z.abs()) < half
            {
                v.position = next;
            } else {
                v.knock_velocity = Vector3::ZERO;
            }
            v.knock_velocity = move_toward(v.knock_velocity, Vector3::ZERO, 7.0 * dt);
        }
        v.stabilization_rate = 0.0;
        if knocked {
            self.geometry
                .refresh_vehicle_collision(v, (self.vehicle)(v).hull)?;
        }
        Ok(None)
    }
    pub(crate) fn aim_vehicle(
        &mut self,
        id: u32,
        dt: f64,
        gunship: bool,
        traverse: [f64; 2],
    ) -> Result<(), &'static str> {
        let v = self.actors.vehicle(id).ok_or("missing aiming vehicle")?;
        let target = self
            .actors
            .get(v.target)
            .filter(|a| self.actors.vehicle_target_valid(a.identity().id))
            .map(|a| (a.identity().id, a.position()));
        self.actors.vehicle_mut(id).unwrap().turret_tick(
            target,
            dt,
            gunship,
            traverse[0],
            traverse[1],
        )?;
        Ok(())
    }
    pub fn dismount_vehicle_world(
        &mut self,
        id: u32,
        boat: bool,
        plans: &mut Vec<AttackPlan>,
        next_plan: &mut u64,
    ) -> Result<Vec<Attack>, &'static str> {
        let plan_id = u32::try_from(*next_plan)
            .ok()
            .filter(|&n| n != 0)
            .ok_or("attack plan ids exhausted")?;
        if plans.len() >= 100_000 || plans.iter().any(|p| p.id == plan_id) {
            return Err("invalid attack plan registry");
        }
        let mut ctx = squad_movement::Context {
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
        };
        let (plan, out) = ctx.dismount_vehicle(id, boat, plan_id, self.visibility)?;
        if let Some(plan) = plan {
            plans.push(plan);
            *next_plan += 1;
        }
        Ok(out)
    }
    pub fn advance_ground_vehicle<'a>(
        &mut self,
        id: u32,
        dt: f64,
        profile: Ground<'_>,
        gunfire: &mut Gunfire,
        network: &mut SupplyNetwork,
        impacts: &mut Vec<Report>,
        plans: &mut Vec<AttackPlan>,
        next_plan: &mut u64,
        mission: bool,
        owned: &[u32],
        armor: &dyn Fn(&Vehicle) -> Armor,
        vehicle_hit: &dyn Fn(&Vehicle) -> f64,
        defense: &dyn Fn(&Vehicle) -> Defense<'a>,
        cannon: &dyn Fn(&Vehicle) -> bool,
        soldier_stock: &dyn Fn(&Infantry) -> Result<SoldierSupply<'a>, &'static str>,
        vehicle_stock: &dyn Fn(&Vehicle) -> Result<[i32; 2], &'static str>,
    ) -> Result<Vec<Event>, &'static str> {
        if !crate::infantry_fight_world::valid_step(dt, self.now, None)
            || !profile.valid()
            || dt > 10.0
        {
            return Err("invalid ground vehicle step");
        }
        if let Some(out) = self.begin_vehicle(id, dt)? {
            return Ok(out);
        }
        let mut out = vec![];
        let v = self.actors.vehicle_mut(id).unwrap();
        v.scan_timer -= dt;
        if v.scan_timer <= 0.0 {
            v.scan_timer = 0.5;
            self.scan_vehicle_world(id, profile.scan)?;
            out.extend(
                self.think_vehicle_world(id, profile.crew, mission, cannon)?
                    .into_iter()
                    .map(Event::Movement),
            );
        }
        let before = self.actors.vehicle(id).unwrap().yaw;
        out.extend(
            self.drive_vehicle_world(id, dt, profile.movement)?
                .into_iter()
                .map(Event::Movement),
        );
        let v = self.actors.vehicle(id).unwrap();
        if profile.crew.base == "tank" && self.actors.vehicle_target_valid(v.target) {
            let available = (profile.traverse[0] - v.traverse.abs()).max(0.0) * dt;
            let correction = wrap_yaw(v.yaw - before).clamp(-available, available);
            let v = self.actors.vehicle_mut(id).unwrap();
            v.turret_yaw = wrap_yaw(v.turret_yaw - correction);
            v.stabilization_rate = correction.abs() / dt.max(0.00001);
        }
        if self.actors.dismount_due(
            id,
            dt,
            false,
            false,
            &self.geometry.navigation.planner,
            self.units,
            crate::traversal::Ground::new(&self.geometry.terrain, &self.geometry.deck),
        )? {
            out.extend(
                self.dismount_vehicle_world(id, false, plans, next_plan)?
                    .into_iter()
                    .map(Event::Attack),
            );
        }
        if let Some((artillery, range)) = profile.artillery {
            out.extend(
                self.advance_vehicle_artillery(id, dt, artillery, range, owned)?
                    .into_iter()
                    .map(Event::Combat),
            );
        }
        let v = self.actors.vehicle(id).unwrap();
        if v.lay_yaw.is_none() || profile.artillery.is_none() {
            self.aim_vehicle(id, dt, false, profile.traverse)?;
        }
        out.extend(
            self.advance_vehicle_fire(
                id,
                profile.weapons,
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
        if self.actors.vehicle(id).is_none() {
            return Ok(out);
        }
        if let Some(service) = profile.service {
            out.extend(
                self.advance_vehicle_service(id, dt, service, soldier_stock, vehicle_stock)?
                    .into_iter()
                    .map(Event::Combat),
            );
        }
        let v = self.actors.vehicle_mut(id).unwrap();
        v.smash_timer -= dt;
        if v.smash_timer <= 0.0 {
            v.smash_timer = 0.15;
            out.extend(
                self.smash_vehicle_world(id, profile.light, profile.crew.armor)?
                    .into_iter()
                    .map(Event::Movement),
            );
        }
        if let Some(v) = self.actors.vehicle_mut(id) {
            v.update_flags(self.now, false, profile.artillery.is_some())?;
        }
        Ok(out)
    }
}
