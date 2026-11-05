//! An individual order detaches one soldier while retaining the squad's shared claims.
use crate::actors::Actor;
use crate::cover::AnchorKind;
use crate::infantry::Goal;
use crate::infantry_action::Round;
use crate::infantry_commands::Command;
use crate::infantry_controller::Task;
use crate::infantry_fire::MountedGun;
use crate::squad_movement::{available, flat, point, Call, Context, Event};
use crate::terrain::{SOLID, TRENCH};
use crate::vector::{normalized, Vector3};

#[derive(Clone, Copy, Debug)]
pub enum Order {
    Move {
        position: Vector3,
        face: Vector3,
        mode: u8,
    },
    Attack(u32),
    Throw {
        position: Vector3,
        round: Round,
    },
    Stop,
    Retreat,
    Man {
        target: u32,
        gun: Option<MountedGun>,
    },
}
impl Context<'_> {
    fn individual_cover(&self, p: Vector3, threat: Vector3) -> Result<Vector3, &'static str> {
        let terrain = &self.geometry.terrain;
        let cell = terrain.index(p);
        let cx = (cell % terrain.n) as i32;
        let cz = (cell / terrain.n) as i32;
        let mut position = p;
        let mut score = -1e9;
        for z in (cz - 2).max(0)..(cz + 3).min(terrain.n as i32) {
            for x in (cx - 2).max(0)..(cx + 3).min(terrain.n as i32) {
                let i = z as usize * terrain.n + x as usize;
                if terrain.layers[SOLID][i] > 0 {
                    continue;
                }
                let at = terrain.center(i);
                let d = f64::from(flat(at - p).length());
                if d > 2. {
                    continue;
                }
                let s = f64::from(terrain.cover_vs(at, threat)) * 3. - d * 0.6
                    + if terrain.layers[TRENCH][i] > 0 {
                        2.5
                    } else {
                        0.
                    };
                if s > score {
                    score = s;
                    position = at;
                }
            }
        }
        let mut best = -1e9;
        let mut anchor = None;
        for id in self
            .actors
            .structures_near(&self.geometry.structures, p, 4.8, false)?
        {
            let st = self.actors.structure(id).unwrap();
            if !st.built || st.cover_points.is_empty() {
                continue;
            }
            for a in &st.anchors {
                let d = f64::from(flat(a.position - p).length());
                if d > 2.8 {
                    continue;
                }
                let toward = flat(threat - a.position);
                if toward.length() < 0.5 || a.normal.dot(normalized(toward)) < 0.3 {
                    continue;
                }
                let material = if a.kind == AnchorKind::Stack {
                    st.cover_material().saturating_sub(1)
                } else {
                    st.cover_material()
                };
                let mut s = [3.5, 5., 6.5, 7.][material as usize] - d * 0.6
                    + if st.kind == "trench" { 2.5 } else { 0. };
                match a.kind {
                    AnchorKind::Shelter => s -= 1.5,
                    AnchorKind::Stack => s -= 2.5,
                    AnchorKind::Over if a.height < 0.62 => s -= 0.5,
                    _ => (),
                }
                if s > best {
                    best = s;
                    anchor = Some(a.position);
                }
            }
        }
        Ok(if best + 0.5 >= score {
            anchor.unwrap_or(position)
        } else {
            position
        })
    }
    pub(crate) fn assign_mount(
        &mut self,
        id: u32,
        target: u32,
        gun: Option<MountedGun>,
    ) -> Result<(), &'static str> {
        let st = self
            .actors
            .structure(target)
            .ok_or("missing commanded gun")?;
        let at = st.position;
        let mount = flat(st.mount_position(gun)?);
        let tower = st.kind == "watchtower";
        self.clear_squad_duty(id);
        let s = self
            .actors
            .soldier_mut(id)
            .ok_or("missing commanded gunner")?;
        s.duty.kind = Task::Man;
        s.duty.entity = target.into();
        s.emplacement.structure = target.into();
        s.duty.phase = 0;
        let dest = mount
            + if tower {
                normalized(flat(s.motion.position - at)) * 1.8
            } else {
                Vector3::ZERO
            };
        self.duty_route(id, dest, Goal::Task, 1)?;
        let Some(Actor::Structure(st)) = self.actors.get_mut(target) else {
            unreachable!()
        };
        st.gunner = id;
        Ok(())
    }
    pub fn unit_order(
        &mut self,
        id: u32,
        order: Order,
        weapon_range: Option<f64>,
    ) -> Result<Vec<Event>, &'static str> {
        if !self.now.is_finite()
            || self.now.abs() > 1e12 - 100.
            || weapon_range.is_some_and(|r| !r.is_finite() || !(0.0..=1_000_000.).contains(&r))
        {
            return Err("invalid individual order context");
        }
        match order {
            Order::Move {
                position,
                face,
                mode,
            } if !point(position) || !point(face) || mode > 2 => {
                return Err("invalid individual move")
            }
            Order::Throw { position, round }
                if !point(position) || round == Round::HighExplosive =>
            {
                return Err("invalid individual grenade")
            }
            _ => (),
        }
        let Some(s) = self.actors.soldier(id).filter(|s| available(s)) else {
            return Ok(vec![]);
        };
        let position = s.motion.position;
        let team = s.identity.team;
        let mut out = vec![];
        match order {
            Order::Move {
                position: p,
                mut face,
                mode,
            } => {
                if face.length() < 0.1 {
                    face = normalized(flat(p - position));
                }
                let cover = self.individual_cover(p, p + face * 40.)?;
                let slot = self
                    .geometry
                    .navigation
                    .planner
                    .nearest_walkable(
                        cover,
                        crate::traversal::Ground::new(&self.geometry.terrain, &self.geometry.deck),
                    )
                    .unwrap();
                self.command(id, Command::Move { slot, mode, face })?;
                self.actors.soldier_mut(id).unwrap().orders.leash = 5.;
            }
            Order::Attack(target) => {
                let Some(t) = self.actors.get(target).filter(|t| {
                    let other = match t {
                        Actor::Soldier(s) => s.identity.team,
                        Actor::Vehicle(v) => v.team,
                        Actor::Structure(s) => s.team,
                        Actor::Projectile(p) => p.team,
                        Actor::Drone(d) => d.team,
                    };
                    other >= 0 && team >= 0 && other != team
                }) else {
                    return Ok(out);
                };
                let at = t.position();
                let range = weapon_range.map_or(25., |r| r * 0.8);
                let direction = flat(at - position);
                let slot = if f64::from(direction.length()) <= range {
                    position
                } else {
                    at - normalized(direction) * range as f32
                };
                let slot = self
                    .geometry
                    .navigation
                    .planner
                    .nearest_walkable(
                        slot,
                        crate::traversal::Ground::new(&self.geometry.terrain, &self.geometry.deck),
                    )
                    .unwrap();
                self.command(
                    id,
                    Command::Attack {
                        target,
                        position: at,
                        slot,
                    },
                )?;
            }
            Order::Throw { position, round } => {
                let s = self.actors.soldier(id).unwrap();
                if (round == Round::Smoke && s.fight.smokes <= 0)
                    || (round == Round::Frag && s.grenades.frags <= 0)
                {
                    self.actors.soldier_mut(id).unwrap().vitals.speech_cooldown = 2.6;
                    return Ok(vec![Event::Speech {
                        soldier: id,
                        call: Call::OutOfAmmo,
                        variant: 0,
                    }]);
                }
                self.command(id, Command::Throw { position, round })?;
            }
            Order::Stop => self.command(id, Command::Stop)?,
            Order::Retreat => {
                if let Some(fob) = self.actors.nearest_fob(team, position) {
                    let dest = fob.position
                        + Vector3::new(
                            self.rng.randf_range(-4., 4.),
                            0.,
                            self.rng.randf_range(-4., 4.),
                        );
                    let position = self
                        .geometry
                        .navigation
                        .planner
                        .nearest_walkable(
                            dest,
                            crate::traversal::Ground::new(
                                &self.geometry.terrain,
                                &self.geometry.deck,
                            ),
                        )
                        .unwrap();
                    self.command(id, Command::Retreat { position })?;
                }
            }
            Order::Man { target, gun } => {
                if self.actors.structure(target).is_some_and(|st| {
                    st.team == team
                        && st.built
                        && matches!(
                            st.kind.as_str(),
                            "mg_nest" | "hmg_nest" | "watchtower" | "mortar_pit" | "at_post"
                        )
                        && self.actors.soldier(st.gunner).is_none_or(|m| {
                            m.identity.gone || m.emplacement.structure != u64::from(target)
                        })
                }) {
                    self.assign_mount(id, target, gun)?;
                    out.push(Event::Stat("manned"));
                }
            }
        }
        self.actors.soldier_mut(id).unwrap().orders.detached = true;
        self.say(id, Call::Individual, 6, true, &mut out);
        Ok(out)
    }
}
