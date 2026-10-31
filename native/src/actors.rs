use frontline_core::actors::{Actor, Actors};
use frontline_core::drone::DroneFlight;
use frontline_core::drone_actor::Drone;
use frontline_core::entities::Kind;
use frontline_core::infantry_casualty::Released;
use frontline_core::projectile_actor::{Event, Explosion};
use frontline_core::vehicle_sling::SlingSpec;
use godot::prelude::*;
use std::collections::HashMap;

type ServiceStock = HashMap<
    u32,
    (
        Option<frontline_core::infantry_supply::Loadout>,
        String,
        i32,
    ),
>;
fn service_stock(rows: Array<Variant>) -> Option<ServiceStock> {
    use frontline_core::infantry_supply::Loadout;
    use frontline_core::infantry_weapon::Weapon;
    if rows.len() > 100_000 {
        return None;
    }
    let mut out = HashMap::new();
    for row in rows.iter_shared() {
        let row = row.try_to::<Array<Variant>>().ok()?;
        if row.len() != 5 {
            return None;
        }
        let id: u32 = row.get(0)?.try_to().ok()?;
        let stock = row.get(1)?.try_to::<PackedInt32Array>().ok()?;
        let reload_time: f64 = row.get(2)?.try_to().ok()?;
        let weapon = row.get(3)?.try_to::<GString>().ok()?.to_string();
        let magazine: i32 = row.get(4)?.try_to().ok()?;
        if id == 0
            || stock.len() != 8
            || weapon.len() > 128
            || weapon.contains('\0')
            || !(0..=1_000_000).contains(&magazine)
        {
            return None;
        }
        let loadout = if stock[0] == -1 {
            None
        } else {
            let p = Loadout {
                ammunition: stock[0],
                special: stock.as_slice()[1..6].try_into().ok()?,
                reload_weapon: Weapon {
                    ammunition: stock[6],
                    magazine: stock[7],
                    reload_time,
                },
            };
            if !p.valid() {
                return None;
            }
            Some(p)
        };
        if out.insert(id, (loadout, weapon, magazine)).is_some() {
            return None;
        }
    }
    Some(out)
}

#[derive(GodotClass)]
#[class(base=RefCounted, init)]
pub(crate) struct ActorStateCore {
    base: Base<RefCounted>,
    pub(crate) core: Actors,
}
fn released(r: Released) -> PackedInt64Array {
    [r.patient, r.stretcher, r.squad, r.drone]
        .map(i64::from)
        .as_slice()
        .into()
}
fn impact(r: Result<Option<Explosion>, &'static str>) -> Array<Variant> {
    match r {
        Ok(e) => varray![&crate::projectile_actor::events(
            e.into_iter().map(Event::Explosion).collect()
        )],
        Err(_) => Array::new(),
    }
}
fn vector(p: frontline_core::vector::Vector3) -> Vector3 {
    Vector3::new(p.x, p.y, p.z)
}
fn sling_spec(a: &PackedInt32Array) -> Result<SlingSpec, &'static str> {
    let a = a.as_slice();
    if a.len() != 6 || [0, 3, 4, 5].into_iter().any(|i| a[i] != 0 && a[i] != 1) {
        return Err("invalid sling profile");
    }
    Ok(SlingSpec {
        lift: a[0] != 0,
        capacity: a[1].try_into().map_err(|_| "invalid capacity")?,
        cargo_weight: a[2].try_into().map_err(|_| "invalid weight")?,
        cargo_helicopter: a[3] != 0,
        cargo_boat: a[4] != 0,
        cargo_automatic: a[5] != 0,
    })
}
fn artillery_profile(
    a: &Array<Variant>,
) -> Option<frontline_core::vehicle_artillery::ArtilleryProfile> {
    if a.len() != 3 {
        return None;
    }
    let kind = a.get(0)?.try_to::<GString>().ok()?;
    let n = a.get(1)?.try_to::<PackedFloat64Array>().ok()?;
    if n.len() != 8 {
        return None;
    }
    Some(frontline_core::vehicle_artillery::ArtilleryProfile {
        shell: frontline_core::projectile::Kind::parse(&kind.to_string())?,
        gun_height: n[0],
        muzzle: n[1],
        scatter: n[2],
        lay: n[3],
        gap: n[4],
        cooldown: n[5],
        traverse: n[6],
        traverse_accel: n[7],
        salvo: a.get(2)?.try_to().ok()?,
    })
}

