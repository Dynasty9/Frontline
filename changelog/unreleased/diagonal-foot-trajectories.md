+++
title = "Improve diagonal rifleman steps"
summary = "Skinned riflemen retain foot clearance when mixing forward and sideways movement."
kind = "fixed"

[[screenshots]]
file = "comparison.jpg"
caption = "Before on the left, corrected foot trajectories on the right"
+++

Diagonal animation blends now preserve the source clips' foot and toe trajectories before solving ground contact. The correction fades in near straight movement, and stride timing accounts for combined travel direction. This reduces the collapsed steps and sliding seen in the opt-in skinned rifleman prototype.

Diagonal steps also anchor the toe while the ankle rolls over it, holding that contact through the longer diagonal step. This further reduces sliding without changing straight walking or running.

Toe-first diagonal landings now engage the anchor before the raised ankle comes down. The anchor permits the full planted step and follows the landing without the previous correction lag. Flat-ground regression samples show substantially less sliding; turning, uneven terrain and other animation transitions remain part of ongoing polish.


Released feet now return to the captured swing more gently while planted toes retain the faster contact correction. This reduces the largest leg movement in the 30 Hz turning regression without losing the diagonal landing fix.
