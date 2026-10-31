//! An FPV drone keeps its operator and target with the flight state.
use crate::collision::CollisionWorld;
use crate::drone::{DroneFlight, Phase};
use crate::projectile_actor::Explosion;
use crate::state_codec::{Reader, Writer};
use crate::vector::Vector3;

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Drone {
    pub id: u32,
    pub team: i8,
    pub operator: u32,
    pub target: u32,
    pub operator_at_spawn: u32,
    pub target_at_spawn: u32,
    pub warhead: f64,
    pub flight: DroneFlight,
}

fn point(p: Vector3) -> bool {
    p.is_finite() && p.abs().max_element() <= 1_000_000.0
}

impl Drone {
    pub fn valid(&self) -> bool {
        self.id != 0
            && (-1..=1).contains(&self.team)
            && self.warhead.is_finite()
            && (0.0..=1000.0).contains(&self.warhead)
            && [
                self.flight.position,
                self.flight.velocity,
                self.flight.target,
            ]
            .into_iter()
            .all(point)
            && self.flight.life.is_finite()
            && self.flight.life.abs() <= 1e12
            && self.flight.yaw.is_finite()
            && self.flight.yaw.abs() <= 1e12
    }

    pub fn lose_control(&mut self) {
        // Repeated loss leaves an already falling drone unchanged, as in the original actor.
        if self.flight.phase != Phase::Uncontrolled {
            self.operator = 0;
            self.flight.lose_control();
        }
    }

    fn explosion(&self) -> Explosion {
        Explosion {
            position: self.flight.position,
            damage: 150.0 * self.warhead,
            radius: 5.0,
            fling: 9.0,
            antitank: 340.0 * self.warhead,
            direction: None,
            top: true,
            track: 0.3,
            source: self.operator,
            team: self.team,
            called_by: 0,
            size: 1.1,
            structure_multiplier: 1.5,
        }
    }

    pub fn detonate(&mut self) -> Option<Explosion> {
        if self.flight.dead {
            return None;
        }
        self.flight.dead = true;
        Some(self.explosion())
    }

    pub fn shot_down(&mut self) -> bool {
        let alive = !self.flight.dead;
        self.flight.dead = true;
        alive
    }

    pub fn advance(
        &mut self,
        dt: f64,
        operator_alive: bool,
        target: Option<Vector3>,
        collision: &mut CollisionWorld,
        map_half: f32,
    ) -> Result<Option<Explosion>, &'static str> {
        if !self.valid()
            || !dt.is_finite()
            || !(0.0..=10.0).contains(&dt)
            || !map_half.is_finite()
            || !(1.0..=1_000_000.0).contains(&map_half)
            || target.is_some_and(|p| !point(p))
        {
            return Err("invalid drone actor step");
        }
        if self.flight.dead {
            return Ok(None);
        }
        let mut next = *self;
        if next.operator != 0 && !operator_alive {
            next.lose_control();
        }
        if target.is_none() {
            next.target = 0;
        }
        let hit = next.flight.advance(dt, target, collision, map_half);
        if !next.valid() {
            return Err("drone step exceeds state limits");
        }
        *self = next;
        Ok(hit.then(|| self.explosion()))
    }

    pub fn checkpoint(&self) -> Result<Vec<u8>, &'static str> {
        if !self.valid() {
            return Err("invalid drone actor");
        }
        let mut out = Writer::new(b"FLDA\x01\0\0\0");
        for id in [
            self.id,
            self.operator,
            self.target,
            self.operator_at_spawn,
            self.target_at_spawn,
        ] {
            out.u32(id);
        }
        out.byte(self.team as u8);
        out.f64(self.warhead);
        out.bytes(&self.flight.checkpoint());
        Ok(out.0)
    }

    pub fn restore(bytes: &[u8]) -> Result<Self, &'static str> {
        let mut input = Reader::new(bytes, b"FLDA\x01\0\0\0")?;
        let s = Self {
            id: input.u32()?,
            operator: input.u32()?,
            target: input.u32()?,
            operator_at_spawn: input.u32()?,
            target_at_spawn: input.u32()?,
            team: input.byte()? as i8,
            warhead: input.f64()?,
            flight: DroneFlight::restore(input.bytes(59)?)?,
        };
        input.finish()?;
        if !s.valid() {
            return Err("invalid drone actor checkpoint");
        }
        Ok(s)
    }
}