#[godot_api]
impl ActorStateCore {
    #[func]
    fn fire_vehicle_cannon(
        &mut self,
        vehicle: u32,
        target: u32,
        now: f64,
        muzzle: Array<Variant>,
        gun: PackedFloat64Array,
        terrain: Gd<crate::terrain::TerrainCore>,
        mut collision: Gd<crate::collision_index::CollisionIndexCore>,
        mut rng: Gd<crate::simulation_random::SimulationRandomCore>,
    ) -> Array<Variant> {
        let Some(muzzle) = crate::vehicle::muzzle_profile(&muzzle) else {
            return Array::new();
        };
        if gun.len() != 4 {
            return Array::new();
        }
        let p = frontline_core::vehicle_cannon::CannonProfile {
            muzzle,
            damage: gun[0],
            radius: gun[1],
            anti_tank: gun[2],
            size: gun[3],
        };
        let terrain = terrain.bind();
        let Some(terrain) = terrain.core.as_ref() else {
            return Array::new();
        };
        match self.core.fire_vehicle_cannon(
            vehicle,
            target,
            now,
            p,
            terrain,
            &mut collision.bind_mut().core,
            &mut rng.bind_mut().core,
        ) {
            Ok(s) => varray![
                vector(s.from),
                &crate::projectile_actor::events(vec![Event::Explosion(s.blast)])
            ],
            Err(_) => Array::new(),
        }
    }
    #[func]
    fn artillery_needs_target(&self, vehicle: u32, now: f64) -> i32 {
        self.core
            .artillery_needs_target(vehicle, now)
            .map_or(-1, i32::from)
    }
    #[func]
    fn artillery_tick(
        &mut self,
        vehicle: u32,
        now: f64,
        dt: f64,
        profile: Array<Variant>,
        target: PackedVector3Array,
    ) -> i32 {
        let Some(p) = artillery_profile(&profile) else {
            return -1;
        };
        if target.len() > 1 {
            return -1;
        }
        match self.core.artillery_tick(
            vehicle,
            now,
            dt,
            p,
            target.as_slice().first().copied().map(crate::point),
        ) {
            Ok(frontline_core::vehicle_artillery::ArtilleryEvent::None) => 0,
            Ok(frontline_core::vehicle_artillery::ArtilleryEvent::Mission) => 1,
            Ok(frontline_core::vehicle_artillery::ArtilleryEvent::Fire) => 2,
            Err(_) => -1,
        }
    }
    #[func]
    fn finish_artillery_round(&mut self, vehicle: u32, profile: Array<Variant>) -> bool {
        artillery_profile(&profile)
            .is_some_and(|p| self.core.finish_artillery_round(vehicle, p).is_ok())
    }
    #[func]
    fn launch_vehicle_shell(
        &mut self,
        vehicle: u32,
        now: f64,
        profile: Array<Variant>,
        mut rng: Gd<crate::simulation_random::SimulationRandomCore>,
    ) -> Array<Variant> {
        let Some(p) = artillery_profile(&profile) else {
            return Array::new();
        };
        match self
            .core
            .launch_vehicle_shell(vehicle, now, p, &mut rng.bind_mut().core)
        {
            Ok(l) => varray![
                l.id,
                vector(l.flight.position),
                vector(l.flight.target),
                vector(l.forward),
                l.flight.shell_duration
            ],
            Err(_) => Array::new(),
        }
    }
    #[func]
    fn launch_vehicle_rocket(
        &mut self,
        vehicle: u32,
        target: u32,
        index: u32,
        mut rng: Gd<crate::simulation_random::SimulationRandomCore>,
    ) -> Array<Variant> {
        match self
            .core
            .launch_vehicle_rocket(vehicle, target, index, &mut rng.bind_mut().core)
        {
            Ok(l) => varray![l.id, vector(l.position), vector(l.velocity)],
            Err(_) => Array::new(),
        }
    }
    #[func]
    fn launch_vehicle_missile(
        &mut self,
        vehicle: u32,
        target: u32,
        anti_tank: bool,
        gunship: bool,
        gun_height: f64,
    ) -> Array<Variant> {
        let kind = if anti_tank {
            frontline_core::guided::Kind::AntiTank
        } else {
            frontline_core::guided::Kind::SurfaceToAir
        };
        match self
            .core
            .launch_vehicle_missile(vehicle, target, kind, gunship, gun_height)
        {
            Ok(l) => varray![l.id, vector(l.position), vector(l.velocity)],
            Err(_) => Array::new(),
        }
    }
    #[func]
    fn projectile_warning_target(&self, projectile: u32) -> i64 {
        self.core
            .projectile_warning_target(projectile)
            .map_or(-1, |id| i64::from(id.unwrap_or(0)))
    }
    #[func]
    fn launch_vehicle_smoke(
        &mut self,
        vehicle: u32,
        now: f64,
        from: Vector3,
        armor: u8,
        helicopter: bool,
        gun_height: f64,
        mut rng: Gd<crate::simulation_random::SimulationRandomCore>,
    ) -> Array<Variant> {
        let profile = frontline_core::vehicle_launch::SmokeProfile {
            armor,
            helicopter,
            gun_height,
        };
        match self.core.launch_vehicle_smoke(
            vehicle,
            now,
            crate::point(from),
            profile,
            &mut rng.bind_mut().core,
        ) {
            Ok(launches) => {
                let launches: Array<Variant> = launches
                    .into_iter()
                    .map(|l| varray![l.id, vector(l.position), vector(l.velocity)].to_variant())
                    .collect();
                varray![&launches]
            }
            Err(_) => Array::new(),
        }
    }
    #[func]
    fn dismount(
        &mut self,
        vehicle: u32,
        boat: bool,
        planner: Gd<crate::path_planner::PathPlannerCore>,
    ) -> Array<Variant> {
        let planner = planner.bind();
        let Some(nav) = planner.core.as_ref() else {
            return Array::new();
        };
        match self.core.dismount(vehicle, boat, nav) {
            Ok(None) => varray![false, 0, Vector3::ZERO, Vector3::ZERO, false],
            Ok(Some(d)) => varray![
                true,
                d.squad,
                vector(d.position),
                vector(d.forward),
                d.assault
            ],
            Err(_) => Array::new(),
        }
    }
    #[func]
    fn dismount_due(
        &mut self,
        vehicle: u32,
        dt: f64,
        lift: bool,
        boat: bool,
        planner: Gd<crate::path_planner::PathPlannerCore>,
        units: Gd<crate::spatial::SpatialIndexCore>,
    ) -> i32 {
        let planner = planner.bind();
        let units = units.bind();
        let (Some(nav), Some(units)) = (planner.core.as_ref(), units.core.as_ref()) else {
            return -1;
        };
        self.core
            .dismount_due(vehicle, dt, lift, boat, nav, units)
            .map_or(-1, i32::from)
    }
    #[func]
    fn can_sling(&self, helicopter: u32, cargo: u32, spec: PackedInt32Array) -> i32 {
        sling_spec(&spec)
            .and_then(|s| self.core.can_sling(helicopter, cargo, s))
            .map_or(-1, i32::from)
    }
    #[func]
    fn order_sling(&mut self, helicopter: u32, cargo: u32, spec: PackedInt32Array) -> i32 {
        sling_spec(&spec)
            .and_then(|s| self.core.order_sling(helicopter, cargo, s))
            .map_or(-1, i32::from)
    }
    #[func]
    fn hook_sling(&mut self, helicopter: u32, cargo: u32, spec: PackedInt32Array) -> i32 {
        sling_spec(&spec)
            .and_then(|s| self.core.hook_sling(helicopter, cargo, s))
            .map_or(-1, i32::from)
    }
    #[func]
    fn step_sling(&mut self, helicopter: u32, dt: f64, height: f64) -> i32 {
        self.core
            .step_sling(helicopter, dt, height)
            .map_or(-1, i32::from)
    }
    #[func]
    fn release_sling(
        &mut self,
        helicopter: u32,
        planner: Gd<crate::path_planner::PathPlannerCore>,
    ) -> i64 {
        let nav = planner.bind();
        let Some(nav) = nav.core.as_ref() else {
            return -1;
        };
        self.core
            .release_sling(helicopter, nav)
            .map_or(-1, |v| i64::from(v.unwrap_or(0)))
    }
    #[func]
    fn drop_sling(
        &mut self,
        cargo: u32,
        planner: Gd<crate::path_planner::PathPlannerCore>,
    ) -> Array<Variant> {
        let nav = planner.bind();
        let Some(nav) = nav.core.as_ref() else {
            return Array::new();
        };
        match self.core.drop_sling(cargo, nav) {
            Ok(drop) => varray![vector(drop.position), drop.damage, drop.impact],
            Err(_) => Array::new(),
        }
    }
    #[func]
    fn service_vehicle(
        &mut self,
        vehicle: u32,
        dt: f64,
        service: GString,
        units: Gd<crate::spatial::SpatialIndexCore>,
        mut random: Gd<crate::simulation_random::SimulationRandomCore>,
        soldiers: Array<Variant>,
        vehicles: Array<Variant>,
    ) -> Array<Variant> {
        use frontline_core::vehicle_service::{Service, ServiceEffect, SoldierSupply};
        let service = match service.to_string().as_str() {
            "repair" => Service::Repair,
            "ammo" => Service::Ammo,
            "medical" => Service::Medical,
            _ => return Array::new(),
        };
        let Some(stock) = service_stock(soldiers) else {
            return Array::new();
        };
        if vehicles.len() > 100_000 {
            return Array::new();
        }
        let mut missiles = HashMap::new();
        for row in vehicles.iter_shared() {
            let Ok(row) = row.try_to::<PackedInt64Array>() else {
                return Array::new();
            };
            if row.len() != 3 {
                return Array::new();
            }
            let (Ok(id), Ok(atgm), Ok(sam)) = (
                u32::try_from(row[0]),
                i32::try_from(row[1]),
                i32::try_from(row[2]),
            ) else {
                return Array::new();
            };
            if id == 0
                || !(0..=1_000_000).contains(&atgm)
                || !(0..=1_000_000).contains(&sam)
                || missiles.insert(id, [atgm, sam]).is_some()
            {
                return Array::new();
            }
        }
        let units = units.bind();
        let Some(units) = units.core.as_ref() else {
            return Array::new();
        };
        match self.core.service_vehicle(
            vehicle,
            dt,
            service,
            units,
            &mut random.bind_mut().core,
            |s| {
                stock
                    .get(&s.identity.id)
                    .map(|(loadout, key, magazine)| SoldierSupply {
                        loadout: *loadout,
                        restored_weapon: (!key.is_empty()).then_some((key.as_str(), *magazine)),
                    })
                    .ok_or("missing infantry stock")
            },
            |v| missiles.get(&v.id).copied().ok_or("missing vehicle stock"),
        ) {
            Ok(events) => {
                let out: Array<Variant> = events
                    .into_iter()
                    .map(|e| {
                        let row = match e {
                            ServiceEffect::Repaired { vehicle, track } => {
                                [0, i64::from(vehicle), i64::from(track)]
                            }
                            ServiceEffect::Reload { soldier, speech } => {
                                [1, i64::from(soldier), i64::from(speech)]
                            }
                            ServiceEffect::Revived { soldier, speech } => {
                                [2, i64::from(soldier), i64::from(speech)]
                            }
                        };
                        PackedInt64Array::from(row.as_slice()).to_variant()
                    })
                    .collect();
                varray![&out]
            }
            Err(_) => Array::new(),
        }
    }
    #[func]
    fn load_state(&mut self, next_id: i64, kinds: PackedByteArray, blocks: Array<Variant>) -> bool {
        if kinds.len() != blocks.len() || blocks.len() > frontline_core::entities::MAX_ENTITIES {
            return false;
        }
        let mut actors = Vec::with_capacity(blocks.len());
        let mut size = 0usize;
        for (index, kind) in kinds.as_slice().iter().enumerate() {
            let Ok(kind) = Kind::try_from(*kind) else {
                return false;
            };
            let Some(bytes) = blocks
                .get(index)
                .and_then(|v| v.try_to::<PackedByteArray>().ok())
            else {
                return false;
            };
            size += bytes.len();
            if bytes.len() > 16 * 1024 * 1024 || size > 256 * 1024 * 1024 {
                return false;
            }
            let Ok(actor) = Actor::restore(kind, bytes.as_slice()) else {
                return false;
            };
            actors.push(actor);
        }
        let Ok(next_id) = u64::try_from(next_id) else {
            return false;
        };
        let Ok(core) = Actors::from_entries(next_id, actors) else {
            return false;
        };
        self.core = core;
        true
    }
    #[func]
    fn actor_state(&self, id: u32) -> PackedByteArray {
        self.core
            .get(id)
            .and_then(|a| a.checkpoint().ok())
            .map_or_else(PackedByteArray::new, |b| b.as_slice().into())
    }
    #[func]
    fn identities(&self) -> PackedInt64Array {
        self.core
            .entities()
            .iter()
            .flat_map(|i| [i64::from(i.id), i.kind as i64])
            .collect()
    }
    #[func]
    fn next_id(&self) -> i64 {
        self.core.entities().next_id() as i64
    }
    #[func]
    fn spawn(&mut self, kind: u8, bytes: PackedByteArray) -> u32 {
        Kind::try_from(kind)
            .and_then(|k| Actor::restore(k, bytes.as_slice()))
            .and_then(|a| self.core.spawn(a))
            .unwrap_or(0)
    }
    #[func]
    fn remove(&mut self, id: u32) -> bool {
        self.core.remove(id).is_some()
    }
    #[func]
    fn board(&mut self, vehicle: u32, soldier: u32, seats: u32, helicopter: bool) -> i32 {
        self.core
            .board(vehicle, soldier, seats, helicopter)
            .map_or(-1, i32::from)
    }
    #[func]
    fn checkpoint(&self) -> PackedByteArray {
        self.core
            .checkpoint()
            .map_or_else(|_| PackedByteArray::new(), |b| b.as_slice().into())
    }
    #[func]
    fn restore(&mut self, bytes: PackedByteArray) -> bool {
        let Ok(core) = Actors::restore(bytes.as_slice()) else {
            return false;
        };
        self.core = core;
        true
    }
    #[func]
    fn release_all(&mut self, id: u32) -> PackedInt64Array {
        self.core
            .release_all(id)
            .map_or_else(|_| PackedInt64Array::new(), released)
    }
    #[func]
    fn go_down(&mut self, id: u32, now: f64) -> PackedInt64Array {
        self.core
            .go_down(id, now)
            .map_or_else(|_| PackedInt64Array::new(), released)
    }
    #[func]
    fn die(&mut self, id: u32, now: f64, ammunition: i32) -> Array<Variant> {
        match self
            .core
            .die(id, now, (ammunition >= 0).then_some(ammunition))
        {
            Ok(r) => varray![r.is_some(), &released(r.unwrap_or_default())],
            Err(_) => Array::new(),
        }
    }
    #[func]
    fn fling_from(
        &mut self,
        id: u32,
        center: Vector3,
        power: f64,
        mut rng: Gd<crate::simulation_random::SimulationRandomCore>,
    ) -> Array<Variant> {
        match self
            .core
            .fling_from(id, crate::point(center), power, &mut rng.bind_mut().core)
        {
            Ok(r) => varray![r.is_some(), &released(r.unwrap_or_default())],
            Err(_) => Array::new(),
        }
    }
    #[func]
    fn drone_checkpoint(
        meta: PackedInt64Array,
        warhead: f64,
        flight: PackedByteArray,
    ) -> PackedByteArray {
        if meta.len() != 6 {
            return PackedByteArray::new();
        }
        let result = (|| {
            let d = Drone {
                id: u32::try_from(meta[0]).ok()?,
                team: i8::try_from(meta[1]).ok()?,
                operator: u32::try_from(meta[2]).ok()?,
                target: u32::try_from(meta[3]).ok()?,
                operator_at_spawn: u32::try_from(meta[4]).ok()?,
                target_at_spawn: u32::try_from(meta[5]).ok()?,
                warhead,
                flight: DroneFlight::restore(flight.as_slice()).ok()?,
            };
            d.checkpoint().ok()
        })();
        result.map_or_else(PackedByteArray::new, |b| b.as_slice().into())
    }
    #[func]
    fn drone_state(&self, id: u32) -> Array<Variant> {
        let Some(Actor::Drone(d)) = self.core.get(id) else {
            return Array::new();
        };
        let f = d.flight;
        varray![
            vector(f.position),
            vector(f.velocity),
            vector(f.target),
            f.life,
            f.phase as i32,
            f.diving,
            f.dead,
            f64::from(f.yaw),
            i64::from(d.operator),
            i64::from(d.target),
            i64::from(d.operator_at_spawn),
            i64::from(d.target_at_spawn),
            d.warhead
        ]
    }
    #[func]
    fn step_drone(
        &mut self,
        id: u32,
        dt: f64,
        mut collision: Gd<crate::collision_index::CollisionIndexCore>,
        map_half: f64,
    ) -> Array<Variant> {
        impact(
            self.core
                .step_drone(id, dt, &mut collision.bind_mut().core, map_half as f32),
        )
    }
    #[func]
    fn detonate_drone(&mut self, id: u32) -> Array<Variant> {
        impact(self.core.detonate_drone(id))
    }
    #[func]
    fn shoot_drone(&mut self, id: u32) -> i32 {
        self.core.shoot_drone(id).map_or(-1, i32::from)
    }
}
