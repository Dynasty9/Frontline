# Swept soldier batch bounds

A spatial cell used an 86 m wide bound with 12 m of upper clearance. Its vertical
bounds could grow after blasts and never shrink. Godot selects mesh LOD for the
whole MultiMesh from its nearest bound, so this retained unnecessary detail.
See [Godot mesh LOD](https://docs.godotengine.org/en/stable/tutorials/3d/mesh_lod.html#using-mesh-lod-with-multimesh-and-particles).

Each upload now unions current/target positions expanded by the full animated
mesh radius and instance scale. The atlas stores the union of all 15 sampled pose
bounds. This covers intermediate turns, interpolation, hills and blasts, and
shrinks again on subsequent uploads. Geometry, animation timing, the four/16
articulated-model budgets, simulation and replay identity are unchanged.

## 5 November comparison

Release Godot 4.7.2, Windows, i9-11900K, RTX 3090, Forward+, High, 1280x720,
uncapped. Flat 1024 m stress map, 500 initial soldiers, combat, seed 3, observer,
focus 0,0, 35 m zoom. Warmup 30 s after loading, measure 30 s. Other applications
left running; no local tests or builds during capture. Order: control, changed,
changed, control. The control is PR #135 e15a71f including the final scheduling
fairness and hidden-soldier changes.

| Build | Average FPS, runs 1 / 2 | Frame p99, ms | Adjacent-frame difference p99, ms |
| --- | --- | --- | --- |
| Control | 72.82 / 71.42 | 25.966 / 29.137 | 10.992 / 11.320 |
| Swept bounds | 76.75 / 73.30 | 23.702 / 24.759 | 8.659 / 10.536 |

This averages about 4% more FPS and 12% lower frame p99. Rendered primitives fall
from 6.75 million to 6.64-6.66 million. GPU p99 is inconsistent (7.47-7.55 ms
control, 6.75-9.85 ms changed), so this does not establish a GPU-time improvement.
This is an incremental improvement, **not steady 60 FPS**. It does not substitute
for large generated-map, camera-pan, multiplayer or low-end GPU validation.

Three batch tests and the separate entity-smoothing test pass. Tests cover sparse
bounds, growth and shrinkage, scaling, every posture for all 16 unit types,
intermediate turns, target movement, teleports, visibility and detail transitions.
All 15 rendered rifleman poses pass the existing CPU/GPU comparison on Vulkan and
Compatibility; both images were inspected. The first new interpolation assertion
incorrectly checked a point above the fixture box; it was replaced with checks of
actual mesh vertices along the swept motion. The first worktree run lacked the
generated extension descriptor and is excluded; the native import and rerun pass.

Raw artifacts: `build/bounds-{control-1,1,2,control-2}/`, `bounds-final-tests.log`,
`bounds-native-tests.log`, `bounds-{vulkan,gl}.log` in the soldier-batch-bounds
worktree. [Compact timing data](soldier-bounds.json). The reproduction command and
frame tracing setup are the same as [the overview comparison](client-overview.md).
