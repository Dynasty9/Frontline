//! Static geometry and building state; model instances and visual toss animation are not simulation state.
use crate::cover::{Anchor, AnchorKind};
use crate::infantry::Credit;
use crate::state_codec::{Reader, Writer};
use crate::vector::Vector3;

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Part {
    pub position: Vector3,
    pub size: Vector3,
    pub yaw: f64,
    pub infantry: u8,
    pub vehicle: u8,
    pub cover: bool,
    pub collision: bool,
    pub door: bool,
}
#[derive(Clone, Debug, PartialEq)]
pub struct Production {
    pub item: String,
    pub remaining: f64,
    pub total: f64,
    pub owner: i32,
    pub cost: i32,
}
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct Work {
    pub worked: bool,
    pub completed: bool,
    pub repaired_fob: bool,
}
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub enum Tick {
    #[default]
    None,
    Fob,
    Town {
        count_houses: bool,
    },
    Production,
    Tent,
    Mount,
    Mine,
    Cache,
}
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct Capture {
    pub changed: bool,
    pub warning: bool,
    pub last_stand: bool,
    pub captured_by: Option<i8>,
    pub resupply: bool,
}
#[derive(Clone, Debug, Default, PartialEq)]
pub struct Produced {
    pub fraction_changed: bool,
    pub cap_warning: bool,
    pub item: Option<Production>,
}
#[derive(Clone, Copy, Debug)]
pub struct TownEconomy {
    pub stock: f64,
    pub yield_per_minute: f64,
    pub capture_pace: f64,
}
impl TownEconomy {
    fn valid(self) -> bool {
        [self.stock, self.yield_per_minute, self.capture_pace]
            .into_iter()
            .all(|v| v.is_finite() && (0.0..=1_000_000.0).contains(&v))
    }
}
#[derive(Clone, Debug, PartialEq)]
pub struct Structure {
    pub id: u32,
    pub team: i8,
    pub owner: i32,
    pub gone: bool,
    pub visible: u8,
    pub seen: u8,
    pub hit_by: Option<Credit>,
    pub kind: String,
    pub position: Vector3,
    pub yaw: f64,
    pub size: Vector3,
    pub variant: i32,
    pub built: bool,
    pub progress: f64,
    pub hp: f64,
    pub max_hp: f64,
    pub name: String,
    pub radius: f64,
    pub footprint: [f32; 2],
    pub parts: Vec<Part>,
    pub cover_points: Vec<Vector3>,
    pub anchors: Vec<Anchor>,
    pub nav_cells: Vec<u32>,
    pub hash_cells: Vec<[i32; 2]>,
    pub smashable: bool,
    pub indestructible: bool,
    pub supply: f64,
    pub wrecked: bool,
    pub capture_progress: f64,
    pub capture_team: i8,
    pub completed_order: u32,
    pub supply_parent: u32,
    pub road: Vec<Vector3>,
    pub truck: u32,
    pub truck_timer: f64,
    pub supply_status: String,
    pub alert_time: f64,
    pub zone_center: Option<Vector3>,
    pub zone_radius: f64,
    pub initial_houses: i32,
    pub intact: f64,
    pub house_timer: f64,
    pub queue: Vec<Production>,
    pub queue_fraction: f64,
    pub rally: Option<Vector3>,
    pub production_status: String,
    pub gunner: u32,
    pub manned: bool,
    pub inside: Vec<u32>,
    pub bearers: Vec<u32>,
    pub bearer_timer: f64,
    pub tick_timer: f64,
    pub tilt: [f32; 2],
    pub wreck_kind: String,
    pub door_closed: bool,
    pub burn: f64,
    pub burnt: bool,
    pub fire_kind: String,
    pub fuel: f64,
    pub fuel_max: f64,
    pub fire_queue: Vec<(Vector3, bool)>,
    pub hit_from: Option<Vector3>,
}
impl Default for Structure {
    fn default() -> Self {
        Self {
            id: 0,
            team: -1,
            owner: 0,
            gone: false,
            visible: 0,
            seen: 0,
            hit_by: None,
            kind: String::new(),
            position: Vector3::ZERO,
            yaw: 0.0,
            size: Vector3::ONE,
            variant: 0,
            built: true,
            progress: 1.0,
            hp: 100.0,
            max_hp: 100.0,
            name: String::new(),
            radius: 1.0,
            footprint: [1.0, 1.0],
            parts: vec![],
            cover_points: vec![],
            anchors: vec![],
            nav_cells: vec![],
            hash_cells: vec![],
            smashable: true,
            indestructible: false,
            supply: 0.0,
            wrecked: false,
            capture_progress: 0.0,
            capture_team: -1,
            completed_order: 0,
            supply_parent: 0,
            road: vec![],
            truck: 0,
            truck_timer: 4.0,
            supply_status: "OK".into(),
            alert_time: 0.0,
            zone_center: None,
            zone_radius: 0.0,
            initial_houses: -1,
            intact: 1.0,
            house_timer: 0.0,
            queue: vec![],
            queue_fraction: 0.0,
            rally: None,
            production_status: String::new(),
            gunner: 0,
            manned: false,
            inside: vec![],
            bearers: vec![],
            bearer_timer: 0.0,
            tick_timer: 0.0,
            tilt: [0.0, 0.0],
            wreck_kind: String::new(),
            door_closed: false,
            burn: 0.0,
            burnt: false,
            fire_kind: String::new(),
            fuel: 0.0,
            fuel_max: 0.0,
            fire_queue: vec![],
            hit_from: None,
        }
    }
}
fn point(p: Vector3) -> bool {
    p.is_finite() && p.abs().max_element() <= 1_000_000.0
}
fn scalar(v: f64) -> bool {
    v.is_finite() && v.abs() <= 1e12
}
fn text(s: &str, limit: usize) -> bool {
    s.len() <= limit
}
fn points(p: &[Vector3]) -> bool {
    p.len() <= 1_000_000 && p.iter().copied().all(point)
}
fn ids(ids: &[u32]) -> bool {
    ids.len() <= 100_000 && ids.iter().all(|&id| id != 0)
}

