//! Authenticated player intent is applied to the same retained world used by the match tick.
use crate::actors::Actor;
use crate::ambush_plan::AmbushPlan;
use crate::attack_plan::{self, AttackPlan};
use crate::boat_navigation::BoatNavigation;
use crate::building_placement::{self, Distances};
use crate::command_handoff::Changed;
use crate::command_ownership::Ownership;
use crate::economy;
use crate::infantry::Infantry;
use crate::infantry_action::Round;
use crate::infantry_control::HiddenReason;
use crate::infantry_controller::Task;
use crate::infantry_fire::MountedGun;
use crate::placement_world::{self, Request};
use crate::production_orders::{Item, Outcome, Research};
use crate::rules_world::Rules;
use crate::squad::Squad;
use crate::squad_brain;
use crate::squad_movement::{self, flat, point};
use crate::structure::Structure;
use crate::support_calls;
use crate::unit_orders;
use crate::vector::{normalized, Vector3};
use crate::vehicle::Vehicle;
use crate::vehicle_orders::Order as VehicleOrder;
use crate::vehicle_sling::SlingSpec;
use crate::water::Water;

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Placement {
    pub position: Vector3,
    pub yaw: f64,
    pub length: Option<f64>,
}
#[derive(Clone, Copy, Debug, PartialEq)]
pub enum UnitOrder {
    Move {
        position: Vector3,
        face: Vector3,
        mode: u8,
    },
    Attack(u32),
    Throw {
        position: Vector3,
        smoke: bool,
    },
    Stop,
    Retreat,
    Man(u32),
}
#[derive(Clone, Debug, PartialEq)]
pub enum Action {
    Move {
        position: Vector3,
        face: Vector3,
        mode: u8,
    },
    Assault {
        position: Vector3,
        face: Vector3,
    },
    Defend {
        position: Vector3,
        face: Vector3,
    },
    Dismount,
    Unit {
        soldier: u32,
        order: UnitOrder,
    },
    Attack(u32),
    Stop,
    Retreat,
    Build {
        kind: String,
        position: Vector3,
        yaw: f64,
    },
    BuildMany {
        kind: String,
        items: Vec<Placement>,
    },
    FireMission {
        building: u32,
        position: Vector3,
        smoke: bool,
    },
    Work(u32),
    Enter(u32),
    Sling(u32),
    Board(u32),
    Throw {
        position: Vector3,
        smoke: bool,
    },
    Support {
        kind: String,
        position: Vector3,
        direction: Vector3,
    },
    DemoSupport {
        kind: String,
        position: Vector3,
        direction: Vector3,
    },
    Produce {
        building: u32,
        item: String,
        research: bool,
    },
    Cancel(u32),
    Rally {
        building: u32,
        position: Vector3,
    },
    TunnelExit {
        building: u32,
        exit: u32,
    },
    Chat {
        text: String,
        team_only: bool,
    },
}
#[derive(Clone, Debug, PartialEq)]
pub struct Command {
    pub squads: Vec<u32>,
    pub vehicles: Vec<u32>,
    pub action: Action,
}
fn key(s: &str) -> bool {
    !s.is_empty() && s.len() <= 128 && !s.contains('\0')
}
fn placement(p: &Placement) -> bool {
    point(p.position)
        && p.yaw.is_finite()
        && p.yaw.abs() <= 1e12
        && p.length
            .is_none_or(|v| v.is_finite() && v.abs() <= 1_000_000.)
}
impl Command {
    pub fn valid(&self) -> bool {
        if self.squads.len() > 100_000 || self.vehicles.len() > 100_000 {
            return false;
        }
        match &self.action {
            Action::Move {
                position,
                face,
                mode,
            }
            | Action::Unit {
                order:
                    UnitOrder::Move {
                        position,
                        face,
                        mode,
                    },
                ..
            } => point(*position) && point(*face) && *mode <= 2,
            Action::Assault { position, face } | Action::Defend { position, face } => {
                point(*position) && point(*face)
            }
            Action::Build {
                kind,
                position,
                yaw,
            } => {
                key(kind)
                    && placement(&Placement {
                        position: *position,
                        yaw: *yaw,
                        length: None,
                    })
            }
            Action::BuildMany { kind, items } => {
                key(kind) && items.len() <= 4096 && items.iter().all(placement)
            }
            Action::FireMission { position, .. }
            | Action::Throw { position, .. }
            | Action::Rally { position, .. }
            | Action::Unit {
                order: UnitOrder::Throw { position, .. },
                ..
            } => point(*position),
            Action::Support {
                kind,
                position,
                direction,
            }
            | Action::DemoSupport {
                kind,
                position,
                direction,
            } => key(kind) && point(*position) && point(*direction),
            Action::Produce { item, .. } => key(item),
            Action::Chat { text, .. } => text.len() <= 8192 && !text.contains('\0'),
            _ => true,
        }
    }
}

