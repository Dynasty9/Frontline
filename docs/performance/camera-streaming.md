# Camera movement and scenery preparation

Follow-up to combined optimizations #144, based on 3674b04d. No simulation,
protocol or replay changes. Other apps and the user's game remained running.

- Continuous movement is capped at 120 m/s after input, follow, glide and cursor
  zoom are combined. Mouse/trackpad displacement drains over frames; explicit
  focus calls for initial placement and test framing remain immediate. Minimap
  clicks and drags use the capped glide; another click retargets it.
- Structure preload boxes expand from 128 to 256 m half-width, with a separate
  384 m retention half-width. Already-active models remain resident in that wider
  band; only the preload band requests new models. The 2 ms/four-object frame
  budget is unchanged.
- Vegetation preloads 9 instead of 7 chunks in each direction (361 instead of
  225 chunks initially). Retention reaches 13 instead of 9 chunks (at most 729
  instead of 361 chunk keys in a full square). Map boundaries reduce these counts.
  Meshes and visible fade distances remain unchanged. The 1 ms/two-chunk budget
  remains unchanged. This trades memory and startup work for less rebuilding.
- Each vegetation MultiMesh uses one 16-float-per-instance buffer submission.

## Checks and measurements

On this Windows i9-11900K / RTX 3090 machine with Godot 4.7.2:

| Diagnostic | Before | After |
|---|---:|---:|
| Dense pan, missing visible-object samples | 4479 / 116400 | 0 / 116400 |
| Dense pan, peak simultaneously missing | 113 | 0 |
| 1024-instance assembly, Forward+ | 2.616 ms | 0.456 ms |
| 1024-instance assembly, Compatibility | 3.406 ms | 0.697 ms |

The pan diagnostic has 22,801 stub structures on an 8 m grid, a 1280x720 camera,
40-degree FOV, 100 m height, 240 steps of 2 m (120 m/s at 60 Hz). Initial residency
is warmed fully. Both versions use the same trajectory and four-object work cap.
It exercises the real StructureView queue but replaces model creation with a flag;
it does not model GPU costs or expensive procedural building generation. Sparse
20 m spacing had no missing visible samples in either version.

The buffer test alternates reference setters and the production bulk path in
ABBA order, 20 measurements each, using 1024 transforms and custom colors. Timing
covers assembly/submission, not GPU completion or a whole game frame. The matched
bush-array renders are pixel-identical in Forward+. Compatibility readback checks
compare against reference uploads because its colors use reduced precision.

Validation: four focused headless regressions (camera ceiling, vegetation bounds
and reversal, structure residency/retention, static batches); full rendered camera
controls 20/20; Vulkan and Compatibility instance transform/custom-data readback.
The full camera scenario retains its existing shutdown warnings (15 ObjectDB
instances and two resources). No script errors occurred in the successful runs.

Reproduce the buffer check with `res://tests/fixtures/vegetation-buffer.tscn`,
Forward+ or `--rendering-method gl_compatibility`. Set `FL_BUFFER_CAPTURE=1` to
save matched images under build/. `res://tests/fixtures/scenery-pan.tscn` runs the
candidate pan; optionally pass `-- --baseline-view=res://build/structure-before.gd`
after extracting #144's structure_view.gd there and removing its class_name line.

No new whole-game FPS claim. Fast rotations, explicit jumps and unusually dense
or slow-to-build scenery can still expose pending chunks. The preload bands are
bounded; this does not allocate the whole map's vegetation.


## Minimap follow-up

Minimap clicks and drags now call the existing capped `glide_to`, rather than
`focus`. Another click replaces the destination; manual panning cancels it.
No loading gate, additional cache or larger per-frame work budget was added.
A 1 km trip takes at least 8.3 seconds at the 120 m/s cap.

The scenery-pan fixture now drives the real minimap and camera over the same
480 m route instead of moving a test camera directly. With 22,801 stub objects,
the old immediate click exposes 193 unready visible objects at the destination.
The glide produced **0 missing / 121,253 visible-object samples**. The sample
count can vary slightly because the production camera reads the real clock.
The earlier 116,400-sample comparison above used the fixture at c02d2e7a.
The new regression asserts arrival, capped movement and no missing visible
objects. It still substitutes a flag for expensive model construction.

The vegetation queue also passes a 960 m diagonal route with 16 ms camera steps
and only one completed chunk per frame (production allows up to two): no pending
chunk intersects the 170 m maximum vegetation fade radius. This tests residency
and queue capacity, not actual chunk construction or GPU time.

Rendered attack-scenario camera controls: **24/24**, including minimap click,
speed limit, retargeting/arrival and manual cancellation. Existing shutdown
warnings remain (15 ObjectDB instances, two resources). No script errors.

## Why large maps take time to load

Existing local benchmark records from November 5, 2026 (not a fresh startup
benchmark of this change) show the generated 3072 m, seed 3, 500-unit workload:

| Stage | Two recorded runs |
|---|---:|
| Terrain/navigation allocation | 3.2-3.4 s |
| Map generation after allocation | 254.8-262.9 s |
| Ground/cover/navigation finalization | 17.5-18.6 s |
| Client world creation to ready | 35.7-36.9 s |

Sources: local session records `346d396366c03e5e5679c906e51c30a2fcc9680658936f74`
and `53f78ef7dc28e88614ea39fc756aad26d52f15aeebbed133`, `.load`, `.view-load`,
and `.json`; generated stress map, combat, 500 units, no vehicles. Other apps
were running. These coarse marks do not isolate geology, woodland placement,
serialization, Rust startup or shader compilation, and are not current-build
speed claims. Most recorded generator time falls inside `MapGen.generate`.
A three-times-wider map has nine times the area; several placement counts scale
with that area, alongside terrain grids.

Desktop startup currently runs a Godot map-authoring helper, saves an initial
simulation snapshot, launches Rust with it, then constructs the client's visual
world. `SimulationInitial.geometry` already serializes native terrain,
navigation, collision and spatial indexes. That is a useful starting point for
precomputation, but the full initial snapshot also contains match-specific
players, units and random state: blindly reusing it would start the wrong match.

The next loading change should separate a versioned immutable map package from
fresh match state. Bake terrain heights/kinds, water, roads, static placements,
cover/collision and navigation; load that package directly in Rust and Godot.
Key cached maps by generator/content/numeric format, dimensions, seed and all
map-affecting options; validate hashes and regenerate incompatible/corrupt data.
Initialize players, ownership, starting units and saved RNG state explicitly so
cached and generated starts remain replay-equivalent. Keep mutable destruction,
cover and navigation changes as match state, never shared cache state.

Ship baked packages for standard maps/missions and cache custom generated maps
after their first successful generation. New random seeds still need generation.
Client-side chunk buffers and blocked vegetation masks can be baked separately;
they need their own renderer/content invalidation. GPU resource uploads and
first-use shaders still require warmup. Prove cached/uncached initial-state and
replay equality, then compare cold and warm load stage timings before claiming a
speedup. No persistent map cache is implemented by this minimap fix.