impl Structure {
    pub fn valid(&self) -> bool {
        self.id != 0
            && (-1..=1).contains(&self.team)
            && self.owner >= -2
            && self.visible <= 3
            && self.seen <= 3
            && self
                .hit_by
                .as_ref()
                .is_none_or(|h| h.owner >= -2 && (-1..=1).contains(&h.team) && text(&h.unit, 128))
            && !self.kind.is_empty()
            && text(&self.kind, 128)
            && point(self.position)
            && point(self.size)
            && [
                self.yaw,
                self.progress,
                self.hp,
                self.max_hp,
                self.supply,
                self.capture_progress,
                self.truck_timer,
                self.alert_time,
                self.house_timer,
                self.queue_fraction,
                self.bearer_timer,
                self.tick_timer,
                self.burn,
                self.fuel,
                self.fuel_max,
            ]
            .into_iter()
            .all(scalar)
            && self.max_hp >= 0.0
            && self.variant >= 0
            && self.variant <= 1_000_000
            && text(&self.name, 1024)
            && self.radius.is_finite()
            && (0.0..=1_000_000.0).contains(&self.radius)
            && self
                .footprint
                .into_iter()
                .all(|v| v.is_finite() && (0.0..=1_000_000.0).contains(&v))
            && self.parts.len() <= 100_000
            && self.parts.iter().all(|p| {
                point(p.position)
                    && point(p.size)
                    && scalar(p.yaw)
                    && p.infantry <= 3
                    && p.vehicle <= 3
            })
            && points(&self.cover_points)
            && self.anchors.len() <= 1_000_000
            && self
                .anchors
                .iter()
                .all(|a| point(a.position) && point(a.normal) && scalar(a.height))
            && self.nav_cells.len() <= 10_000_000
            && self.nav_cells.iter().all(|&n| n < 3072 * 3072)
            && self.hash_cells.len() <= 1_000_000
            && self
                .hash_cells
                .iter()
                .flatten()
                .all(|&v| (-1_000_000..=1_000_000).contains(&v))
            && (-1..=1).contains(&self.capture_team)
            && points(&self.road)
            && text(&self.supply_status, 128)
            && self.zone_center.is_none_or(point)
            && self.zone_radius.is_finite()
            && (0.0..=1_000_000.0).contains(&self.zone_radius)
            && (-1..=1_000_000).contains(&self.initial_houses)
            && self.intact.is_finite()
            && (0.0..=1.0).contains(&self.intact)
            && self.queue.len() <= 6
            && self.queue.iter().all(|q| {
                !q.item.is_empty()
                    && text(&q.item, 128)
                    && scalar(q.remaining)
                    && scalar(q.total)
                    && q.total > 0.0
                    && q.owner >= -2
                    && q.cost >= 0
            })
            && self.rally.is_none_or(point)
            && text(&self.production_status, 128)
            && ids(&self.inside)
            && ids(&self.bearers)
            && self
                .tilt
                .into_iter()
                .all(|v| v.is_finite() && v.abs() <= 1e12)
            && text(&self.wreck_kind, 128)
            && text(&self.fire_kind, 128)
            && self.fire_queue.len() <= 100_000
            && self.fire_queue.iter().all(|(p, _)| point(*p))
            && self.hit_from.is_none_or(point)
    }

