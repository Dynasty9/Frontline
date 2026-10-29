use frontline_core::projectile::{Flight, Hit, Holder, Kind, Outcome};
use godot::prelude::*;

#[derive(GodotClass)]
#[class(base=RefCounted, init)]
struct ProjectileFlightCore {
    base: Base<RefCounted>,
    flight: Option<Flight>,
}

#[godot_api]
impl ProjectileFlightCore {
    #[func]
    fn advance_shell(&mut self, dt: f64) -> Vector4 {
        let Some(flight) = self.flight.as_mut() else {
            return Vector4::new(0.0, 0.0, 0.0, -1.0);
        };
        if !dt.is_finite()
            || dt < 0.0
            || matches!(
                flight.kind,
                Kind::Frag | Kind::Smoke | Kind::Rocket | Kind::Recoilless | Kind::Bomb
            )
        {
            return Vector4::new(0.0, 0.0, 0.0, -1.0);
        }
        let outcome = flight.advance(dt, Holder::Free, None);
        let p = flight.position;
        Vector4::new(
            p.x,
            p.y,
            p.z,
            if matches!(outcome, Outcome::Impact(_)) {
                1.0
            } else {
                0.0
            },
        )
    }

    #[func]
    fn checkpoint(&self) -> PackedByteArray {
        self.flight.map_or_else(PackedByteArray::new, |flight| {
            PackedByteArray::from(flight.checkpoint().as_slice())
        })
    }

    #[func]
    fn restore(&mut self, bytes: PackedByteArray) -> bool {
        match Flight::restore(bytes.as_slice()) {
            Ok(flight) => {
                self.flight = Some(flight);
                true
            }
            Err(_) => false,
        }
    }

    #[func]
    fn reset(&mut self, kind: GString, state: PackedFloat64Array) -> bool {
        let Some(kind) = Kind::parse(&kind.to_string()) else {
            return false;
        };
        let s = state.as_slice();
        if s.len() != 18
            || !s.iter().all(|v| v.is_finite())
            || !s[..12].iter().all(|v| (*v as f32).is_finite())
        {
            return false;
        }
        let point = |i: usize| {
            frontline_core::vector::Vector3::new(s[i] as f32, s[i + 1] as f32, s[i + 2] as f32)
        };
        let flight = Flight {
            kind,
            position: point(0),
            velocity: point(3),
            origin: point(6),
            target: point(9),
            fuse: s[12],
            flying: s[13] != 0.0,
            life: s[14],
            smoke_time: s[15],
            smoke_radius: s[16],
            shell_duration: s[17],
        };
        self.flight = Some(flight);
        true
    }

    #[func]
    fn advance(
        &mut self,
        dt: f64,
        holder: i32,
        held_position: Vector3,
        collision: PackedVector3Array,
    ) -> PackedFloat64Array {
        if !dt.is_finite()
            || dt < 0.0
            || !(0..=2).contains(&holder)
            || !held_position.is_finite()
            || ![0, 2].contains(&collision.len())
            || !collision.as_slice().iter().all(|p| p.is_finite())
        {
            return PackedFloat64Array::new();
        }
        let Some(flight) = self.flight.as_mut() else {
            return PackedFloat64Array::new();
        };
        let held = match holder {
            1 => Holder::Alive(crate::point(held_position)),
            2 => Holder::Dropped,
            _ => Holder::Free,
        };
        let hit = if collision.is_empty() {
            None
        } else {
            Some(Hit {
                position: crate::point(collision[0]),
                normal: crate::point(collision[1]),
            })
        };
        let outcome = flight.advance(dt, held, hit);
        observation(flight, outcome)
    }

    #[func]
    fn advance_in_world(
        &mut self,
        dt: f64,
        holder: i32,
        held_position: Vector3,
        mut collision: Gd<crate::collision_index::CollisionIndexCore>,
        excluded: PackedInt64Array,
    ) -> PackedFloat64Array {
        if !dt.is_finite() || dt < 0.0 || !(0..=2).contains(&holder) || !held_position.is_finite() {
            return PackedFloat64Array::new();
        }
        let Some(flight) = self.flight.as_mut() else {
            return PackedFloat64Array::new();
        };
        let held = match holder {
            1 => Holder::Alive(crate::point(held_position)),
            2 => Holder::Dropped,
            _ => Holder::Free,
        };
        let outcome = flight.advance_in_world(
            dt,
            held,
            &mut collision.bind_mut().core,
            excluded.as_slice(),
        );
        observation(flight, outcome)
    }
}

fn observation(flight: &Flight, outcome: Outcome) -> PackedFloat64Array {
    let (code, impact) = match outcome {
        Outcome::Flying => (0.0, frontline_core::vector::Vector3::ZERO),
        Outcome::Impact(at) => (1.0, at),
        Outcome::Expired => (2.0, frontline_core::vector::Vector3::ZERO),
    };
    let p = flight.position;
    let v = flight.velocity;
    PackedFloat64Array::from(&[
        p.x as f64,
        p.y as f64,
        p.z as f64,
        v.x as f64,
        v.y as f64,
        v.z as f64,
        flight.fuse,
        if flight.flying { 1.0 } else { 0.0 },
        flight.life,
        flight.smoke_time,
        flight.smoke_radius,
        code,
        impact.x as f64,
        impact.y as f64,
        impact.z as f64,
    ])
}
