//! A wounded man can fire before crawling; both operations see the same world and RNG.
use crate::bullet::Weapon;
use crate::bullet_world::{Gunfire, Shot};
use crate::infantry::Goal;
use crate::infantry_aim::{Target, TargetKind};
use crate::infantry_controller::Task;
use crate::infantry_cover::{CoverIntent, CoverWorld};
use crate::infantry_fire::MountedGun;
use crate::infantry_travel_owned::Event as Movement;
use crate::infantry_vitals::Life;
use crate::squad::Report;
use crate::supply_network::SupplyNetwork;
use crate::vector::{normalized, Vector3};
use crate::vehicle::Vehicle;
use crate::vehicle_damage::Armor;
use crate::visibility::Sight;
use crate::world::WorldContext;
use crate::world_combat;

#[derive(Clone, Copy, Debug)]
pub struct Input {
    pub dt: f64,
    pub medicine: bool,
    pub optics: bool,
    pub gun: Option<MountedGun>,
}
#[derive(Clone, Debug, PartialEq)]
pub enum Event {
    World(world_combat::Event),
    Cry { id: u32, cue: u8 },
    Died(u32),
    Movement { id: u32, event: Movement },
}
fn flat(v: Vector3) -> Vector3 {
    Vector3::new(v.x, 0.0, v.z)
}

