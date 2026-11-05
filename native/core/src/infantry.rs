//! Retained infantry state. Entity links are stable IDs; presentation objects stay outside the core.
pub use crate::breach_selection::Opening;
use crate::drone_reaction::DroneMemory;
use crate::grenade_attack::GrenadeAttack;
use crate::grenade_reaction::GrenadeMemory;
use crate::infantry_action::{Action, ActionState, Round};
use crate::infantry_aim::InfantryAim;
use crate::infantry_arsenal::InfantryArsenal;
use crate::infantry_control::Control;
use crate::infantry_controller::{Controller, Task};
use crate::infantry_idle::Idle;
use crate::infantry_motion::InfantryMotion;
use crate::infantry_pose::Posture;
use crate::infantry_shock::InfantryShock;
use crate::infantry_supply::SupplyTimers;
use crate::infantry_vitals::InfantryVitals;
use crate::infantry_weapon::InfantryWeapon;
use crate::state_codec::{Reader, Writer};
use crate::vector::Vector3;

#[derive(Clone, Debug, Default, PartialEq)]
pub struct Credit {
    pub owner: i32,
    pub team: i8,
    pub unit: String,
    pub soldier: u32,
}

#[derive(Clone, Debug, Default, PartialEq)]
pub struct Identity {
    pub id: u32,
    pub team: i8,
    pub owner: i32,
    pub gone: bool,
    pub visible: u8,
    pub seen: u8,
    pub unit: String,
    pub name: String,
    pub squad: u32,
    pub weapon: String,
    pub mounted_weapon: String,
    pub hit_by: Option<Credit>,
}

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
#[repr(u8)]
pub enum Goal {
    #[default]
    None,
    Slot,
    Cover,
    Task,
    Prison,
    Crawl,
}
impl TryFrom<u8> for Goal {
    type Error = &'static str;
    fn try_from(v: u8) -> Result<Self, Self::Error> {
        match v {
            0 => Ok(Self::None),
            1 => Ok(Self::Slot),
            2 => Ok(Self::Cover),
            3 => Ok(Self::Task),
            4 => Ok(Self::Prison),
            5 => Ok(Self::Crawl),
            _ => Err("invalid route purpose"),
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Orders {
    pub pending_path: bool,
    pub path_revision: u64,
    pub goal: Vector3,
    pub purpose: Goal,
    pub move_mode: u8,
    pub base_y: f64,
    pub backwards: bool,
    pub hold_position: Vector3,
    pub hold_face: Vector3,
    pub leash: f64,
    pub detached: bool,
}
impl Default for Orders {
    fn default() -> Self {
        Self {
            pending_path: false,
            path_revision: 0,
            goal: Vector3::ZERO,
            purpose: Goal::None,
            move_mode: 0,
            base_y: 0.0,
            backwards: false,
            hold_position: Vector3::ZERO,
            hold_face: Vector3::NEG_Z,
            leash: 9.0,
            detached: false,
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct FightingPosition {
    pub kind: u8,
    pub position: Vector3,
    pub at_cover: bool,
    pub lean_direction: Vector3,
    pub threat: Vector3,
    pub evaluate_at: f64,
    pub normal: Vector3,
    pub height: f64,
    pub material: i8,
    pub structure: u64,
    pub anchor: i32,
    pub shifting: bool,
}
impl Default for FightingPosition {
    fn default() -> Self {
        Self {
            kind: 0,
            position: Vector3::ZERO,
            at_cover: false,
            lean_direction: Vector3::ZERO,
            threat: Vector3::NEG_Z,
            evaluate_at: 0.0,
            normal: Vector3::ZERO,
            height: 0.0,
            material: -1,
            structure: 0,
            anchor: -1,
            shifting: false,
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Duty {
    pub kind: Task,
    pub entity: u64,
    pub partner: u64,
    pub phase: u8,
    pub timer: f64,
    pub position: Vector3,
    pub second_position: Vector3,
    pub front: bool,
    pub throw_kind: Round,
}
impl Default for Duty {
    fn default() -> Self {
        Self {
            kind: Task::Fight,
            entity: 0,
            partner: 0,
            phase: 0,
            timer: 0.0,
            position: Vector3::ZERO,
            second_position: Vector3::ZERO,
            front: false,
            throw_kind: Round::Frag,
        }
    }
}

#[derive(Clone, Debug, Default, PartialEq)]
pub struct Links {
    pub vehicle: u64,
    pub dragged_by: u64,
    pub rescue_claimed: u64,
    pub carried_by: Vec<u64>,
    pub stretcher_claimed: bool,
    pub captor: u64,
    pub hidden_in: u64,
    pub tent_dead: bool,
    pub home: u64,
    pub prison_destination: u64,
    pub intel_left: i32,
    pub intel_timer: f64,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct BreachChoice {
    pub house: u64,
    pub opening: Opening,
    pub enemy: u64,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct HouseEntry {
    pub clear: bool,
    pub no_frag: bool,
    pub selected: Option<BreachChoice>,
    pub house: u64,
    pub opening: Option<Opening>,
    pub next_check: f64,
    pub cooking_started: f64,
    pub grenade: u64,
    pub wait_until: f64,
    pub reordered: bool,
}
impl Default for HouseEntry {
    fn default() -> Self {
        Self {
            clear: false,
            no_frag: false,
            selected: None,
            house: 0,
            opening: None,
            next_check: 0.0,
            cooking_started: -1.0,
            grenade: 0,
            wait_until: 0.0,
            reordered: false,
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Emplacement {
    pub structure: u64,
    pub target: u64,
    pub scan_timer: f64,
    pub mortar_aim: Option<Vector3>,
    pub mortar_round: Round,
    pub mortar_delay: f64,
}
impl Default for Emplacement {
    fn default() -> Self {
        Self {
            structure: 0,
            target: 0,
            scan_timer: 0.0,
            mortar_aim: None,
            mortar_round: Round::HighExplosive,
            mortar_delay: 5.0,
        }
    }
}

#[derive(Clone, Debug, Default, PartialEq)]
pub struct Fight {
    pub target: u64,
    pub forced_target: u64,
    pub visible_targets: Vec<u64>,
    pub covering_until: f64,
    pub covering_position: Vector3,
    pub fire_team: u8,
    pub out_of_ammo_said: bool,
    pub controlled_drone: u64,
    pub sector: Vector3,
    pub separation: Vector3,
    pub shuffling: bool,
    pub noticed_grenade: u64,
    pub flee_fire_at: f64,
    pub build_sound_timer: f64,
    pub loot: i32,
    pub smokes: i32,
}

#[derive(Clone, Debug, Default, PartialEq)]
pub struct Infantry {
    pub identity: Identity,
    pub vitals: InfantryVitals,
    pub motion: InfantryMotion,
    pub weapon: InfantryWeapon,
    pub arsenal: InfantryArsenal,
    pub grenades: GrenadeAttack,
    pub supply: SupplyTimers,
    pub control: Control,
    pub idle: Idle,
    pub controller: Controller,
    pub shock: InfantryShock,
    pub aim: InfantryAim,
    pub grenade_memory: GrenadeMemory,
    pub drone_memory: DroneMemory,
    pub action: ActionState,
    pub orders: Orders,
    pub cover: FightingPosition,
    pub duty: Duty,
    pub links: Links,
    pub entry: HouseEntry,
    pub emplacement: Emplacement,
    pub fight: Fight,
    pub posture: Posture,
    pub activity: u8,
    pub flags: u8,
    pub doing: u8,
    pub doing_entity: u64,
    pub hit_direction: Vector3,
    pub hit_kind: String,
}

fn point(p: Vector3) -> bool {
    p.is_finite() && p.abs().max_element() <= 1_000_000.0
}
fn time(v: f64) -> bool {
    v.is_finite() && v.abs() <= 1e12
}
fn id(v: u64) -> bool {
    v <= u32::MAX as u64
}
fn text(v: &str, max: usize) -> bool {
    v.len() <= max && !v.contains('\0')
}
fn opening(o: Opening) -> bool {
    id(o.id) && point(o.center) && point(o.normal)
}
fn ids(v: &[u64], limit: usize) -> bool {
    v.len() <= limit && v.iter().all(|v| *v != 0 && id(*v))
}

impl Infantry {
    pub fn checkpoint(&self) -> Result<Vec<u8>, &'static str> {
        if !self.valid() {
            return Err("invalid infantry state");
        }
        let mut out = Writer::new(b"FLIN\x01\0\0\0");
        let i = &self.identity;
        out.u32(i.id);
        out.byte(i.team as u8);
        out.u32(i.owner as u32);
        out.byte(u8::from(i.gone));
        out.byte(i.visible);
        out.byte(i.seen);
        out.bytes(i.unit.as_bytes());
        out.bytes(i.name.as_bytes());
        out.u32(i.squad);
        out.bytes(i.weapon.as_bytes());
        out.bytes(i.mounted_weapon.as_bytes());
        out.byte(u8::from(i.hit_by.is_some()));
        if let Some(h) = &i.hit_by {
            out.u32(h.owner as u32);
            out.byte(h.team as u8);
            out.bytes(h.unit.as_bytes());
            out.u32(h.soldier);
        }
        out.bytes(&self.vitals.checkpoint());
        out.bytes(&self.motion.checkpoint());
        out.bytes(&self.weapon.checkpoint());
        out.bytes(&self.arsenal.checkpoint());
        out.bytes(&self.grenades.checkpoint());
        out.bytes(&self.supply.checkpoint());
        out.bytes(&self.control.checkpoint());
        out.bytes(&self.idle.checkpoint());
        out.bytes(&self.controller.checkpoint());
        out.bytes(&self.shock.checkpoint());
        out.bytes(&self.aim.checkpoint());
        out.bytes(&self.grenade_memory.checkpoint());
        out.bytes(&self.drone_memory.checkpoint());
        out.bytes(&self.action.checkpoint());
        let o = &self.orders;
        out.byte(u8::from(o.pending_path));
        out.u64(o.path_revision);
        out.point(o.goal);
        out.byte(o.purpose as u8);
        out.byte(o.move_mode);
        out.f64(o.base_y);
        out.byte(u8::from(o.backwards));
        out.point(o.hold_position);
        out.point(o.hold_face);
        out.f64(o.leash);
        out.byte(u8::from(o.detached));
        let c = &self.cover;
        out.byte(c.kind);
        out.point(c.position);
        out.byte(u8::from(c.at_cover));
        out.point(c.lean_direction);
        out.point(c.threat);
        out.f64(c.evaluate_at);
        out.point(c.normal);
        out.f64(c.height);
        out.byte(c.material as u8);
        out.u64(c.structure);
        out.u32(c.anchor as u32);
        out.byte(u8::from(c.shifting));
        let d = &self.duty;
        out.byte(d.kind as u8);
        out.u64(d.entity);
        out.u64(d.partner);
        out.byte(d.phase);
        out.f64(d.timer);
        out.point(d.position);
        out.point(d.second_position);
        out.byte(u8::from(d.front));
        out.byte(d.throw_kind as u8);
        let l = &self.links;
        out.u64(l.vehicle);
        out.u64(l.dragged_by);
        out.u64(l.rescue_claimed);
        write_ids(&mut out, &l.carried_by);
        out.byte(u8::from(l.stretcher_claimed));
        out.u64(l.captor);
        out.u64(l.hidden_in);
        out.byte(u8::from(l.tent_dead));
        out.u64(l.home);
        out.u64(l.prison_destination);
        out.u32(l.intel_left as u32);
        out.f64(l.intel_timer);
        let e = &self.entry;
        out.byte(u8::from(e.clear));
        out.byte(u8::from(e.no_frag));
        out.byte(u8::from(e.selected.is_some()));
        if let Some(b) = e.selected {
            out.u64(b.house);
            write_opening(&mut out, b.opening);
            out.u64(b.enemy);
        }
        out.u64(e.house);
        out.byte(u8::from(e.opening.is_some()));
        if let Some(o) = e.opening {
            write_opening(&mut out, o);
        }
        out.f64(e.next_check);
        out.f64(e.cooking_started);
        out.u64(e.grenade);
        out.f64(e.wait_until);
        out.byte(u8::from(e.reordered));
        let m = &self.emplacement;
        out.u64(m.structure);
        out.u64(m.target);
        out.f64(m.scan_timer);
        out.byte(u8::from(m.mortar_aim.is_some()));
        if let Some(p) = m.mortar_aim {
            out.point(p);
        }
        out.byte(m.mortar_round as u8);
        out.f64(m.mortar_delay);
        let f = &self.fight;
        out.u64(f.target);
        out.u64(f.forced_target);
        write_ids(&mut out, &f.visible_targets);
        out.f64(f.covering_until);
        out.point(f.covering_position);
        out.byte(f.fire_team);
        out.byte(u8::from(f.out_of_ammo_said));
        out.u64(f.controlled_drone);
        out.point(f.sector);
        out.point(f.separation);
        out.byte(u8::from(f.shuffling));
        out.u64(f.noticed_grenade);
        out.f64(f.flee_fire_at);
        out.f64(f.build_sound_timer);
        out.u32(f.loot as u32);
        out.u32(f.smokes as u32);
        out.byte(self.posture as u8);
        out.byte(self.activity);
        out.byte(self.flags);
        out.byte(self.doing);
        out.u64(self.doing_entity);
        out.point(self.hit_direction);
        out.bytes(self.hit_kind.as_bytes());
        Ok(out.0)
    }

    pub fn restore(bytes: &[u8]) -> Result<Self, &'static str> {
        let mut input = Reader::new(bytes, b"FLIN\x01\0\0\0")?;
        let identity = Identity {
            id: input.u32()?,
            team: input.byte()? as i8,
            owner: input.u32()? as i32,
            gone: input.boolean()?,
            visible: input.byte()?,
            seen: input.byte()?,
            unit: read_text(&mut input, 128)?,
            name: read_text(&mut input, 1024)?,
            squad: input.u32()?,
            weapon: read_text(&mut input, 128)?,
            mounted_weapon: read_text(&mut input, 128)?,
            hit_by: if input.boolean()? {
                Some(Credit {
                    owner: input.u32()? as i32,
                    team: input.byte()? as i8,
                    unit: read_text(&mut input, 128)?,
                    soldier: input.u32()?,
                })
            } else {
                None
            },
        };
        let vitals = InfantryVitals::restore(input.bytes(4096)?)?;
        let motion = InfantryMotion::restore(input.bytes(12_001_024)?)?;
        let weapon = InfantryWeapon::restore(input.bytes(4096)?)?;
        let arsenal = InfantryArsenal::restore(input.bytes(4096)?)?;
        let grenades = GrenadeAttack::restore(input.bytes(4096)?)?;
        let supply = SupplyTimers::restore(input.bytes(4096)?)?;
        let control = Control::restore(input.bytes(4096)?)?;
        let idle = Idle::restore(input.bytes(530_000)?)?;
        let controller = Controller::restore(input.bytes(4096)?)?;
        let shock = InfantryShock::restore(input.bytes(4096)?)?;
        let aim = InfantryAim::restore(input.bytes(4096)?)?;
        let grenade_memory = GrenadeMemory::restore(input.bytes(800_012)?)?;
        let drone_memory = DroneMemory::restore(input.bytes(4096)?)?;
        let action = ActionState::restore(input.bytes(4096)?)?;
        let orders = Orders {
            pending_path: input.boolean()?,
            path_revision: input.u64()?,
            goal: input.point()?,
            purpose: Goal::try_from(input.byte()?)?,
            move_mode: input.byte()?,
            base_y: input.f64()?,
            backwards: input.boolean()?,
            hold_position: input.point()?,
            hold_face: input.point()?,
            leash: input.f64()?,
            detached: input.boolean()?,
        };
        let cover = FightingPosition {
            kind: input.byte()?,
            position: input.point()?,
            at_cover: input.boolean()?,
            lean_direction: input.point()?,
            threat: input.point()?,
            evaluate_at: input.f64()?,
            normal: input.point()?,
            height: input.f64()?,
            material: input.byte()? as i8,
            structure: input.u64()?,
            anchor: input.u32()? as i32,
            shifting: input.boolean()?,
        };
        let duty = Duty {
            kind: Task::try_from(input.byte()?)?,
            entity: input.u64()?,
            partner: input.u64()?,
            phase: input.byte()?,
            timer: input.f64()?,
            position: input.point()?,
            second_position: input.point()?,
            front: input.boolean()?,
            throw_kind: read_round(&mut input)?,
        };
        let links = Links {
            vehicle: input.u64()?,
            dragged_by: input.u64()?,
            rescue_claimed: input.u64()?,
            carried_by: read_ids(&mut input, 64)?,
            stretcher_claimed: input.boolean()?,
            captor: input.u64()?,
            hidden_in: input.u64()?,
            tent_dead: input.boolean()?,
            home: input.u64()?,
            prison_destination: input.u64()?,
            intel_left: input.u32()? as i32,
            intel_timer: input.f64()?,
        };
        let entry = HouseEntry {
            clear: input.boolean()?,
            no_frag: input.boolean()?,
            selected: if input.boolean()? {
                Some(BreachChoice {
                    house: input.u64()?,
                    opening: read_opening(&mut input)?,
                    enemy: input.u64()?,
                })
            } else {
                None
            },
            house: input.u64()?,
            opening: if input.boolean()? {
                Some(read_opening(&mut input)?)
            } else {
                None
            },
            next_check: input.f64()?,
            cooking_started: input.f64()?,
            grenade: input.u64()?,
            wait_until: input.f64()?,
            reordered: input.boolean()?,
        };
        let emplacement = Emplacement {
            structure: input.u64()?,
            target: input.u64()?,
            scan_timer: input.f64()?,
            mortar_aim: if input.boolean()? {
                Some(input.point()?)
            } else {
                None
            },
            mortar_round: read_round(&mut input)?,
            mortar_delay: input.f64()?,
        };
        let fight = Fight {
            target: input.u64()?,
            forced_target: input.u64()?,
            visible_targets: read_ids(&mut input, 100_000)?,
            covering_until: input.f64()?,
            covering_position: input.point()?,
            fire_team: input.byte()?,
            out_of_ammo_said: input.boolean()?,
            controlled_drone: input.u64()?,
            sector: input.point()?,
            separation: input.point()?,
            shuffling: input.boolean()?,
            noticed_grenade: input.u64()?,
            flee_fire_at: input.f64()?,
            build_sound_timer: input.f64()?,
            loot: input.u32()? as i32,
            smokes: input.u32()? as i32,
        };
        let value = Self {
            identity,
            vitals,
            motion,
            weapon,
            arsenal,
            grenades,
            supply,
            control,
            idle,
            controller,
            shock,
            aim,
            grenade_memory,
            drone_memory,
            action,
            orders,
            cover,
            duty,
            links,
            entry,
            emplacement,
            fight,
            posture: Posture::try_from(input.byte()?)?,
            activity: input.byte()?,
            flags: input.byte()?,
            doing: input.byte()?,
            doing_entity: input.u64()?,
            hit_direction: input.point()?,
            hit_kind: read_text(&mut input, 128)?,
        };
        input.finish()?;
        if !value.valid() {
            return Err("invalid infantry checkpoint");
        }
        Ok(value)
    }

    pub fn valid(&self) -> bool {
        let i = &self.identity;
        let o = &self.orders;
        let c = &self.cover;
        let d = &self.duty;
        let l = &self.links;
        let e = &self.entry;
        let m = &self.emplacement;
        let f = &self.fight;
        i.id != 0
            && (-1..=1).contains(&i.team)
            && i.owner >= -2
            && i.visible <= 3
            && i.seen <= 3
            && !i.unit.is_empty()
            && text(&i.unit, 128)
            && text(&i.name, 1024)
            && text(&i.weapon, 128)
            && text(&i.mounted_weapon, 128)
            && i.hit_by
                .as_ref()
                .is_none_or(|h| h.owner >= -2 && (-1..=1).contains(&h.team) && text(&h.unit, 128))
            && self.vitals.valid()
            && self.motion.valid()
            && self.weapon.valid()
            && self.arsenal.valid()
            && self.grenades.valid()
            && self.supply.valid()
            && self.control.valid()
            && self.idle.valid()
            && self.controller.valid()
            && self.shock.valid()
            && self.aim.valid()
            && self.grenade_memory.valid()
            && self.drone_memory.valid()
            && self.action.valid()
            && id(self.motion.door)
            && id(self.idle.partner)
            && id(self.aim.sight_target)
            && self.grenade_memory.seen.iter().copied().all(id)
            && self.drone_memory.heard.iter().copied().all(id)
            && match self.action.current {
                Action::Rethrow { grenade, .. }
                | Action::Kick { grenade, .. }
                | Action::Pickup { grenade } => id(grenade),
                Action::DoorKick { door, .. } => id(door),
                Action::Melee { target }
                | Action::Launch { target }
                | Action::LaunchDrone { target } => id(target),
                _ => true,
            }
            && o.path_revision <= i64::MAX as u64
            && o.move_mode <= 2
            && point(o.goal)
            && point(o.hold_position)
            && point(o.hold_face)
            && o.base_y.is_finite()
            && o.base_y.abs() <= 1_000_000.0
            && o.leash.is_finite()
            && (0.0..=1_000_000.0).contains(&o.leash)
            && c.kind <= 3
            && [c.position, c.lean_direction, c.threat, c.normal]
                .into_iter()
                .all(point)
            && time(c.evaluate_at)
            && c.height.is_finite()
            && c.height.abs() <= 1_000_000.0
            && (-1..=3).contains(&c.material)
            && id(c.structure)
            && (-1..=1_000_000).contains(&c.anchor)
            && id(d.entity)
            && id(d.partner)
            && time(d.timer)
            && point(d.position)
            && point(d.second_position)
            && d.throw_kind != Round::HighExplosive
            && [
                l.vehicle,
                l.dragged_by,
                l.rescue_claimed,
                l.captor,
                l.hidden_in,
                l.home,
                l.prison_destination,
            ]
            .into_iter()
            .all(id)
            && ids(&l.carried_by, 64)
            && (0..=1_000_000).contains(&l.intel_left)
            && time(l.intel_timer)
            && e.selected
                .is_none_or(|b| id(b.house) && opening(b.opening) && id(b.enemy))
            && id(e.house)
            && e.opening.is_none_or(opening)
            && [e.next_check, e.cooking_started, e.wait_until]
                .into_iter()
                .all(time)
            && id(e.grenade)
            && id(m.structure)
            && id(m.target)
            && time(m.scan_timer)
            && m.mortar_aim.is_none_or(point)
            && m.mortar_round != Round::Frag
            && m.mortar_delay.is_finite()
            && (0.0..=3600.0).contains(&m.mortar_delay)
            && [
                f.target,
                f.forced_target,
                f.controlled_drone,
                f.noticed_grenade,
            ]
            .into_iter()
            .all(id)
            && ids(&f.visible_targets, 100_000)
            && [f.covering_until, f.flee_fire_at, f.build_sound_timer]
                .into_iter()
                .all(time)
            && [f.covering_position, f.sector, f.separation]
                .into_iter()
                .all(point)
            && f.fire_team <= 1
            && (0..=1_000_000).contains(&f.loot)
            && (-1_000_000..=1_000_000).contains(&f.smokes)
            && self.activity <= 36
            && self.doing <= 52
            && id(self.doing_entity)
            && point(self.hit_direction)
            && text(&self.hit_kind, 128)
    }
}

fn read_text(input: &mut Reader<'_>, limit: usize) -> Result<String, &'static str> {
    std::str::from_utf8(input.bytes(limit)?)
        .map(str::to_owned)
        .map_err(|_| "invalid infantry text")
}
fn write_ids(out: &mut Writer, ids: &[u64]) {
    out.u32(ids.len() as u32);
    for id in ids {
        out.u64(*id);
    }
}
fn read_ids(input: &mut Reader<'_>, limit: usize) -> Result<Vec<u64>, &'static str> {
    let count = input.u32()? as usize;
    if count > limit {
        return Err("too many infantry links");
    }
    let mut ids = Vec::new();
    for _ in 0..count {
        ids.push(input.u64()?);
    }
    Ok(ids)
}
fn write_opening(out: &mut Writer, opening: Opening) {
    out.u64(opening.id);
    out.point(opening.center);
    out.point(opening.normal);
    out.byte(u8::from(opening.door));
}
fn read_opening(input: &mut Reader<'_>) -> Result<Opening, &'static str> {
    Ok(Opening {
        id: input.u64()?,
        center: input.point()?,
        normal: input.point()?,
        door: input.boolean()?,
    })
}
fn read_round(input: &mut Reader<'_>) -> Result<Round, &'static str> {
    match input.byte()? {
        0 => Ok(Round::Frag),
        1 => Ok(Round::Smoke),
        2 => Ok(Round::HighExplosive),
        _ => Err("invalid infantry round"),
    }
}
