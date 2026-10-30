//! Infantry health, suppression and fatigue; squad and task effects remain ordered by the actor.
use crate::random::SimulationRandom;
use crate::state_codec::{Reader, Writer};

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
#[repr(u8)]
pub enum Life {
    #[default]
    Alive,
    Downed,
    Dead,
    Surrender,
    Captive,
    Hidden,
}

impl TryFrom<u8> for Life {
    type Error = &'static str;
    fn try_from(value: u8) -> Result<Self, Self::Error> {
        match value {
            0 => Ok(Self::Alive),
            1 => Ok(Self::Downed),
            2 => Ok(Self::Dead),
            3 => Ok(Self::Surrender),
            4 => Ok(Self::Captive),
            5 => Ok(Self::Hidden),
            _ => Err("invalid infantry life"),
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct InfantryVitals {
    pub life: Life,
    pub times_downed: u32,
    pub hp: f64,
    pub max_hp: f64,
    pub base_hp: f64,
    pub suppression: f64,
    pub last_suppression: f64,
    pub reveal_until: f64,
    pub bleed: f64,
    pub bleed_max: f64,
    pub stamina: f64,
    pub speech_cooldown: f64,
    pub hit_dirt_timer: f64,
    pub downed_at: f64,
    pub dead_at: f64,
    pub scream_timer: f64,
    pub pistol_timer: f64,
    pub crawl_timer: f64,
}

impl Default for InfantryVitals {
    fn default() -> Self {
        Self {
            life: Life::Alive,
            times_downed: 0,
            hp: 100.0,
            max_hp: 100.0,
            base_hp: 100.0,
            suppression: 0.0,
            last_suppression: 0.0,
            reveal_until: 0.0,
            bleed: 0.0,
            bleed_max: 45.0,
            stamina: 1.0,
            speech_cooldown: 0.0,
            hit_dirt_timer: 0.0,
            downed_at: 0.0,
            dead_at: 0.0,
            scream_timer: 0.0,
            pistol_timer: 0.0,
            crawl_timer: 0.0,
        }
    }
}

#[derive(Clone, Copy, Debug, Default)]
pub struct Protection {
    pub at_cover: bool,
    pub cover_kind: u8,
    pub material: Option<u8>,
    pub peek_up: bool,
    pub protected_mount: bool,
    pub in_trench: bool,
}

impl Protection {
    fn valid(self) -> bool {
        self.cover_kind <= 3 && self.material.is_none_or(|m| m < 4)
    }
}

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct SuppressionResult {
    pub report_position: bool,
    pub speech: Option<u8>,
}

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub enum DamageResult {
    #[default]
    Ignored,
    Survived(Option<u8>),
    Down,
    Die,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct CorpseStep {
    pub height: f32,
    pub carried: bool,
    pub clear_carriers: bool,
    pub despawn: bool,
}

#[derive(Clone, Copy, Debug, Default)]
pub struct FatigueInput {
    pub moving_or_diving: bool,
    pub move_mode: i32,
    pub crawling: bool,
    pub heavy_task: bool, // rescue, stretcher or smother
    pub carrying: bool,   // stretcher, dragging or carrying at a halt
    pub standing: bool,
}

const SUPPRESSION: [f64; 4] = [0.85, 0.62, 0.4, 0.35];
const SUPPRESSION_CAP: [f64; 4] = [100.0, 86.0, 68.0, 62.0];
fn scalar(value: f64) -> bool {
    value.is_finite() && value.abs() <= 1e12
}
fn step(dt: f64) -> bool {
    dt.is_finite() && (0.0..=10.0).contains(&dt)
}

impl InfantryVitals {
    pub fn valid(self) -> bool {
        self.times_downed <= 1_000_000
            && [
                self.hp,
                self.max_hp,
                self.base_hp,
                self.suppression,
                self.last_suppression,
                self.reveal_until,
                self.bleed,
                self.bleed_max,
                self.stamina,
                self.speech_cooldown,
                self.hit_dirt_timer,
                self.downed_at,
                self.dead_at,
                self.scream_timer,
                self.pistol_timer,
                self.crawl_timer,
            ]
            .into_iter()
            .all(scalar)
            && self.max_hp >= 0.0
            && self.base_hp >= 0.0
            && self.bleed_max >= 0.0
            && (0.0..=1.0).contains(&self.stamina)
    }

    pub fn recover(
        &mut self,
        dt: f64,
        time: f64,
        protection: Protection,
    ) -> Result<(), &'static str> {
        if !self.valid()
            || !step(dt)
            || !scalar(time)
            || !protection.valid()
            || !scalar(self.speech_cooldown - dt)
        {
            return Err("invalid infantry recovery");
        }
        if self.suppression > 0.0 && time - self.last_suppression > 1.4 {
            let mut rate = if self.suppression > 50.0 { 8.0 } else { 13.0 };
            if protection.at_cover && protection.cover_kind != 0 {
                rate *= 1.15;
            }
            self.suppression = (self.suppression - dt * rate).max(0.0);
        }
        if protection.at_cover && !protection.peek_up {
            if let Some(material) = protection.material {
                let cap = SUPPRESSION_CAP[usize::from(material)];
                if self.suppression > cap {
                    self.suppression = (self.suppression - dt * 16.0).max(cap);
                }
            }
        }
        self.speech_cooldown -= dt;
        if self.hit_dirt_timer > 0.0 {
            self.hit_dirt_timer -= dt;
        }
        Ok(())
    }

    pub fn fatigue(&mut self, dt: f64, input: FatigueInput) -> Result<(), &'static str> {
        if !self.valid() || !step(dt) {
            return Err("invalid infantry fatigue");
        }
        let mut drain = 0.0;
        if input.moving_or_diving {
            drain = [0.0, 0.022, 0.045][input.move_mode.clamp(0, 2) as usize];
            if input.crawling {
                drain = 0.012;
            }
            if input.heavy_task {
                drain += 0.025;
            }
        } else if input.carrying {
            drain = 0.025;
        }
        if drain > 0.0 {
            self.stamina = (self.stamina - drain * dt).max(0.0);
        } else {
            self.stamina = (self.stamina + if input.standing { 0.045 } else { 0.06 } * dt).min(1.0);
        }
        Ok(())
    }

    pub fn suppress(
        &mut self,
        amount: f64,
        time: f64,
        retreating: bool,
        has_squad: bool,
        protection: Protection,
        rng: &mut SimulationRandom,
    ) -> Result<SuppressionResult, &'static str> {
        if !self.valid()
            || !scalar(amount)
            || amount < 0.0
            || !scalar(time)
            || !protection.valid()
            || (has_squad && time > self.reveal_until && !scalar(time + 1.0))
        {
            return Err("invalid infantry suppression");
        }
        let mut result = SuppressionResult::default();
        if self.life != Life::Alive {
            return Ok(result);
        }
        let amount = amount * if retreating { 0.5 } else { 1.0 };
        let mut multiplier = 1.0;
        let mut cap: f64 = 100.0;
        if protection.protected_mount {
            multiplier = 0.5;
        } else if protection.at_cover && protection.cover_kind != 0 {
            multiplier = protection
                .material
                .map_or(0.62, |m| SUPPRESSION[usize::from(m)]);
            if !protection.peek_up {
                if let Some(material) = protection.material {
                    cap = SUPPRESSION_CAP[usize::from(material)];
                }
            }
        }
        if protection.in_trench {
            multiplier *= 0.5;
        }
        self.suppression = cap
            .max(self.suppression)
            .min(self.suppression + amount * multiplier);
        self.last_suppression = time;
        if has_squad && time > self.reveal_until {
            self.reveal_until = time + 1.0;
            result.report_position = true;
        }
        if self.suppression >= 60.0 && f64::from(rng.randf()) < 0.05 {
            result.speech = Some((rng.randi() % 4) as u8);
        }
        Ok(result)
    }

    /// The actor applies Down/Die after recording hit statistics and notifying squads.
    pub fn damage(
        &mut self,
        amount: f64,
        explosion: bool,
        bearer: bool,
        rng: &mut SimulationRandom,
    ) -> Result<DamageResult, &'static str> {
        if !self.valid() || !scalar(amount) || amount < 0.0 {
            return Err("invalid infantry damage");
        }
        if self.life == Life::Dead || self.life == Life::Hidden {
            return Ok(DamageResult::Ignored);
        }
        if self.life == Life::Downed {
            if !scalar(self.bleed - amount * 0.3) {
                return Err("infantry bleeding exceeds limit");
            }
            self.bleed -= amount * 0.3;
            return Ok(
                if (explosion && amount > 45.0)
                    || self.bleed <= 0.0
                    || f64::from(rng.randf()) < amount / 300.0
                {
                    DamageResult::Die
                } else {
                    DamageResult::Survived(None)
                },
            );
        }
        if !scalar(self.hp - amount) {
            return Err("infantry damage exceeds limit");
        }
        self.hp -= amount;
        self.suppression = (self.suppression + 22.0).min(100.0);
        if self.hp <= 0.0 {
            if self.life == Life::Surrender
                || self.life == Life::Captive
                || (bearer && f64::from(rng.randf()) < 0.3)
            {
                return Ok(DamageResult::Die);
            }
            let probability = if self.times_downed >= 3 {
                1.0
            } else {
                0.14 + -self.hp / 150.0 + if explosion { 0.25 } else { 0.0 }
            };
            Ok(if f64::from(rng.randf()) < probability {
                DamageResult::Die
            } else {
                DamageResult::Down
            })
        } else {
            Ok(DamageResult::Survived(
                (f64::from(rng.randf()) < 0.3).then(|| (rng.randi() % 4) as u8),
            ))
        }
    }