impl WorldContext<'_> {
    fn wounded_death(&mut self, id: u32) -> Result<Vec<Event>, &'static str> {
        let s = self.actors.soldier(id).unwrap();
        let profile = (self.man)(s, self.squads);
        let squad = s.identity.squad;
        let role = s
            .identity
            .hit_by
            .as_ref()
            .and_then(|by| self.actors.soldier(by.soldier))
            .map_or_else(String::new, self.role);
        self.battle.soldier_died(
            s,
            Life::Downed,
            profile.bearer,
            profile.value,
            self.actors,
            &role,
        )?;
        if let Some(released) = self
            .actors
            .soldier_mut(id)
            .unwrap()
            .die(self.now, profile.ammunition)?
        {
            self.actors.release_links(id, released);
            if let Some(q) = self
                .squads
                .iter_mut()
                .find(|q| q.id == released.squad && q.breach_by == id)
            {
                q.breach_by = 0;
            }
        }
        self.geometry.navigation.planner.cancel(u64::from(id));
        let mut events = vec![Event::World(world_combat::Event::Stat("killed"))];
        if let Some(q) = self.squads.iter_mut().find(|q| q.id == squad) {
            if let Some(speech) = q.casualty(id, self.now, self.actors, self.rng)? {
                events.push(Event::World(world_combat::Event::Speech(speech)));
            }
        }
        events.push(Event::Died(id));
        Ok(events)
    }
    fn wounded_pistol(
        &mut self,
        id: u32,
        optics: bool,
        gunfire: &mut Gunfire,
        network: &mut SupplyNetwork,
        impacts: &mut Vec<Report>,
        armor: &dyn Fn(&Vehicle) -> Armor,
        vehicle_hit: &dyn Fn(&Vehicle) -> f64,
    ) -> Result<Vec<Event>, &'static str> {
        let s = self.actors.soldier(id).unwrap();
        let position = s.motion.position;
        let eye = position + Vector3::Y * 0.45;
        let team = s.identity.team;
        let mut nearest = 22.0;
        let mut target = 0;
        for who in self.actors.units_near(self.units, position, 22.0, -1)? {
            let Some(other) = self.actors.soldier(who).filter(|s| {
                s.identity.team != team && s.identity.team >= 0 && s.vitals.life == Life::Alive
            }) else {
                continue;
            };
            let distance = f64::from(flat(other.motion.position - position).length());
            if distance >= nearest {
                continue;
            }
            let points = self.actors.infantry_pose(who).unwrap().exposed_points();
            if self.visibility.can_see(
                &mut crate::collision::RayScene {
                    boxes: &mut self.geometry.collision,
                    ground: crate::traversal::Ground::new(
                        &self.geometry.terrain,
                        &self.geometry.deck,
                    ),
                },
                eye,
                u64::from(who),
                points.as_slice(),
                &[],
                true,
            ) == Some(Sight::Visible)
            {
                nearest = distance;
                target = who;
            }
        }
        if target == 0 {
            return Ok(vec![]);
        }
        let pose = self.actors.infantry_pose(target).unwrap();
        let direction = flat(pose.position - position);
        let s = self.actors.soldier_mut(id).unwrap();
        if s.links.dragged_by == 0 && direction.length_squared() > 0.0001 {
            s.motion.yaw =
                f64::from(libm::atan2(-f64::from(direction.x), -f64::from(direction.z)) as f32);
        }
        s.weapon.last_shot = self.now;
        let points = pose.exposed_points();
        let aim = Target {
            id: u64::from(target),
            kind: TargetKind::Infantry {
                over_cover: pose.over_cover(),
                cover_height: pose.cover_height,
            },
            position: pose.position,
            center: pose.center(),
            points: points.as_slice(),
            excluded: &[],
        }
        .aim_point(self.rng)?;
        let shot = Shot {
            shooter: id,
            target,
            muzzle: eye + normalized(direction) * 0.4,
            aim,
            weapon: Weapon {
                accuracy: 0.35,
                range: 25.0,
                damage: 16.0,
                anti_air: false,
                penetration: 0,
                drone_accuracy: 0.03,
                explosive_radius: None,
                airburst: false,
            },
            accuracy: 0.75,
            optics,
            piercing: false,
            suppression: 4.0,
            sound: "pistol",
        };
        let mut out = vec![Event::World(world_combat::Event::Stat("pistol_while_down"))];
        out.extend(
            self.fire_bullet(shot, gunfire, network, impacts, armor, vehicle_hit)?
                .into_iter()
                .map(Event::World),
        );
        Ok(out)
    }

    pub fn advance_wounded(
        &mut self,
        id: u32,
        input: Input,
        gunfire: &mut Gunfire,
        network: &mut SupplyNetwork,
        impacts: &mut Vec<Report>,
        armor: &dyn Fn(&Vehicle) -> Armor,
        vehicle_hit: &dyn Fn(&Vehicle) -> f64,
    ) -> Result<Vec<Event>, &'static str> {
        if !input.dt.is_finite()
            || !(0.0..=10.0).contains(&input.dt)
            || !self.now.is_finite()
            || !(0.0..=1e12 - 100.0).contains(&self.now)
            || input.gun.is_some_and(|g| !g.valid())
        {
            return Err("invalid wounded infantry step");
        }
        let s = self.actors.soldier(id).ok_or("missing wounded infantry")?;
        if s.vitals.life != Life::Downed {
            return Err("infantry is not wounded");
        }
        let rescued = self.actors.soldier(s.links.dragged_by as u32).is_some()
            || !s.links.carried_by.is_empty();
        if self.actors.soldier_mut(id).unwrap().vitals.bleed_step(
            input.dt,
            rescued,
            input.medicine,
        )? {
            return self.wounded_death(id);
        }
        let s = self.actors.soldier(id).unwrap();
        let dragged = self
            .actors
            .soldier(s.links.dragged_by as u32)
            .is_some_and(|b| {
                !b.identity.gone && b.vitals.life == Life::Alive && b.duty.kind == Task::Rescue
            });
        let carried = s.links.carried_by.iter().any(|who| {
            self.actors
                .soldier(*who as u32)
                .is_some_and(|b| !b.identity.gone && b.vitals.life == Life::Alive)
        });
        let s = self.actors.soldier_mut(id).unwrap();
        if !dragged {
            s.links.dragged_by = 0;
        }
        if !carried {
            s.links.carried_by.clear();
        }
        let mut out = vec![];
        if s.vitals.scream_step(input.dt, self.rng)? {
            let cue = (self.rng.randi() % 6) as u8;
            s.vitals.speech_cooldown = 2.6;
            out.push(Event::Cry { id, cue });
        }
        if carried {
            s.activity = 13;
            return Ok(out);
        }
        if s.vitals.pistol_step(input.dt, self.rng)? {
            out.extend(self.wounded_pistol(
                id,
                input.optics,
                gunfire,
                network,
                impacts,
                armor,
                vehicle_hit,
            )?);
        }
        let s = self.actors.soldier_mut(id).unwrap();
        if s.links.dragged_by != 0 {
            s.activity = 12;
            return Ok(out);
        }
        let ground = s
            .motion
            .cached_ground(self.now, &self.geometry.terrain, &self.geometry.deck);
        let y = f64::from(s.motion.position.y);
        s.motion.position.y = (y + (ground - y) * (1.0 - libm::exp(-input.dt * 8.0))) as f32;
        if s.orders.purpose == Goal::Crawl && s.is_moving() {
            s.activity = 11;
            let (_, movement) = self.move_infantry_world(id, input.dt, 0.55, input.gun)?;
            for event in movement {
                out.push(Event::Movement { id, event });
            }
            return Ok(out);
        }
        s.activity = if self.now - s.weapon.last_shot < 0.6 {
            23
        } else {
            0
        };
        if s.vitals.crawl_step(input.dt)? {
            let s = self.actors.soldier(id).unwrap();
            let position = s.motion.position;
            let squad = self.squads.iter().find(|q| q.id == s.identity.squad);
            let threats = self.actors.infantry_threats(id, self.now, squad)?;
            let ground = self.geometry.terrain.ground_y(
                position,
                !self.geometry.deck.is_empty()
                    && self.geometry.deck[self.geometry.terrain.index(position)] == 1,
            );
            let eye = position + Vector3::Y * (ground + 0.3) as f32;
            let covered = threats
                .iter()
                .filter(|th| {
                    crate::collision::Raycast::ray(
                        &mut crate::collision::RayScene {
                            boxes: &mut self.geometry.collision,
                            ground: crate::traversal::Ground::new(
                                &self.geometry.terrain,
                                &self.geometry.deck,
                            ),
                        },
                        eye,
                        **th,
                        &[],
                    )
                    .is_some_and(|r| position.distance(r.position) < 3.5)
                })
                .count();
            if threats.is_empty() || covered as f64 / (threats.len() as f64) < 0.99 {
                let search = self.actors.find_infantry_cover(
                    s,
                    CoverIntent {
                        now: self.now,
                        anchor: position,
                        radius: 8.0,
                        weapon_range: (self.movement)(s).weapon_range.unwrap_or(0.0),
                        unarmed: s.identity.weapon.is_empty(),
                    },
                    true,
                    &threats,
                    squad,
                    &mut CoverWorld {
                        terrain: &self.geometry.terrain,
                        nav: &self.geometry.navigation.planner,
                        collision: &mut self.geometry.collision,
                        heat: self.fires.hot(),
                        deck: &self.geometry.deck,
                        units: self.units,
                        structures: &self.geometry.structures,
                    },
                )?;
                if let Some(choice) = search
                    .choice
                    .filter(|c| flat(c.position - position).length() > 0.8)
                {
                    let route = self.actors.soldier_mut(id).unwrap().go_to(
                        choice.position,
                        Goal::Crawl,
                        0,
                    )?;
                    self.geometry.navigation.submit_infantry(
                        self.actors.soldier_mut(id).unwrap(),
                        route,
                        self.now,
                        self.rng,
                        crate::traversal::Ground::new(&self.geometry.terrain, &self.geometry.deck),
                    )?;
                    out.push(Event::World(world_combat::Event::Stat("crawl_to_cover")));
                }
            }
        }
        Ok(out)
    }
}
