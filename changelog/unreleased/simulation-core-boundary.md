+++
title = "Separate visual randomness from battles"
summary = "Drawing debris no longer changes the random sequence used by gameplay. Simulation calculations are being separated from the renderer as groundwork for a standalone server."
kind = "fixed"
+++

- Cosmetic debris no longer consumes gameplay randomness when cosmetic physics is unavailable.
- This is groundwork for the server migration. Battles still use the existing simulation, and recordings are not yet independently verified.