    pub fn front(&self) -> Vector3 {
        Vector3::new(
            -libm::sin(self.yaw) as f32,
            0.0,
            -libm::cos(self.yaw) as f32,
        )
    }
    pub fn exit(&self) -> Vector3 {
        self.position + self.front() * (f64::from(self.size.z) * 0.5 + 3.0) as f32
    }
    pub fn needs_work(&self) -> bool {
        !self.built || self.hp < self.max_hp - 1.0
    }
    pub fn fire_kind(&self) -> &str {
        if self.burnt || !self.built || self.gone {
            return "";
        }
        match self.kind.as_str() {
            "tree" | "crates" | "watchtower" | "medic_tent" | "barracks" | "camo_net"
            | "barricade" => &self.kind,
            "car" if self.variant < 6 => "car",
            "wreck" | "rubble" if self.variant >= 6 => "wreck",
            "low_wall" if self.variant % 3 == 1 => "hedge",
            "roof" if self.variant % 2 == 0 => "roof",
            "bunker" if self.team == 1 => "log_bunker",
            "ammo_cache" => "crates",
            _ => "",
        }
    }
    pub fn char_out(&mut self) -> Result<bool, &'static str> {
        if !self.valid() {
            return Err("invalid structure state");
        }
        if self.burnt || self.gone {
            return Ok(false);
        }
        let variant = match self.kind.as_str() {
            "tree" => self.variant | 16,
            "car" => self.variant + 6,
            _ => self.variant,
        };
        if variant > 1_000_000 {
            return Err("charred variant exceeds limit");
        }
        self.burnt = true;
        self.variant = variant;
        Ok(true)
    }
    pub fn open_door(&mut self) -> bool {
        if !self.door_closed {
            return false;
        }
        self.door_closed = false;
        self.parts.retain(|p| !p.door);
        true
    }
    pub fn add_work(&mut self, amount: f64, build_time: Option<f64>) -> Result<Work, &'static str> {
        if !self.valid()
            || !amount.is_finite()
            || !(0.0..=1_000_000.0).contains(&amount)
            || build_time.is_some_and(|t| !t.is_finite() || !(0.001..=1e9).contains(&t))
        {
            return Err("invalid structure work");
        }
        if self.gone {
            return Ok(Work::default());
        }
        if self.built && self.burn > 0.0 && !scalar(self.fuel - amount * 4.0) {
            return Err("structure fuel exceeds limit");
        }
        if !self.built {
            let progress = (self.progress + amount / build_time.unwrap_or(10.0)).min(1.0);
            let hp = self.hp.max(self.max_hp * progress);
            if !scalar(hp) {
                return Err("structure health exceeds limit");
            }
            self.progress = progress;
            self.hp = hp;
            let completed = progress >= 1.0;
            if completed {
                self.built = true;
                self.progress = 1.0;
                self.hp = self.max_hp;
            }
            return Ok(Work {
                worked: true,
                completed,
                repaired_fob: false,
            });
        }
        if self.burn > 0.0 {
            self.fuel -= amount * 4.0;
        }
        if self.hp < self.max_hp {
            self.hp = (self.hp + amount * self.max_hp / (build_time.unwrap_or(20.0) * 0.8))
                .min(self.max_hp);
            let repaired_fob = self.wrecked && self.hp >= self.max_hp * 0.5;
            if repaired_fob {
                self.wrecked = false;
            }
            return Ok(Work {
                worked: true,
                completed: false,
                repaired_fob,
            });
        }
        Ok(Work::default())
    }

    pub fn door_blocks(&self, position: Vector3, direction: Vector3) -> bool {
        let inverse = crate::cover::rotation(-self.yaw);
        let p = crate::cover::transform(inverse, position - self.position);
        let d = crate::cover::transform(inverse, direction);
        let z = f64::from(p.z) - 0.08;
        f64::from(p.x).abs() < 1.05
            && z.abs() < 0.9
            && f64::from(d.z).abs() > 0.3
            && z * f64::from(d.z) < 0.0
    }

    /// Preserve the building's staggered work clock, including the stock earned before a town's house count.
    pub fn begin_tick(&mut self, dt: f64, economy: TownEconomy) -> Result<Tick, &'static str> {
        if !self.valid()
            || !dt.is_finite()
            || !(0.0..=10.0).contains(&dt)
            || !economy.valid()
            || !scalar(self.tick_timer - dt)
        {
            return Err("invalid structure tick");
        }
        if (self.team < 0 && self.kind != "town") || !self.built {
            return Ok(Tick::None);
        }
        self.tick_timer -= dt;
        if matches!(
            self.kind.as_str(),
            "barracks" | "factory" | "research" | "helipad" | "dock"
        ) {
            return Ok(Tick::Production);
        }
        if self.kind == "town" && self.team >= 0 && self.supply < economy.stock {
            self.supply = (self.supply
                + economy.yield_per_minute / 60.0 * dt * self.town_yield_factor())
            .min(economy.stock);
        }
        if self.tick_timer > 0.0 {
            return Ok(Tick::None);
        }
        let (interval, work) = match self.kind.as_str() {
            "fob" => (0.5, Tick::Fob),
            "town" => {
                // A due house count resets its timer, so an already overdue timer never underflows.
                let count_houses = self.house_timer <= 0.5;
                self.house_timer = if count_houses {
                    10.0
                } else {
                    self.house_timer - 0.5
                };
                (0.5, Tick::Town { count_houses })
            }
            "medic_tent" => (1.0, Tick::Tent),
            "mg_nest" | "watchtower" | "hmg_nest" | "mortar_pit" | "at_post" => (0.7, Tick::Mount),
            "mines" => (0.2, Tick::Mine),
            "ammo_cache" => (0.5, Tick::Cache),
            _ => return Ok(Tick::None),
        };
        self.tick_timer = interval;
        Ok(work)
    }
    pub fn town_yield_factor(&self) -> f64 {
        0.35 + 0.65 * self.intact
    }
    pub fn count_houses(&mut self, count: u32) -> Result<bool, &'static str> {
        if !self.valid() || count > 1_000_000 {
            return Err("invalid town houses");
        }
        if self.initial_houses < 0 {
            self.initial_houses = count as i32;
        }
        let fraction = if self.initial_houses > 0 {
            (f64::from(count) / f64::from(self.initial_houses)).clamp(0.0, 1.0)
        } else {
            1.0
        };
        let changed = (fraction - self.intact).abs() > 0.003;
        if changed {
            self.intact = fraction;
        }
        Ok(changed)
    }
    pub fn fob_capture(&mut self, counts: [u32; 2], last: bool) -> Result<Capture, &'static str> {
        if !self.valid() || self.kind != "fob" || self.team < 0 {
            return Err("invalid FOB capture");
        }
        let old = self.capture_progress;
        let friend = self.team as usize;
        let enemy = 1 - friend;
        let mut out = Capture::default();
        if counts[enemy] > 0 && counts[friend] == 0 {
            if self.capture_team != enemy as i8 {
                self.capture_team = enemy as i8;
                self.capture_progress = 0.0;
                out.warning = true;
                out.last_stand = last;
            }
            self.capture_progress +=
                (2.0 + f64::from(counts[enemy].min(6))) * if last { 0.25 } else { 1.0 };
            if self.capture_progress >= 100.0 {
                self.capture_progress = 0.0;
                self.capture_team = -1;
                out.captured_by = Some(enemy as i8);
                return Ok(out);
            }
        } else {
            self.capture_progress =
                (self.capture_progress - if counts[friend] > 0 { 8.0 } else { 3.0 }).max(0.0);
        }
        if self.capture_progress <= 0.0 {
            self.capture_team = -1;
        }
        out.changed = old != self.capture_progress;
        out.resupply = !self.wrecked;
        Ok(out)
    }
    pub fn town_capture(
        &mut self,
        counts: [u32; 2],
        now: f64,
        economy: TownEconomy,
    ) -> Result<Capture, &'static str> {
        if !self.valid()
            || self.kind != "town"
            || !scalar(now)
            || !scalar(now + 30.0)
            || !economy.valid()
        {
            return Err("invalid town capture");
        }
        let old = self.capture_progress;
        let mut out = Capture::default();
        let taker = (0..2).find(|&t| counts[t] > 0 && counts[1 - t] == 0 && self.team != t as i8);
        if let Some(taker) = taker {
            if self.capture_team != taker as i8 {
                self.capture_team = taker as i8;
                self.capture_progress = 0.0;
                if self.team >= 0 && now > self.alert_time {
                    self.alert_time = now + 30.0;
                    out.warning = true;
                }
            }
            self.capture_progress +=
                (0.8 + f64::from(counts[taker].min(8)) * 0.45) * economy.capture_pace * 0.5;
            if self.capture_progress >= 100.0 {
                self.capture_progress = 0.0;
                self.capture_team = -1;
                out.captured_by = Some(taker as i8);
                return Ok(out);
            }
        } else if counts[0] == 0 || counts[1] == 0 {
            let decay = if self.team >= 0 && counts[self.team as usize] > 0 {
                4.0
            } else {
                1.5
            };
            self.capture_progress = (self.capture_progress - decay).max(0.0);
        }
        if self.capture_progress <= 0.0 {
            self.capture_team = -1;
        }
        out.changed = old != self.capture_progress;
        out.resupply = self.team >= 0;
        Ok(out)
    }
    pub fn produce(&mut self, dt: f64, has_cap: bool) -> Result<Produced, &'static str> {
        if !self.valid() || !dt.is_finite() || !(0.0..=10.0).contains(&dt) {
            return Err("invalid production tick");
        }
        let mut out = Produced::default();
        let Some(q) = self.queue.first_mut() else {
            out.fraction_changed = self.queue_fraction != 0.0;
            self.queue_fraction = 0.0;
            return Ok(out);
        };
        if self.kind != "research" && !has_cap {
            out.cap_warning = self.production_status != "cap";
            self.production_status = "cap".into();
            return Ok(out);
        }
        let remaining = q.remaining - dt;
        let fraction = 1.0 - remaining / q.total;
        if !scalar(remaining) || !scalar(fraction) {
            return Err("production time exceeds limit");
        }
        self.production_status.clear();
        q.remaining = remaining;
        if (fraction - self.queue_fraction).abs() > 0.02 {
            self.queue_fraction = fraction;
            out.fraction_changed = true;
        }
        if remaining <= 0.0 {
            out.item = Some(self.queue.remove(0));
        }
        Ok(out)
    }

    pub fn checkpoint(&self) -> Result<Vec<u8>, &'static str> {
        if !self.valid() {
            return Err("invalid structure state");
        }
        let mut w = Writer::new(b"FLST\x01\0\0\0");
        for s in [
            &self.kind,
            &self.name,
            &self.supply_status,
            &self.production_status,
            &self.wreck_kind,
            &self.fire_kind,
        ] {
            w.bytes(s.as_bytes());
        }
        for id in [
            self.id,
            self.completed_order,
            self.supply_parent,
            self.truck,
            self.gunner,
        ] {
            w.u32(id);
        }
        w.byte(self.team as u8);
        w.u32(self.owner as u32);
        w.u32(self.variant as u32);
        w.u32(self.initial_houses as u32);
        w.byte(self.capture_team as u8);
        for b in [
            self.gone,
            self.built,
            self.smashable,
            self.indestructible,
            self.wrecked,
            self.manned,
            self.door_closed,
            self.burnt,
        ] {
            w.byte(u8::from(b));
        }
        w.byte(self.visible);
        w.byte(self.seen);
        for v in [
            self.yaw,
            self.progress,
            self.hp,
            self.max_hp,
            self.radius,
            self.supply,
            self.capture_progress,
            self.truck_timer,
            self.alert_time,
            self.zone_radius,
            self.intact,
            self.house_timer,
            self.queue_fraction,
            self.bearer_timer,
            self.tick_timer,
            self.burn,
            self.fuel,
            self.fuel_max,
        ] {
            w.f64(v);
        }
        w.point(self.position);
        w.point(self.size);
        for v in self.footprint.into_iter().chain(self.tilt) {
            w.f32(v);
        }
        for p in [self.zone_center, self.rally, self.hit_from] {
            w.byte(u8::from(p.is_some()));
            if let Some(p) = p {
                w.point(p);
            }
        }
        w.byte(u8::from(self.hit_by.is_some()));
        if let Some(h) = &self.hit_by {
            w.u32(h.owner as u32);
            w.byte(h.team as u8);
            w.bytes(h.unit.as_bytes());
            w.u32(h.soldier);
        }
        w.u32(self.parts.len() as u32);
        for p in &self.parts {
            w.point(p.position);
            w.point(p.size);
            w.f64(p.yaw);
            w.byte(p.infantry);
            w.byte(p.vehicle);
            for b in [p.cover, p.collision, p.door] {
                w.byte(u8::from(b));
            }
        }
        for ps in [&self.cover_points, &self.road] {
            w.u32(ps.len() as u32);
            for &p in ps {
                w.point(p);
            }
        }
        w.u32(self.anchors.len() as u32);
        for a in &self.anchors {
            w.point(a.position);
            w.point(a.normal);
            w.f64(a.height);
            w.byte(a.kind as u8);
        }
        for ids in [&self.nav_cells, &self.inside, &self.bearers] {
            w.u32(ids.len() as u32);
            for &id in ids {
                w.u32(id);
            }
        }
        w.u32(self.hash_cells.len() as u32);
        for cell in &self.hash_cells {
            w.u32(cell[0] as u32);
            w.u32(cell[1] as u32);
        }
        w.u32(self.queue.len() as u32);
        for q in &self.queue {
            w.bytes(q.item.as_bytes());
            w.f64(q.remaining);
            w.f64(q.total);
            w.u32(q.owner as u32);
            w.u32(q.cost as u32);
        }
        w.u32(self.fire_queue.len() as u32);
        for &(p, smoke) in &self.fire_queue {
            w.point(p);
            w.byte(u8::from(smoke));
        }
        Ok(w.0)
    }
    pub fn restore(bytes: &[u8]) -> Result<Self, &'static str> {
        if bytes.len() > 128 * 1024 * 1024 {
            return Err("structure checkpoint exceeds limit");
        }
        let mut r = Reader::new(bytes, b"FLST\x01\0\0\0")?;
        let kind = read_text(&mut r, 128)?;
        let name = read_text(&mut r, 1024)?;
        let supply_status = read_text(&mut r, 128)?;
        let production_status = read_text(&mut r, 128)?;
        let wreck_kind = read_text(&mut r, 128)?;
        let fire_kind = read_text(&mut r, 128)?;
        let id = r.u32()?;
        let completed_order = r.u32()?;
        let supply_parent = r.u32()?;
        let truck = r.u32()?;
        let gunner = r.u32()?;
        let team = r.byte()? as i8;
        let owner = r.u32()? as i32;
        let variant = r.u32()? as i32;
        let initial_houses = r.u32()? as i32;
        let capture_team = r.byte()? as i8;
        let gone = r.boolean()?;
        let built = r.boolean()?;
        let smashable = r.boolean()?;
        let indestructible = r.boolean()?;
        let wrecked = r.boolean()?;
        let manned = r.boolean()?;
        let door_closed = r.boolean()?;
        let burnt = r.boolean()?;
        let visible = r.byte()?;
        let seen = r.byte()?;
        let mut vs = [0.0; 18];
        for v in &mut vs {
            *v = r.f64()?;
        }
        let [yaw, progress, hp, max_hp, radius, supply, capture_progress, truck_timer, alert_time, zone_radius, intact, house_timer, queue_fraction, bearer_timer, tick_timer, burn, fuel, fuel_max] =
            vs;
        let position = r.point()?;
        let size = r.point()?;
        let footprint = [r.f32()?, r.f32()?];
        let tilt = [r.f32()?, r.f32()?];
        let zone_center = read_point(&mut r)?;
        let rally = read_point(&mut r)?;
        let hit_from = read_point(&mut r)?;
        let hit_by = if r.boolean()? {
            Some(Credit {
                owner: r.u32()? as i32,
                team: r.byte()? as i8,
                unit: read_text(&mut r, 128)?,
                soldier: r.u32()?,
            })
        } else {
            None
        };
        let parts = list(&mut r, 100_000, |r| {
            Ok(Part {
                position: r.point()?,
                size: r.point()?,
                yaw: r.f64()?,
                infantry: r.byte()?,
                vehicle: r.byte()?,
                cover: r.boolean()?,
                collision: r.boolean()?,
                door: r.boolean()?,
            })
        })?;
        let cover_points = list(&mut r, 1_000_000, |r| r.point())?;
        let road = list(&mut r, 1_000_000, |r| r.point())?;
        let anchors = list(&mut r, 1_000_000, |r| {
            let position = r.point()?;
            let normal = r.point()?;
            let height = r.f64()?;
            let kind = match r.byte()? {
                1 => AnchorKind::Over,
                2 => AnchorKind::EdgeLeft,
                3 => AnchorKind::EdgeRight,
                4 => AnchorKind::Shelter,
                5 => AnchorKind::Stack,
                _ => return Err("invalid structure anchor"),
            };
            Ok(Anchor {
                position,
                normal,
                height,
                kind,
            })
        })?;
        let nav_cells = list(&mut r, 10_000_000, |r| r.u32())?;
        let inside = list(&mut r, 100_000, |r| r.u32())?;
        let bearers = list(&mut r, 100_000, |r| r.u32())?;
        let hash_cells = list(&mut r, 1_000_000, |r| {
            Ok([r.u32()? as i32, r.u32()? as i32])
        })?;
        let queue = list(&mut r, 6, |r| {
            Ok(Production {
                item: read_text(r, 128)?,
                remaining: r.f64()?,
                total: r.f64()?,
                owner: r.u32()? as i32,
                cost: r.u32()? as i32,
            })
        })?;
        let fire_queue = list(&mut r, 100_000, |r| Ok((r.point()?, r.boolean()?)))?;
        r.finish()?;
        let s = Self {
            id,
            team,
            owner,
            gone,
            visible,
            seen,
            hit_by,
            kind,
            position,
            yaw,
            size,
            variant,
            built,
            progress,
            hp,
            max_hp,
            name,
            radius,
            footprint,
            parts,
            cover_points,
            anchors,
            nav_cells,
            hash_cells,
            smashable,
            indestructible,
            supply,
            wrecked,
            capture_progress,
            capture_team,
            completed_order,
            supply_parent,
            road,
            truck,
            truck_timer,
            supply_status,
            alert_time,
            zone_center,
            zone_radius,
            initial_houses,
            intact,
            house_timer,
            queue,
            queue_fraction,
            rally,
            production_status,
            gunner,
            manned,
            inside,
            bearers,
            bearer_timer,
            tick_timer,
            tilt,
            wreck_kind,
            door_closed,
            burn,
            burnt,
            fire_kind,
            fuel,
            fuel_max,
            fire_queue,
            hit_from,
        };
        if !s.valid() {
            return Err("invalid structure checkpoint");
        }
        Ok(s)
    }
}
fn read_text(r: &mut Reader<'_>, limit: usize) -> Result<String, &'static str> {
    std::str::from_utf8(r.bytes(limit)?)
        .map(str::to_owned)
        .map_err(|_| "invalid structure text")
}
fn read_point(r: &mut Reader<'_>) -> Result<Option<Vector3>, &'static str> {
    Ok(if r.boolean()? { Some(r.point()?) } else { None })
}
fn list<T>(
    r: &mut Reader<'_>,
    limit: usize,
    mut read: impl FnMut(&mut Reader<'_>) -> Result<T, &'static str>,
) -> Result<Vec<T>, &'static str> {
    let n = r.u32()? as usize;
    if n > limit {
        return Err("structure collection exceeds limit");
    }
    let mut result = Vec::new();
    for _ in 0..n {
        result.push(read(r)?);
    }
    Ok(result)
}
