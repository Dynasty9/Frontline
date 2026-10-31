// Pinned glam/libm arithmetic without platform fast-math; checkpoint goldens guard the contract.
pub use glam::Vec3 as Vector3;

pub(crate) fn turn_yaw(
    yaw: f64,
    direction: Vector3,
    position: Vector3,
    dt: f64,
    rate: f64,
    mount: Option<(Vector3, f64)>,
) -> f64 {
    use std::f64::consts::{PI, TAU};
    if f64::from(direction.length_squared()) < 0.0001 {
        return yaw;
    }
    let target = libm::atan2(-f64::from(direction.x), -f64::from(direction.z));
    let yaw = if let Some((_, speed)) = mount.filter(|(p, _)| {
        let delta = position - *p;
        f64::from(Vector3::new(delta.x, 0.0, delta.z).length()) < 0.8
    }) {
        let difference = target - yaw;
        let wrapped = difference - TAU * ((difference + PI) / TAU).floor();
        yaw + wrapped.clamp(-speed * dt, speed * dt)
    } else {
        let difference = (target - yaw) % TAU;
        let distance = (2.0 * difference) % TAU - difference;
        yaw + distance * (1.0 - libm::exp(-dt * rate))
    };
    f64::from(yaw as f32)
}

pub fn normalized(value: Vector3) -> Vector3 {
    let length = value.length();
    if length == 0.0 || !length.is_finite() {
        return Vector3::ZERO;
    }
    Vector3::new(value.x / length, value.y / length, value.z / length)
}

// Godot 4.7's collinear fallback and angle convention (see GODOT-LICENSE.txt).
pub fn slerp(from: Vector3, to: Vector3, weight: f32) -> Vector3 {
    let start_squared = from.length_squared();
    let end_squared = to.length_squared();
    let mut axis = from.cross(to);
    let axis_squared = axis.length_squared();
    if start_squared == 0.0 || end_squared == 0.0 || axis_squared == 0.0 {
        return from + (to - from) * weight;
    }
    let axis_length = libm::sqrtf(axis_squared);
    axis = Vector3::new(
        axis.x / axis_length,
        axis.y / axis_length,
        axis.z / axis_length,
    );
    let start = libm::sqrtf(start_squared);
    let length = start + (libm::sqrtf(end_squared) - start) * weight;
    let angle = libm::atan2f(from.cross(to).length(), from.dot(to));
    let angle = angle * weight;
    let cosine = libm::cosf(angle);
    let sine = libm::sinf(angle);
    let squared = axis * axis;
    let t = 1.0 - cosine;
    let xy = axis.x * axis.y * t;
    let xz = axis.x * axis.z * t;
    let yz = axis.y * axis.z * t;
    let row0 = Vector3::new(
        squared.x + cosine * (1.0 - squared.x),
        xy - axis.z * sine,
        xz + axis.y * sine,
    );
    let row1 = Vector3::new(
        xy + axis.z * sine,
        squared.y + cosine * (1.0 - squared.y),
        yz - axis.x * sine,
    );
    let row2 = Vector3::new(
        xz - axis.y * sine,
        yz + axis.x * sine,
        squared.z + cosine * (1.0 - squared.z),
    );
    Vector3::new(row0.dot(from), row1.dot(from), row2.dot(from)) * (length / start)
}
