//! Retained infantry firing-cycle state. Inter-soldier effects happen in the returned order.
use crate::random::SimulationRandom;
use crate::state_codec::{Reader, Writer};
use crate::vector::Vector3;

#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct InfantryWeapon {
    pub peek_timer: f64,
    pub peek_up: bool,
    pub peek_from: f64,
    pub up_suppression: f64,
    pub stayed: bool,
    pub watching: bool,
    pub blind: bool,
    pub reload_timer: f64,
    pub burst_left: i32,
    pub magazine: i32,
    pub reserve: i32,
    pub fire_timer: f64,
    pub last_shot: f64,
    pub low_ammo_said: bool,
}

#[derive(Clone, Copy, Debug)]
pub struct Weapon {
    pub ammunition: i32,
    pub magazine: i32,
    pub reload_time: f64,
}

impl Weapon {
    fn valid(self) -> bool {
        (0..=1_000_000).contains(&self.ammunition)
            && (0..=1_000_000).contains(&self.magazine)
            && self.reload_time.is_finite()
            && (0.0..=3600.0).contains(&self.reload_time)
    }
}

#[derive(Clone, Copy, Debug)]
pub struct ShotInput {
    pub weapon: Weapon,
    pub burst_min: i32,
    pub burst_max: i32,
    pub time: f64,
    pub stamina: f64,
    pub moving: bool,
    pub gun_override: bool,
    pub squad_accuracy: f64,
    pub ambush: bool,
}

#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct ShotResult {
    pub fired: bool,
    pub low_ammo: bool,
    pub announce_low_ammo: bool,
    pub reload_speech: Option<u8>,
    pub accuracy: f64,
}

#[derive(Clone, Copy, Debug)]
pub struct CoverInput {
    pub dt: f64,
    pub time: f64,
    pub team: i32,
    pub suppression: f64,
    pub last_suppression: f64,
    pub hit_dirt_timer: f64,
    pub ground: f64,
    pub cover_kind: u8,
    pub cover_height: f64,
    pub cover_material: i32,
    pub want_fire: bool,
    pub pinned: bool,
    pub target_valid: bool,
    pub buddy_up: bool,
    pub weapon: Option<Weapon>,
}

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct CoverResult {
    pub drew_fire: bool,
    pub peeked: bool,
    pub blind_fire: bool,
    pub reload_speech: Option<u8>,
    pub call_cover: bool,
    pub shift_along: bool,
}

