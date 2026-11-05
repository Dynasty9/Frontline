//! Immutable geology, shared by ground contact, traversal and construction.
use crate::cover::{rotation, transform};
use crate::vector::Vector3;
use glam::Vec2;

pub const STEP: usize = 4;

#[derive(Clone, Debug, PartialEq)]
pub struct Landform {
    side: usize,
    samples: Vec<f32>,
    peak: f64,
    slopes: Vec<f32>,
    vehicle_slopes: Vec<f32>,
}

impl Landform {
    pub fn new(side: usize, samples: Vec<f32>) -> Option<Self> {
        let width = side / STEP + 1;
        if !(2..=3072).contains(&side)
            || (!samples.is_empty() && (width < 2 || samples.len() != width * width))
            || samples
                .iter()
                .any(|h| !h.is_finite() || !(0.0..=512.0).contains(h))
        {
            return None;
        }
        let mut result = Self {
            side,
            peak: samples.iter().copied().fold(0.0_f32, f32::max) as f64,
            samples,
            slopes: Vec::new(),
            vehicle_slopes: Vec::new(),
        };
        if result.is_empty() {
            return Some(result);
        }
        result.slopes.reserve(side * side);
        let half = side as f32 * 0.5;
        for z in 0..side {
            for x in 0..side {
                result.slopes.push(result.slope(Vector3::new(
                    x as f32 + 0.5 - half,
                    0.,
                    z as f32 + 0.5 - half,
                )) as f32);
            }
        }
        // A turning hull must fit the steepest part of its eight-metre envelope.
        let mut horizontal = vec![0.0_f32; side * side];
        for z in 0..side {
            for x in 0..side {
                for xx in x.saturating_sub(4)..(x + 5).min(side) {
                    horizontal[z * side + x] =
                        horizontal[z * side + x].max(result.slopes[z * side + xx]);
                }
            }
        }
        result.vehicle_slopes.resize(side * side, 0.);
        for z in 0..side {
            for x in 0..side {
                for zz in z.saturating_sub(4)..(z + 5).min(side) {
                    result.vehicle_slopes[z * side + x] =
                        result.vehicle_slopes[z * side + x].max(horizontal[zz * side + x]);
                }
            }
        }
        Some(result)
    }

    pub fn is_empty(&self) -> bool {
        self.samples.is_empty()
    }
    pub fn samples(&self) -> &[f32] {
        &self.samples
    }
    pub fn peak(&self) -> f64 {
        self.peak
    }
    pub fn cell_slope(&self, index: usize) -> f64 {
        self.slopes.get(index).copied().unwrap_or(0.) as f64
    }
    pub fn vehicle_slope(&self, index: usize) -> f64 {
        self.vehicle_slopes.get(index).copied().unwrap_or(0.) as f64
    }

    pub fn height(&self, p: Vector3) -> f64 {
        if self.is_empty() {
            return 0.;
        }
        let n = self.side / STEP + 1;
        let half = self.side as f64 * 0.5;
        let fx = ((f64::from(p.x) + half) / STEP as f64).clamp(0., (n - 1) as f64);
        let fz = ((f64::from(p.z) + half) / STEP as f64).clamp(0., (n - 1) as f64);
        let x = (fx as usize).min(n - 2);
        let z = (fz as usize).min(n - 2);
        let i = z * n + x;
        let lerp = |a: f64, b: f64, t: f64| a + (b - a) * t;
        let a = lerp(
            self.samples[i] as f64,
            self.samples[i + 1] as f64,
            fx - x as f64,
        );
        let b = lerp(
            self.samples[i + n] as f64,
            self.samples[i + n + 1] as f64,
            fx - x as f64,
        );
        lerp(a, b, fz - z as f64)
    }

    pub fn slope(&self, p: Vector3) -> f64 {
        f64::from(
            Vec2::new(
                (self.height(p + Vector3::X * 2.) - self.height(p - Vector3::X * 2.)) as f32,
                (self.height(p + Vector3::Z * 2.) - self.height(p - Vector3::Z * 2.)) as f32,
            )
            .length(),
        ) * 0.25
    }

    pub fn fits(&self, p: Vector3, footprint: Vec2, yaw: f64, tolerance: f64) -> bool {
        if !p.is_finite()
            || !footprint.is_finite()
            || footprint.min_element() < 0.
            || !yaw.is_finite()
            || !tolerance.is_finite()
            || tolerance < 0.
        {
            return false;
        }
        let basis = rotation(yaw);
        let height = self.height(p);
        for z in [-1., 0., 1.] {
            for x in [-1., 0., 1.] {
                if (self.height(
                    p + transform(basis, Vector3::new(x * footprint.x, 0., z * footprint.y)),
                ) - height)
                    .abs()
                    > tolerance
                {
                    return false;
                }
            }
        }
        true
    }
}
