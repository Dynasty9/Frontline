# Native soldier batches

The Godot view still owns visibility, pose policy, selection and detailed model
budgets. Its existing presentation queue updates native batch metadata only when
those decisions change. Position targets remain in `SoldierViewMotion`, which
already smooths the client nodes. Property corrections preserve the metadata;
despawn removes it. Pose changes now wake the presentation queue too.

Once every pose atlas is ready, one native pass culls cells, groups the visible
men, encodes transforms/motion/pose values and computes swept bounds. Godot
uploads one buffer per populated group. The loading/reference path uses the same
buffer encoder. No simulation, network or replay format changes are involved.

## Component benchmark

Windows, i9-11900K, RTX 3090, Godot 4.7.2 Forward+, release Rust extension.
Other applications remain running. Two views share the same 500/2,000 soldiers,
two teams, positions, stances and target transforms. All soldiers are included;
the small BoxMesh isolates preparation from model draw cost. Each view warms up
for 24 uploads, then 256 uploads alternate old/new order within each frame.
The old view is the unchanged #137/#138 implementation. This deliberately
forces uploads; production normally updates them with snapshots, not every frame.

| Soldiers | Before mean / p99 ms | Native mean / p99 ms | Mean reduction |
| --- | ---: | ---: | ---: |
| 500 | 2.847 / 4.537 | 0.718 / 1.207 | 74.8% |
| 2,000 | 10.679 / 16.022 | 2.501 / 4.290 | 76.6% |

An earlier prototype replaced only the per-instance setters and bounds encoder.
It saved just 3.5% at 500 soldiers. The retained change moves the entire assembly
loop into native code; the small prototype was not published separately.

Local evidence: `build/soldier-upload-bench.gd`, `build/native-upload-bench.log`
and `build/soldier-upload-bench.json` in the soldier-buffer-upload worktree.

## Validation

Four headless fixture tests cover motion/presentation retention, native versus
reference buffer values, cell crossing, high elevation, scaled swept bounds,
corrections, removal/freed nodes, capacity growth/shrink, fog, selection and
all 16 unit pose sets. Invalid buffer input cannot partially append an instance.
The same layout test passes with Forward+ and Compatibility.

All 15 rendered poses are compared against the existing CPU reference, including
translation, yaw and lighting. Average byte errors are below 0.009 on both
renderers (out of 255), with visually matching side-by-side models. Compatibility
uses half-precision instance colors/custom data, so only those fields use a
0.1% relative comparison tolerance; transform floats remain strict.

Godot import and Windows release export pass. No reduced model count or graphics
setting is required for this change. Low-end GPUs and WebGL are not benchmarked.

## Full-game capture

Four alternating runs use the same saved 3 km city, 500 starting soldiers,
team 0, focus 0,0, zoom 130, High preset, Forward+, 1280 x 720, uncapped and
rendered offscreen. Each warms up for 30 seconds and measures 30 seconds.
Other applications stay running; no local builds/tests overlap these captures.
The control is #138, so this comparison excludes its ground-cover change.

| Run | FPS | p99 frame ms | Mean / p99 batch ms | Server ticks captured |
| --- | ---: | ---: | ---: | ---: |
| native-control-1 | 45.10 | 38.95 | 0.736 / 4.354 | 1800 |
| native-batch-1 | 47.36 | 34.91 | 0.315 / 0.899 | 1800 |
| native-batch-2 | 42.23 | 39.84 | 0.392 / 1.101 | 1800 |
| native-control-2 | 46.47 | 34.72 | 0.666 / 4.133 | 1800 |

Batch preparation is consistently cheaper, but whole-game FPS ranges overlap;
these captures do not establish an overall FPS gain. Background load affects
GPU timing too, and simulation warmup reaches different starting ticks despite
all captures containing 1,800 ticks. The summarized raw values are in the adjacent
JSON. Sustained 60 FPS and moving-camera performance remain unproven.