#[derive(Clone, Copy, Debug, Default)]
pub struct StanceInput {
    pub time: f64,
    pub entity: u64,
    pub mode: u8, // normal, escort, crew
    pub moving: bool,
    pub crawling: bool,
    pub near_cover: bool,
    pub move_mode: u8,
    pub shifting: bool,
    pub at_cover: bool,
    pub cover_kind: u8,
    pub cover_height: f64,
    pub mounted: bool,
    pub bay: bool,
    pub danger: bool,
    pub pinned: bool,
    pub suppression: f64,
    pub hit_dirt_timer: f64,
    pub sector: bool,
    pub machine_gunner: bool,
    pub target_valid: bool,
    pub covering: bool,
    pub crew_mount: bool,
    pub armed: bool,
    pub ambush: bool,
    pub forced_target: bool,
    pub yaw: f64,
    pub threat: Vector3,
    pub lean_direction: Vector3,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct StanceResult {
    pub posture: u8, // stand, crouch, prone, lean left, lean right
    pub can_aim: bool,
    pub face_threat: u8, // none, gradual, immediate
}

impl StanceInput {
    fn valid(self) -> bool {
        self.mode <= 2
            && self.move_mode <= 2
            && self.cover_kind <= 3
            && [
                self.time,
                self.cover_height,
                self.suppression,
                self.hit_dirt_timer,
                self.yaw,
            ]
            .into_iter()
            .all(scalar)
            && self.threat.is_finite()
            && self.lean_direction.is_finite()
    }
    /// Evaluate this before the cover cycle, whose shift event can change at_cover.
    pub fn cycles_cover(self) -> bool {
        self.mode == 0
            && !self.moving
            && self.at_cover
            && (self.cover_kind == 1 || self.cover_kind == 2)
            && !(self.cover_kind == 1 && self.cover_height <= 0.0 && !self.mounted)
    }
}

fn scalar(v: f64) -> bool {
    v.is_finite() && v.abs() <= 1e12
}

impl InfantryWeapon {
    /// The caller has applied any cover-cycle events, including a new cover height.
    pub fn stance(
        &mut self,
        input: StanceInput,
        cycled_cover: bool,
    ) -> Result<StanceResult, &'static str> {
        if !self.valid() || !input.valid() {
            return Err("invalid infantry stance");
        }
        let mut posture;
        let mut shoot;
        let mut face_threat = 0;
        if input.mode == 1 {
            posture = 0;
            shoot = true;
        } else if input.mode == 2 {
            let down = input.suppression >= 88.0;
            posture = if down {
                if input.bay {
                    1
                } else {
                    2
                }
            } else if input.bay {
                0
            } else {
                1
            };
            shoot = !down;
            self.peek_up = false;
            if !input.target_valid && !input.covering {
                face_threat = 1;
            }
        } else if input.moving {
            posture = if input.crawling {
                2
            } else if (input.near_cover && input.danger)
                || (input.move_mode == 0 && input.danger && input.suppression > 20.0)
            {
                1
            } else {
                0
            };
            shoot = input.move_mode == 0 && posture != 2 && !input.shifting;
            self.peek_up = false;
            self.blind = false;
        } else if cycled_cover {
            if input.cover_kind == 1 {
                posture = if input.cover_height <= 0.0 {
                    if self.peek_up {
                        0
                    } else {
                        1
                    }
                } else if input.cover_height < 0.62 {
                    2
                } else if input.cover_height < 1.12 {
                    if self.peek_up || input.cover_height >= 0.8 {
                        1
                    } else {
                        2
                    }
                } else if self.peek_up {
                    0
                } else {
                    1
                };
            } else if self.peek_up {
                face_threat = 2;
                let yaw = if input.threat.length_squared() > 0.0001 {
                    f64::from(
                        libm::atan2(-f64::from(input.threat.x), -f64::from(input.threat.z)) as f32,
                    )
                } else {
                    input.yaw
                };
                let right = Vector3::new(libm::cos(yaw) as f32, 0.0, -libm::sin(yaw) as f32);
                posture = if input.lean_direction.dot(right) > 0.0 {
                    4
                } else {
                    3
                };
            } else {
                posture = 0;
            }
            shoot = self.peek_up && (self.blind || input.time - self.peek_from > 0.35);
        } else if input.at_cover
            && input.cover_kind == 1
            && input.cover_height <= 0.0
            && !input.mounted
        {
            posture = if input.pinned { 2 } else { 1 };
            shoot = true;
            self.peek_up = false;
        } else if input.at_cover && input.cover_kind == 3 {
            posture = 1;
            shoot = true;
        } else {
            posture = if input.pinned {
                2
            } else if input.danger {
                if input.suppression > 35.0 {
                    2
                } else {
                    1
                }
            } else if input.sector {
                if input.machine_gunner {
                    2
                } else {
                    1
                }
            } else {
                0
            };
            shoot = !input.pinned || (input.time + (input.entity % 13) as f64 * 0.37) % 4.0 < 1.3;
        }
        if input.pinned && posture == 0 && input.mode == 0 {
            posture = 1;
        }
        if input.hit_dirt_timer > 0.0 && input.mode != 1 && !input.moving {
            posture = 2;
            shoot = false;
        }
        let can_aim = shoot
            && self.reload_timer <= 0.0
            && input.armed
            && (self.fire_timer <= 0.0 || input.crew_mount)
            && (input.suppression < 88.0 || input.mode == 1)
            && !(input.ambush && input.mode == 0 && !input.forced_target);
        Ok(StanceResult {
            posture,
            can_aim,
            face_threat,
        })
    }

    pub fn valid(&self) -> bool {
        [
            self.peek_timer,
            self.peek_from,
            self.up_suppression,
            self.reload_timer,
            self.fire_timer,
            self.last_shot,
        ]
        .into_iter()
        .all(scalar)
            && [self.burst_left, self.magazine, self.reserve]
                .into_iter()
                .all(|n| (0..=1_000_000).contains(&n))
    }

    fn reload(&mut self, weapon: Weapon, rng: &mut SimulationRandom) -> Option<u8> {
        if self.reserve <= 0 || self.reload_timer > 0.0 {
            return None;
        }
        self.reload_timer = weapon.reload_time;
        self.burst_left = 0;
        (f64::from(rng.randf()) < 0.3).then(|| (rng.randi() % 3) as u8)
    }

