use godot::prelude::*;

#[derive(GodotClass)]
#[class(base=RefCounted, init)]
struct SimulationRandomCore {
    base: Base<RefCounted>,
    core: frontline_core::random::SimulationRandom,
}

#[godot_api]
impl SimulationRandomCore {
    #[func]
    fn set_seed(&mut self, seed: i64) {
        self.core = frontline_core::random::SimulationRandom::new(seed as u64);
    }

    #[func]
    fn get_seed(&self) -> i64 {
        self.core.seed() as i64
    }

    #[func]
    fn set_state(&mut self, state: i64) {
        self.core.set_state(state as u64);
    }

    #[func]
    fn get_state(&self) -> i64 {
        self.core.state() as i64
    }

    #[func]
    fn randi(&mut self) -> i64 {
        i64::from(self.core.randi())
    }

    #[func]
    fn randf(&mut self) -> f64 {
        f64::from(self.core.randf())
    }

    #[func]
    fn randf_range(&mut self, from: f64, to: f64) -> f64 {
        f64::from(self.core.randf_range(from as f32, to as f32))
    }

    #[func]
    fn randi_range(&mut self, from: i32, to: i32) -> i32 {
        self.core.randi_range(from, to)
    }
}
