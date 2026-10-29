+++
title = "Move projectile flight and battlefield raycasts into Rust"
summary = "Projectile flight, battlefield raycasts and seeded gameplay randomness now use the shared Rust core as the standalone server migration continues."
kind = "fixed"
+++

- Cosmetic debris no longer consumes gameplay randomness when cosmetic physics is unavailable.
- Grenade, smoke, rocket, bomb and shell flight now use the shared simulation core, preserving flight behavior, pickup, kicking and rethrowing.
- Battlefield raycasts now use the shared simulation core, updating when vehicles move, doors open and structures change.
- This is groundwork for the server migration. Battles still use the existing simulation, and recordings are not yet independently verified.
