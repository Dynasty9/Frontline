//! Arrival rules for boarding, tunnels, ammunition collection and ordered throws.
use crate::vector::Vector3;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Boarding {
    Cancel,
    Enter,
    Move,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum AfterBoarding {
    Enter,
    Continue { repath: bool },
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Tunnel {
    Move,
    Approach,
    Enter,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Throw {
    Move,
    Cancel,
    Release { remaining: i32 },
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct SupplyArrival {
    pub rounds: i32,
    pub announce: bool,
    pub return_to_hold: bool,
}

fn point(p: Vector3) -> bool {
    p.is_finite() && p.abs().max_element() <= 1_000_000.0
}
fn distance(a: Vector3, b: Vector3) -> f64 {
    let d = a - b;
    f64::from(Vector3::new(d.x, 0.0, d.z).length())
}
fn rounds(value: i32) -> bool {
    (0..=1_000_000).contains(&value)
}

pub fn boarding(
    valid: bool,
    position: Vector3,
    vehicle: Vector3,
    seats: i32,
    helicopter: bool,
    boat: bool,
    moving: bool,
) -> Result<Boarding, &'static str> {
    if !point(position) || !point(vehicle) || !(-1000..=1000).contains(&seats) {
        return Err("invalid boarding input");
    }
    if !valid || seats <= 0 || (helicopter && vehicle.y > 1.0) {
        return Ok(Boarding::Cancel);
    }
    let d = distance(vehicle, position);
    Ok(if d < 3.6 || (boat && (d < 8.0 || (d < 18.0 && !moving))) {
        Boarding::Enter
    } else {
        Boarding::Move
    })
}

pub fn after_boarding_move(
    position: Vector3,
    vehicle: Vector3,
    goal: Vector3,
    boat: bool,
    moved: bool,
) -> Result<AfterBoarding, &'static str> {
    if !point(position) || !point(vehicle) || !point(goal) {
        return Err("invalid boarding arrival");
    }
    // A stopped boat passenger may have waded as far as the ground permits.
    Ok(if boat && !moved && distance(vehicle, position) < 18.0 {
        AfterBoarding::Enter
    } else {
        AfterBoarding::Continue {
            repath: !moved || distance(goal, vehicle) > 3.0,
        }
    })
}

pub fn tunnel_arrival(
    position: Vector3,
    entrance: Vector3,
    moved: bool,
) -> Result<Tunnel, &'static str> {
    if !point(position) || !point(entrance) {
        return Err("invalid tunnel arrival");
    }
    Ok(if moved {
        Tunnel::Move
    } else if distance(entrance, position) > 2.5 {
        Tunnel::Approach
    } else {
        Tunnel::Enter
    })
}

pub fn ordered_throw(
    position: Vector3,
    target: Vector3,
    inventory: i32,
) -> Result<Throw, &'static str> {
    if !point(position) || !point(target) || !rounds(inventory) {
        return Err("invalid ordered throw");
    }
    Ok(if distance(target, position) > 25.0 {
        Throw::Move
    } else if inventory <= 0 {
        Throw::Cancel
    } else {
        Throw::Release {
            remaining: inventory - 1,
        }
    })
}

pub fn supply_arrival(
    capacity: i32,
    magazine: i32,
    reserve: i32,
    corpse_loot: Option<i32>,
) -> Result<SupplyArrival, &'static str> {
    if !rounds(capacity)
        || !rounds(magazine)
        || !rounds(reserve)
        || corpse_loot.is_some_and(|loot| !rounds(loot))
    {
        return Err("invalid supply arrival");
    }
    let total = magazine + reserve;
    Ok(if let Some(loot) = corpse_loot {
        SupplyArrival {
            rounds: if loot > 0 {
                (capacity - total).min(loot)
            } else {
                0
            },
            announce: loot > 0,
            return_to_hold: true,
        }
    } else {
        SupplyArrival {
            rounds: 0,
            announce: false,
            return_to_hold: total >= capacity - 5,
        }
    })
}