#[derive(Clone, Copy, Debug, Default)]
pub struct VehicleOptions {
    pub seats: i32,
    pub artillery: Option<(f64, f64)>,
    pub sling_capacity: Option<i8>,
}
/// All definitions come from the server's immutable content, never from a command packet.
pub struct Profiles<'a> {
    pub building: &'a dyn Fn(&str) -> Option<building_placement::Definition<'a>>,
    pub support: &'a dyn Fn(&str) -> Option<support_calls::Definition<'a>>,
    pub item: &'a dyn Fn(&str, bool) -> Option<&'a Item>,
    pub produces: &'a dyn Fn(&str) -> &'a [String],
    pub research: &'a [Research],
    pub vehicle: &'a dyn Fn(&Vehicle) -> VehicleOptions,
    pub mount: &'a dyn Fn(&Structure) -> Option<MountedGun>,
    pub engineer: &'a dyn Fn(&Infantry) -> bool,
    pub mortar: &'a dyn Fn(&Infantry) -> bool,
    pub structure_name: &'a dyn Fn(&Structure) -> String,
    pub squad_name: &'a dyn Fn(&Squad) -> String,
    pub distances: &'a Distances,
    pub fob_names: &'a [Vec<String>; 2],
}
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Audience {
    Peer(i32),
    Team(i8),
    Everyone,
}
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum MessageKind {
    Alert,
    Warning,
    Info,
    Chat,
    Radio,
    Intel,
}
#[derive(Clone, Debug, PartialEq)]
pub enum Event {
    Ownership(Changed),
    Squad(squad_movement::Event),
    Brain(squad_brain::Event),
    Attack(attack_plan::Event),
    Placement(placement_world::Event),
    Support(support_calls::Event),
    Message {
        audience: Audience,
        kind: MessageKind,
        text: String,
        position: Option<Vector3>,
    },
    Speech {
        soldier: u32,
        text: String,
    },
    Deed {
        peer: i32,
        text: String,
        position: Vector3,
        major: bool,
    },
}
pub struct Dispatcher<'a, 'w, 'p> {
    pub world: &'a mut crate::world::WorldContext<'w>,
    pub rules: &'a mut Rules,
    pub owners: &'a Ownership,
    pub boats: &'a mut BoatNavigation,
    pub water: &'a Water,
    pub plans: &'a mut Vec<AttackPlan>,
    pub ambushes: &'a mut [AmbushPlan],
    pub next_plan: &'a mut u64,
    pub profiles: &'a Profiles<'p>,
    pub winner: i8,
    pub host_peer: i32,
}
fn team(a: &Actor) -> i8 {
    match a {
        Actor::Soldier(s) => s.identity.team,
        Actor::Vehicle(v) => v.team,
        Actor::Structure(s) => s.team,
        Actor::Projectile(p) => p.team,
        Actor::Drone(d) => d.team,
    }
}
fn movement<'a>(w: &'a mut crate::world::WorldContext<'_>) -> squad_movement::Context<'a> {
    squad_movement::Context {
        actors: w.actors,
        geometry: w.geometry,
        units: w.units,
        squads: w.squads,
        rng: w.rng,
        now: w.now,
        town: w.town,
        man: w.movement,
        automatic: w.automatic,
        player_building: w.player_building,
    }
}
fn message(
    out: &mut Vec<Event>,
    audience: Audience,
    kind: MessageKind,
    text: String,
    position: Option<Vector3>,
) {
    out.push(Event::Message {
        audience,
        kind,
        text,
        position,
    });
}
fn warn(out: &mut Vec<Event>, peer: i32, text: &str) {
    if peer > 0 {
        message(
            out,
            Audience::Peer(peer),
            MessageKind::Warning,
            text.into(),
            None,
        );
    }
}
impl Dispatcher<'_, '_, '_> {
    fn take(
        &mut self,
        peer: i32,
        squads: &[u32],
        vehicles: &[u32],
        out: &mut Vec<Event>,
    ) -> Result<(), &'static str> {
        let changed = self.owners.take_command(
            peer,
            squads,
            vehicles,
            self.world.squads,
            self.world.actors,
        )?;
        if changed != Changed::default() {
            out.push(Event::Ownership(changed));
        }
        Ok(())
    }
    fn plan_id(&self) -> Result<u32, &'static str> {
        let id = u32::try_from(*self.next_plan)
            .ok()
            .filter(|&id| id != 0)
            .ok_or("attack plan ids exhausted")?;
        if self.plans.len() >= 100_000 || self.plans.iter().any(|p| p.id == id) {
            return Err("invalid attack plan registry");
        }
        Ok(id)
    }
    fn face(
        &mut self,
        squads: &[u32],
        vehicles: &[u32],
        position: Vector3,
        face: Vector3,
    ) -> Vector3 {
        if f64::from(face.length()) >= 0.1 {
            return face;
        }
        let mut center = Vector3::ZERO;
        for &id in squads {
            let q = self.world.squads.iter_mut().find(|q| q.id == id).unwrap();
            center += q.centroid(self.world.now, self.world.actors);
        }
        for &id in vehicles {
            center += self.world.actors.vehicle(id).unwrap().position;
        }
        center /= (squads.len() + vehicles.len()).max(1) as f32;
        if center.distance(position) > 1. {
            normalized(flat(position - center))
        } else {
            Vector3::NEG_Z
        }
    }
    fn place(
        &mut self,
        peer: i32,
        side: i8,
        squads: &[u32],
        kind: &str,
        p: Placement,
        assign: bool,
        out: &mut Vec<Event>,
    ) -> Result<bool, &'static str> {
        let def = (self.profiles.building)(kind);
        let size = p
            .length
            .zip(def.as_ref())
            .map(|(len, d)| Vector3::new(len.clamp(1.5, 8.) as f32, 3., d.body.size[1]));
        let w = &mut self.world;
        let mut ctx = squad_movement::Context {
            actors: w.actors,
            geometry: w.geometry,
            units: w.units,
            squads: w.squads,
            rng: w.rng,
            now: w.now,
            town: w.town,
            man: w.movement,
            automatic: w.automatic,
            player_building: w.player_building,
        };
        let events = ctx.place_building(
            self.rules,
            self.owners,
            w.battle,
            self.water,
            Request {
                peer,
                team: side,
                position: p.position,
                yaw: p.yaw,
                size,
                squads,
                assign,
            },
            def.as_ref(),
            self.profiles.distances,
            self.profiles
                .fob_names
                .get(side as usize)
                .map_or(&[], Vec::as_slice),
            self.profiles.engineer,
            self.profiles.structure_name,
        )?;
        let placed = events
            .iter()
            .any(|e| matches!(e, placement_world::Event::Placed { .. }));
        out.extend(events.into_iter().map(Event::Placement));
        Ok(placed)
    }
    fn mortar(
        &mut self,
        id: u32,
        peer: i32,
        side: i8,
        at: Vector3,
        smoke: bool,
        out: &mut Vec<Event>,
    ) {
        let Some(st) = self
            .world
            .actors
            .structure(id)
            .filter(|s| s.team == side && s.kind == "mortar_pit" && s.built)
        else {
            return;
        };
        let gunner = st.gunner;
        if !self
            .world
            .actors
            .soldier(gunner)
            .is_some_and(|s| !s.identity.gone && s.duty.kind == Task::Man)
        {
            warn(
                out,
                peer,
                "Nobody is crewing that mortar pit. Move a squad next to it.",
            );
            return;
        }
        let distance = flat(at - st.position).length();
        if !(30. ..=160.).contains(&distance) {
            warn(out, peer, "Out of mortar range (30-160 m).");
            return;
        }
        let Some(Actor::Structure(st)) = self.world.actors.get_mut(id) else {
            unreachable!()
        };
        st.fire_queue = vec![(at, smoke); 6];
        self.world
            .actors
            .soldier_mut(gunner)
            .unwrap()
            .vitals
            .speech_cooldown = 2.6;
        out.push(Event::Speech {
            soldier: gunner,
            text: format!(
                "Fire mission, {}! Rounds out!",
                if smoke { "smoke" } else { "HE" }
            ),
        });
    }
    fn tunnel(
        &mut self,
        peer: i32,
        id: u32,
        exit: u32,
        out: &mut Vec<Event>,
    ) -> Result<(), &'static str> {
        let Some(st) = self.world.actors.structure(id) else {
            return Ok(());
        };
        let Some(ex) = self.world.actors.structure(exit) else {
            return Ok(());
        };
        if st.kind != "tunnel" || ex.kind != "tunnel" || !ex.built || ex.team != st.team {
            return Ok(());
        }
        let side = st.team;
        let position = ex.position;
        let travel = if id == exit {
            1.
        } else {
            3. + f64::from(flat(position - st.position).length())
                / if self.rules.economy.has_upgrade(side, "deep_tunnels") {
                    28.
                } else {
                    14.
                }
        };
        let inside = st.inside.clone();
        let mut moved = 0;
        for id in inside {
            let Some(s) = self.world.actors.soldier_mut(id).filter(|s| {
                !s.identity.gone
                    && self
                        .owners
                        .can_command(peer, s.identity.team, s.identity.owner)
            }) else {
                continue;
            };
            s.control.hidden = HiddenReason::TunnelTravel;
            s.control.hidden_timer = travel + f64::from(self.world.rng.randf()) * 1.5;
            s.duty.position = position
                + Vector3::new(
                    self.world.rng.randf_range(-3., 3.),
                    0.,
                    self.world.rng.randf_range(-3., 3.),
                );
            let squad = s.identity.squad;
            if self.world.squads.iter().any(|q| q.id == squad) {
                self.take(peer, &[squad], &[], out)?;
                self.world
                    .squads
                    .iter_mut()
                    .find(|q| q.id == squad)
                    .unwrap()
                    .order_position = position;
            }
            moved += 1;
        }
        if moved > 0 {
            message(
                out,
                Audience::Team(side),
                MessageKind::Info,
                format!(
                    "{moved} soldiers moving through the tunnels to {}.",
                    crate::prisoner_intelligence::grid_ref(
                        position,
                        self.world.geometry.terrain.n as u32
                    )
                ),
                None,
            );
        }
        Ok(())
    }
    /// `peer` and its display name are supplied by the authenticated session, outside the payload.
    pub fn execute(
        &mut self,
        peer: i32,
        name: &str,
        command: &Command,
    ) -> Result<Vec<Event>, &'static str> {
        if !command.valid()
            || name.len() > 4096
            || name.contains('\0')
            || !self.world.now.is_finite()
            || self.world.now.abs() > 1e12 - 100_000.
        {
            return Err("invalid match command");
        }
        let side = self.owners.team_of(peer);
        let mut out = vec![];
        if peer == 0 || peer < -2 || peer > 0 && !self.owners.players.iter().any(|p| p.0 == peer) {
            return Ok(out);
        }
        if let Action::DemoSupport {
            kind,
            position,
            direction,
        } = &command.action
        {
            if side < 0 && (peer == self.host_peer || self.owners.players.iter().all(|p| p.1 < 0)) {
                if let Some(def) = (self.profiles.support)(kind) {
                    out.extend(
                        self.rules
                            .support
                            .demo(
                                self.world.actors,
                                self.world.rng,
                                self.world.now,
                                *position,
                                *direction,
                                &def,
                                self.world.geometry.terrain.n as u32,
                            )?
                            .into_iter()
                            .map(Event::Support),
                    );
                }
            }
            return Ok(out);
        }
        if !(0..=1).contains(&side) || self.winner >= 0 {
            return Ok(out);
        }
        let mut squads = self
            .owners
            .select_squads(peer, &command.squads, self.world.squads)?;
        let vehicles = self.owners.select_vehicles(
            peer,
            &command.vehicles,
            self.world.actors,
            self.world.automatic,
        )?;
        if !matches!(command.action, Action::Retreat | Action::Unit { .. }) {
            squads.retain(|id| {
                let q = self.world.squads.iter().find(|q| q.id == *id).unwrap();
                if q.drill != "rout" {
                    return true;
                }
                if peer > 0 {
                    message(
                        &mut out,
                        Audience::Peer(peer),
                        MessageKind::Alert,
                        format!(
                            "{} is routing - it won't take orders until it rallies.",
                            (self.profiles.squad_name)(q)
                        ),
                        None,
                    );
                }
                false
            });
        }
        let count_orders = !matches!(command.action, Action::Unit { .. } | Action::Dismount);
        if count_orders
            && squads.iter().any(|id| {
                self.world
                    .squads
                    .iter()
                    .any(|q| q.id == *id && q.order_number >= i64::MAX as u64)
            })
        {
            return Err("squad order counter exhausted");
        }
        if matches!(command.action, Action::Assault { .. } | Action::Dismount) {
            self.plan_id()?;
        }
        if count_orders {
            for &id in &squads {
                self.world
                    .squads
                    .iter_mut()
                    .find(|q| q.id == id)
                    .unwrap()
                    .order_number += 1;
            }
        }
        match &command.action {
            Action::Move { position, face, .. }
            | Action::Assault { position, face }
            | Action::Defend { position, face } => {
                self.take(peer, &squads, &vehicles, &mut out)?;
                let face = self.face(&squads, &vehicles, *position, *face);
                let across = normalized(face.cross(Vector3::Y));
                for (i, &id) in squads.iter().enumerate() {
                    let p = *position
                        + across * (i as f64 - (squads.len() - 1) as f64 / 2.) as f32 * 13.;
                    match command.action {
                        Action::Move { mode, .. } => out.extend(
                            movement(self.world)
                                .order_move(id, p, face, mode, true)?
                                .into_iter()
                                .map(Event::Squad),
                        ),
                        Action::Defend { .. } => out.extend(
                            movement(self.world)
                                .order_defend(id, p, face, false)?
                                .into_iter()
                                .map(Event::Squad),
                        ),
                        _ if squads.len() == 1 => {
                            let plan_id = self.plan_id()?;
                            let w = &mut self.world;
                            let mut ctx = squad_movement::Context {
                                actors: w.actors,
                                geometry: w.geometry,
                                units: w.units,
                                squads: w.squads,
                                rng: w.rng,
                                now: w.now,
                                town: w.town,
                                man: w.movement,
                                automatic: w.automatic,
                                player_building: w.player_building,
                            };
                            let (plan, events) =
                                ctx.order_assault(id, p, face, plan_id, w.visibility)?;
                            if let Some(plan) = plan {
                                self.plans.push(plan);
                                *self.next_plan += 1;
                            }
                            out.extend(events.into_iter().map(Event::Attack));
                        }
                        _ => out.extend(
                            movement(self.world)
                                .order_assault_bounds(id, p, face)?
                                .into_iter()
                                .map(Event::Squad),
                        ),
                    }
                }
                if matches!(command.action, Action::Assault { .. }) && squads.len() >= 2 {
                    let plan_id = self.plan_id()?;
                    let w = &mut self.world;
                    let mut ctx = squad_movement::Context {
                        actors: w.actors,
                        geometry: w.geometry,
                        units: w.units,
                        squads: w.squads,
                        rng: w.rng,
                        now: w.now,
                        town: w.town,
                        man: w.movement,
                        automatic: w.automatic,
                        player_building: w.player_building,
                    };
                    let (plan, events) = AttackPlan::make(
                        &mut ctx,
                        plan_id,
                        &squads,
                        *position,
                        face,
                        w.visibility,
                    )?;
                    if let Some(plan) = plan {
                        self.plans.push(plan);
                        *self.next_plan += 1;
                    }
                    out.extend(events.into_iter().map(Event::Attack));
                }
                for (i, &id) in vehicles.iter().enumerate() {
                    let p = *position
                        + across * (i as f64 - (vehicles.len() - 1) as f64 / 2.) as f32 * 9.
                        - face * if squads.is_empty() { 0. } else { 6. };
                    self.world.order_vehicle(
                        id,
                        if matches!(command.action, Action::Assault { .. }) {
                            VehicleOrder::Assault(p)
                        } else {
                            VehicleOrder::Move(p)
                        },
                        self.boats,
                    )?;
                }
            }
            Action::Dismount => {
                self.take(peer, &[], &vehicles, &mut out)?;
                for id in vehicles {
                    let boat = (self.world.vehicle)(self.world.actors.vehicle(id).unwrap())
                        .crew
                        .base
                        == "boat";
                    out.extend(
                        self.world
                            .dismount_vehicle_world(id, boat, self.plans, self.next_plan)?
                            .into_iter()
                            .map(Event::Attack),
                    );
                }
            }
            Action::Unit { soldier, order } => {
                if let Some(s) = self.world.actors.soldier(*soldier).filter(|s| {
                    self.owners
                        .can_command(peer, s.identity.team, s.identity.owner)
                }) {
                    let squad = s.identity.squad;
                    let range = (self.world.movement)(s).weapon_range;
                    if self.world.squads.iter().any(|q| q.id == squad) {
                        self.take(peer, &[squad], &[], &mut out)?;
                    } else if peer > 0 && s.identity.owner < 0 {
                        self.world
                            .actors
                            .soldier_mut(*soldier)
                            .unwrap()
                            .identity
                            .owner = peer;
                        out.push(Event::Ownership(Changed {
                            soldiers: vec![*soldier],
                            ..Default::default()
                        }));
                    }
                    let order = match *order {
                        UnitOrder::Move {
                            position,
                            face,
                            mode,
                        } => unit_orders::Order::Move {
                            position,
                            face,
                            mode,
                        },
                        UnitOrder::Attack(id) => unit_orders::Order::Attack(id),
                        UnitOrder::Throw { position, smoke } => unit_orders::Order::Throw {
                            position,
                            round: if smoke { Round::Smoke } else { Round::Frag },
                        },
                        UnitOrder::Stop => unit_orders::Order::Stop,
                        UnitOrder::Retreat => unit_orders::Order::Retreat,
                        UnitOrder::Man(target) => unit_orders::Order::Man {
                            target,
                            gun: self
                                .world
                                .actors
                                .structure(target)
                                .and_then(self.profiles.mount),
                        },
                    };
                    out.extend(
                        movement(self.world)
                            .unit_order(*soldier, order, range)?
                            .into_iter()
                            .map(Event::Squad),
                    );
                }
            }
            Action::Attack(target) => {
                if self
                    .world
                    .actors
                    .get(*target)
                    .is_some_and(|a| team(a) >= 0 && team(a) != side)
                {
                    self.take(peer, &squads, &vehicles, &mut out)?;
                    for id in squads {
                        out.extend(
                            movement(self.world)
                                .order_attack(id, *target)?
                                .into_iter()
                                .map(Event::Squad),
                        );
                    }
                    for id in vehicles {
                        self.world
                            .order_vehicle(id, VehicleOrder::Attack(*target), self.boats)?;
                    }
                }
            }
            Action::Stop | Action::Retreat => {
                self.take(peer, &squads, &vehicles, &mut out)?;
                let retreat = matches!(command.action, Action::Retreat);
                for id in squads {
                    if retreat {
                        out.extend(
                            movement(self.world)
                                .squad_retreat(id)?
                                .into_iter()
                                .map(Event::Brain),
                        );
                    } else {
                        out.extend(
                            movement(self.world)
                                .order_stop(id)?
                                .into_iter()
                                .map(Event::Squad),
                        );
                    }
                }
                for id in vehicles {
                    if !retreat {
                        self.world
                            .order_vehicle(id, VehicleOrder::Stop, self.boats)?;
                    } else if let Some(fob) = economy::nearest_fob(
                        self.world.actors,
                        side,
                        self.world.actors.vehicle(id).unwrap().position,
                    ) {
                        let position = self.world.actors.structure(fob).unwrap().position
                            + Vector3::new(
                                self.world.rng.randf_range(-8., 8.),
                                0.,
                                self.world.rng.randf_range(-8., 8.),
                            );
                        self.world
                            .order_vehicle(id, VehicleOrder::Move(position), self.boats)?;
                    }
                }
            }
            Action::Build {
                kind,
                position,
                yaw,
            } => {
                if self.place(
                    peer,
                    side,
                    &squads,
                    kind,
                    Placement {
                        position: *position,
                        yaw: *yaw,
                        length: None,
                    },
                    true,
                    &mut out,
                )? {
                    out.push(Event::Deed {
                        peer,
                        text: format!("Placed {}", (self.profiles.building)(kind).unwrap().name),
                        position: *position,
                        major: false,
                    });
                }
            }
            Action::BuildMany { kind, items } => {
                let mut laid = 0;
                let mut at = Vector3::ZERO;
                for &p in items {
                    if self.place(peer, side, &squads, kind, p, laid == 0, &mut out)? {
                        laid += 1;
                        at = p.position;
                    }
                }
                if laid > 0 {
                    out.push(Event::Deed {
                        peer,
                        text: format!(
                            "Laid {laid} × {}",
                            (self.profiles.building)(kind).unwrap().name
                        ),
                        position: at,
                        major: false,
                    });
                }
            }
            Action::FireMission {
                building,
                position,
                smoke,
            } => {
                self.mortar(*building, peer, side, *position, *smoke, &mut out);
                for id in vehicles {
                    let v = self.world.actors.vehicle(id).unwrap();
                    let Some((min, max)) = (self.profiles.vehicle)(v).artillery else {
                        continue;
                    };
                    if v.fire_queue.len() >= 3 {
                        continue;
                    }
                    let distance = f64::from(flat(*position - v.position).length());
                    if distance < min || distance > max {
                        message(
                            &mut out,
                            Audience::Team(side),
                            MessageKind::Info,
                            format!(
                                "{}: out of range ({}-{} m).",
                                (self.world.vehicle)(v).name,
                                min as i64,
                                max as i64
                            ),
                            Some(v.position),
                        );
                        continue;
                    }
                    self.take(peer, &[], &[id], &mut out)?;
                    let v = self.world.actors.vehicle_mut(id).unwrap();
                    v.fire_queue.push(*position);
                    v.artillery_until = v.artillery_until.min(self.world.now);
                }
                self.take(peer, &squads, &[], &mut out)?;
                for id in squads {
                    out.extend(
                        movement(self.world)
                            .order_fire_mission(id, *position, *smoke, self.profiles.mortar)?
                            .into_iter()
                            .map(Event::Squad),
                    );
                }
            }
            Action::Work(target) | Action::Enter(target) | Action::Board(target) => {
                if self.world.actors.get(*target).is_some_and(|a| {
                    team(a) == side
                        && match command.action {
                            Action::Enter(_) => matches!(a, Actor::Structure(_)),
                            Action::Board(_) => matches!(a, Actor::Vehicle(_)),
                            _ => true,
                        }
                }) {
                    self.take(peer, &squads, &[], &mut out)?;
                    let gun = self
                        .world
                        .actors
                        .structure(*target)
                        .and_then(self.profiles.mount);
                    let seats = self
                        .world
                        .actors
                        .vehicle(*target)
                        .map_or(0, |v| (self.profiles.vehicle)(v).seats);
                    for id in squads {
                        let events = match command.action {
                            Action::Work(_) => movement(self.world).order_work(id, *target)?,
                            Action::Enter(_) => {
                                movement(self.world).order_enter(id, *target, gun)?
                            }
                            _ => movement(self.world).order_board(id, *target, seats)?,
                        };
                        out.extend(events.into_iter().map(Event::Squad));
                    }
                }
            }
            Action::Sling(target) => {
                if let Some(v) = self
                    .world
                    .actors
                    .vehicle(*target)
                    .filter(|v| v.team == side)
                {
                    let cargo = (self.world.vehicle)(v);
                    let (weight, heli, boat, automatic) = (
                        cargo.weight,
                        cargo.crew.helicopter,
                        cargo.crew.base == "boat",
                        cargo.crew.automatic,
                    );
                    for id in vehicles {
                        let h = self.world.actors.vehicle(id).unwrap();
                        let spec = SlingSpec {
                            lift: (self.world.vehicle)(h).crew.base == "lift_heli",
                            capacity: (self.profiles.vehicle)(h).sling_capacity.unwrap_or(-1),
                            cargo_weight: weight,
                            cargo_helicopter: heli,
                            cargo_boat: boat,
                            cargo_automatic: automatic,
                        };
                        if self.world.actors.can_sling(id, *target, spec)? {
                            self.take(peer, &[], &[id, *target], &mut out)?;
                            self.world.actors.order_sling(id, *target, spec)?;
                            break;
                        }
                    }
                }
            }
            Action::Throw { position, smoke } => {
                self.take(peer, &squads, &[], &mut out)?;
                for id in squads {
                    out.extend(
                        movement(self.world)
                            .order_throw(
                                id,
                                *position,
                                if *smoke { Round::Smoke } else { Round::Frag },
                            )?
                            .into_iter()
                            .map(Event::Squad),
                    );
                }
            }
            Action::Support {
                kind,
                position,
                direction,
            } => {
                if let Some(def) = (self.profiles.support)(kind) {
                    let (called, events) = self.rules.support.call(
                        self.world.actors,
                        self.world.battle,
                        self.world.rng,
                        self.world.now,
                        peer,
                        side,
                        *position,
                        *direction,
                        &def,
                        self.world.geometry.terrain.n as u32,
                    )?;
                    out.extend(events.into_iter().map(Event::Support));
                    if called {
                        out.push(Event::Deed {
                            peer,
                            text: format!("Called in {}", def.name),
                            position: *position,
                            major: true,
                        });
                    }
                }
            }
            Action::Produce {
                building,
                item,
                research,
            } => {
                if let Some(st) = self
                    .world
                    .actors
                    .structure(*building)
                    .filter(|s| s.team == side)
                {
                    if let Some(item) =
                        (self.profiles.item)(item, *research).filter(|i| i.research == *research)
                    {
                        let position = st.position;
                        let display = (self.profiles.structure_name)(st);
                        let produces = (self.profiles.produces)(&st.kind);
                        match self.rules.economy.order_production(
                            self.world.actors,
                            self.world.battle,
                            *building,
                            peer,
                            side,
                            item,
                            produces,
                            self.profiles.research,
                        )? {
                            Outcome::Changed => out.push(Event::Deed {
                                peer,
                                text: if *research {
                                    format!("Researching {}", item.name)
                                } else {
                                    format!("Training {} at {display}", item.name)
                                },
                                position,
                                major: *research,
                            }),
                            Outcome::Warning { peer, text } => warn(&mut out, peer, &text),
                            Outcome::Ignored => (),
                        }
                    }
                }
            }
            Action::Cancel(id) => {
                if let Outcome::Warning { peer, text } = self.rules.economy.cancel_production(
                    self.world.actors,
                    self.world.battle,
                    *id,
                    side,
                )? {
                    warn(&mut out, peer, &text);
                }
            }
            Action::Rally { building, position } => {
                if let Some(Actor::Structure(s)) = self.world.actors.get_mut(*building) {
                    if s.team == side {
                        s.rally = Some(*position);
                    }
                }
            }
            Action::TunnelExit { building, exit } => {
                if self
                    .world
                    .actors
                    .structure(*building)
                    .is_some_and(|s| s.team == side)
                {
                    self.tunnel(peer, *building, *exit, &mut out)?;
                }
            }
            Action::Chat { text, team_only } => {
                let text: String = text.trim().chars().take(200).collect();
                if !text.is_empty() {
                    message(
                        &mut out,
                        if *team_only {
                            Audience::Team(side)
                        } else {
                            Audience::Everyone
                        },
                        MessageKind::Chat,
                        format!("{}{name}: {text}", if *team_only { "[TEAM] " } else { "" }),
                        None,
                    );
                }
            }
            Action::DemoSupport { .. } => unreachable!(),
        }
        for event in &out {
            let movement = match event {
                Event::Squad(e)
                | Event::Placement(placement_world::Event::Squad(e))
                | Event::Attack(attack_plan::Event::Squad(e))
                | Event::Brain(squad_brain::Event::Movement(e)) => Some(e),
                _ => None,
            };
            if let Some(squad_movement::Event::CancelAmbush(id)) = movement {
                if let Some(plan) = self.ambushes.iter_mut().find(|p| p.id == *id) {
                    plan.done = true;
                }
            }
        }
        Ok(out)
    }
}
