# Camera movement and scenery preparation

Follow-up to combined optimizations #144, based on 3674b04d. No simulation,
protocol or replay changes. Other apps and the user's game remained running.

- Continuous movement is capped at 120 m/s after input, follow, glide and cursor
  zoom are combined. Mouse/trackpad displacement drains over frames; explicit
  focus/minimap jumps clear that displacement and remain immediate.
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
