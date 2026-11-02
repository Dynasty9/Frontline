//! Recruitment uses the same identities, random stream and orders as units already in battle.
use crate::actors::Actor;
use crate::battle_stats::Unit;
use crate::infantry::Infantry;
use crate::infantry_control::HiddenReason;
use crate::infantry_pose::Posture;
use crate::infantry_spawn::{self, Loadout};
use crate::infantry_vitals::Life;
use crate::squad::Squad;
use crate::squad_movement::{self, flat, point};
use crate::vector::{normalized, Vector3};
use crate::vehicle_loss_world::Context;

#[derive(Clone, Copy)]
pub struct Definition<'a> {
    pub kind: &'a str,
    pub name: &'a str,
    pub members: &'a [Loadout],
    pub armor_upgrade: bool,
    pub grenade_upgrade: bool,
}
#[derive(Clone, Copy)]
pub struct Spawn {
    pub team: i8,
    pub owner: i32,
    pub position: Vector3,
    pub destination: Option<Vector3>,
}
impl Context<'_> {
    pub fn spawn_squad(
        &mut self,
        spawn: Spawn,
        profile: Definition<'_>,
    ) -> Result<(u32, Vec<squad_movement::Event>), &'static str> {
        let count = profile.members.len();
        let first = self.actors.entities().next_id();
        let id = u32::try_from(*self.next_squad).map_err(|_| "squad registry exhausted")?;
        if !(0..=1).contains(&spawn.team)
            || spawn.owner < -2
            || !point(spawn.position)
            || spawn.destination.is_some_and(|p| !point(p))
            || !self.now.is_finite()
            || self.now.abs() > 1e12 - 100.0
            || profile.kind.is_empty()
            || profile.kind.len() > 128
            || profile.kind.contains('\0')
            || profile.name.len() > 4096
            || profile.name.contains('\0')
            || !(1..=4096).contains(&count)
            || !profile.members.iter().all(Loadout::valid)
            || self.actors.entities().len() + count > crate::entities::MAX_ENTITIES
            || first + count as u64 > u64::from(u32::MAX) + 1
            || self.squads.len() >= 100_000
            || self.squads.iter().any(|q| q.id == id)
            || !infantry_spawn::valid_names(&self.names[spawn.team as usize])
        {
            return Err("invalid squad birth");
        }
        let mut q = Squad::new(id, spawn.team, spawn.owner, profile.kind.into())?;
        let mut face = if spawn.team == 0 {
            Vector3::NEG_Z
        } else {
            Vector3::Z
        };
        if let Some(dest) = spawn.destination {
            let direction = flat(dest - spawn.position);
            if direction.length() > 1.0 {
                face = normalized(direction);
            }
        }
        let yaw = libm::atan2(-f64::from(face.x), -f64::from(face.z));
        let mut rng = *self.rng;
        let mut recruits = Vec::with_capacity(count);
        for (i, loadout) in profile.members.iter().enumerate() {
            let off = Vector3::new(
                ((i % 3) as f64 - 1.0) as f32 * 1.4,
                0.0,
                ((i / 3) as f64 * 1.4) as f32,
            );
            let position = self
                .geometry
                .navigation
                .planner
                .nearest_walkable(
                    spawn.position + off,
                    crate::traversal::Ground::new(&self.geometry.terrain, &self.geometry.deck),
                )
                .ok_or("invalid squad birth position")?;
            let soldier = Infantry::from_spawn(
                (first + i as u64) as u32,
                infantry_spawn::Spawn {
                    team: spawn.team,
                    owner: spawn.owner,
                    position,
                    yaw,
                    name: infantry_spawn::random_name(&self.names[spawn.team as usize], &mut rng)?,
                    squad: id,
                    life: Life::Alive,
                    posture: Posture::Stand,
                    armor_upgrade: profile.armor_upgrade,
                    grenade_upgrade: profile.grenade_upgrade,
                },
                loadout,
                &mut rng,
            )?;
            q.members.push(soldier.identity.id);
            recruits.push(soldier);
        }
        q.order_position = spawn.position;
        q.facing = face;
        // Reject a malformed definition before committing identities or consuming match randomness.
        self.battle.register_unit(Unit {
            key: format!("s{id}"),
            name: q.callsign(),
            kind: profile.name.into(),
            team: q.team,
            owner: q.owner,
            started: self.now,
            ended: -1.0,
            men: count as u32,
            ..Default::default()
        })?;
        for s in recruits {
            self.actors.spawn(Actor::Soldier(Box::new(s)))?;
        }
        self.squads.push(q);
        *self.next_squad += 1;
        *self.rng = rng;
        let events = if let Some(destination) = spawn.destination {
            squad_movement::Context {
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
            .order_move(id, destination, face, 0, true)?
        } else {
            vec![]
        };
        Ok((id, events))
    }

    pub fn embark_new_squad(
        &mut self,
        vehicle: u32,
        profile: Definition<'_>,
    ) -> Result<u32, &'static str> {
        let v = self
            .actors
            .vehicle(vehicle)
            .filter(|v| !v.gone)
            .ok_or("missing squad transport")?;
        if v.passengers.len() + profile.members.len() > 4096 {
            return Err("transport passenger limit exceeded");
        }
        let spawn = Spawn {
            team: v.team,
            owner: v.owner,
            position: v.position,
            destination: None,
        };
        let (id, _) = self.spawn_squad(spawn, profile)?;
        let q = self.squads.last().unwrap();
        for &member in &q.members {
            let s = self.actors.soldier_mut(member).unwrap();
            s.links.vehicle = u64::from(vehicle);
            s.hide_in(HiddenReason::Vehicle, 9999.0, None)?;
            self.actors
                .vehicle_mut(vehicle)
                .unwrap()
                .passengers
                .push(member);
        }
        Ok(id)
    }
}
