//! Versioned gameplay randomness, compatible with Godot 4.7's standard build.
//! PCG XSH-RR 64/32; the stream and float mapping are part of the replay rules.

const MULTIPLIER: u64 = 6364136223846793005;
const STREAM: u64 = (1442695040888963407u64 << 1) | 1;
pub const RANDOM_VERSION: u32 = 1;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct SimulationRandom {
    seed: u64,
    state: u64,
}

impl Default for SimulationRandom {
    fn default() -> Self {
        Self::new(1)
    }
}

impl SimulationRandom {
    pub fn new(seed: u64) -> Self {
        let mut rng = Self { seed, state: 0 };
        rng.randi();
        rng.state = rng.state.wrapping_add(seed);
        rng.randi();
        rng
    }

    pub fn seed(&self) -> u64 {
        self.seed
    }

    pub fn state(&self) -> u64 {
        self.state
    }

    pub fn set_state(&mut self, state: u64) {
        self.state = state;
    }

    pub fn randi(&mut self) -> u32 {
        let previous = self.state;
        self.state = previous.wrapping_mul(MULTIPLIER).wrapping_add(STREAM);
        let mixed = (((previous >> 18) ^ previous) >> 27) as u32;
        mixed.rotate_right((previous >> 59) as u32)
    }

    pub fn randf(&mut self) -> f32 {
        let exponent = self.randi();
        if exponent == 0 {
            return 0.0;
        }
        let significand = (self.randi() | 0x80000001) as f32;
        // An exact power of two avoids a platform libm dependency.
        let scale = f32::from_bits((127 - 32 - exponent.leading_zeros()) << 23);
        significand * scale
    }

    pub fn randf_range(&mut self, from: f32, to: f32) -> f32 {
        self.randf() * (to - from) + from
    }

    pub fn randi_range(&mut self, from: i32, to: i32) -> i32 {
        if from == to {
            return from;
        }
        let low = i64::from(from.min(to));
        let width = (i64::from(from.max(to)) - low + 1) as u64;
        if width == 1u64 << 32 {
            return (i64::from(self.randi()) + low) as i32;
        }
        let bound = width as u32;
        let threshold = bound.wrapping_neg() % bound;
        loop {
            let value = self.randi();
            if value >= threshold {
                return (i64::from(value % bound) + low) as i32;
            }
        }
    }
}