    pub fn go_down(&mut self, time: f64) -> Result<(), &'static str> {
        if !self.valid() || !scalar(time) {
            return Err("invalid infantry downing");
        }
        self.life = Life::Downed;
        self.hp = 0.0;
        self.bleed_max = [50.0, 38.0, 26.0, 16.0][self.times_downed.min(3) as usize];
        self.bleed = self.bleed_max;
        self.scream_timer = 0.4;
        self.pistol_timer = 2.5;
        self.crawl_timer = 1.5;
        self.downed_at = time;
        Ok(())
    }

    pub fn bleed_step(
        &mut self,
        dt: f64,
        rescued: bool,
        medicine: bool,
    ) -> Result<bool, &'static str> {
        if !self.valid() || !step(dt) {
            return Err("invalid infantry bleeding step");
        }
        let rate = if rescued { 0.35 } else { 1.0 } * if medicine { 0.67 } else { 1.0 };
        let bleed = self.bleed - dt * rate;
        if !scalar(bleed) {
            return Err("infantry bleeding exceeds limit");
        }
        self.bleed = bleed;
        Ok(self.bleed <= 0.0)
    }

    // These stages straddle speech, pistol fire and movement; their effects may consume RNG.
    pub fn scream_step(
        &mut self,
        dt: f64,
        rng: &mut SimulationRandom,
    ) -> Result<bool, &'static str> {
        if !self.valid() || !step(dt) || !scalar(self.scream_timer - dt) {
            return Err("invalid wounded infantry speech step");
        }
        self.scream_timer -= dt;
        let speak = self.scream_timer <= 0.0;
        if speak {
            self.scream_timer = f64::from(rng.randf_range(4.0, 8.0));
        }
        Ok(speak)
    }

    pub fn pistol_step(
        &mut self,
        dt: f64,
        rng: &mut SimulationRandom,
    ) -> Result<bool, &'static str> {
        if !self.valid() || !step(dt) || !scalar(self.pistol_timer - dt) {
            return Err("invalid wounded infantry pistol step");
        }
        self.pistol_timer -= dt;
        let fire = self.pistol_timer <= 0.0;
        if fire {
            self.pistol_timer = f64::from(rng.randf_range(0.9, 1.7));
        }
        Ok(fire)
    }

    pub fn crawl_step(&mut self, dt: f64) -> Result<bool, &'static str> {
        if !self.valid() || !step(dt) || !scalar(self.crawl_timer - dt) {
            return Err("invalid wounded infantry crawl step");
        }
        self.crawl_timer -= dt;
        if self.crawl_timer <= 0.0 {
            self.crawl_timer = 3.0;
            return Ok(self.bleed > self.bleed_max * 0.5);
        }
        Ok(false)
    }

    pub fn corpse_step(
        self,
        height: f32,
        ground: f64,
        time: f64,
        carried: bool,
        carrier_alive: bool,
        stretcher_claimed: bool,
    ) -> Result<CorpseStep, &'static str> {
        if !self.valid()
            || !height.is_finite()
            || height.abs() > 1_000_000.0
            || !ground.is_finite()
            || ground.abs() > 1_000_000.0
            || !scalar(time)
        {
            return Err("invalid infantry corpse step");
        }
        let height = if carried {
            height
        } else {
            (f64::from(height) + (ground - f64::from(height)) * 0.2) as f32
        };
        Ok(CorpseStep {
            height,
            carried: carried && carrier_alive,
            clear_carriers: carried && !carrier_alive,
            despawn: !carried && !stretcher_claimed && time - self.dead_at > 300.0,
        })
    }

    pub fn die(&mut self, time: f64) -> Result<(), &'static str> {
        if !self.valid() || !scalar(time) {
            return Err("invalid infantry death");
        }
        if self.life != Life::Dead {
            self.life = Life::Dead;
            self.hp = 0.0;
            self.dead_at = time;
        }
        Ok(())
    }

    pub fn revive(&mut self, full: bool) -> Result<(), &'static str> {
        if !self.valid() || self.times_downed >= 1_000_000 {
            return Err("invalid infantry revival");
        }
        self.times_downed += 1;
        self.life = Life::Alive;
        self.max_hp =
            self.base_hp * [1.0, 0.8, 0.62, 0.45, 0.35][self.times_downed.min(4) as usize];
        self.hp = self.max_hp * if full { 1.0 } else { 0.85 };
        self.suppression = 25.0;
        Ok(())
    }

    pub fn checkpoint(self) -> Vec<u8> {
        let mut out = Writer::new(b"FLIV\x01\0\0\0");
        out.byte(self.life as u8);
        out.u32(self.times_downed);
        for value in [
            self.hp,
            self.max_hp,
            self.base_hp,
            self.suppression,
            self.last_suppression,
            self.reveal_until,
            self.bleed,
            self.bleed_max,
            self.stamina,
            self.speech_cooldown,
            self.hit_dirt_timer,
            self.downed_at,
            self.dead_at,
            self.scream_timer,
            self.pistol_timer,
            self.crawl_timer,
        ] {
            out.f64(value);
        }
        out.0
    }

    pub fn restore(bytes: &[u8]) -> Result<Self, &'static str> {
        let mut input = Reader::new(bytes, b"FLIV\x01\0\0\0")?;
        let state = Self {
            life: Life::try_from(input.byte()?)?,
            times_downed: input.u32()?,
            hp: input.f64()?,
            max_hp: input.f64()?,
            base_hp: input.f64()?,
            suppression: input.f64()?,
            last_suppression: input.f64()?,
            reveal_until: input.f64()?,
            bleed: input.f64()?,
            bleed_max: input.f64()?,
            stamina: input.f64()?,
            speech_cooldown: input.f64()?,
            hit_dirt_timer: input.f64()?,
            downed_at: input.f64()?,
            dead_at: input.f64()?,
            scream_timer: input.f64()?,
            pistol_timer: input.f64()?,
            crawl_timer: input.f64()?,
        };
        input.finish()?;
        if !state.valid() {
            return Err("invalid infantry vitals checkpoint");
        }
        Ok(state)
    }
}
