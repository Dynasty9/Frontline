+++
title = "Move navigation and aircraft behavior into the Rust simulation core"
summary = "Navigation grids, aircraft attack schedules, missile guidance, projectile flight and battlefield raycasts now use the shared Rust core as the standalone server migration continues."
kind = "fixed"
+++

- Cosmetic debris no longer consumes gameplay randomness when cosmetic physics is unavailable.
- Grenade, smoke, rocket, bomb and shell flight now use the shared simulation core, preserving flight behavior, pickup, kicking and rethrowing.
- Battlefield raycasts now use the shared simulation core, updating when vehicles move, doors open and structures change.
- Local navigation grids and boat routes now use Rust, preserving weighted paths and corner-blocking rules.
- Hierarchical routes, danger weighting and map repairs now run in Rust. Large-cluster route caches distinguish entrances that previously shared a truncated key.
- Route refinement, smoothing, shared corridors and queued movement orders also run in Rust, retaining fire avoidance and order completion quotas.
- FPV drones, guided missiles and support-aircraft attack schedules now use Rust, preserving target loss, smoke countermeasures, bomb runs, gun bursts and reconnaissance.
- This is groundwork for the server migration. Battles still use the existing simulation, and recordings are not yet independently verified.