    pub fn advance_timers(&mut self, dt: f64, weapon: Weapon) -> Result<(), &'static str> {
        if !self.valid() || !dt.is_finite() || !(0.0..=10.0).contains(&dt) || !weapon.valid() {
            return Err("invalid infantry weapon timers");
        }
        let take = weapon.magazine.min(self.reserve);
        if self.reload_timer > 0.0 && self.reload_timer <= dt && self.magazine + take > 1_000_000 {
            return Err("infantry magazine exceeds limit");
        }
        self.fire_timer -= dt;
        if self.reload_timer > 0.0 {
            self.reload_timer -= dt;
            if self.reload_timer <= 0.0 {
                self.magazine += take;
                self.reserve -= take;
            }
        }
        Ok(())
    }

    /// Combat consumes randomness between this decision and finish_shot.
    pub fn prepare_shot(
        &mut self,
        input: ShotInput,
        rng: &mut SimulationRandom,
    ) -> Result<ShotResult, &'static str> {
        if !self.valid()
            || !input.weapon.valid()
            || !(1..=1_000_000).contains(&input.burst_min)
            || !(input.burst_min..=1_000_000).contains(&input.burst_max)
            || ![input.time, input.stamina, input.squad_accuracy]
                .into_iter()
                .all(scalar)
            || input.squad_accuracy < 0.0
        {
            return Err("invalid infantry shot");
        }
        let mut result = ShotResult::default();
        let infinite = input.weapon.ammunition >= 9000;
        if self.magazine <= 0 && !infinite {
            result.reload_speech = self.reload(input.weapon, rng);
            return Ok(result);
        }
        result.low_ammo = !infinite
            && self.magazine + self.reserve < (f64::from(input.weapon.ammunition) * 0.3) as i32;
        if self.burst_left <= 0 {
            self.burst_left = if result.low_ammo {
                1
            } else {
                rng.randi_range(input.burst_min, input.burst_max)
            };
            if result.low_ammo && !self.low_ammo_said {
                self.low_ammo_said = true;
                result.announce_low_ammo = true;
            }
        }
        if !infinite {
            self.magazine -= 1;
        }
        self.burst_left -= 1;
        self.last_shot = input.time;
        result.fired = true;
        result.accuracy = 1.0;
        if self.blind {
            result.accuracy *= 0.12;
        }
        if input.moving {
            result.accuracy *= 0.55;
        }
        if input.gun_override {
            result.accuracy *= 1.15;
        }
        result.accuracy *= input.squad_accuracy;
        if input.ambush {
            result.accuracy *= 1.3;
        }
        result.accuracy *= 0.75 + 0.25 * (input.stamina / 0.5).clamp(0.0, 1.0);
        Ok(result)
    }

    pub fn finish_shot(
        &mut self,
        weapon: Weapon,
        interval: f64,
        suppression: f64,
        low_ammo: bool,
        cover_fire: bool,
        rng: &mut SimulationRandom,
    ) -> Result<Option<u8>, &'static str> {
        if !self.valid()
            || !weapon.valid()
            || !scalar(suppression)
            || !interval.is_finite()
            || !(0.0..=3600.0).contains(&interval)
        {
            return Err("invalid infantry shot recovery");
        }
        if self.burst_left <= 0 {
            let suppression_factor = 1.0 + (suppression - 20.0).clamp(0.0, 80.0) / 40.0;
            self.fire_timer = f64::from(rng.randf_range(0.5, 1.2))
                * if low_ammo { 2.4 } else { 1.0 }
                * if cover_fire { 0.65 } else { 1.0 }
                * suppression_factor;
        } else {
            self.fire_timer = interval * f64::from(rng.randf_range(0.9, 1.25));
        }
        Ok(
            if self.magazine <= 0 && self.reserve > 0 && weapon.ammunition < 9000 {
                self.reload(weapon, rng)
            } else {
                None
            },
        )
    }

    pub fn cover_cycle(
        &mut self,
        input: CoverInput,
        rng: &mut SimulationRandom,
    ) -> Result<CoverResult, &'static str> {
        if !self.valid()
            || !input.dt.is_finite()
            || !(0.0..=10.0).contains(&input.dt)
            || ![
                input.time,
                input.suppression,
                input.last_suppression,
                input.hit_dirt_timer,
                input.ground,
                input.cover_height,
            ]
            .into_iter()
            .all(scalar)
            || input.cover_kind > 3
            || !(-1..=3).contains(&input.cover_material)
            || input.weapon.is_some_and(|w| !w.valid())
        {
            return Err("invalid infantry firing cycle");
        }
        let mut result = CoverResult::default();
        self.peek_timer -= input.dt;
        let calm = !input.want_fire
            && !input.pinned
            && input.suppression < 12.0
            && input.time - input.last_suppression > 4.0
            && self.reload_timer <= 0.0
            && input.hit_dirt_timer <= 0.0;
        if calm {
            if !self.peek_up {
                self.peek_up = true;
                self.peek_from = input.time;
                self.up_suppression = input.suppression;
            }
            self.blind = false;
            self.watching = true;
            return Ok(result);
        }
        if self.watching {
            self.watching = false;
            if input.want_fire && self.peek_up {
                self.peek_timer = f64::from(rng.randf_range(2.2, 4.0));
                self.peek_from = input.time - 0.4;
                self.up_suppression = input.suppression;
                self.stayed = false;
            } else {
                self.peek_up = false;
                self.peek_timer = f64::from(rng.randf_range(0.6, 1.4));
            }
            return Ok(result);
        }
        if self.peek_up {
            let drew =
                input.suppression - self.up_suppression > 28.0 && input.time - self.peek_from > 1.1;
            let mut done = self.peek_timer <= 0.0
                || self.reload_timer > 0.0
                || !input.want_fire
                || drew
                || input.suppression >= 88.0;
            if done
                && self.peek_timer <= 0.0
                && !drew
                && !input.pinned
                && input.want_fire
                && self.reload_timer <= 0.0
                && !self.stayed
                && !input.buddy_up
            {
                self.stayed = true;
                self.peek_timer = f64::from(rng.randf_range(0.8, 1.6));
                done = false;
            }
            if done {
                result.drew_fire = drew;
                self.peek_up = false;
                self.blind = false;
                self.peek_timer = f64::from(rng.randf_range(0.6, 1.4))
                    * if input.suppression > 30.0 { 1.8 } else { 1.0 }
                    * if drew { 2.2 } else { 1.0 };
                if let Some(weapon) = input.weapon.filter(|w| {
                    w.ammunition < 9000
                        && f64::from(self.magazine) < f64::from(w.magazine) * 0.5
                        && self.reserve > 0
                }) {
                    result.reload_speech = self.reload(weapon, rng);
                    result.call_cover = true;
                } else if drew || input.cover_kind == 1 && f64::from(rng.randf()) < 0.2 {
                    result.shift_along = true;
                }
            }
            return Ok(result);
        }
        if self.peek_timer > 0.0 || self.reload_timer > 0.0 || !input.want_fire {
            return Ok(result);
        }
        if input.pinned {
            if input.team == 1
                && input.cover_kind == 1
                && input.cover_height >= 0.62
                && input.target_valid
                && f64::from(rng.randf()) < 0.4
            {
                self.blind = true;
                self.peek_up = true;
                self.peek_timer = f64::from(rng.randf_range(1.0, 2.0));
                result.blind_fire = true;
            } else if f64::from(rng.randf())
                < 0.22
                    + if input.cover_material >= 2 { 0.15 } else { 0.0 }
                    + if input.ground < -0.6 { 0.1 } else { 0.0 }
            {
                self.peek_up = true;
                self.peek_timer = f64::from(rng.randf_range(0.9, 1.6));
            } else {
                self.peek_timer = f64::from(rng.randf_range(0.5, 1.1));
                return Ok(result);
            }
        } else {
            self.peek_up = true;
            self.peek_timer = f64::from(rng.randf_range(2.2, 4.0));
        }
        self.peek_from = input.time;
        self.up_suppression = input.suppression;
        self.stayed = false;
        result.peeked = true;
        Ok(result)
    }

    pub fn checkpoint(&self) -> Vec<u8> {
        let mut out = Writer::new(b"FLIW\x01\0\0\0");
        for v in [
            self.peek_timer,
            self.peek_from,
            self.up_suppression,
            self.reload_timer,
        ] {
            out.f64(v);
        }
        for v in [self.peek_up, self.stayed, self.watching, self.blind] {
            out.byte(u8::from(v));
        }
        for v in [self.burst_left, self.magazine, self.reserve] {
            out.u32(v as u32);
        }
        out.f64(self.fire_timer);
        out.f64(self.last_shot);
        out.byte(u8::from(self.low_ammo_said));
        out.0
    }

    pub fn restore(bytes: &[u8]) -> Result<Self, &'static str> {
        let mut input = Reader::new(bytes, b"FLIW\x01\0\0\0")?;
        let value = Self {
            peek_timer: input.f64()?,
            peek_from: input.f64()?,
            up_suppression: input.f64()?,
            reload_timer: input.f64()?,
            peek_up: input.boolean()?,
            stayed: input.boolean()?,
            watching: input.boolean()?,
            blind: input.boolean()?,
            burst_left: input.u32()? as i32,
            magazine: input.u32()? as i32,
            reserve: input.u32()? as i32,
            fire_timer: input.f64()?,
            last_shot: input.f64()?,
            low_ammo_said: input.boolean()?,
        };
        input.finish()?;
        if !value.valid() {
            return Err("invalid infantry weapon checkpoint");
        }
        Ok(value)
    }
}
