+++
title = "Faster shared soldier rendering"
summary = "Large armies spend less CPU time preparing their distant models."
kind = "improved"
+++

The native view now groups distant soldiers, culls cells and prepares complete
instance buffers in one pass. Godot retains pose selection, fog visibility,
selection and close-up models. Walking still animates between network updates.

In a controlled upload test, 500 soldiers took 0.72 ms instead of 2.85 ms;
2,000 took 2.50 ms instead of 10.68 ms. These are batch preparation times, not
whole-frame FPS. All 15 shared poses retain their geometry, motion and lighting
in comparisons on both desktop rendering paths.
